local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")

local BASE_URL = "https://raw.githubusercontent.com/SerGamE/Breeding-robot-OC-IC2-computronics-MC1.12.2-/refs/heads/main/"

-- Все возможные файлы проекта
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

-- Определяем: это робот или сервер?
local is_robot = component.isAvailable("robot")

local files_to_install = {}

if is_robot then
    print("= ОБНАРУЖЕН РОБОТ =")
    -- Роботу нужен только его скрипт и конфиг (для порта и прочего)
    table.insert(files_to_install, { url = "robot.lua", path = ALL_FILES["robot.lua"] })
    table.insert(files_to_install, { url = "config.lua", path = ALL_FILES["config.lua"] })
else
    print("= ОБНАРУЖЕН СЕРВЕР =")
    -- Серверу нужен весь набор файлов, КРОМЕ робота
    for name, path in pairs(ALL_FILES) do
        if name ~= "robot.lua" then
            table.insert(files_to_install, { url = name, path = path })
        end
    end
    -- Сортируем для красоты вывода (по алфавиту)
    table.sort(files_to_install, function(a, b) return a.url < b.url end)
end

term.clear()
term.setCursor(1, 1)
print("= OC Auto Selector Installer/Deinstaller =")
print("Режим: " .. (is_robot and "РОБОТ" or "СЕРВЕР"))
print("Выберите действие:")
print("1. Установить / Переустановить (скачать свежие с GitHub)")
print("2. Деинсталлировать ")
print("0. Выход")
print("")

local choice = io.read()

if choice == "0" then
    print("Выход.")
    return
elseif choice == "2" then
    print("\n= УДАЛЕНИЕ =")
    local deleted_count = 0
    for _, file in ipairs(files_to_install) do
        if fs.exists(file.path) then
            fs.remove(file.path)
            print("Удален: " .. file.path)
            deleted_count = deleted_count + 1
        else
            print("Файл не найден (пропуск): " .. file.path)
        end
    end
    
    -- Удаляем автозапуск из .shrc (только для робота)
    if is_robot and fs.exists("/home/.shrc") then
        local f = fs.open("/home/.shrc", "r")
        local content = f:read("*a")
        f:close()
        local new_content = content:gsub("lua /home/r%.lua\r?\n?", "")
        if new_content ~= content then
            local f2 = fs.open("/home/.shrc", "w")
            f2:write(new_content)
            f2:close()
            print("Автозапуск из .shrc удален.")
        end
    end
    
    print("\nУдалено файлов: " .. deleted_count)
    return
elseif choice ~= "1" then
    print("Неверный выбор. Выход.")
    return
end

-- === РЕЖИМ УСТАНОВКИ / ПЕРЕУСТАНОВКИ ===
print("\n= УСТАНОВКА / ОБНОВЛЕНИЕ =")

if not component.isAvailable("internet") then
    print("[ОШИБКА] Интернет-карта не найдена!")
    return
end

local total = #files_to_install
local success_count = 0

for i, file in ipairs(files_to_install) do
    print(string.format("[%d/%d] Скачиваю %s ...", i, total, file.url))
    
    -- -f (force) перезаписывает файлы
    local command = string.format('wget -fq "%s%s" "%s"', BASE_URL, file.url, file.path)
    local ok, reason = shell.execute(command)
    
    if ok then
        print("  -> Успешно: " .. file.path)
        success_count = success_count + 1
    else
        print("  -> [ОШИБКА] " .. tostring(reason))
    end
end

print("\n= Установка завершена =")
print(string.format("Успешно скачано: %d из %d", success_count, total))

if success_count == total then
    print("\nВсе файлы обновлены.")
    
    -- Для робота предлагаем автозапуск
    if is_robot then
        print("\nНастроить автозапуск робота? (y/n)")
        local is_auto = io.read()
        if is_auto == "y" or is_auto == "Y" then
            local f = fs.open("/home/.shrc", "a")
            if f then
                local check_f = fs.open("/home/.shrc", "r")
                local content = check_f:read("*a")
                check_f:close()
                
                if not content:find("lua /home/r%.lua") then
                    f:write("\nlua /home/r.lua\n")
                    f:close()
                    print("Автозапуск добавлен в /home/.shrc")
                else
                    print("Автозапуск уже настроен.")
                end
            end
        end
    end
else
    print("\n[ВНИМАНИЕ] Некоторые файлы не скачались. Проверьте Интернет.")
end