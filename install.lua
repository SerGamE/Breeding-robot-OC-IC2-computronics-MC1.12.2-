local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")

-- Твой репозиторий на GitHub
local BASE_URL = "https://raw.githubusercontent.com/SerGamE/Breeding-robot-OC-IC2-computronics-MC1.12.2-/refs/heads/main/"

-- Список файлов для скачивания
local files = {
    { url = "SeedsDB.lua",       path = "/home/SeedsDB.lua" },
    { url = "config.lua",        path = "/home/config.lua" },
    { url = "logic.lua",         path = "/home/logic.lua" },
    { url = "map_manager.lua",   path = "/home/map_manager.lua" },
    { url = "mapping.lua",       path = "/home/mapping.lua" },
    { url = "robot.lua",         path = "/home/r.lua" },      -- ВАЖНО: переименовываем
    { url = "scanner.lua",       path = "/home/scanner.lua" },
    { url = "server.lua",        path = "/home/server.lua" },
    { url = "tasks.lua",         path = "/home/tasks.lua" },
    { url = "ui.lua",            path = "/home/ui.lua" }
}

term.clear()
print("=== OC Auto Selector Installer ===")
print("Репозиторий: " .. BASE_URL)

-- Проверка наличия Интернет-карты
if not component.isAvailable("internet") then
    print("\n[ОШИБКА] Интернет-карта не найдена!")
    print("Установите Интернет-карту в компьютер и перезапустите.")
    return
end

local total = #files
local success_count = 0

-- Проходим по списку файлов
for i, file in ipairs(files) do
    print(string.format("\n[%d/%d] Скачиваю %s ...", i, total, file.url))
    
    -- Формируем команду wget
    -- -f (force) - перезаписать, если файл уже есть
    -- -q (quiet) - без лишнего мусора в консоли
    local command = string.format('wget -fq "%s%s" "%s"', BASE_URL, file.url, file.path)
    
    -- Выполняем через shell.execute
    local ok, reason = shell.execute(command)
    
    if ok then
        print("  -> Успешно сохранено в " .. file.path)
        success_count = success_count + 1
    else
        print("  -> [ОШИБКА] Не удалось скачать: " .. tostring(reason))
    end
end

print("\n=== Установка завершена ===")
print(string.format("Скачано файлов: %d из %d", success_count, total))

if success_count == total then
    print("\nВсе файлы успешно обновлены!")
    
    -- Предложение настроить автозапуск
    print("\nНастроить автозапуск робота? (y/n)")
    local input = io.read()
    if input == "y" or input == "Y" then
        local f = fs.open("/home/.shrc", "a")
        if f then
            f:write("\nlua /home/r.lua\n")
            f:close()
            print("Автозапуск добавлен в /home/.shrc")
        else
            print("[ОШИБКА] Не удалось открыть .shrc")
        end
    end
else
    print("\n[ВНИМАНИЕ] Некоторые файлы не скачались. Проверьте подключение к интернету или правильность URL.")
end
