

-- ==================== DIAGNOSTIC TEST ====================
do
    local clam_src = [[local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Auto Clam Opener"] = "自动开蚌"
    L["Enable"] = "启用"
    L["Enable auto clam opening feature."] = "启用自动开蚌功能。"
    L["Auto Open on Window Close"] = "窗口关闭时自动开蚌"
    L["Automatically open clams when loot/mail/trade/bank closes."] = "关闭拾取、邮件、交易或银行窗口后自动开蚌。"
    L["Open Clams Now"] = "立即开蚌"
    L["Opening clams..."] = "正在开蚌..."
    L["Clam opener is already running."] = "开蚌功能已在运行中。"
    L["Clam opener is disabled."] = "自动开蚌功能已禁用。"
    L["No clams found in your bags."] = "背包中未找到蚌壳。"
    L["No more clams to open."] = "蚌壳已全部打开。"
    L["Clam opener stopped: %s"] = "开蚌停止: %s"
end

-- Hardcoded vanilla clam item IDs
local CLAM_IDS = {
    [5523]  = true, -- Small Barnacled Clam (小蚌壳)
    [5524]  = true, -- Thick-shelled Clam (厚壳蚌)
    [7973]  = true, -- Big-mouth Clam (巨型蚌壳)
    [15874] = true, -- Soft-shelled Clam (软壳蚌)
}

local OPEN_DELAY = 0.5   -- seconds between opens; lets loot/bag updates settle
local QUIET_DELAY = 0.5  -- seconds of silence after a *_CLOSED event before auto-opening
local running = false
local silentRun = false
local pendingToken = 0   -- bumped on every auto-trigger and on LOOT_OPENED to cancel stale timers
local module = nil

-- ==================== Lightweight Timer Frame ====================

local timer_frame = CreateFrame("Frame", "OzClamOpenerTimerFrame")
timer_frame:Hide()
local scheduled_tasks = {}

local function ScheduleTimer(delay, fn)
    local run_time = GetTime() + delay
    table.insert(scheduled_tasks, { time = run_time, fn = fn })
    timer_frame:Show()
end

local function ClearAllTimers()
    scheduled_tasks = {}
    timer_frame:Hide()
end

timer_frame:SetScript("OnUpdate", function()
    local now = GetTime()
    local i = 1
    while i <= table.getn(scheduled_tasks) do
        local task = scheduled_tasks[i]
        if now >= task.time then
            table.remove(scheduled_tasks, i)
            task.fn()
        else
            i = i + 1
        end
    end
    if table.getn(scheduled_tasks) == 0 then
        timer_frame:Hide()
    end
end)

-- ==================== Window & Bag Helpers ====================

-- Returns true if any blocking window (loot/mail/trade/merchant/bank/auction) is open
local function IsBlockingWindowOpen()
    local frames = {
        "LootFrame", "MailFrame", "TradeFrame", "MerchantFrame",
        "BankFrame", "AuctionFrame",
        "Guda_BankFrame", "Guda_MailboxFrame"
    }
    for _, name in ipairs(frames) do
        local f = getglobal(name)
        if f and f.IsShown and f:IsShown() then
            return true
        end
    end
    return false
end

-- Find the next clam in player bags. Returns bagID, slotID or nil.
local function FindNextClam()
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local link = GetContainerItemLink(bagID, slotID)
                if link then
                    local _, _, idStr = string.find(link, "item:(%d+)")
                    local itemID = idStr and tonumber(idStr)
                    if itemID and CLAM_IDS[itemID] then
                        return bagID, slotID
                    end
                end
            end
        end
    end
    return nil
end

-- ==================== Execution Flow ====================

local event_frame = CreateFrame("Frame", "OzClamOpenerEventFrame")
event_frame:Hide()

local function StopRun(reason)
    if not running then return end
    running = false
    event_frame:UnregisterEvent("UI_ERROR_MESSAGE")
    if reason and not silentRun then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. reason)
    end
    silentRun = false
end

local function OpenNext()
    if not running then return end

    -- Never use a clam while cursor is busy, a blocking window is open, or loot is active
    if CursorHasItem()
       or IsBlockingWindowOpen()
       or (GetNumLootItems and GetNumLootItems() > 0) then
        ScheduleTimer(OPEN_DELAY, OpenNext)
        return
    end

    local bagID, slotID = FindNextClam()
    if not bagID then
        StopRun(L["No more clams to open."])
        return
    end

    UseContainerItem(bagID, slotID)
    ScheduleTimer(OPEN_DELAY, OpenNext)
end

local function OnUIError()
    if not running then return end
    local msg = arg1
    StopRun(string.format(L["Clam opener stopped: %s"], tostring(msg or "error")))
end

OzClamOpener = {}

function OzClamOpener:Open(silent)
    if OZAIO_CONFIG and OZAIO_CONFIG["bag.clam_opener_enable"] == false then
        if not silent then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. L["Clam opener is disabled."])
        end
        return
    end

    if running then
        if not silent then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. L["Clam opener is already running."])
        end
        return
    end

    if not FindNextClam() then
        if not silent then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. L["No clams found in your bags."])
        end
        return
    end

    running = true
    silentRun = (silent == true)
    event_frame:RegisterEvent("UI_ERROR_MESSAGE")
    if not silent then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. L["Opening clams..."])
    end
    OpenNext()
end

local function OnLootOpened()
    -- New loot window opened: invalidate any pending auto-open
    pendingToken = pendingToken + 1
end

local function tryAutoOpen()
    if running then return end
    if OZAIO_CONFIG and OZAIO_CONFIG["bag.clam_opener_enable"] == false then
        return
    end
    if not (OZAIO_CONFIG and OZAIO_CONFIG["bag.auto_open_clams"]) then
        return
    end
    pendingToken = pendingToken + 1
    local myToken = pendingToken
    ScheduleTimer(QUIET_DELAY, function()
        if myToken ~= pendingToken then return end
        if running then return end
        if IsBlockingWindowOpen() then return end
        if GetNumLootItems and GetNumLootItems() > 0 then return end
        OzClamOpener:Open(true)
    end)
end

event_frame:SetScript("OnEvent", function()
    if event == "UI_ERROR_MESSAGE" then
        OnUIError()
    elseif event == "LOOT_OPENED" then
        OnLootOpened()
    elseif event == "LOOT_CLOSED"
        or event == "MAIL_CLOSED"
        or event == "TRADE_CLOSED"
        or event == "BANKFRAME_CLOSED" then
        tryAutoOpen()
    end
end)

-- ==================== Slash Command ====================

SLASH_OZCLAM1 = "/ozclam"
SLASH_OZCLAM2 = "/clam"
SlashCmdList["OZCLAM"] = function(msg)
    OzClamOpener:Open(false)
end

-- ==================== Module Registration ====================

module = OzFramework:registerMod({
    name = "oz_clam_opener",
    title = L["Auto Clam Opener"],
    category = "Bag",
    order = 2,
    enabled = true,
    config = {
        ["bag.clam_opener_enable"] = true,
        ["bag.auto_open_clams"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Auto Clam Opener"],
            tooltip = L["Enable auto clam opening feature."],
            config_key = "bag.clam_opener_enable",
            onChange = function(checked)
                if module then
                    if checked then
                        module:enable()
                    else
                        module:disable()
                    end
                end
            end,
        },
        {
            type = "checkbox",
            label = L["Auto Open on Window Close"],
            tooltip = L["Automatically open clams when loot/mail/trade/bank closes."],
            config_key = "bag.auto_open_clams",
        },
        {
            type = "button",
            label = L["Open Clams Now"],
            func = function()
                OzClamOpener:Open(false)
            end,
            width = 120,
            height = 24,
        },
    },
    enable = function(self)
        if OZAIO_CONFIG and OZAIO_CONFIG["bag.clam_opener_enable"] == false then return end
        event_frame:RegisterEvent("LOOT_OPENED")
        event_frame:RegisterEvent("LOOT_CLOSED")
        event_frame:RegisterEvent("MAIL_CLOSED")
        event_frame:RegisterEvent("TRADE_CLOSED")
        event_frame:RegisterEvent("BANKFRAME_CLOSED")
    end,
    disable = function(self)
        event_frame:UnregisterAllEvents()
        StopRun()
        ClearAllTimers()
    end,
})
]]
    local fn, err = loadstring(clam_src)
    if not fn then
        message("CLAM SYNTAX ERROR:\n" .. tostring(err))
    else
        local ok, rerr = pcall(fn)
        if not ok then
            message("CLAM RUNTIME ERROR:\n" .. tostring(rerr))
        end
    end

    local unlock_src = [[local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Auto Unlock"] = "自动开锁"
    L["Enable Rogue lockpicking utilities."] = "启用潜行者开锁辅助功能。"
    L["Trade Frame Unlock Button"] = "交易界面开锁按钮"
    L["Add an Unlock button to the trade window to quickly pick locks on trade items."] = "在交易窗口添加开锁按钮，快速为交易物品开锁。"
    L["Right-Click Unlock"] = "右键背包开锁"
    L["Right-click locked boxes in your bags to pick lock."] = "在背包中右键点击锁定的箱子直接开锁。"
    L["Unlock"] = "开锁"
    L["Lockpicking spell not found."] = "未找到开锁技能。"
    L["Cast Pick Lock. If an item is in the 'will not be traded' slot, automatically clicks it."] = "施放开锁技能。如果对方不可交易栏有物品，自动点击该栏位。"
    L["(Only active for Rogues)"] = "（仅限潜行者生效）"
end

local _, playerClass = UnitClass("player")
local is_rogue = (playerClass == "ROGUE")
local module = nil

-- ==================== Spell Detection ====================

local function FindPickLockSpell()
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local texture = GetSpellTexture(i, BOOKTYPE_SPELL)
        if name == "Pick Lock" or name == "开锁" or name == "開鎖"
           or (texture and string.find(string.lower(texture), "spell_nature_moonkey")) then
            return i, BOOKTYPE_SPELL
        end
        i = i + 1
    end
    return nil, nil
end

-- ==================== Tooltip Scanner ====================

local scan_owner = CreateFrame("Frame", "OzUnlockTooltipOwner", UIParent)
scan_owner:Hide()
local scan_tooltip = CreateFrame("GameTooltip", "OzUnlockTooltip", scan_owner, "GameTooltipTemplate")

local function IsItemLocked(bag, slot)
    scan_tooltip:SetOwner(scan_owner, "ANCHOR_NONE")
    scan_tooltip:ClearLines()
    scan_tooltip:SetBagItem(bag, slot)
    local num_lines = scan_tooltip:NumLines()
    if not num_lines or num_lines == 0 then
        scan_tooltip:Hide()
        return false
    end
    for i = 2, num_lines do
        local line = getglobal("OzUnlockTooltipTextLeft" .. i)
        if line and line:IsShown() then
            local text = line:GetText()
            if text then
                if string.find(text, "Locked") or string.find(text, "锁定") or string.find(text, "已锁") or (LOCKED and string.find(text, LOCKED)) then
                    scan_tooltip:Hide()
                    return true
                end
            end
        end
    end
    scan_tooltip:Hide()
    return false
end

-- Returns true if player is currently interacting with an interface where right-click has other meanings
local function IsInteractingWindowOpen()
    return (BankFrame and BankFrame:IsVisible())
        or (MerchantFrame and MerchantFrame:IsVisible())
        or (TradeFrame and TradeFrame:IsVisible())
        or (MailFrame and MailFrame:IsVisible())
        or (AuctionFrame and AuctionFrame:IsVisible())
end

-- ==================== Bag Right-Click Hook ====================

local function on_bag_item_click(button, ignoreShift)
    if button == "RightButton" and is_rogue then
        if OZAIO_CONFIG and OZAIO_CONFIG["bag.unlock_enable"] == false then
            return
        end
        if OZAIO_CONFIG and OZAIO_CONFIG["bag.bag_right_click_unlock"] then
            if not IsInteractingWindowOpen() and not (UnitAffectingCombat and UnitAffectingCombat("player")) and this then
                local parent = this.GetParent and this:GetParent()
                local bag = parent and parent.GetID and parent:GetID()
                local slot = this.GetID and this:GetID()
                if bag and slot and bag >= 0 and bag <= 4 and slot >= 1 then
                    if IsItemLocked(bag, slot) then
                        local spell_id, book = FindPickLockSpell()
                        if spell_id then
                            CastSpell(spell_id, book)
                            PickupContainerItem(bag, slot)
                            return false -- Intercept: suppress standard ContainerFrameItemButton_OnClick
                        end
                    end
                end
            end
        end
    end
end

-- ==================== Trade Frame Unlock Button ====================

local trade_button = nil

local function EnsureTradeFrameButton()
    if trade_button then return trade_button end
    if not is_rogue then return nil end
    if not TradeFrame or not TradeFrameCancelButton then return nil end

    trade_button = CreateFrame("Button", "OzAiOTradeUnlockButton", TradeFrame, "UIPanelButtonTemplate")
    trade_button:SetWidth(80)
    trade_button:SetHeight(22)
    trade_button:SetText(L["Unlock"])
    trade_button:SetPoint("TOP", TradeFrameCancelButton, "BOTTOM", 0, -4)

    trade_button:SetScript("OnClick", function()
        local spell_id, book = FindPickLockSpell()
        if not spell_id then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. L["Lockpicking spell not found."])
            return
        end
        CastSpell(spell_id, book)
        -- Slot 7 of the trade partner is the 'will not be traded' slot in WoW 1.12
        if GetTradeTargetItemInfo and GetTradeTargetItemInfo(7) and SpellIsTargeting and SpellIsTargeting() then
            ClickTargetTradeButton(7)
        end
    end)

    trade_button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(trade_button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Unlock"])
        GameTooltip:AddLine(L["Cast Pick Lock. If an item is in the 'will not be traded' slot, automatically clicks it."], 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    trade_button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return trade_button
end

local function UpdateTradeButtonState()
    if not is_rogue then return end
    local master_enabled = not OZAIO_CONFIG or (OZAIO_CONFIG["bag.unlock_enable"] ~= false)
    local button_enabled = not OZAIO_CONFIG or (OZAIO_CONFIG["bag.trade_unlock_button"] ~= false)
    if master_enabled and button_enabled then
        local btn = EnsureTradeFrameButton()
        if btn and TradeFrame and TradeFrame:IsShown() then
            btn:Show()
        end
    else
        if trade_button then
            trade_button:Hide()
        end
    end
end

local trade_event_frame = CreateFrame("Frame", "OzUnlockEventFrame")
trade_event_frame:SetScript("OnEvent", function()
    if event == "TRADE_SHOW" then
        UpdateTradeButtonState()
    elseif event == "TRADE_CLOSED" then
        if trade_button then
            trade_button:Hide()
        end
    end
end)

-- ==================== Module Registration ====================

local config_items = {}
if not is_rogue then
    table.insert(config_items, {
        type = "label",
        label = L["(Only active for Rogues)"],
        font = "GameFontNormalSmall",
    })
end
table.insert(config_items, {
    type = "checkbox",
    label = L["Auto Unlock"],
    tooltip = L["Enable Rogue lockpicking utilities."],
    config_key = "bag.unlock_enable",
    onChange = function(checked)
        if module then
            if checked then
                module:enable()
            else
                module:disable()
            end
        end
        UpdateTradeButtonState()
    end,
})
table.insert(config_items, {
    type = "checkbox",
    label = L["Trade Frame Unlock Button"],
    tooltip = L["Add an Unlock button to the trade window to quickly pick locks on trade items."],
    config_key = "bag.trade_unlock_button",
    onChange = function(val)
        UpdateTradeButtonState()
    end,
})
table.insert(config_items, {
    type = "checkbox",
    label = L["Right-Click Unlock"],
    tooltip = L["Right-click locked boxes in your bags to pick lock."],
    config_key = "bag.bag_right_click_unlock",
})

module = OzFramework:registerMod({
    name = "oz_unlock",
    title = L["Auto Unlock"],
    category = "Bag",
    order = 3,
    enabled = true,
    config = {
        ["bag.unlock_enable"] = true,
        ["bag.trade_unlock_button"] = true,
        ["bag.bag_right_click_unlock"] = true,
    },
    config_ui_creator = config_items,
    enable = function(self)
        if is_rogue then
            if OZAIO_CONFIG and OZAIO_CONFIG["bag.unlock_enable"] == false then return end
            OzHook:hook("ContainerFrameItemButton_OnClick", on_bag_item_click)
            trade_event_frame:RegisterEvent("TRADE_SHOW")
            trade_event_frame:RegisterEvent("TRADE_CLOSED")
            UpdateTradeButtonState()
        end
    end,
    disable = function(self)
        if is_rogue then
            OzHook:unhook("ContainerFrameItemButton_OnClick", on_bag_item_click)
            trade_event_frame:UnregisterAllEvents()
            if trade_button then
                trade_button:Hide()
            end
        end
    end,
})
]]
    local ufn, uerr = loadstring(unlock_src)
    if not ufn then
        message("UNLOCK SYNTAX ERROR:\n" .. tostring(uerr))
    else
        local ok, rerr = pcall(ufn)
        if not ok then
            message("UNLOCK RUNTIME ERROR:\n" .. tostring(rerr))
        end
    end
end
