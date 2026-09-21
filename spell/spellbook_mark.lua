local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if LOCALE == "zhCN" then
    L["Spellbook Mark"] = "法术书标记"
    L["Tag Action Bar Spells in Spellbook"] = "法术书标记"
    L["Mark spells already on action bars when viewing spellbook"] = "在法术书中标记已放入动作条的技能"
end

-- ==================== Tooltip Scanner ====================

local scan_tooltip = nil
local scan_owner = nil

local function ensure_scan_tooltip()
    if not scan_tooltip then
        scan_owner = CreateFrame("Frame", "OzSpellMarkTooltipOwner", UIParent)
        scan_owner:Hide()
        scan_tooltip = CreateFrame("GameTooltip", "OzSpellMarkToolTip", scan_owner, "GameTooltipTemplate")
    end
end

local function get_action_spell_info(slot_id)
    if not HasAction(slot_id) then return nil end
    if GetActionText(slot_id) then return nil end -- macro text, not a direct spell

    ensure_scan_tooltip()
    scan_tooltip:SetOwner(scan_owner, "ANCHOR_NONE")
    scan_tooltip:SetAction(slot_id)

    local text_left = OzSpellMarkToolTipTextLeft1
    local name = text_left and text_left:GetText()
    scan_tooltip:Hide()

    if not name or name == "" then
        return nil
    end
    return name
end

-- ==================== Spellbook Cache ====================

local function build_spellbook_cache()
    local cache = {}
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        cache[name] = true
        i = i + 1
    end
    return cache
end

-- ==================== Action Bar Queries ====================

-- Returns a set of all spell names currently present on any action bar slot.
-- Only entries present in the spellbook are considered spells (ignoring items).
local function get_active_action_spells(spellbook_cache)
    local on_bar = {}
    local sb = spellbook_cache or build_spellbook_cache()
    for slot = 1, 120 do
        local name = get_action_spell_info(slot)
        if name and sb[name] then
            on_bar[name] = true
        end
    end
    return on_bar
end

-- ==================== Spellbook Tagging ====================

local function reset_spellbook_colors()
    for i = 1, 12 do
        local text = getglobal("SpellButton" .. i .. "SpellName")
        if text then
            text:SetTextColor(1.0, 0.82, 0.0) -- Default Blizzard yellow
        end
    end
end

local function get_spell_id_for_button(button_id)
    if SpellButton_GetSpellID then
        return SpellButton_GetSpellID(button_id)
    end
    local tab = SpellBookFrame and SpellBookFrame.selectedSkillLine or 1
    local page = (SpellBook_GetCurrentPage and SpellBook_GetCurrentPage())
              or (SpellBookFrame and SpellBookFrame.currentPage) or 1
    local offset = 0
    if tab and tab > 0 and GetSpellTabInfo then
        local _, _, tab_offset = GetSpellTabInfo(tab)
        offset = tab_offset or 0
    end
    return button_id + 12 * (page - 1) + offset
end

local function update_spellbook_tags()
    if not (SpellBookFrame and SpellBookFrame:IsVisible()) then return end
    if not (OZAIO_CONFIG and OZAIO_CONFIG["spell.tag_spellbook"]) then
        reset_spellbook_colors()
        return
    end

    local sb_cache = build_spellbook_cache()
    local on_bar = get_active_action_spells(sb_cache)

    for i = 1, 12 do
        local btn = getglobal("SpellButton" .. i)
        local text = getglobal("SpellButton" .. i .. "SpellName")
        if btn and text and btn:IsShown() then
            local spell_id = get_spell_id_for_button(i)
            local name = GetSpellName(spell_id, BOOKTYPE_SPELL)
            if name and on_bar[name] then
                text:SetTextColor(1.0, 0.2, 0.2) -- Red: already on action bar
            else
                text:SetTextColor(1.0, 0.82, 0.0) -- Default yellow
            end
        end
    end
end

-- ==================== Event Frame & Lifecycle ====================

local event_frame = CreateFrame("Frame", "OzSpellMarkEventFrame", UIParent)
event_frame:SetScript("OnEvent", function()
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED" then
        if SpellBookFrame and SpellBookFrame:IsVisible() and OZAIO_CONFIG and OZAIO_CONFIG["spell.tag_spellbook"] then
            update_spellbook_tags()
        end
    end
end)

local function enable_mark_module()
    event_frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    event_frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")

    OzHook:hook("SpellBookFrame_Update", nil, update_spellbook_tags)
    OzHook:hook(SpellBookFrame, "OnHide", nil, reset_spellbook_colors)

    if SpellBookFrame and SpellBookFrame:IsVisible() then
        update_spellbook_tags()
    end
end

local function disable_mark_module()
    event_frame:UnregisterAllEvents()

    OzHook:unhook("SpellBookFrame_Update", update_spellbook_tags)
    OzHook:unhook(SpellBookFrame, "OnHide", reset_spellbook_colors)
    reset_spellbook_colors()
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "Spellbook Mark",
    title = L["Tag Action Bar Spells in Spellbook"],
    category = "Actionbar",
    order = 2,
    enabled = true,
    config = {
        ["spell.tag_spellbook"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Tag Action Bar Spells in Spellbook"],
            tooltip = L["Mark spells already on action bars when viewing spellbook"],
            config_key = "spell.tag_spellbook",
            onChange = function(checked)
                if checked then
                    update_spellbook_tags()
                else
                    reset_spellbook_colors()
                end
            end,
        },
    },
    enable = function(self)
        enable_mark_module()
    end,
    disable = function(self)
        disable_mark_module()
    end,
})
