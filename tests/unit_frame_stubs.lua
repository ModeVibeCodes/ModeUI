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
    function methods:AddMaskTexture(mask) self.mask=mask end
    function methods:SetAtlas(atlas) self.atlas=atlas;self.texture=nil end
    local setTexture=methods.SetTexture
    function methods:SetTexture(path,...) self.atlas=nil;return setTexture(self,path,...) end
    function methods:SetGradient(orientation,a,b) self.gradient={orientation,a,b} end
    function methods:GetStatusBarTexture() self.fillTexture=self.fillTexture or self:CreateTexture(nil,'BACKGROUND');return self.fillTexture end
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
    function UnitPower(u) return units[u].power end
    function UnitPowerMax(u) return units[u].powerMax end
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
    function UnitHealthPercent(u,_,curve)
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

    -- Native frames: content parts fade, the frame itself keeps running.
    for _,spec in ipairs({{'PlayerFrame','PlayerFrameContainer','PlayerFrameContent'},{'TargetFrame','TargetFrameContainer','TargetFrameContent'}}) do
        local native=CreateFrame('Button',spec[1],UIParent);native:EnableMouse(true)
        native[spec[2]]=CreateFrame('Frame',nil,native);native[spec[3]]=CreateFrame('Frame',nil,native)
        native[spec[3]]:SetAlpha(0.9)
    end
    function Point(region,i) return {region:GetPoint(i or 1)} end
