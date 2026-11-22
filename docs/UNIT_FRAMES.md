> Moved from Play The Game Tools to ModeUI on November 12, 2026. File paths
> below that start with `PlayTheGameTools/` now live under `ModeUI/`, and the
> settings now live in `ModeUIDB` (imported once from the active PTG profile).
> The history below is kept as written.

# Interface: Unit Frames (Player and Target)

## Standard tabs (November 21, 2026)

The owner's settings review: the page uses the standard tabs
(DESIGN_LANGUAGE.md, "Standard tabs"), a card per part of the frame in each,
instead of one tab per part. Saved keys, defaults and ranges are unchanged.

- **General:** Frame (Show Frame, Hide Blizzard's Frame, Scale, Frame Width,
  Frame Height), Match the Player (the Target), Power Bar (Show Power Bar,
  Power Bar Height), Portrait (Show Portrait, Portrait Style, Portrait Side,
  Portrait Size), Status Icons, Cast Bar (Show Cast Bar, Hide Blizzard Cast
  Bar, Position, Bar Height, Spacing, Full Width, Bar Width, Spell Icon),
  Class Resource, Placement (the frames that attach).
- **Fill:** Health Bar (Show: Health or Mana on the Player, Fill Direction,
  Fill End Line, Shields, Health Color, textures and opacity), Power Bar,
  Cast Bar (textures, Cast Color, Uninterruptible Color), Class Resource
  (point colors).
- **Border:** Frame (Border, Border Metal, Shadow), Portrait (Ring Style,
  Ring Finish, Portrait Ring Color), Auras (Buff Border, Debuff Border: each
  group's own, so no group switch is needed there).
- **Glow:** Frame (Prism Glow), Combat Ring (Combat Ring, its color, Pulse
  When Pulled: the color serves the ring and the pulse, so they stay
  together), Text Glows.
- **Text:** Text Style (Font, Outline, Shadow, Text Color), Text Colors, one
  card per text (Name, Level, Health Text, Power Text), Cast Bar Text (Spell
  Name, Timer, Outline, Size).
- **Auras:** the Buffs/Debuffs switch and Show, Which Auras, Icons (size,
  spacing, shape, corner, grow, offsets), Timer and Stacks.
- **Above every tab:** the Frame Off and Target Matches Player tips, once
  (each tab used to repeat them).
- **Class Resource** cards show while Editing is the Target, the frame its
  points sit on, so the preview shows them (the old Class Resource tab
  switched the preview to the Target).
- **Copy To… and Reset…** (the settings footer) replace the Style Tools card:
  Copy To… copies the Player's style to the Target (and back) or to a
  smaller frame (`M:CopyActions`); Reset… resets the frame being edited or
  all of Unit Frames (`M:ResetScopes`).
- **Labels:** Turn On is Show Frame; Drop Shadow, Text Outline and Text
  Shadow are Shadow, Outline and Shadow; the cast bar's Gap and Font Size are
  Spacing and Size; Prism Glow's Off and the Spell Icon's and texts' Hidden
  read None. Rested Corner shows only for the Player.
- A preview click still opens the tab that holds the part's row (the mark
  records the row's tab): the health bar opens Fill, the portrait, cast bar
  and class resource General.

## Show: Health or Mana (a mana frame), Frame Height, Cast Bar Gap -1, Healer layout (November 19, 2026)

- **Show** (Player, Health Bar tab, Bar group: two pills, Health or Mana;
  `barShows`, a frame's own key, so a Target matching the Player keeps
  health). A mana frame's bar shows the unit's mana: the mana power type
  (`Domain.Power.ReadType(unit, Power.ManaType())`), so a Druid in Bear or
  Cat Form keeps mana under Rage or Energy, in the mana color
  (`Power.Color("MANA")`), with no shields. Health texts still show health;
  power texts show the bar's mana. `UNIT_POWER_FREQUENT` and
  `UNIT_MAXPOWER` (already registered) update it; `UNIT_HEALTH` leaves the
  bar alone. Values may be secret and only reach `StatusBar:SetMinMaxValues`
  / `SetValue` and the FontString setters. A new key fills from its default
  (Health), so nothing changes in a saved profile.
- **Frame Height** (owner): the Health Bar tab's Health Bar Height slider is
  now labeled Frame Height. It sets the same key (`healthHeight`): the bar
  block is that plus its 2px rim each side (and the power bar, when shown).
- **Cast Bar Gap** goes down to -1: the bar 1px from the frame, the two
  shadows sharing one pixel, as Mode's icons and frames do.
- **Names just above the border** (owner, in every profile;
  DESIGN_LANGUAGE.md, "Placement"): a text On the Border sits with its
  line's bottom 1px over the bar block's edge, on the border's shadow pixel
  (`BorderBottom`: the bars' rim + 1px + its Y offset), so no letter crosses
  the rim. It used to sit on the rim, descenders dipping over it. Higher,
  the ring curves away, so a name on the portrait side starts a little
  closer to it (28px in from the bars on a default Target, was 31); auras
  lifted over the name follow it.
- **Healer layout** (`Modules/UnitFrames/Layouts.lua`, new profiles only):
  the Player a mana frame at Frame Height 26 (the owner's pick in game, a
  little shorter than Mode-DPS/TANK's 28), no power bar: a 30px bar block
  with a 44px ring (Portrait Size 145), and Frame Width 142, so 136 of bar
  shows past the ring, the party column's width; 180 x 44. The name (12)
  just above the border at the top right (nothing hangs from these frames
  here), Power Percent (12) inside at the right, no level. Its block's right
  edge on the party column's (x -323), 1px over the first member; the ring
  hangs past the column's left edge, clear of it. The Target the same size,
  mirrored, not matching the Player's look but matching its height (Edit
  Mode's Match Height, so the two stay the same height to the pixel at any
  Frame Height the Player gets): the name just above the border at the top
  left, Health Current (12) inside at the left; its block 1px right of the
  Player's; its buffs 18 wide at its top right, growing left, Y -1 (1px
  over the block, on the name's line), three to a row so a row ends before
  a name of about 11 letters (a name can't be measured: it may be secret),
  more rows going up, up to 9; its cast bar 12 tall, Gap -1, icon hidden.
  The Focus 136 x 20 (Frame Width 134, Health 14, Power 3, no portrait), 1px
  under the Target's cast bar, left edges lined up, its cast bar 12 tall,
  Gap -1. Target of Target and Target of Focus off. Mode-Border in its own metal, no text
  glow, no Drop Shadow, as in Mode-DPS/TANK.
- In-game check: a Mode-Healer profile made before these values keeps its
  old ones (layouts only write new profiles). **Navigation:** `/modeui`,
  then **Profiles**. **Action:** if **Mode-Healer** is the profile in use,
  switch to another first; pick **Mode-Healer** in **Profile**, click
  **Delete**; under **Manage**, leave **New from Healer Layout** empty and
  click **Create**; pick **Mode-Healer**, click **Switch to This Profile**,
  then **Reload**. **Required state:** a mana user with a target and a
  focus, out of combat, 1080p (alone is fine: the party frames show you).
  **Confirmation:** the Player frame is a blue mana bar about as tall as
  Mode-DPS/TANK's, your name on its border at the top right and mana percent
  inside at the right; it sits on the party frames, its right end on
  theirs; the Target sits 1px to its right with its name on the border and
  current health inside at the left; the Focus hangs 1px under the Target's
  cast bar. Then `/modeui`, **Frames**, **Unit Frames**, Player, **Health
  Bar**: **Show** reads Mana (pick Health and the bar shows health again),
  and the slider reads **Frame Height** 26.

## Mode-DPS/TANK layout (November 18, 2026)

The unit frames' part of the built-in **Mode-DPS/TANK** layout (DPS / Tank,
`Shared/Runtime/Layouts.lua`), from the owner's layout editor, is in
`Modules/UnitFrames/Layouts.lua`. It only builds the new Mode-DPS/TANK
profile; no existing profile changes. The same at 1080 and 1440 except the
height (y) of the row:

- **Size** (owner's tuning, November 18, 2026): Player (and the Target, which
  matches it) as tall as an Essential Cooldowns icon: Show Power off, 28
  health and the 2px rim make a 32px bar block, 34 with its shadow, as a 30px
  icon is with its 2px edge each side. Portrait Size 145 makes the ring 46;
  Frame Width 166 (Player and Target; 18 under the default) makes each frame
  206 x 46. Text
  glow (name and health) off on every frame. **Drop Shadow** off on Player
  and Target (a new Border setting, on by default: the Mode Frame border's
  soft drop), so the icons on their borders keep a crisp 1px shadow line
  instead of sitting in the drop's dark halo. Aura icons (buffs and debuffs)
  at Spacing 1 on every frame, sharing one shadow pixel. Every frame's (and
  its cast bar's) border in **Mode-Border in its own metal**. Every frame's border
  and cast bar border are drawn in pieces in every profile (Target of Target
  showed only corner specks; DESIGN_LANGUAGE.md, "Pieces"). Without a power bar the health
  bar fills the block, so a Bottom slot sits on the frame's bottom edge.
- **Player** (`unitFramesPlayer`): its CENTER on the screen's BOTTOM, x -256,
  y 300 (1080) or 325 (1440): its band 10px from Essential Cooldowns' band
  (Essential is 288 wide with its edges, its band 143 out past the shadow
  pixel: 143 + 10 + 103, half the frame's width). Texts: the name moves from the
  border to **Top Right** (size 11) and the health text from Right to
  **Bottom Right** (size 10), inside the health bar, so Defensive Cooldowns
  own the top border's right end; the level stays at Bottom Left (size 10).
- **Target** (`unitFramesTarget`): its CENTER on the screen's BOTTOM, x 256,
  the same y. It still matches and mirrors the Player (defaults), so its name
  sits at the top left and its health text at the bottom left. Its buffs
  start at the Top Left and grow Right (`target.buffs.anchor = "TOPLEFT"`,
  `grow = "right"`).
- **Focus** (`unitFramesFocus`): Frame Width 120, 20px health, 3px power,
  Scale 100, no portrait, buffs and debuffs off, its cast bar on, 12 tall and
  8 below the frame (122 x 26 with its 1px rim). The editor hung its bottom
  left 64 over the Target's top left corner; unit frames are placed on the
  screen only (`allowedTargets = { "screen" }` in `Build.lua`), so the layout
  writes that spot from the screen: BOTTOMLEFT on the screen's BOTTOM, x 153
  (256 less half the Target's 206), y 387 (1080) or 412 (1440) (the Target's
  top, y + 23, plus 64). Moving the Target later does not move the Focus.
- **Target of Focus** off. **Target of Target** keeps its defaults (attached
  under the Target frame).

Player and Target are 206 x 46 in Edit Mode (their stand-ins,
`ModeUI<Name>UnitFramePreview`, are the frames' size): the 46px ring (145% of
the 32px bar block: 28 health and the 2px rim) and the 166px bars.

**Bar block targets** (owner, November 18, 2026): the Player's and Target's
bar blocks are Edit Mode targets of their own, **ModeUI Player Frame Bars**
(`unitFramesPlayerBars`) and **ModeUI Target Frame Bars**
(`unitFramesTargetBars`): the stand-in's block, `ModeUI<Name>UnitFrameBars`,
its border on the block's edge. Something hung from a block stays on its
border whatever Portrait Size, Health Height or Frame Width do to the frame
around it (the frame's own element is as tall as the ring, so an offset from
it moved whenever the ring did). The layout hangs Defensive Cooldowns and
Player Buffs from the Player's block. Character portraits everywhere are centered and cropped 16% on
every side, so the face fills most of the ring (owner, November 18, 2026;
was 10% at the sides and bottom, 4% at the top). The Player's cast bar steps aside when the Cooldown Manager's
cast bar is on, as before.

## Ring Style and Ring Finish, Class Color by default, true class colors (layout version 24)

The owner asked for the portrait ring to read like a reference ring: a class
or reaction color band, lightly shaded, with fine black edges. The comparison,
with pixel samples and the shading options, is the "Portrait Ring Lab"
artifact (November 18, 2026); the owner picked the black line "In band" and
Specular shading at Gradient Strength 100% with no softness, then (in game)
any Ring Style with any finish and Portrait Size 165.

- Every portrait ring (`Style.Ring`) has a 1px black line between its band
  and the portrait, in every Ring Style and color. It takes the band's inner
  pixel, so the ring keeps its size, the portrait keeps its size and nothing
  on the frame moves. Outside in: the 1px shadow ring, the 2px band, the 1px
  black line, the portrait. The line replaces the dark disc that sat under
  the portrait.
- **Ring Style** and **Ring Finish** (Portrait tab) replace the Portrait Ring
  choice: any Mode border style, then its finish, one of Default, Silver,
  Steel, Gunmetal (Portrait Ring "border" with that Ring Metal), **Class
  Color** or **Custom** (with Portrait Ring Color). The saved keys are
  unchanged (`portraitRing`, `portraitRingStyle`, `portraitRingMetal`,
  `portraitRingColor`; `M.RingFinish` and `M:SetRingFinish` map the one
  choice onto them).
- The default is **Mode-Border's ring lighting in Class Color**: the class color for players,
  the reaction color for NPCs. A colored ring (Class Color, Custom and the
  combat red) draws its Ring Style's own lighting in five tones made from the
  color (`Style.ColorTones`: hi and light 60% and 30% toward white, the color
  itself, dark and deep 45% and 65% toward black): Mode-Blizz's Specular,
  Mode-Thin's and Mode-Round's Bevel, or Mode-BlizzEmpty's flat color.
- **Portrait Size** is 165% on the Player and Target by default (the owner,
  in game, November 18, 2026); the smaller frames keep 140%.
- **Class Color Softness is retired.** Class and reaction colors are their
  true colors everywhere on the unit frames: the ring, Class Color health,
  class and reaction texts and names. The slider is gone from the Text tab.

Version 23 to 24 moves a Portrait Ring still on Metal (the old default) to
Class Color, a Player or Target Portrait Size still at 140 to 165, and
removes `classSoftness`. Custom stays, and the saved Ring Style and Ring
Metal are kept.

Manual check (layout version 24):
- **Navigation:** **Frames** › **Unit Frames**, the **Portrait** and
  **Text** tabs, **Editing:** Player; then the game world.
- **Action:** look at the Player and Target portraits with a hostile, a
  neutral and a friendly NPC targeted. On the Portrait tab, try each **Ring
  Style** with **Ring Finish** Class Color, then Silver, then Custom. Open
  the **Text** tab.
- **Required state:** out of combat, Unit Frames on, a profile last saved
  on Metal at Portrait Size 140 (or a fresh one).
- **Confirmation:** Portrait Size reads 165. Both rings are your class color
  on the Player and red, yellow or green on the Target, at full strength (not
  pastel), in Mode-Blizz's lighting (lighter near the top, darker through the
  sides), with a thin black line outside the color and another between the
  color and the portrait. Ring Style stays on screen for every finish and
  changes the ring's lighting in the color too; Ring Finish lists Default,
  Silver, Steel, Gunmetal, Class Color and Custom, and Custom shows Portrait
  Ring Color. The Text tab has no Class Color Softness slider.

## Player auras move to Buffs & Debuffs (November 17, 2026)

The owner asked for the Player frame's buffs and debuffs to be bars in the
new **Buffs & Debuffs** module ([BUFFS_DEBUFFS.md](BUFFS_DEBUFFS.md)): bars you
filter by kind, size, style, blacklist and place anywhere (Player Buffs and
Player Debuffs anchor to the ModeUI Player Frame by default). Unit Frames no
longer draws Player auras (`M:ShowsAuras(unit)` in `Auras.lua`), and editing
the Player, the **Auras** tab shows a note and **Open Buffs & Debuffs**
instead of its controls. `db.player.buffs` and `db.player.debuffs` stay saved
and untouched; a profile whose Player frame showed either starts Buffs &
Debuffs switched on (its `Adopt`). Target, Target of Target, Focus and Target
of Focus keep their auras here. No layout version change: nothing saved moved.

## Match Width and Match Height (November 15, 2026)

Every unit frame offers Edit Mode's **Match Width** and **Match Height**
(the element panel's Match Size): click one, then the element whose width or
height the frame should take, on screen (its own Scale is divided out). The
frame follows it whenever it changes. Width sets the bars' length (the
portrait stays); height sets the bar block, or with a portrait the ring
(Portrait Size % of the block). Frame Width and Health Height stay saved for
when matching stops, and the ranges still apply (a Health Height of 10 to
60). `matchWidth` and `matchHeight` per frame (identity keys: a Target that
matches the Player keeps its own); the picks are the profile's
`sizeMatches`. Each frame's stand-in is a Position target
(`unitFramesPlayer`, ..., labelled "ModeUI Player Frame" and so on) so
other elements can pick it, for matching and for anchoring where they take
any ModeUI element. Unit frames themselves still hang only from the screen
(or attach to the Target and Focus). Code: `Layout.lua` (`MatchedFrame`),
`Build.lua` (`RegisterPosition`).

## Lighter Slate, a 4px ring, glowing health numbers

- Empty bars are a lighter Slate (`#575757`), easier to tell from the fill.
- The portrait ring is 3px of Steel (was 2px), lit from the top like the frames'
  edge-lit rims, with a 1px dark shadow ring outside; the portrait sits 3px
  inside. The Ring choice formerly called Steel Sheen is now Steel.
- Health texts and names glow (Text tab, Glow group; `Style.TextHalo`, the
  Halo: 8 copies of the text 1px out under it, in place of the text's
  shadows). **Health Text Glow**: on,
  **Health Glow Color** Deep, **Health Glow Strength** 15%. **Name Text
  Glow**: on, **Name Glow Color** Ink, **Name Glow Strength** 20% (names and
  Level and Name, not the level alone). Colors: Deep, Ink, Match Text;
  strength 5% to 40%. Keys `healthTextGlowColor`, `healthTextGlowStrength`,
  `nameTextGlow`, `nameTextGlowColor`, `nameTextGlowStrength` (November 17,
  2026, filled from defaults with no version step; `healthTextGlow` keeps its
  value). Before, health texts had a 22% capsule behind them (`Style.TextGlow`).
- Borders stay one physical pixel even when a frame's scale changes after
  layout: each edge's holder ignores its parents' scale and takes Blizzard's
  pixel factor (this fixed oversized rims on nameplate aura icons).

## Textures that read in game (layout version 23)

- Health in its Default color is the dark fill `#1C1D1C` (`Style.Tone.darkFill`),
  lighter than the old Onyx `#131212`, so the texture shows.
- Mode textures with light (Matte, Gradient, Glass, Button, Cast, Panel)
  draw their base times the bar color plus the white lift over the fill
  (`Style.ApplyBarLook` through `Kit.BarForeground`), as the previews do,
  instead of the single baked file whose light the dark color hid.
- Mode Matte has a soft sheen: a faint top line and a light band fading out
  by the middle.
- Empty bars are Slate at 60% (Background Opacity, health and power) with no
  black plate behind them, so the world shows through the gray; the plate
  returns only when both empty bars are at 100%.

Version 22 to 23 moves Background Opacity still at 100 to 60, on the health
and power bars; other values stay.

## Text by kind, outlined cast text, a whiter Gradient

- The Text tab: Font and Colors, then a tile per kind of text (Name, Level,
  Health Text, Power Text) with the same controls: Show (its formats or
  Hidden), Position (a spot on the frame; a spot another text holds says so),
  Size, Color (the modes that suit it, and a Custom swatch), Offset X and Y.
  Moving a text carries its size, color and offset; turning a hidden one on
  puts it in its home spot. The spot grid and its quick color icons are gone.
- Cast text has its own Outline (Cast Bar tab), on by default.
- The Gradient ends 50% toward white, and the letters reach it sooner.

## Bold bar text, health by color, auras clear of the ring (layout version 22)

- Text in the bars and the cast bar in Bold; names on the border stay
  SemiBold. Cast text 11px.
- Health texts in their Default color follow **Health Text Color** (Text tab):
  By Health (default: Rosewood at 30% and under, Ivory, Celadon at full,
  through `Style.PaintHealthText`'s color curve on `UnitHealthPercent`) or the
  Text Color. Dead, ghost, offline and objects keep the Text Color.
- Auras: a row starting on the portrait's side starts past the ring (the
  frame's `tuck` plus 2px); 22px icons, five to a row, so the Target's buffs
  sit on its border and end before the name.
- Settings: every text spot (Top, Middle and Bottom Text, Name on the Border,
  Power Text) moved to the Text tab, which the preview's texts now open.

Version 21 to 22 changes 20px auras to 22, eight to a row to five, and 10px
cast text to 11.

## After the first in-game check (layout version 21)

- Portrait Size 140 (a 58px ring on the 42px block); the portrait image is
  cropped a little toward the face (texture coordinates 0.1–0.9 across,
  0.04–0.84 down) and sits on a dark disc, so nothing behind shows through.
- One text shadow: the lifted second copy is off by default (it doubled the
  text); when turned on, its copy of a Gradient name carries no color codes.
- Names in SemiBold when the frame's font is the Mode typeface (`Style.Weighted`);
  the Gradient runs 40% toward white.
- The cast bar icon sits on the portrait side; the Comet spark is clipped to
  the bar, so it never shows past the bar's start.
- The shield's finish lines live inside the clip that follows the shield's
  fill, so an empty shield (and full health with no shield) shows no line.
- Reset in the settings footer returns every frame, its cast bar, auras,
  status and texts, and the class resource to the defaults
  (`M:ResetToDefaults`); Edit Mode keeps the positions.
- Settings: the text spots are four tiles (Top, Middle and Bottom Text, Name
  on the Border) and the Portrait tab three (Portrait, Status Icons, Combat
  Ring).

Version 20 to 21 changes Portrait Size 165 to 140, turns the lifted shadow
off, and moves a far-side cast icon to the portrait side.

## The Mode look (layout version 20)

November 2026, the Mode design language (`docs/DESIGN_LANGUAGE.md`). The
Onyx skin's masked rim, cap and circle textures are gone; every frame is built
from `Shared/Style`:

- **Frame:** the bar block (health, a 1px black line, power) inside a
  `Style.Edge` border, `frame` (2px band, a 1px black line just inside) on the
  Player and Target and `frameThin` (1px) on the smaller frames, in each
  frame's **Border Style** and **Border Metal** (Frame tab; Mode-Border in
  its own metal by default), the cast bar with it. The border covers its
  own rounded corners, so nothing is masked. Frames keep the Onyx frame's
  overall size, so positions and attachments carry over.
- **Portrait:** a `Style.Ring` (Mode-Border's ring lighting, no gap) centred on the block's
  portrait-side edge, drawn over the bars, which run under it. Portrait Ring:
  Metal (the default until layout version 24: **Ring Style**, Mode-Border or Mode-Empty, Mode-Border by default,
  in **Ring Metal**, Default being the style's own), Class Color or Custom
  (in the ring style's lighting, in tones of the color); the combat ring is in
  the combat red.
- **Bars:** Mode-FG health (Dark) and power over Mode-BG on Slate at
  85%; any SharedMedia texture still works. Combined shields
  (`Style.Shield`) on health, from Blizzard's heal prediction calculator
  (`UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_HEAL_PREDICTION`); **Shields** on the
  Health Bar tab turns them off.
- **The Player's cast bar steps aside** while the Cooldown Manager's Cast Bar
  (ModeCDM) is on: it claims the player's cast (`Kit.PlayerCast`), and the
  Cast Bar tab says so. Blizzard's Player cast bar stays faded while either
  holds it (`Kit.NativeFade`, shared since November 18, 2026). Without ModeCDM
  nothing changes. Target and Focus cast bars are untouched.
- **Cast bar:** a `frameThin` block, black inside, Mode-FG over Mode-BG, with
  the Comet spark (`Style.Comet`). Its 2px gap is clear space between the two
  borders' shadow rings, and with a portrait it starts where the ring ends.
- **Text:** the Mode typeface (Urbanist, "Mode"); names in the solid class color (Gradient an option)
  (`Style.GradientText`, a secret name keeps the plain color), the new default
  Name Color.
- **Sizes:** Player and Target 184 wide, 34px health, 3px power, a 66px
  portrait in its 70px ring (Portrait Size 165%); the smaller frames 22px
  health and 3px power, 130 wide (Focus 160).
- **Settings:** tiles four across under the preview strip; the descriptive
  notes are gone.

Version 19 to 20 replaces only values still at their old defaults: power 10
(6 on the small frames) to 3, health 26 to 34 (16 to 22), width 180 to 184
(110 to 130, Focus 160), Portrait Size 150 to 165, Mode Gradient health to
Mode Matte, power to Mode Gradient, cast to Mode Cast, Mode Slate to Mode BG,
70% backgrounds to 100%, Sky names to Gradient, the Class Gradient ring to
Steel Sheen, Expressway to Mode Geist, and the 3px cast gap to 2px (the Focus
keeps its 8px).

## Texts colored by the unit

November 13, 2026, per the owner: a text spot's color (`texts.<slot>.colorMode`)
can also be **Reaction** (hostile red, neutral yellow, friendly green, tapped
gray, softened by Class Color Softness), **Class Color** (a player's class
color, anyone else by reaction) or, for the level only, **Level Difficulty**
(`GetCreatureDifficultyColor` for the unit's level against yours; a skull
level is red). A mode that doesn't suit the text (Level Difficulty on a name)
shows the default color; an unknown color does too. These colors are
repainted whenever the frame's unit, faction or level updates
(`M:PaintUnitColoredTexts`); stand-ins show the Player friendly and the other
frames as a level 60 enemy. In the Health Bar and Power Bar tabs each spot with
a text shows icons for the modes that suit it, at the right of its size
controls: three stripes for Reaction, your class icon for Class Color and five
stripes for Level Difficulty. Clicking the lit icon goes back to the default;
right-clicking the swatch does too (the Default button is gone). No saved key
changes: the new values are extra choices of `colorMode`.

## Editing marks, cast bar width, Focus cast gap (layout version 19)

November 13, 2026, per the owner:

- **Editing** lists each frame with **On** (Mode green) or **Off** (muted)
  beside its name, as Action Bars marks its bars; the dot and the separate
  On / Off label beside the list are gone. **Turn On** still shows for a frame
  that is off.
- **Portrait** tab: **Show Portrait** comes first, then Status, then the
  portrait's look. A matched Target takes it from the Player (as before).
- **Mirror on a Right-Side Portrait** is now called **Keep Relative Text
  Positions**, the name the owner asked for. It still does what it did: on a
  right-hand portrait the Rested and Combat badges swap to the mirrored
  corners, so they keep their place relative to the bars (`status.mirror`).
- **Cast Bar**: **Bar Height** and **Gap** were already there, beside each
  other under Placement. The owner found no size option besides them, so
  **Full Width** (on: the bar block's width, short of the portrait, as
  before) and **Bar Width** (off: that wide, centred under the same span)
  join them (`castBar.fullWidth`, `castBar.width`, 40-400).
- **Focus cast bar** sits 8px from the frame by default (`CastDefaults`).
  Layout version 19 moves a Focus cast bar still at the old 3px to 8px; a gap
  you chose stays.

Manual check (layout version 19):
- **Navigation:** **Frames** › **Unit Frames**, the **Editing** list at the
  preview's top right; then the **Portrait** and **Cast Bar** tabs.
- **Action:** open the Editing list; turn Focus off with **Show Frame** and
  open the list again; Turn On. On the Portrait tab, look at the first
  setting. On the Cast Bar tab (Editing: Focus), untick **Full Width** and
  move **Bar Width**, then change **Bar Height**.
- **Required state:** out of combat, Focus set.
- **Confirmation:** every frame reads "On" in green or "Off" in gray beside
  its name; Focus reads Off while off. Show Portrait is the Portrait tab's
  first setting, and the badge switch reads Keep Relative Text Positions. The
  Focus cast bar hangs 8px under the frame, narrows and stays centred under
  the bars with Bar Width, and grows taller with Bar Height.

## Settings by part, Class Resource (layout version 18)

November 13, 2026, per the owner:

- **Editing** (the frame every tab changes) sits at the preview's top right,
  as on Action Bars, with a dot and On / Off for whether that frame is shown,
  and **Turn On** beside a frame that is off. Tabs no longer start with their
  own Editing row.
- **Tabs**: Frame, Health Bar, Power Bar, Portrait, Cast Bar, Auras, Class
  Resource, Text.
  - **Frame**: Show Frame, Hide Blizzard's Frame; on the Target, Match Player
    Frame and Mirror Player Text (the only place for them); Scale; Placement
    (Target of Target, Target of Focus); Reset Frame and Copy Style; Status.
  - **Health Bar** (Layout and Health together): Frame Width and Health Bar
    Height side by side, Fill Direction, Fill End Line, Health Color, its
    textures and opacity, and its text spots (nine plus the border). Width
    and fill direction stay the frame's own, so a matched Target shows them.
    The portrait is a share of the bar block's height (Portrait Size), so it
    grows and shrinks with the bars.
  - **Power Bar**: Show Power Bar, height, color, its own textures and
    opacity, and its three text spots.
  - **Cast Bar**: gains its own Foreground / Background textures.
  - **Text**: name colors and the font.
- **Own textures**: `powerForegroundTexture`, `powerBackgroundTexture`,
  `powerForegroundOpacity`, `powerBackgroundOpacity` and
  `castBar.foregroundTexture` / `castBar.backgroundTexture`. The old shared
  keys (`foregroundTexture`, `backgroundTexture`, `barForegroundOpacity`,
  `barBackgroundOpacity`) are now the health bar's. Layout version 18 copies
  the shared values into the new keys, so nothing changes on screen.
- **Class Resource** (was Combo Points; settings still in `db.comboPoints`):
  `Shared/Domain/ClassResource.lua` lists each class's resource. Forever's
  Camelot unit frames load only the Rogue and Druid combo point bars
  (Blizzard_UnitFrame.toc excludes Holy Power, Soul Shards, Chi, Runes, Arcane
  Charges and Essence for Camelot), so Rogues, and Druids in Cat Form, have
  Combo Points; another class sees "has no class resource on WoW Forever" in
  the tab, no controls, and nothing on the frame or in the stand-ins. A class
  that gains one later is a new entry in `ClassResource.CLASSES`.

## Text slots (layout version 17)

November 13, 2026, per the owner (after EllesmereUI's text elements): every
frame has fixed text spots, and each shows one text picked from a list, with
its own font size, color and offsets. They replace the separate name, level,
health and power text settings.

- **Spots** (`M.textSlots`, `Modules/UnitFrames/TextSlots.lua`): nine on the
  health bar (Top Left, Top, Top Right, Left, Center, Right, Bottom Left,
  Bottom, Bottom Right), **On the Border** (the name sitting on the top rim,
  with Border Alignment Left / Center / Right) and three on the power bar
  (Power Left, Power Center, Power Right). Saved in `db[unit].texts[slot]` as
  `content`, `size` (6–24), `x` / `y` (−100–100), `colorMode` (Default or
  Custom), `color`, and `align` on the border spot.
- **What a spot shows** (`M.choices.textContent`): None, Name, Level, Level and
  Name, Health Percent, Health Current, Health Current and Percent, Health
  Deficit, Power Percent, Power Current, Power Current and Percent.
- **Default color**: names take the Name Color (Sky, the presets, class or
  custom), the level stays muted (in Level and Name only the level is muted),
  numbers use the Text Color. Custom colors the whole text.
- **Placement** (`Modules/UnitFrames/Texts.lua`): a bar spot anchors to that
  point of its bar, 4 units in from the side and 1px in from the top or bottom
  edge. Spots on the portrait side keep the existing rule: they stop 2px before
  the portrait ring across their own line, and an X offset toward the portrait
  stops there. Names in a bar spot are at most 60% of the bar wide. Power spots
  show only with the power bar; a power value in a health spot still updates.
- **Health Deficit**: `UnitHealthMissing` is secret on Forever, so the text is
  made by `C_StringUtil.TruncateWhenZero` (a whole number, empty at zero) and
  `C_StringUtil.WrapString` (adds the "-" only to a non-empty text). Both
  accept secret values; the result goes straight to `SetText`. It shows
  "-1234" (not abbreviated) and nothing at full health.
- **Matched Target**: a Target matching the Player uses the Player's spots;
  with Mirror Player Text each Player spot shows on the other side (Left ↔
  Right, Bottom Left ↔ Bottom Right…), its X offset and border alignment
  flipped.
- **Settings**: the Text tab lays the spots out like the frame, three equal
  dropdowns to a line (Top Left, Top, Top Right; Left, Center, Right; Bottom
  Left, Bottom, Bottom Right; then On the Border with Border Alignment, and
  Power Left, Power Center, Power Right). A spot showing a text has a color
  swatch (the game's color picker; Default returns to the default color) and
  a font size (- / number / +) under its dropdown. Names (Name Color, Class
  Color Softness) and Font follow. The Name & Level tab is gone; Health and
  Power keep their bar settings. Clicking a text in the preview opens its
  spot. Offsets stay saved (migrated ones still apply) but have no control.
- **Each text once**: picking a text for a spot clears it from any other spot
  on that frame (`M:SetTextOptions`), so moving the level from Left to Right
  leaves Left empty.
- **Preview and live controls** (owner, November 13, 2026): the preview draws
  the sample at 80% (`M.PREVIEW_SCALE`) in a 150px area. Every settings slider
  and the color picker apply the first change at once, then at most one
  change every 0.12s while dragging (`W.Throttle`); letting go applies the
  last value. Each change rebuilds the frames and the settings page, which
  was what dropped frames when it ran on every slider step.
- **Migration** (layout version 17): each frame's texts move to the matching
  spots, so nothing moves: the name On the Border (Above Frame names go to the
  border raised by the difference) or in the Left / Center / Right spot when it
  was On Health Bar; health and power text in the spot of their side; the level
  in the bottom corner on the portrait side (a level Beside Health Text goes
  there too, since two texts can't share a spot). A text whose spot is taken
  moves to that spot's top row. A level color other than the default becomes
  that spot's Custom color. The old keys are removed.

## One border, the name on it (layout version 16)

November 13, 2026, per the owner: the 2px rim plus the 2px black gap inside it
read as two borders. The gap is gone (`M.GAP = 0`): one crisp 2px border runs
round the block, with the bars right inside it, so the block is 4px shorter
(42px by default) and the portrait 64px. The rim draws on its own layer
(`panel.edge`) above the bars and below the portrait, and the bars' rounded end
reaches 1px under it, so the rim covers their soft edge and no seam shows. The
fill under the portrait's end of the block takes the rim color.

Names default to **On the Border** (`namePosition = "border"`, `M:NameBottom`):
the baseline on the middle of the top rim (a quarter of the font size taken as
the descent), so the letters sit on the border, clear of the portrait ring at
their own height. Layout version 16 moves names set Above Frame onto the border.

## Level in the corner, a mirrored Target (layout version 15)

November 13, 2026, per the owner: **Level Position** (`levelPosition`, Name &
Level tab) is **Bottom Corner** by default: the level sits at the bottom of the
health bar on the portrait side, 1px up, clear of the portrait across its own
line like every bar text, with the health text alone at the other side. The
old layout is **Beside Health Text**. The Target mirrors the Player by default
(`mirrorText`), so its health text is on the left and its level bottom right.
Layout version 15 turns mirroring on for a Target that matches the Player.
Every bar text is anchored to its side of the health bar, so changing Frame
Width moves each with its side.

## Rounded-rectangle ends, a lighter rim, a softer fill line

November 13, 2026, per the owner (with a rounded-rectangle reference): the
ends are a straight edge with circular corners rather than a half oval. The
cap textures are 64x256, a straight end with 64px round corners, used at a
depth of a quarter of the box's height (`Kit.CAP_DEPTH = 0.25`) so the corners
stay circular: 12px on the 46px bar block, 6px on the 22px cast bar. Unit
frame rims (bar block, cast bar, badges, combo points, the portrait ring's
Default) use `Kit.onyx.frameRim` #40454C, a little lighter than the Onyx
border, to stand apart from the health bar. The fill end line is white at 22%
instead of 45%.

## Half-oval ends, a line that hides at full, darker Mode Slate

November 13, 2026, after the hard-edged borders were tried in game, per the
owner: keep rounded corners, with "almost a half oval" at the end. The bar
block's rim and gap are now rings (`Kit.CapRing`, `Shared/Kit/Capsule.lua`):
hard-edged flat strips along the straight edges, and a half ellipse at the end
away from the portrait (both ends without a portrait), `0.4 ×` the block's
height deep (a semicircle would be 0.5; `Kit.CAP_DEPTH`). Each rounded end is a
cap texture (`Mode/CapRight.tga`, `CapLeft.tga`) hollowed into a ring by a hole
mask (`CapHole*.tga`), so nothing opaque sits under the bars and the
background keeps its opacity to the curve. End masks (`Kit.EndMask`, wrap
`CLAMPTOWHITE`) round the health and power fills, backgrounds, sheen, fill
line and hairline to the same shape. The cast bar is rounded at both ends,
black inside its rim; its icon sits where the straight part starts.

The fill end line now sits in a clipping frame that stops 1px short of the
bar's end, so a full bar shows no line, without reading the (possibly secret)
value. Mode Slate is a touch darker: #44464A (hatch tint #55585D).

## Status on the portrait

November 13, 2026, per the owner (the recommended Portrait Badge concept):
round badges sit on the portrait ring's corners (`Status.lua`, **Status** on
the Portrait tab): **Rested** (Player only, top left, Sky icon) and **Combat**
(bottom left, red icon). Each has its own switch and corner; badges are an
even pixel size centred on the ring and swap to the outer side on a right-hand
portrait (**Mirror on a Right-Side Portrait**, now **Keep Relative Text
Positions**). **Combat Ring** turns the ring
red while the unit is in combat. **Pulse When Pulled** (Player) pulses a red
halo behind the ring while you are in combat and have no enemy targeted that is
itself in combat (`Domain.Status.PulledUnawares`); targeting the attacker
stops the pulse, and the ring holds red until combat ends. Settings are in
`db[unit].status` (own keys). Defaults: the Player has everything on; the
Target shows the combat badge; the small frames start off. Icons are
`UnitFrames/Rested.tga` and `UnitFrames/Combat.tga` from
`tools/build_shape_textures.lua`, tinted in game.

## Text never reaches the portrait

November 13, 2026, per the owner: every text stays over the bars. A text on
the portrait side (health, level, power, a name on the bar, a name above the
frame) measures the ring's **outer** edge across its own line, the band of
its font at its Y offset, and stops 2px before it, rounded out to whole
pixels: `clear = R + √(R² − d²) + 2px − inset`, where `R` is the portrait's
outer radius, `d` the line's edge nearest the portrait's centre and `inset`
where the bars start. A line past the circle gets no tuck. X offsets move a
text away from the portrait freely; toward it they stop at that line. At
default sizes bar texts keep their 12px inset; a name above the frame sits
closer (1px in from the bars), since the ring curves away up there.

## Mode Slate backgrounds (layout version 14)

November 13, 2026, per the owner: no pattern lines in bar backgrounds, and a
stronger, more solid feel. Two new background textures, shared with the
nameplates (`Kit.BarBackground`, `Kit.BarBackgroundColor`):

- **Mode Slate** (`slate`): flat, tinted `Kit.onyx.slate` #4C4E52, a
  near-neutral gray clearly lighter than the Onyx fill. The unit frame
  default, at 70% Background Opacity.
- **Mode Slate Hatch** (`slateHatch`): `Mode/SlateHatch.tga`, a 4×4 tile (80%
  gray with a full-white diagonal) tinted #5F6267, so its base matches Mode
  Slate and the lines are a little lighter. It tiles one texel per screen
  pixel (`SetTexCoord` from the bar's size over `4 × px`, nearest filtering).
  Kept for overlays such as overshields; also offered as a background.

Layout version 14 moves a frame still on the old defaults (Flat, 25%) to Mode
Slate at 70%; chosen textures and opacities stay.

**Frame Width.** The bar width setting is now **Frame Width**, one of each
frame's own keys (`barWidth` in `M.ownKeys`), shown on the Layout tab under
Editing even while the Target matches the Player, beside Fill Direction.
Layout version 14 gives a matched Target the Player's width, so nothing moves.

## Hard-edged borders and the fill end line

November 13, 2026, per the owner: the rounded rim and gap textures were
filtered when scaled, so the border looked inset and softly bled into the
bars. The bar block and the cast box now draw a hard-edged border: four flat
strips each for the 2px rim and the 2px black gap (`Kit.Edges`,
`Kit.PlaceEdges`, square corners, whole pixels), plus a flat black cap under
the portrait's end of the block up to the bars. Nothing sits under the bars,
so their background still shows the world through it (the clipped bands are
no longer needed here). The health fill also gets a 1px light line where it
ends (`fillEdge`, on by default; **Fill End Line** on the Layout tab), placed
on the fill texture's leading side (`Kit.FillEdge`), so it follows the fill
direction and secret values alike.

## Fill direction, cast bar clearance, steady preview

November 13, 2026, after the first look in game, per the owner:

- **Fill direction** (`fillDirection`: standard, Left to Right / reverse,
  Right to Left; Layout tab). The Target defaults to Right to Left, the other
  way from the Player. It's an identity key, like the portrait side, so a
  Target matching the Player keeps its own, and it shows on the Layout tab
  even while matched.
- **Cast bars stop short of the portrait.** The box's portrait end sits where
  the ring's circle crosses the box's edge nearest the portrait's centre, plus
  2px, rounded out to whole pixels; the bar starts one rim and gap in. A box
  far enough away to clear the circle starts under the portrait's centre, and
  without a portrait it spans the bar block.
- **Steady preview.** The preview has one fixed size (`M.PREVIEW_WIDTH`,
  `M.PREVIEW_HEIGHT`) and centres the sample frame on it, so moving or
  resizing parts no longer resizes the preview or moves the sample.
- **The open tab picks the sample** for parts only one frame has: on the
  Combo Points tab the preview shows the Target whatever Editing says
  (`M.previewSectionUnits`).
- **Tab slider.** Settings pages whose tabs don't fit get `<` and `>` buttons
  at both ends and a 6px scroll bar under the tab strip
  (Shared/Settings/SectionTabs.lua), shown only while they overflow; the
  buttons, dragging the bar or the mouse wheel scroll the tabs.

## Settings preview

November 13, 2026, per the owner: the Unit Frames page has a live preview like
the Nameplates page (`Preview.lua`, through `W.Preview`). It shows one sample of
the frame chosen with **Editing**, built and painted by the same code as the
frames in the world (`BuildFace`, `ApplyLayout`, `PaintSample`), so it shows the
portrait, bars, texts, cast bar, sample buffs and debuffs and, on the Target,
combo points exactly as set. Static shows the cast part-way through; Animated
loops it. Clicking the health bar, power bar, portrait, name, cast bar, an aura
(its group) or the combo points opens that part's tab at its first setting
(`M:JumpTo`, `page.jumpTargets`).

## Buffs and debuffs

November 13, 2026, per the owner: each frame shows buffs and debuffs
(`Auras.lua`, the **Auras** tab with a Buffs/Debuffs switch), each group with
the same options in `db[unit].buffs` / `db[unit].debuffs` (own keys):
`enabled` (buffs on for the Target only; debuffs off), `filter` all / mine /
dispellable, `anchor` (a corner: Top Right, Top Left, Bottom Right, Bottom
Left), `grow` left/right, `max` 8, `perRow` 8, `x`/`y`, `size` 20, `spacing` 2,
`shape` cropped (4px wider than tall, like the nameplates) / square, `border`
by dispel type / Mode, `timer` and `count`.

A group's rows start at a corner of the health bar's span: Top Right puts the
first icon's right edge on the health bar's right edge, so the row lines up
with the bars and never reaches over the portrait. Top rows sit 2px over the
bar block; when the name is above the frame on the same side (or centred) the
row sits over the name instead, so they never overlap. Bottom rows sit under
the bars, past a cast bar below them. Rows stack away from the frame. Filters
are game filter strings (`Domain.Auras.frameFilters`, without the nameplate
filter) and aura fields go only to widgets that accept secrets, as on the
nameplates. Hovering an icon shows the game's aura tooltip
(`GameTooltip:SetUnitBuffByAuraInstanceID` / `SetUnitDebuffByAuraInstanceID`,
from Forever's `TooltipDataHandler`); the ID may be secret only for
Blizzard's own code, so while it is hidden the call fails under `pcall` and no
tooltip shows. Icons take mouse motion only, where the client allows it.

## Cast bars

November 13, 2026, per the owner: each frame has a cast bar in the Mode skin
(`CastBar.lua`, the **Cast Bar** tab), on for the Player, Target and Focus. It
is a second block with the frame's rounded rim, black gap and bar texture,
exactly as wide as the bar block, `gap` pixels under it (or over it); its bar
starts and ends where the health bar does, and the portrait ring caps its near
end like the bar block's. The spell icon takes a square from the far end, the
portrait end, or is hidden; the spell name and a timer sit inside. Settings
are in `db[unit].castBar` (`enabled`, `hideBlizzard`, `position` below/above,
`height` 14, `gap` 3, `icon` far/near/none, `showText`, `showTimer`,
`fontSize` 10, `color`, `lockedColor`), one of the frame's **own keys**: a
Target matching the Player keeps its own, while Copy Style and Reset include
it. Hide Blizzard Cast Bar fades `PlayerCastingBarFrame`, `TargetFrameSpellBar`
or `FocusFrameSpellBar`. While faded, the Alpha animations on the bar itself
run from 0 to 0: Blizzard's interrupt hold (`HoldFadeOutAnim`) sets the bar's
alpha directly and would show it for a second. Cast painting and the timer are shared with
Nameplates (`Kit.PaintCastBar`, `Kit.CastTimer` in `Shared/Kit/Cast.lua`).

## Combo points around the Target portrait

November 13, 2026, per the owner: Blizzard's combo points stayed pinned to the
faded Blizzard Target frame. The Target frame now draws its own (`Combo.lua`,
the **Combo Points** tab): one round socket per point (Onyx rim, dark socket,
lit fill) on an arc around the portrait's outer side, or in a row under the
bars when the portrait is off. Settings live in `modules.unitFrames.comboPoints`
(not per frame, so they stay editable while the Target matches the Player):
`enabled`, `hideBlizzard` (fades Blizzard's `ComboFrame`), `arc` (Upper Outer,
Outer Side, Lower Outer, Top, Bottom), `size` 10, `spacing` 3, `distance` 3,
`activeColor`, `emptyColor`. Sizes are even pixel counts and centres are
snapped, so the sockets sit on the pixel grid. Points show while the player is
a Rogue or a Druid in Cat Form; the count may be secret and only reaches
StatusBar `SetValue`.

## Small-frame defaults and attachment (layout version 13)

November 13, 2026, per the owner: Target of Target defaults to no portrait,
75% scale and the name inside the health bar on the left, attached under the
Target frame's bottom-right corner. Target of Focus is the same under the
Focus frame, and Focus is the same frame at 90% scale on its own. Layout
version 13 moves a saved setting to the new default only while it still equals
the version 12 default.

Attachment (`attach`, `attachPoint`, `attachOffsetX`/`attachOffsetY` in
physical pixels; identity keys, so Copy Style and Reset keep them) is handled
by the module: the Position Manager's frame anchors refuse ModeUI frames, so an
attached frame is unregistered from it and its button is anchored to the
parent's button (its Edit Mode stand-in to the parent's stand-in, so a secure
frame is never anchored to a plain one). Detached, or while the parent frame
is off, it registers again at its saved position and moves in Edit Mode.

## Target of Target, Focus and Target of Focus

November 13, 2026, per the owner: three more secure frames in the same skin,
`targettarget`, `focus` and `focustarget`, each saved under its unit token
with the full per-frame settings set (the Target is still the only frame that
can match the Player). Target of Target and Target of Focus default to a small
frame (bar width 110, health 16, power 6, no level) with the portrait on the
left; Focus is 150 wide with the portrait on the right. Each has its own Edit
Mode element (`unitFramesTargetTarget`, `unitFramesFocus`,
`unitFramesFocusTarget`) and Hide Blizzard option. Blizzard's Focus frame is
built from the Target frame template, so it fades the same parts; Blizzard's
Target of Target and Target of Focus fade whole, also while their Target or
Focus frame is hidden. The Frames tab shows Show and Hide Blizzard side by
side for each frame, and the element tabs pick the frame from an **Editing**
dropdown. Existing profiles gain the three frames with their defaults on load.

## See-through bar backgrounds, bar textures and opacity

November 13, 2026, per the owner: the dark Onyx fill was hard to tell from the
near-black empty bar. Each frame now has four bar settings, shared by its
health and power bars and shown in the Layout tab's **Bar Textures** and
**Bar Opacity** cards:

- `foregroundTexture` (Mode Gradient) and `backgroundTexture` (Flat), or any
  SharedMedia status bar (`Kit.BarTextureChoices`, shared with Nameplates).
- `barForegroundOpacity` 100 (10–100%) fades the fills.
- `barBackgroundOpacity` 25 (0–100%) fades the empty bar, so the world shows
  through it. (`backgroundOpacity` is the panel opacity retired in layout
  version 9, so the new keys carry a `bar` prefix.)

New keys take their defaults on load, so existing frames get the see-through
background without a layout-version change. For the background to be truly
see-through, nothing opaque may sit under the bars: the rim and black gap are
drawn as four clipped bands around the bars' rectangle (`Kit.Bands`,
`Kit.PlaceBands`, moved from Nameplates into `Shared/Kit/Bands.lua`), and the
1px hairline between health and power is its own solid texture.

## Near-black rim

November 12, 2026, per the owner: the Onyx rim (`Kit.onyx.border`) is now
#25282C instead of slate #6A737D, so frame borders read close to black. The
portrait ring's Default color follows it.

## Mode Gradient on every bar (layout version 12)

November 12, 2026, per the owner: every ModeUI bar uses one texture, **Mode
Gradient** (`Kit.ModeGradient`: a flat fill with a soft white gradient over its
top half, the look the old "Mode" choice gave). The Bar Texture setting is gone,
and layout version 12 removes the saved `texture` key from both frames. ModeUI's
text and interface default to Expressway, with the bundled Lato as the fallback.

November 11, 2026. First module (in the **Frames** category since November 13) and the start of
the Play The Game Tools UI suite. Opt-in (default off), Forever only, built into
PTG with no dependency on ModeTools or any other addon. Static/mock validated
only; **native acceptance is pending**.

## Sky names, lifted shadow on all text, Target copies the Player (layout version 11)

After testing layout version 10 in-game, the owner asked for three changes:

- try their own name color, #91C6FF
- make the crisp shadow treatment the default text style for the UI
- make the Target's text match their Player frame by default

Their Player has health text on the right with Level Offset X −45, so the level
sits at the bar's left end. The mirrored Target flipped the health text to the
left and the offset to +45. That pushed the level onto the health text
("927 25 00%").

- **Sky** (#91C6FF) is the new default Name Color and `M.ACCENT`. Champagne,
  Lilac, Frost, Class Color and Custom remain.
- **Suite text style.** Every unit frame text (name, level, health and power)
  now has the fully opaque shadow one screen pixel down-right plus the lifted
  shadow: one black copy 2 pixels down-right at 45%. Each text has its own
  `lift` font string. Every write goes to both through `Write`/`Formatted`, so
  secret health and power values reach the lift through
  `SetText`/`SetFormattedText` only.
  - **Lifted Shadow** moved to the Text tab, under Text Shadow, and applies to
    all text.
  - Later suite pieces (action bars, nameplates) are meant to reuse this style
    (`M.LIFT_PIXELS`, `M.LIFT_ALPHA`).
- **Matched Target copies the Player's text layout.** With Match Player Frame
  on, the Target uses the Player's alignment and offsets as they are, so its
  health, level and name sit where the Player's do. Portrait-side text still
  clears the Target's own portrait curve.
- **Mirror Player Text** (`mirrorText`, Target only, off by default) is shown
  on every element tab while the Target is matched, next to Match Player
  Frame. It flips the alignment and horizontal offsets to the other side.
  - The grouped level and health text now read in mirror order: health first,
    then the level beside it, toward the portrait.
  - The result is the exact mirror image, so a level moved by its offset no
    longer lands on the health text.
  - It is an identity key, so Copy Style leaves it alone.

Layout version 10 → 11:

- Champagne, Lilac and Frost become Sky, so the new color shows straight away.
  Class Color and Custom are kept.
- `nameLift` becomes `liftedShadow`.
- `mirrorText` starts off.

`/reload` is enough; no new textures were added.

## Champagne, Lilac and Frost names with a lifted shadow (layout version 10)

The owner asked for the Mist names to "pop more", with more contrast and a
slight glow. A brightened Mist (#9EF0DD) with a 12-copy soft glow (commit
267fe03) looked fuzzy in-game, because translucent copies 1–2 pixels apart
smear the letter edges. From an eighth design canvas the owner then asked to
test three colors that contrast the cool Onyx/slate skin, with the cleanest
effect that still gives a slight pop, and no accent line or mark.

- **Name Color** is Champagne (#F2DFB8, default; warm ivory against the slate
  rim), Lilac (#C9BBFF; cool but clearly colored, unlike every reaction
  color), Frost (#EAF1F8; near-white with a cool tint), Class Color (pastel)
  or Custom. The colors are `M.nameAccents`; `M.ACCENT` is Champagne and seeds
  the Custom Name Color and Portrait Ring Color defaults.
- **Lifted shadow** replaces the glow. The name's own shadow is fully opaque
  and exactly one screen pixel down-right (`g.px`; other text keeps the 90%
  shadow at 1 unit). Under it, one black copy of the name sits 2 pixels
  down-right at 45% opacity (`M.LIFT_PIXELS`, `M.LIFT_ALPHA`). It uses whole
  pixels and no blur, so it adds depth while staying crisp. The copy uses the
  name's font, size and outline flag, has no shadow of its own, and a secret
  name goes straight to its `SetText`.
  - **Lifted Shadow** (Name & Level tab, on by default) turns the copy off
    and leaves the crisp shadow.
  - The lift needs Text Shadow (Text tab), so the toggle is hidden while Text
    Shadow is off.

Layout version 9 → 10 sets Name Color to Champagne unless it is Class Color or
Custom, and deletes the retired `nameGlow` and `nameGlowStrength` keys. A
saved Custom Name Color keeps its value. `/reload` is enough; no new textures
were added.

## Locked Onyx skin, class-gradient portrait ring and Mist names (layout version 9)

From a seventh design canvas the owner asked for three changes:

- Onyx colors everywhere, with health defaulting to #1C1E21
- a full portrait border in a subtle class-color gradient
- plain-text names in an accent color

They picked the Mist accent and asked for the skin to be locked to Onyx for
every frame.

- **One skin.** Every frame uses the Onyx look: the round portrait caps one
  rounded bar block inside a 2px slate rim (#6A737D) and a 2px black gap, with
  a 1px hairline between health and power. These are fixed, along with the
  empty bar (#0A0B0C) and the background.
  - Retired: the Palette presets and Custom palette, rim/gap/hairline
    thickness and color, background color and opacity, and border color and
    opacity.
  - Also retired: the Satin Matte, Inset Wells, Mode Rounded, Thin Line and
    None border styles, with their bezels, trim, name plate and level badge.
    Their unused textures (Panel, PanelEdge, Well, WellBezel, Ring, Hairline,
    TileMask) were removed. These styles remain in Git history.
- **Health Color** is Default (Onyx #131212), Class Color (pastel class for
  players, pastel reaction for NPCs) or Custom.
- **Portrait ring.** The portrait frame now sits above the bar block, so its
  whole ring is drawn over the bar's end, followed by the black gap and the
  image. Portrait Ring is one of:
  - Class Gradient (default): a vertical gradient from the pastel
    class/reaction color lightened 35% at the top to 72% of it at the bottom
  - Default: the slate rim
  - Custom
- **Names** are plain text with no sheen or texture. Name Color is Accent (Mist
  #A9D9CF, default), Class Color (pastel) or Custom. Name Position is Above
  Frame or On Health Bar.
- **Settings:** the Border tab is gone, so the element tabs are Frames,
  Layout, Portrait, Name & Level, Health, Power and Text.

Layout version 8 → 9 migrates each frame as follows:

| Setting | Before | After |
| --- | --- | --- |
| Health Color | Palette Grey, Mode Green | Default |
| Health Color | Reaction | Class Color |
| Health Color | Custom | Custom (kept) |
| Name Color | any | Accent |
| Portrait Ring | any except Custom | Class Gradient |
| Name Position | Name Row | Above Frame |
| Level | Name Row | Shown |

Every retired key is deleted from the frame's settings, and explicit choices
such as the level color stay. Layouts 2–7 keep their effects on the keys that
remain: right-aligned names, the 26 health bar, Expressway and the level size.
`/reload` is enough; no new textures were added.

## Pastel class colors, mirrored Target text and element tabs (layout version 8)

The owner asked for three changes, then chose the Soft (40%) pastel strength on
the design canvas:

- the Target's health text aligned left
- settings that can edit every part of the frame, split up piece by piece
- softer, pastel class colors

What changed:

- **Mirrored Target text.** A Target matching the Player now mirrors text
  alignment when its portrait is on the other side. Name alignment, health
  text position and power text position flip LEFT and RIGHT (CENTER stays),
  and horizontal text offsets change sign. The Player's right-aligned
  "31 54%" therefore reads "33 76%" from the Target's left.
- **Level then health.** When the health text is on the left, the level is
  placed first and the health text follows it, so both sides read level first.
- **Class Color Softness** (default 40%, range 0–100). Class and reaction
  colors are blended toward white by this amount. It applies to class-colored
  names, Class / Reaction and Reaction health, and a Class / Reaction portrait
  ring. 0% gives the original colors.
- **Settings by element.** The page now has one tab per element: Frames,
  Layout, Portrait, Name & Level, Health, Power, Border and Text. Each element
  tab starts with an **Editing: Player | Target** switch, shared by all tabs
  for the session. A matched Target shows the Match Player Frame toggle and a
  note instead of controls. A hidden frame says to turn it on in Frames.
  Frames holds visibility, Target Matches Player, the status line and the
  per-frame Reset and Copy Style tools.
- **New settings.** These make every part of the Minimal Rounded frame editable:
  - **Portrait Size** as a percentage of the bar block (`portraitScale`, 150,
    range 100–200). Portrait Ring now also applies to the round portrait.
  - **Name Sheen Strength** (55%), **Name Offset X/Y**, **Level Font Size**,
    **Level Color**, **Level Offset X/Y**, **Health Text Offset X/Y** and
    **Power Text Offset X/Y**.
  - **Palette Fill Color**, **Empty Bar Color**, **Rim Color** and **Gap
    Color**. Palette is now a preset: editing any of these four colors switches
    the frame to the new **Custom** palette. The edit starts from the preset's
    colors, so the other three stay as they looked.
  - **Rim Thickness** (2px, range 1–6), **Gap Thickness** (2px, range 0–6) and
    **Hairline Thickness** (1px, range 0–4), all in whole screen pixels.

  Health and power text offsets also work in the other border styles. Name and
  level offsets are Minimal Rounded only, so their rows show only there.

Layout version 7 → 8 gives the level its own font size, starting from the
health text size it used to share. Every other new key fills from its default,
so the frame looks the same apart from the softer class colors and the mirrored
Target text. No new textures, so `/reload` is enough.

## Onyx, Expressway, encased outline and matched Target (layout version 7)

The owner asked for four changes:

- a darker grey, closer to black
- Expressway text
- a border that clearly encloses the frame
- a Target frame that matches the Player

From a fifth design canvas they chose **A, Encased Outline**.

- **Onyx palette (new default).** The health fill is #474D53 (Satin tint), the
  empty bar #0A0B0C, the rim #6A737D and the inner gap pure black. The rim stays
  lighter than the fill so the case reads against dark scenery. Slate Grey,
  Graphite, Silver and Smoke remain selectable.
- **Encased outline.** The 2px rim still traces the bar and wraps the portrait
  as one outline. The black gap inside it is now 2px (was 1px), around both the
  bars and the portrait, so every part reads as sitting inside one case. The
  hairline between health and power stays 1px.
- **Expressway text.** It is the default font on both frames. PTG registers
  Expressway from an installed AyijeUI or EllesmereUI copy, so the font itself
  is never bundled (it is a commercial font). If no provider is installed, the
  frames use the bundled PTG Lato.
- **Match Player Frame** (Target only, default on). The Target renders with the
  Player's look, mirrored: the same sizes, palette, texture, text, power bar and
  so on. Only its side, visibility and the toggle stay its own, through one
  cached settings proxy (`FrameDB`). Player changes apply to both. While it is
  on, the Target tab shows only the identity controls and the toggle; turn it
  off to customize the Target separately.

Layout version 6 → 7 sets both frames to Onyx and changes PTG Lato to
Expressway; another explicit font is kept. The Target starts matching the
Player. Choices made afterwards are not migrated. No new textures, so `/reload`
is enough if the previous build's textures are already loaded.

## Palettes, round portrait and pixel-perfect borders (layout version 6)

The owner kept the main bar and asked for these changes to the default
Minimal Rounded frame:

- a circular portrait
- a slightly heavier, noticeable border that follows the bar's outline and
  then wraps the portrait
- a main color closer to a true slate grey
- an easily distinguishable grey health vs background palette
- right-aligned text, with the level staying in the health bar
- a slightly taller health bar, with the bars about 2/3 the portrait's height
- pixel-perfect borders

Three palettes were drawn on a fourth design canvas. They ship, together with
the requested true slate grey (the default), as a per-frame **Palette**
setting so they can be compared in-game:

| Palette | Health (Satin tint) | Empty bar | Border | Inner line |
| --- | --- | --- | --- | --- |
| Slate Grey (default) | #708090 | #1C2127 | #4C5866 | #0B0E11 |
| Graphite on Charcoal | #B4B4B4 | #1F1F1F | #4A4A4A | #0A0A0A |
| Silver on Slate | #DEDEDE | #2C3035 | #5A5F66 | #0A0A0A |
| Smoke on Coal | #969696 | #121212 | #3C3C3C | #050505 |

- **Round portrait, bars at 2/3.** The portrait is 1.5× the bar block's
  height (an even pixel count), so the block is about 2/3 of it and centred on
  it. The block starts under the circle's centre. The bars start where the
  portrait's dark inner disc crosses their top edge, less 1px, so the circle's
  curve meets them with no gap. Text on the portrait side, and the name, are
  pushed in by the disc's reach over the bars (`tuck`, 8 units at defaults).
- **One border outline.** The 2px palette border traces the bar and then wraps
  the portrait as a single shape. Draw order gives the union outline: bar border
  (`FrameFill`), portrait border circle (on the bar's layer), the bar's 1px dark
  inner line (`FrameInner`, radius 3, 2px in), the bars, the portrait's 1px dark
  inner disc, then the portrait with Blizzard's circular mask. Each shape's inner
  fill covers the other's border where they overlap, so only the combined outer
  outline shows, and the inner line continues around the portrait where the bars
  meet it. The inner line also shows as the 1px hairline between health and
  power. Circles use the crisp 128px `Circle.tga`.
- **Pixel perfect.** One physical pixel in the frame's units is Blizzard's
  `PixelUtil.GetPixelToUIUnitFactor()` divided by the frame's effective scale.
  Borders, lines, bar heights, insets and the portrait size are whole pixels.
  Frame width and height are even pixel counts, so the centre anchor stays on
  the grid, and Edit Mode positions are snapped to whole pixels too.
  `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`, both registered by Blizzard's
  Forever UI in `SharedUIPanelTemplates.lua`, re-snap the frames. Without
  `PixelUtil`, the size falls back to whole UI units.
- **Text.** The name is right-aligned above the frame. The health text is
  right-aligned in the bar, with the muted level just to its left. With Health
  Text set to None, the level sits alone at the right.
- **Health bar.** The default height is 26, up from 22; a 1px adjustment may be
  added to keep the frame an even pixel height.
- **Health Color → Palette Grey** (Slate Grey by default) is the new default. Class/Reaction, Reaction,
  Mode Green and Custom remain.

Layout version 5 → 6 right-aligns both names (owner request), grows a 22
health bar to 26, and switches health to Palette Grey so the palettes show
immediately. A previous custom health color stays saved; choosing Custom
restores it. Choices made afterwards are not migrated.

## Minimal Rounded (layout version 5)

From a third design canvas (minimal integrated frames), the owner chose
**A, Integrated Tile**, with soft rounded corners rather than a hard edge.
Their brief: a thin, minimal border around the whole frame, no separate borders
on the health/resource bars, the portrait part of the bars with no separation,
no name background, and a class-colored name with a themed text texture.

- **One thin rounded border.** A near-black rounded backing (`FrameFill.tga`,
  32×32, radius 5, slice 6) is the frame's edge. It also shows through as the
  1px hairlines between portrait, health and power. A faint 1px inner highlight
  (`Hairline.tga` at 8% white, 1 unit inside) keeps the edge clean against dark
  scenery. Content sits 2 units in, inside the corner curve, so nothing square
  pokes past the rounded silhouette.
- **Portrait tile.** The portrait fills the outer end of the bar block at its
  full height (health + hairline + power). It uses an unmasked square portrait
  (`SetPortraitTexture(texture, unit, true)`), zoomed 8% to fill, and its
  corners are rounded by `TileMask.tga`. Portrait Side moves it; Portrait Size
  and Ring don't apply.
- **No bar borders.** Health and power sit directly on a #1A1A1A track, with
  the Satin bar fill by default.
- **Level** is a small muted (#B9B9B9) number inside the health bar, opposite
  the health text. Hidden with Level Display → Hidden.
- **Name** sits just above the frame with no plate, spanning the bars and
  aligned by Name Alignment (Player left, Target right). It is class colored for
  players and in Mode reaction colors for NPCs. **Name Sheen** (default on) is
  the text texture: WoW can't fill text with a texture, so a lighter copy of the
  name (55% toward white, no shadow) is clipped to the upper 62% of the font
  height over the base text. Both copies only receive `SetText`, so secret names
  still work. The sheen applies to every border style.
- Background Color/Opacity, Border Color/Opacity, Trim and bar-bezel settings
  are hidden for Minimal Rounded. Its edge is fixed near-black so it stays thin
  and consistent.

Layout version 4 → 5 changes only values still at the previous defaults:
Satin Matte → Minimal Rounded, and text-colored names → class-colored names.
Every other style and explicit choice is kept, and later choices are never
migrated. Satin Matte, Inset Wells, Mode Rounded, Thin Line and None remain.
The three new textures come from `tools/build_unit_frame_textures.py`, and the
others rebuild byte-identically. New media needs a client restart.

## Bar bezels, no outer edge

After seeing Satin Matte in the client, the owner asked to remove the outer
frame border and frame the health/resource bars instead, with a lighter
grey/white border that has its own texture.

- **Show Frame Edge** (per frame, default off) controls Satin Matte's black
  rounded outer edge. Existing profiles take the off default, because the key is
  new.
- Each health/power well sits in a 3-unit **bezel** made from
  `WellBezel.tga` (32×32, outer radius 7, slice 8, built by the same script). It
  has a crisp bright top edge, a softer grey lower half, a horizontal brushed
  grain that stretches naturally along the bars, and a darker inner lip so the
  well reads as set into it. **Bar Border Color** (default #D8D8D8) and **Bar
  Border Opacity** (default 100%) tint it. The bezel replaces the faint
  highlight line under each well, and the two bezels sit 2 units apart.
- The name plate keeps its dark edge, and the portrait keeps its black edge and
  silver trim. Bezels belong to Satin Matte only; other styles are unchanged.

## Satin Matte finish (layout version 4)

From a second design canvas (rounded grey finishes) the owner asked for "a
clean, matte with sheen and texturing to make an elegant look". **Satin Matte**
is now the default Border Style and bar texture for both frames. It keeps the
Inset Wells layout (name plate, recessed wells, silver trim), but rounds every
part and draws it with custom textures. Inset Wells remains available.

Textures are built by `tools/build_unit_frame_textures.py` into
`Media/Textures/UnitFrames/`. The build is deterministic: fixed grain seeds,
8× supersampled anti-aliased silhouettes and byte-identical rebuilds. All five
are neutral grey (R=G=B), multiplied in-game by the frame's colors:

| File | Size | Use |
| --- | --- | --- |
| `Panel.tga` | 64×64, radius 7, slice 8 | Panel and name plate body: soft top-lit satin falloff, a broad highlight band, a 1px inner top highlight and fine softened grain. The grain stretches into a faint brushed texture across wide panels. |
| `PanelEdge.tga` | 64×64, slice 8 | 1.5px anti-aliased rounded outline, tinted black (#0B0B0B) |
| `Well.tga` | 32×32, radius 4, slice 5 | Rounded recessed bar slot with a black rim and baked inner top shadow, tinted #0E0E0E. A faint highlight line sits below it. |
| `Ring.tga` | 64×64 circle | Satin portrait-ring and level-badge body with a curved top rim light |
| `BarSatin.tga` | 64×32 | Satin health/power fill (bright top line, gentle falloff, light grain), tinted by the bar color |

The default tint is #585858 (Background Color); the satin luminance tops out
near 0.9, so the visible body runs from about #4B4B4B to #303030. Background
Color and Opacity tint the satin, and Trim Color recolors the silver
hairlines. Border Color/Opacity are hidden for Satin Matte because its outer
edge is always black. If a satin texture fails to load, the frame falls back to
the crisp Inset Wells lines rather than going transparent. New media files need
a full client restart.

Layout version 3 → 4 changes only values still at the previous defaults:
Inset Wells → Satin Matte, the Mode bar texture → Satin, and a #2B2B2B
background → #585858. Explicit choices are kept, such as another bar texture, a
custom background color, or any opacity, including 0%.

## Inset Wells border (layout version 3)

The owner reviewed three border concepts on a design canvas and chose **B,
Inset Wells**, Blizzard-like but neater. It is now the default
**Border Style**:

- The panel has a crisp double edge: a 1px black outer line (#0B0B0B) and a
  1px inner line in Border Color (#424242). These are flat line textures, so
  they stay sharp at any scale. Vertical lines stop short so corners never
  double up.
- The name sits in a darker **name plate** straddling the panel's top edge
  (about 62% of the bar width, with the same double edge). Name Alignment moves
  the plate (Target defaults to Right, beside its portrait). A row-style level
  sits at the plate's end.
- Health and power each sit in a recessed **well**: a 1px black edge around
  #0E0E0E, a soft top shadow inside, a faint #3A3A3A highlight below, and 3
  units of padding around the colored fill.
- The portrait and level badge keep a black outer edge with a **silver trim**
  hairline (Trim Color, default #9A9A9A) around a graphite ring. Portrait Ring
  "Match Frame" uses Trim Color here; Class / Reaction, Mode Cyan and Custom
  recolor the trim.

Mode Rounded, Thin Line and None remain. Profiles saved at layout version 2
that were still on the previous default (Mode Rounded) adopt Inset Wells once,
and Target's left-aligned name mirrors to the right. Any other border choice is
kept.

**In-game fixes found after the first native look:**

- **Edit Mode registration.** Position Manager measures the stand-in with
  `GetCenter`, which is nil until the frame has an anchor, so registration
  failed in the client. The stand-in now gets a default anchor first. This fix
  came from the owner's checkout and is kept unchanged.
- **Bar fill draw order.** The screenshot showed a gray health bar: the opaque
  track could draw over the colored fill. The fill is now pinned to the
  ARTWORK layer and the track to BACKGROUND −8.
- If the Mode surface texture fails to load, the panel falls back to a flat
  opaque fill instead of the asset's transparent fallback.

## Blizzard-style Mode redesign (layout version 2)

The owner asked for simple Blizzard-style frames using the PTG **mode**
theme's colors, textures, text and borders, with expanded per-frame options.

- **Layout.** A circular portrait sits on the outer edge (Player left, Target
  right, either can be switched) and overlaps a rounded panel. The panel holds
  a name row, health bar and power bar. The level shows in a small badge on the
  portrait, like Blizzard's level circle.
- **Mode materials.** The panel uses `ModeSurface` (rounded satin) and
  `ModeBorder`, tinted with the Mode graphite (#2B2B2B) and line (#424242)
  colors. The portrait ring and level badge use `ModeThumb`. Bars are flat with
  a soft Mode sheen over a #252525 track. Text uses **PTG Lato** in #D4D4D4.
  Health defaults to Mode green (#7FDB97), hostile/neutral reactions use Mode
  red/amber, and Mode cyan (#00F0FF) is available as a ring accent. Panels
  shorter than the rounded slice fall back to a flat fill with a thin line.
- **Every frame is customized independently.** Settings are grouped as Layout,
  Portrait, Name & Level, Health, Power, Background & Border, Text and Style
  Tools. Style Tools has **Reset** and **Copy Style to …**; copying mirrors the
  look but keeps the target frame's side, visibility and Blizzard-hiding choice.
- **Migration.** Phase-1 profiles (no `layoutVersion`) are migrated once. Values
  the user changed from phase-1 defaults carry into each frame. Untouched values
  adopt the Mode defaults. Retired top-level keys stay in the profile, unused.

## Suite plan

One part at a time, each accepted in-game before the next starts:

1. **Unit Frames: Player and Target** (this document).
2. Unit Frames, later phases: target of target, pet, party, then raid; cast
   bars and auras on the PTG frames.
3. Action bars (secure buttons; layout changes only outside combat).
4. Nameplates.
5. Minimap, chat, bags and tooltips. Chat may merge with the planned Reskins →
   Chat Window page rather than duplicate it.

## Reference research

The owner chose **AyijeUI 1.06** (installed in the Forever AddOns folder) as
the reference. Its `License.txt` is *All Rights Reserved* with no permission to
copy, modify or redistribute. EllesmereUI (References\Addons) is likewise
all-rights-reserved. **No code, layout values or media from either addon were
copied.** Only general patterns were studied: one `SecureUnitButtonTemplate`
button per unit, `RegisterUnitWatch` for visibility, `*type1=target` /
`*type2=togglemenu` attributes, frame styling deferred until combat ends, and
`GetClassAtlas` for class-icon portraits. The Mode look reuses PTG's own
character-panel portrait technique (`ModeThumb` rim plus Blizzard's
`TempPortraitAlphaMask`), which the owner has already seen render natively.

## Blizzard API findings (Forever branch of Gethe/wow-ui-source)

- [Blizzard_UnitFrame.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitFrame/Blizzard_UnitFrame.toc)
  loads mainline `[Family]` files with Camelot (`[Game]`) overrides. Forever is
  the mainline client, so Midnight-style secret values apply.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua):
  `UnitHealth` has `SecretReturns = true`. `UnitHealthMax`, `UnitPower`,
  `UnitPowerMax` and `UnitName` are secret under restriction conditions.
  `UnitHealthPercent` and `UnitPowerPercent` take an optional curve.
  `SetPortraitTexture(texture, unitToken)` exists; plain unit tokens are allowed
  from addon code. Every event the module registers is listed there or in
  SystemDocumentation.lua, including `UNIT_PORTRAIT_UPDATE`,
  `UNIT_MODEL_CHANGED` and `PORTRAITS_UPDATED`.
- [SimpleStatusBarAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua):
  `SetMinMaxValues`, `SetValue` and `SetStatusBarColor` are
  `SecretArguments = "AllowedWhenTainted"`.
- [SimpleFontStringAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua):
  `SetText` and `SetFormattedText` accept secret arguments when tainted.
- [CurveConstants.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXMLBase/CurveConstants.lua)
  defines `CurveConstants.ScaleTo100`, which maps a 0–1 percentage to 0–100.
- [SecureTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
  supports the `togglemenu` secure action.
- Mainline PlayerFrame.xml / TargetFrame.xml: the art and bars live in
  `PlayerFrameContainer`/`PlayerFrameContent` and
  `TargetFrameContainer`/`TargetFrameContent`. PetFrame is parented to
  PlayerFrame, and the target cast bar, auras and target of target are children
  of TargetFrame.

## Design

- **Secure buttons.** `PlayTheGameToolsPlayerUnitFrame` and
  `PlayTheGameToolsTargetUnitFrame` use `SecureUnitButtonTemplate`, with
  left-click to target and right-click for the unit menu, plus a unit tooltip on
  hover. They are created on first enable and never in combat.
  `RegisterUnitWatch` shows and hides them. The whole frame, portrait included,
  is clickable.
- **Secret-safe rendering.** Values are passed straight to status bars and
  `SetText`/`SetFormattedText`, never compared, tested or used in arithmetic.
  Percent text comes from `UnitHealthPercent`/`UnitPowerPercent` with
  `CurveConstants.ScaleTo100`. Booleans (dead/connected/player/tapped) count
  only when public `true`; a secret or failed answer is treated as unknown.
  Names may be secret and go straight to `SetText`.
- **Portraits.** Character Portrait uses `SetPortraitTexture`. Class Icon uses
  `GetClassAtlas(class)` only when the function exists and
  `C_Texture.GetAtlasInfo` confirms the atlas; NPCs, unknown classes and missing
  helpers fall back to the character portrait, then to a question-mark icon. The
  image is masked to a circle inside a tinted `ModeThumb` ring: Match Border,
  Class / Reaction, Mode Cyan or Custom.
- **Edit Mode.** PTG's Position Manager refuses protected frames, so each
  frame has a plain stand-in, `PlayTheGameTools<Unit>UnitFramePreview`,
  registered as `unitFramesPlayer`/`unitFramesTarget` (screen anchoring only).
  The stand-in uses the same Mode face with sample values; its name is yours
  on the Player and "Name" on the others, since the handle centered above it
  names the frame ("Player Frame") in volt green. The secure button
  copies its anchor and scale outside combat. Saved positions live in the shared
  `positions` table.
- **Native frames.** "Hide Blizzard … Frame" sets the alpha of the native
  Container and Content parts to 0 (re-applied if Blizzard restores it) and
  disables the native frame's mouse input. Blizzard's Target of Target
  (`TargetFrameToT`) is a child of the Target frame
  (`TargetFrameMixin:CreateTargetofTarget`), so it would float on its own: it
  fades whole with the Target frame, and it and its debuff icons release the
  mouse. Nothing is reparented and no events are unregistered, so the pet
  frame, combo points/class resources, target auras and target cast bar keep
  working. Turning the option or module off restores the saved alpha and mouse
  input outside combat (`Native.lua`).
- **Combat.** Show/hide, size, position, unit-watch and native-frame changes
  are protected. Requests made in combat are kept and applied on
  `PLAYER_REGEN_ENABLED`. Settings controls refuse changes in combat. Health,
  power, text and portrait updates continue in combat.
- **Events.** One event frame with unit-filtered `RegisterUnitEvent` for
  player/target and a second one for focus (a frame filters to at most two
  units), plus `UNIT_TARGET`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`,
  `PLAYER_ENTERING_WORLD` and `PORTRAITS_UPDATED`, registered only while a
  frame is shown. The game sends no unit events for `targettarget` or
  `focustarget`, so while either frame is on a hidden-when-unused timer
  refreshes them every 0.1 s, as Blizzard's own Target of Target does with
  `OnUpdate`.

## Target health color (layout version 25, November 20, 2026)

Health Color is each frame's own, a matched Target's too (`M.ownKeys`): the
Target's health defaults to Class Color (its class or reaction color) while
the Player's stays dark. Version 25 moves a Target still at Default (Dark)
to Class Color; a picked color stays. The Health Bar tab shows Health Color
for a matched Target.

## Totem timers (November 20, 2026)

`Totems.lua` reskins Blizzard's TotemFrame (the timers it hangs below its
Player frame) while the ModeUI Player frame is on, look only: each timer a
Mode icon (24 x 20, cropped, the circle mask taken off) in the `frameThin`
edge, its rim the element's color for a Shaman (`Tone.totem`), Blizzard's
gold ring faded, a flat swipe, the time in Urbanist Bold 10 Text bright
(a hook puts the color back after Blizzard's per-frame recolor). The Player
frame off brings Blizzard's look back. `tests/totem_timers.lua`.

Placement (`db.totems`: Attach and Size): the timers leave Blizzard's Player
frame layout (`ignoreFramePositionManager`, as Blizzard does for its cast
bar) and hang from the ModeUI Player frame's bar block: **Below, Right**
(default; Mode-DPS/TANK: their top 1px under the block's shadow, outside
the frame, growing left from its right edge), **Above, Right** (their
bottom 1px over its top, growing left, the time on the icon) or **Above,
Left** (Mode-Healer: the same height, from 1px past the portrait ring's
shadow growing right, clear of the name at the top right, 24 wide, the
time on the icon); **Blizzard's Place** gives them back. Each button holds
its icon and edge, neighbours share one shadow pixel; the row is laid out
again after each Blizzard update. Fitted once per profile (`fit` 1): a
Player mana frame (Bar Shows Mana) still at the default place, or at the
Above, Right at 18 (the first fitting's and healer@7's, which the owner
found too small), takes Above, Left at 24; any other keeps its place.

## Settings (`modules.unitFrames`)

`layoutVersion` is 17. Each frame (`player`, `target`, `targettarget`,
`focus`, `focustarget`) holds the set below (defaults shown). The Onyx rim,
empty bar and background are constants (`M.onyx`), not settings. Since layout
version 17 the Name, Level, Health text and Power text keys below are replaced
by text slots (`texts`, see "Text slots" at the top); the rows are kept as the
history of what was migrated.

| Group | Keys (default; range or choices) |
| --- | --- |
| Text slots | `texts.<slot>`: `content` (see "Text slots"), `size` 6–24, `x`/`y` −100–100, `colorMode` default / custom, `color`; `texts.border.align` LEFT / CENTER / RIGHT. Player: `border` Name (12, RIGHT), `bottomLeft` Level (11), `right` Health Percent (11). Small frames: `left` Name (11), `right` Health Percent (10). |
| Names | `nameColorMode` sky / champagne / lilac / frost / class / custom, `nameColor` Sky #91C6FF, `classSoftness` 40 (0–100%; retired at layout version 24) |

History (layout version 11):

| Group | Keys (default; range or choices) |
| --- | --- |
| Visibility | `enabled` (true), `hideBlizzard` (true) |
| Matching | `matchPlayer` (Target on): render with the Player's look and text layout; `mirrorText` (Target, off): mirror the Player's text alignment and horizontal offsets |
| Layout | `scale` 100 (50–200%), `barWidth` 180 (100–400), `healthHeight` 26 (10–60), `showPower` (true), `powerHeight` 10 (2–30) |
| Bars | `foregroundTexture` mode / flat / `media:<name>`, `backgroundTexture` flat / `media:<name>`, `barForegroundOpacity` 100 (10–100%), `barBackgroundOpacity` 25 (0–100%) |
| Portrait | `showPortrait` (true), `portraitStyle` portrait / class, `portraitSide` left (Target right), `portraitScale` 150 (100–200% of the bar block), `portraitRing` class (default since layout version 24) / border / custom, `portraitRingColor` Mist |
| Name | `showName` (true), `namePosition` above / bar, `nameAlign` RIGHT / LEFT / CENTER, `nameFontSize` 12 (8–24), `nameColorMode` sky / champagne / lilac / frost / class / custom, `nameColor` Sky #91C6FF, `nameOffsetX`/`nameOffsetY` 0 (−100–100), `classSoftness` 40 (0–100%; retired at layout version 24) |
| Level | `levelStyle` badge (shown) / none, `levelFontSize` 11 (6–24), `levelColor` #B9B9B9, `levelOffsetX`/`levelOffsetY` 0 |
| Health | `healthColorMode` default / class / custom, `healthColor`, `healthText` percent / current / both / none, `healthTextPosition` RIGHT, `healthFontSize` 11 (8–24), `healthTextOffsetX`/`healthTextOffsetY` 0 |
| Power | `powerColorMode` type / custom, `powerColor`, `powerText` none / percent / current / both, `powerTextPosition` CENTER, `powerFontSize` 9 (6–20), `powerTextOffsetX`/`powerTextOffsetY` 0 |
| Text | `font` game, `fontMedia` Expressway, `outline` (off), `shadow` (on: opaque, one screen pixel), `liftedShadow` (on; needs `shadow`), `textColor` #D4D4D4 |

"Class Color" uses Global Settings class colors for players and Mode reaction
colors for NPCs, softened by Class Color Softness.
`UnitFrames.Initialize` validates detached profile copies (profile import and
validation). Settings change only through `SetFrameOption`, `ResetFrame` and
`CopyStyle`.

## Limitations and open questions

- Native taint/security behavior, rendering, rounded-slice fit at small sizes,
  portrait masking and unit-menu operation are **unverified in the client**.
  The mock models intent only.
- Whether Forever actually returns secret health/power for player or target in
  ordinary play is unknown. Both paths are supported.
- `AbbreviateNumbers` (Current text) is a client global with no generated
  documentation for secret arguments on Forever. If it errors, the text falls
  back to the percentage.
- `GetClassAtlas` is not confirmed in the Forever source. It is used only when
  present and confirmed by `C_Texture.GetAtlasInfo`; otherwise class style shows
  the character portrait.
- "Above Frame" names sit outside the clickable area.
- Hidden native parts keep their screen space. The native pet frame and class
  resources stay where Blizzard places them; move them with Blizzard's Edit
  Mode if needed.
- No cast bar, auras, combat feedback, threat or raid icon on PTG frames yet.
  Pet, party and raid frames are later phases.
- Whether Forever's rules let players set a focus is unverified. The Focus
  frame only shows while a focus exists (unit watch), so it stays hidden if not.
- Blizzard's combo points on Forever (`ComboFrame`, Camelot) are parented to
  the Target frame and centred on its portrait; they keep working and stay
  visible where that portrait was.

## Manual checks (native acceptance)

New texture files were added in earlier versions, so restart the client fully
before testing if this is your first build since then (`/reload` cannot find
new media). Check M covers layout version 11 and check N covers version 10
(since version 11, names start in Sky and Lifted Shadow is on the Text tab).
Check O covers version 9 and check P covers version 8 (the mirrored Target text in
check P now needs Mirror Player Text on);
version 9 removed the Border tab and its controls from check P. Checks 1–10 below describe earlier styles;
use check 0 for the current default, and checks 3, 4 and 8–10 still apply as
written.

M. Sky names, lifted shadow on all text, Target copies the Player (layout version 11).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target an NPC. **Required state:** OOC.
     **Confirmation:**
     - Both names are Sky blue.
     - The name, level and health text all have a solid dark shadow with a
       fainter second shadow just below it.
     - The Target's level and health text sit like the Player's: the level
       toward the bar's left end and the health text on the right, with no
       overlap.
   - **Navigation:** `/ptg` → Interface → Unit Frames → Layout tab →
     Editing: Target → Mirror Player Text. **Action:** turn it on, then off.
     **Required state:** OOC. **Confirmation:**
     - With it on, the Target's text is the mirror image of the Player's: the
       health text on the left, the level toward the portrait, and the name
       aligned to the other side, with no overlap.
     - With it off, the text matches the Player again.
   - **Navigation:** Text tab → Editing: Player → Lifted Shadow.
     **Action:** turn it off, then on. **Required state:** OOC.
     **Confirmation:** the fainter second shadow disappears from every text on
     both frames, then returns; the crisp shadow stays.

N. Champagne, Lilac and Frost names with a lifted shadow (layout version 10).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target an NPC. **Required state:** OOC.
     **Confirmation:** both names are warm ivory Champagne with sharp edges
     (no halo), a solid dark shadow and a fainter second shadow just below it.
   - **Navigation:** `/ptg` → Interface → Unit Frames → Name & Level tab →
     Editing: Player → Name Color. **Action:** choose Lilac, then Frost, then
     Champagne. **Required state:** OOC. **Confirmation:** both names turn soft
     violet, then near-white, then Champagne; the shadows stay black.
   - **Navigation:** Text tab → Editing: Player → Lifted Shadow.
     **Action:** turn it off, then on. **Required state:** OOC.
     **Confirmation:** the fainter second shadow disappears and returns; the
     name and its crisp shadow stay.
   - **Navigation:** Text tab → Editing: Player → Text Shadow. **Action:** turn it
     off, open the Name & Level tab, then turn Text Shadow back on.
     **Required state:** OOC. **Confirmation:** with Text Shadow off the name has
     no shadows and Lifted Shadow is hidden; both come back with Text Shadow on.

O. Locked Onyx skin (layout version 9).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target an NPC. **Required state:** OOC.
     **Confirmation:**
     - Health fills are the very dark Onyx grey #131212.
     - Each portrait has a complete ring with no gap where the bar meets it,
       and the ring is a soft gradient of your class color (the NPC's reaction
       color on the Target).
     - Names are plain text with no lighter upper half (now Champagne with a
       lifted shadow; see check N).
   - **Navigation:** `/ptg` → Interface → Unit Frames. **Confirmation:** the
     tabs are Frames, Layout, Portrait, Name & Level, Health, Power and Text,
     with no Border tab, and no Palette, Border Style or Background controls.
   - **Navigation:** Health tab → Editing: Player → Health Color.
     **Action:** choose Class Color, then Custom (pick a color with Custom
     Health Color), then Default. **Required state:** OOC.
     **Confirmation:** the fill turns pastel class color, then your color, then
     Onyx again.
   - **Navigation:** Portrait tab → Editing: Player → Portrait Ring.
     **Action:** choose Default, then Custom (pick a color with Portrait Ring
     Color), then Class Gradient. **Required state:** OOC.
     **Confirmation:** the ring turns slate, then your color, then the class
     gradient.
   - **Navigation:** Name & Level tab → Editing: Player → Name Color.
     **Action:** choose Class Color, then Champagne. **Required state:** OOC.
     **Confirmation:** the name turns pastel class color, then Champagne.

P. Pastel colors, mirrored Target text and element tabs (layout version 8).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target a player of another class or an NPC.
     **Required state:** OOC. **Confirmation:** the Player reads "level
     health%" right-aligned. The Target reads "level health%" from its left
     edge, away from its portrait. Class-colored names look softer and pastel,
     not saturated.
   - **Navigation:** `/ptg` → Interface → Unit Frames. **Action:** look at the
     tab strip. **Confirmation:** the tabs are Frames, Layout, Portrait, Name &
     Level, Health, Power, Border and Text. Each tab except Frames starts with
     the Editing row and its Player and Target buttons.
   - **Navigation:** Name & Level tab → Editing: Player → Class Color Softness.
     **Action:** drag the slider to 0%, then to 100%, then back to 40%.
     **Required state:** OOC. **Confirmation:** the name goes from the
     original class color, to white, to pastel.
   - **Navigation:** Border tab → Editing: Player → Rim Thickness, Gap
     Thickness and Hairline Thickness. **Action:** change each by 1.
     **Required state:** OOC. **Confirmation:** each line changes by one
     crisp screen pixel. The Target follows while it matches.
   - **Navigation:** Border tab → Editing: Player → Rim Color → Pick.
     **Action:** choose a color. **Required state:** OOC.
     **Confirmation:** the rim around the bars and the portrait changes, and
     Health tab → Palette now shows Custom. Picking Onyx restores the preset.
   - **Navigation:** Layout tab → Editing: Target. **Required state:** OOC.
     **Confirmation:** only Match Player Frame and the note show. Turn Match
     Player Frame off, and the Target's own controls appear. Turn it back on.
   - **Navigation:** Portrait tab → Editing: Player → Portrait Size; Health tab
     → Health Text Offset X/Y; Name & Level tab → Name Offset X/Y, Level Font
     Size, Level Color. **Action:** change each. **Required state:** OOC.
     **Confirmation:** only that part of the frame changes.

0. **Navigation:** game world, Unit Frames enabled. **Action:** restart WoW,
   log in and target an enemy. **Required state:** OOC.
   **Confirmation:** each frame is a rounded bar block about 2/3 the height of
   a larger round portrait at its outer end (Player left, Target right). One
   noticeable 2px slate border runs along the bar and wraps around the portrait,
   with a thin dark inner line that continues around the portrait where the bars
   meet it. Health is a slate grey satin fill over a dark slate empty bar, with the power bar below it, split by
   a 1px line. The level and health text are right-aligned in the health bar, and
   the class-colored name with its sheen is right-aligned above. Edges are crisp,
   not blurred, at your UI scale.
   **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Health →
   Player Palette (and Target tab → Health → Target Palette). **Action:** set
   Player and Target to different palettes and compare, then try the third.
   **Required state:** OOC. **Confirmation:** the health fill, empty bar,
   border and portrait ring change together, per frame.
   **Navigation:** WoW Settings → Graphics → UI Scale (or the window size).
   **Action:** change it. **Confirmation:** the frames re-snap and stay crisp.

1. **Navigation:** `/ptg` → Interface → Unit Frames → header toggle.
   **Action:** switch to Enabled. **Required state:** OOC.
   **Confirmation:** a Blizzard-style Player frame appears left of center. It
   has a circular portrait with a black edge and silver trim on the left, and a
   dark panel with a crisp black and gray edge. The name sits in a plate on the
   panel's top edge, above a **green** health bar and a power bar, each in a
   recessed well, with a level badge on the portrait. Blizzard's player art fades
   out; your pet frame and combo points remain.
2. **Navigation:** game world. **Action:** target an enemy NPC, a friendly
   player and yourself; clear the target. **Required state:** OOC, then in
   combat. **Confirmation:** the mirrored Target frame (portrait on the right)
   shows/hides with your target. It shows the portrait, name, reaction or class
   color, and level badge (`??+` for unknown-level elites), and updates health
   in combat. Blizzard's target auras and cast bar still appear.
3. **Navigation:** game world, PTG Player/Target frames. **Action:**
   left-click, right-click and hover each, including the portrait.
   **Required state:** OOC and in combat. **Confirmation:** left-click targets,
   right-click opens the unit menu, hover shows the unit tooltip, and no
   "Interface action failed" or BugSack error appears.
4. **Navigation:** `/ptg` → window header → Edit Mode. **Action:** drag the
   Player Frame and Target Frame stand-ins, then click Done.
   **Required state:** OOC. **Confirmation:** Mode-styled stand-ins appear.
   After each drag ends, the real frame jumps to the new spot at the same size.
   Positions survive `/reload`.
5. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Layout and
   Portrait. **Action:** change Player Scale, Player Bar Width, Player Health
   Bar Height, Show Player Power Bar, Player Power Bar Height, Show Player
   Portrait, Player Portrait Style (Class Icon), Player Portrait Side, Player
   Portrait Size and Player Portrait Ring (each option; Custom shows Player
   Portrait Ring Color). **Required state:** OOC. **Confirmation:** each change
   applies immediately. Class Icon shows your class emblem, or the portrait if
   the client lacks it. The Target frame is unchanged.
6. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Name &
   Level, Health, Power. **Action:** try every Player Name Position, Player Name
   Alignment, Player Name Color, Player Level Display, Player Health Color,
   Player Health Text, Player Health Text Position, Player Power Color and
   Player Power Text option, plus the font-size sliders. **Required state:** OOC.
   **Confirmation:** text moves and recolors as labeled. Current text shows
   values such as `3,450`, or falls back to a percentage. Dead/ghost/offline
   units show `Dead`/`Ghost`/`Offline`.
7. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Background &
   Border, Text. **Action:** change Player Bar Texture, Player Background
   Color/Opacity, Player Border Style (Inset Wells, Mode Rounded, Thin Line,
   None), Player Border Color/Opacity, Player Trim Color (Inset Wells only),
   Player Font, Player Text Outline/Shadow and Player Text Color.
   **Required state:** OOC. **Confirmation:** Inset Wells shows the name plate,
   wells and silver trim, and Trim Color recolors the portrait and badge
   hairlines. The other styles switch to the rounded Mode border, a thin line or
   no border, without plate or wells. Text follows the chosen font.
8. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Style Tools.
   **Action:** click "Copy Style to Target", then switch to the Target tab and
   click "Reset Target Frame". **Required state:** OOC. **Confirmation:** Target
   first takes the Player look while keeping its portrait on the right, then
   returns to defaults. The Player frame is unchanged by the reset.
9. **Navigation:** `/ptg` → Interface → Unit Frames → Frames tab → Hide
   Blizzard Player Frame / Hide Blizzard Target Frame. **Action:** turn each off
   and on. **Required state:** OOC. **Confirmation:** off restores Blizzard's art
   and click handling; on fades it again.
10. **Navigation:** `/ptg` → Interface → Unit Frames → header toggle.
    **Action:** start combat, switch to Disabled, then leave combat.
    **Required state:** in combat, then OOC. **Confirmation:** Status reads
    "Changes are waiting until you leave combat." After combat the PTG frames
    hide and Blizzard's frames return, with no errors.

## Validation

`python tests/unit_frames.py` covers:

- Defaults and validation.
- Phase-1 migration: changed values carried over, untouched values adopting
  Mode, and repeated runs changing nothing.
- Deferral of in-combat enable/disable; secure attributes and unit watch.
- Mirrored geometry with bars past the portrait.
- Mode surface/border/ring textures and palette.
- Portrait and class-atlas paths, ring and health/power color modes, name and
  level placements, power text, border and texture styles.
- Copy Style and Reset; independence of the two frames.
- Public versus secret rendering. A secret fixture errors on any arithmetic,
  comparison, concatenation or tostring.
- Edit Mode stand-ins and the anchor/scale copy.
- Native fade/restore, and persistence across a profile round trip.

The smoke suite expects 16 modules and 7 categories.
