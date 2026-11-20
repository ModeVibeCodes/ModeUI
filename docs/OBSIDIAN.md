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

| Name | File | Job |
|---|---|---|
| Mode-Obsidian rings | `Borders/soft*.tga` | every Obsidian border ring (the data names them) |
| Mode-Obsidian ring lighting | `Borders/Ring<profile>.tga` | the class-colored portrait ring |
| Mode-Obsidian | `Bars/ObsidianBase.tga`, `Bars/ObsidianLift.tga`, `Bars/Obsidian.tga` | dark glass health fill (LibSharedMedia "Mode-Obsidian") |
| Mode-Obsidian Track | `Bars/ObsidianTrack.tga` | the lighter graphite empty part (LibSharedMedia "Mode-Obsidian Track") |
| Mode-Prism | `Glows/Prism.tga` | the soft glow behind a frame on mouseover and focus |
| Mode-Urbanist | `Media/Fonts/Urbanist/` | the typeface (Regular, Medium, SemiBold, Bold; OFL) |

## Change log

Entries are added as each piece lands (newest last).

- 2026-11-20: plan written; branch `t3/obsidian` from `e9246c0`; baseline: all 27 tests pass.
