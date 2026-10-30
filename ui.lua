local component = require("component")
local gpu = component.gpu

local ui = {}
local buttons = {}
local old_scan, old_stat, old_chat, old_header = {}, {}, {}, ""
local chat_history = {}

function ui.init()
    gpu.setBackground(0x000000); gpu.setForeground(0xFFFFFF)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
end

function ui.logChat(sender, text)
    table.insert(chat_history, 1, string.format("[%s] %s", sender, text))
    if #chat_history > 15 then table.remove(chat_history) end
end

function ui.createButton(x, y, w, h, label, action, color)
    table.insert(buttons, {x=x, y=y, w=w, h=h, label=label, action=action, color=color or 0x555555})
end

function ui.getButtons()
    return buttons
end

local function drawButtons()
    for _, btn in ipairs(buttons) do
        gpu.setBackground(btn.color)
        gpu.fill(btn.x, btn.y, btn.w, btn.h, " ")
        gpu.setForeground(0xFFFFFF)
        local text_x = btn.x + math.floor((btn.w - #btn.label) / 2)
        local text_y = btn.y + math.floor(btn.h / 2)
        gpu.set(text_x, text_y, btn.label)
    end
end

local function drawCell(state, key, px, py, cell_w, cell_h)
    local st = state.cell_status[key]
    local bg_color = 0x222222
    if st == 1 then bg_color = 0x004400
    elseif st == 2 then bg_color = 0x000044
    elseif st == 3 then bg_color = 0x333333 end
    
    gpu.setBackground(bg_color)
    for row = 0, cell_h - 1 do gpu.set(px, py + row, string.rep(" ", cell_w)) end
    
    if st == 3 then gpu.setForeground(0x777777); gpu.set(px + 2, py + 2, "[TECH]"); return end
    
    local data = state.scan_data[key]
    local stat = state.status_line[key] or ""
    if not data then
        gpu.setForeground(0x555555); gpu.set(px + 2, py + 2, "empty")
        if stat ~= "" then gpu.setForeground(0xFFFF55); gpu.set(px + 1, py + 4, stat:sub(1, cell_w - 2)) end
        return
    end
    if data.id == "" then
        gpu.setForeground(0x55FFFF); gpu.set(px + 3, py + 2, "DBL")
        if stat ~= "" then gpu.setForeground(0x55FFFF); gpu.set(px + 1, py + 4, stat:sub(1, cell_w - 2)) end
        return
    end
    gpu.setForeground(0xFFFFFF); gpu.set(px + 1, py, (data.id or "---"):sub(1, cell_w - 2))
    gpu.setForeground(0xFFFF55); gpu.set(px + 1, py + 1, (data.stats or "-/-/-"):sub(1, cell_w - 2))
    gpu.setForeground(0x55FFFF); gpu.set(px + 1, py + 2, (data.stage or "0/7"):sub(1, cell_w - 2))
    gpu.setForeground(0xAA55FF); gpu.set(px + 1, py + 3, ("GP:"..(data.gp or "0")):sub(1, cell_w - 2))
    if stat ~= "" then
        if stat:match("WEAK") or stat:match("EXCESS") or stat:match("NEW") or stat:match("REPLACE") or stat:match("CLEAR") or stat:match("WEED") then 
            gpu.setForeground(0xFF5555)
        elseif stat:match("DBL") then 
            gpu.setForeground(0x55FFFF)
        elseif stat:match("GROW") then 
            gpu.setForeground(0xFFFF55)
        else 
            gpu.setForeground(0xFFFFFF) 
        end
        gpu.set(px + 1, py + 4, string.rep(" ", cell_w - 2))
        gpu.set(px + 1, py + 4, stat:sub(1, cell_w - 2))
    else
        gpu.set(px + 1, py + 4, string.rep(" ", cell_w - 2))
    end
end

function ui.render(state, CONFIG, force)
    local w, h = gpu.getResolution()
    local start_y, start_x, cell_w, cell_h = 4, 2, 10, 5
    
    local header_str = string.format("=== Server | %s | %s ===", state.phase, (state.busy and "BUSY" or "IDLE"))
    if force or old_header ~= header_str then
        gpu.setBackground(0x000000); gpu.setForeground(0xFFFF55)
        gpu.set(1, 1, header_str .. string.rep(" ", w - #header_str))
        gpu.setForeground(0xFFFFFF)
        local t_str = string.format("Target: %d/%d/%d | MaxPar: %d/%d/%d | MaxCh: %d/%d/%d", 
            CONFIG.target.g, CONFIG.target.ga, CONFIG.target.r, 
            state.max_parent.g, state.max_parent.ga, state.max_parent.r,
            state.max_child.g, state.max_child.ga, state.max_child.r)
        gpu.set(1, 2, t_str .. string.rep(" ", w - #t_str))
        old_header = header_str
    end
    
    for x = CONFIG.field_x, 1, -1 do
        for z = 0, CONFIG.field_z - 1 do
            local key = x .. "," .. z
            local px = start_x + (z * cell_w)
            local py = start_y + (CONFIG.field_x - x) * cell_h
            local new_d = state.scan_data[key]
            local old_d = old_scan[key]
            local need = force
            if not old_d or not new_d then need = true
            elseif new_d.id ~= old_d.id or new_d.stats ~= old_d.stats or new_d.stage ~= old_d.stage or new_d.gp ~= old_d.gp then need = true end
            if (state.status_line[key] or "") ~= (old_stat[key] or "") then need = true end
            if old_stat[key] ~= nil and state.status_line[key] == nil then need = true end --чистка
            if state.cell_status[key] ~= old_scan["_st_"..key] then need = true end
            if need then
                drawCell(state, key, px, py, cell_w, cell_h)
                old_scan[key] = new_d and {id=new_d.id, stats=new_d.stats, stage=new_d.stage, gp=new_d.gp} or nil
                old_scan["_st_"..key] = state.cell_status[key]
                old_stat[key] = state.status_line[key]
            end
        end
    end
    
    local chat_x = start_x + (CONFIG.field_z * cell_w) + 3
    gpu.setForeground(0xFFFFFF); gpu.set(chat_x, start_y, "--- CHAT ---")
    local chat_w = w - chat_x - 1
    for i = 1, 14 do
        local txt = chat_history[i] or ""
        if force or txt:sub(1, chat_w) ~= old_chat[i] then
            gpu.setBackground(0x000000); gpu.set(chat_x, start_y + i, string.rep(" ", chat_w))
            if chat_history[i] then
                local c = 0xFFFFFF
                if chat_history[i]:match("^%[R%]") then c = 0x55FFFF
                elseif chat_history[i]:match("^%[S%]") then c = 0x55FF55 end
                gpu.setForeground(c); gpu.set(chat_x, start_y + i, chat_history[i]:sub(1, chat_w))
            end
            old_chat[i] = txt
        end
    end
    drawButtons()
end

return ui