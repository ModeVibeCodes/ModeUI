-- Settings fit audit: every module page and tab, laid out at the settings
-- window's real widths (docs/DESIGN_LANGUAGE.md, "Settings window"), with no
-- control or text reaching past its tile, row or cell; not WoW.
local H = dofile((debug.getinfo(1, "S").source:sub(2)):gsub("[^/\\]+$", "") .. "harness.lua")

local STUBS = H.Read(H.root .. "tests/unit_frame_stubs.lua")
-- The audit itself, run inside each world: Check(where, frame, room, depth,
-- row, top) adds to `problems`.
local CHECK = [[
    local problems = {}
    local function Num(value) return type(value) == "number" and value or 0 end
    -- Left edge of a region inside `host`, following LEFT-to-RIGHT chains of siblings.
    local function LeftOf(region, host, depth)
        local point, relative, relativePoint, x = region:GetPoint(1)
        if type(point) ~= "string" or not point:find("LEFT") then return nil end
        if relative == nil or relative == host then
            if type(relativePoint) == "string" and relativePoint:find("RIGHT") then return nil end
            return Num(x)
        end
        if depth < 6 and type(relative) == "table" and relative.GetPoint and type(relativePoint) == "string" and relativePoint:find("RIGHT") then
            local left = LeftOf(relative, host, depth + 1)
            if left then return left + Num(relative:GetWidth()) + Num(x) end
        end
    end
    -- Room a child filling its parent between a left and a right anchor gets.
    local function Filled(child, available)
        if child:GetNumPoints() ~= 2 then return nil end
        local p1, r1, _, x1 = child:GetPoint(1)
        local p2, r2, _, x2 = child:GetPoint(2)
        local parent = child:GetParent()
        if (r1 ~= nil and r1 ~= parent) or (r2 ~= nil and r2 ~= parent) then return nil end
        if not (p1:find("LEFT") and p2:find("RIGHT")) then return nil end
        return available - Num(x1) + Num(x2)
    end
    local function Name(region)
        local text = region.label and region.label.GetText and region.label:GetText() or region.GetText and region:GetText()
        return (region:GetObjectType() or "?") .. (text and text ~= "" and (" '" .. tostring(text):sub(1, 24) .. "'") or "")
    end
    -- hostTop: the frame's top inside `row` while it fills its parent (nil once
    -- unknown); wrapped text anchored from its top must end inside the row.
    local function Check(where, frame, available, depth, row, hostTop)
        if depth > 5 or not frame.GetChildren then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:IsShown() then
                if child:GetNumPoints() == 1 then
                    local left = LeftOf(child, frame, 0)
                    if left and left + Num(child:GetWidth()) > available + 0.5 then
                        problems[#problems + 1] = string.format("%s: %s reaches %.0f of %.0f", where, Name(child), left + Num(child:GetWidth()), available)
                    end
                    if child.width and not child.switchFrame then Check(where, child, child.width, depth + 1, row) end
                else
                    local room = Filled(child, available)
                    local _, _, _, _, y = child:GetPoint(1)
                    if room then Check(where, child, room, depth + 1, row, hostTop and hostTop - Num(y)) end
                end
            end
        end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:GetObjectType() == "FontString" and region:IsShown() and region:GetNumPoints() == 1 and (region:GetText() or "") ~= "" then
                local left = LeftOf(region, frame, 0)
                local used = math.min(Num(region:GetWidth()), Num(region:GetStringWidth()))
                if left and left + used > available + 0.5 then
                    problems[#problems + 1] = string.format("%s: text %s reaches %.0f of %.0f", where, Name(region), left + used, available)
                end
                local point, _, _, _, y = region:GetPoint(1)
                if hostTop and point:find("^TOP") then
                    local bottom = hostTop - Num(y) + Num(region:GetStringHeight())
                    if bottom > Num(row:GetHeight()) + 0.5 then
                        problems[#problems + 1] = string.format("%s: text %s ends at %.0f of %.0f tall", where, Name(region), bottom, Num(row:GetHeight()))
                    end
                end
            end
        end
    end
]]
-- Every page in both themes: Mode-Blizz, and Mode-Obsidian (a fresh account,
-- docs/DESIGN_LANGUAGE.md "Mode-Obsidian theme"), whose fonts and pickers differ.
for _, obsidian in ipairs({ false, true }) do
local world = H.Load({ before = STUBS, obsidian = obsidian })
local problems = world.run(CHECK .. [[
    SlashCmdList.MODEUI()
    local window, S = addon.configWindow, addon.ConfigWidgets.SETTINGS_SIZES
    -- Pages that edit one of several things show each one's cards.
    local editors = { unitFrames = { set = "SetEditing", list = addon.UnitFrames and addon.UnitFrames.units } }
    local function Audit(id)
        addon:SelectConfigPage(id)
        local page = window.pages[id]
        local layout = window.layout
        -- The scroll view's width in game for this shape.
        local column = math.max(S.column, (page.minimumWidth or 0) + 44)
        page.scroll.width = layout == "split" and column - S.pad - 2 - 24
            or (S.width - (layout == "page" and S.sidebar or S.rail) - S.pad - 4 - 24)
        local editor = editors[id]
        for _, thing in ipairs(editor and editor.list or { false }) do
            if thing then page[editor.set](thing) end
            local sections = page.sectionTabs and page.sections or { false }
            for _, section in ipairs(sections) do
                if section then page:SelectSectionTab(section) end
                page:Layout()
                for _, row in ipairs(page.rows) do
                    if row:IsShown() and row.width then
                        local where = id .. (thing and (" (" .. thing .. ")") or "") .. (section and (" / " .. section.title) or "")
                            .. " / " .. tostring(row.settingsTitle or row.settingsGroupTitle or "?")
                        Check(where, row, row.width, 0, row, 0)
                    end
                end
            end
        end
    end
    for id in pairs(window.sidebarModuleButtons) do if id ~= "home" then Audit(id) end end
    Audit("home")
    -- Text a refresher sets after a layout (the page opens, then refreshes):
    -- its row takes the new height without another Layout call.
    addon:SelectConfigPage("unitFrames")
    local frames = window.pages.unitFrames
    frames.SetEditing("target"); frames:SelectSectionTab(1); frames:Layout()
    local note = frames.unitFrameResourceNote
    local noteRow = note:GetParent().row
    local fitted = noteRow:GetHeight()
    assert(noteRow:IsShown() and noteRow.gridStacked and note:GetText() ~= "", "the Target's Class Resource note shows, its label above it")
    note:SetText(string.rep(note:GetText() .. " ", 4)); frames:Layout()
    assert(noteRow:GetHeight() > fitted, "a longer note's row is taller")
    frames:Refresh()
    assert(noteRow:GetHeight() == fitted, "the refreshed note's row takes its height without a Layout call")
    -- Edit Mode's panel (EditPage.lua): every Interface and Panels page at the
    -- panel's width, one card per row, without its preview.
    local host = CreateFrame("Frame", nil, UIParent); host:SetSize(424, 470)
    for _, category in ipairs({ "frames", "interface" }) do
        for _, id in ipairs(addon.categories[category].modules) do
            local module = addon.modules[id]
            if module.CreateConfigPage and not module.standalone then
                local page = addon.EditPage:Borrow(module, host)
                page.scroll.width = 424 - 24
                local sections = page.sectionTabs and page.sections or { false }
                for _, section in ipairs(sections) do
                    if section then page:SelectSectionTab(section) end
                    page:Layout()
                    for _, row in ipairs(page.rows) do
                        if row:IsShown() and row.width then
                            Check("panel " .. id .. (section and (" / " .. section.title) or "") .. " / "
                                .. tostring(row.settingsTitle or row.settingsGroupTitle or "?"), row, row.width, 0, row, 0)
                        end
                    end
                end
                addon.EditPage:Return()
            end
        end
    end
    table.sort(problems)
    return problems
]], "settings_fit")

if #problems > 0 then
    error("settings fit (" .. (obsidian and "Mode-Obsidian" or "Mode-Blizz") .. "): " .. #problems
        .. " control(s) past their tile\n  " .. table.concat(problems, "\n  "), 0)
end
end

-- ModeCDM's window: each page at its body's width (Window.lua: 1060 wide, the
-- 220 list and margins beside it), every bar, resource and the Cast Bar.
local CDM = STUBS .. H.Read(H.root .. "tests/cooldown_manager_stubs.lua")
local cdm = H.Load({ before = CDM .. "\nMakeViewers()" })
local cdmProblems = cdm.run(CHECK .. [[
    local M = addon.CooldownManager
    addon:SetModuleEnabled("cooldownManager", true)
    SlashCmdList.MODEUICDM()
    local pages = { "home", "style", "cast", "swing" }
    for _, id in ipairs(M:BarIds()) do pages[#pages + 1] = id end
    for id in pairs(M.resourceSpecs) do pages[#pages + 1] = "resource:" .. id end
    local checked = 0
    for _, value in ipairs(pages) do
        if M:SelectEditing(value) then
            local page = M[({ home = "homePage", style = "stylePage", cast = "castPage", swing = "swingPage" })[value]
                or (value:find("^resource:") and "resourcePage") or "page"]
            page.scroll.width = 1060 - 220 - 24 - 28 - 24
            page:Layout()
            for _, row in ipairs(page.rows) do
                if row:IsShown() and row.width then
                    checked = checked + 1
                    Check("cdm " .. value .. " / " .. tostring(row.settingsTitle or row.settingsGroupTitle or "?"), row, row.width, 0, row, 0)
                end
            end
        end
    end
    assert(checked > 100, "ModeCDM's pages were laid out (" .. checked .. " rows)")
    table.sort(problems)
    return problems
]], "settings_fit_cdm")
if #cdmProblems > 0 then
    error("settings fit (ModeCDM): " .. #cdmProblems .. " control(s) past their tile\n  " .. table.concat(cdmProblems, "\n  "), 0)
end
print("settings fit: every page and tab fits its tiles")
