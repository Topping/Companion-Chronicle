local _, ns = ...
local W = {}
ns.Widgets = W
function W.Label(parent, text, x, y, width, height, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetSize(width, height)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.14, 0.095, 0.055)
    label:SetShadowOffset(0, 0)
    label:SetText(text)
    return label
end

local Label = W.Label

function W.Rect(parent, layer, x, y, width, height, r, g, b, alpha)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    texture:SetSize(width, height)
    texture:SetColorTexture(r, g, b, alpha or 1)
    return texture
end

local Rect = W.Rect

function W.Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    Rect(button, "BACKGROUND", 0, 0, width, 24, 0.46, 0.33, 0.16)
    local fill = Rect(button, "BORDER", 1, -1, width - 2, 22, 0.70, 0.60, 0.42)
    local caption = Label(button, text, 4, -2, width - 8, 20, "GameFontHighlightSmall")
    caption:SetJustifyH("CENTER")
    button:SetFontString(caption)
    button:SetText(text)
    button:SetScript("OnEnter", function() fill:SetColorTexture(0.80, 0.70, 0.49) end)
    button:SetScript("OnLeave", function() fill:SetColorTexture(0.70, 0.60, 0.42) end)
    button:SetScript("OnClick", callback)
    return button
end

function W.Panel(name, width, height)
    local panel = CreateFrame("Frame", name, UIParent)
    panel:SetSize(width, height)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Rect(panel, "BACKGROUND", 0, 0, width, height, 0.16, 0.10, 0.05)
    Rect(panel, "BORDER", 2, -2, width - 4, height - 4, 0.60, 0.44, 0.23)
    local leather = Rect(panel, "BORDER", 4, -4, width - 8, height - 8, 0.24, 0.13, 0.07)
    leather:SetTexture("Interface\\AddOns\\CompanionChronicle\\Art\\leather.tga")
    leather:SetVertexColor(0.50, 0.45, 0.40)
    Rect(panel, "ARTWORK", 4, -4, width - 8, 36, 0.035, 0.025, 0.015, 0.65)
    local paper = Rect(panel, "ARTWORK", 12, -44, width - 24, height - 56, 0.89, 0.80, 0.60)
    paper:SetTexture("Interface\\AddOns\\CompanionChronicle\\Art\\parchment.tga")
    paper:SetVertexColor(0.82, 0.78, 0.69)
    panel.paper = paper
    panel:Hide()
    return panel
end


function W.StylePanel(panel, appearance)
    if panel.appearance == appearance then return end
    panel.appearance = appearance
    if appearance == "immersive" then
        panel.paper:SetTexture("Interface\\AddOns\\CompanionChronicle\\Art\\chronicle-book.tga")
        panel.paper:SetTexCoord(0.075, 0.45, 0.1, 0.87)
        panel.paper:SetVertexColor(1, 1, 1)
    else
        panel.paper:SetTexture("Interface\\AddOns\\CompanionChronicle\\Art\\parchment.tga")
        panel.paper:SetTexCoord(0, 1, 0, 1)
        panel.paper:SetVertexColor(0.82, 0.78, 0.69)
    end
end

function W.RenderHistoryRow(row, item, parent, offset, width, deleteX, showDetails)
    local entry = item and item.entry
    row.entry = entry
    row:SetShown(entry ~= nil)
    if not entry then return offset end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -offset)
    row:SetSize(width, item.height)
    row.title:SetText(entry.delta and string.format("%+d Rep", entry.delta) or "Note")
    row.note:SetSize(width, item.noteHeight)
    row.note:SetText(ns.Escape(entry.note or ""))
    row.note:SetShown(entry.note ~= nil)
    row.edit:SetText(entry.note and "Read / edit" or "Add note")
    row.edit:Show()
    local metadataY = entry.note and item.noteHeight + 28 or 28
    row.context:SetText(ns.Escape(item.detailsText))
    row.context:SetHeight(item.contextHeight)
    row.context:ClearAllPoints()
    row.context:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -metadataY)
    row.context:SetShown(showDetails)
    row.delete:ClearAllPoints()
    row.delete:SetPoint("TOPLEFT", row, "TOPLEFT", deleteX, -metadataY)
    row.delete:SetShown(showDetails)
    row.divider:ClearAllPoints()
    row.divider:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -item.height + 6)
    return offset + item.height
end

function W.RenderHistoryPager(view, state)
    local multiple = state.entryPageCount > 1
    view.historyPage:SetText(multiple and (state.entryPage .. " / " .. state.entryPageCount) or "")
    view.historyPrevious:SetShown(multiple)
    view.historyNext:SetShown(multiple)
    view.historyPrevious:SetEnabled(state.entryPage > 1)
    view.historyNext:SetEnabled(state.entryPage < state.entryPageCount)
end
