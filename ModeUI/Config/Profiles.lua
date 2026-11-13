local _, addon = ...
local M, P, W, T = addon.ProfilesModule, addon.Profiles, addon.ConfigWidgets, addon.InterfaceTheme
if not M then return end

-- Two tabs: Profiles (switch, create, duplicate, rename, delete) and
-- Import / Export. Every action reports its result in the Status line.
function M:CreateConfigPage(parent)
    local page = W.Page(parent, 480); self.page = page
    local selected = P:Active()
    local function Selected()
        if not P:Exists(selected) then selected = P:Active() end
        return selected
    end
    local function Choices()
        local items = {}
        for _, name in ipairs(P:List()) do
            local tags = {}
            if name == P:Active() then tags[#tags + 1] = "active" end
            if name == P:Pending() then tags[#tags + 1] = "after reload" end
            items[#items + 1] = { id = name, label = #tags > 0 and (name .. "  (" .. table.concat(tags, ", ") .. ")") or name }
        end
        return items
    end
    local function Label(row, color)
        local label = W.Label(row, "", nil, 0, -4, 420, color or T.text); label:SetWordWrap(true)
        return label
    end
    local function Refresh(fn) page.refreshers[#page.refreshers + 1] = fn end
    local function Action(row, text, width, callback, style, anchor)
        local button = W.Button(row, text, width, 28, style)
        if anchor then button:SetPoint("LEFT", anchor, "RIGHT", 8, 0) else button:SetPoint("LEFT") end
        button:SetScript("OnClick", function() callback(); page:Refresh(); page:Layout() end)
        return button
    end
    local function InputAction(title, placeholder, text, callback)
        local row = page:Row(title, 48)
        local input = W.TextInput(row, 220, placeholder)
        local function Run()
            local ok = callback(input:GetText())
            if ok then input:SetText("") end
        end
        input.onEnter = function() Run(); page:Refresh() end
        local button = Action(row, text, 110, Run, nil, input)
        return input, button
    end

    page:Section("Profiles", nil, false)
    local active = Label(page:Row("Active Profile", 48), T.primary)
    Refresh(function()
        local pending = P:Pending()
        active:SetText(P:Active() .. (pending and ("   ->   " .. pending .. " after reload") or ""))
    end)
    local choose = W.Select(page:Row("Profile", 48), 260, Choices,
        function() return Selected(), Selected() end, function(name) selected = name; page:Refresh() end)
    Refresh(function() choose:Refresh() end)
    local actions = page:Row("", 48)
    local switch = Action(actions, "Switch to This Profile", 180, function() P:Select(Selected()) end, "primary")
    local cancel = Action(actions, "Keep Current", 120, function() P:CancelSelection() end, "secondary", switch)
    local delete = Action(actions, "Delete", 90, function()
        if P:Delete(Selected()) then selected = P:Active() end
    end, "secondary", cancel)
    Refresh(function()
        local name = Selected()
        switch:SetEnabled(name ~= P:Active() and name ~= P:Pending())
        cancel:SetEnabled(P:Pending() ~= nil)
        delete:SetEnabled(name ~= P:Active())
    end)
    page:Group("Manage")
    local renameInput, rename = InputAction("Rename", "New name", "Rename", function(text)
        local old = Selected()
        local ok = P:Rename(old, text)
        if ok then selected = P:Name(text) end
        return ok
    end)
    local duplicateInput, duplicate = InputAction("Duplicate", "Name for the copy", "Duplicate", function(text)
        local ok = P:Create(text, Selected())
        if ok then selected = P:Name(text) end
        return ok
    end)
    local createInput, create = InputAction("New Profile", "Profile name", "Create", function(text)
        local ok = P:Create(text)
        if ok then selected = P:Name(text) end
        return ok
    end)
    local status = Label(page:Row("Status", 56), T.muted)
    local note = W.Label(page:Row("About Profiles", 96), "A profile holds all of ModeUI's settings: which modules are on, Unit Frames and their Edit Mode positions, Optimizations and Class Colors. Changes save to the active profile as you make them. Switching applies after a reload, so the frames start cleanly from the new settings; use Reload in the header, or reload when you close the window. Play The Game Tools keeps its own, separate profiles.", nil, 0, -4, 420, T.muted)
    note:SetWordWrap(true); page:FooterNote(note)

    page:Section("Import / Export", nil, false)
    local exportRow = page:Row("Export", 48)
    local export = Action(exportRow, "Export Selected Profile", 190, function()
        local text, reason = P:Export(Selected())
        page.profileEditorMode = "export"
        page.setEditorText(text or "")
        page.transferStatus:SetText(text and ("Profile string for " .. Selected() .. ". Press Ctrl+A, then Ctrl+C to copy it.") or reason)
        if text then page.profileEditor:SetFocus(); page.profileEditor:HighlightText() end
    end)
    local importName, import = InputAction("Import As", "Name (optional)", "Import", function(text)
        local ok, message, name = P:Import(page.profileEditor:GetText(), text)
        page.transferStatus:SetText(message or "")
        if ok then selected = name; page.setEditorText("") end
        return ok
    end)
    -- Multi-line profile string editor.
    local editorRow = page:Row("Profile String", 220)
    local editorHost = editorRow; editorHost.rowLabel:Hide()
    editorHost:ClearAllPoints(); editorHost:SetPoint("TOPLEFT", editorHost.row, "TOPLEFT", 0, -8); editorHost:SetPoint("BOTTOMRIGHT", editorHost.row, "BOTTOMRIGHT", -12, 8)
    local scroll = CreateFrame("ScrollFrame", nil, editorHost); scroll:SetAllPoints(editorHost); scroll:EnableMouseWheel(true)
    local edit = CreateFrame("EditBox", nil, scroll); edit:SetSize(400, 200); edit:SetMultiLine(true); edit:SetAutoFocus(false)
    edit:SetMaxLetters(addon.ProfileCodec.limit); edit:SetFontObject(GameFontHighlight); edit:SetTextInsets(8, 8, 8, 8)
    addon.Media:BindInterfaceFont(edit, GameFontHighlight); W.Texture(edit, "InputField"); scroll:SetScrollChild(edit)
    local hint = W.Label(edit, "Paste a ModeUI profile string here, or export one.", nil, 8, -8, 380, T.muted)
    local resizing = false
    local function Resize()
        if resizing then return end
        resizing = true
        local width = math.max(200, scroll:GetWidth() - 4)
        if edit:GetWidth() ~= width then edit:SetWidth(width) end
        local _, fontHeight = edit:GetFont()
        local lines = edit:GetNumLines()
        local height = math.max(200, lines * (fontHeight or 12) + math.max(0, lines - 1) * (edit.GetSpacing and edit:GetSpacing() or 0) + 16)
        if edit:GetHeight() ~= height then edit:SetHeight(height) end
        local maximum = math.max(0, height - scroll:GetHeight())
        if scroll:GetVerticalScroll() > maximum then scroll:SetVerticalScroll(maximum) end
        resizing = false
    end
    local settingText = false
    edit:SetScript("OnTextChanged", function()
        hint:SetShown(edit:GetText() == "")
        Resize()
        if not settingText then
            page.profileEditorMode = "import"
            local draft = edit:GetText()
            addon.ReloadManager:SetDraft("profile-import", draft:match("^%s*(.-)%s*$") ~= "")
            if draft:match("^%s*$") then page.transferStatus:SetText("")
            else
                local profile, name, reason = P:PrepareImport(draft, importName:GetText())
                page.transferStatus:SetText(profile and ("Ready to import as " .. name .. ".") or reason)
            end
        end
    end)
    scroll:SetScript("OnSizeChanged", Resize)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(math.max(0, edit:GetHeight() - scroll:GetHeight()), scroll:GetVerticalScroll() - delta * 36)))
    end)
    function page.setEditorText(text)
        settingText = true; edit:SetText(text); settingText = false
        hint:SetShown(text == "")
        if text == "" then addon.ReloadManager:SetDraft("profile-import", false) end
        Resize()
    end
    local clearRow = page:Row("", 44)
    Action(clearRow, "Clear", 90, function() page.setEditorText(""); page.transferStatus:SetText("") end, "secondary")
    page.transferStatus = Label(page:Row("Result", 56), T.muted)

    page.profileSelect, page.profileSwitch, page.profileCancel, page.profileDelete = choose, switch, cancel, delete
    page.renameInput, page.renameButton, page.duplicateInput, page.duplicateButton = renameInput, rename, duplicateInput, duplicate
    page.createInput, page.createButton, page.profileStatus, page.activeLabel = createInput, create, status, active
    page.exportButton, page.importName, page.importButton, page.profileEditor = export, importName, import, edit
    page.selectedProfile = Selected
    function page.selectProfile(name) selected = name; page:Refresh() end

    Refresh(function() status:SetText(P.status or "Changes save automatically to the active profile.") end)
    W.PinnedSectionTabs(page)
    page:Finish(); return page
end
