# OzAiO (Oz All-in-One / Oz工具箱)

[![Interface](https://img.shields.io/badge/Interface-11200%20(1.12.1)-blue.svg)]()
[![Platform](https://img.shields.io/badge/Game-Turtle%20WoW%20%7C%20Vanilla-orange.svg)]()
[![SuperWoW](https://img.shields.io/badge/SuperWoW-1.5%20%26%202.2%2B-green.svg)]()

[English](#english) | [中文说明](#chinese)

---

<a name="english"></a>
## English Documentation

### Overview
**OzAiO (Oz All-in-One)** is a lightweight, modular, and high-performance quality-of-life suite built specifically for **World of Warcraft 1.12.1 (Vanilla)** and **Turtle WoW**, featuring native optimizations and optional capabilities for **SuperWoW (1.5 & 2.2+)**.

Designed under a strict non-intrusive paradigm, OzAiO provides essential modern conveniences without cluttering your screen, altering core gameplay aesthetics, or causing performance drops.

---

### Commands & GUI
- `/oz` — Open/close the modern unified Configuration GUI.
- `/rl` — Quick reload interface shortcut (`ReloadUI()`).
- **Minimap Button** — Left-click opens settings, right-click toggles World Buff HUD, drag to reposition around the minimap rim.

---

### Key Features

#### 1. General & Quality of Life
- **Quick Reload (`/rl`)**: Convenient slash command to reload the UI.
- **Global Font Scaling**: Adjust the base UI font size with a single slider. Automatically maps consistent scales across normal, small, large, and header fonts, as well as player/target unit frames.
- **Auto Dismount & Auto Stance**:
  - Automatically dismounts when attempting to cast spells or attack while mounted.
  - Automatically shifts into the required warrior or druid stance upon casting stance-restricted abilities.
  - *Conflict-Aware*: Automatically disables itself if pfUI or ShaguTweaks are detected.

#### 2. SuperWoW Native Integrations (1.5 & 2.2+)
- **Smart Autoloot**:
  - Instant autoloot upon opening loot windows.
  - Shift-only autoloot mode with state-debounced OnUpdate listeners.
- **511-Character Macro Editor**: Automatically extends macro script letter limits from 255 to 511 characters.
- **Field of View (FoV)**: Custom camera FoV slider (1.0 to 2.5 multiplier).
- **Selection Circle Styles**: Choose from 4 target indicator circle styles (Default, Full circle, Full circle with arrow, Classic oriented).
- **Background Sound & 64 Audio Channels**: Keep audio playing when WoW is minimized, and uncap sound channels to 64.
- **Loot Sparkle & Clickthrough Corpses**: Visual sparkles on lootable targets, and optional click-through dead corpses.
- **SuperWoW 2.2+ Exclusives**:
  - *Floating Healing Text*: In-world green healing numbers (guarded by client CombatText validation).
  - *Nameplate Motion*: Switch nameplate stacking (Default spread, Smart spread, Compact spread, Overlap).
- **SuperAPI Enhancements**:
  - Shift-click spellbook abilities to insert clickable spell hyperlinks into chat.
  - Shift-click quest log titles to insert clickable quest hyperlinks into chat.
  - Special negative item stack count indicator (`*` for stacks past -999).

#### 3. World Buff Timers & Automation
- **Multi-Buff Tracking**: Real-time server-synced countdowns for Onyxia, Nefarian, Hakkar, Rend Blackhand, and Darkmoon Faire.
- **Movable On-Screen HUD**: Minimalist, lockable countdown frame with channel broadcasting options.
- **Audio Voice Alerts**: 10-second vocal/sound countdown alerts prior to buff drops.
- **Automated Actions**:
  - Auto-Hearthstone when a tracked buff drops.
  - Auto-Logout after receiving buffs to preserve world buff duration for raid nights.

#### 4. Chat System Enhancements
- **Two-Stage Architecture**: Independent event-filter and display-filter pipelines.
- **Short Channel Names**: Shortens verbose prefixes (`[1. General]` -> `[G]`, `[2. Trade]` -> `[T]`, `[World]` -> `[W]`, etc.).
- **Hardcore Death Redirect**: Intercepts Turtle WoW Hardcore death notices and routes them exclusively to a chosen chat tab/window, keeping main chat clean.
- **Timed Broadcaster (Auto-Shout)**:
  - Configurable interval in minutes (1–15 mins).
  - Dynamic channel selector (Say, Yell, Guild, Party, Raid, World, Trade, etc.).
  - **Hybrid Item Link Resolution**: Type `[Item Name]` or shift-click gear; OzAiO automatically queries bags/cache and converts them into genuine clickable chat hyperlinks.
  - **Packet Splitting (>255 bytes)**: Automatically splits long messages exceeding 255 bytes at word boundaries without breaking hyperlink escape sequences.
  - **Combat Pause**: Temporarily suspends broadcast while in combat or dead.
  - Test button for instant preview.
- **Clickable Group Invites (Click2Inv)**: Converts trigger words (`1`, `111`, `inv`, `invite`, `组`) into clickable hyperlinks. Clicking instantly invites the player.
- **Shift-Click Player Names**: Shift-clicking a player name in chat inserts their formatted player link into the editbox instead of firing `/who`.
- **EditBox Tweaks (Optional)**: Move editbox to screen center with dynamic action bar dodging, and direct Up/Down arrow history navigation without holding Alt.

#### 5. Bags, Merchant & Rogue Unlock
- **Smart Merchant Automation**:
  - Auto-sell grey junk items with safety caps.
  - Custom auto-sell and auto-buy lists with fund and bag space verification.
  - Financial transaction audit summary printed in chat on vendor close.
- **Auto Clam Opener**:
  - Automatically opens clams (Big-mouth, Small Barnacled, Thick-shelled, Soft-shelled) with safe 0.5s intervals.
  - Gated against active trade, mail, bank, and combat windows.
- **Rogue Lockpicking Utilities**:
  - Adds an **"Unlock"** button to the trade frame; automatically casts Pick Lock and targets slot 7 ("will not be traded").
  - Right-click locked lockboxes directly in inventory to pick lock.

#### 6. Automated Reputation Loot Rolling
- **Zul'Gurub Tokens**: Configurable actions (`Need`, `Greed`, `Pass`, `Manual`) for all 9 ZG Bijous and 9 ZG Coins.
- **Caverns of Time**: Auto-roll for **Corrupted Sand** (ID 50203).
- **BoP Auto-Confirmation**: Automatically confirms the Bind-on-Pickup roll prompt for processed reputation items.

#### 7. Spell & Action Bar Auto-Upgrade
- **Automatic Spell Upgrade**: Detects newly learned spell ranks from trainers and instantly updates all matching action bar slots (1–120).
- **Budgeted Scanning**: Scans 1 slot per frame to eliminate micro-stutters.
- **One-Click Upgrade Sweep**: Manual button in settings to sweep and upgrade all down-ranked abilities on all bars.

#### 8. Quest & Gossip Automation
- **Auto-Accept & Complete**: Automatically accepts quests and completes zero-reward or single-reward quests.
- **Reward Safety Net**: Pauses automation on multi-choice gear rewards so you never pick the wrong equipment.
- **Custom Turn-in Rules**: Register specific reward choices for repeatable reputation turn-in quests.
- **Gossip Auto-Skip**: Skips single-option NPC gossip dialogs with an editable blacklist (Spirit Healers, Innkeepers, Battlemasters, etc.).
- **Daisy (Mirage Raceway) Fast-Pass**: Whitelisted bypass to immediately join the race without confirmation delays.
- **Bypass Modifier**: Hold **Alt** at any time to temporarily pause all quest automation.
- **Auto-Accept Quest Sharing**: Automatically accepts shared quests from party/raid members.

#### 9. Minimap Customization
- **Clean Minimap**: Toggle visibility of default Blizzard buttons (Tracking, Time/DayNight, Zoom, WorldMap).
- **Persistent Minimap Button**: Circular drag-and-drop button with saved angle position.

---

<a name="chinese"></a>
## 中文说明文档

### 插件概述
**OzAiO（Oz工具箱）** 是专为 **魔兽世界 1.12.1（香草时代）** 与 **乌龟服（Turtle WoW）** 量身定制的模块化全能增强插件。深度兼容并充分释放 **SuperWoW（1.5 及 2.2+）** 引擎底层能力。

秉持“非侵入式、极简高效、杜绝卡顿”的设计理念，在完全保留原版 UI 风格的同时，为玩家提供全方位的现代化便利体验。

---

### 常用命令与配置界面
- `/oz` — 打开/关闭统一设置管理面板。
- `/rl` — 快速重载插件及界面（`/reloadui` 快捷方式）。
- **小地图图标** — 左键打开设置，右键显示/隐藏世界 Buff 倒计时窗口，按住左键可环绕小地图边缘自由拖动。

---

### 核心功能模块

#### 1. 通用与基础体验
- **一键重载 (`/rl`)**：无需输入繁琐的 `/reloadui`。
- **全局字体统一调节**：滑动条即可按比例缩放系统标准字体、任务文本、聊天与头顶姓名板字体大小，解决高分辨率屏幕字体过小问题。
- **自动下坐骑与自动切姿态**：
  - 马上施法或攻击时自动解除坐骑。
  - 战士与德鲁伊施放限定姿态/形态的技能时，自动切换至所需姿态。
  - *冲突自动规避*：检测到 pfUI 或 ShaguTweaks 时自动停用，绝不产生逻辑冲突。

#### 2. SuperWoW 引擎深度增强（适配 1.5 与 2.2+）
- **极速自动拾取**：
  - 打开战利品窗口瞬间秒拾取。
  - 支持“仅在按住 Shift 键时自动拾取”模式，按键状态智能去抖，不浪费 CPU 周期。
- **511 字符宏突破**：将默认 255 字符的宏文本限制扩充至 511 字符。
- **视野范围调节 (FoV)**：1.0 至 2.5 倍超广视角倍率无缝调节。
- **目标脚下光圈样式**：提供 4 种样式选择（默认残环、完整圆环、带方向箭头的圆环、经典圆环）。
- **后台音频播放与 64 声道**：切换出游戏窗口时继续播放背景声音；解除声道上限至 64 通道。
- **尸体穿透与发光特效**：支持鼠标穿透已死亡尸体进行选怪或移动；可拾取目标显眼发光粒子。
- **SuperWoW 2.2+ 专属特性**：
  - *浮动治疗数字*：游戏世界中浮动显示绿色治疗量（内置战斗文字状态检测安全守卫）。
  - *姓名板堆叠排列模式*：支持默认分散、智能分散、紧凑堆叠、完全重叠 4 种模式。
- **SuperAPI 增强特性**：
  - Shift 点击法术书技能直接发送法术超链接到聊天框。
  - Shift 点击任务日志标题直接发送任务超链接到聊天框。
  - 支持负数物品堆叠显示特殊角标（超过 -999 显示 `*`）。

#### 3. 世界 Buff 计时与联动通知
- **多 Buff 实时追踪**：黑龙、奈法、哈卡、酋长祝福（雷德）、暗月马戏团倒计时全服同步精准追踪。
- **独立悬浮 HUD**：轻量化界面，支持右键快捷菜单、锁定位置与频道通报。
- **语音/音效提前预警**：Buff 落地前 10 秒语音与音效精准倒计时提醒。
- **智能化联动**：
  - 收到 Buff 落地通知时自动施放炉石。
  - 自动小退（Auto Logout）保护珍贵世界 Buff 持续时间，备战团本必备。

#### 4. 聊天系统全方位增强
- **双阶段流水线引擎**：独立事件过滤器与显示渲染管道，扩展性极高。
- **频道名缩写**：精简前缀（`[1. 综合]` -> `[综]`，`[2. 交易]` -> `[交]`，`[世界]` -> `[世]`，`[寻求组队]` -> `[组]`，`[硬核]` -> `[核]`）。
- **硬核死亡信息独立分流**：拦截乌龟服全服硬核死亡刷屏广播，分流至指定聊天标签页，还主聊天框清静。
- **定时广播喊话**：
  - 支持 1~15 分钟任意时间间隔。
  - 智能频道下拉框（大喊、公会、队伍、团队、交易、世界等）。
  - **混合装备超链接转换**：支持输入 `[物品名称]` 或直接 Shift 点击背包装备，自动转换为原汁原味的可点击装备超链接。
  - **超长消息分段发送 (>255 字节)**：自动校验字节长度，在不截断链接标签的前提下平滑拆分为多条依次发送。
  - **战斗暂停安全守卫**：进入战斗或死亡时自动静默挂起，脱战后继续。
  - 提供即时测试发送预览按钮。
- **点击求组快速邀请 (Click2Inv)**：将聊天中出现的常见求组关键词（`1`、`111`、`inv`、`求组`、`组我`）转换为青色可点击链接，点击即自动执行 `/invite 玩家名`。
- **Shift 点击玩家姓名链接**：输入框打开时，Shift 点击聊天框中的玩家姓名直接将其链接插入输入框，不再触发多余的 `/who` 查询。
- **输入框居中与免 Alt 翻历史 (可选)**：聊天输入框居中并自动避让底部动作条，支持无需按住 Alt 直接使用上下键翻阅历史输入记录。

#### 5. 背包、商人交易与盗贼开锁
- **智能商人交易自动化**：
  - 进店自动出售灰色垃圾物品。
  - 自定义黑白名单出售列表与补货购买列表，严格校验背包空间与金币余额，防止超买。
  - 离店在聊天框输出收支明细清单。
- **自动批量开蚌壳**：
  - 自动遍历背包开启各类蚌壳（黑珍珠、金珍珠、软壳、厚壳等）。
  - 0.5 秒安全间隔，并在开包、交易、银行与战斗中智能暂停，防卡防掉线。
- **潜行者开锁神器**：
  - 交易窗口直显 **"开锁"** 快捷按钮：自动施放开锁并精准点击第 7 格（不可交易栏位）。
  - 背包内右键点击上锁的重垃圾箱/铁皮箱，直接自动施法开锁。

#### 6. 自动化掷骰（祖尔格拉布 & 时光之穴）
- **ZG 宝石与硬币**：针对全部 9 种哈卡莱宝石与 9 种祖尔格拉布硬币，可单独预设 `需求`、`贪婪`、`放弃` 或 `手动`。
- **时光之穴声望道具**：自动掷骰 **腐蚀之沙** (ID 50203)。
- **拾取绑定弹窗自动确认**：处理上述配置物品时，全自动静默确认拾取绑定提示弹窗。

#### 7. 法术等级与动作条自动升级
- **学习新技能自动替换**：在训练师处学会更高等级技能时，自动搜寻动作条 1~120 格上的同名旧技能并无缝升级至最高等级。
- **平滑帧预算扫描**：每帧仅检测 1 个技能格，彻底杜绝单帧卡顿现象。
- **一键全技能升级扫频**：设置界面提供一键巡检按钮，瞬间将所有动作条技能更新至当前最高等级。

#### 8. 任务与对话全自动化
- **秒接与秒交任务**：与 NPC 对话自动接取任务，无奖励或唯一奖励任务自动交付。
- **多选一装备奖励安全网**：遇到多选一装备奖励时自动暂停，保留人工自选，绝不会选错装备。
- **重复交付声望任务自定义规则**：针对重复提交道具的任务，支持预设指定奖励项自动交付。
- **单选项 NPC 对话秒过**：单一选项自动点击，内置可编辑黑名单（灵魂医者、旅店老板、战场军官等）。
- **闪光平原赛车手黛西秒接**：针对千针石林闪光平原 NPC「黛西」定制赛车白名单，快速开跑不等待。
- **一键暂停快捷键**：在任何时候按住 **Alt** 键，可临时暂停所有任务自动化操作。
- **自动接受队友任务共享**：自动接收小队或团队成员分享的任务。

#### 9. 小地图系统优化
- **清爽小地图**：一键隐藏暴雪原版系统按钮（追踪图标、昼夜/时间、缩放按键、世界地图按钮）。
- **记忆位置小地图图标**：美观的统一控制入口，自由拖曳吸附并永久保存角度。

---

### Installation / 安装方法
1. Download the latest release or clone this repository.
2. Place the folder into your World of Warcraft directory:
   `Interface\AddOns\OzAiO`
3. Ensure the folder name is strictly `OzAiO` (do not rename to `OzAiO-master`).
4. Restart the game or log in to a character.

1. 下载最新发行包或克隆本仓库。
2. 将解压后的文件夹放入游戏目录：
   `Interface\AddOns\OzAiO`
3. 请确保文件夹名称必须是 `OzAiO`（不要包含 `-master` 等后缀）。
4. 启动游戏或进入角色列表即可生效。

---

### Compatibility / 兼容性说明
- **Client**: World of Warcraft 1.12.1 (Build 5875), Turtle WoW.
- **Engines**: SuperWoW 1.5 & SuperWoW 2.2+ (Vanilla non-SuperWoW clients are supported with graceful feature fallbacks).
- **UI Frameworks**: Fully compatible with pfUI, ShaguTweaks, Modui, and classic default Blizzard UI. OzAiO includes auto-conflict detection for frame anchors and chat components.

---

### License / 授权协议
Distributed under the MIT License. See `LICENSE` for more information.
Created with ❤️ by **Oz**.
