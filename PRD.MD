# Product Requirements Document (PRD)

## Project: OzAiO (Oz Toolbox / Oz工具箱)
**Version:** 1.0  
**Target Client:** World of Warcraft: Classic / Vanilla (Patch 1.12.1, Interface 11200)  
**Supported Platforms:** Vanilla 1.12.1 Clients, Turtle WoW (tWOW build > 6000), SuperWoW Client Extension  
**Document Status:** Approved / Implemented Base Specification  

---

### 1. Executive Summary & Vision

#### 1.1 Product Vision
**OzAiO** (Oz All-in-One / Oz Toolbox) is a modular, high-performance Quality-of-Life (QoL) and automation suite engineered specifically for the World of Warcraft 1.12.1 client, with first-class support for Turtle WoW and SuperWoW. 

Unlike monolithic UI replacements (such as pfUI) that enforce complete visual overhauls, OzAiO focuses on surgically enhancing the default Blizzard UI and existing addon ecosystems. It solves longstanding Vanilla 1.12 friction points—including manual vendor management, spell rank management upon training, chat clutter, minimap button pollution, shared quest acceptance, and world buff tracking—with zero frame drops, smart frame-budgeting, and comprehensive localization (English & Simplified Chinese).

#### 1.2 Core Value Propositions
- **Modular Micro-Architecture:** Independent modules registered under a unified framework (`OzFramework`), allowing selective activation without inter-module coupling.
- **Engineered for Low Overhead:** Strict adherence to 1.12.1 single-thread limits. Critical operations (action bar scanning, vendor transactions) are time-sliced across frames to eliminate client stutter and mouse cursor flickering.
- **SuperWoW & Turtle WoW Synergy:** Unlocks native SuperWoW enhancements (FoV, clickthrough corpses, uncapped audio channels, 511-char macros, mouseover units, spell/quest linking) and hides server-specific UI clutter.
- **World Buff Network Coordination:** Interoperable with the community-standard `WorldBuffsTracker` protocol (`TWB` channel) and cross-faction relays (`LFT` channel), delivering automated visual/audio countdowns, hearthstone quick-casts, and safe auto-logouts.

---

### 2. User Personas & Use Cases

| Persona | Needs & Pain Points | How OzAiO Solves It |
| :--- | :--- | :--- |
| **Vanilla Raider** | Needs world buffs (Onyxia, Nefarian) without sitting AFK in Orgrimmar/Stormwind for hours; risk of losing buffs on death. | Real-time countdown HUD, guild alerts, one-click emergency hearthstone, and automatic logout 60s after receiving buffs. |
| **Leveler / Quester** | Upgrading spells at class trainers requires manually finding and dragging new ranks onto action bars; party quest sharing requires repeated clicking. | Automatically updates action bars when new spell ranks are trained; highlights spells already slotted in the spellbook; auto-accepts shared quests with Alt-key override. |
| **Farmer / Grinder** | Bags fill up quickly with grey trash; restocking reagents (potions, flash powder, food) at vendors is tedious and error-prone. | One-click or auto-sell grey items and custom blacklisted items; auto-buys exact target quantities of required items with stock/funds checks. |
| **Hardcore (Turtle WoW)**| Death announcements flood primary chat tabs; accidental dismount or stance errors lead to death. | Auto-redirects HC death messages to a dedicated chat window; auto-dismounts on cast failure; auto-switches to required warrior/druid stances. |
| **SuperWoW User** | Macro length 255-char limit is restrictive; lacks modern camera FoV, directional selection circles, and chat spell links. | Enables native SuperWoW CVars, expands macro editor to 511 characters, and hooks chat linking for spells and quests. |

---

### 3. Architecture & Shared Infrastructure

```
+-----------------------------------------------------------------------+
|                              OzAiO Addon                              |
+-----------------------------------------------------------------------+
|  core/framework.lua: Module Registry, Config UI, Minimap Button, Init  |
|  core/ozapi.lua:     Public API Table (Cross-Addon Communication)     |
+------------------------------------+----------------------------------+
|              lib/                  |              modules/            |
|  - configuihelper.lua (Panel/Theme)|  - general.lua    (QoL/Stance)   |
|  - libhook.lua        (OzHook)     |  - bag/*          (Vendor Auto)  |
|  - lib.lua            (OzLib)      |  - loot/*         (Auto-Roll)    |
|                                    |  - spell/*        (ActionBar)    |
|                                    |  - chat/*         (Channel/HC)   |
|                                    |  - minimap/*      (Clutter)      |
|                                    |  - superwow.lua   (SuperAPI)     |
|                                    |  - worldbuff.lua  (Sync/Alert)   |
|                                    |  - quest/*        (Auto-Accept)  |
+------------------------------------+----------------------------------+
```

#### 3.1 Module Registry & Framework Architecture (`core/framework.lua`)
- **Fixed Category Navigation:**
  The configuration UI organizes all features into **8 standardized categories** on the left panel:
  1. `General` (通用)
  2. `Chat` (聊天)
  3. `Minimap` (小地图)
  4. `Quest` (任务)
  5. `Actionbar` (动作条)
  6. `Buff` (增益 / 世界BUFF)
  7. `Bag` (背包 / 商人)
  8. `Loot` (拾取 / 战利品)
  Selecting a category activates its scrollable container, rendering all features registered under that category.

- **Declarative Mod Registration Contract (`registerMod`):**
  Modules register via `OzFramework:registerMod({ name, category, order, config_ui_creator, enable, disable })`:
  - `name`: Unique identifier string.
  - `category`: Target category matching one of the 8 fixed categories.
  - `order`: Integer for vertical placement priority within the category view.
  - `config_ui_creator`: Function returning (or direct table of) an Automaton-style declarative options schema.
  - `enable()` / `disable()`: Pure lifecycle callbacks for registering/unregistering events and hooks.

- **Table-Driven UI Schema Specification (Automaton/AceOptions Style):**
  The framework's schema parser interprets the table returned by `config_ui_creator` and automatically generates widgets via `OzUIHelper`:
  - **`type = "checkbox"`**: Checkbox (`makeCheckbox`) for boolean states. Attributes: `name`, `desc` (optional tooltip or label), `get = function()`, `set = function(value)`.
  - **`type = "dropdown"`**: Dropdown menu (`makeDropdown`) for multi-option selection. Attributes: `name`, `desc`, `values = { [key] = label }` or `{ {label, value} }`, `get = function()`, `set = function(value)`.
  - **`type = "button"`**: Action button (`makeButton`). Attributes: `name`, `desc`, `func = function()`.
  - **`type = "editbox"`**: Text input box (`makeLabeledEditBox`). Attributes: `name`, `desc`, `get = function()`, `set = function(text)`.
  - **`type = "header"`**: A header with a separator line (`makeSeparator` + label). Attributes: `name`, `desc` (optional tooltip or label).
  - **`type = "label"`**: Formatted informational text block. Attributes: `text`. usually in grey color.
  - **`type = "itemlist"`**: Scrollable item list (`makeScrollItemList`). Attributes: `name`, `getItems = function()`, `showQuantity = true/false`, `nameResolver`, `colorResolver`.
  - **`type = "custom"`**: Escape hatch for arbitrary custom frames/widgets. Attributes: `create = function(parent) return frame, height end`.

- **Collapsible / Foldable Module Sections:**
  Modules with multiple options render with an interactive foldable header (`OzUIHelper:createFoldableHeader`) featuring `[-]` / `[+]` toggle indicators, title highlight on hover, and localized collapse/expand hints. All sections expand by default upon opening the UI. Folding dynamically reflows all section widgets in-memory and recalculates scroll dimensions without recreating frames. Folded state is not persisted across sessions. **Single-Option Optimization:** Modules containing only a single option omit the redundant header bar, displaying the option directly to conserve vertical screen space.

- **Backward Compatibility:**
  Legacy `OzFramework:register(id, moduleTable)` remains supported alongside `registerMod`. Legacy modules using `create_config_panel` are automatically mapped to their corresponding fixed category tab (`oz_general` & `oz_superwow` $\rightarrow$ `General`, `oz_chat` $\rightarrow$ `Chat`, `oz_minimap` $\rightarrow$ `Minimap`, `oz_quest` $\rightarrow$ `Quest`, `oz_spell` $\rightarrow$ `Actionbar`, `oz_worldbuff` $\rightarrow$ `Buff`, `oz_bag` $\rightarrow$ `Bag`).

- **Config Storage:** Saved variables stored per character:
  - `OZAIO_CONFIG`: Key-value registry for all module settings.
  - `OZAIO`: Core settings (e.g., `minimap_angle`, `info_level`, `config_size = { width, height }`).
- **Config Initialization:** Merges module default settings into `OZAIO_CONFIG` on `ADDON_LOADED` without overwriting existing user configurations.

#### 3.2 Non-Intrusive Hooking Engine (`lib/libhook.lua` - `OzHook`)
- **Cross-Addon Singleton & Versioning:**
  `OzHook` implements a versioned singleton guard (`MAJOR = "OzHook-1.0"`, `MINOR = 1`). If multiple addons embed or load `libhook.lua`, the highest minor version takes precedence without overwriting active hook registries.
- **Stateless & Shared Registry Architecture:**
  - All internal registrations, wrapper functions, and re-entrancy flags reside in a shared singleton registry (`OzHook._registry = OzHook._registry or {}`) instead of file-local closures.
  - Guarantees that when multiple distinct addons hook the same Blizzard function or frame script (e.g. `ChatFrame_OnEvent`, `UseContainerItem`, or `SpellButton_OnClick`), they share a single unified execution pipeline without redundant nested wrappers, unhook collisions, or broken hook chains.
- **Unified Signature:** Single entry point `OzHook:hook(target, [name,] preFn, [postFn])` supporting global functions, table methods, and frame script handlers (`OnShow`, `OnClick`, `OnEvent`, etc.).
- **Execution Pipeline:** `Wrapper -> Pre-Hook(s) -> Original Function -> Post-Hook(s)`.
  - If a pre-hook returns `false`, execution halts and the original function is cancelled.
  - If a pre-hook returns values, arguments passed to the original function are substituted.
  - Recursive hook prevention flag (`entry.running`) ensures safety against re-entrant calls.
- **Clean Lifecycle:** Supports unhooking specific callbacks or restoring all hooked globals to pristine state via `OzHook:unhookAll()`.

#### 3.3 Dynamic Layout & UI Design System (`lib/configuihelper.lua` - `OzUIHelper`)
- **Cross-Addon Singleton & Stateless Factory Architecture:**
  `OzUIHelper` operates as a versioned, stateless widget factory and layout engine (`MAJOR = "OzUIHelper-1.0"`, `MINOR = 1`):
  - **Zero Global UI State:** `OzUIHelper` stores zero persistent layout or widget state inside its own table. All layout state (cursor coordinates, content heights, item caches) is strictly encapsulated within the returned `panel` or `widget` instance, ensuring multiple independent addons can use `OzUIHelper` concurrently without state collisions.
  - **Namespaced Frame Generation:** Auto-generated frame names accept an optional addon-specific prefix (defaulting to `"OZAIO"` or caller-defined, e.g. `prefix .. "_" .. nextId()`), preventing global frame name clashes across different addons.
  - **Instance-Scoped Pooling:** Object pools (e.g. `makeScrollItemList` row pools) are attached directly to their parent widget instance rather than stored globally.
  - **Theme Non-Pollution:** Base theme definitions provide safe shared defaults while allowing callers to pass custom backdrops, metrics, or colors without mutating global theme tables.
- **Resizable Configuration Shell:**
  - `OzAiOConfigFrame` is fully resizable via `frame:SetResizable(true)`.
  - **Dimensional Bounds:** Minimum: `500 x 420`, Maximum: `900 x 850` (enforced via `SetMinResize` / `SetMaxResize`).
  - **Resize Grip Handle:** Bottom-right corner grabber button using native Blizzard textures (`Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up` / `-Highlight` / `-Down`). Handlers invoke `StartSizing("BOTTOMRIGHT")` on mouse down and `StopMovingOrSizing()` on mouse up.
  - **Dynamic Layout Adaptation:** On resize, `tabFrame` adapts its height, `contentScroll` expands to fill available width and height, and `contentFrame` automatically matches `contentScroll:GetWidth()`.
  - **Session Persistence:** Window dimensions are persisted in `OZAIO.config_size = { width, height }` and restored upon display.
- **Unified Panel Hierarchy (`Frame -> ScrollPanel -> Widget / Row`):**
  Eliminates the redundant `flow` intermediate layer in favor of a self-contained, scrollable layout panel:
  - `createScrollPanel(parent, [opts])`: Instantiates a scrollable container that directly manages widget placement and self-calculates content height.
  - `panel:Add(widget)`: Default column stacking. Automatically places the widget and advances vertically to the next row, removing repetitive manual `newLine()` boilerplate (covering ~85% of standard settings controls).
  - `panel:AddRow({ widget1, widget2, ... }, [opts])`: Arranges multiple controls horizontally on a single line (e.g., Label + EditBox + Buttons), handling horizontal spacing and baseline vertical alignment automatically.
  - `panel:GetContentHeight()`: Automatically tracks cumulative content bounds, eliminating manual `math.abs(flow.y) + padding` calculations in each module.
- **Standardized Visual Backdrops:** Shared visual theme presets:
  - `widget`: Tooltip-style dark background (`#0D0D0D`, alpha 0.8) with thin borders.
  - `panel`: Inset container backdrop (`#0D0D14`, alpha 0.6).
  - `flat`: Solid borderless backdrops for buttons and headers.
  - `dropdownItem`: Hover-highlighted menu list items.
- **Class-Colored UI:** Dynamically skins window headers and player elements using class colors (`OzUIHelper:classColor`).
- **Compound Widgets (`create*` API standard, with `make*` backward-compat aliases):**
  - `createCheckbox(parent, text, value, onChange)`
  - `createLabeledEditBox(parent, labelText, editWidth)`
  - `createDropdown(parent, label, options, defaultValue, onChange)` with shared full-screen click-catcher to dismiss.
  - `createSlider(parent, label, min, max, step, defaultValue, onChange, width)`
  - `createHeader(parent, text)`
  - `createSeparator(parent, width)`
  - `createLabel(parent, text, font)`
  - `createButton(parent, text, onClick, width, height)`
  - `createScrollItemList(parent, opts)`: Reusable scrollable list with item quality color resolution, item count displays, and ascending/alphabetical sorting (leveraging frame pooling).
- **Minimap Button Widget:** Polar coordinate-based draggable minimap button (`radius = 80px`) via `createMinimapButton(opts)` with saved angle persistence in `OZAIO.minimap_angle`.

#### 3.4 Common Utilities (`lib/lib.lua` - `OzLib`)
- **Logging / Print Engine:** Level-filtered colored console printing (`OzLib:print(msg, level)`) with levels `default`, `debug`, and `error`.
- **Currency Formatter:** `OzLib:convertMoney(copper)` converting raw copper into formatted, colored Gold/Silver/Copper strings.
- **Item Quality Resolution:** `OzLib:itemQualityColor(idOrLink)` mapping Vanilla item qualities (0 to 5) to RGB colors.

#### 3.5 Public API Layer (`core/ozapi.lua` - `OzAPI`)
- Exposes clean external hooks for third-party addon integration:
  - `OzAPI.getLastWBTime`: Query latest recorded dragon buff drop time.
  - `OzAPI.isDarkmoonAtAlliance`: Query Darkmoon Faire active location status.

---

### 4. Functional Specifications by Module

---

#### 4.1 General Module (`general/general.lua` - `oz_general`)
**Primary Objective:** Core convenience commands, typography adjustment, and combat movement automation.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **GEN-01** | `/rl` Slash Command | Registers `/rl` as a shortcut for `/script ReloadUI()`. | None (Built-in) |
| **GEN-02** | Unified Font Resizer | Dynamically scales all core game fonts (`SystemFont`, `GameFontNormal`, `ChatFontNormal`, `QuestFont`, `PlayerName`, `TargetName`, etc.) based on a single integer setting (Range: 8 to 20, Default: 14). Small fonts = Base - 2; Large fonts = Base + 2; Huge fonts = Base + 6. Supports `FRIZQT__.TTF` (enUS) and `ARIALN.TTF` (zhCN). | `general.font_size` |
| **GEN-03** | Auto Dismount | Intercepts `UI_ERROR_MESSAGE` events for mount-blocked casts (e.g., `SPELL_FAILED_NOT_MOUNTED`). Matches active player buff textures against known mount icon substrings (including Turtle WoW custom mounts: zebra, boar, turtle, reindeer, etc.) and cancels the mount buff. Also stands up if sitting (`SPELL_FAILED_NOT_STANDING`). Zero tooltip scanning ensures zero mouse cursor flickering. | `general.auto_dismount` |
| **GEN-04** | Auto Stance | Intercepts `SPELL_FAILED_ONLY_SHAPESHIFT` error strings and automatically casts the required Warrior stance (Battle, Defensive, Berserker) or Druid form (Bear, Cat) required by the attempted ability. | `general.auto_stance` |
| **GEN-05** | Addon Conflict Gating | Detects `pfUI` or `ShaguTweaks` on `PLAYER_LOGIN`. If present, automatically yields execution and disables `oz_general` Auto Dismount / Auto Stance to prevent double-casting or hook collision. | Automated |

---

#### 4.2 Bag, Vendor & Utility Modules (`bag/merchant.lua`, `bag/clam_opener.lua`, `bag/unlock.lua`)
**Primary Objective:** Streamlined vendor interactions, automated inventory cleanup, intelligent reagent purchasing, clam opening, and Rogue lockpicking utilities.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **BAG-01** | Auto Sell Junk | Automatically iterates container slots when opening a merchant (`MERCHANT_SHOW`) and sells all Poor (grey, hex `ff9d9d9d`) quality items via a throttled queue (0.2s interval). | `bag.sell_junk` |
| **BAG-02** | Auto Sell Custom List | Allows users to add specific items to a blacklist. When visiting a vendor, any non-grey matching items in bags are queued and sold automatically. | `bag.auto_sell`, `bag.auto_sell_list` |
| **BAG-03** | Auto Buy Reagents | Users configure target quantities for essential items (e.g., Ankhs, Flash Powder, Food, Drink, Poison ingredients). Upon opening a vendor selling those items: <br>1. Calculates `need = targetQty - currentInventory`. <br>2. Finds the cheapest matching merchant slot. <br>3. Computes required stack purchases. <br>4. Queues purchases throttled to 0.2s ticks. | `bag.auto_buy`, `bag.auto_buy_list` |
| **BAG-04** | Transaction Safeguards | Prevents purchasing if bags are full (inspects bag slot capacity and stack limits) or if player funds are insufficient. | Automated |
| **BAG-05** | Inventory Sync Verification | Listens to `BAG_UPDATE` to confirm receipt of bought items before advancing the buy queue, preventing stock desync or race conditions under server latency. | Automated |
| **BAG-06** | Financial Audit Summary | Summarizes vendor transactions in chat upon `MERCHANT_CLOSED`, detailing items bought, total costs, and net money gained/spent. | Automated |
| **BAG-07** | Smart Item Input Parser | Item lists accept raw numeric Item IDs, pasted chat item links, or partial name searches (scans current bags and merchant window). | Configuration UI |
| **BAG-08** | Auto Clam Opener | Iterates player bags for clam items (IDs: 5523, 5524, 7973, 15874). Opens sequentially with 0.5s intervals. Auto-triggered on `LOOT_CLOSED`, `MAIL_CLOSED`, `TRADE_CLOSED`, `BANKFRAME_CLOSED` (with 0.5s quiet delay and `LOOT_OPENED` cancellation). Avoids `BAG_UPDATE` to eliminate race conditions with autoloot. Includes safety gates against open blocking windows and active loot. | `bag.clam_opener_enable` |
| **BAG-09** | Trade Frame Unlock Button | Adds an "Unlock" button to the trade window (`TradeFrameCancelButton` anchor) for Rogues. Casts Pick Lock and automatically targets slot 7 ("will not be traded") if an item is present. | `bag.unlock_enable` |
| **BAG-10** | Bag Right-Click Unlock | Hooks `ContainerFrameItemButton_OnClick` via `OzHook` for Rogues. Right-clicking locked boxes in inventory automatically casts Pick Lock on the box. | `bag.unlock_enable` |

---

#### 4.3 Loot Management Module (`loot/auto_roll.lua` - `oz_auto_roll`)
**Primary Objective:** Automated loot rolling on raid and dungeon reputation tokens (Zul'Gurub and Caverns of Time / Black Morass) and seamless Bind-on-Pickup confirmation handling.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **LOT-01** | Auto Roll Master Toggle | Master switch to activate automatic roll processing on group/raid loot drops (`START_LOOT_ROLL`). When disabled, the standard Blizzard roll UI is completely unhindered. | `loot.auto_roll_enable` |
| **LOT-02** | ZG Bijous Auto Roll | Automatically rolls on all 9 Zul'Gurub Hakkari Bijous. Configurable actions: `Need`, `Greed`, `Pass`, or `Manual` (ignore/prompt). | `loot.zg_bijous_action` |
| **LOT-03** | ZG Coins Auto Roll | Automatically rolls on all 9 Zul'Gurub Coins. Configurable actions: `Need`, `Greed`, `Pass`, or `Manual` (ignore/prompt). | `loot.zg_coins_action` |
| **LOT-04** | CoT Corrupted Sand Auto Roll | Automatically rolls on Caverns of Time reputation item: **Corrupted Sand** (腐蚀之沙, ID: `50203`). Configurable actions: `Need`, `Greed`, `Pass`, or `Manual` (ignore/prompt). | `loot.cot_items_action` |
| **LOT-05** | BoP Popup Auto-Confirm | Automatically confirms the `CONFIRM_LOOT_ROLL` modal dialog for items processed by the auto-roll system, eliminating blocking confirmation prompts. | `loot.auto_roll_enable` |

##### 4.3.1 Auto Roll Detailed Technical Specifications (`loot/auto_roll.lua`)
- **Event Pipeline:**
  1. `START_LOOT_ROLL (rollID, rollTime)`: Retrieves `GetLootRollItemLink(rollID)` and parses numeric item ID via `|Hitem:(%d+)`.
  2. Matches item against configured groups:
     - **ZG Bijous (哈卡莱宝石, IDs 19707–19715):** Red (19707), Blue (19708), Yellow (19709), Orange (19710), Green (19711), Purple (19712), Bronze (19713), Silver (19714), Gold (19715).
     - **ZG Coins (祖尔格拉布硬币, IDs 19698–19706):** Zulian (19698), Razzashi (19699), Hakkari (19700), Gurubashi (19701), Vilebranch (19702), Witherbark (19703), Sandfury (19704), Skullsplitter (19705), Bloodscalp (19706).
     - **CoT Rep Item (时光之穴):** Specifically **Corrupted Sand** (腐蚀之沙, ID `50203`).
  3. Action Resolution:
     - `"need"`: Calls `RollOnLoot(rollID, 1)`. If `canNeed == 0` (cannot Need), gracefully falls back to Greed (`2`) or Pass (`0`).
     - `"greed"`: Calls `RollOnLoot(rollID, 2)`.
     - `"pass"`: Calls `RollOnLoot(rollID, 0)`.
     - `"manual"`: No action taken; standard Blizzard roll frame remains visible.
  4. Auto-Confirm: Tracks active `rollID` in a session table. When `CONFIRM_LOOT_ROLL` triggers for an auto-rolled item, calls `ConfirmLootRoll(rollID, rollType)` immediately and suppresses the `CONFIRM_LOOT_ROLL` static popup.
  5. Audit Output: Prints a clean colored notification to chat when `loot.announce_roll` is enabled (e.g. `[OzAiO] Auto-Rolled Need on [Corrupted Sand]`).

---

#### 4.4 Spell & Action Bar Modules (`spell/update_spell_lvl.lua`)
**Primary Objective:** Eliminate manual action bar maintenance when training new abilities.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **SPL-01** | Auto-Update on Train | Listens to `CHAT_MSG_SYSTEM` for learned spell messages (`"You have learned a new spell: ..."`). Defers by one frame, locates the newly learned highest rank in the spellbook, and updates all matching action bar slots (1-120) with the new rank using `PickupSpell` and `PlaceAction`. | `spell.auto_update_rank` |
| **SPL-02** | Frame-Budgeted Slot Scanning | Avoids single-frame lag spikes by distributing action bar scanning across frames: advances **1 slot per OnUpdate frame** (120 frames total). Tooltip owner remains hidden to avoid visual glitches. | Automated |
| **SPL-03** | Manual Action Bar Upgrade Sweep | Provides a one-click button in settings: *"Update All Action Bar Spells Now"*. Sweeps slots 1 through 120 and upgrades any down-ranked abilities to their highest learned spellbook rank. | UI Action Button |

---

#### 4.5 Chat Enhancements Module (`chat/*` - `oz_chat`)
**Primary Objective:** Enhance readability, reduce clutter, and organize specialized server chat channels.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **CHT-01** | Two-Stage Chat Pipeline | Provides an extensible chat processor separating **Event Filters** (inspects/cancels/redirects raw events) from **Display Filters** (mutates formatted strings in `AddMessage`). | Architecture |
| **CHT-02** | Channel Name Shortening | Replaces verbose standard channel tags in `ChatFrameX:AddMessage` with concise brackets: <br>- `[General]` / `[综合]` -> `[G]` / `[综]` <br>- `[Trade]` / `[交易]` -> `[T]` / `[交]` <br>- `[World]` / `[世界]` -> `[W]` / `[世]` <br>- `[LookingForGroup]` / `[寻求组队]` -> `[LFG]` / `[组]` <br>- `[Hardcore]` / `[硬核]` -> `[H]` / `[核]`, etc. | `chat.short_channel_name` |
| **CHT-03** | Hardcore Channel Redirection | Traps Turtle WoW Hardcore death messages (`CHAT_MSG_HARDCORE`) and suppresses them from default chat frames, redirecting them solely to a designated chat tab/frame ID (Configurable: 1 to 20). | `chat.hc_channel_num` |
| **CHT-04** | Timed Message Broadcaster | Automatically broadcasts configured messages to a selected chat channel on a periodic timer: <br>- **Configurable Interval (Minutes):** UI slider/input configured directly in minutes (Range: 1 to 15 minutes, Default: 2 minutes; stored in `chat.broadcast_interval`). <br>- **Dynamic Channel Selector:** Dropdown dynamically populated with standard channels (`SAY`, `YELL`, `GUILD`, `PARTY`, `RAID`) and active numbered channels from `GetChannelList()` (e.g. `General`, `Trade`, `World`), filtering out private sync channels (`TWB`, `LFT`), identical to the `worldbuff_hud.lua` channel menu. <br>- **Hybrid Item Link Resolution (Method 1 + Method 3):** <br>&nbsp;&nbsp;1. *Direct Shift-Click (Method 1):* EditBox accepts native item hyperlinks inserted via Shift-clicking items in bags, character sheet, or chat. <br>&nbsp;&nbsp;2. *Bracketed Name Resolution (Method 3):* Automatically scans message text for bracketed names (e.g. `[Lionheart Helm]` or `[狮心头盔]`), queries inventory bags (`GetContainerItemLink`), equipment slots (`GetInventoryItemLink`), and client item cache (`GetItemInfo`), replacing them with authentic clickable item hyperlinks (`|c...|Hitem:...|h[...] |h|r`). <br>- **Input Pre-Validation & Caching:** Upon user input/edit in the UI, immediately parses and validates raw message tokens, checking item availability in bags/cache and pre-caching resolved output to save runtime inventory scanning overhead. <br>- **Automatic Message Chunk Splitting (>255 Bytes):** Checks total byte length after item link resolution against WoW's native 255-character chat packet limit. If exceeded, safely splits the message into 2 or 3 parts at clean word/token boundaries without truncating or corrupting embedded hyperlink tags (`|c...|r`), sending parts sequentially with a 0.2s debounce to prevent server flood disconnects. <br>- **Combat & Death Throttling Guard:** Automatically pauses timer ticks while player is in combat (`UnitAffectingCombat("player")`) or dead/ghost, resuming cleanly upon recovery. <br>- **Test Dispatch:** Provides a one-click test button in settings to broadcast immediately for visual inspection. | `chat.broadcast_enable`, <br>`chat.broadcast_interval`, <br>`chat.broadcast_channel`, <br>`chat.broadcast_message`, <br>`chat.broadcast_combat_pause` |
| **CHT-05** | Player Name Link Shift-Click | Enables Shift-clicking a player's name link in the chat log while `ChatFrameEditBox` is visible to automatically insert their formatted clickable player hyperlink (`|cffffffff|Hplayer:Name|h[Name]|h|r`) directly into the active chat edit box, cancelling the default `/who` lookup. | `chat.player_link` |
| **CHT-06** | Clickable Auto-Invite Links | Converts common group invite trigger words (`1`, `111`, `inv`, `invite`, `组`, `求组`, `组我`, `组队`, etc.) in public and group channels into clickable hyperlinks (`|cff00ffff|Hinvite:Sender|h[...]|h|r`). Clicking the bracketed link in chat immediately fires `InviteByName(sender)`. | `chat.click2inv` |
| **CHT-07** | EditBox Center & History Arrows | Centers `ChatFrameEditBox` at the bottom of the screen while dynamically dodging bottom action bars (`MainMenuBarArtFrame`, `MultiBarBottomLeft`, `MultiBarBottomRight`, `PetActionBarFrame`, `ShapeshiftBarFrame`) via `UIParent_ManageFramePositions`. Enables direct Up/Down arrow key chat history iteration without requiring Alt (`ChatFrameEditBox:SetAltArrowKeyMode(false)`). | `chat.editbox_tweak` |

---

#### 4.6 Minimap Management Module (`minimap/hide_sys_button.lua` - `oz_minimap`)
**Primary Objective:** Clear visual clutter from the minimap circumference.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **MAP-01** | Hide Standard System Buttons | Hides default Blizzard minimap frames: `MiniMapTrackingFrame`, `MiniMapMeetingStoneFrame`, `MinimapZoomIn`, `MinimapZoomOut`, and `MiniMapMailFrame`. | `minimap.hide_system_buttons` |
| **MAP-02** | Hide Turtle WoW Custom Buttons | Detects Turtle WoW (`build > 6000`) and suppresses custom server frames: `EVTButtonFrame`, `MinimapShopFrame`, `TWMiniMapBattlefieldFrame`, `LFTMinimapButton`, and `EBC_Minimap`. | `minimap.hide_system_buttons` |

---

#### 4.7 SuperWoW Enhancements Module (`general/superwow.lua` - `oz_superwow`)
**Primary Objective:** Surface native SuperWoW client enhancements, CVars, and SuperAPI features directly into the addon interface.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **SPW-01** | Native Autoloot & Shift-Loot | Integrates with SuperWoW `SetAutoloot(1/0)`. Supports either full automated loot or an inverted "Hold Shift to Autoloot" polling mode. | `superwow.auto_loot`, `superwow.shift_loot` |
| **SPW-02** | Clickthrough Corpses | Calls SuperWoW `Clickthrough(1/0)` to allow targeting through dead monster corpses. | `superwow.click_through` |
| **SPW-03** | Audio Enhancements | Exposes CVars for background sound (`BackgroundSound 1/0`) and uncapped audio channels (`UncapSounds 1`, setting software and hardware sound channels from 12 to 64). | `superwow.background_sound`, `superwow.uncapped_sounds` |
| **SPW-04** | Visual CVars | Configures Field of View (`FoV`), target selection circle styles (`SelectionCircleStyle` 1 to 4: incomplete, full, full with arrow, classic oriented), and loot sparkle effects (`LootSparkle`). | `superwow.fov`, `superwow.selection_circle_style`, `superwow.loot_sparkle` |
| **SPW-05** | 511-Character Macro Editor | Hooks `MacroFrameText:SetMaxLetters` to raise the macro character limit from 255 to 511 characters. | Automated |
| **SPW-06** | SuperAPI Global Hooks | - **Spell Shift-Click Linking:** Inserts `|Henchant:<id>|h[SpellName]|h` links into chat when shift-clicking the spellbook. <br>- **Spell Link Tooltips:** Rewrites `spell:` links to `enchant:` in `SetItemRef` so tooltips show on click. <br>- **Negative Stack Badges:** Renders SuperWoW negative item counts yellow with `*` when below -999. <br>- **UnitFrame Mouseover:** Calls `SetMouseoverUnit(this.unit)` on unit frame hover. <br>- **Combat Text Names:** Replaces hex GUIDs (`0x000...`) in scrolling combat text with resolved unit names. <br>- **Quest Shift-Linking:** Shift-clicking the quest log uses `QuestInfo_GetQuestID()` to insert clickable quest links into chat. | Automated |

---

#### 4.8 World Buff Tracker & Relay Module (`general/worldbuff.lua` - `oz_worldbuff`)
**Primary Objective:** Automated detection, cross-client synchronization, visual/audio alerts, and safety utilities for world buffs (Onyxia & Nefarian).

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **WBF-01** | Monster Yell Detection | Scans `CHAT_MSG_MONSTER_YELL` in Orgrimmar and Stormwind for dragon head drop announcements: <br>- Alliance: Major Mattingly (Onyxia), Field Marshal Afrasiabi (Nefarian). <br>- Horde: Overlord Runthak (Onyxia), High Overlord Saurfang (Nefarian). | `worldbuff.enabled` |
| **WBF-02** | Cross-Client Relay (`LFT` Channel) | Broadcasts detected yell events over the public `LFT` channel (`MPWB:<Dragon>:<Faction>`) to notify other OzAiO users across zones. | `worldbuff.enabled` |
| **WBF-03** | TWB Peer-to-Peer Mesh Sync | Connects to the community `TWB` channel with protocol compatibility with `WorldBuffsTracker`: <br>- `SyncS:A<ts>OH<ts>N...`: Periodic full-state synchronization of buff expiration timestamps (2h duration). <br>- `Lightning:<releaseTS>@<Key>`: Broadcasts impending buff drops (~18s delay). | `worldbuff.enabled` |
| **WBF-04** | Server Time Calibration | Sends `.server info` queries to capture actual server time offset via system messages, applying exponential backoff retries (5s to 60s, limit 6 retries) to maintain millisecond-accurate sync across timezones. | Automated |
| **WBF-05** | Flashing Countdown Bar | Displays a prominent screen-centered animated countdown bar (`OzAiOWorldBuffCaution`) pulsing yellow/green during the 18-second window before the buff lands. | `worldbuff.countdown` |
| **WBF-06** | Audio & Guild Broadcasts | Plays custom audio alert (`sound/wb_alert.ogg`) and announces incoming buffs to guild chat (`GUILD`). | `worldbuff.sound`, `worldbuff.guild` |
| **WBF-07** | Emergency Hearthstone Button | Spawns a floating interactive Hearthstone button (`OzAiOWorldBuffHearthstone`) on the screen for 10 seconds. Cached bag slot lookups ensure instantaneous use without scanning bags during lag. | `worldbuff.hearthstone` |
| **WBF-08** | Automated Safety Logout | Initiates `/logout` exactly 60 seconds after buff drop. Validates that the player is in Orgrimmar or Stormwind and delays logout tick-by-tick if the player is in combat. | `worldbuff.auto_logout` |
| **WBF-09** | Floating Timer Frame (HUD) | Draggable, semi-transparent HUD showing active cooldowns for all 4 dragon buffs (`[A] Onyxia`, `[A] Nefarian`, `[H] Onyxia`, `[H] Nefarian`) in remaining minutes (`<45m>`) or `<None>`. Position is persisted in `worldbuff.timer_pos`. | `worldbuff.timer`, `worldbuff.timer_pos` |
| **WBF-10** | Right-Click Share Menu | Right-clicking the timer frame opens a dropdown menu to broadcast current buff cooldown status to Say, Yell, Guild, Party, Raid, Hardcore, or any custom joined chat channels. | UI Context Menu |

#### 4.9 Quest Automation Modules (`quest/auto_accept_sharing.lua`, `quest/quest_automation.lua`)
**Primary Objective:** Streamline quest acquisition, dialogue progression, and quest turn-ins with zero clicks while strictly safeguarding player choices and preventing accidental quest or reward selections.

| Feature ID | Feature Name | Description | Configuration Key |
| :--- | :--- | :--- | :--- |
| **QST-01** | Auto-Accept Shared Quests | Listens to `QUEST_SHOW` events and hooks `StaticPopup_OnShow` for popup type `QUEST_ACCEPT`. Automatically calls `ConfirmAcceptQuest()` and dismisses the modal dialog. | `quest.accept_sharing` |
| **QST-02** | Auto-Accept Available Quests | Intercepts available quest offerings (`QUEST_DETAIL`, `QUEST_GREETING`, and `GOSSIP_SHOW`). Automatically invokes `AcceptQuest()` or selects available quest indices using native 1.12 C-APIs without artificial UI clicks. | `quest.auto_accept` |
| **QST-03** | Auto-Complete Finished Quests | Automates quest progression through `QUEST_PROGRESS` (invoking `CompleteQuest()` if `IsQuestCompletable()`) and `QUEST_COMPLETE`. Intercepts `GOSSIP_SHOW` and `QUEST_GREETING` to automatically select ready-to-turn-in quests. | `quest.auto_complete` |
| **QST-04** | Multi-Reward Safety Net | Protects player gear choices: <br>- When a quest offers **0 choices** (money/fixed items only) or **exactly 1 choice**, automatically claims the reward via `GetQuestReward(1)`. <br>- When a quest offers **multiple reward choices (> 1)**, auto-completion is **halted** by default to allow manual player inspection, unless an explicit reward choice is matched in the custom turn-in rules. | Safety Architecture |
| **QST-05** | Single-Option Gossip Auto-Skip | When conversing with an NPC with **no available/active quests** and **exactly one gossip option** (e.g. Flight Master taxi map, Banker vault, single-line lore triggers), automatically selects that option via `SelectGossipOption(1)`. | `quest.skip_gossip` |
| **QST-06** | Gossip Skip Blacklist | Configurable blacklist of NPC names or substrings that should **never** be auto-skipped (e.g. Battlemasters, Class/Talent Trainers, Innkeepers), preventing accidental teleportation, respec dialogs, or taxi departures. | `quest.skip_gossip_blacklist` |
| **QST-07** | Custom & Repeatable Turn-in Rules | Dedicated support for reputation repeatable turn-ins (e.g. Thorium Brotherhood, Argent Dawn tokens, ZG Bijous/Coins, Timbermaw, BG Marks). Allows defining specific quests with designated reward indices (1–4) for rapid turn-ins. | `quest.custom_turnin_rules` |
| **QST-08** | Alt-Key Temporary Bypass | Holding the `Alt` key (`IsAltKeyDown()`) temporarily disables all quest and gossip automation, allowing manual inspection of dialogue, rewards, or quest objectives without toggling addon settings. | Automated (`Alt` key) |

##### 4.9.1 Technical Architecture & Comparison with Legacy Addons (Automatonex)

Unlike legacy implementations (such as `Automatonex/QuestAutomation.lua`), which exhibit brittle frame scraping and global namespace pollution, OzAiO's Quest Automation adheres to clean architectural principles:

1. **Native 1.12 C-APIs vs. Fragile UI Button Scraping**:
   - *Legacy Flaw:* Loops through `GossipTitleButton1..32` and `QuestTitleButton1..32`, scraping `.type` and text, calling `:Click()` on UI buttons. This breaks under custom UI reskins (pfUI, ModUI, ElvUI) and risks frame script recursion.
   - *Oz-Optimized:* Utilizes Blizzard's native 1.12 C-APIs directly:
     - **Gossip:** `GetNumGossipAvailableQuests()`, `SelectGossipAvailableQuest(i)`, `GetNumGossipActiveQuests()`, `SelectGossipActiveQuest(i)`, `GetNumGossipOptions()`, `SelectGossipOption(i)`.
     - **Greeting:** `GetNumAvailableQuests()`, `SelectAvailableQuest(i)`, `GetNumActiveQuests()`, `SelectActiveQuest(i)`.
     - **Completion:** `IsQuestCompletable()`, `CompleteQuest()`, `GetNumQuestChoices()`, `GetQuestReward(choiceIndex)`.

2. **Non-Disruptive Quest Log Cache**:
   - *Legacy Flaw:* Invokes `SelectQuestLogEntry(i)` in a loop during `QUEST_LOG_UPDATE`, which changes the player's active quest log selection and disrupts the quest log UI.
   - *Oz-Optimized:* Reads the 7th return value of `GetQuestLogTitle(i)` (`isComplete`) without mutating log selection, maintaining a lightweight hash cache of completed quest titles in memory.

3. **Multi-Reward Protection Architecture**:
   - Never auto-picks arbitrary items when gear decisions exist. Automatically completes zero-choice or single-choice quests, but leaves multi-choice equipment rewards open for deliberate player choice unless defined in `quest.custom_turnin_rules`.

4. **Single-Tick Debounce & State Protection**:
   - Employs a single-tick debounce (`OzHook` / 1-frame dispatch) to prevent event bouncing or re-trigger loops when NPCs trigger back-to-back gossip and greeting frames.

5. **Non-Intrusive Popup Handling**:
   - Replaces raw global overwrites of `StaticPopup_OnShow` with clean `OzHook` or event-driven `QUEST_ACCEPT` confirmation, preserving Blizzard static popup stack integrity.

---

### 5. Configuration & Persistence Specification

#### 5.1 SavedVariables Architecture
All configuration data is stored per-character via `OzAiO.TOC` entries:
```lua
## SavedVariablesPerCharacter: OZAIO, OZAIO_CONFIG
```

1. **`OZAIO` (Global State Table):**
   - `minimap_angle`: Integer/float angle (0–360°) for minimap button positioning.
   - `info_level`: Console logging verbosity (`"default"`, `"debug"`, `"error"`).
   - `config_size`: Table `{ width, height }` persisting custom resizable window dimensions.

2. **`OZAIO_CONFIG` (Module Settings Table):**
   A flat key-value dictionary where every key strictly follows `<module>.<setting_in_snake_case>` format:
   ```lua
   OZAIO_CONFIG = {
       -- General
       ["general.font_size"] = 14,
       ["general.auto_dismount"] = true,
       ["general.auto_stance"] = true,

       -- Bag & Vendor
       ["bag.sell_junk"] = true,
       ["bag.auto_buy"] = false,
       ["bag.auto_buy_list"] = { [17020] = 20 },  -- itemID = targetQty
       ["bag.auto_sell"] = false,
       ["bag.auto_sell_list"] = { [2589] = true }, -- itemID = true

       -- Loot
       ["loot.auto_roll_enable"] = true,
       ["loot.zg_bijous_action"] = "need",
       ["loot.zg_coins_action"] = "need",
       ["loot.cot_items_action"] = "need",
       ["loot.announce_roll"] = true,

       -- Spells
       ["spell.auto_update_rank"] = true,

       -- Chat
       ["chat.hc_channel_num"] = 1,
       ["chat.short_channel_name"] = true,
       ["chat.broadcast_enable"] = false,
       ["chat.broadcast_interval"] = 2,            -- minutes (e.g. 1 to 15, default 2)
       ["chat.broadcast_channel"] = "YELL",
       ["chat.broadcast_message"] = "",
       ["chat.broadcast_combat_pause"] = true,

       -- Minimap
       ["minimap.hide_system_buttons"] = true,

       -- SuperWoW
       ["superwow.auto_loot"] = true,
       ["superwow.click_through"] = false,
       ["superwow.shift_loot"] = false,
       ["superwow.fov"] = 1.5,
       ["superwow.background_sound"] = true,
       ["superwow.selection_circle_style"] = 1,
       ["superwow.loot_sparkle"] = true,
       ["superwow.uncapped_sounds"] = true,

       -- World Buff
       ["worldbuff.enabled"] = true,
       ["worldbuff.countdown"] = true,
       ["worldbuff.sound"] = true,
       ["worldbuff.hearthstone"] = true,
       ["worldbuff.timer"] = true,
       ["worldbuff.guild"] = false,
       ["worldbuff.auto_logout"] = false,
       ["worldbuff.timer_pos"] = { 100, 300 },      -- { leftOffset, bottomOffset }

        -- Quest & Dialogue Automation
        ["quest.accept_sharing"] = true,
        ["quest.auto_accept"] = true,
        ["quest.auto_complete"] = true,
        ["quest.skip_gossip"] = false,
        ["quest.skip_gossip_blacklist"] = {
            ["Battlemaster"] = true,
            ["Innkeeper"] = true,
            ["Spirit Healer"] = true,
        },
        ["quest.custom_turnin_rules"] = {},
   }
   ```

---

### 6. Non-Functional Requirements & Performance SLAs

#### 6.1 Performance & Frame Budgeting (60 FPS Guardrails)
- **Zero-Block Action Bar Scanning:** Vanilla 1.12 `GameTooltip:SetAction` causes micro-freezes if executed across 120 slots in a single frame. The spell module is limited to **1 slot per frame** inside `OnUpdate`.
- **Tooltip Flicker Elimination:** Mount detection in `oz_general` checks raw buff icon texture strings rather than scanning tooltips via `SetPlayerBuff`. This eliminates cursor hide/show flicker.
- **Consolidated Ticker:** The world buff module consolidates timekeeping, countdown animations, auto-logout checks, and network sync into a **single centralized `OnUpdate` ticker frame**, minimizing script execution overhead.
- **Bag Snapshot Caching:** Vendor planning creates an in-memory inventory snapshot upon `MERCHANT_SHOW` and only invalidates upon `BAG_UPDATE`, eliminating repetitive bag loop iterations.

#### 6.2 Compatibility & Interoperability Matrix
| Target Addon / System | Relationship | Compatibility Handling |
| :--- | :--- | :--- |
| **SuperWoW DLL** | Hardware Enhancement | Full support: guarded by `if not SUPERWOW_VERSION then return end`. |
| **Turtle WoW (tWOW)** | Private Server Core | Full support: detects build > 6000; hides custom frames; supports custom mount textures. |
| **pfUI / ShaguTweaks** | Monolithic UI Suites | Conflict Avoidance: `oz_general` listens on `PLAYER_LOGIN` and unregisters Auto Dismount / Auto Stance if `pfUI` or `ShaguTweaks` are loaded. |
| **WorldBuffsTracker** | World Buff Addon | Wire Compatibility: Shared `TWB` channel protocol (`SyncS:`, `Lightning:`) ensuring data interoperability. |

#### 6.3 Internationalization (i18n)
- Native support for **English (`enUS` / `enGB`)** and **Simplified Chinese (`zhCN`)**.
- Metatable-driven localization dictionaries with transparent fallback to English keys.
- Automatic font routing: selects `ARIALN.TTF` for Chinese clients and `FRIZQT__.TTF` for Western clients.

---

### 7. File & Package Inventory

| File Path | LOC | Purpose |
| :--- | :--- | :--- |
| [OzAiO.TOC](file:///d:/proj/wow_addon/OzAiO/OzAiO.TOC) | 24 | Addon metadata, load order, saved variables declaration |
| [core/framework.lua](file:///d:/proj/wow_addon/OzAiO/core/framework.lua) | 316 | Framework core, module registration, settings UI dialog, minimap button |
| [core/ozapi.lua](file:///d:/proj/wow_addon/OzAiO/core/ozapi.lua) | 4 | Public API table definition |
| [lib/lib.lua](file:///d:/proj/wow_addon/OzAiO/lib/lib.lua) | 82 | Utility functions (printing, argument validation, currency, quality colors) |
| [lib/libhook.lua](file:///d:/proj/wow_addon/OzAiO/lib/libhook.lua) | 229 | Non-intrusive pre/post hook engine |
| [lib/configuihelper.lua](file:///d:/proj/wow_addon/OzAiO/lib/configuihelper.lua) | 857 | Unified scrollable panel layout engine, widget templates, theming |
| [general/general.lua](file:///d:/proj/wow_addon/OzAiO/general/general.lua) | 378 | `/rl` command, font scaler, auto dismount, auto stance |
| [bag/merchant.lua](file:///d:/proj/wow_addon/OzAiO/bag/merchant.lua) <br> [bag/clam_opener.lua](file:///d:/proj/wow_addon/OzAiO/bag/clam_opener.lua) <br> [bag/unlock.lua](file:///d:/proj/wow_addon/OzAiO/bag/unlock.lua) | 1000 | Vendor automation (junk, custom sell/buy), clam opener, Rogue lockpicking |
| [loot/auto_roll.lua](file:///d:/proj/wow_addon/OzAiO/loot/auto_roll.lua) | 300 | Automated loot roll (ZG Bijous/Coins, CoT Corrupted Sand) & BoP confirm |
| [spell/update_spell_lvl.lua](file:///d:/proj/wow_addon/OzAiO/spell/update_spell_lvl.lua) | 240 | Action bar rank auto-updater, manual rank sweep |
| [chat/chat_core.lua](file:///d:/proj/wow_addon/OzAiO/chat/chat_core.lua) <br> [chat/chat_short_channel_name.lua](file:///d:/proj/wow_addon/OzAiO/chat/chat_short_channel_name.lua) <br> [chat/chat_hc_window.lua](file:///d:/proj/wow_addon/OzAiO/chat/chat_hc_window.lua) <br> [chat/auto_message.lua](file:///d:/proj/wow_addon/OzAiO/chat/auto_message.lua) | 350 | Chat filter pipelines, short channel names, HC redirect, periodic auto broadcaster with item link resolution |
| [minimap/hide_sys_button.lua](file:///d:/proj/wow_addon/OzAiO/minimap/hide_sys_button.lua) | 99 | Minimap button decluttering (Blizzard + Turtle WoW) |
| [general/superwow.lua](file:///d:/proj/wow_addon/OzAiO/general/superwow.lua) | 372 | SuperWoW CVars, SuperAPI hooks (spell/quest linking, mouseover) |
| [general/worldbuff.lua](file:///d:/proj/wow_addon/OzAiO/general/worldbuff.lua) <br> [general/worldbuff_hud.lua](file:///d:/proj/wow_addon/OzAiO/general/worldbuff_hud.lua) | 900 | World buff detection, TWB sync, timer HUD, alert countdown, hearthstone |
| [quest/auto_accept_sharing.lua](file:///d:/proj/wow_addon/OzAiO/quest/auto_accept_sharing.lua) <br> [quest/quest_automation.lua](file:///d:/proj/wow_addon/OzAiO/quest/quest_automation.lua) | 350 | Shared quest auto-accept, NPC quest accept/complete automation, single gossip skip |

---

### 8. Verification & Test Strategy

| Test Area | Scenario | Expected Behavior |
| :--- | :--- | :--- |
| **Framework: Window Resize** | Drag bottom-right corner grabber handle. Test below 500x420 and above 900x850. Reload UI. | Window resizes smoothly; content scroll area expands/contracts; minimum (500x420) and maximum (900x850) bounds are enforced; dimensions persist across `/rl`. |
| **Framework: Fixed Categories** | Click through all 8 left panel tabs: General, Chat, Minimap, Quest, Actionbar, Buff, Bag, Loot. | Each tab activates its unified category viewport without frame collisions; right-hand scrollable container displays all registered category features. |
| **Framework: Table Schema UI** | Register a module via `OzFramework:registerMod` with an Automaton-style options schema table. | Checkboxes (`toggle`), sliders (`range`), dropdowns (`select`), buttons (`execute`), and editboxes (`text`) render automatically without manual layout math. |
| **Libraries: Cross-Addon Isolation** | Load a second addon that also embeds `OzHook` and `OzUIHelper`. | Both addons hook globals without breaking wrappers; higher library version takes precedence; widget names and layout states do not collide. |
| **General: Dismount** | Mount up, sit down, cast a spell. | Player stands up immediately and cancels mount buff; spell cast initiates without error popup. |
| **General: Conflict** | Load alongside `pfUI`. | Chat prints detection message; Auto Dismount & Stance handlers yield without error. |
| **Bag: Auto Sell/Buy** | Open vendor with grey items and configured auto-buy items. | Grey items sell automatically at 0.2s intervals; buy orders execute until target quotas are satisfied; chat reports net cost. |
| **Loot: Auto Roll** | In group/raid with ZG Bijous, ZG Coins, or CoT Corrupted Sand dropping. | Automatically selects configured action (Need/Greed/Pass), auto-confirms BoP popups if enabled, and outputs audit note to chat. |
| **Spell: Auto Update** | Train rank 2 of an ability currently on action bar slot 1. | System detects learn message; slot 1 automatically upgrades to rank 2; chat logs upgrade notification. |
| **Spell: Spellbook Tag** | Open Spellbook with Fireball rank 1 on bar and Frostbolt unassigned. | Fireball text displays red; Frostbolt text displays default yellow. |
| **World Buff: Test** | Execute `/ozwb onyxia`. | Screen displays pulsing countdown bar; alert audio plays; emergency hearthstone button appears for 10s. |
| **World Buff: Sync** | Join `TWB` channel with other clients online. | Receives `SyncS:` messages; timer HUD reflects active dragon buff minutes remaining; right-click dropdown shares to chat. |
| **Quest: Shared Quests** | Party member shares a quest; test with and without holding Alt. | Automatically accepted without prompt when Alt is released; prompt appears normally when Alt is held down. |
| **Chat: Auto Message** | Enter message with `[Item Name]` or pasted Shift-link, select channel (e.g. `YELL` or `Trade`), interval 2m. | Ticker dispatches message at interval; item names convert to interactive colored links; pauses in combat; test button sends immediately. |
| **SuperWoW: Macro** | Open macro window with SuperWoW active. | Character counter shows `X/511`; editor accepts macros longer than 255 characters. |

---

### 9. Future Roadmap & Extensibility

1. **Additional World Buffs:**
   - Extend `general/worldbuff.lua` to track Zul'Gurub (Heart of Hakkar), Warchief's Blessing (Rend Blackhand), Songflower Serenade (Felwood), and Darkmoon Faire Sayge buffs.
2. **Public API Expansion (`core/ozapi.lua`):**
   - Provide formal export functions for external unit frames and raid frames to query OzAiO's world buff timers and bag reagent thresholds.
3. **Automated Equipment Repair:**
   - Add automated repair (guild bank or personal funds) into `bag/merchant.lua` upon vendor visit.
4. **Enhanced Mailbox Automation:**
   - Provide one-click mailbox collecting and batch mailing under a dedicated `oz_mail` module.
5. **UI Layout Engine Modernization (`OzUIHelper`):**
   - Refactor `lib/configuihelper.lua` to deprecate the separate `flow` cursor engine and migrate module panels to the unified `ScrollPanel` architecture (`panel:Add()` vertical auto-stacking + `panel:AddRow()` for horizontal groups).
   - Implement frame recycling pools for dynamic item lists (`makeScrollItemList`) to eliminate uncollectable frame allocation churn.
