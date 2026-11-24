local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Swing Timer's page (Forever only; SwingInit.lua): one scrolling page
-- with a section index like the other player bars. Its preview is the
-- Layout view with the swing timer outlined.
function M:SwingPreviewOwner()
    return setmetatable({
        CreateConfigPreview = function(_, parent)
            local frame = CreateFrame("Frame", nil, parent)
            frame:SetAllPoints()
            local view = { frame = frame }
            view.area = CreateFrame("Frame", nil, frame)
            view.caption = W.Label(frame, "", nil, 0, 0, 520, T.muted)
            view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
            function view.Refresh()
                local mode = M.previewMode
                M.previewMode = "layout"
                local drawn = M:RenderStage(view, "swing")
                M.previewMode = mode
                if not drawn then view.caption:SetText(M:SwingStatus()) end
            end
            view.RenderSimulation = view.Refresh
            M.swingPreview = view
            return view
        end,
    }, { __index = M })
end

local function Owner()
    local appearance = setmetatable({}, { __index = function(_, key) return M.db.swing[key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetSwingOption(key, value) end
    return owner
end

function M:CreateSwingPage(parent)
    local page = W.Page(parent, 480); self.swingPage = page
    local function db() return M.db.swing end
    local ui = self:PageHelpers(page, { db = db, set = function(key, value) M:SetSwingOption(key, value) end,
        ranges = M.swingRanges, owner = Owner() })
    local When, Columns = ui.When, ui.Columns
    M:PageScaffold(page, ui, { follows = function(group) return M:PlayerFollows("swing", group) end,
        setFollow = function(group, on) M:FollowPlayerGroup("swing", group, on) end })
    function ui.Tab(title, build)
        ui.Section(title)
        if title ~= "Layout" then
            When(function() return not db().show end, function() W.Tip(ui.Note("This bar is off. Turn on Show Bar under Layout to use it.")) end)
        end
        build()
    end
    W.Preview(page, self:SwingPreviewOwner(), { contentHeight = 120 })

    ui.Tab("Layout", function()
        page.swingShowToggles = ui.Toggles({ { "Show Bar", "show" } })
        page.swingStatus = ui.Status(function() return M:SwingStatus() end)
        page:Group(L["Size"])
        local size = Columns({ "Height" })
        page.swingHeightSlider = ui.Slider(size[1], "height", "px")
        ui.More("swingSize", function()
            local width = Columns({ "Width" })
            page.swingWidthSlider = ui.Slider(width[1], "width", "px")
        end)
        page:Group(L["Swings"])
        page.swingToggles = ui.Toggles({ { "Off-Hand Lane", "offHand" }, { "Ranged Swings", "ranged" }, { "Out of Range Tint", "rangeTint" } })
    end)

    ui.Tab("Look", function()
        page:Group(L["Border"]); ui.Chip("border")
        ui.Styled("border", function()
            ui.Pills("Border", M.swingChoices.border, "border", 96)
            When(function() return db().border ~= "none" end, function()
                local cells = Columns({ "Border Style", "Border Size" })
                ui.Select(cells[1], 180, function() return M.swingChoices.edgeStyle end, "edgeStyle")
                ui.Select(cells[2], 180, function() return M.choices.edgeSize end, "edgeSize")
            end)
        end)
        page:Group(L["Bar"])
        local color = Columns({ "Bar Color" })
        page.swingColorSelect = ui.Select(color[1], 180, function() return M.swingChoices.barColorMode end, "barColorMode")
        When(function() return db().barColorMode == "custom" end, function()
            local custom = Columns({ "Custom Color" })
            ui.Color(custom[1], "barColor")
        end)
        ui.More("swingBar", function()
            local textures = Columns({ "Bar Texture", "Bar Background" })
            ui.Select(textures[1], 180, function() return addon.Kit.BarTextureChoices(true) end, "barTexture")
            ui.Select(textures[2], 180, function() return addon.Kit.BarTextureChoices(false) end, "barBackground")
            local back = Columns({ "Background Opacity" })
            ui.Slider(back[1], "barBackgroundOpacity", "%")
        end)
    end)

    ui.Tab("Text", function()
        page:Group(L["Timer"])
        page.swingTimerToggles = ui.Toggles({ { "Show", "timerShow" } })
        When(function() return db().timerShow end, function()
            local size = Columns({ "Size" })
            ui.Slider(size[1], "textSize")
        end)
        page:Group(L["Font"]); ui.Chip("text")
        ui.Styled("text", function()
            local _, fontRefresh = W.FontDropdown(page:Row(L["Font"], 48), ui.owner); ui.Refresh(fontRefresh)
            ui.Toggles({ { "Outline", "outline" }, { "Text Shadow", "shadow" }, { "Sharp Text", "slug" } })
        end)
    end)

    ui.Tab("Show", function()
        page:Group(L["When to Show"])
        local opacity = Columns({ "Opacity" })
        page.swingOpacitySlider = ui.Slider(opacity[1], "opacity", "%")
        W.Tip(ui.Note("The swing timer shows while you swing, and with a sample in Edit Mode and Test on Screen.", 32))
        ui.More("swingShow", function()
            page.swingResetButton = ui.Button("Reset to Defaults", 150, function() M:ResetSwing() end)
        end)
    end)

    page:Finish()
    return page
end
