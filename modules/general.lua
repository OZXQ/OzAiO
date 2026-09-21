-- Feature 1: add /rl shortcut for /reloadui
-- Feature 2: customize font size, but keep it simple — user only defines GameFontNormal size
--           Small = Normal - 2, Large = Normal + 2
-- Feature 3: Auto Dismount / Auto Stance (ported from ShaguTweaks)

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        if (LOCALE ~= "enUS") and (LOCALE ~= "enGB") then
            OzLib.print("Locale fetch failed for general" .. v, "error")
        end
        return v
    end
})
if LOCALE == "zhCN" then
    L["General"] = "通用"
    L["Use /rl to reload the interface."] = "输入/rl以重新加载插件及界面"
    L["Font Size"] = "字体大小"
    L["Small = Normal - 2, Large = Normal + 2"] = "小字体 = 基础 - 2，大字体 = 基础 + 2"
    L["Please enter a number between 8 and 20"] = "请输入8-20之间的数字"
    L["Auto Dismount"] = "自动下坐骑"
    L["Automatically dismounts whenever a spell is casted."] = "当施放任何法术时自动取消坐骑。"
    L["Auto Stance"] = "自动切姿态"
    L["Automatically switch to the required warrior or druid stance on spell cast."] = "自动切换技能所需姿态(战士/德鲁伊)。"
    L["Auto Dismount and Auto Stance disabled: pfUI/ShaguTweaks detected"] = "检测到 pfUI/ShaguTweaks，已默认关闭自动下坐骑和自动切姿态"
end
-- Default font path (can be changed as needed)
local fontPath = "Fonts\\FRIZQT__.TTF"

if LOCALE == "zhCN" then
    fontPath = "Fonts\\ARIALN.TTF"
end

local module = OzFramework:register("oz_general", {
    title = L["General"],
    order = 0,
    enabled = true,
    config = {
        ["general.fontsize"] = 14,  -- default base font size
        ["general.dismount"] = true,
        ["general.stance"] = true,
    }
})

-- Helper: safely set font on a font object
local function SetFontSafe(fontObject, fontPath, fontSize, fontFlag)
    if fontObject and fontObject.SetFont then
        fontObject:SetFont(fontPath, fontSize, fontFlag)
    end
end

-- Apply font size across all game font objects
local function ApplyFontSize(baseSize)
    -- Clamp to valid range
    if not baseSize or type(baseSize) ~= "number" or baseSize < 8 or baseSize > 20 then
        baseSize = 14
    end
    
    local small_size = baseSize - 2
    local large_size = baseSize + 2
    local huge_size = large_size + 4

    -- 1. Core GameFont series
    -- Normal (base size)
    SetFontSafe(SystemFont, fontPath, baseSize)
    SetFontSafe(GameFontNormal, fontPath, baseSize)
    SetFontSafe(GameFontHighlight, fontPath, baseSize)
    SetFontSafe(GameFontDisable, fontPath, baseSize)
    SetFontSafe(GameFontGreen, fontPath, baseSize)
    SetFontSafe(GameFontRed, fontPath, baseSize)
    SetFontSafe(GameFontBlack, fontPath, baseSize)
    SetFontSafe(GameFontWhite, fontPath, baseSize)
    SetFontSafe(DialogButtonNormalText, fontPath, baseSize)
    SetFontSafe(DialogButtonHighlightText, fontPath, baseSize)

    
    -- Small (Normal - 2)
    SetFontSafe(GameFontNormalSmall, fontPath, small_size)
    SetFontSafe(GameFontHighlightSmall, fontPath, small_size)
    SetFontSafe(GameFontHighlightSmallOutline, fontPath, small_size, "OUTLINE")
    SetFontSafe(GameFontDisableSmall, fontPath, small_size)
    SetFontSafe(GameFontGreenSmall, fontPath, small_size)
    SetFontSafe(GameFontRedSmall, fontPath, small_size)
    SetFontSafe(GameFontDarkGraySmall, fontPath, small_size)
    
    -- Large (Normal + 2)
    SetFontSafe(GameFontNormalLarge, fontPath, large_size)
    SetFontSafe(GameFontHighlightLarge, fontPath, large_size)
    SetFontSafe(GameFontDisableLarge, fontPath, large_size)
    SetFontSafe(GameFontGreenLarge, fontPath, large_size)
    SetFontSafe(GameFontRedLarge, fontPath, large_size)
    
    -- 2. Other common fonts, mapped to corresponding sizes
    SetFontSafe(NumberFontNormal, fontPath, baseSize, "OUTLINE")
    SetFontSafe(NumberFontNormalSmall, fontPath, small_size, "OUTLINE")
    SetFontSafe(NumberFontNormalLarge, fontPath, large_size, "OUTLINE")
    SetFontSafe(ChatFontNormal, fontPath, baseSize)
    SetFontSafe(QuestFontNormalSmall, fontPath, small_size)
    SetFontSafe(QuestTitleFont, fontPath, huge_size)
    SetFontSafe(TextStatusBarText, fontPath, small_size)
    SetFontSafe(GameTooltipText, fontPath, small_size)
    SetFontSafe(GameTooltipHeaderText, fontPath, baseSize, "THICK")
    SetFontSafe(GameFontNormalHuge, fontPath, huge_size)

end

-- Apply font size to game fonts plus the player/target name plates
local function ApplyAllFontSizes(baseSize)
    ApplyFontSize(baseSize)

    if PlayerName and PlayerName.SetFont then
        PlayerName:SetFont(fontPath, baseSize + 4, "OUTLINE")
    end
    if TargetName and TargetName.SetFont then
        TargetName:SetFont(fontPath, baseSize + 4, "OUTLINE")
    end
end

-- ================== Feature 3: Auto Dismount / Auto Stance ==================
-- Ported from ShaguTweaks (mods/auto-dismount.lua, mods/auto-stance.lua):
--   - Auto Dismount: stands up / cancels mount or shapeshift when a cast fails
--   - Auto Stance: casts the stance required by a failed spell (warrior/druid)
-- Mounts are detected purely by their buff icon texture (the same fragments
-- used by SpecialEvents-Mount-2.0 / Automaton on this client). No GameTooltip
-- scan is involved: tooltip reads (SetPlayerBuff) show/hide the tooltip frame
-- on every failed cast, which flickers the mouse cursor.

-- Buff icons used by druid / shaman shapeshift forms
local shapeshift_icons = {
    "ability_racial_bearform", "ability_druid_catform", "ability_druid_travelform",
    "spell_nature_forceofnature", "ability_druid_aquaticform", "spell_nature_spiritwolf",
}

-- Buff icon fragments shared by mount buffs on this client (Turtle WoW):
-- regular mounts all use the Ability_Mount_ prefix; the remaining entries are
-- Turtle's special mounts (turtle, boar, zebra, ghost griffon, reindeer,
-- engineering, seasonal) whose icons do not contain "mount". Extend this list
-- when the server adds mounts with new icon families.
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

local function handle_dismount(error)
    -- Stand up when a cast failed because the player was sitting
    if error == SPELL_FAILED_NOT_STANDING then
        SitOrStand()
        return
    end

    local blocked = false
    for _, err in ipairs(mount_errors) do
        if error == err then
            blocked = true
            break
        end
    end
    if not blocked then return end

    for i = 0, 31 do
        -- Mounts and shapeshifts are identified by their buff icon texture
        -- only; no tooltip read is involved, so the mouse cursor is never
        -- touched while scanning.
        local texture = GetPlayerBuffTexture(i)
        if texture then
            local lower = string.lower(texture)
            for _, icon in ipairs(mount_icons) do
                if string.find(lower, icon) then
                    CancelPlayerBuff(i)
                    return
                end
            end
            for _, icon in ipairs(shapeshift_icons) do
                if string.find(lower, icon) then
                    CancelPlayerBuff(i)
                    return
                end
            end
        end
    end
end

-- "Can't do that while %s" -> "Can't do that while (.+)" (client-localized)
local function strsplit(delimiter, subject)
    if not subject then return nil end
    local delimiter, fields = delimiter or ":", {}
    local pattern = string.format("([^%s]+)", delimiter)
    string.gsub(subject, pattern, function(c)
        fields[table.getn(fields) + 1] = c
    end)
    return unpack(fields)
end

local stance_scan = string.gsub(SPELL_FAILED_ONLY_SHAPESHIFT, "%%s", "(.+)")

local function handle_stance(error)
    for stances in string.gfind(error, stance_scan) do
        local list = { strsplit(",", stances) }
        for i = 1, table.getn(list) do
            CastSpellByName(string.gsub(list[i], "^%s*(.-)%s*$", "%1"))
        end
    end
end

-- Listener frame, created in module.enable
local automation_frame = nil
-- One-shot default-initializer frame (PLAYER_LOGIN), created in module.enable
local automation_init = nil

module.enable = function(self)
    -- Register /rl command
    if not SlashCmdList["OZAIO_RL"] then
        SLASH_OZAIO_RL1="/rl"
        SlashCmdList["OZAIO_RL"]=function()
            ReloadUI()
        end
    end
    
    -- Apply font settings (game fonts + player/target name plates)
    ApplyAllFontSizes(OZAIO_CONFIG["general.fontsize"] or 14)

    -- Auto Dismount / Auto Stance listener (feature 3)
    if not automation_frame then
        automation_frame = CreateFrame("Frame")
        automation_frame:RegisterEvent("UI_ERROR_MESSAGE")
        automation_frame:SetScript("OnEvent", function()
            if OZAIO_CONFIG["general.dismount"] then
                handle_dismount(arg1)
            end
            if OZAIO_CONFIG["general.stance"] then
                -- Cheap pre-filter: only run the pattern/cast machinery for
                -- errors that can actually describe a stance restriction.
                if string.find(arg1, stance_scan) then
                    handle_stance(arg1)
                end
            end
        end)
    end

    -- pfUI / ShaguTweaks ship the same Auto Dismount / Auto Stance features,
    -- so the listener is hard-disabled when either addon is loaded. Detection
    -- happens at PLAYER_LOGIN because other addons load after OzAiO and their
    -- globals do not exist yet when OzAiO's ADDON_LOADED fires.
    if not automation_init then
        automation_init = CreateFrame("Frame")
        automation_init:RegisterEvent("PLAYER_LOGIN")
        automation_init:SetScript("OnEvent", function()
            automation_init:UnregisterAllEvents()
            local conflict = type(pfUI) == "table"
                or type(ShaguTweaks) == "table"
                or IsAddOnLoaded("pfUI")
                or IsAddOnLoaded("ShaguTweaks")
            if conflict then
                automation_frame:UnregisterAllEvents()
                automation_frame:SetScript("OnEvent", nil)
                OzLib.print(L["Auto Dismount and Auto Stance disabled: pfUI/ShaguTweaks detected"], "error")
            end
        end)
    end
end

module.disable = function(self)
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
end

-- Re-apply font when config changes
module.on_config_change = function(self, key, value)
    if key == "general.fontsize" then
        ApplyAllFontSizes(value)
    end
end

module.create_config_panel = function(self, parent)
    local panel = CreateFrame("Frame", "OZGeneralConfig", parent)
    panel:SetAllPoints()
    
    -- Create Flow layout
    local flow = OzUIHelper:createFlow(panel, 8)
    OzUIHelper:attachResize(panel, flow)
    
    -- Title
    local title = OzUIHelper:makeLabel(panel, L["General"], "GameFontNormalLarge")
    title:SetWidth(flow.maxWidth - flow.padding)
    title:SetJustifyH("CENTER")
    OzUIHelper:add(flow, title, flow.maxWidth - flow.padding, 20)
    OzUIHelper:newLine(flow)
    
    -- /rl hint
    local rl_statement = OzUIHelper:makeLabel(panel, L["Use /rl to reload the interface."], "GameFontNormalSmall")
    rl_statement:SetTextColor(0.5, 0.5, 0.5)
    OzUIHelper:add(flow, rl_statement)
    OzUIHelper:newLine(flow)
    
    -- Label: "Font Size: <currentValue>"
    local font_resizer = OzUIHelper:makeLabeledEditBox(panel, L["Font Size"] .. ":", 40)
    local currentValue = OZAIO_CONFIG["general.fontsize"]
    font_resizer:SetValue(currentValue)
    font_resizer:SetCallback(function(value)
        value = tonumber(value)
        if value and value >= 8 and value <= 20 then
            OZAIO_CONFIG["general.fontsize"] = value
            ApplyAllFontSizes(value)
        else
            OzLib.print(L["Please enter a number between 8 and 20"], "error")
            font_resizer:SetValue(OZAIO_CONFIG["general.fontsize"])
        end
    end)    
    OzUIHelper:add(flow, font_resizer)
    OzUIHelper:newLine(flow)

    -- Auto Dismount / Auto Stance toggles (feature 3)
    local dismountCb = OzUIHelper:makeCheckbox(panel, L["Auto Dismount"], OZAIO_CONFIG["general.dismount"], function(checked)
        OZAIO_CONFIG["general.dismount"] = checked
    end)
    OzUIHelper:add(flow, dismountCb)
    OzUIHelper:newLine(flow)

    local dismountHint = OzUIHelper:makeLabel(panel, L["Automatically dismounts whenever a spell is casted."], "GameFontNormalSmall")
    dismountHint:SetTextColor(0.5, 0.5, 0.5)
    OzUIHelper:add(flow, dismountHint)
    OzUIHelper:newLine(flow)

    local stanceCb = OzUIHelper:makeCheckbox(panel, L["Auto Stance"], OZAIO_CONFIG["general.stance"], function(checked)
        OZAIO_CONFIG["general.stance"] = checked
    end)
    OzUIHelper:add(flow, stanceCb)
    OzUIHelper:newLine(flow)

    local stanceHint = OzUIHelper:makeLabel(panel, L["Automatically switch to the required warrior or druid stance on spell cast."], "GameFontNormalSmall")
    stanceHint:SetTextColor(0.5, 0.5, 0.5)
    OzUIHelper:add(flow, stanceHint)
    
    return { frame = panel, height = math.abs(flow.y) + flow.padding }
end
