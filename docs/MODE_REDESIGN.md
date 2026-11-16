# Mode redesign: status, decisions and plan

The working record of the Mode design-language rollout: what is built, what
the owner decided along the way, how the work is done, and what comes next.
Read this, `AGENTS.md` and `docs/DESIGN_LANGUAGE.md` before continuing on a new
machine or in a new session. Last updated November 15, 2026 (Phase 6
closed: the Cooldown Manager rebuild and ModeCDM confirmed in game, the UI
scale default, the Edit Mode strip and panel, Match Size for any element;
`main` fast-forwarded locally, not pushed).

## Goal

Rebuild every ModeUI module in the Mode design language
(`docs/DESIGN_LANGUAGE.md`): one set of color tokens (`Style.Tone`), border
presets (`Style.Edge`), bar textures ("Mode <Name>" in `Style.Asset`), Geist
fonts and the `Style.Bar` / `Style.Shield` / `Style.Comet` factories, all in
`ModeUI/Shared/Style/`. Modules never hard-code colors, borders, masks,
texture paths or font files; `tests/design.lua` enforces it.

The work goes phase by phase. Each phase (and each module within a phase)
ends at an **in-game gate**: the owner checks it in WoW Forever and confirms
before the next starts.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0 | Baseline screenshots | Done |
| 1 | The standard: `DESIGN_LANGUAGE.md`, `tests/design.lua` + legacy list | Done, confirmed |
| 2 | Assets: Mode textures (`tools/build_mode_assets.lua`), Geist, LibSharedMedia | Done, confirmed |
| 3 | Style core: Tone, Edge, Bar, Shield, Comet, Fonts, Names, `/modeui style` sheet | Done, confirmed |
| 4 | Settings window: hybrid window, widgets, page layouts, tile packing | Done, confirmed |
| 5 | Frames: Unit Frames, Party Frames, Nameplates | Done, confirmed |
| 5b | Texture retune after in-game look (see below) | Done, confirmed |
| 6 | Bars and buttons: **Action Bars**, then **Cooldown Manager** (the ModeCDM addon) | Done, confirmed (November 15) |
| 7 | Windows and panels: Skin layer + Windows, Chat, Damage Meters, Tooltip, Bags, Minimap | Skin layer + Windows done, confirmed (November 15); Chat done, confirmed (November 15); next: Damage Meters |
| 8 | Cleanup: delete legacy border systems and palettes | Not started |
| 9 | Release 0.2.0: notes, notices | Only with the owner's go-ahead |
| 10 | New coverage (optional) | Waits on decision 2 |

### What each finished module carries now

- **Unit Frames** (layout version 23): Mode Matte health, Mode Gradient power,
  Mode Cast casts, Mode BG empty bars, Geist, Gradient names, health text
  colored by health with a soft glow, a 3px edge-lit Steel portrait ring with a
  1px shadow ring, Combined shields. See `docs/UNIT_FRAMES.md`.
- **Party Frames** (settings version 7): the `group` edge, 150 x 34 + 3, Mode
  Glass health (owner's pick), Shields tab (texture, color, opacity), Gradient
  names, aggro/target/dispel rim swaps, dispel Gradient. See
  `docs/PARTY_FRAMES.md`.
- **Nameplates** (settings version 11): `frameThin` edge, Ivory target line,
  Rosewood focus line, Mode BG fills, Mode Cast with the Comet spark, gradient
  names, health text by health with glow. See `docs/NAMEPLATES.md`.
- **Aura icons** everywhere (`Shared/Kit/AuraIcon.lua`): the `frameThin` edge,
  Border Size 1 or 2, dispel type tints the rim.
- **Action Bars** (settings version 6): 40 x 34 buttons in the `frame` edge
  outside each button, Mode Button face, Ivory hover line, Celadon proc rim,
  Mode icon tints (range, power, unusable), Geist Bold texts. See
  `docs/ACTION_BARS.md`.
- **Cooldown Manager** (settings version 5, built and confirmed November 15): icons 40 x 34 / 32 x 28 in the `frameThin` edge outside the icon
  (the approved probe), a Mode Button face, Spacing between the shadows,
  Border glows as a Mode Empty rim swap (Celadon procs and buffs, Ivory active
  and ready), Rosewood out of range, Geist Bold texts; Tracked Bars 220 x 16 in
  Mode Gradient on Mode BG with the Comet spark in your class color; Resource
  Bars in the `frameThin` edge, Mode BG at 60%. Ships as the companion addon
  **ModeCDM** (`ModeCDM/`), nested under ModeUI in the AddOn list. See
  `docs/COOLDOWN_MANAGER.md` and "Companion addons" in `docs/ARCHITECTURE.md`.
  A provenance audit (November 15) found no code from other authors in it;
  its racial spell list follows Blizzard's `TrackedCooldowns.lua`.

### Texture retune (owner's in-game feedback, November 15)

- Module bars draw a Mode texture's **base plus its white lift** over the fill
  (`Style.ApplyBarLook` via `Kit.BarForeground`), not the single baked file:
  the multiply was hiding the light on dark fills. The baked files are only for
  other addons through LibSharedMedia.
- `darkFill` is `#1C1D1C` (owner's pick); Unit Frames' Default health uses it.
- Empty bars are Slate `#575757` at 60% (`Tone.emptyAlpha`) with no black
  plate behind them, so the world shows through.
- Mode Matte has a gentle sheen lift (`MatteLift`); the settings window keeps
  the plain face (`MatteBase`).
- Borders keep one physical pixel even when the host's scale changes after
  layout: each `Style.Edge` holder ignores parent scale and takes Blizzard's
  pixel factor (fixed huge rims on nameplate aura buttons).
- Health text glow: on by default, 22%, a soft round halo sized from the
  format (health text is never measured; it can be secret).

The owner may keep tuning textures; expect small edits to
`tools/build_mode_assets.lua` profiles and `Style.Tone` values.

## Next steps, in order

1. ~~Cooldown Manager in-game gate~~: confirmed November 15;
   `probes/ModeUI_ProbeBars` is deleted.
2. **Phase 7**, one module per gate, from `probes/ModeUI_ProbePanels`
   (approved): the Skin layer and Windows module, then Chat, Damage Meters,
   Tooltip, Bags, Minimap (each module's current behavior is in its own doc).
   Retire each probe tab as its module ships; delete the probe addon (and
   `ModeUI_ProbeFrames`, whose designs are all built) when empty, along with
   their `tests/probes.lua` entries and `tools/build_probes.ps1` targets.
3. **Phase 8 cleanup**: delete the legacy border systems (`Kit.ModeBorder`,
   `Kit.Rim`, `Kit.PlaceRim`, `Shared/Kit/Border.lua`, the masked rounded
   rims), the old palettes (`Kit.onyx`, `Kit.palette` where unused), the
   legacy slot art, and Lato (decision 4). `tests/design_legacy.lua` should end
   empty. Keep every saved key working (migrate, never reset).
4. **Phase 9 release** 0.2.0: release notes and notices. Only when the owner
   says so.
5. **Phase 10** only after decision 2 (below).

## Decisions

From the plan's "Decisions for you" (owner's answers):

1. **Cooldown Manager window:** stays a separate window, and ships as a
   companion addon. The owner named it **ModeCDM** (November 15): it shows as
   its own entry nested under ModeUI in the AddOn list, and its options and
   settings stay linked with ModeUI (`ModeUIDB`, ModeUI's Edit Mode and
   profiles).
2. **New coverage** (Pet, Boss, Arena and Raid frames, Buffs and Debuffs, XP and
   reputation, breath timer, Loot, Objective Tracker, Extra Action button):
   recommended after Phases 0-9, one at a time, most wanted first. **Open:**
   ask the owner before starting Phase 10.
3. **Fonts:** first Geist replaced Expressway as the default (each rebuilt
   module's migration). Then, November 15, after seeing Geist in text-heavy
   windows in game, the owner chose **Expressway when the client has it**
   (an installed addon's copy; ModeUI can't ship the commercial font), with
   Geist as the fallback. The font name "Mode" points at whichever the client
   has; profile typeface step 2 (`Shared/Runtime/DB.lua`) moves every saved
   "Mode Geist" to "Mode"; anyone who picked a different font keeps it.
4. **Lato:** kept registered for one version, removed in Phase 8.
5. **Options → AddOns entry:** none.
6. **Branches and releases:** one branch per phase (`t3/mode-phase-N-<name>`),
   fast-forwarded into `main`; version 0.2.0 at the end; pushes and releases
   only with the owner's go-ahead.

Owner preferences gathered along the way:

- **Edit Mode** (November 15): a slim strip across the top (Highlights,
  Center Lines, Grid, Exit) and a small element panel under it (Position,
  Snap To, Match Size, a small Settings button), replacing the tall window
  whose toggle labels clipped. Match Width and Match Height follow an element
  you click, independent of the anchor.

- **UI scale** (November 15): ModeUI fits itself pixel perfect at 1080p and
  1440p from the screen the game reports. Optimizations' Set UI Scale starts
  on at Pixel Perfect (version 2 migrates profiles still at the old default,
  off); **General** › **UI Scale** has a one-click "Use <scale>" button.

- **Probe addons first.** New designs ship as probe addons (`probes/`,
  `/mprobe <name> [tab]`, zips from `tools/build_probes.ps1` into
  `dist/probes/`, gitignored) so the live addon is never broken while the
  owner can't check. Once a probe is approved, build it into the real module.
- **Icons** are wider than tall: 4px shorter up to 35px wide, 6px from 36px.
- 1px edge-lit rims use half the edge light (the top read heavier).
- **Settings window:** sidebar captions Interface / Panels / System; footer
  keeps Reload and Preview on the left; "strip" layout (rail, preview across
  the top, cards below) for small previews, "split" only for tall ones; tiles
  pack in bands; the window closes when combat starts; the sidebar uses Mode
  Matte.
- **Notes are tips only:** about 90% of descriptive text was removed;
  `W.Note` hides, `W.Tip` keeps usage tips, game-option dependencies, conflicts
  and empty-tab reasons. Run `tests/settings_fit.lua` after any settings
  change (it audits every page at real widths).
- **Segmented choices** sit side by side only when every label fits, else a
  compact dropdown in place (no vertical stacks). Multi-pick lists are
  ChoiceGrid buttons, not toggles.
- **General page grows per phase:** it shows only cards whose settings the
  modules already obey; Accent/Text/Textures/Borders/Shields/Names/Scale/
  Combat cards arrive with the phase that makes modules follow them.
- **Unit Frames** (owner, in game): Portrait Size 140, no lifted shadow, cast
  icon on the portrait side, SemiBold names, Gradient to 50% white.
- **Party Frames:** Mode Glass health; shields on their own tab.

## How the work is done

- **Order:** design doc first, then `Shared/Style/`, then the modules. Files
  stay under 400 lines. Secure frames change only out of combat. No
  placeholder functionality.
- **Saved variables:** never reset `ModeUIDB`. Each module has a settings
  version and a migration; a new default only replaces a value still equal to
  the old default (`Style.SameColor` for colors). Old defaults needed by
  migrations live in `Style.LEGACY` or as named constants in the module, never
  as color literals in modules.
- **Tests:** run every `tests/*.lua` except `harness.lua`, `wow_mock.lua`,
  `design_legacy.lua` and `*_stubs.lua`. They run in a simulated client (no
  WoW rendering, security or taint), so the owner's in-game check is the real
  gate. No Python is needed; any Lua 5.3+ works (on the owner's Windows
  machine, the `lua-language-server.exe` bundled with the VS Code Lua
  extension runs them). A loop:

  ```sh
  for t in tests/*.lua; do case $t in *stubs.lua|*harness.lua|*wow_mock.lua|*design_legacy.lua) continue;; esac
    lua "$t" >/dev/null 2>&1 || echo "FAIL $t"; done
  ```

- **Textures:** `lua tools/build_mode_assets.lua` from the repository root
  regenerates every Mode texture (deterministic; commit the changed TGAs).
- **Manual checks** given to the owner use Navigation / Action / Required
  state / Confirmation with the real control labels.
- **Commits:** commit on the phase branch, fast-forward `main`, push only with
  the owner's go-ahead. Never force-push or reset; no bare `git stash`.

### Things learned the hard way

- **Secret values** (Forever 12.x): unit values can be secret in combat.
  Pass them only to widgets that accept them (`SetValue`, `SetText`,
  `SetVertexColor`, `SetTextColor`, `SetVertexColorFromBoolean`,
  `SetAlphaFromBoolean`). Never measure a FontString that may hold secret
  text; its sizes become secret too.
- **Aura containers** create their buttons once (`initializeFrame`) at
  whatever scale the plate has then, so anything sized from the host's scale
  at that moment goes stale. Hence the edge holders' own pixel grid.
- **LibSharedMedia vs Mode looks:** modules must draw lifted textures in two
  layers (base + lift); see Texture retune above.
- **Masks:** a texture holds at most 3 masks; a 4th errors and stops ModeUI
  loading. Mode borders need no masks.
- **Line endings:** the repository has `* -text`; most files are LF but
  `tests/wow_mock.lua` is CRLF (with some LF lines) and `docs/UNIT_FRAMES.md`
  is mixed. Edit those byte-safe (a small Lua replace script) and check
  `git diff --stat` before committing.
- **Blizzard UI source:** use the local mainline copy or the `forever` branch
  of github.com/Gethe/wow-ui-source to confirm APIs; never assume Retail
  behavior applies to Forever.

## Resuming on another machine

1. Clone the repository and check out `main`.
2. Read `AGENTS.md`, this file, `docs/DESIGN_LANGUAGE.md` and
   `docs/ARCHITECTURE.md`.
3. Run the whole test suite; it should pass.
4. To test in game, link or copy `ModeUI/` and `ModeCDM/` into WoW Forever's
   `Interface/AddOns/`. For probes, run `tools/build_probes.ps1` and extract
   the zips from `dist/probes/` into the same folder.
5. Start the next step above on a new branch.
