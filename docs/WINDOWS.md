# Interface: Windows

November 13, 2026. Sixth module of the **Interface** category (the roadmap's
"Blizzard UI Windows"). Off by default (turn it on with the switch in the page
header). Static/mock validated only; **native acceptance is pending**. APIs and
their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-chat-and-windows--november-13-2026).
Design canvas: https://claude.ai/artifact/E9m1Krqr6LXYaJJvjAUAPL (Windows artboard).

## What it does

ModeUI restyles Blizzard's windows in place. It never moves, sizes, shows or
hides a window, so Blizzard keeps opening, closing and placing them. Blizzard's
art is faded (alpha only); ModeUI's textures go on top.

| Part | Look |
|---|---|
| Frame | NineSlice pieces (one by one, so the Settings panel's title survives), parchment (`Bg`), `TopTileStreaks`, portrait, glow and the older corner and edge textures are faded. A fill (#0B0B0D at Background Opacity, 94%) inside a one-pixel rim (#25282C). |
| Title | A 22 px strip (#121316) over a one-pixel divider (#1E2024). Portrait-window titles are centered on the strip, clear of the close button; the title is Expressway 13 in #F2F2F2. Header and dialog titles (Game Menu, Settings) keep their place. |
| Close | An 18 px field with a thin cross, 3 px inside the top-right corner; the rim and cross turn cyan on hover. |
| Insets | A darker field (#0E0F11) on a #1E2024 rim. |
| Tabs | A 24 px field across each tab; the selected tab is the lighter segment (#22262B) with a 2 px cyan bar on its window side. Follows `PanelTemplates_SelectTab`/`DeselectTab` and TabSystem's `SetTabSelected`. Side tabs (Character, Collections, ...) get a field with a cyan rim when checked. |
| Buttons | Fields whose rim turns cyan on hover. |
| Fields | Edit boxes (`InputBoxTemplate`, search boxes): fields whose rim turns cyan with focus. |
| Scroll bars | `MinimalScrollBar` and `WowTrimScrollBar`: a 4 px track (#16181B) and thumb (#4A4F56); the arrows stay clickable but invisible. |

Controls are recognised by the keys their templates give them
(`Shared/Skin/Controls.lua`, `Skin.Kind`), six levels into each window, and
again each time the window shows, so lists Blizzard fills later are caught.
Text inside windows keeps the game's fonts: ModeUI never rewrites game-wide
font objects.

## Windows

Character, Spellbook and Talents, Professions, Social, Guild and Communities,
Group Finder, Collections, Achievements, World Map (rim and strip only: the
map draws under its border frame), Quests and Gossip, Merchant, Mail, Bank,
Trade, Inspect, Trainer, Auction House, Dressing Room, Pet Stable, Raid,
Macros, AddOn List, Game Menu and Game Settings. Each can be left out on the
**Windows** tab. Windows from load-on-demand Blizzard addons are skinned when
the addon loads (`ADDON_LOADED`).

Collections and Professions hold secure buttons. Windows like these are
skinned (and their close button placed) only outside combat, through `Defer`;
plain windows are skinned at once, in combat too.

## Settings

Tabs: **Look** (Status, Frame, Text, Controls, Defaults) and **Windows** (one
switch per window). Look changes repaint every skinned window right away.
Turning a window, a control kind or the module off brings Blizzard's art back
on the next reload; ModeUI asks for one.

Saved under `modules.windows` (version 1): `windows` (window ID → on),
`backgroundColor`, `backgroundOpacity`, `border`, `borderColor`, `titleBar`,
`font`, `fontMedia`, `titleSize`, `tabSize`, `outline`, `shadow`, `tabs`,
`buttons`, `fields`, `scrollBars`, `insets`.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the window registry, defaults, ranges |
| `Migrations.lua` | `Initialize(db)`: validation; fills in windows added later |
| `Driver.lua` | lifecycle, load-on-demand, skinning on show, settings |
| `Settings.lua` | the page |

The skinning itself is shared: `Shared/Skin/Frame.lua` (windows) and
`Shared/Skin/Controls.lua` (controls). Tests: `tests/windows.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Windows** in the sidebar.
- **Action:** turn the module on with the switch in the page header, then open
  the Social window, the Character window and Collections the way you
  normally do, and switch tabs in each.
- **Required state:** out of combat.
- **Confirmation:** each window has a dark fill with a thin rim, a title strip
  with a centered white title and a small square close button with a thin
  cross, no portrait or gold border; tabs are dark fields and the selected one
  is lighter with a cyan bar. Buttons light up cyan on hover. Closing and
  reopening keeps the look. No Lua errors, and no "blocked" messages when
  using toys or casting from the spellbook afterwards.
