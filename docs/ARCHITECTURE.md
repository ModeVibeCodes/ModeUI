# ModeUI architecture

How the addon is laid out and how every module is built. This is a living
document: add to it when a new idea or module changes the shape of things.
`tests/structure.lua` enforces the parts that can be checked mechanically.

> **Status (November 12, 2026):** the target layout below is being adopted in
> phases (see [Restructure phases](#restructure-phases)). The shared code lives in
> `Libs/` and `Shared/`, and the Runtime services, Domain readers and Kit builders below are in place. Until
> phase 5, the modules (Unit Frames, Profiles, Optimizations, Class Colors) are
> still flat `Modules/*.lua` files with their pages in `Config/`, listed as legacy
> in `tests/structure.lua`. New code goes in the new layout only.

## Folder layout

```
ModeUI/
  ModeUI.toc                  Libs, then Shared, then one XML line per module
  Libs/                       third-party libraries (LibStub, CallbackHandler, LibSharedMedia)
  Media/                      fonts and textures only; no code
  Shared/                     code used by more than one module
    Runtime/                  the core every other file depends on
      Core.lua                addon table, edition check, version, secret-safe helpers
      DB.lua                  ModeUIDB defaults, schema check, runs module migrations, PTG import
      Lifecycle.lua           module registry: register, initialize, enable, disable, combat broadcast
      Events.lua              shared game-event dispatcher
      Callbacks.lua           internal messages between modules (CallbackHandler-1.0)
      Defer.lua               out-of-combat queue for protected frame work
      Locale.lua              string table (English now)
      Feedback.lua            chat output (PrintAction)
      Reload.lua              reload requests and prompt state
      Boot.lua                ADDON_LOADED startup sequence; always the last file loaded
    Forever/                  client adapters (reload, secret checks, curve constants)
    Domain/                   game-data readers; the only code that calls Unit* APIs
    Kit/                      frame builders: bars, text with lifted shadow, icons, gradients
    Border/                   pixel borders
    Media/                    media registry and discovery (code; assets stay in ModeUI/Media)
    Placement/                positions, Edit Mode, Preview, frame anchors
    Skin/                     re-skinning Blizzard frames in the Mode look
    Settings/                 settings window framework (window, pages, search, tabs)
      Widgets/                one file per widget kind
    Templates/                XML virtual templates, added when a module needs one
  Modules/
    <Name>/
      <Name>.xml              loads this module's files; listed once in ModeUI.toc
      Init.lua                declares and registers the module (always loaded first)
      Driver.lua              lifecycle hooks and core logic
      Settings.lua            the module's settings page, built only when opened
      ...                     more files split by responsibility (Layout, Build, Update, Migrations)
```

### Dependency direction

Each layer may use the layers above it, never the ones below:

```
Libs  →  Shared/Runtime  →  Shared/Forever  →  Shared/Domain, Kit, Border, Media
      →  Shared/Placement, Skin  →  Shared/Settings  →  Modules/<Name>
```

- **Modules never use another module's files.** If two modules need the same
  thing, it moves into `Shared/`. Modules talk to each other only through
  `Callbacks` messages.
- **Shared never names a module.** Runtime loops over the registry; it never
  reaches for `addon.UnitFrames` or any other module directly.

## Load order

WoW's TOC can't use wildcards, so the order is explicit:

1. `Libs/` files.
2. `Shared/Runtime/Core.lua`, then `Shared/Forever/`, then the rest of `Runtime`.
3. `Domain`, `Kit`, `Border`, `Media`, `Placement`, `Skin`, then the `Settings` framework.
4. One `Modules\<Name>\<Name>.xml` line per module, in sidebar order.
5. `Shared/Runtime/Boot.lua`, last.

A module's XML loads `Init.lua` first and then the rest, with paths relative to
the XML file:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="Init.lua"/>
    <Script file="Migrations.lua"/>
    <Script file="Driver.lua"/>
    <Script file="Layout.lua"/>
    <Script file="Settings.lua"/>
</Ui>
```

`tests/harness.lua` follows `<Script file>` and `<Include file>` the same way the
client does. It rejects any other XML element, so it never quietly skips code.
It will learn `Templates/` frames when the first template is added.

## The module contract

Every module is a folder with the same shape.

### `Init.lua`: what the module is

Declarative only. It builds the module table, declares its constants and
registers it. It creates no frames and registers no events.

```lua
local _, addon = ...
local L = addon.L
local M = {
    title = L["Unit Frames"],
    category = "interface",
    defaultEnabled = true,
}
addon.UnitFrames = M
addon:RegisterModule("unitFrames", M)
-- defaults, ranges, choice lists and other constants follow
```

The module ID (`"unitFrames"`) is also its saved-variable key and must never
change once released.

### `Driver.lua`: what the module does

The lifecycle hooks Runtime calls. Every hook is optional.

| Hook | Called when | Rules |
|---|---|---|
| `OnInitialize()` | once, after `ModeUIDB` is ready | validate and migrate `self.db`; no protected frames yet |
| `OnEnable()` / `OnDisable()` | the module switch changes, and at startup | protected work goes through `Defer` |
| `OnCombatStateChanged(inCombat)` | entering and leaving combat | |
| `SetEditMode(on)` / `SetPreviewMode(on)` | Edit Mode or Preview changes | only outside combat |
| `Refresh()` | settings or media changed | must be safe to call repeatedly |
| `CreateConfigPage(parent)` | the settings page is opened for the first time | lives in `Settings.lua` |

### Other files

Anything bigger than a few functions gets its own file, named for its job:
`Migrations.lua`, `Layout.lua`, `Build.lua`, `Update.lua` and so on. Every file
attaches to the same module table (`local M = addon.UnitFrames`).

**Line budget:** 400 lines per file, outside `Libs/`. Split at the budget and
aim for under 300. The structure test fails on new files over the budget.

## Settings load on demand

The settings code ships inside each module, but none of it runs until the user
opens it:

- `Settings.lua` only defines `M:CreateConfigPage(parent)`. Loading it creates
  no frames.
- The settings window is built the first time `/modeui` opens it.
- Each module's page is built the first time it's selected, or the first time a
  settings search needs its entries.
- `tests/smoke.lua` asserts that no window exists before `/modeui`.

WoW still reads every Lua file listed in the TOC at login. That costs very little
compared with building frames. Real `LoadOnDemand` would need a separate
`ModeUI_Options` addon folder, and that can't hold files from inside each module
folder. We keep the settings inside the module and build pages lazily.

## Runtime services

All in `Shared/Runtime/`, loaded in this order:

| File | Job | API |
|---|---|---|
| `Core.lua` | edition gate and the secret-safe checks every file shares | `addon.IsPublic(v)`, `addon.IsNumber(v, low, high)`, `addon.InCombat()`, `addon.Edition:CheckClient()` |
| `Locale.lua` | user-facing text | `addon.L["English text"]`, `addon:RegisterLocale("deDE", strings)` |
| `Events.lua` | one frame for game events | `addon.Events:On(owner, event, handler)`, `:Off(owner, event)`, `:OffAll(owner)`, `:IsOn(owner, event)`; handlers get `(event, ...)` |
| `Callbacks.lua` | messages between modules and services | `addon.RegisterMessage(owner, message, fn)`, `addon.UnregisterMessage(owner, message)`, `addon:SendMessage(message, ...)`; names in `addon.Messages` |
| `Defer.lua` | work that must wait for the end of combat | `addon.Defer:Run(key, fn)` (now, or queued in combat), `:Queue(key, fn)`, `:Cancel(key)`, `:IsQueued(key)`; the latest task per key wins and the queue runs on `PLAYER_REGEN_ENABLED` |
| `Feedback.lua` | chat output, throttled and never from restricted code | `addon:PrintAction(message, key)` |
| `ProfileCodec.lua` | bounded copy, export and import of settings tables | `addon.ProfileCodec.Copy(value)` and friends |
| `DB.lua` | `ModeUIDB`: defaults, schema check and migration, never reset; each module's `Initialize(db)` validates its own settings; one-time PTG import | `addon:InitializeDatabase()`, `addon.Database` |
| `Profiles.lua` | account-wide named profiles; switching applies on reload | `addon.Profiles` |
| `Reload.lua` | reload requests and the reasons shown to the user | `addon.ReloadManager:Request(key, reason)`, `:Clear(key)`, `:Reload()` |
| `Lifecycle.lua` | categories and the module registry; enable/disable; combat broadcast | `addon:RegisterCategory(id, def)`, `addon:RegisterModule(id, module)`, `addon:SetModuleEnabled(id, on)`, `addon:BroadcastCombatState(inCombat)` |
| `Boot.lua` | the startup sequence on `ADDON_LOADED`, then `/modeui`; always the last file | |

Messages in use (`addon.Messages`):

| Name | Arguments | Sent when |
|---|---|---|
| `MODULE_TOGGLED` | `id, enabled` | a module was switched on or off; Edit Mode and the settings window refresh |
| `CLASS_COLORS_CHANGED` | | Class Colors changed; class-colored modules redraw |

Notes:

- **Events:** a frame's `RegisterUnitEvent` filters to at most two units. Events
  that filter by unit stay on a frame owned by the code that needs them. Plain
  events share the one frame.
- **Callbacks:** handler order isn't guaranteed, so a listener must not depend
  on another listener having run.
- **Defer:** combat runs from `PLAYER_REGEN_DISABLED` to `PLAYER_REGEN_ENABLED`.
  The queue runs before the Placement refresh and before modules hear
  `OnCombatStateChanged(false)`.
- **Locale:** keys are the English strings, so a missing translation shows
  English. Saved settings store IDs (`"sky"`, `"left"`), never labels, so a
  language change never affects saved data. Translations go in
  `Shared/Locale/<code>.lua`, loaded after `Shared/Runtime/Locale.lua`.

## Domain and Kit

`Shared/Domain/` reads game data. It's the only code that calls `Unit*` APIs,
and every call is guarded: a missing API, an error or a secret answer counts as
"unknown". Values that may be secret are returned only so they can go straight
to widgets documented as accepting them.

| File | API |
|---|---|
| `Query.lua` | `Domain.Query.Call(fn, ...)`, `.Truthy(fn, ...)`, `.Plain(fn, ...)` |
| `Health.lua` | `Domain.Health.Read(unit)` → okMax, max, okValue, value (secret); `.Percent(unit, curve)`; `.State(unit)` → `"Offline"`, `"Ghost"`, `"Dead"` or nil |
| `Power.lua` | `Domain.Power.Read(unit)` → powerType, token, okMax, max, okValue, value; `.Percent(unit, powerType, curve)`; `.Color(token)` |
| `Name.lua` | `Domain.Name.Get(unit)` → name (may be secret) or `""` |
| `Level.lua` | `Domain.Level.Text(unit)` → `"60"`, `"60+"`, `"??"` or `""` |
| `UnitColor.lua` | `Domain.UnitColor.Class(class)`, `.NativeClass(class)`, `.PlayerClass(unit)`, `.Reaction(unit)` → `"tapped"`, `"hostile"`, `"neutral"`, `"friendly"`; `.SetClassOverride(fn)` (Class Colors supplies the custom colors) |
| `Portrait.lua` | `Domain.Portrait.Apply(icon, unit, style)`, `.SetIcon(icon, path)`, `.Exists(unit)` |

`Shared/Kit/` builds frame pieces in the Mode look. It holds no game data.

| File | API |
|---|---|
| `Color.lua` | `Kit.Tint(region, color, alpha)`, `.Lighten(color, t)`, `.Scale(color, f)`, `.Gradient(texture, top, bottom, alpha)`, `Kit.FLAT` |
| `Shape.lua` | `Kit.PixelSize(frame)`, `.Bar(parent)`, `.Circle(frame, layer, sublevel)`, `.Inset(texture, host, inset)`, `.Rounded(texture, key)` |
| `Text.lua` | the suite's text style: `Kit.Text(layer, drawLayer)`, `.Write(text, value)`, `.Formatted(text, pattern, ...)`, `.Font(text, style, size, path, px)`, `.LayoutLift(...)`, `.ValueText(text, mode, percentFn, unit, hasCurrent, current)`; `Kit.LIFT_PIXELS`, `Kit.LIFT_ALPHA` |

## Rules every module follows

- **Secret values.** Only `Shared/Domain` reads unit data. It returns secret
  values only for widgets documented as accepting them (StatusBar
  `SetMinMaxValues`/`SetValue`, FontString `SetText`/`SetFormattedText`). See
  `docs/API_COMPATIBILITY.md`.
- **Combat.** Secure frames are created, shown, moved and resized outside combat,
  through `Defer`.
- **Saved variables.** Each module owns `ModeUIDB.modules.<id>` and its position
  keys under `ModeUIDB.positions`. Keys never change without a migration, and
  migrations never reset data. The top-level `schemaVersion` changes only when
  the shared layout of `ModeUIDB` does.
- **Globals.** Only `ModeUIDB`, `SLASH_MODEUI1`/`SlashCmdList.MODEUI` and frame
  names that start with `ModeUI`.
- **Game-wide settings** (CVars, UI scale, loot) change only through the
  Optimizations module: each one is off by default, and turning it off puts back
  the game's previous value. Other modules never write them, and nothing rewrites
  the game-wide fonts.
- **APIs:** before building a module, write down every API it relies on, with a
  Forever source link, in `docs/API_COMPATIBILITY.md`. Don't assume Retail
  behavior applies to Forever.

## Module roadmap and what each one needs from Shared

Planned order after Unit Frames. Each entry lists what the module adds to
`Shared/`, so the shared pieces are designed once and reused. Every API family
named here still has to be verified against the Forever source before that
module is built.

| # | Module | Category | Adds to Shared | Things to research first |
|---|---|---|---|---|
| 0 | Unit Frames | Interface | Domain: Health, Power, Name, Level, UnitColor, Portrait. Kit: Bar, Text (lifted shadow), Circle, Gradient | done (native acceptance pending) |
| 1 | Nameplates | Interface | Domain: Cast, Auras, RaidIcon, Threat. Kit: Icon, Cooldown | what addons may change on nameplates in Forever; secret aura and cast data |
| 2 | Party Frames | Interface | Domain: Absorb, HealPrediction, Range, Role, Status (dead, offline, AFK), ReadyCheck. Templates: secure group header | secure group header attributes; range checks under secret rules |
| 3 | Action Bars | Interface | Kit: Button, Keybind text. Templates: secure action button. Placement: bar layouts | which action bar APIs and secure templates Forever ships |
| 4 | Chat Windows | Interface | Skin: chat frames, edit box, tabs. Kit: ScrollText | chat frame hooks that don't taint |
| 5 | Damage Meters | Interface | Domain: combat data source | whether Forever has a built-in damage meter API and what it exposes |
| 6 | Bags | Interface | Domain: Containers, Items. Kit: ItemButton. Templates: item slot | `C_Container` on Forever; secure use of items from addon buttons |
| 7 | Blizzard UI Windows | Interface | Skin: frame stripping, Mode borders, buttons, tabs, scroll bars | per-window taint risk; load-on-demand Blizzard addons |
| 8 | Minimap | Interface | Skin: minimap shape and border. Kit: addon-button collector | minimap APIs and cluster frames on Forever |

Every module gets design notes in `docs/<NAME>.md` (like `docs/UNIT_FRAMES.md`)
and an entry in the README's module table.

## Adding a module (once phase 3 lands)

1. Create `Modules/<Name>/` with `<Name>.xml`, `Init.lua` and `Driver.lua`.
   Add `Settings.lua` if it has a settings page.
2. Add `Modules\<Name>\<Name>.xml` to `ModeUI.toc`, after the Shared files and
   before `Shared\Runtime\Boot.lua`.
3. Pick an existing category, or register a new one in Runtime.
4. Put anything another module could use in `Shared/` instead of the module.
5. Record its APIs in `docs/API_COMPATIBILITY.md` and its design in
   `docs/<NAME>.md`.
6. Add tests, and run `tests/structure.lua`, `tests/smoke.lua` and
   `tests/unit_frames.lua`.

## Restructure phases

Each phase is one focused commit. All tests pass after every phase, with no
change to behavior, looks or saved data.

| Phase | Work | Status |
|---|---|---|
| 1 | This document, AGENTS.md rules, `tests/structure.lua`, XML support in the harness | done |
| 2 | Move files into `Libs/` and `Shared/*` with `git mv`; no code edits. The libraries now load before `Edition.lua` | done |
| 3 | Runtime: `Core.lua` (from `Edition.lua` and the copied secret checks), `DB.lua`, `Reload.lua`, `Lifecycle.lua` (from `Modules.lua`, `Categories.lua` and the combat broadcast in `DisplayModes.lua`); add Events, Defer, Callbacks, Locale | done |
| 4 | Domain and Kit: unit readers and frame builders out of `UnitFramesDisplay.lua` | done |
| 5 | Module folders: `Modules/UnitFrames/` (Init, Migrations, Driver, Layout, Build, Update, Settings), then `Profiles/`, `Optimizations/` and `ClassColors/` (Init, Driver, Settings) | planned |
| 6 | Split `Widgets.lua` and `Window.lua` into `Shared/Settings/Widgets/`; modules register their own page layout | planned |
| 7 | Module skeleton and the README "Adding a module" section | planned |

After phases 2–6, the in-game check is the same:

- **Navigation:** type `/modeui`, then pick **Interface** › **Unit Frames** in the sidebar.
- **Action:** switch the module off and on, open **Edit Mode**, move the Player
  frame, then `/reload`. **Edit Mode** is in the settings window header.
- **Required state:** out of combat, with a target selected.
- **Confirmation:** the frames look the same and sit where they did before.
