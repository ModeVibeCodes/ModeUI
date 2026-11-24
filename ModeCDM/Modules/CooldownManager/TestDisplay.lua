local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Test on Screen (owner, November 24, 2026): while the window is open and out
-- of combat, every icon bar that shows draws sample icons in its real place
-- (its own frames over the holder, never Blizzard's), some cooling and one
-- lit; the Cast Bar shows its sample. It stops when combat starts, the
-- window closes, or the button is pressed again.
local SAMPLE_ICON = 134400 -- the question mark icon
local COOLING = { [2] = 0.45, [4] = 0.8, [6] = 0.25 }

function M:CanTestDisplay()
    return self.active == true and self.built == true and not addon.InCombat()
end

local function Sample(self, id, index, bar)
    self.testSamples[id] = self.testSamples[id] or {}
    local sample = self.testSamples[id][index]
    if not sample then
        sample = self:BuildSample(self.testHost, bar)
        self.testSamples[id][index] = sample
    end
    return sample
end

local function Draw(self, id)
    local holder, style = self.holders and self.holders[id], self.db[id]
    if not holder or not style.show then return end
    local bar = self:IsBar(id)
    local entries = self:PreviewEntries(id)
    local count = math.max(#entries, bar and 2 or 4)
    local g = self.Geometry(style, count, self.PixelSize(holder))
    local now = GetTime and GetTime() or 0
    for index = 1, count do
        local entry = entries[index] or { icon = SAMPLE_ICON }
        local sample = Sample(self, id, index, bar)
        sample:SetParent(self.testHost)
        sample:SetFrameStrata("HIGH")
        local state = self:Dress(sample)
        state.viewer, state.g = id, g
        self.Place(sample, holder, g, index)
        if bar then
            self:SkinBar(sample, style, g, state)
            sample.Icon.Icon:SetTexture(entry.icon)
            sample.Bar:SetValue(1 - (index - 1) * 0.3)
            sample.Bar.Name:SetText(entry.name or "")
        else
            self:SkinIcon(sample, style, g, state)
            sample.Icon:SetTexture(entry.icon)
            local cooling = COOLING[index]
            if cooling and sample.Cooldown.SetCooldown then
                pcall(sample.Cooldown.SetCooldown, sample.Cooldown, now - 30 * cooling, 30)
                sample.Icon:SetDesaturated(style.desaturate == true)
                sample.cooldownText:SetText(tostring(math.floor(30 * (1 - cooling) + 0.5)))
            else
                if sample.Cooldown.Clear then sample.Cooldown:Clear() end
                sample.Icon:SetDesaturated(false)
                sample.cooldownText:SetText("")
            end
        end
        self:StyleTexts(id, sample, style, g, false)
        local look = index == 1 and not bar and self:GlowDefaults(id, self:IsBuff(id) and "buff" or "proc") or nil
        self:WantGlow(sample, "proc", look)
        self:ResolveGlows(sample)
        sample:SetAlpha(style.opacity / 100)
        sample:Show()
    end
    for index = count + 1, #(self.testSamples[id] or {}) do self.testSamples[id][index]:Hide() end
end

function M:SetTestDisplay(on)
    on = on and self:CanTestDisplay() or false
    self.testDisplay = on or nil
    self.testSamples = self.testSamples or {}
    if not self.testHost then
        self.testHost = CreateFrame("Frame", nil, UIParent)
        self.testHost:SetAllPoints(UIParent)
    end
    for _, list in pairs(self.testSamples) do for _, sample in ipairs(list) do sample:Hide() end end
    self.testHost:SetShown(on)
    if on then
        for _, id in ipairs(self:BarIds()) do Draw(self, id) end
        if self.castFrame and self.db.castBar.show then self.castFrame:Show(); self:PaintCastSample(self.castFrame) end
    elseif self.castFrame then
        self:RefreshCast()
    end
    if self.window then self:RefreshWindow() end
    return on
end
