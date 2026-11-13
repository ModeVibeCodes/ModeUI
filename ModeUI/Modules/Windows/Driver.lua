local _, addon = ...
local M = addon.Windows
if not M then return end

-- Lifecycle, finding Blizzard's windows and settings changes. A window is
-- skinned when the module turns on (if it exists by then), when its
-- load-on-demand addon loads, and again each time it shows, so controls
-- Blizzard makes later are picked up. Skinning runs through Defer: some
-- windows hold secure buttons (Collections, Professions), and placing their
-- close button waits for the end of combat. Fading, textures and fonts are
-- plain widget calls; ModeUI never writes Blizzard's fields or replaces its
-- functions, and never moves, sizes or hides a window.
local Defer, Events, L, Kit, Skin = addon.Defer, addon.Events, addon.L, addon.Kit, addon.Skin
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- A frame by global name, or "Name.Key" for a frame held by another.
function M:Resolve(path)
    local name, key = path:match("^([^.]+)%.?(.*)$")
    local frame = _G[name]
    if frame and key ~= "" then frame = frame[key] end
    if frame and frame.GetObjectType then return frame end
    return nil
end

function M:OnInitialize()
    self.Initialize(self.db)
    self.skinned = setmetatable({}, { __mode = "k" })
    self.hooked = setmetatable({}, { __mode = "k" })
    addon.Media:RegisterFontListener(self, function() if self.active then self:Repaint() end end)
end

function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("windows")
    -- Load-on-demand windows are skinned as their Blizzard addon loads.
    Events:On(self, "ADDON_LOADED", function(_, name) self:OnAddonLoaded(name) end)
    for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        Events:On(self, event, function() self:Repaint() end)
    end
    self:SkinAll()
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    if next(self.skinned) then
        addon.ReloadManager:Request("windows", L["Windows: reload to give Blizzard's windows back their own look."])
    end
end

function M:OnAddonLoaded(name)
    for _, entry in ipairs(self.registry) do
        if entry.addon == name then self:SkinEntry(entry) end
    end
end

function M:SkinAll()
    for _, entry in ipairs(self.registry) do self:SkinEntry(entry) end
end

-- The look every skinned window shares, from the settings.
function M:Style()
    local db = self.db
    return { fill = db.backgroundColor, alpha = db.backgroundOpacity / 100, rim = db.borderColor, border = db.border,
        titleBar = db.titleBar, path = Kit.FontPath(db, self.id), titleSize = db.titleSize, tabSize = db.tabSize,
        outline = db.outline, shadow = db.shadow,
        controls = { Button = db.buttons, Field = db.fields, Tab = db.tabs, SideTab = db.tabs,
            ScrollBar = db.scrollBars, Inset = db.insets } }
end

function M:SkinEntry(entry)
    if not self.active or not self.db.windows[entry.id] then return end
    for _, path in ipairs(entry.frames) do
        local frame = self:Resolve(path)
        if frame then self:Watch(frame, entry) end
    end
end

-- Skins now (or after combat) and on every show from then on.
function M:Watch(frame, entry)
    if not self.hooked[frame] and frame.HookScript then
        self.hooked[frame] = entry
        frame:HookScript("OnShow", function(shown)
            if self.active and self.db.windows[entry.id] then self:Skin(shown, entry) end
        end)
    end
    self:Skin(frame, entry)
end

-- Plain windows are skinned at once, in combat too; windows holding secure
-- frames wait for the end of combat. `repaint` only repaints a window that
-- was skinned before (one switched off since, until the reload).
function M:Skin(frame, entry, repaint)
    local function Run()
        if not self.active then return end
        if repaint then Skin.PaintWindow(frame, self:Style()); return end
        if not self.db.windows[entry.id] then return end
        self.skinned[frame] = entry
        Skin.Window(frame, self:Style(), entry.options)
    end
    local protected = frame.IsProtected and frame:IsProtected()
    if addon.IsPublic(protected) and not protected then Run(); return end
    Defer:Run("windows:" .. entry.id .. ":" .. tostring(frame), Run)
end

-- Colors, fonts and the title strip on every skinned window.
function M:Repaint()
    if not self.active then return end
    for frame, entry in pairs(self.skinned) do self:Skin(frame, entry, not self.db.windows[entry.id]) end
    if self.page then self.page:Refresh() end
end

-- Values are checked by Initialize on a copy before they're kept. Turning a
-- window or a control kind off brings Blizzard's art back on the next reload.
function M:SetOption(key, value)
    if self.defaults[key] == nil or key == "version" or key == "windows" then return false end
    local candidate = Copy(self.db)
    candidate[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = candidate[key]
    if self.reloadKeys[key] and value == false and self.active and next(self.skinned) then
        addon.ReloadManager:Request("windows", L["Windows: reload to give Blizzard's windows back their own look."])
    end
    self:Repaint()
    return true
end

function M:SetWindow(id, on)
    if not self.byId[id] or type(on) ~= "boolean" then return false end
    self.db.windows[id] = on
    if on then self:SkinEntry(self.byId[id])
    elseif self.active then
        for _, entry in pairs(self.skinned) do
            if entry.id == id then
                addon.ReloadManager:Request("windows", L["Windows: reload to give Blizzard's windows back their own look."])
                break
            end
        end
    end
    if self.page then self.page:Refresh() end
    return true
end

function M:ResetToDefaults()
    for key, value in pairs(self.defaults) do
        if key ~= "windows" then self.db[key] = Copy(value) end
    end
    self:Repaint()
    return true
end

function M:AppearanceOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db[key] end }) } }
    function owner.CanConfigure() return true end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(key, value) end
    return owner
end

function M:Status()
    if not self.active then return L["Off. Turn the module on to skin Blizzard's windows."] end
    local count = 0
    for _ in pairs(self.skinned) do count = count + 1 end
    return string.format(L["On. %d windows skinned so far; the rest are skinned when they first open."], count)
end
