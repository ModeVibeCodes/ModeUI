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
    assert(M and addon.modules.unitFrames==M and M.category=='frames' and M.defaultEnabled==true)
    assert(addon.categories.frames.title=='Interface')
    assert(not M.enabled and M.frames.player==nil,'default off creates nothing')
    assert(M.db.layoutVersion==28 and M.db.player.portraitSide=='left' and M.db.target.portraitSide=='right')
    -- The Mode-Obsidian look (docs/DESIGN_LANGUAGE.md; the theme part runs on
    -- every profile): Urbanist, Mode-FG health and power over Mode-BG at 85%,
    -- 3px power, Combined shields.
    assert(M.db.player.fontMedia == '' and M.db.player.texture==nil)
    assert(M.db.player.foregroundTexture=='media:Mode-FG' and M.db.player.powerForegroundTexture=='media:Mode-FG'
        and M.db.player.backgroundTexture=='media:Mode-BG' and M.db.player.barBackgroundOpacity==85 and M.db.player.powerBackgroundOpacity==85)
    assert(M.db.player.powerHeight==3 and M.db.focus.powerHeight==3 and M.db.player.showShields==true)
    assert(M.db.player.castBar.gap==2 and M.db.focus.castBar.gap==8 and M.db.player.castBar.foregroundTexture=='media:Mode-FG' and M.db.player.castBar.backgroundTexture=='media:Mode-BG')
    assert(M.db.target.matchPlayer==true and M.db.player.matchPlayer==false)
    assert(M.db.player.healthColorMode=='default' and M.db.player.nameColorMode=='class' and M.db.player.portraitRing=='class')
    local PS=M.db.player.texts
    assert(PS.border.content=='name' and PS.border.align=='RIGHT' and PS.border.size==12 and M.db.player.classSoftness==nil,'Class Color Softness retired')
    assert(M.db.player.dropShadow==true and M.db.target.dropShadow==true,'Drop Shadow on by default')
    for _,key in ipairs(M.retiredKeys) do assert(M.frameDefaults.player[key]==nil and M.db.player[key]==nil,'retired: '..key) end
    -- The locked Onyx skin and the Sky, Champagne, Lilac and Frost name colors.
    local function Hex(c) return string.format('%02X%02X%02X',math.floor(c[1]*255+0.5),math.floor(c[2]*255+0.5),math.floor(c[3]*255+0.5)) end
    assert(Hex(O.health)=='131212' and Hex(O.track)=='0A0B0C' and Hex(O.border)=='25282C')
    assert(Hex(M.ACCENT)=='91C6FF' and Hex(M.nameAccents.sky)=='91C6FF' and Hex(M.nameAccents.champagne)=='F2DFB8' and Hex(M.nameAccents.lilac)=='C9BBFF' and Hex(M.nameAccents.frost)=='EAF1F8')
    local ids={};for _,c in ipairs(M.choices.nameColor) do ids[#ids+1]=c.id end
    assert(table.concat(ids,',')=='gradient,sky,champagne,lilac,frost,class,custom')
    assert(M.db.player.liftedShadow==false and M.db.target.mirrorText==true and M.identityKeys.mirrorText and M.db.player.nameLift==nil)
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
    -- Defaults: Portrait Size 165 on the Player and Target (layout version 24), the single text shadow, cast icons on the portrait side.
    assert(M.db.player.portraitScale==165 and M.db.target.portraitScale==165 and M.db.focus.portraitScale==140 and M.db.player.liftedShadow==false and M.db.player.castBar.icon=='near' and M.db.target.castBar.icon=='near')
    -- The geometry below is measured at Portrait Size 165, with the lifted shadow
    -- and far-side cast icons (all still options).
    local function Pin()
        assert(M:SetFrameOption('player','portraitScale',165) and M:SetFrameOption('player','liftedShadow',true))
        assert(M:SetCastOption('player','icon','far') and M:SetCastOption('target','icon','far'))
    end
    Pin()
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
    local r=35+3+5;assert(math.abs(math.sqrt(c1[4]^2+c1[5]^2)-r)<1,'radius: portrait, distance, half a point')
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
    -- (35px out at 135° and 225°, snapped), mirrored to the outer side on the Target.
    local sp,st=M.db.player.status,M.db.target.status
    -- No combat badge by default since layout 27 (owner, November 23, 2026); turned on here to check it.
    assert(sp.restIcon and not sp.combatIcon and sp.combatRing and sp.pulse and not st.combatIcon and not st.restIcon and not st.pulse and not M.db.focus.status.combatIcon)
    assert(M:SetStatusOption('player','combatIcon',true) and M:SetStatusOption('target','combatIcon',true))
    resting=true;FireEvent('PLAYER_UPDATE_RESTING')
    assert(p.restBadge:IsShown() and not p.combatBadge:IsShown() and not t.restBadge:IsShown(),'rested: Player only')
    local rb=Point(p.restBadge);assert(rb[1]=='CENTER' and rb[2]==p.portrait and rb[4]==-25 and rb[5]==25 and p.restBadge.width==20,'top left, on the ring')
    assert(p.restBadge.icon.vertexColor[1]==M.ACCENT[1] and p.restBadge.rim.vertexColor[1]==M.RIM_COLOR[1])
    -- Pulled while running: in combat, nothing targeted that is fighting you. Red ring, pulsing halo.
    combat.player=true;FireEvent('PLAYER_REGEN_DISABLED')
    local cb2=Point(p.combatBadge);assert(p.combatBadge:IsShown() and cb2[4]==-25 and cb2[5]==-25,'bottom left')
    local red=M.db.player.status.ringColor
    assert(p.redRing and p.portrait.ring.layers[2].texture.vertexColor[1]==red[1] and p.portrait.ring.layers[2].texture:IsShown(),'the ring turns red: Specular in red tones')
    assert(p.portrait.halo:IsShown(),'pulled unawares: the ring pulses')
    -- You target it and it fights you: the pulse stops; the ring holds red.
    combat.target,attackable.target=true,true;FireEvent('UNIT_FLAGS','target')
    assert(not p.portrait.halo:IsShown() and p.redRing,'targeted: steady red')
    assert(t.combatBadge:IsShown() and Point(t.combatBadge)[4]==25 and Point(t.combatBadge)[5]==-25 and not t.redRing,'Target: its own badge, outer side; no red ring by default')
    combat.target=false;FireEvent('UNIT_FLAGS','target');assert(p.portrait.halo:IsShown(),'a target that is not fighting you does not count')
    combat.player,combat.target,attackable.target,resting=false,false,false,false;FireEvent('PLAYER_REGEN_ENABLED')
    assert(not p.combatBadge:IsShown() and not p.restBadge:IsShown() and not p.redRing and not p.portrait.halo:IsShown() and not t.combatBadge:IsShown())
    -- Settings: corners, size, mirror; validated.
    resting=true;FireEvent('PLAYER_UPDATE_RESTING')
    assert(M:SetStatusOption('player','restCorner','topRight') and Point(p.restBadge)[4]==25 and Point(p.restBadge)[5]==25)
    assert(M:SetStatusOption('player','badgeSize',25) and p.restBadge.width==26,'even pixel sizes')
    assert(not M:SetStatusOption('player','restCorner','middle') and not M:SetStatusOption('player','badgeSize',60))
    assert(M:SetStatusOption('player','restIcon',false) and not p.restBadge:IsShown())
    assert(M:SetStatusOption('player','restIcon',true) and M:SetStatusOption('player','restCorner','topLeft') and M:SetStatusOption('player','badgeSize',20))
    resting=false;FireEvent('PLAYER_UPDATE_RESTING')
    assert(M:FrameDB('target').status==M.db.target.status,'a matched Target keeps its own status settings')

    -- The default slots (owner): the Player's level in the health bar's bottom left,
    -- clear of the portrait's ring (35px in, 2px past the ring), 1px up; health percent at the right.
    -- A matched Target mirrors them: health on the left, level bottom right.
    local PT,TT=p.texts,t.texts
    local lv=Point(PT.bottomLeft);assert(lv[1]=='BOTTOMLEFT' and lv[2]==p.health and lv[3]=='BOTTOMLEFT' and lv[4]==35 and lv[5]==1 and PT.bottomLeft.justifyH=='LEFT')
    local hv=Point(PT.right);assert(hv[1]=='RIGHT' and hv[2]==p.health and hv[4]==-4 and PT.right:IsShown(),'health percent at the right')
    assert(not PT.center:IsShown() and not PT.powerCenter:IsShown() and PT.center:GetText()=='','empty slots hide')
    local tlv=Point(TT.bottomRight);assert(tlv[1]=='BOTTOMRIGHT' and tlv[2]==t.health and tlv[4]==-35 and tlv[5]==1,'Target: level bottom right, clear of its portrait')
    assert(Point(TT.left)[1]=='LEFT' and Point(TT.left)[2]==t.health and Point(TT.left)[4]==4 and TT.left:IsShown() and not TT.right:IsShown(),'Target: health on the left')
    assert(M:SetTextOption('player','bottomLeft','x',-6) and Point(PT.bottomLeft)[4]==35,'never into the portrait')
    assert(Point(TT.bottomRight)[4]==-35 and M:SetTextOption('player','bottomLeft','x',5) and Point(PT.bottomLeft)[4]==40 and Point(TT.bottomRight)[4]==-40,'mirrored offsets')
    assert(M:SetTextOption('player','bottomLeft','x',0))
    -- Changing the width moves nothing out of place: every text keeps its anchor on the health bar.
    assert(M:SetFrameOption('player','barWidth',240) and p.width==60+240+2)
    assert(Point(PT.right)[2]==p.health and Point(PT.right)[4]==-4 and Point(PT.bottomLeft)[2]==p.health and Point(PT.bottomLeft)[4]==35,'texts stay on their sides')
    assert(Point(PT.border)[2]==p.health and Point(PT.border,2)[2]==p.health,'the name spans the wider bar')
    assert(M:SetFrameOption('player','barWidth',184))

    -- Cast bars (docs/DESIGN_LANGUAGE.md): a frameThin block 2px under the bar
    -- block (clear of both shadow rings: 4px), its far end lined up with the
    -- block's; with a portrait it starts where the ring ends (radius 35).
    local pc,tex=p.castBox,function(key) return (addon.Media:GetTexture(key)) end
    assert(pc and not pc:IsShown() and PlayerCastingBarFrame:GetAlpha()==0 and TargetFrameSpellBar:GetAlpha()==0 and FocusFrameSpellBar:GetAlpha()==0)
    local cp1,cp2=Point(pc),Point(pc,2)
    assert(cp1[1]=='TOPLEFT' and cp1[2]==p.panel and cp1[3]=='BOTTOMLEFT' and cp1[4]==35 and cp1[5]==-4 and cp2[1]=='TOPRIGHT' and cp2[3]=='BOTTOMRIGHT' and cp2[4]==0)
    assert(pc.clear==35,'starts where the ring ends')
    assert(pc.height==14+2 and pc.depth==1 and pc.edge.def==addon.Style.EDGE_PRESETS.frameThin,'14px inside a 1px frameThin border')
    assert(pc.gap.vertexColor[1]==0 and Point(pc.gap)[2]==pc.inner,'black inside the rim')
    local cb1,cb2=Point(pc.bar),Point(pc.bar,2)
    assert(cb1[1]=='TOPLEFT' and cb1[4]==1 and cb1[5]==-1,'bar one rim in from the box')
    assert(cb2[1]=='BOTTOMRIGHT' and cb2[4]==-(1+14+1) and cb2[5]==1,'the icon at the far end, a pixel apart')
    local ic=Point(pc.icon);assert(ic[1]=='RIGHT' and ic[4]==-1 and pc.icon.width==14 and pc.icon.height==14)
    assert(pc:GetFrameLevel()<p.portrait:GetFrameLevel(),'the portrait ring caps it')
    assert(pc.edge.holder:GetFrameLevel()>pc.bar:GetFrameLevel(),'the border over its bar')
    assert(pc.comet and Point(pc.comet.head)[2]==pc.bar:GetStatusBarTexture() and pc.comet.head.width==10,'the Comet spark on the fill edge')
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
    assert(Point(tcb.bar)[1]=='TOPRIGHT' and Point(tcb.bar)[4]==-1 and Point(tcb)[4]==-35 and Point(tcb.icon)[1]=='LEFT','mirrored on the Target')
    -- Settings: position, icon side, Blizzard's bar; validated; per frame even while matched.
    assert(M:SetCastOption('player','position','above') and Point(pc)[1]=='BOTTOMLEFT' and Point(pc)[3]=='TOPLEFT' and Point(pc)[5]==4)
    assert(M:SetCastOption('player','icon','near') and Point(pc.icon)[1]=='LEFT' and Point(pc.icon)[4]==1 and Point(pc.bar)[4]==1+14+1)
    assert(M:SetCastOption('player','icon','none') and not pc.icon:IsShown() and Point(pc.bar,2)[4]==-1)
    assert(M:SetCastOption('player','gap',40) and Point(pc)[4]==35,'with a portrait it starts where the ring ends at any gap')
    assert(M:SetCastOption('player','gap',2) and M:SetFrameOption('player','showPortrait',false) and Point(pc)[4]==0 and Point(pc.bar)[4]==1)
    assert(M:SetFrameOption('player','showPortrait',true))
    assert(M:SetCastOption('player','hideBlizzard',false) and PlayerCastingBarFrame:GetAlpha()==1)
    -- Blizzard's interrupt hold is an Alpha animation on the bar itself, which
    -- would override the fade: while faded it runs from 0 to 0. A child's stays.
    local function Alpha(target,from,to)
        local a={target=target,from=from,to=to}
        function a:GetObjectType() return 'Alpha' end
        function a:GetTarget() return self.target end
        function a:GetFromAlpha() return self.from end
        function a:GetToAlpha() return self.to end
        function a:SetFromAlpha(v) self.from=v end
        function a:SetToAlpha(v) self.to=v end
        return a
    end
    local hold,fade,child=Alpha(PlayerCastingBarFrame,1,1),Alpha(PlayerCastingBarFrame,1,0),Alpha({},0,1)
    local holdGroup={GetAnimations=function() return hold,fade,child end}
    PlayerCastingBarFrame.GetAnimationGroups=function() return holdGroup end
    assert(M:SetCastOption('player','hideBlizzard',true) and hold.from==0 and hold.to==0 and fade.from==0 and fade.to==0,'muted while faded')
    assert(child.from==0 and child.to==1,'animations on children keep their alpha')
    assert(M:SetCastOption('player','hideBlizzard',false) and hold.from==1 and hold.to==1 and fade.from==1 and fade.to==0,'restored when shown')
    assert(not M:SetCastOption('player','height',99) and not M:SetCastOption('player','icon','top') and not M:SetCastOption('player','bogus',1))
    assert(M:FrameDB('target').castBar==M.db.target.castBar and M.db.target.matchPlayer,'a matched Target keeps its own cast bar')
    assert(M:ResetFrame('player') and M.db.player.castBar.position=='below' and PlayerCastingBarFrame:GetAlpha()==0,'reset restores it')
    Pin()
    assert(M:SetCastOption('target','enabled',false) and TargetFrameSpellBar:GetAlpha()==1 and M:SetCastOption('target','enabled',true))
    assert(M.db.targettarget.castBar.enabled==false and M.db.focus.castBar.enabled==true)
    assert(M.db.focus.castBar.gap==8 and M.db.player.castBar.gap==2 and M.db.player.castBar.fullWidth,'the Focus cast bar sits 8px off; full width')
    -- Bar Width: centred under the bar span, that wide.
    assert(M:SetCastOption('player','fullWidth',false) and M:SetCastOption('player','width',120) and p.castBox.width==120 and Point(p.castBox)[1]=='TOP')
    assert(M:SetCastOption('player','fullWidth',true) and #p.castBox.points==2,'full width again: both ends')

    -- Auras: buffs on the Target by default, debuffs off; each group its own settings.
    assert(M.db.target.buffs.enabled and not M.db.target.debuffs.enabled and not M.db.player.buffs.enabled and not M.db.focus.buffs.enabled)
    units.target.helpful={{icon=136078,auraInstanceID=1,applications=3,duration=10,expirationTime=20},{icon=136090,auraInstanceID=2}}
    units.target.harmful={{icon=136207,auraInstanceID=3,dispelName='Magic'}}
    FireEvent('UNIT_AURA','target')
    local b1,b2=t.auraIcons.buffs[1],t.auraIcons.buffs[2]
    assert(b1:IsShown() and b2:IsShown() and t.auraShown.buffs==2 and t.auraShown.debuffs==0 and auraFilters[#auraFilters]=='HELPFUL')
    assert(b1.icon.texture==136078 and b1.count:GetText()=='3' and b1.cooldown.cooldownStart==10 and b1.edge.preset=='frameThin' and b1.edge.tint==nil and b1.rim.vertexColor[1]==addon.Style.Tone.metal.obsidian.deep[1] and b1.edge.styleId=='obsidian','auras wear the frameThin edge in Mode-Border')
    -- Border Style and Border Metal (owner, November 17, 2026): Mode-Border in
    -- its own metal by default, frame and cast bar together; any style keeps
    -- the layout; an old style id (Mode-Round) draws as Mode-Border.
    assert(M.db.player.edgeStyle=='obsidian' and M.db.player.edgeMetal=='default' and p.panel.edge.styleId=='obsidian'
        and p.panel.edge:Metal()==addon.Style.Tone.metal.obsidian and p.castBox.edge.styleId=='obsidian','frames in Mode-Border')
    local before=p.geometry.width
    assert(M:SetFrameOption('player','edgeStyle','obsidianEmpty') and p.panel.edge.styleId=='obsidianEmpty' and p.castBox.edge.styleId=='obsidianEmpty' and p.geometry.width==before,'Mode-Empty, same size')
    assert(M:SetFrameOption('player','edgeStyle','round') and p.panel.edge.styleId=='obsidian','an old id draws as Mode-Border')
    assert(M:SetFrameOption('player','edgeMetal','gunmetal') and p.panel.edge:Metal()==addon.Style.Tone.metal.gunmetal)
    assert(not M:SetFrameOption('player','edgeStyle','nope') and M.db.player.edgeStyle=='round','unknown styles are refused')
    assert(M:SetFrameOption('player','edgeStyle','obsidian') and M:SetFrameOption('player','edgeMetal','default') and p.panel.edge.styleId=='obsidian')
    -- Hover shows the game's tooltip for that aura; a secret ID (combat) shows none.
    function GameTooltip:SetOwner(owner) self.owner=owner end
    function GameTooltip:GetOwner() return self.owner end
    function GameTooltip:SetUnitBuffByAuraInstanceID(unit,id) if issecretvalue(id) then error('secret id') end self.aura={unit,id,'buff'} end
    function GameTooltip:SetUnitDebuffByAuraInstanceID(unit,id) self.aura={unit,id,'debuff'} end
    assert(b1.scripts.OnEnter and b1.mouse,'icons take the mouse')
    b1.scripts.OnEnter(b1);assert(GameTooltip:IsShown() and GameTooltip.owner==b1 and GameTooltip.aura[1]=='target' and GameTooltip.aura[2]==1 and GameTooltip.aura[3]=='buff')
    b1.scripts.OnLeave(b1);assert(not GameTooltip:IsShown())
    b1.auraID=Secret('id');b1.scripts.OnEnter(b1);assert(not GameTooltip:IsShown(),'no empty tooltip for a hidden aura');b1.auraID=1
    -- Top right, the Target's portrait side: the row starts past the ring (its 33px
    -- tuck over the bars, plus 2), 22px cropped icons growing left. The mirrored
    -- Target's name is on its left, so the row sits right on the bar block.
    local clear=-(33+2)
    assert(Point(b1)[1]=='BOTTOMRIGHT' and Point(b1)[2]==t.health and Point(b1)[3]=='TOPRIGHT' and Point(b1)[4]==clear and Point(b1)[5]==2+2,'on the bar block, clear of the ring')
    -- With the name on the right too, the row sits over the name instead of on it.
    assert(M:SetTextOption('player','border','align','LEFT'))
    local q=Point(b1);assert(q[5]==(2+1)+14+2,'over the name just above the border')
    local h=b1.height
    assert(b1.width==22 and h<22 and Point(b2)[4]==clear-(22+2) and Point(b2)[5]==q[5],'cropped, growing left')
    assert(M:SetAuraOption('target','buffs','perRow',1) and Point(b2)[4]==clear and Point(b2)[5]==q[5]+h+2,'a new row above')
    assert(M:SetAuraOption('target','buffs','shape','square') and b1.height==22 and M:SetAuraOption('target','buffs','perRow',5))
    assert(M:SetAuraOption('target','buffs','filter','mine') and auraFilters[#auraFilters]=='HELPFUL|PLAYER')
    assert(M:SetAuraOption('target','buffs','max',1) and not b2:IsShown() and M:ResetFrame('target') and b2:IsShown(),'reset restores the auras')
    assert(M:SetTextOption('player','border','align','RIGHT'))
    -- Debuffs: under the bars, past the cast bar below them; rims by dispel type.
    assert(M:SetAuraOption('target','debuffs','enabled',true));local d1=t.auraIcons.debuffs[1]
    assert(d1:IsShown() and d1.rim.vertexColor[3]==M.dispelColors.Magic[3])
    local dq=Point(d1);assert(dq[1]=='TOPRIGHT' and dq[2]==t.power and dq[5]==-(2+2+2+2+14+2),'below the cast bar (its 2px gap clear of both shadow rings)')
    assert(M:SetCastOption('target','position','above') and Point(d1)[5]==-(2+2) and M:SetCastOption('target','position','below'))
    assert(M:SetAuraOption('target','debuffs','border','mode') and d1.edge.tint==nil,'Mode: the Gunmetal metal')
    assert(not M:SetAuraOption('target','debuffs','anchor','MIDDLE') and not M:SetAuraOption('target','debuffs','size',99) and not M:SetAuraOption('target','nope','size',20))
    assert(M:FrameDB('target').buffs==M.db.target.buffs,'a matched Target keeps its own auras')
    assert(M:SetAuraOption('target','debuffs','enabled',false) and not d1:IsShown())
    units.target.helpful,units.target.harmful=nil,nil;FireEvent('UNIT_AURA','target');assert(not b1:IsShown())
    -- The Player frame's auras moved to Buffs & Debuffs: none draw here, whatever its saved settings say.
    assert(M:SetAuraOption('player','debuffs','enabled',true));units.player.harmful={{icon=136207,auraInstanceID=9,dispelName='Magic'}}
    FireEvent('UNIT_AURA','player');assert(M.frames.player.auraShown.debuffs==0 and not M:ShowsAuras('player') and M:ShowsAuras('target'),'no Player auras')
    units.player.harmful=nil;assert(M:SetAuraOption('player','debuffs','enabled',false))

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
    assert(d.barWidth==130 and d.healthHeight==22 and d.texts.bottomLeft.content=='none' and d.scale==75 and d.showPortrait==false and d.texts.left.content=='name' and d.texts.border.content=='none')
    assert(d.texts.left.size==11 and d.texts.right.content=='healthPercent' and d.texts.right.size==10)
    assert(M.db.focustarget.scale==75 and M.db.focustarget.attach and M.db.focustarget.showPortrait==false)
    assert(M.db.focus.scale==90 and M.db.focus.barWidth==160 and M.db.focus.showPortrait==false and M.db.focus.texts.left.content=='name' and not M.db.focus.attach)
    assert(not M.db.focus.matchPlayer and not d.matchPlayer)
    assert(tt.scale==0.75 and fo.scale==0.9 and not tt.portrait:IsShown() and not tt.texts.bottomLeft:IsShown(),'small frames')
    assert(tt.panel.edge.def==addon.Style.EDGE_PRESETS.frameThin and p.panel.edge.def==addon.Style.EDGE_PRESETS.frame,'small frames: the 1px frameThin border')
    local tn=Point(tt.texts.left);assert(tn[1]=='LEFT' and tn[2]==tt.health and tn[4]==4 and tt.texts.left.justifyH=='LEFT' and tt.texts.left.width==130*0.6,'name in the bar, on the left')
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
    Advance(0.05);assert(Plain(tt.texts.left:GetText())~='Totfix','waits for the timer')
    Advance(0.06);assert(Plain(tt.texts.left:GetText())=='Totfix' and tt.texts.right:GetText()=='50%','refreshed on the timer')
    units.focus={exists=true,health=50,max=100,power=20,powerMax=100,token='MANA',name='Focusfix',level=30,reaction=5,connected=true}
    FireEvent('PLAYER_FOCUS_CHANGED');assert(Plain(fo.texts.left:GetText())=='Focusfix' and fo.texts.right:GetText()=='50%')
    units.focus.health=25;FireEvent('UNIT_HEALTH','focus');assert(fo.texts.right:GetText()=='25%','focus unit events')
    units.targettarget.name='Swapped';FireEvent('UNIT_TARGET','target');assert(Plain(tt.texts.left:GetText())=='Swapped','new target of target at once')
    assert(M:SetFrameOption('targettarget','enabled',false) and M.poller:IsShown(),'the Target of Focus still needs the timer')
    assert(M:SetFrameOption('focustarget','enabled',false) and not M.poller:IsShown(),'no timer without them')
    assert(M:SetFrameOption('targettarget','enabled',true) and M:SetFrameOption('focustarget','enabled',true) and M.poller:IsShown())
    units.targettarget,units.focus=nil,nil

    -- The Mode frame (docs/DESIGN_LANGUAGE.md): the bar block in its 2px Mode Frame
    -- border, the portrait's Steel Sheen ring centred on its edge, 1px line between bars.
    local mg=p.geometry
    -- px=1: block = 34 health + 1 + 3 power + 2*2 rim = 42; the ring is 165% of the
    -- block (70: a 66px portrait in a 2px ring), the block centred 14 down.
    assert(mg.px==1 and mg.border==2 and mg.line==0 and mg.gap==1 and mg.pad==2)
    assert(mg.healthHeight==34 and mg.blockHeight==42 and mg.portrait==70 and mg.height==70 and mg.blockY==14 and mg.portraitY==0)
    -- The frame keeps the Onyx frame's width; the bars run under the ring from one rim in.
    assert(mg.blockStart==35 and mg.inset==37 and mg.width==246 and mg.tuck==33 and mg.barsTop==16)
    assert(p.width==246 and p.height==70)
    local pp=Point(p.panel);assert(pp[1]=='TOPLEFT' and pp[4]==35 and pp[5]==-14,'bar block starts under the ring centre')
    local pb=Point(p.panel,2);assert(pb[1]=='BOTTOMRIGHT' and pb[5]==14)
    -- The border: the frame preset round the bars' area one rim in; its corners cover
    -- the bars' square corners (no masks).
    local S=addon.Style
    assert(p.panel.edge.def==S.EDGE_PRESETS.frame and p.panel.edge.host==p.panel.inner and Point(p.panel.inner)[4]==2 and Point(p.panel.inner)[5]==-2)
    assert(p.panel.edge.holder:GetFrameLevel()>p.health:GetFrameLevel() and p.panel.edge.holder:GetFrameLevel()<p.portrait:GetFrameLevel(),'border over the bars, under the ring')
    assert(p.portrait.ring and p.portrait.icon==p.portrait.ring.portrait and p.portrait.width==70,'the portrait in its ring')
    assert(Point(p.portrait)[1]=='TOPLEFT' and Point(p.portrait)[4]==0 and Point(t.portrait)[1]=='TOPRIGHT','ring centred on the block edge, mirrored on the Target')
    -- Mode-FG health and power over Mode-BG on Slate.
    -- Textures with a lift draw their base, with the white lift over the fill.
    local Base=S.AssetPath
    assert(p.health.statusBarTexture==Base('FGBase') and p.power.statusBarTexture==Base('FGBase'),'Mode textures')
    assert(p.health.sheen:IsShown() and p.health.sheen.texture==Base('FGLift') and p.power.sheen.texture==Base('FGLift'),'the lifts')
    assert(Point(p.health.sheen)[2]==p.health.fillTexture and p.health.sheen.vertexColor[1]==1,'the lift follows the fill, white')
    for _,bar in ipairs({p.health,p.power}) do
        assert(bar.bg.vertexColor[1]==S.Tone.slate[1] and math.abs(bar.bg.vertexColor[4]-0.85)<1e-6,'Mode-BG on Slate, see-through')
        assert(bar.fillTexture.drawLayer=='ARTWORK','fill drawn above the track')
    end
    assert(p.panel.back.vertexColor[4]==0,'no black plate behind see-through empty bars')
    local d=M.db.player
    assert(d.barForegroundOpacity==100 and d.barBackgroundOpacity==85)
    assert(M:SetFrameOption('player','barBackgroundOpacity',100) and p.panel.back.vertexColor[4]==0,'power still see-through')
    assert(M:SetFrameOption('player','powerBackgroundOpacity',100) and p.panel.back.vertexColor[4]==1,'solid bars keep the plate')
    assert(M:SetFrameOption('player','backgroundTexture','flat') and p.health.bg.vertexColor[1]==O.track[1] and p.health.bg.texCoord[2]==1)
    assert(M:SetFrameOption('player','backgroundTexture','media:Mode-BG') and not M:SetFrameOption('player','foregroundTexture','slate'))
    -- Combined shields on health (Style.Shield).
    assert(p.health.shield and p.health.shield.bar==p.health and p.health.shield.clip:IsShown())
    assert(M:SetFrameOption('player','showShields',false) and not p.health.shield.clip:IsShown() and M:SetFrameOption('player','showShields',true))
    -- Bar Shows: Mana (owner, November 19, 2026): the bar shows the unit's mana
    -- (the mana type, whatever power shows now), in the mana color, no shields;
    -- health texts keep health, power texts show the mana; a matched Target keeps health.
    assert(M.db.player.barShows=='health' and M.ownKeys.barShows and not M:SetFrameOption('player','barShows','rage'))
    units.player.mana,units.player.manaMax=300,600
    assert(M:SetFrameOption('player','barShows','mana') and M:FrameDB('target').barShows=='health','the matched Target keeps health')
    M:Update('player')
    local lo,hi=p.health:GetMinMaxValues();assert(lo==0 and hi==600 and p.health:GetValue()==300,'mana on the bar, not energy')
    local mana=addon.Style.Tone.powerType.MANA;assert(p.health.fillColor==mana,'the mana color')
    assert(not p.health.shield.clip:IsShown(),'no shields on a mana frame')
    units.player.health=100;M:UpdateHealth('player');assert(p.health:GetValue()==300,'health leaves the bar alone')
    units.player.mana=Secret('m');units.player.manaMax=Secret('mm');M:UpdatePower('player')
    assert(p.health:GetValue()==units.player.mana,'secret mana passes straight to the bar')
    units.player.mana,units.player.manaMax,units.player.health=nil,nil,900
    assert(M:SetFrameOption('player','barShows','health'));M:Update('player')
    assert(p.health:GetValue()==900 and p.health.fillColor~=mana and p.health.shield.clip:IsShown(),'health again')
    -- The end of the health fill gets a 1px light line, on the side it fills toward.
    local fe=p.health.fillEdge;assert(fe and fe:IsShown() and fe.width==1 and Point(fe)[1]=='TOPRIGHT' and Point(fe)[2]==p.health.fillTexture)
    assert(Point(t.health.fillEdge)[1]=='TOPLEFT','reverse fill: on the left')
    -- A full bar shows no line: it lives in a clip frame that stops 1px short of the bar's end.
    local clip=p.health.fillEdgeClip;assert(clip.clipsChildren and fe:GetParent()==clip and Point(clip,2)[1]=='BOTTOMRIGHT' and Point(clip,2)[4]==-1)
    assert(Point(t.health.fillEdgeClip)[4]==1 and Point(t.health.fillEdgeClip,2)[4]==0,'reverse: 1px short on the left')
    assert(M:SetFrameOption('player','fillEdge',false) and not fe:IsShown() and M:SetFrameOption('player','fillEdge',true) and fe:IsShown())
    local hl=p.panel.hairline;assert(hl:IsShown() and hl.vertexColor[1]==addon.Style.Tone.shadow[1] and hl.vertexColor[4]==1 and Point(hl)[2]==p.health and Point(hl,2)[2]==p.power,'solid hairline')
    local mhp=Point(p.health);assert(mhp[1]=='TOPLEFT' and mhp[2]==p.panel.inner and mhp[4]==0 and mhp[5]==0 and p.health.height==34)
    -- Fill direction: the Target fills and drains the other way from the Player, even while matched.
    assert(M.db.player.fillDirection=='standard' and M.db.target.fillDirection=='reverse' and M.identityKeys.fillDirection)
    assert(p.health.reverseFill==false and p.power.reverseFill==false and t.health.reverseFill==true and t.power.reverseFill==true)
    assert(M:SetFrameOption('player','fillDirection','reverse') and p.health.reverseFill==true and t.health.reverseFill==true,'own setting, not copied from the Player')
    assert(M:SetFrameOption('target','fillDirection','standard') and t.health.reverseFill==false and not M:SetFrameOption('target','fillDirection','up'))
    assert(M:SetFrameOption('player','fillDirection','standard') and M:SetFrameOption('target','fillDirection','reverse'))
    assert(Point(p.power)[5]==-1 and p.power.height==3,'3px power, 1px line between health and power')
    local cap=Point(p.portrait);assert(cap[1]=='TOPLEFT' and cap[4]==0 and cap[5]==0 and p.portrait.width==70)
    assert(Point(t.portrait)[1]=='TOPRIGHT')
    local ring=p.portrait
    -- The ring sits above the bars and the border, so its whole circle is drawn over the block's end.
    assert(ring:GetFrameLevel()>p.health:GetFrameLevel() and ring:GetFrameLevel()>p.panel.edge.holder:GetFrameLevel(),'ring over the block end')
    assert(ring.ring.disc.texture==addon.Style.AssetPath('Circle') and #ring.ring.layers==3 and ring.ring.layers[2].texture.texture==addon.Style.AssetPath('Ringorh') and ring.ring.shadow.vertexColor[4]==addon.Style.Tone.shadowAlpha,'Mode-Border ring (lit top, deeper bottom) with its shadow ring')
    local line=ring.ring.line
    assert(Point(line)[4]==2 and Point(line)[5]==-2 and line.vertexColor[1]==0 and line.vertexColor[2]==0 and line.vertexColor[3]==0,'the 1px black line, the band inner pixel')
    assert(Point(ring.icon)[4]==3 and Point(ring.icon)[5]==-3 and ring.ring.mask,'the whole portrait 3px in, cut round')
    assert(p.nameClip==nil and p.nameShine==nil and p.panel.ringBorder==nil)
    assert(p.textLayer:GetFrameLevel()>ring:GetFrameLevel(),'text above the portrait')
    -- On the Border (default): the baseline on the top rim's middle (bottom = 2 - 1 - 3
    -- descent = -2), clear of the ring at its height (31 in from the bars' start).
    local np=Point(p.texts.border);assert(np[1]=='BOTTOMLEFT' and np[2]==p.health and np[4]==28 and np[5]==3 and p.texts.border.justifyH=='RIGHT','name just above the border (1px over the block)')
    assert(p.texts.border.font[1]:find('Urbanist%-SemiBold') and p.texts.right.font[1]:find('Urbanist%-Bold'),'Urbanist: names on the border in SemiBold, text in the bars in Bold')
    assert(t.texts.border.justifyH=='LEFT','the mirrored Target has its name on the left')
    -- Mirror Player Text off: the Player's slots as they are, each clear of the Target's own portrait.
    assert(M:SetFrameOption('target','mirrorText',false) and t.texts.border.justifyH=='RIGHT' and not t.texts.left:IsShown())
    local th=Point(t.texts.right);assert(th[1]=='RIGHT' and th[2]==t.health and th[4]==-35,'health on the right, like the Player, clear of the ring')
    local tl=Point(t.texts.bottomLeft);assert(tl[1]=='BOTTOMLEFT' and tl[4]==4 and tl[5]==1,'level bottom left, away from the portrait')
    -- The name clears the ring at its own height: on the border, 28px in from the bars (just above the border the ring curves away).
    assert(Point(t.texts.border,2)[4]==-28 and Point(p.texts.border,2)[4]==0,'name clear of the portrait at its own height')
    assert(M:SetFrameOption('target','mirrorText',true) and Point(t.texts.border)[4]==0 and Point(t.texts.border,2)[4]==-28)
    assert(p.texts.bottomLeft.color[1]==P.muted[1],'the level muted by default')
    -- Bar text never reaches the portrait: 2px before the ring's outer edge across
    -- its own line (at the bars' middle: 35 + 35 + 2 - 37 = 35 from the bars' start),
    -- and an X offset toward the portrait stops there.
    assert(M:SetTextOption('player','left','content','healthCurrent') and Point(p.texts.left)[4]==35,'a left text at the clearance')
    assert(M:SetTextOption('player','left','x',-9) and Point(p.texts.left)[4]==35,'an offset into the ring stops at the line')
    assert(M:SetTextOption('player','left','x',5) and Point(p.texts.left)[4]==40,'away from the portrait it moves freely')
    assert(M:SetTextOption('player','left','x',0) and M:SetTextOption('player','left','content','none'))
    -- Top slots sit 1px under the bar's top, also clear of the ring across their line.
    assert(M:SetTextOption('player','topLeft','content','name'))
    local tp=Point(p.texts.topLeft);assert(tp[1]=='TOPLEFT' and tp[2]==p.health and tp[5]==-1 and tp[4]>=35,'top left, under the bar top')
    -- Each text shows once per frame: picking it for a spot clears its old spot.
    assert(M.db.player.texts.border.content=='none' and not p.texts.border:IsShown() and Plain(p.texts.topLeft:GetText())=='Fixture','moved, not copied')
    assert(M:SetTextOption('player','border','content','name') and M.db.player.texts.topLeft.content=='none' and not p.texts.topLeft:IsShown())
    assert(M.db.player.texts.right.content=='healthPercent' and M:SetTextOption('player','left','content','level') and M.db.player.texts.bottomLeft.content=='none')
    assert(M:SetTextOption('player','bottomLeft','content','level') and M.db.player.texts.left.content=='none','other texts stay put')
    assert(M:SetTextOptions('player','right',{colorMode='custom',color={0,1,0}}) and p.texts.right.color[2]==1 and M:SetTextOption('player','right','colorMode','default'),'several settings in one change')
    -- Texts colored by the unit: Reaction, Class Color, and Level Difficulty for the level.
    assert(M:SetFrameOption('target','matchPlayer',false))
    local TL=t.texts.bottomRight
    assert(M:SetTextOption('target','bottomRight','colorMode','reaction') and TL.color[1]==M:IdentityColor('target',true)[1] and TL.color[2]==M:IdentityColor('target',true)[2],'a hostile level in red')
    assert(M:SetTextOption('target','bottomRight','colorMode','difficulty') and TL.color[1]==P.hostile[1] and TL.color[2]==P.hostile[2],'a skull level: red')
    assert(M:SetTextOption('target','right','colorMode','class') and t.texts.right.color[1]==M:IdentityColor('target')[1],'an NPC by reaction')
    assert(M:SetTextOption('target','border','colorMode','difficulty') and t.texts.border.color[1]==M:NameColor('target')[1],'difficulty does not suit a name: its default color')
    units.target.reaction=5;FireEvent('UNIT_FACTION','target');assert(TL.color[1]==P.hostile[1],'skull stays red')
    assert(M:SetTextOption('target','bottomRight','colorMode','reaction') and TL.color[2]==M:IdentityColor('target',true)[2],'repainted when the reaction changes')
    assert(math.abs(TL.color[2]-P.green[2])<1e-9,'friendly now, the true color')
    units.target.reaction=2;FireEvent('UNIT_FACTION','target')
    GetCreatureDifficultyColor=function() return {r=0.25,g=0.75,b=0.25} end
    assert(M:SetTextOption('player','bottomLeft','colorMode','difficulty') and p.texts.bottomLeft.color[2]==0.75,'your own level by difficulty')
    GetCreatureDifficultyColor=nil;M:UpdateAll();assert(p.texts.bottomLeft.color[1]==P.muted[1],'unknown difficulty: the default color')
    assert(M:SetTextOption('player','bottomLeft','colorMode','default') and not M:SetTextOption('player','bottomLeft','colorMode','rainbow'))
    assert(M:ResetFrame('target') and M:SetFrameOption('target','matchPlayer',true))
    assert(M:SetTextOption('player','powerLeft','content','powerPercent'))
    -- The power line sits under the ring's centre, where the ring still reaches out
    -- almost its full radius: 34 in from the bars' start.
    assert(Point(p.texts.powerLeft)[1]=='LEFT' and Point(p.texts.powerLeft)[2]==p.power and Point(p.texts.powerLeft)[4]==34,'the power text measured across its own line')
    assert(M:SetTextOption('player','powerLeft','y',-12) and Point(p.texts.powerLeft)[4]<34,'lower, where the ring has curved away, it can sit closer')
    assert(M:SetTextOption('player','powerLeft','y',0) and M:SetTextOption('player','powerLeft','content','none'))
    assert(not M:SetTextOption('player','powerLeft','content','mana') and not M:SetTextOption('player','middle','size',10) and not M:SetTextOption('player','left','size',40),'validated')
    assert(not M:SetTextOption('player','left','align','LEFT'),'only the border text has an alignment')

    -- Names default to the solid class color (Mode-Obsidian); Gradient is a choice.
    assert(M.defaults.player.nameColorMode=='class' and M.defaults.focus.prismGlow=='always' and M.defaults.player.prismGlow=='hover','Mode-Obsidian defaults')
    assert(M:SetFrameOption('player','nameColorMode','gradient'))
    M:UpdateAll()
    local function Near(a,b) return math.abs(a-b)<1e-9 end
    local rc=addon.ClassColors:GetColor('ROGUE');local rogue={rc.r,rc.g,rc.b}
    -- Dark health on the Player; the Target's in its class or reaction color, its own even while it matches the Player.
    local tc=M:IdentityColor('target')
    assert(p.health.statusBarColor[1]==S.Tone.darkFill[1] and tc and Near(t.health.statusBarColor[1],tc[1]) and Near(t.health.statusBarColor[3],tc[3]),'Dark Player health, class-colored Target by default')
    assert(M.db.target.matchPlayer and M:FrameDB('target').healthColorMode=='class' and M:FrameDB('player').healthColorMode=='default','the Target keeps its own health color while matched')
    -- Gradient names (docs/DESIGN_LANGUAGE.md): each letter from the class color toward white.
    local name=p.texts.border:GetText()
    assert(Plain(name)=='Fixture' and name:find('^|cff') and name~='Fixture' and p.texts.border.color[1]==1,'Gradient names, letter by letter')
    assert(name:sub(1,10)=='|cff'..string.format('%02x%02x%02x',math.floor(rogue[1]*255+0.5),math.floor(rogue[2]*255+0.5),math.floor(rogue[3]*255+0.5)),'starting at the class color')
    assert(t.texts.border.text.label=='name','secret target name passed straight to SetText')
    -- The suite's text style: every text has an opaque one-pixel shadow and a lifted
    -- shadow (one translucent black copy 2px down-right); a glowing text (the
    -- name and health, switched on; off by default in Mode-Obsidian) has neither:
    -- the glow takes their place.
    local px=p.geometry.px
    assert(not M.defaults.player.nameTextGlow and not M.defaults.player.healthTextGlow,'no text glow by default')
    assert(M:SetFrameOption('player','nameTextGlow',true) and M:SetFrameOption('player','healthTextGlow',true))
    for _,text in ipairs({p.texts.border,p.texts.right}) do
        assert(text.halo and text.halo.on and text.shadowColor[4]==0 and not text.lift:IsShown(),'the glow replaces the shadows')
    end
    assert(M:SetFrameOption('player','nameTextGlow',false) and M:SetFrameOption('player','healthTextGlow',false))
    for _,text in ipairs({p.texts.border,p.texts.bottomLeft,p.texts.right}) do
        local lift,la,lb=text.lift,Point(text.lift,1),Point(text.lift,2)
        assert(text.shadowColor[4]==1 and text.shadowOffset[1]==px and text.shadowOffset[2]==-px,'opaque one-pixel shadow')
        assert(lift:IsShown() and Plain(lift:GetText())==Plain(text:GetText()) and lift.color[1]==0 and lift.color[3]==0 and Near(lift.color[4],M.LIFT_ALPHA),'translucent black copy')
        assert(la[1]=='TOPLEFT' and la[2]==text and la[4]==2*px and la[5]==-2*px,'2px down-right in screen pixels')
        assert(lb[1]=='BOTTOMRIGHT' and lb[2]==text and lb[4]==2*px and lb[5]==-2*px,'covers the text box')
        assert(lift.shadowColor[4]==0 and lift.font[2]==text.font[2] and lift.font[3]=='')
    end
    assert(M:SetFrameOption('player','nameTextGlow',true) and M:SetFrameOption('player','healthTextGlow',true))
    assert(p.texts.border.lift.justifyH=='RIGHT' and not p.texts.powerCenter.lift:IsShown(),'no power text by default, so no lift')
    assert(t.texts.border.lift.text.label=='name' and t.texts.left.lift.text.secret.label=='pct','secret values go straight to the lifts')
    -- Metal: Ring Style in Ring Metal (Mode-Border in its own metal by default);
    -- Class Color is Mode-Border's ring lighting (the color, a lit top, a
    -- deeper bottom) in tones of the true class color (Style.PaintRing).
    local S=addon.Style
    local ob,pr=S.Tone.metal.obsidian,p.portrait.ring
    assert(M.db.player.portraitRing=='class' and Near(pr.disc.vertexColor[1],rogue[1]) and pr.layers[2].texture:IsShown() and pr.styleId=='obsidian','Class Color by default: the ring lighting in the class tones')
    assert(M:SetFrameOption('player','portraitRing','border'))
    assert(M.db.player.portraitRingStyle=='obsidian' and M.db.player.portraitRingMetal=='default')
    assert(pr.styleId=='obsidian' and pr.disc.vertexColor[1]==ob.mid[1] and pr.layers[3].texture:IsShown() and pr.layers[2].texture.vertexColor[1]==ob.hi[1],'Mode-Border in its own metal')
    assert(M:SetFrameOption('player','portraitRingMetal','gunmetal') and pr.disc.vertexColor[1]==S.Tone.metal.gunmetal.mid[1],'Ring Metal')
    assert(M:SetFrameOption('player','edgeMetal','steel') and pr.disc.vertexColor[1]==S.Tone.metal.gunmetal.mid[1],'Border Metal leaves the ring alone')
    assert(M:SetFrameOption('player','edgeMetal','default') and not M:SetFrameOption('player','portraitRingMetal','gold'))
    assert(M:SetFrameOption('player','portraitRingMetal','default') and pr.disc.vertexColor[1]==ob.mid[1],'Default: the style own metal')
    assert(M:SetFrameOption('player','portraitRingStyle','obsidianEmpty') and #pr.layers==1 and pr.disc.vertexColor[1]==ob.mid[1] and not pr.pool[2]:IsShown(),'Mode-Empty: flat')
    assert(M:SetFrameOption('player','portraitRingStyle','round') and pr.styleId=='obsidian' and not M:SetFrameOption('player','portraitRingStyle','none'),'an old id draws as Mode-Border')
    assert(M:SetFrameOption('player','portraitRingStyle','obsidian') and #pr.layers==3)
    assert(M:SetFrameOption('player','portraitRing','class') and Near(pr.disc.vertexColor[1],rogue[1]) and pr.layers[2].texture:IsShown(),'the class tones')
    assert(M:SetFrameOption('player','portraitRingStyle','obsidianEmpty') and #pr.layers==1 and Near(pr.disc.vertexColor[1],rogue[1]),'Mode-Empty: the flat class color')
    assert(M:SetFrameOption('player','portraitRingStyle','obsidian'))
    -- Ring Finish (the Portrait tab): a metal, Class Color or Custom in one choice.
    assert(M.RingFinish(M.db.player)=='class' and M:SetRingFinish('player','steel') and M.db.player.portraitRing=='border' and M.db.player.portraitRingMetal=='steel' and M.RingFinish(M.db.player)=='steel')
    assert(pr.disc.vertexColor[1]==S.Tone.metal.steel.mid[1],'Steel finish')
    assert(M:SetRingFinish('player','custom') and M.RingFinish(M.db.player)=='custom' and M.db.player.portraitRingMetal=='steel')
    assert(M:SetRingFinish('player','default') and M:SetRingFinish('player','class') and not M:SetRingFinish('player','gold'))
    assert(M:SetFrameOption('player','portraitRing','border') and pr.layers[2].texture:IsShown())
    local tc=p.portrait.icon.texCoord
    assert(p.portrait.icon.texture=='portrait:player' and tc[1]==0.16 and tc[2]==0.84 and tc[3]==0.16 and tc[4]==0.84,'the portrait centered, cropped 16% each side')
    assert(p.texts.bottomLeft:GetText()=='60' and p.texts.right:GetText()=='90%')

    -- Colors: health Default/Class/Custom, name Accent/Class/Custom, ring Class/Default/Custom.
    assert(M:SetFrameOption('player','healthColorMode','class') and Near(p.health.statusBarColor[1],rogue[1]),'class health, the true color')
    assert(Near(t.health.statusBarColor[1],P.hostile[1]),'matched target: NPC reaction color')
    assert(M:SetFrameOption('player','healthColorMode','custom') and M:SetFrameOption('player','healthColor',{0,0,1}) and p.health.statusBarColor[3]==1)
    assert(M:SetFrameOption('player','healthColorMode','default') and p.health.statusBarColor[1]==S.Tone.darkFill[1])
    -- Foreground and background opacity and textures, per frame; a matched Target follows the Player.
    assert(p.health.statusBarColor[4]==1 and p.power.statusBarColor[4]==1,'opaque fill by default')
    assert(M:SetFrameOption('player','barForegroundOpacity',50) and p.health.statusBarColor[4]==0.5 and p.power.statusBarColor[4]==1,'the health bar only')
    assert(M:SetFrameOption('player','powerForegroundOpacity',40) and p.power.statusBarColor[4]==0.4 and p.health.statusBarColor[4]==0.5,'the power bar has its own')
    assert(M:SetFrameOption('player','powerBackgroundOpacity',20) and p.power.bg.vertexColor[4]==0.2 and p.health.bg.vertexColor[4]==1)
    assert(M:SetFrameOption('player','powerForegroundTexture','flat') and p.power.statusBarTexture==addon.Kit.FLAT and p.health.statusBarTexture==addon.Style.AssetPath('FGBase'),'power texture its own')
    assert(not M:SetFrameOption('player','powerBackgroundTexture','mode'),'validated')
    assert(M:SetFrameOption('player','powerForegroundTexture','media:Mode-FG') and M:SetFrameOption('player','powerForegroundOpacity',100) and M:SetFrameOption('player','powerBackgroundOpacity',100))
    assert(M:SetCastOption('player','foregroundTexture','flat') and p.castBox.bar.statusBarTexture==addon.Kit.FLAT and p.health.statusBarTexture~=addon.Kit.FLAT,'the cast bar has its own texture')
    assert(not M:SetCastOption('player','backgroundTexture','mode') and M:SetCastOption('player','foregroundTexture','media:Mode-FG'))
    assert(t.health.statusBarColor[4]==0.5,'matched target follows')
    assert(M:SetFrameOption('player','barBackgroundOpacity',0) and p.health.bg.vertexColor[4]==0 and t.health.bg.vertexColor[4]==0)
    assert(not M:SetFrameOption('player','barForegroundOpacity',5) and not M:SetFrameOption('player','barBackgroundOpacity',101),'ranges')
    assert(M:SetFrameOption('player','foregroundTexture','flat') and p.health.statusBarTexture==addon.Kit.FLAT and not p.health.sheen:IsShown())
    assert(not M:SetFrameOption('player','backgroundTexture','mode') and not M:SetFrameOption('player','foregroundTexture','bogus'),'texture choices validated')
    assert(M:SetFrameOption('player','foregroundTexture','mode') and p.health.sheen:IsShown() and p.health.sheen.texture==S.AssetPath('FGLift'),'the older Mode Gradient draws as Mode-FG')
    assert(M:SetFrameOption('player','foregroundTexture','media:Mode Matte') and p.health.sheen:IsShown() and p.health.sheen.texture==S.AssetPath('FGLift'),'an old Mode texture draws as Mode-FG')
    assert(M:SetFrameOption('player','foregroundTexture','media:Mode-BG') and not p.health.sheen:IsShown(),'BG has no lift')
    assert(M:SetFrameOption('player','foregroundTexture','media:Mode-FG') and p.health.sheen.texture==S.AssetPath('FGLift'))
    assert(M:SetFrameOption('player','barForegroundOpacity',100) and M:SetFrameOption('player','barBackgroundOpacity',85) and M:SetFrameOption('player','powerBackgroundOpacity',85))
    assert(M:SetFrameOption('player','showPower',false) and not p.panel.hairline:IsShown() and M:SetFrameOption('player','showPower',true))
    assert(not M:SetFrameOption('player','healthColorMode','palette') and not M:SetFrameOption('player','healthColorMode','reaction'),'only Default, Class Color or Custom')
    assert(M:SetFrameOption('player','nameColorMode','class') and Near(p.texts.border.color[1],rogue[1]))
    assert(M:SetFrameOption('player','nameColorMode','custom') and M:SetFrameOption('player','nameColor',{1,0,0}) and p.texts.border.color[1]==1 and p.texts.border.color[2]==0)
    local L,F=M.nameAccents.lilac,M.nameAccents.frost
    assert(M:SetFrameOption('player','nameColorMode','lilac') and p.texts.border.color[1]==L[1] and p.texts.border.color[3]==L[3] and t.texts.border.color[2]==L[2],'Lilac')
    assert(M:SetFrameOption('player','nameColorMode','frost') and p.texts.border.color[1]==F[1] and p.texts.border.color[2]==F[2],'Frost')
    assert(p.texts.border.lift.color[1]==0 and Near(p.texts.border.lift.color[4],M.LIFT_ALPHA),'the lift stays black whatever the name color')
    local C=M.nameAccents.champagne
    assert(M:SetFrameOption('player','nameColorMode','champagne') and p.texts.border.color[1]==C[1] and p.texts.border.color[3]==C[3],'Champagne')
    assert(M:SetFrameOption('player','nameColorMode','sky') and p.texts.border.color[1]==M.ACCENT[1] and p.texts.border.color[2]==M.ACCENT[2],'Sky')
    assert(not M:SetFrameOption('player','nameColorMode','accent') and not M:SetFrameOption('player','nameColorMode','mist'),'Mist is retired')
    assert(M:SetFrameOption('player','nameColorMode','gradient'),'back to the default Gradient')
    assert(not M:SetFrameOption('player','nameGlow',true) and not M:SetFrameOption('player','nameGlowStrength',50),'glow settings are retired')
    assert(not M:SetFrameOption('player','nameLift',true),'the name-only lift is retired')
    assert(M:SetFrameOption('player','liftedShadow',false) and not p.texts.border.lift:IsShown() and not p.texts.right.lift:IsShown(),'one toggle for every text')
    assert(p.texts.border:IsShown() and p.texts.bottomLeft.shadowColor[4]==1 and p.texts.border.shadowColor[4]==0,'lift off keeps the crisp shadow (the glowing name has none)')
    assert(M:SetFrameOption('player','liftedShadow',true) and not p.texts.border.lift:IsShown() and p.texts.bottomLeft.lift:IsShown())
    assert(M:SetFrameOption('player','shadow',false) and not p.texts.border.lift:IsShown() and not p.texts.right.lift:IsShown(),'the lift needs Text Shadow')
    assert(p.texts.right.shadowColor[4]==0 and p.texts.right.shadowOffset[1]==0)
    assert(M:SetFrameOption('player','shadow',true) and M:SetTextOption('player','border','content','none') and not p.texts.border.lift:IsShown())
    assert(M:SetTextOption('player','border','content','name') and not p.texts.border.lift:IsShown() and Plain(p.texts.border.lift:GetText())=='Fixture')
    assert(M:SetFrameOption('player','outline',true) and p.texts.bottomLeft.lift:IsShown() and p.texts.bottomLeft.lift.font[3]=='OUTLINE' and p.texts.bottomLeft.lift.font[3]=='OUTLINE','lift matches the outlined glyphs')
    assert(M:SetFrameOption('player','outline',false))
    -- Readable Target text (layout 28): outlined slug text, names in Bold, its own while matched.
    local function Face(text) return text.font[1]:match('Urbanist%-(%a+)%.ttf') end
    assert(M.db.target.matchPlayer and M.db.target.outline and M.db.target.slug and M.db.target.boldText and not M.db.player.slug and not M.db.player.boldText,'target defaults')
    assert(M:FrameDB('target').outline==true and M:FrameDB('target').boldText==true and M:FrameDB('player').outline==false,'matched Target keeps its own')
    assert(t.texts.border.font[3]=='OUTLINE' and Face(t.texts.border)=='Bold' and p.texts.border.font[3]=='' and Face(p.texts.border)=='SemiBold','outlined Bold name on the Target only')
    assert(M:SetFrameOption('target','boldText',false) and Face(t.texts.border)=='SemiBold' and M:SetFrameOption('target','boldText',true))
    assert(M:SetTextOption('player','powerCenter','content','powerPercent') and p.texts.powerCenter.lift:IsShown() and p.texts.powerCenter.lift:GetText()=='50%','power text lifts too')
    assert(M:SetTextOption('player','powerCenter','content','none') and not p.texts.powerCenter.lift:IsShown())
    local function Disc(f) return f.portrait.ring.disc.vertexColor end
    local function Mid(f) return f.portrait.ring.layers[1].texture.vertexColor end
    assert(M:SetFrameOption('player','portraitRing','border') and Near(Disc(p)[1],S.Tone.metal.obsidian.mid[1]),'Mode-Border')
    assert(M:SetFrameOption('player','portraitRing','custom') and M:SetFrameOption('player','portraitRingColor',{1,0,1})
        and Mid(p)[1]==1 and Mid(p)[2]==0 and Mid(p)[3]==1,'the ring in the custom color')
    assert(not M:SetFrameOption('player','portraitRing','accent'))
    assert(M:SetFrameOption('player','portraitRing','class'))
    assert(Near(Mid(p)[1],rogue[1]) and not M:SetFrameOption('player','classSoftness',0),'the true class color; Class Color Softness is retired')
    assert(M:SetFrameOption('player','portraitRing','border'))
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
    assert(math.abs(p.width-q.width)<1e-9 and Point(p.health)[2]==p.panel.inner)
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
    assert(M:SetFrameOption('player','showPower',false) and not p.power:IsShown() and p.geometry.blockHeight==34+4 and p.geometry.portrait==62)
    assert(M:SetFrameOption('player','showPower',true))
    assert(M:SetFrameOption('player','portraitScale',200) and p.geometry.portrait==84 and p.geometry.blockY==21)
    assert(M:SetFrameOption('player','portraitScale',100) and p.geometry.portrait==p.geometry.blockHeight and p.geometry.blockY==0)
    assert(M:SetFrameOption('player','portraitScale',165) and p.geometry.portrait==70)
    -- Text slots: any slot shows any text; offsets, size and color are each slot's own.
    assert(M:SetTextOption('player','border','content','none') and M:SetTextOption('player','right','content','name'))
    assert(Point(p.texts.right)[2]==p.health and Point(p.texts.right)[1]=='RIGHT' and Plain(p.texts.right:GetText())=='Fixture' and p.texts.right.width==184*0.6,'the name in the bar, 60% wide at most')
    assert(p.texts.right:GetText()~='Fixture' and t.texts.left.text.label=='name','names keep the Gradient in any slot; the Target mirrors it')
    assert(M:SetTextOption('player','right','content','healthPercent') and p.texts.right:GetText()=='90%' and p.texts.right.width==0)
    assert(M:SetTextOption('player','border','content','levelName'))
    local mu=P.muted;local tag=string.format('|cff%02x%02x%02x',math.floor(mu[1]*255+0.5),math.floor(mu[2]*255+0.5),math.floor(mu[3]*255+0.5))
    assert(p.texts.border:GetText()==tag..'60|r Fixture' and p.texts.border.color[1]==M:NameColor('player')[1],'Level and Name: the level muted, then the name')
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
    assert(M:SetFrameOption('target','mirrorText',false) and Point(t.texts.right)[4]==-35,'toward its portrait an offset stops at the line')
    assert(M:SetFrameOption('target','mirrorText',true))
    assert(M:SetTextOption('player','border','x',3) and M:SetTextOption('player','border','y',4) and Point(p.texts.border)[5]==3+4 and Point(p.texts.border)[4]==27,'a little higher, still clear of the ring')
    assert(M:SetTextOption('player','border','y',11) and Point(p.texts.border)[5]==3+11 and Point(p.texts.border)[4]==15,'higher, where the ring curves away: closer')
    for _,key in ipairs({'x','y'}) do assert(M:SetTextOption('player','border',key,0) and M:SetTextOption('player','right',key,0)) end
    assert(M:SetTextOption('player','bottomLeft','colorMode','custom') and M:SetTextOption('player','bottomLeft','color',{1,0,0}) and M:SetTextOption('player','bottomLeft','size',14))
    assert(p.texts.bottomLeft.color[1]==1 and p.texts.bottomLeft.font[2]==14 and p.texts.right.font[2]==11,'each slot its own color and size')
    assert(M:SetTextOption('player','bottomLeft','colorMode','default') and M:SetTextOption('player','bottomLeft','size',11) and p.texts.bottomLeft.color[1]==P.muted[1])
    assert(M:SetTextOption('player','border','align','CENTER') and p.texts.border.justifyH=='CENTER' and t.texts.border.justifyH=='CENTER' and M:SetTextOption('player','border','align','RIGHT'))

    -- The Target matches the Player (mirrored) until Match Player Frame is turned off.
    assert(M:SetFrameOption('player','barWidth',200) and t.width==60+184+2 and p.width==60+200+2 and t.geometry.inset==p.geometry.inset,'width is each frame own')
    assert(Point(t.portrait)[1]=='TOPRIGHT' and Point(t.panel)[1]=='TOPRIGHT','still mirrored')
    assert(M:SetFrameOption('player','showPower',false) and not t.power:IsShown(),'power bar follows the Player')
    assert(M:SetFrameOption('player','showPower',true) and t.power:IsShown())
    assert(M:SetFrameOption('target','barWidth',300) and t.width==60+300+2,'a matched Target uses its own width')
    assert(M:FrameDB('target').portraitSide=='right' and M:FrameDB('target').barWidth==300 and M:FrameDB('target').healthHeight==M.db.player.healthHeight)
    assert(M:SetFrameOption('target','matchPlayer',false) and t.width==60+300+2,'own settings once unmatched (its own Portrait Size 165, as the Player)')
    assert(M:FrameDB('target')==M.db.target and t.texts.border.justifyH=='RIGHT' and t.texts.right:IsShown() and not t.texts.left:IsShown(),'its own slots')
    assert(M:SetFrameOption('player','barWidth',184) and M:SetFrameOption('target','barWidth',184))

    -- Public player values and portrait.
    M:UpdateAll()
    assert(p.health.value==900 and p.health.high==1000 and p.power.value==50)
    assert(p.texts.right:GetText()=='90%' and Plain(p.texts.border:GetText())=='Fixture' and p.texts.bottomLeft:GetText()=='60')
    assert(M:SetFrameOption('target','healthColorMode','class'))

    -- Secret target values pass straight to widgets and formatters.
    assert(issecretvalue(t.health.value) and t.health.high.label=='max' and t.power.value.label=='p')
    assert(t.texts.right.text.secret.label=='pct' and t.texts.border.text.label=='name')
    assert(t.texts.bottomRight:GetText()=='??+')
    assert(Near(t.health.statusBarColor[1],P.hostile[1]),'NPC reaction color')
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
    assert(p.health.statusBarTexture==addon.Style.AssetPath('FGBase') and p.power.statusBarTexture==addon.Style.AssetPath('FGBase'),'Mode textures on the bars')
    assert(not M:SetFrameOption('player','texture','flat'),'the bar texture is no longer a setting')
    assert(M:SetFrameOption('player','scale',120) and p.scale==1.2)
    assert(M:SetFrameOption('player','barWidth',240) and p.width==60+240+2)

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
    assert(M:ResetFrame('target') and M.db.target.barWidth==184 and M.db.target.healthColorMode=='class' and M.db.target.portraitSide=='right')
    assert(M.db.target.matchPlayer==false,'reset keeps the identity toggle')
    assert(M.db.player.barWidth==240,'reset is per frame')

    -- Edit Mode: stand-ins in the same skin; the secure button copies the anchor.
    local ghost=M.ghosts.player
    assert(not ghost.secure and not ghost:IsShown())
    assert(addon:SetEditMode(true) and ghost:IsShown() and M.ghosts.target:IsShown())
    assert(Plain(ghost.texts.border:GetText())=='Fixture' and ghost.texts.border.color[1]==1,'the player stand-in shows your name, in its Gradient')
    assert(Plain(M.ghosts.target.texts.border:GetText())=='Name','other stand-ins show a sample name, not the frame title')
    local handle=addon.PositionManager.elements.unitFramesPlayer.decoration
    assert(handle and handle.label:GetText()=='Player Frame' and addon.PositionManager.elements.unitFramesTarget.decoration.label:GetText()=='Target Frame','each handle names its frame')
    assert(Plain(ghost.texts.border.lift:GetText())=='Fixture' and ghost.texts.bottomLeft.lift:IsShown() and ghost.texts.border.halo and ghost.texts.border.halo.on and ghost.texts.bottomLeft.lift:GetText()=='60','stand-in text has the lift too')
    local silverBase=addon.Style.Tone.metal.obsidian.mid
    assert(ghost.width==p.width and ghost.portrait.ring.disc.vertexColor[1]==silverBase[1],'stand-in matches size and ring')
    assert(Near(M.ghosts.target.portrait.ring.layers[1].texture.vertexColor[1],M.palette.hostile[1]),'target stand-in: Class Color, a sample enemy in the hostile tones')
    local gc=M.ghosts.target.combo;assert(gc:IsShown() and gc.points[3].bar.value==M.COMBO_SAMPLE and gc.points[5]:IsShown(),'stand-in shows sample combo points')
    local ga=M.ghosts.target;assert(ga.auraShown.buffs==M.AURA_SAMPLE and ga.auraIcons.buffs[1]:IsShown() and ga.auraShown.debuffs==0,'sample buffs')
    assert(ga.castBox:IsShown() and ga.castBox.text:GetText()=='Frostbolt' and not M.ghosts.player.auraIcons.buffs[1],'sample cast; no buffs on the Player')
    assert(addon.PositionManager:SetOffsets('unitFramesPlayer',-300,-150))
    local point,gp=Point(p),Point(ghost)
    assert(point[1]==gp[1] and point[3]==gp[3] and point[4]==gp[4] and point[5]==gp[5] and p.scale==ghost.scale,'secure button copies the stand-in anchor at the same scale')
    -- Match Width / Match Height: any unit frame can take another element's
    -- size, though it can't hang from it. The Target takes the Player's width.
    local PM,E,A,panel=addon.PositionManager,addon.EditMode,addon.EditAnchor,addon.editWindow
    assert(M:SetFrameOption('target','barWidth',150) and M.ghosts.target.width<ghost.width,'a narrower Target')
    assert(E:Select('unitFramesTarget'),'the Target selected');addon:RefreshEditWindow()
    assert(panel.matchWidthButton:IsEnabled() and panel.matchHeightButton:IsEnabled() and not panel.matchWidthButton.selected,'offered on unit frames')
    panel.matchWidthButton.scripts.OnClick(panel.matchWidthButton);assert(A:Matching()=='width','picking the width')
    local cursor=GetCursorPosition;GetCursorPosition=function() return ghost:GetCenter() end;A.overlay.scripts.OnEvent(A.overlay,'GLOBAL_MOUSE_DOWN','LeftButton');GetCursorPosition=cursor
    assert(M.db.target.matchWidth and PM:GetSizeMatchTarget('unitFramesTarget','width')=='unitFramesPlayer','the Player picked')
    -- On screen: the Player is at 120% here, so the Target (100%) is wider in its own units.
    local function Screen(f) return f.width*f:GetEffectiveScale()/UIParent:GetEffectiveScale() end
    assert(math.abs(Screen(M.ghosts.target)-Screen(ghost))<=1 and M.frames.target.width==M.ghosts.target.width and M.db.target.barWidth==150,"the Player's width on screen; its own Frame Width kept")
    assert(panel.matchedLabel:GetText()=='Width: ModeUI Player Frame\nHeight: off')
    -- Height: the Focus frame (no portrait) takes the Player's: its bar block that tall on screen.
    local tot=M.ghosts.focus
    local function Tall(f) return f.height*f:GetEffectiveScale()/UIParent:GetEffectiveScale() end
    local focusScale=M.db.focus.scale;assert(M:SetFrameOption('focus','scale',150))
    assert(PM:SetSizeMatchTarget('unitFramesFocus','height','unitFramesPlayer') and M.db.focus.matchHeight)
    assert(math.abs(Tall(tot)-Tall(ghost))<=2 and M.db.focus.healthHeight==22,"the Player's height on screen; its own Health Height kept")
    panel.matchWidthButton.scripts.OnClick(panel.matchWidthButton)
    assert(not M.db.target.matchWidth and M.ghosts.target.width<ghost.width,'off: its own width again')
    assert(PM:SetSizeMatchValue('unitFramesFocus','height',false) and M:SetFrameOption('focus','scale',focusScale) and M:SetFrameOption('target','barWidth',184))
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
    assert(v1.layoutVersion==28 and v1.player.barWidth==260 and v1.player.hideBlizzard==false and v1.player.texts.bottomLeft.content=='none')
    assert(v1.player.texts.right.content=='healthBoth' and v1.player.texts.right.size==14 and v1.player.texts.border.size==14 and v1.player.healthColorMode=='default')
    assert(v1.player.healthText==nil and v1.player.levelStyle==nil and v1.player.nameFontSize==nil,'old text keys removed')
    assert(v1.player.fontMedia == 'Mode' and v1.player.texture==nil and v1.player.backgroundColor==nil,'phase-1 background is not carried into the locked skin')
    assert(v1.target.enabled==false and v1.target.barWidth==184)
    local custom={player={width=220,height=36,powerHeight=8,showPower=true},target={width=220,height=36},classColor=false,healthColor={0,1,0}}
    M.Initialize(custom);assert(custom.player.healthColorMode=='custom' and custom.player.healthColor[2]==1)
    local again=addon.ProfileCodec.Copy(v1);M.Initialize(again);assert(again.player.barWidth==260,'migration is idempotent')
    -- Layouts 2-7 keep their effects on the keys that remain.
    local v5={layoutVersion=5,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v5.player.healthHeight=22;v5.player.nameAlign='CENTER';v5.player.fontMedia='PTG Lato';v5.player.levelFontSize=nil;v5.player.healthFontSize=13
    v5.player.borderStyle='satin';v5.player.palette='slate'
    M.Initialize(v5)
    assert(v5.layoutVersion==28 and v5.player.healthHeight==34 and v5.player.texts.border.align=='RIGHT' and v5.player.fontMedia == 'Mode')
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
    assert(v8.layoutVersion==28 and v8.player.healthColorMode=='default' and v8.target.healthColorMode=='class')
    assert(v8b.target.healthColorMode=='custom' and v8b.target.healthColor[3]==0.4 and v8b.player.healthColorMode=='default')
    assert(v8.player.nameColorMode=='gradient' and v8.target.nameColorMode=='gradient','names adopt the default color')
    assert(v8.player.portraitRing=='class' and v8.target.portraitRing=='custom' and v8.target.portraitRingColor[3]==1,'Class Color ring unless custom')
    local v8s=v8.player.texts;assert(v8s.border.content=='name' and v8s.bottomLeft.content=='level' and v8s.bottomLeft.colorMode=='custom' and v8s.bottomLeft.color[2]==1,'explicit level color kept')
    for _,key in ipairs(M.retiredKeys) do assert(v8.player[key]==nil and v8.target[key]==nil,'retired key removed: '..key) end
    -- Layout 9 -> 10: Mist and its glow give way to Champagne and the lifted shadow.
    local v9={layoutVersion=9,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v9.player.nameColorMode='accent';v9.player.nameGlow=true;v9.player.nameGlowStrength=80;v9.player.nameLift=nil
    v9.target.nameColorMode='custom';v9.target.nameColor={0,1,0};v9.target.nameGlow=false
    M.Initialize(v9)
    assert(v9.layoutVersion==28 and v9.player.nameColorMode=='gradient' and v9.player.liftedShadow==false and v9.player.nameLift==nil,'the lifted shadow came in at 10 and left at 21')
    assert(v9.player.nameGlow==nil and v9.player.nameGlowStrength==nil and v9.target.nameGlow==nil,'glow keys removed')
    assert(v9.target.nameColorMode=='custom' and v9.target.nameColor[2]==1,'custom name color kept')
    -- Layout 10 -> 11: Sky replaces the presets to try; the name lift becomes Lifted Shadow for all text.
    local v10={layoutVersion=10,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v10.player.nameColorMode='lilac';v10.player.nameLift=false;v10.player.liftedShadow=nil;v10.player.mirrorText=nil
    v10.target.nameColorMode='class';v10.target.nameLift=true;v10.target.mirrorText=nil
    M.Initialize(v10)
    assert(v10.layoutVersion==28 and v10.player.nameColorMode=='gradient' and v10.target.nameColorMode=='class','presets move to Sky, then Gradient; Class Color kept')
    assert(v10.player.liftedShadow==false and v10.target.liftedShadow==false and v10.player.nameLift==nil and v10.target.nameLift==nil,'the lift carried over at 11, then version 21 turns it off (true was the default)')
    assert(v10.target.mirrorText==true,'matched Target copies the Player text layout, mirrored since version 15')
    local v11={layoutVersion=11,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v11.player.texture='flat';v11.target.texture='media:Smooth';M.Initialize(v11)
    assert(v11.layoutVersion==28 and v11.player.texture==nil and v11.target.texture==nil,'retired Bar Texture removed')
    -- Layout 25 -> 26 (owner, November 23, 2026): cast colors still at the old
    -- amber and gray take light blue and orange-red; picked colors stay.
    local Tone,Same,Legacy=addon.Style.Tone,addon.Style.SameColor,addon.Style.LEGACY
    local v25={layoutVersion=25,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v25.player.castBar={color=addon.ProfileCodec.Copy(Legacy.palette.neutral),lockedColor=addon.ProfileCodec.Copy(Legacy.palette.tapped)}
    v25.target.castBar={color={0.1,0.2,0.3},lockedColor=addon.ProfileCodec.Copy(Legacy.palette.tapped)}
    v25.player.status={combatIcon=true};v25.target.status={combatIcon=true}
    M.Initialize(v25)
    assert(Same(v25.player.castBar.color,Tone.cast.casting) and Same(v25.player.castBar.lockedColor,Tone.cast.shielded),'old defaults follow')
    assert(Same(v25.target.castBar.color,{0.1,0.2,0.3}) and Same(v25.player.castBar.channelColor,Tone.cast.channeling),'picked color stays; channels green')
    assert(v25.layoutVersion==28 and v25.player.status.combatIcon==false and v25.target.status.combatIcon==false,'layout 27: no combat badge')
    local v27={layoutVersion=27,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    v27.target.outline,v27.target.slug,v27.target.boldText=false,nil,nil
    M.Initialize(v27)
    assert(v27.target.outline==true and v27.target.slug==true and v27.target.boldText==true and v27.player.outline==false and v27.player.slug==false,'layout 28: readable Target text')
    -- Version 12 -> 13: new small-frame defaults, but a changed setting stays.
    local v12={layoutVersion=12,targettarget={scale=100,showPortrait=true,namePosition='above',nameAlign='CENTER',barWidth=110},
        focus={scale=120,showPortrait=true,barWidth=150,healthHeight=22,levelStyle='badge',nameFontSize=12}}
    M.Initialize(v12)
    assert(v12.layoutVersion==28 and v12.targettarget.scale==75 and v12.targettarget.showPortrait==false and v12.targettarget.texts.border.content=='none')
    assert(v12.targettarget.texts.center.content=='name' and v12.focus.scale==120,'user changes kept: a centred name in the bar')
    local fs=v12.focus.texts;assert(v12.focus.barWidth==160 and v12.focus.healthHeight==22 and fs.bottomRight.content=='none' and fs.left.content=='name' and fs.left.size==11)
    assert(v12.targettarget.attach==true and v12.focustarget.attach==true and v12.focus.attach==false,'new keys take defaults')
    -- Version 13 -> 14: Mode Slate at 70% for frames still on the old Flat / 25%.
    local v13={layoutVersion=13,player={backgroundTexture='flat',barBackgroundOpacity=25},target={backgroundTexture='media:Smooth',barBackgroundOpacity=40}}
    M.Initialize(v13)
    assert(v13.layoutVersion==28 and v13.player.backgroundTexture=='media:Mode BG' and v13.player.barBackgroundOpacity==60)
    assert(v13.target.backgroundTexture=='media:Smooth' and v13.target.barBackgroundOpacity==40,'chosen backgrounds stay')
    local v15={layoutVersion=15,player={namePosition='above'},target={namePosition='bar'}};M.Initialize(v15)
    assert(v15.layoutVersion==28 and v15.player.texts.border.content=='name' and v15.player.texts.border.y==0,'version 16: names above sit on the border')
    assert(v15.target.texts.right.content=='name' and v15.target.texts.topRight.content=='healthPercent','a taken spot moves to its top row')
    local v14={layoutVersion=14,player={levelStyle='badge'},target={matchPlayer=true,mirrorText=false}};M.Initialize(v14)
    assert(v14.layoutVersion==28 and v14.target.mirrorText==true and v14.player.texts.bottomLeft.content=='level','version 15: corner level, mirrored Target')
    -- Version 16 -> 17: text slots. Every text moves to its matching slot, so nothing moves.
    local v16={layoutVersion=16,player={namePosition='above',nameOffsetY=2,nameOffsetX=-3,nameAlign='CENTER',levelPosition='health',levelOffsetY=1,
        healthText='current',healthTextPosition='LEFT',healthTextOffsetX=3,healthFontSize=13,powerText='both',powerTextPosition='RIGHT',powerFontSize=10},
        target={matchPlayer=true,showName=false,levelStyle='none',healthText='none',powerText='percent'},
        focus={namePosition='bar',nameAlign='RIGHT',healthText='percent',healthTextPosition='RIGHT'}}
    M.Initialize(v16)
    local s=v16.player.texts
    assert(v16.layoutVersion==28 and s.border.content=='name' and s.border.align=='CENTER' and s.border.x==-3 and s.border.y==2+4+3,'Above Frame: on the border, raised by the difference')
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
    local q17=v17.player;assert(v17.layoutVersion==28 and q17.powerForegroundTexture=='flat' and q17.powerBackgroundTexture=='slateHatch' and q17.powerForegroundOpacity==80 and q17.powerBackgroundOpacity==40)
    assert(q17.castBar.foregroundTexture=='flat' and q17.castBar.backgroundTexture=='slateHatch' and q17.castBar.height==14,'nothing changes on screen')
    assert(v17.target.powerForegroundTexture=='media:Mode-FG' and v17.target.castBar.backgroundTexture=='media:Mode-BG','new frames take the defaults')
    -- Version 18 -> 19: the Focus cast bar at the old 3px moves to 8px; a chosen gap stays.
    local v18={layoutVersion=18,focus={castBar={gap=3}},player={castBar={gap=3}}};M.Initialize(v18)
    assert(v18.layoutVersion==28 and v18.focus.castBar.gap==8 and v18.player.castBar.gap==2 and v18.focus.castBar.fullWidth==true)
    local v18b={layoutVersion=18,focus={castBar={gap=5}}};M.Initialize(v18b);assert(v18b.focus.castBar.gap==5)
    -- Version 19 -> 20: the Mode design language. Values still at the old defaults
    -- take the new ones; anything chosen stays.
    local v19={layoutVersion=19,player={powerHeight=10,foregroundTexture='mode',backgroundTexture='slate',barBackgroundOpacity=70,
        powerForegroundTexture='mode',nameColorMode='sky',portraitRing='class',fontMedia='Expressway',barWidth=180,healthHeight=26,portraitScale=150,
        castBar={gap=3,foregroundTexture='mode',backgroundTexture='slate'}},
        target={powerHeight=12,foregroundTexture='media:Smooth',nameColorMode='class',portraitRing='custom',fontMedia='Friz',barWidth=200,
        castBar={gap=6,foregroundTexture='flat'}},
        targettarget={powerHeight=6,healthHeight=16,barWidth=110}}
    M.Initialize(v19)
    local a,b,c=v19.player,v19.target,v19.targettarget
    assert(v19.layoutVersion==28 and a.powerHeight==3 and a.foregroundTexture=='media:Mode Matte' and a.backgroundTexture=='media:Mode BG' and a.barBackgroundOpacity==60)
    assert(a.powerForegroundTexture=='media:Mode Gradient' and a.nameColorMode=='gradient' and a.portraitRing=='class' and a.fontMedia == 'Mode')
    assert(a.barWidth==184 and a.healthHeight==34 and a.portraitScale==165 and a.castBar.gap==2 and a.castBar.foregroundTexture=='media:Mode Cast' and a.castBar.backgroundTexture=='media:Mode BG')
    assert(b.powerHeight==12 and b.foregroundTexture=='media:Smooth' and b.nameColorMode=='class' and b.portraitRing=='custom' and b.fontMedia=='Friz' and b.barWidth==200,'choices kept')
    assert(b.castBar.gap==6 and b.castBar.foregroundTexture=='flat' and c.powerHeight==3 and c.healthHeight==22 and c.barWidth==130)
    -- Version 20 -> 21: Portrait Size 140, no lifted shadow, cast icons on the portrait side; choices kept.
    local v20={layoutVersion=20,player={portraitScale=165,liftedShadow=true,castBar={icon='far'}},target={portraitScale=180,castBar={icon='none'}}}
    M.Initialize(v20)
    assert(v20.layoutVersion==28 and v20.player.portraitScale==165 and v20.player.liftedShadow==false and v20.player.castBar.icon=='near')
    assert(v20.target.portraitScale==180 and v20.target.castBar.icon=='none','choices kept')
    -- Version 24 -> 25: the Target's health still at Dark takes Class Color; a picked one and the Player's stay.
    local v24={layoutVersion=24,player={healthColorMode='default'},target={healthColorMode='default'},focus={healthColorMode='default'}}
    M.Initialize(v24)
    assert(v24.layoutVersion==28 and v24.target.healthColorMode=='class' and v24.player.healthColorMode=='default' and v24.focus.healthColorMode=='default')
    local v24c={layoutVersion=24,target={healthColorMode='custom'}}
    M.Initialize(v24c); assert(v24c.target.healthColorMode=='custom','a picked Target health color stays')
    -- Totem timers fitted once to the Player frame: a mana frame over its left end at 24, others under it at 24; a later choice stays.
    local tm={layoutVersion=25,player={barShows='mana'}}; M.Initialize(tm)
    assert(tm.totems.attach=='aboveLeft' and tm.totems.size==24 and tm.totems.fit==1,'a mana frame: over its left end')
    local tk={layoutVersion=25,player={barShows='mana'},totems={attach='below',size=24}}; M.Initialize(tk)
    assert(tk.totems.attach=='aboveLeft','a default place saved before the fitting moves too')
    local tf={layoutVersion=25,player={barShows='mana'},totems={attach='above',size=18,fitted=true}}; M.Initialize(tf)
    assert(tf.totems.attach=='aboveLeft' and tf.totems.size==24 and tf.totems.fitted==nil,'the first fitting (Above, Right at 18) moves on')
    local t7={layoutVersion=25,player={barShows='mana'},totems={attach='above',size=18}}; M.Initialize(t7)
    assert(t7.totems.attach=='aboveLeft','healer@7 (Above, Right at 18, never fitted) moves on')
    local tc={layoutVersion=25,player={barShows='mana'},totems={attach='below',size=24,fit=1}}; M.Initialize(tc)
    assert(tc.totems.attach=='below','a fitted place stays')
    local th={layoutVersion=25,player={barShows='health'}}; M.Initialize(th)
    assert(th.totems.attach=='below' and th.totems.size==24 and th.totems.fit==1,'a health frame: under it')
    -- Version 21 -> 22: 22px auras five to a row, 11px cast text; choices kept.
    local v21={layoutVersion=21,player={buffs={size=20,perRow=8},debuffs={size=30,perRow=3},castBar={fontSize=10}}}
    M.Initialize(v21)
    assert(v21.layoutVersion==28 and v21.player.buffs.size==22 and v21.player.buffs.perRow==5 and v21.player.castBar.fontSize==11)
    assert(v21.player.debuffs.size==30 and v21.player.debuffs.perRow==3 and v21.player.healthTextColor=='health')
    -- Text glow (Style.TextHalo): off by default; health numbers in Deep at 15%, names in Ink at 20%.
    local d0=M.db.player
    assert(v21.player.healthTextGlow==false and d0.healthTextGlowColor=='deep' and d0.healthTextGlowStrength==15)
    assert(d0.nameTextGlow==true and d0.nameTextGlowColor=='ink' and d0.nameTextGlowStrength==20 and v21.player.nameTextGlowColor=='ink','new keys fill in')
    local ht0=assert(p.textKinds.health[1],'a health text').text
    local halo=ht0.halo
    assert(halo and halo.on and halo.mode=='deep' and #halo==8 and halo[1]:IsShown(),'health numbers glow')
    assert(math.abs(halo[1].alpha-0.15)<1e-9 and ht0.shadowColor[4]==0,'15%, in place of the shadow')
    assert(not ht0.glow,'no capsule')
    local nt0
    for _,entry in ipairs(p.textKinds.name) do if entry.content=='name' then nt0=entry.text end end
    assert(nt0 and nt0.halo and nt0.halo.on and nt0.halo.mode=='ink' and nt0.halo[1].color[1]==addon.Style.Tone.shadow[1],'names glow in Ink')
    assert(M:SetFrameOption('player','healthTextGlow',false) and not halo[1]:IsShown() and ht0.shadowColor[4]==1,'Health Text Glow off: the shadow is back')
    assert(M:SetFrameOption('player','healthTextGlow',true) and halo[1]:IsShown())
    assert(M:SetFrameOption('player','healthTextGlowColor','match') and halo.mode=='match' and M:SetFrameOption('player','healthTextGlowColor','deep'))
    assert(not M:SetFrameOption('player','healthTextGlowStrength',50) and not M:SetFrameOption('player','nameTextGlowColor','bright'),'ranges and choices hold')
    assert(M:SetFrameOption('player','nameTextGlow',false) and not nt0.halo[1]:IsShown() and M:SetFrameOption('player','nameTextGlow',true))
    -- Version 22 -> 23: solid empty bars (100) take the see-through 60; picked values stay.
    local v22={layoutVersion=22,player={barBackgroundOpacity=100,powerBackgroundOpacity=40},target={barBackgroundOpacity=80}}
    M.Initialize(v22)
    assert(v22.layoutVersion==28 and v22.player.barBackgroundOpacity==60 and v22.player.powerBackgroundOpacity==40 and v22.target.barBackgroundOpacity==80)
    -- Version 23 -> 24: a ring still on Metal takes Class Color; Custom and the ring's style stay.
    local v23={layoutVersion=23,player={portraitRing='border',portraitRingStyle='thin',classSoftness=40,portraitScale=140},target={portraitRing='custom'},focus={portraitRing='class',portraitScale=140}}
    M.Initialize(v23)
    assert(v23.layoutVersion==28 and v23.player.portraitRing=='class' and v23.player.portraitRingStyle=='thin' and v23.player.classSoftness==nil and v23.player.portraitScale==165 and v23.focus.portraitScale==140 and v23.target.portraitRing=='custom' and v23.focus.portraitRing=='class')
    -- Health text by health (Style.PaintHealthText): Celadon at full, Rosewood at 30% and under.
    local S=addon.Style
    local function Is(c,token) return math.abs(c[1]-token[1])<1e-9 and math.abs(c[2]-token[2])<1e-9 end
    local wasOn=M.enabled;addon:SetModuleEnabled('unitFrames',true)
    units.player.health=1000;FireEvent('UNIT_HEALTH','player');local ht=assert(p.textKinds.health[1],'a health text').text;assert(Is(ht.color,S.Tone.celadon),'full health: Celadon')
    units.player.health=250;FireEvent('UNIT_HEALTH','player');assert(Is(ht.color,S.Tone.rosewood),'under 30%: Rosewood')
    assert(M:SetFrameOption('player','healthTextColor','text') and Is(p.textKinds.health[1].text.color,M.db.player.textColor),'or the Text Color')
    assert(M:SetFrameOption('player','healthTextColor','health'));units.player.health=900;FireEvent('UNIT_HEALTH','player')
    assert(p.castBox.text.font[1]:find('Urbanist%-Bold') and M.db.player.castBar.fontSize==11,'cast text in Bold, 11px')
    addon:SetModuleEnabled('unitFrames',wasOn)
    -- Reset (the settings footer): every frame back to the defaults.
    local before=addon.ProfileCodec.Copy(M.db)
    assert(M:SetFrameOption('player','barWidth',300) and M:SetFrameOption('target','matchPlayer',false) and M.ResetToDefaults)
    assert(M:ResetToDefaults() and M.db.player.barWidth==184 and M.db.target.matchPlayer==true and M.db.player.portraitScale==165)
    for key,value in pairs(before) do M.db[key]=value end;M:Refresh()
    local v14b={layoutVersion=14,target={matchPlayer=false,mirrorText=false}};M.Initialize(v14b)
    assert(v14b.target.mirrorText==false,'an unmatched Target is left alone')
    local w13={layoutVersion=13,player={barWidth=230},target={matchPlayer=true,barWidth=180}};M.Initialize(w13)
    assert(w13.target.barWidth==230,'a matched Target keeps the width it showed')
    local kept={layoutVersion=12,player=addon.ProfileCodec.Copy(M.frameDefaults.player),target=addon.ProfileCodec.Copy(M.frameDefaults.target)}
    kept.player.nameColorMode='class';kept.player.portraitRing='custom';M.Initialize(kept)
    assert(kept.player.nameColorMode=='class' and kept.player.portraitRing=='custom','later choices are not migrated')
    local bad=addon.ProfileCodec.Copy(M.db);bad.target.healthColorMode='x';assert(not pcall(M.Initialize,bad))
]====]
, "unit_frames")

world.run([[addon:SetModuleEnabled("unitFrames",true); assert(addon.UnitFrames:SetFrameOption("target","barWidth",300))]])
local restored = H.Load({ before = STUBS, saved = world.saved() })
restored.run([====[
    local M=addon.UnitFrames
    assert(M.enabled and M.db.target.barWidth==300 and M.db.player.barWidth==240,'settings persist')
    assert(M.frames.player and M.frames.target.width==60+300+2,'frames built at login (unmatched target keeps its width)')
    assert(addon.PositionManager.elements.unitFramesTarget,'stand-in registered at login despite nil GetCenter before anchoring')
]====]
, "unit_frames_restore")
restored.run([====[
    local M=addon.UnitFrames
    addon:SetModuleEnabled('unitFrames',true)
    assert(M:ResetFrame('player') and M:SetFrameOption('target','matchPlayer',true))
    if not addon.EnsureConfigPage then addon:ToggleConfig() end
    local page=addon:EnsureConfigPage('unitFrames')
    -- Unit Frames opens in split view: its live preview shows in the pane while the page is open.
    addon:SelectConfigPage('unitFrames')
    -- The standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs"), a card per part in each.
    local titles={};for _,section in ipairs(page.sectionTabs.sections) do titles[#titles+1]=section.title end
    assert(table.concat(titles,'|')=='General|Fill|Border|Glow|Text|Auras','the standard tabs, in order')
    assert(page.standardTabs and #page.sectionTabs.buttons==6)
    local function Tab(title) for _,section in ipairs(page.sections) do if section.title==title then return section end end end
    -- section nil: the rows above every tab.
    local function In(row,section) if section==nil then return row.section==nil end return row.section and row.section.title==section end
    local function Find(section,title)
        for _,row in ipairs(page.rows) do if In(row,section) and row.settingsTitle==title then return row end end
    end
    local function Row(section,title) return Find(section,title) or error('missing row '..tostring(section)..' / '..title) end
    local function Visible(row) return not row.visibleWhen or row.visibleWhen() end
    local function Toggle(section,label)
        for _,row in ipairs(page.rows) do
            if In(row,section) and row.settingsToggles then
                for _,cell in ipairs(row.settingsToggles) do if cell.label:GetText()==label then return row end end
            end
        end
        error('missing toggle '..tostring(section)..' / '..label)
    end
    local function Count(title) local n=0;for _,row in ipairs(page.rows) do if row.settingsTitle==title then n=n+1 end end;return n end
    for section,list in pairs({General={'Scale','Frame Width','Frame Height','Status','Power Bar Height','Portrait Style','Portrait Size'},
        Fill={'Fill Direction','Health Color','Power Color'},Glow={'Prism Glow'},
        Text={'Name Color','Health Text Color','Font','Text Color','Shadow'}}) do
        for _,title in ipairs(list) do assert(Visible(Row(section,title)),'Player editable: '..section..' / '..title) end
        assert(not Find(section,'Editing'),'Editing is in the preview header, not in each tab')
    end
    for _,title in ipairs({'Scale','Frame Width','Frame Height','Fill Direction','Health Color'}) do assert(Count(title)==1,'one place for each setting: '..title) end
    assert(Row('General','Frame Width').settingsGroup=='Frame' and Row('Fill','Fill Direction').settingsGroup=='Health Bar','cards named for the part')
    assert(Visible(Toggle('Text','Outline')) and Visible(Toggle('Border','Shadow')) and Visible(Toggle('Glow','Health Text Glow')),'one term per idea')
    assert(page.unitFrameBorder:GetParent().row.section.title=='Border' and page.unitFrameRingStyle:GetParent().row.section.title=='Border','every border in Border')
    assert(page.unitFrameRingStyle and page.unitFrameRingFinish and Count('Portrait Ring')==0,'Ring Style and Ring Finish replace Portrait Ring')
    -- Editing at the preview's top right, with whether the frame is on.
    assert(page.unitFrameEditSelect and Point(page.unitFrameEditSelect:GetParent())[1]=='TOPRIGHT' and page.unitFrameEditSelect:GetParent():GetParent()==page.previewArea)
    -- Each frame in the Editing list says On or Off beside its name.
    assert(M.FrameStateLabel('player'):find('^Player  |cffb4cdb6On|r') and page.unitFrameEditSelect.label:GetText():find('On',1,true) and not page.unitFrameTurnOn:IsShown())
    -- Each bar's own textures and opacity, two to a row.
    assert(page.unitFrameForeground and page.unitFrameBackground and page.unitFrameForegroundOpacity and page.unitFrameBackgroundOpacity)
    assert(page.unitFramePowerForeground and page.unitFramePowerBackgroundOpacity and page.unitFrameCastForeground and page.unitFrameCastBackground)
    local fg,pfg,cfg=page.unitFrameForeground:GetParent().row,page.unitFramePowerForeground:GetParent().row,page.unitFrameCastForeground:GetParent().row
    assert(fg.section.title=='Fill' and fg.settingsGroup=='Health Bar' and pfg.section.title=='Fill' and pfg.settingsGroup=='Power Bar')
    assert(cfg.section.title=='Fill' and cfg.settingsGroup=='Cast Bar','each bar its own Fill card')
    -- Width and height side by side: both stacked, pairable sliders in the Frame card.
    assert(Row('General','Frame Width').pairable and Row('General','Frame Height').pairable)
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
    assert(not Visible(Row('Fill','Custom Health Color')) and M:SetFrameOption('player','healthColorMode','custom') and Visible(Row('Fill','Custom Health Color')))
    assert(not Visible(Row('Text','Custom Name Color')) and M:SetFrameOption('player','nameColorMode','custom') and Visible(Row('Text','Custom Name Color')))
    assert(not Visible(Row('Border','Portrait Ring Color')) and M:SetFrameOption('player','portraitRing','custom') and Visible(Row('Border','Portrait Ring Color')))
    assert(not Find('Text','Glow Strength') and not Find('Text','Name Glow'),'glow controls are gone')
    for _,title in ipairs({'Name Position','Health Text','Power Text Position','Level Position','Show Level'}) do
        for _,section in ipairs(page.sections) do assert(not Find(section.title,title),'replaced by text slots: '..title) end
    end
    assert(M:ResetFrame('player'))
    -- The Text tab: a tile per kind of text (Name, Level, Health Text, Power Text),
    -- each with the same controls: Show, Position, Size, Color, Offset X and Y.
    assert(not Find('Text','Style Slot') and page.unitFrameStyleSlot==nil,'no Slot Style')
    local K=page.unitFrameTextKinds
    for _,id in ipairs({'name','level','health','power'}) do
        local c=K[id];assert(c and c.show and c.position and c.size and c.color and c.x and c.y,'uniform controls: '..id)
        assert(c.show:GetParent().row.section.title=='Text','on the Text tab: '..id)
    end
    local H=K.health
    assert(H.show.label:GetText()=='Health Percent' and H.position.label:GetText()=='Right','health percent at the right')
    assert(Visible(H.position:GetParent().row) and not Visible(H.custom:GetParent().row),'custom color only when chosen')
    -- Moving a text carries its size, color and offset; the old spot clears.
    assert(M:SetTextOptions('player','right',{size=13,x=2}))
    H.position.rows=H.position.rows or {};H.position:GetScript('OnClick')(H.position)
    local moved=false
    for _,row in ipairs(H.position.rows) do if row:IsShown() and row.choice and row.choice.id=='center' then row:GetScript('OnClick')(row);moved=true end end
    assert(moved and M.db.player.texts.center.content=='healthPercent' and M.db.player.texts.center.size==13 and M.db.player.texts.center.x==2,'moved with its settings')
    assert(M.db.player.texts.right.content=='none','the old spot cleared')
    assert(M:SetTextOptions('player','right',{content='healthPercent',size=11,x=0}) and M.db.player.texts.center.content=='none')
    -- None: only Show is left; turning it on again takes its home spot.
    assert(M:SetTextOption('player','right','content','none') and not Visible(H.position:GetParent().row) and H.show.label:GetText()=='None')
    assert(M:SetTextOption('player','right','content','healthPercent') and Visible(H.size:GetParent():GetParent()))
    -- Color: modes that suit the text; the custom swatch opens the picker.
    assert(M:SetTextOption('player','right','colorMode','custom') and Visible(H.custom:GetParent().row))
    H.custom.scripts.OnClick();assert(ColorPickerFrame:IsShown())
    ColorPickerFrame.r,ColorPickerFrame.g,ColorPickerFrame.b=1,0,0;ColorPickerFrame.swatchFunc()
    assert(M.db.player.texts.right.colorMode=='custom' and M.db.player.texts.right.color[1]==1,'picked color is custom')
    assert(M:SetTextOption('player','right','colorMode','default'))
    -- The border alignment shows while the name is on the border.
    assert(Visible(K.name.align:GetParent().row) and M:SetTextOption('player','border','content','none') and not Visible(K.name.align:GetParent().row))
    assert(M:SetTextOption('player','border','content','name'))
    assert(M:SetFrameOption('player','showPower',false) and not Visible(K.power.show:GetParent().row) and M:SetFrameOption('player','showPower',true))
    -- No in-page tools: Copy To… and Reset… in the settings footer act on the frame Editing names.
    assert(page.unitFrameReset==nil and page.unitFrameCopy==nil and Count('Frame Tools')==0,'no in-page tools')
    local copy=M:CopyActions();assert(#copy==1 and copy[1].label=='Player Style to Target')
    assert(not Visible(Toggle('General','Match Player Frame')),"matching is the Target's")
    page.SetEditing('target');assert(M:CopyActions()[1].label=='Target Style to Player')
    page.SetEditing('focus');copy=M:CopyActions();assert(copy[1].label=='Player Style to Focus')
    assert(#addon:ConfigActionItems('copy',M)==1)
    assert(M:SetFrameOption('player','barWidth',200));copy[1].run()
    assert(M.db.focus.barWidth==200 and M.db.focus.portraitSide=='right','copies the Player look, keeps its side')
    local reset=M:ResetScopes();assert(#reset==2 and reset[1].label=='Focus Frame' and reset[2].label=='All of Unit Frames' and reset[1].prompt)
    assert(#addon:ConfigActionItems('reset',M)==2)
    reset[1].run();assert(M.db.focus.barWidth==160 and M:ResetFrame('player'))
    -- A frame that is off: Off in red, Show Frame beside it, and every tab says so.
    assert(M:SetFrameOption('focus','enabled',false) and page.unitFrameEditSelect.label:GetText():find('Focus  ',1,true) and page.unitFrameEditSelect.label:GetText():find('Off|r',1,true) and page.unitFrameTurnOn:IsShown())
    assert(page.unitFrameTurnOn.label:GetText()=='Show Frame')
    assert(Visible(Row(nil,'Frame Off')) and not Visible(Row('General','Frame Width')))
    page.unitFrameTurnOn.scripts.OnClick();assert(M.db.focus.enabled and page.unitFrameEditSelect.label:GetText():find('On|r',1,true))
    -- Match Player Frame is on the Target's General tab only; above every tab, why its look is missing.
    page.SetEditing('target')
    assert(Visible(Toggle('General','Mirror Player Text')) and Visible(Row(nil,'Target Matches Player')),'match and mirror on the Target\'s General tab')
    assert(not Visible(Row('General','Scale')) and Visible(Row('General','Frame Width')) and Visible(Row('Fill','Fill Direction')) and not Visible(Row('General','Frame Height')),'a matched Target keeps its own width and fill')
    assert(not Visible(Toggle('General','Show Power Bar')) and not Visible(Row('Fill','Power Color')))
    -- Class Resource: the Target's own settings, editable even while it matches the Player.
    assert(page.unitFrameComboArc and page.unitFrameComboSize and Visible(Row('General','Arc Position')) and Visible(Row('Fill','Lit Point Color')))
    assert(page.unitFrameResourceNote:GetText():find('Combo Points'),'names your class\'s resource')
    assert(M:SetComboOption('enabled',false) and not Visible(Row('General','Arc Position')) and not Visible(Row('Fill','Lit Point Color')) and M:SetComboOption('enabled',true))
    page.SetEditing('player');assert(not Visible(Toggle('General','Mirror Player Text')),'only the Target matches')
    assert(not Visible(Row('General','Arc Position')) and not Visible(Row('General','Your Class')),'the class resource sits on the Target')
    -- Cast Bar edits the frame's own cast bar, even on a matched Target.
    assert(page.unitFrameCastPosition and page.unitFrameCastHeight and Visible(Row('General','Position')))
    assert(Visible(Toggle('Text','Spell Name')) and Row('Fill','Cast Color'),'cast text in Text, its colors in Fill')
    -- Width: Full Width by default; off, Bar Width.
    local castWidthRow=page.unitFrameCastWidth:GetParent().row
    assert(page.unitFrameCastFullWidth and not Visible(castWidthRow))
    assert(M:SetCastOption(page.unitFrameEditing(),'fullWidth',false) and Visible(castWidthRow) and M:SetCastOption(page.unitFrameEditing(),'fullWidth',true))
    -- Show Portrait opens the Portrait card; the status toggle names what it keeps.
    local portraitRows={}
    for _,row in ipairs(page.rows) do if In(row,'General') and row.settingsGroup=='Portrait' and row.settingsTitle~=nil then portraitRows[#portraitRows+1]=row end end
    assert(Visible(Toggle('General','Show Portrait')) and Toggle('General','Show Portrait')==portraitRows[1],'Show Portrait first')
    assert(Toggle('General','Keep Relative Text Positions') and not pcall(Toggle,'General','Mirror on a Right-Side Portrait'),'renamed')
    assert(Visible(Toggle('Glow','Combat Ring')) and Visible(Toggle('Glow','Pulse When Pulled')),'the combat ring and its pulse in Glow')
    page.SetEditing('target');assert(M.db.target.matchPlayer and Visible(Row('General','Spell Icon')) and not Visible(Row('General','Scale')))
    page.SetEditing('targettarget');assert(not Visible(Row('General','Position')),'off by default on the Target of Target')
    -- Auras: Buffs and Debuffs share the controls; the group switch picks one.
    page.SetEditing('target');assert(page.unitFrameAuraGroup()=='buffs' and page.unitFrameAuraAnchor and Visible(Row('Auras','Filter')))
    local function Shared() return Visible(page.unitFrameAuraAnchor:GetParent().row) end
    assert(Shared());page.unitFrameAuraButtons[2].scripts.OnClick();assert(page.unitFrameAuraGroup()=='debuffs' and not Shared(),'debuffs start off')
    assert(M:SetAuraOption('target','debuffs','enabled',true) and Shared() and M:SetAuraOption('target','debuffs','enabled',false))
    page.SetAuraGroup('buffs')
    -- Each group's icon border in the Border tab, while that group shows.
    local borders=page.unitFrameAuraBorders
    assert(borders.buffs:GetParent().row.section.title=='Border' and Visible(borders.buffs:GetParent().row) and not Visible(borders.debuffs:GetParent().row))
    assert(M:SetAuraOption('target','debuffs','enabled',true) and Visible(borders.debuffs:GetParent().row) and M:SetAuraOption('target','debuffs','enabled',false))
    -- Editing the Player: its Auras tab points to Buffs & Debuffs.
    page.SetEditing('player');assert(Visible(page.unitFramePlayerAurasButton:GetParent().row) and not Shared(),'Player auras live in Buffs & Debuffs')
    page.SetEditing('target');assert(not Visible(page.unitFramePlayerAurasButton:GetParent().row) and Shared())
    -- Preview: a live sample of the frame being edited, built by the same code as
    -- the frames in the world; clicking a part opens its settings.
    local view=page.configPreview
    assert(view and page.previewArea:IsShown() and not page.testDisplayButton:IsShown(),'preview without a screen test')
    local face=view.faces.target
    assert(face and face:IsShown() and face:GetParent()==view.frame and not (view.faces.player and view.faces.player:IsShown()))
    assert(face.auraShown.buffs==M.AURA_SAMPLE and face.castBox:IsShown() and face.combo:IsShown(),'buffs, cast bar and combo points')
    assert(Plain(face.texts.border:GetText())=='Target Frame' and face.health.value==75)
    local at=Point(face);assert(at[1]=='TOPLEFT' and at[2]==view.frame and at[3]=='TOPLEFT' and at[4]==math.floor(at[4]) and at[5]==math.floor(at[5]),'centred on whole pixels')
    assert(math.abs(at[4]+face.geometry.width/2-view.frame:GetWidth()/2/face:GetScale())<=1,'the frame centre on the preview centre')
    assert(M:SetAuraOption('target','buffs','enabled',false) and face.auraShown.buffs==0 and M:SetAuraOption('target','buffs','enabled',true),'follows the settings')
    -- One fixed size and spot: moving or resizing parts never moves the sample.
    local w0,h0=M:GetPreviewSize(view)
    assert(M:SetAuraOption('target','buffs','size',36) and M:SetCastOption('target','height',30) and M:SetAuraOption('target','buffs','perRow',1))
    local w1,h1=M:GetPreviewSize(view);local moved=Point(face)
    assert(w0==w1 and h0==h1 and moved[4]==at[4] and moved[5]==at[5],'no jumping around')
    assert(M:ResetFrame('target') and M:SetFrameOption('target','matchPlayer',true))
    -- The sample is the frame Editing names, on every tab (the class resource's cards show for the Target).
    page.SetEditing('player');page:SelectSectionTab(Tab('Fill'));assert(M:PreviewUnit()=='player' and view.faces.player:IsShown())
    page.SetEditing('target');assert(M:PreviewUnit()=='target' and view.faces.target:IsShown() and not view.faces.player:IsShown(),'class resource: on the Target')
    -- Clicking a part opens the tab that now holds its row, and that row.
    local function Jump(region,target,tab,styled)
        page:SelectSectionTab(Tab(tab=='Text' and 'Fill' or 'Text'))
        region.scripts.OnMouseUp(region,'LeftButton')
        assert(page.selectedSection.title==tab and page.jumpTargets[target].section==page.selectedSection,target..' opens '..tab)
        assert(styled or page.jumpTargets[target].row:IsShown(),target..': its row shows')
    end
    Jump(face.castBox,'cast','General');assert(page.jumpTargets.cast.row==page.unitFrameCastToggles[1].frame:GetParent().row)
    Jump(face.auraIcons.buffs[1],'auras','Auras');assert(page.unitFrameAuraGroup()=='buffs')
    Jump(face.health,'health','Fill');assert(page.jumpTargets.health.row==Row('Fill','Fill Direction'))
    Jump(face.combo,'combo','General');assert(page.jumpTargets.combo.row==Row('General','Your Class'))
    Jump(face.portrait,'portrait','General',true);assert(page.jumpTargets.portrait.row==Toggle('General','Show Portrait'))
    -- A text opens the Text tab at its own spot.
    page.SetEditing('player');local pf=view.faces.player;local hit
    for _,child in ipairs(frames) do if child.jump and child.jump.target=='text:bottomLeft' and child:GetParent()==pf.textLayer then hit=child end end
    assert(hit,'every text is clickable')
    hit.scripts.OnMouseUp(nil,'LeftButton');assert(page.selectedSection.title=='Text' and page.jumpTargets['text:bottomLeft'].section.title=='Text','a text in the preview opens the Text tab')
    assert(pf.scale==M.PREVIEW_SCALE and M.PREVIEW_HEIGHT==150,'the sample draws at 80%')
    page.SetEditing('target')
    page.SetEditing('targettarget');local small=view.faces.targettarget
    assert(small:IsShown() and not face:IsShown() and math.abs(small.scale-0.75*M.PREVIEW_SCALE)<1e-9 and not small.portrait:IsShown() and not small.castBox:IsShown())
    local w,h=M:GetPreviewSize(view);assert(w==M.PREVIEW_WIDTH and h==M.PREVIEW_HEIGHT)
    -- More tabs than fit: arrows at both ends and a scroll bar under them show the overflow and drag it.
    local strip=page.sectionTabs
    assert(strip.slider and not strip.slider:IsShown() and strip.maximum==0,'no slider while every tab fits')
    local top=strip:GetHeight();strip.viewport.width=300;strip:Layout()
    assert(strip.maximum>0 and strip.slider:IsShown() and strip:GetHeight()==top+addon.ConfigWidgets.SECTION_SLIDER_ROOM and strip.previousButton:IsShown() and strip.nextButton:IsShown(),'shown with room below the tabs, arrows at both ends')
    strip.slider:SetValue(60);assert(strip.viewport:GetHorizontalScroll()==60,'dragging scrolls the tabs')
    strip:Scroll(10);assert(strip.slider:GetValue()==10,'the wheel moves the slider')
    strip.viewport.width=nil;strip:Layout();assert(not strip.slider:IsShown() and not strip.previousButton:IsShown() and strip:GetHeight()==top)
    page.SetEditing('player')
    page.SetEditing('focus');assert(page.unitFrameEditing()=='focus' and page.unitFrameEditSelect.label:GetText():find('^Focus  '))
    assert(Visible(Row('General','Scale')) and not Visible(Toggle('General','Match Player Frame')),'only the Target matches the Player')
    assert(M:SetFrameOption('focus','barBackgroundOpacity',50) and M.db.player.barBackgroundOpacity==85,'edits the Focus only')
    assert(M:ResetFrame('focus'))
    -- Placement shows only for frames that attach; its offsets only while attached.
    assert(not Visible(Row('General','Attach Point')),'Focus has no parent frame')
    page.SetEditing('targettarget');assert(Visible(Row('General','Attach Point')) and page.unitFrameAttachY)
    assert(M:SetFrameOption('targettarget','attach',false) and not Visible(Row('General','Attach Point')) and M:SetFrameOption('targettarget','attach',true))
    page.SetEditing('target');assert(page.unitFrameEditing()=='target' and page.unitFrameEditSelect.label:GetText():find('^Target  '),'switch to the Target')
    assert(not Visible(Row('General','Scale')) and Visible(Row(nil,'Target Matches Player')),'matched Target explains itself')
    assert(Visible(Row('Fill','Fill Direction')) and Visible(Row('General','Frame Width')),'a matched Target still picks its width and fill direction')
    -- The settings look: labels above controls, and two dropdowns or sliders share a
    -- line in a card; the frame's scale, width and height side by side.
    page.SetEditing('player');page:SelectSectionTab(Tab('General'));page:Layout()
    local scaleRow,widthRow,heightRow=Row('General','Scale'),Row('General','Frame Width'),Row('General','Frame Height')
    assert(widthRow.stacked and widthRow.pairable and heightRow.pairable and scaleRow.pairable)
    -- Tiles four across: too narrow to share a line, so each control takes the tile's width.
    assert(widthRow.offset>scaleRow.offset and heightRow.offset>widthRow.offset and math.abs(widthRow.width-heightRow.width)<1,'one per line in a narrow tile')
    assert(Point(widthRow.settingsLabel)[1]=='TOPLEFT' and Point(widthRow.settingsHost)[5]==-22,'label above the control')
    local input=widthRow.settingsHost.numericInput;assert(Point(input)[2]==widthRow.settingsHost.valueAnchor and Point(widthRow.settingsHost.slider,2)[4]==0,'value on the label line, slider full width')
    -- Status Icons (General): the frame's own, so a matched Target edits it; rested and pulse are the Player's.
    page.SetEditing('target')
    assert(Visible(page.unitFrameCombatCorner:GetParent().row),'status on a matched Target')
    assert(page.unitFrameRestCorner and not Visible(page.unitFrameRestCorner:GetParent().row) and not Visible(Toggle('Glow','Pulse When Pulled')),'only the Player rests and pulses')
    page.SetEditing('player');assert(Visible(page.unitFrameCombatCorner:GetParent().row) and Visible(page.unitFrameRestCorner:GetParent().row))
    assert(M:SetFrameOption('player','showPortrait',false) and not Visible(page.unitFrameCombatCorner:GetParent().row),'no portrait, no status')
    assert(M:SetFrameOption('player','showPortrait',true));page.SetEditing('target')
    assert(M:SetFrameOption('target','barWidth',150) and M.db.player.barWidth==184 and M.frames.target.geometry.width<M.frames.player.geometry.width,'its own width')
    assert(M:SetFrameOption('target','barWidth',184))
    assert(M:SetFrameOption('target','matchPlayer',false) and Visible(Row('General','Scale')) and Visible(Row('General','Frame Height')))
    assert(M:SetFrameOption('target','barWidth',220) and M.db.player.barWidth==184)
    assert(M:ResetFrame('target') and M:SetFrameOption('target','matchPlayer',true))
    page.SetEditing('player');assert(page.unitFrameEditing()=='player' and Visible(Row('General','Scale')))
    assert(M:SetFrameOption('player','enabled',false) and Visible(Row(nil,'Frame Off')) and not Visible(Row('General','Scale')))
    assert(Visible(Toggle('General','Show Frame')),'the General tab can always turn it back on')
    assert(M:SetFrameOption('player','enabled',true))
    -- Class Resource for a class without one: said so, nothing to set, nothing shown.
    units.player.class='MAGE';page.SetEditing('target')
    assert(page.unitFrameResourceNote:GetText():find('no class resource') and Visible(Row('General','Your Class')) and not Visible(Row('General','Arc Position')))
    assert(not Visible(Toggle('General','Show Class Resource')) and not Visible(Row('Fill','Lit Point Color')))
    page.SetEditing('player')
    M:RenderGhosts();addon:SetEditMode(true);assert(not M.ghosts.target.combo:IsShown(),'no sample points for a class without them')
    addon:SetEditMode(false);units.player.class='ROGUE';page:Refresh()
]====]
, "unit_frames_page")
print("unit frames: all checks passed")

-- The Mode-DPS/TANK layout (DPS / Tank, Modules/UnitFrames/Layouts.lua): the
-- values it writes at both screen heights, then the frames in a world that
-- uses the profile, measured where Edit Mode sees them (the stand-ins).
local layoutWorld = H.Load({ before = STUBS })
layoutWorld.run([====[
    local M=addon.UnitFrames
    for variant,y in pairs({ ['1080']=300, ['1440']=325 }) do
        local profile=assert(addon.Layouts:Build('mode-default',variant))
        local db,pos=profile.modules.unitFrames,profile.positions
        -- The name at the top right and the health text at the bottom right, inside the health bar (owner's tuning, November 18, 2026).
        local t=db.player.texts
        assert(db.enabled==true and t.border.content=='none' and t.right.content=='none','the border and the right side left free')
        assert(t.topRight.content=='name' and t.bottomRight.content=='healthPercent','name top right, health bottom right')
        assert(t.bottomLeft.content=='level','the level stays')
        assert(db.player.healthHeight==28 and db.player.showPower==false,'28 health, no power bar: as tall as an Essential icon')
        assert(db.player.barWidth==166 and db.target.barWidth==166,'18 shorter')
        assert(db.player.portraitScale==145 and db.target.portraitScale==145,'Portrait Size 145')
        assert(db.player.dropShadow==false and db.target.dropShadow==false,'no soft drop under the border')
        for _,unit in ipairs({'player','target','targettarget','focus','focustarget'}) do
            assert(db[unit].buffs.spacing==1 and db[unit].debuffs.spacing==1,unit..': aura icons 1px apart')
            assert(db[unit].edgeStyle=='obsidian' and db[unit].edgeMetal=='default',unit..': Mode-Border in its own metal')
        end
        assert(t.topRight.size==11 and t.bottomRight.size==10 and t.bottomLeft.size==10,'room in the bar: 11, 10 and 10')
        for _,unit in ipairs({'player','target','targettarget','focus','focustarget'}) do
            assert(db[unit].nameTextGlow==false and db[unit].healthTextGlow==false,unit..': no text glow')
        end
        assert(db.target.matchPlayer==true and db.target.mirrorText==true and db.target.buffs.enabled==true
            and db.target.buffs.anchor=='TOPLEFT' and db.target.buffs.grow=='right','Target buffs top left, growing right')
        local f=db.focus
        assert(f.barWidth==120 and f.healthHeight==20 and f.powerHeight==3 and f.scale==100 and f.showPortrait==false)
        assert(f.buffs.enabled==false and f.debuffs.enabled==false and f.castBar.enabled==true and f.castBar.height==12 and f.castBar.gap==8)
        assert(db.focustarget.enabled==false and db.targettarget.enabled==true and db.targettarget.attach==true,'Target of Focus off, Target of Target as it was')
        local function At(id,target,point,relative,x,yy)
            local p=pos[id]
            assert(p and p.target==target and p.point==point and p.relativePoint==relative and p.x==x and p.y==yy,
                id..' '..variant..': '..tostring(p and p.point)..' '..tostring(p and p.x)..','..tostring(p and p.y))
        end
        At('unitFramesPlayer','screen','CENTER','BOTTOM',-256,y)
        At('unitFramesTarget','screen','CENTER','BOTTOM',256,y)
        -- 64 over the Target's top left corner (206 x 46), from the screen.
        At('unitFramesFocus','screen','BOTTOMLEFT','BOTTOM',153,y+87)
        assert(pos.unitFramesTargetTarget==nil and pos.unitFramesFocusTarget==nil)
        -- The sizes behind those numbers.
        local edge=addon.Style.EdgeDepth
        local pg=M:Geometry(db.player,1,edge('frame'))
        local fg=M:Geometry(db.focus,1,edge('frameThin'))
        assert(pg.width==206 and pg.height==46 and fg.width==122 and fg.height==26)
    end
    -- Made into its own profile once at login (1080 here: the mock UI is 800 tall).
    assert(ModeUIDB.profiles['Mode-DPS/TANK'].positions.unitFramesFocus.y==387)
]====], "unit_frames_layout")
-- Only this module's part (and its places) go into the Default profile, so
-- the check stays on these frames whatever other modules add to the layout.
local used = layoutWorld.saved()
local built, default = used.profiles['Mode-DPS/TANK'], used.profiles.Default
default.modules.unitFrames = built.modules.unitFrames
for _, id in ipairs({ 'unitFramesPlayer', 'unitFramesTarget', 'unitFramesFocus' }) do default.positions[id] = built.positions[id] end
H.Load({ before = STUBS, saved = used }).run([====[
    local M=addon.UnitFrames
    assert(M.active and M.ghosts.player and M.ghosts.focus,'the frames are on')
    local function Box(f) local x,y=f:GetCenter();local w,h=f:GetWidth(),f:GetHeight();return x-w/2,y-h/2,x+w/2,y+h/2,w,h end
    local _,uy=UIParent:GetCenter();local ux=UIParent:GetCenter();local bottom=uy-UIParent:GetHeight()/2
    local pl,pb,pr,pt,pw,ph=Box(M.ghosts.player)
    local tl,tb,tr,tt,tw,th=Box(M.ghosts.target)
    local fl,fb,fr,ft,fw,fh=Box(M.ghosts.focus)
    assert(pw==206 and ph==46 and tw==206 and th==46 and fw==122 and fh==26,'Edit Mode measures the frames as built')
    assert((pl+pr)/2-ux==-256 and (pb+pt)/2-bottom==300 and (tl+tr)/2-ux==256 and (tb+tt)/2-bottom==300)
    -- The bar blocks are targets: the stand-ins' blocks, by name.
    assert(_G.ModeUIPlayerUnitFrameBars==M.ghosts.player.panel and _G.ModeUITargetUnitFrameBars==M.ghosts.target.panel,'bar block targets')
    assert(addon.Positioning:Resolve('unitFramesPlayerBars')==M.ghosts.player.panel,'the Player block resolves')
    -- Every frame's border in pieces (Target of Target showed only corner specks).
    for _,unit in ipairs({'player','target','targettarget','focus'}) do
        local fr=M.frames[unit]
        assert(fr.panel.edge.pieces and #fr.panel.edge.parts[1]==8,unit..': border in pieces')
        if fr.castBox then assert(fr.castBox.edge.pieces,unit..': cast bar border in pieces') end
    end
    -- Drop Shadow off: the soft drop is hidden; switching it on shows it again.
    local edge=M.frames.player.panel.edge
    assert(edge.below and not edge.below:IsShown(),'no soft drop in Mode-DPS/TANK')
    assert(M:SetFrameOption('player','dropShadow',true) and edge.below:IsShown(),'Drop Shadow on')
    assert(M.frames.target.panel.edge.below:IsShown(),'the matched Target follows')
    assert(M:SetFrameOption('player','dropShadow',false) and not edge.below:IsShown())
    -- No power bar: the health bar fills the block, so Bottom Right sits on the frame's bottom right.
    local f=M.frames.player
    local g=f.geometry
    assert(not f.power:IsShown() and g.healthHeight+2*g.pad==g.blockHeight and f.health:GetHeight()==g.healthHeight,'health fills the block without power')
    local p=f.texts.bottomRight.points[1]
    assert(p[1]=='BOTTOMRIGHT' and p[2]==f.health and p[3]=='BOTTOMRIGHT','health text on the bar bottom right')
    assert(fl==tl and fb==tt+64,'the Focus 64 over the Target top left')
]====], "unit_frames_layout_world")
print("unit frames: Mode-DPS/TANK layout checks passed")
