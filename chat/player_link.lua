-- Shift-click Player Link to Chat (CHT-05)
-- Inserts player hyperlinks (|cffffffff|Hplayer:Name|h[Name]|h|r) into ChatFrameEditBox
-- when Shift-clicking a player link in chat while the editbox is open.

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Player Link"] = "玩家姓名链接"
    L["Shift-click player link"] = "Shift点击玩家姓名"
    L["Allows Shift-clicking player names in chat to insert their name link into the chat editbox."] = "在聊天输入框打开时，按住Shift点击聊天框中的玩家姓名可将其超链接插入到输入框中。"
end

local module = nil

local function handle_set_item_ref(link, text, button)
    if not (OZAIO_CONFIG and OZAIO_CONFIG["chat.player_link"]) then
        return
    end

    local is_player_link = link and string.sub(link, 1, 6) == "player"
    if is_player_link then
        local name = string.sub(link, 8)
        if name and string.len(name) > 0 then
            -- Lua 5.0 compatibility: extract name before any colon using string.find
            local _, _, matched_name = string.find(name, "([^:]+)")
            if matched_name then
                name = matched_name
            end
            name = string.gsub(name, "([^%s]*)%s+([^%s]*)%s+([^%s]*)", "%3")
            name = string.gsub(name, "([^%s]*)%s+([^%s]*)", "%2")
            if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:Insert("|cffffffff|Hplayer:" .. name .. "|h[" .. name .. "]|h|r")
                return false
            end
        end
    end
end

local function enable_player_link()
    if OZAIO_CONFIG and OZAIO_CONFIG["chat.player_link"] == false then
        return
    end
    OzHook:hook("SetItemRef", handle_set_item_ref)
end

local function disable_player_link()
    OzHook:unhook("SetItemRef", handle_set_item_ref)
end

-- ==================== Module Registration ====================

module = OzFramework:registerMod({
    name = "oz_chat_player_link",
    title = L["Player Link"],
    category = "Chat",
    order = 3,
    enabled = true,
    config = {
        ["chat.player_link"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Shift-click player link"],
            tooltip = L["Allows Shift-clicking player names in chat to insert their name link into the chat editbox."],
            config_key = "chat.player_link",
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
        enable_player_link()
    end,
    disable = function(self)
        disable_player_link()
    end,
})
