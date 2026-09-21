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

if not OZAIO then
    OZAIO = {
        minimap_angle = 0,
        config_size = { width = 500, height = 600 },
    }
end

if not OZAIO.minimap_angle then
    OZAIO.minimap_angle = 0
end

if not OZAIO.config_size then
    OZAIO.config_size = { width = 500, height = 600 }
end

if not OZAIO.hs_bag then
    OZAIO.hs_bag = 0
end

if not OZAIO.hs_slot then
    OZAIO.hs_slot = 0
end


-- ==================== Categories ====================

local CATEGORY_LIST = {
    "General",
    "Chat",
    "Minimap",
    "Quest",
    "Actionbar",
    "Buff",
    "Bag",
    "Loot",
}

local CATEGORY_NORMALIZE = {
    ["general"]   = "General",
    ["chat"]      = "Chat",
    ["minimap"]   = "Minimap",
    ["quest"]     = "Quest",
    ["actionbar"] = "Actionbar",
    ["buff"]      = "Buff",
    ["bag"]       = "Bag",
    ["loot"]      = "Loot",
}

-- ==================== Localization ====================

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        if (LOCALE ~= "enUS") and (LOCALE ~= "enGB") then
            if OzLib and OzLib.print then
                OzLib.print("Locale fetch failed for framework " .. v, "error")
            end
        end
        return v
    end
})

if LOCALE == "zhCN" then
    L["OZAiO"] = "OZ工具箱"
    L["Click to Open/Close Settings"] = "点击打开/关闭设置"
    L["OZAiO Config"] = "OZ工具箱配置"
    L["General"] = "通用"
    L["Chat"] = "聊天"
    L["Minimap"] = "小地图"
    L["Quest"] = "任务"
    L["Actionbar"] = "动作条"
    L["Buff"] = "增益效果"
    L["Bag"] = "背包"
    L["Loot"] = "拾取"
    L["No modules registered in this category."] = "该分类下暂无已注册模块。"
    L["(Click to collapse)"] = "(点击折叠)"
    L["(Click to expand)"] = "(点击展开)"
    L["Click to collapse this section."] = "点击折叠此选项区域。"
    L["Click to expand this section."] = "点击展开此选项区域。"
end

-- ==================== Layout Aliases ====================

local MD = OzUIHelper.Metrics.dialog  -- dialog component sizes
local M  = OzUIHelper.Metrics         -- general widget sizes + minimap

-- Minimap asset paths
local MINIMAP_ASSETS = {
    icon      = "Interface\\Addons\\OzAiO\\texture\\ozicon.blp",
    border    = "Interface\\Minimap\\MiniMap-TrackingBorder",
    highlight = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}

-- ==================== Size Helper ====================

local function get_saved_size()
    local s = OZAIO.config_size or {}
    local w = tonumber(s.width) or MD.width or 500
    local h = tonumber(s.height) or MD.height or 600
    if w < 500 then w = 500 end
    if w > 900 then w = 900 end
    if h < 420 then h = 420 end
    if h > 850 then h = 850 end
    OZAIO.config_size = { width = w, height = h }
    return w, h
end

-- ==================== Module Registration ====================

-- Legacy registration: OzFramework:register(id, mod)
function OzFramework:register(id, mod)
    if OzFramework.core.modules[id] then
        return OzFramework.core.modules[id]
    end

    mod.id = id
    mod.config = mod.config or {}
    local norm = mod.category and CATEGORY_NORMALIZE[string.lower(mod.category)]
    mod.category = norm or "General"
    mod.order = mod.order or 50

    OzFramework.core.modules[id] = mod
    return mod
end

-- Modern registration: OzFramework:registerMod({ name, category, order, config_ui_creator, enable, disable })
function OzFramework:registerMod(opts)
    if not opts then return end
    local id = opts.id or opts.name
    if not id then return end

    if OzFramework.core.modules[id] then
        return OzFramework.core.modules[id]
    end

    local mod = opts
    mod.id = id
    mod.name = opts.name or id
    mod.title = opts.title or opts.name or id
    mod.config = opts.config or {}

    local cat = opts.category and CATEGORY_NORMALIZE[string.lower(opts.category)]
    mod.category = cat or "General"
    mod.order = opts.order or 50

    if mod.enabled == nil then
        mod.enabled = true
    end

    OzFramework.core.modules[id] = mod

    if OzFramework.core.initialized and mod.enabled and mod.enable then
        mod:enable()
    end

    return mod
end

local OBSOLETE_CONFIG_KEYS = {
    "quest.shared_accept",
    "minimap.hideSystemButtons",
    "worldbuff.autoLogout",
    "worldbuff.timerPos",
    "superwow.autoloot",
    "superwow.shiftloot",
    "superwow.clickthrough",
    "superwow.lootsparkle",
    "superwow.selectioncirclestyle",
    "superwow.backgroundsound",
    "superwow.uncappedsounds",
    "general.fontsize",
    "general.dismount",
    "general.stance",
    "chat.short_channel",
}

-- Merge module default config values into OZAIO_CONFIG for any missing keys
local function merge_config()
    if not OZAIO then
        OZAIO = {}
    end
    OZAIO.folded_modules = nil
    if not OZAIO_CONFIG then
        OZAIO_CONFIG = {}
    end
    for _, oldKey in ipairs(OBSOLETE_CONFIG_KEYS) do
        OZAIO_CONFIG[oldKey] = nil
    end
    for _, mod in pairs(OzFramework.core.modules) do
        if mod.config then
            for key, value in pairs(mod.config) do
                if OZAIO_CONFIG[key] == nil then
                    if type(value) == "table" then
                        local copy = {}
                        for tk, tv in pairs(value) do copy[tk] = tv end
                        OZAIO_CONFIG[key] = copy
                    else
                        OZAIO_CONFIG[key] = value
                    end
                end
            end
        end
    end
end

-- ==================== Table-Driven UI Schema Interpreter ====================

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
        if item.get then
            return item.get()
        elseif item.config_key and OZAIO_CONFIG then
            return OZAIO_CONFIG[item.config_key]
        end
        return item.default
    end

    local function set_value(val)
        if item.set then
            item.set(val)
        elseif item.config_key and OZAIO_CONFIG then
            OZAIO_CONFIG[item.config_key] = val
        end
        if item.onChange then
            item.onChange(val)
        end
    end

    if itype == "checkbox" or itype == "toggle" then
        widget = OzUIHelper:createCheckbox(parent, item.label or "", get_value(), function(checked)
            set_value(checked)
        end)
        attach_tooltip(widget, item.tooltip, item.label)

    elseif itype == "dropdown" or itype == "select" then
        widget = OzUIHelper:createDropdown(parent, item.label or "", item.options or {}, get_value(), function(val)
            set_value(val)
        end)
        attach_tooltip(widget, item.tooltip, item.label)

    elseif itype == "slider" or itype == "range" then
        widget = OzUIHelper:createSlider(parent, item.label or "", item.min or 0, item.max or 100, item.step or 1, get_value(), function(val)
            set_value(val)
        end, item.width)
        attach_tooltip(widget, item.tooltip, item.label)

    elseif itype == "editbox" or itype == "text" then
        widget = OzUIHelper:createLabeledEditBox(parent, (item.label or "") .. ":", item.width or 60)
        local val = get_value()
        if val ~= nil then widget:SetValue(val) end
        widget:SetCallback(function(newVal)
            set_value(newVal)
        end)
        attach_tooltip(widget, item.tooltip, item.label)

    elseif itype == "button" or itype == "execute" then
        widget = OzUIHelper:createButton(parent, item.label or "", function()
            if item.func then item.func() end
        end, item.width, item.height)
        attach_tooltip(widget, item.tooltip, item.label)

    elseif itype == "header" then
        widget = OzUIHelper:createHeader(parent, item.label or "")

    elseif itype == "label" then
        local fs = OzUIHelper:createLabel(parent, item.label or "", item.font or OzUIHelper.Fonts.normal)
        if item.color then
            fs:SetTextColor(unpack(item.color))
        end
        widget = fs

    elseif itype == "separator" then
        widget = OzUIHelper:createSeparator(parent, item.width)

    elseif itype == "itemlist" then
        local listWidget = OzUIHelper:createScrollItemList(parent, item.opts or {})
        if listWidget and listWidget.refresh then listWidget:refresh() end
        widget = listWidget and listWidget.scrollFrame or nil

    elseif itype == "custom" and type(item.create) == "function" then
        widget = item.create(parent)
    end

    return widget
end

local function build_schema_ui(panel, creator, mod)
    local schema = creator
    if type(creator) == "function" then
        schema = creator(panel)
    end
    if not schema then return end

    -- Support returning a frame directly from creator
    if type(schema) == "table" and (schema.IsObjectType or schema.frame) then
        local f = schema.frame or schema
        local h = schema.height or (f.GetHeight and f:GetHeight()) or 200
        f._fullWidth = true
        panel:Add(f, { height = h, fullWidth = true })
        return
    end

    if type(schema) ~= "table" then return end

    for _, item in ipairs(schema) do
        if type(item) == "table" then
            local itype = item.type and string.lower(item.type) or "label"
            if itype == "space" then
                panel:AddSpace(item.height or 8)
            elseif itype == "row" and type(item.items) == "table" then
                local rowWidgets = {}
                for _, subItem in ipairs(item.items) do
                    local w = create_schema_widget(panel.scrollChild, subItem)
                    if w then
                        table.insert(rowWidgets, w)
                    end
                end
                if table.getn(rowWidgets) > 0 then
                    panel:AddRow(rowWidgets, { rowSpacing = item.rowSpacing })
                end
            else
                local w = create_schema_widget(panel.scrollChild, item)
                if w then
                    panel:Add(w, {
                        height = item.height,
                        fullWidth = item.fullWidth or (itype == "header"),
                    })
                end
            end
        end
    end
end

-- ==================== Config UI Construction ====================

local function create_config_ui()
    if OzFramework.core.config_frame then return end

    local initW, initH = get_saved_size()

    local frame = CreateFrame("Frame", "OzAiOConfigFrame", UIParent)
    frame:SetWidth(initW)
    frame:SetHeight(initH)
    OzUIHelper:anchor(frame, UIParent, "CENTER", "CENTER", 0, 0)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true, tileSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    -- Movable & Resizable (min: 500x420, max: 900x850)
    OzUIHelper:makeMovable(frame)
    frame:SetResizable(true)
    frame:SetMinResize(500, 420)
    frame:SetMaxResize(900, 850)
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

    -- Border overlay (renders above header in Z-order)
    local borderOverlay = CreateFrame("Frame", nil, frame)
    borderOverlay:SetAllPoints(frame)
    borderOverlay:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
    })

    -- Resize grabber handle (bottom-right)
    local grabber = CreateFrame("Button", nil, frame)
    grabber:SetWidth(16)
    grabber:SetHeight(16)
    grabber:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 7)
    grabber:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grabber:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grabber:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grabber:SetFrameLevel(frame:GetFrameLevel() + 10)
    grabber:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grabber:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local w, h = frame:GetWidth(), frame:GetHeight()
        OZAIO.config_size.width = w
        OZAIO.config_size.height = h
    end)

    -- Tab + Content layout
    local LM = MD.main

    local tabFrame = CreateFrame("Frame", nil, frame)
    tabFrame:ClearAllPoints()
    OzUIHelper:anchor(tabFrame, frame, "TOPLEFT",    "TOPLEFT",    LM.margin, LM.topOffset)
    OzUIHelper:anchor(tabFrame, frame, "BOTTOMLEFT", "BOTTOMLEFT", LM.margin, LM.bottomOffset)
    tabFrame:SetWidth(MD.tab.width)
    OzUIHelper:applyBackdrop(tabFrame, "panel")

    local contentContainer = CreateFrame("Frame", nil, frame)
    contentContainer:ClearAllPoints()
    OzUIHelper:anchor(contentContainer, tabFrame, "TOPLEFT",     "TOPRIGHT", LM.gap, 0)
    OzUIHelper:anchor(contentContainer, frame,    "BOTTOMRIGHT", "BOTTOMRIGHT", -LM.margin, LM.bottomOffset)
    OzUIHelper:applyBackdrop(contentContainer, "panel")

    local category_panels = {}
    local tab_buttons = {}
    local active_category = nil

    local function update_layout()
        local h = frame:GetHeight()
        tabFrame:SetHeight(h - math.abs(LM.topOffset) - LM.bottomOffset)
        local w = frame:GetWidth()
        OZAIO.config_size.width = w
        OZAIO.config_size.height = h
    end

    OzUIHelper:onResize(frame, update_layout)
    update_layout()

    -- Category Panel Factory
    local function get_category_panel(catName)
        if category_panels[catName] then
            return category_panels[catName]
        end

        local panel = OzUIHelper:createScrollPanel(contentContainer, {
            padding = 6,
            spacing = 2,
            rowSpacing = 4,
            step = 20,
            backdropStyle = "flat",
        })
        panel.scrollFrame:SetAllPoints(contentContainer)
        panel.scrollFrame:SetBackdropColor(0, 0, 0, 0)
        panel.scrollFrame:SetBackdropBorderColor(0, 0, 0, 0)

        -- Find all modules for this category
        local catMods = {}
        for _, mod in pairs(OzFramework.core.modules) do
            if mod.category and string.lower(mod.category) == string.lower(catName) then
                table.insert(catMods, mod)
            end
        end
        table.sort(catMods, function(a, b)
            local oa = a.order or 50
            local ob = b.order or 50
            return oa < ob
        end)

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

                if not sec.isFolded then
                    for _, item in ipairs(sec.items) do
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
                                local ww = (w._layout and w._layout.width)
                                        or (w.GetStringWidth and w:GetStringWidth())
                                        or (w.GetWidth and w:GetWidth())
                                        or 100
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
                else
                    for _, item in ipairs(sec.items) do
                        if item.type == "widget" then
                            item.widget:Hide()
                        elseif item.type == "row" then
                            for _, w in ipairs(item.widgets) do
                                w:Hide()
                            end
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
                if type(schema) == "function" then
                    schema = schema(panel)
                end

                local isFolded = false  -- Expand all by default; do not persist folding state

                local secHeader = nil
                local section = nil
                secHeader = OzUIHelper:createFoldableHeader(panel.scrollChild, headerTitle, isFolded, function(btn)
                    local header = btn or secHeader or (section and section.header)
                    section.isFolded = not section.isFolded
                    if header and header.SetFolded then
                        header:SetFolded(section.isFolded)
                    end
                    panel:RelayoutSections()
                end, L)

                section = {
                    mod = mod,
                    header = secHeader,
                    headerHeight = 20,
                    isFoldable = true,
                    isFolded = isFolded,
                    items = {},
                    spaceAfter = (modIdx < table.getn(catMods)) and 6 or 0,
                }

                if schema then
                    if type(schema) == "table" and (schema.IsObjectType or schema.frame) then
                        local f = schema.frame or schema
                        local h = schema.height or (f.GetHeight and f:GetHeight()) or 200
                        f._fullWidth = true
                        table.insert(section.items, {
                            type = "widget",
                            widget = f,
                            height = h,
                            fullWidth = true,
                        })
                        table.insert(panel.widgets, f)
                    elseif type(schema) == "table" then
                        for _, item in ipairs(schema) do
                            if type(item) == "table" then
                                local itype = item.type and string.lower(item.type) or "label"
                                if itype == "space" then
                                    table.insert(section.items, {
                                        type = "space",
                                        height = item.height or 8,
                                    })
                                elseif itype == "row" and type(item.items) == "table" then
                                    local rowWidgets = {}
                                    local maxH = 0
                                    for _, subItem in ipairs(item.items) do
                                        local w = create_schema_widget(panel.scrollChild, subItem)
                                        if w then
                                            local wh = (w._layout and w._layout.height)
                                                    or (w.GetStringHeight and w:GetStringHeight())
                                                    or (w.GetHeight and w:GetHeight())
                                                    or 18
                                            if wh > maxH then maxH = wh end
                                            table.insert(rowWidgets, w)
                                            table.insert(panel.widgets, w)
                                        end
                                    end
                                    if maxH <= 0 then maxH = 18 end
                                    if table.getn(rowWidgets) > 0 then
                                        table.insert(section.items, {
                                            type = "row",
                                            widgets = rowWidgets,
                                            height = maxH,
                                            rowSpacing = item.rowSpacing,
                                        })
                                    end
                                else
                                    local w = create_schema_widget(panel.scrollChild, item)
                                    if w then
                                        local wh = item.height
                                        if not wh then
                                            if w._layout and w._layout.height and w._layout.height > 0 then
                                                wh = w._layout.height
                                            elseif w.GetStringHeight and w:GetStringHeight() and w:GetStringHeight() > 0 then
                                                wh = w:GetStringHeight()
                                            elseif w.GetHeight and w:GetHeight() and w:GetHeight() > 0 then
                                                wh = w:GetHeight()
                                            else
                                                wh = 18
                                            end
                                        end
                                        table.insert(section.items, {
                                            type = "widget",
                                            widget = w,
                                            height = wh,
                                            fullWidth = item.fullWidth or (itype == "header"),
                                        })
                                        table.insert(panel.widgets, w)
                                    end
                                end
                            end
                        end
                    end
                elseif mod.create_config_panel then
                    local sectionFrame = CreateFrame("Frame", nil, panel.scrollChild)
                    local usableW = panel.scrollChild:GetWidth()
                    if usableW and usableW > panel.padding * 2 then
                        sectionFrame:SetWidth(usableW - panel.padding * 2)
                    else
                        sectionFrame:SetWidth(MD.width - MD.tab.width - 60)
                    end

                    local result = mod:create_config_panel(sectionFrame)
                    local secH = 200
                    if type(result) == "table" and result.frame then
                        secH = result.height or result.frame:GetHeight()
                        OzFramework.core.module_frames[mod.id] = result.frame
                    elseif type(result) == "table" and result.GetHeight then
                        secH = result:GetHeight()
                        OzFramework.core.module_frames[mod.id] = result
                    end
                    if secH <= 0 then secH = 200 end

                    sectionFrame:SetHeight(secH)
                    sectionFrame._layout = { width = sectionFrame:GetWidth(), height = secH }
                    sectionFrame._fullWidth = true
                    table.insert(section.items, {
                        type = "widget",
                        widget = sectionFrame,
                        height = secH,
                        fullWidth = true,
                    })
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
        active_category = catName
        for name, p in pairs(category_panels) do
            if p and p.scrollFrame then
                p.scrollFrame:Hide()
            end
        end

        for name, btn in pairs(tab_buttons) do
            if name == catName then
                btn:LockHighlight()
                local btnText = btn:GetFontString()
                if btnText then btnText:SetTextColor(1, 0.82, 0) end
            else
                btn:UnlockHighlight()
                local btnText = btn:GetFontString()
                if btnText then btnText:SetTextColor(1, 1, 1) end
            end
        end

        local catPanel = get_category_panel(catName)
        if catPanel and catPanel.scrollFrame then
            if catPanel.UpdateDimensions then
                catPanel:UpdateDimensions()
            end
            catPanel.scrollFrame:Show()
            catPanel:UpdateScroll()
        end
    end

    -- Tab buttons (Left Panel: 7 Fixed Categories)
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

    -- Initial tab selection
    local initialTab = OzFramework.core.default_tab or "General"
    local norm = CATEGORY_NORMALIZE[string.lower(initialTab)]
    select_category(norm or "General")

    OzFramework.core.config_frame = frame
    OzFramework.core.config_tab_frame = tabFrame
    OzFramework.core.config_content_frame = contentContainer
    OzFramework.core.category_panels = category_panels
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

-- ==================== Slash Commands ====================

SLASH_OZAIO1 = "/oz"
SLASH_OZAIO2 = "/ozaio"
SlashCmdList["OZAIO"] = function()
    toggle_config_ui()
end

-- ==================== Minimap Button ====================

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

-- ==================== Initialization ====================

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

