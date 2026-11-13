# ModeUI — Forever only

- This repository is the home for Mode's custom interface modules for WoW Forever.
  Edit the addon in `ModeUI/`. Play The Game Tools is a separate addon and repo.
- The settings window uses the Mode theme only. Keep new pages on the shared
  widgets in `Shared/Settings/` so they inherit it.
- Preserve functionality, appearance, settings and saved-variable keys unless
  the user asks for a specific change. Never reset `ModeUIDB`; migrate instead.
- Read the relevant source before editing, and implement one focused feature at a time.
- Research uncertain APIs in current Blizzard source and docs. Never invent APIs,
  bypass restrictions, or assume Retail behavior applies to Forever. Unit values
  can be secret: pass them only to widgets documented as accepting them.
- Secure frames are created, shown, moved and resized outside combat only.
- Follow `docs/ARCHITECTURE.md`. New code goes in `Libs/`, `Shared/` or
  `Modules/<Name>/`, never the legacy `Config/` folder. Each module is a
  folder with `<Name>.xml` (listed in the TOC), `Init.lua` loaded first, and
  `Driver.lua`. Code two modules need belongs in `Shared/`; modules never use each
  other's files. Files stay under 400 lines. Settings pages are built only when opened.
- Keep `ModeUI/ModeUI.toc` load order correct. No placeholder functionality.
- Run `lua tests/structure.lua`, `lua tests/runtime.lua`, `lua tests/smoke.lua`,
  `lua tests/unit_frames.lua` and `lua tests/global.lua`. Do not claim native testing without the user's in-game confirmation.
- Manual checks must state Navigation, Action, Required state and Confirmation,
  using the actual control labels. Do not invent UI paths.
- Releases, pushes and collaborator invitations need the user's authorization.
- Preserve licenses and notices. Never force-push or reset.
