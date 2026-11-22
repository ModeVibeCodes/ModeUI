local _, addon = ...
local M = addon.Media
-- Per-scope media choices (a module may override the global font, texture or
-- border) and registering ModeUI's bundled media with LibSharedMedia.

-- Addon-local defaults. Never use LSM:SetGlobal to change other addons' media.
-- Local custom media wins; old game/flat defaults inherit without rewriting them.
function M:FrameScope(frame)
    while frame do
        if frame.modeMediaScope then return frame.modeMediaScope end
        frame=frame.GetParent and frame:GetParent()
    end
end
function M:GlobalStyle(kind)
    local db=addon.db and addon.db.globalMedia
    return db and db[kind]
end

function M:ResolveFont(key)
    if key=="game" then return self.gameFont end
    if key=="chat" then return self.chatFont end
    if type(key)=="string" and key:sub(1,6)=="media:" then
        local name=key:sub(7)
        -- The Mode typeface before LibSharedMedia has it registered.
        return self:GetFont(name) or (name==addon.Style.FONT_DEFAULT and addon.Style.FontPath("regular") or nil)
    end
end
function M:GetSurfaceTexture(scope, key)
    key=key or self:GlobalStyle("texture",scope) or "default"
    local kind,name=key:match("^([^:]+):(.+)$")
    kind=kind=="background" and "background" or "statusbar"
    if name and self.library then
        local entries=self.library:HashTable(kind)
        local path=entries and entries[name]
        if type(path)=="string" and path~="" then return path end
    end
    return self.defaultStatusBar
end
function M:GetTextures()
    local choices={{key="default",label="Flat"}}
    if self.library then
        for _,kind in ipairs({"statusbar","background"}) do
            local entries=self.library:HashTable(kind) or {}
            for _,name in ipairs(self.library:List(kind) or {}) do
                if type(entries[name])=="string" and entries[name]~="" then
                    choices[#choices+1]={key=(kind=="statusbar" and "media:" or "background:")..name,label=self:MediaLabel(name)}
                end
            end
        end
    end
    return choices
end
function M:PaintSurface(texture,color,alpha,scope)
    scope=scope or self:FrameScope(texture)
    if texture:SetTexture(self:GetSurfaceTexture(scope))==false then texture:SetTexture(self.defaultStatusBar) end
    texture:SetVertexColor(color[1],color[2],color[3],alpha or color[4] or 1)
end
function M:SetGlobalStyle(kind,value,scope)
    if InCombatLockdown() or UnitAffectingCombat("player") then return false end
    if kind~="font" and kind~="texture" and kind~="border" then return false end
    if scope then return false end
    local choices=kind=="font" and self:GetFonts() or kind=="border" and self:GetBorders() or self:GetTextures()
    local valid=false
    for _,choice in ipairs(choices) do if choice.key==value then valid=true end end
    if not valid then return false end
    local db=addon.db.globalMedia
    db[kind]=value
    addon.ReloadManager:Request("globalMedia","Apply Global Settings media changes.")
    return true
end
