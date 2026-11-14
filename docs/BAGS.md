# Interface: Bags

November 13, 2026. A module of the **Interface** category. Off by
default (turn it on with the switch in the page header). Static/mock
validated only (`tests/bags.lua`); **native acceptance is pending**. APIs and
their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#bags--november-13-2026).

## What it does

Every bag in one Mode window: the backpack, the equipped bags, the reagent
bag and the keyring show together on one grid of slots.

| Part | Look and behavior |
|---|---|
| Window | A fill in Background Color (the unit frames' health color, Onyx #1C1E21, at 95%) inside ModeUI's border in its rounded-rectangle form (`Kit.ModeBoxBorder`: 2px, `Kit.BORDER_COLOR`, Corner Radius 6). |
| Header | A Mode Gradient bar in Header Color over a one-pixel black divider: the **Bags** title on the left; **Sort** (names the view order), **Clean Up** and the close cross on the right, in the text color and the Mode cyan under the mouse. Unlocked, dragging the header moves the window (out of combat). |
| Search | A Mode field under the header. It sets the game's own bag search (`C_Container.SetItemSearch`, the one Blizzard's bag search box uses), so names, types and tooltip text match; items that don't match fade to 25%. Escape clears it; closing the bags clears it. |
| Slots | Columns wide (12), Slot Size (38 px) apart by Spacing (4 px), Padding (8 px) inside the border. Each slot looks like an action bar slot: a hollow rim Slot Border Size thick (2px, Onyx border color), a near-black fill with the ActionBarSlot grain at Slot Opacity (75%), the icon one pixel inside the rim cropped square. Pushed and highlight states are flat Mode overlays. |
| Rims | A new item: the Mode cyan, until you point at it. A quest item: Quest Color (#FFB12F). Otherwise the item's quality color from Minimum Quality (Uncommon) up, else Slot Border Color. |
| Marks | Stack counts (bottom right), item level on weapons and armor (bottom left, in the quality color or white), a coin on gray items you can sell (Junk Coin) and those items grayed (Fade Junk). Locked items (being moved) are gray. Cooldowns use the button's own swipe. |
| Sections | The backpack and equipped bags first (each its own block with Separate Bags), then **Reagents** (the reagent bag, Reagent Section) and **Keyring** (Keyring, when the game shows a keyring), each under a small title and a hairline. |
| Footer | Free slots on the left ("29/36 Free", held bags only) and the money on the right (gold, silver, copper with the game's coin icons). |

### Sort and Clean Up

- **Sort** changes only the order items *show* in: **Bag Order** (as they lie
  in the bags), **Quality** (best first, then type, then name), **Type** (item
  class and subclass, then quality, then name) or **Name**. Empty slots go
  last; ties keep bag order, so the view never shuffles between redraws. The
  header's Sort button cycles through them; the Layout tab sets it.
- **Clean Up** is the game's own sort (`C_Container.SortBags`, Blizzard's
  "Clean Up Bags"), which moves items in the bags. Not in combat.

## How it follows Blizzard

Blizzard keeps deciding when bags open and close: the B key, the bag bar,
vendors, mail, the bank and Esc all call its own functions (`OpenAllBags`,
`ToggleAllBags`, `ToggleBag`, `CloseAllBags`, ...), which show and hide its
bag frames (`ContainerFrameCombinedBags`, `ContainerFrame1-N`).

- While the module is on, each of those frames that holds the backpack, an
  equipped bag, the reagent bag or the keyring is parented to a hidden ModeUI
  frame. It keeps its shown state (so Blizzard's toggles, `IsBagOpen` and the
  bag bar's highlights still work) but never draws or takes clicks.
- Post-hooks on those frames' `Show`, `Hide` and `SetShown` show ModeUI's
  window while any of them is shown and hide it when none is.
- A frame Blizzard reuses for another container (a bank bag) goes back under
  its own parent. `ContainerFrame_SetFullScreenFrame` and
  `ContainerFrame_ClearFullScreenFrame` move Blizzard's bag frames under the
  fullscreen frame of the moment; ModeUI takes them back right after.
- The close cross calls `CloseAllBags()`; the settings page's **Show Bags**
  calls `OpenAllBags()` (out of combat).
- Switching the module off puts every frame back under the parent Blizzard
  gave it, so open bags show in Blizzard's look at once.

Nothing is written to Blizzard's tables: the old parents live in a weak table
keyed by the frame, and every hook is a post-hook.

## Slots are Blizzard's buttons

Each slot is made with `CreateFrame("ItemButton", "ModeUIBagsItemN", holder,
"ContainerFrameItemButtonTemplate")`, on a holder frame per bag whose ID is
the bag's ID (`holder:SetID(bag)`), with the button's ID the slot
(`button:SetID(slot)`). Blizzard's mixin finds the bag with
`self.bagID or self:GetParent():GetID()` and never reads anything ModeUI
sets, so its click (use, equip, sell at a vendor, pick up, place), drag,
stack splitting (Shift-click), modified clicks (link, dress up) and tooltip
run as Blizzard's own code, in combat too. ModeUI never calls Blizzard's
update functions on these buttons and writes no fields to them; its
textures, texts and per-button state live in weak tables keyed by the button.
The buttons are named because the template names its children after their
parent.

The template isn't secure or protected in Blizzard's source, so ModeUI shows,
places and sizes slots in combat. If the client ever reports one as
protected, the layout waits for the end of combat.

## Redraws

- `BAG_UPDATE_DELAYED`, `BAG_CONTAINER_UPDATE`, `PLAYER_ENTERING_WORLD`: the
  whole window is drawn again.
- `QUEST_LOG_UPDATE`, `GET_ITEM_INFO_RECEIVED`: one redraw a tenth of a
  second after the first of a burst (item levels arrive as the game loads
  item data).
- `ITEM_LOCK_CHANGED`, `INVENTORY_SEARCH_UPDATE`, `BAG_NEW_ITEMS_UPDATED`:
  rims, locks and search fades only. `BAG_UPDATE_COOLDOWN`: cooldowns.
  `PLAYER_MONEY`: the footer.
- While the window is closed, changes only mark it stale; it redraws as it
  opens. Its size is still worked out (no slots are built), so Edit Mode's
  stand-in matches it.

## Placement

The window hangs from a stand-in registered with ModeUI's Edit Mode
(`modeBags`, default: the screen's bottom right, 60 px in, 110 px up) at its
**Grow From** corner (Bottom Right by default), so that corner stays put and
the window grows away from it as bags change. **Scale** (50-200%) scales the
window; the stand-in covers it. In Edit Mode the stand-in can be dragged or
attached to another element. Dragging the header (unlocked, out of combat,
not in Edit Mode) saves the same position Edit Mode would: the Grow From
corner as an offset from the same corner of the screen, in whole pixels.

## Settings

| Tab | Card | Settings |
|---|---|---|
| Layout | (top) | Status, **Show Bags** |
| | Grid | Columns (4-24), Slot Size (24-64 px), Spacing (0-12 px), Padding (0-24 px), Scale (50-200%) |
| | Contents | Separate Bags, Reagent Section, Keyring; Sort (Bag Order, Quality, Type, Name) |
| | Defaults | Reset to Defaults |
| Window | Frame | Background Color and Opacity, Border Color, Corner Radius (2-16 px), Header Color |
| | Parts | Title, Search Box, Money, Free Slots, Lock Window |
| Slots | Slot | Slot Color and Opacity, Slot Border Color and Size (0-4 px) |
| | Borders | Quality Borders (Minimum Quality: Poor to Epic), Quest Borders (Quest Color), New Items |
| | Marks | Fade Junk, Junk Coin, Item Level (Item Level Color: Quality or White) |
| Text | Font | Font (Expressway by default), Title Size (header, search, footer), Count Size, Item Level Size, Outline |
| Position | Position | Grow From (four corners), **Edit Mode** |

Saved under `ModeUIDB` profile `modules.bags` (settings version 1) and
`positions.modeBags`. Every change applies to the open window at once.

## Not included

- The bank, guild bank and account bank keep Blizzard's windows (the Windows
  module skins the bank window).
- The bag bar (equipped bag slots) stays where it is (Action Bars can restyle
  it as a utility bar).
- Game-wide bag options (sort direction, insert order, junk selling) are left
  alone.

## Manual check

1. **Navigation:** `/modeui` › **Interface** › **Bags**. **Action:** turn the
   module on with the page header's switch, then click **Show Bags**.
   **Required state:** out of combat, not at a bank. **Confirmation:** one
   Mode window with every bag's slots; Blizzard's bag frames don't show.
2. **Action:** press B twice, then open a vendor and close it. **Confirmation:**
   the window toggles with B and opens and closes with the vendor; Esc closes it.
3. **Action:** right-click a consumable in the window, in and out of combat;
   Shift-click a stack; drag an item to an empty slot. **Confirmation:** each
   works as in Blizzard's bags, with no "action blocked" message.
4. **Action:** type part of an item name in **Search**; click **Sort** in the
   header; click **Clean Up**. **Confirmation:** other items fade; the order
   changes and the button names it; the game sorts the bags.
5. **Navigation:** the Slots, Window and Position tabs. **Action:** change
   Columns, Slot Size, Background Color, Quality Borders and Grow From with
   the bags open. **Confirmation:** the window updates at once.
6. **Action:** switch the module off with the bags open. **Confirmation:**
   Blizzard's bag frames show in Blizzard's look.
