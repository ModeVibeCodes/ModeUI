# ModeCDM Workbench (November 24, 2026)

The planning page for the ModeCDM organization, structure and features pass.
It is a planning page, not addon code: nothing here loads in game, and
nothing in `ModeCDM/` changed for it.

Live page (private to the owner):
https://claude.ai/artifact/B7sAjyhRsKvJ2Fy8c651nT

Tabs: Brief (findings), House Style (shared default rules with a to-scale
preview), Window (list structure options), Pages (where each control goes:
Always, More options, House Style or Remove), Features (Build now, Later,
Skip), Words (label changes), Inventory (files, WoW API, game files) and
Plan (phases with files and methods, plus open questions).

## Saving

On claude.ai, **Save choices** writes the owner's choices to the artifact's
database as `workbench/choices` (the `db` capability). Claude reads that
document before building. Opened from disk, the page works but can't save.

Republishing on another machine: publish `index.html` as an Artifact with
`capabilities: { db: {} }`. Saved choices stay with the original artifact.

## What was built

The owner's saved choices (November 24, 2026) were built on `t3/cdm-rework`
and merged into `main`: see `docs/COOLDOWN_MANAGER.md`, "The window (rework,
November 24, 2026)", and `docs/MODE_REDESIGN.md`, "Revision: ModeCDM
rework". Items marked Later on the Features tab (poisons and imbues, pet
bar, keybind text, sharing a setup, per-spec setups) are not built.
