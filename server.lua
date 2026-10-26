-- ==============================================================================
-- SERVER: server.lua (Main Loop)
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
    busy = false, busy_time = 0,
    robot_ready = false, last_wake_time = 0,
    
    max_parent = {g=0, ga=0, r=0},
    max_child  = {g=0, ga=0, r=0},
    
    paused = false,
    shutdown_mode = false
}

local function setStatus(key, text) state.status_line[key] = text end

local function wakeRobot()
    modem.broadcast(CONFIG.port, CONFIG.wake_message)
    state.busy_time = os.time()
    state.last_wake_time = os.time()
end

-- ==============================================================================
-- ОСНОВНОЙ ЦИКЛ
-- ==============================================================================
local function mainLoop()
    ui.init()
    modem.open(CONFIG.port)
    
    -- Загрузка карты
    local ok, p_count, c_count, t_count = map_manager.load(state)
    if not ok then
        ui.logChat("S", "Ошибка: карта не найдена! Запустите mapping.lua")
        return
    end
    ui.logChat("S", "Загружено: " .. p_count .. " род, " .. c_count .. " кр, " .. t_count .. " тех.")
    
    -- Создаем кнопки (пока не работают, но пусть будут)
    ui.createButton(60, 2, 10, 1, "PAUSE", function() 
        state.paused = not state.paused 
        ui.logChat("S", state.paused and "PAUSE ВКЛ" or "PAUSE ВЫКЛ")
    end, 0x005500)
    
    ui.createButton(71, 2, 10, 1, "SHUTDOWN", function() 
        state.shutdown_mode = true 
        ui.logChat("S", "SHUTDOWN: Начинаю очистку...")
    end, 0x550000)

    -- Включаем точный режим экрана, если он есть
    if component.isAvailable("screen") then
        pcall(function() component.screen.setPrecise(true) end)
    end

    local last_scan = 0
    local last_phase_check = 0

    while true do
        -- Слушаем модем и клики
        local ev = table.pack(event.pull(0.1, "modem_message", "touch"))
        local need_render = false

        -- 1. Обработка кликов по кнопкам
        if ev[1] == "touch" then
            local x, y = ev[3], ev[4]
            for _, btn in ipairs(ui.getButtons()) do
                if x >= btn.x and x < btn.x + btn.w and y >= btn.y and y < btn.y + btn.h then
                    btn.action()
                    need_render = true
                    break
                end
            end
        end

        -- 2. Обработка сети
        if ev[1] == "modem_message" then
            local _, _, _, _, _, msg, id, arg1, arg2, arg3 = table.unpack(ev)
            state.busy_time = os.time() -- Сбрасываем таймаут при любом сообщении

            if msg == "READY" then
                state.robot_ready = true
                if state.phase == "EMERGENCY" then
                    state.phase = nil  -- checkPhase на следующем тике определит режим по факту поля
                end
                if not state.busy then
                    state.current_task = nil
                end
                need_render = true
            elseif msg == "NOT_READY" then
                state.phase = "EMERGENCY"
                state.busy = false
                state.current_task = nil
                state.locked = {} 
                ui.logChat("R<", "АВАРИЯ! Ждем ремонта.")
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

        -- 3. Таймауты
        if state.busy and (os.time() - state.busy_time > CONFIG.answer_timeout) then
            if os.time() - state.last_wake_time > 30 then
                ui.logChat("S", "Таймаут! Бужу робота.")
                wakeRobot()
                state.busy = false
                state.current_task = nil
                state.locked = {}
                need_render = true
            end
        end

        -- 4. Сканирование (раз в 0.5 сек)
        if os.time() - last_scan > 0.5 then
            scanner.scan(state, CONFIG, CROP_DB)
            last_scan = os.time()
            need_render = true
        end

        -- 5. Проверка фаз (раз в 2 сек)
        if os.time() - last_phase_check > 2 then
            local phase_msg = logic.checkPhase(state, CONFIG)
            if phase_msg then
                ui.logChat("S", "Phase -> " .. phase_msg)
            end
            last_phase_check = os.time()
            need_render = true
        end

        -- 6. SHUTDOWN (если включен, чистим поле и выключаемся)
        if state.shutdown_mode and not state.busy then
            local has_threats = false
            for k, d in pairs(state.scan_data) do
                if d.id == "weed" or d.id == "" then
                    has_threats = true
                    break
                end
            end
            if not has_threats then
                ui.logChat("S", "Безопасное завершение работы.")
                ui.render(state, CONFIG, true)
                os.sleep(2)
                computer.shutdown()
            end
        end

        -- 7. Выдача задач
        if state.robot_ready and not state.busy then
            local action, key, display_status = tasks.getTask(state, CONFIG)
            if action then
                state.task_counter = state.task_counter + 1
                state.busy = true
                state.busy_time = os.time()
                state.current_task = { id = state.task_counter, key = key, action = action }
                state.locked[key] = true

                setStatus(key, display_status)
                ui.logChat("S>", string.format("%s #%d -> %s", action, state.task_counter, key))
                modem.broadcast(CONFIG.port, "CMD", state.task_counter, action, key, display_status)
                need_render = true
            end
        end

        -- 8. Отрисовка
        if need_render then 
            ui.render(state, CONFIG, false) 
        end
    end
end

-- ==============================================================================
-- СТАРТ
-- ==============================================================================
mainLoop()