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
        if (LOCALE ~= "enUS") and (LOCALE ~= "enGB") then
            OzLib.print("Locale fetch failed for minimap" .. v, "error")
        end
        return v
    end
})
if LOCALE == "zhCN" then
    L["Minimap"] = "小地图"
    L["Hide System Buttons"] = "隐藏系统按键"
end

local module = OzFramework:register("oz_minimap", {
    title = L["Minimap"],
    order = 3,
    enabled = true,
    config = {
        ["minimap.hideSystemButtons"] = true,
    }
})

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

module.enable = function(self)
    toggle_system_buttons(OZAIO_CONFIG["minimap.hideSystemButtons"])
    if _G["MinimapShopFrame"] then
        _G["MinimapShopFrame"]:Hide()
    end
end

module.create_config_panel = function(self, parent)
    local panel = CreateFrame("Frame", "OzMiniMapConfig", parent)
    panel:SetAllPoints()

    local flow = OzUIHelper:createFlow(panel, 10)
    OzUIHelper:attachResize(panel, flow)

    local title = OzUIHelper:makeLabel(panel, L["Minimap"], "GameFontNormalLarge")
    title:SetWidth(flow.maxWidth - flow.padding)
    title:SetJustifyH("CENTER")
    OzUIHelper:add(flow, title, flow.maxWidth - flow.padding, 20)

    OzUIHelper:newLine(flow)

    local enableCheckbox = OzUIHelper:makeCheckbox(panel, L["Hide System Buttons"], OZAIO_CONFIG["minimap.hideSystemButtons"], function(checked)
        OZAIO_CONFIG["minimap.hideSystemButtons"] = checked
        toggle_system_buttons(checked)
    end)
    OzUIHelper:add(flow, enableCheckbox)

    return { frame = panel, height = math.abs(flow.y) + flow.padding }
end
