-- OzUIHelper: automatic-layout UI helpers for WoW 1.12
-- Versioned widget factory and layout engine for OzAiO and embedded addons.

local MAJOR, MINOR = "OzUIHelper-1.0", 3
local _G = getfenv(0)
if not _G.OzLib then _G.OzLib = {} end
local Master = _G.OzLib

local active = Master[MAJOR]
if active and active.version >= MINOR then return end

local lib = active or _G.OzUIHelper or { _id = 0 }
lib.version = MINOR
Master[MAJOR], _G.OzUIHelper = lib, lib
local OzUIHelper = lib

-- ==================== Factory & Config ====================
function lib:New(addonName)
    return setmetatable({ addonName = addonName or "OzUI", _id = 0 }, { __index = self })
end

lib.GetInstance = lib.New

function lib:SetAddonName(addonName)
    self.addonName = addonName
end

function lib:nextName(prefix, addonName)
    self._id = (self._id or 0) + 1
    return (addonName or self.addonName or "OzUI") .. "_" .. (prefix or "W") .. "_" .. self._id
end

local function mkBackdrop(bg, edge, es, insets)
    return {
        bgFile = bg,
        edgeFile = edge,
        tile = true,
        tileSize = 16,
        edgeSize = es,
        insets = { left = insets, right = insets, top = insets, bottom = insets }
    }
end
local TT_BG         = "Interface\\Tooltips\\UI-Tooltip-Background"
local TT_BD         = "Interface\\Tooltips\\UI-Tooltip-Border"

lib.Fonts           = { normal = "GameFontNormal", small = "GameFontNormalSmall", large = "GameFontNormalLarge", huge =
"GameFontNormalHuge" }
lib.Theme           = {
    backdrop = {
        widget       = mkBackdrop(TT_BG, TT_BD, 1, 2),
        panel        = mkBackdrop(TT_BG, TT_BD, 8, 3),
        blizaad      = mkBackdrop(TT_BG, TT_BD, 16, 3),
        dropdownItem = mkBackdrop(TT_BG, TT_BD, 1, 2),
        flat         = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
    },
    color = {
        widget        = { bg = { 0.05, 0.05, 0.05, 0.8 }, border = { 0.3, 0.3, 0.3, 0.8 } },
        panel         = { bg = { 0.05, 0.05, 0.08, 0.6 }, border = { 0.2, 0.2, 0.3, 0.5 } },
        dropdownItem  = { bg = { 0.05, 0.05, 0.05, 0.8 }, border = { 0.15, 0.15, 0.15, 0.3 } },
        dropdownHover = { bg = { 0.2, 0.2, 0.3, 0.9 }, border = { 0.4, 0.4, 0.6, 0.8 } },
    },
    dropdown = { height = 20, minWidth = 80, padding = 5, arrowPadding = 5, menuPadX = 2, menuPadY = 2, itemHeight = 18, itemSpacing = 0, labelGap = 6 }
}

lib.BlizaadBackdrop = lib.Theme.backdrop.blizaad
lib.PFUIBackdrop    = lib.Theme.backdrop.flat

lib.Metrics         = {
    padding = 4,
    spacing = 2,
    lineSpacing = 1,
    widgetH = 18,
    editBoxW = 60,
    editBoxH = 18,
    buttonW = 90,
    buttonH = 20,
    checkboxGap = 4,
    labelGap = 6,
    list    = { rowH = 22, contentRightInset = 20, rowPadX = 5, rowPadTop = 2, rowPadBottom = 4, namePadX = 2, qtyPadX = 2, qtyGap = 8 },
    dialog  = {
        width = 500,
        height = 600,
        header = { height = 48, insetL = 11, insetR = 12, insetT = 12 },
        main   = { margin = 15, topOffset = -64, bottomOffset = 15, gap = 5 },
        tab    = { width = 120, btnW = 100, btnH = 16, flowPad = 16 },
        scroll = { step = 22 }
    },
    minimap = { btnSize = 32, radius = 80, iconSize = 21, iconOffX = 7, iconOffY = -6, overlaySize = 56, texCoord = { 0.075, 0.925, 0.075, 0.925 } }
}
local M             = lib.Metrics

-- ==================== Utility ====================
function lib:applyBackdrop(f, style)
    local s = style or "widget"
    local bd, c = self.Theme.backdrop[s], self.Theme.color[s]
    if bd then f:SetBackdrop(bd) end
    if c then
        f:SetBackdropColor(unpack(c.bg)); f:SetBackdropBorderColor(unpack(c.border))
    end
end

function lib:setSize(w, width, height)
    w:SetWidth(width); w:SetHeight(height)
    w._layout = { width = width, height = height }
end

local tooltip
local function getTooltip()
    if not tooltip then
        tooltip = CreateFrame("Frame", "OzUITooltip", UIParent)
        tooltip:SetFrameStrata("TOOLTIP"); tooltip:SetClampedToScreen(true)
        tooltip:SetBackdrop(mkBackdrop(TT_BG, TT_BD, 16, 5))
        tooltip:SetBackdropColor(0, 0, 0, 0.9); tooltip:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
        tooltip.title = tooltip:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        tooltip.title:SetPoint("TOPLEFT", 10, -10); tooltip.title:SetTextColor(1, 0.82, 0); tooltip.title:SetJustifyH(
        "LEFT")
        tooltip.desc = tooltip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        tooltip.desc:SetPoint("TOPLEFT", tooltip.title, "BOTTOMLEFT", 0, -4); tooltip.desc:SetTextColor(0.85, 0.85, 0.85); tooltip
            .desc:SetJustifyH("LEFT")
        tooltip:Hide()
    end
    return tooltip
end

function lib:showTooltip(owner, title, text, anchor)
    if not owner or ((not title or title == "") and (not text or text == "")) then return end
    local tt = getTooltip()
    if GameTooltip and GameTooltip:IsShown() then GameTooltip:Hide() end

    tt.title:SetText(title or ""); if title and title ~= "" then tt.title:Show() else tt.title:Hide() end
    tt.desc:SetText(text or ""); if text and text ~= "" then tt.desc:Show() else tt.desc:Hide() end

    local tw = title and tt.title:GetStringWidth() or 0
    local dw = text and tt.desc:GetStringWidth() or 0
    local maxW = math.min(280, math.max(tw, dw, 60))
    tt.title:SetWidth(maxW); tt.desc:SetWidth(maxW)

    local th = title and (math.max(1, math.ceil(tw / 270)) * 14) or 0
    local _, nl = string.gsub(text or "", "\n", "")
    local dh = text and (math.max(1 + nl, math.ceil(dw / 270) + nl) * 13) or 0

    tt:SetWidth(maxW + 20); tt:SetHeight(24 + th + dh)
    if owner.GetFrameLevel then tt:SetFrameLevel(owner:GetFrameLevel() + 25) end

    tt:ClearAllPoints()
    local anchors = {
        ANCHOR_LEFT       = { "RIGHT", owner, "LEFT", -4, 0 },
        ANCHOR_RIGHT      = { "LEFT", owner, "RIGHT", 4, 0 },
        ANCHOR_BOTTOMLEFT = { "TOPLEFT", owner, "BOTTOMLEFT", 0, -4 },
        ANCHOR_TOPRIGHT   = { "BOTTOMRIGHT", owner, "TOPRIGHT", 0, 4 },
    }
    local a = anchors[anchor] or { "BOTTOMLEFT", owner, "TOPLEFT", 0, 4 }
    tt:SetPoint(a[1], a[2], a[3], a[4], a[5])
    tt:Show()
end

function lib:hideTooltip()
    if tooltip then tooltip:Hide() end
end

-- ==================== Flow Layout ====================
function lib:createFlow(parent, opts)
    local p = type(opts) == "number" and opts or (type(opts) == "table" and opts.padding) or self.Metrics.padding
    local sp = (type(opts) == "table" and opts.spacing) or self.Metrics.spacing
    local ls = (type(opts) == "table" and opts.lineSpacing) or self.Metrics.lineSpacing
    return { parent = parent, x = p, y = -p, startX = p, padding = p, spacing = sp, lineSpacing = ls, lineHeight = 0, items = {}, maxWidth =
    parent:GetWidth() - p }
end

function lib:add(flow, widget, width, height)
    if not flow or not widget then return end
    local w = width or (widget._layout and widget._layout.width) or (widget.GetWidth and widget:GetWidth()) or M.buttonW
    local h = height or (widget._layout and widget._layout.height) or (widget.GetHeight and widget:GetHeight()) or
    M.widgetH

    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", flow.parent, "TOPLEFT", flow.x, flow.y)
    if h and widget.SetHeight then widget:SetHeight(h) end
    if widget.SetJustifyV then widget:SetJustifyV("MIDDLE") end

    flow.x = flow.x + w + flow.spacing
    if h > flow.lineHeight then flow.lineHeight = h end
    table.insert(flow.items, { widget = widget, width = w, height = h })
end

function lib:newLine(flow)
    if not flow then return end
    flow.x = flow.startX; flow.y = flow.y - flow.lineHeight - flow.lineSpacing
    flow.lineHeight = 0; table.insert(flow.items, { newLine = true })
end

function lib:rebuildFlow(flow)
    if not flow or type(flow.items) ~= "table" then return end
    local saved = flow.items
    flow.x, flow.y, flow.lineHeight, flow.items = flow.startX, -flow.padding, 0, {}
    for _, e in ipairs(saved) do
        if e.newLine then self:newLine(flow) else self:add(flow, e.widget, e.width, e.height) end
    end
end

-- ==================== Scrollable Panel ====================
function lib:createScrollPanel(parent, opts)
    local o = opts or {}
    local p, sp, step = o.padding or 8, o.spacing or 4, o.step or 22
    local rightInset = o.rightInset or 20

    local sf = CreateFrame("ScrollFrame", self:nextName("ScrollPanel"), parent)
    self:applyBackdrop(sf, o.backdropStyle or "panel")
    sf:EnableMouseWheel(true)

    local sc = CreateFrame("Frame", self:nextName("ScrollChild"), sf)
    sf:SetScrollChild(sc)

    local panel = {
        scrollFrame = sf,
        scrollChild = sc,
        padding = p,
        spacing = sp,
        rowSpacing = o.rowSpacing or 4,
        step = step,
        rightInset = rightInset,
        currentY = -p,
        widgets = {}
    }

    local function updateDim()
        local sw = sf:GetWidth()
        if sw and sw > panel.rightInset then
            local usableW = sw - panel.rightInset
            sc:SetWidth(usableW)
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

    panel.UpdateDimensions = updateDim
    sf:SetScript("OnSizeChanged", updateDim)
    sf:SetScript("OnMouseWheel", function()
        local cur = this:GetVerticalScroll() - arg1 * panel.step
        local maxS = math.max(0, sc:GetHeight() - sf:GetHeight())
        this:SetVerticalScroll(math.max(0, math.min(cur, maxS)))
    end)

    function panel:UpdateScroll()
        local totalH = math.max(sf:GetHeight() or 0, math.abs(self.currentY) + self.padding)
        sc:SetHeight(totalH)
        local maxS = math.max(0, totalH - (sf:GetHeight() or 0))
        if sf:GetVerticalScroll() > maxS then sf:SetVerticalScroll(maxS) end
    end

    function panel:GetContentHeight()
        return math.abs(self.currentY) + self.padding
    end

    function panel:AddSpace(height)
        self.currentY = self.currentY - (height or 8)
        self:UpdateScroll()
    end

    function panel:Add(widget, wOpts)
        if not widget then return end
        local wo = wOpts or {}
        local h = wo.height or (widget._layout and widget._layout.height) or (widget.GetHeight and widget:GetHeight()) or
        24
        widget:ClearAllPoints(); widget:SetParent(sc)
        widget:SetPoint("TOPLEFT", sc, "TOPLEFT", self.padding, self.currentY)
        if wo.fullWidth or widget._fullWidth then
            widget._wOptsFullWidth = true
            local w = (sf:GetWidth() or 0) - self.rightInset - self.padding * 2
            if w > 0 then
                widget:SetWidth(w); if widget._layout then widget._layout.width = w end
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
        local spacing = (rOpts and rOpts.rowSpacing) or 8

        for _, w in ipairs(rowWidgets) do
            local width = (w._layout and w._layout.width) or (w.GetStringWidth and w:GetStringWidth()) or
            (w.GetWidth and w:GetWidth()) or 100
            local height = (w._layout and w._layout.height) or (w.GetHeight and w:GetHeight()) or 20
            w:ClearAllPoints(); w:SetParent(sc)
            w:SetPoint("TOPLEFT", sc, "TOPLEFT", x, self.currentY)
            x = x + width + spacing
            if height > maxH then maxH = height end
            table.insert(self.widgets, w)
        end
        self.currentY = self.currentY - maxH - self.spacing
        self:UpdateScroll()
    end

    function panel:Clear()
        for _, w in ipairs(self.widgets) do if w.Hide then w:Hide() end end
        self.widgets = {}; self.currentY = -self.padding
        sf:SetVerticalScroll(0); self:UpdateScroll()
    end

    return panel
end

-- ==================== Layout & Primitives ====================
function lib:anchor(w, parent, point, relPoint, x, y)
    w:SetPoint(point or "TOPLEFT", parent, relPoint or point or "TOPLEFT", x or 0, y or 0)
end

function lib:dock(w, parent, side, size, pad)
    w:ClearAllPoints(); local p = pad or 0
    if side == "top" then
        self:anchor(w, parent, "TOPLEFT", "TOPLEFT", p, -p); self:anchor(w, parent, "TOPRIGHT", "TOPRIGHT", -p, -p); w
            :SetHeight(size)
    elseif side == "bottom" then
        self:anchor(w, parent, "BOTTOMLEFT", "BOTTOMLEFT", p, p); self:anchor(w, parent, "BOTTOMRIGHT", "BOTTOMRIGHT", -
        p, p); w:SetHeight(size)
    elseif side == "left" then
        self:anchor(w, parent, "TOPLEFT", "TOPLEFT", p, -p); self:anchor(w, parent, "BOTTOMLEFT", "BOTTOMLEFT", p, p); w
            :SetWidth(size)
    elseif side == "right" then
        self:anchor(w, parent, "TOPRIGHT", "TOPRIGHT", -p, -p); self:anchor(w, parent, "BOTTOMRIGHT", "BOTTOMRIGHT", -p,
            p); w:SetWidth(size)
    end
end

function lib:makeMovable(f)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
end

function lib:onResize(frame, callback)
    local old = frame:GetScript("OnSizeChanged")
    frame:SetScript("OnSizeChanged", function()
        if old then old() end
        callback(this, this:GetWidth(), this:GetHeight())
    end)
end

function lib:attachResize(frame, flow)
    self:onResize(frame, function(f, width)
        flow.maxWidth = width - flow.padding
        self:rebuildFlow(flow)
    end)
end

function lib:createLabel(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or self.Fonts.normal)
    fs:SetText(text or ""); fs:SetJustifyV("MIDDLE")
    self:setSize(fs, fs:GetStringWidth() or 100, fs:GetHeight() > 0 and fs:GetHeight() or 14)
    return fs
end

function lib:setFont(fs, font, size, flags)
    if fs and font then fs:SetFont(font, size, flags) end
end

function lib:createButton(parent, text, onClick, width, height)
    local btn = CreateFrame("Button", self:nextName("Btn"), parent, "UIPanelButtonTemplate")
    self:setSize(btn, width or M.buttonW, height or M.buttonH)
    btn:SetText(text or "")
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

function lib:createEditBox(parent, width, height, onEnter)
    local eb = CreateFrame("EditBox", self:nextName("Edit"), parent)
    self:setSize(eb, width or M.editBoxW, height or M.editBoxH)
    eb:SetAutoFocus(false); eb:SetFontObject(GameFontNormal)
    if eb.SetTextInsets then eb:SetTextInsets(4, 4, 0, 0) end
    self:applyBackdrop(eb, "widget")
    if onEnter then eb:SetScript("OnEnterPressed", function()
            onEnter(eb:GetText()); eb:ClearFocus()
        end) end
    return eb
end

function lib:createSeparator(parent, width)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(1, 1, 1, 0.15)
    self:setSize(tex, width or 300, 1)
    tex._fullWidth = true
    return tex
end

function lib:createHeader(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    local fs = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 0, 0); fs:SetText(text or ""); fs:SetTextColor(1, 0.82, 0)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.2); line:SetPoint("BOTTOMLEFT", 0, 2); line:SetPoint("BOTTOMRIGHT", 0, 2); line:SetHeight(1)
    self:setSize(f, 300, 20); f._fullWidth, f.text, f.line = true, fs, line
    return f
end

function lib:createFoldableHeader(parent, text, isFolded, onToggle, locTable)
    local frame = CreateFrame("Button", self:nextName("FoldHeader"), parent)
    self:setSize(frame, 300, 20)
    frame._fullWidth = true
    self:applyBackdrop(frame, "flat")
    frame:SetBackdropColor(0.12, 0.12, 0.15, 0.5)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.6)

    local indicator = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    indicator:SetPoint("LEFT", frame, "LEFT", 6, 0)

    local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", indicator, "RIGHT", 6, 0); fs:SetText(text or ""); fs:SetTextColor(1, 0.82, 0)

    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hint:SetPoint("RIGHT", frame, "RIGHT", -4, 0)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.2); line:SetPoint("BOTTOMLEFT", 0, 2); line:SetPoint("BOTTOMRIGHT", 0, 2); line:SetHeight(1)
    frame.text, frame.indicator, frame.hint, frame.line = fs, indicator, hint, line

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
        local tip = this.isFolded and get_loc("Click to expand this section.", "Click to expand this section.") or
        get_loc("Click to collapse this section.", "Click to collapse this section.")
        lib:showTooltip(this, text, tip, "ANCHOR_TOPLEFT")
    end)
    frame:SetScript("OnLeave", function()
        fs:SetTextColor(1, 0.82, 0)
        lib:hideTooltip()
    end)
    frame:SetScript("OnClick", function()
        if onToggle then onToggle(this) end
        if this:IsShown() and tooltip and tooltip:IsShown() then
            local tip = this.isFolded and get_loc("Click to expand this section.", "Click to expand this section.") or
            get_loc("Click to collapse this section.", "Click to collapse this section.")
            lib:showTooltip(this, text, tip, "ANCHOR_TOPLEFT")
        end
    end)
    return frame
end

function lib:createSlider(parent, label, minVal, maxVal, step, defaultVal, onChange, width)
    local f = CreateFrame("Frame", nil, parent)
    self:setSize(f, width or 160, 32)
    local sName = self:nextName("Slider")
    local s = CreateFrame("Slider", sName, f, "OptionsSliderTemplate")
    s:SetPoint("BOTTOMLEFT", 0, 1); s:SetPoint("BOTTOMRIGHT", 0, 1); s:SetHeight(14)
    s:SetMinMaxValues(minVal or 0, maxVal or 100); s:SetValueStep(step or 1)

    local txt, low, high = getglobal(sName .. "Text"), getglobal(sName .. "Low"), getglobal(sName .. "High")
    if low then low:SetText(tostring(minVal or 0)) end
    if high then high:SetText(tostring(maxVal or 100)) end
    s:SetValue(defaultVal or minVal or 0)

    local function updateText(v)
        if txt then txt:SetText((label or "") .. ": " .. (step and step < 1 and string.format("%.2f", v) or tostring(v))) end
    end
    updateText(s:GetValue())

    s:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        if step and step > 0 then v = math.floor(v / step + 0.5) * step end
        updateText(v)
        if onChange then onChange(v) end
    end)
    function f:SetValue(v)
        s:SetValue(v); updateText(v)
    end

    function f:GetValue() return s:GetValue() end

    return f
end

-- ==================== Compound Widgets ====================
function lib:createCheckbox(parent, text, value, onChange)
    local f = CreateFrame("Button", nil, parent)
    f:EnableMouse(true); f:RegisterForClicks("LeftButtonUp")

    local cb = CreateFrame("CheckButton", self:nextName("CB"), f)
    cb:SetPoint("LEFT", 0, 0); self:setSize(cb, M.widgetH, M.widgetH); self:applyBackdrop(cb, "widget")
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); check:SetPoint("TOPLEFT", 1, -1); check:SetPoint(
    "BOTTOMRIGHT", -1, 1); check:Hide()

    local lbl = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("LEFT", cb, "RIGHT", M.checkboxGap, 0); lbl:SetText(text or "")
    self:setSize(f, M.widgetH + M.checkboxGap + lbl:GetStringWidth(), M.widgetH)

    local function sync() if cb:GetChecked() then check:Show() else check:Hide() end end
    cb:SetChecked((value and value ~= 0 and value ~= "0") and 1 or nil); sync()

    cb:SetScript("OnClick", function()
        local isChecked = cb:GetChecked() and true or false
        sync()
        if onChange then onChange(isChecked) end
    end)
    f:SetScript("OnClick", function() cb:Click() end)
    function f:SetValue(v)
        cb:SetChecked((v and v ~= 0 and v ~= "0") and 1 or nil); sync()
    end

    function f:GetValue() return cb:GetChecked() and true or false end

    return f
end

function lib:createLabeledEditBox(parent, labelText, editWidth)
    local widget = CreateFrame("Frame", nil, parent)
    local label = self:createLabel(widget, labelText)
    label:SetPoint("LEFT", widget, "LEFT", 0, 0)
    local ew = editWidth or M.editBoxW
    local edit = self:createEditBox(widget, ew, M.editBoxH)
    edit:SetPoint("LEFT", label, "RIGHT", M.labelGap, 0)
    self:setSize(widget, label:GetStringWidth() + M.labelGap + ew, M.widgetH)

    widget.editBox, widget._callback = edit, nil
    function widget:SetValue(v) self.editBox:SetText(tostring(v)) end

    function widget:GetValue() return self.editBox:GetText() end

    function widget:SetCallback(f) self._callback = f end

    edit:SetScript("OnEnterPressed", function()
        if widget._callback then widget._callback(this:GetText()) end
        this:ClearFocus()
    end)
    return widget
end

function lib:createLabeledEditArea(parent, labelText, width, height)
    local f = CreateFrame("Frame", nil, parent)
    local w, h = width or 280, height or 60
    local labelH = (labelText and labelText ~= "") and 18 or 0
    if labelH > 0 then
        local l = self:createLabel(f, labelText); l:SetPoint("TOPLEFT", 0, 0)
    end

    local bg = CreateFrame("Frame", nil, f)
    bg:SetPoint("TOPLEFT", 0, -labelH); bg:SetWidth(w); bg:SetHeight(h)
    self:applyBackdrop(bg, "widget"); bg:EnableMouse(true)

    local eb = CreateFrame("EditBox", self:nextName("EditArea"), bg)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(500)
    eb:SetPoint("TOPLEFT", 6, -6); eb:SetPoint("BOTTOMRIGHT", -6, 6)
    eb:SetFontObject(GameFontHighlightSmall)
    bg:SetScript("OnMouseDown", function() eb:SetFocus() end)
    self:setSize(f, w, labelH + h)

    eb.lastText, f.editBox = eb:GetText() or "", eb
    local function checkChange()
        local cur = eb:GetText() or ""
        if cur ~= eb.lastText then
            eb.lastText = cur; if f._cb then f._cb(cur) end
        end
    end

    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function()
        this._focus = true
        lib._activeEditArea = this
        Master._activeEditArea = this
    end)
    eb:SetScript("OnEditFocusLost", function()
        this._focus = nil
        if lib._activeEditArea == this then lib._activeEditArea = nil end
        if Master._activeEditArea == this then Master._activeEditArea = nil end
        checkChange()
    end)

    local t = 0
    eb:SetScript("OnUpdate", function()
        if not this._focus then return end
        t = t + (arg1 or 0)
        if t >= 0.1 then
            t = 0; checkChange()
        end
    end)

    function f:SetValue(v)
        eb:SetText(tostring(v or "")); eb.lastText = eb:GetText()
    end

    function f:GetValue() return eb:GetText() end

    function f:SetCallback(cb) self._cb = cb end

    return f
end

function lib:createDropdown(parent, label, options, defaultValue, onChange)
    local DD = self.Theme.dropdown
    local f = CreateFrame("Frame", nil, parent)
    local lbl = self:createLabel(f, label or ""); lbl:SetPoint("LEFT", 0, 0)

    local opts = options or {}
    local maxW = 0
    for _, opt in pairs(opts) do
        local str = opt.label or tostring(opt.value)
        if string.len(str) * 7 > maxW then maxW = string.len(str) * 7 end
    end
    local btnW = math.max(DD.minWidth, maxW + DD.arrowPadding * 2 + 20)

    local btn = CreateFrame("Button", self:nextName("DD"), f)
    btn:SetWidth(btnW); btn:SetHeight(DD.height); btn:SetPoint("LEFT", lbl, "RIGHT", DD.labelGap, 0)
    self:applyBackdrop(btn, "widget")

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", DD.padding, 0); btnText:SetJustifyH("LEFT"); btnText:SetWidth(btnW - DD.padding * 2)

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -DD.arrowPadding, 0); arrow:SetText("\226\150\188"); arrow:SetTextColor(0.5, 0.5, 0.5)

    local list = {}
    for _, o in pairs(opts) do table.insert(list, o) end
    local count = table.getn(list)
    local menuH = count * DD.itemHeight + DD.menuPadY * 2

    local function getLabel(val)
        for _, o in ipairs(list) do if o.value == val then return o.label or tostring(val) end end
        return tostring(val or "Select...")
    end
    btnText:SetText(getLabel(defaultValue))

    local function getBlocker()
        if not Master._dropdownBlocker then
            local b = CreateFrame("Frame", "OzUI_DropdownBlocker", UIParent)
            b:SetFrameStrata("DIALOG"); b:SetAllPoints(UIParent); b:EnableMouse(true); b:Hide()
            b:SetScript("OnMouseDown", function()
                if Master._activeDD then
                    Master._activeDD:Hide(); Master._activeDD = nil
                end
                this:Hide()
            end)
            Master._dropdownBlocker = b
        end
        return Master._dropdownBlocker
    end

    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetWidth(btnW); menu:SetHeight(menuH)
    self:applyBackdrop(menu, "widget"); menu:SetBackdropColor(0.05, 0.05, 0.05, 0.95); menu:Hide()
    menu:SetScript("OnHide", function()
        if Master._activeDD == menu then
            Master._activeDD = nil; getBlocker():Hide()
        end
    end)

    for i, opt in ipairs(list) do
        local optValue = opt.value
        local optLabel = opt.label or tostring(opt.value)

        local item = CreateFrame("Button", nil, menu)
        item:SetWidth(btnW - DD.menuPadX * 2); item:SetHeight(DD.itemHeight)
        item:SetPoint("TOPLEFT", DD.menuPadX, -DD.menuPadY - (i - 1) * DD.itemHeight)
        self:applyBackdrop(item, "dropdownItem")

        local itText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itText:SetPoint("LEFT", DD.padding, 0); itText:SetText(optLabel); itText:SetTextColor(1, 1, 1)

        item:SetScript("OnEnter", function()
            self:applyBackdrop(item, "dropdownHover"); itText:SetTextColor(1, 0.82, 0)
        end)
        item:SetScript("OnLeave", function()
            self:applyBackdrop(item, "dropdownItem"); itText:SetTextColor(1, 1, 1)
        end)
        item:SetScript("OnClick", function()
            btnText:SetText(optLabel)
            menu:Hide()
            if onChange then onChange(optValue) end
        end)
    end

    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            if Master._activeDD then Master._activeDD:Hide() end
            getBlocker():Show()
            Master._activeDD = menu
            local _, y = btn:GetCenter()
            menu:ClearAllPoints()
            if y and (y - menuH < 0) then
                menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
            else
                menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            end
            menu:Show(); menu:Raise()
        end
    end)

    self:setSize(f, lbl:GetStringWidth() + DD.labelGap + btnW, DD.height)
    function f:SetValue(v) btnText:SetText(getLabel(v)) end

    function f:GetValue()
        local txt = btnText:GetText()
        for _, o in ipairs(list) do if (o.label or tostring(o.value)) == txt then return o.value end end
    end

    return f
end

-- ==================== Scrollable Item List ====================
function lib:createScrollItemList(parent, opts)
    local o             = opts or {}
    local width         = o.width or 300
    local height        = o.height or 100
    local getItems      = o.getItems or function() return {} end
    local sortFunc      = o.sortFunc
    local emptyText     = o.emptyText or "No items"
    local showQty       = (o.showQty ~= false)
    local totalPrefix   = o.totalPrefix or "Total: "
    local nameColorFunc = o.nameColorFunc
    local LS            = self.Metrics.list

    local scrollFrame   = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetWidth(width); scrollFrame:SetHeight(height)
    self:applyBackdrop(scrollFrame, "panel")

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(width - LS.contentRightInset)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:EnableMouseWheel(true)

    scrollFrame:SetScript("OnMouseWheel", function()
        local cur = this:GetVerticalScroll() - arg1 * LS.rowH
        local maxS = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        this:SetVerticalScroll(math.max(0, math.min(cur, maxS)))
    end)

    local widget = {}
    scrollFrame:SetScript("OnSizeChanged", function()
        local sw = this:GetWidth()
        if sw and sw > LS.contentRightInset then
            scrollChild:SetWidth(sw - LS.contentRightInset)
            if widget.refresh then widget:refresh() end
        end
    end)

    local totalLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalLabel:SetTextColor(0.5, 0.5, 0.5)

    local rowPool = {}
    local emptyLabel = nil

    local function getRow(index)
        if not rowPool[index] then
            local rowFrame  = CreateFrame("Frame", nil, scrollChild)
            local nameLabel = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            local qtyLabel  = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            rowPool[index]  = { frame = rowFrame, nameLabel = nameLabel, qtyLabel = qtyLabel }
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
        if sortFunc then table.sort(itemList, sortFunc) end

        local count = table.getn(itemList)
        if count == 0 then
            if not emptyLabel then
                emptyLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                emptyLabel:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
                emptyLabel:SetText(emptyText); emptyLabel:SetTextColor(0.4, 0.4, 0.4)
            end
            emptyLabel:Show()
            for _, r in ipairs(rowPool) do r.frame:Hide() end
            scrollChild:SetHeight(height)
            totalLabel:SetText(totalPrefix .. "0")
            return
        end

        if emptyLabel then emptyLabel:Hide() end
        local totalH = count * LS.rowH + LS.rowPadTop + LS.rowPadBottom
        scrollChild:SetHeight(math.max(totalH, height))
        local innerW = scrollChild:GetWidth()

        for i = 1, count do
            local itemData = itemList[i]
            local itemID   = itemData.itemID
            local capValue = itemData.value
            local r        = getRow(i)

            r.frame:ClearAllPoints()
            r.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", LS.rowPadX, -LS.rowPadTop - (i - 1) * LS.rowH)
            r.frame:SetWidth(innerW - LS.rowPadX * 2); r.frame:SetHeight(LS.rowH)

            r.nameLabel:ClearAllPoints()
            r.nameLabel:SetPoint("LEFT", r.frame, "LEFT", LS.namePadX, 0)
            r.nameLabel:SetJustifyH("LEFT")

            local name, _, quality = GetItemInfo(itemID)
            r.nameLabel:SetText(name or ("Item #" .. tostring(itemID)))

            if nameColorFunc then
                local cr, cg, cb = nameColorFunc(itemID, quality)
                if cr then r.nameLabel:SetTextColor(cr, cg, cb) else r.nameLabel:SetTextColor(1, 1, 1) end
            elseif quality and OzLib and OzLib.ITEM_QUALITY_COLORS and OzLib.ITEM_QUALITY_COLORS[quality] then
                local qc = OzLib.ITEM_QUALITY_COLORS[quality]
                r.nameLabel:SetTextColor(qc[1], qc[2], qc[3])
            else
                r.nameLabel:SetTextColor(1, 1, 1)
            end

            if showQty then
                r.qtyLabel:ClearAllPoints()
                r.qtyLabel:SetPoint("RIGHT", r.frame, "RIGHT", -LS.qtyPadX, 0)
                r.qtyLabel:SetText("x " .. tostring(capValue))
                r.qtyLabel:Show()
                r.nameLabel:SetWidth(innerW - LS.namePadX - LS.qtyPadX - r.qtyLabel:GetStringWidth() - LS.qtyGap)
            else
                r.qtyLabel:Hide()
                r.nameLabel:SetWidth(innerW - LS.namePadX - LS.qtyPadX)
            end
            r.frame:Show()
        end

        for k = count + 1, table.getn(rowPool) do rowPool[k].frame:Hide() end
        totalLabel:SetText(totalPrefix .. count)
    end

    return widget
end

-- ==================== Class Colors ====================
lib.CLASS_COLORS = {
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

function lib:classColor(class)
    if not class then return 1, 1, 1 end
    local color = self.CLASS_COLORS[string.lower(class)]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- ==================== Minimap Widget ====================
function lib:createMinimapButton(opts)
    local o = opts or {}
    local MM = o.metrics or self.Metrics.minimap
    local btn = CreateFrame("Button", o.name or self:nextName("Minimap"), Minimap)
    btn:SetWidth(MM.btnSize); btn:SetHeight(MM.btnSize); btn:SetFrameStrata("LOW")
    btn:EnableMouse(true); btn:SetMovable(true); btn:RegisterForDrag("LeftButton")

    local state = o.angleState or btn
    local function updatePos()
        local rad = math.rad(state.minimap_angle or 0)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * MM.radius, math.sin(rad) * MM.radius)
    end
    updatePos()

    if o.icon then
        local icon = btn:CreateTexture(nil, "BACKGROUND")
        icon:SetTexture(o.icon); icon:SetWidth(MM.iconSize); icon:SetHeight(MM.iconSize)
        icon:SetPoint("TOPLEFT", MM.iconOffX, MM.iconOffY)
        icon:SetTexCoord(unpack(o.texCoord or MM.texCoord))
    end
    if o.overlay then
        local ov = btn:CreateTexture(nil, "OVERLAY")
        ov:SetTexture(o.overlay); ov:SetWidth(MM.overlaySize); ov:SetHeight(MM.overlaySize); ov:SetPoint("TOPLEFT", 0, 0)
    end
    if o.highlight then
        btn:SetHighlightTexture(o.highlight, "ADD")
    end

    btn:SetScript("OnDragStart", function()
        btn:SetScript("OnUpdate", function()
            local mx, my = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            local sx, sy = Minimap:GetCenter()
            local a = math.deg(math.atan2((my / s) - sy, (mx / s) - sx))
            state.minimap_angle = (a < 0) and (a + 360) or a
            updatePos()
        end)
    end)
    btn:SetScript("OnDragStop", function() btn:SetScript("OnUpdate", nil) end)
    if o.tooltipTitle then
        btn:SetScript("OnEnter", function() lib:showTooltip(this, o.tooltipTitle, o.tooltipText, "ANCHOR_LEFT") end)
        btn:SetScript("OnLeave", function() lib:hideTooltip() end)
    end
    if o.onClick then btn:SetScript("OnClick", o.onClick) end
    return btn
end
