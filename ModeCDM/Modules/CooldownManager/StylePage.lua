local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Bar Style page (owner, November 24, 2026): the default look for bars.
-- New bars start with it; existing bars use it if you choose (each bar's
-- chips, or Use Bar Style on Every Bar). Above it the Bar Style drawn on
-- sample icons and a bar (StylePreview.lua); one scrolling page with a
-- section index: Presets, Size, Border, Background, Cooldown, Text,
-- Starting Glow Look and Bar Fill.
local function Owner()
    local appearance = setmetatable({}, { __index = function(_, key) return M.db.barStyle[key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetBarStyle(key, value) end
    return owner
end

function M:CreateStylePage(parent)
    local page = W.Page(parent, 480); self.stylePage = page
    local function db() return M.db.barStyle end
    local ui = self:PageHelpers(page, { db = db, set = function(key, value) M:SetBarStyle(key, value) end,
        ranges = M.barStyleRanges, owner = Owner() })
    M:PageScaffold(page, ui)
    W.Preview(page, self:StylePreviewOwner(), { contentHeight = 170 })
    W.Tip(ui.Note("The default look for bars. New bars start with it; existing bars use it if you choose: each bar's chips, or Use Bar Style on Every Bar below.", 40))

    ui.Section("Presets")
    page:Group(L["Start From"])
    local choices = {}
    for _, tag in ipairs(M.barStylePresetOrder) do choices[#choices + 1] = { label = L[M.barStylePresets[tag].label], value = tag, width = 120 } end
    local buttons, refresh = W.Exclusive(page:Row(L["Preset"], 48), choices, function() return M:BarStylePreset() end,
        function(tag) M:ApplyBarStylePreset(tag) end)
    ui.Refresh(refresh); page.presetButtons = buttons
    page.useEverywhereButton = ui.Button("Use Bar Style on Every Bar", 220, function() M:UseBarStyleEverywhere() end)

    ui.Section("Size")
    page:Group(L["Large Icons"])
    W.Tip(ui.Note("Essential, Utility and your Cooldown Bars.", 28))
    local large = ui.Columns({ "Width", "Height" })
    ui.Slider(large[1], "largeWidth", "px"); ui.Slider(large[2], "largeHeight", "px")
    page:Group(L["Small Icons"])
    W.Tip(ui.Note("Tracked Buffs and your Buff Bars.", 28))
    local small = ui.Columns({ "Width", "Height" })
    ui.Slider(small[1], "smallWidth", "px"); ui.Slider(small[2], "smallHeight", "px")
    page:Group(L["Spacing"])
    local spacing = ui.Columns({ "Spacing" })
    page.styleSpacingSlider = ui.Slider(spacing[1], "spacing", "px")

    ui.Section("Border")
    page:Group(L["Border"])
    page.styleBorderPills = ui.Pills("Border", M.choices.border, "border", 96)
    ui.When(function() return db().border ~= "none" end, function()
        page.styleBorderStylePicker, page.styleBorderMetalPicker = W.BorderPickers(page,
            { get = function() return db().edgeStyle end, set = ui.Set("edgeStyle") },
            { get = function() return db().edgeMetal end, set = ui.Set("edgeMetal") }, { labels = { "Border Style", "Border Color" } })
        local size = ui.Columns({ "Border Size" })
        ui.Select(size[1], 180, function() return M.choices.edgeSize end, "edgeSize")
        ui.When(function() return addon.Style.IsFlatStyle(db().edgeStyle) end, function()
            local color = ui.Columns({ "Band Color" })
            ui.Color(color[1], "edgeColor")
        end)
    end)
    W.Tip(ui.Note("The resource bars and the Cast Bar take this border and the font below too.", 28))

    ui.Section("Background")
    page:Group(L["Background"])
    local background = ui.Columns({ "Background Color", "Background Opacity" })
    ui.Color(background[1], "backgroundColor")
    ui.Slider(background[2], "backgroundOpacity", "%")

    ui.Section("Cooldown")
    page:Group(L["Cooldown"])
    ui.Toggles({ { "Gray on Cooldown", "desaturate" }, { "Out of Range Tint", "rangeTint" } })
    local swipe = ui.Columns({ "Swipe Color", "Swipe Opacity" })
    ui.Color(swipe[1], "swipeColor")
    ui.Slider(swipe[2], "swipeOpacity", "%")
    ui.More("styleCooldown", function()
        ui.Toggles({ { "Show Effect Time", "auraSwipe" }, { "Swipe Edge", "showEdge" }, { "Finish Sparkle", "showBling" }, { "Ready Flash", "showFlash" } })
    end)

    ui.Section("Text")
    page:Group(L["Text"])
    W.Tip(ui.Note("Sizes are for the size above; a taller or shorter icon scales them.", 28))
    local cooldown = ui.Columns({ "Cooldown Numbers", "Small Icons" })
    ui.Slider(cooldown[1], "cooldownSize"); ui.Slider(cooldown[2], "cooldownSizeSmall")
    local count = ui.Columns({ "Count", "Small Icons" })
    ui.Slider(count[1], "countSize"); ui.Slider(count[2], "countSizeSmall")
    local colors = ui.Columns({ "Cooldown Color", "Count Color" })
    ui.Color(colors[1], "cooldownColor"); ui.Color(colors[2], "countColor")
    local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), Owner()); ui.Refresh(fontRefresh)
    ui.Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Sharp Text", "slug" } })
    ui.More("styleText", function()
        local bars = ui.Columns({ "Tracked Bars Text" })
        ui.Slider(bars[1], "barTextSize")
    end)

    ui.Section("Starting Glow Look")
    W.Tip(ui.Note("Glows start off on every spell. A glow you switch on in a spell's menu starts with this look.", 40))
    for _, kind in ipairs(M.glowKinds) do
        page:Group(L[M.glowLabels[kind]])
        ui.Pills("Style", M.glowStyles, kind .. "Glow", 84)
        local color = ui.Columns({ "Glow Color" })
        ui.Color(color[1], kind .. "Color")
        ui.Toggles({ { "Pulse", kind .. "Pulse" } })
    end
    ui.More("styleGlows", function()
        page.styleReadyPills = ui.Pills("Ready Glow", M.choices.readyMode, "readyMode", 110)
        local timing = ui.Columns({ "Glow Time", "Pixel Lines", "Pixel Thickness" })
        ui.Slider(timing[1], "readyDuration", "s"); ui.Slider(timing[2], "glowLines"); ui.Slider(timing[3], "glowThickness", "px")
    end)

    ui.Section("Bar Fill")
    page:Group(L["Tracked Bars"])
    local fill = ui.Columns({ "Bar Color" })
    ui.Select(fill[1], 200, function() return M.choices.barColorMode end, "barColorMode")
    ui.When(function() return db().barColorMode == "custom" end, function()
        local custom = ui.Columns({ "Custom Color" })
        ui.Color(custom[1], "barColor")
    end)
    local textures = ui.Columns({ "Bar Texture", "Bar Background" })
    ui.Select(textures[1], 200, function() return addon.Kit.BarTextureChoices(true) end, "barTexture")
    ui.Select(textures[2], 200, function() return addon.Kit.BarTextureChoices(false) end, "barBackground")
    local opacity = ui.Columns({ "Background Opacity" })
    ui.Slider(opacity[1], "barBackgroundOpacity", "%")
    ui.Toggles({ { "Spark", "showSpark" } })

    page:Finish()
    return page
end
