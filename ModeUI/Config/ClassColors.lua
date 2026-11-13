local _, addon = ...
local M, W, T = addon.ClassColors, addon.ConfigWidgets, addon.InterfaceTheme
if not M then return end

-- A grid of classes: each shows its current color; click to pick a custom
-- color, Reset to return to the game's color. Changes apply immediately.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local function Combat() return InCombatLockdown() or UnitAffectingCombat("player") end
    page:Section("Class Colors", nil, false)
    local intro = W.Label(page:Row("How It Works", 56), "Click a class to choose its color. Names, health bars and portrait rings that use class colors update right away. Reset returns a class to the game's color.", nil, 0, -4, 420, T.muted)
    intro:SetWordWrap(true)

    local host = page:Row("", 200); host.rowLabel:Hide(); host:ClearAllPoints()
    host:SetPoint("TOPLEFT", host.row, "TOPLEFT", 0, -12)
    host:SetPoint("BOTTOMRIGHT", host.row, "BOTTOMRIGHT", -12, 12)
    local cells = {}
    page.classButtons = {}
    for i, class in ipairs(M.classes) do
        local cell = CreateFrame("Frame", nil, host); cells[i] = cell
        local pick = W.Button(cell, M:ClassName(class), 132, 30); pick:SetPoint("TOPLEFT")
        local swatch = pick:CreateTexture(nil, "OVERLAY"); swatch:SetSize(10, 16); swatch:SetPoint("LEFT", 8, 0)
        local reset = W.Button(cell, "Reset", 60, 26, "secondary"); reset:SetPoint("LEFT", pick, "RIGHT", 6, 0)
        pick:SetScript("OnClick", function()
            if Combat() then return end
            if not ColorPickerFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_ColorPickerFrame") end
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
                print("ModeUI: the color picker is unavailable on this client."); return
            end
            if addon.CloseTimerColorPicker then addon:CloseTimerColorPicker() end
            local old = M.db.colors[class]
            old = old and { old[1], old[2], old[3] }
            local current = M:GetColor(class) or M:NativeColor(class)
            local function Changed()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                M:SetColor(class, { r, g, b })
            end
            addon.timerPickerCallback, addon.timerPickerOwner = Changed, pick
            ColorPickerFrame:SetupColorPickerAndShow({ r = current.r, g = current.g, b = current.b, hasOpacity = false,
                swatchFunc = Changed, cancelFunc = function() M:SetColor(class, old) end })
        end)
        reset:SetScript("OnClick", function() M:SetColor(class, nil) end)
        page.refreshers[#page.refreshers + 1] = function()
            local custom = M.db.colors[class]
            local color = custom and { r = custom[1], g = custom[2], b = custom[3] } or M:NativeColor(class)
            pick:SetLabelColor({ color.r, color.g, color.b, 1 })
            swatch:SetColorTexture(color.r, color.g, color.b, 1)
            reset:SetEnabled(custom ~= nil)
        end
        page.classButtons[class] = { pick = pick, reset = reset, swatch = swatch }
    end
    function host.row:layoutChildren(width)
        local available = width - 12
        local columns = math.max(1, math.min(3, math.floor(available / 210)))
        local size = available / columns
        for i, cell in ipairs(cells) do
            cell:SetSize(size, 44); cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", ((i - 1) % columns) * size, -math.floor((i - 1) / columns) * 44)
        end
        self:SetHeight(math.ceil(#cells / columns) * 44 + 24)
    end

    local resetRow = page:Row("All Classes", 48)
    local resetAll = W.Button(resetRow, "Reset All Classes", 160, 28, "secondary"); resetAll:SetPoint("LEFT")
    resetAll:SetScript("OnClick", function() M:ResetAll() end)
    page.resetAll = resetAll
    local state = W.Label(page:Row("Status", 48), "", nil, 0, -4, 420, T.muted); state:SetWordWrap(true)
    page.refreshers[#page.refreshers + 1] = function()
        local count = 0
        for _ in pairs(M.db.colors) do count = count + 1 end
        resetAll:SetEnabled(count > 0)
        if not M.enabled then state:SetText("Class Colors is off, so ModeUI uses the game's colors. Your custom colors are kept.")
        elseif count == 0 then state:SetText("Using the game's colors for every class.")
        else state:SetText(count == 1 and "1 class has a custom color." or (count .. " classes have custom colors.")) end
    end
    page:Finish(); return page
end
