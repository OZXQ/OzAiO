-- Auto-accept shared quests from party members
-- Ported from Automatonex/QuestAutomation.lua (QUEST_SHOW + StaticPopup_OnShow hook)

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        if (LOCALE ~= "enUS") and (LOCALE ~= "enGB") then
            OzLib.print("Locale fetch failed for quest: " .. v, "error")
        end
        return v
    end
})
if LOCALE == "zhCN" then
    L["Quest"] = "任务"
    L["Enable"] = "启用"
    L["Auto accept shared quests"] = "自动接受共享任务"
    L["Automatically accept quests shared by party members"] = "自动接受队友分享的任务"
    L["Hold Alt to temporarily disable"] = "按住Alt键临时禁用"
end

local module = OzFramework:register("oz_quest", {
    title = L["Quest"],
    order = 6,
    enabled = true,
    config = {
        ["quest.enabled"] = true,
        ["quest.accept_shared"] = true,
    }
})

-- Alt-key override: holding Alt temporarily disables auto-accept so the
-- player can manually decline a single shared quest.
local function should_auto_accept()
    if not OZAIO_CONFIG then return false end
    if not OZAIO_CONFIG["quest.enabled"] then return false end
    if not OZAIO_CONFIG["quest.accept_shared"] then return false end
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

-- Hook StaticPopup_OnShow: the QUEST_ACCEPT popup is what the player
-- actually sees when a quest is shared. Catching it here is more reliable
-- than the QUEST_SHOW event alone (the popup may not be visible yet when
-- the event fires).
local orig_static_popup_onshow = StaticPopup_OnShow
StaticPopup_OnShow = function()
    if orig_static_popup_onshow then
        orig_static_popup_onshow()
    end
    if this.which == "QUEST_ACCEPT" and should_auto_accept() then
        ConfirmAcceptQuest()
        this:Hide()
    end
end

module.enable = function(self)
    if not OZAIO_CONFIG["quest.enabled"] then return end
    event_frame:RegisterEvent("QUEST_SHOW")
end

module.disable = function(self)
    event_frame:UnregisterAllEvents()
end

module.create_config_panel = function(self, parent)
    local panel = CreateFrame("Frame", "OzQuestConfig", parent)
    panel:SetAllPoints()

    local flow = OzUIHelper:createFlow(panel, 10)
    OzUIHelper:attachResize(panel, flow)

    local title = OzUIHelper:makeLabel(panel, L["Quest"], "GameFontNormalLarge")
    title:SetWidth(flow.maxWidth - flow.padding)
    title:SetJustifyH("CENTER")
    OzUIHelper:add(flow, title, flow.maxWidth - flow.padding, 20)
    OzUIHelper:newLine(flow)

    local enableCb = OzUIHelper:makeCheckbox(
        panel, L["Enable"], OZAIO_CONFIG["quest.enabled"],
        function(checked)
            OZAIO_CONFIG["quest.enabled"] = checked
            if checked then module:enable() else module:disable() end
        end)
    OzUIHelper:add(flow, enableCb)
    OzUIHelper:newLine(flow)

    local acceptSharedCb = OzUIHelper:makeCheckbox(
        panel, L["Auto accept shared quests"], OZAIO_CONFIG["quest.accept_shared"],
        function(checked)
            OZAIO_CONFIG["quest.accept_shared"] = checked
        end)
    OzUIHelper:add(flow, acceptSharedCb)
    OzUIHelper:newLine(flow)

    local hint = OzUIHelper:makeLabel(panel, L["Hold Alt to temporarily disable"], "GameFontNormalSmall")
    hint:SetTextColor(0.7, 0.7, 0.7)
    OzUIHelper:add(flow, hint, flow.maxWidth - flow.padding, 16)
    OzUIHelper:newLine(flow)

    return { frame = panel, height = math.abs(flow.y) + flow.padding }
end
