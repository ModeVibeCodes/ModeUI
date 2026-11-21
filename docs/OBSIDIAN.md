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

## Update: the only look (November 20, 2026, after the owner's check)

The owner saw Mode-Obsidian in the live addon ("it looks great") and asked
for the next step, which supersedes decisions 1-3, 6 and the "Going back"
section below:

- **Mode-Obsidian is the only look.** The Mode-Blizz art (borders, ring
  lighting, the Matte, Gradient, Button, Glass, Cast, Panel, Title and old BG
  textures, the pre-Mode settings surfaces) and the Geist typeface no longer
  ship; a copy is kept in `archive/mode-blizz/` (with the old `EdgeData.lua`
  and builder; see its README). Every profile turns Mode-Obsidian when it is
  checked; the first-start copy and New Mode-Obsidian Copy are retired.
- **Renamed:** the bar textures **Mode-FG** (was Mode-Obsidian) and
  **Mode-BG** (was Mode-Obsidian Track); the border styles **Mode-Border**
  (was Mode-Obsidian) and **Mode-Empty** (was Mode-ObsidianEmpty). Style ids
  stay `obsidian` and `obsidianEmpty`; old ids and texture names stay valid
  and each profile moves its saved ones once (look step 1; Geist weights:
  typeface step 4).
- **Type:** Urbanist only (Mode-Urbanist); an installed Expressway is just a
  font a player may pick.
- **Softer edge:** the shadow ring at 65% (was 90%), the dark glass `deep`
  `#19191C` (was `#0F0F11`), and longer fades on the lit top row (gone 42%
  down, was 33%) and the champagne bottom row (from 62% down, was 72%).
- **Every old surface in the new look:** buttons, icon faces, title strips
  and cards are Mode-FG; large panels are **Surface** (Solid plus the mock's
  soft sheen).
- **Role profiles:** **Mode-DPS/TANK** (the DPS / Tank layout, Mode-Default
  before) and **Mode-Healer**, remade in Mode-Obsidian under new seeds
  (`mode-default@2`, `healer@2`). The Cooldown Manager's icons are
  **Mode-Empty** in a neutral, darker rim (`Tone.emptyRim` `#343438`), by
  default and in both layouts. An account the first seeds reached keeps its
  old Mode-Default and gets its old Mode-Healer renamed "Mode-Healer (old)".

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

## Going back (superseded: see the update above)

Mode-Blizz no longer ships. To bring a piece back, see
`archive/mode-blizz/README.md`; the last code with both looks is `3b601cd`.
What follows was true before the update.

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
   repository's `ModeUI` folder), and the game fully restarted (new font and
   texture files don't load on `/reload`). Confirmation: a ModeUI line says the
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
- 2026-11-20: every theme part puts border metals back to the style's own (`Themes.DefaultMetal`; new parts for Buffs & Debuffs and the Minimap), so a layout's Steel or Gunmetal no longer tints the Obsidian rims gray in the Mode-Obsidian copy (the original profile keeps them). Checked against the owner's real saved variables (the backup) in the test harness: the first start copies "2s" to Mode-Obsidian, runs every part, and all six profiles still pass validation.
- 2026-11-20: fixes from an independent review of the whole diff (no runtime, secret-value or combat problems found): a module is marked in `themeParts` only when its part ran, so a part added later still runs; the Play The Game Tools import runs before the first start, and an account that imported gets a Mode-Obsidian copy (the import keeps its own profile); the first-start copy is checked before it is made active, and a copy that fails leaves the account as it was (tried again next start); on Player and Target the frame border's soft drop steps aside while the Prism glow shows; Action Bars and Buffs & Debuffs migrations write Mode-Blizz values whatever theme is in use; Party Frames lay out their glow with the member. Regression tests in `tests/obsidian.lua`.
- Note for the first in-game run: the Urbanist fonts and the new textures are new files, so the game must be fully restarted (not just `/reload`) before they load.
- 2026-11-20 (after the owner's in-game check): Mode-Obsidian only. Mode-Blizz art and Geist archived to `archive/mode-blizz/` (never loaded); renames Mode-FG, Mode-BG, Mode-Border, Mode-Empty; Urbanist only; the softer edge; Surface for large panels and Mode-FG for every other surface; the look step and typeface step 4; Mode-DPS/TANK and Mode-Healer remade in Mode-Obsidian (new seeds, the old Mode-Healer kept as "(old)"); the Cooldown Manager's icons in Mode-Empty with `Tone.emptyRim`. Checked against the owner's current saved variables in the test harness: all six profiles validate and no old texture, style or Geist name is left.
- 2026-11-20 (owner's next in-game check): ModeUI's Edit Mode frames were restored by the client's layout cache (layout-local.txt) at login over the profile's places, and the anchor cache kept them there until Edit Mode; Shared/Placement/PositionRestore.lua keeps them out of the cache and places every element again after login, and Positioning notices a moved frame. Role layouts @3: the tooltip left of the meters, the bag window on the top meter's corner, Tracked Bars under Utility, resource texts that fit their bars.
- 2026-11-20 (owner's 1440 Healer check): the party column hangs from its top right, snug under the mana frame; the Healer Cast Bar 20 tall; the Cast Bar in your class color by default in every profile (ModeCDM version 10); Healer layout seed @4.
- 2026-11-20 (owner's next Healer check): the party header hangs by its Top on the stand-in's top middle (a corner anchor let the header's own width shift the column 2px right of the Player frame); the Target's health in its class or reaction color by default, its own while matched (Unit Frames layout version 25).
- 2026-11-20 (owner's next Healer check, 1440p at 1.2 pixels a unit): the party column hangs from the Player frame's bar block (unitFramesPlayerBars) so its right edge is the frame's real one; the stand-in's size no longer moves a pinned edge; moves and resizes cascade to anchored elements; the Healer Focus 80 lower; seed healer@5.
