# Healer layout prototype (November 19, 2026)

The owner's Healer layout, planned before it was built: to-scale previews of
the screen at 1080p and 1440p (Calm and Busy states, overlap and 1px-join
checks, a magnified view of the Player, Target, Focus and party column),
every value against DPS / Tank, the Blizzard API inventory, the party
Defensives double-icon finding and the build plan. It is a planning page,
not addon code: nothing here loads in game. What it planned is built: see
`docs/ARCHITECTURE.md`, "Layouts", and `docs/MODE_REDESIGN.md`, "Revision:
Healer layout".

Live page (private to the owner):
https://claude.ai/artifact/HLq3CPadopGaUukoaT8GHt

`index.html` is a copy of the page as published. It opens from disk in a
browser. To republish it from another machine, publish `index.html` as an
Artifact (no capabilities needed).

The page's model (`build()` in its script) holds the layout's numbers in UI
units at the pixel-perfect scale, from the screen's center, y up. The addon's
own numbers are in each module's `Layouts.lua`, and
`tests/layouts_healer.lua` checks they line up as the page shows.
