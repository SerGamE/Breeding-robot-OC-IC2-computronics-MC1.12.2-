-- ==============================================================================
-- SERVER: server.lua (Strict Dialog Protocol)
-- ==============================================================================
local component = require("component")
local event     = require("event")
local computer  = require("computer")
local serialization = require("serialization")

local CONFIG      = require("config")
local CROP_DB     = require("SeedsDB")
local ui          = require("ui")
local map_manager = require("map_manager")
local scanner     = require("scanner")
local logic       = require("logic")
local tasks       = require("tasks")

local modem = component.modem

local state = {
    phase = "INIT",
    crop_matrix = {}, cell_status = {}, scan_data = {}, status_line = {}, locked = {},
    task_counter = 0, current_task = nil,
    busy = false, busy_uptime = 0,
    robot_ready = false, last_wake_uptime = 0,
    max_parent = {g=0, ga=0, r=0}, max_child = {g=0, ga=0, r=0},
    paused = false, shutdown_mode = false, emergency_notified = false
}

local function setStatus(key, text) state.status_line[key] = text end

local function wakeRobot()
    modem.broadcast(CONFIG.port, CONFIG.wake_message)
    state.busy_uptime = computer.uptime()
    state.last_wake_uptime = computer.uptime()
    state.robot_ready = false 
    state.busy = false
    state.current_task = nil
    state.locked = {}
end

local function mainLoop()
    ui.init()
    modem.open(CONFIG.port)
    
    local ok, p_count, c_count, t_count = map_manager.load(state)
    if not ok then ui.logChat("S", "Ошибка: карта не найдена!"); return end
    ui.logChat("S", "Загружено: " .. p_count .. " род, " .. c_count .. " кр, " .. t_count .. " тех.")
    
    ui.createButton(60, 2, 10, 1, "PAUSE", function() state.paused = not state.paused end, 0x005500)
    ui.createButton(71, 2, 10, 1, "SHUTDOWN", function() state.shutdown_mode = true end, 0x550000)

    if component.isAvailable("screen") then pcall(function() component.screen.setPrecise(true) end) end
    ui.logChat("S", "Сервер запущен. Жду READY от робота.")

    local last_scan, last_full_scan, last_phase_check = 0, 0, 0

    while true do
        local ev = table.pack(event.pull(0.1, "modem_message"))
        local need_render = false

        -- 1. Сеть
        if ev[1] == "modem_message" then
            local _, _, _, _, _, msg, id, arg1, arg2, arg3 = table.unpack(ev)
            state.busy_uptime = computer.uptime()

            if msg == "READY" then
                state.robot_ready = true
                state.emergency_notified = false
                need_render = true
                
            elseif msg == "NOT_READY" then
                state.robot_ready = false
                state.busy = false; state.current_task = nil; state.locked = {} 
                state.phase = "EMERGENCY"
                if not state.emergency_notified then
                    ui.logChat("R<", "АВАРИЯ! Робот требует ремонта.")
                    state.emergency_notified = true
                end
                need_render = true
                
            elseif msg == "ALIVE" then
                -- ALIVE только для сброса таймера.
                state.busy_uptime = computer.uptime()

            elseif msg == "TAKEN" then
                if state.current_task and state.current_task.id == id then
                    state.current_task.taken = true
                    state.busy_uptime = computer.uptime()
                end
                
            elseif msg == "ACK" then
                if state.current_task and state.current_task.id == id then
                    state.busy = false; state.current_task = nil
                    if state.locked[arg1] then state.locked[arg1] = nil end
                    setStatus(arg1, nil)
                    need_render = true
                end
                
            elseif msg == "REPLACE_RESULT" then
                if state.current_task and state.current_task.id == id then
                    state.busy = false; state.current_task = nil
                    if state.locked[arg1] then state.locked[arg1] = nil end
                    if state.locked[arg2] then state.locked[arg2] = nil end
                    setStatus(arg1, nil)
                    
                    local seeds_count = tonumber(arg3) or 0
                    if seeds_count > 0 then
                        local candidates = {}
                        for pk, st in pairs(state.cell_status) do
                            if st == 1 and not state.locked[pk] then
                                local pd = state.scan_data[pk]
                                local score = -1
                                if pd and pd.id == CONFIG.crop_id then score = (pd.g or 0) + (pd.ga or 0) + (pd.r or 0) end
                                table.insert(candidates, {key=pk, score=score})
                            end
                        end
                        table.sort(candidates, function(a,b) return a.score < b.score end)
                        local targets = {}
                        for i = 1, math.min(seeds_count, #candidates) do table.insert(targets, candidates[i].key) end
                        
                        if #targets > 0 then
                            state.task_counter = state.task_counter + 1
                            state.busy = true
                            state.busy_uptime = computer.uptime()
                            state.current_task = { id = state.task_counter, key = arg1, action = "PLANT_MULTI", taken = false }
                            local coords = serialization.serialize(targets)
                            modem.broadcast(CONFIG.port, "CMD", state.task_counter, "PLANT_MULTI", coords)
                            ui.logChat("S>", string.format("PLANT_MULTI #%d -> %d слотов", state.task_counter, #targets))
                        end
                    end
                    need_render = true
                end
            elseif msg == "ALERT" then
                ui.logChat("R<", "ERROR: " .. tostring(arg1))
                need_render = true
            end
        end

        -- 2. Таймауты
        if state.busy and state.current_task then
            local delta = computer.uptime() - state.busy_uptime
            
            if state.current_task.taken then
                -- Ждем ACK (робот взял и работает)
                if delta > 40 then
                    ui.logChat("S", "Таймаут выполнения! Бужу робота.")
                    wakeRobot()
                    need_render = true
                end
            else
                -- Ждем TAKEN (робот не взял задачу)
                if delta > 5 then
                    if state.robot_ready then
                        -- Робот сказал READY, но прослушал. Шлем еще раз.
                        ui.logChat("S", "Робот не взял задачу. Повтор #" .. state.current_task.id)
                        modem.broadcast(CONFIG.port, "CMD", state.current_task.id, state.current_task.action, state.current_task.key)
                        state.busy_uptime = computer.uptime() -- Даем еще 5 сек
                    else
                        -- Робот не сказал READY (возможно проснулся, но не загрузился)
                        ui.logChat("S", "Робот не готов. Жду READY.")
                        state.busy = false
                        state.current_task = nil
                        state.locked = {}
                        need_render = true
                    end
                end
            end
        end

        -- 3. Скан
        if computer.uptime() - last_scan >= 0.2 then
            local full = (computer.uptime() - last_full_scan >= 3)
            scanner.scan(state, CONFIG, CROP_DB, full)
            if full then last_full_scan = computer.uptime() end
            last_scan = computer.uptime()
            need_render = true
        end

        -- 4. Фазы
        if computer.uptime() - last_phase_check >= 5 then
            if state.phase ~= "EMERGENCY" then
                local phase_msg = logic.checkPhase(state, CONFIG)
                if phase_msg then ui.logChat("S", "Phase -> " .. phase_msg) end
            end
            last_phase_check = computer.uptime()
            need_render = true
        end

        -- 5. Выдача задач
        local can_work = state.robot_ready or (state.phase == "EMERGENCY" and not state.robot_ready)
        if can_work and not state.busy then
            local action, key, display_status = tasks.getTask(state, CONFIG)
            if action then
                state.task_counter = state.task_counter + 1
                state.busy = true
                state.busy_uptime = computer.uptime()
                state.current_task = { id = state.task_counter, key = key, action = action, taken = false }
                state.locked[key] = true

                setStatus(key, display_status)
                ui.logChat("S>", string.format("%s #%d -> %s", action, state.task_counter, key))
                
                if state.phase == "EMERGENCY" then
                    modem.broadcast(CONFIG.port, "CMD", state.task_counter, "EMERGENCY_CLEAR", key)
                else
                    modem.broadcast(CONFIG.port, "CMD", state.task_counter, action, key, display_status)
                end
                need_render = true
            end
        end

        if need_render then ui.render(state, CONFIG, false) end
    end
end

mainLoop()