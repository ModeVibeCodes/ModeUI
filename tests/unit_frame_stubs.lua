-- Unit frame client stubs (secure templates, secret values, native frames) shared by the tests.
    local methods=getmetatable(UIParent).__index
    -- Secure/template stubs. They record intent; real protection is native only.
    function methods:SetAttribute(key,value)
        assert(not InCombatLockdown(),'SetAttribute in combat');self.attributes=self.attributes or {};self.attributes[key]=value
    end
    local setPoint,clear,show,hide,setSize=methods.SetPoint,methods.ClearAllPoints,methods.Show,methods.Hide,methods.SetSize
    local function Guard(self,what) assert(not (self.secure and InCombatLockdown()),what..' on secure frame in combat') end
    function methods:SetPoint(...) Guard(self,'SetPoint');return setPoint(self,...) end
    function methods:ClearAllPoints() Guard(self,'ClearAllPoints');return clear(self) end
    function methods:Show() Guard(self,'Show');return show(self) end
    function methods:Hide() Guard(self,'Hide');return hide(self) end
    function methods:SetSize(...) Guard(self,'SetSize');return setSize(self,...) end
    -- Native status bars accept secret values; record them without arithmetic.
    local setValue,setRange=methods.SetValue,methods.SetMinMaxValues
    function methods:SetValue(v,...) if self.kind=='StatusBar' then self.value=v;return end return setValue(self,v,...) end
    function methods:SetMinMaxValues(a,b) if self.kind=='StatusBar' then self.low,self.high=a,b;return end return setRange(self,a,b) end
    function methods:SetFormattedText(pattern,...)
        for i=1,select('#',...) do local v=select(i,...);if issecretvalue(v) then self.text={formatted=pattern,secret=v};return end end
        self:SetText(string.format(pattern,...))
    end
    function methods:CreateMaskTexture() local m=self:CreateTexture(nil,'OVERLAY');m.kind='MaskTexture';return m end
    -- The client holds at most 3 masks on a texture and errors on a 4th.
    function methods:AddMaskTexture(mask)
        self.masks=self.masks or {}
        assert(#self.masks<3,'Texture:AddMaskTexture(): Texture already has the maximum number of mask textures (3)')
        self.masks[#self.masks+1]=mask;self.mask=mask
    end
    function methods:RemoveMaskTexture(mask)
        local found
        for i,held in ipairs(self.masks or {}) do if held==mask then found=i end end
        assert(found,'removes its own mask');table.remove(self.masks,found);self.mask=self.masks[#self.masks]
    end
    function methods:SetAtlas(atlas) self.atlas=atlas;self.texture=nil end
    local setTexture=methods.SetTexture
    function methods:SetTexture(path,...) self.atlas=nil;return setTexture(self,path,...) end
    function methods:SetGradient(orientation,a,b) self.gradient={orientation,a,b} end
    function methods:GetStatusBarTexture()
        if self.statusBarTexture==nil then return nil end
        self.fillTexture=self.fillTexture or self:CreateTexture(nil,'BACKGROUND');return self.fillTexture
    end
    function methods:SetDrawLayer(layer,sub) self.drawLayer,self.drawSublevel=layer,sub end
    -- Native GetCenter is nil until a frame has an anchor, and Position Manager
    -- measures with it: unit frame stand-ins must be anchored before registering.
    local register=addon.PositionManager.RegisterElement
    function addon.PositionManager:RegisterElement(id,frame,options)
        if type(id)=='string' and id:find('^unitFrames') then
            assert(#(frame.points or {})>0,'stand-in must be anchored before Position Manager registration')
        end
        return register(self,id,frame,options)
    end
    function CreateColor(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    local create=CreateFrame
    function CreateFrame(kind,name,parent,template)
        local f=create(kind,name,parent)
        f.secure=template=='SecureUnitButtonTemplate'
        if f.secure then assert(not InCombatLockdown(),'secure frame created in combat') end
        return f
    end
    watched={}
    function RegisterUnitWatch(f) assert(not InCombatLockdown());watched[f]=true end
    function UnregisterUnitWatch(f) assert(not InCombatLockdown());watched[f]=nil end
    function hooksecurefunc(t,name,hook) local old=t[name];t[name]=function(...) local r=old(...);hook(...);return r end end
    GameTooltip=CreateFrame('Frame');function GameTooltip:SetUnit(u) self.unit=u end
    function SetPortraitTexture(texture,unit) texture:SetTexture('portrait:'..unit) end
    function GetClassAtlas(class) return 'classicon-'..class:lower() end
    C_Texture={GetAtlasInfo=function(atlas) return atlas:find('^classicon%-') and {} or nil end}

    -- Any arithmetic, comparison, concatenation or string use of a secret fails.
    local function Boom() error('secret value misused',2) end
    function Secret(label)
        return setmetatable({secret=true,label=label},{__add=Boom,__sub=Boom,__mul=Boom,__div=Boom,__mod=Boom,__pow=Boom,
            __unm=Boom,__lt=Boom,__le=Boom,__concat=Boom,__tostring=Boom,__len=Boom})
    end
    units={player={exists=true,health=900,max=1000,power=50,powerMax=100,token='ENERGY',name='Fixture',level=60,class='ROGUE',isPlayer=true,connected=true},
        target={exists=true,health=Secret('hp'),max=Secret('max'),power=Secret('p'),powerMax=Secret('pm'),token='MANA',name=Secret('name'),level=-1,classification='elite',reaction=2,connected=true}}
    function UnitExists(u) return units[u] and units[u].exists or false end
    function UnitHealth(u) return units[u].health end
    function UnitHealthMax(u) return units[u].max end
    -- A unit's `mana`/`manaMax` answer for the mana type (0) when set (a Druid in a form).
    function UnitPower(u,t) local d=units[u];if t==0 and d.mana~=nil then return d.mana end return d.power end
    function UnitPowerMax(u,t) local d=units[u];if t==0 and d.manaMax~=nil then return d.manaMax end return d.powerMax end
    function UnitPowerType(u) return 0,units[u].token end
    function UnitName(u) return units[u].name end
    function UnitLevel(u) return units[u].level end
    function UnitClassification(u) return units[u].classification or 'normal' end
    function UnitClass(u) return 'Rogue',units[u].class or 'ROGUE',4 end
    function UnitIsPlayer(u) return units[u].isPlayer==true end
    function UnitIsTapDenied() return false end
    function UnitReaction(u) return units[u].reaction end
    function UnitIsConnected(u) return units[u].connected end
    function UnitIsGhost() return false end
    function UnitIsDeadOrGhost(u) return units[u].dead==true end
    CurveConstants={ScaleTo100={}}
    C_CurveUtil=C_CurveUtil or {}
    function C_CurveUtil.CreateColorCurve()
        local curve={colorPoints={}}
        function curve:SetType(t) self.type=t end
        function curve:AddPoint(x,color) self.colorPoints[#self.colorPoints+1]={x=x,color=color} end
        return curve
    end
    function UnitHealthPercent(u,_,curve)
        if type(curve)=='table' and curve.colorPoints then
            local d=units[u];if issecretvalue(d.health) then error('secret color') end
            local share,best=d.health/d.max,nil
            for _,p in ipairs(curve.colorPoints) do if share>=p.x-1e-9 then best=p.color end end
            local c=best;return {GetRGB=function() return c.r,c.g,c.b end}
        end
        assert(curve==CurveConstants.ScaleTo100,'percent uses the 0-100 curve')
        local d=units[u];if issecretvalue(d.health) then return Secret('pct') end
        return d.health/d.max*100
    end
    function UnitPowerPercent(u,_,_,curve)
        assert(curve==CurveConstants.ScaleTo100,'power percent uses the 0-100 curve')
        local d=units[u];if issecretvalue(d.power) then return Secret('ppct') end
        return d.power/d.powerMax*100
    end
    function AbbreviateNumbers(v) if issecretvalue(v) then return Secret('abbr') end return tostring(v) end
    -- Health Deficit: missing health, made into text by C_StringUtil (secret in, secret out).
    function UnitHealthMissing(u) local d=units[u];if issecretvalue(d.health) then return Secret('miss') end return d.max-d.health end
    C_StringUtil={TruncateWhenZero=function(n) if issecretvalue(n) then return Secret('digits') end n=math.floor(n);return n==0 and '' or tostring(n) end,
        WrapString=function(infix,prefix,suffix) if issecretvalue(infix) then return Secret('wrapped') end if infix=='' then return '' end return (prefix or '')..infix..(suffix or '') end}

    -- Native frames: content parts fade, the frame itself keeps running.
    for _,spec in ipairs({{'PlayerFrame','PlayerFrameContainer','PlayerFrameContent'},{'TargetFrame','TargetFrameContainer','TargetFrameContent'},
        {'FocusFrame','TargetFrameContainer','TargetFrameContent'}}) do
        local native=CreateFrame('Button',spec[1],UIParent);native:EnableMouse(true)
        native[spec[2]]=CreateFrame('Frame',nil,native);native[spec[3]]=CreateFrame('Frame',nil,native)
        native[spec[3]]:SetAlpha(0.9)
    end
    -- Blizzard's Target of Target and Target of Focus sit on the Target and
    -- Focus frames, with mouse-enabled debuff icons.
    for _,owner in ipairs({'TargetFrame','FocusFrame'}) do
        local tot=CreateFrame('Button',owner..'ToT',_G[owner]);tot:EnableMouse(true)
        for i=1,4 do CreateFrame('Frame',owner..'ToTDebuff'..i,tot):EnableMouse(true) end
    end
    -- Forever's ComboFrame is pinned to the Target frame; combo points live on the target.
    CreateFrame('Frame','ComboFrame',TargetFrame)
    comboPoints=0
    function GetComboPoints(unit,target) assert(unit=='player' and target=='target');return comboPoints end
    -- Casts: Blizzard's player cast bar and the Target/Focus spell bars.
    function methods:SetReverseFill(value) assert(type(value)=='boolean','Usage: self:SetReverseFill(isReverseFill)');self.reverseFill=value end
    -- As in the client: three numbers, or one color object (with GetRGB).
    local setBarColor=methods.SetStatusBarColor
    function methods:SetStatusBarColor(r,g,b,a)
        local numbers=(type(r)=='number' or issecretvalue(r)) and (type(g)=='number' or issecretvalue(g)) and (type(b)=='number' or issecretvalue(b))
        local object=type(r)=='table' and not issecretvalue(r) and type(r.GetRGB)=='function'
        assert(numbers or object,'bad argument #1 to SetStatusBarColor (Usage: self:SetStatusBarColor(color [, a]))')
        return setBarColor(self,r,g,b,a)
    end
    function UnitCastingInfo(u) local c=units[u] and units[u].cast;if c then return c.name,c.text,c.icon,c.start,c.stop,false,'id',c.locked end end
    function UnitChannelInfo(u) local c=units[u] and units[u].channel;if c then return c.name,c.text,c.icon,c.start,c.stop,false,c.locked end end
    CreateFrame('StatusBar','PlayerCastingBarFrame',UIParent);CreateFrame('StatusBar','TargetFrameSpellBar',TargetFrame)
    CreateFrame('StatusBar','FocusFrameSpellBar',FocusFrame)
    -- Auras: units[u].helpful / .harmful, picked by the filter's first word.
    auraFilters={}
    C_UnitAuras={GetUnitAuras=function(unit,filter,max)
            auraFilters[#auraFilters+1]=filter
            local list={}
            for _,a in ipairs((units[unit] or {})[filter:find('^HELPFUL') and 'helpful' or 'harmful'] or {}) do if #list<max then list[#list+1]=a end end
            return list
        end,
        GetAuraApplicationDisplayCount=function(unit,id,minimum)
            for _,a in ipairs(units[unit].helpful or {}) do if a.auraInstanceID==id then return (a.applications or 0)>=minimum and tostring(a.applications) or '' end end
            return ''
        end}
    -- Rest and combat state (plain booleans on Forever).
    combat,attackable,resting={},{},false
    function UnitAffectingCombat(u) return combat[u]==true or (u=='player' and testCombat==true) end
    function UnitCanAttack(_,u) return attackable[u]==true end
    function IsResting() return resting end
    function Point(region,i) return {region:GetPoint(i or 1)} end
-- Text without color codes (Gradient names color each letter).
function Plain(text) return (tostring(text):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')) end
