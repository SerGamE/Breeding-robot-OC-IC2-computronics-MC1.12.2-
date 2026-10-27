local scanner = require("scanner")
local logic = require("logic")
local tasks = {}

function tasks.getTask(state, CONFIG)
    -- 1. РЕЖИМЫ ОЧИСТКИ (EMERGENCY)
    if state.phase == "EMERGENCY" then
        -- Приоритет 1: Growth >= 24 (любые)
        for k, d in pairs(state.scan_data) do
            if d.g and d.g >= 24 and not state.locked[k] then
                return "EMERGENCY_CLEAR", k, "EMERG_G24"
            end
        end
        -- Приоритет 2: Сорняки на крестах
        for k, d in pairs(state.scan_data) do
            if d.id == "weed" and state.cell_status[k] == 2 and not state.locked[k] then
                return "EMERGENCY_CLEAR", k, "EMERG_WEED"
            end
        end
        -- Приоритет 3: Сорняки на родителях
        for k, d in pairs(state.scan_data) do
            if d.id == "weed" and state.cell_status[k] == 1 and not state.locked[k] then
                return "EMERGENCY_CLEAR", k, "EMERG_WEED_P"
            end
        end
        -- Приоритет 4: DBL (двойные жердочки) на крестах
        for k, d in pairs(state.scan_data) do
            if d.id == "" and state.cell_status[k] == 2 and not state.locked[k] then
                return "EMERGENCY_CLEAR", k, "EMERG_DBL"
            end
        end
        -- Приоритет 5: Жердочки на родителях (пустые)
        for k, d in pairs(state.scan_data) do
            if d.id == "" and state.cell_status[k] == 1 and not state.locked[k] then
                return "EMERGENCY_CLEAR", k, "EMERG_STICK_P"
            end
        end
        return nil
    end

    -- 2. РЕЖИМЫ PAUSE / SHUTDOWN
    if state.shutdown_mode or state.paused then
        for k, d in pairs(state.scan_data) do
            if d.id == "weed" and not state.locked[k] then 
                return "WEED", k, "WEED" 
            end
        end
        for k, d in pairs(state.scan_data) do
            if d.id == "" and not state.locked[k] then 
                return "CLEAR", k, "CLEAR" 
            end
        end
        return nil
    end
    
    -- 3. СОРНЯКИ (штатные)
    for k, d in pairs(state.scan_data) do
        if d.id == "weed" and not state.locked[k] then
            return "WEED", k, (state.cell_status[k] == 1 and "CLEAR" or "WEED")
        end
    end
    
    if state.phase == "INIT" then return nil end
    
    -- 4. ПУСТЫЕ DBL (без 2 зрелых предков)
    for k, d in pairs(state.scan_data) do
        if state.cell_status[k] == 2 and d.id == "" and not state.locked[k] then
            local mature = 0
            for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id and state.scan_data[nk].sz >= state.scan_data[nk].max_stages then 
                    mature = mature + 1 
                end
            end
            if mature < 2 then return "CLEAR", k, "CLEAR" end
        end
    end
    
    -- 5. УНИЧТОЖЕНИЕ (WEAK, EXCESS, NEW)
    if state.phase == "SELECTION" or state.phase == "MUTATION" then
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and d.id ~= "" and d.id ~= "weed" and not state.locked[k] then
                if d.id ~= CONFIG.crop_id then
                    if CONFIG.new_species == "destroy" then return "DESTROY", k, "NEW" end
                else
                    local parents = {}
                    for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                        if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id then 
                            table.insert(parents, state.scan_data[nk]) 
                        end
                    end
                    local cls = logic.classify(d, parents, CONFIG)
                    if cls == "EXCESS" then return "DESTROY", k, "EXCESS" end
                    if cls == "WEAK" then return "DESTROY", k, "WEAK" end
                end
            end
        end
        
        -- 6. ЗАМЕНА (REPLACE)
        -- (этот блок не трогаем, оставляем как было для будущих тестов)
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and d.id == CONFIG.crop_id and d.sz >= d.max_stages and not state.locked[k] then
                local parents = {}
                for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                    if state.cell_status[nk] == 1 and state.scan_data[nk] and state.scan_data[nk].id == CONFIG.crop_id then 
                        table.insert(parents, state.scan_data[nk]) 
                    end
                end
                if logic.classify(d, parents, CONFIG) == "CANDIDATE" then
                    local target = nil
                    for pk, pd in pairs(state.scan_data) do
                        if state.cell_status[pk] == 1 and not state.locked[pk] then
                            if not pd or pd.id ~= CONFIG.crop_id then target = pk; break end
                        end
                    end
                    if not target then
                        local worst = 999
                        for pk, pd in pairs(state.scan_data) do
                            if state.cell_status[pk] == 1 and pd.id == CONFIG.crop_id and not state.locked[pk] then
                                local score = pd.g + pd.ga + pd.r
                                if score < worst then worst = score; target = pk end
                            end
                        end
                    end
                    if target then return "REPLACE_TRY", k, target end
                end
            end
        end
    end
    
    -- 7. УСТАНОВКА DBL
    if state.phase == "SELECTION" or state.phase == "BREEDING" then
        for k, d in pairs(state.scan_data) do
            if state.cell_status[k] == 2 and not d and not state.locked[k] then
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
    
    return nil
end

return tasks