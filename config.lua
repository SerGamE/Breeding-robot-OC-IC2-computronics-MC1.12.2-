return {
    --для ic2 experemental max_growth = 24, для classic nil или 0 чтобы отключить
    max_growth = 24, -- Порог гена Growth, выше которого растение сносится 
    --размеры поля
    field_x = 6,
    field_z = 6,
    --культура которую робот будет скрещивать
    crop_id = "stickreed",
    -- статы до которых будем качать семена
    target = { g = 21, ga = 31, r = 0 },
    -- сохранять новые виды в режиме SELECTION
    new_species = "destroy", --заменить на save чтоб сохранять новые виды в режиме SELECTION
    --системные настройки
    answer_timeout = 40,
    boot_timeout = 180,
    wake_message = "WAKE_UP_MAN",
    port = 109,
    min_dead_parents = 4, -- порог смертей родителей при котором режим MUTATION выключается 
}
