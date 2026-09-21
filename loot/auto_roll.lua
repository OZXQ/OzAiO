local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Auto Roll"] = "自动掷骰"
    L["Automatically roll on raid/dungeon reputation items."] = "自动对团队/地下城声望物品进行掷骰（需求/贪婪/放弃）。"
    L["Enable Auto Roll"] = "启用自动掷骰"
    L["Auto-Confirm BoP"] = "自动确认拾取绑定"
    L["Automatically confirm Bind on Pickup dialogs for auto-rolled items."] = "对自动掷骰的拾取绑定物品自动点击确定，避免弹窗打断战斗。"
    L["Announce in Chat"] = "聊天栏提示"
    L["Print chat message when automatically rolling on items."] = "在聊天窗口提示自动掷骰操作。"
    L["ZG Bijous (宝石)"] = "祖尔格拉布宝石"
    L["Roll rule for Zul'Gurub Hakkari Bijous (all 9 colors)."] = "祖尔格拉布9种哈卡莱双子宝石的掷骰规则。"
    L["ZG Coins (硬币)"] = "祖尔格拉布硬币"
    L["Roll rule for Zul'Gurub Coins (Zulian, Razzashi, Hakkari, etc.)."] = "祖尔格拉布9种声望硬币的掷骰规则。"
    L["CoT Corrupted Sand (时光之穴)"] = "时光之穴腐蚀之沙"
    L["Roll rule for Caverns of Time Corrupted Sand (ID 50203)."] = "时光之穴/黑色沼泽腐蚀之沙（ID: 50203）的掷骰规则。"
    L["Disabled"] = "禁用/手动"
    L["Need"] = "需求"
    L["Greed"] = "贪婪"
    L["Pass"] = "放弃"
    L["Auto-Rolled %s on %s"] = "自动掷骰: %s -> %s"
end

local ACTION_NEED  = "need"
local ACTION_GREED = "greed"
local ACTION_PASS  = "pass"
local ACTION_MANUAL = "manual"

-- Zul'Gurub Hakkari Bijous (哈卡莱宝石, IDs 19707–19715)
local ZG_BIJOUS = {
    [19707] = true, -- 红色哈卡莱双子宝石 Red Hakkari Bijou
    [19708] = true, -- 蓝色哈卡莱双子宝石 Blue Hakkari Bijou
    [19709] = true, -- 黄色哈卡莱双子宝石 Yellow Hakkari Bijou
    [19710] = true, -- 橙色哈卡莱双子宝石 Orange Hakkari Bijou
    [19711] = true, -- 绿色哈卡莱双子宝石 Green Hakkari Bijou
    [19712] = true, -- 紫色哈卡莱双子宝石 Purple Hakkari Bijou
    [19713] = true, -- 青铜哈卡莱双子宝石 Bronze Hakkari Bijou
    [19714] = true, -- 白银哈卡莱双子宝石 Silver Hakkari Bijou
    [19715] = true, -- 黄金哈卡莱双子宝石 Gold Hakkari Bijou
}

-- Zul'Gurub Coins (祖尔格拉布硬币, IDs 19698–19706)
local ZG_COINS = {
    [19698] = true, -- 祖利安硬币 Zulian Coin
    [19699] = true, -- 拉扎什硬币 Razzashi Coin
    [19700] = true, -- 哈卡莱硬币 Hakkari Coin
    [19701] = true, -- 古拉巴什硬币 Gurubashi Coin
    [19702] = true, -- 邪枝硬币 Vilebranch Coin
    [19703] = true, -- 枯木硬币 Witherbark Coin
    [19704] = true, -- 沙怒硬币 Sandfury Coin
    [19705] = true, -- 劈颅硬币 Skullsplitter Coin
    [19706] = true, -- 血顶硬币 Bloodscalp Coin
}

-- Caverns of Time: Corrupted Sand (时光之穴: 腐蚀之沙)
local COT_ITEMS = {
    [50203] = true, -- 腐蚀之沙 Corrupted Sand
}

local pending_confirm = {}
local handled_rolls = {}
local module = nil

-- Item classifier: returns category ("zg_bijous", "zg_coins", "cot_items") or nil
local function ClassifyItem(itemID, itemName)
    if itemID then
        if ZG_BIJOUS[itemID] then return "zg_bijous" end
        if ZG_COINS[itemID] then return "zg_coins" end
        if COT_ITEMS[itemID] then return "cot_items" end
    end

    if itemName then
        local lowerName = string.lower(itemName)
        -- Name-based fallback for ZG Bijous
        if string.find(lowerName, "bijou") or string.find(itemName, "双子宝石") or string.find(itemName, "哈卡莱宝石") then
            return "zg_bijous"
        end
        -- Name-based fallback for ZG Coins
        if (string.find(lowerName, "coin") or string.find(itemName, "硬币")) and
           (string.find(lowerName, "zulian") or string.find(lowerName, "razzashi") or
            string.find(lowerName, "hakkari") or string.find(lowerName, "gurubashi") or
            string.find(lowerName, "vilebranch") or string.find(lowerName, "witherbark") or
            string.find(lowerName, "sandfury") or string.find(lowerName, "skullsplitter") or
            string.find(lowerName, "bloodscalp") or string.find(itemName, "祖利安") or
            string.find(itemName, "拉扎什") or string.find(itemName, "哈卡莱") or
            string.find(itemName, "古拉巴什") or string.find(itemName, "邪枝") or
            string.find(itemName, "枯木") or string.find(itemName, "沙怒") or
            string.find(itemName, "劈颅") or string.find(itemName, "血顶")) then
            return "zg_coins"
        end
        -- Name-based fallback for CoT Corrupted Sand
        if string.find(itemName, "腐蚀之沙") or string.find(lowerName, "corrupted sand") then
            return "cot_items"
        end
    end

    return nil
end

local function GetCategoryAction(category)
    if not OZAIO_CONFIG then return ACTION_MANUAL end
    if category == "zg_bijous" then
        return OZAIO_CONFIG["loot.zg_bijous_action"] or ACTION_NEED
    elseif category == "zg_coins" then
        return OZAIO_CONFIG["loot.zg_coins_action"] or ACTION_NEED
    elseif category == "cot_items" then
        return OZAIO_CONFIG["loot.cot_items_action"] or ACTION_NEED
    end
    return ACTION_MANUAL
end

local function ResolveRollType(action, canNeed, canGreed)
    if action == ACTION_NEED then
        if canNeed and (canNeed == 1 or canNeed == true) then
            return 1 -- Need
        elseif canGreed and (canGreed == 1 or canGreed == true) then
            return 2 -- Fallback to Greed
        else
            return 0 -- Fallback to Pass
        end
    elseif action == ACTION_GREED then
        if canGreed and (canGreed == 1 or canGreed == true) then
            return 2 -- Greed
        else
            return 0 -- Fallback to Pass
        end
    elseif action == ACTION_PASS then
        return 0 -- Pass
    end
    return nil -- Manual
end

local function ActionLabel(rollType)
    if rollType == 1 then return "|cff00ff00" .. L["Need"] .. "|r" end
    if rollType == 2 then return "|cff00ccff" .. L["Greed"] .. "|r" end
    if rollType == 0 then return "|cffff6600" .. L["Pass"] .. "|r" end
    return ""
end

-- ==================== Event Handling ====================

local event_frame = CreateFrame("Frame", "OzAutoRollEventFrame")

local function OnStartLootRoll(rollID)
    if not rollID or handled_rolls[rollID] then return end
    if OZAIO_CONFIG and OZAIO_CONFIG["loot.auto_roll_enable"] == false then return end

    local link = GetLootRollItemLink(rollID)
    local itemID = nil
    if link then
        local _, _, idStr = string.find(link, "item:(%d+)")
        if idStr then itemID = tonumber(idStr) end
    end

    local texture, name, count, quality, bop, canNeed, canGreed = GetLootRollItemInfo(rollID)
    local category = ClassifyItem(itemID, name)
    if not category then return end

    local action = GetCategoryAction(category)
    if not action or action == ACTION_MANUAL then return end

    local rollType = ResolveRollType(action, canNeed, canGreed)
    if rollType ~= nil then
        handled_rolls[rollID] = true
        pending_confirm[rollID] = rollType

        RollOnLoot(rollID, rollType)

        if OZAIO_CONFIG and OZAIO_CONFIG["loot.announce_roll"] ~= false then
            local displayName = link or (name and ("[" .. name .. "]")) or ("[" .. tostring(itemID or rollID) .. "]")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. string.format(L["Auto-Rolled %s on %s"], ActionLabel(rollType), displayName))
        end
    end
end

local function OnConfirmLootRoll(rollID, rollType)
    if not rollID then return end
    if OZAIO_CONFIG and OZAIO_CONFIG["loot.auto_roll_enable"] == false then return end
    if OZAIO_CONFIG and OZAIO_CONFIG["loot.auto_confirm_bop"] == false then return end

    if pending_confirm[rollID] then
        ConfirmLootRoll(rollID, rollType)
        pending_confirm[rollID] = nil

        -- Dismiss matching Blizzard confirmation static popup
        for i = 1, STATICPOPUP_NUMDIALOGS do
            local dialog = getglobal("StaticPopup" .. i)
            if dialog and dialog:IsShown() and dialog.which == "CONFIRM_LOOT_ROLL" then
                dialog:Hide()
            end
        end
    end
end

event_frame:SetScript("OnEvent", function()
    if event == "START_LOOT_ROLL" then
        OnStartLootRoll(arg1)
    elseif event == "CONFIRM_LOOT_ROLL" then
        OnConfirmLootRoll(arg1, arg2)
    end
end)

-- ==================== Config UI ====================

local action_options = {
    { label = L["Disabled"], value = ACTION_MANUAL },
    { label = L["Need"],     value = ACTION_NEED },
    { label = L["Greed"],    value = ACTION_GREED },
    { label = L["Pass"],     value = ACTION_PASS },
}

local function build_roll_config_ui()
    return {
        {
            type = "checkbox",
            label = L["Enable Auto Roll"],
            tooltip = L["Automatically roll on raid/dungeon reputation items."],
            config_key = "loot.auto_roll_enable",
            onChange = function(checked)
                if module then
                    if checked then module:enable() else module:disable() end
                end
            end,
        },
        {
            type = "checkbox",
            label = L["Auto-Confirm BoP"],
            tooltip = L["Automatically confirm Bind on Pickup dialogs for auto-rolled items."],
            config_key = "loot.auto_confirm_bop",
        },
        {
            type = "checkbox",
            label = L["Announce in Chat"],
            tooltip = L["Print chat message when automatically rolling on items."],
            config_key = "loot.announce_roll",
        },
        { type = "separator" },
        {
            type = "dropdown",
            label = L["ZG Bijous (宝石)"],
            tooltip = L["Roll rule for Zul'Gurub Hakkari Bijous (all 9 colors)."],
            options = action_options,
            config_key = "loot.zg_bijous_action",
            default = ACTION_NEED,
        },
        {
            type = "dropdown",
            label = L["ZG Coins (硬币)"],
            tooltip = L["Roll rule for Zul'Gurub Coins (Zulian, Razzashi, Hakkari, etc.)."],
            options = action_options,
            config_key = "loot.zg_coins_action",
            default = ACTION_NEED,
        },
        {
            type = "dropdown",
            label = L["CoT Corrupted Sand (时光之穴)"],
            tooltip = L["Roll rule for Caverns of Time Corrupted Sand (ID 50203)."],
            options = action_options,
            config_key = "loot.cot_items_action",
            default = ACTION_NEED,
        },
    }
end

-- ==================== Module Registration ====================

module = OzFramework:registerMod({
    name = "oz_auto_roll",
    title = L["Auto Roll"],
    category = "Loot",
    order = 1,
    enabled = true,
    config = {
        ["loot.auto_roll_enable"] = true,
        ["loot.auto_confirm_bop"] = true,
        ["loot.announce_roll"]   = true,
        ["loot.zg_bijous_action"] = ACTION_NEED,
        ["loot.zg_coins_action"]  = ACTION_NEED,
        ["loot.cot_items_action"] = ACTION_NEED,
    },
    config_ui_creator = build_roll_config_ui,
    enable = function(self)
        if OZAIO_CONFIG and OZAIO_CONFIG["loot.auto_roll_enable"] == false then return end
        event_frame:RegisterEvent("START_LOOT_ROLL")
        event_frame:RegisterEvent("CONFIRM_LOOT_ROLL")
    end,
    disable = function(self)
        event_frame:UnregisterAllEvents()
        pending_confirm = {}
        handled_rolls = {}
    end,
})
