local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Changing the Bar Style (BarStyle.lua) and what follows it: a Bar Style
-- value (every bar that follows that group takes it), a bar's group back to
-- the Bar Style or its own, every group of one bar or of every bar, and the
-- presets. Each change is checked by Initialize on a copy before it's kept,
-- like every other setting.
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Presets: what each sets on top of the owner's Bar Style.
M.barStylePresetOrder = { "mode", "compact", "large" }
M.barStylePresets = {
    mode = { label = "Mode Default", values = {} },
    compact = { label = "Compact", values = { largeWidth = 32, largeHeight = 26, smallWidth = 26, smallHeight = 20,
        cooldownSize = 11, cooldownSizeSmall = 9, countSize = 9, countSizeSmall = 8 } },
    large = { label = "Large & Clear", values = { largeWidth = 44, largeHeight = 36, smallWidth = 36, smallHeight = 28, spacing = 2,
        edgeSize = 2, cooldownSize = 16, cooldownSizeSmall = 13, countSize = 12, countSizeSmall = 11 } },
}

-- Keeps `candidate` (already checked): every table in place, so what holds
-- a bar's table keeps seeing it.
local function Keep(self, candidate)
    for key, value in pairs(candidate) do
        local target = self.db[key]
        if type(value) == "table" and type(target) == "table" then
            for k in pairs(target) do target[k] = nil end
            for k, v in pairs(value) do target[k] = v end
        else
            self.db[key] = value
        end
    end
    self:Refresh()
    if self.page then self.page:Layout() end
    if self.window then self:RefreshList() end
    return true
end
local function Try(self, change)
    if not self:CanConfigure() then return false end
    local candidate = Copy(self.db)
    if change(candidate) == false then return false end
    if not pcall(self.Initialize, candidate) then return false end
    return Keep(self, candidate)
end

function M:BarStyleValue(key) return self.db.barStyle[key] end
function M:SetBarStyle(key, value)
    if self.barStyleDefaults[key] == nil then return false end
    return Try(self, function(db) db.barStyle[key] = Copy(value) end)
end
-- Sets several Bar Style values at once (a preset).
function M:SetBarStyleValues(values)
    return Try(self, function(db)
        for key, value in pairs(values) do
            if self.barStyleDefaults[key] == nil then return false end
            db.barStyle[key] = Copy(value)
        end
    end)
end
function M:ApplyBarStylePreset(tag)
    local preset = self.barStylePresets[tag]
    if not preset then return false end
    local values = Copy(self.barStyleDefaults)
    -- A preset keeps the profile's colors and background (the Mode-Obsidian
    -- face); it sets sizes, spacing, the band and the text.
    for _, key in ipairs({ "backgroundColor", "edgeColor", "swipeColor", "barColor" }) do values[key] = Copy(self.db.barStyle[key]) end
    for key, value in pairs(preset.values) do values[key] = value end
    return self:SetBarStyleValues(values)
end
-- The preset the Bar Style matches now, if any.
function M:BarStylePreset()
    local bs = self.db.barStyle
    for _, tag in ipairs(self.barStylePresetOrder) do
        local same = true
        for key, default in pairs(self.barStyleDefaults) do
            local want = self.barStylePresets[tag].values[key]
            if want == nil then want = default end
            if type(want) ~= "table" and bs[key] ~= want then same = false; break end
        end
        if same then return tag end
    end
end

-- One group of a bar back to the Bar Style (on) or its own (off: it keeps
-- the values it has now).
function M:FollowGroup(id, group, on)
    if not self:HasBar(id) then return false end
    return Try(self, function(db)
        local style = db[id]
        if type(style.follow) ~= "table" then style.follow = {} end
        local allowed = false
        for _, g in ipairs(self:StyleGroups(id)) do if g == group then allowed = true end end
        if not allowed then return false end
        style.follow[group] = on == true
    end)
end
-- Every group of one bar (a default bar keeps its own size) or of every bar.
function M:UseBarStyle(id)
    if not self:HasBar(id) then return false end
    return Try(self, function(db) db[id].follow = self.NewFollow(db, id) end)
end
function M:UseBarStyleEverywhere()
    return Try(self, function(db)
        for _, id in ipairs(self:BarIds()) do db[id].follow = self.NewFollow(db, id) end
        for _, id in ipairs(self.resources) do db.resources[id].follow = { border = true, text = true } end
        db.castBar.follow = { border = true, text = true }
    end)
end
-- How many groups of a bar are its own beyond what Use Bar Style would
-- leave (a default bar keeps its own size).
function M:CustomGroups(id)
    local count = 0
    for group, on in pairs(self.NewFollow(self.db, id)) do if on and not self:Follows(id, group) then count = count + 1 end end
    return count
end

-- The resource bars and the Cast Bar: `id` is a resource ID or "cast".
local function PlayerStyle(db, id) if id == "cast" then return db.castBar end return db.resources[id] end
function M:PlayerFollows(id, group)
    local style = PlayerStyle(self.db, id)
    return type(style) == "table" and type(style.follow) == "table" and style.follow[group] == true
end
function M:FollowPlayerGroup(id, group, on)
    if id ~= "cast" and not self.resourceSpecs[id] then return false end
    if group ~= "border" and group ~= "text" then return false end
    return Try(self, function(db)
        local style = PlayerStyle(db, id)
        if type(style.follow) ~= "table" then style.follow = {} end
        style.follow[group] = on == true
    end)
end
