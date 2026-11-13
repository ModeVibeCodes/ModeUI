<img src="assets/icon.svg" width="64" height="64" alt="">

# ModeUI

Custom interface creations for **WoW Forever**, in the Mode look. ModeUI is the
home for every Mode interface module. It started from the Interface work that
used to live in [Play The Game Tools](https://github.com/ModeVibeCodes/PlayTheGameTools).

> Forever only. ModeUI checks the client's project ID at startup and does
> nothing on other clients.

## What's in it

| Category  | Module      | What it does |
|-----------|-------------|--------------|
| Interface | Unit Frames | Secure Player, Target, Target of Target, Focus and Target of Focus frames in the locked Onyx skin, with Mode cast bars, buffs and debuffs, a class resource (combo points for Rogues and Cat Form Druids) around the Target portrait and a click-to-edit live preview: a round portrait with a class-gradient ring, a rounded health/power block inside a pixel-perfect slate rim, Sky names, and a lifted shadow on all text. Text slots (nine on the health bar, one on the border, three on the power bar) each show a name, level, health or power text you pick. Pick the frame to edit above the preview; Frame, Health Bar, Power Bar, Portrait, Cast Bar, Auras, Class Resource and Text tabs each hold their part's own settings, and the Target can match the Player. |
| Interface | Nameplates  | Onyx plates with separate Enemy and Friendly settings and a live preview on the settings page: health with reaction, class or threat colors, name, health text, cast bars that turn gray when they can't be interrupted, auras (crowd control, debuffs, buffs; position and size per kind), raid markers and a cyan rim on your target. Rounded rims and the Mode Gradient bar texture. Off by default. Friendly plates in instances and your personal resource display stay Blizzard's. |
| Interface | Action Bars | Blizzard's own action buttons (bars 1-8, pet and stance) on ModeUI bars in the Mode look, with a live preview of your own bar: 42 by 36 buttons by default, rows or columns, size and spacing, rounded, square or no border with its own size and color, cropped icons, a textured slot background with its own color and opacity, page switching (macro conditions), proc glows (Mode Glow, Border, Blizzard or None), a glow when a cooldown is ready, gray icons on cooldown, short keybinds (sE), a glow menu on each preview button, keybind, count, macro name and cooldown text each with its own place, size and color, Show (Always, Mouseover, Hidden, combat, target or custom macro conditions) and opacity. Move, anchor and nudge bars in Edit Mode; bind keys with `/kb`. Each bar wears a name tag while the page is open. Actions, paging and keybinds stay Blizzard's. Off by default. |
| Interface | Damage Meters | Up to three meter windows in the Mode look, fed by the game's own damage meter: Damage Done, DPS, Damage Taken, Healing Done, HPS, Interrupts, Dispels, Deaths and more, for the current fight, overall or an earlier fight. Class-colored Mode Gradient bars with class icons, rank, name, amount and per second (whole numbers or 1-3 decimals, your choice of separator; percent after the fight) in white outlined text with each text (name, value, title, timer) styled on its own, an Onyx header bar with the meter, timer and buttons for the fight (C/O), Reset and the lock, Always Show Me, scrolling, a header menu, a spell breakdown beside the window and Death Recap. Unlocked, drag a header to move a window and its corner grip to resize it; windows anchored on it take its width. Group windows to stack them above or below one another with matching settings and their own meter and rows. Copy & Apply copies one window's look, or just its window and header, bars or text, to the others. Every part is adjustable: size, rows, spacing, padding, rim, background, header, bar textures and colors, fonts and text, decimals, and when each window shows. Pixel-perfect sizes, a live preview and Edit Mode placement. Needs the game's own Damage Meter option on; Blizzard's own meter window is hidden while the module is on (Hide Blizzard's Meter) and keeps recording. Off by default. |
| Interface | Chat | Blizzard's chat windows in the Mode look: a Mode Slate fill inside a crisp 2px border (as the unit frames'), Expressway text (each window keeps its own size), Glass or Solid tabs resting on the border (the selected one raised, white with a cyan bar; the others tucked), a button compartment at the end of the tab row (Channels, voice, Chat Menu; Social and Text to Speech above it), the edit box joined inside the window (bottom or top, or a separate field below) with a line that turns cyan while typing, a slim scroll bar, and an idle fade to 40% after 8 seconds without use (a whisper wakes it); tabs hide once idle (Tabs When Idle). Background, border, edit box, tabs, fades and buttons are adjustable. Off by default. |
| Interface | Windows | Blizzard's windows in the Mode look: Character, Spellbook and Talents, Professions, Social, Guild, Group Finder, Collections, Achievements, World Map, Quests and Gossip, Merchant, Mail, Bank, Trade, Inspect, Trainer, Auction House, Dressing Room, Pet Stable, Raid, Macros, AddOn List, Game Menu and Game Settings. A dark fill, a crisp 2px border, a title strip, Expressway text throughout, Mode window buttons (close, maximize/minimize), and Mode tabs, buttons, fields, dropdowns and their menus, side tabs, scroll bars, insets and list rows. Window Style swaps every window between ModeUI and Blizzard; each window can be kept Blizzard's, scaled, or given its own look (collapsed rows on the Windows tab). The Character tab adds a stats display (any stats, Main Stat first, anchored and nudged on the model), rarity borders and enchant text beside each slot. Load-on-demand windows are skinned when they load. Off by default. |
| Interface | Tooltip | Blizzard's tooltips in the Mode look: a rounded Onyx box (the health bar color) in Mode Gradient with a rounded 2px border (an item's quality color, a player's class color), Expressway lines, player names and class lines in class colors, NPC names by reaction, the level number by difficulty and quest lines in orange-yellow (each adjustable), no health bar, and Minimum Width, Padding and Scale. The main tooltip shows at its own anchor, moved or attached to another element in ModeUI's Edit Mode (or at the cursor), and stays on the screen; Hide in Combat keeps it away while fighting (Shift shows it). Off by default. |
| Global    | Profiles    | Account-wide profiles of all ModeUI settings: create (from defaults), duplicate, rename, delete, switch (applies on reload) and import/export as a text string. Play The Game Tools keeps its own, separate profiles. |
| Global    | Optimizations | Auto Loot, Fast Loot, Hide Error Text, Max Camera Distance and UI Scale (Pixel Perfect or custom). All off by default: ModeUI only changes a game setting while you have that optimization on, and turning it off puts back the game's previous value. |
| Global    | Class Colors | Custom colors per class for ModeUI's class-colored elements (names, health bars, portrait rings). Changes apply right away; Reset returns a class to the game's color. |

The settings window uses the **Mode** theme from Play The Game Tools: graphite
surfaces, a cyan accent, Lato type and the Mode control artwork. It's the only
theme ModeUI has.

## Using it

- `/modeui` opens or closes the settings window. `/modeui resetwindow` re-centers it.
- **Edit Mode** in the window header lets you drag every unit frame and each
  action bar and damage meter window. Cyan guides show when an element nears the center or an
  offset of 0, and it snaps there. The arrows beside the selected element (or the
  arrow keys) move it one pixel. **Anchor To...** in the Edit Mode window hangs the selected
  element from the next one you click, then offers its sides; anchoring always starts at X and Y 0. **Match Width** and **Match Height** size an
  anchored element to what it hangs from, where its module offers them (damage meter windows do).
  **Preview** shows sample frames.
- `/kb` opens Keybind Mode for the action bars: hover a button and press a key.
- Size, visibility and position changes made in combat are applied once combat ends,
  because Blizzard protects clickable unit frames.
- **Unit Frames** is on by default. Turn it off with the switch in the page header.
  Turning it off gives Blizzard's frames back once you're out of combat.

### Coming from Play The Game Tools

The first time ModeUI loads, it copies the Unit Frames settings and frame
positions from your active Play The Game Tools profile, if PTG has any. It only
reads PTG's data and never changes it. After that, ModeUI keeps its own
account-wide settings in `ModeUIDB`, organized into profiles (Global → Profiles).

### Running alongside Play The Game Tools

Both addons can be installed together or on their own. They keep separate
settings, frames and slash commands. PTG also has its own Optimizations: if both
addons set the camera distance or UI scale, the last one to apply wins, so turn
each one on in only one addon. The ModeUI page shows a reminder while PTG is loaded.

## Repository layout

```
ModeUI/            the addon folder (this is what goes in Interface/AddOns)
  ModeUI.toc
  Libs/            bundled libraries (LibStub, CallbackHandler, LibSharedMedia)
  Shared/          code shared by modules: Runtime (startup, settings, profiles, modules,
                   events, messages), Domain (unit data), Kit (frame pieces), Placement
                   (Edit Mode), Media, Border, Skin (Blizzard frames), Settings (window, widgets)
  Modules/         one folder per module (UnitFrames, Nameplates, ActionBars, DamageMeters, Chat, Windows, Tooltip, Profiles, Optimizations, ClassColors),
                   each with its own XML, Init.lua, Driver.lua and Settings.lua
  Media/           Mode theme textures, unit frame textures, Lato fonts
tests/             structure, runtime, smoke, Unit Frames, Nameplates, Action Bars, Damage Meters, Chat, Windows, Tooltip, Global and template tests
                   (simulated client, not WoW)
tools/             texture generators (Python + Pillow; ModeFlat and nameplate shapes in plain Lua)
design/mode/       Mode theme source artwork and provenance
docs/              architecture (docs/ARCHITECTURE.md) and design notes (docs/UNIT_FRAMES.md, NAMEPLATES.md, ACTION_BARS.md, DAMAGE_METERS.md, CHAT.md, WINDOWS.md)
```

## Local development

The working copy is linked into the Forever client:

```
A:\World of Warcraft\_forever_\Interface\AddOns\ModeUI  ->  <repo>\ModeUI
```

Edits show up in game after `/reload`.

### Tests

The tests run on any Lua 5.1+ interpreter. They simulate the client and do not
replace checking things in game.

```
lua tests/structure.lua
lua tests/runtime.lua
lua tests/smoke.lua
lua tests/unit_frames.lua
lua tests/global.lua
lua tests/template.lua
lua tests/nameplates.lua
lua tests/action_bars.lua
lua tests/damage_meters.lua
lua tests/chat.lua
lua tests/windows.lua
lua tests/tooltip.lua
```

## Adding a module

Every module is a folder, `ModeUI/Modules/<Name>/`. The full contract is in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#the-module-contract), and
`tests/structure.lua` enforces the layout.

1. Copy [docs/module-template](docs/module-template/) to the folder and follow its
   README. It has `<Name>.xml`, `Init.lua` (declares and registers the module,
   loaded first), `Driver.lua` (lifecycle and logic) and `Settings.lua` (the page,
   built only when opened).
2. List `Modules\<Name>\<Name>.xml` in `ModeUI/ModeUI.toc`, after the other
   modules and before `Shared\Runtime\Boot.lua`.
3. Use an existing category, or register one in `Shared/Runtime/Lifecycle.lua`.
4. Put anything another module could use in `Shared/` (Domain for game data,
   Kit for frame pieces), and talk to other modules only through `addon.Messages`.

## License

The original ModeUI code is MIT, Copyright (c) 2026 Mode (see `LICENSE`). The
bundled distribution is GPL-3.0-only because it includes LGPL libraries. See
`THIRD_PARTY_NOTICES.md` and `LICENSES/`.
