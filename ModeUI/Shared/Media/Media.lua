local _, addon = ...

-- Shared media service. Game UI font changes are an explicit Global Settings feature.
local M = {
    gameFont = GameFontHighlight:GetFont(), chatFont = ChatFontNormal:GetFont(),
    regions = setmetatable({}, { __mode = "k" }),
    -- Regions redrawn once their font had time to load (RedrawInterfaceText).
    settled = setmetatable({}, { __mode = "k" }),
    fontListeners = setmetatable({}, { __mode = "k" }),
    borderListeners = setmetatable({}, { __mode = "k" }),
    borderRevision = 0,
    statusbarListeners = setmetatable({}, { __mode = "k" }), statusbarRevision = 0,
    textureFailures = {},
    soundListeners = setmetatable({}, { __mode = "k" }),
}
addon.Media = M
function M:MediaLabel(name)
    local label=(name or ""):gsub("%s*%b()",""):gsub("%s+$","")
    return label~="" and label or (name or ""):gsub("[()]","")
end
M.defaultStatusBar = "Interface\\Buttons\\WHITE8X8"
function M:RegisterStatusBarListener(owner,callback) self.statusbarListeners[owner]=callback end
function M:UnregisterStatusBarListener(owner) self.statusbarListeners[owner]=nil end
function M:GetStatusBar(style, scope)
    if style==nil or style=="default" then return self:GetSurfaceTexture(scope) end
    if style=="flat" then return self.defaultStatusBar end
    if type(style)~="string" or style:sub(1,6)~="media:" or not self.library then return end
    -- A Mode texture saved before November 20, 2026 draws as the one it became.
    style=addon.Style.OLD_MEDIA[style] or style
    local name=style:sub(7)
    local entries=self.library:HashTable("statusbar")
    if not entries or not entries[name] then return end
    local path=self.library:GetGlobal("statusbar") and entries[name] or self.library:Fetch("statusbar",name,true)
    if type(path)=="string" and path~="" then return path end
end
function M:GetStatusBars()
    local choices={{key="default",label="Default"}}; local seen={}
    if self.library then
        for _,name in ipairs(self.library:List("statusbar") or {}) do
            if type(name)=="string" and not seen[name] and self:GetStatusBar("media:"..name) then
                seen[name]=true; choices[#choices+1]={key="media:"..name,label=self:MediaLabel(name)}
            end
        end
    end
    return choices
end
function M:RefreshStatusBars()
    if addon.InCombat() then self.statusbarPending=true; self:RefreshAfterCombat(); return end
    self.statusbarPending=false; self.statusbarRevision=self.statusbarRevision+1
    for owner,callback in pairs(self.statusbarListeners) do callback(owner) end
end

-- Listeners receive their owner after out-of-combat font refreshes.
function M:RegisterFontListener(owner, callback)
    assert(type(owner) == "table" and type(callback) == "function", "ModeUI: media listener requires owner and callback.")
    self.fontListeners[owner] = callback
end

function M:UnregisterFontListener(owner)
    self.fontListeners[owner] = nil
end

function M:RegisterBorderListener(owner, callback)
    assert(type(owner) == "table" and type(callback) == "function", "ModeUI: border listener requires owner and callback.")
    self.borderListeners[owner] = callback
end

function M:UnregisterBorderListener(owner) self.borderListeners[owner] = nil end

-- LSM supplies paths, not per-border edge dimensions. Native backdrop strips
-- use a conservative tiled edge, capped by the consuming icon's size.
function M:GetBorder(style)
    if style == "none" then return { kind = "none" } end
    if style == "thin" then return { kind = "thin", edgeSize = 1 } end
    if type(style) ~= "string" or style:sub(1, 6) ~= "media:" or not self.library then return end
    local name = style:sub(7)
    local entries = self.library:HashTable("border")
    if not entries or not entries[name] then return end
    local path = self.library:GetGlobal("border") and entries[name] or self.library:Fetch("border", name, true)
    if type(path) == "string" and path ~= "" then return { kind = "shared", path = path, edgeSize = 8 } end
end

function M:GetBorders()
    local choices = { { key = "none", label = "None" }, { key = "thin", label = "ModeUI Thin" } }
    local seen = {}
    if self.library then
        for _, name in ipairs(self.library:List("border") or {}) do
            if type(name) == "string" and not seen[name] and self:GetBorder("media:" .. name) then
                seen[name] = true
                choices[#choices + 1] = { key = "media:" .. name, label = self:MediaLabel(name) }
            end
        end
    end
    return choices
end

function M:RefreshBorders()
    if addon.InCombat() then self.borderPending = true; self:RefreshAfterCombat(); return end
    self.borderPending = false
    self.borderRevision = self.borderRevision + 1
    for owner, callback in pairs(self.borderListeners) do callback(owner) end
end

-- ModeUI's interface font is the Mode typeface by default
-- (docs/DESIGN_LANGUAGE.md, "Text"); headings use its SemiBold.
function M:GetInterfaceFont(fallbackPath, scope, weight)
    local theme = addon.InterfaceTheme
    -- The settings window keeps the Mode typeface whatever font the suite
    -- (Global > Appearance) gives module text.
    if theme and theme.id == "mode" then
        return addon.Style.FontPath(weight == "heading" and "semibold" or weight or "regular")
    end
    local inherited=self:ResolveFont(self:GlobalStyle("font",scope))
    if inherited then return inherited end
    -- The Blizzard theme keeps the stock game fonts its artwork is drawn for.
    if theme and theme.blizzardArt then return fallbackPath or GameFontHighlight:GetFont() end
    return self:GetFont("Expressway") or fallbackPath or GameFontHighlight:GetFont()
end

local InCombat = addon.InCombat

-- Media changes during combat wait for one refresh after combat: RefreshFonts
-- also catches up the border, status bar and sound listeners that were skipped.
function M:RefreshAfterCombat()
    self.pending = true
    addon.Defer:Queue("media", function() M:RefreshFonts() end)
end

function M:AttachLibrary()
    local library = LibStub and LibStub("LibSharedMedia-3.0", true)
    if library then
        for _, method in ipairs({ "List", "Fetch", "HashTable", "GetGlobal" }) do
            if type(library[method]) ~= "function" then return false end
        end
    end
    if not library or library == self.library then return false end
    if self.library and self.library.UnregisterCallback then
        self.library.UnregisterCallback(self, "LibSharedMedia_Registered")
        self.library.UnregisterCallback(self, "LibSharedMedia_SetGlobal")
    end
    self.library = library
    self:RegisterProviderFonts()
    if library.RegisterCallback then
        library.RegisterCallback(self, "LibSharedMedia_Registered", "OnMediaRegistered")
        library.RegisterCallback(self, "LibSharedMedia_SetGlobal", "OnMediaRegistered")
    end
    return true
end

function M:GetFont(name)
    if name=="builtin:game" then return self.gameFont end
    if name=="builtin:chat" then return self.chatFont end
    if type(name) ~= "string" or name == "" or not self.library then return end
    -- Fetch may honor an LSM global override; prefer the exact registered entry.
    local media = self.library:HashTable("font")
    if not media or not media[name] then return end
    local path = self.library:GetGlobal("font") and media[name] or self.library:Fetch("font", name, true)
    if type(path) == "string" and path ~= "" then return path end
end

function M:GetFonts()
    local choices = {
        { key = "game", label = "Game font", path = self.gameFont },
        { key = "chat", label = "Chat font", path = self.chatFont },
    }
    local seen = {}
    if self.library then
        for _, name in ipairs(self.library:List("font") or {}) do
            local path = self:GetFont(name)
            if path and not seen[name] then
                seen[name] = true
                choices[#choices + 1] = { key = "media:" .. name, label = self:MediaLabel(name), path = path, media = name }
            end
        end
    end
    return choices
end

function M:GetGlobalFont()
    local name=self.library and self.library:GetGlobal("font")
    if type(name)=="string" then return self:GetFont(name) end
end
function M:GetDisplayFont(appearance, respectGlobal, scope)
    if (appearance.fontMedia or "")=="" and appearance.font~="chat" then
        local inherited=self:ResolveFont(self:GlobalStyle("font", scope or appearance))
        if inherited then return inherited end
    end
    return (respectGlobal and self:GetGlobalFont()) or self:GetFont(appearance.fontMedia or "")
        or (appearance.font == "chat" and self.chatFont or self.gameFont)
end

function M:ApplyInterfaceFont(region, spec)
    local preferred = spec.fixed and spec.path or self:GetInterfaceFont(spec.path,spec.scope,spec.weight)
    if not region:SetFont(preferred, spec.size, spec.flags) then
        region:SetFont(spec.fallback or spec.path, spec.size, spec.flags)
    end
end

-- A font that doesn't follow the interface font (the Mode Script wordmark),
-- redrawn with the rest; `fallback` if the client refuses the file.
function M:BindFixedFont(region, path, size, fallback)
    local spec = { path = path, size = size, flags = "", fixed = true, fallback = fallback }
    self.regions[region], self.settled[region] = spec, nil
    self:ApplyInterfaceFont(region, spec)
end

function M:BindInterfaceFont(region, fontObject, fontSize, scope, weight)
    local path, size, flags = fontObject:GetFont()
    local spec = { path = path, size = fontSize or size, flags = flags or "", scope = scope or self:FrameScope(region), weight = weight }
    self.regions[region], self.settled[region] = spec, nil
    self:ApplyInterfaceFont(region, spec)
end
function M:UnbindInterfaceFont(region) self.regions[region] = nil end

-- A shared-media font file can still be loading the first time it is used in
-- a game session; text set during that window stays blank until it is set
-- again. Re-apply the font and re-set the text of every bound FontString.
-- EditBoxes are skipped: re-setting their text would fire their handlers.
-- settle: the late pass. Its regions are done (their font has loaded) and
-- later redraws skip them, until they bind again or the fonts change: a
-- redraw of every label in the game each time a window opened was a
-- noticeable hitch (November 27, 2026).
function M:RedrawInterfaceText(settle)
    if InCombat() then return false end
    for region, spec in pairs(self.regions) do
        if not self.settled[region] and region.GetObjectType and region:GetObjectType() == "FontString" then
            self:ApplyInterfaceFont(region, spec)
            local text = region:GetText()
            if type(text) == "string" and text ~= "" then region:SetText(""); region:SetText(text) end
            if settle then self.settled[region] = true end
        end
    end
    return true
end

-- Redraws shortly after a surface opens, and once more a second later, so a
-- font that finishes loading after the first pass is still picked up.
function M:ScheduleTextRedraw()
    if not (C_Timer and C_Timer.After) then return end
    self.redrawEpoch = (self.redrawEpoch or 0) + 1
    local epoch = self.redrawEpoch
    for _, delay in ipairs({ 0.2, 1 }) do
        C_Timer.After(delay, function()
            if self.redrawEpoch == epoch then self:RedrawInterfaceText(delay == 1) end
        end)
    end
end

function M:RefreshFonts()
    self:AttachLibrary()
    if InCombat() then self:RefreshAfterCombat(); return end
    self.pending = false
    -- A font file new to this session may load late: every label redraws again.
    self.settled = setmetatable({}, { __mode = "k" })
    for region, spec in pairs(self.regions) do self:ApplyInterfaceFont(region, spec) end
    for owner, callback in pairs(self.fontListeners) do callback(owner) end
    if self.borderPending then self:RefreshBorders() end
    if self.statusbarPending then self:RefreshStatusBars() end
    if self.soundPending then self:RefreshSounds() end
end

function M:OnMediaRegistered(_, mediaType, name)
    self:RememberMedia(mediaType,name)
    if mediaType == "font" then self:RefreshFonts() end
    if mediaType == "border" then self:RefreshBorders() end
    if mediaType == "statusbar" then self:RefreshStatusBars() end
    if mediaType == "sound" then self:RefreshSounds() end
end

function M:Initialize()
    if self.started then return end
    self.started = true
    -- Another addon may bring fonts, textures or a LibSharedMedia copy with it.
    addon.Events:On(self, "ADDON_LOADED", function()
        if self:AttachLibrary() then self:RefreshFonts(); self:RefreshBorders(); self:RefreshStatusBars(); self:RefreshSounds() end
        self:RegisterProviderFonts()
        self:DiscoverMedia()
        if addon.Positioning then addon.Positioning:Discover() end
    end)
    self:RefreshFonts()
    self:RefreshBorders()
    self:RefreshStatusBars()
end

function M:GetSound(style)
    if style=="default" then return SOUNDKIT and SOUNDKIT.RAID_WARNING end
    if type(style)~="string" or style:sub(1,6)~="media:" or not self.library then return end
    local entries=self.library:HashTable("sound")
    if (issecretvalue and issecretvalue(entries)) or type(entries)~="table" or (issecrettable and issecrettable(entries))
        or (canaccesstable and not canaccesstable(entries)) then return end
    local value=entries and entries[style:sub(7)]
    if issecretvalue and issecretvalue(value) then return end
    if (type(value)=="string" and value~="") or (type(value)=="number" and value>0 and value<math.huge and value==math.floor(value)) then return value end
end
function M:GetSounds()
    local choices={{key="default",label="Blizzard Warning"}}
    if self.library then for _,name in ipairs(self.library:List("sound") or {}) do
        if type(name)=="string" and self:GetSound("media:"..name) then choices[#choices+1]={key="media:"..name,label=name} end
    end end
    return choices
end
function M:RegisterSoundListener(owner,callback) self.soundListeners[owner]=callback end
function M:RefreshSounds()
    if InCombat() then self.soundPending=true;self:RefreshAfterCombat();return end
    self.soundPending=false
    for owner,callback in pairs(self.soundListeners) do callback(owner) end
end



-- Reference only verified installed assets; never copy a provider's font file.
-- Respect an existing LSM registration, including one supplied by a media pack.
-- Expressway (and Expressway Bold) are the Mode typeface when present
-- (Style.PROVIDER_FONTS); once they're known, "Mode" is registered.
function M:RegisterProviderFonts()
    local library=self.library
    if not library or type(library.Register)~="function" then return end
    if C_UIFileAsset and C_UIFileAsset.IsKnownFile then
        local fonts=library:HashTable("font")
        for _,font in ipairs(addon.Style.PROVIDER_FONTS) do
            if not (fonts and fonts[font.name]) then
                for _,path in ipairs(font.paths) do
                    local ok,known=pcall(C_UIFileAsset.IsKnownFile,path)
                    if ok and not (issecretvalue and issecretvalue(known)) and known==true then
                        library:Register("font",font.name,path)
                        break
                    end
                end
            end
        end
    end
    addon.Style.RegisterTypeface(library)
end

