local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if LOCALE == "zhCN" then
    L["Chat"] = "聊天"
    L["Short channel names"] = "频道名缩写"
    L["Shortens channel prefixes, e.g. [1. General] to [G]."] = "将频道名称前缀缩短显示，例如 [1. 综合] 缩短为 [综]。"
end

local channelNameMapping = {
    ["General"] = "G",
    ["综合"] = "综",
    ["Trade"] = "T",
    ["交易"] = "交",
    ["LocalDefense"] = "LD",
    ["本地防务"] = "本",
    ["WorldDefense"] = "WD",
    ["世界防务"] = "世",
    ["LookingForGroup"] = "LFG",
    ["寻求组队"] = "组",
    ["GuildRecruitment"] = "GR",
    ["公会招募"] = "公",
    ["Hardcore"] = "H",
    ["硬核"] = "核",
    ["World"] = "W",
    ["世界"] = "世",
    ["Party"] = "P",
    ["小队"] = "队",
    ["Raid"] = "R",
    ["团队"] = "团",
    ["Say"] = "S",
    ["说"] = "说",
    ["Whisper"] = "W",
    ["密语"] = "密",
    ["Yell"] = "Y",
    ["喊"] = "喊",
}

local function filter_short_channel_name(displayEvent)
    local enabled = OZAIO_CONFIG and OZAIO_CONFIG["chat.short_channel_name"]
    if not enabled then
        return displayEvent
    end
    if not displayEvent.msg or type(displayEvent.msg) ~= "string" then
        return displayEvent
    end

    displayEvent.msg = string.gsub(displayEvent.msg, "^%[%d*%.?%s*([^%]]+)%]", function(name)
        name = string.gsub(name, "^%s*(.-)%s*$", "%1")
        local short = channelNameMapping[name]
        if short then
            return "[" .. short .. "]"
        end
        return "[" .. name .. "]"
    end)

    return displayEvent
end

if ozChat and ozChat.regDspFilter then
    ozChat:regDspFilter("Short Channel Name", filter_short_channel_name)
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "oz_chat_short_channel",
    title = L["Short channel names"],
    category = "Chat",
    order = 1,
    enabled = true,
    config = {
        ["chat.short_channel_name"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Short channel names"],
            tooltip = L["Shortens channel prefixes, e.g. [1. General] to [G]."],
            config_key = "chat.short_channel_name",
        },
    },
    enable = function(self)
        if ozChat and ozChat.init then
            ozChat:init()
        end
    end,
})
