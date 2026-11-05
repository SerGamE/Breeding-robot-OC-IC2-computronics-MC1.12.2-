local lang = {}

lang.Ru = {
    -- Шапка
    header = "=== Сервер | %s | %s ===",
    phase_init = "ИНИТ",
    phase_breeding = "РАЗМНОЖЕНИЕ",
    phase_selection = "СЕЛЕКЦИЯ",
    phase_mutation = "МУТАЦИЯ",
    phase_emergency = "АВАРИЯ",
    phase_pause = "ПАУЗА",
    status_busy = "ЗАНЯТ",
    status_idle = "ЖДЕТ",
    stats = "Цель: %d/%d/%d | МаксРод: %d/%d/%d | МаксДет: %d/%d/%d",
    chat_title = "--- ЧАТ ---",

    -- Статусы на поле
    dbl = "#",
    empty = "пусто",
    tech = "[ТЕХ]",

    -- Статусы задач
    st_weak = "СЛАБЫЙ",
    st_excess = "ЭКСЦЕСС",
    st_new = "НОВЫЙ",
    st_clear = "ОЧИСТКА",
    st_weed = "СОРНЯК",
    st_g24 = "G24",
    st_place_dbl = "ЖЕРД",
    st_multi = "ПЕРЕСАДКА",
    st_new_seeds = "НОВЫЕ СЕМЕНА",
    st_top_seeds = "ТОП СЕМЕНА",
    st_emerg = "АВАРИЯ",

    -- Логи
    log_loaded = "Загружено: %d род, %d кр, %d тех.",
    log_err_map = "Ошибка: карта не найдена!",
    log_search = "Поиск робота...",
    log_ready = "Готов. Жду готовность робота.",
    log_pause_on = "ПАУЗА ВКЛ",
    log_pause_off = "ПАУЗА ВЫКЛ",
    log_shutdown = "ВЫКЛЮЧЕНИЕ: Начинаю очистку.",
    log_field_clean = "Поле чистое. Завершаю работу.",
    log_emerg_on = "АВАРИЯ! Робот требует ремонта.",
    log_emerg_off = "АВАРИЯ ВЫКЛ (робот починился)",
    log_timeout = "Робот пропал. Отменяю задачу.",
    log_repeat = "Повтор #%d",
    log_phase = "Фаза -> %s",
    log_task = "%s #%d -> %s", -- статус, id, ключ
    log_invert = "Поле инвертированно!",
    log_alert = "ОШИБКА: %s",
}

lang.En = {
    -- Head
    header = "=== Server | %s | %s ===",
    phase_init = "INIT",
    phase_breeding = "BREEDING",
    phase_selection = "SELECTION",
    phase_mutation = "MUTATION",
    phase_emergency = "EMERGENCY",
    phase_pause = "PAUSE",
    status_busy = "BUSY",
    status_idle = "IDLE",
    stats = "Target: %d/%d/%d | MaxPar: %d/%d/%d | MaxCh: %d/%d/%d",
    chat_title = "--- CHAT ---",

    -- Field statuses
    dbl = "#",
    empty = "empty",
    tech = "[TECH]",

    -- Task statuses
    st_weak = "WEAK",
    st_excess = "EXCESS",
    st_new = "NEW",
    st_clear = "CLEAR",
    st_weed = "WEED",
    st_g24 = "G24",
    st_place_dbl = "DBL",
    st_multi = "MULTI",
    st_new_seeds = "NEW SEEDS",
    st_top_seeds = "TOP SEEDS",
    st_emerg = "EMERG",

    -- Logs
    log_loaded = "Loaded: %d par, %d cr, %d tech.",
    log_err_map = "Error: map not found!",
    log_search = "Searching robot...",
    log_ready = "Ready. Waiting for robot.",
    log_pause_on = "PAUSE ON",
    log_pause_off = "PAUSE OFF",
    log_shutdown = "SHUTDOWN: Starting cleanup...",
    log_field_clean = "Field is clean. Shutting down...",
    log_emerg_on = "EMERGENCY! Robot needs repair.",
    log_emerg_off = "EMERGENCY OFF (robot fixed)",
    log_timeout = "Robot lost. Cancelling task.",
    log_repeat = "Repeat #%d",
    log_phase = "Phase -> %s",
    log_task = "%s #%d -> %s",
    log_invert = "MAP INVERTED!",
    log_alert = "ERROR: %s",
}

return lang