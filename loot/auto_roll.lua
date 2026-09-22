local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Auto Roll"] = "自动需求"
    L["Automatically roll on raid/dungeon reputation items."] = "自动对团队/地下城声望物品进行掷骰（需求/贪婪/放弃）。"
    L["Enable Auto Roll"] = "启用自动需求"
    L["Auto-Confirm BoP"] = "自动确认拾取绑定"
    L["Automatically confirm Bind on Pickup dialogs for auto-rolled items."] = "对自动掷骰的拾取绑定物品自动点击确定，避免弹窗打断战斗。"
    L["Announce in Chat"] = "聊天栏提示"
    L["Print chat message when automatically rolling on items."] = "在聊天窗口提示自动掷骰操作。"
    L["Zul Gurub Bijous"] = "祖尔格拉布宝石"
    L["Roll rule for Zul'Gurub Hakkari Bijous (all 9 colors)."] = "祖尔格拉布9种哈卡莱双子宝石的掷骰规则。"
    L["Zul Gurub Coins"] = "祖尔格拉布硬币"
    L["Roll rule for Zul'Gurub Coins (Zulian, Razzashi, Hakkari, etc.)."] = "祖尔格拉布9种声望硬币的掷骰规则。"
    L["CoT BM Corrupted Sand"] = "时光之穴腐蚀之沙"
    L["Roll rule for Caverns of Time Corrupted Sand."] = "时光之穴腐蚀之沙的掷骰规则。"
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

-- Fast item classification by numeric ID
local function ClassifyItem(itemID)
    if not itemID then return nil end
    if ZG_BIJOUS[itemID] then return "zg_bijous" end
    if ZG_COINS[itemID] then return "zg_coins" end
    if COT_ITEMS[itemID] then return "cot_items" end
    return nil
end

local CATEGORY_CONFIG_KEYS = {
    zg_bijous = "loot.zg_bijous_action",
    zg_coins  = "loot.zg_coins_action",
    cot_items = "loot.cot_items_action",
}

local ROLL_TYPES = {
    [ACTION_NEED]  = 1,
    [ACTION_GREED] = 2,
    [ACTION_PASS]  = 0,
}

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
    if not link then return end

    local _, _, idStr = string.find(link, "item:(%d+)")
    if not idStr then return end

    local category = ClassifyItem(tonumber(idStr))
    if not category then return end

    local action = OZAIO_CONFIG and OZAIO_CONFIG[CATEGORY_CONFIG_KEYS[category]] or ACTION_NEED
    local rollType = ROLL_TYPES[action]
    if rollType == nil then return end

    handled_rolls[rollID] = true
    pending_confirm[rollID] = rollType

    RollOnLoot(rollID, rollType)

    if OZAIO_CONFIG and OZAIO_CONFIG["loot.announce_roll"] ~= false then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OzAiO]|r " .. string.format(L["Auto-Rolled %s on %s"], ActionLabel(rollType), link))
    end
end

local function OnConfirmLootRoll(rollID, rollType)
    if not rollID then return end
    if OZAIO_CONFIG and OZAIO_CONFIG["loot.auto_roll_enable"] == false then return end
    if OZAIO_CONFIG and OZAIO_CONFIG["loot.auto_confirm_bop"] == false then return end

    if pending_confirm[rollID] then
        local confirmType = rollType or pending_confirm[rollID]
        ConfirmLootRoll(rollID, confirmType)
        pending_confirm[rollID] = nil

        -- Dismiss matching Blizzard confirmation static popup
        if StaticPopup_Hide then
            StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
        end
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
    elseif event == "CANCEL_LOOT_ROLL" then
        if arg1 then
            handled_rolls[arg1] = nil
            pending_confirm[arg1] = nil
        end
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
            label = L["Zul Gurub Bijous"],
            tooltip = L["Roll rule for Zul'Gurub Hakkari Bijous (all 9 colors)."],
            options = action_options,
            config_key = "loot.zg_bijous_action",
            default = ACTION_NEED,
        },
        {
            type = "dropdown",
            label = L["Zul Gurub Coins"],
            tooltip = L["Roll rule for Zul'Gurub Coins (Zulian, Razzashi, Hakkari, etc.)."],
            options = action_options,
            config_key = "loot.zg_coins_action",
            default = ACTION_NEED,
        },
        {
            type = "dropdown",
            label = L["CoT BM Corrupted Sand"],
            tooltip = L["Roll rule for Caverns of Time Corrupted Sand."],
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
        event_frame:RegisterEvent("CANCEL_LOOT_ROLL")
    end,
    disable = function(self)
        event_frame:UnregisterAllEvents()
        pending_confirm = {}
        handled_rolls = {}
    end,
})
