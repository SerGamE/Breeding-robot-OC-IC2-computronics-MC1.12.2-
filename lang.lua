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
    
    -- Фазы
    phase_msg_init = "ИНИТ (ждем посадки)",
    phase_msg_breeding_1 = "РАЗМНОЖЕНИЕ (1 растение)",
    phase_msg_mutation = "МУТАЦИЯ (все target)",
    phase_msg_selection_dead = "СЕЛЕКЦИЯ (погибло %d родителей)",
    phase_msg_selection = "СЕЛЕКЦИЯ (есть валидный крест)",
    phase_msg_breeding = "РАЗМНОЖЕНИЕ (нужно размножение)",

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
    -- Header
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
    --phase
    phase_msg_init = "INIT (waiting for plant)",
    phase_msg_breeding_1 = "BREEDING (1 plant)",
    phase_msg_mutation = "MUTATION (all target)",
    phase_msg_selection_dead = "SELECTION (%d parents died)",
    phase_msg_selection = "SELECTION (valid cross exists)",
    phase_msg_breeding = "BREEDING (need breeding)",

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

lang.Ja = {
    --Header
    header = "=== サーバー | %s | %s ===",
    phase_init = "初期化",
    phase_breeding = "繁殖",
    phase_selection = "選抜",
    phase_mutation = "突然変異",
    phase_emergency = "緊急",
    phase_pause = "一時停止",
    status_busy = "実行中",
    status_idle = "待機中",
    stats = "目標: %d/%d/%d | 最大親: %d/%d/%d | 最大子: %d/%d/%d",
    chat_title = "--- チャット ---",
    --phase
    phase_msg_init = "初期化（植え付け待ち）",
    phase_msg_breeding_1 = "繁殖（植物1つ）",
    phase_msg_mutation = "突然変異（すべて目標）",
    phase_msg_selection_dead = "選抜（親が%d匹死亡）",
    phase_msg_selection = "選抜（有効な交配あり）",
    phase_msg_breeding = "繁殖（繁殖が必要）",
    
    -- Field statuses
    dbl = "#",
    empty = "空",
    tech = "[技術]",

    -- Task statuses
    st_weak = "弱い",
    st_excess = "過剰",
    st_new = "新種",
    st_clear = "除去",
    st_weed = "雑草",
    st_g24 = "G24",
    st_place_dbl = "棒",
    st_multi = "移植",
    st_new_seeds = "新種の種",
    st_top_seeds = "最高の種",
    st_emerg = "緊急",

    -- Logs
    log_loaded = "ロード完了: %d 親, %d 交配, %d 技術",
    log_err_map = "エラー: マップが見つかりません！",
    log_search = "ロボットを探しています...",
    log_ready = "準備完了。ロボットを待っています。",
    log_pause_on = "一時停止 オン",
    log_pause_off = "一時停止 オフ",
    log_shutdown = "シャットダウン: クリーンアップを開始...",
    log_field_clean = "フィールドはきれいです。終了します...",
    log_emerg_on = "緊急事態！ロボットの修理が必要です。",
    log_emerg_off = "緊急事態解除（ロボット修理完了）",
    log_timeout = "ロボットが見つかりません。タスクをキャンセルします。",
    log_repeat = "リピート #%d",
    log_phase = "フェーズ -> %s",
    log_task = "%s #%d -> %s",
    log_invert = "マップが反転されました！",
    log_alert = "エラー: %s",
}

return lang