# Mode-Obsidian: plan, inventory and change log

The owner approved a redesign of ModeUI from the Mode-Blizz look to
**Mode-Obsidian** on November 20, 2026, and asked for it to be built in one
unattended run. The source of the look is the Mode Obsidian page
(https://claude.ai/artifact/FmYkTTQsWESUUoz21vBuvG), after three rounds of
studies (Lookbook, Pane Studies, Lens Studies). The owner's picks:

- **Obsidian** as the base: black glass, soft rounded corners, a quiet border
  (a black outer line, a soft lit top row, a warm champagne bottom row).
- **Dark first:** health is a near-black fill on a lighter graphite track.
  Color stays in hints: names, spell names, portrait rings, power, states.
- **Class-colored portrait rings** in the Obsidian/Prism style.
- **Prism glow** only as a supplement: mouseover and focus.
- **Backlit dispels:** the dispel type's color rising from the bottom edge.
- **Urbanist** for text ("Everything else in this look crushes. Including the
  font change.").
- The health fill's end line: a lighter white with a light-blue hue, kept
  inside the border (owner, on the unit frame screenshot).
- Names: "Mode-<Name>" for everything new.
- A guard against wanting to revert: a separate profile.

## How it is built (the decisions)

1. **The theme is a profile setting** (`profile.theme`: `"blizz"` or
   `"obsidian"`). A profile without it is Mode-Blizz, so every existing
   profile looks exactly as before, and an older ModeUI simply ignores the
   key (profiles keep unknown keys; `Shared/Runtime/DB.lua`).
2. **The guard: a Mode-Obsidian profile.** On the first start with this
   code, ModeUI copies the active profile to **Mode-Obsidian**, gives the copy
   the Obsidian theme and makes it active. The old profile is untouched:
   switch back to it in `/modeui`, Profiles, and reload. (Once per account,
   recorded in `ModeUIDB.builtThemes`.) A backup of the saved variables from
   before the first run is at
   `C:\Users\mikew\Documents\ModeUI-backups\ModeUI.lua.pre-obsidian-2026-11-20`
   (made from commit `e9246c0`).
3. **Borders follow the theme in Style.** Under Obsidian, `Style.Edge` and
   the portrait ring draw every Mode metal style (Mode-Blizz, Mode-Thin,
   Mode-Round) as **Mode-Obsidian** and Mode-BlizzEmpty as
   **Mode-ObsidianEmpty**. That reaches every border, the hard-wired ones
   included (aura icons, windows, the settings window), without touching a
   saved `edgeStyle`. The reach of every role is unchanged, so no layout
   moves. Border Metal still works (the Obsidian lighting in Silver, Steel or
   Gunmetal tones); the default metal is Obsidian's own.
4. **Theme parts set module defaults.** Like a layout part, each module may
   add an Obsidian part (`addon.Themes:Contribute("obsidian", moduleId, fn)`)
   that sets its own Obsidian defaults (dark health, the new bar textures,
   the glow toggles). A part runs once per profile and module
   (`profile.themeParts`), so whatever the player changes afterwards stays.
   Companion modules (ModeCDM) get theirs when they start.
5. **Token values follow the theme.** Under Obsidian, `Style.ApplyTheme`
   sets the surface tokens in place after the profile is checked: deeper
   Graphite and Mono panels, the dark fill, the lighter graphite track, warm
   white text. Code that reads tokens at draw time follows automatically.
6. **The Mode typeface follows the theme.** Under Obsidian, "Mode" is
   **Urbanist** (bundled, OFL), Expressway or not.
7. **No settings version bumps.** Every new setting is a new key with a
   default (filled by each module's `Initialize`), so an older ModeUI can
   still read every profile but Mode-Obsidian (whose new values, such as the
   Mode-Obsidian style, it doesn't know).

## Inventory

What draws ModeUI's look today, and how each part reaches Obsidian.

| Area | Files | How Obsidian reaches it |
|---|---|---|
| Border factory | `Shared/Style/Edge.lua`, `EdgeData.lua` | new shapes (soft round 6px heavy, 4px thin), Obsidian lighting, styles `obsidian`/`obsidianEmpty`, metal `obsidian`; theme mapping in `Style.Edge`, `Edge:SetStyle`, `Style.SetRingStyle` |
| Border art | `tools/build_mode_assets.lua` (reads EdgeData) | new rings generated from the data; portrait ring profiles |
| Tokens | `Shared/Style/Tone.lua` | `Tone.metal.obsidian`, `Style.OBSIDIAN` values, `Style.ApplyTheme` |
| Fonts | `Shared/Style/Fonts.lua`, `Media/Fonts/Urbanist/` | Urbanist static weights + OFL; "Mode" resolves to Urbanist under Obsidian |
| Bars | `Shared/Style/Bar.lua`, `Shared/Kit/Shape.lua`, `Shared/Kit/Edges.lua` | Mode-Obsidian fill and Mode-Obsidian Track; the fill-end line ice white, inset 1px; the track tint |
| Glow | new `Style.Glow` (`Shared/Style/Glow.lua`) | Prism glow for mouseover and focus |
| Runtime | `Shared/Runtime/DB.lua`, new `Themes.lua` | `profile.theme`, `profile.themeParts`, the registry, seeding Mode-Obsidian |
| Unit Frames | `Modules/UnitFrames` | part: dark health, Mode-Obsidian textures, class-colored names, glow on mouseover and on the focus frame |
| Party Frames | `Modules/PartyFrames` | part: dark health, Mode-Obsidian textures, Backlit dispels (gradient from the bottom), glow on mouseover and focus |
| Nameplates | `Modules/Nameplates` | part: focus glow; edges by the theme; reaction colors kept (gameplay meaning) |
| Buffs & Debuffs, aura icons | `Modules/BuffsDebuffs`, `Shared/Kit/AuraIcon.lua` | edges by the theme |
| Action Bars, Cooldown Manager | `Modules/ActionBars`, `ModeCDM/` | edges by the theme; faces from tokens |
| Windows, Chat, Tooltip, Bags, Damage Meters, Minimap | `Shared/Skin`, those modules | edges by the theme; panels from tokens; saved window colors in their parts |
| Settings window | `Shared/Settings` | edges by the theme; palette from tokens; the Border Style picker lists the theme's styles |

## Assets (all generated by `tools/build_mode_assets.lua`)

The labeled bundle, with the approved mock and an offline render of the real
textures, is `design/obsidian/` (README.md, approved-mock.html, preview.png).

| Name | File | Job |
|---|---|---|
| Mode-Obsidian rings | `Borders/softHeavy*.tga`, `Borders/softThin*.tga` (21 files) | every Obsidian border ring (the data names them) |
| Mode-Obsidian ring lighting | `Borders/Ringorh.tga`, `Borders/Ringord.tga` | the class-colored portrait ring's lit top and deeper bottom |
| Mode-Obsidian | `Bars/ObsidianBase.tga`, `Bars/ObsidianLift.tga`, `Bars/Obsidian.tga` | dark glass health fill (LibSharedMedia "Mode-Obsidian") |
| Mode-Obsidian Track | `Bars/ObsidianTrack.tga` | the lighter graphite empty part (LibSharedMedia "Mode-Obsidian Track") |
| Mode-Prism | `Glows/Prism.tga` | the soft glow behind a frame on mouseover and focus |
| Mode-Urbanist | `Media/Fonts/Urbanist/` | the typeface (Regular, Medium, SemiBold, Bold; OFL) |

## What each element looks like under Mode-Obsidian

| Element | Mode-Obsidian |
|---|---|
| Every border (frames, buttons, icons, auras, windows, tooltips, chat, meters, bags, minimap, settings window) | Mode-Obsidian: soft round corners (6px on `frame` and `window`, 4px elsewhere), black outer line, dark glass band, a soft lit top row, a champagne bottom row; same reach as before |
| Proc, ready, aggro, quest and dispel rims | Mode-ObsidianEmpty: the same soft shape, one flat color |
| Portrait rings | class or reaction color, lit top, deeper bottom, between black lines |
| Unit Frames health | dark: `#161618` in Mode-Obsidian over Mode-Obsidian Track at 85%; names in the solid class or reaction color; ice fill-end line 1px inside the bar |
| Unit Frames glow | Prism glow on mouseover (Player, Target, Target of Target, Target of Focus); always on the Focus frame |
| Party Frames | dark health on the same textures; Backlit dispels (the type color rising from the bottom); Prism glow on mouseover and on your focus (the white mouse tint off) |
| Nameplates | reaction-colored health kept (gameplay meaning) over Mode-Obsidian Track at 85%; focus in the Glow; soft borders |
| Cooldown Manager | soft borders; every bar's empty part Mode-Obsidian Track at 85% (bars were already Dark) |
| Windows, Chat, Tooltip, Bags, Damage Meters | deeper Graphite panels (`#0B0B0C`), warm text; saved colors still at the Mode-Blizz tokens moved to Mode-Obsidian's |
| Text everywhere | Urbanist (Mode-Urbanist); warm whites (`#E8E3D9`, `#F7F3EA`) |
| Settings window | the same palette, rebuilt from the theme's tokens; Border Style pickers list Mode-Obsidian and Mode-ObsidianEmpty; Profiles has New Mode-Obsidian Copy |

## Going back

- **In the game:** `/modeui`, Profiles: choose the profile you had before
  (the chat line after the first login names it), **Switch to This Profile**,
  then reload. It is untouched and draws Mode-Blizz.
- **The code:** the work is on branch `t3/obsidian` (from `e9246c0`). No
  module's settings version changed, so an older ModeUI still reads every
  profile except Mode-Obsidian (and any profile where you picked a
  Mode-Obsidian style yourself). Switch to your old profile before going back
  to older code.
- **The saved variables** from before the first run:
  `C:\Users\mikew\Documents\ModeUI-backups\ModeUI.lua.pre-obsidian-2026-11-20`.

## In-game checks (nothing here was run in the game)

1. **First start.** Navigation: log in. Action: read the chat. Required
   state: this code in the AddOns folder (the junction points at the
   repository's `ModeUI` folder). Confirmation: a ModeUI line says the
   settings were copied to Mode-Obsidian and names the old profile;
   `/modeui`, Profiles, Active Profile reads Mode-Obsidian.
2. **Borders and type.** Navigation: look at the Player frame, action bars
   and a tooltip. Action: none. Required state: Mode-Obsidian active.
   Confirmation: soft round borders with a faint lit top and a warm bottom
   line; Urbanist text.
3. **Dark health and the end line.** Navigation: Player frame. Action: take
   some damage. Required state: Mode-Obsidian. Confirmation: the health is the
   near-black part, the missing part lighter gray, and a 1px light-blue line
   marks the end without touching the border.
4. **Prism glow.** Navigation: Player and Target frames, party frames.
   Action: hover a frame; set a focus. Required state: Unit Frames, Frame tab,
   Border card, **Prism Glow** Mouseover; Party Frames, Highlights, **Hover
   Glow** and **Focus Glow** on. Confirmation: a soft class-colored glow
   round the hovered frame; the Focus frame glows all the time.
5. **Backlit dispels.** Navigation: party frames. Action: a party member gets
   a debuff you can dispel. Required state: Party Frames, Highlights, Dispel
   Overlay, **Gradient From** Bottom. Confirmation: the type color rises from
   the bottom edge of that member.
6. **Going back.** Navigation: `/modeui`, Profiles. Action: choose the old
   profile, **Switch to This Profile**, reload. Required state: none.
   Confirmation: Mode-Blizz exactly as before.

## Not checked, and follow-ups

- Nothing was run in the game. The client calls used (`SetBlendMode("ADD")`,
  `SetIgnoreParentScale`, slice margins on the Prism glow, Urbanist through
  `SetFont`) are ones ModeUI already uses elsewhere. The glow's secret-safe
  path (`SetAlphaFromBoolean`) is not used yet: party focus uses the same
  public check as the target highlight.
- Not reached by the theme: Edit Mode stand-ins keep their cyan fill, and the
  legacy Onyx colors (cast bar tracks, combo sockets) stay as they are.
- Nameplates have no mouseover glow (they have no hover handling today).
- The approved mock showed gray cast fills in dark mode; cast bars keep their
  cast colors (casting, channeling, not interruptible), since they carry
  meaning.

## Change log

Entries are added as each piece lands (newest last).

- 2026-11-20: plan written; branch `t3/obsidian` from `e9246c0`; baseline: all 27 tests pass.
- 2026-11-20: Urbanist bundled (four static weights, OFL, notice in `THIRD_PARTY_NOTICES.md`).
- 2026-11-20: design doc first: "Mode-Obsidian theme" in `docs/DESIGN_LANGUAGE.md`.
- 2026-11-20 (`daa5534`): theme core: tokens and `Style.ApplyTheme`, Obsidian shapes, lighting and styles in `EdgeData.lua`, theme mapping in `Edge.lua` and the ring, Urbanist in `Fonts.lua`, `Style.FillEnd`, Mode-Obsidian bar textures, `Style.Glow`, `Shared/Runtime/Themes.lua`, profile seeding in `DB.lua`, the harness default, `tests/obsidian.lua`. 28 new textures; every existing texture unchanged.
- 2026-11-20 (`a4945f1`): theme parts for Unit Frames, Party Frames, Nameplates, Action Bars, Bags, Chat, Damage Meters, Tooltip, Windows and the Cooldown Manager; Unit Frames' Prism Glow (Off, Mouseover, Always); Party Frames' Hover Glow, Focus Glow and Gradient From; pickers list the theme's styles while settings checks accept every style (a picked Mode-Obsidian style would otherwise have failed validation); new and layout profiles take the active theme; `tests/settings_fit.lua` runs in both themes.
- 2026-11-20 (`24559f5`): the settings window's palette rebuilds from the theme's tokens (`Style.OnThemeApplied`); brighter Obsidian rows after the offline render (hi `#6E6E74`, light `#8C806A`).
- 2026-11-20 (`e2ecba3`): Profiles: New Mode-Obsidian Copy (`Profiles:CreateThemed`); `Style.IsFlatStyle` where Mode-BlizzEmpty was checked by name (Cooldown Manager); the minimap's metal swatch reads the theme's style.
- 2026-11-20: the asset bundle `design/obsidian/` and `tools/render_obsidian_preview.lua`; `docs/ARCHITECTURE.md` "Themes"; warm keybind and meter header text in the Action Bars and Damage Meters parts.
