-- Unit Frames: locked Onyx skin, per-frame settings, migration, secret pass-through,
-- combat deferral and Edit Mode; not native rendering or security.
-- Ported from Play The Game Tools tests/unit_frames.py when Unit Frames moved to ModeUI.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")

-- Fresh install with the module switched off, as PTG shipped it.
local world = H.Load({ before = STUBS, saved = { modules = { unitFrames = { enabled = false } } } })
world.run([====[
    local M=addon.UnitFrames
    local P,O=M.palette,M.onyx
    assert(M and addon.modules.unitFrames==M and M.category=='interface' and M.defaultEnabled==true)
    assert(addon.categories.interface.title=='Interface')
    assert(not M.enabled and M.frames.player==nil,'default off creates nothing')
    assert(M.db.layoutVersion==12 and M.db.player.portraitSide=='left' and M.db.target.portraitSide=='right')
    assert(M.db.player.fontMedia=='Expressway' and M.db.player.texture==nil,'one bar texture: Mode Gradient')
    assert(M.db.target.matchPlayer==true and M.db.player.matchPlayer==false)
    assert(M.db.player.healthColorMode=='default' and M.db.player.nameColorMode=='sky' and M.db.player.portraitRing=='class')
    assert(M.db.player.namePosition=='above' and M.db.player.nameAlign=='RIGHT' and M.db.player.classSoftness==40)
    for _,key in ipairs(M.retiredKeys) do assert(M.frameDefaults.player[key]==nil and M.db.player[key]==nil,'retired: '..key) end
    -- The locked Onyx skin and the Sky, Champagne, Lilac and Frost name colors.
    local function Hex(c) return string.format('%02X%02X%02X',math.floor(c[1]*255+0.5),math.floor(c[2]*255+0.5),math.floor(c[3]*255+0.5)) end
    assert(Hex(O.health)=='1C1E21' and Hex(O.track)=='0A0B0C' and Hex(O.border)=='25282C' and Hex(O.inner)=='000000')
    assert(Hex(M.ACCENT)=='91C6FF' and Hex(M.nameAccents.sky)=='91C6FF' and Hex(M.nameAccents.champagne)=='F2DFB8' and Hex(M.nameAccents.lilac)=='C9BBFF' and Hex(M.nameAccents.frost)=='EAF1F8')
    local ids={};for _,c in ipairs(M.choices.nameColor) do ids[#ids+1]=c.id end
    assert(table.concat(ids,',')=='sky,champagne,lilac,frost,class,custom')
    assert(M.db.player.liftedShadow==true and M.db.target.mirrorText==false and M.identityKeys.mirrorText and M.db.player.nameLift==nil)
    assert(M.db.player.nameGlow==nil and M.db.player.nameGlowStrength==nil and M.frameRanges.nameGlowStrength==nil)

    -- Enabling in combat waits; nothing secure is created until combat ends.
    testLockdown=true;testCombat=true
    addon:SetModuleEnabled('unitFrames',true)
    assert(M.active and M.pending and M.frames.player==nil,'combat enable deferred')
    testLockdown=false;testCombat=false
    FireEvent('PLAYER_REGEN_ENABLED')
    local p,t=M.frames.player,M.frames.target
    assert(p and t and p.secure and t.secure and not M.pending,'secure buttons created after combat')
    assert(p.attributes.unit=='player' and t.attributes['*type2']=='togglemenu' and p.clickRegistration=='AnyUp')
    assert(watched[p] and watched[t])
    assert(PlayerFrame.PlayerFrameContainer:GetAlpha()==0 and TargetFrame.mouse==false,'native art faded')
    assert(TargetFrameToT:GetAlpha()==0 and TargetFrameToT.mouse==false and TargetFrameToTDebuff1.mouse==false and TargetFrameToTDebuff4.mouse==false,'Blizzard Target of Target fades with the Target frame')
    TargetFrameToT:SetAlpha(1);assert(TargetFrameToT:GetAlpha()==0,'kept faded when Blizzard restores it')

    -- Target of Target, Focus and Target of Focus: secure frames of their own,
    -- each replacing Blizzard's; Blizzard's Focus frame fades like the Target.
    local tt,fo,ft=M.frames.targettarget,M.frames.focus,M.frames.focustarget
    assert(tt.secure and fo.secure and ft.secure and watched[tt] and watched[fo] and watched[ft])
    assert(ModeUITargetTargetUnitFrame==tt and ModeUIFocusUnitFrame==fo and ModeUIFocusTargetUnitFrame==ft and ModeUIFocusUnitFramePreview==M.ghosts.focus)
    assert(tt.attributes.unit=='targettarget' and fo.attributes.unit=='focus' and ft.attributes.unit=='focustarget')
    assert(FocusFrame.TargetFrameContainer:GetAlpha()==0 and FocusFrame.TargetFrameContent:GetAlpha()==0 and FocusFrame.mouse==false)
    assert(FocusFrameToT:GetAlpha()==0 and FocusFrameToTDebuff3.mouse==false,'Blizzard Target of Focus fades too')
    for _,id in ipairs({'unitFramesTargetTarget','unitFramesFocus','unitFramesFocusTarget'}) do assert(addon.PositionManager.elements[id],id) end
    assert(M.db.targettarget.barWidth==110 and M.db.targettarget.levelStyle=='none' and M.db.focustarget.healthHeight==16)
    assert(M.db.focus.portraitSide=='right' and M.db.focus.barWidth==150 and not M.db.focus.matchPlayer and not M.db.targettarget.matchPlayer)
    assert(tt.width<p.width and tt.height<p.height and not tt.levelText:IsShown(),'Target of Target is small, without a level')
    -- The game sends no unit events for targettarget/focustarget: a short timer refreshes them.
    assert(M.poller:IsShown());Advance(0.2)
    units.targettarget={exists=true,health=300,max=600,power=10,powerMax=100,token='RAGE',name='Totfix',level=12,reaction=2,connected=true}
    Advance(0.05);assert(tt.nameText:GetText()~='Totfix','waits for the timer')
    Advance(0.06);assert(tt.nameText:GetText()=='Totfix' and tt.healthText:GetText()=='50%','refreshed on the timer')
    units.focus={exists=true,health=50,max=100,power=20,powerMax=100,token='MANA',name='Focusfix',level=30,reaction=5,connected=true}
    FireEvent('PLAYER_FOCUS_CHANGED');assert(fo.nameText:GetText()=='Focusfix' and fo.healthText:GetText()=='50%')
    units.focus.health=25;FireEvent('UNIT_HEALTH','focus');assert(fo.healthText:GetText()=='25%','focus unit events')
    units.targettarget.name='Swapped';FireEvent('UNIT_TARGET','target');assert(tt.nameText:GetText()=='Swapped','new target of target at once')
    assert(M:SetFrameOption('targettarget','enabled',false) and M.poller:IsShown(),'the Target of Focus still needs the timer')
    assert(M:SetFrameOption('focustarget','enabled',false) and not M.poller:IsShown(),'no timer without them')
    assert(M:SetFrameOption('targettarget','enabled',true) and M:SetFrameOption('focustarget','enabled',true) and M.poller:IsShown())
    units.targettarget,units.focus=nil,nil

    -- Onyx frame: round portrait cap over one rounded bar block, 2px rim + 2px gap, 1px hairline.
    local tex=function(key) return (addon.Media:GetTexture(key)) end
    local mg=p.geometry
    -- px=1: block = 26 health + 1 + 10 power + 2*(2 rim + 2 gap) = 45 -> odd, so health grows 1
    -- (block 46); the portrait is 1.5x the block (70), the bars about 2/3 of it, centred 12 down.
    assert(mg.px==1 and mg.border==2 and mg.line==2 and mg.gap==1 and mg.pad==4)
    assert(mg.healthHeight==27 and mg.blockHeight==46 and mg.portrait==70 and mg.height==70 and mg.blockY==12 and mg.portraitY==0)
    assert(mg.blockStart==35 and mg.inset==60 and mg.width==244 and mg.tuck==8 and mg.barsTop==16)
    assert(p.width==244 and p.height==70)
    local pp=Point(p.panel);assert(pp[1]=='TOPLEFT' and pp[4]==35 and pp[5]==-12,'bar block starts under the portrait centre')
    local pb=Point(p.panel,2);assert(pb[1]=='BOTTOMRIGHT' and pb[5]==12)
    assert(p.panel.fill.texture==tex('UnitFrameFrame') and p.panel.fill.vertexColor[1]==O.border[1],'slate rim')
    local ip=Point(p.panel.border);assert(p.panel.border.texture==tex('UnitFrameFrameInner') and ip[4]==2 and ip[5]==-2,'2px black gap inside the 2px rim')
    assert(p.panel.border.vertexColor[1]==O.inner[1])
    for _,bar in ipairs({p.health,p.power}) do
        assert(bar.bg.vertexColor[1]==O.track[1] and bar.bg.vertexColor[3]==O.track[3] and bar.statusBarTexture==addon.Kit.FLAT and bar.sheen:IsShown(),'Mode Gradient bars')
        assert(bar.fillTexture.drawLayer=='ARTWORK','fill drawn above the track')
    end
    -- See-through background: 25% by default, so the rim and gap are four clipped
    -- bands around the bars' rectangle (nothing opaque under the bars), with a
    -- solid hairline between health and power.
    local d=M.db.player
    assert(d.barForegroundOpacity==100 and d.barBackgroundOpacity==25 and d.foregroundTexture=='mode' and d.backgroundTexture=='flat')
    for _,bar in ipairs({p.health,p.power}) do assert(math.abs(bar.bg.vertexColor[4]-0.25)<1e-9,'25% background') end
    assert(#p.panel.bands==4 and #p.panel.fills==4 and p.panel.bands[1].clipsChildren)
    for i=1,4 do assert(p.panel.fills[i].texture==tex('UnitFrameFrame') and p.panel.inners[i].texture==tex('UnitFrameFrameInner')) end
    -- Hole: from the bars' start (inset 60 - block start 35) to one rim and gap (4) in.
    assert(Point(p.panel.bands[1],2)[5]==-4 and Point(p.panel.bands[2])[5]==4,'top and bottom bands stop at the bars')
    assert(Point(p.panel.bands[3],2)[4]==25 and Point(p.panel.bands[4])[4]==-4,'side bands stop at the bars')
    assert(Point(p.panel.bands[3])[5]==-4+1 and Point(p.panel.bands[3],2)[5]==4-1,'side bands overlap by a pixel')
    assert(Point(t.panel.bands[3],2)[4]==4 and Point(t.panel.bands[4])[4]==-25,'target: the portrait side is the right')
    local hl=p.panel.hairline;assert(hl:IsShown() and hl.vertexColor[1]==O.inner[1] and hl.vertexColor[4]==1 and Point(hl)[2]==p.health and Point(hl,2)[2]==p.power,'solid hairline')
    local mhp=Point(p.health);assert(mhp[1]=='TOPLEFT' and mhp[4]==60 and mhp[5]==-16 and p.health.height==27)
    local mht=Point(t.health);assert(mht[1]=='TOPRIGHT' and mht[4]==-60,'target mirrored: portrait on the right')
    assert(Point(p.power)[5]==-1 and p.power.height==10,'1px hairline between health and power')
    local cap=Point(p.portrait);assert(cap[1]=='TOPLEFT' and cap[4]==0 and cap[5]==0 and p.portrait.width==70)
    assert(Point(t.portrait)[1]=='TOPRIGHT')
    local ring=p.portrait
    -- Full ring: the portrait frame sits above the bars, so its whole circle is drawn over the bar's end.
    assert(ring:GetFrameLevel()>p.health:GetFrameLevel() and ring:GetFrameLevel()>p.panel:GetFrameLevel(),'full ring over the bar end')
    assert(ring.ring.texture==tex('UnitFrameCircle') and ring.ring:IsShown())
    assert(Point(ring.innerEdge)[4]==2 and ring.innerEdge.vertexColor[1]==O.inner[1],'black gap inside the ring')
    assert(Point(ring.back)[4]==4 and ring.back.vertexColor[1]==O.track[1])
    assert(Point(ring.icon)[4]==4 and ring.icon.mask.texture=='Interface\\CHARACTERFRAME\\TempPortraitAlphaMask','circular portrait')
    assert(p.nameClip==nil and p.nameShine==nil and p.panel.ringBorder==nil,'plain name, single ring')
    assert(p.textLayer:GetFrameLevel()>ring:GetFrameLevel(),'text above the portrait')
    local np=Point(p.nameText);assert(np[1]=='BOTTOMLEFT' and np[2]==p.health and np[4]==12 and np[5]==4+3 and p.nameText.justifyH=='RIGHT','name right-aligned above')
    assert(p.nameText.font[1]:find('Lato') and p.healthText.font[1]:find('Lato'),'Expressway falls back to ModeUI Lato when not installed')
    assert(t.nameText.justifyH=='RIGHT','matched target copies the Player name alignment')
    local lp=Point(p.levelText);assert(lp[1]=='RIGHT' and lp[2]==p.healthText and lp[4]==-6,'level before the right-aligned health text')
    assert(Point(p.healthText)[4]==-4 and Point(p.healthText)[1]=='RIGHT')
    -- Matched Target copies the Player's text layout: level before the right-aligned
    -- health text, which clears the Target's own portrait curve.
    local th=Point(t.healthText);assert(th[1]=='RIGHT' and th[2]==t.health and th[4]==-4-8,'health text on the right, like the Player')
    local tl=Point(t.levelText);assert(tl[1]=='RIGHT' and tl[2]==t.healthText and tl[4]==-6,'level before it, like the Player')
    assert(Point(t.nameText,2)[4]==-(8+4) and Point(p.nameText,2)[4]==0,'name kept clear of the portrait')
    assert(p.levelText.color[1]==P.muted[1])

    M:UpdateAll()
    local function Soft(c,amount) amount=amount or 0.4;return {c[1]+(1-c[1])*amount,c[2]+(1-c[2])*amount,c[3]+(1-c[3])*amount} end
    local function Near(a,b) return math.abs(a-b)<1e-9 end
    local rc=addon.ClassColors:GetColor('ROGUE');local rogue={rc.r,rc.g,rc.b}
    assert(p.health.statusBarColor[1]==O.health[1] and t.health.statusBarColor[1]==O.health[1],'Onyx #1C1E21 health by default')
    assert(p.nameText.color[1]==M.ACCENT[1] and t.nameText.color[2]==M.ACCENT[2] and p.nameText:GetText()=='Fixture','plain Sky names')
    assert(t.nameText.text.label=='name','secret target name passed straight to SetText')
    -- The suite's text style: every text has an opaque one-pixel shadow and a lifted
    -- shadow (one translucent black copy 2px down-right).
    local px=p.geometry.px
    for _,text in ipairs({p.nameText,p.levelText,p.healthText}) do
        local lift,la,lb=text.lift,Point(text.lift,1),Point(text.lift,2)
        assert(text.shadowColor[4]==1 and text.shadowOffset[1]==px and text.shadowOffset[2]==-px,'opaque one-pixel shadow')
        assert(lift:IsShown() and lift:GetText()==text:GetText() and lift.color[1]==0 and lift.color[3]==0 and Near(lift.color[4],M.LIFT_ALPHA),'translucent black copy')
        assert(la[1]=='TOPLEFT' and la[2]==text and la[4]==2*px and la[5]==-2*px,'2px down-right in screen pixels')
        assert(lb[1]=='BOTTOMRIGHT' and lb[2]==text and lb[4]==2*px and lb[5]==-2*px,'covers the text box')
        assert(lift.shadowColor[4]==0 and lift.font[2]==text.font[2] and lift.font[3]=='')
    end
    assert(p.nameText.lift.justifyH=='RIGHT' and not p.powerText.lift:IsShown(),'no power text by default, so no lift')
    assert(t.nameText.lift.text.label=='name' and t.healthText.lift.text.secret.label=='pct','secret values go straight to the lifts')
    -- Class gradient ring: light top, pastel class color, deeper bottom.
    local function RingTop(f) return f.portrait.ring.gradient[3] end
    local function RingBottom(f) return f.portrait.ring.gradient[2] end
    local soft=Soft(rogue)
    assert(p.portrait.ring.gradient[1]=='VERTICAL' and Near(RingTop(p).r,Soft(soft,0.35)[1]) and Near(RingBottom(p).r,soft[1]*0.72))
    assert(Near(RingTop(t).g,Soft(Soft(P.hostile),0.35)[2]),'NPC ring uses the pastel reaction color')
    assert(p.portrait.icon.texture=='portrait:player' and p.portrait.icon.texCoord[1]==0)
    assert(p.levelText:GetText()=='60' and p.healthText:GetText()=='90%')

    -- Colors: health Default/Class/Custom, name Accent/Class/Custom, ring Class/Default/Custom.
    assert(M:SetFrameOption('player','healthColorMode','class') and Near(p.health.statusBarColor[1],soft[1]),'pastel class health')
    assert(Near(t.health.statusBarColor[1],Soft(P.hostile)[1]),'matched target: NPC reaction color, pastel')
    assert(M:SetFrameOption('player','healthColorMode','custom') and M:SetFrameOption('player','healthColor',{0,0,1}) and p.health.statusBarColor[3]==1)
    assert(M:SetFrameOption('player','healthColorMode','default') and p.health.statusBarColor[1]==O.health[1])
    -- Foreground and background opacity and textures, per frame; a matched Target follows the Player.
    assert(p.health.statusBarColor[4]==1 and p.power.statusBarColor[4]==1,'opaque fill by default')
    assert(M:SetFrameOption('player','barForegroundOpacity',50) and p.health.statusBarColor[4]==0.5 and p.power.statusBarColor[4]==0.5)
    assert(t.health.statusBarColor[4]==0.5,'matched target follows')
    assert(M:SetFrameOption('player','barBackgroundOpacity',0) and p.health.bg.vertexColor[4]==0 and t.health.bg.vertexColor[4]==0)
    assert(not M:SetFrameOption('player','barForegroundOpacity',5) and not M:SetFrameOption('player','barBackgroundOpacity',101),'ranges')
    assert(M:SetFrameOption('player','foregroundTexture','flat') and p.health.statusBarTexture==addon.Kit.FLAT and not p.health.sheen:IsShown())
    assert(not M:SetFrameOption('player','backgroundTexture','mode') and not M:SetFrameOption('player','foregroundTexture','bogus'),'texture choices validated')
    assert(M:SetFrameOption('player','foregroundTexture','mode') and p.health.sheen:IsShown())
    assert(M:SetFrameOption('player','barForegroundOpacity',100) and M:SetFrameOption('player','barBackgroundOpacity',25))
    assert(M:SetFrameOption('player','showPower',false) and not p.panel.hairline:IsShown() and M:SetFrameOption('player','showPower',true))
    assert(not M:SetFrameOption('player','healthColorMode','palette') and not M:SetFrameOption('player','healthColorMode','reaction'),'only Default, Class Color or Custom')
    assert(M:SetFrameOption('player','nameColorMode','class') and Near(p.nameText.color[1],soft[1]))
    assert(M:SetFrameOption('player','nameColorMode','custom') and M:SetFrameOption('player','nameColor',{1,0,0}) and p.nameText.color[1]==1 and p.nameText.color[2]==0)
    local L,F=M.nameAccents.lilac,M.nameAccents.frost
    assert(M:SetFrameOption('player','nameColorMode','lilac') and p.nameText.color[1]==L[1] and p.nameText.color[3]==L[3] and t.nameText.color[2]==L[2],'Lilac')
    assert(M:SetFrameOption('player','nameColorMode','frost') and p.nameText.color[1]==F[1] and p.nameText.color[2]==F[2],'Frost')
    assert(p.nameText.lift.color[1]==0 and Near(p.nameText.lift.color[4],M.LIFT_ALPHA),'the lift stays black whatever the name color')
    local C=M.nameAccents.champagne
    assert(M:SetFrameOption('player','nameColorMode','champagne') and p.nameText.color[1]==C[1] and p.nameText.color[3]==C[3],'Champagne')
    assert(M:SetFrameOption('player','nameColorMode','sky') and p.nameText.color[1]==M.ACCENT[1] and p.nameText.color[2]==M.ACCENT[2],'Sky')
    assert(not M:SetFrameOption('player','nameColorMode','accent') and not M:SetFrameOption('player','nameColorMode','mist'),'Mist is retired')
    assert(not M:SetFrameOption('player','nameGlow',true) and not M:SetFrameOption('player','nameGlowStrength',50),'glow settings are retired')
    assert(not M:SetFrameOption('player','nameLift',true),'the name-only lift is retired')
    assert(M:SetFrameOption('player','liftedShadow',false) and not p.nameText.lift:IsShown() and not p.healthText.lift:IsShown(),'one toggle for every text')
    assert(p.nameText:IsShown() and p.nameText.shadowColor[4]==1 and p.healthText.shadowColor[4]==1,'lift off keeps the crisp shadow')
    assert(M:SetFrameOption('player','liftedShadow',true) and p.nameText.lift:IsShown() and p.levelText.lift:IsShown())
    assert(M:SetFrameOption('player','shadow',false) and not p.nameText.lift:IsShown() and not p.healthText.lift:IsShown(),'the lift needs Text Shadow')
    assert(p.healthText.shadowColor[4]==0 and p.healthText.shadowOffset[1]==0)
    assert(M:SetFrameOption('player','shadow',true) and M:SetFrameOption('player','showName',false) and not p.nameText.lift:IsShown())
    assert(M:SetFrameOption('player','showName',true) and p.nameText.lift:IsShown() and p.nameText.lift:GetText()=='Fixture')
    assert(M:SetFrameOption('player','outline',true) and p.nameText.lift.font[3]=='OUTLINE' and p.levelText.lift.font[3]=='OUTLINE','lift matches the outlined glyphs')
    assert(M:SetFrameOption('player','outline',false))
    assert(M:SetFrameOption('player','powerText','percent') and p.powerText.lift:IsShown() and p.powerText.lift:GetText()=='50%','power text lifts too')
    assert(M:SetFrameOption('player','powerText','none') and not p.powerText.lift:IsShown())
    assert(M:SetFrameOption('player','portraitRing','border') and RingTop(p).r==O.border[1] and RingBottom(p).r==O.border[1],'Default matches the frame rim')
    assert(M:SetFrameOption('player','portraitRing','custom') and M:SetFrameOption('player','portraitRingColor',{1,0,1}) and RingTop(p).g==0 and RingBottom(p).r==1)
    assert(not M:SetFrameOption('player','portraitRing','accent'))
    assert(M:SetFrameOption('player','portraitRing','class'))
    assert(M:SetFrameOption('player','classSoftness',0) and Near(RingTop(p).r,Soft(rogue,0.35)[1]) and Near(RingBottom(p).r,rogue[1]*0.72),'0% softness: original class color')
    assert(not M:SetFrameOption('player','classSoftness',120))
    assert(M:SetFrameOption('player','classSoftness',40))
    -- Locked skin: retired settings are not options.
    for _,key in ipairs({'palette','borderStyle','backgroundOpacity','backgroundColor','rimThickness','nameSheen','portraitSize'}) do
        assert(not M:SetFrameOption('player',key,M.db.player.scale),'locked: '..key)
    end

    -- Pixel perfect: at 1440p (factor 768/1440) every size is whole, even pixels.
    PixelUtil={GetPixelToUIUnitFactor=function() return 768/1440 end}
    FireEvent('UI_SCALE_CHANGED')
    local q=p.geometry;local px=768/1440
    local function Whole(v) return math.abs(v/px-math.floor(v/px+0.5))<1e-6 end
    local function Even(v) return Whole(v) and math.floor(v/px+0.5)%2==0 end
    assert(math.abs(q.px-px)<1e-9 and math.abs(q.border-2*px)<1e-9 and math.abs(q.line-2*px)<1e-9 and math.abs(q.gap-px)<1e-9,'2px rim, 2px gap, 1px hairline in screen pixels')
    for _,v in ipairs({q.healthHeight,q.powerHeight,q.inset,q.blockStart,q.portrait}) do assert(Whole(v),'whole pixels') end
    assert(Even(q.width) and Even(q.height),'even pixel frame keeps the centre anchor on the grid')
    assert(Whole(q.blockY) and Whole(q.tuck) and Even(q.blockHeight) and Even(q.portrait))
    assert(math.abs(p.width-q.width)<1e-9 and Point(p.health)[5]==-q.barsTop)
    assert(M:SetFrameOption('player','scale',120))
    local r=p.geometry
    local function EvenAt(v,u) local n=v/u;return math.abs(n-math.floor(n+0.5))<1e-6 and math.floor(n+0.5)%2==0 end
    assert(math.abs(r.px-px/1.2)<1e-9 and EvenAt(r.width,r.px) and EvenAt(r.height,r.px),'re-snapped at the new frame scale')
    assert(M:SetFrameOption('player','scale',100))
    PixelUtil=nil;M:Refresh()
    assert(p.geometry.px==1)

    -- Layout options.
    assert(M:SetFrameOption('player','showPortrait',false) and p.geometry.inset==4 and Point(p.panel)[4]==0 and not p.portrait:IsShown())
    assert(M:SetFrameOption('player','showPortrait',true))
    assert(M:SetFrameOption('player','showPower',false) and not p.power:IsShown() and p.geometry.blockHeight==26+8 and p.geometry.portrait==52)
    assert(M:SetFrameOption('player','showPower',true))
    assert(M:SetFrameOption('player','portraitScale',200) and p.geometry.portrait==92 and p.geometry.blockY==23)
    assert(M:SetFrameOption('player','portraitScale',100) and p.geometry.portrait==p.geometry.blockHeight and p.geometry.blockY==0)
    assert(M:SetFrameOption('player','portraitScale',150) and p.geometry.portrait==70)
    assert(M:SetFrameOption('player','namePosition','bar') and Point(p.nameText)[2]==p.health and Point(p.nameText)[1]=='RIGHT')
    assert(not M:SetFrameOption('player','namePosition','panel'),'the old name row is retired')
    assert(M:SetFrameOption('player','namePosition','above'))
    assert(M:SetFrameOption('player','levelStyle','none') and not p.levelText:IsShown())
    assert(not M:SetFrameOption('player','levelStyle','text'))
    assert(M:SetFrameOption('player','levelStyle','badge'))
    assert(M:SetFrameOption('player','healthTextPosition','LEFT') and Point(p.levelText)[1]=='LEFT' and Point(p.levelText)[4]==4+8,'left group clears the curve')
    assert(Point(p.healthText)[2]==p.levelText and Point(p.healthText)[4]==6,'level read before the health text')
    assert(Point(t.levelText)[1]=='LEFT' and Point(t.levelText)[2]==t.health and Point(t.levelText)[4]==4,'matched target copies the left group')
    -- Mirror Player Text: the exact mirror image, read health first toward the portrait side.
    assert(M:SetFrameOption('target','mirrorText',true) and M:FrameDB('target').mirrored==true and M:FrameDB('target').healthTextPosition=='RIGHT')
    assert(Point(t.levelText)[1]=='RIGHT' and Point(t.levelText)[2]==t.health and Point(t.levelText)[4]==-4-8,'level at the edge, clear of the curve')
    assert(Point(t.healthText)[1]=='RIGHT' and Point(t.healthText)[2]==t.levelText and Point(t.healthText)[4]==-6,'health text inside it')
    assert(t.nameText.justifyH=='LEFT','mirrored name alignment')
    assert(M:SetFrameOption('target','mirrorText',false) and M:FrameDB('target').mirrored==false and t.nameText.justifyH=='RIGHT')
    assert(M:SetFrameOption('player','healthText','none') and Point(p.levelText)[1]=='RIGHT' and Point(p.levelText)[2]==p.health,'level alone at the right')
    assert(M:SetFrameOption('player','healthText','percent') and M:SetFrameOption('player','healthTextPosition','RIGHT'))
    assert(M:SetFrameOption('player','healthTextOffsetX',5) and M:SetFrameOption('player','healthTextOffsetY',-2))
    assert(Point(p.healthText)[4]==-4+5 and Point(p.healthText)[5]==-2,'health text offset')
    assert(M:FrameDB('target').healthTextOffsetX==5 and Point(t.healthText)[4]==-4+5-8,'matched target copies offsets')
    assert(M:SetFrameOption('target','mirrorText',true) and M:FrameDB('target').healthTextOffsetX==-5,'mirrored offsets')
    assert(Point(t.healthText)[1]=='LEFT' and Point(t.healthText)[2]==t.health and Point(t.healthText)[4]==4-5)
    assert(Point(t.levelText)[1]=='LEFT' and Point(t.levelText)[2]==t.healthText and Point(t.levelText)[4]==6,'level after the health text')
    -- The owner's layout: level moved 45 to the left of right-aligned health text.
    assert(M:SetFrameOption('player','healthTextOffsetX',1) and M:SetFrameOption('player','levelOffsetX',-45))
    assert(Point(p.levelText)[4]==-6-45 and Point(t.healthText)[4]==4-1 and Point(t.levelText)[4]==6+45,'mirror keeps the level clear of the health text')
    assert(M:SetFrameOption('target','mirrorText',false) and Point(t.healthText)[1]=='RIGHT' and Point(t.levelText)[4]==-6-45,'same layout as the Player')
    assert(M:SetFrameOption('player','levelOffsetX',0) and M:SetFrameOption('player','healthTextOffsetX',5))
    assert(M:SetFrameOption('player','nameOffsetX',3) and M:SetFrameOption('player','nameOffsetY',4) and Point(p.nameText)[5]==4+3+4 and Point(p.nameText)[4]==12+3)
    assert(M:SetFrameOption('player','levelOffsetX',-2) and Point(p.levelText)[4]==-6-2)
    for _,key in ipairs({'healthTextOffsetX','healthTextOffsetY','nameOffsetX','nameOffsetY','levelOffsetX'}) do assert(M:SetFrameOption('player',key,0)) end
    assert(M:SetFrameOption('player','levelColor',{1,0,0}) and M:SetFrameOption('player','levelFontSize',14))
    assert(p.levelText.color[1]==1 and p.levelText.font[2]==14 and p.healthText.font[2]==11,'level color and size are its own')
    assert(M:SetFrameOption('player','levelColor',P.muted) and M:SetFrameOption('player','levelFontSize',11))

    -- The Target matches the Player (mirrored) until Match Player Frame is turned off.
    assert(M:SetFrameOption('player','barWidth',200) and t.width==p.width and t.geometry.inset==p.geometry.inset)
    assert(Point(t.portrait)[1]=='TOPRIGHT' and Point(t.health)[1]=='TOPRIGHT','still mirrored')
    assert(M:SetFrameOption('player','showPower',false) and not t.power:IsShown(),'power bar follows the Player')
    assert(M:SetFrameOption('player','showPower',true) and t.power:IsShown())
    assert(M:SetFrameOption('target','barWidth',300) and t.width==p.width,'own style ignored while matched')
    assert(M:FrameDB('target').portraitSide=='right' and M:FrameDB('target').barWidth==200)
    assert(M:SetFrameOption('target','matchPlayer',false) and t.width==60+300+4,'own settings once unmatched')
    assert(M:FrameDB('target')==M.db.target and t.nameText.justifyH=='RIGHT')
    assert(M:SetFrameOption('player','barWidth',180) and M:SetFrameOption('target','barWidth',180))

    -- Public player values and portrait.
    M:UpdateAll()
    assert(p.health.value==900 and p.health.high==1000 and p.power.value==50)
    assert(p.healthText:GetText()=='90%' and p.nameText:GetText()=='Fixture' and p.levelText:GetText()=='60')
    assert(M:SetFrameOption('target','healthColorMode','class'))

    -- Secret target values pass straight to widgets and formatters.
    assert(issecretvalue(t.health.value) and t.health.high.label=='max' and t.power.value.label=='p')
    assert(t.healthText.text.secret.label=='pct' and t.nameText.text.label=='name')
    assert(t.levelText:GetText()=='??+')
    assert(Near(t.health.statusBarColor[1],Soft(P.hostile)[1]),'NPC reaction color, pastel')
    assert(t.portrait.icon.texture=='portrait:target')

    -- Per-frame customization stays independent.
    assert(M:SetFrameOption('player','portraitStyle','class') and p.portrait.icon.atlas=='classicon-rogue')
    assert(t.portrait.icon.texture=='portrait:target','target keeps its style')
    assert(M:SetFrameOption('target','portraitStyle','class') and t.portrait.icon.texture=='portrait:target','NPC falls back to portrait')
    assert(M:SetFrameOption('player','portraitSide','right') and Point(p.portrait)[1]=='TOPRIGHT')
    assert(M:SetFrameOption('player','portraitSide','left'))
    assert(M:SetFrameOption('player','powerText','percent') and p.powerText:IsShown() and p.powerText:GetText()=='50%')
    assert(M:SetFrameOption('target','powerText','both') and t.powerText.text.formatted=='%s · %.0f%%')
    assert(M:SetFrameOption('player','powerColorMode','custom') and M:SetFrameOption('player','powerColor',{1,0,1}))
    assert(p.power.statusBarColor[1]==1 and p.power.statusBarColor[2]==0)
    assert(M:SetFrameOption('player','healthText','both') and p.healthText:GetText()=='900 · 90%')
    local abbreviate=AbbreviateNumbers;AbbreviateNumbers=function() error('unsupported') end
    M:UpdateHealth('player');assert(p.healthText:GetText()=='90%','fallback to percent');AbbreviateNumbers=abbreviate
    units.player.dead=true;M:UpdateHealth('player');assert(p.healthText:GetText()=='Dead');units.player.dead=false
    assert(M:SetFrameOption('player','healthTextPosition','CENTER') and Point(p.healthText)[1]=='CENTER')
    assert(p.health.sheen:IsShown() and p.health.sheen.gradient and p.power.sheen:IsShown(),'Mode Gradient on every bar')
    assert(not M:SetFrameOption('player','texture','flat'),'the bar texture is no longer a setting')
    assert(M:SetFrameOption('player','scale',120) and p.scale==1.2)
    assert(M:SetFrameOption('player','barWidth',240) and p.width==60+240+4)

    -- Validation refuses bad values without changing settings.
    assert(not M:SetFrameOption('player','barWidth',50) and M.db.player.barWidth==240)
    assert(not M:SetFrameOption('player','namePosition','bogus') and M.db.player.namePosition=='above')
    assert(not M:SetFrameOption('player','portraitRingColor',{2,0,0}))
    assert(not M:SetFrameOption('player','width',200),'retired keys are not options')
    testCombat=true;assert(not M:SetFrameOption('player','barWidth',200));testCombat=false

    -- Copy Style mirrors the look but keeps identity; Reset restores defaults.
    assert(M:CopyStyle('player','target'))
    assert(M.db.target.barWidth==240 and M.db.target.portraitSide=='right' and M.db.target.enabled)
    assert(Point(t.portrait)[1]=='TOPRIGHT')
    assert(M:ResetFrame('target') and M.db.target.barWidth==180 and M.db.target.healthColorMode=='default' and M.db.target.portraitSide=='right')
    assert(M.db.target.matchPlayer==false,'reset keeps the identity toggle')
    assert(M.db.player.barWidth==240,'reset is per frame')

    -- Edit Mode: stand-ins in the same skin; the secure button copies the anchor.
    local ghost=M.ghosts.player
    assert(not ghost.secure and not ghost:IsShown())
    assert(addon:SetEditMode(true) and ghost:IsShown() and M.ghosts.target:IsShown())
    assert(ghost.nameText:GetText()=='Player Frame' and ghost.nameText.color[1]==M.ACCENT[1])
    assert(ghost.nameText.lift:GetText()=='Player Frame' and ghost.nameText.lift:IsShown() and ghost.levelText.lift:GetText()=='60','stand-in text has the lift too')
    assert(ghost.width==p.width and Near(RingTop(ghost).r,Soft(soft,0.35)[1]),'stand-in matches size and class ring')
    assert(Near(RingTop(M.ghosts.target).r,Soft(Soft(P.hostile),0.35)[1]),'target stand-in shows an enemy ring')
    assert(addon.PositionManager:SetOffsets('unitFramesPlayer',-300,-150))
    local point,gp=Point(p),Point(ghost)
    assert(point[1]==gp[1] and point[3]==gp[3] and point[4]==gp[4] and point[5]==gp[5] and p.scale==ghost.scale,'secure button copies the stand-in anchor at the same scale')
    assert(addon:SetEditMode(false) and not ghost:IsShown())

    -- Hiding a frame or disabling in combat waits, then restores natives.
    assert(M:SetFrameOption('target','enabled',false))
    assert(not watched[t] and not t:IsShown() and TargetFrame.TargetFrameContainer:GetAlpha()==1 and TargetFrame.mouse==true)
    assert(TargetFrame.TargetFrameContent:GetAlpha()==0.9,'original native alpha restored')
    assert(TargetFrameToT:GetAlpha()==0,'the ModeUI Target of Target still replaces Blizzard\'s')
    assert(M:SetFrameOption('targettarget','enabled',false) and TargetFrameToT:GetAlpha()==1 and TargetFrameToT.mouse==true and TargetFrameToTDebuff2.mouse==true,'Target of Target and its debuffs restored')
    assert(M:SetFrameOption('target','enabled',true) and watched[t])
    assert(TargetFrameToT:GetAlpha()==0 and M:SetFrameOption('target','hideBlizzard',false) and TargetFrameToT:GetAlpha()==1)
    assert(M:SetFrameOption('target','hideBlizzard',true) and TargetFrameToT:GetAlpha()==0,'Hide Blizzard Target Frame covers its Target of Target')
    assert(M:SetFrameOption('targettarget','enabled',true) and M:SetFrameOption('targettarget','hideBlizzard',false) and TargetFrameToT:GetAlpha()==0,'still covered by the Target')
    assert(M:SetFrameOption('targettarget','hideBlizzard',true))
    testLockdown=true;testCombat=true
    addon:SetModuleEnabled('unitFrames',false)
    assert(M.pending and watched[p],'disable deferred in combat')
    testLockdown=false;testCombat=false
    FireEvent('PLAYER_REGEN_ENABLED')
    assert(not watched[p] and not watched[t] and PlayerFrame.mouse==true and PlayerFrame.PlayerFrameContainer:GetAlpha()==1)
    assert(FocusFrame.TargetFrameContainer:GetAlpha()==1 and FocusFrame.mouse==true and FocusFrameToT:GetAlpha()==1 and TargetFrameToT:GetAlpha()==1)
    assert(not watched[M.frames.focus] and not M.poller:IsShown(),'every frame and the timer stop')

    -- Phase-1 migration: changed values carry over once, everything else adopts Onyx.
    local v1={layoutVersion=nil,scale=100,texture='default',classColor=true,fontSize=14,outline=false,shadow=true,
        healthColor={52/255,168/255,83/255},backgroundColor={0.5,0.5,0.5},backgroundOpacity=85,borderColor={66/255,66/255,66/255},
        borderOpacity=100,textColor={1,1,1},font='game',fontMedia='',
        player={enabled=true,hideBlizzard=false,width=260,height=36,powerHeight=8,showPower=true,showName=true,showLevel=false,healthText='both'},
        target={enabled=false,hideBlizzard=true,width=220,height=36,powerHeight=8,showPower=true,showName=true,showLevel=true,healthText='percent'}}
    M.Initialize(v1)
    assert(v1.layoutVersion==12 and v1.player.barWidth==260 and v1.player.hideBlizzard==false and v1.player.levelStyle=='none')
    assert(v1.player.healthText=='both' and v1.player.nameFontSize==14 and v1.player.healthColorMode=='default')
    assert(v1.player.fontMedia=='Expressway' and v1.player.texture==nil and v1.player.backgroundColor==nil,'phase-1 background is not carried into the locked skin')
    assert(v1.target.enabled==false and v1.target.barWidth==180)
    local custom={player={width=220,height=36,powerHeight=8,showPower=true},target={width=220,height=36},classColor=false,healthColor={0,1,0}}
    M.Initialize(custom);assert(custom.player.healthColorMode=='custom' and custom.player.healthColor[2]==1)
    local again=addon.ProfileCodec.Copy(v1);M.Initialize(again);assert(again.player.barWidth==260,'migration is idempotent')
    -- Layouts 2-7 keep their effects on the keys that remain.
    local v5={layoutVersion=5,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v5.player.healthHeight=22;v5.player.nameAlign='CENTER';v5.player.fontMedia='PTG Lato';v5.player.levelFontSize=nil;v5.player.healthFontSize=13
    v5.player.borderStyle='satin';v5.player.palette='slate'
    M.Initialize(v5)
    assert(v5.layoutVersion==12 and v5.player.healthHeight==26 and v5.player.nameAlign=='RIGHT' and v5.player.fontMedia=='Expressway')
    assert(v5.player.levelFontSize==13 and v5.player.borderStyle==nil and v5.player.palette==nil)
    local v7={layoutVersion=7,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v7.player.nameAlign='LEFT';v7.player.fontMedia='PTG Lato';M.Initialize(v7)
    assert(v7.player.nameAlign=='LEFT' and v7.player.fontMedia=='PTG Lato','later choices are not migrated')
    -- Layout 8 -> 9: the locked Onyx skin.
    local v8={layoutVersion=8,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v8.player.healthColorMode='palette';v8.player.nameColorMode='class';v8.player.portraitRing='accent';v8.player.namePosition='panel'
    v8.player.levelStyle='text';v8.player.levelColor={1,1,0};v8.player.palette='custom';v8.player.paletteBorder={0,1,1}
    v8.player.nameSheen=true;v8.player.nameSheenStrength=55;v8.player.rimThickness=3;v8.player.backgroundOpacity=0;v8.player.borderStyle='minimal'
    v8.target.healthColorMode='reaction';v8.target.portraitRing='custom';v8.target.portraitRingColor={0,0,1};v8.target.nameColorMode='text'
    local v8b=addon.ProfileCodec.Copy(v8);v8b.target.healthColorMode='custom';v8b.target.healthColor={0.2,0.3,0.4};v8b.player.healthColorMode='mode'
    M.Initialize(v8);M.Initialize(v8b)
    assert(v8.layoutVersion==12 and v8.player.healthColorMode=='default' and v8.target.healthColorMode=='class')
    assert(v8b.target.healthColorMode=='custom' and v8b.target.healthColor[3]==0.4 and v8b.player.healthColorMode=='default')
    assert(v8.player.nameColorMode=='sky' and v8.target.nameColorMode=='sky','names adopt the default color')
    assert(v8.player.portraitRing=='class' and v8.target.portraitRing=='custom' and v8.target.portraitRingColor[3]==1,'class gradient ring unless custom')
    assert(v8.player.namePosition=='above' and v8.player.levelStyle=='badge' and v8.player.levelColor[2]==1,'explicit level color kept')
    for _,key in ipairs(M.retiredKeys) do assert(v8.player[key]==nil and v8.target[key]==nil,'retired key removed: '..key) end
    -- Layout 9 -> 10: Mist and its glow give way to Champagne and the lifted shadow.
    local v9={layoutVersion=9,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v9.player.nameColorMode='accent';v9.player.nameGlow=true;v9.player.nameGlowStrength=80;v9.player.nameLift=nil
    v9.target.nameColorMode='custom';v9.target.nameColor={0,1,0};v9.target.nameGlow=false
    M.Initialize(v9)
    assert(v9.layoutVersion==12 and v9.player.nameColorMode=='sky' and v9.player.liftedShadow==true and v9.player.nameLift==nil)
    assert(v9.player.nameGlow==nil and v9.player.nameGlowStrength==nil and v9.target.nameGlow==nil,'glow keys removed')
    assert(v9.target.nameColorMode=='custom' and v9.target.nameColor[2]==1,'custom name color kept')
    -- Layout 10 -> 11: Sky replaces the presets to try; the name lift becomes Lifted Shadow for all text.
    local v10={layoutVersion=10,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v10.player.nameColorMode='lilac';v10.player.nameLift=false;v10.player.liftedShadow=nil;v10.player.mirrorText=nil
    v10.target.nameColorMode='class';v10.target.nameLift=true;v10.target.mirrorText=nil
    M.Initialize(v10)
    assert(v10.layoutVersion==12 and v10.player.nameColorMode=='sky' and v10.target.nameColorMode=='class','presets move to Sky; Class Color kept')
    assert(v10.player.liftedShadow==false and v10.target.liftedShadow==true and v10.player.nameLift==nil and v10.target.nameLift==nil,'lift choice carried over')
    assert(v10.target.mirrorText==false,'matched Target now copies the Player text layout')
    local v11={layoutVersion=11,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v11.player.texture='flat';v11.target.texture='media:Smooth';M.Initialize(v11)
    assert(v11.layoutVersion==12 and v11.player.texture==nil and v11.target.texture==nil,'retired Bar Texture removed')
    local kept={layoutVersion=12,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    kept.player.nameColorMode='class';kept.player.portraitRing='border';M.Initialize(kept)
    assert(kept.player.nameColorMode=='class' and kept.player.portraitRing=='border','later choices are not migrated')
    local bad=addon.ProfileCodec.Copy(M.db);bad.target.healthColorMode='x';assert(not pcall(M.Initialize,bad))
]====]
, "unit_frames")

world.run([[addon:SetModuleEnabled("unitFrames",true); assert(addon.UnitFrames:SetFrameOption("target","barWidth",300))]])
local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([====[
    local M=addon.UnitFrames
    assert(M.enabled and M.db.target.barWidth==300 and M.db.player.barWidth==240,'settings persist')
    assert(M.frames.player and M.frames.target.width==60+300+4,'frames built at login (unmatched target keeps its width)')
    assert(addon.PositionManager.elements.unitFramesTarget,'stand-in registered at login despite nil GetCenter before anchoring')
]====]
, "unit_frames_restore")
restored.run([====[
    local M=addon.UnitFrames
    addon:SetModuleEnabled('unitFrames',true)
    assert(M:ResetFrame('player') and M:SetFrameOption('target','matchPlayer',true))
    if not addon.EnsureConfigPage then addon:ToggleConfig() end
    local page=addon:EnsureConfigPage('unitFrames')
    local titles={};for _,section in ipairs(page.sections) do titles[#titles+1]=section.title end
    assert(table.concat(titles,'|')=='Frames|Layout|Portrait|Name & Level|Health|Power|Text','one tab per frame element; no Border tab')
    assert(page.sectionTabs and #page.sectionTabs.buttons==7)
    local function Find(section,title)
        for _,row in ipairs(page.rows) do if row.section and row.section.title==section and row.settingsTitle==title then return row end end
    end
    local function Row(section,title) return Find(section,title) or error('missing row '..section..' / '..title) end
    local function Visible(row) return not row.visibleWhen or row.visibleWhen() end
    for section,list in pairs({Layout={'Scale','Bar Width'},Portrait={'Portrait Style','Portrait Size','Portrait Ring'},
        ['Name & Level']={'Name Color','Name Offset X','Class Color Softness','Level Font Size','Level Color','Level Offset Y'},
        Health={'Health Bar Height','Health Color','Health Text Offset X'},Power={'Power Bar Height','Power Text'},Text={'Font','Text Color'}}) do
        for _,title in ipairs(list) do assert(Visible(Row(section,title)),'Player editable: '..section..' / '..title) end
        assert(Visible(Row(section,'Editing')),'every element tab has the Editing switch')
    end
    -- Bar textures and opacity sit in Layout cards, two to a row.
    assert(page.unitFrameForeground and page.unitFrameBackground and page.unitFrameForegroundOpacity and page.unitFrameBackgroundOpacity)
    assert(page.unitFrameForeground:GetParent().rowLabel:GetText()=='Foreground' and page.unitFrameBackgroundOpacity:GetParent().rowLabel:GetText()=='Background Opacity')
    for _,title in ipairs({'Border Style','Palette','Background Color','Rim Color','Rim Thickness','Name Sheen Strength','Empty Bar Color'}) do
        for _,section in ipairs(page.sections) do assert(not Find(section.title,title),'locked to Onyx: '..title) end
    end
    assert(not Visible(Row('Health','Custom Health Color')) and M:SetFrameOption('player','healthColorMode','custom') and Visible(Row('Health','Custom Health Color')))
    assert(not Visible(Row('Name & Level','Custom Name Color')) and M:SetFrameOption('player','nameColorMode','custom') and Visible(Row('Name & Level','Custom Name Color')))
    assert(not Visible(Row('Portrait','Portrait Ring Color')) and M:SetFrameOption('player','portraitRing','custom') and Visible(Row('Portrait','Portrait Ring Color')))
    assert(not Find('Name & Level','Glow Strength') and not Find('Name & Level','Name Glow'),'glow controls are gone')
    assert(M:ResetFrame('player'))
    -- Frames tab: Show and Hide Blizzard side by side for each of the five frames, and their tools.
    assert(page.unitFrameResetTargetTarget and page.unitFrameCopyFocus and page.unitFrameCopyPlayer and Row('Frames','Target of Focus Tools'))
    assert(page.unitFrameCopyPlayer.label:GetText()=='Copy Style to Target' and page.unitFrameCopyFocus.label:GetText()=='Copy Player Style')
    assert(M:SetFrameOption('player','barWidth',200));page.unitFrameCopyFocus.scripts.OnClick()
    assert(M.db.focus.barWidth==200 and M.db.focus.portraitSide=='right','copies the Player look, keeps its side')
    page.unitFrameResetFocus.scripts.OnClick();assert(M.db.focus.barWidth==150 and M:ResetFrame('player'))
    -- Editing picks one of the five frames, shared by every tab.
    assert(#page.unitFrameEditSelects==6)
    page.SetEditing('focus');assert(page.unitFrameEditing()=='focus' and page.unitFrameEditSelects[3].label:GetText()=='Focus')
    assert(Visible(Row('Layout','Scale')) and not Visible(Row('Layout','Target Matches Player')),'only the Target matches the Player')
    assert(M:SetFrameOption('focus','barBackgroundOpacity',50) and M.db.player.barBackgroundOpacity==25,'edits the Focus only')
    assert(M:ResetFrame('focus'))
    page.SetEditing('target');assert(page.unitFrameEditing()=='target' and page.unitFrameEditSelects[2].label:GetText()=='Target','switch to the Target')
    assert(page.unitFrameEditSelects[5].label:GetText()=='Target','one choice across tabs')
    assert(not Visible(Row('Layout','Scale')) and Visible(Row('Layout','Target Matches Player')),'matched Target explains itself')
    assert(M:SetFrameOption('target','matchPlayer',false) and Visible(Row('Layout','Scale')))
    assert(M:SetFrameOption('target','barWidth',220) and M.db.player.barWidth==180)
    assert(M:ResetFrame('target') and M:SetFrameOption('target','matchPlayer',true))
    page.SetEditing('player');assert(page.unitFrameEditing()=='player' and Visible(Row('Layout','Scale')))
    assert(M:SetFrameOption('player','enabled',false) and Visible(Row('Layout','Frame Hidden')) and not Visible(Row('Layout','Scale')))
    assert(M:SetFrameOption('player','enabled',true))
]====]
, "unit_frames_page")
print("unit frames: all checks passed")
