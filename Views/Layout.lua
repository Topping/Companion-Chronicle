local _, ns = ...
-- Native text measurement and page packing are presentation concerns. The
-- controller receives only plain page data, never a FontString or other widget.
local Layout = {}
ns.Layout = Layout

function Layout:EntryDetails(entry)
    local c = entry.context
    local location = c.zone or "Location unknown"
    if c.subzone and c.subzone ~= c.zone then location = c.subzone .. " · " .. location end
    if c.instance then location = location .. " · " .. c.instance end
    if c.instanceType then location = location .. " (" .. c.instanceType .. ")" end
    local group = c.group or "Unknown"
    if c.sharedGroup == true then group = group .. " · Together"
    elseif c.sharedGroup == false and c.group ~= "Solo" then group = group .. " · Not together" end
    return ns.When(entry.createdAt) .. " · " .. group .. "\n" .. location
end

function Layout:Pages(entries, expanded, appearance)
    local width, size = 490, 14
    if appearance == "immersive" then width, size = 350, 15 end
    if not self.measure then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()
        self.measure = frame:CreateFontString(nil, "ARTWORK", "QuestFont")
    end
    local font, _, flags = self.measure:GetFont()
    if font then self.measure:SetFont(font, size, flags) end
    self.measure:SetWidth(width)
    local pages, used = { {} }, 0
    local budget = expanded and 252 or 300
    -- Reserve a quiet footer above Chronicle's curved, worn page edge.
    if appearance == "immersive" then budget = 258 end
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if font then self.measure:SetFont(font, size, flags) end
        self.measure:SetWidth(width)
        local noteHeight = 0
        if entry.note then
            self.measure:SetText(ns.Escape(entry.note))
            noteHeight = appearance == "immersive"
                and math.max(18, math.ceil(self.measure:GetStringHeight()) + 2)
                or math.max(42, math.ceil(self.measure:GetStringHeight()) + 6)
            -- Oversized imported text keeps a bounded preview and the full editor.
            noteHeight = math.min(noteHeight, budget - (expanded and 84 or 30))
        end
        local height = (entry.note and noteHeight + 30 or 30) + (expanded and 54 or 0)
        local detailsText, contextHeight
        if appearance == "immersive" then
            detailsText = self:EntryDetails(entry)
            contextHeight = 0
            if expanded then
                if font then self.measure:SetFont(font, 10, flags) end
                self.measure:SetWidth(240)
                self.measure:SetText(ns.Escape(detailsText))
                contextHeight = math.min(math.ceil(self.measure:GetStringHeight()) + 4, budget - 54)
            end
            noteHeight = math.min(noteHeight, budget - contextHeight - 54)
            height = (entry.note and noteHeight + 28 or 28) + contextHeight + 16
        end
        if used + height > budget then pages[#pages + 1] = {}; used = 0 end
        pages[#pages][#pages[#pages] + 1] = { entry = entry, height = height, noteHeight = noteHeight,
            detailsText = detailsText, contextHeight = contextHeight }
        used = used + height
    end
    return pages
end
