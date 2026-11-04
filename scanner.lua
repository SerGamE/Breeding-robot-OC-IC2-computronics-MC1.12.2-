local component = require("component")
local scanner = {}

local proxy_cache = {}

local function getProxy(uuid)
    if proxy_cache[uuid] then return proxy_cache[uuid] end
    local ok, p = pcall(component.proxy, uuid)
    if ok and p then
        proxy_cache[uuid] = p
        return p
    end
    return nil
end

function scanner.scan(state, CONFIG, CROP_DB, full_scan)
    state.max_parent = {g=0, ga=0, r=0}
    state.max_child  = {g=0, ga=0, r=0}
    
    local all_components = component.list()
    
    for key, uuid in pairs(state.crop_matrix) do
        if all_components[uuid] then
            local proxy = getProxy(uuid)
            if proxy then
                local ok_id, id = pcall(proxy.getID)
                if ok_id and id and id ~= "" then
                    -- 1. ЧИТАЕМ ГЕНЫ (ВСЕГДА)
                    local g, ga, r
                    local ok_g, res_g = pcall(proxy.getGrowth); if ok_g then g = res_g end
                    local ok_ga, res_ga = pcall(proxy.getGain); if ok_ga then ga = res_ga end
                    local ok_r, res_r = pcall(proxy.getResistance); if ok_r then r = res_r end
                    
                    -- 2. ЧИТАЕМ РАЗМЕР И GP (ТОЛЬКО ПРИ ПОЛНОМ СКАНЕ)
                    local sz, gp
                    local old_data = state.scan_data[key]
                    
                    if full_scan or not old_data then
                        local ok_sz, res_sz = pcall(proxy.getCurrentSize); if ok_sz then sz = res_sz end
                        local ok_gp, res_gp = pcall(proxy.getGrowthPoints); if ok_gp then gp = res_gp end
                    else
                        -- Берем старые данные, если это быстрый скан
                        sz = old_data.sz
                        gp = old_data.gp
                    end
                    
                    local db_stages = CROP_DB[id] and CROP_DB[id].stages or 7
                    local current_sz = sz or 0
                    
                    -- 3. ОБНОВЛЯЕМ СУЩЕСТВУЮЩУЮ ТАБЛИЦУ (чтобы не создавать мусор)
                    if not old_data or old_data.id ~= id then
                        -- Если растение появилось впервые или изменился вид - создаем новую таблицу
                        old_data = { id = id }
                        state.scan_data[key] = old_data
                    end
                    
                    old_data.g = g or 0
                    old_data.ga = ga or 0
                    old_data.r = r or 0
                    old_data.sz = current_sz
                    old_data.gp = gp or 0
                    old_data.max_stages = db_stages
                    
                    -- 4. ОБНОВЛЯЕМ СТРОКИ ДЛЯ ОТРИСОВКИ (только если изменились)
                    local new_stats = string.format("%d/%d/%d", g or 0, ga or 0, r or 0)
                    if old_data.stats ~= new_stats then old_data.stats = new_stats end
                    
                    local new_stage = string.format("%d/%d", current_sz, db_stages)
                    if old_data.stage ~= new_stage then old_data.stage = new_stage end
                    
                    -- 5. СЧИТАЕМ МАКСИМУМЫ
                    if id == CONFIG.crop_id then
                        local safe_g, safe_ga, safe_r = g or 0, ga or 0, r or 0
                        local st = state.cell_status[key]
                        if st == 1 then
                            if safe_g > state.max_parent.g then state.max_parent.g = safe_g end
                            if safe_ga > state.max_parent.ga then state.max_parent.ga = safe_ga end
                            if safe_r > state.max_parent.r then state.max_parent.r = safe_r end
                        elseif st == 2 then
                            if safe_g > state.max_child.g then state.max_child.g = safe_g end
                            if safe_ga > state.max_child.ga then state.max_child.ga = safe_ga end
                            if safe_r > state.max_child.r then state.max_child.r = safe_r end
                        end
                    end
                else
                    -- Пустой компонент (нет растения)
                    if not state.scan_data[key] or state.scan_data[key].id ~= "" then
                        state.scan_data[key] = { id = "", stats = "", stage = "", gp = "" }
                    end
                end
            end
        else
            state.scan_data[key] = nil
        end
    end
end

function scanner.getNeighbors(state, CONFIG, key)
    local x, z = key:match("(%d+),(%d+)")
    local n = {}
    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local k = string.format("%d,%d", tonumber(x)+d[1], tonumber(z)+d[2])
        if state.cell_status[k] == 1 then
            local d_data = state.scan_data[k]
            if d_data and d_data.id == CONFIG.crop_id then
                n[#n+1] = k
            end
        end
    end
    return n
end

return scanner