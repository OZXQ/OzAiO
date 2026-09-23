-- Timed Auto Message Broadcaster (CHT-04)
-- Periodically broadcasts messages to a target chat channel.
-- Features: Minute-based interval, dynamic channel dropdown, hybrid item link resolution
-- (Method 1 Shift-click + Method 3 bracketed name resolution), message chunk splitting
-- for >255 byte messages without breaking hyperlinks, input pre-validation, and combat guard.

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Auto Message"] = "定时喊话"
    L["Enable Auto Broadcast"] = "启用定时喊话"
    L["Periodically broadcast messages to the selected channel"] = "在设定好的时间间隔内，自动向指定频道循环发送喊话内容"
    L["Target Channel"] = "目标频道"
    L["Select which channel to broadcast to (e.g. Yell, Trade, World)"] = "选择发送的目标频道（如大喊、交易、世界频道等）"
    L["Broadcast Interval (Minutes)"] = "喊话间隔（分钟）"
    L["How many minutes between each broadcast (1 to 15 minutes)"] = "每次发送消息之间的时间间隔（1 到 15 分钟）"
    L["Broadcast Message"] = "喊话内容"
    L["Enter message. Supports Shift-clicking items or typing [Item Name] for auto-links."] = "输入喊话文本。支持直接 Shift 点击物品，或输入 [物品名称] 自动转为超链接"
    L["Pause in Combat"] = "战斗中自动暂停"
    L["Temporarily halt broadcasting while in combat"] = "进入战斗状态时暂停喊话，脱战后恢复"
    L["Test Broadcast Now"] = "立即测试发送一次"
    L["Send the broadcast message immediately to test formatting and links"] = "立即发送一次喊话内容，用于测试格式与装备超链接效果"
    L["Say"] = "说话"
    L["Yell"] = "大喊"
    L["Guild"] = "公会"
    L["Party"] = "小队"
    L["Raid"] = "团队"
    L["Hardcore"] = "硬核"
    L["Message is empty. Please enter a broadcast message first."] = "喊话内容为空，请先输入喊话文本。"
    L["Channel not found or not joined: %s"] = "未找到或未加入频道: %s"
    L["Broadcast sent to %s."] = "已向频道 [%s] 发送喊话。"
    L["All items resolved."] = "所有物品名称已成功识别并转换为超链接。"
    L["Warning: Unresolved items: %s"] = "提示：以下物品在背包/装备栏中未找到: %s"
end

-- ==================== Cache & State ====================

local cached_resolved_msg = ""
local cached_unresolved_items = {}
local ticker_elapsed = 0
local current_editarea_widget = nil

-- ==================== Item Link Resolver (Method 1 + Method 3) ====================

-- Scan bags (0..4) and equipped items (1..19) for an item by name
local function find_item_link_by_name(target_name)
    if not target_name or target_name == "" then return nil end

    -- 1. Try client cache GetItemInfo if numeric ID or item link string
    if tonumber(target_name) then
        local name, link, quality = GetItemInfo(tonumber(target_name))
        if link and string.find(link, "|Hitem:") then
            return link
        elseif name and quality then
            local hex = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex) or "|cffffffff"
            return hex .. "|Hitem:" .. target_name .. ":0:0:0|h[" .. name .. "]|h|r"
        end
    elseif string.find(target_name, "^item:") then
        local name, link, quality = GetItemInfo(target_name)
        if link and string.find(link, "|Hitem:") then
            return link
        end
    end

    local lower_target = string.lower(target_name)

    -- 2. Check bags (0..4)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local item_link = GetContainerItemLink(bag, slot)
                if item_link then
                    local _, _, linkName = string.find(item_link, "%[(.+)%]")
                    if linkName then
                        -- Check exact match first (safe for UTF-8 / Chinese), then case-insensitive for English
                        if linkName == target_name or string.lower(linkName) == lower_target then
                            return item_link
                        end
                    end
                end
            end
        end
    end

    -- 3. Check equipment slots (1..19)
    for slot = 1, 19 do
        local item_link = GetInventoryItemLink("player", slot)
        if item_link then
            local _, _, linkName = string.find(item_link, "%[(.+)%]")
            if linkName then
                -- Check exact match first, then case-insensitive for English
                if linkName == target_name or string.lower(linkName) == lower_target then
                    return item_link
                end
            end
        end
    end

    return nil
end

-- Resolve all bracketed items in raw message without corrupting existing hyperlinks
local function resolve_message_links(raw_text, missing_callback)
    if not raw_text or raw_text == "" then return "" end

    -- 1. Preserve already formed hyperlinks (e.g. from Shift-click) using temporary tokens
    local preserved_links = {}
    local pcount = 0
    local protected_text = string.gsub(raw_text, "(|c%x+|Hitem:[^|]+|h%[[^%]]-%]|h|r)", function(link)
        pcount = pcount + 1
        preserved_links[pcount] = link
        return "\001LNK" .. pcount .. "\002"
    end)

    -- 2. Resolve only remaining user-typed bracketed items [Item Name] or [#ID]
    local resolved_text = string.gsub(protected_text, "(%b[])", function(token)
        local inner = string.sub(token, 2, -2)
        if inner == "" then return token end

        -- Check numeric item ID (e.g. [#19019] or [19019] or [item:19019])
        local _, _, id = string.find(inner, "^#?(%d+)$")
        if not id then
            _, _, id = string.find(inner, "^item:(%d+)$")
        end
        if id then
            local name, link, quality = GetItemInfo(tonumber(id))
            if link and string.find(link, "|Hitem:") then
                return link
            elseif name and quality then
                local hex = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex) or "|cffffffff"
                return hex .. "|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r"
            end
        end

        -- Look up by item name in bags (0..4) and equipment (1..19)
        local resolved_link = find_item_link_by_name(inner)
        if resolved_link then
            return resolved_link
        end

        -- Missing item
        if missing_callback then
            missing_callback(inner)
        end
        return token
    end)

    -- 3. Restore all preserved hyperlinks intact
    local final_text = string.gsub(resolved_text, "\001LNK(%d+)\002", function(idx)
        local num = tonumber(idx)
        return (num and preserved_links[num]) or ""
    end)

    return final_text
end

local function update_pre_validation(raw_text)
    cached_unresolved_items = {}
    if not raw_text or raw_text == "" then
        cached_resolved_msg = ""
        return
    end

    cached_resolved_msg = resolve_message_links(raw_text, function(missing_name)
        table.insert(cached_unresolved_items, missing_name)
    end)
end

-- ==================== Safe Chunk Splitting (>255 Bytes) ====================

local function split_message_safely(msg, max_len)
    max_len = max_len or 240
    if not msg or string.len(msg) <= max_len then
        return { msg or "" }
    end

    local tokens = {}
    local pos = 1
    local total_len = string.len(msg)

    while pos <= total_len do
        -- Check if an atomic hyperlink starts at pos: |c%x+|Hitem:[^|]+|h%[[^%]]-%]|h|r
        local link_start, link_end = string.find(msg, "|c%x+|Hitem:[^|]+|h%[[^%]]-%]|h|r", pos)
        if link_start == pos then
            table.insert(tokens, string.sub(msg, link_start, link_end))
            pos = link_end + 1
        else
            -- Search for next boundary: space or next hyperlink
            local next_space = string.find(msg, "%s+", pos)
            local next_link = string.find(msg, "|c%x+|Hitem:", pos)

            local next_cut = nil
            if next_space and next_link then
                next_cut = math.min(next_space, next_link)
            else
                next_cut = next_space or next_link
            end

            if not next_cut or next_cut == pos then
                if next_space == pos then
                    local s_end = string.find(msg, "%S", pos)
                    if s_end then
                        table.insert(tokens, string.sub(msg, pos, s_end - 1))
                        pos = s_end
                    else
                        table.insert(tokens, string.sub(msg, pos))
                        pos = total_len + 1
                    end
                else
                    table.insert(tokens, string.sub(msg, pos))
                    pos = total_len + 1
                end
            else
                table.insert(tokens, string.sub(msg, pos, next_cut - 1))
                pos = next_cut
            end
        end
    end

    local chunks = {}
    local current_chunk = ""

    for _, token in ipairs(tokens) do
        if string.len(current_chunk) + string.len(token) <= max_len then
            current_chunk = current_chunk .. token
        else
            if current_chunk ~= "" then
                table.insert(chunks, current_chunk)
                current_chunk = ""
            end
            if string.len(token) > max_len then
                table.insert(chunks, string.sub(token, 1, max_len))
                current_chunk = string.sub(token, max_len + 1)
            else
                current_chunk = token
            end
        end
    end

    if current_chunk ~= "" then
        table.insert(chunks, current_chunk)
    end

    return chunks
end

-- ==================== Sequential Dispatch Queue ====================

local send_queue = {}
local queue_timer = 0
local queue_frame = CreateFrame("Frame", "OzAutoMessageQueueFrame", UIParent)

local function raw_send_chat(message, channel_target)
    if not message or message == "" then return end
    channel_target = channel_target or "YELL"

    if channel_target == "YELL" or channel_target == "SAY" or channel_target == "GUILD" or channel_target == "PARTY" or channel_target == "RAID" or channel_target == "Hardcore" or channel_target == "HARDCORE" then
        SendChatMessage(message, channel_target)
    else
        -- Numeric/Named channel
        local chan_name = string.gsub(channel_target, "^CHANNEL:", "")
        local chan_id = tonumber(chan_name)
        if not chan_id or chan_id <= 0 then
            chan_id = GetChannelName(chan_name)
        end
        if chan_id and chan_id > 0 then
            SendChatMessage(message, "CHANNEL", nil, chan_id)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[OzAiO]|r " .. string.format(L["Channel not found or not joined: %s"], tostring(chan_name)))
        end
    end
end

queue_frame:Hide()
queue_frame:SetScript("OnUpdate", function()
    local elapsed = arg1 or 0.1
    queue_timer = queue_timer + elapsed
    if queue_timer >= 0.2 then
        queue_timer = 0
        local item = table.remove(send_queue, 1)
        if item then
            raw_send_chat(item.msg, item.target)
        end
        if table.getn(send_queue) == 0 then
            queue_frame:Hide()
        end
    end
end)

local function queue_send_chunks(chunks, channel_target, immediate_first)
    if not chunks or table.getn(chunks) == 0 then return end
    for _, chunk in ipairs(chunks) do
        table.insert(send_queue, { msg = chunk, target = channel_target })
    end
    if immediate_first and table.getn(send_queue) > 0 then
        local item = table.remove(send_queue, 1)
        if item then
            raw_send_chat(item.msg, item.target)
        end
    end
    if table.getn(send_queue) > 0 then
        queue_timer = 0
        queue_frame:Show()
    else
        queue_frame:Hide()
    end
end

local function execute_broadcast(immediate_first)
    -- 1. Sync from bound editarea widget directly if available
    if current_editarea_widget and current_editarea_widget.GetValue then
        local live_text = current_editarea_widget:GetValue()
        if live_text and live_text ~= "" and OZAIO_CONFIG then
            OZAIO_CONFIG["chat.broadcast_message"] = live_text
        end
    end

    -- 2. If active edit area is open, sync its text as well
    if OzUIHelper and OzUIHelper._activeEditArea then
        local active_text = OzUIHelper._activeEditArea:GetText()
        if active_text and active_text ~= "" and OZAIO_CONFIG then
            OZAIO_CONFIG["chat.broadcast_message"] = active_text
        end
    end

    local raw = OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_message"]
    if not raw or raw == "" then return false, L["Message is empty. Please enter a broadcast message first."] end

    -- Always re-resolve before sending to catch latest bag/equipment changes
    update_pre_validation(raw)

    local final_msg = cached_resolved_msg
    if not final_msg or final_msg == "" then
        final_msg = raw
    end

    local channel_target = OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_channel"] or "YELL"
    local chunks = split_message_safely(final_msg, 240)
    queue_send_chunks(chunks, channel_target, immediate_first)
    return true, nil, final_msg
end

-- ==================== Dynamic Channel Options ====================

local function get_channel_options()
    local options = {
        { label = L["Yell"],     value = "YELL" },
        { label = L["Say"],      value = "SAY" },
        { label = L["Guild"],    value = "GUILD" },
        { label = L["Party"],    value = "PARTY" },
        { label = L["Raid"],     value = "RAID" },
        { label = L["Hardcore"], value = "Hardcore" },
    }

    local channels = { GetChannelList() }
    for i = 1, table.getn(channels), 2 do
        local first, second = channels[i], channels[i + 1]
        local name, num
        if type(first) == "number" then
            name, num = second, first
        else
            name, num = first, second
        end
        local is_hardcore = type(name) == "string" and (string.lower(name) == "hardcore" or name == "硬核")
        if name and not is_hardcore and name ~= "TWB" and name ~= "LFT" then
            table.insert(options, {
                label = string.format("[%d] %s", num, name),
                value = "CHANNEL:" .. name,
            })
        end
    end

    return options
end

-- ==================== Timer Engine ====================

local ticker_frame = CreateFrame("Frame", "OzAutoMessageTicker", UIParent)
ticker_frame:Hide()

ticker_frame:SetScript("OnUpdate", function()
    local elapsed = arg1 or 0.1
    ticker_elapsed = ticker_elapsed + elapsed
    local interval_mins = OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_interval"] or 2
    local interval_secs = interval_mins * 60

    if ticker_elapsed >= interval_secs then
        ticker_elapsed = 0

        -- Combat guard
        if OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_combat_pause"] and UnitAffectingCombat and UnitAffectingCombat("player") then
            return
        end

        -- Dead/ghost guard
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
            return
        end

        execute_broadcast(true)
    end
end)

local function enable_broadcaster()
    local raw = OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_message"]
    update_pre_validation(raw)
    ticker_elapsed = 0
    if OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_enable"] then
        ticker_frame:Show()
    else
        ticker_frame:Hide()
    end
end

local function disable_broadcaster()
    ticker_frame:Hide()
    queue_frame:Hide()
    send_queue = {}
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "oz_auto_message",
    title = L["Auto Message"],
    category = "Chat",
    order = 4,
    enabled = true,
    config = {
        ["chat.broadcast_enable"] = false,
        ["chat.broadcast_interval"] = 2,
        ["chat.broadcast_channel"] = "YELL",
        ["chat.broadcast_message"] = "",
        ["chat.broadcast_combat_pause"] = true,
    },
    config_ui_creator = function()
        return {
            {
                type = "checkbox",
                label = L["Enable Auto Broadcast"],
                tooltip = L["Periodically broadcast messages to the selected channel"],
                config_key = "chat.broadcast_enable",
                onChange = function(checked)
                    if checked then
                        ticker_frame:Show()
                    else
                        ticker_frame:Hide()
                    end
                end,
            },
            {
                type = "dropdown",
                label = L["Target Channel"],
                tooltip = L["Select which channel to broadcast to (e.g. Yell, Trade, World)"],
                config_key = "chat.broadcast_channel",
                options = get_channel_options(),
            },
            {
                type = "slider",
                label = L["Broadcast Interval (Minutes)"],
                tooltip = L["How many minutes between each broadcast (1 to 15 minutes)"],
                config_key = "chat.broadcast_interval",
                min = 1,
                max = 15,
                step = 1,
                width = 200,
            },
            {
                type = "editarea",
                label = L["Broadcast Message"],
                tooltip = L["Enter message. Supports Shift-clicking items or typing [Item Name] for auto-links."],
                config_key = "chat.broadcast_message",
                width = 300,
                height = 64,
                onCreated = function(w)
                    current_editarea_widget = w
                end,
                onChange = function(new_val)
                    update_pre_validation(new_val)
                end,
            },
            {
                type = "space",
                height = 8,
            },
            {
                type = "checkbox",
                label = L["Pause in Combat"],
                tooltip = L["Temporarily halt broadcasting while in combat"],
                config_key = "chat.broadcast_combat_pause",
            },
            {
                type = "button",
                label = L["Test Broadcast Now"],
                tooltip = L["Send the broadcast message immediately to test formatting and links"],
                width = 180,
                height = 24,
                func = function()
                    if OzUIHelper and OzUIHelper._activeEditArea then
                        OzUIHelper._activeEditArea:ClearFocus()
                    end
                    local success, err, final_msg = execute_broadcast(true)
                    if not success and err then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[OzAiO]|r " .. tostring(err))
                    elseif success then
                        local chan = OZAIO_CONFIG and OZAIO_CONFIG["chat.broadcast_channel"] or "YELL"
                        DEFAULT_CHAT_FRAME:AddMessage("|cff20b2aa[OzAiO]|r " .. string.format(L["Broadcast sent to %s."], tostring(chan)))
                        if final_msg then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff808080[Preview]|r " .. final_msg)
                        end
                    end
                end,
            },
        }
    end,
    enable = function(self)
        enable_broadcaster()
    end,
    disable = function(self)
        disable_broadcaster()
    end,
})
