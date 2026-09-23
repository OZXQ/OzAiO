-- Auto-accept shared quests from party members
-- Ported from Automatonex/QuestAutomation.lua (QUEST_SHOW + StaticPopup_OnShow hook)

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if LOCALE == "zhCN" then
    L["Auto Accept Sharing"] = "自动接受共享任务"
    L["Enable"] = "启用"
    L["Auto accept shared quests"] = "自动接受共享任务"
    L["Automatically accept quests shared by party members"] = "自动接受队友分享的任务"
    L["Hold Alt to temporarily disable"] = "按住Alt键临时禁用"
end

-- Alt-key override: holding Alt temporarily disables auto-accept so the
-- player can manually decline a single shared quest.
local function should_auto_accept()
    if not OZAIO_CONFIG then return false end
    if not (OZAIO_CONFIG and OZAIO_CONFIG["quest.accept_sharing"]) then return false end
    if IsAltKeyDown() then return false end
    return true
end

local function accept_shared_quest()
    if not should_auto_accept() then return end
    if StaticPopup_Visible("QUEST_ACCEPT") then
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
    end
end

-- ================== Event Frame ==================
local event_frame = CreateFrame("Frame", "OzAiOQuestEvents", UIParent)
event_frame:SetScript("OnEvent", function()
    if event == "QUEST_SHOW" then
        accept_shared_quest()
    end
end)

-- Hook StaticPopup_OnShow safely via OzHook
local function on_static_popup_show()
    if this and this.which == "QUEST_ACCEPT" and should_auto_accept() then
        ConfirmAcceptQuest()
        this:Hide()
    end
end

local module = OzFramework:registerMod({
    name = "oz_auto_quest_accept",
    title = L["Auto Accept Sharing"],
    category = "Quest",
    order = 6,
    enabled = true,
    config = {
        ["quest.accept_sharing"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Auto Accept Sharing"],
            tooltip = L["Automatically accept quests shared by party members"],
            config_key = "quest.accept_sharing",
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
        if OZAIO_CONFIG and OZAIO_CONFIG["quest.accept_sharing"] == false then return end
        event_frame:RegisterEvent("QUEST_SHOW")
        OzHook:hook("StaticPopup_OnShow", nil, on_static_popup_show)
    end,
    disable = function(self)
        event_frame:UnregisterAllEvents()
        OzHook:unhook("StaticPopup_OnShow", on_static_popup_show)
    end,
})
