local _, addon = ...
-- The settings window (docs/DESIGN_LANGUAGE.md, "Settings window"): one hybrid
-- window that changes shape. The main panel is the full sidebar with the
-- General page; a visual module (layout = "split") folds the sidebar into the
-- icon rail, puts its settings in a 432px column and a live preview beside it;
-- a simple module (layout = "page") keeps the sidebar and the whole page.
-- Header: MODE wordmark, "‹ All modules" with a breadcrumb, search, profile,
-- close. Footer: Reload and Preview, then Edit Mode, Reset and Done.
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local Style = addon.Style
local S = W.SETTINGS_SIZES
local WINDOW_WIDTH, WINDOW_HEIGHT, HEADER_HEIGHT, FOOTER_HEIGHT = S.width, S.height, S.header, S.footer
local SIDEBAR_WIDTH, RAIL_WIDTH = S.sidebar, S.rail
-- The header's right side (search, profile, close) is never a drag handle.
local HEADER_RESERVED = 400

local InCombat = addon.InCombat
-- An open window shows a module's new on/off state at once.
addon.RegisterMessage("ModeUI.SettingsWindow", addon.Messages.MODULE_TOGGLED, function()
    if addon.RefreshConfig then addon:RefreshConfig() end
end)
function addon:RecoverWindowPosition()
    local window=self.configWindow
    if not window or InCombat() then return false end
    local ratio=window:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local w,h=window:GetWidth()*ratio,window:GetHeight()*ratio
    local keep=math.min(40,width/4,height/4)
    -- Retain a draggable header fragment, not the full window rectangle.
    local minX=-width/2-w/2+(window.headerReserved or HEADER_RESERVED)*ratio+keep
    local maxX=width/2+w/2-keep
    local minY=-height/2-h/2+keep
    local maxY=height/2-h/2+HEADER_HEIGHT*ratio-keep
    self.root.window.x=math.max(minX,math.min(maxX,self.root.window.x))
    self.root.window.y=math.max(minY,math.min(maxY,self.root.window.y))
    return true
end
function addon:ResetConfigWindowPosition()
    if InCombat() then print("ModeUI: reset the configuration window outside combat.");return false end
    self:FinishWindowInteraction()
    self.root.window.x,self.root.window.y=0,0
    if not self.configWindow then self:CreateConfig() end
    self:UpdateWindowBounds();self.configWindow:Show();return true
end

function addon:FinishWindowInteraction()
    local window = self.configWindow
    if not window or not window.moving then return end
    window:StopMovingOrSizing()
    window.moving = false
    -- A drag leaves the window anywhere: its borders snap to whole pixels again.
    W.SnapSettings()
    local ratio = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = window:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        self.root.window.x, self.root.window.y = x * ratio - parentX, y * ratio - parentY
    end
    if InCombat() then
        addon.Defer:Queue("settings:bounds", function() addon:UpdateWindowBounds() end)
    else
        self:RecoverWindowPosition()
        window:ClearAllPoints()
        window:SetPoint("CENTER", UIParent, "CENTER", self.root.window.x / ratio, self.root.window.y / ratio)
    end
end

function addon:UpdateWindowBounds(initial)
    local window = self.configWindow
    if not window then return end
    if InCombat() and not initial then addon.Defer:Queue("settings:bounds", function() addon:UpdateWindowBounds() end); return end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    -- Legacy saved dimensions are intentionally ignored and left untouched.
    local scale = math.min(1, math.max(1, width - 32) / WINDOW_WIDTH, math.max(1, height - 32) / WINDOW_HEIGHT)
    window:SetScale(scale)
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    if not InCombat() then self:RecoverWindowPosition() end
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", self.root.window.x / scale, self.root.window.y / scale)
    W.RefreshPixelInsets()
end

-- A 1px black separator along one side of a frame.
local function Line(frame, side)
    local line = W.Fill(frame, T.line, "BORDER")
    line:ClearAllPoints()
    if side == "BOTTOM" or side == "TOP" then
        line:SetPoint(side .. "LEFT", 0, 0); line:SetPoint(side .. "RIGHT", 0, 0); line:SetHeight(1)
    else
        line:SetPoint("TOP" .. side, 0, 0); line:SetPoint("BOTTOM" .. side, 0, 0); line:SetWidth(1)
    end
    return line
end
W.SettingsLine = Line

-- A Graphite surface in a Mode texture, tiled 1:1 when the texture tiles.
local function Surface(frame, key, color, sublevel)
    local texture = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel or 0)
    texture:SetAllPoints()
    Style.ApplyAsset(texture, key)
    texture:SetVertexColor(color[1], color[2], color[3], 1)
    if Style.TILE_SIZE[key] then
        local function Fit(owner, w, h) Style.TileCoords(texture, key, w, h, Style.Pixel(owner)) end
        frame:HookScript("OnSizeChanged", Fit)
        Fit(frame, frame:GetWidth(), frame:GetHeight())
    end
    return texture
end
W.SettingsSurface = Surface

function addon:CreateConfig()
    local window = CreateFrame("Frame", "ModeUIConfigWindow", UIParent)
    window:Hide()
    self.configWindow = window
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(false)
    window:EnableMouse(true)
    window.canvas = Surface(window, "Surface", T.background, -8)
    -- Above the header and footer, so its rounded corners cover their square ones.
    window.edge = Style.Edge(window, "window", { level = 20 })
    window.headerReserved = HEADER_RESERVED

    -- Header.
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(HEADER_HEIGHT)
    header:SetFrameLevel(window:GetFrameLevel() + 10)
    Surface(header, "FG", T.header)
    Line(header, "BOTTOM")
    local drag = CreateFrame("Frame", nil, header)
    drag:SetAllPoints(); drag:SetFrameLevel(header:GetFrameLevel() + 1)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if InCombat() then return end
        window.moving = true
        window:StartMoving()
    end)
    drag:SetScript("OnDragStop", function() self:FinishWindowInteraction() end)
    window.header, window.headerBar = drag, header
    local controls = CreateFrame("Frame", nil, header)
    controls:SetAllPoints(); controls:SetFrameLevel(header:GetFrameLevel() + 2); controls:EnableMouse(false)
    window.headerControls = controls
    local function Control(button) button:SetFrameLevel(controls:GetFrameLevel() + 1); return button end
    -- The wordmark: "Mode" in Mode Script (Damion), Ivory.
    local wordmark = Control(W.Button(controls, "Mode", 64, 24, "quiet"))
    wordmark:SetPoint("LEFT", 8, 0)
    addon.Media:BindFixedFont(wordmark.label, addon.Style.SCRIPT_FONT, T.fontSize.brand, addon.Style.FontPath("bold"))
    wordmark:SetLabelColor(T.primary)
    wordmark:SetScript("OnClick", function() self:ConfigBack() end)
    window.wordmark, window.title = wordmark, wordmark.label
    local back = Control(W.Button(controls, "‹ All modules", 100, 22))
    back:SetPoint("LEFT", wordmark, "RIGHT", 6, 0)
    back:SetScript("OnClick", function() self:ShowConfigHome() end)
    local crumb = W.Label(controls, "ModeUI ›", nil, 0, 0, 60, T.muted)
    crumb:ClearAllPoints(); crumb:SetPoint("LEFT", back, "RIGHT", 10, 0); crumb:SetWidth(0)
    addon.Media:BindInterfaceFont(crumb, GameFontHighlight, T.fontSize.small)
    local crumbTitle = W.Label(controls, "", nil, 0, 0, 220, T.heading)
    crumbTitle:ClearAllPoints(); crumbTitle:SetPoint("LEFT", crumb, "RIGHT", 4, 0)
    addon.Media:BindInterfaceFont(crumbTitle, GameFontHighlight, T.fontSize.small, nil, "heading")
    window.backButton, window.crumb, window.crumbTitle = back, crumb, crumbTitle
    local close = Control(W.Button(controls, "×", 24, 24, "quiet"))
    close:SetPoint("RIGHT", -8, 0)
    addon.Media:BindInterfaceFont(close.label, GameFontHighlight, T.fontSize.page)
    close:SetScript("OnClick", function() window:Hide() end)
    window.closeButton = close
    local profileHost = CreateFrame("Frame", nil, controls)
    profileHost:SetSize(140, 24); profileHost:SetPoint("RIGHT", close, "LEFT", -10, 0)
    profileHost:SetFrameLevel(controls:GetFrameLevel() + 1)
    window.profileSelect = W.Select(profileHost, 140, function()
        local list = {}
        for _, name in ipairs(addon.Profiles:List()) do list[#list + 1] = { id = name, label = name } end
        return list
    end, function()
        local name = addon.Profiles:Pending() or addon.Profiles:Active()
        return name, "Profile · " .. tostring(name)
    end, function(name)
        local _, message = addon.Profiles:Select(name)
        if message then addon:PrintAction(message, "profile") end
    end)

    -- Footer.
    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(FOOTER_HEIGHT)
    footer:SetFrameLevel(window:GetFrameLevel() + 10)
    Surface(footer, "Solid", T.header)
    Line(footer, "TOP")
    window.footer = footer
    local function FooterButton(label, width, style)
        local button = W.Button(footer, label, width, 24, style)
        button:SetFrameLevel(footer:GetFrameLevel() + 1)
        return button
    end
    local done = FooterButton("Done", 64, "primary"); done:SetPoint("RIGHT", -12, 0)
    done:SetScript("OnClick", function() window:Hide() end)
    local reset = FooterButton("Reset", 64, "danger"); reset:SetPoint("RIGHT", done, "LEFT", -8, 0)
    reset:SetScript("OnClick", function() self:ResetSelectedModule() end)
    local edit = FooterButton("Edit Mode", 84); edit:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    edit:SetScript("OnClick", function() self:SetEditMode(not self.editMode) end)
    local reload = FooterButton("Reload", 64); reload:SetPoint("LEFT", 12, 0)
    reload:SetScript("OnClick", function()
        local _,reason=self.ReloadManager:Reload()
        print("ModeUI: "..reason)
    end)
    local preview = FooterButton("Preview", 72); preview:SetPoint("LEFT", reload, "RIGHT", 8, 0)
    preview:SetScript("OnClick", function() self:SetPreviewMode(not self.previewMode) end)
    window.doneButton, window.resetButton, window.editButton = done, reset, edit
    window.reloadButton, window.previewButton = reload, preview

    -- Sidebar, icon rail and body.
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT); sidebar:SetPoint("BOTTOMLEFT", 0, FOOTER_HEIGHT)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    Surface(sidebar, "FGBase", T.sidebar); Line(sidebar, "RIGHT")
    local rail = CreateFrame("Frame", nil, window)
    rail:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT); rail:SetPoint("BOTTOMLEFT", 0, FOOTER_HEIGHT)
    rail:SetWidth(RAIL_WIDTH)
    Surface(rail, "FGBase", T.sidebar); Line(rail, "RIGHT")
    rail:Hide()
    window.sidebar, window.rail = sidebar, rail
    local body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0); body:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)
    window.body = body
    local column = CreateFrame("Frame", nil, body)
    window.column = column
    column.line = Line(column, "RIGHT")
    local pane = CreateFrame("Frame", nil, body)
    pane:SetPoint("TOPLEFT", column, "TOPRIGHT", 0, 0); pane:SetPoint("BOTTOMRIGHT")
    Surface(pane, "Surface", T.previewPane)
    pane:Hide()
    window.previewPane = pane
    local moduleHeader = W.ModuleHeader(column)
    window.moduleHeader = moduleHeader
    local pageHost = CreateFrame("Frame", nil, column)
    window.pageHost = pageHost
    self:BuildConfigNavigation(window)
    self:CreateSettingsSearch()
    self:CreateConfigBackCatcher(window)

    window:RegisterEvent("UI_SCALE_CHANGED")
    window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    -- The window closes itself when combat starts.
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then if window:IsShown() then window:Hide() end; return end
        self:FinishWindowInteraction(); self:UpdateWindowBounds()
        if self.EditMode then self.EditMode:ViewportChanged() end
    end)
    window:SetScript("OnShow", function()
        if self.ReloadManager.prompt then self.ReloadManager.prompt:Hide() end
        -- Borders follow the window's scale, which is set here.
        self:UpdateWindowBounds(); self:SelectConfigPage(window.selectedPage or "home", true)
        if window.backCatcher then window.backCatcher:Show() end
        -- Fills in labels left blank by a font still loading on a fresh launch.
        addon.Media:ScheduleTextRedraw()
        W.SnapSettings()
    end)
    window:SetScript("OnHide", function()
        if window.backCatcher then window.backCatcher.closing = true; window.backCatcher:Hide(); window.backCatcher.closing = nil end
        if self.FrameAnchors then self.FrameAnchors:Stop() end
        if self.PreviewStates then self.PreviewStates:StopAll() end
        self:FinishWindowInteraction()
        if self.CloseTimerColorPicker then self:CloseTimerColorPicker() end
        if self.CloseFontDropdown then self:CloseFontDropdown() end
        if self.CloseSettingsSearch then self:CloseSettingsSearch() end
        if window.editSuspended then return end
        self:ResetDisplayModes()
        self:NotifyConfigClosed()
    end)
    self:UpdateWindowBounds(true)
end

-- Esc goes back one level: module, then the main panel, then closed. A hidden
-- frame in UISpecialFrames takes the game's own Esc (safe in combat, no
-- keyboard capture): when Esc hides it inside a module, it returns to the main
-- panel and shows itself again.
function addon:CreateConfigBackCatcher(window)
    local catcher = CreateFrame("Frame", "ModeUIConfigBack", UIParent)
    catcher:SetSize(1, 1); catcher:Hide()
    catcher:SetScript("OnHide", function(owner)
        if owner.closing or not window:IsShown() then return end
        if window.selectedPage ~= "home" then self:ShowConfigHome(); owner:Show()
        else window:Hide() end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ModeUIConfigBack") end
    window.backCatcher = catcher
end

function addon:ShowConfigHome() self:SelectConfigPage("home") end
-- The wordmark: back to the main panel, or closed from there.
function addon:ConfigBack()
    local window = self.configWindow
    if not window then return end
    if window.selectedPage ~= "home" then self:ShowConfigHome() else window:Hide() end
end

-- Reset (footer): the selected module's own reset to defaults, after asking.
function addon:ResetSelectedModule()
    local module = self.configWindow and self.modules[self.configWindow.selectedPage]
    if not module or not module.ResetToDefaults then return false end
    W.Confirm("Reset " .. module.title, "Put every " .. module.title .. " setting back to its default?", "Reset", function()
        module:ResetToDefaults()
        self:RefreshConfig()
    end)
    return true
end

function addon:NotifyConfigClosed()
    for _, module in pairs(self.modules) do
        if module.OnConfigClosed then module:OnConfigClosed() end
    end
    self.ReloadManager:OnWindowClosed()
end

function addon:ToggleConfig()
    if self.editMode then self:SetEditMode(false); return end
    if not self.configWindow then self:CreateConfig() end
    self.configWindow:SetShown(not self.configWindow:IsShown())
end

-- Shows the settings window (leaving Edit Mode first) without ever closing it:
-- the game menu button and the minimap's addon compartment use this.
function addon:OpenConfig()
    if not self.initialized then return false end
    if self.editMode then self:SetEditMode(false) end
    if not self.configWindow then self:CreateConfig() end
    self.configWindow:Show()
    return true
end
