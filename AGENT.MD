# Agent Guidelines: WoW 1.12.1 & Lua 5.0 Addon Development

This document defines the strict engineering standards, language constraints, and architecture conventions for AI agents and developers working on the **OzAiO** codebase and World of Warcraft 1.12.1 (Vanilla / Turtle WoW / SuperWoW) addons.

---

## 1. Runtime Environment & Lua 5.0 Dialect

World of Warcraft 1.12.1 (client build 5875) executes a customized **Lua 5.0.2** runtime. Many features standard in Lua 5.1, 5.2, 5.3, and LuaJIT **do NOT exist** or will cause critical runtime syntax errors that halt addon execution.

### Strict Syntax Rules & Forbidden Features

| Feature | Status in WoW 1.12 | Correct Alternative |
| :--- | :--- | :--- |
| **Length Operator (`#t`)** | ❌ **SYNTAX ERROR** | Use `table.getn(t)` for tables, `string.len(s)` for strings. |
| **Integer Division (`//`)** | ❌ **SYNTAX ERROR** | Use `math.floor(a / b)`. |
| **Bitwise Operators (`&`, `\|`, `~`)** | ❌ **SYNTAX ERROR** | Use arithmetic emulation or SuperWoW bitlib if available. |
| **`string.gmatch`** | ❌ **DOES NOT EXIST** | Use `string.gfind(s, pattern)`. |
| **`string.match`** | ❌ **DOES NOT EXIST** | Use `string.find(s, pattern)` with capture unpacks. |
| **Variadic Expression (`...`)** | ⚠️ **UNRELIABLE** | Inside functions, rely on the implicit `arg` table (`arg[1]`, `arg.n`), `unpack()`, or explicit parameter lists. |
| **`goto` / Labels** | ❌ **SYNTAX ERROR** | Use structured control flow (`repeat ... until true`, `break`). |
| **Modulus Operator (`%`)** | Supported | `%` works in WoW 1.12. `math.mod(a, b)` is also available. |
| **Global Environment Table** | `_G` & `getglobal` | Both `_G["name"]` and `getglobal("name")` are valid. |

### Closure Variable Scoping Gotcha
In Lua 5.0, loop variables inside `for` loops can have scope quirks when captured by closures. Always re-bind loop variables into an explicit local variable before creating closures:
```lua
-- Correct in Lua 5.0:
for _, categoryName in ipairs(CATEGORY_LIST) do
    local capCategory = categoryName -- explicit local capture
    btn:SetScript("OnClick", function()
        select_category(capCategory)
    end)
end
```

---

## 2. WoW 1.12 FrameXML & Script System

### Pure Lua UI: Strictly NO XML for UI Creation
- **Rule:** Never use XML files (`.xml`) to create UI layouts, frames, or visual elements.
- **Rationale:** All frames, textures, buttons, and font strings must be created programmatically in Lua using `CreateFrame`, `OzUIHelper:create*`, or declarative schema tables. Pure Lua UI eliminates XML caching/reload bugs, avoids global namespace pollution from template tags, keeps layout testable, and allows complete dynamic resizing and anchor recalculation.

### Script Handler Context: `this`, `event`, `arg1`–`arg9`
In WoW 1.12, frame script handlers (`SetScript`) are executed within a special global context. They do **NOT** receive `self` as the first parameter:
```lua
-- ❌ Modern WoW (3.x+) pattern - FAILS in 1.12:
frame:SetScript("OnEvent", function(self, event, arg1) ... end)

-- ✅ Correct WoW 1.12 pattern:
frame:SetScript("OnEvent", function()
    -- 'this' is the frame
    -- 'event' is the event name string
    -- 'arg1' ... 'arg9' are the event payload arguments
    if event == "ADDON_LOADED" and arg1 == "OzAiO" then
        -- handle init
    end
end)
```

### Frame Creation & Memory Permanence
> **CRITICAL:** Frames created via `CreateFrame` can **NEVER be garbage collected** by the client during a game session.
- **Frame Leaks:** Never call `CreateFrame` inside loops, `OnUpdate`, or repeated UI `refresh()` calls.
- **Frame Pooling:** Always recycle rows and buttons using a virtual row pool table (`rowPool = {}`). Show active rows and hide unused rows.
- **Parenting:** Always explicitly specify the parent frame. If orphaned, frames will fail to inherit scale or hide/show state.

### Strata Hierarchy
When overlapping frames or popups, use standard strata:
`BACKGROUND` &rarr; `LOW` &rarr; `MEDIUM` &rarr; `HIGH` &rarr; `DIALOG` &rarr; `FULLSCREEN` &rarr; `FULLSCREEN_DIALOG` &rarr; `TOOLTIP`.

---

## 3. Hooking Conventions & Safe Interception

Directly overwriting Blizzard or third-party functions is strictly forbidden. Always use **`OzHook`**:

```lua
-- Global function hook:
OzHook:hook("ChatFrame_OnEvent", preFunc, postFunc)

-- Object method hook:
OzHook:hook(GameTooltip, "AddMessage", preFunc, postFunc)

-- Frame script hook:
OzHook:hook(frame, "OnShow", preFunc, postFunc)
```

### Hook Safety Rules
1. **Pre-Hooks:** Return `false` to cancel execution of the original function and subsequent hooks. Return `nil` to leave arguments unchanged. Return a new table to mutate arguments.
2. **Recursion / Re-entrancy:** Hooks must never cause infinite recursion. `OzHook` includes internal re-entrancy flags, but manual logic that triggers hooked events inside the hook must be guarded.
3. **Unhooking:** When a module or feature is disabled, cleanly call `OzHook:unhook(target, func)` to restore the original state.

---

## 4. Addon Lifecycle & Data Persistence

1. **`ADDON_LOADED`**:
   - `arg1` matches the folder name in `OzAiO.TOC` (`"OzAiO"`).
   - SavedVariables (`OZAIO`, `OZAIO_CONFIG`) become accessible *only* after `ADDON_LOADED` fires for this addon.
   - Run configuration merging and enable active modules here.
2. **`PLAYER_ENTERING_WORLD`**:
   - Safe to query player bags, inventory items, spellbook ranks, talents, and equipment.
   - Do **NOT** query `GetContainerItemInfo()` or `GetSpellName()` during `ADDON_LOADED` (data is not yet populated by the server).
3. **Configuration Storage**:
   - Store character-specific toggles in `OZAIO_CONFIG[key]`.
   - **Key Naming Convention**: Every key in `OZAIO_CONFIG` must strictly follow `<module>.<snake_case>` format (e.g. `OZAIO_CONFIG["bag.sell_junk"]`, `OZAIO_CONFIG["superwow.auto_loot"]`). Never use squished words (like `bag.selljunk`) or camelCase (like `autoLogout`).
   - Store global window metrics (e.g. `config_size`, `minimap_angle`) in `OZAIO`.

---

## 5. OzAiO Framework Standards

### 7 Fixed Categories
All modules and settings must register under exactly one of the **7 fixed categories**:
1. `General` (通用)
2. `Chat` (聊天)
3. `Minimap` (小地图)
4. `Quest` (任务)
5. `Actionbar` (动作条)
6. `Buff` (增益效果)
7. `Bag` (背包)

### Module Registration (`registerMod`)
Features must be registered using `OzFramework:registerMod`:
```lua
local module = OzFramework:registerMod({
    name = "oz_myfeature",
    title = L["My Feature"],
    category = "General",        -- Must be one of the 7 categories
    order = 10,                 -- Sorting order within category
    enabled = true,
    config = {
        ["myfeature.enabled"] = true,
    },
    config_ui_creator = { ... }, -- Declarative options schema
    enable = function(self) ... end,
    disable = function(self) ... end,
})
```

### Table-Driven UI Schema Specification
Configuration interfaces must use declarative schema tables instead of manual flow math:

```lua
config_ui_creator = {
    -- Header
    { type = "header", label = L["Section Title"] },

    -- Toggle / Checkbox
    {
        type = "checkbox", -- or "toggle"
        label = L["Enable Feature"],
        tooltip = L["Detailed explanation shown on hover"],
        config_key = "myfeature.enabled",
        onChange = function(checked) ... end,
    },

    -- Slider / Range
    {
        type = "slider", -- or "range"
        label = L["Threshold"],
        min = 1, max = 100, step = 5,
        config_key = "myfeature.threshold",
        onChange = function(val) ... end,
    },

    -- Dropdown / Select
    {
        type = "dropdown", -- or "select"
        label = L["Style"],
        options = {
            { value = 1, label = "Option A" },
            { value = 2, label = "Option B" },
        },
        config_key = "myfeature.style",
    },

    -- EditBox / Text
    {
        type = "editbox", -- or "text"
        label = L["Filter Tag"],
        width = 60,
        config_key = "myfeature.tag",
    },

    -- Button / Action
    {
        type = "button", -- or "execute"
        label = L["Reset"],
        func = function() ... end,
    },

    -- Informational Label
    {
        type = "label",
        label = L["Tip: Use /rl to reload."],
        color = { 0.5, 0.5, 0.5 },
    },

    -- Side-by-side Row
    {
        type = "row",
        items = {
            { type = "editbox", label = "A", width = 40, ... },
            { type = "button", label = "+", width = 24, ... },
        },
    },
}
```

### OzUIHelper API Naming Standards
All UI widget factory methods follow the **`create*`** convention:
- Containers: `createScrollPanel`, `createFlow`
- Primitives: `createLabel`, `createButton`, `createEditBox`, `createSeparator`, `createHeader`
- Compound: `createCheckbox`, `createSlider`, `createLabeledEditBox`, `createDropdown`, `createScrollItemList`, `createMinimapButton`
- Modifiers: `makeMovable` / `setMovable`

*(Note: Legacy `make*` names are preserved as backward-compat aliases, but all new code must use `create*`.)*

---

## 6. Naming Standards & Code Style

To maintain clean, consistent, and predictable code across the addon, adhere strictly to these naming conventions:

| Element | Convention | Example | Notes |
| :--- | :--- | :--- | :--- |
| **Class / Table / Metatable** | `PascalCase` | `OzConfig`, `OzUIHelper`, `OzHook`, `OzFramework` | Applied to modules, singleton libraries, and metatables. |
| **Class Method** | `camelCase` | `getValue`, `createButton`, `applyBackdrop`, `registerMod` | Invoked with colon syntax (`obj:getValue()`). |
| **Local Function** | `snake_case` (starts with a **verb**) | `print_null`, `toggle_system_buttons`, `update_layout`, `build_schema_ui`, `get_saved_size` | Must always start with an action verb (`get_`, `set_`, `toggle_`, `build_`, `create_`, `update_`). |
| **Global Variable / Constant** | `UPPER_SNAKE_CASE` | `CATEGORY_LIST`, `MINIMAP_ASSETS`, `CLASS_COLORS`, `OZAIO_CONFIG` | Used for constants, global configurations, and lookup tables. |
| **Local Variable / Value** | `snake_case` (starts with a **noun**) | `system_status`, `frame_width`, `active_category`, `event_frame`, `item_count` | Must start with a noun or noun phrase describing the entity. |

---

## 7. Localization: Metatable Auto-Value Pattern

Never manually assign identical values for both `enUS` and `zhCN`. The English key string **IS** the default value.

### Standard Localization Pattern
Always define the localization table `L` using an auto-assigning metatable (`rawset(t, k, v)`):

```lua
local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})

-- Only define overrides for non-English locales (e.g. zhCN):
if LOCALE == "zhCN" then
    L["Auto Dismount"] = "自动下马"
    L["Auto Stance"]   = "自动姿态"
    L["Font Size"]     = "字体大小"
end
```

### Key Rules
- ❌ **FORBIDDEN:** Manually writing `L["Auto Dismount"] = "Auto Dismount"` for English. It creates redundant code, wastes memory, and adds maintenance overhead.
- ✅ **ALLOWED:** Reference English phrases directly in code via `L["Some English Text"]`. The metatable will dynamically cache and return the key itself on first access.
- ✅ **OVERRIDE:** Add non-English translations only under conditional locale blocks (`if LOCALE == "zhCN" then ... end`).

---

## 8. Performance & Code Quality Checklist

Before committing or submitting changes to this repository, verify:
- [ ] **Strictly NO XML for UI:** All UI constructed programmatically in Lua.
- [ ] **Naming standards adhered to:** Classes in `PascalCase`, methods in `camelCase`, local functions start with a verb (`snake_case`), local variables start with a noun (`snake_case`), globals in `UPPER_SNAKE_CASE`.
- [ ] **Metatable auto-value used for localization:** No redundant manual `enUS` key=value assignments.
- [ ] **No `#` length operators used.** (`table.getn` / `string.len` used instead).
- [ ] **No `//` integer division.** (`math.floor(a / b)` used instead).
- [ ] **No `string.gmatch`.** (`string.gfind` used instead).
- [ ] **No frame allocation leaks in loops.** Reusable row frame pools used for lists.
- [ ] **Script handlers use `this`, `event`, `arg1`..`arg9`** (no modern `self` parameters in `SetScript`).
- [ ] **Hooks registered via `OzHook`** without destructive global clobbering.
- [ ] **Modules declare a valid `category`** matching one of the 7 standard categories.
