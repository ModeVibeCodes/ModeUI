# ModeUI architecture

How the addon is laid out and how every module is built. This is a living
document: add to it when a new idea or module changes the shape of things.
`tests/structure.lua` enforces the parts that can be checked mechanically.

> **Status (November 12, 2026):** the layout below is in place and all seven
> restructure phases are done. Every module is a folder with its own XML,
> `Init.lua` and `Driver.lua`, and every file is under the line budget. Folders
> marked "added with" don't exist yet; the first module that needs one creates it.

## Folder layout

```
ModeUI/
  ModeUI.toc                  Libs, then Shared, then one XML line per module
  Libs/                       third-party libraries (LibStub, CallbackHandler, LibSharedMedia)
  Media/                      fonts and textures only; no code
  Shared/                     code used by more than one module
    Runtime/                  the core every other file depends on
      Core.lua                edition check and the secret-safe IsPublic, IsNumber, InCombat
      DB.lua                  ModeUIDB defaults, schema check, runs module migrations, PTG import
      Lifecycle.lua           module registry: register, initialize, enable, disable, combat broadcast
      Events.lua              shared game-event dispatcher
      Callbacks.lua           internal messages between modules (CallbackHandler-1.0)
      Defer.lua               out-of-combat queue for protected frame work
      Locale.lua              string table (English now)
      ProfileCodec.lua        bounded copy, export and import of settings tables
      Profiles.lua            account-wide named profiles
      Feedback.lua            chat output (PrintAction)
      Reload.lua              reload requests and prompt state
      API.lua                 the read-only ModeUI-Core LibStub API (after Style)
      Boot.lua                ADDON_LOADED startup sequence; always the last file loaded
    Forever/                  client adapters; added with the first one a module needs
    Domain/                   game-data readers; the only code that calls Unit* APIs
    Style/                    the Mode design language: Tone, Assets, Fonts, ProviderMedia, Edge, Bar, Shield, Names, Icon (docs/DESIGN_LANGUAGE.md)
    Kit/                      frame builders: bars, text with lifted shadow, icons, gradients
    Media/                    media registry and discovery (code; assets stay in ModeUI/Media)
    Placement/                positions, Edit Mode (guides, nudging, grid, keeping stacks on screen), Preview, frame anchors, size matching (SizeMatch.lua: Match Width/Height follow a picked element, saved in the profile's sizeMatches)
    Skin/                     re-skinning Blizzard frames (Skin, Controls, Extras, Frame): Chat and Windows
    Settings/                 settings window framework (window, pages, search, tabs) and its launchers (game menu, minimap addon compartment)
      Widgets/                one file per widget kind (Core, Shape, Art, Text, Button, Switch, Header, Input, AnchorPicker, Nudge: `W.Nudge(parent, getX, getY, setX, setY, range)`, four 1px arrows)
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
Libs  →  Shared/Runtime  →  Shared/Forever  →  Shared/Domain  →  Shared/Style  →  Kit, Media
      →  Shared/Placement, Skin  →  Shared/Settings  →  Modules/<Name>
```

- **Modules never use another module's files.** If two modules need the same
  thing, it moves into `Shared/`. Modules talk to each other only through
  `Callbacks` messages.
- **Shared never names a module.** Runtime loops over the registry; it never
  reaches for `addon.UnitFrames` or any other module directly. `tests/structure.lua` fails any Shared file, or other module, that uses the table a module's `Init.lua` publishes (`addon.UnitFrames` and the like).

## Load order

WoW's TOC can't use wildcards, so the order is explicit:

1. `Libs/` files.
2. `Shared/Runtime/Core.lua`, then the rest of `Runtime` (and `Shared/Forever/` once it exists).
3. `Domain`, `Kit`, `Media`, `Placement`, `Border`, `Skin` (Skin, Controls, Extras, Frame), then the `Settings` framework.
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
defaults, and registers it. It creates no frames and registers no events.

```lua
local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

local L = addon.L
local M = { title = L["Unit Frames"], category = "frames", defaultEnabled = true,
    configDescription = L["Player and Target frames in the Onyx look. Configure outside combat."],
    -- The page keeps its own sections; the Mode layer restyles headings.
    modeLayout = { decorateOnly = true } }
addon.UnitFrames = M
addon:RegisterModule("unitFrames", M)
-- defaults, ranges, choice lists and other constants follow
```

Every other file of the module starts with:

```lua
local _, addon = ...
local M = addon.UnitFrames
if not M then return end
```

Module fields Runtime reads:

| Field | Meaning |
|---|---|
| `title` | sidebar and page title (through `L`) |
| `category` | a registered category ID: `"global"`, `"interface"` (Blizzard's own UI restyled) or `"frames"` (unit frames, nameplates, party frames) |
| `defaultEnabled` | `false` to start switched off on a fresh profile |
| `alwaysOn` | `true` for a module that can't be switched off (Profiles) |
| `configDescription` | the line under the page title |
| `modeLayout` | the page's Mode presentation plan, such as `{ decorateOnly = true }` |
| `standalone` | `true` for a module with its own settings window instead of a page in ModeUI's (the Cooldown Manager, `/mcdm`): no category, no sidebar entry or search results; it builds its window on demand, registers it with `addon:RegisterSettingsWindow(window)` so Edit Mode hides it and brings it back, and Edit Mode's Open Module Settings calls its `OpenSettings(elementId)` |
| `ptgImport` | `{ positions = { ... } }` to copy this module's settings (same ID) and those position keys from the active Play The Game Tools profile once, on ModeUI's first start (Unit Frames) |
| `Initialize(db)` | a plain function (not a method) that fills defaults, migrates and validates the module's settings, erroring on bad data. Profile validation calls it on detached copies, so it must not touch frames or other state |
| `Adopt(db, modules)` | optional, a plain function called before `Initialize(db)` on the same copy, with every module's saved settings by key (`modules`): a module that takes over settings another kept reads them here and writes only its own `db` (Buffs & Debuffs turns itself on when the Unit Frames Player frame showed auras) |

The module ID (`"unitFrames"`) is also its saved-variable key and must never
change once released.

### `Driver.lua`: what the module does

The lifecycle hooks Runtime calls. Every hook is optional. `self.db` is the
module's settings table and `self.enabled` its switch.

| Hook | Called when | Rules |
|---|---|---|
| `OnInitialize()` | once at startup, after `ModeUIDB` is ready, whether or not the module is on | call `self.Initialize(self.db)`; subscribe to messages; build no protected frames |
| `OnEnable()` / `OnDisable()` | the module switch changes, and at startup if it's on | build frames on first enable; protected work goes through `Defer` |
| `OnCombatStateChanged(inCombat)` | entering and leaving combat, while enabled | |
| `SetEditMode(on)` / `SetPreviewMode(on)` | Edit Mode or Preview changes | only outside combat |
| `CreateConfigPage(parent)` | the settings page is opened for the first time | lives in `Settings.lua`; returns the page |
| `OpenElementSettings(elementId)` | Edit Mode's **Open Module Settings**, after the page opens | for modules with several movable elements; shows that element's settings |

A module talks to others only through `addon.Messages`. For example, Unit
Frames redraws on `CLASS_COLORS_CHANGED` instead of Class Colors calling it.

### Other files

Anything bigger than a few functions gets its own file, named for its job.
Unit Frames, the largest module, has:

| File | Job |
|---|---|
| `Init.lua` | declaration, constants, defaults |
| `Migrations.lua` | `Initialize(db)`: validation and layout-version migrations |
| `Driver.lua` | lifecycle, settings changes, Blizzard's frames, events, secure refresh |
| `Layout.lua` | pixel-perfect geometry and placing every region |
| `Build.lua` | frame faces, secure buttons, Edit Mode stand-ins |
| `Update.lua` | colors and live unit data |
| `Settings.lua` | the settings page |

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
- `Shared/Settings/Launchers.lua` (installed by `Boot.lua`) adds the other ways
  in: a **ModeUI** button in its own section of the game menu, between Shop and
  AddOns (a post-hook on `GameMenuFrame:InitButtons`, skipped in combat), and an
  entry in the minimap's addon compartment (`AddonCompartmentFrame:RegisterAddon`,
  so no global function). They call `addon:OpenConfig()` and
  `addon:ToggleConfig()` and build nothing until clicked.
- The window opens on the first page in the sidebar. Categories are listed in
  the order `Shared/Runtime/Lifecycle.lua` registers them (Global, Interface,
  Frames); a category's modules in the order `ModeUI.toc` loads them.

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
| `Layouts.lua` | built-in layouts: a whole screen of settings a new profile starts from; each module adds its own part; once per account a seeded layout becomes its own profile at `PLAYER_LOGIN` | `addon.Layouts:Register(id, spec)`, `:Contribute(id, moduleId, fn(db, ctx))`, `:Build(id, variant)`, `addon.Profiles:CreateFromLayout(name, id)`; see "Layouts" below |
| `Themes.lua` | the look (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"): `profile.theme` (always "obsidian"), each module's part, run once per profile; formerly the first start's Mode-Obsidian profile; see "Themes" below | `addon.Themes:Contribute(theme, moduleId, fn(db))`, `:CatchUp(profile, moduleId, db)`, `:Seed(root, fresh)`, `.SwapColor(t, key, group, role)`, `addon.Profiles:CreateThemed(name, source, theme)` |
| `Reload.lua` | reload requests and the reasons shown to the user | `addon.ReloadManager:Request(key, reason)`, `:Clear(key)`, `:Reload()` |
| `Lifecycle.lua` | categories and the module registry; enable/disable; combat broadcast | `addon:RegisterCategory(id, def)`, `addon:RegisterModule(id, module)`, `addon:SetModuleEnabled(id, on)`, `addon:BroadcastCombatState(inCombat)` |
| `API.lua` | the `ModeUI-Core` LibStub API for companion addons and probes, loaded after `Shared/Style/` (read only, except `Companion`) | `LibStub("ModeUI-Core").Style`, `.Domain`, `.IsPublic`, `.IsNumber`, `.InCombat`, `.Ready()`, `.Companion(name)` (ModeUI's addon table, for the companions it lists) |
| `Boot.lua` | the startup sequence on `ADDON_LOADED`, then `/modeui`; always the last file | |

Messages in use (`addon.Messages`):

| Name | Arguments | Sent when |
|---|---|---|
| `MODULE_TOGGLED` | `id, enabled` | a module was switched on or off; Edit Mode and the settings window refresh |
| `CLASS_COLORS_CHANGED` | | Class Colors changed; class-colored modules redraw |
| `PROFILES_CHANGED` | `status` | a profile was created, switched, renamed, deleted or imported; the Profiles module refreshes the window |

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

## The Mode design system (`Shared/Style/`)

The look lives in one place. `docs/DESIGN_LANGUAGE.md` is the spec; `Shared/Style/`
is its only implementation; `tests/design.lua` keeps everything else from
drawing on its own (colors, borders, masks, bar textures, texture paths, font
files). `tests/design_legacy.lua` counted down the code written before the
standard; Phase 8 (November 15, 2026) brought every file to it, so the list
is empty and stays empty. `Style/Tone.lua` loads first of all the design
files (before `Shared/Domain`, whose power colors it holds).

| File | Job |
|---|---|
| `Tone.lua` | every color token (Mono and Graphite ramps, Slate, metals, accents, gameplay and module colors: power types, threat, debuff types, stats, name accents...), `Style.LEGACY` (pre-Mode defaults saved settings still hold or migrations recognize, `Kit.palette` and `Kit.onyx` among them), `Style.SameColor` and `Style.ColorText(text, color)` |
| `Assets.lua` | the "Mode <Name>" texture registry: file, slice margins, wrap, LibSharedMedia type and name; `Style.TEXTURE_ROOT` (ModeUI's texture folder); the module icons and glyphs (`Style.ICONS`, `Style.GLYPHS`) |
| `Fonts.lua` | the Mode typeface ("Mode": Urbanist), its weights, the installed Expressway copies a player may pick (`Style.PROVIDER_FONTS`); Mode Script (`Style.SCRIPT_FONT`, Damion, the wordmark only) |
| `ProviderMedia.lua` | other addons' media by reference (`Style.PROVIDER_MEDIA`: kind, name, path), registered by Media only when installed; no asset bundled |
| `Edge.lua` | the one border factory and its presets (frame, frameThin, group, window, ring, line, empty) |
| `Bar.lua`, `Shield.lua` | the one bar factory: Mode BG empty part, fill-end line, Comet spark, Combined shields; `Style.ApplyBarLook` (a module bar in a Mode texture: base plus lift) and `Style.SetBarTexture` (any other fill file) |
| `Names.lua`, `Icon.lua` | name styles and placement; icon sizes and crops; `Style.SetShapeMask` (a frame's own shape, the minimap's rectangle) |
| `Halo.lua` | text glow, Halo (`Style.TextHalo`): copies of a text under it that take its writes; glow colors Deep, Ink, Match Text |
| `Glow.lua` | the Prism glow (`Style.Glow`): a soft light round a frame in the unit's color, for mouseover and focus (Mode-Obsidian) |

Art is generated by `tools/build_mode_assets.lua`. Companion addons reach Style
through ModeUI's addon table (below). Probe addons reach it through the
`ModeUI-Core` LibStub API, on the kit in `probes/Kit/` (`probes/README.md`):
previews of planned redesigns that leave ModeUI alone, built into zips by
`tools/build_probes.ps1` and checked by `tests/probes.lua`. Every redesign of
the Mode rebuild shipped, so there are no probes right now; the kit stays for
the next one.

## Domain and Kit

`Shared/Domain/` reads game data. It's the only code that calls `Unit*` APIs,
and every call is guarded: a missing API, an error or a secret answer counts as
"unknown". Values that may be secret are returned only so they can go straight
to widgets documented as accepting them.

| File | API |
|---|---|
| `Query.lua` | `Domain.Query.Call(fn, ...)`, `.Truthy(fn, ...)`, `.Plain(fn, ...)`, `.Read(fn, ...)` (up to seven values, secret ones as nil) |
| `Health.lua` | `Domain.Health.Read(unit)` → okMax, max, okValue, value (secret); `.Percent(unit, curve)`; `.State(unit)` → `"Offline"`, `"Ghost"`, `"Dead"` or nil |
| `Power.lua` | `Domain.Power.Read(unit)` → powerType, token, okMax, max, okValue, value; `.Percent(unit, powerType, curve)`; `.Color(token)` |
| `Name.lua` | `Domain.Name.Get(unit)` → name (may be secret) or `""` |
| `Level.lua` | `Domain.Level.Text(unit)` → `"60"`, `"60+"`, `"??"` or `""` |
| `UnitColor.lua` | `Domain.UnitColor.Class(class)`, `.NativeClass(class)`, `.PlayerClass(unit)`, `.Reaction(unit)` → `"tapped"`, `"hostile"`, `"neutral"`, `"friendly"`; `.SetClassOverride(fn)` (Class Colors supplies the custom colors) |
| `Portrait.lua` | `Domain.Portrait.Apply(icon, unit, style)`, `.SetIcon(icon, path)`, `.Exists(unit)` |
| `ClassResource.lua` | `Domain.ClassResource.Spec()` → the player class's resource (`CLASSES`: Rogue, and Druid in Cat Form, have Combo Points on Forever) or nil, `.Read()` → ok, count (may be secret), `.Max()` (public; 0 without a resource), `.Active()`, `.ClassName()` |
| `Cast.lua` | `Domain.Cast.Read(unit)` → nil or { channel, text, texture, startMs, endMs, notInterruptible } (may be secret); `.Now()` |
| `RaidIcon.lua` | `Domain.RaidIcon.Apply(texture, unit)`: the marker through `SetSpriteSheetCell`, or hidden |
| `Threat.lua` | `Domain.Threat.Status(unit)` → your threat on the unit, 0-3 or nil when unknown or secret; `.Aggro(unit)` → the unit's own threat on whatever it fights (2-3: a mob is on it) |
| `Group.lua` | `Domain.Group.Role(unit)` → `"TANK"`, `"HEALER"`, `"DAMAGER"` or nil, `.LeaderAtlas(unit)`, `.ReadyCheck(unit)` → `"ready"`, `"notready"`, `"waiting"` or nil, `.Incoming(unit)` (summon, resurrection or another phase), `.InRange(unit)` → ok, inRange (secret; for `SetAlphaFromBoolean`), `.IncomingHeals(unit)`/`.Absorbs(unit)` → ok, amount (secret; for `StatusBar:SetValue`), `.NewCalculator()`, `.Prediction(unit, calculator)` → { max, heals, shield, total, overflow, calculated } (amounts and overflow may be secret); `ROLE_ATLAS`, `READY_ATLAS`, `INCOMING_ATLAS` |
| `Nameplate.lua` | `Domain.Nameplate.ForUnit(unit)`, `.IsPlayerPlate(frame)`, `.WidgetsOnly(unit)`, `.ActiveUnits()` |
| `Auras.lua` | `Domain.Auras.Filters(crowdControl, debuffs, buffs)` → filter strings; `.Collect(unit, filters, max)`; `.Apply(icon, unit, aura, showTimer, showCount)`; `.ApplyTimer(...)`; `.NeverSecret(spellID)` (the game never keeps that aura secret: `C_Secrets.GetSpellAuraSecrecy`); `.Spells(unit)` → { id, icon, harmful } with public spell IDs (out of combat, for pickers); the game's filters choose auras, no secret field is compared |
| `DamageMeter.lua` | `Domain.DamageMeter.types`/`.typeById` (meter IDs saved in settings), `.Supported()`, `.Available()` → ok, reason, `.GameMeterOn()` (reads the game's option), `.Session(session, typeId)` → { sources (ranked by the game), max, total, duration } (may be secret), `.Source(session, typeId, guid, creatureID)` → { spells, max, total } (public arguments only), `.Sessions()`, `.Duration(session)`, `.Reset()`, `.SpellName(id)`, `.SpellIcon(id)`, `.ClassAtlas(class)`, `.Clock(seconds)`; `.EVENTS` |
| `Containers.lua` | `Domain.Containers.HeldBags()` (backpack, equipped and reagent bags), `.IsHeld(bag)`, `.IsReagent(bag)`, `.HasKeyring()`, `.NumSlots(bag)` (the keyring through `GetKeyRingSize`), `.FreeSlots(bag)`, `.Item(bag, slot)` → nil or { icon, count, quality, locked, link, id, name, filtered, noValue, readable, bound }, `.Quest(bag, slot)`, `.IsNew(bag, slot)`, `.Cooldown(bag, slot)`, `.ItemClass(link)`, `.ItemLevel(link)` (weapons and armor), `.QualityColor(quality)`, `.Money()`, `.SetSearch(text)`/`.HasSearch()` (the game's bag search), `.CleanUp()`/`.CanCleanUp()` (`C_Container.SortBags`); `.KEYRING` (-2) |
| `Cooldowns.lua` | `Domain.Cooldowns.VIEWERS` (the IDs ModeUI saves → Blizzard's viewer names), `.Viewer(id)`, `.Enabled()` (the `cooldownViewerEnabled` option), `.Available()` → available, reason, `.Items(viewer)` (active item frames in Blizzard's order), `.ItemCooldownID(item)`, `.Info(cooldownID)`, `.SpellID(cooldownID)`, `.SpellName(spell)`, `.SpellIcon(spell)`, `.Cooling(spell)` (from the never-secret `isActive`/`isOnGCD`), `.Shown(region)` → true, false or nil when secret; reads only, never writes to or refreshes Blizzard's frames. Spells by ID: `.SpellExists(id)`, `.Override(id)`, `.Known(id)`, `.SurelyKnown(id)` (false when the game can't say), `.InSpellBook(id)` (a spellbook slot; nil when the game can't say), `.CooldownDuration(id)`/`.ChargeDuration(id)` (duration objects, for `SetCooldownFromDurationObject`), `.Charges(id)` → current (may be secret), max, recharging, `.Usable(id)`. `.ClassCooldowns(categories)` → { cooldownID, spellID, known } for every cooldown your class and spec has in those categories, learned or not |
| `Items.lua` | Items by ID: `Domain.Items.Exists(id)`, `.Load(id)`, `.Name(id)`, `.Icon(id)`, `.Count(id)` (charges counted, no bank), `.Cooldown(id)` → start, duration, cooling (longer than the global cooldown), `.Usable(id)` → usable, noPower, `.Spell(id)` (its Use: spell), `.UsableInBags()` → { id, icon, name } for each usable item in your held bags |

`Shared/Kit/` builds frame pieces in the Mode look. It holds no game data.

| File | API |
|---|---|
| `Color.lua` | `Kit.Tint(region, color, alpha)`, `.Lighten(color, t)`, `.Scale(color, f)`, `.Gradient(texture, top, bottom, alpha)`, `Kit.FLAT` |
| `Palette.lua` | `Kit.palette`, `Kit.onyx`, `Kit.OLD_ONYX_HEALTH`, `Kit.BORDER_COLOR` (aliases of `Style.LEGACY`: pre-Mode defaults), `Kit.IsOldOnyxHealth(color)`, `Kit.ColorFromBoolean(region, value, ifTrue, ifFalse)` for possibly secret booleans |
| `Shape.lua` | `Kit.PixelSize(frame)`, `.Bar(parent)`, `.Circle(frame, layer, sublevel)`, `.Inset(texture, host, inset)`, `.Rounded(texture, key)`, `.ModeGradient(bar, barHeight, px)` (the one bar texture), `.BarForeground(bar, choice, barHeight, px)`, `.BarBackground(bar, choice)`, `.BarTextureChoices(foreground)`, `.ValidBarTexture(value, foreground)`, `.Rim(host, layer, sublevel)`, `.PlaceRim(edges, host, thickness, cut, color, alpha)` (a hollow pixel rim; `cut` rounds the corners), `.FillTexture(bar, choice, width, height, px, color, alpha)` (a status bar fill in any texture, Mode Slate Hatch tiled crisply through a clip that follows the fill; for shields and overshields), `.FillTextureChoices()`, `.ValidFillTexture(value)` |
| `Cast.lua` | `Kit.PaintCastBar(bar, channel, notInterruptible, color, lockedColor)`, `.CastTimer(text, info, unit)`: secret-safe cast colors and seconds left; `Kit.CAST_HOLD`, `.CAST_HOLD_FADE` and `.CastInterrupted(event, ...)`: Show Interrupted's hold and what counts as an interrupt (Nameplates, ModeCDM's Cast Bar) |
| `Native.lua` | `Kit.NativeFade:Sync(owner, regions)`, `:IsHeld(region, owner)`, `.Fadable(region)`: Blizzard frames faded (never hidden) while any owner holds them, their own alpha animations muted (Unit Frames, ModeCDM's Cast Bar); `Kit.PlayerCast.Claim(owner, on)`, `.ClaimedBy(except)`: the module drawing the player's cast bar (Messages.PLAYER_CAST_CLAIMED) |
| `Slot.lua` | Icon pieces for Action Bars and the Cooldown Manager (both draw their face and edge from `Style`; the old slot art is gone): `.CropIcon(icon, g)`, `.SlotOverlay(texture, host, inset, color, alpha)`, `.SlotGlow(host)`, `.PaintSlotGlow(frame, host, style, color, pulse, px, options)` (a soft glow or a colored frame, with a pulse; Pixel, Blizzard and GCD through Glows.lua) |
| `Glows.lua` | Animated glows for `PaintSlotGlow`: `Kit.PaintPixelGlow(frame, host, color, px, lines, thickness)` (marching lines), `Kit.PaintFlipbookGlow(frame, host, style, color, px)` (the game's proc loop or rotation-assist art; the proc loop when an atlas is missing), `Kit.HideGlowExtras(frame, style)`; one shared ticker runs only while one shows |
| `Points.lua` | Class resource points (the Target frame's combo points, the target nameplate's): `Kit.ResourcePoint(parent, index)`, `.LayoutResourcePoint(point, size, px, emptyColor, activeColor)`, `.ResourcePointSize(size, px)` (whole, even pixels), `.FillResourcePoints(points, count, ok, value)`: one round socket per point in the ModeUI border color, each a StatusBar spanning `(index - 1, index)` so a secret count only ever reaches `SetValue` |
| `Bands.lua` | `Kit.Bands(parent)`, `.PlaceBands(bands, box, left, top, right, bottom, px, room)`: a rim drawn in four clipped bands around a see-through hole |
| `Text.lua` | the suite's text style: `Kit.Text(layer, drawLayer)`, `.Write(text, value)`, `.Formatted(text, pattern, ...)`, `.Font(text, style, size, path, px)` (style.outline: true or "outline", "thick", false or "none"), `.OutlineFlags(style)`, `.LayoutLift(...)`, `.ValueText(text, mode, percentFn, unit, hasCurrent, current)`, `.ShortNumber(value, decimals)` (abbreviated with 0-2 decimals, whole below a thousand, secret-safe); `Kit.LIFT_PIXELS`, `Kit.LIFT_ALPHA`; `Kit.FontPath(style, scope)` |
| `AuraIcon.lua` | `Kit.AuraIcon(parent)`, `Kit.LayoutAuraIcon(icon, size, px, style, fontPath)`: slate-rimmed icon with swipe and stacks; `Kit.DispelAuraRim(button, options, color, icon)` (`icon`: the frame holding the parts when it is a child of the button) |
| `AuraContainer.lua` | Blizzard's custom aura containers: `Kit.HasAuraContainers()`, `.AuraDispelColors(colorOf, alpha)` (a step curve on `Kit.DISPEL_TYPE_IDS`, or a name map), `.AuraDispelOptions(colors)`, `.AuraTimeFormatter(hours)` (`hours`: "2h" past an hour); `Kit.AURA_CONTAINER_TEMPLATE`, `Kit.AURA_FLOW`, `Kit.AURA_AXIS`. Used by Nameplates, Party Frames and Buffs & Debuffs |

## Skin

`Shared/Skin/` restyles Blizzard's own frames. Blizzard's art is faded (alpha)
or hidden, never destroyed; ModeUI's textures go on top. Nothing is stored on
Blizzard's frame tables (ModeUI's pieces live in weak tables keyed by the
frame), Blizzard's globals and fields are never written, and every hook is a
post-hook (`hooksecurefunc`, `HookScript`).

| File | API |
|---|---|
| `Skin.lua` | the Mode pieces for windows and controls: `Skin.mode` (Style.Tone tokens), `Skin.Box(host, preset, opts)` (a face texture and a Style.Edge on its own frame), `Skin.PaintBox(parts, box, key, color, alpha, edge, highlight)`, `Skin.Ink(text, color)`; for modules not rebuilt yet `Skin.colors` (the old skin palette), `Skin.Snap(value, px)`, `.Once(frame, key, fn)`, `.Fade(region)`, `.FadeTextures(frame, keep)`, `.Suppress(region)`/`.Release(region)` (hidden, and hidden again whenever Blizzard shows it), `.PinAlpha(frame, getter)`/`.Unpin(frame)` (ModeUI's alpha put back after each Blizzard `SetAlpha`), `.Panel(host, layer, sublevel)`, `.PaintPanel(parts, box, fill, alpha, rimColor, thickness)`, `.Font(region, path, size, outline, shadow, px)`, `.Face(region, path)` (face only, size and flags kept), `.Edge(host, lift)`/`.PaintEdge(parts, thickness, color)` (a crisp square border on its own frame above the host's children) |
| `Controls.lua` | `Skin.Kind(frame)` → `"Button"`, `"Field"`, `"Tab"`, `"SideTab"`, `"RightSideTab"`, `"Dropdown"`, `"ScrollBar"` or nil (by template keys); `.Button`, `.Field`, `.Tab`, `.SideTab`, `.GlyphButton(button, glyph)`, `.Close`, `.ScrollBar`, `.Inset` (field on the inset's parent, under the content), `.FadeNineSlice` |
| `Extras.lua` | `Skin.Dropdown`, `.Menu(menu)`/`.MenuClosed(menu)`/`.WatchMenu(dropdown)` (a lent Mode panel under a WowStyle dropdown's open menu), `.RightSideTab`, `.MaxMinOf(frame)`/`.MaxMin(holder, close)`, `.Texts(frame, path, skip)` (every font string in the Mode face), `.IsScrollBox`/`.WatchList(box, onRow)`/`.Row(row, style, fadeRows)` |
| `Frame.lua` | `Skin.Window(frame, style, options)` (art and decoration faded, fill, border on its own layer, title strip, window buttons, inset, list rows, window text, controls six levels deep), `.PaintWindow(frame, style)`, `.TitleOf(frame)`, `.CloseOf(frame)`, `.PlaceClose(frame, close, style)` (outside combat for protected windows) |

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
- **Look.** Every bar uses `Kit.ModeGradient` (Mode Gradient); there is no bar
  texture setting. Settings pages group rows on cards (`page:Group`: ModeCard
  panels, 6 px corners, a one-pixel `cardBorder` rim, 16 px padding, 12 px
  apart, with a small uppercase accent title) and put related controls side by
  side (`page:Columns`). Since November 13, 2026 (the owner's Layout tab
  design) a standard row stacks its label above its 28 px control (58 px
  pitch); sliders show their value at the right of the label line and span the
  full width; two pairable rows in a row (sliders and dropdowns,
  `row.pairable`) share one line in a card, 24 px apart; rows with wider
  controls, `page:ToggleGrid` and `page:Columns`
  (`Shared/Settings/PageControls.lua`) keep the full width. Colors: cards
  #121316 on a #1E2024 rim, fields #0E0F11 on #2A2D32, labels #C4C8CE, values
  #8A8F96, a #22262B selected segment. Controls are drawn by `Widgets/Shape.lua` as a
  rounded fill inside a one-physical-pixel rim (`W.Box`, 4 px corners): buttons
  are fields with a `rim` that turns accent on hover (primary buttons are
  accent with ink text, quiet ones text only); toggles are 28x16 pill switches;
  exclusive choices are segments in one field, the chosen one on `accentFill`;
  sliders are a 4 px track with a ringed round thumb and a 48x24 value field;
  dropdowns are fields with a chevron. Section tabs are text tabs with a 2 px
  accent underline; sidebar captions are small uppercase `faint` text and the
  chosen module row has an accent bar on its left. The palette (Theme.lua) is
  Graphite with the Ivory accent; the type scale is
  `InterfaceTheme.fontSize` (page 24, card 19, brand 21 for the ModeUI wordmark, section 14, body 13, small 12, group 12).
  The shape textures come from `tools/build_shape_textures.lua`. Rims are near-black (`Kit.onyx.border`). Anchoring settings
  use `W.AnchorPicker` (a compass of eight anchors around a small plate). Text and the interface use the Mode typeface
  (Urbanist). Every color is a `Style.Tone` token.
- **Globals.** Only `ModeUIDB`, `SLASH_MODEUI1`/`SlashCmdList.MODEUI`,
  `SLASH_MODEUICDM1`/`SlashCmdList.MODEUICDM` (`/mcdm`, the Cooldown Manager's
  window, asked for by the owner on November 13, 2026),
  `SLASH_MODEUIKEYBIND1`/`SlashCmdList.MODEUIKEYBIND` (`/kb`, Action Bars' Keybind
  Mode, asked for by the owner on November 13, 2026) and frame names that start
  with `ModeUI`.
- **Game-wide settings** (CVars, UI scale, loot) change only through the
  Optimizations module: each one is off by default except the UI scale (on at
  Pixel Perfect since November 15, 2026, the owner's request), and turning one
  off puts back the game's previous value. Other modules never write them, and nothing rewrites
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
| 0 | Unit Frames | Frames | Domain: Health, Power, Name, Level, UnitColor, Portrait. Kit: Bar, Text (lifted shadow), Circle, Gradient | done (native acceptance pending) |
| 1 | Nameplates | Frames | Domain: Cast, RaidIcon, Threat, Nameplate, Auras. Kit: Palette, ColorFromBoolean, FontPath, ModeGradient, AuraIcon | done; auras native acceptance pending |
| 2 | Party Frames | Frames | Domain: Group (role, leader, ready check, summons, range, heals and absorbs). Kit: AuraContainer (moved from Nameplates). Uses Blizzard's secure group header; no Templates folder needed | done (November 13, 2026); native acceptance pending |
| 3 | Action Bars | Interface | Placement: `PositionManager:SetEditable` (one element per bar), `Positioning:AddTarget` (bars anchor to bars), PositionGuides (alignment guides, snapping, `Nudge`). Kit: `LayoutLift` for text ModeUI doesn't own. Reuses Blizzard's buttons, so no secure template | done (native acceptance pending) |
| 4 | Chat | Interface | Skin: Box (the Mode window and controls), suppress, alpha pin, fonts | done, confirmed in game (November 15, 2026); tab alphas pinned, never Blizzard's constants |
| 5 | Damage Meters | Interface | Domain: DamageMeter (the game's own meter through `C_DamageMeter`). Skin: Box (the Mode window on each meter) | done, confirmed in game (November 15, 2026); Forever loads Blizzard_DamageMeter |
| 6 | Bags | Interface | Domain: Containers (bags, slots, items, search, sort). Slots are Blizzard's `ContainerFrameItemButtonTemplate` on holders carrying the bag ID, so no secure template of ModeUI's own | done (native acceptance pending); Blizzard's bag frames wait under a hidden frame and the window follows them |
| 7 | Windows | Interface | Skin: window frames, controls by template keys (buttons, fields, tabs, side tabs, close, scroll bars, insets) | done (native acceptance pending); secure windows skinned out of combat |
| 8 | Minimap | Interface | Domain: Location (zone name, PvP type, player position). The addon-button collector stays in the module until a second module needs it | done (November 14, 2026; native acceptance pending): Blizzard's Minimap on a ModeUI holder, one mask per size, difference and corner choice (tools/build_minimap_masks.lua), Blizzard's mask re-set after `UpdateMinimapConfig` |
| 9 | Tooltip | Interface | Skin: Panel, Edge, Font on Blizzard's tooltips. Placement: one Edit Mode element (the tooltip's anchor) | done (native acceptance pending); GameTooltip_SetDefaultAnchor post-hook, Blizzard's container untouched |
| 10 | Cooldown Manager | own window (`/mcdm`, standalone) | Domain: Cooldowns (Blizzard's Cooldown Manager viewers and items). Kit: Slot (icon cropping and glows, moved out of Action Bars). Domain: Items (items by ID). Kit: Glows (Pixel, Blizzard and GCD glows). Settings: `standalone` modules, `addon:RegisterSettingsWindow`, `W.Confirm` (a confirmation for actions that can't be undone). Placement: `PositionManager:SetLabel`, `gapPixels` (pixel-perfect gaps to a target), `SetSizeMatch` with Match Width and Match Height in the Edit Mode window, `AllowTarget`, `Positioning:RemoveTarget`/`SetTargetLabel`. Restyles and re-places Blizzard's own item frames (also onto custom bars) with post-hooks only, writing no field on them | done (native acceptance pending); Forever loads Blizzard_CooldownViewer for `camelot` |
| 11 | Buffs & Debuffs | Interface (`frames`) | Runtime: the `Adopt(db, modules)` module hook (the Player frame's auras from Unit Frames). Domain: `Auras.NeverSecret`, `Auras.Spells`. Kit: `DispelAuraRim` on a child icon, `AuraTimeFormatter(hours)`. Bars are Blizzard's custom aura containers on the player, in ModeUI holders placed by Edit Mode movers; Blizzard's BuffFrame and DebuffFrame step aside (unregistered, their parts hidden in place) and stay as anchors | built November 17, 2026 on `t3/buffs-debuffs`, merged into `main` the same day; run in game by the owner (stand-in, handover, icons), the Boss & Important bar and bar picker row still to recheck |

Every module gets design notes in `docs/<NAME>.md` (like `docs/UNIT_FRAMES.md`)
and an entry in the README's module table.

## Layouts

`Shared/Runtime/Layouts.lua` (owner, November 18, 2026). A layout is a whole
screen of ModeUI settings that a **new** profile starts from; it never
changes an existing profile, so nothing a player placed moves. The first is
**Mode-DPS/TANK** (label DPS / Tank; Mode-Default until November 20, 2026, when
both role layouts were remade in Mode-Obsidian under new seeds), built from the owner's layout editor
(plan and editor: https://claude.ai/artifact/6FWUxBmvD5qerXYSV5vYuT, copied to
`design/layout-editor/`). The second is **Mode-Healer** (label Healer,
owner, November 19, 2026), from the prototype at
https://claude.ai/artifact/HLq3CPadopGaUukoaT8GHt (copied to
`design/healer-layout/`): a Player mana frame over the party column left of
center, the party column ending level with Essential's second row.

- **Parts.** Each module adds its own part from `Modules/<Name>/Layouts.lua`
  (ModeCDM from its own folder): `addon.Layouts:Contribute("mode-default",
  moduleId, function(db, ctx) ... end)`, and one for `"healer"`. A module
  whose part is the same in both (Action Bars, Damage Meters, Minimap,
  Nameplates) contributes one function to both; the others share what is
  common in a local function. A healer place that depends on another
  module's size (the party column on Essential, the Player frame on the
  party column, Player Debuffs on Right Buffs) is a number in each part, and
  `tests/layouts_healer.lua` checks the two agree. `db` is the module's settings in a
  fresh profile (defaults filled in); `ctx.Place(elementId, target, point,
  relativePoint, x, y)` writes an Edit Mode place (explicit points: no
  built-in gap), `ctx.Match(elementId, axis, target)` a Match Width or Height
  pick, and `ctx.V{ ["1080"] = a, ["1440"] = b }` picks by screen. A part
  never touches another module's settings. Modules in the layout today:
  Unit Frames, Party Frames, Buffs & Debuffs, Action Bars, Damage Meters,
  Minimap, Nameplates and the Cooldown Manager (every other module is on,
  with its defaults: `allModules`). Chat is left out: a chat window's size
  and place are Blizzard's Edit Mode settings, and whether an addon may set
  them safely is still to be researched.
- **Every module on.** A layout marked `allModules` switches every module
  on in the profile it builds (all but `alwaysOn` and planned ones), before
  the parts run; Mode-DPS/TANK and Mode-Healer do (owner, November 18 and
  19, 2026).
- **Screens.** A layout has places for 1080p and 1440p at the pixel-perfect
  scale (1 UI unit = 1 pixel); a profile takes the set nearest the UI height
  when it is built (1440's from 1260 up). Changing UI scale later moves
  nothing.
- **Building.** `Layouts:Build(id, variant)` makes a new profile from
  defaults, runs each installed module's part, then checks the whole profile
  as an import is checked (`Database:ValidateProfile`). A module that isn't
  installed (ModeCDM missing) is skipped.
- **Profiles.** `Profiles:CreateFromLayout(name, id)`; the Profiles page has
  **New from DPS / Tank Layout** and **New from Healer Layout** (an empty
  name takes the layout's profile name, made unique). A layout with a `seed` becomes its own profile once per account
  and seed at `PLAYER_LOGIN` (when every companion has registered), recorded
  in `ModeUIDB.builtLayouts[seed]`; it is never made active, and a deleted
  one is not made again. A layout remade for a new look takes a new seed
  (`"<id>@2"`, November 20, 2026): a profile the earlier seed made under the
  same name (`earlierName`) is kept as "<name> (old)" and the new one is made
  beside it.
- **Tests.** `tests/layouts.lua` builds the whole layout at both screens,
  checks every place hangs from a known target, seeding once, and ModeUI
  starting with the profile active; each module's own test checks its part.
  `tests/layouts_healer.lua` does the same for Mode-Healer and checks its
  alignments (widths, 1px joins, the column on Essential's second row).

## Themes

`Shared/Runtime/Themes.lua` (owner, November 20, 2026; the history in
`docs/OBSIDIAN.md`). Mode-Obsidian is the only look: `profile.theme` is
always `"obsidian"` (`Database:ValidateProfile` sets it; a profile from
before may say `"blizz"` or nothing). The Mode-Blizz art, the Geist typeface
and the code that drew them are kept outside the addon in
`archive/mode-blizz/` and never load.

- **Tokens:** `Style.ApplyTheme()` sets the Mode-Obsidian surface tokens in
  place at load (so defaults copied from tokens are already Mode-Obsidian's)
  and again once the profile is checked; the Mode-Blizz values stay only for
  migrations (`Style.BlizzTone`). Code that copies token colors registers
  `Style.OnThemeApplied(fn)` (the settings window's palette does).
- **Borders:** two styles, Mode-Border (`obsidian`) and Mode-Empty
  (`obsidianEmpty`). `Style.ThemeStyle(id)` maps an old saved id (`blizz`,
  `thin`, `round`; `blizzEmpty`) to the style it draws as, in `Style.Edge`,
  `Edge:SetStyle`, `Style.SetRingStyle` and the Border picker. Pickers list
  the two styles (`Style.EdgeStyleChoices(withNone, true)`); a module's
  settings check also accepts the old ids (`Style.EdgeStyleChoices()`).
- **Textures:** Mode-FG and Mode-BG (`Style.ASSETS` FG and BG), Surface for
  large panels; an old saved texture name draws as the one it became
  (`Style.OLD_MEDIA`, in `Style.MediaAsset` and `Media:GetStatusBar`).
- **Migrations** (`DB.lua`, once per profile, after every module's own and
  its part): look step 1 moves saved old texture names (`Style.OLD_MEDIA`;
  Mode BG drawing a fill takes Mode-FG) and old `edgeStyle` and
  `portraitRingStyle` ids; typeface step 4 moves saved Geist weights to
  Urbanist's.
- **Parts.** Each module moves its own settings from the Mode-Blizz
  defaults to Mode-Obsidian's from `Modules/<Name>/Theme.lua` (ModeCDM from
  its own folder): `addon.Themes:Contribute("obsidian", moduleId, function(db) ... end)`.
  A part runs once per profile and module (`profile.themeParts[moduleId]`),
  right after the module's `Initialize` in `Database:ValidateProfile` (and in
  `StartLateModules` for a companion), so the player's later changes stay.
  A part never touches another module's settings; `Themes.SwapColor` moves a
  saved color still at its Mode-Blizz token to Mode-Obsidian's.
- **Profiles.** Every profile is Mode-Obsidian; a layout's runs the parts
  again after the layout's (`Layouts:Build`). The first-start
  "Mode-Obsidian" copy and the Profiles page's New Mode-Obsidian Copy were
  retired with Mode-Blizz (`builtThemes` and `previousProfile` stay readable
  account keys).
- **Tests.** `tests/obsidian.lua` covers an old profile turning
  Mode-Obsidian, the mapping, the tokens, the typeface and the parts;
  `tests/smoke.lua` the look and typeface steps.

## Companion addons

A ModeUI module can ship as an addon of its own beside `ModeUI/` (November 15,
2026, owner's request). The first is **`ModeCDM/`**, the Cooldown Manager.

```
ModeCDM/
  ModeCDM.toc        ## Dependencies: ModeUI, ## Group: ModeUI (nests under ModeUI in the AddOn list)
  Core.lua           first: ns.ModeUI = LibStub("ModeUI-Core").Companion("ModeCDM")
  Modules/CooldownManager/   the module, with the usual contract (<Name>.xml, Init.lua first, Driver.lua)
  Start.lua          last: addon:StartLateModules()
  LICENSE
```

- **One addon table.** Each module file starts `local _, ns = ...` and
  `local addon = ns.ModeUI or {}`, then runs exactly as it would inside
  ModeUI: Style, Domain, Kit, Placement, the settings widgets, `Messages`.
  `ModeUI-Core`'s `Companion(name)` returns the table only for the names in
  its `COMPANIONS` list; anything else gets nil.
- **Settings stay in ModeUI.** The module keeps its saved key
  (`ModeUIDB` profiles, `modules.cooldownManager`) and its Edit Mode places, so
  moving it out of ModeUI needed no migration. Without the companion, ModeUI
  leaves those settings as they are (profile checks only touch registered
  modules), and they come back when it's enabled again.
- **Late registration.** The client may run a dependent addon's files after
  ModeUI's `ADDON_LOADED`. A module with `companion = "<Addon>"` may register
  then; it waits in `addon.lateModules` until the companion's `Start.lua`
  calls `addon:StartLateModules()`, which checks and migrates its settings on
  a copy (as the profile check does) and starts it. Registered before ModeUI
  starts, it simply starts with the others.
- **Tests.** `tests/harness.lua` loads every companion in `H.COMPANIONS` after
  ModeUI with its own name and namespace (`companions = false` loads ModeUI
  alone, `lateCompanions = true` after ModeUI's start). `tests/structure.lua`
  and `tests/design.lua` check companions too (legacy entries are keyed
  `ModeCDM/...`); `tests/companion.lua` covers ModeUI alone and a late start.
- **Installing.** Link or copy each companion folder into
  `Interface/AddOns` beside `ModeUI`.

## Adding a module

1. Copy [docs/module-template](module-template/) to `Modules/<Name>/` and
   follow its README. It's a complete, tested module (`tests/template.lua`), so
   the new one starts with the right shape.
2. Add `Modules\<Name>\<Name>.xml` to `ModeUI.toc`, after the other modules and
   before `Shared\Runtime\Boot.lua`.
3. Pick an existing category, or register a new one in `Shared/Runtime/Lifecycle.lua`.
4. Put anything another module could use in `Shared/` instead of the module:
   game data in Domain, frame pieces in Kit. Add a message to `addon.Messages`
   when another module needs to hear about a change.
5. Record its APIs in `docs/API_COMPATIBILITY.md` and its design in
   `docs/<NAME>.md`.
6. Add tests, and run every test listed in the README.

## Restructure phases

Each phase is one focused commit. All tests pass after every phase, with no
change to behavior, looks or saved data.

| Phase | Work | Status |
|---|---|---|
| 1 | This document, AGENTS.md rules, `tests/structure.lua`, XML support in the harness | done |
| 2 | Move files into `Libs/` and `Shared/*` with `git mv`; no code edits. The libraries now load before `Edition.lua` | done |
| 3 | Runtime: `Core.lua` (from `Edition.lua` and the copied secret checks), `DB.lua`, `Reload.lua`, `Lifecycle.lua` (from `Modules.lua`, `Categories.lua` and the combat broadcast in `DisplayModes.lua`); add Events, Defer, Callbacks, Locale | done |
| 4 | Domain and Kit: unit readers and frame builders out of `UnitFramesDisplay.lua` | done |
| 5 | Module folders: `Modules/UnitFrames/` (Init, Migrations, Driver, Layout, Build, Update, Settings), then `Profiles/`, `Optimizations/` and `ClassColors/` (Init, Driver, Settings) | done |
| 6 | Split the files over budget: `Widgets.lua` into `Shared/Settings/Widgets/` (Core, Art, Text, Button, Switch, Header, Input), the sidebar out of `Window.lua` (`Sidebar.lua`), textures and scoped styles out of `Media.lua`, anchor width and dragging out of `PositionManager.lua`. Modules declare their own page layout (`modeLayout`, done in phase 5) | done |
| 7 | `docs/module-template` (a working module checked by `tests/template.lua`) and the README "Adding a module" section | done |

After phases 2–6, the in-game check is the same:

- **Navigation:** type `/modeui`, then pick **Frames** › **Unit Frames** in the sidebar.
- **Action:** switch the module off and on, open **Edit Mode**, move the Player
  frame, then `/reload`. **Edit Mode** is in the settings window header.
- **Required state:** out of combat, with a target selected.
- **Confirmation:** the frames look the same and sit where they did before.
