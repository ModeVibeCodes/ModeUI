local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Global > Optimizations: auto loot, fast loot, hidden error text, max camera
-- distance and UI scale. Everything is off by default, and ModeUI only touches
-- a game setting while you have that optimization turned on. Turning it off (or
-- the whole module) puts back the value the game had before ModeUI changed it.
local M = { title = "Optimizations", category = "global", defaultEnabled = true,
    configDescription = "Loot, error text, camera distance and UI scale. Nothing changes until you turn it on." }
addon.Optimizations = M
addon:RegisterModule("optimizations", M)

M.defaults = { autoLoot = false, fastLoot = false, hideErrors = false,
    manageCamera = false, cameraZoom = 4, manageScale = false, scaleMode = "auto", uiScale = 71 }
M.ranges = { cameraZoom = { 1, 4 }, uiScale = { 40, 115 } }
M.scaleModes = { auto = true, custom = true }
-- Floor of the game's own UI scale setting; smaller scales are applied to
-- UIParent directly, as Blizzard's pixel-perfect scale does.
M.CVAR_SCALE_FLOOR = 0.65

local Public = addon.IsPublic
local function Number(v, low, high) return Public(v) and type(v) == "number" and v == v and v >= low and v <= high end
local Combat = addon.InCombat
local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local results = { pcall(fn, ...) }
    if not results[1] then return end
    for i = 2, #results do if not Public(results[i]) then results[i] = nil end end
    return unpack(results, 2, 8)
end

function M.Initialize(db)
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = default end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid optimization setting: " .. key)
    end
    for key, range in pairs(M.ranges) do
        assert(Number(db[key], range[1], range[2]), "Invalid optimization range: " .. key)
    end
    assert(M.scaleModes[db.scaleMode], "Invalid UI scale mode.")
end

-- Game settings --------------------------------------------------------------

function M:GetCVar(name)
    local value = C_CVar and Read(C_CVar.GetCVar, name)
    if value == nil and type(GetCVar) == "function" then value = Read(GetCVar, name) end
    if type(value) == "string" then return value end
end

-- Writes a game setting the client lets addons change; reports what happened.
function M:WriteCVar(name, value)
    value = tostring(value)
    local current = self:GetCVar(name)
    if current == nil then return false, "Not available in this client." end
    if C_CVar and C_CVar.GetCVarInfo then
        local _, _, _, _, locked, secure, readOnly = Read(C_CVar.GetCVarInfo, name)
        if locked == true or secure == true or readOnly == true then return false, "The game doesn't allow addons to change this." end
    end
    if current ~= value then
        local set = C_CVar and C_CVar.SetCVar or SetCVar
        if type(set) ~= "function" or Read(set, name, value) == false then return false, "The game didn't accept this setting." end
    end
    local result = self:GetCVar(name)
    local a, b = tonumber(result), tonumber(value)
    if result == value or (a and b and math.abs(a - b) < 0.001) then return true end
    return false, "The game kept " .. tostring(result) .. "."
end

-- want ~= nil: remember the game's value once, then set want.
-- want == nil: put back the remembered value, if ModeUI changed it.
function M:Manage(name, want)
    local originals = addon.root.optimizationOriginals
    if want ~= nil then
        if originals[name] == nil then
            local current = self:GetCVar(name)
            if current == nil then return false, "Not available in this client." end
            originals[name] = current
        end
        return self:WriteCVar(name, want)
    end
    local original = originals[name]
    if original == nil then return true, "untouched" end
    local ok, reason = self:WriteCVar(name, original)
    if ok then originals[name] = nil; return true, "restored" end
    return false, reason
end

-- Detection ------------------------------------------------------------------

function M:Resolution()
    local width, height = Read(GetPhysicalScreenSize)
    if Number(width, 320, 32768) and Number(height, 200, 32768) then return width, height end
end

-- Pixel perfect: one UI unit per screen pixel (768 units tall).
function M:RecommendedScale()
    local _, height = self:Resolution()
    if height then return math.max(40, math.min(115, 768 / height * 100)) end
end

function M:DesiredScale()
    if self.db.scaleMode == "auto" then return self:RecommendedScale() end
    return self.db.uiScale
end

function M:On(key) return self.enabled == true and self.db[key] == true end

-- Applying -------------------------------------------------------------------

function M:ApplyLoot()
    local ok, reason = self:Manage("autoLootDefault", self:On("autoLoot") and "1" or nil)
    self.status.autoLoot = not ok and reason or (self:On("autoLoot") and "On." or (reason == "restored" and "Game setting restored." or "Game setting unchanged."))
    for _, event in ipairs({ "LOOT_READY", "LOOT_CLOSED" }) do
        if self:On("fastLoot") then
            if not self.events:IsEventRegistered(event) then self.events:RegisterEvent(event) end
        elseif self.events:IsEventRegistered(event) then self.events:UnregisterEvent(event) end
    end
    self.lootGeneration = self.lootGeneration + 1
end

function M:ApplyErrors()
    local frame = UIErrorsFrame
    if type(frame) ~= "table" or not frame.IsEventRegistered then return end
    if self:On("hideErrors") then
        if not self.errorsHidden then
            self.restoreErrors = Read(frame.IsEventRegistered, frame, "UI_ERROR_MESSAGE") == true
            frame:UnregisterEvent("UI_ERROR_MESSAGE"); self.errorsHidden = true
        end
        self.status.hideErrors = "Red error text hidden."
    else
        if self.errorsHidden then
            if self.restoreErrors and not frame:IsEventRegistered("UI_ERROR_MESSAGE") then frame:RegisterEvent("UI_ERROR_MESSAGE") end
            self.errorsHidden, self.restoreErrors = nil, nil
        end
        self.status.hideErrors = "Shown, as normal."
    end
end

function M:ApplyCamera()
    local want = self:On("manageCamera") and string.format("%.1f", self.db.cameraZoom) or nil
    local ok, reason = self:Manage("cameraDistanceMaxZoomFactor", want)
    self.status.camera = not ok and reason or (want and ("Max distance " .. want .. "x.") or (reason == "restored" and "Game setting restored." or "Game setting unchanged."))
end

function M:ApplyScale()
    if self.applyingScale then return end
    self.applyingScale = true
    if self:On("manageScale") then
        local desired = self:DesiredScale()
        if not desired then
            self.status.scale = "Screen resolution isn't available yet."
        else
            local ok, reason = self:Manage("useUiScale", "1")
            if ok then ok, reason = self:Manage("uiScale", string.format("%.4f", math.max(self.CVAR_SCALE_FLOOR, desired / 100))) end
            if ok then
                local set = pcall(UIParent.SetScale, UIParent, desired / 100)
                local actual = Read(UIParent.GetScale, UIParent)
                self.scaleApplied = true
                ok = set and Number(actual, 0.1, 2) and math.abs(actual - desired / 100) < 0.001
                reason = not ok and "The game didn't accept this UI scale." or nil
            end
            self.status.scale = ok and string.format("UI scale %.2f%%.", desired) or reason
        end
    else
        local okUse, useReason = self:Manage("useUiScale", nil)
        local originals = addon.root.optimizationOriginals
        local storedScale = originals.uiScale
        local okScale, scaleReason = self:Manage("uiScale", nil)
        local restored = useReason == "restored" or scaleReason == "restored"
        if okUse and okScale and restored and self.scaleApplied then
            -- The game redraws its own scale from these settings; a reload makes
            -- sure nothing is left at ModeUI's scale.
            local scale = tonumber(storedScale or self:GetCVar("uiScale"))
            if self:GetCVar("useUiScale") == "1" and Number(scale, 0.1, 2) then pcall(UIParent.SetScale, UIParent, scale)
            else addon.ReloadManager:Request("uiScale", "Restore the game's UI scale.") end
            self.scaleApplied = false
        end
        self.status.scale = not (okUse and okScale) and (useReason ~= "restored" and useReason or scaleReason)
            or (restored and "Game setting restored." or "Game setting unchanged.")
    end
    self.applyingScale = false
end

-- Settings that touch the game wait until combat ends.
function M:Apply()
    if not self.ready then return end
    if Combat() then self.pending = true; return end
    self.pending = false
    self:ApplyLoot(); self:ApplyErrors(); self:ApplyCamera(); self:ApplyScale()
    if self.page then self.page:Refresh() end
end

-- Fast loot: take each item as soon as the loot window opens. It only runs
-- when the game is auto looting, and native confirmations stay in charge.
function M:LootReady(autoloot)
    self.lootGeneration = self.lootGeneration + 1
    if Combat() or not self:On("fastLoot") or self.lootBlocked or not Public(autoloot) or autoloot ~= true
        or type(LootSlot) ~= "function" or not (C_Timer and C_Timer.After) then return end
    local count = Read(GetNumLootItems)
    if not Number(count, 1, 1000) or count % 1 ~= 0 then return end
    local generation = self.lootGeneration
    for slot = 1, count do
        local index = slot
        C_Timer.After(slot * 0.05, function()
            if generation ~= self.lootGeneration or not self:On("fastLoot") or self.lootBlocked or Combat() then return end
            if not pcall(LootSlot, index) then self.lootBlocked = true; self.lootGeneration = self.lootGeneration + 1 end
        end)
    end
end

-- Lifecycle ------------------------------------------------------------------

function M:OnInitialize()
    self.Initialize(self.db)
    self.status, self.lootGeneration = {}, 0
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)
end

function M:OnEvent(event, ...)
    if event == "LOOT_READY" then self:LootReady(...)
    elseif event == "LOOT_CLOSED" then self.lootGeneration = self.lootGeneration + 1
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then self.ready = true; self:Apply()
    elseif event == "PLAYER_REGEN_ENABLED" then if self.pending then self:Apply() end
    elseif self.ready and self:On("manageScale") then
        -- The game resets UIParent's scale on resolution or scale changes.
        if Combat() then self.pending = true else self:ApplyScale() end
    end
end

-- Lifecycle callbacks run before the module's enabled flag changes; apply the new state.
function M:OnEnable() self.enabled = true; self:Apply() end
function M:OnDisable() self.enabled = false; self:Apply() end

function M:CanConfigure() return not Combat() end

function M:SetOption(key, value)
    if not self:CanConfigure() or self.defaults[key] == nil then return false end
    local candidate = addon.ProfileCodec.Copy(self.db); candidate[key] = value
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = value
    if key == "uiScale" then self.db.scaleMode = "custom" end
    if key == "fastLoot" and value then self.lootBlocked = false end
    self:Apply()
    if addon.configWindow and addon.RefreshConfig then addon:RefreshConfig() end
    return true
end

-- Play The Game Tools has its own Optimizations; if both manage the same
-- setting, whichever applies last wins.
function M:OtherManager()
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local loaded = Read(C_AddOns.IsAddOnLoaded, "PlayTheGameTools")
        if loaded == true then return "Play The Game Tools" end
    end
end
