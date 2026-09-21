-- OzUIHelper: automatic-layout UI helpers for WoW 1.12
--
-- Widgets self-size where possible. Flow layout auto-wraps.
--   flow:add(widget)           -- uses widget._layout for size
--   flow:add(widget, 100, 20)  -- explicit size (backward compat)

OzUIHelper = { _id = 0 }

-- ==================== Typography (font objects) ====================

OzUIHelper.Fonts = {
    normal = "GameFontNormal",
    small  = "GameFontNormalSmall",
    large  = "GameFontNormalLarge",
    huge   = "GameFontNormalHuge",
}

-- ==================== Theme (visual) ====================

OzUIHelper.Theme = {
    backdrop = {
        widget = {
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        },
        panel = {
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        },
        blizaad = {
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        },
        flat = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        },
        dropdownItem = {
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        },
    },

    color = {
        widget        = { bg = {0.05,0.05,0.05,0.8},  border = {0.3,0.3,0.3,0.8} },
        panel         = { bg = {0.05,0.05,0.08,0.6},  border = {0.2,0.2,0.3,0.5} },
        dropdownItem  = { bg = {0.05,0.05,0.05,0.8},  border = {0.15,0.15,0.15,0.3} },
        dropdownHover = { bg = {0.2,0.2,0.3,0.9},      border = {0.4,0.4,0.6,0.8} },
    },

    dropdown = {
        height        = 22,
        minWidth      = 80,
        padding       = 6,
        arrowPadding  = 6,
        menuPadX      = 2,
        menuPadY      = 2,
        itemHeight    = 20,
        itemSpacing   = 0,
        labelGap      = 8,
    },
}

-- Backward-compat aliases
OzUIHelper.BlizaadBackdrop = OzUIHelper.Theme.backdrop.blizaad
OzUIHelper.PFUIBackdrop    = OzUIHelper.Theme.backdrop.flat

-- ==================== Metrics (layout sizes) ====================

OzUIHelper.Metrics = {
    -- General defaults
    padding     = 4,
    spacing     = 4,
    lineSpacing = 2,

    -- Widget-level sizes
    widgetH     = 24,
    editBoxW    = 60,
    editBoxH    = 20,
    buttonW     = 100,
    buttonH     = 22,
    checkboxGap = 4,
    labelGap    = 8,

    -- Scrollable item list
    list = {
        rowH          = 22,
        contentRightInset = 20,
        rowPadX       = 5,
        rowPadTop     = 2,
        rowPadBottom  = 4,
        namePadX      = 2,
        qtyPadX       = 2,
        qtyGap        = 8,
    },

    -- Config dialog (framework-level)
    dialog = {
        width  = 500,
        height = 600,
        header = {
            height = 48,
            insetL = 11,
            insetR = 12,
            insetT = 12,
        },
        main = {
            margin       = 15,
            topOffset    = -64,
            bottomOffset = 15,
            gap          = 5,
        },
        tab = {
            width   = 120,
            btnW    = 100,
            btnH    = 16,
            flowPad = 16,
        },
        scroll = {
            step = 22,
        },
    },

    -- Minimap button
    minimap = {
        btnSize     = 32,
        radius      = 80,
        iconSize    = 21,
        iconOffX    = 7,
        iconOffY    = -6,
        overlaySize = 56,
        texCoord    = { 0.075, 0.925, 0.075, 0.925 },
    },
}

-- Legacy THEME local for backward compat (referenced by older code)
local M = OzUIHelper.Metrics

-- ==================== Utility ====================

function OzUIHelper:applyBackdrop(frame, style)
    local s = style or "widget"
    local bd = self.Theme.backdrop[s]
    if bd then frame:SetBackdrop(bd) end
    local c = self.Theme.color[s]
    if c then
        frame:SetBackdropColor(unpack(c.bg))
        frame:SetBackdropBorderColor(unpack(c.border))
    end
end

function OzUIHelper:setSize(widget, w, h)
    widget:SetWidth(w)
    widget:SetHeight(h)
    widget._layout = { width = w, height = h }
end

function OzUIHelper:nextName(prefix)
    self._id = self._id + 1
    return "OZAIO_" .. (prefix or "W") .. "_" .. self._id
end

-- ==================== Flow Layout ====================

function OzUIHelper:createFlow(parent, opts)
    local p, sp, ls
    if type(opts) == "number" then
        p = opts; sp = self.Metrics.spacing; ls = self.Metrics.lineSpacing
    elseif type(opts) == "table" then
        p  = opts.padding     or self.Metrics.padding
        sp = opts.spacing     or self.Metrics.spacing
        ls = opts.lineSpacing or self.Metrics.lineSpacing
    else
        p = self.Metrics.padding; sp = self.Metrics.spacing; ls = self.Metrics.lineSpacing
    end

    return {
        parent      = parent,
        x           = p,
        y           = -p,
        startX      = p,
        padding     = p,
        spacing     = sp,
        lineSpacing = ls,
        lineHeight  = 0,
        items       = {},
        -- Model A: maxWidth is the right edge of the usable area, not the
        -- available width; x already starts at the left padding, so a
        -- full-width row uses (maxWidth - padding)
        maxWidth    = parent:GetWidth() - p,
    }
end

function OzUIHelper:add(flow, widget, width, height)
    if not flow or not widget then return end

    local w = width  or (widget._layout and widget._layout.width)
                     or (widget.GetWidth  and widget:GetWidth())
                     or M.buttonW
    local h = height or (widget._layout and widget._layout.height)
                     or (widget.GetHeight and widget:GetHeight())
                     or M.widgetH

    -- No automatic wrapping: a new line starts only when the caller calls
    -- OzUIHelper:newLine(flow) explicitly, so multi-widget rows stay on one
    -- line even when they overflow the panel width.
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", flow.parent, "TOPLEFT", flow.x, flow.y)
    -- Apply the allocated row height so FontStrings actually get the space
    -- callers reserve for them; MIDDLE justification then centers the text
    -- the same way an EditBox centers its own text.
    if h and widget.SetHeight then widget:SetHeight(h) end
    if widget.SetJustifyV then widget:SetJustifyV("MIDDLE") end

    flow.x = flow.x + w + flow.spacing
    if h > flow.lineHeight then
        flow.lineHeight = h
    end

    table.insert(flow.items, { widget = widget, width = w, height = h })
end

function OzUIHelper:newLine(flow)
    if not flow then return end
    flow.x = flow.startX
    flow.y = flow.y - flow.lineHeight - flow.lineSpacing
    flow.lineHeight = 0
    table.insert(flow.items, { newLine = true })
end

function OzUIHelper:rebuildFlow(flow)
    if not flow or type(flow.items) ~= "table" then return end
    -- flow.items is the permanent layout description; replay it into a fresh
    -- table so rebuilds don't mutate the list they are iterating
    local saved = flow.items
    flow.x = flow.startX
    flow.y = -flow.padding
    flow.lineHeight = 0
    flow.items = {}
    for _, entry in ipairs(saved) do
        if entry.newLine then
            self:newLine(flow)
        else
            self:add(flow, entry.widget, entry.width, entry.height)
        end
    end
end

-- ==================== Unified Resize ====================
-- All OnSizeChanged registrations chain through onResize() so attachResize()
-- and onResize() compose instead of clobbering each other. Chained handlers
-- get the current size passed explicitly; callbacks receive (frame, w, h).

function OzUIHelper:onResize(frame, callback)
    local old = frame:GetScript("OnSizeChanged")
    frame:SetScript("OnSizeChanged", function()
        local width  = this:GetWidth()
        local height = this:GetHeight()
        if old then old(width, height) end
        if callback then callback(this, width, height) end
    end)
end

function OzUIHelper:attachResize(frame, flow)
    self:onResize(frame, function(f, width)
        -- Model A: maxWidth is the right edge of the usable area
        flow.maxWidth = width - flow.padding
        self:rebuildFlow(flow)
    end)
end

-- ==================== Layout Helpers ====================

function OzUIHelper:anchor(widget, parent, point, relPoint, x, y)
    widget:SetPoint(point or "TOPLEFT", parent, relPoint or point or "TOPLEFT", x or 0, y or 0)
end

function OzUIHelper:dock(widget, parent, side, size, pad)
    widget:ClearAllPoints()
    local p = pad or 0
    if side == "top" then
        self:anchor(widget, parent, "TOPLEFT",  "TOPLEFT",   p, -p)
        self:anchor(widget, parent, "TOPRIGHT", "TOPRIGHT", -p, -p)
        widget:SetHeight(size)
    elseif side == "bottom" then
        self:anchor(widget, parent, "BOTTOMLEFT",  "BOTTOMLEFT",   p,  p)
        self:anchor(widget, parent, "BOTTOMRIGHT", "BOTTOMRIGHT", -p,  p)
        widget:SetHeight(size)
    elseif side == "left" then
        self:anchor(widget, parent, "TOPLEFT",     "TOPLEFT",      p, -p)
        self:anchor(widget, parent, "BOTTOMLEFT",  "BOTTOMLEFT",   p,  p)
        widget:SetWidth(size)
    elseif side == "right" then
        self:anchor(widget, parent, "TOPRIGHT",    "TOPRIGHT",    -p, -p)
        self:anchor(widget, parent, "BOTTOMRIGHT", "BOTTOMRIGHT", -p,  p)
        widget:SetWidth(size)
    end
end

function OzUIHelper:makeMovable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    -- Native drag: StartMoving/StopMovingOrSizing preserve the frame's
    -- anchors and adjust offsets; no per-frame cursor math needed
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
end

-- ==================== Primitives ====================

function OzUIHelper:makeLabel(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or self.Fonts.normal)
    fs:SetText(text or "")
    -- Vertical center so the text lines up with taller siblings (EditBoxes,
    -- buttons) on the same flow line instead of hugging the top edge.
    fs:SetJustifyV("MIDDLE")
    return fs
end

-- Set a raw font path (file, size, flags) on a FontString
function OzUIHelper:setFont(fs, font, size, flags)
    if fs and font then
        fs:SetFont(font, size, flags)
    end
end

function OzUIHelper:makeButton(parent, text, onClick, width, height)
    local btn = CreateFrame("Button", self:nextName("Btn"), parent, "UIPanelButtonTemplate")
    self:setSize(btn, width or M.buttonW, height or M.buttonH)
    btn:SetText(text or "")
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

function OzUIHelper:makeEditBox(parent, width, height, onEnter)
    local eb = CreateFrame("EditBox", self:nextName("Edit"), parent)
    self:setSize(eb, width or M.editBoxW, height or M.editBoxH)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontNormal)
    self:applyBackdrop(eb, "widget")
    if onEnter then
        eb:SetScript("OnEnterPressed", function()
            onEnter(eb:GetText())
            eb:ClearFocus()
        end)
    end
    return eb
end

function OzUIHelper:makeSeparator(parent, width)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(1, 1, 1, 0.15)
    self:setSize(tex, width or 300, 1)
    return tex
end

-- ==================== Compound Widgets ====================

function OzUIHelper:makeCheckbox(parent, text, value, onChange)
    -- The whole row is a Button so clicking the label area toggles too
    local frame = CreateFrame("Button", nil, parent)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")

    local cb = CreateFrame("CheckButton", self:nextName("CB"), frame)
    cb:SetPoint("LEFT", frame, "LEFT", 0, 0)
    self:setSize(cb, M.widgetH, M.widgetH)
    self:applyBackdrop(cb, "widget")

    -- Check indicator
    local checkTex = cb:CreateTexture(nil, "OVERLAY")
    checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkTex:SetPoint("TOPLEFT", cb, "TOPLEFT", 1, -1)
    checkTex:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -1, 1)
    checkTex:Hide()

    local function updateCheck()
        if cb:GetChecked() then checkTex:Show() else checkTex:Hide() end
    end

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", cb, "RIGHT", M.checkboxGap, 0)
    label:SetText(text or "")

    local contentW = M.widgetH + M.checkboxGap + label:GetStringWidth()
    self:setSize(frame, contentW, M.widgetH)

    cb:SetChecked(value)
    updateCheck()
    cb:SetScript("OnClick", function()
        if onChange then onChange(cb:GetChecked()) end
        updateCheck()
    end)
    frame:SetScript("OnClick", function()
        cb:Click()
    end)

    frame.checkbox = cb
    frame.label    = label
    return frame
end

function OzUIHelper:makeLabeledEditBox(parent, labelText, editWidth)
    local widget = CreateFrame("Frame", nil, parent)

    local label = self:makeLabel(widget, labelText)
    label:SetPoint("LEFT", widget, "LEFT", 0, 0)

    local ew = editWidth or M.editBoxW
    local edit = self:makeEditBox(widget, ew, M.editBoxH)
    edit:SetPoint("LEFT", label, "RIGHT", M.labelGap, 0)

    self:setSize(widget, label:GetStringWidth() + M.labelGap + ew, M.widgetH)

    widget.editBox  = edit
    widget._callback = nil

    function widget:SetValue(v)    self.editBox:SetText(tostring(v)) end
    function widget:GetValue()     return self.editBox:GetText() end
    function widget:SetCallback(f) self._callback = f end

    edit:SetScript("OnEnterPressed", function()
        -- Generic: pass the raw text; callers tonumber() as needed
        if widget._callback then widget._callback(this:GetText()) end
        this:ClearFocus()
    end)

    return widget
end

function OzUIHelper:makeDropdown(parent, label, options, defaultValue, onChange)
    local DD = self.Theme.dropdown

    local frame = CreateFrame("Frame", nil, parent)

    -- Label
    local lbl = self:makeLabel(frame, label or "")
    lbl:SetPoint("LEFT", frame, "LEFT", 0, 0)

    -- Calculate max option width
    local maxOptionWidth = 0
    for _, opt in pairs(options) do
        local text  = opt.label or tostring(opt.value)
        local temp  = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        temp:SetText(text)
        local width = temp:GetStringWidth()
        temp:Hide()
        if width > maxOptionWidth then maxOptionWidth = width end
    end

    local btnWidth = maxOptionWidth + DD.arrowPadding * 2 + 20
    if btnWidth < DD.minWidth then btnWidth = DD.minWidth end

    -- Dropdown button
    local btn = CreateFrame("Button", self:nextName("DD"), frame)
    btn:SetWidth(btnWidth)
    btn:SetHeight(DD.height)
    btn:SetPoint("LEFT", lbl, "RIGHT", DD.labelGap, 0)
    self:applyBackdrop(btn, "widget")

    -- Button text
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", btn, "LEFT", DD.padding, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetWidth(btnWidth - DD.padding - DD.arrowPadding - 10)

    -- Arrow
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -DD.arrowPadding, 0)
    arrow:SetText("\226\150\188")  -- ▼ (UTF-8)
    arrow:SetTextColor(0.5, 0.5, 0.5)

    -- Build sequential option list
    local optionList = {}
    for _, opt in pairs(options) do
        table.insert(optionList, opt)
    end
    local optionCount = table.getn(optionList)
    -- Row height model: rows are itemHeight tall, itemSpacing apart
    local menuH = optionCount * DD.itemHeight
        + (optionCount - 1) * DD.itemSpacing
        + DD.menuPadY * 2

    -- Label lookup
    local function getLabel(value)
        for i = 1, table.getn(optionList) do
            if optionList[i].value == value then
                return optionList[i].label or tostring(value)
            end
        end
        return tostring(value or "Select...")
    end
    btnText:SetText(getLabel(defaultValue))

    -- Menu (HIGH strata so it renders above the click-catcher)
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("HIGH")
    menu:SetWidth(btnWidth)
    menu:SetHeight(menuH)
    self:applyBackdrop(menu, "widget")
    -- Slightly more opaque for popup
    menu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    menu:Hide()

    -- Full-screen click-catcher: any click outside the menu closes it.
    -- Created after the menu, so menu:Raise() puts the menu on top.
    local blocker = CreateFrame("Frame", nil, UIParent)
    blocker:SetFrameStrata("HIGH")
    blocker:SetAllPoints(UIParent)
    blocker:EnableMouse(true)
    blocker:Hide()
    blocker:SetScript("OnMouseDown", function()
        menu:Hide()
    end)
    menu:SetScript("OnHide", function()
        blocker:Hide()
    end)

    -- Dropdown menu items
    for i = 1, table.getn(optionList) do
        local opt   = optionList[i]
        local item  = CreateFrame("Button", nil, menu)
        item:SetWidth(btnWidth - DD.menuPadX * 2)
        item:SetHeight(DD.itemHeight)
        item:SetPoint("TOPLEFT", menu, "TOPLEFT",
                      DD.menuPadX, -DD.menuPadY - (i - 1) * (DD.itemHeight + DD.itemSpacing))

        self:applyBackdrop(item, "dropdownItem")

        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", item, "LEFT", DD.padding, 0)
        itemText:SetText(opt.label or tostring(opt.value))
        itemText:SetTextColor(1, 1, 1)

        local optValue = opt.value
        local optLabel = opt.label or tostring(opt.value)

        item:SetScript("OnEnter", function()
            self:applyBackdrop(item, "dropdownHover")
            itemText:SetTextColor(1, 0.82, 0)
        end)
        item:SetScript("OnLeave", function()
            self:applyBackdrop(item, "dropdownItem")
            itemText:SetTextColor(1, 1, 1)
        end)
        item:SetScript("OnClick", function()
            btnText:SetText(optLabel)
            menu:Hide()
            if onChange then onChange(optValue) end
        end)
    end

    -- Toggle menu
    btn:SetScript("OnClick", function()
        if menu:IsVisible() then
            menu:Hide()
        else
            blocker:Show()
            menu:Raise()
            local _, y  = btn:GetCenter()
            menu:ClearAllPoints()
            if y - menuH < 0 then
                menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
            else
                menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            end
            menu:Show()
        end
    end)

    self:setSize(frame, lbl:GetStringWidth() + DD.labelGap + btnWidth, DD.height)

    frame._menu    = menu
    frame._btnText = btnText
    frame._btn     = btn

    function frame:SetValue(v) btnText:SetText(getLabel(v)) end
    function frame:GetValue()
        local currentText = btnText:GetText()
        for i = 1, table.getn(optionList) do
            if (optionList[i].label or tostring(optionList[i].value)) == currentText then
                return optionList[i].value
            end
        end
        return nil
    end
    function frame:Cleanup()
        if self._menu then self._menu:Hide() end
    end

    return frame
end

-- ==================== Scrollable Item List ====================

function OzUIHelper:makeScrollItemList(parent, opts)
    local o = opts or {}
    local width  = o.width  or 300
    local height = o.height or 100
    local showQty     = o.showQuantity or false
    local emptyText   = o.emptyText   or "No items added"
    local totalPrefix = o.totalPrefix or "Total: "
    local nameResolver = o.nameResolver or function(id) return "[" .. tostring(id) .. "]" end
    local colorResolver = o.colorResolver
    local getItems = o.getItems or function() return {} end
    -- Sort order is pluggable (itemID ascending by default; an ignore-list
    -- would pass a name-alphabetical comparator)
    local sortFunc = o.sortFunc or function(a, b)
        return a.itemID < b.itemID
    end

    local LS = M.list

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetWidth(width)
    scrollFrame:SetHeight(height)
    self:applyBackdrop(scrollFrame, "panel")

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(width - LS.contentRightInset)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:EnableMouseWheel(true)

    local capScrollChild = scrollChild
    local capScrollFrame = scrollFrame
    scrollFrame:SetScript("OnMouseWheel", function()
        local cur  = this:GetVerticalScroll()
        local new  = cur - arg1 * LS.rowH
        if new < 0 then new = 0 end
        local maxS = capScrollChild:GetHeight() - capScrollFrame:GetHeight()
        if maxS < 0 then maxS = 0 end
        if new > maxS then new = maxS end
        this:SetVerticalScroll(new)
    end)

    -- Total label
    local totalLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalLabel:SetTextColor(0.5, 0.5, 0.5)

    -- Row storage
    local rows = {}

    local function clearRows()
        for _, r in ipairs(rows) do
            if r.frame then r.frame:Hide() end
        end
        rows = {}
    end

    local widget = {}
    widget.scrollFrame = scrollFrame
    widget.totalLabel  = totalLabel

    function widget:refresh()
        clearRows()
        local itemTable = getItems() or {}

        local itemList = {}
        for itemID, val in pairs(itemTable) do
            table.insert(itemList, { itemID = itemID, value = val })
        end
        table.sort(itemList, sortFunc)

        if table.getn(itemList) == 0 then
            local emptyLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            emptyLabel:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
            emptyLabel:SetText(emptyText)
            emptyLabel:SetTextColor(0.4, 0.4, 0.4)
            table.insert(rows, { frame = emptyLabel })
            scrollChild:SetHeight(40)
            totalLabel:SetText(totalPrefix .. "0")
            return
        end

        local rowH   = LS.rowH
        local totalH = table.getn(itemList) * rowH + LS.rowPadBottom
        scrollChild:SetHeight(math.max(totalH, height))
        local innerW = width - LS.contentRightInset - LS.rowPadX * 2

        for i, entry in ipairs(itemList) do
            local capItemID = entry.itemID
            local capValue  = entry.value

            local rowFrame = CreateFrame("Frame", nil, scrollChild)
            rowFrame:SetWidth(innerW)
            rowFrame:SetHeight(rowH)
            rowFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT",
                              LS.rowPadX, -LS.rowPadTop - (i - 1) * rowH)

            local nameStr  = nameResolver(capItemID)
            local nameLabel = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            nameLabel:SetPoint("LEFT", rowFrame, "LEFT", LS.namePadX, 0)
            nameLabel:SetWidth(innerW - LS.namePadX - LS.qtyPadX)
            nameLabel:SetText(nameStr)
            if colorResolver then
                local r, g, b = colorResolver(capItemID)
                if r then nameLabel:SetTextColor(r, g, b) end
            end

            if showQty then
                local qtyLabel = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                qtyLabel:SetPoint("RIGHT", rowFrame, "RIGHT", -LS.qtyPadX, 0)
                qtyLabel:SetText("x " .. tostring(capValue))
                nameLabel:SetWidth(innerW - LS.namePadX - LS.qtyPadX
                                   - qtyLabel:GetStringWidth() - LS.qtyGap)
            end

            table.insert(rows, { frame = rowFrame })
        end

        totalLabel:SetText(totalPrefix .. table.getn(itemList))
    end

    return widget
end

-- ==================== Class Colors ====================

local CLASS_COLORS = {
    warrior = { r = 0.78, g = 0.61, b = 0.43 },
    mage    = { r = 0.41, g = 0.80, b = 0.94 },
    rogue   = { r = 1.00, g = 0.96, b = 0.41 },
    druid   = { r = 1.00, g = 0.49, b = 0.04 },
    hunter  = { r = 0.67, g = 0.83, b = 0.45 },
    shaman  = { r = 0.00, g = 0.44, b = 0.87 },
    priest  = { r = 1.00, g = 1.00, b = 1.00 },
    warlock = { r = 0.58, g = 0.51, b = 0.79 },
    paladin = { r = 0.96, g = 0.55, b = 0.73 },
}

-- Expose for other modules (e.g. OzIgnore class-colored rows)
OzUIHelper.CLASS_COLORS = CLASS_COLORS

function OzUIHelper:classColor(class)
    -- Explicit class required: callers resolve UnitClass() themselves
    if not class then return 1, 1, 1 end
    local color = CLASS_COLORS[string.lower(class)]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- ==================== Minimap Button Widget ====================

function OzUIHelper:createMinimapButton(opts)
    local o = opts or {}
    local MM = o.metrics or self.Metrics.minimap

    local button = CreateFrame("Button", o.name or self:nextName("Minimap"), Minimap)
    button:SetWidth(MM.btnSize)
    button:SetHeight(MM.btnSize)
    button:SetFrameStrata("LOW")
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Position update (angle-based, optionally overrideable)
    local angleState = o.angleState or OZAIO
    local function update_position()
        local angle = angleState.minimap_angle or 0
        local rad = math.rad(angle)
        local x = math.cos(rad) * MM.radius
        local y = math.sin(rad) * MM.radius
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    update_position()

    -- Icon
    if o.icon then
        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetTexture(o.icon)
        icon:SetWidth(MM.iconSize)
        icon:SetHeight(MM.iconSize)
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", MM.iconOffX, MM.iconOffY)
        if o.texCoord then
            icon:SetTexCoord(unpack(o.texCoord))
        elseif MM.texCoord then
            icon:SetTexCoord(unpack(MM.texCoord))
        end
    end

    -- Overlay border
    if o.overlay then
        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetTexture(o.overlay)
        overlay:SetWidth(MM.overlaySize)
        overlay:SetHeight(MM.overlaySize)
        overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    end

    -- Highlight
    if o.highlight then
        button:SetHighlightTexture(o.highlight, "ADD")
    end

    -- Drag rotation
    button:SetScript("OnDragStart", function()
        button._dragActive = true
        button:SetScript("OnUpdate", function()
            if not button._dragActive then return end
            local mx, my = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local sx, sy = Minimap:GetCenter()
            mx = mx / scale
            my = my / scale
            local a = math.deg(math.atan2(my - sy, mx - sx))
            if a < 0 then a = a + 360 end
            angleState.minimap_angle = a
            update_position()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button._dragActive = nil
        button:SetScript("OnUpdate", nil)
    end)

    -- Tooltip
    if o.tooltipTitle then
        button:SetScript("OnEnter", function()
            if GameTooltip then
                GameTooltip:SetOwner(this, "ANCHOR_LEFT")
                GameTooltip:SetText(o.tooltipTitle)
                if o.tooltipText then
                    GameTooltip:AddLine(o.tooltipText, 0.8, 0.8, 0.8)
                end
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Click
    if o.onClick then
        button:SetScript("OnClick", o.onClick)
    end

    return button
end
