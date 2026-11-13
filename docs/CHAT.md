# Interface: Chat

November 13, 2026. Fifth module of the **Interface** category. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-chat-and-windows--november-13-2026).
Design canvas: https://claude.ai/artifact/E9m1Krqr6LXYaJJvjAUAPL (Chat artboard).

## What it does

ModeUI restyles Blizzard's own chat windows (`ChatFrame1` up to the game's
maximum, and temporary whisper windows). It never sends, reads, filters or
measures messages, and it never writes Blizzard's globals or fields.

| Part | Look |
|---|---|
| Window | Blizzard's background and border textures (`CHAT_FRAME_TEXTURES`) are hidden, so its own fades skip them. A fill (Mode Slate #44464A at Background Opacity, 60%) inside a crisp square border, Border Size thick (2 px, the unit frames' rim color #40454C), drawn on its own frame above the window, as the unit frames' rim sits above their bars. |
| Box | Blizzard's `Background` region stays as the window's box, moved to Text Inset (6 px) plus the border around the messages, plus the edit box when it sits inside and the scroll bar's 10 px gutter (more on top for the combat log's quick buttons). The tab dock, button frame and alerts that Blizzard anchors to it follow. |
| Text | Expressway by default (the Font setting), with a crisp one-pixel shadow. Each window keeps its own Font Size from its tab's right-click menu; Blizzard re-applies the size but keeps the face. |
| Edit box | **Bottom** (default) or **Top**: joined to the window inside its border, on a band a little darker than the window, Edit Box Height tall, with a one-pixel divider toward the text that turns cyan while typing. **Below**: its own field Edit Gap under the window, with the window's border, cyan while typing. Its text, header and prompt use the chat face. |
| Tabs | Blizzard's tab art is faded. Panes rest on the window's border: the selected tab stands Tab Height tall (24 px), the others tuck down Tuck Depth (3 px). **Glass**: the ModeGlass texture (feathered sides and top), a soft white wash over its top half, a diagonal glint (ModeSheen, added light) and a faint top line. **Solid**: flat dark fields. The selected tab has white text and a 2 px cyan bar; the others are label gray. Whisper tabs keep their whisper color. Text sits on the pane's middle. |
| Tab width | Blizzard sizes a tab to its text in whatever font it had; General, Combat Log and other fixed or undocked tabs are sized again in the Mode face right after (post-hook on `PanelTemplates_TabResize`), so names aren't cut off. Dynamic docked tabs keep the dock's width; whisper tabs (whose names can be secret) are never measured. |
| Compartment | One capsule at the right end of the main window's tab row: Channels (cyan while a voice channel is active), Voice Deafen and Voice Mute (only while voice chat shows them) and the Chat Menu, 22 by 18 px cells with one-pixel dividers. They are Blizzard's own buttons moved in, so clicks, menus and tooltips are Blizzard's. Social and Text to Speech (Blizzard's chat alert column) stack just above it. |
| Scroll | Blizzard's MinimalScrollBar, skinned: a slim Mode track and thumb in the gutter, shown while the mouse is over the chat (Scroll Bar off hides it). Scroll to Bottom is a 16 px field with a chevron in the box's bottom-right corner, shown whenever the window is scrolled up; Blizzard's flashing arrow is hidden. |

The window can't really blur what's behind it: the client has no backdrop
blur. The "glass" is the feathered, see-through pane, its wash, glint and top
line.

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
  fill, border, edit band, scroll bar).

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

Saved under `modules.chat` (version 2): `font`, `fontMedia`, `outline`,
`shadow`, `backgroundColor`, `backgroundOpacity`, `border`, `borderColor`,
`borderSize`, `editPosition` (`bottom`, `top` or `below`), `editHeight`,
`editGap`, `glassTabs` (Tab Style: true Glass, false Solid), `tabHeight`,
`tuckDepth`, `tabFontSize`, `unselectedTabOpacity`, `awayTabOpacity` (Tabs
When Idle), `buttons` (`compartment` or `hidden`), `scrollBar`, `idleFade`,
`idleOpacity`, `idleDelay`, `wakeOnWhisper`.

Version 2 (November 13, 2026, per the owner): values still at version 1's
defaults move to the new ones (fill #0B0B0D → Mode Slate, 72% → 60%, border
#25282C → #40454C) and the scroll bar is shown; values the user picked stay.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, pixel layout constants, defaults, ranges |
| `Migrations.lua` | `Initialize(db)`: version 1 → 2, validation |
| `Driver.lua` | lifecycle, finding the windows, Blizzard post-hooks, settings |
| `Window.lua` | window fill, border and box, font, edit box and band, scroll bar, Scroll to Bottom |
| `Tabs.lua` | glass tabs, tuck, width, selected state |
| `Buttons.lua` | the compartment |
| `Fade.lua` | in-use detection, use, tab and idle levels, alphas |
| `Settings.lua` | the page |

Shared pieces live in `Shared/Skin/Skin.lua` (panel, edge, fade, suppress,
alpha pin, fonts). Tests: `tests/chat.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Chat** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Look at
  the chat, click the Combat Log tab and back to General, scroll the chat up
  a little, then move the mouse away and wait about 10 seconds; then move it
  back over the chat and press Enter. On the page, open the **Tabs** tab and
  switch **Style** between Glass and Solid.
- **Required state:** out of combat, with General and Combat Log docked
  (Blizzard's default) and a few lines of chat.
- **Confirmation:** the chat is Mode Slate with a crisp 2px border and
  Expressway text; the edit box sits inside the border at the bottom, with no
  gap; tab names show in full and the selected tab stands taller than the
  others; the scroll bar is a slim gray line, and the Scroll to Bottom button
  doesn't flash. Away from the mouse the tabs stay until the chat goes idle,
  then hide while the chat eases to 40%. Over the chat or typing it comes
  back and the line above the edit box turns cyan. The settings tabs sit
  above the cards, not over them. No Lua errors.
