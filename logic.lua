local scanner = require("scanner")
local logic = {}

function logic.checkPhase(state, CONFIG)
    local total_plants = 0
    local parents = 0
    local crosses = 0
    local target_parents = 0
    local total_parent_slots = 0
    local valid_crosses = 0
    
    -- Считаем общее кол-во родительских клеток и занятых target-родителей
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
    
    -- Считаем все растения crop_id на поле
    for k, d in pairs(state.scan_data) do
        if d.id == CONFIG.crop_id then
            total_plants = total_plants + 1
        end
    end

    -- Ищем валидные кресты (у которых 2+ соседа-родителя с crop_id)
    for k, st in pairs(state.cell_status) do
        if st == 2 then
            local par_count = 0
            for _, nk in ipairs(scanner.getNeighbors(state, CONFIG, k)) do
                par_count = par_count + 1
            end
            if par_count >= 2 then
                valid_crosses = valid_crosses + 1
            end
        end
    end
    
    -- 0 растений: INIT
    if total_plants == 0 then
        if state.phase ~= "INIT" then 
            state.phase = "INIT"
            return "INIT (ждем посадки)"
        end
        return nil
    end
    
    -- 1 растение: BREEDING
    if total_plants == 1 then
        if state.phase ~= "BREEDING" then 
            state.phase = "BREEDING"
            return "BREEDING (1 растение)"
        end
        return nil
    end
    
    -- 2+ растения
    if total_plants >= 2 then
        -- MUTATION: все родительские места заняты target-растениями
        if parents == total_parent_slots and target_parents == total_parent_slots then
            if state.phase ~= "MUTATION" then 
                state.phase = "MUTATION"
                return "MUTATION (все target)"
            end
            return nil
        end
        
        -- Если мы в MUTATION, но погибло >= min_dead_parents, выходим в SELECTION
        if state.phase == "MUTATION" then
            local dead_parents = total_parent_slots - parents
            if dead_parents >= CONFIG.min_dead_parents then
                state.phase = "SELECTION"
                return "SELECTION (погибло " .. dead_parents .. " родителей)"
            else
                return nil -- Остаемся в MUTATION, ждем восстановления
            end
        end
        
        -- SELECTION: если есть хотя бы 1 валидный крест (2+ соседа-родителя)
        if valid_crosses > 0 then
            if state.phase ~= "SELECTION" then 
                state.phase = "SELECTION"
                return "SELECTION (есть валидный крест)"
            end
            return nil
        end
        
        -- Иначе BREEDING (нужно размножение)
        if state.phase ~= "BREEDING" then 
            state.phase = "BREEDING"
            return "BREEDING (нужно размножение)"
        end
    end
    return nil
end

function logic.classify(c, parents, CONFIG)
    -- Проверка на превышение лимитов
    if c.g > CONFIG.target.g or c.ga > CONFIG.target.ga or c.r > CONFIG.target.r then 
        return "EXCESS" 
    end
    
    local weaker = true
    local better = false
    for _, p in ipairs(parents) do
        -- Ребенок лучше хотя бы одного родителя
        if (c.g >= p.g and c.ga >= p.ga and c.r >= p.r) and (c.g > p.g or c.ga > p.ga or c.r > p.r) then 
            better = true 
        end
        -- Ребенок не слабее этого родителя
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