local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if LOCALE == "zhCN" then
    L["HC display window"] = "HC显示窗口"
    L["HC window must be 1-20"] = "HC窗口编号需在1-20之间"
    L["Chat frame ID (1-20) to redirect Hardcore messages."] = "重定向硬核消息的目标聊天窗口编号 (1-20)。"
end

local function filter_hc_redirect(chat)
    local hcWindowNum = OZAIO_CONFIG and OZAIO_CONFIG["chat.hc_window_num"]
    if hcWindowNum and chat.type == "HARDCORE" then
        local targetId = tonumber(hcWindowNum)
        if chat.frameId == targetId then
            chat.cancelled = false
        else
            chat.cancelled = true
        end
    end
    return chat
end

if ozChat and ozChat.regEvtFilter then
    ozChat:regEvtFilter("HC Window", filter_hc_redirect)
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "oz_chat_hc_window",
    title = L["HC display window"],
    category = "Chat",
    order = 2,
    enabled = true,
    config = {
        ["chat.hc_window_num"] = 1,
    },
    config_ui_creator = {
        {
            type = "editbox",
            label = L["HC display window"],
            tooltip = L["Chat frame ID (1-20) to redirect Hardcore messages."],
            width = 40,
            config_key = "chat.hc_window_num",
            onChange = function(val)
                local num = tonumber(val)
                if num and num >= 1 and num <= 20 then
                    OZAIO_CONFIG["chat.hc_window_num"] = num
                else
                    OzLib.print(L["HC window must be 1-20"], "error")
                end
            end,
        },
    },
    enable = function(self)
        if ozChat and ozChat.init then
            ozChat:init()
        end
    end,
})
