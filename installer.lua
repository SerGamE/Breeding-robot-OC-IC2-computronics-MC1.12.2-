local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")

local BASE_URL = "https://raw.githubusercontent.com/SerGamE/Breeding-robot-OC-IC2-computronics-MC1.12.2-/refs/heads/main/"

local ALL_FILES = {
    ["SeedsDB.lua"]     = "/home/SeedsDB.lua",
    ["config.lua"]      = "/home/config.lua",
    ["logic.lua"]       = "/home/logic.lua",
    ["map_manager.lua"] = "/home/map_manager.lua",
    ["mapping.lua"]     = "/home/mapping.lua",
    ["robot.lua"]       = "/home/r.lua",
    ["scanner.lua"]     = "/home/scanner.lua",
    ["server.lua"]      = "/home/server.lua",
    ["tasks.lua"]       = "/home/tasks.lua",
    ["ui.lua"]          = "/home/ui.lua"
}

local is_robot = component.isAvailable("robot")
local files_to_install = {}

if is_robot then
    print("=== ОБНАРУЖЕН РОБОТ ===")
    table.insert(files_to_install, { url = "robot.lua", path = ALL_FILES["robot.lua"] })
    table.insert(files_to_install, { url = "config.lua", path = ALL_FILES["config.lua"] })
else
    print("=== ОБНАРУЖЕН СЕРВЕР ===")
    for name, path in pairs(ALL_FILES) do
        if name ~= "robot.lua" then
            table.insert(files_to_install, { url = name, path = path })
        end
    end
    table.sort(files_to_install, function(a, b) return a.url < b.url end)
end

term.clear()
term.setCursor(1, 1)
print("=== OC Auto Selector Installer/Deinstaller ===")
print("Режим: " .. (is_robot and "РОБОТ" or "СЕРВЕР"))
print("1. Установить / Переустановить")
print("2. Удалить")
print("0. Выход")
print("")

local choice = io.read()

if choice == "0" then
    return
elseif choice == "2" then
    print("\n=== УДАЛЕНИЕ ===")
    for _, file in ipairs(files_to_install) do
        if fs.exists(file.path) then
            fs.remove(file.path)
            print("Удален: " .. file.path)
        end
    end
    
    -- Безопасное удаление из .shrc
    if is_robot and fs.exists("/home/.shrc") then
        local f = fs.open("/home/.shrc", "r")
        local content = f:read("*a")
        f:close()
        local new_content = content:gsub("lua /home/r%.lua\r?\n?", "")
        if new_content ~= content then
            local f2 = fs.open("/home/.shrc", "w")
            f2:write(new_content)
            f2:close()
            print("Автозапуск удален.")
        end
    end
    return
elseif choice ~= "1" then
    return
end

print("\n=== УСТАНОВКА ===")

if not component.isAvailable("internet") then
    print("[ОШИБКА] Нет Интернет-карты!")
    return
end

for i, file in ipairs(files_to_install) do
    print(string.format("[%d/%d] %s", i, #files_to_install, file.url))
    local command = string.format('wget -fq "%s%s" "%s"', BASE_URL, file.url, file.path)
    shell.execute(command)
end

print("\nУстановка завершена.")

-- === БЕЗОПАСНЫЙ АВТОЗАПУСК ===
if is_robot then
    print("\nНастроить автозапуск? (y/n)")
    if io.read() == "y" then
        local shrc_path = "/home/.shrc"
        local content = ""
        
        -- Читаем существующий файл, если он есть
        if fs.exists(shrc_path) then
            local f = fs.open(shrc_path, "r")
            content = f:read("*a")
            f:close()
        end
        
        -- Если автозапуска еще нет — добавляем
        if not content:find("lua /home/r%.lua") then
            content = content .. "\nlua /home/r.lua\n"
            local f = fs.open(shrc_path, "w")
            if f then
                f:write(content)
                f:close()
                print("Автозапуск добавлен в .shrc")
            else
                print("[ОШИБКА] Не удалось записать .shrc")
            end
        else
            print("Автозапуск уже есть.")
        end
    end
end