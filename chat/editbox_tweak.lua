-- Chat EditBox Tweaks (CHT-07)
-- References ShaguTweaks (chat-input-center.lua & chat-tweaks.lua):
-- 1. Centers ChatFrameEditBox and dodges bottom action bars via UIParent_ManageFramePositions.
-- 2. Enables direct Up/Down arrow history iteration without holding Alt.

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["EditBox Tweaks"] = "聊天输入框增强"
    L["Move chat editbox to screen center dodging action bars, and iterate history with arrow keys."] = "将聊天输入框居中并避开动作条，支持无需按Alt直接用上下键翻阅聊天历史。"
end

local dodge_frames = {
    MainMenuBarArtFrame,
    MultiBarBottomLeft,
    MultiBarBottomRight,
    PetActionBarFrame,
    ShapeshiftBarFrame,
}

local function update_position()
    local top = 0
    for _, frame in ipairs(dodge_frames) do
        if frame and frame:IsVisible() and frame:GetTop() then
            top = math.max(top, frame:GetTop())
        end
    end
    ChatFrameEditBox:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, top)
end

local function enable_editbox()
    ChatFrameEditBox:ClearAllPoints()
    ChatFrameEditBox:SetWidth(300)
    ChatFrameEditBox:SetAltArrowKeyMode(false)
    OzHook:hook("UIParent_ManageFramePositions", nil, update_position)
    update_position()
end

local function disable_editbox()
    OzHook:unhook("UIParent_ManageFramePositions", update_position)
    ChatFrameEditBox:SetAltArrowKeyMode(true)
    ChatFrameEditBox:ClearAllPoints()
    if DEFAULT_CHAT_FRAME then
        ChatFrameEditBox:SetPoint("TOPLEFT", DEFAULT_CHAT_FRAME, "BOTTOMLEFT", -5, -2)
        ChatFrameEditBox:SetPoint("TOPRIGHT", DEFAULT_CHAT_FRAME, "BOTTOMRIGHT", 5, -2)
    end
end

-- ==================== Module Registration ====================

local module
module = OzFramework:registerMod({
    name = "oz_chat_editbox",
    title = L["EditBox Tweaks"],
    category = "Chat",
    order = 6,
    enabled = true,
    config = {
        ["chat.editbox_tweak"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["EditBox Tweaks"],
            tooltip = L["Move chat editbox to screen center dodging action bars, and iterate history with arrow keys."],
            config_key = "chat.editbox_tweak",
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
        enable_editbox()
    end,
    disable = function(self)
        disable_editbox()
    end,
})
