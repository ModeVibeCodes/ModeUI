local _, addon = ...
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L

-- A confirmation in the Mode look, for actions that can't be undone (deleting
-- a bar): a message, the action's button and Cancel. It sits above every
-- settings window, takes the mouse so nothing behind it is clicked, and
-- closes on Cancel, Escape, combat or the action. One at a time: a new one
-- replaces an open one. Built the first time it's needed.
local WIDTH, PAD = 340, 18

local function Build()
    local frame = CreateFrame("Frame", "ModeUIConfirm", UIParent)
    frame:Hide()
    frame:SetSize(WIDTH, 140)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(300)
    frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:EnableKeyboard(true)
    W.Texture(frame, "Window"); W.Texture(frame, "BorderSilver", "BORDER")
    frame.title = W.Heading(frame, "", T.fontSize.section, PAD, -16, WIDTH - 2 * PAD, T.text)
    frame.message = W.Label(frame, "", nil, PAD, -44, WIDTH - 2 * PAD, T.muted)
    frame.message:SetWordWrap(true)
    frame.accept = W.Button(frame, "", 140, 30, "primary")
    frame.accept:SetPoint("BOTTOMLEFT", PAD, 16)
    frame.cancel = W.Button(frame, L["Cancel"], 140, 30, "secondary")
    frame.cancel:SetPoint("BOTTOMRIGHT", -PAD, 16)
    frame.cancel:SetScript("OnClick", function() frame:Hide() end)
    frame.accept:SetScript("OnClick", function()
        local action = frame.action
        frame:Hide()
        if action then action() end
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); self:Hide() else self:SetPropagateKeyboardInput(true) end
    end)
    frame:SetScript("OnShow", function(self) self:RegisterEvent("PLAYER_REGEN_DISABLED") end)
    frame:SetScript("OnHide", function(self) self:UnregisterAllEvents(); self.action = nil end)
    frame:SetScript("OnEvent", function(self) self:Hide() end)
    return frame
end

-- Asks before `action` runs: title, message, the action button's label.
function W.Confirm(title, message, acceptLabel, action)
    if addon.InCombat() then return false end
    W.confirmFrame = W.confirmFrame or Build()
    local frame = W.confirmFrame
    frame.title:SetText(title)
    frame.message:SetText(message)
    frame.accept.label:SetText(acceptLabel)
    frame.action = action
    frame:Show()
    return true
end
