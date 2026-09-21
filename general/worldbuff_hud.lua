-- World Buff Floating Timer HUD & Share Menu for OzAiO
-- Extracted from general/worldbuff.lua

OzWorldBuffHUD = OzWorldBuffHUD or {}

local locale = GetLocale()
local L_LOCAL = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

if locale == "zhCN" then
    L_LOCAL["World Buff Timer"] = "龙头计时"
    L_LOCAL["None"] = "暂无"
    L_LOCAL["[A] "] = "【LM】"
    L_LOCAL["[H] "] = "【BL】"
    L_LOCAL["Onyxia "] = "黑龙"
    L_LOCAL["Nefarian "] = "奈法"
    L_LOCAL["m"] = "分"
    L_LOCAL["Send timer to"] = "发送计时到"
    L_LOCAL["Say"] = "说话"
    L_LOCAL["Yell"] = "大喊"
    L_LOCAL["Guild"] = "公会"
    L_LOCAL["Party"] = "小队"
    L_LOCAL["Raid"] = "团队"
    L_LOCAL["Hardcore"] = "硬核"
end

local L = L_LOCAL

-- Internal state references
local server_time_now_fn = nil
local wb_timers_ref = nil
local get_config_fn = nil
local set_config_fn = nil

local timer_frame = nil
local timer_lines = {}
local line_cached_text = {}
local minute_cache = {}
local timer_none_text = {}

local wb_timer_keys = { "Alliance_Onyxia", "Alliance_Nefarian", "Horde_Onyxia", "Horde_Nefarian" }

local function get_row_prefix(faction)
    return (faction == "Alliance" and L["[A] "]) or L["[H] "]
end

local function get_dragon_label(dragon)
    return (dragon == "Onyxia" and L["Onyxia "]) or L["Nefarian "]
end

local function format_none_bracket()
    return "<" .. L["None"] .. ">"
end

local function timer_row_prefix(key)
    local us = string.find(key, "_")
    local faction = string.sub(key, 1, us - 1)
    local dragon = string.sub(key, us + 1)
    return get_row_prefix(faction) .. get_dragon_label(dragon)
end

-- ================== Share Timer Menu (Right-Click) ==================
local timer_menu = nil
local function get_timer_menu()
    if not timer_menu then
        timer_menu = CreateFrame("Frame", "OzAiOWorldBuffMenu", UIParent, "UIDropDownMenuTemplate")
    end
    return timer_menu
end

local function format_timer_summary()
    local st = server_time_now_fn and server_time_now_fn()
    local alliance = {}
    local horde = {}

    for _, key in ipairs(wb_timer_keys) do
        local faction = string.sub(key, 1, string.find(key, "_") - 1)
        local dragon = string.sub(key, string.find(key, "_") + 1)
        local t = wb_timers_ref and wb_timers_ref[key]
        local time_text
        if t and t.active and t.to and st and t.to > st then
            time_text = string.format("<%d%s>", math.ceil((t.to - st) / 60), L["m"])
        else
            time_text = format_none_bracket()
        end
        local parts = faction == "Alliance" and alliance or horde
        table.insert(parts, get_dragon_label(dragon) .. time_text)
    end

    return get_row_prefix("Alliance") .. table.concat(alliance),
           get_row_prefix("Horde") .. table.concat(horde)
end

local function timer_menu_initialize()
    local function add_target(text, chat_type, channel_num)
        local info = {}
        info.text = text
        info.notCheckable = true
        info.func = function()
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

    add_target(L["Hardcore"], "Hardcore")

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
        if name and not is_hardcore and name ~= "TWB" and name ~= "LFT" then
            table.insert(channel_entries, { name, num })
        end
    end
    for _, entry in ipairs(channel_entries) do
        add_target(entry[1], "CHANNEL", entry[2])
    end
end

-- ================== HUD Construction ==================
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
        local none_str = timer_row_prefix(key) .. format_none_bracket()
        timer_none_text[key] = none_str
        line_cached_text[key] = none_str
        line:SetText(none_str)
        timer_lines[key] = line
        row_y = row_y - 16
    end
end

function OzWorldBuffHUD:init(server_time_fn, timers_table, get_cfg_fn, set_cfg_fn, locTable)
    server_time_now_fn = server_time_fn
    wb_timers_ref = timers_table
    get_config_fn = get_cfg_fn
    set_config_fn = set_cfg_fn
    if locTable then L = locTable end
end

function OzWorldBuffHUD:create()
    if timer_frame then return timer_frame end

    timer_frame = CreateFrame("Frame", "OzAiOWorldBuffTimer", UIParent)
    timer_frame:SetWidth(135)
    timer_frame:SetHeight(92)
    timer_frame:SetFrameStrata("MEDIUM")
    timer_frame:EnableMouse(true)
    timer_frame:SetMovable(true)
    timer_frame:RegisterForDrag("LeftButton")

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

    timer_frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    timer_frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local left, bottom = timer_frame:GetLeft(), timer_frame:GetBottom()
        local ul, ub = UIParent:GetLeft(), UIParent:GetBottom()
        if left and ul and set_config_fn then
            set_config_fn("worldbuff.timer_pos", { left - ul, bottom - ub })
        end
    end)

    timer_frame:SetScript("OnMouseUp", function()
        if arg1 == "RightButton" then
            local menu = get_timer_menu()
            UIDropDownMenu_Initialize(menu, timer_menu_initialize)
            ToggleDropDownMenu(1, nil, menu, timer_frame:GetName(), 0, 0)
        end
    end)

    local pos = get_config_fn and get_config_fn("worldbuff.timer_pos")
    timer_frame:ClearAllPoints()
    if pos then
        timer_frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
    else
        timer_frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -120, -140)
    end

    return timer_frame
end

-- Update countdown strings: skips string formatting when no active timer timestamp exists
function OzWorldBuffHUD:update(st, wb_timers)
    if not timer_frame or not timer_frame:IsShown() then return end
    local timers = wb_timers or wb_timers_ref
    if not timers then return end

    for _, key in ipairs(wb_timer_keys) do
        local line = timer_lines[key]
        if line then
            local t = timers[key]
            if t and t.active and t.to and st and (t.to - st > 0) then
                local remaining_mins = math.ceil((t.to - st) / 60)
                if minute_cache[key] ~= remaining_mins then
                    minute_cache[key] = remaining_mins
                    local active_str = timer_row_prefix(key) .. "<" .. remaining_mins .. L["m"] .. ">"
                    line_cached_text[key] = active_str
                    line:SetText(active_str)
                end
            else
                -- No active timer: skip formatting if already showing none
                minute_cache[key] = nil
                local none_str = timer_none_text[key]
                if line_cached_text[key] ~= none_str then
                    line_cached_text[key] = none_str
                    line:SetText(none_str)
                end
            end
        end
    end
end

function OzWorldBuffHUD:show()
    if timer_frame then
        timer_frame:Show()
    end
end

function OzWorldBuffHUD:hide()
    if timer_frame then
        timer_frame:Hide()
    end
end

function OzWorldBuffHUD:isShown()
    return timer_frame and timer_frame:IsShown()
end

function OzWorldBuffHUD:updateVisibility(enabled, timer_enabled)
    if not timer_frame then return end
    if enabled and timer_enabled then
        timer_frame:Show()
    else
        timer_frame:Hide()
    end
end

