local _, addon = ...
local M = addon.Example
if not M then return end

-- Lifecycle and logic. Nothing is built until the module is first switched on.
local Defer, Events, Kit, Name = addon.Defer, addon.Events, addon.Kit, addon.Domain.Name

function M:OnInitialize()
    self.Initialize(self.db)
    -- Other modules reach this one only through messages.
    addon.RegisterMessage(self, addon.Messages.PROFILES_CHANGED, function() self:Refresh() end)
end

-- Runtime sets self.enabled after these return, so they track their own state.
function M:OnEnable()
    self.active = true
    Events:On(self, "PLAYER_TARGET_CHANGED", function() self:Update() end)
    self:Refresh()
end
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self:Refresh()
end

-- Frame changes go through Defer: they run now, or after combat if the player
-- is fighting. Protected (secure) frames must always be handled this way.
function M:Refresh()
    Defer:Run("example:refresh", function()
        if self.active and not self.frame then self:Build() end
        local frame = self.frame
        if not frame then return end
        frame:SetScale(self.db.scale / 100)
        frame:SetShown(self.active and self.db.showTarget)
        self:Update()
    end)
end

function M:Build()
    local frame = CreateFrame("Frame", "ModeUIExampleFrame", UIParent)
    frame:SetSize(240, 24)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    frame.text = Kit.Text(frame)
    frame.text:SetPoint("CENTER")
    self.frame = frame
end

-- Names can be secret: they go straight to SetText, never compared or joined.
function M:Update()
    if not self.frame or not self.frame:IsShown() then return end
    self.frame.text:SetText(Name.Get("target"))
end

-- Settings change outside combat only, and only to values Initialize accepts.
function M:SetOption(key, value)
    if addon.InCombat() or self.defaults[key] == nil then return false end
    local candidate = addon.ProfileCodec.Copy(self.db)
    candidate[key] = value
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = value
    self:Refresh()
    return true
end
