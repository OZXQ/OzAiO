-- Chat EditBox Tweaks (CHT-07)
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
    L["Move chat editbox to screen center dodging action bars, and iterate history with arrow keys."] =
    "将聊天输入框居中并避开动作条，支持无需按Alt直接用上下键翻阅聊天历史。"
end

local DODGE_GAP = 8
local orig_ClearAllPoints, orig_SetPoint

local dodge_frames = {
    "MainMenuBar",
    "BonusActionBarFrame",
    "ShapeshiftBarFrame",
    "PetActionBarFrame",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
}

local function get_dodge_top()
    local top = 0
    for _, name in ipairs(dodge_frames) do
        local frame = getglobal(name)
        if frame and frame:IsVisible() and frame:GetTop() then
            local frameTop = (frame:GetTop() * frame:GetEffectiveScale())
            top = math.max(frameTop, top)
        end
    end
    if top == 0 then top = 200 end
    return top
end

local function enable_editbox()
    if OZAIO_CONFIG and OZAIO_CONFIG["chat.editbox_tweak"] == false then
        return
    end
    if not ChatFrameEditBox then return end
    ChatFrameEditBox:SetAltArrowKeyMode(false)

    if not orig_ClearAllPoints then
        orig_ClearAllPoints = ChatFrameEditBox.ClearAllPoints
        orig_SetPoint = ChatFrameEditBox.SetPoint
    end

    -- Also lock SetPoint and ClearAllPoints
    local top = math.floor(get_dodge_top() + 0.5) + DODGE_GAP
    local halfWidth = 300

    ChatFrameEditBox:ClearAllPoints()
    ChatFrameEditBox:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -halfWidth, top)
    ChatFrameEditBox:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", halfWidth, top)

    ChatFrameEditBox.ClearAllPoints = function() end
    ChatFrameEditBox.SetPoint = function() end
end

local function disable_editbox()
    if not ChatFrameEditBox then return end
    ChatFrameEditBox:SetAltArrowKeyMode(true)

    if orig_ClearAllPoints and orig_SetPoint then
        -- Restore methods
        ChatFrameEditBox.ClearAllPoints = orig_ClearAllPoints
        ChatFrameEditBox.SetPoint = orig_SetPoint
        orig_ClearAllPoints = nil
        orig_SetPoint = nil

        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -5, -2)
        ChatFrameEditBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 5, -2)
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
        ["chat.editbox_tweak"] = false,
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
