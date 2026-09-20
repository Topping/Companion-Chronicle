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

function Layout:Pages(entries, expanded, appearance, canonicalName, rpVisible)
    local cached = self.cached
    if cached and cached.entries == entries and cached.expanded == expanded
        and cached.appearance == appearance and cached.canonicalName == canonicalName
        and cached.rpVisible == rpVisible and #cached.fingerprint == #entries then
        local unchanged = true
        for i, entry in ipairs(entries) do
            local old, context = cached.fingerprint[i], entry.context
            if old.entry ~= entry or old.note ~= entry.note or old.createdAt ~= entry.createdAt
                or old.zone ~= context.zone or old.subzone ~= context.subzone
                or old.instance ~= context.instance or old.instanceType ~= context.instanceType
                or old.group ~= context.group or old.sharedGroup ~= context.sharedGroup
                or old.persona ~= (context.rp and context.rp.displayName) then
                unchanged = false
                break
            end
        end
        if unchanged then return cached.pages end
    end
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
    local budget = 274
    -- Reserve a quiet footer above Chronicle's curved, worn page edge.
    if appearance == "immersive" then budget = 258 end
    if rpVisible then budget = budget - 24 end
    for i = #entries, 1, -1 do
        local entry = entries[i]
        local displayName = entry.context.rp and entry.context.rp.displayName
        local personaText = displayName and displayName:lower() ~= (canonicalName or ""):lower()
            and ("As " .. displayName) or nil
        local personaHeight = personaText and 16 or 0
        if font then self.measure:SetFont(font, size, flags) end
        self.measure:SetWidth(width)
        local noteHeight = 0
        if entry.note then
            self.measure:SetText(ns.Escape(entry.note))
            noteHeight = math.max(18, math.ceil(self.measure:GetStringHeight()) + 2)
        end
        local detailsText = self:EntryDetails(entry)
        local contextHeight = 0
        if expanded then
            if font then self.measure:SetFont(font, 10, flags) end
            self.measure:SetWidth(appearance == "immersive" and 240 or 392)
            self.measure:SetText(ns.Escape(detailsText))
            contextHeight = math.min(math.ceil(self.measure:GetStringHeight()) + 4, budget - 54)
        end
        -- Oversized imported text keeps a bounded preview and the full editor.
        noteHeight = math.min(noteHeight, budget - contextHeight - personaHeight - 54)
        local height = (entry.note and noteHeight + 28 or 28) + personaHeight + contextHeight + 16
        if used + height > budget then pages[#pages + 1] = {}; used = 0 end
        pages[#pages][#pages[#pages] + 1] = { entry = entry, height = height, noteHeight = noteHeight,
            detailsText = detailsText, contextHeight = contextHeight,
            personaText = personaText, personaHeight = personaHeight }
        used = used + height
    end
    local fingerprint = {}
    for i, entry in ipairs(entries) do
        local context = entry.context
        fingerprint[i] = {
            entry = entry, note = entry.note, createdAt = entry.createdAt,
            zone = context.zone, subzone = context.subzone, instance = context.instance,
            instanceType = context.instanceType, group = context.group,
            sharedGroup = context.sharedGroup,
            persona = context.rp and context.rp.displayName,
        }
    end
    self.cached = { entries = entries, expanded = expanded, appearance = appearance,
        canonicalName = canonicalName, rpVisible = rpVisible,
        fingerprint = fingerprint, pages = pages }
    return pages
end
