local _, addon = ...
-- Edit Mode panel's resize grip (docs/DESIGN_LANGUAGE.md, "Edit Mode"): the
-- grip in its bottom corner (bottom-left while pinned, as the panel then
-- grows left from the screen's edge) sets its width and height, from the
-- panel's default width by MIN_HEIGHT up to MAX_WIDTH and the screen; the
-- size is saved for the account (ModeUIDB.editMode.panelWidth/panelHeight).
-- The borrowed page lays out again at the new width, so a wide enough panel
-- shows every tab.
local MIN_HEIGHT, MAX_WIDTH = 320, 900
local Combat = addon.InCombat

-- Builds the grip on `panel` and applies the saved size.
function addon:CreateEditPanelGrip(panel)
    local function Saved() return addon.root and addon.root.editMode end
    local function Cursor()
        if type(GetCursorPosition) ~= "function" then return end
        local x, y = GetCursorPosition()
        local scale = panel:GetEffectiveScale()
        if type(x) ~= "number" or type(y) ~= "number" or not scale or scale <= 0 then return end
        return x / scale, y / scale
    end
    local WIDTH, HEIGHT = addon.EDIT_PANEL_SIZE[1], addon.EDIT_PANEL_SIZE[2]
    function panel:ApplySize(width, height)
        local ratio = UIParent:GetEffectiveScale() / math.max(0.01, self:GetEffectiveScale())
        width = math.max(WIDTH, math.min(MAX_WIDTH, UIParent:GetWidth() * ratio - 16, width))
        height = math.max(MIN_HEIGHT, math.min(UIParent:GetHeight() * ratio - 60, height))
        self:SetSize(width, height)
        local saved = Saved()
        if saved then saved.panelWidth, saved.panelHeight = width, height end
        local page = addon.EditPage:Page()
        if page and page:IsShown() then
            if page.sectionTabs then page.sectionTabs:Layout() end
            page:Layout()
        end
    end
    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(16, 16); grip:SetFrameLevel(panel:GetFrameLevel() + 30)
    grip.icon = grip:CreateTexture(nil, "OVERLAY"); grip.icon:SetAllPoints()
    addon.Media:ApplyTexture(grip.icon, "ResizeGrip"); grip.icon:SetAlpha(0.45)
    grip:SetScript("OnEnter", function() grip.over = true; grip.icon:SetAlpha(1) end)
    grip:SetScript("OnLeave", function() grip.over = false; if not grip.from then grip.icon:SetAlpha(0.45) end end)
    -- The bottom-right corner, or bottom-left while pinned (the art mirrored).
    function grip:Place()
        self:ClearAllPoints()
        if panel.pinned then self:SetPoint("BOTTOMLEFT", 3, 3); self.icon:SetTexCoord(1, 0, 0, 1)
        else self:SetPoint("BOTTOMRIGHT", -3, 3); self.icon:SetTexCoord(0, 1, 0, 1) end
    end
    local function Track()
        local x, y = Cursor()
        local from = grip.from
        if not x or not from then return end
        local dx, dy = x - from.x, y - from.y
        panel:ApplySize(from.width + (panel.pinned and -dx or dx), from.height - dy)
    end
    grip:SetScript("OnMouseDown", function()
        if Combat() then return end
        local x, y = Cursor()
        if not x then return end
        -- Held by the corner that stays put while it grows.
        local left, top, right = panel:GetLeft(), panel:GetTop(), panel:GetRight()
        if left and top and right then
            panel:ClearAllPoints()
            if panel.pinned then panel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
            else panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top) end
        end
        grip.from = { x = x, y = y, width = panel:GetWidth(), height = panel:GetHeight() }
        grip:SetScript("OnUpdate", Track)
    end)
    grip:SetScript("OnMouseUp", function()
        Track()
        grip.from = nil; grip:SetScript("OnUpdate", nil)
        if not grip.over then grip.icon:SetAlpha(0.45) end
    end)
    panel.grip = grip
    local saved = Saved()
    panel:ApplySize(saved and saved.panelWidth or WIDTH, saved and saved.panelHeight or HEIGHT)
    grip:Place()
end
