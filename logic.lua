local scanner = require("scanner")
local map_manager = require("map_manager")
local logic = {}

function logic.checkPhase(state, CONFIG)
    local total_plants = 0
    local parents = 0
    local crosses = 0
    local target_parents = 0
    local total_parent_slots = 0
    local valid_crosses = 0
    
    for k, st in pairs(state.cell_status) do
        if st == 1 then
            total_parent_slots = total_parent_slots + 1
            local d = state.scan_data[k]
            if d and d.id == CONFIG.crop_id then
                parents = parents + 1
                if d.g >= CONFIG.target.g and d.ga >= CONFIG.target.ga and d.r >= CONFIG.target.r then
                    target_parents = target_parents + 1
                end
            end
        elseif st == 2 then
            crosses = crosses + 1
        end
    end
    
    for k, d in pairs(state.scan_data) do
        if d.id == CONFIG.crop_id then
            total_plants = total_plants + 1
        end
    end

    for k, st in pairs(state.cell_status) do
        if st == 2 then
            local par_count = 0
            for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                par_count = par_count + 1
            end
            if par_count >= 2 then valid_crosses = valid_crosses + 1 end
        end
    end
    
    if total_plants == 0 then
        if state.phase ~= "INIT" then state.phase = "INIT"; return "INIT (ждем посадки)" end
        return nil
    end
    
    if total_plants == 1 then
        -- Ищем единственное растение
        local solo_key = nil
        for k, d in pairs(state.scan_data) do
            if d.id and d.id ~= "" then solo_key = k; break end
        end
        
        if solo_key then
            local solo_data = state.scan_data[solo_key]
            local solo_status = state.cell_status[solo_key]
            
            -- Если это КРЕСТ с нашим crop_id -> ИНВЕРТИРУЕМ ШАХМАТКУ
            if solo_status == 2 and solo_data.id == CONFIG.crop_id then
                local new_status = {}
                for k, st in pairs(state.cell_status) do
                    if st == 1 then new_status[k] = 2
                    elseif st == 2 then new_status[k] = 1
                    else new_status[k] = st end
                end
                state.cell_status = new_status
                map_manager.save(state) -- Переписываем map.lua
                state.phase = "BREEDING"
                return "BREEDING (инверсия: крест -> родитель)"
            end
        end

        if state.phase ~= "BREEDING" then 
            state.phase = "BREEDING"
            return "BREEDING (1 растение)"
        end
        return nil
    end
    
    if total_plants >= 2 then
        if parents == total_parent_slots and target_parents == total_parent_slots then
            if state.phase ~= "MUTATION" then state.phase = "MUTATION"; return "MUTATION (все target)" end
            return nil
        end
        
        if state.phase == "MUTATION" then
            local dead_parents = total_parent_slots - parents
            if dead_parents >= CONFIG.min_dead_parents then
                state.phase = "SELECTION"
                return "SELECTION (погибло " .. dead_parents .. " родителей)"
            else
                return nil 
            end
        end
        
        if valid_crosses > 0 then
            if state.phase ~= "SELECTION" then state.phase = "SELECTION"; return "SELECTION (есть валидный крест)" end
            return nil
        end
        
        if state.phase ~= "BREEDING" then state.phase = "BREEDING"; return "BREEDING (нужно размножение)" end
    end
    return nil
end

function logic.classify(c, parents, CONFIG)
    -- Если достиг target — идеален, не WEAK
    if c.g >= CONFIG.target.g and c.ga >= CONFIG.target.ga and c.r >= CONFIG.target.r then 
        return "CANDIDATE" 
    end
    
    -- Проверка на превышение лимитов (EXCESS)
    if c.g > CONFIG.target.g or c.ga > CONFIG.target.ga or c.r > CONFIG.target.r then 
        return "EXCESS" 
    end
    
    local weaker = true
    local better = false
    for _, p in ipairs(parents) do
        if (c.g >= p.g and c.ga >= p.ga and c.r >= p.r) and (c.g > p.g or c.ga > p.ga or c.r > p.r) then 
            better = true 
        end
        if c.g >= p.g and c.ga >= p.ga and c.r >= p.r then 
            weaker = false 
        end
    end
    
    if weaker and #parents > 0 then return "WEAK" end
    if better then return "CANDIDATE" end
    return "WEAK"
end

function logic.isExcess(c, CONFIG)
    return (c.g > CONFIG.target.g) or (c.ga > CONFIG.target.ga) or (c.r > CONFIG.target.r)
end

return logic