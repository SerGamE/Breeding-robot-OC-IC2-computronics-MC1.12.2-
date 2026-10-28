-- ==============================================================================
-- SERVER: server.lua (Uptime timers + fast scan)
-- ==============================================================================
local component = require("component")
local event     = require("event")
local computer  = require("computer")

local CONFIG      = require("config")
local CROP_DB     = require("SeedsDB")
local ui          = require("ui")
local map_manager = require("map_manager")
local scanner     = require("scanner")
local logic       = require("logic")
local tasks       = require("tasks")

local modem = component.modem

-- ==============================================================================
-- СОСТОЯНИЕ
-- ==============================================================================
local state = {
    phase = "INIT",
    crop_matrix = {},
    cell_status = {},
    scan_data = {},
    status_line = {},
    locked = {},
    
    task_counter = 0,
    current_task = nil,
    busy = false, busy_uptime = 0,
    robot_ready = false, last_wake_uptime = 0,
    
    max_parent = {g=0, ga=0, r=0},
    max_child  = {g=0, ga=0, r=0},
    
    paused = false,
    shutdown_mode = false,
    
    emergency_notified = false
}

local function setStatus(key, text) state.status_line[key] = text end

local function wakeRobot()
    modem.broadcast(CONFIG.port, CONFIG.wake_message)
    state.busy_uptime = computer.uptime()
    state.last_wake_uptime = computer.uptime()
end

-- ==============================================================================
-- ОСНОВНОЙ ЦИКЛ
-- ==============================================================================
local function mainLoop()
    ui.init()
    modem.open(CONFIG.port)
    
    local ok, p_count, c_count, t_count = map_manager.load(state)
    if not ok then
        ui.logChat("S", "Ошибка: карта не найдена! Запустите mapping.lua")
        return
    end
    ui.logChat("S", "Загружено: " .. p_count .. " род, " .. c_count .. " кр, " .. t_count .. " тех.")
    
    ui.createButton(60, 2, 10, 1, "PAUSE", function() 
        state.paused = not state.paused 
        ui.logChat("S", state.paused and "PAUSE ВКЛ" or "PAUSE ВЫКЛ")
    end, 0x005500)
    
    ui.createButton(71, 2, 10, 1, "SHUTDOWN", function() 
        state.shutdown_mode = true 
        ui.logChat("S", "SHUTDOWN: Начинаю очистку...")
    end, 0x550000)

    if component.isAvailable("screen") then
        pcall(function() component.screen.setPrecise(true) end)
    end

    wakeRobot()
    ui.logChat("S", "Отправлен WAKE_UP роботу")

    local last_scan = 0
    local last_full_scan = 0
    local last_phase_check = 0

    while true do
        local ev = table.pack(event.pull(0.1, "modem_message"))
        local need_render = false

        -- 1. Обработка сети
        if ev[1] == "modem_message" then
            local _, _, _, _, _, msg, id, arg1, arg2, arg3 = table.unpack(ev)
            
            state.busy_uptime = computer.uptime()

            if msg == "READY" then
                state.robot_ready = true
                state.busy = false
                state.current_task = nil
                state.locked = {} 
                if state.phase == "EMERGENCY" then
                    state.phase = "INIT"
                    ui.logChat("S", "EMERGENCY OFF (робот починился)")
                end
                state.emergency_notified = false
                need_render = true
                
            elseif msg == "NOT_READY" then
                state.robot_ready = false
                state.busy = false
                state.current_task = nil
                state.locked = {} 
                state.phase = "EMERGENCY"
                if not state.emergency_notified then
                    ui.logChat("R<", "АВАРИЯ! Робот требует ремонта.")
                    state.emergency_notified = true
                end
                need_render = true
                
            elseif msg == "ACK" then
                if state.current_task and state.current_task.id == id then
                    state.busy = false
                    state.current_task = nil
                    if state.locked[arg1] then state.locked[arg1] = nil end
                    setStatus(arg1, nil)
                    need_render = true
                end
            elseif msg == "REPLACE_RESULT" then
                if state.current_task and state.current_task.id == id then
                    state.busy = false
                    state.current_task = nil
                    if state.locked[arg1] then state.locked[arg1] = nil end
                    setStatus(arg1, nil)
                    need_render = true
                end
            elseif msg == "ALERT" then
                ui.logChat("R<", "ERROR: " .. tostring(arg1))
                need_render = true
            end
        end

        -- 2. Таймаут ожидания робота
        if state.busy and (computer.uptime() - state.busy_uptime > CONFIG.answer_timeout) then
            if computer.uptime() - state.last_wake_uptime > 10 then
                ui.logChat("S", "Таймаут задачи. Бужу робота.")
                wakeRobot()
                state.locked = {}
                state.current_task = nil
            end
        end

        -- 3. Сканирование (быстрый каждые 0.2 сек, полный раз в 3 сек)
        if computer.uptime() - last_scan >= 0.2 then
            local full = (computer.uptime() - last_full_scan >= 3)
            scanner.scan(state, CONFIG, CROP_DB, full)
            if full then last_full_scan = computer.uptime() end
            last_scan = computer.uptime()
            need_render = true
        end

        -- 4. Проверка фаз (раз в 5 сек, кроме EMERGENCY)
        if computer.uptime() - last_phase_check >= 5 then
            if state.phase ~= "EMERGENCY" then
                local phase_msg = logic.checkPhase(state, CONFIG)
                if phase_msg then
                    ui.logChat("S", "Phase -> " .. phase_msg)
                end
            end
            last_phase_check = computer.uptime()
            need_render = true
        end

        -- 5. Выдача задач
        local can_work = state.robot_ready or (state.phase == "EMERGENCY")
        if can_work and not state.busy then
            local action, key, display_status = tasks.getTask(state, CONFIG)
            if action then
                state.task_counter = state.task_counter + 1
                state.busy = true
                state.busy_uptime = computer.uptime()
                state.current_task = { id = state.task_counter, key = key, action = action }
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

        -- 6. Отрисовка
        if need_render then 
            ui.render(state, CONFIG, false) 
        end
    end
end

-- ==============================================================================
-- СТАРТ
-- ==============================================================================
mainLoop()