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
| Window | Blizzard's background and border textures (`CHAT_FRAME_TEXTURES`) are hidden, so its own fades skip them. A fill (#0B0B0D at Background Opacity, 72%) inside a one-pixel rim (#25282C) is drawn on the window under the text. |
| Box | Blizzard's `Background` region stays as the window's box, moved to an even 6 px Text Inset around the messages (more on top for the combat log's quick buttons). The tab dock, button frame and alerts that Blizzard anchors to it follow. |
| Text | Expressway by default (the Font setting), with a crisp one-pixel shadow. Each window keeps its own Font Size from its tab's right-click menu; Blizzard re-applies the size but keeps the face. |
| Edit box | 24 px tall, 4 px under the box and as wide as it. A field (#0E0F11 on #2A2D32) whose rim turns cyan while typing. Its text, header and prompt use the chat face. |
| Tabs | Blizzard's tab art is faded. A 22 px glass pane fills each tab's bottom: the ModeGlass texture (feathered 2 px at the sides and top, thinning toward the bottom), a soft white sheen over the top half and a faint top line. The selected tab has white text and a 2 px cyan bar; the others are label gray. Whisper tabs keep their whisper color. Glass Tabs off gives flat dark fields. |
| Compartment | One capsule at the right end of the main window's tab row: Channels (cyan while a voice channel is active), Voice Deafen and Voice Mute (only while voice chat shows them) and the Chat Menu, 22 by 18 px cells with one-pixel dividers. They are Blizzard's own buttons moved in, so clicks, menus and tooltips are Blizzard's. Social and Text to Speech (Blizzard's chat alert column) stack just above it. |
| Scroll | The thin scroll bar is hidden unless Scroll Bar is on. Scroll to Bottom is a 16 px field with a chevron in the box's bottom-right corner, shown whenever the window is scrolled up. |

The window can't really blur what's behind it: the client has no backdrop
blur. The "glass" is the feathered, see-through pane, its sheen and top line.

## Fading

Two eased levels drive every alpha (Fade.lua):

- **Tab level:** 1 while the chat is in use, 0 when it isn't. Tabs move between
  **Tabs When Away** (0%) and full; while in use the selected tab is full and
  **Other Tabs** are 55%. The compartment and the dock's overflow button follow.
  A tab flashing for a new whisper always shows.
- **Idle level:** 1 while the chat was used in the last **Idle Delay** seconds
  (8), then **Idle Opacity** (40%). It multiplies everything: windows, text,
  edit box, tabs and buttons.

"In use": the mouse over a window (with its tab row and edit box), a tab or
the compartment; the edit box focused; the chat menu or the tab overflow list
open; a window being moved. With **Wake on Whispers** a whisper counts too.
Levels ease in over 0.15 s and out over 0.6 s.

Blizzard fades tabs by calling `SetAlpha` every frame from its own code, and
keeps its tab constants away from addon taint on purpose. ModeUI never changes
those constants: `Skin.PinAlpha` post-hooks each tab's `SetAlpha` and puts
ModeUI's value back right after.

## Settings

Tabs on the page: **Window** (Status, Text, Background, Buttons, Defaults),
**Tabs** (Glass Tabs, Tab Fade) and **Fade** (Idle Fade). Changes show on the
real chat right away. Turning the module off stops the fades and asks for a
reload to bring Blizzard's look back.

Saved under `modules.chat` (version 1): `font`, `fontMedia`, `outline`,
`shadow`, `backgroundColor`, `backgroundOpacity`, `border`, `borderColor`,
`glassTabs`, `tabFontSize`, `unselectedTabOpacity`, `awayTabOpacity`, `buttons`
(`compartment` or `hidden`), `scrollBar`, `idleFade`, `idleOpacity`,
`idleDelay`, `wakeOnWhisper`.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, pixel layout constants, defaults, ranges |
| `Migrations.lua` | `Initialize(db)`: validation |
| `Driver.lua` | lifecycle, finding the windows, Blizzard post-hooks, settings |
| `Window.lua` | window panel and box, font, edit box, scroll bar and Scroll to Bottom |
| `Tabs.lua` | glass tabs and their selected state |
| `Buttons.lua` | the compartment |
| `Fade.lua` | in-use detection, tab and idle levels, alphas |
| `Settings.lua` | the page |

Shared pieces live in `Shared/Skin/Skin.lua` (panel, fade, suppress, alpha
pin, fonts). Tests: `tests/chat.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Chat** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Move the
  mouse away from the chat and wait about 10 seconds; then move it back over
  the chat and press Enter.
- **Required state:** out of combat, with General and Combat Log docked
  (Blizzard's default) and a few lines of chat.
- **Confirmation:** the chat has a dark fill with a thin rim, Expressway text,
  glass tabs (General white with a cyan bar) and a small button capsule at the
  right end of the tab row. Away from the mouse the tabs and buttons fade out,
  then the whole chat eases to 40%. Over the chat or typing it comes back to
  full and the edit box rim turns cyan. No Lua errors.
