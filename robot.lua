-- ==============================================================================
-- ROBOT: r.lua (Architecture 4.1 - Clean Protocol)
-- ==============================================================================
local robot         = require("robot")
local component     = require("component")
local event         = require("event")
local computer      = require("computer")
local term          = require("term")
local serialization = require("serialization")
local fs            = require("filesystem")
local thread        = require("thread")

local inv  = component.inventory_controller
local nav  = component.navigation
local modem = component.modem

-- ==============================================================================
-- БЛОК 1: КОНФИГ И ИНИЦИАЛИЗАЦИЯ
-- ==============================================================================
local PORT = 109
local WAKE_MSG = "WAKE_UP_MAN"
local WAYPOINT_LABEL = "CHICHI"
local HOME_FACING = 3 -- 3 = глобальный Юг
local MIN_STICKS = 1

local SLOT_STICK = 1
local SLOT_AXE   = 2
local FIRST_CARGO_SLOT = 3

modem.open(PORT)
modem.setWakeMessage(WAKE_MSG)

local TOOLS_FILE = "/home/tools.lua"
local TOOLS = { stick = "ic2:crop_stick", weapon = "gravisuite:vajra", trowel = "ic2:weeding_trowel" }

local function setupTools()
    if fs.exists(TOOLS_FILE) then
        local ok, loaded = pcall(require, "tools")
        if ok and type(loaded) == "table" then TOOLS = loaded return end
    end
    term.clear()
    print("=== НАСТРОЙКА ИНСТРУМЕНТОВ ===")
    print("СЛОТ 1: Жердочки, СЛОТ 2: Оружие, СЛОТ 3: Пропалыватель")
    print("Нажмите Enter...")
    event.pull("key_down")
    local s1, s2, s3 = inv.getStackInInternalSlot(1), inv.getStackInInternalSlot(2), inv.getStackInInternalSlot(3)
    if s1 then TOOLS.stick = s1.name end
    if s2 then TOOLS.weapon = s2.name end
    if s3 then TOOLS.trowel = s3.name end
    local f = fs.open(TOOLS_FILE, "w")
    f:write("return { stick='"..TOOLS.stick.."', weapon='"..TOOLS.weapon.."', trowel='"..TOOLS.trowel.."' }")
    f:close()
    term.clear(); print("Сохранено!"); os.sleep(1)
end

-- ==============================================================================
-- БЛОК 2: НАВИГАЦИЯ И ВОЗВРАТ
-- ==============================================================================
local state = {
    last_ready_pulse = 0,
    ready_sent = false,
    not_ready_sent = false,
    cur_x = 0, cur_z = 0, cur_dir = 0,
    is_ready = false, is_emergency = false,
    last_completed_task_id = nil,
    pending_ack = nil,
    my_best_seeds = {}
}

local function getPos()
    if not nav then return nil, nil end
    for _, wp in ipairs(nav.findWaypoints(50)) do
        if wp.label == WAYPOINT_LABEL then return wp.position[1], wp.position[3] end
    end
    return nil, nil
end

local function faceDir(target_dir)
    if not nav then return end
    local current = nav.getFacing()
    local turns = 0
    while current ~= target_dir and turns < 4 do 
        robot.turnRight(); current = nav.getFacing(); turns = turns + 1
    end
end

local function emergencyGoHome()
    if not nav then return end
    local dx, dz = getPos()
    if not dx then return end
    local attempts = 0
    while (math.abs(dx) > 0.5 or math.abs(dz) > 0.5) and attempts < 30 do
        if math.abs(dx) > 0.5 then
            if dx < 0 then faceDir(4) else faceDir(5) end
            if not robot.forward() then robot.turnRight(); robot.forward(); robot.turnLeft() end
        elseif math.abs(dz) > 0.5 then
            if dz > 0 then faceDir(3) else faceDir(2) end
            if not robot.forward() then robot.turnRight(); robot.forward(); robot.turnLeft() end
        end
        dx, dz = getPos(); attempts = attempts + 1; os.sleep(0.1)
    end
    faceDir(HOME_FACING)
    state.cur_x, state.cur_z, state.cur_dir = 0, 0, 0
end

-- ==============================================================================
-- БЛОК 3: ДВИЖЕНИЕ
-- ==============================================================================
local function turn(dir)
    while state.cur_dir ~= dir do robot.turnRight(); state.cur_dir = (state.cur_dir + 1) % 4 end
end

local function walk(x, z)
    if x > 20 or z > 20 or x < -2 or z < -2 then emergencyGoHome(); return end
    local success = true
    if x > state.cur_x then 
        turn(0); for _ = 1, x - state.cur_x do if not robot.forward() then success = false break end end
    elseif x < state.cur_x then 
        turn(2); for _ = 1, state.cur_x - x do if not robot.forward() then success = false break end end 
    end
    if success and z > state.cur_z then 
        turn(1); for _ = 1, z - state.cur_z do if not robot.forward() then success = false break end end
    elseif success and z < state.cur_z then 
        turn(3); for _ = 1, state.cur_z - z do if not robot.forward() then success = false break end end 
    end
    if not success then emergencyGoHome() else state.cur_x, state.cur_z = x, z end
end

local function goHome()
    if state.cur_x and state.cur_z then
        walk(0, 0)
        if nav then while nav.getFacing() ~= HOME_FACING do robot.turnRight(); state.cur_dir = (state.cur_dir + 1) % 4 end end
    else
        emergencyGoHome()
    end
end

-- ==============================================================================
-- БЛОК 4: ИНВЕНТАРЬ
-- ==============================================================================
local function getStackInHand()
    local empty_slot = nil
    for slot = FIRST_CARGO_SLOT, robot.inventorySize() do
        if inv.getStackInInternalSlot(slot) == nil then empty_slot = slot; break end
    end
    if not empty_slot then
        for slot = FIRST_CARGO_SLOT, robot.inventorySize() do
            local s = inv.getStackInInternalSlot(slot)
            if s and s.name ~= TOOLS.stick and s.name ~= TOOLS.weapon and s.name ~= TOOLS.trowel then
                robot.select(slot); robot.drop(); empty_slot = slot; break
            end
        end
    end
    if not empty_slot then return nil end
    robot.select(empty_slot); inv.equip()
    local item = inv.getStackInInternalSlot(empty_slot)
    inv.equip(); robot.select(1)
    return item and item.name or nil
end

local function quickInventoryCheck()
    local s1 = inv.getStackInInternalSlot(1)
    if not s1 or s1.name ~= TOOLS.stick or robot.count(1) < MIN_STICKS then return false, "NO_STICKS" end
    local s2 = inv.getStackInInternalSlot(2)
    if not s2 or s2.name ~= TOOLS.weapon then return false, "NO_WEAPON" end
    local hand = getStackInHand()
    if hand ~= TOOLS.trowel then return false, "NO_TROWEL" end
    if nav and nav.getFacing() ~= HOME_FACING then return false, "WRONG_FACING" end
    return true
end

-- ==============================================================================
-- БЛОК 5: САМОДИАГНОСТИКА
-- ==============================================================================
local function selfDiagnosis()
    emergencyGoHome()
    if nav then while nav.getFacing() ~= HOME_FACING do robot.turnRight() end end

    local hand = getStackInHand()
    if hand ~= TOOLS.trowel then
        local found = false
        for i = 1, robot.inventorySize() do
            local s = inv.getStackInInternalSlot(i)
            if s and s.name == TOOLS.trowel then robot.select(i); inv.equip(); robot.select(1); found = true; break end
        end
        if not found then return false, "NO_TROWEL" end
    end

    local s1 = inv.getStackInInternalSlot(1)
    if s1 and s1.name ~= TOOLS.stick then
        if s1.name == TOOLS.weapon then robot.transferTo(2) else robot.select(1); robot.drop() end
    end
    local s2 = inv.getStackInInternalSlot(2)
    if s2 and s2.name ~= TOOLS.weapon then
        if s2.name == TOOLS.stick then robot.transferTo(1) else robot.select(2); robot.drop() end
    end

    if robot.count(1) < MIN_STICKS then
        local my_sticks_slots = {}
        for i = 3, robot.inventorySize() do
            local s = inv.getStackInInternalSlot(i)
            if s and s.name == TOOLS.stick then table.insert(my_sticks_slots, i) end
        end
        if #my_sticks_slots > 0 then
            walk(0, 1)
            for _, slot in ipairs(my_sticks_slots) do robot.select(slot); robot.dropDown() end
            robot.select(1); goHome()
        end
        walk(0, 1)
        robot.select(1); robot.suckDown(64)
        goHome()
        if robot.count(1) < MIN_STICKS then return false, "NO_STICKS" end
    end

    local s2_new = inv.getStackInInternalSlot(2)
    if not s2_new or s2_new.name ~= TOOLS.weapon then
        local found_weapon = false
        for i = 3, robot.inventorySize() do
            local s = inv.getStackInInternalSlot(i)
            if s and s.name == TOOLS.weapon then robot.select(i); robot.transferTo(2); found_weapon = true; break end
        end
        if not found_weapon then return false, "NO_WEAPON" end
    end

    local final_s1 = inv.getStackInInternalSlot(1)
    local final_s2 = inv.getStackInInternalSlot(2)
    local final_hand = getStackInHand()
    if not final_s1 or final_s1.name ~= TOOLS.stick then return false, "STICKS_ERROR" end
    if not final_s2 or final_s2.name ~= TOOLS.weapon then return false, "WEAPON_ERROR" end
    if final_hand ~= TOOLS.trowel then return false, "TROWEL_ERROR" end

    walk(0, -1)
    for slot = 3, robot.inventorySize() do
        if robot.count(slot) > 0 then robot.select(slot); robot.dropDown() end
    end
    robot.select(1); goHome()
    return true
end

-- ==============================================================================
-- БЛОК 6: ДЕЙСТВИЯ
-- ==============================================================================
local function swingAxe() robot.select(2); inv.equip(); robot.swingDown(); inv.equip(); robot.select(1) end
local function placeDoubleCrop() robot.select(1); inv.equip(); robot.useDown(); robot.useDown(); inv.equip(); robot.select(1) end

local function dropExcessSticks()
    local stick_slots = {}
    for slot = 3, robot.inventorySize() do
        local s = inv.getStackInInternalSlot(slot)
        if s and s.name == TOOLS.stick then table.insert(stick_slots, slot) end
    end
    if #stick_slots == 0 then return end
    walk(0, 1)
    for _, slot in ipairs(stick_slots) do robot.select(slot); robot.dropDown() end
    robot.select(1); goHome()
end

local function dropCargo()
    dropExcessSticks()
    walk(0, -1)
    for slot = 3, robot.inventorySize() do
        if robot.count(slot) > 0 then robot.select(slot); robot.dropDown() end
    end
    robot.select(1); goHome()
end

local function refillSticks()
    walk(0, 1)
    robot.select(1)
    robot.suckDown(64 - robot.count(1))
    dropExcessSticks()
    robot.select(1)
    goHome()
end

local function cleanupBeforePlantMulti()
    local total = robot.count(1)
    if total > MIN_STICKS then
        walk(0, 1)
        robot.select(1)
        robot.dropDown()
        robot.suckDown(MIN_STICKS)
        goHome()
    end
    walk(0, -1)
    for slot = FIRST_CARGO_SLOT, robot.inventorySize() do
        if robot.count(slot) > 0 then robot.select(slot); robot.dropDown() end
    end
    robot.select(1); goHome()
end

-- ==============================================================================
-- БЛОК 7: ОБРАБОТКА ЗАДАЧ
-- ==============================================================================
local function taskPlaceDouble(task_id, key)
    local x, z = key:match("(%d+),(%d+)")
    walk(tonumber(x), tonumber(z))
    if robot.count(1) < MIN_STICKS then refillSticks() end
    placeDoubleCrop()
    goHome()
end

local function taskDestroy(task_id, key)
    local x, z = key:match("(%d+),(%d+)")
    walk(tonumber(x), tonumber(z))
    swingAxe(); os.sleep(1.0)
    placeDoubleCrop()
    dropCargo()
end

local function taskClear(task_id, key)
    local x, z = key:match("(%d+),(%d+)")
    walk(tonumber(x), tonumber(z))
    swingAxe(); os.sleep(1.0)
    dropCargo()
end

local function taskWeed(task_id, key)
    local x, z = key:match("(%d+),(%d+)")
    walk(tonumber(x), tonumber(z))
    robot.useDown(); os.sleep(1.0)
    dropCargo()
end

local function taskEmergencyClear(task_id, key)
    local x, z = key:match("(%d+),(%d+)")
    walk(tonumber(x), tonumber(z))
    robot.select(1); robot.swingDown(); os.sleep(1.0)
    goHome()
end

local function taskReplaceTry(task_id, cross_key, weak_key)
    local my_empty_slots = {}
    for slot = 3, robot.inventorySize() do
        if inv.getStackInInternalSlot(slot) == nil then table.insert(my_empty_slots, slot) end
    end
    local cx, cz = cross_key:match("(%d+),(%d+)")
    if robot.count(3) > 0 then dropCargo() end
    walk(tonumber(cx), tonumber(cz))
    swingAxe(); os.sleep(1.5)
    
    state.my_best_seeds = {}
    for _, slot in ipairs(my_empty_slots) do
        local s = inv.getStackInInternalSlot(slot)
        if s and s.name == "ic2:crop_seed_bag" then table.insert(state.my_best_seeds, slot) end
    end
    placeDoubleCrop()
    modem.broadcast(PORT, "REPLACE_RESULT", task_id, cross_key, weak_key, #state.my_best_seeds)
    if #state.my_best_seeds == 0 then dropCargo() end
end

local function taskPlantMulti(task_id, coords_str)
    local coords = serialization.unserialize(coords_str)
    for i, coord in ipairs(coords) do
        local x, z = coord:match("(%d+),(%d+)")
        walk(tonumber(x), tonumber(z))
        local slot = state.my_best_seeds[i]
        if slot then
            robot.select(1); robot.placeDown()
            robot.select(slot); robot.placeDown()
            robot.select(1)
        end
    end
    state.my_best_seeds = {}
    dropCargo()
end

-- ==============================================================================
-- БЛОК 8: ПРОТОКОЛ
-- ==============================================================================
local function processCommand(task_id, action, key, arg2)
    if state.last_completed_task_id == task_id then return end
    
    if not state.is_ready and action ~= "EMERGENCY_CLEAR" then return end
    
    if action ~= "EMERGENCY_CLEAR" then
        local inv_ok, reason = quickInventoryCheck()
        if not inv_ok and reason == "NO_STICKS" then
            refillSticks()
            inv_ok, reason = quickInventoryCheck()
        end
        if not inv_ok then
            state.is_ready = false
            state.is_emergency = true
            modem.broadcast(PORT, "NOT_READY")
            term.clear(); print("PRE-TASK FAIL: " .. tostring(reason))
            return
        end
    end
    
    -- ШЛЕМ TAKEN
    modem.broadcast(PORT, "TAKEN", task_id)
    state.ready_sent = false -- Теперь мы не "готовы", мы работаем
    
    if action == "PLANT_MULTI" or action == "REPLACE_TRY" then
        cleanupBeforePlantMulti()
    end
    
    local success, err = pcall(function()
        if action == "PLACE_DOUBLE" then taskPlaceDouble(task_id, key)
        elseif action == "DESTROY" then taskDestroy(task_id, key)
        elseif action == "CLEAR" then taskClear(task_id, key)
        elseif action == "WEED" then taskWeed(task_id, key)
        elseif action == "REPLACE_TRY" then taskReplaceTry(task_id, key, arg2)
        elseif action == "PLANT_MULTI" then taskPlantMulti(task_id, key)
        elseif action == "EMERGENCY_CLEAR" then taskEmergencyClear(task_id, key)
        end
    end)
    
    if not success then modem.broadcast(PORT, "ALERT", "ERR:" .. tostring(err)) end
    
    state.last_completed_task_id = task_id
    state.pending_ack = { id = task_id, key = key } -- ACK отправит основной цикл
end

-- ==============================================================================
-- СТАРТ
-- ==============================================================================
term.clear()
setupTools()
emergencyGoHome()

-- Фоновый поток: только ALIVE
thread.create(function()
    while true do
        modem.broadcast(PORT, "ALIVE")
        os.sleep(10)
    end
end)

local last_diag_time = 0
local last_quick_check = 0

while true do
    -- 1. Статус (READY / NOT_READY)
    local at_base = (state.cur_x == 0 and state.cur_z == 0)
    local should_be_ready = at_base and state.is_ready and not state.pending_ack
    
    if should_be_ready then
        -- Пульс READY раз в 30 секунд
        if not state.ready_sent or (os.time() - state.last_ready_pulse > 30) then
            modem.broadcast(PORT, "READY")
            state.ready_sent = true
            state.not_ready_sent = false
            state.last_ready_pulse = os.time()
        end
    else
        state.ready_sent = false
    end
    
    -- Пульс NOT_READY раз в 30 секунд
    if at_base and state.is_emergency then
        if not state.not_ready_sent or (os.time() - state.last_ready_pulse > 30) then
            modem.broadcast(PORT, "NOT_READY")
            state.not_ready_sent = true
            state.ready_sent = false
            state.last_ready_pulse = os.time()
        end
    else
        state.not_ready_sent = false
    end

    -- 2. Диагностика
    if not state.is_ready then
        if os.time() - last_diag_time > 5 then
            local ok, reason = selfDiagnosis()
            if ok then
                state.is_ready = true; state.is_emergency = false
                term.clear(); print("READY")
            else
                state.is_emergency = true
                term.clear(); print("EMERGENCY: " .. tostring(reason))
            end
            last_diag_time = os.time()
        end
    else
        if os.time() - last_quick_check > 10 then
            local inv_ok, reason = quickInventoryCheck()
            if not inv_ok then
                state.is_ready = false; state.is_emergency = true
                term.clear(); print("IDLE CHECK FAIL: " .. reason)
            end
            last_quick_check = os.time()
        end
    end

    -- 3. Прием команд
    local ev = table.pack(event.pull(0.5, "modem_message"))
    if ev[1] == "modem_message" then
        local _, _, _, _, _, msg, id, action, key, arg2 = table.unpack(ev)
        if msg == "CMD" then
            processCommand(tonumber(id), action, key, arg2)
        end
    end

    -- 4. Отправка ACK (один раз!)
    if state.pending_ack then
        modem.broadcast(PORT, "ACK", state.pending_ack.id, state.pending_ack.key)
        state.pending_ack = nil
    end
end