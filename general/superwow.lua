if not SUPERWOW_VERSION then
    OzLib.print("superwow isn't installed, please check dll","error")
    return
end

local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if LOCALE == "zhCN" then
    L["SuperWoW"] = "SuperWoW"
    L["%d/511 Characters Used"] = "已使用 %d/511 个字符"
    L["Shows whisper, party, raid, and battleground chat text in speech bubbles above characters' heads."] = "显示密语、小队、团队和战场聊天文本在角色头顶的气泡中。"
    L["Show Whisper and Group Chat Bubbles"] = "显示密语和团队聊天气泡"
    L["Shift to toggle on"] = "按Shift键开启"
    L["Autoloot (Read tooltip)"] = "自动拾取"
    L["Clickthrough corpses"] = "点击穿透尸体"
    L["Field of view (Requires reload)"] = "视野范围（需要重载）"
    L["Selection circle style"] = "选择目标脚下光圈样式"
    L["Default - incomplete circle"] = "默认 - 不完整圆环"
    L["Full circle"] = "完整圆环"
    L["Full circle with arrow"] = "带方向箭头的完整圆环"
    L["Classic oriented circle"] = "经典朝向圆环"
    L["Background sound"] = "背景声音"
    L["Uncapped sounds"] = "无限制声音"
    L["Loot Sparkle"] = "战利品闪光效果"
    L["Automatically loots items when opening a loot window."] = "打开战利品窗口时自动拾取所有物品。"
    L["Only autoloots when holding down the Shift key."] = "仅在按住Shift键时才自动拾取。"
    L["Allows targeting and interacting through dead corpses."] = "允许鼠标点击穿透已死亡的尸体进行选项目标或移动。"
    L["Enables game audio playback when WoW is running in the background."] = "当游戏在后台运行时继续播放游戏声音。"
    L["Enables sparkling visual effect on lootable corpses and objects."] = "在可拾取的尸体或物体上显示发光粒子特效。"
    L["Uncaps sound hardware/software channels to 64 for rich audio fidelity."] = "解除声道上限限制，提升至64通道以获得更丰富的声音细节。"
    L["Camera field of view multiplier (1.0 to 2.5). Requires /rl to take effect."] = "镜头视野倍率(1.0 - 2.5)。需要输入 /rl 重载界面生效。"
    L["Style of the selection indicator circle underneath your target."] = "当前选定目标脚下的光圈样式。"
end

-- Setting mutators
local autoloot_frame = nil

local function get_sw_config(key, default)
    if not OZAIO_CONFIG then return default end
    if OZAIO_CONFIG[key] ~= nil then return OZAIO_CONFIG[key] end
    return default
end

local function apply_autoloot()
    if autoloot_frame then
        autoloot_frame:SetScript("OnUpdate", nil)
        autoloot_frame = nil
    end

    local shiftLoot = get_sw_config("superwow.shift_loot", false)
    local autoLoot = get_sw_config("superwow.auto_loot", true)

    if shiftLoot then
        autoloot_frame = CreateFrame("Frame")
        autoloot_frame:SetScript("OnUpdate", function()
            if IsShiftKeyDown() then
                SetAutoloot(1)
            else
                SetAutoloot(0)
            end
        end)
    elseif autoLoot then
        SetAutoloot(1)
    else
        SetAutoloot(0)
    end
end

local function set_autoloot(enabled)
    OZAIO_CONFIG["superwow.auto_loot"] = enabled
    if enabled then
        OZAIO_CONFIG["superwow.shift_loot"] = false
    end
    apply_autoloot()
end

local function set_shift_loot(enabled)
    OZAIO_CONFIG["superwow.shift_loot"] = enabled
    if enabled then
        OZAIO_CONFIG["superwow.auto_loot"] = false
    end
    apply_autoloot()
end

local function set_fov(value)
    if value then
        pcall(SetCVar, "FoV", value)
        OZAIO_CONFIG["superwow.fov"] = value
    end
end

local function set_bg_sound(enabled)
    if enabled then
        pcall(SetCVar, "BackgroundSound", "1")
    else
        pcall(SetCVar, "BackgroundSound", "0")
    end
    OZAIO_CONFIG["superwow.background_sound"] = enabled
end

local function set_selection_circle_style(value)
    if value then
        pcall(SetCVar, "SelectionCircleStyle", tostring(value))
    end
    OZAIO_CONFIG["superwow.selection_circle_style"] = value
end

local function set_loot_sparkle(enabled)
    if enabled then
        pcall(SetCVar, "LootSparkle", "1")
    else
        pcall(SetCVar, "LootSparkle", "0")
    end
    OZAIO_CONFIG["superwow.loot_sparkle"] = enabled
end

local function set_uncapped_sound(enabled)
    if enabled then
        pcall(SetCVar, "UncapSounds", "1")
        pcall(SetCVar, "SoundSoftwareChannels", "64")
        pcall(SetCVar, "SoundMaxHardwareChannels", "64")
    else
        pcall(SetCVar, "UncapSounds", "0")
        pcall(SetCVar, "SoundSoftwareChannels", "12")
        pcall(SetCVar, "SoundMaxHardwareChannels", "12")
    end
    OZAIO_CONFIG["superwow.uncapped_sounds"] = enabled
end

local function set_clickthrough(enabled)
    if enabled then
        Clickthrough(1)
    else
        Clickthrough(0)
    end
    OZAIO_CONFIG["superwow.click_through"] = enabled
end

-- ================== SuperAPI-style hooks ==================
-- Ported from SuperAPI for SuperWoW 1.2: spell links, spell shift-click,
-- item counts, unitframe mouseover, combat-text names and quest links.
-- Originals are captured at load (FrameXML runs first); hooks are applied in
-- module.enable and restored in module.disable so a /reload re-applies them.

local orig_set_item_ref        = SetItemRef
local orig_spellbutton_click   = SpellButton_OnClick
local orig_set_item_count      = SetItemButtonCount
local orig_unitframe_enter     = UnitFrame_OnEnter
local orig_unitframe_leave     = UnitFrame_OnLeave
local orig_combat_text         = CombatText_AddMessage
local orig_questlog_click      = QuestLogTitleButton_OnClick

-- Build a chat link for a spell ID; "enchant:" is used because the Vanilla
-- client cannot natively render "spell:" links (SetItemRef rewrites them).
local function get_spell_link(id)
    local spellname = SpellInfo(id)
    return "\124cffffffff\124Henchant:" .. id .. "\124h[" .. spellname .. "]\124h\124r"
end

local function install_api_hooks()
    -- Spell shift-click: insert the spell link into the open chat box
    SpellButton_OnClick = function(drag)
        if (not drag) and IsShiftKeyDown()
            and ChatFrameEditBox and ChatFrameEditBox:IsVisible()
            and (not MacroFrame or not MacroFrame:IsVisible()) then
            if SpellBook_GetSpellID then
                local bookId = SpellBook_GetSpellID(this:GetID())
                local _, _, spellID = GetSpellName(bookId, SpellBookFrame.bookType)
                if spellID then
                    ChatFrameEditBox:Insert(get_spell_link(spellID))
                    return
                end
            end
        end
        orig_spellbutton_click(drag)
    end

    -- Spell links render as "enchant:" so tooltips show on click
    SetItemRef = function(link, text, button)
        link = string.gsub(link, "spell:", "enchant:")
        orig_set_item_ref(link, text, button)
    end

    -- Item buttons: keep base counts, but render SuperWoW's special negative
    -- counts yellow with "*" beyond -999
    SetItemButtonCount = function(button, count)
        if not button or not count then
            return orig_set_item_count(button, count)
        end
        if count < 0 then
            local countText = button:GetName() and getglobal(button:GetName() .. "Count")
            if countText then
                if count < -999 then
                    countText:SetText("*")
                else
                    countText:SetText(-count)
                end
                countText:Show()
                countText:SetFontObject(NumberFontNormalYellow)
            end
            return
        end
        orig_set_item_count(button, count)
    end

    -- Unit frames: expose the hovered unit via SuperWoW SetMouseoverUnit
    UnitFrame_OnEnter = function()
        if orig_unitframe_enter then orig_unitframe_enter() end
        SetMouseoverUnit(this.unit)
    end
    UnitFrame_OnLeave = function()
        if orig_unitframe_leave then orig_unitframe_leave() end
        SetMouseoverUnit()
    end

    -- Scrolling combat text: replace internal unit GUIDs with names
    CombatText_AddMessage = function(message, scrollFunction, r, g, b, displayType, isStaggered)
        local newMessage = string.gsub(
            message,
            "(%s%[)(0x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)(%])",
            function(bracket1, hex, bracket2)
                if UnitIsUnit(hex, "player") then return nil end
                return " [" .. UnitName(hex) .. "]"
            end)
        return orig_combat_text(newMessage, scrollFunction, r, g, b, displayType, isStaggered)
    end

    -- Quest log: shift-click a quest to insert its chat link. Vanilla cannot
    -- resolve quest-log IDs; SuperWoW's QuestInfo_GetQuestID makes it work.
    if orig_questlog_click and QuestInfo_GetQuestID then
        QuestLogTitleButton_OnClick = function()
            local id = this:GetID()
            if id > 0 and IsShiftKeyDown()
                and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                QuestLog_SetSelection(id)
                local questID = QuestInfo_GetQuestID()
                local title, level = GetQuestLogTitle(id)
                if questID and title then
                    ChatFrameEditBox:Insert(
                        "|cff808080|Hquest:" .. questID .. ":" .. (level or 1) .. "|h[" .. title .. "]|h|r")
                    return
                end
            end
            orig_questlog_click()
        end
    end
end

local function uninstall_api_hooks()
    SpellButton_OnClick = orig_spellbutton_click
    SetItemRef = orig_set_item_ref
    SetItemButtonCount = orig_set_item_count
    UnitFrame_OnEnter = orig_unitframe_enter
    UnitFrame_OnLeave = orig_unitframe_leave
    CombatText_AddMessage = orig_combat_text
    QuestLogTitleButton_OnClick = orig_questlog_click
end

-- ================== Module Registration ==================

local module = OzFramework:registerMod({
    name = "oz_superwow",
    title = L["SuperWoW"],
    category = "General",
    order = 4,
    enabled = true,
    config = {
        ["superwow.auto_loot"] = true,
        ["superwow.click_through"] = false,
        ["superwow.shift_loot"] = false,
        ["superwow.fov"] = 1.5,
        ["superwow.background_sound"] = true,
        ["superwow.selection_circle_style"] = 1,
        ["superwow.loot_sparkle"] = true,
        ["superwow.uncapped_sounds"] = true,
    },
    config_ui_creator = {
        {
            type = "checkbox",
            label = L["Autoloot (Read tooltip)"],
            tooltip = L["Automatically loots items when opening a loot window."],
            config_key = "superwow.auto_loot",
            onChange = function(checked)
                set_autoloot(checked)
            end,
        },
        {
            type = "checkbox",
            label = L["Shift to toggle on"],
            tooltip = L["Only autoloots when holding down the Shift key."],
            config_key = "superwow.shift_loot",
            onChange = function(checked)
                set_shift_loot(checked)
            end,
        },
        {
            type = "checkbox",
            label = L["Clickthrough corpses"],
            tooltip = L["Allows targeting and interacting through dead corpses."],
            config_key = "superwow.click_through",
            onChange = function(checked)
                set_clickthrough(checked)
            end,
        },
        {
            type = "checkbox",
            label = L["Background sound"],
            tooltip = L["Enables game audio playback when WoW is running in the background."],
            config_key = "superwow.background_sound",
            onChange = function(checked)
                set_bg_sound(checked)
            end,
        },
        {
            type = "checkbox",
            label = L["Loot Sparkle"],
            tooltip = L["Enables sparkling visual effect on lootable corpses and objects."],
            config_key = "superwow.loot_sparkle",
            onChange = function(checked)
                set_loot_sparkle(checked)
            end,
        },
        {
            type = "checkbox",
            label = L["Uncapped sounds"],
            tooltip = L["Uncaps sound hardware/software channels to 64 for rich audio fidelity."],
            config_key = "superwow.uncapped_sounds",
            onChange = function(checked)
                set_uncapped_sound(checked)
            end,
        },
        { type = "space", height = 6 },
        {
            type = "slider",
            label = L["Field of view (Requires reload)"],
            tooltip = L["Camera field of view multiplier (1.0 to 2.5). Requires /rl to take effect."],
            min = 1.0,
            max = 2.5,
            step = 0.1,
            config_key = "superwow.fov",
            onChange = function(val)
                set_fov(val)
            end,
        },
        { type = "space", height = 6 },
        {
            type = "dropdown",
            label = L["Selection circle style"],
            tooltip = L["Style of the selection indicator circle underneath your target."],
            options = {
                { label = L["Default - incomplete circle"], value = 1 },
                { label = L["Full circle"], value = 2 },
                { label = L["Full circle with arrow"], value = 3 },
                { label = L["Classic oriented circle"], value = 4 },
            },
            config_key = "superwow.selection_circle_style",
            onChange = function(val)
                set_selection_circle_style(val)
            end,
        },
    },
    enable = function(self)
        -- Extend macro frame to 511 characters
        if MacroFrame_LoadUI then
            MacroFrame_LoadUI()
        end
        if MacroFrameText then
            MacroFrameText:SetMaxLetters(511)
        end
        MACROFRAME_CHAR_LIMIT = L["%d/511 Characters Used"]

        -- Override chat-bubble option strings for localization
        OPTION_TOOLTIP_PARTY_CHAT_BUBBLES = L["Shows whisper, party, raid, and battleground chat text in speech bubbles above characters' heads."]
        PARTY_CHAT_BUBBLES_TEXT = L["Show Whisper and Group Chat Bubbles"]

        -- Apply initial CVar / autoloot state from saved values
        set_clickthrough(get_sw_config("superwow.click_through", false))
        set_loot_sparkle(get_sw_config("superwow.loot_sparkle", true))
        set_selection_circle_style(get_sw_config("superwow.selection_circle_style", 1))
        set_bg_sound(get_sw_config("superwow.background_sound", true))
        set_uncapped_sound(get_sw_config("superwow.uncapped_sounds", true))
        apply_autoloot()

        -- SuperAPI-style global hooks (spell links, item counts, unitframe
        -- mouseover, combat text names, quest links)
        install_api_hooks()
    end,
    disable = function(self)
        uninstall_api_hooks()
    end,
})
