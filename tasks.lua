local scanner = require("scanner")
local logic = require("logic")
local tasks = {}

function tasks.getTask(state, CONFIG)
    -- 1. РЕЖИМЫ ОЧИСТКИ (EMERGENCY)
    if state.phase == "EMERGENCY" then
        for k, d in pairs(state.scan_data) do
            if d.g and d.g >= 24 and not state.locked[k] then return "EMERGENCY_CLEAR", k, "EMERG_G24" end
        end
        for k, d in pairs(state.scan_data) do
            if d.id == "weed" and state.cell_status[k] == 2 and not state.locked[k] then return "EMERGENCY_CLEAR", k, "EMERG_WEED" end
        end
        for k, d in pairs(state.scan_data) do
            if d.id == "weed" and state.cell_status[k] == 1 and not state.locked[k] then return "EMERGENCY_CLEAR", k, "EMERG_WEED_P" end
        end
        for k, d in pairs(state.scan_data) do
            if d.id == "" and state.cell_status[k] == 2 and not state.locked[k] then return "EMERGENCY_CLEAR", k, "EMERG_DBL" end
        end
        for k, d in pairs(state.scan_data) do
            if d.id == "" and state.cell_status[k] == 1 and not state.locked[k] then return "EMERGENCY_CLEAR", k, "EMERG_STICK_P" end
        end
        return nil
    end

    -- 2. РЕЖИМЫ PAUSE / SHUTDOWN
    if state.shutdown_mode or state.paused then
        for k, d in pairs(state.scan_data) do
            if d.id == "weed" and not state.locked[k] then return "WEED", k, "WEED" end
        end
        for k, d in pairs(state.scan_data) do
            if d.id == "" and not state.locked[k] then return "CLEAR", k, "CLEAR" end
        end
        return nil
    end
    
    -- 3. G24 (ГЛОБАЛЬНЫЙ ПРИОРИТЕТ)
    for k, d in pairs(state.scan_data) do
        if d.g and d.g >= 24 and not state.locked[k] then return "DESTROY", k, "G24" end
    end

    -- 4. СОРНЯКИ (штатные)
    for k, d in pairs(state.scan_data) do
        if d.id == "weed" and not state.locked[k] then
            return "WEED", k, (state.cell_status[k] == 1 and "CLEAR" or "WEED")
        end
    end
    
    if state.phase == "INIT" then return nil end
    
    -- 5. MUTATION: Сбор семян новых видов (только если выросли до максимума)
    if state.phase == "MUTATION" then
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and d.id ~= "" and d.id ~= "weed" and d.id ~= CONFIG.crop_id and not state.locked[k] then
                if d.sz >= d.max_stages then
                    return "DESTROY", k, "NEW_SEEDS"
                end
            end
        end
    end
    
    -- 6. ПУСТЫЕ DBL (без 2 зрелых предков)
    for k, st in pairs(state.cell_status) do
        if st == 2 and not state.locked[k] then
            local d = state.scan_data[k]
            if d and d.id == "" then
                local mature = 0
                for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                    if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id and state.scan_data[nk].sz >= state.scan_data[nk].max_stages then 
                        mature = mature + 1 
                    end
                end
                if mature < 2 then return "CLEAR", k, "CLEAR" end
            end
        end
    end
    
    -- 7. EXCESS (для всех крестов, включая новые виды)
    if state.phase == "SELECTION" or state.phase == "MUTATION" then
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and d.id ~= "" and d.id ~= "weed" and not state.locked[k] then
                if logic.isExcess(d, CONFIG) then
                    return "DESTROY", k, "EXCESS"
                end
            end
        end
    end
    
    -- 8. NEW (снос любых новых видов в SELECTION)
    if state.phase == "SELECTION" then
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and d.id ~= "" and d.id ~= "weed" and d.id ~= CONFIG.crop_id and not state.locked[k] then
                if CONFIG.new_species == "destroy" then return "DESTROY", k, "NEW" end
            end
        end
    end
    
    -- 9. WEAK (только для crop_id на крестах в SELECTION и MUTATION)
    if state.phase == "SELECTION" or state.phase == "MUTATION" then
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and d.id == CONFIG.crop_id and not state.locked[k] then
                local parents = {}
                for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                    if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id then table.insert(parents, state.scan_data[nk]) end
                end
                if logic.classify(d, parents, CONFIG) == "WEAK" then return "DESTROY", k, "WEAK" end
            end
        end
    end
    
    -- 10. MultiPlant
    if state.phase == "SELECTION" or state.phase == "MUTATION" then
        local need_replace = false
        for pk, st in pairs(state.cell_status) do
            if st == 1 then
                local pd = state.scan_data[pk]
                if not pd or pd.id ~= CONFIG.crop_id then need_replace = true; break end
                if pd.g < CONFIG.target.g or pd.ga < CONFIG.target.ga or pd.r < CONFIG.target.r then need_replace = true; break end
            end
        end
        
        if need_replace then
            -- ищем топ-крест и отдаем REPLACE_TRY
            for k, d in pairs(state.scan_data) do
                if state.cell_status[k] == 2 and d.id == CONFIG.crop_id and d.sz >= d.max_stages and not state.locked[k] then
                    local parents = {}
                    for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                        if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id then table.insert(parents, state.scan_data[nk]) end
                    end
                    if logic.classify(d, parents, CONFIG) == "CANDIDATE" then
                        -- ищем худшего родителя
                        local target = nil
                        local worst_score = 9999
                        for pk, st in pairs(state.cell_status) do
                            if st == 1 and not state.locked[pk] then
                                local pd = state.scan_data[pk]
                                local score = -1
                                if pd and pd.id == CONFIG.crop_id then score = (pd.g or 0) + (pd.ga or 0) + (pd.r or 0) end
                                if score < worst_score then worst_score = score; target = pk end
                            end
                        end
                        if target then return "REPLACE_TRY", k, target end
                    end
                end
            end
        else
            -- Все родители target. Ищем выросший крест с target для сноса
            for k, d in pairs(state.scan_data) do
                if state.cell_status[k] == 2 and d.id == CONFIG.crop_id and d.sz >= d.max_stages and not state.locked[k] then
                    if d.g >= CONFIG.target.g and d.ga >= CONFIG.target.ga and d.r >= CONFIG.target.r then
                        return "DESTROY", k, "TOP_SEEDS" 
                    end
                end
            end
        end
    end
    
    -- 11. УСТАНОВКА DBL
    if state.phase == "SELECTION" or state.phase == "BREEDING" or state.phase == "MUTATION" then
        for k, st in pairs(state.cell_status) do
            if st == 2 and not state.locked[k] then
                local d = state.scan_data[k]
                if not d then
                    local mature = 0
                    for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                        if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id and state.scan_data[nk].sz >= state.scan_data[nk].max_stages then 
                            mature = mature + 1 
                        end
                    end
                    if mature >= 2 then return "PLACE_DOUBLE", k, "PLACE_DBL" end
                end
            end
        end
    end
    
    return nil
end

return tasks