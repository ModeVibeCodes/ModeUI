local _, addon = ...
local W = addon.ConfigWidgets

-- The standard settings tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs"; the
-- owner's settings review, November 21, 2026). Every Interface and Panels
-- module page uses these tab names, in this order, showing only the ones it
-- has; Edit Mode adds Place. Inside a tab, a module's cards follow the
-- section order below (by part where one tab holds several parts).
W.STANDARD_TABS = { "General", "Fill", "Border", "Glow", "Text", "Auras", "Behavior" }
W.STANDARD_SECTIONS = {
    General = { "Show", "Link", "Size", "Arrange" },
    Fill = { "Bars", "Empty part", "Shields", "Background" },
    Border = { "Border", "Icon borders", "Rims" },
    Glow = { "Effects", "Highlights", "Aura glows", "Text glows" },
    Text = { "Text style", "One card per text" },
    Auras = { "Which auras", "Icons", "Timer", "Stacks" },
    Behavior = { "When it shows", "Fade", "Paging and clicks" },
}
local STANDARD = {}
for index, title in ipairs(W.STANDARD_TABS) do STANDARD[title] = index end
W.STANDARD_TAB_INDEX = STANDARD

-- One term per idea (the glossary): labels a converted page may no longer
-- use, and the term that replaced each.
W.RETIRED_LABELS = {
    ["Border Style"] = "Border", ["Border Thickness"] = "Border Size", ["Border Gap"] = "Padding",
    ["Border Shift"] = "Padding", ["Turn On"] = "Show <Part>", ["Text Outline"] = "Outline",
    ["Text Shadow"] = "Shadow", ["Drop Shadow"] = "Shadow", ["Font Size"] = "Size", ["Gap"] = "Spacing",
    ["Copy & Apply"] = "Copy To…", ["Reset to Defaults"] = "Reset…", ["Opacity"] = "Background Opacity or Bar Opacity",
    ["Use Global Setting"] = "Suite",
}

-- page:Tab(title) opens a standard tab: the first call makes it, a later one
-- goes back to it, so a module can add a part's border card to Border and
-- its fill card to Fill from the same block of code. Rows keep the order they
-- were added in; each tab shows only its own.
function W.TabControls(page)
    function page:Tab(title)
        for _, section in ipairs(self.sections) do
            if section.title == title then
                self.activeSection, self.activeGroup, self.activeCard = section, nil, nil
                return section
            end
        end
        return self:Section(title, nil, false)
    end
end

-- The page's tabs in the standard order (any other tab after them; the
-- taxonomy test fails a converted module that has one). pinned: tabs above
-- the page's scroll area (pages without a preview layer).
function W.StandardTabs(page, pinned)
    local order, seen = {}, {}
    for _, title in ipairs(W.STANDARD_TABS) do
        for _, section in ipairs(page.sections) do
            if section.title == title and not seen[section] then order[#order + 1] = title; seen[section] = true end
        end
    end
    for _, section in ipairs(page.sections) do
        if not seen[section] then order[#order + 1] = section.title; seen[section] = true end
    end
    page.standardTabs = true
    W.SectionTabs(page, order)
    if pinned then W.PinnedSectionTabs(page) end
end
