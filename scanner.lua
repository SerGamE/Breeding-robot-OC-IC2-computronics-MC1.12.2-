local component = require("component")

local scanner = {}

function scanner.scan(state, CONFIG, CROP_DB)
    state.max_parent = {g=0, ga=0, r=0}
    state.max_child  = {g=0, ga=0, r=0}
    
    for key, uuid in pairs(state.crop_matrix) do
        local ok_comp = component.list()[uuid]
        local p, id, g, ga, r, sz, gp
        
        if ok_comp then
            local ok_proxy, proxy = pcall(component.proxy, uuid)
            if ok_proxy and proxy then
                local ok_id, res_id = pcall(proxy.getID)
                if ok_id then id = res_id end
                if id and id ~= "" then
                    local ok_g, res_g = pcall(proxy.getGrowth); if ok_g then g = res_g end
                    local ok_ga, res_ga = pcall(proxy.getGain); if ok_ga then ga = res_ga end
                    local ok_r, res_r = pcall(proxy.getResistance); if ok_r then r = res_r end
                    local ok_sz, res_sz = pcall(proxy.getCurrentSize); if ok_sz then sz = res_sz end
                    local ok_gp, res_gp = pcall(proxy.getGrowthPoints); if ok_gp then gp = res_gp end
                end
            end
        end
        
        if id and id ~= "" then
            local db_stages = CROP_DB[id] and CROP_DB[id].stages or 7
            local current_sz = sz or 0
            state.scan_data[key] = {
                id = id, g = g or 0, ga = ga or 0, r = r or 0,
                sz = current_sz, gp = gp or 0, max_stages = db_stages,
                stats = string.format("%d/%d/%d", g or 0, ga or 0, r or 0),
                stage = string.format("%d/%d", current_sz, db_stages)
            }
            
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
        elseif ok_comp then
            state.scan_data[key] = { id = "", stats = "", stage = "", gp = "" }
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