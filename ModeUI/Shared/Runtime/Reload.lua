local _,addon=...
local R={requests={},drafts={}}
addon.ReloadManager=R
local Combat = addon.InCombat
function R:IsPending() return next(self.requests)~=nil end
function R:GetReason()
    local keys,reasons={},{}
    for key in pairs(self.requests) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do reasons[#reasons+1]=self.requests[key].reason end
    return table.concat(reasons," ")
end
function R:Refresh()
    local window=addon.configWindow
    if window and window.reloadButton then window.reloadButton:SetSelected(self:IsPending()) end
    if self.prompt then
        if not self:IsPending() then self.prompt:Hide()
        elseif self.prompt:IsShown() then self.prompt.reason:SetText(self:GetReason()) end
    end
end
function R:Request(key,reason,validate)
    assert(type(key)=="string" and key~="" and type(reason)=="string" and #reason<=200,"ModeUI: invalid reload request.")
    assert(validate==nil or type(validate)=="function","ModeUI: invalid reload validator.")
    self.requests[key]={reason=reason,validate=validate};self:Refresh()
end
function R:Clear(key) self.requests[key]=nil;self:Refresh() end
function R:SetDraft(key,dirty) self.drafts[key]=dirty and true or nil end
function R:Reload()
    if Combat() then return false,"Reload is unavailable during combat. Try again afterwards." end
    if next(self.drafts) then return false,"Finish or clear unsent changes before reloading." end
    for _,request in pairs(self.requests) do
        if request.validate then local ok,reason=request.validate();if not ok then return false,reason end end
    end
    local reload=ReloadUI
    if addon.Edition and addon.Edition.name=="Forever" and C_UI and type(C_UI.Reload)=="function" then
        reload=C_UI.Reload
    end
    if type(reload)~="function" then return false,"Reload is unavailable; use /reload when safe." end
    reload();return true,"Reload requested."
end
function R:OnWindowClosed()
    if not self:IsPending() then return end
    if Combat() then print("ModeUI: reload pending; use Reload outside combat.");return end
    if addon.ShowReloadPrompt then addon:ShowReloadPrompt() end
end
function R:Start()
    if self.started then return end
    self.started=true
    addon.Events:On(self,"PLAYER_REGEN_DISABLED",function() if self.prompt then self.prompt:Hide() end end)
end
