local LOCALE = GetLocale()
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
    L["Unlock"] = "开锁"
    L["Lockpicking spell not found."] = "未找到开锁技能。"
    L["Cast Pick Lock. If an item is in the 'will not be traded' slot, automatically clicks it."] = "施放开锁技能。如果对方不可交易栏有物品，自动点击该栏位。"
    L["(Only active for Rogues)"] = "（仅限潜行者生效）"
end

local function is_player_rogue()
    local classLoc, classEn = UnitClass("player")
    if classEn and string.upper(classEn) == "ROGUE" then return true end
    if classLoc and (classLoc == "潜行者" or classLoc == "盗贼" or string.upper(classLoc) == "ROGUE") then return true end
    return false
end

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

local scan_owner = nil
local scan_tooltip = nil

local function ensure_scan_tooltip()
    if not scan_tooltip then
        scan_owner = CreateFrame("Frame", "OzUnlockTooltipOwner", UIParent)
        scan_owner:Hide()
        scan_tooltip = CreateFrame("GameTooltip", "OzUnlockTooltip", scan_owner, "GameTooltipTemplate")
    end
end

local function IsItemLocked(bag, slot)
    ensure_scan_tooltip()
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
    if button == "RightButton" and is_player_rogue() then
        if OZAIO_CONFIG and OZAIO_CONFIG["bag.unlock_enable"] == false then
            return
        end
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

-- ==================== Trade Frame Unlock Button ====================

local trade_button = nil

local function EnsureTradeFrameButton()
    if trade_button then return trade_button end
    if not is_player_rogue() then return nil end
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
    if not is_player_rogue() then return end
    local master_enabled = not OZAIO_CONFIG or (OZAIO_CONFIG["bag.unlock_enable"] ~= false)
    if master_enabled then
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

local function build_unlock_config_ui()
    local items = {}
    if not is_player_rogue() then
        table.insert(items, {
            type = "label",
            label = L["(Only active for Rogues)"],
            font = "GameFontNormalSmall",
        })
    end
    table.insert(items, {
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
    return items
end

module = OzFramework:registerMod({
    name = "oz_unlock",
    title = L["Auto Unlock"],
    category = "Bag",
    order = 3,
    enabled = true,
    config = {
        ["bag.unlock_enable"] = true,
    },
    config_ui_creator = build_unlock_config_ui,
    enable = function(self)
        if is_player_rogue() then
            if OZAIO_CONFIG and OZAIO_CONFIG["bag.unlock_enable"] == false then return end
            OzHook:hook("ContainerFrameItemButton_OnClick", on_bag_item_click)
            trade_event_frame:RegisterEvent("TRADE_SHOW")
            trade_event_frame:RegisterEvent("TRADE_CLOSED")
            UpdateTradeButtonState()
        end
    end,
    disable = function(self)
        if is_player_rogue() then
            OzHook:unhook("ContainerFrameItemButton_OnClick", on_bag_item_click)
            trade_event_frame:UnregisterAllEvents()
            if trade_button then
                trade_button:Hide()
            end
        end
    end,
})
