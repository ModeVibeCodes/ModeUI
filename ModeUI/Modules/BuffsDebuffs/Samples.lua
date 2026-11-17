local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Sample auras: in ModeUI's Edit Mode each bar that's on is filled with them
-- (its container waits), and the settings preview draws the bar being
-- edited with them. Laid out as the container lays out real auras: from the
-- start corner, the way the bar grows, rows across, kinds in bar order.
-- Each sample lists the kinds it counts as and, for debuffs, its type.
local Kit = addon.Kit
local ICON = "Interface\\Icons\\"
M.SAMPLES = {
    buffs = {
        { icon = "Spell_Holy_PowerWordShield", cats = { "bigdef", "mine", "cancelable", "short" }, time = "8" },
        { icon = "Spell_Nature_StoneClawTotem", cats = { "extdef", "short" }, time = "10" },
        { icon = "Spell_Nature_Bloodlust", cats = { "important", "short" }, time = "32" },
        { icon = "Spell_Frost_ColdHearted", cats = { "important", "mine", "cancelable", "short" }, time = "18" },
        { icon = "Spell_Holy_Renew", cats = { "hots", "short" }, time = "12" },
        { icon = "Spell_Nature_Rejuvenation", cats = { "hots", "short" }, time = "9", count = "2" },
        { icon = "Spell_Holy_MagicalSentry", cats = { "mine", "cancelable" }, time = "56m" },
        { icon = "Spell_Holy_WordFortitude", cats = { "cancelable" }, time = "1h" },
        { icon = "INV_Misc_Food_15", cats = { "cancelable" }, time = "48m" },
        { icon = "INV_Stone_02", cats = { "enchant" }, time = "1h", enchant = true },
    },
    debuffs = {
        { icon = "Spell_Shadow_Possession", cats = { "cc", "dispellable" }, type = "Magic", time = "4" },
        { icon = "Spell_Shadow_ShadowWordPain", cats = { "dispellable" }, type = "Magic", time = "14" },
        { icon = "Spell_Shadow_ShadowBolt", cats = { "boss" }, time = "22" },
        { icon = "Spell_Shadow_CurseOfMannoroth", cats = {}, type = "Curse", time = "1m" },
        { icon = "Spell_Shadow_AbominationExplosion", cats = {}, type = "Disease", time = "18", count = "3" },
        { icon = "Ability_PoisonSting", cats = {}, type = "Poison", time = "9", count = "2" },
        { icon = "Ability_Gouge", cats = {}, type = "Bleed", time = "11" },
        { icon = "Spell_Shadow_UnholyFrenzy", cats = {}, time = "25" },
    },
}

-- Whether a sample shows on a bar, and under which kind (its place in line).
local function Rank(self, bar, sample)
    for index, category in ipairs(self.categories[bar.kind]) do
        if bar.cats[category.id] then
            local match
            if category.all then match = not sample.enchant
            elseif category.enchant then match = sample.enchant
            elseif category.dispel then match = sample.type == category.dispel
            elseif category.other then match = sample.type == nil and not sample.enchant
            else
                for _, id in ipairs(sample.cats) do if id == category.id then match = true end end
            end
            if match then return index end
        end
    end
end

-- The samples a bar shows, in its order, at most its Max Shown.
function M:SampleList(bar)
    local list = {}
    for order, sample in ipairs(self.SAMPLES[bar.kind]) do
        local rank = Rank(self, bar, sample)
        if rank then list[#list + 1] = { sample = sample, rank = rank, order = order } end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)
    local shown = {}
    for index = 1, math.min(#list, bar.max) do shown[index] = list[index].sample end
    return shown
end

-- The rim: the debuff type's color with By Type, else the bar's metal.
local function Rim(bar, sample)
    if bar.byType and bar.kind == "debuffs" then
        return addon.Style.Tone.debuffType[sample.type] or addon.Style.Tone.metal.gunmetal.mid
    end
end

-- Lays a bar's samples into `host` from its start corner. pool holds the
-- icons made so far; returns how many show.
function M:PaintSamples(host, pool, bar, px)
    local samples = self:SampleList(bar)
    local cw, ch = self:CellSize(bar, px)
    local _, iconHeight = self:IconSize(bar, px)
    -- The icon sits at the top of its cell (time text below it).
    local lift = ch - iconHeight
    local spacing = bar.spacing * px
    local corner = self:StartCorner(bar)
    local horizontal = self.HORIZONTAL[bar.grow]
    local dx = corner:find("RIGHT") and -1 or 1
    local dy = corner:find("TOP") and -1 or 1
    for index, sample in ipairs(samples) do
        local icon = pool[index]
        if not icon then
            icon = Kit.AuraIcon(host)
            icon.below = Kit.Text(icon)
            pool[index] = icon
        end
        local _, _, path = self:LayoutIcon(icon, bar, px)
        icon.icon:SetTexture(ICON .. sample.icon)
        Kit.Write(icon.count, bar.count and sample.count or "")
        icon.cooldown:Hide()
        local shownTime = bar.timer ~= "none" and sample.time or ""
        icon.timer:SetText(bar.timer == "center" and shownTime or "")
        self:LayoutBelow(icon.below, bar, px, path, icon)
        icon.below:SetText(bar.timer == "below" and shownTime or "")
        Kit.TintAuraRim(icon, Rim(bar, sample))
        local glow = bar.glow ~= "none" and (bar.glowColor == "custom" and bar.glowCustomColor
            or (bar.kind == "debuffs" and (addon.Style.Tone.debuffType[sample.type] or addon.Style.Tone.metal.gunmetal.mid))) or nil
        Kit.GlowAura(icon, glow, bar.glow)
        local slot, line = (index - 1) % bar.perRow, math.floor((index - 1) / bar.perRow)
        local column, row = horizontal and slot or line, horizontal and line or slot
        icon:ClearAllPoints()
        icon:SetPoint(corner, host, corner, dx * column * (cw + spacing), dy * row * (ch + spacing) + (dy < 0 and 0 or lift))
        icon:Show()
    end
    for index = #samples + 1, #pool do pool[index]:Hide() end
    return #samples
end

-- Edit Mode: a bar that's on shows its samples on its holder.
function M:RenderSamples(id)
    local holder = self.holders and self.holders[id]
    if not holder then return end
    local pool = self.samples[id] or {}
    self.samples[id] = pool
    local show = self.editing == true and self.active == true and self.db.bars[id] and self.db.bars[id].show
    if show then self:PaintSamples(holder, pool, self.db.bars[id], Kit.PixelSize(holder))
    else for _, icon in ipairs(pool) do icon:Hide() end end
end
