# Interface: Minimap

November 14, 2026. A module in the **Interface** category, after Bags. Off by
default (turn it on with the switch in the page header). Static/mock
validated only; **native acceptance is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#minimap--november-14-2026). The
look was approved in the plan canvas
(https://claude.ai/artifact/MRLooaetaRKR4UBbqbysEQ) before any code.

## The look (owner's design)

- A rounded rectangle, **16 px wider than tall** (200 × 184 by default), with
  **8 px corners** (Medium).
- The ModeUI border round the map in **Bold** (3 physical pixels) and **Thin**
  (1 px) borders round the button tiles inside it, in the Mode rim color
  (#40454C) unless another Border Color is picked.
- The clock above the zone, centered at the bottom of the map; coordinates
  centered at the top. Expressway with ModeUI's lifted shadow. Zone text in
  Mode tones by PvP status (green friendly, amber contested, red hostile,
  cyan sanctuary) or white.
- Tracking (top left), Calendar (top right) and New Mail (bottom right) on
  small Onyx tiles; the Expansion Button off by default. The group-finder
  eye on its own tile in the bottom-left corner.
- Other addons' minimap buttons in an **Addon Buttons** box under the map,
  as wide as the map, with Blizzard's addon menu (which holds ModeUI's own
  entry) first.
- Forever's day and night ring is hidden (owner, for now).

## How it works

- **The map.** Blizzard's `Minimap` moves onto ModeUI's map frame
  (`ModeUIMinimapMap`) inside the holder (`ModeUIMinimap`), which follows an
  Edit Mode stand-in (`ModeUIMinimapMover`). The game draws the minimap
  square, so `Minimap` stays as wide as it is tall and hangs half the
  difference above and below the map frame; the mask crops those bands, and
  `SetHitRectInsets` trims the click area to the visible map.
- **Masks.** A mask stretches over the square map, so its shape is a
  fraction of the map's side. To keep the difference and the corners in
  exact pixels there is one mask per size (140-280 in 4 px steps),
  difference (0, 8, 16) and corner choice (0, 4, 8, 12 px): 432 files in
  `Media/Textures/Minimap/`, 256×256, run-length encoded TGAs (the format
  other minimap addons ship), made by `tools/build_minimap_masks.lua`. The
  shape sits half a pixel inside the map's edge, so the mask's soft edge
  lies under the border.
- **Blizzard puts its mask back.** `MinimapCluster:UpdateMinimapConfig`
  (Forever's `Camelot/Minimap.lua`) sets the round mask at load and whenever
  Rotate Minimap changes; a post-hook sets ModeUI's again. The hybrid
  minimap (some indoor maps, load on demand) has its own round
  `CircleMask`, swapped for the same mask when it loads.
- **Blizzard's art.** The cluster (zone text, day and night ring,
  Blizzard's coordinates) is hidden and kept hidden (`Skin.Suppress`); the
  backdrop (compass ring) and the zoom buttons wait under a hidden ModeUI
  frame. Quest and dig-site ring textures are set to 0 (they're round).
- **Moving Blizzard's frames.** `Adopt.lua` reparents and places a frame,
  and does it again right after Blizzard calls `SetPoint`, `SetParent` or
  `SetScale` on it (post-hooks). Where frames go lives in ModeUI's weak
  tables; nothing else is written on Blizzard's frames.
- **Tiles.** Blizzard's own buttons are scaled onto ModeUI tiles, so
  clicking works as before. A tile shows while its switch is on and
  Blizzard shows the button (Show/Hide post-hooks).
- **The eye.** `QueueStatusButton` (its own Blizzard Edit Mode frame) sits
  on a tile that follows the **Group Finder** stand-in in ModeUI's Edit
  Mode. While the module is on, Blizzard's Edit Mode position for the eye
  doesn't apply.
- **Addon buttons.** LibDBIcon's list, then named Minimap children that
  look like buttons, skipping map pins (HandyNotes, TomTom, GatherMate,
  HereBeDragons, Questie), Blizzard's frames (`issecurevariable`),
  protected frames and ModeUI's own. Searched again 2, 6 and 12 seconds
  after enabling, at each loading screen and when LibDBIcon makes an icon.
  LibDBIcon's round border art is faded; no addon function is replaced.
- **Pings.** Blizzard pings only inside a circle; a post-hook on
  `OnMouseUp` pings the corners with `Minimap:PingLocation`.
- **Off.** Turning the module off asks for a reload, which gives Blizzard's
  minimap back.

## Settings

| Tab | Card | Settings |
|---|---|---|
| Shape | Minimap | Size (140-280), Wider Than Tall By (0, 8 px, 16 px), Corners (Square, Small, Medium, Large) |
| Shape | Border | Map Border (Thin, Mode, Bold, Heavy), Button Border (Thin, Mode), Border Color (Mode Rim, Onyx, Black, Mode Slate, Accent, Class Color) |
| Text | Zone and Clock | Text Layout (On Map, Bar Below, On Hover), Zone Color (PvP Status, White), Clock, Coordinates, Clock Format (24 Hour, 12 Hour), Text Size |
| Buttons | Blizzard Buttons | Tracking, Calendar, New Mail, Expansion Button: a switch and a corner each |
| Buttons | Addon Buttons | Show (Always, Mouseover, Hidden), Match Minimap Width, Button Size, Spacing |
| Behavior | Zoom | Mouse Wheel Zoom, Zoom Out After (Off, 10 s, 30 s) |
| Behavior | Visibility | Combat Opacity, Opacity |

Saved under `modules.minimap` (version 1). Positions are ModeUI Edit Mode
positions: `modeMinimap`, `modeMinimapQueue`, `modeMinimapButtons`.

## Manual checks (in game)

New texture files need a full client restart, not just `/reload`.

1. **The shape**
   - **Navigation:** type `/modeui`, then pick **Interface** › **Minimap** in the sidebar.
   - **Action:** turn the module on with the switch in the page header.
   - **Required state:** out of combat, outdoors.
   - **Confirmation:** the minimap is a rounded rectangle a little wider than
     tall, with a 3 px rim and no round Blizzard frame, zone text or zoom
     buttons; terrain fills every corner up to the rim with nothing showing
     outside it.
2. **The mask stays**
   - **Navigation:** the chat box.
   - **Action:** type `/console rotateMinimap 1`, then `/console rotateMinimap 0`
     (Blizzard's Rotate Minimap setting, which re-applies its round mask).
   - **Required state:** the module on.
   - **Confirmation:** the map stays a rounded rectangle both times.
3. **Text and tiles**
   - **Navigation:** the minimap itself.
   - **Action:** look at the bottom of the map; hover Tracking (top left) and
     Calendar (top right) and click each; get mail.
   - **Required state:** the module on.
   - **Confirmation:** the clock sits above the zone name at the bottom
     center; the zone is colored by PvP status; coordinates show at the top
     and change as you move; the tiles open Blizzard's tracking menu and
     calendar; a mail tile appears at the bottom right with new mail.
4. **The eye and addon buttons**
   - **Navigation:** `/modeui`, then **Edit Mode** in the window's header.
   - **Action:** join a group-finder queue; in Edit Mode drag the **Group
     Finder** box and the **Addon Buttons** box, then leave Edit Mode.
   - **Required state:** at least one addon with a minimap button (most use LibDBIcon).
   - **Confirmation:** the eye sits on a tile in the map's bottom-left corner
     and moves where you dragged it; addon buttons sit in a box under the
     map, clickable, without their round frames.
5. **Corners ping**
   - **Navigation:** the minimap itself.
   - **Action:** click near a corner, outside where the old round map was.
   - **Required state:** in a group, so the ping is visible.
   - **Confirmation:** the ping shows where you clicked.

Not yet confirmed in game: whether edge arrows for tracked targets reach
into the corners, and whether the game draws a non-square `Minimap` without
stretching (if it does, the mask set could shrink to four files).
