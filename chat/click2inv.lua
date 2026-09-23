-- Clickable Auto-Invite Links (CHT-06)
-- Converts common group invite trigger words (1, 111, inv, invite, 组, 求组, 组我, etc.)
-- into clickable hyperlinks (|cff00ffff|Hinvite:Sender|h[...]|h|r) in public and group channels.
-- Clicking the bracketed link instantly calls InviteByName(sender).

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Click to invite"] = "点击邀请"
    L["Clickable invite keywords in chat to quickly invite players to your group."] = "将聊天中常见的求组关键词（如 1、111、inv、invite、组、求组、组我等）转换为可点击链接，点击即可直接邀请该玩家。"
end

local module = nil

-- Convert trigger keywords within message to clickable invite hyperlinks
local function convert_keywords_to_links(msg, sender)
    if not msg or msg == "" then return msg end

    -- Avoid mutating messages that already contain hyperlinks
    if string.find(msg, "|H") then
        return msg
    end

    local link_prefix = "|cff00ffff|Hinvite:" .. sender .. "|h["
    local link_suffix = "]|h|r"

    -- 1. Pure 1s: "1", "11", "111", "1111", etc. (with optional spaces or punctuation)
    local _, _, trg1 = string.find(msg, "^%s*(1+)[%s%p]*$")
    if trg1 then
        return link_prefix .. trg1 .. link_suffix
    end

    -- 1b. Class/Role prefix + 1s: e.g. "fs 1", "dz 111", "法师 111"
    local _, _, prefix, trg1b = string.find(msg, "^%s*([%a%d\128-\255]+)%s+(1+)[%s%p]*$")
    if prefix and trg1b then
        return prefix .. " " .. link_prefix .. trg1b .. link_suffix
    end

    -- 2. Chinese trigger phrases: "求个组", "求组", "组我一个", "组我"
    if string.find(msg, "求个组") then
        return string.gsub(msg, "求个组", link_prefix .. "求个组" .. link_suffix, 1)
    end
    if string.find(msg, "求组") then
        return string.gsub(msg, "求组", link_prefix .. "求组" .. link_suffix, 1)
    end
    if string.find(msg, "组我一个") then
        return string.gsub(msg, "组我一个", link_prefix .. "组我一个" .. link_suffix, 1)
    end
    if string.find(msg, "组我") then
        return string.gsub(msg, "组我", link_prefix .. "组我" .. link_suffix, 1)
    end

    -- 3. Standalone Chinese trigger: "组", "组组", "组队"
    local clean_msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    clean_msg = string.gsub(clean_msg, "[%p%s]+$", "")
    if clean_msg == "组" or clean_msg == "组组" or clean_msg == "组队" then
        return link_prefix .. clean_msg .. link_suffix
    end

    -- 4. English whole words: "invite", "inv"
    local padded = " " .. msg .. " "

    -- Check whole-word "invite"
    local new_padded, count = string.gsub(padded, "([^%a])([iI][nN][vV][iI][tT][eE])([^%a])", function(pre, word, post)
        return pre .. link_prefix .. word .. link_suffix .. post
    end, 1)

    if count and count > 0 then
        return string.sub(new_padded, 2, string.len(new_padded) - 1)
    end

    -- Check whole-word "inv"
    new_padded, count = string.gsub(padded, "([^%a])([iI][nN][vV])([^%a])", function(pre, word, post)
        return pre .. link_prefix .. word .. link_suffix .. post
    end, 1)

    if count and count > 0 then
        return string.sub(new_padded, 2, string.len(new_padded) - 1)
    end

    return msg
end

-- Event filter pipeline hook for ozChat
local function filter_click_to_invite(chat)
    if not (OZAIO_CONFIG and OZAIO_CONFIG["chat.click2inv"]) then
        return chat
    end

    if not chat or not chat.message or type(chat.message) ~= "string" or chat.message == "" then
        return chat
    end

    if not chat.sender or chat.sender == "" then
        return chat
    end

    if chat.sender == UnitName("player") then
        return chat
    end

    local event_type = chat.type
    if event_type ~= "CHANNEL"
        and event_type ~= "WHISPER"
        and event_type ~= "SAY"
        and event_type ~= "YELL"
        and event_type ~= "GUILD"
        and event_type ~= "PARTY"
        and event_type ~= "RAID" then
        return chat
    end

    local new_message = convert_keywords_to_links(chat.message, chat.sender)
    if new_message then
        chat.message = new_message
    end

    return chat
end

if ozChat and ozChat.regEvtFilter then
    ozChat:regEvtFilter("Click2Inv", filter_click_to_invite)
end

-- Hyperlink click handler for SetItemRef
local function handle_set_item_ref(link, text, button)
    if not (OZAIO_CONFIG and OZAIO_CONFIG["chat.click2inv"]) then
        return
    end

    if link and string.sub(link, 1, 7) == "invite:" then
        local sender = string.sub(link, 8)
        if sender and string.len(sender) > 0 then
            local _, _, clean_sender = string.find(sender, "([^:]+)")
            if clean_sender then
                sender = clean_sender
            end
            sender = string.gsub(sender, "^%s*(.-)%s*$", "%1")
            if string.len(sender) > 0 then
                InviteByName(sender)
                return false
            end
        end
    end
end

local function enable_click_to_invite()
    if OZAIO_CONFIG and OZAIO_CONFIG["chat.click2inv"] == false then
        return
    end
    if ozChat and ozChat.init then
        ozChat:init()
    end
    OzHook:hook("SetItemRef", handle_set_item_ref)
end

local function disable_click_to_invite()
    OzHook:unhook("SetItemRef", handle_set_item_ref)
end

-- ==================== Module Registration ====================

module = OzFramework:registerMod({
    name = "oz_chat_click2inv",
    title = L["Click to invite"],
    category = "Chat",
    order = 5,
    enabled = true,
    config = {
        ["chat.click2inv"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Click to invite"],
            tooltip = L["Clickable invite keywords in chat to quickly invite players to your group."],
            config_key = "chat.click2inv",
            onChange = function(checked)
                if checked then
                    module:enable()
                else
                    module:disable()
                end
            end,
        },
    },
    enable = function(self)
        enable_click_to_invite()
    end,
    disable = function(self)
        disable_click_to_invite()
    end,
})
