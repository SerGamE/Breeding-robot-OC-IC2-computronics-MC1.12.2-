local fs = require("filesystem")
local serialization = require("serialization")
local MAP_FILE = "/home/map.lua"

local map_manager = {}

function map_manager.save(state)
    local map_data = {}
    for k, v in pairs(state.crop_matrix) do
        local x, z = k:match("(%d+),(%d+)")
        local status = state.cell_status[k] or 0
        map_data[{tonumber(x), tonumber(z)}] = { uuid = v, status = status }
    end
    local f = fs.open(MAP_FILE, "w")
    if f then 
        f:write("return " .. serialization.serialize(map_data))
        f:close() 
    end
end

function map_manager.load(state)
    package.loaded["map"] = nil 
    local ok, data = pcall(require, "map")
    if not ok or type(data) ~= "table" then return false end
    
    state.crop_matrix = {}; state.cell_status = {}
    local p_count, c_count, t_count = 0, 0, 0
    
    for coord, info in pairs(data) do
        local k = coord[1] .. "," .. coord[2]
        state.crop_matrix[k] = info.uuid
        state.cell_status[k] = info.status
        if info.status == 3 then t_count = t_count + 1
        elseif info.status == 1 then p_count = p_count + 1
        elseif info.status == 2 then c_count = c_count + 1 end
    end
    
    return true, p_count, c_count, t_count
end

return map_manager