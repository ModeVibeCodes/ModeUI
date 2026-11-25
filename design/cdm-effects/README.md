# ModeCDM Icon Effects (November 25, 2026)

The research and planning page for ModeCDM's icon effect suite: how a
cooldown or buff icon reacts to its spell's state (Riposte lighting up after
a parry is the owner's example). It is a planning page, not addon code:
nothing here loads in game, and nothing in `ModeCDM/` or `ModeUI/` changed
for it.

Live page (private to the owner):
https://claude.ai/artifact/MtDgRmXXbe1V8xVWQXfSQu

- `index.html`: the page (Brief, Bench, States, Settings Layout, Colors,
  Inventory, Plan).
- `RESEARCH.md`: the research behind it. It covers the Blizzard Forever
  source and APIs, other addons, the Midnight secret-value limits, and the
  ModeCDM files involved.

## Tabs

- **Brief:** what ModeCDM does today, the gaps, Forever and Midnight notes,
  what other addons do, and the proposal.
- **Bench:** a to-scale CDM in the Bar Style (Rogue or Warrior spells)
  reacting to a simulated fight, with a live editor for every state's look,
  for all spells or for one.
- **States:** every state with its detection, tags and a Build now / Later
  / Skip pick.
- **Settings Layout:** four layouts (A state table, B recipes, C state strip
  and inspector, D rules list) with mockups and pros and cons. C is the
  recommended one.
- **Colors:** each state's default color, taken from `Style.Tone`.
- **Inventory:** Blizzard files and APIs on the Forever branch, and the
  ModeCDM and ModeUI files involved.
- **Plan:** phases 0 to 5 with files and methods, and the open questions.

## Saving

On claude.ai, **Save choices** writes the owner's picks to the artifact's
database as `effects/choices` (the `db` capability). Claude reads that
document (ArtifactData `get`, collection `effects`, doc `choices`) before
building. Opened from disk, the page works but can't save. As of the
commit that added this folder, nothing had been saved yet.

Republishing on another machine: publish `index.html` as an Artifact with
`capabilities: { db: {} }`. Saved choices stay with the original artifact, so
to keep them, update that URL (pass it as `url`) instead of making a new one.
