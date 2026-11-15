-- Client stubs the probe addons (tests/probes.lua) read beyond the unit frame stubs.
    CurveConstants=CurveConstants or {ScaleTo100={}}
    function UnitIsUnit(a,b) return a==b end
    function IsInRaid() return false end
    function GetRaidTargetIndex(u) return units[u] and units[u].marker end
    -- Action slots: slot 1 a spell with a secret count, slot 2 empty.
    actionSlots={[1]={texture=135000,kind='spell',id=1752,count=Secret('count')}}
    function GetActionTexture(slot) return actionSlots[slot] and actionSlots[slot].texture end
    function GetActionCount(slot) return actionSlots[slot] and actionSlots[slot].count or 0 end
    function GetActionInfo(slot) local a=actionSlots[slot];if a then return a.kind,a.id end end
    function IsUsableAction(slot) return actionSlots[slot]~=nil,false end
    function IsActionInRange() return Secret('range') end
    function GetBindingKey(command) if command=='ACTIONBUTTON1' then return 'SHIFT-1' end end
    -- Class cooldowns for the viewer rows.
    Enum=Enum or {};Enum.CooldownViewerCategory={Essential=0,Utility=1,TrackedBuff=2,TrackedBar=3}
    C_CooldownViewer={GetCooldownViewerCategorySet=function(category) return ({[0]={11,12},[1]={21}})[category] or {} end,
        GetCooldownViewerCooldownInfo=function(id) return {spellID=id*100,isKnown=id~=12} end}
    C_Spell=C_Spell or {};C_Spell.GetSpellTexture=function(id) return 'spell:'..id end
    C_Spell.GetSpellCooldownDuration=function() return {duration='object'} end
    -- Bags: two items in the backpack, one epic.
    C_Container={GetContainerNumSlots=function(bag) return bag==0 and 4 or 0 end,
        GetContainerItemInfo=function(bag,slot)
            if bag==0 and slot==1 then return {iconFileID=1001,stackCount=5,quality=1,itemID=2589} end
            if bag==0 and slot==2 then return {iconFileID=1002,stackCount=1,quality=4,itemID=19019} end
        end}
    function GetMoney() return 123456 end
    function GetGameTime() return 9,5 end
    function GetMinimapZoneText() return Secret('zone') end
    ChatTypeInfo={GUILD={r=0.25,g=1,b=0.25}}
