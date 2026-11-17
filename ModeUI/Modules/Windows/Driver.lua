local _, addon = ...
local M = addon.Windows
if not M then return end

-- Lifecycle, finding Blizzard's windows and settings changes. A window is
-- skinned when the module turns on (if it exists by then), when its
-- load-on-demand addon loads, and again each time it shows, so controls
-- Blizzard makes later are picked up. Window Style Blizzard (or a window
-- switched off) leaves a window Blizzard's; its Scale still applies. Windows
-- holding secure buttons (Collections, Professions) are skinned and scaled
-- only outside combat, through Defer. Fading, textures and fonts are plain
-- widget calls; ModeUI never writes Blizzard's fields or replaces its
-- functions, and never moves or hides a window.
local Defer, Events, L, Kit, Skin = addon.Defer, addon.Events, addon.L, addon.Kit, addon.Skin
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local RELOAD = "Windows: reload to give Blizzard's windows back their own look."

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
    self.scaled = setmetatable({}, { __mode = "k" })
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
    self:CharacterEnable()
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self:CharacterDisable()
    if next(self.skinned) or next(self.scaled) then addon.ReloadManager:Request("windows", L[RELOAD]) end
end

function M:OnAddonLoaded(name)
    for _, entry in ipairs(self.registry) do
        if entry.addon == name then self:SkinEntry(entry) end
    end
end

function M:SkinAll()
    for _, entry in ipairs(self.registry) do self:SkinEntry(entry) end
end

-- Whether a window is in the Mode look: Window Style ModeUI and its switch on.
function M:IsModeUI(entry) return self.db.style == "modeui" and self.db.windows[entry.id] == true end

-- The look a window gets: the Look tab's, or its own when it has one.
function M:Style(entry)
    local db = self.db
    local look = entry and db.looks[entry.id]
    local custom = look and look.custom
    local alpha, border, titleBar = db.backgroundOpacity, db.border, db.titleBar
    if custom then alpha, border, titleBar = look.backgroundOpacity, look.border, look.titleBar end
    return { fill = db.backgroundColor, alpha = alpha / 100, border = border,
        titleBar = titleBar, path = Kit.FontPath(db, self.id), titleSize = db.titleSize,
        tabSize = db.tabSize, outline = db.outline, shadow = db.shadow, bodyFont = db.bodyFont,
        controls = { Button = db.buttons, Field = db.fields, Tab = db.tabs, SideTab = db.tabs, RightSideTab = db.tabs,
            Dropdown = db.dropdowns, ScrollBar = db.scrollBars, Inset = db.insets } }
end

function M:SkinEntry(entry)
    if not self.active then return end
    for _, path in ipairs(entry.frames) do
        local frame = self:Resolve(path)
        if frame then self:Watch(frame, entry) end
    end
end

-- Skins and scales now (or after combat) and on every show from then on.
function M:Watch(frame, entry)
    if not self.hooked[frame] and frame.HookScript then
        self.hooked[frame] = entry
        frame:HookScript("OnShow", function(shown) if self.active then self:Skin(shown, entry) end end)
    end
    self:Skin(frame, entry)
end

-- Plain windows are skinned at once, in combat too; windows holding secure
-- frames wait for the end of combat. `repaint` only repaints a window that
-- was skinned before (one switched to Blizzard since, until the reload).
function M:Skin(frame, entry, repaint)
    local function Run()
        if not self.active then return end
        self:ApplyScale(frame, entry)
        if repaint then Skin.PaintWindow(frame, self:Style(entry))
        elseif not self:IsModeUI(entry) then return
        else
            self.skinned[frame] = entry
            Skin.Window(frame, self:Style(entry), entry.options)
        end
        self:StyleEdge(frame)
    end
    local protected = frame.IsProtected and frame:IsProtected()
    if addon.IsPublic(protected) and not protected then Run(); return end
    Defer:Run("windows:" .. entry.id .. ":" .. tostring(frame), Run)
end

-- The window's own edge in the Border Style and Border Metal (the same reach
-- in every style, so nothing inside moves). Its controls and cards keep theirs.
function M:StyleEdge(frame)
    local parts = Skin.parts[frame]
    if parts and parts.modeEdge then parts.modeEdge:SetStyle(self.db.edgeStyle, self.db.edgeMetal) end
end

-- A window's Scale (100% leaves Blizzard's own until it's been changed).
function M:ApplyScale(frame, entry)
    if entry.noScale or not frame.SetScale then return end
    local scale = self.db.looks[entry.id].scale / 100
    if scale == 1 and not self.scaled[frame] then return end
    self.scaled[frame] = true
    frame:SetScale(scale)
end

-- Colors, fonts, the title strip and scale on every window seen so far.
function M:Repaint()
    if not self.active then return end
    for frame, entry in pairs(self.hooked) do
        if self.skinned[frame] or self.scaled[frame] or self.db.looks[entry.id].scale ~= 100 then
            self:Skin(frame, entry, self.skinned[frame] ~= nil and not self:IsModeUI(entry))
        end
    end
    self:CharacterRefresh()
    if self.page then self.page:Refresh() end
end

local function AskReload()
    if M.active and next(M.skinned) then addon.ReloadManager:Request("windows", L[RELOAD]) end
end

-- Values are checked by Initialize on a copy before they're kept. Turning a
-- window, a control kind or Window Style ModeUI off brings Blizzard's art
-- back on the next reload.
function M:SetOption(key, value)
    if self.defaults[key] == nil or key == "version" or key == "windows" or key == "looks" then return false end
    local candidate = Copy(self.db)
    candidate[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = candidate[key]
    if (self.reloadKeys[key] and value == false) or (key == "style" and value == "blizzard") then AskReload() end
    if key == "style" and value == "modeui" then self:SkinAll() end
    self:Repaint()
    -- Rows shown only with another setting (Border Color with Border) follow.
    if self.page then self.page:Layout() end
    return true
end

-- One stat in the Character window's stats display.
function M:SetStat(id, on)
    if not self.statsById[id] or type(on) ~= "boolean" then return false end
    self.db.charStatList[id] = on
    self:CharacterRefresh()
    -- Its color row shows with it.
    if self.page then self.page:Layout() end
    return true
end

-- One stat's label color in the stats display.
function M:SetStatColor(id, color)
    if not self.STAT_COLORS[id] or type(color) ~= "table" then return false end
    for i = 1, 3 do if not addon.IsNumber(color[i], 0, 1) then return false end end
    self.db.charStatColors[id] = { color[1], color[2], color[3] }
    self:CharacterRefresh()
    if self.page then self.page:Refresh() end
    return true
end

function M:SetWindow(id, on)
    if not self.byId[id] or type(on) ~= "boolean" then return false end
    self.db.windows[id] = on
    if on then self:SkinEntry(self.byId[id])
    else
        for _, entry in pairs(self.skinned) do
            if entry.id == id then AskReload(); break end
        end
    end
    if self.page then self.page:Refresh() end
    return true
end

-- One setting of a window's own look (M.LOOK), checked against its range.
function M:SetLook(id, key, value)
    local look = self.db.looks[id]
    local default = self.LOOK[key]
    if not (self.byId[id] and look and default ~= nil and type(value) == type(default)) then return false end
    local r = self.lookRanges[key]
    if r and not (addon.IsNumber(value, r[1], r[2]) and value == math.floor(value)) then return false end
    look[key] = value
    if key == "border" or key == "titleBar" or key == "custom" then self:SkinEntry(self.byId[id]) end
    self:Repaint()
    if self.page then self.page:Layout() end
    return true
end

-- The Look tab's reset: the window switches, their own looks and the
-- Character tab's settings stay.
function M:ResetToDefaults()
    for key, value in pairs(self.defaults) do
        if key ~= "windows" and key ~= "looks" and not key:find("^char") then self.db[key] = Copy(value) end
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
    if self.db.style ~= "modeui" then return L["On, in Blizzard's look. Pick ModeUI to restyle the windows."] end
    local count = 0
    for _ in pairs(self.skinned) do count = count + 1 end
    return string.format(L["On. %d windows skinned so far; the rest are skinned when they first open."], count)
end
