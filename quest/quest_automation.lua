-- Quest Automation Module (QST-02 through QST-08)
-- Streamlines quest acquisition, dialogue progression, and quest turn-ins
-- Features: Native 1.12 C-APIs, multi-reward safety net, gossip skip & blacklist,
-- non-disruptive quest log caching, 1-tick debounce, and Alt-key bypass.

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Quest Automation"] = "任务自动化"
    L["Auto Accept Quests"] = "自动接受可用任务"
    L["Auto-accept available quests when talking to NPCs"] = "与NPC对话时自动接受可领取的任务"
    L["Auto Complete Quests"] = "自动交付已完成任务"
    L["Auto-complete finished quests and claim rewards (safely pauses on multiple gear rewards)"] =
    "自动提交已完成的任务并领取奖励（当存在多个可选装备奖励时会自动暂停由玩家手动挑选）"
    L["Auto Skip Single Gossip"] = "自动跳过单一对话选项"
    L["Automatically select the only option when speaking to NPCs like Flight Masters or Bankers"] =
    "与NPC对话仅有唯一步骤时自动选择（例如飞行点开启地图、银行家打开仓库等）"
    L["Multi-reward choice detected for '%s'. Please select your reward manually."] = "任务 [%s] 包含多项可选奖励，已暂停自动交付，请手动选择奖励。"
    L["Hold Alt to temporarily bypass all quest automation."] = "按住Alt键可临时禁用所有任务自动化操作。"
    L["Custom Turn-in & Safety Net"] = "自定义交付与安全机制"
    L["Zero-choice or single-choice quest rewards are claimed automatically. Multi-choice rewards require manual selection unless registered in custom turnin rules."] =
    "零奖励或唯一奖励任务会自动交付。多选一装备奖励会暂停由玩家自选，确保不选错装备。"
end

local whitelist_npc = { "黛西", "Daisy" }

-- ==================== State & Cache ====================

local completed_quests_cache = {}

local function update_quest_log_cache()
    completed_quests_cache = {}
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if not isHeader and title and title ~= "" then
            if isComplete and isComplete > 0 then
                completed_quests_cache[title] = true
            end
        end
    end
end

local function is_alt_down()
    return IsAltKeyDown and IsAltKeyDown()
end

-- ==================== Debounce Dispatcher ====================

local dispatch_frame = CreateFrame("Frame", "OzQuestAutomationDispatch", UIParent)
local pending_action = nil

local function schedule_action(action_func)
    pending_action = action_func
    dispatch_frame:Show()
end

dispatch_frame:Hide()
dispatch_frame:SetScript("OnUpdate", function()
    this:Hide()
    if pending_action then
        local action = pending_action
        pending_action = nil
        action()
    end
end)

-- ==================== Handler Functions ====================

local function handle_quest_detail()
    if is_alt_down() then return end
    if not (OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_accept"]) then return end
    AcceptQuest()
end

local function handle_quest_progress()
    if is_alt_down() then return end
    if not (OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_complete"]) then return end
    if IsQuestCompletable() then
        CompleteQuest()
    end
end

local function handle_quest_complete()
    if is_alt_down() then return end
    if not (OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_complete"]) then return end

    local title = GetTitleText() or ""
    local custom_rules = OZAIO_CONFIG and OZAIO_CONFIG["quest.custom_turnin_rules"]
    local custom_choice = custom_rules and custom_rules[title]
    if type(custom_choice) == "table" then
        custom_choice = custom_choice.reward_index or custom_choice.choice
    end

    local numChoices = GetNumQuestChoices()

    -- QST-07: Custom & Repeatable Turn-in Rules
    if custom_choice and tonumber(custom_choice) then
        GetQuestReward(tonumber(custom_choice))
        return
    end

    -- QST-04: Multi-Reward Safety Net
    if numChoices <= 1 then
        -- In 1.12: GetQuestReward(1) when 1 choice; GetQuestReward(0) when 0 choices
        GetQuestReward(numChoices == 1 and 1 or 0)
    else
        -- Halt auto-completion to let player manually pick from multi-choice gear
        if title ~= "" and OzLib and OzLib.print then
            OzLib.print(
                string.format(L["Multi-reward choice detected for '%s'. Please select your reward manually."], title),
                "info")
        end
    end
end

local function handle_quest_greeting()
    if is_alt_down() then return end

    -- 1. Try to turn in completed active quests first
    if OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_complete"] then
        local numActive = GetNumActiveQuests()
        for i = 1, numActive do
            local title = GetActiveTitle(i)
            if title and completed_quests_cache[title] then
                SelectActiveQuest(i)
                return
            end
        end
    end

    -- 2. If no completed active quests, select available quest
    if OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_accept"] then
        local numAvailable = GetNumAvailableQuests()
        if numAvailable > 0 then
            SelectAvailableQuest(1)
            return
        end
    end
end

local function handle_gossip_show()
    if is_alt_down() then return end

    -- 1. Check for complete active quests (Vanilla 1.12 returns pairs: title, level/icon)
    local activeQuests = { GetGossipActiveQuests() }
    local numActive = math.floor(table.getn(activeQuests) / 2)
    if numActive > 0 and OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_complete"] then
        for i = 1, numActive do
            local title = activeQuests[(i - 1) * 2 + 1]
            if title and completed_quests_cache[title] then
                SelectGossipActiveQuest(i)
                return
            end
        end
    end

    -- Special Exception: NPC Daisy (Mirage Raceway) - immediately select option 1 to join race without waiting
    local npc_name = UnitName("npc") or UnitName("target") or ""
    local is_whitelisted = false
    for _, npc in ipairs(whitelist_npc) do
        if string.find(npc_name, npc, 1, true) then
            is_whitelisted = true
            break
        end
    end

    local gossipOptions = { GetGossipOptions() }
    local numOptions = math.floor(table.getn(gossipOptions) / 2)
    if is_whitelisted and numOptions > 0 then
        SelectGossipOption(1)
        return
    end

    -- 2. Check for available quests
    local availableQuests = { GetGossipAvailableQuests() }
    local numAvailable = math.floor(table.getn(availableQuests) / 2)
    if numAvailable > 0 and OZAIO_CONFIG and OZAIO_CONFIG["quest.auto_accept"] then
        SelectGossipAvailableQuest(1)
        return
    end

    -- 3. QST-05 & QST-06: Single-Option Gossip Auto-Skip & Blacklist
    if OZAIO_CONFIG and OZAIO_CONFIG["quest.skip_gossip"] then
        if numActive == 0 and numAvailable == 0 and numOptions == 1 then
            local blacklist = OZAIO_CONFIG["quest.skip_gossip_blacklist"] or {}
            local is_blacklisted = false
            if npc_name ~= "" then
                for bl_key, enabled in pairs(blacklist) do
                    if enabled and string.find(npc_name, bl_key, 1, true) then
                        is_blacklisted = true
                        break
                    end
                end
            end
            if not is_blacklisted then
                SelectGossipOption(1)
                return
            end
        end
    end
end

-- ==================== Event Frame ====================

local event_frame = CreateFrame("Frame", "OzQuestAutomationEvents", UIParent)
event_frame:SetScript("OnEvent", function()
    if event == "QUEST_LOG_UPDATE" then
        update_quest_log_cache()
    elseif event == "QUEST_DETAIL" then
        schedule_action(handle_quest_detail)
    elseif event == "QUEST_PROGRESS" then
        schedule_action(handle_quest_progress)
    elseif event == "QUEST_COMPLETE" then
        schedule_action(handle_quest_complete)
    elseif event == "QUEST_GREETING" then
        schedule_action(handle_quest_greeting)
    elseif event == "GOSSIP_SHOW" then
        schedule_action(handle_gossip_show)
    elseif event == "PLAYER_LOGIN" then
        update_quest_log_cache()
    end
end)

local function enable_module()
    update_quest_log_cache()
    event_frame:RegisterEvent("QUEST_LOG_UPDATE")
    event_frame:RegisterEvent("QUEST_DETAIL")
    event_frame:RegisterEvent("QUEST_PROGRESS")
    event_frame:RegisterEvent("QUEST_COMPLETE")
    event_frame:RegisterEvent("QUEST_GREETING")
    event_frame:RegisterEvent("GOSSIP_SHOW")
    event_frame:RegisterEvent("PLAYER_LOGIN")
end

local function disable_module()
    event_frame:UnregisterAllEvents()
    dispatch_frame:Hide()
    pending_action = nil
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "oz_quest_automation",
    title = L["Quest Automation"],
    category = "Quest",
    order = 1,
    enabled = true,
    config = {
        ["quest.auto_accept"] = true,
        ["quest.auto_complete"] = true,
        ["quest.skip_gossip"] = false,
        ["quest.skip_gossip_blacklist"] = {
            ["Battlemaster"] = true,
            ["Innkeeper"] = true,
            ["Spirit Healer"] = true,
        },
        ["quest.custom_turnin_rules"] = {},
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Auto Accept Quests"],
            tooltip = L["Auto-accept available quests when talking to NPCs"],
            config_key = "quest.auto_accept",
        },
        {
            type = "checkbox",
            label = L["Auto Complete Quests"],
            tooltip = L["Auto-complete finished quests and claim rewards (safely pauses on multiple gear rewards)"],
            config_key = "quest.auto_complete",
        },
        {
            type = "checkbox",
            label = L["Auto Skip Single Gossip"],
            tooltip = L["Automatically select the only option when speaking to NPCs like Flight Masters or Bankers"],
            config_key = "quest.skip_gossip",
        },
        {
            type = "label",
            text = "|cff888888" .. L["Hold Alt to temporarily bypass all quest automation."] .. "|r",
        },
        {
            type = "label",
            text = "|cff888888" ..
                L
                ["Zero-choice or single-choice quest rewards are claimed automatically. Multi-choice rewards require manual selection unless registered in custom turnin rules."] ..
                "|r",
        },
    },
    enable = function(self)
        enable_module()
    end,
    disable = function(self)
        disable_module()
    end,
})
