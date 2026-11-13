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
    assert(M.db.layoutVersion==18 and M.db.player.portraitSide=='left' and M.db.target.portraitSide=='right')
    assert(M.db.player.fontMedia=='Expressway' and M.db.player.texture==nil,'one bar texture: Mode Gradient')
    assert(M.db.target.matchPlayer==true and M.db.player.matchPlayer==false)
    assert(M.db.player.healthColorMode=='default' and M.db.player.nameColorMode=='sky' and M.db.player.portraitRing=='class')
    local PS=M.db.player.texts
    assert(PS.border.content=='name' and PS.border.align=='RIGHT' and PS.border.size==12 and M.db.player.classSoftness==40)
    for _,key in ipairs(M.retiredKeys) do assert(M.frameDefaults.player[key]==nil and M.db.player[key]==nil,'retired: '..key) end
    -- The locked Onyx skin and the Sky, Champagne, Lilac and Frost name colors.
    local function Hex(c) return string.format('%02X%02X%02X',math.floor(c[1]*255+0.5),math.floor(c[2]*255+0.5),math.floor(c[3]*255+0.5)) end
    assert(Hex(O.health)=='1C1E21' and Hex(O.track)=='0A0B0C' and Hex(O.border)=='25282C' and Hex(O.inner)=='000000')
    assert(Hex(M.ACCENT)=='91C6FF' and Hex(M.nameAccents.sky)=='91C6FF' and Hex(M.nameAccents.champagne)=='F2DFB8' and Hex(M.nameAccents.lilac)=='C9BBFF' and Hex(M.nameAccents.frost)=='EAF1F8')
    local ids={};for _,c in ipairs(M.choices.nameColor) do ids[#ids+1]=c.id end
    assert(table.concat(ids,',')=='sky,champagne,lilac,frost,class,custom')
    assert(M.db.player.liftedShadow==true and M.db.target.mirrorText==true and M.identityKeys.mirrorText and M.db.player.nameLift==nil)
    -- Text slots: the name on the border, the level bottom left, health percent at the right.
    assert(PS.bottomLeft.content=='level' and PS.right.content=='healthPercent' and PS.right.size==11 and PS.powerCenter.content=='none')
    for _,slot in ipairs(M.textSlots) do if slot~='border' and slot~='bottomLeft' and slot~='right' then assert(PS[slot].content=='none',slot) end end
    assert(#M.textSlots==13 and M.slotPlaces.topLeft.v=='TOP' and M.slotMirror.bottomLeft=='bottomRight')
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

    -- Combo points ring the Target portrait (Rogue fixture): five sockets, each its
    -- own StatusBar over (i-1, i), so a secret count fills them without comparisons.
    local cb=t.combo;assert(cb and cb:IsShown() and cb.count==5 and not cb.points[6]:IsShown() and p.combo==nil)
    assert(ComboFrame:GetAlpha()==0,'Blizzard combo points fade')
    for i=1,5 do local lo,hi=cb.points[i].bar.low,cb.points[i].bar.high;assert(lo==i-1 and hi==i and cb.points[i].bar.value==0) end
    comboPoints=3;FireEvent('UNIT_POWER_FREQUENT','player');assert(cb.points[3].bar.value==3 and cb.points[5].bar.value==3)
    comboPoints=Secret('cp');FireEvent('COMBO_TARGET_CHANGED');assert(cb.points[1].bar.value.label=='cp','secret count straight to SetValue')
    comboPoints=0;FireEvent('PLAYER_TARGET_CHANGED')
    -- Pixel perfect on an arc around the portrait's centre, on its outer side (right).
    local c1,c5=Point(cb.points[1]),Point(cb.points[5])
    assert(c1[1]=='CENTER' and c1[2]==t.portrait and c1[4]>0 and c5[5]>c1[5],'from the lower outer end upward')
    for i=1,5 do local q=Point(cb.points[i]);assert(q[4]==math.floor(q[4]) and q[5]==math.floor(q[5]) and cb.points[i].width%2==0) end
    local r=32+3+5;assert(math.abs(math.sqrt(c1[4]^2+c1[5]^2)-r)<1,'radius: portrait, distance, half a point')
    assert(cb.points[1].rim.vertexColor[1]==M.RIM_COLOR[1] and Point(cb.points[1].bar)[4]==2)
    assert(M:SetComboOption('arc','top') and math.abs(Point(cb.points[3])[4])<1 and Point(cb.points[3])[5]>0,'centred over the top')
    assert(M:SetComboOption('size',14) and cb.points[1].width==14 and M:SetComboOption('size',10) and M:SetComboOption('arc','topOuter'))
    assert(not M:SetComboOption('arc','sideways') and not M:SetComboOption('size',40),'validated')
    assert(M:SetComboOption('hideBlizzard',false) and ComboFrame:GetAlpha()==1 and M:SetComboOption('hideBlizzard',true) and ComboFrame:GetAlpha()==0)
    assert(M:SetComboOption('enabled',false) and not cb:IsShown() and ComboFrame:GetAlpha()==1,'off: Blizzard\'s come back')
    assert(M:SetComboOption('enabled',true) and cb:IsShown())
    -- Matching the Player never borrows combo settings; a Target without a portrait lines them up under the bars.
    assert(M:SetFrameOption('player','showPortrait',false) and Point(cb.points[1])[1]=='TOPLEFT' and Point(cb.points[1])[2]==t.power)
    assert(M:SetFrameOption('player','showPortrait',true) and Point(cb.points[1])[2]==t.portrait)

    -- Status on the portrait: rested top left and combat bottom left on the ring
    -- (32px out at 135° and 225°, snapped), mirrored to the outer side on the Target.
    local sp,st=M.db.player.status,M.db.target.status
    assert(sp.restIcon and sp.combatIcon and sp.combatRing and sp.pulse and st.combatIcon and not st.restIcon and not st.pulse and not M.db.focus.status.combatIcon)
    resting=true;FireEvent('PLAYER_UPDATE_RESTING')
    assert(p.restBadge:IsShown() and not p.combatBadge:IsShown() and not t.restBadge:IsShown(),'rested: Player only')
    local rb=Point(p.restBadge);assert(rb[1]=='CENTER' and rb[2]==p.portrait and rb[4]==-23 and rb[5]==23 and p.restBadge.width==20,'top left, on the ring')
    assert(p.restBadge.icon.vertexColor[1]==M.ACCENT[1] and p.restBadge.rim.vertexColor[1]==M.RIM_COLOR[1])
    -- Pulled while running: in combat, nothing targeted that is fighting you. Red ring, pulsing halo.
    combat.player=true;FireEvent('PLAYER_REGEN_DISABLED')
    local cb2=Point(p.combatBadge);assert(p.combatBadge:IsShown() and cb2[4]==-23 and cb2[5]==-23,'bottom left')
    local red=M.db.player.status.ringColor
    assert(p.redRing and math.abs(p.portrait.ring.gradient[3].r-(red[1]+(1-red[1])*0.35))<1e-9,'the ring turns red')
    assert(p.portrait.halo:IsShown(),'pulled unawares: the ring pulses')
    -- You target it and it fights you: the pulse stops; the ring holds red.
    combat.target,attackable.target=true,true;FireEvent('UNIT_FLAGS','target')
    assert(not p.portrait.halo:IsShown() and p.redRing,'targeted: steady red')
    assert(t.combatBadge:IsShown() and Point(t.combatBadge)[4]==23 and Point(t.combatBadge)[5]==-23 and not t.redRing,'Target: its own badge, outer side; no red ring by default')
    combat.target=false;FireEvent('UNIT_FLAGS','target');assert(p.portrait.halo:IsShown(),'a target that is not fighting you does not count')
    combat.player,combat.target,attackable.target,resting=false,false,false,false;FireEvent('PLAYER_REGEN_ENABLED')
    assert(not p.combatBadge:IsShown() and not p.restBadge:IsShown() and not p.redRing and not p.portrait.halo:IsShown() and not t.combatBadge:IsShown())
    -- Settings: corners, size, mirror; validated.
    resting=true;FireEvent('PLAYER_UPDATE_RESTING')
    assert(M:SetStatusOption('player','restCorner','topRight') and Point(p.restBadge)[4]==23 and Point(p.restBadge)[5]==23)
    assert(M:SetStatusOption('player','badgeSize',25) and p.restBadge.width==26,'even pixel sizes')
    assert(not M:SetStatusOption('player','restCorner','middle') and not M:SetStatusOption('player','badgeSize',60))
    assert(M:SetStatusOption('player','restIcon',false) and not p.restBadge:IsShown())
    assert(M:SetStatusOption('player','restIcon',true) and M:SetStatusOption('player','restCorner','topLeft') and M:SetStatusOption('player','badgeSize',20))
    resting=false;FireEvent('PLAYER_UPDATE_RESTING')
    assert(M:FrameDB('target').status==M.db.target.status,'a matched Target keeps its own status settings')

    -- The default slots (owner): the Player's level in the health bar's bottom left,
    -- clear of the portrait (12px across its line), 1px up; health percent at the right.
    -- A matched Target mirrors them: health on the left, level bottom right.
    local PT,TT=p.texts,t.texts
    local lv=Point(PT.bottomLeft);assert(lv[1]=='BOTTOMLEFT' and lv[2]==p.health and lv[3]=='BOTTOMLEFT' and lv[4]==12 and lv[5]==1 and PT.bottomLeft.justifyH=='LEFT')
    local hv=Point(PT.right);assert(hv[1]=='RIGHT' and hv[2]==p.health and hv[4]==-4 and PT.right:IsShown(),'health percent at the right')
    assert(not PT.center:IsShown() and not PT.powerCenter:IsShown() and PT.center:GetText()=='','empty slots hide')
    local tlv=Point(TT.bottomRight);assert(tlv[1]=='BOTTOMRIGHT' and tlv[2]==t.health and tlv[4]==-12 and tlv[5]==1,'Target: level bottom right, clear of its portrait')
    assert(Point(TT.left)[1]=='LEFT' and Point(TT.left)[2]==t.health and Point(TT.left)[4]==4 and TT.left:IsShown() and not TT.right:IsShown(),'Target: health on the left')
    assert(M:SetTextOption('player','bottomLeft','x',-6) and Point(PT.bottomLeft)[4]==12,'never into the portrait')
    assert(Point(TT.bottomRight)[4]==-12 and M:SetTextOption('player','bottomLeft','x',5) and Point(PT.bottomLeft)[4]==17 and Point(TT.bottomRight)[4]==-17,'mirrored offsets')
    assert(M:SetTextOption('player','bottomLeft','x',0))
    -- Changing the width moves nothing out of place: every text keeps its anchor on the health bar.
    assert(M:SetFrameOption('player','barWidth',240) and p.width==54+240+2)
    assert(Point(PT.right)[2]==p.health and Point(PT.right)[4]==-4 and Point(PT.bottomLeft)[2]==p.health and Point(PT.bottomLeft)[4]==12,'texts stay on their sides')
    assert(Point(PT.border)[2]==p.health and Point(PT.border,2)[2]==p.health,'the name spans the wider bar')
    assert(M:SetFrameOption('player','barWidth',180))

    -- Cast bars: a block in the frame's own skin under the bar block, its far end
    -- lined up with the block's; the portrait end stops 2px short of the ring's
    -- circle (radius 32, crossing the box's top 24px under the centre: 21.2 + 2, rounded out).
    local pc,tex=p.castBox,function(key) return (addon.Media:GetTexture(key)) end
    assert(pc and not pc:IsShown() and PlayerCastingBarFrame:GetAlpha()==0 and TargetFrameSpellBar:GetAlpha()==0 and FocusFrameSpellBar:GetAlpha()==0)
    local cp1,cp2=Point(pc),Point(pc,2)
    assert(cp1[1]=='TOPLEFT' and cp1[2]==p.panel and cp1[3]=='BOTTOMLEFT' and cp1[4]==24 and cp1[5]==-3 and cp2[1]=='TOPRIGHT' and cp2[3]=='BOTTOMRIGHT' and cp2[4]==0)
    assert(pc.clear==24,'clear of the portrait')
    assert(pc.height==14+4 and pc.depth==5 and pc.rim.ends.LEFT.cap:IsShown() and pc.rim.ends.RIGHT.cap:IsShown(),'rounded at both ends (a quarter of 18px, rounded)')
    assert(pc.gap.texture==addon.Kit.FLAT and Point(pc.gap)[4]==2 and pc.gap.capMasks[pc.gapMasks.LEFT] and pc.bar.fillTexture.capMasks[pc.barMasks.RIGHT],'black inside and the bar, rounded to match')
    local cb1,cb2=Point(pc.bar),Point(pc.bar,2)
    assert(cb1[1]=='TOPLEFT' and cb1[4]==2 and cb1[5]==-2,'bar one rim in from the box')
    assert(cb2[1]=='BOTTOMRIGHT' and cb2[4]==-(5+14+1) and cb2[5]==2,'the icon sits where the far end rounds, a hairline apart')
    local ic=Point(pc.icon);assert(ic[1]=='RIGHT' and ic[4]==-5 and pc.icon.width==14 and pc.icon.height==14)
    assert(pc:GetFrameLevel()<p.portrait:GetFrameLevel(),'the portrait ring caps it')
    units.player.cast={name='Frostbolt',text='Frostbolt',icon=135846,start=1000,stop=3000}
    FireEvent('UNIT_SPELLCAST_START','player')
    assert(pc:IsShown() and pc.bar.low==1000 and pc.bar.high==3000 and pc.text:GetText()=='Frostbolt' and pc.icon.texture==135846)
    assert(pc.bar.fillTexture.vertexColor[1]==M.castDefaults.color[1] and pc.bar.reverseFill==false and pc.bar.value==GetTime()*1000)
    units.player.cast=nil;FireEvent('UNIT_SPELLCAST_STOP','player');assert(not pc:IsShown())
    -- A channel drains; secret values go straight to the widgets.
    units.target.channel={name=Secret('c'),text=Secret('ctext'),icon=Secret('i'),start=Secret('s'),stop=Secret('e'),locked=Secret('l')}
    FireEvent('UNIT_SPELLCAST_CHANNEL_START','target');local tcb=t.castBox
    assert(tcb:IsShown() and tcb.bar.reverseFill==true and tcb.text.text.label=='ctext' and tcb.bar.low.label=='s')
    units.target.channel=nil;FireEvent('UNIT_SPELLCAST_CHANNEL_STOP','target');assert(not tcb:IsShown())
    assert(Point(tcb.bar)[1]=='TOPRIGHT' and Point(tcb.bar)[4]==-2 and Point(tcb)[4]==-24 and Point(tcb.icon)[1]=='LEFT','mirrored on the Target')
    -- Settings: position, icon side, Blizzard's bar; validated; per frame even while matched.
    assert(M:SetCastOption('player','position','above') and Point(pc)[1]=='BOTTOMLEFT' and Point(pc)[3]=='TOPLEFT' and Point(pc)[5]==3)
    assert(M:SetCastOption('player','icon','near') and Point(pc.icon)[1]=='LEFT' and Point(pc.icon)[4]==5 and Point(pc.bar)[4]==5+14+1)
    assert(M:SetCastOption('player','icon','none') and not pc.icon:IsShown() and Point(pc.bar,2)[4]==-2)
    assert(M:SetCastOption('player','gap',40) and Point(pc)[4]==0,'far enough down, it can start under the portrait centre')
    assert(M:SetCastOption('player','gap',3) and M:SetFrameOption('player','showPortrait',false) and Point(pc)[4]==0 and Point(pc.bar)[4]==2)
    assert(M:SetFrameOption('player','showPortrait',true))
    assert(M:SetCastOption('player','hideBlizzard',false) and PlayerCastingBarFrame:GetAlpha()==1)
    assert(not M:SetCastOption('player','height',99) and not M:SetCastOption('player','icon','top') and not M:SetCastOption('player','bogus',1))
    assert(M:FrameDB('target').castBar==M.db.target.castBar and M.db.target.matchPlayer,'a matched Target keeps its own cast bar')
    assert(M:ResetFrame('player') and M.db.player.castBar.position=='below' and PlayerCastingBarFrame:GetAlpha()==0,'reset restores it')
    assert(M:SetCastOption('target','enabled',false) and TargetFrameSpellBar:GetAlpha()==1 and M:SetCastOption('target','enabled',true))
    assert(M.db.targettarget.castBar.enabled==false and M.db.focus.castBar.enabled==true)

    -- Auras: buffs on the Target by default, debuffs off; each group its own settings.
    assert(M.db.target.buffs.enabled and not M.db.target.debuffs.enabled and not M.db.player.buffs.enabled and not M.db.focus.buffs.enabled)
    units.target.helpful={{icon=136078,auraInstanceID=1,applications=3,duration=10,expirationTime=20},{icon=136090,auraInstanceID=2}}
    units.target.harmful={{icon=136207,auraInstanceID=3,dispelName='Magic'}}
    FireEvent('UNIT_AURA','target')
    local b1,b2=t.auraIcons.buffs[1],t.auraIcons.buffs[2]
    assert(b1:IsShown() and b2:IsShown() and t.auraShown.buffs==2 and t.auraShown.debuffs==0 and auraFilters[#auraFilters]=='HELPFUL')
    assert(b1.icon.texture==136078 and b1.count:GetText()=='3' and b1.cooldown.cooldownStart==10 and b1.rim.vertexColor[1]==O.border[1])
    -- Hover shows the game's tooltip for that aura; a secret ID (combat) shows none.
    function GameTooltip:SetOwner(owner) self.owner=owner end
    function GameTooltip:GetOwner() return self.owner end
    function GameTooltip:SetUnitBuffByAuraInstanceID(unit,id) if issecretvalue(id) then error('secret id') end self.aura={unit,id,'buff'} end
    function GameTooltip:SetUnitDebuffByAuraInstanceID(unit,id) self.aura={unit,id,'debuff'} end
    assert(b1.scripts.OnEnter and b1.mouse,'icons take the mouse')
    b1.scripts.OnEnter(b1);assert(GameTooltip:IsShown() and GameTooltip.owner==b1 and GameTooltip.aura[1]=='target' and GameTooltip.aura[2]==1 and GameTooltip.aura[3]=='buff')
    b1.scripts.OnLeave(b1);assert(not GameTooltip:IsShown())
    b1.auraID=Secret('id');b1.scripts.OnEnter(b1);assert(not GameTooltip:IsShown(),'no empty tooltip for a hidden aura');b1.auraID=1
    -- Top right: the first icon's right edge on the health bar's right edge (clear of
    -- the portrait), cropped icons growing left. The mirrored Target's name is on its
    -- left, so the row sits right on the bar block.
    assert(Point(b1)[1]=='BOTTOMRIGHT' and Point(b1)[2]==t.health and Point(b1)[3]=='TOPRIGHT' and Point(b1)[4]==0 and Point(b1)[5]==2+2,'right on the bar block')
    -- With the name on the right too, the row sits over the name instead of on it.
    assert(M:SetTextOption('player','border','align','LEFT'))
    local q=Point(b1);assert(q[5]==(2-1-3)+14+2,'over the name on the border')
    assert(b1.width==20 and b1.height==16 and Point(b2)[4]==-(20+2) and Point(b2)[5]==q[5],'cropped, growing left')
    assert(M:SetAuraOption('target','buffs','perRow',1) and Point(b2)[4]==0 and Point(b2)[5]==q[5]+16+2,'a new row above')
    assert(M:SetAuraOption('target','buffs','shape','square') and b1.height==20 and M:SetAuraOption('target','buffs','perRow',8))
    assert(M:SetAuraOption('target','buffs','filter','mine') and auraFilters[#auraFilters]=='HELPFUL|PLAYER')
    assert(M:SetAuraOption('target','buffs','max',1) and not b2:IsShown() and M:ResetFrame('target') and b2:IsShown(),'reset restores the auras')
    assert(M:SetTextOption('player','border','align','RIGHT'))
    -- Debuffs: under the bars, past the cast bar below them; rims by dispel type.
    assert(M:SetAuraOption('target','debuffs','enabled',true));local d1=t.auraIcons.debuffs[1]
    assert(d1:IsShown() and d1.rim.vertexColor[3]==M.dispelColors.Magic[3])
    local dq=Point(d1);assert(dq[1]=='TOPRIGHT' and dq[2]==t.power and dq[5]==-(2+2+3+14+4),'below the cast bar')
    assert(M:SetCastOption('target','position','above') and Point(d1)[5]==-(2+2) and M:SetCastOption('target','position','below'))
    assert(M:SetAuraOption('target','debuffs','border','mode') and d1.rim.vertexColor[1]==O.border[1])
    assert(not M:SetAuraOption('target','debuffs','anchor','MIDDLE') and not M:SetAuraOption('target','debuffs','size',99) and not M:SetAuraOption('target','nope','size',20))
    assert(M:FrameDB('target').buffs==M.db.target.buffs,'a matched Target keeps its own auras')
    assert(M:SetAuraOption('target','debuffs','enabled',false) and not d1:IsShown())
    units.target.helpful,units.target.harmful=nil,nil;FireEvent('UNIT_AURA','target');assert(not b1:IsShown())

    -- Target of Target, Focus and Target of Focus: secure frames of their own,
    -- each replacing Blizzard's; Blizzard's Focus frame fades like the Target.
    local tt,fo,ft=M.frames.targettarget,M.frames.focus,M.frames.focustarget
    assert(tt.secure and fo.secure and ft.secure and watched[tt] and watched[fo] and watched[ft])
    assert(ModeUITargetTargetUnitFrame==tt and ModeUIFocusUnitFrame==fo and ModeUIFocusTargetUnitFrame==ft and ModeUIFocusUnitFramePreview==M.ghosts.focus)
    assert(tt.attributes.unit=='targettarget' and fo.attributes.unit=='focus' and ft.attributes.unit=='focustarget')
    assert(FocusFrame.TargetFrameContainer:GetAlpha()==0 and FocusFrame.TargetFrameContent:GetAlpha()==0 and FocusFrame.mouse==false)
    assert(FocusFrameToT:GetAlpha()==0 and FocusFrameToTDebuff3.mouse==false,'Blizzard Target of Focus fades too')
    -- Target of Target: small, no portrait or level, 75%, name in the bar on the left.
    -- Focus is the same frame at 90%; Target of Focus matches the Target of Target.
    local d=M.db.targettarget
    assert(d.barWidth==110 and d.texts.bottomLeft.content=='none' and d.scale==75 and d.showPortrait==false and d.texts.left.content=='name' and d.texts.border.content=='none')
    assert(d.texts.left.size==11 and d.texts.right.content=='healthPercent' and d.texts.right.size==10)
    assert(M.db.focustarget.scale==75 and M.db.focustarget.attach and M.db.focustarget.showPortrait==false)
    assert(M.db.focus.scale==90 and M.db.focus.barWidth==110 and M.db.focus.showPortrait==false and M.db.focus.texts.left.content=='name' and not M.db.focus.attach)
    assert(not M.db.focus.matchPlayer and not d.matchPlayer)
    assert(tt.scale==0.75 and fo.scale==0.9 and not tt.portrait:IsShown() and not tt.texts.bottomLeft:IsShown(),'small frames')
    assert(tt.panel.rim.ends.LEFT.cap:IsShown() and tt.panel.rim.ends.RIGHT.cap:IsShown() and Point(tt.panel.nearMask)[1]=='TOPLEFT','no portrait: rounded at both ends')
    local tn=Point(tt.texts.left);assert(tn[1]=='LEFT' and tn[2]==tt.health and tn[4]==4 and tt.texts.left.justifyH=='LEFT' and tt.texts.left.width==110*0.6,'name in the bar, on the left')
    -- Attached under the Target frame's bottom-right corner, button to button and
    -- stand-in to stand-in; attached frames leave the Position Manager.
    local ta=Point(tt);assert(ta[1]=='TOPRIGHT' and ta[2]==t and ta[3]=='BOTTOMRIGHT' and ta[4]==0 and ta[5]==-2,'attached under the Target')
    local ga=Point(M.ghosts.targettarget);assert(ga[2]==M.ghosts.target and ga[1]=='TOPRIGHT')
    assert(Point(ft)[2]==fo,'Target of Focus attaches to the Focus')
    local PM=addon.PositionManager
    assert(not PM.elements.unitFramesTargetTarget and not PM.elements.unitFramesFocusTarget and PM.elements.unitFramesFocus)
    assert(M:SetFrameOption('targettarget','attachPoint','bottomleft') and Point(tt)[1]=='TOPLEFT' and Point(tt)[3]=='BOTTOMLEFT')
    assert(M:SetFrameOption('targettarget','attachOffsetX',3) and Point(tt)[4]==3 and M:ResetFrame('targettarget'),'pixel offsets')
    assert(M.db.targettarget.attachPoint=='bottomleft' and M.db.targettarget.attachOffsetX==3,'reset keeps placement')
    assert(M:SetFrameOption('targettarget','attachPoint','bottomright') and M:SetFrameOption('targettarget','attachOffsetX',0))
    -- Detached (or while the Target frame is off) it is placed and moved like any frame.
    assert(M:SetFrameOption('targettarget','attach',false) and PM.elements.unitFramesTargetTarget and Point(tt)[2]~=t)
    assert(M:SetFrameOption('targettarget','attach',true) and not PM.elements.unitFramesTargetTarget and Point(tt)[2]==t)
    assert(M:SetFrameOption('target','enabled',false) and PM.elements.unitFramesTargetTarget,'free while the Target is off')
    assert(M:SetFrameOption('target','enabled',true) and Point(tt)[2]==t)
    -- The game sends no unit events for targettarget/focustarget: a short timer refreshes them.
    assert(M.poller:IsShown());Advance(0.2)
    units.targettarget={exists=true,health=300,max=600,power=10,powerMax=100,token='RAGE',name='Totfix',level=12,reaction=2,connected=true}
    Advance(0.05);assert(tt.texts.left:GetText()~='Totfix','waits for the timer')
    Advance(0.06);assert(tt.texts.left:GetText()=='Totfix' and tt.texts.right:GetText()=='50%','refreshed on the timer')
    units.focus={exists=true,health=50,max=100,power=20,powerMax=100,token='MANA',name='Focusfix',level=30,reaction=5,connected=true}
    FireEvent('PLAYER_FOCUS_CHANGED');assert(fo.texts.left:GetText()=='Focusfix' and fo.texts.right:GetText()=='50%')
    units.focus.health=25;FireEvent('UNIT_HEALTH','focus');assert(fo.texts.right:GetText()=='25%','focus unit events')
    units.targettarget.name='Swapped';FireEvent('UNIT_TARGET','target');assert(tt.texts.left:GetText()=='Swapped','new target of target at once')
    assert(M:SetFrameOption('targettarget','enabled',false) and M.poller:IsShown(),'the Target of Focus still needs the timer')
    assert(M:SetFrameOption('focustarget','enabled',false) and not M.poller:IsShown(),'no timer without them')
    assert(M:SetFrameOption('targettarget','enabled',true) and M:SetFrameOption('focustarget','enabled',true) and M.poller:IsShown())
    units.targettarget,units.focus=nil,nil

    -- Onyx frame: round portrait cap over one rounded bar block, 2px rim + 2px gap, 1px hairline.
    local tex=function(key) return (addon.Media:GetTexture(key)) end
    local mg=p.geometry
    -- px=1: block = 26 health + 1 + 10 power + 2*2 rim = 41 -> odd, so health grows 1
    -- (block 42); the portrait is 1.5x the block (64), the bars about 2/3 of it, centred 11 down.
    -- One border (owner, November 13, 2026): a 2px rim, no gap, so the bars sit 2px in.
    assert(mg.px==1 and mg.border==2 and mg.line==0 and mg.gap==1 and mg.pad==2)
    assert(mg.healthHeight==27 and mg.blockHeight==42 and mg.portrait==64 and mg.height==64 and mg.blockY==11 and mg.portraitY==0)
    assert(mg.blockStart==32 and mg.inset==54 and mg.width==236 and mg.tuck==8 and mg.barsTop==13)
    assert(p.width==236 and p.height==64)
    local pp=Point(p.panel);assert(pp[1]=='TOPLEFT' and pp[4]==32 and pp[5]==-11,'bar block starts under the portrait centre')
    local pb=Point(p.panel,2);assert(pb[1]=='BOTTOMRIGHT' and pb[5]==11)
    -- Straight edges are hard flat strips on whole pixels; the far end is rounded,
    -- 11px deep (a quarter of the 42px block, rounded): a straight end with round corners,
    -- a cap hollowed into a ring by a hole mask. One border: the lighter frame rim color,
    -- on its own layer above the bars and below the portrait; no black gap ring.
    local tex=function(key) return (addon.Media:GetTexture(key)) end
    local rim,gap=p.panel.rim,p.panel.gap
    assert(p.panel.depth==11 and rim.top:GetParent()==p.panel.edge and rim.top.texture==addon.Kit.FLAT and rim.top.height==2 and rim.top.vertexColor[1]==M.RIM_COLOR[1])
    assert(Point(rim.top)[4]==0 and Point(rim.top)[5]==0 and Point(rim.top,2)[4]==-11,'top strip from the near edge to where the far end rounds')
    local rc=rim.ends.RIGHT;assert(rc.cap:IsShown() and not rc.strip:IsShown() and rc.cap.texture==tex('ModeCapRight') and rc.cap.width==11 and rc.cap.vertexColor[1]==M.RIM_COLOR[1])
    assert(rc.cap.mask==rc.hole and rc.hole.texture==tex('ModeCapHoleRight') and Point(rc.hole)[4]==-2 and Point(rc.hole)[5]==-2 and rc.hole.width==9,'hollowed 2px in: a ring')
    assert(rim.ends.LEFT.strip:IsShown() and not rim.ends.LEFT.cap:IsShown() and rim.ends.LEFT.strip.width==2,'the portrait end stays straight under the portrait')
    assert(not gap.top:IsShown() and not gap.ends.RIGHT.cap:IsShown() and not gap.ends.LEFT.strip:IsShown(),'no black gap ring')
    assert(p.panel.edge:GetFrameLevel()>p.health:GetFrameLevel() and p.panel.edge:GetFrameLevel()<p.portrait:GetFrameLevel(),'rim over the bars, under the portrait')
    -- The bars are rounded to the same end, reaching 1px under the rim so their edge
    -- hides under it (no soft seam); the near mask is parked off the block.
    local fm=p.panel.farMask;assert(fm.texture==tex('ModeCapRight') and Point(fm)[4]==-1 and Point(fm)[5]==-1 and fm.width==10)
    assert(Point(p.panel.nearMask)[1]=='TOPRIGHT' and Point(p.panel.nearMask)[3]=='TOPLEFT','near mask parked past the near end')
    assert(p.health.fillTexture.capMasks[fm] and p.health.bg.capMasks[fm] and p.power.fillTexture.capMasks[p.panel.nearMask])
    assert(t.panel.rim.ends.LEFT.cap:IsShown() and t.panel.rim.ends.LEFT.cap.texture==tex('ModeCapLeft') and not t.panel.rim.ends.RIGHT.cap:IsShown(),'target: rounded on the left')
    local cap=p.panel.cap;assert(cap:IsShown() and Point(cap)[1]=='TOPLEFT' and Point(cap)[4]==2 and cap.width==22-2 and cap.vertexColor[1]==M.RIM_COLOR[1],'rim color under the portrait up to the bars: one border')
    for _,bar in ipairs({p.health,p.power}) do
        assert(bar.bg.vertexColor[1]==O.slate[1] and bar.bg.vertexColor[3]==O.slate[3] and bar.bg.texture==addon.Kit.FLAT and bar.statusBarTexture==addon.Kit.FLAT and bar.sheen:IsShown(),'Mode Gradient bars')
        assert(bar.fillTexture.drawLayer=='ARTWORK','fill drawn above the track')
    end
    -- See-through background: nothing opaque under the bars (rim, gap and cap
    -- surround them), with a solid hairline between health and power.
    local d=M.db.player
    assert(d.barForegroundOpacity==100 and d.barBackgroundOpacity==70 and d.foregroundTexture=='mode' and d.backgroundTexture=='slate','Mode Slate at 70%')
    for _,bar in ipairs({p.health,p.power}) do assert(math.abs(bar.bg.vertexColor[4]-0.7)<1e-9,'70% background') end
    assert(M:SetFrameOption('player','backgroundTexture','slateHatch') and p.health.bg.texture==addon.Media:GetTexture('ModeSlateHatch') and p.health.bg.vertexColor[1]==O.slateHatch[1])
    local hc=p.health.bg.texCoord;assert(hc[2]==(236-54-2)/4 and hc[4]==27/4,'the hatch tiles one texel per pixel')
    assert(M:SetFrameOption('player','backgroundTexture','flat') and p.health.bg.vertexColor[1]==O.track[1] and p.health.bg.texCoord[2]==1)
    assert(M:SetFrameOption('player','backgroundTexture','slate') and not M:SetFrameOption('player','foregroundTexture','slate'))
    assert(Point(t.panel.cap)[1]=='TOPRIGHT' and Point(t.panel.cap)[4]==-2,'target: the cap is on the right')
    -- The end of the health fill gets a 1px light line, on the side it fills toward.
    local fe=p.health.fillEdge;assert(fe and fe:IsShown() and fe.width==1 and Point(fe)[1]=='TOPRIGHT' and Point(fe)[2]==p.health.fillTexture)
    assert(Point(t.health.fillEdge)[1]=='TOPLEFT','reverse fill: on the left')
    -- A full bar shows no line: it lives in a clip frame that stops 1px short of the bar's end.
    local clip=p.health.fillEdgeClip;assert(clip.clipsChildren and fe:GetParent()==clip and Point(clip,2)[1]=='BOTTOMRIGHT' and Point(clip,2)[4]==-1)
    assert(Point(t.health.fillEdgeClip)[4]==1 and Point(t.health.fillEdgeClip,2)[4]==0,'reverse: 1px short on the left')
    assert(M:SetFrameOption('player','fillEdge',false) and not fe:IsShown() and M:SetFrameOption('player','fillEdge',true) and fe:IsShown())
    local hl=p.panel.hairline;assert(hl:IsShown() and hl.vertexColor[1]==O.inner[1] and hl.vertexColor[4]==1 and Point(hl)[2]==p.health and Point(hl,2)[2]==p.power,'solid hairline')
    local mhp=Point(p.health);assert(mhp[1]=='TOPLEFT' and mhp[4]==54 and mhp[5]==-13 and p.health.height==27)
    local mht=Point(t.health);assert(mht[1]=='TOPRIGHT' and mht[4]==-54,'target mirrored: portrait on the right')
    -- Fill direction: the Target fills and drains the other way from the Player, even while matched.
    assert(M.db.player.fillDirection=='standard' and M.db.target.fillDirection=='reverse' and M.identityKeys.fillDirection)
    assert(p.health.reverseFill==false and p.power.reverseFill==false and t.health.reverseFill==true and t.power.reverseFill==true)
    assert(M:SetFrameOption('player','fillDirection','reverse') and p.health.reverseFill==true and t.health.reverseFill==true,'own setting, not copied from the Player')
    assert(M:SetFrameOption('target','fillDirection','standard') and t.health.reverseFill==false and not M:SetFrameOption('target','fillDirection','up'))
    assert(M:SetFrameOption('player','fillDirection','standard') and M:SetFrameOption('target','fillDirection','reverse'))
    assert(Point(p.power)[5]==-1 and p.power.height==10,'1px hairline between health and power')
    local cap=Point(p.portrait);assert(cap[1]=='TOPLEFT' and cap[4]==0 and cap[5]==0 and p.portrait.width==64)
    assert(Point(t.portrait)[1]=='TOPRIGHT')
    local ring=p.portrait
    -- Full ring: the portrait frame sits above the bars, so its whole circle is drawn over the bar's end.
    assert(ring:GetFrameLevel()>p.health:GetFrameLevel() and ring:GetFrameLevel()>p.panel:GetFrameLevel(),'full ring over the bar end')
    assert(ring.ring.texture==tex('UnitFrameCircle') and ring.ring:IsShown())
    assert(Point(ring.innerEdge)[4]==2 and ring.innerEdge.vertexColor[1]==O.inner[1],'black gap inside the ring')
    assert(Point(ring.back)[4]==2 and ring.back.vertexColor[1]==O.track[1],'one ring: the image backing sits right inside it')
    assert(Point(ring.icon)[4]==2 and ring.icon.mask.texture=='Interface\\CHARACTERFRAME\\TempPortraitAlphaMask','circular portrait')
    assert(p.nameClip==nil and p.nameShine==nil and p.panel.ringBorder==nil,'plain name, single ring')
    assert(p.textLayer:GetFrameLevel()>ring:GetFrameLevel(),'text above the portrait')
    -- On the Border (default): the baseline on the top rim's middle (bottom = 2 - 1 - 3
    -- descent = -2), clear of the ring at its height (32 + 27.1 + 2 - 54, rounded out = 8).
    local np=Point(p.texts.border);assert(np[1]=='BOTTOMLEFT' and np[2]==p.health and np[4]==8 and np[5]==-2 and p.texts.border.justifyH=='RIGHT','name sitting on the border')
    assert(p.texts.border.font[1]:find('Lato') and p.texts.right.font[1]:find('Lato'),'Expressway falls back to ModeUI Lato when not installed')
    assert(t.texts.border.justifyH=='LEFT','the mirrored Target has its name on the left')
    -- Mirror Player Text off: the Player's slots as they are, each clear of the Target's own portrait.
    assert(M:SetFrameOption('target','mirrorText',false) and t.texts.border.justifyH=='RIGHT' and not t.texts.left:IsShown())
    local th=Point(t.texts.right);assert(th[1]=='RIGHT' and th[2]==t.health and th[4]==-4-8,'health on the right, like the Player, clear of the curve')
    local tl=Point(t.texts.bottomLeft);assert(tl[1]=='BOTTOMLEFT' and tl[4]==4 and tl[5]==1,'level bottom left, away from the portrait')
    -- The name clears the ring at its own height: on the border, 17px above the ring's
    -- centre at its nearest, the ring reaches 27.1px out, so 8px in from the bars.
    assert(Point(t.texts.border,2)[4]==-8 and Point(p.texts.border,2)[4]==0,'name clear of the portrait at its own height')
    assert(M:SetFrameOption('target','mirrorText',true) and Point(t.texts.border)[4]==0 and Point(t.texts.border,2)[4]==-8)
    assert(p.texts.bottomLeft.color[1]==P.muted[1],'the level muted by default')
    -- Bar text never reaches the portrait: 2px before the ring's outer edge across
    -- its own line (at the bars' middle: 35 + 35 + 2 - 60 = 12 from the bars' edge),
    -- and an X offset toward the portrait stops there.
    assert(M:SetTextOption('player','left','content','healthCurrent') and Point(p.texts.left)[4]==12,'a left text at the clearance')
    assert(M:SetTextOption('player','left','x',-9) and Point(p.texts.left)[4]==12,'an offset into the ring stops at the line')
    assert(M:SetTextOption('player','left','x',5) and Point(p.texts.left)[4]==17,'away from the portrait it moves freely')
    assert(M:SetTextOption('player','left','x',0) and M:SetTextOption('player','left','content','none'))
    -- Top slots sit 1px under the bar's top, also clear of the ring across their line.
    assert(M:SetTextOption('player','topLeft','content','name'))
    local tp=Point(p.texts.topLeft);assert(tp[1]=='TOPLEFT' and tp[2]==p.health and tp[5]==-1 and tp[4]>=12,'top left, under the bar top')
    -- Each text shows once per frame: picking it for a spot clears its old spot.
    assert(M.db.player.texts.border.content=='none' and not p.texts.border:IsShown() and p.texts.topLeft:GetText()=='Fixture','moved, not copied')
    assert(M:SetTextOption('player','border','content','name') and M.db.player.texts.topLeft.content=='none' and not p.texts.topLeft:IsShown())
    assert(M.db.player.texts.right.content=='healthPercent' and M:SetTextOption('player','left','content','level') and M.db.player.texts.bottomLeft.content=='none')
    assert(M:SetTextOption('player','bottomLeft','content','level') and M.db.player.texts.left.content=='none','other texts stay put')
    assert(M:SetTextOptions('player','right',{colorMode='custom',color={0,1,0}}) and p.texts.right.color[2]==1 and M:SetTextOption('player','right','colorMode','default'),'several settings in one change')
    assert(M:SetTextOption('player','powerLeft','content','powerPercent'))
    -- The power line's nearest edge is 8px under the ring's centre, where the ring
    -- still reaches 31px out: 32 + 31 + 2 - 54, rounded out, is 11.
    assert(Point(p.texts.powerLeft)[1]=='LEFT' and Point(p.texts.powerLeft)[2]==p.power and Point(p.texts.powerLeft)[4]==11,'the power text measured across its own line')
    assert(M:SetTextOption('player','powerLeft','y',-12) and Point(p.texts.powerLeft)[4]<11,'lower, where the ring has curved away, it can sit closer')
    assert(M:SetTextOption('player','powerLeft','y',0) and M:SetTextOption('player','powerLeft','content','none'))
    assert(not M:SetTextOption('player','powerLeft','content','mana') and not M:SetTextOption('player','middle','size',10) and not M:SetTextOption('player','left','size',40),'validated')
    assert(not M:SetTextOption('player','left','align','LEFT'),'only the border text has an alignment')

    M:UpdateAll()
    local function Soft(c,amount) amount=amount or 0.4;return {c[1]+(1-c[1])*amount,c[2]+(1-c[2])*amount,c[3]+(1-c[3])*amount} end
    local function Near(a,b) return math.abs(a-b)<1e-9 end
    local rc=addon.ClassColors:GetColor('ROGUE');local rogue={rc.r,rc.g,rc.b}
    assert(p.health.statusBarColor[1]==O.health[1] and t.health.statusBarColor[1]==O.health[1],'Onyx #1C1E21 health by default')
    assert(p.texts.border.color[1]==M.ACCENT[1] and t.texts.border.color[2]==M.ACCENT[2] and p.texts.border:GetText()=='Fixture','plain Sky names')
    assert(t.texts.border.text.label=='name','secret target name passed straight to SetText')
    -- The suite's text style: every text has an opaque one-pixel shadow and a lifted
    -- shadow (one translucent black copy 2px down-right).
    local px=p.geometry.px
    for _,text in ipairs({p.texts.border,p.texts.bottomLeft,p.texts.right}) do
        local lift,la,lb=text.lift,Point(text.lift,1),Point(text.lift,2)
        assert(text.shadowColor[4]==1 and text.shadowOffset[1]==px and text.shadowOffset[2]==-px,'opaque one-pixel shadow')
        assert(lift:IsShown() and lift:GetText()==text:GetText() and lift.color[1]==0 and lift.color[3]==0 and Near(lift.color[4],M.LIFT_ALPHA),'translucent black copy')
        assert(la[1]=='TOPLEFT' and la[2]==text and la[4]==2*px and la[5]==-2*px,'2px down-right in screen pixels')
        assert(lb[1]=='BOTTOMRIGHT' and lb[2]==text and lb[4]==2*px and lb[5]==-2*px,'covers the text box')
        assert(lift.shadowColor[4]==0 and lift.font[2]==text.font[2] and lift.font[3]=='')
    end
    assert(p.texts.border.lift.justifyH=='RIGHT' and not p.texts.powerCenter.lift:IsShown(),'no power text by default, so no lift')
    assert(t.texts.border.lift.text.label=='name' and t.texts.left.lift.text.secret.label=='pct','secret values go straight to the lifts')
    -- Class gradient ring: light top, pastel class color, deeper bottom.
    local function RingTop(f) return f.portrait.ring.gradient[3] end
    local function RingBottom(f) return f.portrait.ring.gradient[2] end
    local soft=Soft(rogue)
    assert(p.portrait.ring.gradient[1]=='VERTICAL' and Near(RingTop(p).r,Soft(soft,0.35)[1]) and Near(RingBottom(p).r,soft[1]*0.72))
    assert(Near(RingTop(t).g,Soft(Soft(P.hostile),0.35)[2]),'NPC ring uses the pastel reaction color')
    assert(p.portrait.icon.texture=='portrait:player' and p.portrait.icon.texCoord[1]==0)
    assert(p.texts.bottomLeft:GetText()=='60' and p.texts.right:GetText()=='90%')

    -- Colors: health Default/Class/Custom, name Accent/Class/Custom, ring Class/Default/Custom.
    assert(M:SetFrameOption('player','healthColorMode','class') and Near(p.health.statusBarColor[1],soft[1]),'pastel class health')
    assert(Near(t.health.statusBarColor[1],Soft(P.hostile)[1]),'matched target: NPC reaction color, pastel')
    assert(M:SetFrameOption('player','healthColorMode','custom') and M:SetFrameOption('player','healthColor',{0,0,1}) and p.health.statusBarColor[3]==1)
    assert(M:SetFrameOption('player','healthColorMode','default') and p.health.statusBarColor[1]==O.health[1])
    -- Foreground and background opacity and textures, per frame; a matched Target follows the Player.
    assert(p.health.statusBarColor[4]==1 and p.power.statusBarColor[4]==1,'opaque fill by default')
    assert(M:SetFrameOption('player','barForegroundOpacity',50) and p.health.statusBarColor[4]==0.5 and p.power.statusBarColor[4]==1,'the health bar only')
    assert(M:SetFrameOption('player','powerForegroundOpacity',40) and p.power.statusBarColor[4]==0.4 and p.health.statusBarColor[4]==0.5,'the power bar has its own')
    assert(M:SetFrameOption('player','powerBackgroundOpacity',20) and p.power.bg.vertexColor[4]==0.2 and p.health.bg.vertexColor[4]==0.7)
    assert(M:SetFrameOption('player','powerForegroundTexture','flat') and p.power.statusBarTexture==addon.Kit.FLAT and p.health.sheen:IsShown(),'power texture its own')
    assert(not M:SetFrameOption('player','powerBackgroundTexture','mode'),'validated')
    assert(M:SetFrameOption('player','powerForegroundTexture','mode') and M:SetFrameOption('player','powerForegroundOpacity',100) and M:SetFrameOption('player','powerBackgroundOpacity',70))
    assert(M:SetCastOption('player','foregroundTexture','flat') and p.castBox.bar.statusBarTexture==addon.Kit.FLAT and p.health.sheen:IsShown(),'the cast bar has its own texture')
    assert(not M:SetCastOption('player','backgroundTexture','mode') and M:SetCastOption('player','foregroundTexture','mode'))
    assert(t.health.statusBarColor[4]==0.5,'matched target follows')
    assert(M:SetFrameOption('player','barBackgroundOpacity',0) and p.health.bg.vertexColor[4]==0 and t.health.bg.vertexColor[4]==0)
    assert(not M:SetFrameOption('player','barForegroundOpacity',5) and not M:SetFrameOption('player','barBackgroundOpacity',101),'ranges')
    assert(M:SetFrameOption('player','foregroundTexture','flat') and p.health.statusBarTexture==addon.Kit.FLAT and not p.health.sheen:IsShown())
    assert(not M:SetFrameOption('player','backgroundTexture','mode') and not M:SetFrameOption('player','foregroundTexture','bogus'),'texture choices validated')
    assert(M:SetFrameOption('player','foregroundTexture','mode') and p.health.sheen:IsShown())
    assert(M:SetFrameOption('player','barForegroundOpacity',100) and M:SetFrameOption('player','barBackgroundOpacity',70))
    assert(M:SetFrameOption('player','showPower',false) and not p.panel.hairline:IsShown() and M:SetFrameOption('player','showPower',true))
    assert(not M:SetFrameOption('player','healthColorMode','palette') and not M:SetFrameOption('player','healthColorMode','reaction'),'only Default, Class Color or Custom')
    assert(M:SetFrameOption('player','nameColorMode','class') and Near(p.texts.border.color[1],soft[1]))
    assert(M:SetFrameOption('player','nameColorMode','custom') and M:SetFrameOption('player','nameColor',{1,0,0}) and p.texts.border.color[1]==1 and p.texts.border.color[2]==0)
    local L,F=M.nameAccents.lilac,M.nameAccents.frost
    assert(M:SetFrameOption('player','nameColorMode','lilac') and p.texts.border.color[1]==L[1] and p.texts.border.color[3]==L[3] and t.texts.border.color[2]==L[2],'Lilac')
    assert(M:SetFrameOption('player','nameColorMode','frost') and p.texts.border.color[1]==F[1] and p.texts.border.color[2]==F[2],'Frost')
    assert(p.texts.border.lift.color[1]==0 and Near(p.texts.border.lift.color[4],M.LIFT_ALPHA),'the lift stays black whatever the name color')
    local C=M.nameAccents.champagne
    assert(M:SetFrameOption('player','nameColorMode','champagne') and p.texts.border.color[1]==C[1] and p.texts.border.color[3]==C[3],'Champagne')
    assert(M:SetFrameOption('player','nameColorMode','sky') and p.texts.border.color[1]==M.ACCENT[1] and p.texts.border.color[2]==M.ACCENT[2],'Sky')
    assert(not M:SetFrameOption('player','nameColorMode','accent') and not M:SetFrameOption('player','nameColorMode','mist'),'Mist is retired')
    assert(not M:SetFrameOption('player','nameGlow',true) and not M:SetFrameOption('player','nameGlowStrength',50),'glow settings are retired')
    assert(not M:SetFrameOption('player','nameLift',true),'the name-only lift is retired')
    assert(M:SetFrameOption('player','liftedShadow',false) and not p.texts.border.lift:IsShown() and not p.texts.right.lift:IsShown(),'one toggle for every text')
    assert(p.texts.border:IsShown() and p.texts.border.shadowColor[4]==1 and p.texts.right.shadowColor[4]==1,'lift off keeps the crisp shadow')
    assert(M:SetFrameOption('player','liftedShadow',true) and p.texts.border.lift:IsShown() and p.texts.bottomLeft.lift:IsShown())
    assert(M:SetFrameOption('player','shadow',false) and not p.texts.border.lift:IsShown() and not p.texts.right.lift:IsShown(),'the lift needs Text Shadow')
    assert(p.texts.right.shadowColor[4]==0 and p.texts.right.shadowOffset[1]==0)
    assert(M:SetFrameOption('player','shadow',true) and M:SetTextOption('player','border','content','none') and not p.texts.border.lift:IsShown())
    assert(M:SetTextOption('player','border','content','name') and p.texts.border.lift:IsShown() and p.texts.border.lift:GetText()=='Fixture')
    assert(M:SetFrameOption('player','outline',true) and p.texts.border.lift.font[3]=='OUTLINE' and p.texts.bottomLeft.lift.font[3]=='OUTLINE','lift matches the outlined glyphs')
    assert(M:SetFrameOption('player','outline',false))
    assert(M:SetTextOption('player','powerCenter','content','powerPercent') and p.texts.powerCenter.lift:IsShown() and p.texts.powerCenter.lift:GetText()=='50%','power text lifts too')
    assert(M:SetTextOption('player','powerCenter','content','none') and not p.texts.powerCenter.lift:IsShown())
    assert(M:SetFrameOption('player','portraitRing','border') and RingTop(p).r==M.RIM_COLOR[1] and RingBottom(p).r==M.RIM_COLOR[1],'Default matches the frame rim')
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
    assert(math.abs(q.px-px)<1e-9 and math.abs(q.border-2*px)<1e-9 and q.line==0 and math.abs(q.gap-px)<1e-9,'one 2px rim, no gap, 1px hairline in screen pixels')
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
    assert(M:SetFrameOption('player','showPortrait',false) and p.geometry.inset==2 and Point(p.panel)[4]==0 and not p.portrait:IsShown())
    assert(M:SetFrameOption('player','showPortrait',true))
    assert(M:SetFrameOption('player','showPower',false) and not p.power:IsShown() and p.geometry.blockHeight==26+4 and p.geometry.portrait==46)
    assert(M:SetFrameOption('player','showPower',true))
    assert(M:SetFrameOption('player','portraitScale',200) and p.geometry.portrait==84 and p.geometry.blockY==21)
    assert(M:SetFrameOption('player','portraitScale',100) and p.geometry.portrait==p.geometry.blockHeight and p.geometry.blockY==0)
    assert(M:SetFrameOption('player','portraitScale',150) and p.geometry.portrait==64)
    -- Text slots: any slot shows any text; offsets, size and color are each slot's own.
    assert(M:SetTextOption('player','border','content','none') and M:SetTextOption('player','right','content','name'))
    assert(Point(p.texts.right)[2]==p.health and Point(p.texts.right)[1]=='RIGHT' and p.texts.right:GetText()=='Fixture' and p.texts.right.width==180*0.6,'the name in the bar, 60% wide at most')
    assert(p.texts.right.color[1]==M.ACCENT[1] and t.texts.left.text.label=='name','names keep the Name Color in any slot; the Target mirrors it')
    assert(M:SetTextOption('player','right','content','healthPercent') and p.texts.right:GetText()=='90%' and p.texts.right.width==0)
    assert(M:SetTextOption('player','border','content','levelName'))
    local mu=P.muted;local tag=string.format('|cff%02x%02x%02x',math.floor(mu[1]*255+0.5),math.floor(mu[2]*255+0.5),math.floor(mu[3]*255+0.5))
    assert(p.texts.border:GetText()==tag..'60|r Fixture' and p.texts.border.color[1]==M.ACCENT[1],'Level and Name: the level muted, then the name')
    assert(M:SetTextOption('player','border','colorMode','custom') and M:SetTextOption('player','border','color',{1,0,0}))
    assert(p.texts.border:GetText()=='60 Fixture' and p.texts.border.color[1]==1 and p.texts.border.color[2]==0,'a custom color is the whole text')
    assert(M:SetTextOption('player','border','colorMode','default') and M:SetTextOption('player','border','content','name'))
    assert(M:SetTextOption('player','center','content','healthDeficit') and p.texts.center:GetText()=='-100','health deficit')
    units.player.health=1000;FireEvent('UNIT_HEALTH','player');assert(p.texts.center:GetText()=='','nothing at full health')
    units.player.health=900;FireEvent('UNIT_HEALTH','player')
    assert(M:SetFrameOption('target','matchPlayer',false) and M:SetTextOption('target','center','content','healthDeficit'))
    assert(t.texts.center.text.label=='wrapped','a secret deficit goes straight to SetText')
    assert(M:SetTextOption('target','center','content','none') and M:SetFrameOption('target','matchPlayer',true))
    assert(M:SetTextOption('player','center','content','powerBoth') and p.texts.center:GetText()=='50 · 50%','power text on the health bar')
    assert(M:SetFrameOption('player','showPower',false) and p.texts.center:IsShown() and not p.texts.powerCenter:IsShown())
    units.player.power=40;FireEvent('UNIT_POWER_FREQUENT','player');assert(p.texts.center:GetText()=='40 · 40%','it follows power without a power bar')
    units.player.power=50;assert(M:SetFrameOption('player','showPower',true) and M:SetTextOption('player','center','content','none'))
    assert(M:SetTextOption('player','bottomLeft','content','none') and not p.texts.bottomLeft:IsShown() and not p.texts.bottomLeft.lift:IsShown())
    assert(M:SetTextOption('player','bottomLeft','content','level'))
    assert(M:SetTextOption('player','right','x',5) and M:SetTextOption('player','right','y',-2))
    assert(Point(p.texts.right)[4]==-4+5 and Point(p.texts.right)[5]==-2,'slot offset')
    assert(Point(t.texts.left)[1]=='LEFT' and Point(t.texts.left)[2]==t.health and Point(t.texts.left)[4]==4-5,'mirrored offsets')
    assert(M:SetFrameOption('target','mirrorText',false) and Point(t.texts.right)[4]==-12,'toward its portrait an offset stops at the line')
    assert(M:SetFrameOption('target','mirrorText',true))
    assert(M:SetTextOption('player','border','x',3) and M:SetTextOption('player','border','y',4) and Point(p.texts.border)[5]==-2+4 and Point(p.texts.border)[4]==5+3,'a little higher the ring has curved away: closer')
    assert(M:SetTextOption('player','border','y',11) and Point(p.texts.border)[5]==-2+11 and Point(p.texts.border)[4]==0+3,'11px higher the ring is past the name: no tuck')
    for _,key in ipairs({'x','y'}) do assert(M:SetTextOption('player','border',key,0) and M:SetTextOption('player','right',key,0)) end
    assert(M:SetTextOption('player','bottomLeft','colorMode','custom') and M:SetTextOption('player','bottomLeft','color',{1,0,0}) and M:SetTextOption('player','bottomLeft','size',14))
    assert(p.texts.bottomLeft.color[1]==1 and p.texts.bottomLeft.font[2]==14 and p.texts.right.font[2]==11,'each slot its own color and size')
    assert(M:SetTextOption('player','bottomLeft','colorMode','default') and M:SetTextOption('player','bottomLeft','size',11) and p.texts.bottomLeft.color[1]==P.muted[1])
    assert(M:SetTextOption('player','border','align','CENTER') and p.texts.border.justifyH=='CENTER' and t.texts.border.justifyH=='CENTER' and M:SetTextOption('player','border','align','RIGHT'))

    -- The Target matches the Player (mirrored) until Match Player Frame is turned off.
    assert(M:SetFrameOption('player','barWidth',200) and t.width==54+180+2 and p.width==54+200+2 and t.geometry.inset==p.geometry.inset,'width is each frame own')
    assert(Point(t.portrait)[1]=='TOPRIGHT' and Point(t.health)[1]=='TOPRIGHT','still mirrored')
    assert(M:SetFrameOption('player','showPower',false) and not t.power:IsShown(),'power bar follows the Player')
    assert(M:SetFrameOption('player','showPower',true) and t.power:IsShown())
    assert(M:SetFrameOption('target','barWidth',300) and t.width==54+300+2,'a matched Target uses its own width')
    assert(M:FrameDB('target').portraitSide=='right' and M:FrameDB('target').barWidth==300 and M:FrameDB('target').healthHeight==M.db.player.healthHeight)
    assert(M:SetFrameOption('target','matchPlayer',false) and t.width==54+300+2,'own settings once unmatched')
    assert(M:FrameDB('target')==M.db.target and t.texts.border.justifyH=='RIGHT' and t.texts.right:IsShown() and not t.texts.left:IsShown(),'its own slots')
    assert(M:SetFrameOption('player','barWidth',180) and M:SetFrameOption('target','barWidth',180))

    -- Public player values and portrait.
    M:UpdateAll()
    assert(p.health.value==900 and p.health.high==1000 and p.power.value==50)
    assert(p.texts.right:GetText()=='90%' and p.texts.border:GetText()=='Fixture' and p.texts.bottomLeft:GetText()=='60')
    assert(M:SetFrameOption('target','healthColorMode','class'))

    -- Secret target values pass straight to widgets and formatters.
    assert(issecretvalue(t.health.value) and t.health.high.label=='max' and t.power.value.label=='p')
    assert(t.texts.right.text.secret.label=='pct' and t.texts.border.text.label=='name')
    assert(t.texts.bottomRight:GetText()=='??+')
    assert(Near(t.health.statusBarColor[1],Soft(P.hostile)[1]),'NPC reaction color, pastel')
    assert(t.portrait.icon.texture=='portrait:target')

    -- Per-frame customization stays independent.
    assert(M:SetFrameOption('player','portraitStyle','class') and p.portrait.icon.atlas=='classicon-rogue')
    assert(t.portrait.icon.texture=='portrait:target','target keeps its style')
    assert(M:SetFrameOption('target','portraitStyle','class') and t.portrait.icon.texture=='portrait:target','NPC falls back to portrait')
    assert(M:SetFrameOption('player','portraitSide','right') and Point(p.portrait)[1]=='TOPRIGHT')
    assert(M:SetFrameOption('player','portraitSide','left'))
    assert(M:SetTextOption('player','powerCenter','content','powerPercent') and p.texts.powerCenter:IsShown() and p.texts.powerCenter:GetText()=='50%')
    assert(M:SetTextOption('target','powerCenter','content','powerBoth') and t.texts.powerCenter.text.formatted=='%s · %.0f%%')
    assert(M:SetFrameOption('player','powerColorMode','custom') and M:SetFrameOption('player','powerColor',{1,0,1}))
    assert(p.power.statusBarColor[1]==1 and p.power.statusBarColor[2]==0)
    assert(M:SetTextOption('player','right','content','healthBoth') and p.texts.right:GetText()=='900 · 90%')
    local abbreviate=AbbreviateNumbers;AbbreviateNumbers=function() error('unsupported') end
    M:UpdateHealth('player');assert(p.texts.right:GetText()=='90%','fallback to percent');AbbreviateNumbers=abbreviate
    units.player.dead=true;M:UpdateHealth('player');assert(p.texts.right:GetText()=='Dead');units.player.dead=false
    assert(M:SetTextOption('player','right','content','none') and M:SetTextOption('player','center','content','healthPercent') and Point(p.texts.center)[1]=='CENTER')
    assert(p.texts.center:GetText()=='90%' and not p.texts.right:IsShown())
    assert(p.health.sheen:IsShown() and p.health.sheen.gradient and p.power.sheen:IsShown(),'Mode Gradient on every bar')
    assert(not M:SetFrameOption('player','texture','flat'),'the bar texture is no longer a setting')
    assert(M:SetFrameOption('player','scale',120) and p.scale==1.2)
    assert(M:SetFrameOption('player','barWidth',240) and p.width==54+240+2)

    -- Validation refuses bad values without changing settings.
    assert(not M:SetFrameOption('player','barWidth',50) and M.db.player.barWidth==240)
    assert(not M:SetTextOption('player','border','content','bogus') and M.db.player.texts.border.content=='name')
    assert(not M:SetFrameOption('player','namePosition','border') and not M:SetFrameOption('player','healthText','percent'),'the old text keys are retired')
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
    assert(ghost.texts.border:GetText()=='Fixture' and ghost.texts.border.color[1]==M.ACCENT[1],'the player stand-in shows your name')
    assert(M.ghosts.target.texts.border:GetText()=='Name','other stand-ins show a sample name, not the frame title')
    local handle=addon.PositionManager.elements.unitFramesPlayer.decoration
    assert(handle and handle.label:GetText()=='Player Frame' and addon.PositionManager.elements.unitFramesTarget.decoration.label:GetText()=='Target Frame','each handle names its frame')
    assert(ghost.texts.border.lift:GetText()=='Fixture' and ghost.texts.border.lift:IsShown() and ghost.texts.bottomLeft.lift:GetText()=='60','stand-in text has the lift too')
    assert(ghost.width==p.width and Near(RingTop(ghost).r,Soft(soft,0.35)[1]),'stand-in matches size and class ring')
    assert(Near(RingTop(M.ghosts.target).r,Soft(Soft(P.hostile),0.35)[1]),'target stand-in shows an enemy ring')
    local gc=M.ghosts.target.combo;assert(gc:IsShown() and gc.points[3].bar.value==M.COMBO_SAMPLE and gc.points[5]:IsShown(),'stand-in shows sample combo points')
    local ga=M.ghosts.target;assert(ga.auraShown.buffs==M.AURA_SAMPLE and ga.auraIcons.buffs[1]:IsShown() and ga.auraShown.debuffs==0,'sample buffs')
    assert(ga.castBox:IsShown() and ga.castBox.text:GetText()=='Frostbolt' and not M.ghosts.player.auraIcons.buffs[1],'sample cast; no buffs on the Player')
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
    assert(v1.layoutVersion==18 and v1.player.barWidth==260 and v1.player.hideBlizzard==false and v1.player.texts.bottomLeft.content=='none')
    assert(v1.player.texts.right.content=='healthBoth' and v1.player.texts.right.size==14 and v1.player.texts.border.size==14 and v1.player.healthColorMode=='default')
    assert(v1.player.healthText==nil and v1.player.levelStyle==nil and v1.player.nameFontSize==nil,'old text keys removed')
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
    assert(v5.layoutVersion==18 and v5.player.healthHeight==26 and v5.player.texts.border.align=='RIGHT' and v5.player.fontMedia=='Expressway')
    assert(v5.player.texts.bottomLeft.size==13 and v5.player.borderStyle==nil and v5.player.palette==nil)
    local v7={layoutVersion=7,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v7.player.nameAlign='LEFT';v7.player.fontMedia='PTG Lato';M.Initialize(v7)
    assert(v7.player.texts.border.align=='LEFT' and v7.player.fontMedia=='PTG Lato','later choices are not migrated')
    -- Layout 8 -> 9: the locked Onyx skin.
    local v8={layoutVersion=8,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v8.player.healthColorMode='palette';v8.player.nameColorMode='class';v8.player.portraitRing='accent';v8.player.namePosition='panel'
    v8.player.levelStyle='text';v8.player.levelColor={1,1,0};v8.player.palette='custom';v8.player.paletteBorder={0,1,1}
    v8.player.nameSheen=true;v8.player.nameSheenStrength=55;v8.player.rimThickness=3;v8.player.backgroundOpacity=0;v8.player.borderStyle='minimal'
    v8.target.healthColorMode='reaction';v8.target.portraitRing='custom';v8.target.portraitRingColor={0,0,1};v8.target.nameColorMode='text'
    local v8b=addon.ProfileCodec.Copy(v8);v8b.target.healthColorMode='custom';v8b.target.healthColor={0.2,0.3,0.4};v8b.player.healthColorMode='mode'
    M.Initialize(v8);M.Initialize(v8b)
    assert(v8.layoutVersion==18 and v8.player.healthColorMode=='default' and v8.target.healthColorMode=='class')
    assert(v8b.target.healthColorMode=='custom' and v8b.target.healthColor[3]==0.4 and v8b.player.healthColorMode=='default')
    assert(v8.player.nameColorMode=='sky' and v8.target.nameColorMode=='sky','names adopt the default color')
    assert(v8.player.portraitRing=='class' and v8.target.portraitRing=='custom' and v8.target.portraitRingColor[3]==1,'class gradient ring unless custom')
    local v8s=v8.player.texts;assert(v8s.border.content=='name' and v8s.bottomLeft.content=='level' and v8s.bottomLeft.colorMode=='custom' and v8s.bottomLeft.color[2]==1,'explicit level color kept')
    for _,key in ipairs(M.retiredKeys) do assert(v8.player[key]==nil and v8.target[key]==nil,'retired key removed: '..key) end
    -- Layout 9 -> 10: Mist and its glow give way to Champagne and the lifted shadow.
    local v9={layoutVersion=9,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v9.player.nameColorMode='accent';v9.player.nameGlow=true;v9.player.nameGlowStrength=80;v9.player.nameLift=nil
    v9.target.nameColorMode='custom';v9.target.nameColor={0,1,0};v9.target.nameGlow=false
    M.Initialize(v9)
    assert(v9.layoutVersion==18 and v9.player.nameColorMode=='sky' and v9.player.liftedShadow==true and v9.player.nameLift==nil)
    assert(v9.player.nameGlow==nil and v9.player.nameGlowStrength==nil and v9.target.nameGlow==nil,'glow keys removed')
    assert(v9.target.nameColorMode=='custom' and v9.target.nameColor[2]==1,'custom name color kept')
    -- Layout 10 -> 11: Sky replaces the presets to try; the name lift becomes Lifted Shadow for all text.
    local v10={layoutVersion=10,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v10.player.nameColorMode='lilac';v10.player.nameLift=false;v10.player.liftedShadow=nil;v10.player.mirrorText=nil
    v10.target.nameColorMode='class';v10.target.nameLift=true;v10.target.mirrorText=nil
    M.Initialize(v10)
    assert(v10.layoutVersion==18 and v10.player.nameColorMode=='sky' and v10.target.nameColorMode=='class','presets move to Sky; Class Color kept')
    assert(v10.player.liftedShadow==false and v10.target.liftedShadow==true and v10.player.nameLift==nil and v10.target.nameLift==nil,'lift choice carried over')
    assert(v10.target.mirrorText==true,'matched Target copies the Player text layout, mirrored since version 15')
    local v11={layoutVersion=11,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v11.player.texture='flat';v11.target.texture='media:Smooth';M.Initialize(v11)
    assert(v11.layoutVersion==18 and v11.player.texture==nil and v11.target.texture==nil,'retired Bar Texture removed')
    -- Version 12 -> 13: new small-frame defaults, but a changed setting stays.
    local v12={layoutVersion=12,targettarget={scale=100,showPortrait=true,namePosition='above',nameAlign='CENTER',barWidth=110},
        focus={scale=120,showPortrait=true,barWidth=150,healthHeight=22,levelStyle='badge',nameFontSize=12}}
    M.Initialize(v12)
    assert(v12.layoutVersion==18 and v12.targettarget.scale==75 and v12.targettarget.showPortrait==false and v12.targettarget.texts.border.content=='none')
    assert(v12.targettarget.texts.center.content=='name' and v12.focus.scale==120,'user changes kept: a centred name in the bar')
    local fs=v12.focus.texts;assert(v12.focus.barWidth==110 and v12.focus.healthHeight==16 and fs.bottomRight.content=='none' and fs.left.content=='name' and fs.left.size==11)
    assert(v12.targettarget.attach==true and v12.focustarget.attach==true and v12.focus.attach==false,'new keys take defaults')
    -- Version 13 -> 14: Mode Slate at 70% for frames still on the old Flat / 25%.
    local v13={layoutVersion=13,player={backgroundTexture='flat',barBackgroundOpacity=25},target={backgroundTexture='media:Smooth',barBackgroundOpacity=40}}
    M.Initialize(v13)
    assert(v13.layoutVersion==18 and v13.player.backgroundTexture=='slate' and v13.player.barBackgroundOpacity==70)
    assert(v13.target.backgroundTexture=='media:Smooth' and v13.target.barBackgroundOpacity==40,'chosen backgrounds stay')
    local v15={layoutVersion=15,player={namePosition='above'},target={namePosition='bar'}};M.Initialize(v15)
    assert(v15.layoutVersion==18 and v15.player.texts.border.content=='name' and v15.player.texts.border.y==0,'version 16: names above sit on the border')
    assert(v15.target.texts.right.content=='name' and v15.target.texts.topRight.content=='healthPercent','a taken spot moves to its top row')
    local v14={layoutVersion=14,player={levelStyle='badge'},target={matchPlayer=true,mirrorText=false}};M.Initialize(v14)
    assert(v14.layoutVersion==18 and v14.target.mirrorText==true and v14.player.texts.bottomLeft.content=='level','version 15: corner level, mirrored Target')
    -- Version 16 -> 17: text slots. Every text moves to its matching slot, so nothing moves.
    local v16={layoutVersion=16,player={namePosition='above',nameOffsetY=2,nameOffsetX=-3,nameAlign='CENTER',levelPosition='health',levelOffsetY=1,
        healthText='current',healthTextPosition='LEFT',healthTextOffsetX=3,healthFontSize=13,powerText='both',powerTextPosition='RIGHT',powerFontSize=10},
        target={matchPlayer=true,showName=false,levelStyle='none',healthText='none',powerText='percent'},
        focus={namePosition='bar',nameAlign='RIGHT',healthText='percent',healthTextPosition='RIGHT'}}
    M.Initialize(v16)
    local s=v16.player.texts
    assert(v16.layoutVersion==18 and s.border.content=='name' and s.border.align=='CENTER' and s.border.x==-3 and s.border.y==2+4+3,'Above Frame: on the border, raised by the difference')
    assert(s.left.content=='healthCurrent' and s.left.x==3 and s.left.size==13 and s.right.content=='none','health text in its side slot')
    assert(s.bottomLeft.content=='level' and s.bottomLeft.y==1 and s.bottomLeft.colorMode=='default','a level beside the health text goes to the bottom corner')
    assert(s.powerRight.content=='powerBoth' and s.powerRight.size==10 and s.powerCenter.size==10)
    local ts=v16.target.texts;assert(ts.border.content=='none' and ts.bottomRight.content=='none' and ts.right.content=='none' and ts.powerCenter.content=='powerPercent')
    assert(v16.focus.texts.right.content=='name' and v16.focus.texts.topRight.content=='healthPercent')
    for _,key in ipairs({'namePosition','nameAlign','levelPosition','healthText','powerTextPosition','levelColor','showName'}) do assert(v16.player[key]==nil and v16.target[key]==nil,'removed: '..key) end
    local v16b=addon.ProfileCodec.Copy(v16);M.Initialize(v16b);assert(v16b.player.texts.border.y==9,'migration is idempotent')
    -- Version 17 -> 18: the power and cast bars start with the textures they showed.
    local v17={layoutVersion=17,player={foregroundTexture='flat',backgroundTexture='slateHatch',barForegroundOpacity=80,barBackgroundOpacity=40,castBar={height=14}}}
    M.Initialize(v17)
    local q17=v17.player;assert(v17.layoutVersion==18 and q17.powerForegroundTexture=='flat' and q17.powerBackgroundTexture=='slateHatch' and q17.powerForegroundOpacity==80 and q17.powerBackgroundOpacity==40)
    assert(q17.castBar.foregroundTexture=='flat' and q17.castBar.backgroundTexture=='slateHatch' and q17.castBar.height==14,'nothing changes on screen')
    assert(v17.target.powerForegroundTexture=='mode' and v17.target.castBar.backgroundTexture=='slate','new frames take the defaults')
    local v14b={layoutVersion=14,target={matchPlayer=false,mirrorText=false}};M.Initialize(v14b)
    assert(v14b.target.mirrorText==false,'an unmatched Target is left alone')
    local w13={layoutVersion=13,player={barWidth=230},target={matchPlayer=true,barWidth=180}};M.Initialize(w13)
    assert(w13.target.barWidth==230,'a matched Target keeps the width it showed')
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
    assert(M.frames.player and M.frames.target.width==54+300+2,'frames built at login (unmatched target keeps its width)')
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
    assert(table.concat(titles,'|')=='Frame|Health Bar|Power Bar|Portrait|Cast Bar|Auras|Class Resource|Text','one tab per part of the frame; no Border tab')
    assert(page.sectionTabs and #page.sectionTabs.buttons==8)
    local function Find(section,title)
        for _,row in ipairs(page.rows) do if row.section and row.section.title==section and row.settingsTitle==title then return row end end
    end
    local function Row(section,title) return Find(section,title) or error('missing row '..section..' / '..title) end
    local function Visible(row) return not row.visibleWhen or row.visibleWhen() end
    local function Toggle(section,label)
        for _,row in ipairs(page.rows) do
            if row.section and row.section.title==section and row.settingsToggles then
                for _,cell in ipairs(row.settingsToggles) do if cell.label:GetText()==label then return row end end
            end
        end
        error('missing toggle '..section..' / '..label)
    end
    for section,list in pairs({Frame={'Scale','Frame Tools','Status'},Portrait={'Portrait Style','Portrait Size','Portrait Ring'},
        ['Health Bar']={'Frame Width','Health Bar Height','Fill Direction','Health Color'},['Power Bar']={'Power Bar Height','Power Color'},
        Text={'Name Color','Class Color Softness','Font','Text Color'}}) do
        for _,title in ipairs(list) do assert(Visible(Row(section,title)),'Player editable: '..section..' / '..title) end
        assert(not Find(section,'Editing'),'Editing is in the preview header, not in each tab')
    end
    assert(not Find('Health Bar','Scale') and not Find('Frame','Health Bar Height') and not Find('Frame','Frame Width'),'one place for each setting')
    -- Editing at the preview's top right, with whether the frame is on.
    assert(page.unitFrameEditSelect and Point(page.unitFrameEditSelect:GetParent())[1]=='TOPRIGHT' and page.unitFrameEditSelect:GetParent():GetParent()==page.previewArea)
    assert(page.unitFrameState:GetText()=='On' and page.unitFrameStateDot.vertexColor[2]==addon.InterfaceTheme.enabled[2] and not page.unitFrameTurnOn:IsShown())
    -- Each bar's own textures and opacity, two to a row.
    assert(page.unitFrameForeground and page.unitFrameBackground and page.unitFrameForegroundOpacity and page.unitFrameBackgroundOpacity)
    assert(page.unitFramePowerForeground and page.unitFramePowerBackgroundOpacity and page.unitFrameCastForeground and page.unitFrameCastBackground)
    assert(page.unitFrameForeground:GetParent().row.section.title=='Health Bar' and page.unitFramePowerForeground:GetParent().row.section.title=='Power Bar')
    -- Width and height side by side: both stacked, pairable sliders in Size.
    assert(Row('Health Bar','Frame Width').pairable and Row('Health Bar','Health Bar Height').pairable)
    assert(page.unitFrameForeground:GetParent().rowLabel:GetText()=='Foreground' and page.unitFrameBackgroundOpacity:GetParent().rowLabel:GetText()=='Background Opacity')
    -- Slider drags apply the first step at once, then at most one value every
    -- W.LIVE_SECONDS; the last value always applies (no rebuild on every step).
    local fs=page.unitFrameForegroundOpacity
    fs:SetValue(60,true);assert(M.db.player.barForegroundOpacity==60,'the first step applies at once')
    fs:SetValue(70,true);assert(M.db.player.barForegroundOpacity==60,'quick steps wait')
    Advance(0.2);assert(M.db.player.barForegroundOpacity==70,'the last value applies')
    fs:SetValue(100,true);Advance(0.2);assert(M.db.player.barForegroundOpacity==100)
    for _,title in ipairs({'Border Style','Palette','Background Color','Rim Color','Rim Thickness','Name Sheen Strength','Empty Bar Color'}) do
        for _,section in ipairs(page.sections) do assert(not Find(section.title,title),'locked to Onyx: '..title) end
    end
    assert(not Visible(Row('Health Bar','Custom Health Color')) and M:SetFrameOption('player','healthColorMode','custom') and Visible(Row('Health Bar','Custom Health Color')))
    assert(not Visible(Row('Text','Custom Name Color')) and M:SetFrameOption('player','nameColorMode','custom') and Visible(Row('Text','Custom Name Color')))
    assert(not Visible(Row('Portrait','Portrait Ring Color')) and M:SetFrameOption('player','portraitRing','custom') and Visible(Row('Portrait','Portrait Ring Color')))
    assert(not Find('Text','Glow Strength') and not Find('Text','Name Glow'),'glow controls are gone')
    for _,title in ipairs({'Name Position','Health Text','Power Text Position','Level Position','Show Level'}) do
        for _,section in ipairs(page.sections) do assert(not Find(section.title,title),'replaced by text slots: '..title) end
    end
    assert(M:ResetFrame('player'))
    -- Text slots: three spots to a line in frame order (left, centre, right), every
    -- dropdown the same width; a spot with a text has a swatch and a size under it.
    assert(not Find('Text','Style Slot') and page.unitFrameStyleSlot==nil,'no Slot Style')
    local S=page.unitFrameTextSelects
    local function Cells(slot) return S[slot]:GetParent():GetParent():GetParent().row end
    for _,line in ipairs({{'topLeft','top','topRight'},{'left','center','right'},{'bottomLeft','bottom','bottomRight'},{'powerLeft','powerCenter','powerRight'}}) do
        local row=Cells(line[1]);assert(Cells(line[2])==row and Cells(line[3])==row and row.settingsTitles[2]==M.textSlotLabels[line[2]],'one line: '..line[1])
        assert(row.section.title==(line[1]=='powerLeft' and 'Power Bar' or 'Health Bar'),'in the tab of its bar')
        assert(Visible(row) and Point(S[line[1]])[1]=='TOPLEFT' and Point(S[line[1]],2)[1]=='TOPRIGHT','stretched across its cell')
    end
    assert(Cells('topLeft').settingsTitles[1]=='Top Left' and Cells('topLeft').settingsTitles[3]=='Top Right')
    local right,top=page.unitFrameTextSizes.right,page.unitFrameTextSizes.top
    assert(right.line:IsShown() and not top.line:IsShown(),'size and color only where a text is')
    assert(page.unitFrameTextSwatches.right.sample.vertexColor[1]==M.db.player.textColor[1] and not right.reset:IsShown())
    right.larger.scripts.OnClick();assert(M.db.player.texts.right.size==12 and M.frames.player.texts.right.font[2]==12,'+ grows the text')
    right.smaller.scripts.OnClick();assert(M.db.player.texts.right.size==11)
    page.unitFrameTextSwatches.right.scripts.OnClick();assert(ColorPickerFrame:IsShown())
    ColorPickerFrame.r,ColorPickerFrame.g,ColorPickerFrame.b=1,0,0;ColorPickerFrame.swatchFunc()
    assert(M.db.player.texts.right.colorMode=='custom' and M.db.player.texts.right.color[1]==1 and right.reset:IsShown(),'picked color is custom')
    ColorPickerFrame.info.cancelFunc();assert(M.db.player.texts.right.colorMode=='default','cancel restores')
    assert(page.unitFrameBorderAlign:IsShown() and M:SetTextOption('player','border','content','none') and not page.unitFrameBorderAlign:IsShown())
    assert(M:SetTextOption('player','border','content','name'))
    assert(M:SetFrameOption('player','showPower',false) and not Visible(Cells('powerLeft')) and M:SetFrameOption('player','showPower',true))
    -- Frame tab: the edited frame's switches and its tools.
    assert(page.unitFrameReset and page.unitFrameCopy and page.unitFrameCopy.label:GetText()=='Copy Style to Target')
    assert(not Visible(Toggle('Frame','Match Player Frame')),"matching is the Target's")
    page.SetEditing('focus');assert(page.unitFrameCopy.label:GetText()=='Copy Player Style')
    assert(M:SetFrameOption('player','barWidth',200));page.unitFrameCopy.scripts.OnClick()
    assert(M.db.focus.barWidth==200 and M.db.focus.portraitSide=='right','copies the Player look, keeps its side')
    page.unitFrameReset.scripts.OnClick();assert(M.db.focus.barWidth==110 and M:ResetFrame('player'))
    -- A frame that is off: Off in red, Turn On beside it, and the tabs say so.
    assert(M:SetFrameOption('focus','enabled',false) and page.unitFrameState:GetText()=='Off' and page.unitFrameTurnOn:IsShown())
    assert(page.unitFrameStateDot.vertexColor[1]==addon.InterfaceTheme.danger[1] and Visible(Row('Health Bar','Frame Off')) and not Visible(Row('Health Bar','Frame Width')))
    page.unitFrameTurnOn.scripts.OnClick();assert(M.db.focus.enabled and page.unitFrameState:GetText()=='On')
    -- Target Matches Player lives on the Target's Frame tab only.
    page.SetEditing('target')
    assert(Visible(Toggle('Frame','Mirror Player Text')) and Visible(Row('Frame','Target Matches Player')),'match and mirror on the Target\'s Frame tab')
    assert(not Visible(Row('Frame','Scale')) and Visible(Row('Health Bar','Frame Width')) and Visible(Row('Health Bar','Fill Direction')) and not Visible(Row('Health Bar','Health Bar Height')),'a matched Target keeps its own width and fill')
    assert(Visible(Row('Power Bar','Target Matches Player')) and not Visible(Toggle('Power Bar','Show Power Bar')))
    page.SetEditing('player');assert(not Visible(Toggle('Frame','Mirror Player Text')),'only the Target matches')
    -- Class Resource: the Target's own settings, editable even while it matches the Player.
    assert(page.unitFrameComboArc and page.unitFrameComboSize and Visible(Row('Class Resource','Arc Position')))
    assert(page.unitFrameResourceNote:GetText():find('Combo Points'),'names your class\'s resource')
    assert(M:SetComboOption('enabled',false) and not Visible(Row('Class Resource','Arc Position')) and M:SetComboOption('enabled',true))
    -- Cast Bar edits the frame's own cast bar, even on a matched Target.
    assert(page.unitFrameCastPosition and page.unitFrameCastHeight and Visible(Row('Cast Bar','Position')))
    page.SetEditing('target');assert(M.db.target.matchPlayer and Visible(Row('Cast Bar','Spell Icon')) and not Visible(Row('Frame','Scale')))
    page.SetEditing('targettarget');assert(not Visible(Row('Cast Bar','Position')),'off by default on the Target of Target')
    -- Auras: Buffs and Debuffs share the controls; the group switch picks one.
    page.SetEditing('target');assert(page.unitFrameAuraGroup()=='buffs' and page.unitFrameAuraAnchor and Visible(Row('Auras','Filter')))
    local function Shared() return Visible(page.unitFrameAuraAnchor:GetParent().row) end
    assert(Shared());page.unitFrameAuraButtons[2].scripts.OnClick();assert(page.unitFrameAuraGroup()=='debuffs' and not Shared(),'debuffs start off')
    assert(M:SetAuraOption('target','debuffs','enabled',true) and Shared() and M:SetAuraOption('target','debuffs','enabled',false))
    page.SetAuraGroup('buffs')
    -- Preview: a live sample of the frame being edited, built by the same code as
    -- the frames in the world; clicking a part opens its settings.
    local view=page.configPreview
    assert(view and page.previewArea:IsShown() and not page.testDisplayButton:IsShown(),'preview without a screen test')
    local face=view.faces.target
    assert(face and face:IsShown() and face:GetParent()==view.frame and not (view.faces.player and view.faces.player:IsShown()))
    assert(face.auraShown.buffs==M.AURA_SAMPLE and face.castBox:IsShown() and face.combo:IsShown(),'buffs, cast bar and combo points')
    assert(face.texts.border:GetText()=='Target Frame' and face.health.value==75)
    local at=Point(face);assert(at[1]=='TOPLEFT' and at[2]==view.frame and at[3]=='TOPLEFT' and at[4]==math.floor(at[4]) and at[5]==math.floor(at[5]),'centred on whole pixels')
    assert(math.abs(at[4]+face.geometry.width/2-view.frame:GetWidth()/2/face:GetScale())<=1,'the frame centre on the preview centre')
    assert(M:SetAuraOption('target','buffs','enabled',false) and face.auraShown.buffs==0 and M:SetAuraOption('target','buffs','enabled',true),'follows the settings')
    -- One fixed size and spot: moving or resizing parts never moves the sample.
    local w0,h0=M:GetPreviewSize(view)
    assert(M:SetAuraOption('target','buffs','size',36) and M:SetCastOption('target','height',30) and M:SetAuraOption('target','buffs','perRow',1))
    local w1,h1=M:GetPreviewSize(view);local moved=Point(face)
    assert(w0==w1 and h0==h1 and moved[4]==at[4] and moved[5]==at[5],'no jumping around')
    assert(M:ResetFrame('target') and M:SetFrameOption('target','matchPlayer',true))
    -- The Class Resource tab shows the Target whatever Editing says.
    page.SetEditing('player');page:SelectSectionTab(page.sections[7]);assert(page.selectedSection.title=='Class Resource')
    assert(M:PreviewUnit()=='target' and view.faces.target:IsShown() and not view.faces.player:IsShown(),'class resource: the Target')
    page:SelectSectionTab(page.sections[2]);assert(M:PreviewUnit()=='player' and view.faces.player:IsShown())
    page.SetEditing('target')
    face.castBox.scripts.OnMouseUp(face.castBox,'LeftButton');assert(page.selectedSection.title=='Cast Bar')
    face.auraIcons.buffs[1].scripts.OnMouseUp(nil,'LeftButton');assert(page.selectedSection.title=='Auras' and page.unitFrameAuraGroup()=='buffs')
    face.health.scripts.OnMouseUp(nil,'LeftButton');assert(page.selectedSection.title=='Health Bar')
    face.combo.scripts.OnMouseUp(nil,'LeftButton');assert(page.selectedSection.title=='Class Resource')
    face.portrait.scripts.OnMouseUp(nil,'LeftButton');assert(page.selectedSection.title=='Portrait')
    -- A text opens the Text tab at its own spot.
    page.SetEditing('player');local pf=view.faces.player;local hit
    for _,child in ipairs(frames) do if child.jump and child.jump.target=='text:bottomLeft' and child:GetParent()==pf.textLayer then hit=child end end
    assert(hit,'every text is clickable')
    hit.scripts.OnMouseUp(nil,'LeftButton');assert(page.selectedSection.title=='Health Bar' and page.jumpTargets['text:bottomLeft'].section.title=='Health Bar')
    assert(pf.scale==M.PREVIEW_SCALE and M.PREVIEW_HEIGHT==150,'the sample draws at 80%')
    page.SetEditing('target')
    page.SetEditing('targettarget');local small=view.faces.targettarget
    assert(small:IsShown() and not face:IsShown() and math.abs(small.scale-0.75*M.PREVIEW_SCALE)<1e-9 and not small.portrait:IsShown() and not small.castBox:IsShown())
    local w,h=M:GetPreviewSize(view);assert(w==M.PREVIEW_WIDTH and h==M.PREVIEW_HEIGHT)
    -- More tabs than fit: a thin slider under them shows the overflow and drags it.
    local strip=page.sectionTabs
    assert(strip.slider and not strip.slider:IsShown() and strip.maximum==0,'no slider while every tab fits')
    local top=strip:GetHeight();strip.viewport.width=300;strip:Layout()
    assert(strip.maximum>0 and strip.slider:IsShown() and strip:GetHeight()==top+8,'shown with room below the tabs')
    strip.slider:SetValue(60);assert(strip.viewport:GetHorizontalScroll()==60,'dragging scrolls the tabs')
    strip:Scroll(10);assert(strip.slider:GetValue()==10,'the wheel moves the slider')
    strip.viewport.width=nil;strip:Layout();assert(not strip.slider:IsShown() and strip:GetHeight()==top)
    page.SetEditing('player')
    page.SetEditing('focus');assert(page.unitFrameEditing()=='focus' and page.unitFrameEditSelect.label:GetText()=='Focus')
    assert(Visible(Row('Frame','Scale')) and not Visible(Toggle('Frame','Match Player Frame')),'only the Target matches the Player')
    assert(M:SetFrameOption('focus','barBackgroundOpacity',50) and M.db.player.barBackgroundOpacity==70,'edits the Focus only')
    assert(M:ResetFrame('focus'))
    -- Placement shows only for frames that attach; its offsets only while attached.
    assert(not Visible(Row('Frame','Attach Point')),'Focus has no parent frame')
    page.SetEditing('targettarget');assert(Visible(Row('Frame','Attach Point')) and page.unitFrameAttachY)
    assert(M:SetFrameOption('targettarget','attach',false) and not Visible(Row('Frame','Attach Point')) and M:SetFrameOption('targettarget','attach',true))
    page.SetEditing('target');assert(page.unitFrameEditing()=='target' and page.unitFrameEditSelect.label:GetText()=='Target','switch to the Target')
    assert(not Visible(Row('Frame','Scale')) and Visible(Row('Health Bar','Target Matches Player')),'matched Target explains itself')
    assert(Visible(Row('Health Bar','Fill Direction')) and Visible(Row('Health Bar','Frame Width')),'a matched Target still picks its width and fill direction')
    -- The settings look: labels above controls, and two dropdowns or sliders share a
    -- line in a card; width and height of the health bar side by side.
    page.SetEditing('player');page:SelectSectionTab(page.sections[2]);page:Layout()
    local widthRow,heightRow,fillRow=Row('Health Bar','Frame Width'),Row('Health Bar','Health Bar Height'),Row('Health Bar','Fill Direction')
    assert(widthRow.stacked and widthRow.pairable and heightRow.pairable and fillRow.pairable)
    assert(widthRow.offset==heightRow.offset and Point(heightRow)[4]>Point(widthRow)[4],'Frame Width and Health Bar Height share a line')
    assert(fillRow.offset>widthRow.offset and math.abs(widthRow.width-heightRow.width)<1,'two halves, then Fill Direction')
    assert(Point(widthRow.settingsLabel)[1]=='TOPLEFT' and Point(widthRow.settingsHost)[5]==-22,'label above the control')
    local input=widthRow.settingsHost.numericInput;assert(Point(input)[2]==widthRow.settingsHost.valueAnchor and Point(widthRow.settingsHost.slider,2)[4]==0,'value on the label line, slider full width')
    -- Status (Portrait tab): the frame's own, so a matched Target edits it; rested and pulse are the Player's.
    page.SetEditing('target')
    assert(page.unitFrameRestCorner and Visible(page.unitFrameRestCorner:GetParent().row),'status on a matched Target')
    page.SetEditing('player');assert(Visible(page.unitFrameCombatCorner:GetParent().row))
    assert(M:SetFrameOption('player','showPortrait',false) and not Visible(page.unitFrameCombatCorner:GetParent().row),'no portrait, no status')
    assert(M:SetFrameOption('player','showPortrait',true));page.SetEditing('target')
    assert(M:SetFrameOption('target','barWidth',150) and M.db.player.barWidth==180 and M.frames.target.geometry.width<M.frames.player.geometry.width,'its own width')
    assert(M:SetFrameOption('target','barWidth',180))
    assert(M:SetFrameOption('target','matchPlayer',false) and Visible(Row('Frame','Scale')) and Visible(Row('Health Bar','Health Bar Height')))
    assert(M:SetFrameOption('target','barWidth',220) and M.db.player.barWidth==180)
    assert(M:ResetFrame('target') and M:SetFrameOption('target','matchPlayer',true))
    page.SetEditing('player');assert(page.unitFrameEditing()=='player' and Visible(Row('Frame','Scale')))
    assert(M:SetFrameOption('player','enabled',false) and Visible(Row('Health Bar','Frame Off')) and not Visible(Row('Frame','Scale')))
    assert(Visible(Toggle('Frame','Show Frame')),'the Frame tab can always turn it back on')
    assert(M:SetFrameOption('player','enabled',true))
    -- Class Resource for a class without one: said so, nothing to set, nothing shown.
    units.player.class='MAGE';page:Refresh();page:Layout()
    assert(page.unitFrameResourceNote:GetText():find('no class resource') and not Visible(Row('Class Resource','Arc Position')))
    assert(not Visible(Toggle('Class Resource','Show Class Resource')))
    M:RenderGhosts();addon:SetEditMode(true);assert(not M.ghosts.target.combo:IsShown(),'no sample points for a class without them')
    addon:SetEditMode(false);units.player.class='ROGUE';page:Refresh()
]====]
, "unit_frames_page")
print("unit frames: all checks passed")
