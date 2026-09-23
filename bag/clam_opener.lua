local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Auto Clam Opener"] = "自动开蚌"
    L["Enable auto clam opening feature."] = "启用自动开蚌功能。"
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

local OPEN_DELAY = 0.5  -- seconds between opens; lets loot/bag updates settle
local QUIET_DELAY = 0.5 -- seconds of silence after a *_CLOSED event before auto-opening
local running = false
local silentRun = false
local pendingToken = 0 -- bumped on every auto-trigger and on LOOT_OPENED to cancel stale timers
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

-- ==================== Module Registration ====================

module = OzFramework:registerMod({
    name = "oz_clam_opener",
    title = L["Auto Clam Opener"],
    category = "Bag",
    order = 2,
    enabled = true,
    config = {
        ["bag.clam_opener_enable"] = true,
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
