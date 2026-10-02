-- Feature 1: add /rl shortcut for /reloadui
-- Feature 2: customize font size, but keep it simple — user only defines GameFontNormal size
--           Small = Normal - 2, Large = Normal + 2
-- Feature 3: Auto Dismount / Auto Stance (ported from ShaguTweaks)

local locale = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if locale == "zhCN" then
    L["General"] = "通用"
    L["Use /rl to reload the interface."] = "输入/rl以重新加载插件及界面"
    L["Font Size"] = "字体大小"
    L["Small = Normal - 2, Large = Normal + 2"] = "小字体 = 基础 - 2，大字体 = 基础 + 2"
    L["Auto Dismount"] = "自动下坐骑"
    L["Automatically dismounts whenever a spell is casted."] = "当施放任何法术时自动取消坐骑。"
    L["Auto Stance"] = "自动切姿态"
    L["Automatically switch to the required warrior or druid stance on spell cast."] = "自动切换技能所需姿态(战士/德鲁伊)。"
    L["Auto Dismount and Auto Stance disabled: pfUI/ShaguTweaks detected"] = "检测到 pfUI/ShaguTweaks，已默认关闭自动下坐骑和自动切姿态"
end

-- Cache original font path and flags per font object so resizing only alters size
local font_cache = {}

-- Helper: safely set font size on a font object while preserving its original font file
local function set_font_safe(font_object, size, flags_override, is_number)
    if not (font_object and font_object.SetFont) then return end

    local cached = font_cache[font_object]
    if not cached then
        local path, _, original_flags = nil, nil, nil
        if font_object.GetFont then path, _, original_flags = font_object:GetFont() end
        if not path or path == "" or (not is_number and string.find(string.upper(path), "ARIALN")) then
            path = is_number and "Fonts\\ARIALN.TTF" or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
        end
        cached = { path = path, flags = original_flags }
        font_cache[font_object] = cached
    end

    font_object:SetFont(cached.path, size, flags_override or cached.flags)
end

local function set_group(fonts, size, flags, is_num)
    for _, f in ipairs(fonts) do set_font_safe(f, size, flags, is_num) end
end

-- Apply font size across all game font objects
local function apply_font_size(base)
    base = (type(base) == "number" and base >= 8 and base <= 20) and base or 14
    local sm, lg, hg = base - 2, base + 2, base + 6

    set_group(
        { SystemFont, GameFontNormal, GameFontHighlight, GameFontDisable, GameFontGreen, GameFontRed, GameFontBlack,
            GameFontWhite, DialogButtonNormalText, DialogButtonHighlightText, ChatFontNormal }, base)
    set_group(
        { GameFontNormalSmall, GameFontHighlightSmall, GameFontDisableSmall, GameFontGreenSmall, GameFontRedSmall,
            GameFontDarkGraySmall, QuestFontNormalSmall, TextStatusBarText, GameTooltipText }, sm)
    set_group(
        { GameFontNormalLarge, GameFontHighlightLarge, GameFontDisableLarge, GameFontGreenLarge, GameFontRedLarge }, lg)
    set_group({ QuestTitleFont, GameFontNormalHuge }, hg)
    set_font_safe(GameFontHighlightSmallOutline, sm, "OUTLINE")
    set_font_safe(GameTooltipHeaderText, base, "THICK")
    set_font_safe(NumberFontNormal, base, "OUTLINE", true)
    set_font_safe(NumberFontNormalSmall, sm, "OUTLINE", true)
    set_font_safe(NumberFontNormalLarge, lg, "OUTLINE", true)
end

-- ================== Feature 3: Auto Dismount / Auto Stance ==================
-- Buff icons used by druid / shaman shapeshift forms
local shapeshift_icons = {
    "ability_racial_bearform", "ability_druid_catform", "ability_druid_travelform",
    "spell_nature_forceofnature", "ability_druid_aquaticform", "spell_nature_spiritwolf",
}

-- Buff icon fragments shared by mount buffs on this client (Turtle WoW)
local mount_icons = {
    "_mount_",                -- regular mounts (Ability_Mount_*)
    "spell_nature_swiftness", -- skeletal warhorse / mechanostrider / kodo / dreadsteed / raptor
    "_qirajicrystal_",        -- Qiraji crystal mounts
    "hunter_pet_turtle",      -- turtle mount (Turtle WoW)
    "boar",                   -- wild boar
    "warstomp",               -- zebra
    "bullrush",               -- ghost griffon
    "_branch_",               -- reindeer
    "zuoqi",                  -- generic Turtle WoW mount icon
    "inv_pet_speedy",
    "inv_misc_head_dragon_black",
    "spell_nature_wispsplode",
    "inv_misc_branch_01",
    "inv_valentinesboxofchocolates02", -- pink horse
    "inv_valentinescard01",            -- pink tiger
    "ability_hunter_pet_dragonhawk",   -- dragonhawk
    "ability_hunter_pet_tallstrider",
    "inv_misc_horn_01",
    "hunter_pet_bear",              -- bear
    "hunter_pet_hippogryph",        -- hippogryph
    "hunter_pet_stag1",             -- stag
    "hunter_pet_tallstrider",       -- lovebird
    "inv_misc_key_06",              -- engineering mounts
    "inv_misc_key_12",
    "spell_nature_sentinal",        -- raven
    "spell_magic_polymorphchicken", -- magic rooster
}

-- Errors that indicate the player is mounted or shapeshifted (client-localized)
local mount_errors = {
    SPELL_FAILED_NOT_MOUNTED, ERR_ATTACK_MOUNTED, ERR_TAXIPLAYERALREADYMOUNTED,
    SPELL_FAILED_NOT_SHAPESHIFT, SPELL_FAILED_NO_ITEMS_WHILE_SHAPESHIFTED, SPELL_NOT_SHAPESHIFTED,
    SPELL_NOT_SHAPESHIFTED_NOSPACE, ERR_CANT_INTERACT_SHAPESHIFTED, ERR_NOT_WHILE_SHAPESHIFTED,
    ERR_NO_ITEMS_WHILE_SHAPESHIFTED, ERR_TAXIPLAYERSHAPESHIFTED, ERR_MOUNT_SHAPESHIFTED,
}

local function handle_dismount(error_msg)
    if error_msg == SPELL_FAILED_NOT_STANDING then
        SitOrStand()
        return
    end

    local is_blocked = false
    for _, err in ipairs(mount_errors) do
        if error_msg == err then
            is_blocked = true
            break
        end
    end
    if not is_blocked then return end

    for i = 0, 31 do
        local texture = GetPlayerBuffTexture(i)
        if texture then
            local lower_texture = string.lower(texture)
            for _, icon in ipairs(mount_icons) do
                if string.find(lower_texture, icon) then
                    CancelPlayerBuff(i)
                    return
                end
            end
            for _, icon in ipairs(shapeshift_icons) do
                if string.find(lower_texture, icon) then
                    CancelPlayerBuff(i)
                    return
                end
            end
        end
    end
end

-- "Can't do that while %s" -> "Can't do that while (.+)" (client-localized)
local function split_string(delimiter, subject)
    if not subject then return nil end
    local sep = delimiter or ":"
    local pattern = string.format("([^%s]+)", sep)
    local fields = {}
    string.gsub(subject, pattern, function(c)
        fields[table.getn(fields) + 1] = c
    end)
    return unpack(fields)
end

local stance_scan = string.gsub(SPELL_FAILED_ONLY_SHAPESHIFT, "%%s", "(.+)")

local function handle_stance(error_msg)
    for stances in string.gfind(error_msg, stance_scan) do
        local list = { split_string(",", stances) }
        for i = 1, table.getn(list) do
            CastSpellByName(string.gsub(list[i], "^%s*(.-)%s*$", "%1"))
        end
    end
end

-- Listener frame, created in module.enable
local automation_frame = nil
-- Delayed font initializer frame for PLAYER_ENTERING_WORLD
local font_init_frame = nil
local entered_world = false

local module = OzFramework:registerMod({
    name = "oz_general",
    title = L["General"],
    category = "General",
    order = 0,
    enabled = true,
    config = {
        ["general.font_size"] = 14,
        ["general.auto_dismount"] = true,
        ["general.auto_stance"] = true,
    },
    config_ui_creator = {
        {
            type = "slider",
            label = L["Font Size"],
            min = 8,
            max = 20,
            step = 1,
            config_key = "general.font_size",
            tooltip = L["Small = Normal - 2, Large = Normal + 2"],
            onChange = function(value)
                apply_font_size(value)
            end,
        },
        {
            type = "checkbox",
            label = L["Auto Dismount"],
            config_key = "general.auto_dismount",
            tooltip = L["Automatically dismounts whenever a spell is casted."],
        },
        {
            type = "checkbox",
            label = L["Auto Stance"],
            config_key = "general.auto_stance",
            tooltip = L["Automatically switch to the required warrior or druid stance on spell cast."],
        },
    },
    enable = function(self)
        -- Register /rl command
        if not SlashCmdList["OZAIO_RL"] then
            SLASH_OZAIO_RL1 = "/rl"
            SlashCmdList["OZAIO_RL"] = function() ReloadUI() end
        end

        local function apply_current_font()
            apply_font_size((OZAIO_CONFIG and OZAIO_CONFIG["general.font_size"]) or 14)
        end

        if entered_world then
            apply_current_font()
        elseif not font_init_frame then
            font_init_frame = CreateFrame("Frame")
            font_init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            font_init_frame:SetScript("OnEvent", function()
                entered_world = true
                font_init_frame:UnregisterAllEvents()
                local elapsed = 0
                font_init_frame:SetScript("OnUpdate", function()
                    elapsed = elapsed + (arg1 or 0)
                    if elapsed >= 0.1 then
                        font_init_frame:SetScript("OnUpdate", nil)
                        apply_current_font()
                    end
                end)
            end)
        end

        -- Auto Dismount / Auto Stance listener (feature 3)
        if not automation_frame then
            automation_frame = CreateFrame("Frame")
            automation_frame:RegisterEvent("UI_ERROR_MESSAGE")
            automation_frame:SetScript("OnEvent", function()
                if OZAIO_CONFIG and OZAIO_CONFIG["general.auto_dismount"] then handle_dismount(arg1) end
                if OZAIO_CONFIG and OZAIO_CONFIG["general.auto_stance"] and string.find(arg1, stance_scan) then
                    handle_stance(arg1)
                end
            end)
        end
    end,
    disable = function(self)
        if font_init_frame then
            font_init_frame:UnregisterAllEvents()
            font_init_frame:SetScript("OnEvent", nil)
            font_init_frame:SetScript("OnUpdate", nil)
            font_init_frame = nil
        end
        if automation_frame then
            automation_frame:UnregisterAllEvents()
            automation_frame:SetScript("OnEvent", nil)
            automation_frame = nil
        end
    end,
})

module.on_config_change = function(self, key, value)
    if key == "general.font_size" then
        apply_font_size(value)
    end
end
