local sw_version = tonumber(SUPERWOW_VERSION) or 0
if sw_version == 0 then
    if OzLib and OzLib.print then
        OzLib.print("superwow isn't installed, please check dll", "error")
    end
    return
end

local is_v22 = (sw_version >= 2.2)

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
    L["Floating Healing Text"] = "浮动治疗数字"
    L["Toggle display of in-world healing feedback (requires combat text enabled)."] = "在游戏世界中显示对目标进行治疗的浮动绿色数字反馈（需要先在游戏界面设置中开启浮动战斗信息）。"
    L["Floating Healing Text requires Combat Text enabled in Interface Options."] = "浮动治疗数字需要先在游戏界面设置中开启浮动战斗信息，否则可能导致客户端崩溃。"
    L["Nameplate Motion"] = "姓名板排列模式"
    L["Changes the behavior of moving nameplates."] = "更改目标姓名板在屏幕上的堆叠与分散排列方式。"
    L["Default spread"] = "默认堆叠分散"
    L["Smart spread"] = "智能分散"
    L["Compact spread"] = "紧凑堆叠"
    L["Overlap"] = "重叠"
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

local function set_healing_text(enabled)
    if not is_v22 then return end
    if enabled then
        -- CombatDamage must be enabled in WoW client or HealingText triggers Error #132 in CCombatText renderer
        local combatDamage = GetCVar and GetCVar("CombatDamage")
        if combatDamage == "0" then
            if OzLib and OzLib.print then
                OzLib.print(L["Floating Healing Text requires Combat Text enabled in Interface Options."], "warning")
            end
            pcall(SetCVar, "HealingText", "0")
            OZAIO_CONFIG["superwow.healing_text"] = false
            return
        end
        pcall(SetCVar, "HealingText", "1")
    else
        pcall(SetCVar, "HealingText", "0")
    end
    OZAIO_CONFIG["superwow.healing_text"] = enabled
end

local function set_nameplate_motion(value)
    if not is_v22 then return end
    value = tonumber(value) or 1
    pcall(SetCVar, "NameplateMotion", tostring(value))
    OZAIO_CONFIG["superwow.nameplate_motion"] = value
end

-- ================== SuperAPI-style hooks ==================
-- Ported from SuperAPI for SuperWoW 1.2: spell links, spell shift-click,
-- item counts, and quest links.
-- Originals are captured at load (FrameXML runs first); hooks are applied in
-- module.enable and restored in module.disable so a /reload re-applies them.

local orig_spellbutton_click   = SpellButton_OnClick
local orig_set_item_count      = SetItemButtonCount
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
    local function pre_spell_link_ref(link, text, button)
        if link and string.find(link, "spell:") then
            return string.gsub(link, "spell:", "enchant:"), text, button
        end
    end
    OzHook:hook("SetItemRef", pre_spell_link_ref)

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

    -- Quest log: shift-click a quest to insert its chat link using SuperWoW
    if orig_questlog_click then
        QuestLogTitleButton_OnClick = function(button)
            local offset = (FauxScrollFrame_GetOffset and QuestLogListScrollFrame) and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
            local questIndex = this:GetID() + offset
            if IsShiftKeyDown() and not this.isHeader
                and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                local questLink = nil
                -- SuperWoW 2.2+ native quest link API
                if is_v22 and GetQuestLinkForLogIndex then
                    questLink = GetQuestLinkForLogIndex(questIndex)
                end
                -- Fallback for SuperWoW 1.5
                if not questLink and QuestInfo_GetQuestID then
                    QuestLog_SetSelection(questIndex)
                    local questID = QuestInfo_GetQuestID()
                    local title, level = GetQuestLogTitle(questIndex)
                    if questID and title then
                        questLink = "|cff808080|Hquest:" .. questID .. ":" .. (level or 1) .. "|h[" .. title .. "]|h|r"
                    end
                end
                if questLink then
                    ChatFrameEditBox:Insert(questLink)
                    return
                end
            end
            orig_questlog_click(button)
        end
    end
end

local function uninstall_api_hooks()
    OzHook:unhook("SetItemRef", pre_spell_link_ref)
    SpellButton_OnClick = orig_spellbutton_click
    SetItemButtonCount = orig_set_item_count
    QuestLogTitleButton_OnClick = orig_questlog_click
end

-- ================== Module Registration ==================

local function build_superwow_config_ui()
    local items = {
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
    }

    if is_v22 then
        table.insert(items, {
            type = "checkbox",
            label = L["Floating Healing Text"],
            tooltip = L["Toggle display of in-world healing feedback (requires combat text enabled)."],
            config_key = "superwow.healing_text",
            onChange = function(checked)
                set_healing_text(checked)
            end,
        })
    end

    table.insert(items, { type = "space", height = 6 })
    table.insert(items, {
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
    })
    table.insert(items, { type = "space", height = 6 })
    table.insert(items, {
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
    })

    if is_v22 then
        table.insert(items, { type = "space", height = 6 })
        table.insert(items, {
            type = "dropdown",
            label = L["Nameplate Motion"],
            tooltip = L["Changes the behavior of moving nameplates."],
            options = {
                { label = L["Default spread"], value = 1 },
                { label = L["Smart spread"], value = 2 },
                { label = L["Compact spread"], value = 3 },
                { label = L["Overlap"], value = 0 },
            },
            config_key = "superwow.nameplate_motion",
            onChange = function(val)
                set_nameplate_motion(val)
            end,
        })
    end

    return items
end

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
        ["superwow.healing_text"] = false,
        ["superwow.nameplate_motion"] = 1,
    },
    config_ui_creator = build_superwow_config_ui,
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
        if is_v22 then
            set_healing_text(get_sw_config("superwow.healing_text", false))
            set_nameplate_motion(get_sw_config("superwow.nameplate_motion", 1))
        end
        apply_autoloot()

        -- SuperAPI-style global hooks (spell links, item counts, quest links)
        install_api_hooks()
    end,
    disable = function(self)
        uninstall_api_hooks()
    end,
})
