-- World buff detection module for OzAiO
-- Detects dragon boss kills via NPC yell, relays to LFT channel, shows countdown and hearthstone button
-- Ported from Automaton/WorldBuffs.lua logic

local locale = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        if OZAIO_DEBUG and (locale ~= "enUS") and (locale ~= "enGB") then
            OzLib.print("Locale fetch failed for worldbuff: " .. v, "error")
        end
        return v
    end
})

-- Localization
if locale == "zhCN" then
    L["World Buff"] = "龙头增益"
    L["Enable"] = "启用"
    L["Countdown bar"] = "倒计时提醒"
    L["Sound alert"] = "播放提示音"
    L["Hearthstone button"] = "显示炉石按钮"
    L["Guild notify"] = "公会通告"
    L["Auto logout"] = "自动登出"
    L["Auto logout after buff"] = "获得世界BUFF后自动登出"
    L["Notice! "] = "注意！"
    L[" Buff in "] = " Buff倒计时，还有"
    L[" secs"] = "秒"
    L["World buff incoming, logout in 60s"] = "即将获得世界BUFF，60秒后自动登出..."
    L["Invalid dragon type, use Onyxia or Nefarian"] = "无效的龙头类型，请使用 Onyxia 或 Nefarian"
    L["Test world buff: "] = "测试世界BUFF: "
    L["World Buff Timer"] = "龙头计时"
    L["Timer frame"] = "计时面板"
    L["None"] = "暂无"
    L["[A] "] = "【LM】"
    L["[H] "] = "【BL】"
    L["Onyxia "] = "黑龙"
    L["Nefarian "] = "奈法"
    L["m"] = "分"
    L["Send timer to"] = "发送计时到"
    L["Say"] = "说话"
    L["Yell"] = "大喊"
    L["Guild"] = "公会"
    L["Party"] = "小队"
    L["Raid"] = "团队"
    L["Hardcore"] = "硬核"
-- else
--     L["World Buff"] = "Dragon Buff Alert"
--     L["Enable"] = "Enable"
--     L["Countdown bar"] = "Countdown bar"
--     L["Sound alert"] = "Sound alert"
--     L["Hearthstone button"] = "Hearthstone button"
--     L["Guild notify"] = "Guild notify"
--     L["Auto logout"] = "Auto logout"
--     L["Auto logout after buff"] = "Auto logout after buff"
--     L["Notice! "] = "Notice! "
--     L[" Buff in "] = " buff in "
--     L[" secs"] = " secs"
--     L["Auto logout cancelled: in combat"] = "Auto logout cancelled: in combat"
--     L["World buff incoming, logout in 60s"] = "World buff incoming, logout in 60s"
--     L["Invalid dragon type, use Onyxia or Nefarian"] = "Invalid dragon type, use Onyxia or Nefarian"
--     L["Test world buff: "] = "Test world buff: "
end

-- Dragon NPC data by faction
local dragon_config = {}
if locale == "zhCN" then
    dragon_config = {
        Alliance = {
            Onyxia = { name = "玛丁雷少校", yell = "向我们的英雄们致敬", msg = "【联盟】黑龙" },
            Nefarian = { name = "艾法希比元帅", yell = "黑石之王已经被干掉了", msg = "【联盟】奈法" },
        },
        Horde = {
            Onyxia = { name = "伦萨克", yell = "奥妮克希亚已经被斩杀了", msg = "【部落】黑龙" },
            Nefarian = { name = "萨鲁法尔大王", yell = "奈法利安被杀掉了", msg = "【部落】奈法" },
        }
    }
else
    dragon_config = {
        Alliance = {
            Onyxia = { name = "Major Mattingly", yell = "history has been made", msg = "[A] Onyxia" },
            Nefarian = { name = "Field Marshal Afrasiabi", yell = "the Lord of Blackrock is slain", msg = "[A] Nefarian" },
        },
        Horde = {
            Onyxia = { name = "Overlord Runthak", yell = "Onyxia, has been slain", msg = "[H] Onyxia" },
            Nefarian = { name = "High Overlord Saurfang", yell = "NEFARIAN IS SLAIN", msg = "[H] Nefarian" },
        }
    }
end

local RELAY_PREFIX = "MPWB"
local LIGHTNING_DELAY = 18
local LFT_CHANNEL = "LFT"
local SOUND_PATH = "Interface\\AddOns\\OzAiO\\sound\\wb_alert.ogg"
local FONT_PATH = "Fonts\\FRIZQT__.TTF"

-- TWB channel sync (world buff timers), protocol compatible with WorldBuffsTracker
local TWB_CHANNEL = "TWB"
local TWB_BUFF_DURATION = 7200 -- onyxia/nefarian buff lasts 2 hours
local TWB_JOIN_CHECK_INTERVAL = 30
local TWB_SYNC_INTERVAL = 60

-- Server-time sync retry: start fast (5s) and back off, stopping after
-- SERVER_RETRY_LIMIT attempts. The initial ".server info" request can be
-- dropped or delayed, so a slow first retry left detection blind too long.
local SERVER_RETRY_INITIAL_INTERVAL = 5
local SERVER_RETRY_MAX_INTERVAL = 60
local SERVER_RETRY_LIMIT = 6

-- Ordered dragon type list (fix #10: avoid pairs() order)
local dragon_types_list = { "Onyxia", "Nefarian" }

-- ================== Config ==================
-- Cache config reads: per-second / event paths shouldn't hit the OZAIO_CONFIG
-- table every time. All writes go through set_config() (config panel toggles,
-- timer drag), which keeps the cache in sync; module.disable clears it so a
-- later re-enable re-reads the saved variables authoritatively.
local config_cache = {}

local function get_config(key)
    local v = config_cache[key]
    if v ~= nil then
        return v
    end
    v = OZAIO_CONFIG and OZAIO_CONFIG[key]
    config_cache[key] = v
    return v
end

local function set_config(key, value)
    OZAIO_CONFIG = OZAIO_CONFIG or {}
    OZAIO_CONFIG[key] = value
    config_cache[key] = value
end

-- ================== Utility ==================
local function get_faction()
    return UnitFactionGroup("player")
end

-- ================== UI: Countdown (fix #3, #4, #5, #12) ==================
local caution
local countdown_time = 0
local countdown_active = false
local countdown_prefix = ""
local is_fading_out = true
local caution_elapsed = 0

local caution_onupdate

local function create_caution_frame()
    if caution then return end
    caution = CreateFrame("Frame", "OzAiOWorldBuffCaution", UIParent)
    caution.string = caution:CreateFontString(nil, "OVERLAY")
    caution.string:SetPoint("CENTER", UIParent, "CENTER", 0, 260)
    caution.string:SetFont(FONT_PATH, 48, "OUTLINE")
    caution:Hide()

    caution_onupdate = function(elapsed)
        -- The ticker only calls this while the frame is visible
        if is_fading_out then
            caution_elapsed = caution_elapsed + elapsed
        else
            caution_elapsed = caution_elapsed - elapsed
        end
        if caution_elapsed >= 1 then
            caution_elapsed = 1
            is_fading_out = false
        elseif caution_elapsed <= 0 then
            is_fading_out = true
            caution_elapsed = 0
        end

        if countdown_active then
            countdown_time = countdown_time - elapsed
            if countdown_time <= 0 then
                countdown_active = false
                -- The consolidated ticker checks IsShown(), so just hide
                caution:Hide()
                if hearthstone_button then hearthstone_button:Hide() end
            else
                caution.string:SetText(
                    L["Notice! "] ..
                    (countdown_prefix or "") ..
                    L[" Buff in "] ..
                    math.floor(countdown_time) ..
                    L[" secs"]
                )
                if countdown_time < 10 and hearthstone_button and hearthstone_button:IsShown() then
                    hearthstone_button:Hide()
                end
            end
        end
        caution.string:SetTextColor(caution_elapsed, 1, 0, caution_elapsed)
    end
end

-- fix #3: reset fade state on show
local function show_caution()
    caution_elapsed = 0
    is_fading_out = true
    caution:Show()
end

-- ================== UI: Hearthstone Button (fix #5, #14) ==================
local hearthstone_button
local hearthstone_icon_texture
local hearthstone_hide_time = nil

-- fix #2, #4: use string.find; item ID 6948 is sufficient, no GetItemInfo fallback needed
-- Vanilla bag iteration is slow, so cache the stone's bag/slot and only
-- rescan when BAG_UPDATE fires.
local hearthstone_bag = nil
local hearthstone_slot = nil
local hearthstone_cached = false

local function invalidate_hearthstone()
    hearthstone_cached = false
end

local function find_hearthstone()
    if hearthstone_cached then
        return hearthstone_bag, hearthstone_slot
    end
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, id_str = string.find(itemLink, "item:(%d+)")
                local id = tonumber(id_str)
                if id and id == 6948 then
                    hearthstone_bag = bag
                    hearthstone_slot = slot
                    hearthstone_cached = true
                    return bag, slot
                end
            end
        end
    end
    hearthstone_cached = true -- cache "not found" too; BAG_UPDATE will rescan
    return nil
end

local function create_hearthstone_button()
    if hearthstone_button then return end
    hearthstone_button = CreateFrame("Button", "OzAiOWorldBuffHearthstone", UIParent)
    hearthstone_button:SetWidth(40)
    hearthstone_button:SetHeight(40)
    hearthstone_button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)

    hearthstone_icon_texture = hearthstone_button:CreateTexture(nil, "BACKGROUND")
    hearthstone_icon_texture:SetAllPoints()
    -- Set a fallback icon in case find_hearthstone fails
    hearthstone_icon_texture:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")

    hearthstone_button:SetScript("OnEnter", function() hearthstone_icon_texture:SetAlpha(0.8) end)
    hearthstone_button:SetScript("OnLeave", function() hearthstone_icon_texture:SetAlpha(1.0) end)
    hearthstone_button:SetScript("OnMouseDown", function() hearthstone_icon_texture:SetAlpha(0.6) end)
    hearthstone_button:SetScript("OnMouseUp", function() hearthstone_icon_texture:SetAlpha(0.8) end)

    hearthstone_button:SetScript("OnClick", function()
        local bag, slot = find_hearthstone()
        if bag then
            local texture = GetContainerItemInfo(bag, slot)
            if texture then
                UseContainerItem(bag, slot)
                hearthstone_button:Hide()
            else
                -- Stone moved without BAG_UPDATE: drop the stale cache
                invalidate_hearthstone()
                hearthstone_button:Hide()
            end
        end
    end)
    hearthstone_button:Hide()
end

local function update_hearthstone_icon()
    if not hearthstone_button or not hearthstone_icon_texture then return end
    local bag, slot = find_hearthstone()
    if bag then
        local texture = GetContainerItemInfo(bag, slot)
        if texture then
            hearthstone_icon_texture:SetTexture(texture)
        end
    end
end

local function show_hearthstone_button()
    if not get_config("worldbuff.hearthstone") then return end
    create_hearthstone_button()
    update_hearthstone_icon()
    hearthstone_button:Show()
    -- fix #1: use OnUpdate-based timer instead of C_Timer.After
    hearthstone_hide_time = GetTime() + 10
end

-- ================== Auto logout (fix #11: combat check) ==================
local logout_at = nil

local function check_logout(now)
    if not logout_at then return end
    if now < logout_at then return end
    -- In combat at the deadline: keep waiting (retry every second) instead of
    -- permanently cancelling the logout.
    if UnitAffectingCombat("player") then
        logout_at = now + 1
        return
    end
    logout_at = nil
    local currentZone = GetRealZoneText()
    if currentZone == "Orgrimmar" or currentZone == "Stormwind City" then
        Logout()
    end
    
end

-- Logout/hearthstone polling moved into the consolidated ticker below.

-- ================== Trigger (fix #6: use L[] strings) ==================
-- Anti-spam: ignore a duplicate trigger of the same dragon within 2 seconds.
-- Keyed by faction+dragon so a genuine Onyxia -> Nefarian sequence is not
-- suppressed (LFT relay and TWB Lightning can both deliver the same kill).
local timer_cooldown = {}

local function trigger_alert(dragon_faction, dragon_type, countdown_secs)
    local now = GetTime()
    local alert_key = (dragon_faction or "") .. "_" .. (dragon_type or "")
    if timer_cooldown[alert_key] and now - timer_cooldown[alert_key] < 2 then return end
    timer_cooldown[alert_key] = now

    local cfg = dragon_config[dragon_faction] and dragon_config[dragon_faction][dragon_type]
    if not cfg then return end
    local buff_msg = cfg.msg

    -- Countdown bar
    if get_config("worldbuff.countdown") then
        create_caution_frame()
        is_fading_out = true
        countdown_prefix = buff_msg
        countdown_time = countdown_secs or LIGHTNING_DELAY
        countdown_active = true
        caution.string:SetText(
            L["Notice! "] ..
            buff_msg ..
            L[" Buff in "] ..
            math.floor(countdown_time) ..
            L[" secs"]
        )
        -- fix #3: use show_caution() to reset fade state
        show_caution()
    end

    -- Sound
    if get_config("worldbuff.sound") then
        PlaySoundFile(SOUND_PATH)
    end

    -- Guild
    if get_config("worldbuff.guild") then
        SendChatMessage(
            L["Notice! "] .. buff_msg .. L[" Buff in "] .. LIGHTNING_DELAY .. L[" secs"],
            "GUILD"
        )
    end

    -- Hearthstone button
    if get_config("worldbuff.hearthstone") then
        show_hearthstone_button()
    end

    -- Auto logout
    if get_config("worldbuff.autoLogout") then
        logout_at = now + 60
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[WorldBuff] " .. L["World buff incoming, logout in 60s"] .. "|r")
    end
end

-- ================== TWB Channel Sync (Feature: world buff timer) ==================
-- Protocol compatible with WorldBuffsTracker on the "TWB" channel:
--   "SyncS:A<expireTS>OH<expireTS>N..."  -- periodic full-state sync
--   "Lightning:<releaseTS>@<Key>"        -- buff about to land (drop + ~18s)

local wb_timer_keys = { "Alliance_Onyxia", "Alliance_Nefarian", "Horde_Onyxia", "Horde_Nefarian" }
local wb_timers = {}
local wb_lightning = {}
local server_time_offset = nil
-- A local kill observed before the server clock was synced is remembered
-- here and replayed by the ticker once server_time_now() becomes available.
local pending_twb_kill = nil

for _, key in ipairs(wb_timer_keys) do
    wb_timers[key] = { active = false }
end

local FACTION_LETTERS = { A = "Alliance", H = "Horde" }
local DRAGON_LETTERS = { O = "Onyxia", N = "Nefarian" }
-- Format side of the same protocol: key parts -> single protocol letters
local FACTION_TO_LETTER = { Alliance = "A", Horde = "H" }
local DRAGON_TO_LETTER = { Onyxia = "O", Nefarian = "N" }

local function server_time_now()
    if server_time_offset then return time() + server_time_offset end
    return nil
end

-- Ask the server for its clock; the answer arrives as CHAT_MSG_SYSTEM "Server Time: ..."
local function request_server_time()
    if get_config("worldbuff.enabled") then
        SendChatMessage(".server info")
    end
end

local function on_system_message()
    if not get_config("worldbuff.enabled") then return end
    -- Locale-independent: ".server info" replies as "Server Time: Tue,
    -- 08.11.2026 14:23:45" (enUS) or "服务器时间: 星期二, ..." (zhCN), so
    -- match the date/time portion anywhere in the message.
    local _, _, dd, mm, yyyy, hh, mi, ss = string.find(
        arg1,
        "(%d+)[%.%/](%d+)[%.%/](%d+)%s*(%d+):(%d+):(%d+)"
    )
    if not dd then return end
    local st = time({
        year = tonumber(yyyy), month = tonumber(mm), day = tonumber(dd),
        hour = tonumber(hh), min = tonumber(mi), sec = tonumber(ss)
    })
    -- Sanity check: reject garbage matches (e.g. unrelated system messages)
    -- that would produce a nonsense time offset
    if st and math.abs(st - time()) < 2 * 86400 then
        server_time_offset = st - time()
    end
end

local function set_wb_timer(key, to_ts)
    local t = wb_timers[key]
    if not t or not to_ts then return end
    if to_ts < 1000000000 then return end -- plausible unix timestamp
    local st = server_time_now()
    if st then
        local remaining = to_ts - st
        if remaining <= 0 or remaining > TWB_BUFF_DURATION + 120 then return end
    end
    -- Keep the freshest data: a later expiry always wins over an earlier one
    if t.active and t.to and to_ts <= t.to then return end
    t.to = to_ts
    t.active = true
end

local function cleanup_wb_timers()
    local st = server_time_now()
    if not st then return end
    for _, key in ipairs(wb_timer_keys) do
        local t = wb_timers[key]
        if t.active and t.to and t.to - st <= 0 then
            t.active = false
            t.to = nil
        end
    end
    for key, release in pairs(wb_lightning) do
        if release - st <= 0 then
            wb_lightning[key] = nil
        end
    end
end

local function parse_twb_sync(msg)
    local pos = 1
    while true do
        -- One pass: captures faction letter, timestamp and dragon letter
        local s, e, f_letter, ts, d_letter = string.find(msg, "([AH])(%d+)([ON])", pos)
        if not s then break end
        if f_letter and DRAGON_LETTERS[d_letter] then
            set_wb_timer(FACTION_LETTERS[f_letter] .. "_" .. DRAGON_LETTERS[d_letter], tonumber(ts))
        end
        pos = e + 1
    end
end

local function parse_twb_lightning(msg)
    local _, _, ts, key = string.find(msg, "Lightning:(%d+)@(%a+_%a+)")
    if not ts or not wb_timers[key] then return end
    local release = tonumber(ts)
    wb_lightning[key] = release
    -- releaseTS is the buff landing time (WorldBuffsTracker sends
    -- Get_Roar_BuffTime() = server time + 18 at the yell). The 2-hour buff
    -- effectively starts at the yell, so expiry = release + 7200 - 18 =
    -- yell + 7200, matching WorldBuffsTracker's receipt-time model exactly.
    set_wb_timer(key, release + TWB_BUFF_DURATION - LIGHTNING_DELAY)
    -- Countdown alert when the buff is about to land for our own faction
    local st = server_time_now()
    local faction = string.sub(key, 1, string.find(key, "_") - 1)
    local dragon = string.sub(key, string.find(key, "_") + 1)
    if st and faction == get_faction() then
        local remaining = release - st
        if remaining > 0 and remaining <= LIGHTNING_DELAY + 30 then
            trigger_alert(faction, dragon, remaining)
        end
    end
end

local function format_twb_entry(key)
    local t = wb_timers[key]
    if not t or not t.active or not t.to then return nil end
    -- Keys are "<Faction>_<Dragon>"; split on "_" and map to the protocol
    -- letters (Alliance -> A, Horde -> H, Onyxia -> O, Nefarian -> N).
    local us = string.find(key, "_")
    local faction = string.sub(key, 1, us - 1)
    local dragon = string.sub(key, us + 1)
    return FACTION_TO_LETTER[faction] .. t.to .. DRAGON_TO_LETTER[dragon]
end

local function format_twb_sync()
    local text = ""
    for _, key in ipairs(wb_timer_keys) do
        local entry = format_twb_entry(key)
        if entry then text = text .. entry end
    end
    if text == "" then return nil end
    return "SyncS:" .. text
end

local function send_twb_message(msg)
    local channel = GetChannelName(TWB_CHANNEL)
    if channel and channel > 0 then
        SendChatMessage(msg, "CHANNEL", nil, channel)
    end
end

local function join_twb_channel()
    if not get_config("worldbuff.enabled") then return end
    local chanList = { GetChannelList() }
    for k, v in next, chanList do
        if v == TWB_CHANNEL then return end
    end
    JoinChannelByName(TWB_CHANNEL)
end

local function on_twb_channel_join()
    if not get_config("worldbuff.enabled") then return end
    -- CHAT_MSG_CHANNEL_JOIN fires for anyone joining the channel, not just
    -- ourselves; only respond when we joined, or every joiner would trigger
    -- a SyncS storm from all enabled clients.
    if arg2 ~= UnitName("player") then return end
    if string.lower(arg9 or "") ~= string.lower(TWB_CHANNEL) then return end
    local msg = format_twb_sync()
    if msg then send_twb_message(msg) end
end

local function on_twb_channel_message()
    if not get_config("worldbuff.enabled") then return end
    if arg2 == UnitName("player") then return end
    if string.lower(arg9 or "") ~= string.lower(TWB_CHANNEL) then return end
    if string.find(arg1, "^SyncS:") then
        parse_twb_sync(string.sub(arg1, 7))
    elseif string.find(arg1, "^Lightning:") then
        parse_twb_lightning(arg1)
    end
end

-- Push locally detected kills into the TWB network (we become a data provider)
-- age: seconds the buff already ran before we had a server clock (pending
-- kill replay); nil/0 for a live detection.
local function notify_twb(faction, dragon_type, age)
    local key = faction .. "_" .. dragon_type
    local st = server_time_now()
    if not st then
        -- No reference clock yet: remember the kill and replay it once the
        -- server time arrives (see the ticker's pending-kill flush) instead
        -- of silently dropping a detected kill.
        pending_twb_kill = { faction = faction, dragon = dragon_type, wall = time() }
        return
    end
    if not wb_timers[key] then return end
    set_wb_timer(key, st + TWB_BUFF_DURATION - (age or 0))
    -- The NPC yell fires AFTER the buff is already applied, so broadcast the
    -- final state via SyncS. Sending Lightning ("buff about to land") would
    -- make WorldBuffsTracker clients announce a buff that has already landed.
    local entry = format_twb_entry(key)
    if entry then send_twb_message("SyncS:" .. entry) end
end

-- TWB per-second maintenance moved into the consolidated ticker below.

-- ================== UI: Timer Frame (PizzaWorldBuff style) ==================
local timer_frame
local timer_lines = {}

-- Faction brackets: 【LM】/【BL】 in zhCN, [A]/[H] otherwise (locale fallback).
local TIMER_ROW_PREFIX = {
    Alliance = L["[A] "],
    Horde = L["[H] "],
}

-- Dragon-only names (the faction bracket is implied by the row/line).
local DRAGON_LABELS = {
    Onyxia   = L["Onyxia "],
    Nefarian = L["Nefarian "],
}

-- Whole minutes, rounded up, wrapped in angle brackets: "<61分>" / "<61min>".
-- Used by both the timer frame rows and the chat report.
local function format_remaining_short(secs)
    return string.format("<%d%s>", math.ceil(secs / 60), L["m"])
end

-- Missing-buff marker: "<暂无>" / "<None>".
local function format_none_bracket()
    return "<" .. L["None"] .. ">"
end

-- "<bracket><dragon>" prefix of a timer row, e.g. "【LM】黑龙".
local function timer_row_prefix(key)
    local us = string.find(key, "_")
    return TIMER_ROW_PREFIX[string.sub(key, 1, us - 1)] .. DRAGON_LABELS[string.sub(key, us + 1)]
end

-- ================== Share Timer Menu (right-click) ==================
-- Right-clicking the timer frame opens a dropdown to send the current dragon
-- timers to a chat destination: say / yell / guild / party / raid or any of
-- the channels the player has joined.
local timer_menu = CreateFrame("Frame", "OzAiOWorldBuffMenu", UIParent, "UIDropDownMenuTemplate")

-- Returns two report lines (Alliance, Horde), e.g. zhCN:
--   【LM】黑龙<61分>奈法<暂无>
--   【BL】黑龙<55分>奈法<106分>
-- Both dragons of a faction are always present; a missing buff prints a
-- bracket None instead of dropping the entry.
local function format_timer_summary()
    local st = server_time_now()
    local alliance = {}
    local horde = {}

    for _, key in ipairs(wb_timer_keys) do
        local faction = string.sub(key, 1, string.find(key, "_") - 1)
        local dragon = string.sub(key, string.find(key, "_") + 1)
        local t = wb_timers[key]
        local time_text
        if t and t.active and t.to and st and t.to > st then
            time_text = format_remaining_short(t.to - st)
        else
            time_text = format_none_bracket()
        end
        local parts = faction == "Alliance" and alliance or horde
        table.insert(parts, DRAGON_LABELS[dragon] .. time_text)
    end

    return TIMER_ROW_PREFIX.Alliance .. table.concat(alliance),
           TIMER_ROW_PREFIX.Horde .. table.concat(horde)
end

local function timer_menu_initialize()
    -- add_target keeps its args in locals (Lua 5.0: no shared loop vars)
    local function add_target(text, chat_type, channel_num)
        local info = {}
        info.text = text
        info.notCheckable = true
        info.func = function()
            -- format_timer_summary returns one line per faction; send each
            -- line as its own chat message. Both lines always have content
            -- (missing buffs print a bracket None).
            local alliance_line, horde_line = format_timer_summary()
            local function send_line(msg)
                if chat_type == "CHANNEL" then
                    SendChatMessage(msg, "CHANNEL", nil, channel_num)
                else
                    SendChatMessage(msg, chat_type)
                end
            end
            if alliance_line ~= "" then
                send_line(alliance_line)
            end
            if horde_line ~= "" then
                send_line(horde_line)
            end
        end
        UIDropDownMenu_AddButton(info)
    end

    local title = {}
    title.text = L["Send timer to"]
    title.isTitle = true
    title.notCheckable = true
    UIDropDownMenu_AddButton(title)

    -- Chat type labels are L keys, not the SAY/YELL/GUILD client globals:
    -- those are not defined consistently across 1.12-based clients (this one
    -- leaves YELL/GUILD unset, which rendered empty menu rows).
    add_target(L["Say"], "SAY")
    add_target(L["Yell"], "YELL")
    if IsInGuild() then
        add_target(L["Guild"], "GUILD")
    end
    if GetNumPartyMembers() > 0 then
        add_target(L["Party"], "PARTY")
    end
    if GetNumRaidMembers() > 0 then
        add_target(L["Raid"], "RAID")
    end

    -- "Hardcore" is a first-class Turtle WoW chat type (CHAT_MSG_HARDCORE),
    -- not a regular joined channel, so it is listed explicitly and excluded
    -- from the dynamic channel list below.
    add_target(L["Hardcore"], "Hardcore")

    -- Joined chat channels (skip TWB: the machine sync channel, and Hardcore:
    -- already listed above). This is dynamic: any custom channel the player
    -- joins (e.g. "bestplayer") shows up here automatically. GetChannelList()
    -- pair order differs across 1.12-based clients (Blizzard: name, number;
    -- some repacks: number, name), so the element types are checked instead
    -- of assuming an order.
    local channels = { GetChannelList() }
    local channel_entries = {}
    for i = 1, table.getn(channels), 2 do
        local first, second = channels[i], channels[i + 1]
        local name, num
        if type(first) == "number" then
            name, num = second, first
        else
            name, num = first, second
        end
        local is_hardcore = type(name) == "string"
            and (string.lower(name) == "hardcore" or name == "硬核")
        -- TWB is the machine sync channel; LFT is intentionally excluded to
        -- avoid automatic world-buff spam in the global looking-for-group
        -- channel.
        if name and not is_hardcore and name ~= TWB_CHANNEL and name ~= LFT_CHANNEL then
            table.insert(channel_entries, { name, num })
        end
    end
    for _, entry in ipairs(channel_entries) do
        add_target(entry[1], "CHANNEL", entry[2])
    end
end

-- Create the per-timer font strings on the timer frame (called once from
-- create_timer_frame). The rows are created together, so they are never
-- missing while the frame exists.
local function create_timer_lines()
    local row_y = -24
    for _, key in ipairs(wb_timer_keys) do
        local line = timer_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetPoint("TOPLEFT", timer_frame, "TOPLEFT", 8, row_y)
        if string.sub(key, 1, string.find(key, "_") - 1) == "Alliance" then
            line:SetTextColor(0.3, 0.6, 1)
        else
            line:SetTextColor(1, 0.35, 0.35)
        end
        line:SetText(timer_row_prefix(key) .. format_none_bracket())
        timer_lines[key] = line
        row_y = row_y - 16
    end
end

local function create_timer_frame()
    if timer_frame then return end
    timer_frame = CreateFrame("Frame", "OzAiOWorldBuffTimer", UIParent)
    timer_frame:SetWidth(100)
    timer_frame:SetHeight(92)
    timer_frame:SetFrameStrata("MEDIUM")
    timer_frame:EnableMouse(true)
    timer_frame:SetMovable(true)
    timer_frame:RegisterForDrag("LeftButton")

    -- Transparent background, no border
    timer_frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16,
    })
    timer_frame:SetBackdropColor(0, 0, 0, 0.4)
    timer_frame:SetBackdropBorderColor(0, 0, 0, 0)

    local title = timer_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", timer_frame, "TOP", 0, -4)
    title:SetText(L["World Buff Timer"])
    title:SetTextColor(1, 0.9, 0.5)

    create_timer_lines()

    -- Drag anywhere on the frame; persist the position in config
    timer_frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    timer_frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local left, bottom = timer_frame:GetLeft(), timer_frame:GetBottom()
        local ul, ub = UIParent:GetLeft(), UIParent:GetBottom()
        if left and ul then
            set_config("worldbuff.timerPos", { left - ul, bottom - ub })
        end
    end)

    -- Right-click opens the "send timer to" chat menu. Plain frames have no
    -- RegisterForClicks in 1.12 (Button-only API), so right-clicks are
    -- detected via OnMouseUp, which fires on any mouse-enabled frame.
    timer_frame:SetScript("OnMouseUp", function()
        if arg1 == "RightButton" then
            UIDropDownMenu_Initialize(timer_menu, timer_menu_initialize)
            ToggleDropDownMenu(1, nil, timer_menu, timer_frame:GetName(), 0, 0)
        end
    end)

    local pos = get_config("worldbuff.timerPos")
    timer_frame:ClearAllPoints()
    if pos then
        timer_frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
    else
        -- Default to the right side of the screen, clear of chat and action bars
        timer_frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -120, -140)
    end

    -- Countdown text is refreshed once per second by the consolidated ticker
end

local function update_timer_frame()
    if not timer_frame then return end
    if get_config("worldbuff.enabled") and get_config("worldbuff.timer") then
        timer_frame:Show()
    else
        timer_frame:Hide()
    end
end

-- ================== Consolidated Ticker ==================
-- Single OnUpdate dispatcher for all periodic work: caution fade/countdown,
-- logout/hearthstone auto-hide, TWB channel/sync maintenance, and the timer
-- frame text refresh. Vanilla's shared UI thread stays as idle as possible.
local ticker_frame = CreateFrame("Frame", "OzAiOWorldBuffTicker", UIParent)
-- Hidden until module.enable(); the OnUpdate guard below makes this a full
-- stop for all per-frame work while the module is disabled.
ticker_frame:Hide()
local tick_elapsed = 0
local join_elapsed = TWB_JOIN_CHECK_INTERVAL -- join on the very first tick
local sync_elapsed = 0
local server_retry_elapsed = 0
local server_retry_count = 0
local server_retry_interval = SERVER_RETRY_INITIAL_INTERVAL

local function on_second_tick()
    local now = GetTime()

    -- Auto logout (combat-safe) and hearthstone auto-hide
    if get_config("worldbuff.autoLogout") then
        check_logout(now)
    end
    if hearthstone_hide_time and now >= hearthstone_hide_time then
        hearthstone_hide_time = nil
        if hearthstone_button then
            hearthstone_button:Hide()
        end
    end

    -- TWB channel maintenance
    if get_config("worldbuff.enabled") then
        cleanup_wb_timers()

        -- A local kill recorded before the server clock was synced is
        -- replayed as soon as a reference time exists (aged so a late replay
        -- does not overstate the remaining buff duration).
        if pending_twb_kill and server_time_now() then
            local kill = pending_twb_kill
            pending_twb_kill = nil
            local age = time() - kill.wall
            if age < TWB_BUFF_DURATION then
                notify_twb(kill.faction, kill.dragon, age)
            end
        end

        join_elapsed = join_elapsed + 1
        sync_elapsed = sync_elapsed + 1

        if join_elapsed >= TWB_JOIN_CHECK_INTERVAL then
            join_elapsed = 0
            join_twb_channel()
        end
        if sync_elapsed >= TWB_SYNC_INTERVAL then
            sync_elapsed = 0
            local msg = format_twb_sync()
            if msg then send_twb_message(msg) end
        end
        -- Server-time retry with backoff (5s -> 10s -> 20s -> 40s -> 60s),
        -- stopping after SERVER_RETRY_LIMIT attempts instead of retrying
        -- forever.
        if not server_time_offset and server_retry_count < SERVER_RETRY_LIMIT then
            server_retry_elapsed = server_retry_elapsed + 1
            if server_retry_elapsed >= server_retry_interval then
                server_retry_elapsed = 0
                server_retry_count = server_retry_count + 1
                server_retry_interval = math.min(server_retry_interval * 2, SERVER_RETRY_MAX_INTERVAL)
                request_server_time()
            end
        end
    end

    -- Timer frame countdown text (once per second while shown)
    if timer_frame and timer_frame:IsShown() then
        local st = server_time_now()
        for _, key in ipairs(wb_timer_keys) do
            local line = timer_lines[key]
            if line then
                local t = wb_timers[key]
                local text = timer_row_prefix(key)
                if t and t.active and t.to and st and t.to - st > 0 then
                    text = text .. format_remaining_short(t.to - st)
                else
                    text = text .. format_none_bracket()
                end
                line:SetText(text)
            end
        end
    end
end

ticker_frame:SetScript("OnUpdate", function()
    -- Disabled: the frame is hidden, so no per-frame work runs
    if not this:IsShown() then return end
    local elapsed = arg1
    if caution and caution:IsShown() then
        caution_onupdate(elapsed)
    end
    tick_elapsed = tick_elapsed + elapsed
    if tick_elapsed >= 1 then
        tick_elapsed = tick_elapsed - 1
        on_second_tick()
    end
end)

-- ================== Event Handlers ==================
local function on_monster_yell()
    if not get_config("worldbuff.enabled") then return end
    local faction = get_faction()
    local npcs = dragon_config[faction]
    if not npcs then return end

    local npc_name = arg2
    local yell_text = arg1

    -- fix #10: use ipairs over ordered list instead of pairs
    for _, dragon_type in ipairs(dragon_types_list) do
        local info = npcs[dragon_type]
        if info and npc_name == info.name and string.find(yell_text, info.yell) then
            -- fix #8: check channel exists before sending
            local channel = GetChannelName(LFT_CHANNEL)
            if channel and channel > 0 then
                SendChatMessage(
                    RELAY_PREFIX .. ":" .. dragon_type .. ":" .. faction,
                    "CHANNEL",
                    nil,
                    channel
                )
            end
            -- Feed the TWB sync network so other players see the timer;
            -- state change first, then the local UI/notifications.
            notify_twb(faction, dragon_type)
            trigger_alert(faction, dragon_type)
            return
        end
    end
end

local function on_channel_message()
    if not get_config("worldbuff.enabled") then return end
    if arg2 == UnitName("player") then return end
    if string.lower(arg9 or "") ~= string.lower(LFT_CHANNEL) then return end

    -- fix #1, #9: capture groups with brackets to extract values
    local _, _, dragon_type, dragon_faction = string.find(
        arg1,
        "^" .. RELAY_PREFIX .. ":([^:]+):([^:]+)$"
    )
    if dragon_type and dragon_faction and dragon_faction == get_faction() then
        trigger_alert(dragon_faction, dragon_type)
    end
end

-- ================== Event Frame ==================
-- Registered as a whole by module.enable() and dropped by module.disable()'s
-- UnregisterAllEvents, so no event work runs while the module is disabled.
local EVENTS = {
    "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_CHANNEL_JOIN",
    "CHAT_MSG_SYSTEM",
    "PLAYER_ENTERING_WORLD",
    "BAG_UPDATE",
}

local event_frame = CreateFrame("Frame", "OzAiOWorldBuffEvents", UIParent)
event_frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_MONSTER_YELL" then
        on_monster_yell()
    elseif event == "CHAT_MSG_CHANNEL" then
        if string.lower(arg9 or "") == string.lower(TWB_CHANNEL) then
            on_twb_channel_message()
        else
            on_channel_message()
        end
    elseif event == "CHAT_MSG_CHANNEL_JOIN" then
        on_twb_channel_join()
    elseif event == "CHAT_MSG_SYSTEM" then
        on_system_message()
    elseif event == "PLAYER_ENTERING_WORLD" then
        request_server_time()
    elseif event == "BAG_UPDATE" then
        invalidate_hearthstone()
    end
end)

-- ================== Slash Command ==================
-- Accept common spellings/casing for the test command
local dragon_aliases = {
    onyxia = "Onyxia",
    nef = "Nefarian",
    nefarian = "Nefarian",
}

SLASH_OZWORLDBUFF1 = "/ozwb"
SlashCmdList["OZWORLDBUFF"] = function(msg)
    local faction = get_faction()
    local key = string.lower(string.gsub(msg or "", "%s", ""))
    local dragon_type = dragon_aliases[key] or (key ~= "" and key or "Onyxia")

    if not dragon_config[faction] or not dragon_config[faction][dragon_type] then
        OzLib.print(L["Invalid dragon type, use Onyxia or Nefarian"], "error")
        return
    end

    trigger_alert(faction, dragon_type)
    DEFAULT_CHAT_FRAME:AddMessage(L["Test world buff: "] .. dragon_config[faction][dragon_type].msg)
end

-- ================== Module Registration ==================
local module = OzFramework:register("oz_worldbuff", {
    title = L["World Buff"],
    order = 5,
    enabled = true,
    config = {
        ["worldbuff.enabled"] = true,
        ["worldbuff.countdown"] = true,
        ["worldbuff.sound"] = true,
        ["worldbuff.hearthstone"] = true,
        ["worldbuff.timer"] = true,
        ["worldbuff.guild"] = false,
        ["worldbuff.autoLogout"] = false,
    }
})

module.enable = function(self)
    -- worldbuff.enabled is the user-facing master switch: if it is off,
    -- nothing below runs even though the framework enabled the module.
    if not get_config("worldbuff.enabled") then return end
    for _, event in ipairs(EVENTS) do
        event_frame:RegisterEvent(event)
    end
    ticker_frame:Show()
    -- Fresh server-time retry budget on every enable
    server_retry_elapsed = 0
    server_retry_count = 0
    server_retry_interval = SERVER_RETRY_INITIAL_INTERVAL
    create_caution_frame()
    create_hearthstone_button()
    create_timer_frame()
    join_twb_channel()
    request_server_time()
    update_timer_frame()
end

-- fix #8: clean up on disable
module.disable = function(self)
    -- Drop the config cache so a later re-enable re-reads OZAIO_CONFIG
    for k in pairs(config_cache) do
        config_cache[k] = nil
    end
    logout_at = nil
    hearthstone_hide_time = nil
    countdown_active = false
    invalidate_hearthstone()
    pending_twb_kill = nil
    ticker_frame:Hide()
    event_frame:UnregisterAllEvents()
    if caution then
        caution:Hide()
    end
    if hearthstone_button then
        hearthstone_button:Hide()
    end
    if timer_frame then
        timer_frame:Hide()
    end
end

module.create_config_panel = function(self, parent)
    local panel = CreateFrame("Frame", "OzWorldBuffConfig", parent)
    panel:SetAllPoints()

    local flow = OzUIHelper:createFlow(panel, 10)
    OzUIHelper:attachResize(panel, flow)

    local title = OzUIHelper:makeLabel(panel, L["World Buff"], "GameFontNormalLarge")
    title:SetWidth(flow.maxWidth - flow.padding)
    title:SetJustifyH("CENTER")
    OzUIHelper:add(flow, title, flow.maxWidth - flow.padding, 20)
    OzUIHelper:newLine(flow)

    local items = {
        { key = "worldbuff.enabled", label = L["Enable"],
          -- Master switch: start/stop the whole module machinery (events,
          -- ticker, TWB channel) instead of leaving it half-running.
          onToggle = function()
              if get_config("worldbuff.enabled") then
                  module:enable()
              else
                  module:disable()
              end
          end },
        { key = "worldbuff.countdown",   label = L["Countdown bar"] },
        { key = "worldbuff.sound",       label = L["Sound alert"] },
        { key = "worldbuff.hearthstone", label = L["Hearthstone button"] },
        { key = "worldbuff.timer",       label = L["Timer frame"], onToggle = update_timer_frame },
        { key = "worldbuff.guild",       label = L["Guild notify"] },
        { key = "worldbuff.autoLogout",  label = L["Auto logout"] },
    }

    for _, item in ipairs(items) do
        local key = item.key
        local label = item.label
        local value = get_config(key) or false
        -- Lua 5.0: the for-loop variable (`item`) is nil inside closures after
        -- the loop ends; capture per-iteration values in locals instead
        local onToggle = item.onToggle
        OzUIHelper:add(flow, OzUIHelper:makeCheckbox(
            panel, label, value,
            function(checked)
                set_config(key, checked)
                if onToggle then onToggle() end
            end
        ))
        OzUIHelper:newLine(flow)
    end

    return { frame = panel, height = math.abs(flow.y) + flow.padding }
end
