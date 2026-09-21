local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Update Spell Level"] = "自动更新技能等级"
    L["Auto Update Spell Rank"] = "自动更新技能等级"
    L["Auto-update action bar when learning higher spell rank"] = "学习更高等级技能时自动更新动作条"
    L["Update All Action Bar Spells Now"] = "立即更新所有动作条技能"
    L["Click to check all action bar buttons and update to highest known rank"] = "点击检查所有动作条按钮并更新为最高等级"
    L["Slot #%d updated: %s (%s)"] = "更新按钮#%d: %s (%s)"
    L["All spells are up-to-date"] = "所有技能已是最新等级"
    L["Update complete: %d spell(s) updated"] = "更新完成: %d个技能已更新"
end

-- ==================== Tooltip Scanner ====================

local scan_tooltip = nil
local scan_owner = nil

local function ensure_scan_tooltip()
    if not scan_tooltip then
        scan_owner = CreateFrame("Frame", "OzUpdateSpellTooltipOwner", UIParent)
        scan_owner:Hide()
        scan_tooltip = CreateFrame("GameTooltip", "OzUpdateSpellToolTip", scan_owner, "GameTooltipTemplate")
    end
end

local function rank_to_number(rank_str)
    if not rank_str or rank_str == "" then return 0 end
    local _, _, num = string.find(rank_str, "(%d+)")
    return tonumber(num) or 0
end

local function get_action_spell_info(slot_id)
    if not HasAction(slot_id) then return nil end
    if GetActionText(slot_id) then return nil end -- macro text, not a direct spell

    ensure_scan_tooltip()
    scan_tooltip:SetOwner(scan_owner, "ANCHOR_NONE")
    scan_tooltip:SetAction(slot_id)

    local text_left = OzUpdateSpellToolTipTextLeft1
    local name = text_left and text_left:GetText()
    if not name or name == "" then
        scan_tooltip:Hide()
        return nil
    end

    local rank_text = nil
    local text_right = OzUpdateSpellToolTipTextRight1
    if text_right and text_right:IsShown() then
        rank_text = text_right:GetText()
    end

    scan_tooltip:Hide()
    return name, rank_text
end

-- ==================== Spellbook Cache ====================

local function build_spellbook_cache()
    local cache = {}
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local rank_num = rank_to_number(rank)
        local existing = cache[name]
        if not existing or rank_num > existing.rank_num then
            cache[name] = {
                index    = i,
                name     = name,
                rank     = rank,
                rank_num = rank_num,
            }
        end
        i = i + 1
    end
    return cache
end

-- ==================== Action Bar Upgrade Sweep ====================

local function update_all_action_spells()
    local spellbook = build_spellbook_cache()
    local updated_count = 0

    for slot = 1, 120 do
        local name, rank_str = get_action_spell_info(slot)
        if name and spellbook[name] then
            local best = spellbook[name]
            if best.rank_num > 0 then
                local current_rn = rank_to_number(rank_str)
                if best.rank_num > current_rn then
                    PickupSpell(best.index, BOOKTYPE_SPELL)
                    PlaceAction(slot)
                    ClearCursor()
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cff20b2aa[OzAiO] " ..
                        string.format(L["Slot #%d updated: %s (%s)"], slot, name, best.rank or "??") ..
                        "|r"
                    )
                    updated_count = updated_count + 1
                end
            end
        end
    end

    if updated_count > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff20b2aa[OzAiO] " ..
            string.format(L["Update complete: %d spell(s) updated"], updated_count) ..
            "|r"
        )
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff20b2aa[OzAiO] " .. L["All spells are up-to-date"] .. "|r"
        )
    end
end

-- ==================== Learn Event Detection ====================

local function parse_learned_spell(msg)
    if not msg then return nil end

    -- enUS: "You have learned a new spell: Fireball (Rank 2)." or "You have learned a new spell: Blink."
    local _, _, raw_en = string.find(msg, "^You have learned a new spell: (.+)%.$")
    if raw_en then
        local clean = string.gsub(raw_en, "%s*%b()$", "")
        return clean
    end

    -- zhCN: "你学会了一个新的法术：火球术（等级 2）。" or "你学会了一个新的法术：闪现术。"
    local _, _, raw_cn = string.find(msg, "^你学会了一个新的法术：(.+)[。%.]?$")
    if raw_cn then
        local clean = string.gsub(raw_cn, "（.-）$", "")
        clean = string.gsub(clean, "%s*%b()$", "")
        return clean
    end

    return nil
end

local pending_learned_spells = {}
local learn_dispatch_frame = CreateFrame("Frame")
learn_dispatch_frame:Hide()
learn_dispatch_frame:SetScript("OnUpdate", function()
    this:Hide()
    if not (OZAIO_CONFIG and OZAIO_CONFIG["spell.auto_update_rank"]) then
        pending_learned_spells = {}
        return
    end

    local spellbook = build_spellbook_cache()
    local to_process = pending_learned_spells
    pending_learned_spells = {}

    for spell_name in pairs(to_process) do
        local best = spellbook[spell_name]
        if best and best.rank_num > 0 then
            for slot = 1, 120 do
                local name, rank_str = get_action_spell_info(slot)
                if name and name == spell_name then
                    local current_rn = rank_to_number(rank_str)
                    if best.rank_num > current_rn then
                        PickupSpell(best.index, BOOKTYPE_SPELL)
                        PlaceAction(slot)
                        ClearCursor()
                        DEFAULT_CHAT_FRAME:AddMessage(
                            "|cff20b2aa[OzAiO] " ..
                            string.format(L["Slot #%d updated: %s (%s)"], slot, spell_name, best.rank or "??") ..
                            "|r"
                        )
                    end
                end
            end
        end
    end
end)

-- ==================== Event Frame & Lifecycle ====================

local event_frame = CreateFrame("Frame", "OzUpdateSpellEventFrame", UIParent)
event_frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SYSTEM" then
        local spell_name = parse_learned_spell(arg1)
        if spell_name then
            pending_learned_spells[spell_name] = true
            learn_dispatch_frame:Show()
        end
    end
end)

local function enable_update_module()
    event_frame:RegisterEvent("CHAT_MSG_SYSTEM")
end

local function disable_update_module()
    event_frame:UnregisterAllEvents()
    learn_dispatch_frame:Hide()
    pending_learned_spells = {}
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "Update Spell Level",
    title = L["Auto Update Spell Rank"],
    category = "Actionbar",
    order = 1,
    enabled = true,
    config = {
        ["spell.auto_update_rank"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Auto Update Spell Rank"],
            tooltip = L["Auto-update action bar when learning higher spell rank"],
            config_key = "spell.auto_update_rank",
        },
        {
            type = "space",
            height = 6,
        },
        {
            type = "button",
            label = L["Update All Action Bar Spells Now"],
            tooltip = L["Click to check all action bar buttons and update to highest known rank"],
            width = 220,
            height = 24,
            func = function()
                update_all_action_spells()
            end,
        },
    },
    enable = function(self)
        enable_update_module()
    end,
    disable = function(self)
        disable_update_module()
    end,
})
