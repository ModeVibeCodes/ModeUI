local _, addon = ...
local M, W, T = addon.Optimizations, addon.ConfigWidgets, addon.InterfaceTheme
if not M then return end

-- One tab per area: Loot, Error Text, Camera, UI Scale. Each optimization is
-- off until turned on; its status line says what ModeUI did to the game setting.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Toggles(items) return page:ToggleGrid(items, { maxColumns = 2, minimumCellWidth = 210 }) end
    local function Option(label, key) return { label = label, get = function() return M.db[key] end, set = function(v) M:SetOption(key, v) end } end
    local function When(predicate, build)
        local start = #page.rows; build()
        for i = start + 1, #page.rows do page.rows[i].visibleWhen = predicate end
    end
    local function Status(key)
        local label = W.Label(page:Row("Status", 48), "", nil, 0, -4, 420, T.muted); label:SetWordWrap(true)
        Refresh(function()
            local text = M.status[key]
            if not M.enabled then text = "Optimizations is off; every game setting is back to its own value." end
            label:SetText(text or "Applies when you log in.")
        end)
        return label
    end
    local function Note(title, text, height)
        local label = W.Label(page:Row(title, height or 52), text, nil, 0, -4, 420, T.muted); label:SetWordWrap(true)
        return W.Note(label)
    end

    -- Shown on the Camera and UI Scale tabs while Play The Game Tools is loaded.
    page.otherManagerNotes = {}
    local function OtherNote()
        local label = W.Tip(Note("Play The Game Tools", "Play The Game Tools is also loaded and has its own Optimizations. If both set the camera distance or UI scale, the last one to apply wins, so turn it on in only one of them.", 56))
        label:GetParent().row.visibleWhen = function() return M:OtherManager() ~= nil end
        page.otherManagerNotes[#page.otherManagerNotes + 1] = label
    end

    page:Section("Loot", nil, false)
    page.lootToggles = Toggles({ Option("Auto Loot", "autoLoot"), Option("Fast Loot", "fastLoot") })
    Note("How It Works", "Auto Loot turns on the game's auto loot. Fast Loot takes every item the moment the loot window opens; it works whenever the game is auto looting.", 56)
    page.lootStatus = Status("autoLoot")

    page:Section("Error Text", nil, false)
    page.errorToggles = Toggles({ Option("Hide Error Text", "hideErrors") })
    Note("How It Works", "Hides the red error messages in the middle of the screen, such as \"Not enough energy\".", 44)
    page.errorStatus = Status("hideErrors")

    page:Section("Camera", nil, false)
    page.cameraToggles = Toggles({ Option("Set Max Camera Distance", "manageCamera") })
    When(function() return M.db.manageCamera end, function()
        local row = page:Row("Max Camera Distance", 48)
        Refresh(W.Slider(row, M.ranges.cameraZoom[1], M.ranges.cameraZoom[2], 0.1, function() return M.db.cameraZoom end,
            function(v) M:SetOption("cameraZoom", math.floor(v * 10 + 0.5) / 10) end, "x", { decimals = 1 }))
        page.cameraSlider = row.slider
    end)
    page.cameraStatus = Status("camera")
    OtherNote()

    page:Section("UI Scale", nil, false)
    page.scaleToggles = Toggles({ Option("Set UI Scale", "manageScale") })
    When(function() return M.db.manageScale end, function()
        local buttons, refresh = W.Exclusive(page:Row("Scale", 48), {
            { label = "Pixel Perfect", value = "auto", width = 132 }, { label = "Custom", value = "custom", width = 110 } },
            function() return M.db.scaleMode end, function(value) M:SetOption("scaleMode", value) end)
        page.scaleModeButtons = buttons; Refresh(refresh)
    end)
    When(function() return M.db.manageScale and M.db.scaleMode == "custom" end, function()
        local row = page:Row("Custom Scale", 48)
        Refresh(W.Slider(row, M.ranges.uiScale[1], M.ranges.uiScale[2], 1, function() return M.db.uiScale end,
            function(v) M:SetOption("uiScale", math.floor(v + 0.5)) end, "%", true))
        page.scaleSlider = row.slider
    end)
    local detected = W.Label(page:Row("Your Screen", 48), "", nil, 0, -4, 420, T.muted)
    Refresh(function()
        local width, height = M:Resolution()
        local recommended = M:RecommendedScale()
        detected:SetText(width and string.format("%d x %d. Pixel Perfect is %.2f%%.", width, height, recommended) or "Resolution isn't available yet.")
    end)
    page.scaleStatus = Status("scale")
    OtherNote()

    W.PinnedSectionTabs(page)
    page:Finish(); return page
end
