--  OzFramework Meta Class 
if OzFramework and OzFramework.loaded then return end
OzFramework = OzFramework or {}
OzFramework.loaded = true

OzFramework.core = {
    name = "OzAiO",
    modules = {},
    module_frames = {},
    config_frame = nil,
    minimap_button = nil,
    config_tab_frame = nil,
    config_content_frame = nil,
    default_tab = "oz_general",
    initialized = false
}

if not OZAIO then
    OZAIO = {
        minimap_angle = 0,
    }
end

if not OZAIO.minimap_angle then
    OZAIO.minimap_angle = 0
end

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        if (LOCALE ~= "enUS") and (LOCALE ~= "enGB") then
            OzLib.print("Locale fetch failed for framework" .. v, "error")
        end
        return v
    end
})
if LOCALE == "zhCN" then
    L["OZAiO"] = "OZ工具箱"
    L["Click to Open/Close Settings"] = "点击打开/关闭设置"
    L["OZAiO Config"] = "OZ工具箱配置"
end

--  Layout Aliases 
local MD = OzUIHelper.Metrics.dialog  -- dialog component sizes
local M  = OzUIHelper.Metrics         -- general widget sizes + minimap

-- Minimap asset paths (theme, not layout)
local MINIMAP_ASSETS = {
    icon     = "Interface\\Addons\\OzAiO\\texture\\ozicon.blp",
    border   = "Interface\\Minimap\\MiniMap-TrackingBorder",
    highlight= "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}

--  Module Registration 
function OzFramework:register(id,mod)

    if OzFramework.core.modules[id] then
        return OzFramework.core.modules[id]
    end

    mod.id=id
    mod.config=mod.config or {}

    OzFramework.core.modules[id]=mod

    return mod
end

-- Merge module default config values into OZAIO_CONFIG for any missing keys
local function merge_config()
    if not OZAIO_CONFIG then
        OZAIO_CONFIG = {}
    end
    for _, mod in pairs(OzFramework.core.modules) do
        if mod.config then
            for key, value in pairs(mod.config) do
                if OZAIO_CONFIG[key] == nil then
                    OZAIO_CONFIG[key] = value
                end
            end
        end
    end
end

--  Config UI 
local function create_config_ui()
    if OzFramework.core.config_frame then return end

    local frame = CreateFrame("Frame", "OzAiOConfigFrame", UIParent)
    frame:SetWidth(MD.width)
    frame:SetHeight(MD.height)
    OzUIHelper:anchor(frame, UIParent, "CENTER", "CENTER", 0, 0)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true, tileSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    OzUIHelper:makeMovable(frame)
    frame:Hide()

    -- Title bar (inset within dialog border)
    local H = MD.header
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  H.insetL, -H.insetT)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -H.insetR, -H.insetT)
    header:SetHeight(H.height)

    OzUIHelper:applyBackdrop(header, "flat")
    local _, playerClass = UnitClass("player")
    local r, g, b = OzUIHelper:classColor(playerClass)
    header:SetBackdropColor(r, g, b, 1.0)
    header:SetBackdropBorderColor(1, 1, 1, 0.5)

    local title = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetText(L["OZAiO Config"])
    title:SetPoint("CENTER", header, "CENTER", 0, 0)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)

    -- Border overlay (edge only, renders above header in Z-order)
    local borderOverlay = CreateFrame("Frame", nil, frame)
    borderOverlay:SetAllPoints(frame)
    borderOverlay:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
    })

    -- Tab + Content layout
    local LM = MD.main

    local tabFrame = CreateFrame("Frame", nil, frame)
    tabFrame:ClearAllPoints()
    OzUIHelper:anchor(tabFrame, frame, "TOPLEFT",    "TOPLEFT",    LM.margin, LM.topOffset)
    OzUIHelper:anchor(tabFrame, frame, "BOTTOMLEFT", "BOTTOMLEFT", LM.margin, LM.bottomOffset)

    tabFrame:SetWidth(MD.tab.width)
    OzUIHelper:applyBackdrop(tabFrame, "panel")

    local contentScroll = CreateFrame("ScrollFrame", nil, frame)
    contentScroll:ClearAllPoints()
    OzUIHelper:anchor(contentScroll, tabFrame, "TOPLEFT",     "TOPRIGHT", LM.gap, 0)
    OzUIHelper:anchor(contentScroll, frame,    "BOTTOMRIGHT", "BOTTOMRIGHT", -LM.margin, LM.bottomOffset)
    OzUIHelper:applyBackdrop(contentScroll, "panel")
    contentScroll:EnableMouseWheel(true)

    local contentFrame = CreateFrame("Frame", nil, contentScroll)
    contentScroll:SetScrollChild(contentFrame)

    -- Sync scroll-child size to match the scroll frame (called on show + resize)
    local function syncScrollChild()
        local w = contentScroll:GetWidth()
        if w > 0 then
            contentFrame:SetWidth(w)
        end
        local h = contentScroll:GetHeight()
        if h > 0 and contentFrame:GetHeight() < h then
            contentFrame:SetHeight(h)
        end
    end

    OzUIHelper:onResize(contentScroll, syncScrollChild)
    frame:SetScript("OnShow", function()
        syncScrollChild()
    end)

    -- Mouse wheel scrolling
    contentScroll:SetScript("OnMouseWheel", function()
        local cur = this:GetVerticalScroll()
        local new = cur - arg1 * MD.scroll.step
        if new < 0 then new = 0 end
        local maxS = contentFrame:GetHeight() - this:GetHeight()
        if maxS < 0 then maxS = 0 end
        if new > maxS then new = maxS end
        this:SetVerticalScroll(new)
    end)

    local function update_layout()
        local h = frame:GetHeight()
        tabFrame:SetHeight(h - math.abs(LM.topOffset) - LM.bottomOffset)
    end

    OzUIHelper:onResize(frame, update_layout)
    update_layout()

    -- Tab buttons (left panel)
    local tabFlow = OzUIHelper:createFlow(tabFrame, 8)
    -- onResize callbacks receive (frame, w, h); the first argument is the
    -- frame itself, not the width.
    OzUIHelper:onResize(tabFrame, function(f, w)
        tabFlow.maxWidth = w - MD.tab.flowPad
        OzUIHelper:rebuildFlow(tabFlow)
    end)

    local function add_tab(id)
        local mod = OzFramework.core.modules[id]
        local btn = OzUIHelper:makeButton(tabFrame, mod.title, function()
            for _, f in pairs(OzFramework.core.module_frames) do
                f:Hide()
            end

            if not OzFramework.core.module_frames[id] then
                if mod.create_config_panel then
                    -- Ensure scroll child is sized before building panel
                    if contentFrame:GetWidth() <= 0 then
                        contentFrame:SetWidth(contentScroll:GetWidth())
                    end
                    if contentFrame:GetHeight() <= 0 then
                        contentFrame:SetHeight(contentScroll:GetHeight())
                    end
                    local result = mod:create_config_panel(contentFrame)
                    -- Support both legacy (frame) and contract ({frame, height})
                    if type(result) == "table" and result.frame then
                        OzFramework.core.module_frames[id] = result.frame
                        result.frame._panelHeight = result.height
                    else
                        OzFramework.core.module_frames[id] = result
                    end
                end
            end

            local panel = OzFramework.core.module_frames[id]
            if panel then
                panel:Show()
                -- Use module height contract if provided, else measure
                local panelH = panel._panelHeight or panel:GetHeight()
                local viewH = contentScroll:GetHeight()
                if panelH > viewH then
                    contentFrame:SetHeight(panelH)
                else
                    contentFrame:SetHeight(viewH)
                end
            end
        end)

        OzUIHelper:add(tabFlow, btn, MD.tab.btnW, MD.tab.btnH)
        -- The flow never wraps automatically; tab buttons stack vertically
        -- only because the line is broken explicitly after each one.
        OzUIHelper:newLine(tabFlow)
    end

    -- Module order (by mod.order, then default_tab first)
    local modules = {}
    for id, mod in pairs(OzFramework.core.modules) do
        table.insert(modules, { id = id, order = mod.order or 99 })
    end
    table.sort(modules, function(a, b)
        if a.id == OzFramework.core.default_tab then return true end
        if b.id == OzFramework.core.default_tab then return false end
        return a.order < b.order
    end)
    for _, entry in ipairs(modules) do
        add_tab(entry.id)
    end

    OzFramework.core.config_frame = frame
    OzFramework.core.config_tab_frame = tabFrame
    OzFramework.core.config_content_frame = contentFrame
end

local function toggle_config_ui()
    if not OzFramework.core.config_frame then
        create_config_ui()
    end
    if OzFramework.core.config_frame:IsShown() then
        OzFramework.core.config_frame:Hide()
    else
        OzFramework.core.config_frame:Show()
    end
end

--  Minimap Button
local function create_minimap_button()
    if OzFramework.core.minimap_button then
        return OzFramework.core.minimap_button
    end

    local button = OzUIHelper:createMinimapButton({
        name         = "OzAiOMinimapButton",
        icon         = MINIMAP_ASSETS.icon,
        overlay      = MINIMAP_ASSETS.border,
        highlight    = MINIMAP_ASSETS.highlight,
        angleState   = OZAIO,
        tooltipTitle = L["OZAiO"],
        tooltipText  = L["Click to Open/Close Settings"],
        onClick      = toggle_config_ui,
    })

    OzFramework.core.minimap_button = button
    OzLib.print("Minimap button created successfully.", "debug")
    return button
end

--  Initialization
local function on_addon_loaded()
    if arg1 ~= OzFramework.core.name or OzFramework.core.initialized then return end
    merge_config()
    OzFramework.core.initialized = true
    for _, mod in pairs(OzFramework.core.modules) do
        if mod.enabled and mod.enable then
            mod:enable()
        end
    end

    OzFramework.core.minimap_button = create_minimap_button()
end

local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:SetScript("OnEvent", on_addon_loaded)
