-- OzFramework Meta Class
if OzFramework and OzFramework.loaded then return end
OzFramework = OzFramework or {}
OzFramework.loaded = true

OzFramework.core = {
    name = "OzAiO",
    modules = {},
    module_frames = {},
    category_panels = {},
    config_frame = nil,
    minimap_button = nil,
    config_tab_frame = nil,
    config_content_frame = nil,
    default_tab = "General",
    initialized = false,
}

OZAIO = OZAIO or {}
OZAIO.minimap_angle = OZAIO.minimap_angle or 0
OZAIO.config_size = OZAIO.config_size or { width = 500, height = 600 }
OZAIO.hs_bag = OZAIO.hs_bag or 0
OZAIO.hs_slot = OZAIO.hs_slot or 0

-- ==================== Categories & Localization ====================

local CATEGORY_LIST = { "General", "Chat", "Minimap", "Quest", "Actionbar", "Buff", "Bag", "Loot" }
local CATEGORY_NORMALIZE = {}
for _, c in ipairs(CATEGORY_LIST) do CATEGORY_NORMALIZE[string.lower(c)] = c end

local LOCALE = GetLocale()
local L = setmetatable(LOCALE == "zhCN" and {
    ["OZAiO"] = "OZ工具箱", ["Click to Open/Close Settings"] = "点击打开/关闭设置",
    ["OZAiO Config"] = "OZ工具箱配置", ["General"] = "通用", ["Chat"] = "聊天",
    ["Minimap"] = "小地图", ["Quest"] = "任务", ["Actionbar"] = "动作条",
    ["Buff"] = "增益效果", ["Bag"] = "背包", ["Loot"] = "拾取",
    ["No modules registered in this category."] = "该分类下暂无已注册模块。",
    ["(Click to collapse)"] = "(点击折叠)", ["(Click to expand)"] = "(点击展开)",
    ["Click to collapse this section."] = "点击折叠此选项区域。",
    ["Click to expand this section."] = "点击展开此选项区域。",
} or {}, { __index = function(t, k) local v = tostring(k); rawset(t, k, v); return v end })

local OzUIHelper     = OzUIHelper:New("OzAiO")
local MD             = OzUIHelper.Metrics.dialog
local M              = OzUIHelper.Metrics

local MINIMAP_ASSETS = {
    icon      = "Interface\\Addons\\OzAiO\\texture\\ozicon.blp",
    border    = "Interface\\Minimap\\MiniMap-TrackingBorder",
    highlight = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}

-- ==================== Helpers ====================

local function get_saved_size()
    local s = OZAIO.config_size or {}
    local w = math.max(500, math.min(900, tonumber(s.width) or MD.width or 500))
    local h = math.max(420, math.min(850, tonumber(s.height) or MD.height or 600))
    OZAIO.config_size = { width = w, height = h }
    return w, h
end

local function widget_h(w, defaultH)
    return (w._layout and w._layout.height and w._layout.height > 0 and w._layout.height)
        or (w.GetHeight and w:GetHeight() and w:GetHeight() > 0 and w:GetHeight())
        or defaultH or 18
end

local function widget_w(w, defaultW)
    return (w._layout and w._layout.width)
        or (w.GetStringWidth and w:GetStringWidth())
        or (w.GetWidth and w:GetWidth())
        or defaultW or 100
end

-- ==================== Module Registration ====================

function OzFramework:registerMod(opts)
    if not opts then return end
    local id = opts.id or opts.name
    if not id then return end
    if OzFramework.core.modules[id] then return OzFramework.core.modules[id] end

    local mod = opts
    mod.id = id
    mod.name = opts.name or id
    mod.title = opts.title or opts.name or id
    mod.config = opts.config or {}
    mod.category = (opts.category and CATEGORY_NORMALIZE[string.lower(opts.category)]) or "General"
    mod.order = opts.order or 50
    if mod.enabled == nil then mod.enabled = true end

    OzFramework.core.modules[id] = mod
    if OzFramework.core.initialized and mod.enabled and mod.enable then mod:enable() end
    return mod
end

local function merge_config()
    OZAIO = OZAIO or {}
    OZAIO_CONFIG = OZAIO_CONFIG or {}
    OZAIO.folded_modules = nil
    for _, mod in pairs(OzFramework.core.modules) do
        if mod.config then
            for k, v in pairs(mod.config) do
                if OZAIO_CONFIG[k] == nil then
                    if type(v) == "table" then
                        local copy = {}
                        for tk, tv in pairs(v) do copy[tk] = tv end
                        OZAIO_CONFIG[k] = copy
                    else
                        OZAIO_CONFIG[k] = v
                    end
                end
            end
        end
    end
end

-- ==================== Schema Widget Creation ====================

local function attach_tooltip(widget, tooltipText, tooltipTitle)
    if not tooltipText or not widget then return end
    local target = widget.checkbox or widget.slider or widget.editBox or widget
    if target and target.SetScript then
        local oldEnter = target:GetScript("OnEnter")
        local oldLeave = target:GetScript("OnLeave")
        target:SetScript("OnEnter", function()
            if oldEnter then oldEnter() end
            OzUIHelper:showTooltip(this, tooltipTitle, tooltipText, "ANCHOR_TOPLEFT")
        end)
        target:SetScript("OnLeave", function()
            if oldLeave then oldLeave() end
            OzUIHelper:hideTooltip()
        end)
    end
end

local function create_schema_widget(parent, item)
    if not item or type(item) ~= "table" then return nil end
    local itype = item.type and string.lower(item.type) or "label"
    local widget = nil

    local function get_value()
        if item.get then return item.get() end
        if item.config_key and OZAIO_CONFIG then return OZAIO_CONFIG[item.config_key] end
        return item.default
    end

    local function set_value(val)
        if item.set then item.set(val) end
        if item.config_key and OZAIO_CONFIG then OZAIO_CONFIG[item.config_key] = val end
        if item.onChange then item.onChange(val) end
    end

    if itype == "checkbox" or itype == "toggle" then
        widget = OzUIHelper:createCheckbox(parent, item.label or "", get_value(), set_value)
    elseif itype == "dropdown" or itype == "select" then
        widget = OzUIHelper:createDropdown(parent, item.label or "", item.options or {}, get_value(), set_value)
    elseif itype == "slider" or itype == "range" then
        widget = OzUIHelper:createSlider(parent, item.label or "", item.min or 0, item.max or 100, item.step or 1, get_value(), set_value, item.width)
    elseif itype == "editbox" or itype == "text" then
        widget = OzUIHelper:createLabeledEditBox(parent, (item.label or "") .. ":", item.width or 60)
        local val = get_value()
        if val ~= nil then widget:SetValue(val) end
        widget:SetCallback(set_value)
    elseif itype == "editarea" or itype == "textarea" then
        widget = OzUIHelper:createLabeledEditArea(parent, item.label or "", item.width or 280, item.height or 60)
        local val = get_value()
        if val ~= nil then widget:SetValue(val) end
        widget:SetCallback(set_value)
        if item.onCreated then item.onCreated(widget) end
    elseif itype == "button" or itype == "execute" then
        widget = OzUIHelper:createButton(parent, item.label or "", function() if item.func then item.func() end end, item.width, item.height)
    elseif itype == "header" then
        widget = OzUIHelper:createHeader(parent, item.label or "")
    elseif itype == "label" then
        widget = OzUIHelper:createLabel(parent, item.label or item.text or "", item.font or OzUIHelper.Fonts.normal)
        if item.color then widget:SetTextColor(unpack(item.color)) end
    elseif itype == "separator" then
        widget = OzUIHelper:createSeparator(parent, item.width)
    elseif itype == "itemlist" then
        local listWidget = OzUIHelper:createScrollItemList(parent, item.opts or {})
        if listWidget and listWidget.refresh then listWidget:refresh() end
        widget = listWidget and listWidget.scrollFrame or nil
    elseif itype == "custom" and type(item.create) == "function" then
        widget = item.create(parent)
    end

    if widget and item.tooltip then
        attach_tooltip(widget, item.tooltip, item.label)
    end

    return widget
end

-- ==================== Config UI Construction ====================

local function create_config_ui()
    if OzFramework.core.config_frame then return end

    local initW, initH = get_saved_size()
    local frame = CreateFrame("Frame", "OzAiOConfigFrame", UIParent)
    frame:SetWidth(initW); frame:SetHeight(initH)
    OzUIHelper:anchor(frame, UIParent, "CENTER", "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true, tileSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    OzUIHelper:makeMovable(frame)
    frame:SetResizable(true)
    frame:SetMinResize(500, 420); frame:SetMaxResize(900, 850)
    frame:Hide()

    -- Title bar
    local H = MD.header
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", H.insetL, -H.insetT)
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
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local borderOverlay = CreateFrame("Frame", nil, frame)
    borderOverlay:SetAllPoints(frame)
    borderOverlay:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32 })

    local grabber = CreateFrame("Button", nil, frame)
    grabber:SetWidth(16); grabber:SetHeight(16)
    grabber:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 7)
    grabber:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grabber:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grabber:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grabber:SetFrameLevel(frame:GetFrameLevel() + 10)
    grabber:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grabber:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        OZAIO.config_size.width, OZAIO.config_size.height = frame:GetWidth(), frame:GetHeight()
    end)

    -- Tab + Content layout
    local LM = MD.main
    local tabFrame = CreateFrame("Frame", nil, frame)
    OzUIHelper:anchor(tabFrame, frame, "TOPLEFT", "TOPLEFT", LM.margin, LM.topOffset)
    OzUIHelper:anchor(tabFrame, frame, "BOTTOMLEFT", "BOTTOMLEFT", LM.margin, LM.bottomOffset)
    tabFrame:SetWidth(MD.tab.width)
    OzUIHelper:applyBackdrop(tabFrame, "panel")

    local contentContainer = CreateFrame("Frame", nil, frame)
    OzUIHelper:anchor(contentContainer, tabFrame, "TOPLEFT", "TOPRIGHT", LM.gap, 0)
    OzUIHelper:anchor(contentContainer, frame, "BOTTOMRIGHT", "BOTTOMRIGHT", -LM.margin, LM.bottomOffset)
    OzUIHelper:applyBackdrop(contentContainer, "panel")

    local category_panels = {}
    local tab_buttons = {}

    local function update_layout()
        tabFrame:SetHeight(frame:GetHeight() - math.abs(LM.topOffset) - LM.bottomOffset)
        OZAIO.config_size.width, OZAIO.config_size.height = frame:GetWidth(), frame:GetHeight()
    end
    OzUIHelper:onResize(frame, update_layout)
    update_layout()

    -- Category Panel Factory
    local function get_category_panel(catName)
        if category_panels[catName] then return category_panels[catName] end

        local panel = OzUIHelper:createScrollPanel(contentContainer, {
            padding = 6, spacing = 2, rowSpacing = 4, step = 20, backdropStyle = "flat",
        })
        panel.scrollFrame:SetAllPoints(contentContainer)
        panel.scrollFrame:SetBackdropColor(0, 0, 0, 0)
        panel.scrollFrame:SetBackdropBorderColor(0, 0, 0, 0)

        local catMods = {}
        for _, mod in pairs(OzFramework.core.modules) do
            if mod.category and string.lower(mod.category) == string.lower(catName) then
                table.insert(catMods, mod)
            end
        end
        table.sort(catMods, function(a, b) return (a.order or 50) < (b.order or 50) end)

        panel.sections = {}

        function panel:RelayoutSections()
            local y = -self.padding
            local sw = self.scrollChild:GetWidth()
            if not sw or sw <= 0 then
                local sfw = self.scrollFrame:GetWidth()
                if sfw and sfw > self.rightInset then
                    sw = sfw - self.rightInset
                    self.scrollChild:SetWidth(sw)
                end
            end
            local innerW = (sw and sw > self.padding * 2) and (sw - self.padding * 2) or 300

            for _, sec in ipairs(self.sections) do
                if sec.header then
                    sec.header:ClearAllPoints()
                    sec.header:SetParent(self.scrollChild)
                    sec.header:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", self.padding, y)
                    if innerW > 0 and sec.header.SetWidth then
                        sec.header:SetWidth(innerW)
                        if sec.header._layout then sec.header._layout.width = innerW end
                    end
                    sec.header:Show()
                    y = y - sec.headerHeight - self.spacing
                end

                for _, item in ipairs(sec.items) do
                    if sec.isFolded then
                        if item.type == "widget" then item.widget:Hide()
                        elseif item.type == "row" then
                            for _, w in ipairs(item.widgets) do w:Hide() end
                        end
                    else
                        if item.type == "widget" then
                            local w = item.widget
                            w:ClearAllPoints()
                            w:SetParent(self.scrollChild)
                            w:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", self.padding, y)
                            if item.fullWidth and innerW > 0 and w.SetWidth then
                                w:SetWidth(innerW)
                                if w._layout then w._layout.width = innerW end
                            end
                            w:Show()
                            y = y - item.height - self.spacing
                        elseif item.type == "row" then
                            local x = self.padding
                            for _, w in ipairs(item.widgets) do
                                local ww = widget_w(w, 100)
                                w:ClearAllPoints()
                                w:SetParent(self.scrollChild)
                                w:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", x, y)
                                w:Show()
                                x = x + ww + (item.rowSpacing or self.rowSpacing)
                            end
                            y = y - item.height - self.spacing
                        elseif item.type == "space" then
                            y = y - item.height
                        end
                    end
                end

                if sec.spaceAfter and sec.spaceAfter > 0 then
                    y = y - sec.spaceAfter
                end
            end

            self.currentY = y
            self:UpdateScroll()
        end

        if table.getn(catMods) == 0 then
            local emptyLabel = OzUIHelper:createLabel(panel.scrollChild, L["No modules registered in this category."], "GameFontNormalSmall")
            emptyLabel:SetTextColor(0.5, 0.5, 0.5)
            panel:Add(emptyLabel, { height = 24 })
        else
            for modIdx, mod in ipairs(catMods) do
                local headerTitle = mod.title or mod.name or mod.id
                local schema = mod.config_ui_creator
                if type(schema) == "function" then schema = schema(panel) end

                local isSingleOption = false
                if type(schema) == "table" and not (schema.IsObjectType or schema.frame) then
                    local count = 0
                    for _, item in ipairs(schema) do
                        if type(item) == "table" then
                            local it = item.type and string.lower(item.type) or "label"
                            if it == "row" and type(item.items) == "table" then
                                for _, sub in ipairs(item.items) do
                                    local st = sub.type and string.lower(sub.type) or "label"
                                    if st ~= "space" and st ~= "label" and st ~= "header" then count = count + 1 end
                                end
                            elseif it ~= "space" and it ~= "label" and it ~= "header" then
                                count = count + 1
                            end
                        end
                    end
                    isSingleOption = (count <= 1)
                end

                local secHeader = nil
                local section = nil
                if not isSingleOption then
                    secHeader = OzUIHelper:createFoldableHeader(panel.scrollChild, headerTitle, false, function(btn)
                        local hdr = btn or secHeader or (section and section.header)
                        section.isFolded = not section.isFolded
                        if hdr and hdr.SetFolded then hdr:SetFolded(section.isFolded) end
                        panel:RelayoutSections()
                    end, L)
                end

                section = {
                    mod = mod,
                    header = secHeader,
                    headerHeight = secHeader and 20 or 0,
                    isFoldable = (secHeader ~= nil),
                    isFolded = false,
                    items = {},
                    spaceAfter = (modIdx < table.getn(catMods)) and 6 or 0,
                }

                if schema then
                    if type(schema) == "table" and (schema.IsObjectType or schema.frame) then
                        local f = schema.frame or schema
                        local h = widget_h(f, schema.height or 200)
                        f._fullWidth = true
                        table.insert(section.items, { type = "widget", widget = f, height = h, fullWidth = true })
                        table.insert(panel.widgets, f)
                    elseif type(schema) == "table" then
                        for _, item in ipairs(schema) do
                            if type(item) == "table" then
                                local itype = item.type and string.lower(item.type) or "label"
                                if itype == "space" then
                                    table.insert(section.items, { type = "space", height = item.height or 8 })
                                elseif itype == "row" and type(item.items) == "table" then
                                    local rowWidgets, maxH = {}, 0
                                    for _, sub in ipairs(item.items) do
                                        if isSingleOption and (sub.label == nil or sub.label == "") then sub.label = headerTitle end
                                        local w = create_schema_widget(panel.scrollChild, sub)
                                        if w then
                                            local wh = widget_h(w, 18)
                                            if wh > maxH then maxH = wh end
                                            table.insert(rowWidgets, w)
                                            table.insert(panel.widgets, w)
                                        end
                                    end
                                    if table.getn(rowWidgets) > 0 then
                                        table.insert(section.items, { type = "row", widgets = rowWidgets, height = maxH > 0 and maxH or 18, rowSpacing = item.rowSpacing })
                                    end
                                else
                                    if isSingleOption and (item.label == nil or item.label == "") then item.label = headerTitle end
                                    local w = create_schema_widget(panel.scrollChild, item)
                                    if w then
                                        local wh = widget_h(w, item.height or 18)
                                        table.insert(section.items, { type = "widget", widget = w, height = wh, fullWidth = item.fullWidth or (itype == "header") })
                                        table.insert(panel.widgets, w)
                                    end
                                end
                            end
                        end
                    end
                elseif mod.create_config_panel then
                    local sectionFrame = CreateFrame("Frame", nil, panel.scrollChild)
                    local usableW = panel.scrollChild:GetWidth()
                    sectionFrame:SetWidth((usableW and usableW > panel.padding * 2) and (usableW - panel.padding * 2) or (MD.width - MD.tab.width - 60))

                    local result = mod:create_config_panel(sectionFrame)
                    local secH = (type(result) == "table" and (result.height or (result.frame and result.frame:GetHeight()) or (result.GetHeight and result:GetHeight()))) or 200
                    if type(result) == "table" then
                        OzFramework.core.module_frames[mod.id] = result.frame or result
                    end
                    if secH <= 0 then secH = 200 end

                    sectionFrame:SetHeight(secH)
                    sectionFrame._layout = { width = sectionFrame:GetWidth(), height = secH }
                    sectionFrame._fullWidth = true
                    table.insert(section.items, { type = "widget", widget = sectionFrame, height = secH, fullWidth = true })
                    table.insert(panel.widgets, sectionFrame)
                end

                table.insert(panel.sections, section)
            end

            panel:RelayoutSections()
        end

        category_panels[catName] = panel
        return panel
    end

    local function select_category(catName)
        for _, p in pairs(category_panels) do
            if p and p.scrollFrame then p.scrollFrame:Hide() end
        end

        for name, btn in pairs(tab_buttons) do
            local btnText = btn:GetFontString()
            if name == catName then
                btn:LockHighlight()
                if btnText then btnText:SetTextColor(1, 0.82, 0) end
            else
                btn:UnlockHighlight()
                if btnText then btnText:SetTextColor(1, 1, 1) end
            end
        end

        local catPanel = get_category_panel(catName)
        if catPanel and catPanel.scrollFrame then
            if catPanel.UpdateDimensions then catPanel:UpdateDimensions() end
            catPanel.scrollFrame:Show()
            catPanel:UpdateScroll()
        end
    end

    -- Tab buttons
    local tabFlow = OzUIHelper:createFlow(tabFrame, 8)
    OzUIHelper:onResize(tabFrame, function(f, w)
        tabFlow.maxWidth = w - MD.tab.flowPad
        OzUIHelper:rebuildFlow(tabFlow)
    end)

    for _, catName in ipairs(CATEGORY_LIST) do
        local localizedName = L[catName] or catName
        local capCat = catName
        local btn = OzUIHelper:createButton(tabFrame, localizedName, function()
            select_category(capCat)
        end, MD.tab.btnW, MD.tab.btnH + 6)

        tab_buttons[catName] = btn
        OzUIHelper:add(tabFlow, btn, MD.tab.btnW, MD.tab.btnH + 6)
        OzUIHelper:newLine(tabFlow)
    end

    local initialTab = OzFramework.core.default_tab or "General"
    select_category(CATEGORY_NORMALIZE[string.lower(initialTab)] or "General")

    OzFramework.core.config_frame = frame
    OzFramework.core.config_tab_frame = tabFrame
    OzFramework.core.config_content_frame = contentContainer
    OzFramework.core.category_panels = category_panels
end

local function toggle_config_ui()
    if not OzFramework.core.config_frame then create_config_ui() end
    if OzFramework.core.config_frame:IsShown() then
        OzFramework.core.config_frame:Hide()
    else
        OzFramework.core.config_frame:Show()
    end
end

-- ==================== Slash Commands ====================

SLASH_OZAIO1 = "/oz"
SLASH_OZAIO2 = "/ozaio"
SlashCmdList["OZAIO"] = toggle_config_ui

-- ==================== Minimap Button ====================

local function create_minimap_button()
    if OzFramework.core.minimap_button then return OzFramework.core.minimap_button end

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
    return button
end

-- ==================== Shift-Click Item Links ====================

local function hook_shift_click_insert()
    local function try_insert(text)
        local ea = OzUIHelper and OzUIHelper._activeEditArea
        if ea and ea:IsVisible() and text then
            ea:Insert(text)
            return false
        end
    end

    OzHook:hook("ContainerFrameItemButton_OnClick", function(button, ignoreShift)
        if button == "LeftButton" and IsShiftKeyDown() and not ignoreShift then
            local parent = this:GetParent()
            local bag, slot = parent and parent:GetID(), this:GetID()
            if bag and slot then return try_insert(GetContainerItemLink(bag, slot)) end
        end
    end)

    OzHook:hook("PaperDollItemSlotButton_OnClick", function(button, ignoreShift)
        if button == "LeftButton" and IsShiftKeyDown() and not ignoreShift then
            local slot = this:GetID()
            if slot then return try_insert(GetInventoryItemLink("player", slot)) end
        end
    end)

    OzHook:hook("SetItemRef", function(link, text, button)
        if IsShiftKeyDown() then return try_insert(text or link) end
    end)
end

-- ==================== Initialization ====================

local function on_addon_loaded()
    if arg1 ~= OzFramework.core.name or OzFramework.core.initialized then return end
    merge_config()
    OzFramework.core.initialized = true
    hook_shift_click_insert()

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
