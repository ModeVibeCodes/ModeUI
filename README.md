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
| Interface | Unit Frames | Secure Player and Target frames in the locked Onyx skin: a round portrait with a class-gradient ring, a rounded health/power block inside a pixel-perfect slate rim, Sky names, and a lifted shadow on all text. Each element (Layout, Portrait, Name & Level, Health, Power, Text) has its own tab, and the Target can match the Player. |

The settings window uses the **Mode** theme from Play The Game Tools: graphite
surfaces, a cyan accent, Lato type and the Mode control artwork. It's the only
theme ModeUI has.

## Using it

- `/modeui` opens or closes the settings window. `/modeui resetwindow` re-centers it.
- **Edit Mode** in the window header lets you drag the Player and Target frames.
  **Preview** shows sample frames.
- Size, visibility and position changes made in combat are applied once combat ends,
  because Blizzard protects clickable unit frames.
- **Unit Frames** is on by default. Turn it off with the switch in the page header.
  Turning it off gives Blizzard's frames back once you're out of combat.

### Coming from Play The Game Tools

The first time ModeUI loads, it copies the Unit Frames settings and frame
positions from your active Play The Game Tools profile, if PTG has any. It only
reads PTG's data and never changes it. After that, ModeUI keeps its own
account-wide settings in `ModeUIDB`.

## Repository layout

```
ModeUI/            the addon folder (this is what goes in Interface/AddOns)
  ModeUI.toc
  Core/            startup, settings, modules, media, Edit Mode positioning
  Config/          Mode-themed settings window and widgets
  Modules/         interface modules (UnitFrames.lua, UnitFramesDisplay.lua)
  Media/           Mode theme textures, unit frame textures, Lato fonts
tests/             Lua smoke and Unit Frames tests (simulated client, not WoW)
tools/             texture generators (Python + Pillow)
design/mode/       Mode theme source artwork and provenance
docs/              design notes (docs/UNIT_FRAMES.md)
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
lua tests/smoke.lua
lua tests/unit_frames.lua
```

## Adding a module

1. Register its category in `Core/Categories.lua` if it needs a new one, for example
   `addon:RegisterCategory("nameplates", { title = "Nameplates" })`.
2. Add `Modules/<Name>.lua` that calls `addon:RegisterModule(id, module)` with
   `category = "<category id>"`. Add a settings page in `Config/<Name>.lua` via
   `module:CreateConfigPage(parent)`.
3. Add the files to `ModeUI/ModeUI.toc`, with modules before `Config\Widgets.lua`
   and pages before `Core\Init.lua`.
4. Add the page to `W.ModeLayoutPlans` in `Config/ModeLayout.lua` for the Mode
   heading treatment.

## License

The original ModeUI code is MIT, Copyright (c) 2026 Mode (see `LICENSE`). The
bundled distribution is GPL-3.0-only because it includes LGPL libraries. See
`THIRD_PARTY_NOTICES.md` and `LICENSES/`.
