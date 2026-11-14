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
| Global    | Profiles    | Account-wide profiles of all ModeUI settings: create (from defaults), duplicate, rename, delete, switch (applies on reload) and import/export as a text string. Play The Game Tools keeps its own, separate profiles. |
| Global    | Optimizations | Auto Loot, Fast Loot, Hide Error Text, Max Camera Distance and UI Scale (Pixel Perfect or custom). All off by default: ModeUI only changes a game setting while you have that optimization on, and turning it off puts back the game's previous value. |
| Global    | Class Colors | Custom colors per class for ModeUI's class-colored elements (names, health bars, portrait rings). Changes apply right away; Reset returns a class to the game's color. |
| Interface | Windows | Blizzard's windows in the Mode look: Character, Spellbook and Talents, Professions, Social, Guild, Group Finder, Collections, Achievements, World Map, Quests and Gossip, Merchant, Mail, Bank, Trade, Inspect, Trainer, Auction House, Dressing Room, Pet Stable, Raid, Macros, AddOn List, Game Menu and Game Settings. A dark fill, a crisp 2px border, a title strip, Expressway text throughout, Mode window buttons (close, maximize/minimize), and Mode tabs, buttons, fields, dropdowns and their menus, side tabs, scroll bars, insets and list rows. Window Style swaps every window between ModeUI and Blizzard; each window can be kept Blizzard's, scaled, or given its own look (collapsed rows on the Windows tab). The Character tab adds a stats display (any stats, Main Stat first, anchored and nudged on the model), rarity borders and enchant text beside each slot. Load-on-demand windows are skinned when they load. Off by default. |
| Interface | Chat | Blizzard's chat windows in the Mode look: the health bar color (Onyx) inside a crisp 2px border (as the unit frames'), Expressway text (each window keeps its own size), Glass or Solid tabs resting on the border (the selected one raised, white with a cyan bar; the others tucked), a button compartment at the end of the tab row (Channels, voice, Chat Menu; Social and Text to Speech above it), the edit box joined inside the window (bottom or top, or a separate field below) with a line that turns cyan while typing, a slim scroll bar, and an idle fade to 40% after 8 seconds without use (a whisper wakes it); tabs hide once idle (Tabs When Idle). Background, border, edit box, tabs, fades and buttons are adjustable. Off by default. |
| Interface | Damage Meters | Up to three meter windows in the Mode look, fed by the game's own damage meter: Damage Done, DPS, Damage Taken, Healing Done, HPS, Interrupts, Dispels, Deaths and more, for the current fight, overall or an earlier fight. Class-colored Mode Gradient bars with class icons, rank, name, amount and per second (whole numbers or 1-3 decimals, your choice of separator; percent after the fight) in white outlined text with each text (name, value, title, timer) styled on its own, an Onyx header bar with the meter, timer and buttons for the fight (C/O), Reset and the lock, Always Show Me, scrolling, a header menu, a spell breakdown beside the window and Death Recap. Unlocked, drag a header to move a window and its corner grip to resize it; windows anchored on it take its width. Group windows to stack them above or below one another with matching settings and their own meter and rows. Copy & Apply copies one window's look, or just its window and header, bars or text, to the others. Every part is adjustable: size, rows, spacing, padding, rim, background, header, bar textures and colors, fonts and text, decimals, and when each window shows. Pixel-perfect sizes, a live preview and Edit Mode placement. Needs the game's own Damage Meter option on; Blizzard's own meter window is hidden while the module is on (Hide Blizzard's Meter) and keeps recording. Off by default. |
| Interface | Action Bars | Blizzard's own action buttons (bars 1-8, pet and stance) on ModeUI bars in the Mode look, with a live preview of your own bar: 42 by 36 buttons by default, rows or columns, size and spacing, rounded, square or no border with its own size and color, cropped icons, a textured slot background with its own color and opacity, page switching (macro conditions), proc glows (Mode Glow, Border, Blizzard or None), a glow when a cooldown is ready, gray icons on cooldown, short keybinds (sE), a glow menu on each preview button, keybind, count, macro name and cooldown text each with its own place, size and color, Show (Always, Mouseover, Hidden, combat, target or custom macro conditions) and opacity. Move, anchor and nudge bars in Edit Mode; bind keys with `/kb`. Each bar wears a name tag while the page is open. Actions, paging and keybinds stay Blizzard's. Off by default. |
| Own window (`/mcdm`) | Cooldown Manager | Blizzard's own Cooldown Manager (Essential and Utility cooldowns, Tracked Buffs and Tracked Bars) in the Mode look, in a window of its own opened with `/mcdm` (with **Open CDM** for Blizzard's spell lists), plus up to ten custom Cooldown Bars and Buff Bars (+ and - in the list, deleting after asking): click the **+** slot in the preview to move a spell you track there, add any class spell not in Blizzard's Cooldown Manager, or an item with a Use: effect (potions, healthstones), or add spells and items by ID. Each bar is placed in ModeUI's Edit Mode, anchored to any ModeUI element 1 px off its edge, with Match Width and Match Height, Growth (centered horizontal or vertical, right, left, down, up) and New Lines, icons per line, size (42 by 34 by default) and spacing; the ModeUI border; icons gray on cooldown (on by default, straight to the spell's cooldown while its effect is up), a flat swipe with its own color and opacity; Proc, Active, Off Cooldown (flash or while ready) and Buff glows, off until switched on per spell, each with its own look (Mode Glow, Border, Pixel, Blizzard or GCD), color and pulse from a popout in the preview; cooldown, count, name and time text; Show and opacity. Which spells are tracked stays Blizzard's. Resource Bars in the same window: Power, Combo Points, a Druid's mana in Bear and Cat Form and Health, each in the ModeUI border with its own size (or Match Width), texture, color (power type, class or custom), background, fill direction, smoothing, text (current, percent, current / max), font, Show and opacity, and its own place in Edit Mode. Off by default. |
| Interface | Tooltip | Blizzard's tooltips in the Mode look: a rounded Onyx box (the health bar color) in Mode Gradient with a rounded 1px border (an item's quality color; a player's class color if you turn it on), Expressway lines, player names and class lines in class colors, NPC names by reaction, the level number by difficulty and quest lines in orange-yellow (each adjustable), no health bar, and Minimum Width, Padding and Scale. The main tooltip shows at its own anchor, moved or attached to another element in ModeUI's Edit Mode (or at the cursor), and stays on the screen; Hide in Combat keeps it away while fighting (Shift shows it). Off by default. |
| Interface | Minimap | Blizzard's minimap as a rounded rectangle in the Mode look: 16 px wider than tall (200 by 184 by default; 0 or 8 px also), 8 px corners (or square, 4 or 12 px), a Bold 3px ModeUI border round the map and Thin 1px borders round the button tiles inside it, in the Mode rim color or Onyx, black, Mode Slate, the accent or your class color. The clock above the zone at the bottom (zone colored by PvP status, or white) and coordinates at the top, or both in an Onyx bar under the map, or shown on hover; 24 or 12 hour clock. Tracking, Calendar, New Mail and the Expansion Button on small Mode tiles in the corner you pick; the group-finder eye on its own tile, bottom left by default and moved in Edit Mode. Other addons' minimap buttons in an Addon Buttons box (always, on mouseover or hidden; as wide as the map or its buttons), placed in Edit Mode. Mouse-wheel zoom, Zoom Out After, Opacity and Combat Opacity. Off by default; turning it off asks for a reload. |
| Interface | Bags | Every bag in one Mode window: the backpack, equipped bags, reagent bag and keyring on one grid of slots in the unit frames' health color inside ModeUI's 2px border, with a Mode Gradient header (Sort, Clean Up, close), a search box (the game's own bag search; other items fade), the free slots and your money. Slots look like action bar slots, with rims in the item's quality color (from a minimum quality), quest items in orange and new items in cyan, item levels on gear, stack counts, and gray junk faded with a coin. Sort shows items by Bag Order, Quality, Type or Name without moving them; Clean Up is the game's own sort. Separate Bags, Reagent and Keyring sections, columns, slot size, spacing, padding, scale, colors, fonts and the corner it grows from are adjustable; drag the header or use Edit Mode to move it. The window opens and closes with Blizzard's bags (B, the bag bar, vendors, mail, Esc), and each slot is Blizzard's own item button, so using, selling, dragging and splitting items work as usual, in combat too. Off by default. |
| Frames    | Unit Frames | Secure Player, Target, Target of Target, Focus and Target of Focus frames in the locked Onyx skin, with Mode cast bars, buffs and debuffs, a class resource (combo points for Rogues and Cat Form Druids) around the Target portrait and a click-to-edit live preview: a round portrait with a class-gradient ring, a rounded health/power block inside a pixel-perfect slate rim, Sky names, and a lifted shadow on all text. Text slots (nine on the health bar, one on the border, three on the power bar) each show a name, level, health or power text you pick. Pick the frame to edit above the preview; Frame, Health Bar, Power Bar, Portrait, Cast Bar, Auras, Class Resource and Text tabs each hold their part's own settings, and the Target can match the Player. |
| Frames    | Nameplates  | Onyx plates with separate Enemy and Friendly settings and a live preview on the settings page: health with reaction, class or threat colors, name, health text, cast bars that turn gray when they can't be interrupted, auras (crowd control, debuffs, buffs; position and size per kind), raid markers and a cyan rim on your target. Rounded rims and the Mode Gradient bar texture. Off by default. Friendly plates in instances and your personal resource display stay Blizzard's. |
| Frames    | Party Frames | You and your party on one secure group header, so members join, leave and sort in combat: health and power (for everyone, healers, mana users, healers with mana or no one; below the health or inset) inside the ModeUI border (Mode or Thin, with chat-window corners), class colors, incoming heals, shields and overshields in Mode Slate Hatch, and texts and icons (name, health text, dead and offline, role, leader, raid marker, ready check, summon and resurrect) each with its own switch, anchor, inside or outside place, offset, 1px nudges and size. An aura manager places Healing Buffs, Group Buffs, Defensives, Tracked Buffs (pick buffs with +, like the Cooldown Manager's bars), Dispellable by You, each debuff type (Magic, Curse, Disease, Poison, Bleed), Crowd Control and Other Debuffs each where you want, with which auras it shows, growth, rows, icon width and height, borders, glows, timers and stacks, previewed on its own; it keeps working in combat through Blizzard's aura containers. Debuff effects by type (border, health color, gradient), target and mouse highlights, out-of-range and dead fading, Party Order or Role sorting, four growth directions, spacing, Show When Solo, Edit Mode placement with a sample party (resizing keeps it in place), Test on Screen and a click-to-edit preview of one member, a party or raid sizes that shows each tab's element and any state you pick (dead, ready check, dispel overlay, overshield ...). Blizzard's party frames are hidden while it's on (Hide Blizzard's Party Frames). Off by default. |

The settings window uses the **Mode** theme from Play The Game Tools: graphite
surfaces, a cyan accent, Lato type and the Mode control artwork. It's the only
theme ModeUI has.

## Using it

- `/modeui` opens or closes the settings window. `/modeui resetwindow` re-centers it.
  The **ModeUI** button in the game menu (Esc), in its own group between **Shop**
  and **AddOns**, opens it too, and so does the **ModeUI** entry in the minimap's
  addon menu (the button that lists your addons by the minimap). The window opens
  on **Global** › **Profiles**; the sidebar lists **Global**, **Interface**
  (Windows, Chat, Damage Meters, Action Bars, Tooltip, Bags) and **Frames** (Unit Frames,
  Nameplates, Party Frames). The Cooldown Manager has its own window: type `/mcdm`.
- **Edit Mode** in the window header lets you drag every unit frame, the party frames and each
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
  Modules/         one folder per module (UnitFrames, Nameplates, PartyFrames, ActionBars, CooldownManager, DamageMeters, Chat, Windows, Tooltip, Bags, Minimap, Profiles, Optimizations, ClassColors),
                   each with its own XML, Init.lua, Driver.lua and Settings.lua
  Media/           Mode theme textures, unit frame textures, Lato fonts
tests/             structure, runtime, smoke, Unit Frames, Nameplates, Party Frames, Action Bars, Cooldown Manager, Resource Bars, Damage Meters, Chat, Windows, Tooltip, Bags, Minimap, Global and template tests
                   (simulated client, not WoW)
tools/             texture generators (Python + Pillow; ModeFlat and nameplate shapes in plain Lua)
design/mode/       Mode theme source artwork and provenance
docs/              architecture (docs/ARCHITECTURE.md) and design notes (docs/UNIT_FRAMES.md, NAMEPLATES.md, ACTION_BARS.md, COOLDOWN_MANAGER.md, DAMAGE_METERS.md, CHAT.md, WINDOWS.md, TOOLTIP.md, BAGS.md, MINIMAP.md)
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
lua tests/party_frames.lua
lua tests/action_bars.lua
lua tests/cooldown_manager.lua
lua tests/resource_bars.lua
lua tests/damage_meters.lua
lua tests/chat.lua
lua tests/windows.lua
lua tests/tooltip.lua
lua tests/bags.lua
lua tests/minimap.lua
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
