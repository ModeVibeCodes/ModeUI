# Interface: Chat

November 13, 2026; rebuilt in the Mode design language November 15, 2026
(Phase 7, settings version 6). Fifth module of the **Interface** category.
Off by default (turn it on with the switch in the page header). Static/mock
validated only; **native acceptance of the Mode rebuild is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-chat-and-windows--november-13-2026).
Design canvas: https://claude.ai/artifact/E9m1Krqr6LXYaJJvjAUAPL (Chat artboard).

## What it does

ModeUI restyles Blizzard's own chat windows (`ChatFrame1` up to the game's
maximum, and temporary whisper windows). It never sends, reads, filters or
measures messages, and it never writes Blizzard's globals or fields.

| Part | Look |
|---|---|
| Window | Blizzard's background and border textures (`CHAT_FRAME_TEXTURES`) are hidden, so its own fades skip them. The box is a Mode window (docs/DESIGN_LANGUAGE.md, "Windows and panels"): Mode Panel (its base and lift) in Graphite panel #121213 at Background Opacity (60%), with the `window` edge inside the box (see Edge below). |
| Edge | The `window` edge (`Skin.Box`, `Style.Edge`: 1px Steel Sheen, a black gap and a shadow ring, 3 px in all), drawn inside the box on its own frame above the window, so the idle fade dims it with the window. Sliced Round 4 rim art covers its own corners: no masks. A see-through window (Background Opacity under 100) has no soft drop, which would only darken it. The edge has no settings. The scroll bar starts clear of the top-right corner, and Scroll to Bottom sits clear of the bottom-right corner when no edit band fills it. |
| Box | Blizzard's `Background` region stays as the window's box, moved to Text Inset (6 px) plus the edge's 3 px around the messages, plus the edit box when it sits inside and the scroll bar's 10 px gutter (more on top for the combat log's quick buttons). The tab dock, button frame and alerts that Blizzard anchors to it follow. |
| Text | The Mode typeface by default (the Font setting's "Mode": Expressway when the client has it, else Geist), with a crisp one-pixel shadow. Each window keeps its own Font Size from its tab's right-click menu; Blizzard re-applies the size but keeps the face. |
| Edit box | **Bottom** (default) or **Top**: joined to the window inside its edge, on a Graphite base band a little darker than the window, Edit Box Height tall, with a one-pixel Graphite line divider toward the text that turns Ivory while typing. **Below**: its own Mode field Edit Gap under the window (a Graphite base inside the `control` edge), its outer line Ivory while typing. Its text, header and prompt use the chat face. |
| Tabs | Blizzard's tab art is faded. Each tab is a Mode control resting on the window's edge (the `control` edge inside the pane), the label in the chat face's SemiBold: the selected tab stands Tab Height tall (24 px) in the chosen tone (Graphite track) with an Ivory label and outer line; the others tuck down Tuck Depth (3 px) in Graphite raised with Graphite secondary text. **Glass**: Mode Glass at 75%, so the world shows through. **Solid**: the Mode Button face. Whisper tabs keep their whisper color. Text sits on the pane's middle. |
| Edit Mode | The main window is one of Blizzard's Edit Mode systems. Blizzard's selection (the blue highlight) reaches 32 units left of and below the window, for the button column ModeUI moves into the compartment, and 60 above. ModeUI lays it over the Mode box and the tab row (and the field, with the edit box Below), 2 units past them for Blizzard's snap padding, and clamps the window by the box. So the highlight shows the window, and snapping to a screen edge or corner puts the box right on it (owner, November 15, 2026). Blizzard's `AnchorSelectionFrame` sets the clamp from the selection again; ModeUI puts its own back right after (post-hook). |
| Tab width | Blizzard sizes a tab to its text in whatever font it had; General, Combat Log and other fixed or undocked tabs are sized again in the Mode face right after (post-hook on `PanelTemplates_TabResize`), so names aren't cut off. Dynamic docked tabs keep the dock's width; whisper tabs (whose names can be secret) are never measured. |
| Compartment | One Mode control (a Graphite base at 85% inside the `control` edge) at the right end of the main window's tab row: Friends (Blizzard's friends and quick join button, a Mode glyph with the online count beside it), Text to Speech and Voice Deafen / Mute (only while the game shows them), Channels (Ivory while a voice channel is active) and the Chat Menu, 18 px tall cells (Friends 34 px wide, the rest 22) inside the edge with one-pixel Graphite line dividers; a hovered cell takes the chosen tone. They are Blizzard's own buttons moved in, so clicks, menus, toasts and tooltips are Blizzard's. Friends is one of Blizzard's chat alerts: the alert column places it again whenever it updates, so ModeUI puts it back right after (post-hook on `ChatAlertFrame:UpdateAnchors`); its own art is hidden for good, since its toast animations fade it in and out. The other alerts (Battle.net toasts, voice notices) stack just above the compartment. |
| Scroll | Blizzard's MinimalScrollBar, skinned: a slim Mode track and thumb in the gutter, shown while the mouse is over the chat (Scroll Bar off hides it). Scroll to Bottom is a 16 px Mode control (Mode Button face) with a chevron in the box's bottom-right corner, shown whenever the window is scrolled up; the chevron and outer line turn Ivory on hover. Blizzard's flashing arrow is hidden. |

The window can't really blur what's behind it: the client has no backdrop
blur. Glass tabs are simply see-through.

## Fading

Three eased levels drive every alpha (Fade.lua):

- **Use level:** 1 while the chat is in use, 0 when it isn't: the scroll bar.
- **Tab level:** 1 until the chat has gone **Idle Delay** seconds without
  use, then 0. Each tab is full when selected and **Other Tabs** (55%)
  otherwise; **Tabs When Idle** scales that once idle: 0 (default) hides
  them, 100 keeps them as they are. The compartment and the dock's overflow
  button follow. A tab flashing for a new whisper always shows. Not tied to
  the window fade.
- **Idle level:** 1 while the chat was used in the last Idle Delay seconds
  (8), then **Idle Opacity** (40%), with Idle Fade on: the windows (text,
  fill, edge, edit band, scroll bar).

"In use": the mouse over a window (with its tab row and edit box), a tab, the
edit box or the compartment; the edit box focused; the chat menu or the tab
overflow list open; a window being moved. With **Wake on Whispers** a whisper
counts too. Levels ease in over 0.15 s and out over 0.6 s.

Blizzard fades tabs by calling `SetAlpha` every frame from its own code, and
keeps its tab constants away from addon taint on purpose. ModeUI never changes
those constants: `Skin.PinAlpha` post-hooks each tab's `SetAlpha` (and the
scroll bar's) and puts ModeUI's value back right after.

## Settings

Tabs on the page, pinned above the scrolling cards: **Window** (Status, Text,
Background, Edit Box, Buttons, Defaults), **Tabs** (Tab Style, Tab Fade) and
**Fade** (Idle Fade). Changes show on the real chat right away. Turning the
module off stops the fades and asks for a reload to bring Blizzard's look
back.

Saved under `modules.chat` (version 6): `font`, `fontMedia`, `outline`,
`shadow`, `backgroundColor`, `backgroundOpacity`, `editPosition` (`bottom`, `top` or `below`), `editHeight`,
`editGap`, `glassTabs` (Tab Style: true Glass, false Solid), `tabHeight`,
`tuckDepth`, `tabFontSize`, `unselectedTabOpacity`, `awayTabOpacity` (Tabs
When Idle), `buttons` (`compartment` or `hidden`), `scrollBar`, `idleFade`,
`idleOpacity`, `idleDelay`, `wakeOnWhisper`.

Version 2 (November 13, 2026, per the owner): values still at version 1's
defaults move to the new ones (fill #0B0B0D → Mode Slate, 72% → 60%, border
#25282C → #40454C) and the scroll bar is shown; values the user picked stay.
Version 3 (same day, per the owner): the fill is the unit frames' default
health color (Onyx #131212), as the meters and tooltips; a fill still at
version 2's Mode Slate follows.
Version 4 (same day, per the owner): the window takes ModeUI's standard
border, as the damage meter windows do; it has no settings, so `border`,
`borderSize` and `borderColor` are removed.
Version 5 (same day): a fill still at the old health color #1C1E21 takes
#131212.
Version 6 (November 15, 2026, Phase 7): the Mode design language. A fill
still at #131212 takes Graphite panel #121213, and a Font still at
"Expressway" takes "Mode" (the Mode typeface: Expressway when installed,
else Geist). Values the user picked stay.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, pixel layout constants, defaults, ranges |
| `Migrations.lua` | `Initialize(db)`: versions 1 → 6, validation |
| `Driver.lua` | lifecycle, finding the windows, Blizzard post-hooks, settings |
| `Window.lua` | the Mode window and its box, font, edit box and band, scroll bar, Scroll to Bottom |
| `Tabs.lua` | Mode tabs (Glass or Solid), tuck, width, selected state |
| `Buttons.lua` | the compartment |
| `Fade.lua` | in-use detection, use, tab and idle levels, alphas |
| `Settings.lua` | the page |

Shared pieces live in `Shared/Skin/Skin.lua` (`Skin.Box` and `Skin.PaintBox`,
fade, suppress, alpha pin, fonts) and `Shared/Style` (tones, the edge,
textures). Tests: `tests/chat.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Chat** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Look at
  the chat, click the Combat Log tab and back to General, scroll the chat up
  a little, then move the mouse away and wait about 10 seconds; then move it
  back over the chat and press Enter. On the page, open the **Tabs** tab and
  switch **Style** between Glass and Solid.
- **Required state:** out of combat, with General and Combat Log docked
  (Blizzard's default) and a few lines of chat.
- **Confirmation:** the chat is a see-through Graphite window (the same
  gray as the Character and Guild windows, at 60%) with the thin steel Mode
  edge just inside it and no drop shadow around it, in Expressway (or Geist
  without it); the edit box sits inside the edge at the bottom on a slightly
  darker band, with no gap. Tab names show in full; the selected tab stands
  taller than the others with an Ivory name and an Ivory outline, the others
  gray. In the tab row's right end, the buttons sit in one small box with
  thin dividers. The scroll bar is a slim gray line; the Scroll to Bottom
  button is a small square with a chevron that doesn't flash and turns Ivory
  under the mouse. Away from the mouse the tabs stay until the chat goes
  idle, then hide while the chat eases to 40%. Over the chat or typing it
  comes back and the line above the edit box turns Ivory. Solid tabs are
  opaque gray buttons; Glass tabs let the world show through. The settings
  tabs sit above the cards, not over them. No Lua errors.
