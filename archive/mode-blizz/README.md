# Mode-Blizz archive (retired November 20, 2026)

The owner made **Mode-Obsidian** ModeUI's only look on November 20, 2026 and
asked for the art of the previous look to be kept here, in the repository, but
never loaded by the addon. Nothing under `archive/` is in a TOC or inside an
AddOns folder, and no ModeUI code names these files (`tests/smoke.lua` checks
every path the addon names ships, and `tests/style.lua` that Geist is gone).

## What is here

| Path | What it was |
|---|---|
| `ModeUI/Media/Textures/Mode/Borders/cut*.tga`, `round*.tga` | the Mode-Blizz, Mode-BlizzEmpty, Mode-Thin (cut corners) and Mode-Round (round 12/6px) border rings |
| `ModeUI/Media/Textures/Mode/Borders/Ringb2*.tga`, `Rings2*.tga` | the portrait ring lighting of the bevel and specular styles |
| `ModeUI/Media/Textures/Mode/Bars/` | Mode Matte, Gradient, Button, Glass, Cast, Panel, Title and the old Mode BG (with their Base and Lift layers) |
| `ModeUI/Media/Textures/Mode/*.tga` | the pre-Mode settings surfaces (Border, Surface, Sheen, PageAbstract, PillSurface, CheckSurfaceRound, ToggleSurfacePill, Thumb), no longer used by any code |
| `ModeUI/Media/Fonts/Geist/` | Geist Regular, Medium, SemiBold and Bold with its OFL (see `THIRD_PARTY_NOTICES.md`) |
| `code/EdgeData.lua` | the border data with every Mode-Blizz style, shape and lighting profile |
| `code/build_mode_assets.lua` | the asset builder that drew all of the above |
| `code/Assets.lua`, `code/Fonts.lua`, `code/MediaTextures.lua` | the texture and font registries as they were |

The art keeps its original paths under `ModeUI/`, so restoring a file is a copy
back to the same place. The full code of the last version with both looks is
commit `3b601cd` ("Mode-Obsidian: review fixes"); `git checkout 3b601cd --
<path>` brings any file back.

## Bringing a piece back

1. Copy the file(s) back under `ModeUI/Media/...`.
2. Register them again: a border style in `Shared/Style/EdgeData.lua`
   (`STYLES`, `SHAPES`, `PROFILES`, `LIGHTS`; `code/EdgeData.lua` has the
   entries), a texture in `Shared/Style/Assets.lua` (`ASSETS`, `BAR_TEXTURES`),
   Geist in `Shared/Style/Fonts.lua`.
3. Rebuild with `tools/build_mode_assets.lua` only if the data changed (it
   writes only the rings the current `EdgeData.lua` names).
4. Update `docs/DESIGN_LANGUAGE.md` first, as with any visual change.
