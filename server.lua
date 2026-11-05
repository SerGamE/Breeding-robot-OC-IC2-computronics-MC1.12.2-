-- ==============================================================================
-- SERVER: server.lua (Strict Dialog Protocol + UI Buttons)
-- ==============================================================================
local component   = require("component")
local event       = require("event")
local computer    = require("computer")
local serialization = require("serialization")
local gpu         = component.gpu
local term        = require("term")
local CONFIG      = require("config")
local CROP_DB     = require("SeedsDB")
local ui          = require("ui")
local map_manager = require("map_manager")
local scanner     = require("scanner")
local logic       = require("logic")
local tasks       = require("tasks")
local thread      = require("thread")
local modem       = component.modem

local state = {
    phase = "INIT",    last_invert_time = 0,     
    crop_matrix = {}, cell_status = {}, scan_data = {}, status_line = {}, locked = {},
    task_counter = 0, current_task = nil,
    busy = false, busy_uptime = 0,
    robot_ready = false, last_wake_uptime = 0,
    max_parent = {g=0, ga=0, r=0}, max_child = {g=0, ga=0, r=0},
    paused = false, shutdown_mode = false, emergency_notified = false, last_alive = 0
}

local function setStatus(key, text) state.status_line[key] = text end

local function wakeRobot()
    modem.broadcast(CONFIG.port, CONFIG.wake_message)
    state.busy_uptime = computer.uptime()
    state.last_wake_uptime = computer.uptime()
    state.last_alive = computer.uptime() -- Сбрасываем таймер жизни
    state.robot_ready = false 
    state.busy = false
    state.current_task = nil
    state.locked = {}
end

-- Действия кнопок (чтобы не дублировать код для клавиш и кнопок)
local function actionPause()
    state.paused = not state.paused 
    ui.logChat("S", state.paused and "PAUSE ВКЛ" or "PAUSE ВЫКЛ")
end

local function actionShutdown()
    state.shutdown_mode = true 
    ui.logChat("S", "SHUTDOWN: Начинаю очистку...")
end

-- Запускаем фоновый поток проверки жизни робота
thread.create(function()
    while true do
        os.sleep(5) -- Проверяем каждые 5 секунд
        local alive_delta = computer.uptime() - state.last_alive
        
        -- Если робот не слал ALIVE больше 40 секунд
        if alive_delta > CONFIG.robot_wake_timeout then
            -- Проверяем, чтобы не спамить пробуждением
            if computer.uptime() - state.last_wake_uptime > 20 then
                wakeRobot()
                -- В лог писать не будем, чтобы не засорять чат каждые 20 сек,
                -- или можем добавить редкий лог
            end
        end
    end
end)

local function mainLoop()
    ui.init(CONFIG)
    modem.open(CONFIG.port)
    -- При запуске будим робота даже если тот не дрыхнет
    state.last_alive = computer.uptime() -- Сбрасываем таймер, чтобы поток не дублировал
    wakeRobot()
    ui.logChat("S", "Поиск робота...")
    local ok, p_count, c_count, t_count = map_manager.load(state)
    if not ok then ui.logChat("S", "Ошибка: карта не найдена!"); return end
    ui.logChat("S", "карта" .. p_count .. " р, " .. c_count .. " к," .. t_count .. " т")
    
    -- Создаем кнопки, привязанные к правому краю
    local w, h = component.gpu.getResolution()
    ui.createButton(w - 4, 2, 2, 1, "⏸", actionPause, 0x005500)
    ui.createButton(w - 2, 2, 2, 1, "❌", actionShutdown, 0x550000)

    if component.isAvailable("screen") then pcall(function() component.screen.setPrecise(true) end) end
    ui.logChat("S", "Готов. Жду готовность робота.")

    local last_scan, last_full_scan, last_phase_check = 0, 0, 0

    while true do
        -- Ловим ВСЁ, без фильтров (чтобы не пропускать события)
        local ev = table.pack(event.pull(0.1))
        local need_render = false
        -- 1. Обработка кликов мышкой
        if ev[1] == "touch" then
            local _, _, tx, ty = table.unpack(ev)
            tx = math.ceil(tx) -- округляем вверх
            ty = math.ceil(ty)
            
            for _, btn in ipairs(ui.getButtons()) do
                if tx >= btn.x and tx < btn.x + btn.w and ty >= btn.y and ty < btn.y + btn.h then
                    btn.action()
                    need_render = true
                    break
                end
            end
        -- 2. Обработка горячих клавиш
        elseif ev[1] == "key_down" then
            local _, _, char, code = table.unpack(ev)
            if code == 201 then -- Кнопка PAUSE
                actionPause()
                need_render = true
            elseif code == 207 then -- Кнопка END
                actionShutdown()
                need_render = true
            end
        -- 3. Обработка сети
        elseif ev[1] == "modem_message" then
            local _, _, _, _, _, msg, id, arg1, arg2, arg3 = table.unpack(ev)

            if msg == "READY" then
                state.robot_ready = true
                state.emergency_notified = false
                if state.phase == "EMERGENCY" then
                    state.phase = "INIT"
                    state.busy = false
                    state.current_task = nil
                    state.locked = {}
                    ui.logChat("S", "EMERG OFF(робот починился)")
                end
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
                
            elseif msg == "TAKEN" then
                if state.current_task and state.current_task.id == id then
                    state.current_task.taken = true
                end

            elseif msg == "ALIVE" then
                state.last_alive = computer.uptime()
                
            elseif msg == "ACK" then
                if state.current_task and state.current_task.id == id then
                    state.busy = false; state.current_task = nil
                    if state.locked[arg1] then state.locked[arg1] = nil end
                    setStatus(arg1, nil)
                    need_render = true
                end
                
            elseif msg == "SEEDS" then
                if state.current_task and state.current_task.id == id then
                    local seeds_count = tonumber(arg1) or 0
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
                            local coords_str = serialization.serialize(targets)
                            modem.broadcast(CONFIG.port, "REPLACE_CORDS", id, coords_str)
                        end
                    end
                end
            elseif msg == "ALERT" then
                ui.logChat("R<", "ERROR: " .. tostring(arg1))
                need_render = true
            end
        end
        -- 4. Таймауты задач
        if state.busy and state.current_task then
            local delta = computer.uptime() - state.busy_uptime
            local alive_delta = computer.uptime() - state.last_alive
            
            if state.current_task.taken then
                -- Ждем ACK. Если робот не шлет ALIVE 40 секунд - отменяем задачу.
                if alive_delta > 40 then
                    ui.logChat("S", "Робот пропал. Отменяю задачу.")
                    state.busy = false
                    state.current_task = nil
                    state.locked = {}
                    need_render = true
                end
            else
                -- Ждем TAKEN
                if delta > 5 then
                    if alive_delta > 30 then
                        -- Робот не отвечает, отменяем. Поток его разбудит.
                        ui.logChat("S", "Робот пропал. Отменяю задачу.")
                        state.busy = false
                        state.current_task = nil
                        state.locked = {}
                        need_render = true
                    else
                        -- Робот жив, но прослушал. Повторяем задачу.
                        ui.logChat("S", "Повтор #" .. state.current_task.id)
                        if state.phase == "EMERGENCY" then
                            modem.broadcast(CONFIG.port, "CMD", state.current_task.id, "EMERGENCY_CLEAR", state.current_task.key)
                        else
                            modem.broadcast(CONFIG.port, "CMD", state.current_task.id, state.current_task.action, state.current_task.key)
                        end
                        state.busy_uptime = computer.uptime() 
                    end
                end
            end
        end
        -- 5. Скан
        if computer.uptime() - last_scan >= 0.2 then
            local full = (computer.uptime() - last_full_scan >= 3)
            scanner.scan(state, CONFIG, CROP_DB, full)
            if full then last_full_scan = computer.uptime() end
            last_scan = computer.uptime()
            need_render = true
        end
        -- 6. Фазы
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
        -- 7. Выдача задач
        local can_work = state.robot_ready or (state.phase == "EMERGENCY" and not state.robot_ready)
        if can_work and not state.busy then
            local action, key, display_status = tasks.getTask(state, CONFIG)
            -- Если мы завершаемся и задач нет - выключаемся
            if state.shutdown_mode and not action then
                ui.logChat("S", "Поле чистое. Завершаю работу...")
                ui.render(state, CONFIG, true) -- принудительно рисуем
                os.sleep(2)
                -- чистимся перед выходом
                ui.reset()
                gpu.setBackground(0x000000)
                gpu.setForeground(0xFFFFFF)
                local w, h = gpu.getResolution()
                gpu.fill(1, 1, w, h, " ")
                term.clear()
                term.setCursor(1, 1)
                print("харэ")
                os.exit()
            end

            if action then
                state.task_counter = state.task_counter + 1
                state.busy = true
                state.busy_uptime = computer.uptime()
                state.current_task = { id = state.task_counter, key = key, action = action, taken = false }
                state.locked[key] = true

                local screen_status = (action == "MULTI_PLANT") and "MULTI" or display_status
                setStatus(key, screen_status)
                -- Если display_status содержит причину (WEAK, EXCESS и т.д.), пишем её вместо action
                local log_action = display_status or action
                -- Для MULTI_PLANT display_status - это координаты, поэтому пишем action
                if action == "MULTI_PLANT" then log_action = action end
                ui.logChat("S>", string.format("%s #%d -> %s", log_action, state.task_counter, key))
                
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
