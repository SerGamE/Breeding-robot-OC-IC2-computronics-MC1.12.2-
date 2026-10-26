-- ==============================================================================
-- MAPPING MODULE (Autonomous)
-- ==============================================================================
local computer = require("computer")
local component = require("component")
local event     = require("event")
local serialization = require("serialization")
local fs        = require("filesystem")

local mapping = {}
local PORT = 109
local MAP_FILE = "/home/map.lua"
local WAKE_MSG = "WAKE_UP_MAN"

-- ==============================================================================
-- Вспомогательные функции
-- ==============================================================================
function mapping.getNewCropUUID(crop_matrix)
    for addr, typ in component.list() do
        if typ == "ic2_crops" then
            local used = false
            for _, u in pairs(crop_matrix) do 
                if u == addr then used = true break end 
            end
            if not used then return addr end
        end
    end
end

-- Загрузка карты (возвращает данные или nil)
function mapping.load()
    if not fs.exists(MAP_FILE) then return nil end
    package.loaded["map"] = nil
    local ok, data = pcall(require, "map")
    if ok and type(data) == "table" then 
        return data 
    end
    return nil
end

-- Сохранение карты
function mapping.save(crop_matrix, tech_zone, parent_set, cross_set)
    local map_data = {}
    for k, v in pairs(crop_matrix) do
        local x, z = k:match("(%d+),(%d+)")
        local status = 0
        if tech_zone[k] then status = 3
        elseif parent_set[k] then status = 1
        elseif cross_set[k] then status = 2 end
        map_data[{tonumber(x), tonumber(z)}] = { uuid = v, status = status }
    end

    local f = fs.open(MAP_FILE, "w")
    if f then
        f:write("return " .. serialization.serialize(map_data))
        f:close()
        print("[Mapping] Карта сохранена в " .. MAP_FILE)
    end
end

-- Функция разбивки шахматки
function mapping.chooseParents(crop_matrix, tech_zone)
    local parent_set = {}; local cross_set = {}
    local live = {}
    for key in pairs(crop_matrix) do 
        if not tech_zone[key] then live[#live+1] = key end 
    end
    
    table.sort(live, function(a, b)
        local ax, az = a:match("(%d+),(%d+)")
        local bx, bz = b:match("(%d+),(%d+)")
        if ax ~= bx then return tonumber(ax) < tonumber(bx) end
        return tonumber(az) < tonumber(bz)
    end)
    
    -- 1. Назначаем родителей (чётные)
    for _, key in ipairs(live) do
        local x, z = key:match("(%d+),(%d+)")
        if (tonumber(x) + tonumber(z)) % 2 == 0 then
            parent_set[key] = true
        end
    end
    
    -- 2. Назначаем кресты (нечётные)
    local function neighbors(key)
        local x, z = key:match("(%d+),(%d+)")
        x, z = tonumber(x), tonumber(z)
        local n = {}
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local k = string.format("%d,%d", x+d[1], z+d[2])
            if crop_matrix[k] and not tech_zone[k] then n[#n+1] = k end
        end
        return n
    end

    for _, key in ipairs(live) do
        local x, z = key:match("(%d+),(%d+)")
        if (tonumber(x) + tonumber(z)) % 2 ~= 0 then
            local par = 0
            for _, nk in ipairs(neighbors(key)) do 
                if parent_set[nk] then par = par + 1 end 
            end
            if par >= 2 then 
                cross_set[key] = true 
            else 
                tech_zone[key] = true 
            end
        end
    end
    
    return parent_set, cross_set
end

-- Основная функция запуска картографии
function mapping.run(field_x, field_z, modem)
    print("[Mapping] Старт картографии...")
    local crop_matrix = {}
    local tech_zone = {}

    -- 1. Будим робота
    print("[Mapping] Бужу робота и жду READY...")
    modem.broadcast(PORT, WAKE_MSG)
    
    -- 2. Ждем READY от робота (с таймаутом)
    local ready_received = false
    local timeout = 60
    local start_time = computer.uptime() -- ИСПОЛЬЗУЕМ computer.uptime()
    
    while not ready_received do
        if computer.uptime() - start_time > timeout then
            print("[Mapping] ОШИБКА: Робот не прислал READY за " .. timeout .. " секунд.")
            return nil, nil, nil, nil
        end
        
        local ev = table.pack(event.pull(1, "modem_message"))
        if ev[1] == "modem_message" then
            local _, _, _, _, _, msg = table.unpack(ev)
            if msg == "READY" then
                ready_received = true
                print("[Mapping] Робот готов! Начинаю змейку.")
            end
        end
    end
    
    -- Небольшая пауза, чтобы робот точно встал на базу
    os.sleep(1)
    
    -- 3. Гоним змейкой
    modem.broadcast(PORT, "START_MAPPING", field_x, field_z)
    
    local done = false
    while not done do
        local ev = table.pack(event.pull(2, "modem_message"))
        if ev[1] == "modem_message" then
            local _, _, _, _, _, msg, a, b = table.unpack(ev)
            
            if msg == "CALIB_CHECK" then
                local key = string.format("%d,%d", a, b)
                local uuid = mapping.getNewCropUUID(crop_matrix)
                if uuid then
                    crop_matrix[key] = uuid
                    modem.broadcast(PORT, "SERVER_OK")
                    print("[Mapping] Связано: " .. key)
                else
                    tech_zone[key] = true
                    modem.broadcast(PORT, "SERVER_TECH")
                    print("[Mapping] Техзона: " .. key)
                end
                
            elseif msg == "CALIB_TECH" then
                local key = string.format("%d,%d", a, b)
                tech_zone[key] = true
                modem.broadcast(PORT, "SERVER_TECH")
                print("[Mapping] Техзона: " .. key)
                
            elseif msg == "CALIB_DONE" then
                done = true
            end
        end
    end

    -- 4. Разбиваем шахматку
    print("[Mapping] Разбивка шахматки...")
    local parent_set, cross_set = mapping.chooseParents(crop_matrix, tech_zone)
    
    -- 5. Сохраняем
    mapping.save(crop_matrix, tech_zone, parent_set, cross_set)
    
    return crop_matrix, tech_zone, parent_set, cross_set
end

-- ==============================================================================
-- Если модуль запущен напрямую (не через require)
-- ==============================================================================
if not package.loaded["mapping"] then
    local modem = component.modem
    modem.open(PORT)
    
    local field_x = 5
    local field_z = 5
    
    print("Запуск ручной картографии поля " .. field_x .. "x" .. field_z)
    mapping.run(field_x, field_z, modem)
    print("Готово!")
end

return mapping