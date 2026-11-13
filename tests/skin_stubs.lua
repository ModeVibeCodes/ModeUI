-- Client stubs for skinning Blizzard frames (Chat, Windows): region and child
-- lists, visibility, mouse-over, IDs, and hooksecurefunc in both its forms.
-- They record intent; real rendering, mouse and taint are native only.
    local methods = getmetatable(UIParent).__index
    function methods:GetRegions()
        local out = {}
        for _, texture in ipairs(textures) do if texture.parent == self then out[#out + 1] = texture end end
        return unpack(out)
    end
    function methods:GetChildren()
        local out = {}
        for _, frame in ipairs(frames) do if frame.parent == self then out[#out + 1] = frame end end
        return unpack(out)
    end
    function methods:IsVisible()
        if not self.shown then return false end
        return self.parent == nil or self.parent:IsVisible()
    end
    function methods:IsMouseOver() return self.mouseOver == true end
    function methods:SetID(id) self.id = id end
    function methods:GetID() return self.id or 0 end
    function methods:SetFrameStrata(value) self.strata = value end
    -- hooksecurefunc(table, name, hook) and hooksecurefunc(globalName, hook).
    function hooksecurefunc(t, name, hook)
        if type(t) == 'string' then t, name, hook = _G, t, name end
        local old = t[name]
        assert(type(old) == 'function', 'hooksecurefunc needs an existing function: ' .. tostring(name))
        t[name] = function(...) local r = { old(...) }; hook(...); return unpack(r) end
    end
    -- Font strings are regions too (GetRegions lists them with textures).
    local createFontString = methods.CreateFontString
    function methods:CreateFontString(...)
        local text = createFontString(self, ...)
        textures[#textures + 1] = text
        return text
    end
    function methods:SetRotation(value) self.rotation = value end
    function methods:GetAtlas() return self.atlas end
    function methods:SetAtlas(value) self.atlas = value end
    -- Frame types the Blizzard templates use, made as plain frames.
    local createFrame = CreateFrame
    function CreateFrame(kind, name, parent, ...)
        if kind == 'CheckButton' or kind == 'DropdownButton' or kind == 'EventFrame' then
            local frame = createFrame(kind == 'EventFrame' and 'Frame' or 'Button', name, parent, ...)
            frame.kind = kind
            return frame
        end
        return createFrame(kind, name, parent, ...)
    end
