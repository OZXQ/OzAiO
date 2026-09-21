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

-- Default font path (can be changed as needed)
local font_path = "Fonts\\FRIZQT__.TTF"
if locale == "zhCN" then
    font_path = "Fonts\\ARIALN.TTF"
end

-- Helper: safely set font on a font object
local function set_font_safe(font_object, path, size, flags)
    if font_object and font_object.SetFont then
        font_object:SetFont(path, size, flags)
    end
end

-- Apply font size across all game font objects
local function apply_font_size(base_size)
    if not base_size or type(base_size) ~= "number" or base_size < 8 or base_size > 20 then
        base_size = 14
    end

    local small_size = base_size - 2
    local large_size = base_size + 2
    local huge_size = large_size + 4

    -- 1. Core GameFont series
    set_font_safe(SystemFont, font_path, base_size)
    set_font_safe(GameFontNormal, font_path, base_size)
    set_font_safe(GameFontHighlight, font_path, base_size)
    set_font_safe(GameFontDisable, font_path, base_size)
    set_font_safe(GameFontGreen, font_path, base_size)
    set_font_safe(GameFontRed, font_path, base_size)
    set_font_safe(GameFontBlack, font_path, base_size)
    set_font_safe(GameFontWhite, font_path, base_size)
    set_font_safe(DialogButtonNormalText, font_path, base_size)
    set_font_safe(DialogButtonHighlightText, font_path, base_size)

    -- Small (Normal - 2)
    set_font_safe(GameFontNormalSmall, font_path, small_size)
    set_font_safe(GameFontHighlightSmall, font_path, small_size)
    set_font_safe(GameFontHighlightSmallOutline, font_path, small_size, "OUTLINE")
    set_font_safe(GameFontDisableSmall, font_path, small_size)
    set_font_safe(GameFontGreenSmall, font_path, small_size)
    set_font_safe(GameFontRedSmall, font_path, small_size)
    set_font_safe(GameFontDarkGraySmall, font_path, small_size)

    -- Large (Normal + 2)
    set_font_safe(GameFontNormalLarge, font_path, large_size)
    set_font_safe(GameFontHighlightLarge, font_path, large_size)
    set_font_safe(GameFontDisableLarge, font_path, large_size)
    set_font_safe(GameFontGreenLarge, font_path, large_size)
    set_font_safe(GameFontRedLarge, font_path, large_size)

    -- 2. Other common fonts, mapped to corresponding sizes
    set_font_safe(NumberFontNormal, font_path, base_size, "OUTLINE")
    set_font_safe(NumberFontNormalSmall, font_path, small_size, "OUTLINE")
    set_font_safe(NumberFontNormalLarge, font_path, large_size, "OUTLINE")
    set_font_safe(ChatFontNormal, font_path, base_size)
    set_font_safe(QuestFontNormalSmall, font_path, small_size)
    set_font_safe(QuestTitleFont, font_path, huge_size)
    set_font_safe(TextStatusBarText, font_path, small_size)
    set_font_safe(GameTooltipText, font_path, small_size)
    set_font_safe(GameTooltipHeaderText, font_path, base_size, "THICK")
    set_font_safe(GameFontNormalHuge, font_path, huge_size)
end

-- Apply font size to game fonts plus the player/target name plates
local function apply_all_font_sizes(base_size)
    apply_font_size(base_size)

    if PlayerName and PlayerName.SetFont then
        PlayerName:SetFont(font_path, base_size + 4, "OUTLINE")
    end
    if TargetName and TargetName.SetFont then
        TargetName:SetFont(font_path, base_size + 4, "OUTLINE")
    end
end

-- ================== Feature 3: Auto Dismount / Auto Stance ==================
-- Buff icons used by druid / shaman shapeshift forms
local shapeshift_icons = {
    "ability_racial_bearform", "ability_druid_catform", "ability_druid_travelform",
    "spell_nature_forceofnature", "ability_druid_aquaticform", "spell_nature_spiritwolf",
}

-- Buff icon fragments shared by mount buffs on this client (Turtle WoW)
local mount_icons = {
    "_mount_",                  -- regular mounts (Ability_Mount_*)
    "spell_nature_swiftness",   -- skeletal warhorse / mechanostrider / kodo / dreadsteed / raptor
    "_qirajicrystal_",          -- Qiraji crystal mounts
    "hunter_pet_turtle",        -- turtle mount (Turtle WoW)
    "boar",                     -- wild boar
    "warstomp",                 -- zebra
    "bullrush",                 -- ghost griffon
    "_branch_",                 -- reindeer
    "zuoqi",                    -- generic Turtle WoW mount icon
    "inv_pet_speedy",
    "inv_misc_head_dragon_black",
    "spell_nature_wispsplode",
    "inv_misc_branch_01",
    "inv_valentinesboxofchocolates02",  -- pink horse
    "inv_valentinescard01",             -- pink tiger
    "ability_hunter_pet_dragonhawk",    -- dragonhawk
    "ability_hunter_pet_tallstrider",
    "inv_misc_horn_01",
    "hunter_pet_bear",                  -- bear
    "hunter_pet_hippogryph",            -- hippogryph
    "hunter_pet_stag1",                 -- stag
    "hunter_pet_tallstrider",           -- lovebird
    "inv_misc_key_06",                  -- engineering mounts
    "inv_misc_key_12",
    "spell_nature_sentinal",            -- raven
    "spell_magic_polymorphchicken",     -- magic rooster
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
-- One-shot default-initializer frame (PLAYER_LOGIN), created in module.enable
local automation_init = nil

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
                apply_all_font_sizes(value)
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
            SlashCmdList["OZAIO_RL"] = function()
                ReloadUI()
            end
        end

        -- Apply font settings (game fonts + player/target name plates)
        local baseSize = 14
        if OZAIO_CONFIG and OZAIO_CONFIG["general.font_size"] then
            baseSize = OZAIO_CONFIG["general.font_size"]
        end
        apply_all_font_sizes(baseSize)

        -- Auto Dismount / Auto Stance listener (feature 3)
        if not automation_frame then
            automation_frame = CreateFrame("Frame")
            automation_frame:RegisterEvent("UI_ERROR_MESSAGE")
            automation_frame:SetScript("OnEvent", function()
                local dismountOn = OZAIO_CONFIG and OZAIO_CONFIG["general.auto_dismount"]
                if dismountOn then
                    handle_dismount(arg1)
                end
                local stanceOn = OZAIO_CONFIG and OZAIO_CONFIG["general.auto_stance"]
                if stanceOn then
                    if string.find(arg1, stance_scan) then
                        handle_stance(arg1)
                    end
                end
            end)
        end

        -- pfUI / ShaguTweaks conflict detection
        if not automation_init then
            automation_init = CreateFrame("Frame")
            automation_init:RegisterEvent("PLAYER_LOGIN")
            automation_init:SetScript("OnEvent", function()
                automation_init:UnregisterAllEvents()
                local is_conflict = type(pfUI) == "table"
                    or type(ShaguTweaks) == "table"
                    or IsAddOnLoaded("pfUI")
                    or IsAddOnLoaded("ShaguTweaks")
                if is_conflict then
                    if automation_frame then
                        automation_frame:UnregisterAllEvents()
                        automation_frame:SetScript("OnEvent", nil)
                    end
                    OzLib.print(L["Auto Dismount and Auto Stance disabled: pfUI/ShaguTweaks detected"], "error")
                end
            end)
        end
    end,
    disable = function(self)
        if automation_frame then
            automation_frame:UnregisterAllEvents()
            automation_frame:SetScript("OnEvent", nil)
            automation_frame = nil
        end
        if automation_init then
            automation_init:UnregisterAllEvents()
            automation_init:SetScript("OnEvent", nil)
            automation_init = nil
        end
    end,
})

module.on_config_change = function(self, key, value)
    if key == "general.font_size" then
        apply_all_font_sizes(value)
    end
end
