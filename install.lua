local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")

local BASE_URL = "https://raw.githubusercontent.com/SerGamE/Breeding-robot-OC-IC2-computronics-MC1.12.2-/refs/heads/main/"

-- Список файлов для управления
local files = {
    { url = "SeedsDB.lua",       path = "/home/SeedsDB.lua" },
    { url = "config.lua",        path = "/home/config.lua" },
    { url = "logic.lua",         path = "/home/logic.lua" },
    { url = "map_manager.lua",   path = "/home/map_manager.lua" },
    { url = "mapping.lua",       path = "/home/mapping.lua" },
    { url = "robot.lua",         path = "/home/r.lua" },      -- Переименовываем при установке
    { url = "scanner.lua",       path = "/home/scanner.lua" },
    { url = "server.lua",        path = "/home/server.lua" },
    { url = "tasks.lua",         path = "/home/tasks.lua" },
    { url = "ui.lua",            path = "/home/ui.lua" }
}

term.clear()
term.setCursor(1, 1)
print("=== OC Auto Selector Installer/Deinstaller ===")
print("Выберите действие:")
print("1. Установить / Переустановить (скачать свежие с GitHub)")
print("2. Удалить (снести все файлы мода)")
print("0. Выход")
print("")

local choice = io.read()

if choice == "0" then
    print("Выход.")
    return
elseif choice == "2" then
    print("\n=== УДАЛЕНИЕ ===")
    local deleted_count = 0
    for i, file in ipairs(files) do
        if fs.exists(file.path) then
            fs.remove(file.path)
            print("Удален: " .. file.path)
            deleted_count = deleted_count + 1
        else
            print("Файл не найден (пропуск): " .. file.path)
        end
    end
    
    -- Удаляем автозапуск из .shrc
    if fs.exists("/home/.shrc") then
        local f = fs.open("/home/.shrc", "r")
        local content = f:read("*a")
        f:close()
        -- Удаляем строку с запуском робота, если она есть
        local new_content = content:gsub("lua /home/r%.lua\r?\n?", "")
        if new_content ~= content then
            local f2 = fs.open("/home/.shrc", "w")
            f2:write(new_content)
            f2:close()
            print("Автозапуск из .shrc удален.")
        end
    end
    
    print("\nУдалено файлов: " .. deleted_count)
    print("Карта (map.lua) и настройки (tools.lua) не тронуты.")
    return
elseif choice ~= "1" then
    print("Неверный выбор. Выход.")
    return
end

-- === РЕЖИМ УСТАНОВКИ / ПЕРЕУСТАНОВКИ ===
print("\n=== УСТАНОВКА / ОБНОВЛЕНИЕ ===")

if not component.isAvailable("internet") then
    print("[ОШИБКА] Интернет-карта не найдена!")
    return
end

local total = #files
local success_count = 0

for i, file in ipairs(files) do
    print(string.format("[%d/%d] Скачиваю %s ...", i, total, file.url))
    
    -- -f (force) перезаписывает файлы, если они есть
    local command = string.format('wget -fq "%s%s" "%s"', BASE_URL, file.url, file.path)
    local ok, reason = shell.execute(command)
    
    if ok then
        print("  -> Успешно: " .. file.path)
        success_count = success_count + 1
    else
        print("  -> [ОШИБКА] " .. tostring(reason))
    end
end

print("\n=== Установка завершена ===")
print(string.format("Успешно скачано: %d из %d", success_count, total))

if success_count == total then
    print("\nВсе файлы обновлены. Карта (map.lua) не тронута.")
    
    -- Для робота предлагаем автозапуск
    print("\nВы настраиваете РОБОТА? (y/n)")
    local is_robot = io.read()
    if is_robot == "y" or is_robot == "Y" then
        local f = fs.open("/home/.shrc", "a")
        if f then
            -- Проверяем, нет ли уже автозапуска, чтобы не дублировать
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
else
    print("\n[ВНИМАНИЕ] Некоторые файлы не скачались. Проверьте Интернет.")
end
