local _, build = GetBuildInfo()
local tWOW = tonumber(build) > 6000

local BLZ_BUTTONS = {
    "MiniMapTrackingFrame",
    "MiniMapMeetingStoneFrame",
    "MinimapZoomIn",
    "MinimapZoomOut",
    "MiniMapMailFrame",
}

local TWOW_BUTTONS = {
    "EVTButtonFrame",
    "MinimapShopFrame",
    "TWMiniMapBattlefieldFrame",
    "LFTMinimapButton",
    "EBC_Minimap"
}

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if LOCALE == "zhCN" then
    L["Hide System Button"] = "隐藏系统按键"
    L["Hide System Buttons"] = "隐藏系统按键"
    L["Hides tracking, zoom, mail, and other default buttons from the minimap border."] = "从迷你地图边缘隐藏追踪、缩放、邮件等默认系统按键。"
end

local function toggle_system_buttons(state)
    for _, btn in pairs(BLZ_BUTTONS) do
        local f = _G[btn]
        if f then
            if not state then
                f:Show()
            else
                f:Hide()
            end
        end
    end
    if tWOW then
        for _, btn in pairs(TWOW_BUTTONS) do
            local f = _G[btn]
            if f then
                if not state then
                    f:Show()
                else
                    f:Hide()
                end
            end
        end
    end
end

local module = OzFramework:registerMod({
    name = "oz_sysbtn_hider",
    title = L["Hide System Button"],
    category = "Minimap",
    order = 3,
    enabled = true,
    config = {
        ["minimap.hide_system_buttons"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Hide System Buttons"],
            tooltip = L["Hides tracking, zoom, mail, and other default buttons from the minimap border."],
            config_key = "minimap.hide_system_buttons",
            onChange = function(checked)
                toggle_system_buttons(checked)
            end,
        },
    },
    enable = function(self)
        local hide = true
        if OZAIO_CONFIG and OZAIO_CONFIG["minimap.hide_system_buttons"] ~= nil then
            hide = OZAIO_CONFIG["minimap.hide_system_buttons"]
        end
        toggle_system_buttons(hide)
        if _G["MinimapShopFrame"] then
            _G["MinimapShopFrame"]:Hide()
        end
    end,
    disable = function(self)
        toggle_system_buttons(false)
    end,
})
