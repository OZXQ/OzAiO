-- Feature 1: Auto-update action bar spells to highest rank when learning new spells
-- Feature 2: Button to check all action bar buttons and update to the highest known rank
-- Feature 3: Tag spells already on action bars when viewing the spellbook

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        if (LOCALE ~= "enUS") and (LOCALE ~= "enGB") then
            OzLib.print("Locale fetch failed for spell" .. v, "error")
        end
        return v
    end
})

if LOCALE == "zhCN" then
    L["Spell"] = "技能"
    L["Auto Update Spell Rank"] = "自动更新技能等级"
    L["Auto-update action bar when learning higher spell rank"] = "学习更高等级技能时自动更新动作条"
    L["Update All Action Bar Spells Now"] = "立即更新所有动作条技能"
    L["Click to check all action bar buttons and update to highest known rank"] = "点击检查所有动作条按钮并更新为最高等级"
    L["Tag Action Bar Spells in Spellbook"] = "法术书标记"
    L["Mark spells already on action bars when viewing spellbook"] = "在法术书中标记已放入动作条的技能"
    L["Slot #%d updated: %s (%s)"] = "更新按钮#%d: %s (%s)"
    L["All spells are up-to-date"] = "所有技能已是最新等级"
    L["Update complete: %d spell(s) updated"] = "更新完成: %d个技能已更新"
end

--  Module Registration 
local module = OzFramework:register("oz_spell", {
    title = L["Spell"],
    order = 2,
    enabled = true,
    config = {
        ["spell.auto_update_rank"] = true,
        ["spell.tag_spellbook"] = true,
    }
})

--  Config Helpers 
local function get_config(key)
    if OZAIO_CONFIG and OZAIO_CONFIG[key] ~= nil then
        return OZAIO_CONFIG[key]
    end
    return nil
end

local function set_config(key, value)
    OZAIO_CONFIG = OZAIO_CONFIG or {}
    OZAIO_CONFIG[key] = value
end

--  Module State 
local spell_state = {
    event_frame = nil,
    spell_tooltip = nil,
    action_spells = {},
    pending_learned = {},
}

--  Helper: Action Slot Spell Info 
-- Uses a hidden GameTooltip to query what spell (if any) is on a given
-- action bar slot, returning the spell name and its rank text.
--
-- IMPORTANT (matches reference SpellBookTag.lua): the tooltip must be
-- re-owned BEFORE every SetAction. In Vanilla 1.12, calling SetAction on a
-- tooltip without a fresh SetOwner leaves the text lines empty, so the
-- cache stays empty and no spell gets marked. SetOwner is called per query
-- exactly like the working reference addon.
local function ensure_spell_tooltip()
    if spell_state.spell_tooltip then return end
    -- Dedicated hidden owner: the scanner tooltip never participates in the
    -- visible UI hierarchy and is never owned by UIParent.
    if not spell_state.tooltip_owner then
        spell_state.tooltip_owner = CreateFrame("Frame", "OzSpellTooltipOwner", UIParent)
        spell_state.tooltip_owner:Hide()
    end
    spell_state.spell_tooltip = CreateFrame(
        "GameTooltip", "OzSpellToolTip", spell_state.tooltip_owner, "GameTooltipTemplate"
    )
end

local function get_action_spell_info(slot_id)
    if not HasAction(slot_id) then return end
    if GetActionText(slot_id) then return end -- macro text, not a direct spell

    ensure_spell_tooltip()

    local tt = spell_state.spell_tooltip
    tt:SetOwner(spell_state.tooltip_owner, "ANCHOR_NONE")
    tt:SetAction(slot_id)

    local name = OzSpellToolTipTextLeft1
    if name then name = name:GetText() end

    local rank_text = nil
    if OzSpellToolTipTextRight1 and OzSpellToolTipTextRight1:IsShown() then
        rank_text = OzSpellToolTipTextRight1:GetText()
    end

    tt:Hide()

    if name and name ~= "" then
        return name, rank_text
    end
end

--  Helper: Rank Parsing 
local function rank_to_number(rank_str)
    if not rank_str then return 0 end
    local start_pos, end_pos = string.find(rank_str, "%d+")
    if start_pos then
        return tonumber(string.sub(rank_str, start_pos, end_pos))
    end
    return 0
end

--  Spellbook Index Lookups 

-- Find the highest learned rank of a spell by name
local function find_highest_rank_index(spell_name)
    local best_index = nil
    local best_rank_num = -1
    local i = 1
    local n, r
    repeat
        n, r = GetSpellName(i, BOOKTYPE_SPELL)
        if n and n == spell_name then
            local rn = rank_to_number(r)
            if rn > best_rank_num then
                best_rank_num = rn
                best_index = i
            end
        end
        i = i + 1
    until not n
    return best_index
end

--  Helper: Clear Cursor 
-- PickupSpell/PlaceAction are real cursor operations; only clear when the
-- cursor still holds a spell after placing (PlaceAction usually consumes
-- it). Never clobber a cursor state we did not create.
local function clear_cursor()
    if CursorHasSpell and CursorHasSpell() then
        ClearCursor()
    end
end

--  Feature 1: Auto-Update on Learn 

-- Parse "learned spell" system messages for the spell name only. The rank
-- in the message is deliberately ignored: the chat line can arrive before
-- the client has added the new rank to the spellbook, so the deferred
-- handler re-reads the highest known rank from the spellbook instead.
local function parse_learned_spell(msg)
    if not msg then return nil end
    
    -- enUS: "You have learned a new spell: Fireball (Rank 2)."
    local start1, end1, spell_name = string.find(
        msg, "^You have learned a new spell: (.+) %((.+)%)%.$"
    )
    if start1 then 
        return spell_name 
    end
    
    -- zhCN: uses full-width parentheses
    start2, end2, spell_name = string.find(
        msg, "^你学会了一个新的法术：(.+)（(.+)）[。%.]?$"
    )
    if start2 then 
        return spell_name 
    end
    
    return nil
end

-- Feature 1 scan state. Learning a spell still needs a look at every action
-- bar slot, but the pass advances ONE slot per OnUpdate tick (same reasoning
-- as the Feature 3 scan), so a learn event never triggers a 120-slot
-- GameTooltip:SetAction burst in a single frame.
local learn_scan = {
    active = false,
    slot   = 0,
    job    = nil,
}
-- Several learns in the same frame (e.g. a quest turn-in) are scanned one
-- after another.
local learn_queue = {}

-- Forward declarations: the singleton OnUpdate frame is created in the
-- Feature 3 section below, but the learn-scan path must reference it too,
-- so the locals are declared here (before the first use) instead of at
-- creation.
local spellbook_refresh_frame
local spellbook_refresh_pending

local function start_learn_scan(spell_name, best, best_rank, best_rank_num)
    local job = {
        spell_name    = spell_name,
        best          = best,
        best_rank     = best_rank,
        best_rank_num = best_rank_num,
    }
    if learn_scan.active then
        table.insert(learn_queue, job)
        return
    end
    learn_scan.job = job
    learn_scan.slot = 1
    learn_scan.active = true
    spellbook_refresh_frame:Show()
end

local function step_learn_scan()
    if not learn_scan.active then return end
    local job = learn_scan.job
    local slot = learn_scan.slot
    if slot > 120 then
        learn_scan.active = false
        local next_job = table.remove(learn_queue, 1)
        if next_job then
            learn_scan.job = next_job
            learn_scan.slot = 1
            learn_scan.active = true
        end
        return
    end
    learn_scan.slot = slot + 1
    local name, current_rank = get_action_spell_info(slot)
    if name and name == job.spell_name then
        local current_rn = rank_to_number(current_rank)
        if job.best_rank_num > current_rn then
            PickupSpell(job.best, BOOKTYPE_SPELL)
            PlaceAction(slot)
            clear_cursor()
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff20b2aa[OzAiO] " ..
                string.format(L["Slot #%d updated: %s (%s)"], slot, job.spell_name, job.best_rank or "??") ..
                "|r"
            )
        end
    end
end

-- Runs one frame after a "learned spell" system message, once the client
-- has definitely updated the spellbook. Uses the highest learned rank
-- (rather than the rank parsed from the chat line, which may not exist in
-- the spellbook yet) and queues the frame-spread upgrade scan.
local function on_learned_spell(spell_name)
    if not get_config("spell.auto_update_rank") then return end

    local best = find_highest_rank_index(spell_name)
    if not best then return end
    local _, best_rank = GetSpellName(best, BOOKTYPE_SPELL)
    start_learn_scan(spell_name, best, best_rank, rank_to_number(best_rank))
end

-- Drain queued learn events collected from CHAT_MSG_SYSTEM. The queue is
-- cleared before processing so a script error in one spell cannot wedge it
-- into retrying every frame.
local function process_pending_learned_spells()
    local names = {}
    for name in pairs(spell_state.pending_learned) do
        table.insert(names, name)
    end
    spell_state.pending_learned = {}
    for _, name in ipairs(names) do
        on_learned_spell(name)
    end
end

--  Feature 2: Update All Spells 

-- Iterates every action bar slot and replaces the spell with the highest
-- known rank. Callable manually from a config-panel button.
local function update_all_action_spells()
    local updated_count = 0

    for slot = 1, 120 do
        local name, current_rank = get_action_spell_info(slot)
        if name then
            local best = find_highest_rank_index(name)
            if best then
                local n, r = GetSpellName(best, BOOKTYPE_SPELL)
                local best_rn = rank_to_number(r)
                local current_rn = rank_to_number(current_rank)
                if best_rn > current_rn then
                    PickupSpell(best, BOOKTYPE_SPELL)
                    PlaceAction(slot)
                    clear_cursor()
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cff20b2aa[OzAiO] " ..
                        string.format(L["Slot #%d updated: %s (%s)"], slot, n, r or "??") ..
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

--  Feature 3: Spellbook Tagging 

-- Map a visual spellbook slot (1-12, read left-to-right, top-to-bottom)
-- to Blizzard's underlying button ID. In Vanilla 1.12 the spellbook uses a
-- two-column layout: positions 1-6 are the LEFT column (odd SpellButtons),
-- positions 7-12 are the RIGHT column (even SpellButtons).
local function spellbook_button_id(spellpos)
    if spellpos > 6 then
        return (spellpos - 6) * 2
    else
        return (spellpos * 2) - 1
    end
end

-- Color-codes spell names on the current spellbook page:
--   red    → spell is already on an action bar
--   yellow → default color
--
-- The action-bar cache is built only when the book opens (one slot per
-- frame, see start_action_scan); display itself is a pure lookup with zero
-- tooltip calls. No game event ever refreshes the cache, so normal play
-- never triggers GameTooltip/SetAction work.
local function show_spellbook_tags()
    if not SpellBookFrame then return end
    if not get_config("spell.tag_spellbook") then return end

    local spelltab = SpellBookFrame.selectedSkillLine
    if not spelltab then return end

    local page = SpellBook_GetCurrentPage()
    local _, _, offset, numSpells = GetSpellTabInfo(spelltab)
    if not offset or not numSpells then return end

    local startspell = offset + 12 * (page - 1)
    local endspell = startspell + 12
    endspell = math.min(endspell, offset + numSpells)

    local spellpos = 1
    for spell_id = startspell + 1, endspell do
        local st_name = GetSpellName(spell_id, BOOKTYPE_SPELL)
        if st_name then
            local found = spell_state.action_spells[st_name]

            local buttonName = "SpellButton" .. spellbook_button_id(spellpos) .. "SpellName"
            local textFrame = getglobal(buttonName)
            if textFrame then
                if found then
                    textFrame:SetTextColor(1, 0, 0)        -- red: on action bar
                else
                    textFrame:SetTextColor(1.0, 0.82, 0)   -- default yellow
                end
            end
            spellpos = spellpos + 1
        end
    end

    -- Reset unused button slots to default color
    for n = spellpos, 12 do
        local buttonName = "SpellButton" .. spellbook_button_id(n) .. "SpellName"
        local textFrame = getglobal(buttonName)
        if textFrame then
            textFrame:SetTextColor(1.0, 0.82, 0)
        end
    end
end

-- Restore all spellbook button name colors to the default yellow
local function reset_spellbook_colors()
    for i = 1, 12 do
        local buttonName = "SpellButton" .. spellbook_button_id(i) .. "SpellName"
        local textFrame = getglobal(buttonName)
        if textFrame then
            textFrame:SetTextColor(1.0, 0.82, 0)
        end
    end
end

-- Feature 3 scan state. The action-bar cache is rebuilt ONLY when the
-- spellbook opens (see on_spellbook_show); no game event can start it. The
-- scan advances one slot per OnUpdate tick, so the 120-slot
-- GameTooltip:SetAction pass is spread over many frames instead of one
-- synchronous burst.
local scan_active = false
local scan_slot = 0

local function start_action_scan()
    spell_state.action_spells = {}
    scan_slot = 1
    scan_active = true
    spellbook_refresh_frame:Show()
end

local function step_action_scan()
    if not scan_active then return end
    if not SpellBookFrame or not SpellBookFrame:IsVisible() then
        scan_active = false
        return
    end
    if scan_slot <= 120 then
        -- Keyed by spell name only: Feature 3 marks "spells already on an
        -- action bar", so Fireball (Rank 3) on a bar must also mark the
        -- Fireball (Rank 1) row in the book.
        local name = get_action_spell_info(scan_slot)
        if name then
            spell_state.action_spells[name] = true
        end
        scan_slot = scan_slot + 1
    else
        scan_active = false
        show_spellbook_tags()
    end
end

--  SpellBookFrame Show/Hide Callbacks 
local function on_spellbook_show()
    if get_config("spell.tag_spellbook") then
        -- The only trigger for the action-bar scan: opening the book.
        start_action_scan()
    end
end

-- Singleton OnUpdate frame for deferred spellbook re-coloring.
-- Blizzard updates spell buttons AFTER click handlers, so a one-tick
-- delay is needed after tab/page switches before reading button state.
-- The frame is hidden by default and only shown when there is work to do,
-- avoiding a per-frame OnUpdate that runs unconditionally forever.
spellbook_refresh_frame = CreateFrame("Frame")
spellbook_refresh_pending = false
spellbook_refresh_frame:Hide()
spellbook_refresh_frame:SetScript("OnUpdate", function()
    -- Advance the book-gated action-bar scan: one slot per frame, and a
    -- no-op while no scan is active, so normal play never touches the
    -- GameTooltip or the cursor.
    step_action_scan()

    -- Advance the learned-spell upgrade scan: one slot per frame too, so a
    -- learn event never produces a 120-slot SetAction burst.
    step_learn_scan()

    -- Learned spells are processed one frame after the chat message so the
    -- spellbook has definitely picked up the new rank.
    if next(spell_state.pending_learned) then
        process_pending_learned_spells()
    end

    if spellbook_refresh_pending then
        spellbook_refresh_pending = false
        if SpellBookFrame and SpellBookFrame:IsVisible() then
            show_spellbook_tags()
        end
    end

    -- Hide self when no work remains (no active scans, no pending tasks)
    if not scan_active
        and not learn_scan.active
        and not next(spell_state.pending_learned)
        and not spellbook_refresh_pending
    then
        this:Hide()
    end
end)

local function request_spellbook_refresh()
    spellbook_refresh_pending = true
    spellbook_refresh_frame:Show()
end

--  Event Handling 
-- Feature 1 listens for learn messages. The tagging scan is NOT event-driven
-- during play — SPELLS_CHANGED / SPELLBOOK_UPDATE / PLAYER_ENTERING_WORLD
-- never schedule tooltip work. ACTIONBAR_SLOT_CHANGED is handled only as a
-- book-visible correctness refresh (see below).
local function on_event()
    if event == "CHAT_MSG_SYSTEM" then
        local spell_name = parse_learned_spell(arg1)
        if spell_name then
            -- Deferred: the system message can arrive before the client has
            -- added the new rank to the spellbook, so only queue the name;
            -- the OnUpdate dispatcher looks up the highest rank next frame.
            spell_state.pending_learned[spell_name] = true
            spellbook_refresh_frame:Show()
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- Correctness only: keep the tags current when bars change while the
        -- book is open. Gated by visibility, so this is inert during normal
        -- play (book closed) and can never cause the map/bag cursor flash.
        if get_config("spell.tag_spellbook")
            and SpellBookFrame and SpellBookFrame:IsVisible()
        then
            start_action_scan()
        end
    end
end

--  Module Lifecycle 
module.enable = function(self)
    if not spell_state.event_frame then
        spell_state.event_frame = CreateFrame("Frame", "OzSpellEventFrame", UIParent)
        spell_state.event_frame:SetScript("OnEvent", on_event)
    end

    -- Feature 1 needs the learned-spell chat message. The tagging scan is
    -- NOT event-driven during play: it runs from the SpellBookFrame OnShow
    -- hook (plus a book-visible-only ACTIONBAR_SLOT_CHANGED refresh), so
    -- map/bag events never touch the GameTooltip and the first book open
    -- rebuilds the cache with no login-time work.
    spell_state.event_frame:RegisterEvent("CHAT_MSG_SYSTEM")
    -- Book-visible-only cache refresh while tagging (see on_event).
    spell_state.event_frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

    -- Spellbook tagging hooks (Feature 3)
    if get_config("spell.tag_spellbook") then
        OzHook:hook(SpellBookFrame, "OnShow", nil, on_spellbook_show)
        OzHook:hook(SpellBookFrame, "OnHide", nil, reset_spellbook_colors)
        -- Page navigation buttons (frame scripts, not global functions)
        OzHook:hook(SpellBookPrevPageButton, "OnClick", nil, request_spellbook_refresh)
        OzHook:hook(SpellBookNextPageButton, "OnClick", nil, request_spellbook_refresh)
        -- Skill-line tab buttons (SpellBookSkillLineTab1..N)
        for i = 1, 32 do
            local tab = getglobal("SpellBookSkillLineTab" .. i)
            if not tab then break end
            OzHook:hook(tab, "OnClick", nil, request_spellbook_refresh)
        end
    end
end

module.disable = function(self)
    scan_active = false
    learn_scan.active = false
    learn_queue = {}
    if spell_state.event_frame then
        spell_state.event_frame:UnregisterAllEvents()
    end
    OzHook:unhook(SpellBookFrame, "OnShow", on_spellbook_show)
    OzHook:unhook(SpellBookFrame, "OnHide", reset_spellbook_colors)
    OzHook:unhook(SpellBookPrevPageButton, "OnClick", request_spellbook_refresh)
    OzHook:unhook(SpellBookNextPageButton, "OnClick", request_spellbook_refresh)
    for i = 1, 32 do
        local tab = getglobal("SpellBookSkillLineTab" .. i)
        if not tab then break end
        OzHook:unhook(tab, "OnClick", request_spellbook_refresh)
    end
    reset_spellbook_colors()
end

--  Config Panel 
module.create_config_panel = function(self, parent)
    local panel = CreateFrame("Frame", "OzSpellConfig", parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local flow = OzUIHelper:createFlow(panel, 10)

    -- Title
    local title = OzUIHelper:makeLabel(panel, L["Spell"], "GameFontNormalLarge")
    title:SetWidth(flow.maxWidth - flow.padding)
    title:SetJustifyH("CENTER")
    OzUIHelper:add(flow, title, flow.maxWidth - flow.padding, 20)
    OzUIHelper:newLine(flow)

    -- Feature 1: Auto Update Rank checkbox
    local autoCb = OzUIHelper:makeCheckbox(
        panel,
        L["Auto Update Spell Rank"],
        get_config("spell.auto_update_rank"),
        function(checked)
            set_config("spell.auto_update_rank", checked)
        end
    )
    OzUIHelper:add(flow, autoCb)
    OzUIHelper:newLine(flow)

    local autoDesc = OzUIHelper:makeLabel(
        panel,
        L["Auto-update action bar when learning higher spell rank"],
        "GameFontNormalSmall"
    )
    autoDesc:SetTextColor(0.5, 0.5, 0.5)
    OzUIHelper:add(flow, autoDesc)
    OzUIHelper:newLine(flow)

    -- Feature 2: Update All button
    local updateBtn = OzUIHelper:makeButton(
        panel,
        L["Update All Action Bar Spells Now"],
        function() update_all_action_spells() end,
        220, 26
    )
    OzUIHelper:add(flow, updateBtn)
    OzUIHelper:newLine(flow)

    local updateDesc = OzUIHelper:makeLabel(
        panel,
        L["Click to check all action bar buttons and update to highest known rank"],
        "GameFontNormalSmall"
    )
    updateDesc:SetTextColor(0.5, 0.5, 0.5)
    OzUIHelper:add(flow, updateDesc)
    OzUIHelper:newLine(flow)

    -- Separator
    OzUIHelper:add(flow, OzUIHelper:makeSeparator(panel, 300))
    OzUIHelper:newLine(flow)

    -- Feature 3: Spellbook Tag checkbox
    local tagCb = OzUIHelper:makeCheckbox(
        panel,
        L["Tag Action Bar Spells in Spellbook"],
        get_config("spell.tag_spellbook"),
        function(checked)
            set_config("spell.tag_spellbook", checked)
            if checked then
                -- No event registration needed: the scan starts on the next
                -- SpellBookFrame OnShow (see module.enable / on_spellbook_show).
                OzHook:hook(SpellBookFrame, "OnShow", nil, on_spellbook_show)
                OzHook:hook(SpellBookFrame, "OnHide", nil, reset_spellbook_colors)
            else
                OzHook:unhook(SpellBookFrame, "OnShow", on_spellbook_show)
                OzHook:unhook(SpellBookFrame, "OnHide", reset_spellbook_colors)
                reset_spellbook_colors()
            end
        end
    )
    OzUIHelper:add(flow, tagCb)
    OzUIHelper:newLine(flow)

    local tagDesc = OzUIHelper:makeLabel(
        panel,
        L["Mark spells already on action bars when viewing spellbook"],
        "GameFontNormalSmall"
    )
    tagDesc:SetTextColor(0.5, 0.5, 0.5)
    OzUIHelper:add(flow, tagDesc)
    OzUIHelper:newLine(flow)

    -- Set content height for scrolling
    local panelHeight = math.abs(flow.y) + flow.padding
    panel:SetHeight(panelHeight)

    return { frame = panel, height = panelHeight }
end
