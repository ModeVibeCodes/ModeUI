local _, addon = ...
local M = addon.Chat
if not M then return end

-- Lifecycle, settings and finding the chat windows. The look is painted in
-- Window.lua (window, edit box, scroll button), Tabs.lua and Buttons.lua (the
-- compartment); Fade.lua runs the tab fade and the idle fade. Chat frames are
-- not protected, so everything here works in combat too. ModeUI only calls
-- widget methods on Blizzard's frames and post-hooks Blizzard's functions; it
-- never writes Blizzard's globals or fields, and never reads message text.
local Events, L, Kit = addon.Events, addon.L, addon.Kit
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Blizzard's chat windows: ChatFrame1 to the game's maximum, and temporary
-- whisper windows (ChatFrame11 and up), all listed in CHAT_FRAMES by name.
function M:ChatFrames()
    local list, seen = {}, {}
    local function Add(name)
        local frame = type(name) == "string" and _G[name]
        if frame and not seen[frame] and frame.GetObjectType then seen[frame] = true; list[#list + 1] = frame end
    end
    local constants = Constants and Constants.ChatFrameConstants
    local count = constants and addon.IsNumber(constants.MaxChatWindows, 1, 50) and constants.MaxChatWindows or 10
    for index = 1, count do Add("ChatFrame" .. index) end
    if type(CHAT_FRAMES) == "table" then for _, name in ipairs(CHAT_FRAMES) do Add(name) end end
    return list
end
function M:TabOf(frame) return frame and frame.GetName and _G[(frame:GetName() or "") .. "Tab"] end

function M:OnInitialize()
    self.Initialize(self.db)
    -- SharedMedia fonts can register after login; Expressway may be one.
    addon.Media:RegisterFontListener(self, function() if self.active then self:Refresh() end end)
end

function M:OnEnable()
    self.active = true
    addon.ReloadManager:Clear("chat")
    self:InstallHooks()
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS",
        "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        Events:On(self, event, function() self:Refresh() end)
    end
    -- A whisper counts as using the chat when Wake on Whispers is on.
    for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do
        Events:On(self, event, function() if self.db.wakeOnWhisper then self:Wake() end end)
    end
    Events:On(self, "VOICE_CHAT_CHANNEL_ACTIVATED", function() self:PaintCompartment() end)
    Events:On(self, "VOICE_CHAT_CHANNEL_DEACTIVATED", function() self:PaintCompartment() end)
    self:Refresh()
end

-- Blizzard's art comes back with a reload; until then fades stop and every
-- alpha goes back to Blizzard.
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    if self.skinned then
        addon.ReloadManager:Request("chat", L["Chat: reload to give the chat windows back their Blizzard look."])
    end
    self:StopFade()
end

-- Post-hooks, installed once; each does nothing while the module is off.
function M:InstallHooks()
    if self.hooksInstalled or not hooksecurefunc then return end
    self.hooksInstalled = true
    local function Active() return self.active == true end
    -- Temporary whisper windows are made on demand.
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() if Active() then self:Refresh() end end)
    end
    -- Blizzard re-anchors a window's background when the combat log's quick
    -- buttons appear; ModeUI's layout hangs from it, so it's placed again.
    if FloatingChatFrame_UpdateBackgroundAnchors then
        hooksecurefunc("FloatingChatFrame_UpdateBackgroundAnchors", function(frame)
            if Active() and frame then self:LayoutWindow(frame) end
        end)
    end
    if FCFTab_UpdateColors then
        hooksecurefunc("FCFTab_UpdateColors", function(tab, selected) if Active() then self:PaintTabState(tab, selected) end end)
    end
    -- Selecting, docking and undocking windows changes which tab is selected.
    for _, name in ipairs({ "FCFDock_SelectWindow", "FCFDock_UpdateTabs", "FCF_DockFrame", "FCF_UnDockFrame", "FCF_Close" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function() if Active() then self:ApplyAlpha(true) end end)
        end
    end
    if FCF_SetChatWindowFontSize then
        hooksecurefunc("FCF_SetChatWindowFontSize", function() if Active() then self:Refresh() end end)
    end
    -- Blizzard sizes a tab to its text (measured in whatever font the text
    -- had); a skinned chat tab is sized again in the Mode face right after.
    -- Fixed sizes (dynamic dock tabs) and whisper tabs are left alone.
    if PanelTemplates_TabResize then
        hooksecurefunc("PanelTemplates_TabResize", function(tab, padding, absoluteSize, minWidth, maxWidth)
            if Active() and tab and absoluteSize == nil and addon.Skin.parts[tab] and addon.Skin.parts[tab].glass then
                self:SizeTab(tab, nil, padding, minWidth, maxWidth)
            end
        end)
    end
    -- Blizzard re-anchors the scroll bar when a window locks or resizes.
    if FCF_UpdateScrollbarAnchors then
        hooksecurefunc("FCF_UpdateScrollbarAnchors", function(frame) if Active() and frame then self:PlaceScrollBar(frame) end end)
    end
end

-- Paints every chat window, its tab and edit box, and the compartment.
function M:Refresh()
    if not self.active then return end
    self.skinned = true
    for _, frame in ipairs(self:ChatFrames()) do
        self:SkinWindow(frame)
        local tab = self:TabOf(frame)
        if tab then self:SkinTab(tab, frame) end
    end
    self:PaintCompartment()
    self:StartFade()
    self:ApplyAlpha(true)
    if self.page then self.page:Refresh() end
end

-- The font file for chat text, from the Font setting (Expressway by default).
function M:FontPath() return Kit.FontPath(self.db, self.id) end

-- Values are checked by Initialize on a copy before they're kept.
function M:SetOption(key, value)
    if self.defaults[key] == nil or key == "version" then return false end
    local candidate = Copy(self.db)
    candidate[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    self.db[key] = candidate[key]
    self:Refresh()
    -- Rows shown only with another setting (Border Color with Border) follow.
    if self.page then self.page:Layout() end
    return true
end

function M:ResetToDefaults()
    for key, value in pairs(self.defaults) do self.db[key] = Copy(value) end
    self:Refresh()
    if self.page then self.page:Refresh() end
    return true
end

-- Owner for the shared font and color widgets.
function M:AppearanceOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db[key] end }) } }
    function owner.CanConfigure() return true end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(key, value) end
    return owner
end

-- The settings page's status line.
function M:Status()
    if not self.active then return L["Off. Turn the module on to skin the chat windows."] end
    if self.db.idleFade then
        return string.format(L["On. Chat fades to %d%% after %d seconds without use."], self.db.idleOpacity, self.db.idleDelay)
    end
    return L["On. The idle fade is off."]
end
