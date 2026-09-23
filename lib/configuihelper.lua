-- OzUIHelper: automatic-layout UI helpers for WoW 1.12
--
-- Widgets self-size where possible. Flow layout auto-wraps.
--   flow:add(widget)           -- uses widget._layout for size
--   flow:add(widget, 100, 20)  -- explicit size (backward compat)

local MAJOR = "OzUIHelper-1.0"
local MINOR = 1

if OzUIHelper and OzUIHelper.version and OzUIHelper.version >= MINOR then
    return
end

OzUIHelper                 = OzUIHelper or { _id = 0 }
OzUIHelper.version         = MINOR

-- ==================== Typography (font objects) ====================

OzUIHelper.Fonts           = {
    normal = "GameFontNormal",
    small  = "GameFontNormalSmall",
    large  = "GameFontNormalLarge",
    huge   = "GameFontNormalHuge",
}

-- ==================== Theme (visual) ====================

OzUIHelper.Theme           = {
    backdrop = {
        widget = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        },
        panel = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        },
        blizaad = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        },
        flat = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        },
        dropdownItem = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        },
    },

    color = {
        widget        = { bg = { 0.05, 0.05, 0.05, 0.8 }, border = { 0.3, 0.3, 0.3, 0.8 } },
        panel         = { bg = { 0.05, 0.05, 0.08, 0.6 }, border = { 0.2, 0.2, 0.3, 0.5 } },
        dropdownItem  = { bg = { 0.05, 0.05, 0.05, 0.8 }, border = { 0.15, 0.15, 0.15, 0.3 } },
        dropdownHover = { bg = { 0.2, 0.2, 0.3, 0.9 }, border = { 0.4, 0.4, 0.6, 0.8 } },
    },

    dropdown = {
        height       = 20,
        minWidth     = 80,
        padding      = 5,
        arrowPadding = 5,
        menuPadX     = 2,
        menuPadY     = 2,
        itemHeight   = 18,
        itemSpacing  = 0,
        labelGap     = 6,
    },
}

-- Backward-compat aliases
OzUIHelper.BlizaadBackdrop = OzUIHelper.Theme.backdrop.blizaad
OzUIHelper.PFUIBackdrop    = OzUIHelper.Theme.backdrop.flat

-- ==================== Metrics (layout sizes) ====================

OzUIHelper.Metrics         = {
    -- General defaults
    padding     = 4,
    spacing     = 2,
    lineSpacing = 1,

    -- Widget-level sizes
    widgetH     = 18,
    editBoxW    = 60,
    editBoxH    = 18,
    buttonW     = 90,
    buttonH     = 20,
    checkboxGap = 4,
    labelGap    = 6,

    -- Scrollable item list
    list        = {
        rowH              = 22,
        contentRightInset = 20,
        rowPadX           = 5,
        rowPadTop         = 2,
        rowPadBottom      = 4,
        namePadX          = 2,
        qtyPadX           = 2,
        qtyGap            = 8,
    },

    -- Config dialog (framework-level)
    dialog      = {
        width  = 500,
        height = 600,
        header = {
            height = 48,
            insetL = 11,
            insetR = 12,
            insetT = 12,
        },
        main   = {
            margin       = 15,
            topOffset    = -64,
            bottomOffset = 15,
            gap          = 5,
        },
        tab    = {
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
    minimap     = {
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
local M                    = OzUIHelper.Metrics

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

local oz_tooltip = nil

local function get_oz_tooltip()
    if not oz_tooltip then
        local frame = CreateFrame("Frame", "OzUITooltip", UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetClampedToScreen(true)
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
        title:SetTextColor(1, 0.82, 0)
        title:SetJustifyH("LEFT")

        local desc = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetTextColor(0.85, 0.85, 0.85)
        desc:SetJustifyH("LEFT")

        frame.title = title
        frame.desc = desc
        frame:Hide()
        oz_tooltip = frame
    end
    return oz_tooltip
end

function OzUIHelper:showTooltip(owner, title, text, anchor)
    if not owner then return end
    local tt = get_oz_tooltip()
    if not tt then return end

    if GameTooltip and GameTooltip:IsShown() then
        GameTooltip:Hide()
    end

    local hasTitle = (title and title ~= "")
    local hasDesc  = (text and text ~= "")

    if not hasTitle and not hasDesc then
        tt:Hide()
        return
    end

    -- Reset width constraints so GetStringWidth measures unconstrained text
    tt.title:SetWidth(0)
    tt.desc:SetWidth(0)

    if hasTitle then
        tt.title:SetText(title)
        tt.title:Show()
    else
        tt.title:SetText("")
        tt.title:Hide()
    end

    if hasDesc then
        tt.desc:SetText(text)
        tt.desc:Show()
    else
        tt.desc:SetText("")
        tt.desc:Hide()
    end

    local tw = hasTitle and (tt.title:GetStringWidth() or 0) or 0
    local dw = hasDesc and (tt.desc:GetStringWidth() or 0) or 0
    local maxTextW = math.max(tw, dw)

    if maxTextW > 280 then
        maxTextW = 280
    end

    local finalW = maxTextW + 20
    if finalW < 80 then finalW = 80 end

    -- Apply width constraint for word wrapping
    if hasTitle then
        tt.title:SetWidth(maxTextW)
        tt.title:ClearAllPoints()
        tt.title:SetPoint("TOPLEFT", tt, "TOPLEFT", 10, -10)
    end

    if hasDesc then
        tt.desc:SetWidth(maxTextW)
        tt.desc:ClearAllPoints()
        if hasTitle then
            tt.desc:SetPoint("TOPLEFT", tt.title, "BOTTOMLEFT", 0, -4)
        else
            tt.desc:SetPoint("TOPLEFT", tt, "TOPLEFT", 10, -10)
        end
    end

    -- Calculate heights
    local th = 0
    if hasTitle then
        th = (tt.title.GetHeight and tt.title:GetHeight()) or 14
        if tw > 270 then
            local lines = math.ceil(tw / 270)
            th = math.max(th, lines * 14)
        end
        if th <= 0 then th = 14 end
    end

    local dh = 0
    if hasDesc then
        dh = (tt.desc.GetHeight and tt.desc:GetHeight()) or 12
        local _, nl = string.gsub(text, "\n", "")
        local newlines = nl or 0
        local lines = 1 + newlines
        if dw > 270 then
            lines = math.max(lines, math.ceil(dw / 270) + newlines)
        end
        dh = math.max(dh, lines * 13)
        if dh <= 0 then dh = 12 end
    end

    local finalH = 20 + th + dh
    if hasTitle and hasDesc then
        finalH = finalH + 4
    end

    tt:SetWidth(finalW)
    tt:SetHeight(finalH)

    if owner.GetFrameLevel then
        tt:SetFrameLevel(owner:GetFrameLevel() + 25)
    end

    tt:ClearAllPoints()
    local a = anchor or "ANCHOR_TOPLEFT"
    if a == "ANCHOR_TOPLEFT" then
        tt:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
    elseif a == "ANCHOR_LEFT" then
        tt:SetPoint("RIGHT", owner, "LEFT", -4, 0)
    elseif a == "ANCHOR_RIGHT" then
        tt:SetPoint("LEFT", owner, "RIGHT", 4, 0)
    elseif a == "ANCHOR_BOTTOMLEFT" then
        tt:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    elseif a == "ANCHOR_TOPRIGHT" then
        tt:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, 4)
    else
        tt:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
    end

    tt:Show()
end

function OzUIHelper:hideTooltip()
    if oz_tooltip then
        oz_tooltip:Hide()
    end
end

-- ==================== Flow Layout ====================

function OzUIHelper:createFlow(parent, opts)
    local p, sp, ls
    if type(opts) == "number" then
        p = opts; sp = self.Metrics.spacing; ls = self.Metrics.lineSpacing
    elseif type(opts) == "table" then
        p  = opts.padding or self.Metrics.padding
        sp = opts.spacing or self.Metrics.spacing
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

    local w = width or (widget._layout and widget._layout.width)
        or (widget.GetWidth and widget:GetWidth())
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

-- ==================== Scrollable Panel ====================

function OzUIHelper:createScrollPanel(parent, opts)
    local o = opts or {}
    local p = o.padding or self.Metrics.padding or 8
    local sp = o.spacing or 4
    local rsp = o.rowSpacing or 6
    local step = o.step or (self.Metrics.dialog and self.Metrics.dialog.scroll and self.Metrics.dialog.scroll.step) or 22
    local rightInset = o.rightInset or 20

    local scrollFrame = CreateFrame("ScrollFrame", self:nextName("ScrollPanel"), parent)
    self:applyBackdrop(scrollFrame, o.backdropStyle or "panel")
    scrollFrame:EnableMouseWheel(true)

    local scrollChild = CreateFrame("Frame", self:nextName("ScrollChild"), scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    local panel = {
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        padding     = p,
        spacing     = sp,
        rowSpacing  = rsp,
        step        = step,
        rightInset  = rightInset,
        currentY    = -p,
        widgets     = {},
    }

    local function updateDimensions()
        if panel.RelayoutSections then
            panel:RelayoutSections()
            return
        end
        local sw = scrollFrame:GetWidth()
        if sw and sw > panel.rightInset then
            local usableW = sw - panel.rightInset
            scrollChild:SetWidth(usableW)
            local innerW = usableW - panel.padding * 2
            if innerW > 0 then
                for _, w in ipairs(panel.widgets) do
                    if (w._fullWidth or w._wOptsFullWidth) and w.SetWidth then
                        w:SetWidth(innerW)
                        if w._layout then w._layout.width = innerW end
                    end
                end
            end
        end
        panel:UpdateScroll()
    end

    panel.UpdateDimensions = updateDimensions

    scrollFrame:SetScript("OnSizeChanged", function()
        updateDimensions()
    end)

    scrollFrame:SetScript("OnMouseWheel", function()
        local cur = this:GetVerticalScroll()
        local new = cur - arg1 * panel.step
        if new < 0 then new = 0 end
        local maxS = scrollChild:GetHeight() - scrollFrame:GetHeight()
        if maxS < 0 then maxS = 0 end
        if new > maxS then new = maxS end
        this:SetVerticalScroll(new)
    end)

    function panel:UpdateScroll()
        local totalH = math.abs(self.currentY) + self.padding
        local viewH  = scrollFrame:GetHeight() or 0
        if totalH < viewH then totalH = viewH end
        scrollChild:SetHeight(totalH)

        local cur = scrollFrame:GetVerticalScroll()
        local maxS = totalH - viewH
        if maxS < 0 then maxS = 0 end
        if cur > maxS then scrollFrame:SetVerticalScroll(maxS) end
    end

    function panel:GetContentHeight()
        return math.abs(self.currentY) + self.padding
    end

    function panel:Add(widget, wOpts)
        if not widget then return end
        local wo = wOpts or {}
        local h = wo.height or (widget._layout and widget._layout.height)
            or (widget.GetHeight and widget:GetHeight())
            or 24
        if h <= 0 then h = 24 end

        widget:ClearAllPoints()
        widget:SetParent(scrollChild)
        widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", self.padding, self.currentY)

        if wo.fullWidth or widget._fullWidth then
            widget._wOptsFullWidth = true
            local sw = scrollChild:GetWidth()
            if not sw or sw <= 0 then
                local sfw = scrollFrame:GetWidth()
                if sfw and sfw > self.rightInset then
                    sw = sfw - self.rightInset
                    scrollChild:SetWidth(sw)
                end
            end
            if sw and sw > self.padding * 2 then
                local w = sw - self.padding * 2
                widget:SetWidth(w)
                if widget._layout then widget._layout.width = w end
            end
        end

        self.currentY = self.currentY - h - self.spacing
        table.insert(self.widgets, widget)
        self:UpdateScroll()
        return widget
    end

    function panel:AddRow(rowWidgets, rOpts)
        if not rowWidgets or table.getn(rowWidgets) == 0 then return end
        local x = self.padding
        local maxH = 0

        for _, widget in ipairs(rowWidgets) do
            local w = widget._layout and widget._layout.width
            if not w or w <= 0 then
                w = (widget.GetStringWidth and widget:GetStringWidth())
                if not w or w <= 0 then
                    w = (widget.GetWidth and widget:GetWidth())
                end
            end
            if not w or w <= 0 then w = 100 end

            local h = widget._layout and widget._layout.height
            if not h or h <= 0 then
                h = (widget.GetHeight and widget:GetHeight())
            end
            if not h or h <= 0 then h = 24 end

            if h > maxH then maxH = h end

            widget:ClearAllPoints()
            widget:SetParent(scrollChild)
            widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, self.currentY)

            x = x + w + self.rowSpacing
            table.insert(self.widgets, widget)
        end

        if maxH <= 0 then maxH = 24 end
        self.currentY = self.currentY - maxH - self.spacing
        self:UpdateScroll()
        return rowWidgets
    end

    function panel:AddSpace(height)
        local h = height or self.spacing
        self.currentY = self.currentY - h
        self:UpdateScroll()
    end

    function panel:Clear()
        for _, w in ipairs(self.widgets) do
            if w.Hide then w:Hide() end
        end
        self.widgets = {}
        self.currentY = -self.padding
        scrollFrame:SetVerticalScroll(0)
        self:UpdateScroll()
    end

    return panel
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
        self:anchor(widget, parent, "TOPLEFT", "TOPLEFT", p, -p)
        self:anchor(widget, parent, "TOPRIGHT", "TOPRIGHT", -p, -p)
        widget:SetHeight(size)
    elseif side == "bottom" then
        self:anchor(widget, parent, "BOTTOMLEFT", "BOTTOMLEFT", p, p)
        self:anchor(widget, parent, "BOTTOMRIGHT", "BOTTOMRIGHT", -p, p)
        widget:SetHeight(size)
    elseif side == "left" then
        self:anchor(widget, parent, "TOPLEFT", "TOPLEFT", p, -p)
        self:anchor(widget, parent, "BOTTOMLEFT", "BOTTOMLEFT", p, p)
        widget:SetWidth(size)
    elseif side == "right" then
        self:anchor(widget, parent, "TOPRIGHT", "TOPRIGHT", -p, -p)
        self:anchor(widget, parent, "BOTTOMRIGHT", "BOTTOMRIGHT", -p, p)
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

function OzUIHelper:createLabel(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or self.Fonts.normal)
    fs:SetText(text or "")
    -- Vertical center so the text lines up with taller siblings (EditBoxes,
    -- buttons) on the same flow line instead of hugging the top edge.
    fs:SetJustifyV("MIDDLE")
    local h = (fs.GetHeight and fs:GetHeight()) or 14
    if h <= 0 then h = 14 end
    self:setSize(fs, (fs.GetStringWidth and fs:GetStringWidth()) or 100, h)
    return fs
end

-- Set a raw font path (file, size, flags) on a FontString
function OzUIHelper:setFont(fs, font, size, flags)
    if fs and font then
        fs:SetFont(font, size, flags)
    end
end

function OzUIHelper:createButton(parent, text, onClick, width, height)
    local btn = CreateFrame("Button", self:nextName("Btn"), parent, "UIPanelButtonTemplate")
    self:setSize(btn, width or M.buttonW, height or M.buttonH)
    btn:SetText(text or "")
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

function OzUIHelper:createEditBox(parent, width, height, onEnter)
    local eb = CreateFrame("EditBox", self:nextName("Edit"), parent)
    self:setSize(eb, width or M.editBoxW, height or M.editBoxH)
    eb:SetAutoFocus(false)
    if eb.SetFontObject then
        eb:SetFontObject(GameFontNormal)
    elseif GameFontNormal and GameFontNormal.GetFont then
        local font, size, flags = GameFontNormal:GetFont()
        eb:SetFont(font, size, flags)
    end
    if eb.SetTextInsets then
        eb:SetTextInsets(4, 4, 0, 0)
    end
    self:applyBackdrop(eb, "widget")
    if onEnter then
        eb:SetScript("OnEnterPressed", function()
            onEnter(eb:GetText())
            eb:ClearFocus()
        end)
    end
    return eb
end

function OzUIHelper:createSeparator(parent, width)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(1, 1, 1, 0.15)
    self:setSize(tex, width or 300, 1)
    return tex
end

function OzUIHelper:createHeader(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    fs:SetText(text or "")
    fs:SetTextColor(1, 0.82, 0)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.2)
    line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
    line:SetHeight(1)

    self:setSize(frame, 300, 20)
    frame._fullWidth = true
    frame.text = fs
    frame.line = line
    return frame
end

function OzUIHelper:createFoldableHeader(parent, text, isFolded, onToggle, locTable)
    local frame = CreateFrame("Button", self:nextName("FoldHeader"), parent)
    self:setSize(frame, 300, 20)
    frame._fullWidth = true
    frame:EnableMouse(true)

    local hl = frame:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(frame)
    hl:SetAlpha(0.2)

    local indicator = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    indicator:SetPoint("LEFT", frame, "LEFT", 2, 0)

    local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", indicator, "RIGHT", 6, 0)
    fs:SetText(text or "")
    fs:SetTextColor(1, 0.82, 0)

    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hint:SetPoint("RIGHT", frame, "RIGHT", -4, 0)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.2)
    line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
    line:SetHeight(1)

    frame.text = fs
    frame.indicator = indicator
    frame.hint = hint
    frame.line = line

    local function get_loc(key, fallback)
        if locTable and locTable[key] then return locTable[key] end
        return fallback or key
    end

    function frame:SetFolded(folded)
        frame.isFolded = folded
        if folded then
            indicator:SetText("|cff00ffcc[ + ]|r")
            hint:SetText("|cff888888" .. get_loc("(Click to expand)", "(Click to expand)") .. "|r")
        else
            indicator:SetText("|cffffcc00[ - ]|r")
            hint:SetText("|cff888888" .. get_loc("(Click to collapse)", "(Click to collapse)") .. "|r")
        end
    end

    frame:SetFolded(isFolded)

    frame:SetScript("OnEnter", function()
        fs:SetTextColor(1, 1, 1)
        local tip = this.isFolded and get_loc("Click to expand this section.", "Click to expand this section.")
            or get_loc("Click to collapse this section.", "Click to collapse this section.")
        OzUIHelper:showTooltip(this, text, tip, "ANCHOR_TOPLEFT")
    end)

    frame:SetScript("OnLeave", function()
        fs:SetTextColor(1, 0.82, 0)
        OzUIHelper:hideTooltip()
    end)

    frame:SetScript("OnClick", function()
        if onToggle then onToggle(this) end
        if this:IsShown() and OzUITooltip and OzUITooltip:IsShown() then
            local tip = this.isFolded and get_loc("Click to expand this section.", "Click to expand this section.")
                or get_loc("Click to collapse this section.", "Click to collapse this section.")
            OzUIHelper:showTooltip(this, text, tip, "ANCHOR_TOPLEFT")
        end
    end)

    return frame
end

function OzUIHelper:createSlider(parent, label, minVal, maxVal, step, defaultVal, onChange, width)
    local w = width or 160
    local frame = CreateFrame("Frame", nil, parent)
    self:setSize(frame, w, 32)

    local sliderName = self:nextName("Slider")
    local slider = CreateFrame("Slider", sliderName, frame, "OptionsSliderTemplate")
    slider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
    slider:SetHeight(14)

    minVal = minVal or 0
    maxVal = maxVal or 100
    step   = step or 1
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)

    local titleText = getglobal(sliderName .. "Text")
    local lowText   = getglobal(sliderName .. "Low")
    local highText  = getglobal(sliderName .. "High")

    if lowText then lowText:SetText(tostring(minVal)) end
    if highText then highText:SetText(tostring(maxVal)) end

    local currentVal = defaultVal or minVal
    if titleText then
        titleText:SetText((label or "") .. ": " .. tostring(currentVal))
    end

    slider:SetValue(currentVal)

    slider:SetScript("OnValueChanged", function()
        local val = this:GetValue()
        if step and step > 0 then
            val = math.floor(val / step + 0.5) * step
            if step < 1 then
                val = tonumber(string.format("%.2f", val))
            end
        end
        if titleText then
            titleText:SetText((label or "") .. ": " .. tostring(val))
        end
        if onChange then
            onChange(val)
        end
    end)

    frame.slider = slider
    frame.titleText = titleText
    function frame:SetValue(v)
        slider:SetValue(v)
        if titleText then
            local displayVal = v
            if step and step > 0 and step < 1 then
                displayVal = tonumber(string.format("%.2f", v))
            end
            titleText:SetText((label or "") .. ": " .. tostring(displayVal))
        end
    end

    function frame:GetValue() return slider:GetValue() end

    return frame
end

-- ==================== Compound Widgets ====================

function OzUIHelper:createCheckbox(parent, text, value, onChange)
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

    local isInitChecked = (value and value ~= 0 and value ~= "0") and 1 or nil
    cb:SetChecked(isInitChecked)
    updateCheck()

    cb:SetScript("OnClick", function()
        local isChecked = (cb:GetChecked() and cb:GetChecked() ~= 0) and true or false
        updateCheck()
        if onChange then onChange(isChecked) end
    end)
    frame:SetScript("OnClick", function()
        cb:Click()
    end)

    function frame:SetValue(v)
        local checked = (v and v ~= 0 and v ~= "0") and 1 or nil
        cb:SetChecked(checked)
        updateCheck()
    end

    function frame:GetValue()
        return (cb:GetChecked() and cb:GetChecked() ~= 0) and true or false
    end

    frame.checkbox = cb
    frame.label    = label
    return frame
end

function OzUIHelper:createLabeledEditBox(parent, labelText, editWidth)
    local widget = CreateFrame("Frame", nil, parent)

    local label = self:createLabel(widget, labelText)
    label:SetPoint("LEFT", widget, "LEFT", 0, 0)

    local ew = editWidth or M.editBoxW
    local edit = self:createEditBox(widget, ew, M.editBoxH)
    edit:SetPoint("LEFT", label, "RIGHT", M.labelGap, 0)

    self:setSize(widget, label:GetStringWidth() + M.labelGap + ew, M.widgetH)

    widget.editBox   = edit
    widget._callback = nil

    function widget:SetValue(v) self.editBox:SetText(tostring(v)) end

    function widget:GetValue() return self.editBox:GetText() end

    function widget:SetCallback(f) self._callback = f end

    edit:SetScript("OnEnterPressed", function()
        -- Generic: pass the raw text; callers tonumber() as needed
        if widget._callback then widget._callback(this:GetText()) end
        this:ClearFocus()
    end)

    return widget
end

function OzUIHelper:createLabeledEditArea(parent, labelText, width, height)
    local widget = CreateFrame("Frame", nil, parent)
    local w = width or 280
    local h = height or 60

    local label = nil
    local labelH = 0
    if labelText and labelText ~= "" then
        label = self:createLabel(widget, labelText)
        label:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, 0)
        local lh = (label.GetHeight and label:GetHeight()) or 14
        if lh <= 0 then lh = 14 end
        labelH = lh + 4
    end

    local bg = CreateFrame("Frame", nil, widget)
    bg:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -labelH)
    bg:SetWidth(w)
    bg:SetHeight(h)
    self:applyBackdrop(bg, "widget")

    local edit = CreateFrame("EditBox", self:nextName("EditArea"), bg)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(500)
    edit:SetPoint("TOPLEFT", bg, "TOPLEFT", 6, -6)
    edit:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -6, 6)
    if edit.SetFontObject then
        edit:SetFontObject(GameFontHighlightSmall)
    elseif GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
        local font, size, flags = GameFontHighlightSmall:GetFont()
        edit:SetFont(font, size, flags)
    end

    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)

    self:setSize(widget, w, labelH + h)

    widget.editBox   = edit
    widget.label     = label
    widget._callback = nil
    edit.lastText    = edit:GetText() or ""

    function widget:SetValue(v)
        local s = tostring(v or "")
        self.editBox:SetText(s)
        self.editBox.lastText = s
    end

    function widget:GetValue()
        return self.editBox:GetText()
    end

    function widget:SetCallback(f)
        self._callback = f
    end

    local function check_text_change(eb)
        local cur = eb:GetText() or ""
        if cur ~= eb.lastText then
            eb.lastText = cur
            if widget._callback then widget._callback(cur) end
        end
    end

    edit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)

    edit:SetScript("OnEditFocusGained", function()
        OzUIHelper._activeEditArea = this
    end)

    edit:SetScript("OnEditFocusLost", function()
        if OzUIHelper._activeEditArea == this then
            OzUIHelper._activeEditArea = nil
        end
        check_text_change(this)
    end)

    -- WoW 1.12 lacks native EditBox OnTextChanged; poll OnUpdate for real-time changes
    edit:SetScript("OnUpdate", function()
        check_text_change(this)
    end)

    return widget
end

function OzUIHelper:createDropdown(parent, label, options, defaultValue, onChange)
    local DD = self.Theme.dropdown

    local frame = CreateFrame("Frame", nil, parent)

    -- Label
    local lbl = self:createLabel(frame, label or "")
    lbl:SetPoint("LEFT", frame, "LEFT", 0, 0)

    -- Calculate max option width
    local maxOptionWidth = 0
    for _, opt in pairs(options) do
        local text = opt.label or tostring(opt.value)
        local temp = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
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
    arrow:SetText("\226\150\188") -- ▼ (UTF-8)
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

    -- Shared blocker helper
    local function getDropdownBlocker()
        if not OzUIHelper._dropdownBlocker then
            local blocker = CreateFrame("Frame", "OzUIHelperDropdownBlocker", UIParent)
            blocker:SetFrameStrata("DIALOG")
            blocker:SetAllPoints(UIParent)
            blocker:EnableMouse(true)
            blocker:Hide()
            blocker:SetScript("OnMouseDown", function()
                if OzUIHelper._activeDropdownMenu then
                    OzUIHelper._activeDropdownMenu:Hide()
                    OzUIHelper._activeDropdownMenu = nil
                end
                this:Hide()
            end)
            OzUIHelper._dropdownBlocker = blocker
        end
        return OzUIHelper._dropdownBlocker
    end

    -- Menu (FULLSCREEN_DIALOG strata so it renders above DIALOG blocker)
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetWidth(btnWidth)
    menu:SetHeight(menuH)
    self:applyBackdrop(menu, "widget")
    -- Slightly more opaque for popup
    menu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    menu:Hide()

    menu:SetScript("OnHide", function()
        if OzUIHelper._activeDropdownMenu == menu then
            OzUIHelper._activeDropdownMenu = nil
            if OzUIHelper._dropdownBlocker then
                OzUIHelper._dropdownBlocker:Hide()
            end
        end
    end)

    if parent and parent.SetScript then
        local oldParentHide = parent:GetScript("OnHide")
        parent:SetScript("OnHide", function()
            if oldParentHide then oldParentHide() end
            if menu:IsShown() then
                menu:Hide()
            end
        end)
    end

    -- Dropdown menu items
    for i = 1, table.getn(optionList) do
        local opt  = optionList[i]
        local item = CreateFrame("Button", nil, menu)
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
            if OzUIHelper._activeDropdownMenu and OzUIHelper._activeDropdownMenu ~= menu then
                OzUIHelper._activeDropdownMenu:Hide()
            end
            local blocker = getDropdownBlocker()
            blocker:Show()
            OzUIHelper._activeDropdownMenu = menu

            local _, y                     = btn:GetCenter()
            menu:ClearAllPoints()
            if y and menuH and (y - menuH < 0) then
                menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
            else
                menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            end
            menu:Show()
            menu:Raise()
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

function OzUIHelper:createScrollItemList(parent, opts)
    local o             = opts or {}
    local width         = o.width or 300
    local height        = o.height or 100
    local showQty       = o.showQuantity or false
    local emptyText     = o.emptyText or "No items added"
    local totalPrefix   = o.totalPrefix or "Total: "
    local nameResolver  = o.nameResolver or function(id) return "[" .. tostring(id) .. "]" end
    local colorResolver = o.colorResolver
    local getItems      = o.getItems or function() return {} end
    -- Sort order is pluggable (itemID ascending by default; an ignore-list
    -- would pass a name-alphabetical comparator)
    local sortFunc      = o.sortFunc or function(a, b)
        return a.itemID < b.itemID
    end

    local LS            = M.list

    -- ScrollFrame
    local scrollFrame   = CreateFrame("ScrollFrame", nil, parent)
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
        local cur = this:GetVerticalScroll()
        local new = cur - arg1 * LS.rowH
        if new < 0 then new = 0 end
        local maxS = capScrollChild:GetHeight() - capScrollFrame:GetHeight()
        if maxS < 0 then maxS = 0 end
        if new > maxS then new = maxS end
        this:SetVerticalScroll(new)
    end)

    local widget = {}

    scrollFrame:SetScript("OnSizeChanged", function()
        local sw = this:GetWidth()
        if sw and sw > LS.contentRightInset then
            capScrollChild:SetWidth(sw - LS.contentRightInset)
            if widget and widget.refresh then widget:refresh() end
        end
    end)

    -- Total label
    local totalLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalLabel:SetTextColor(0.5, 0.5, 0.5)

    -- Row frame pool (reuses frame objects across refreshes to eliminate frame leaks)
    local rowPool = {}
    local emptyLabel = nil

    local function getRow(index)
        if not rowPool[index] then
            local rowFrame  = CreateFrame("Frame", nil, scrollChild)
            local nameLabel = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            local qtyLabel  = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            rowPool[index]  = {
                frame     = rowFrame,
                nameLabel = nameLabel,
                qtyLabel  = qtyLabel,
            }
        end
        return rowPool[index]
    end

    widget.scrollFrame = scrollFrame
    widget.totalLabel  = totalLabel
    widget.rowPool     = rowPool

    function widget:refresh()
        local itemTable = getItems() or {}

        local itemList = {}
        for itemID, val in pairs(itemTable) do
            table.insert(itemList, { itemID = itemID, value = val })
        end
        table.sort(itemList, sortFunc)

        local count = table.getn(itemList)
        if count == 0 then
            if not emptyLabel then
                emptyLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                emptyLabel:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
                emptyLabel:SetText(emptyText)
                emptyLabel:SetTextColor(0.4, 0.4, 0.4)
            end
            emptyLabel:Show()
            for _, r in ipairs(rowPool) do
                r.frame:Hide()
            end
            scrollChild:SetHeight(40)
            totalLabel:SetText(totalPrefix .. "0")
            return
        end

        if emptyLabel then
            emptyLabel:Hide()
        end

        local rowH   = LS.rowH
        local totalH = count * rowH + LS.rowPadBottom
        scrollChild:SetHeight(math.max(totalH, height))
        local currentW = scrollFrame:GetWidth()
        if not currentW or currentW <= 0 then currentW = width end
        local innerW = currentW - LS.contentRightInset - LS.rowPadX * 2
        if innerW < 50 then innerW = 50 end

        for i, entry in ipairs(itemList) do
            local capItemID = entry.itemID
            local capValue  = entry.value

            local r         = getRow(i)
            r.frame:SetWidth(innerW)
            r.frame:SetHeight(rowH)
            r.frame:ClearAllPoints()
            r.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT",
                LS.rowPadX, -LS.rowPadTop - (i - 1) * rowH)

            local nameStr = nameResolver(capItemID)
            r.nameLabel:ClearAllPoints()
            r.nameLabel:SetPoint("LEFT", r.frame, "LEFT", LS.namePadX, 0)
            r.nameLabel:SetText(nameStr)
            if colorResolver then
                local cr, cg, cb = colorResolver(capItemID)
                if cr then
                    r.nameLabel:SetTextColor(cr, cg, cb)
                else
                    r.nameLabel:SetTextColor(1, 1, 1)
                end
            else
                r.nameLabel:SetTextColor(1, 1, 1)
            end

            if showQty then
                r.qtyLabel:ClearAllPoints()
                r.qtyLabel:SetPoint("RIGHT", r.frame, "RIGHT", -LS.qtyPadX, 0)
                r.qtyLabel:SetText("x " .. tostring(capValue))
                r.qtyLabel:Show()
                r.nameLabel:SetWidth(innerW - LS.namePadX - LS.qtyPadX
                    - r.qtyLabel:GetStringWidth() - LS.qtyGap)
            else
                r.qtyLabel:Hide()
                r.nameLabel:SetWidth(innerW - LS.namePadX - LS.qtyPadX)
            end

            r.frame:Show()
        end

        for k = count + 1, table.getn(rowPool) do
            rowPool[k].frame:Hide()
        end

        totalLabel:SetText(totalPrefix .. count)
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
            OzUIHelper:showTooltip(this, o.tooltipTitle, o.tooltipText, "ANCHOR_LEFT")
        end)
        button:SetScript("OnLeave", function()
            OzUIHelper:hideTooltip()
        end)
    end

    -- Click
    if o.onClick then
        button:SetScript("OnClick", o.onClick)
    end

    return button
end
