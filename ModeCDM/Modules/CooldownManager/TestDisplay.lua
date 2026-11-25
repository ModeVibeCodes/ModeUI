local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- Test on Screen (owner, November 24, 2026): out of combat, every icon bar
-- that shows draws sample icons in its real place (its own frames over the
-- holder, never Blizzard's), some cooling and one lit; the Cast Bar and the
-- Swing Timer show their samples. While it runs a bar at the top of the
-- screen says so with a Stop Test button (owner, November 24, 2026: there
-- was no clear way to stop it). It also stops when combat starts, the
-- window closes, the module is switched off, or either Test on Screen
-- button (the window's header, the preview's) is pressed again.
--
-- The state lives on the module itself: the Bar Style, Cast Bar, resource
-- and Swing Timer previews hand the shared preview widget a proxy of the
-- module, and a test started from one of them used to keep its state on the
-- proxy, where closing the window couldn't find it.
local SAMPLE_ICON = 134400 -- the question mark icon
local COOLING = { [2] = 0.45, [4] = 0.8, [6] = 0.25 }
local Style = addon.Style

function M:CanTestDisplay()
    return M.active == true and M.built == true and not addon.InCombat()
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

-- The bar at the top of the screen while the test runs: what it is, and Stop Test.
local function Banner(self)
    if self.testBanner then return self.testBanner end
    local banner = CreateFrame("Frame", "ModeUICooldownTestBanner", self.testHost)
    banner:SetFrameStrata("DIALOG")
    banner:SetSize(420, 44)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -96)
    banner:EnableMouse(true)
    banner.fill = W.Fill(banner, T.background, "BACKGROUND")
    banner.edge = Style.Edge(banner, M.EDGE, { pieces = true })
    banner.edge:Layout()
    banner.label = W.Label(banner, L["Test on Screen: sample spells on your bars"], nil, 14, -15, 270, T.text)
    banner.label:SetWordWrap(false)
    banner.stop = W.Button(banner, L["Stop Test"], 110, 28, "primary")
    banner.stop:SetPoint("RIGHT", banner, "RIGHT", -8, 0)
    banner.stop:SetScript("OnClick", function() M:SetTestDisplay(false) end)
    self.testBanner = banner
    return banner
end

-- Starts (true) or stops the test; returns whether it runs now. The
-- previews call it on their proxies (see above), so it always works on M.
function M.SetTestDisplay(_, on)
    local self = M
    on = on and self:CanTestDisplay() or false
    self.testDisplay = on or nil
    -- The shared preview's Test on Screen button reads `testing`.
    self.testing = on or nil
    self.testSamples = self.testSamples or {}
    if not self.testHost then
        self.testHost = CreateFrame("Frame", nil, UIParent)
        self.testHost:SetAllPoints(UIParent)
    end
    for _, list in pairs(self.testSamples) do for _, sample in ipairs(list) do sample:Hide() end end
    self.testHost:SetShown(on)
    if on then
        Banner(self):Show()
        for _, id in ipairs(self:BarIds()) do Draw(self, id) end
        if self.castFrame and self.db.castBar.show then self.castFrame:Show(); self:PaintCastSample(self.castFrame) end
    elseif self.castFrame then
        self:RefreshCast()
    end
    if self.swingFrame then self:RenderSwingMover() end
    if self.window then self:RefreshWindow() end
    return on
end
