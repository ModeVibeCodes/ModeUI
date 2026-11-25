local _, addon = ...
local M = addon.Optimizations
if not M then return end

-- Applying each optimization while it's on, the module lifecycle, events and
-- settings changes. Game settings are read and written in GameSettings.lua.
local Public, Number, Combat, Read = addon.IsPublic, addon.IsNumber, addon.InCombat, addon.Domain.Query.Read

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

-- The game's own UI Scale settings where addons may change them, then the
-- interface itself (UIParent, out of combat). On Forever useUiScale is a
-- secure setting (C_CVar.GetCVarInfo: isSecure; owner's client, November 24,
-- 2026), so the game's UI Scale stays off and its automatic scale (64% at
-- 1440p) was all that showed: the interface now takes the scale either way.
function M:ApplyScale()
    if self.applyingScale then return end
    self.applyingScale = true
    if self:On("manageScale") then
        local desired = self:DesiredScale()
        if not desired then
            self.status.scale = "Screen resolution isn't available yet."
        else
            local game = self:Manage("useUiScale", "1")
            if game then game = self:Manage("uiScale", string.format("%.4f", math.max(self.CVAR_SCALE_FLOOR, desired / 100))) end
            local set = pcall(UIParent.SetScale, UIParent, desired / 100)
            local actual = Read(UIParent.GetScale, UIParent)
            local ok = set and Number(actual, 0.1, 2) and math.abs(actual - desired / 100) < 0.001
            if ok then self.scaleApplied = true end
            self.status.scale = (not ok and "The game didn't accept this UI scale.")
                or (game and string.format("UI scale %.2f%%.", desired))
                or string.format("UI scale %.2f%%, on the interface (the game keeps its own UI Scale setting from addons).", desired)
        end
    else
        local okUse, useReason = self:Manage("useUiScale", nil)
        local originals = addon.root.optimizationOriginals
        local storedScale = originals.uiScale
        local okScale, scaleReason = self:Manage("uiScale", nil)
        local restored = useReason == "restored" or scaleReason == "restored"
        if okUse and okScale and self.scaleApplied then
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

-- The General page's quick action: Set UI Scale on, at the Pixel Perfect
-- scale for this screen (switching Optimizations on if it was off).
-- In use means on screen: the interface at that scale now, not only chosen.
function M:UsingSuggestedScale()
    local scale = self:SuggestedScale()
    if not (self:On("manageScale") and self.db.scaleMode == "auto" and scale) then return false end
    local actual = Read(UIParent.GetScale, UIParent)
    return Number(actual, 0.1, 2) and math.abs(actual - scale / 100) < 0.001 or false
end
function M:UseSuggestedScale()
    local scale, height = self:SuggestedScale()
    if not scale or not self:CanConfigure() then return false end
    if not self.enabled then addon:SetModuleEnabled(self.id, true) end
    self.db.scaleMode = "auto"
    if not self:SetOption("manageScale", true) then return false end
    addon:PrintAction(string.format("UI scale %.2f%%, pixel perfect for %dp.", scale, height), "uiScale")
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
