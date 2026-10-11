local _, ns = ...
-- Native text measurement and page packing are presentation concerns. The
-- controller receives only plain page data, never a FontString or other widget.
local Layout = {}
ns.Layout = Layout

local function CharacterCount(text)
    local _, count = text:gsub("[^\128-\191]", "")
    return count
end

local function CharacterPrefix(text, limit)
    local count = 0
    for i = 1, #text do
        local byte = text:byte(i)
        if byte < 128 or byte >= 192 then
            count = count + 1
            if count > limit then return text:sub(1, i - 1) end
        end
    end
    return text
end

function Layout:ChronicleName(name)
    local full = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
    if not self.nameMeasure then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()
        self.nameMeasure = frame:CreateFontString(nil, "ARTWORK", "QuestFont")
        self.nameMeasure:SetSize(1000, 40)
    end
    local measure = self.nameMeasure
    local font, _, flags = measure:GetFont()
    local function fittingSize(text, width)
        measure:SetText(ns.Escape(text))
        if not font then return 14 end
        for size = 30, 14, -2 do
            measure:SetFont(font, size, flags)
            local measured = measure.GetUnboundedStringWidth
                and measure:GetUnboundedStringWidth() or measure:GetStringWidth()
            if measured <= width then return size end
        end
        return nil
    end
    local first, surname = full:match("^(%S+)%s+(.+)$")
    if not surname or CharacterCount(full) <= 19 then
        local fullSize = fittingSize(full, 265)
        if fullSize then return { first = full, firstSize = fullSize } end
    end
    if not surname then return { first = full, firstSize = 14 } end
    local sharedSize = math.min(fittingSize(first, 265) or 14, fittingSize(surname, 350) or 14)
    return { first = first, surname = surname,
        firstSize = sharedSize, surnameSize = sharedSize }
end

function Layout:EntryTitle(entry)
    local c = entry.context
    local location = c.zone or "Unknown place"
    if c.subzone and c.subzone ~= c.zone then location = c.subzone .. ", " .. location end
    local action = entry.delta and string.format("%+d Rep", entry.delta) or "Memory"
    return (entry.createdAt and date("%d %b", entry.createdAt) or "Undated")
        .. " · " .. location .. " · " .. action
end

function Layout:NotePreview(note, appearance)
    local compact = note:gsub("%s+", " "):match("^%s*(.-)%s*$")
    local limit = appearance == "immersive" and 96 or 120
    if CharacterCount(compact) <= limit then return compact end
    return CharacterPrefix(compact, limit):gsub("%s+$", "") .. "…"
end

function Layout:Pages(entries, appearance, canonicalName, rpVisible, nameWrapped)
    local cached = self.cached
    if cached and cached.entries == entries and cached.appearance == appearance
        and cached.canonicalName == canonicalName
        and cached.rpVisible == rpVisible and cached.nameWrapped == nameWrapped
        and #cached.fingerprint == #entries then
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
    local width, size = 392, 14
    if appearance == "immersive" then width, size = 326, 15 end
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
    -- The right page keeps a quiet footer after the memory section.
    if appearance == "immersive" then budget = 286 - (nameWrapped and 12 or 0) end
    if rpVisible then budget = budget - 20 end
    for i = #entries, 1, -1 do
        local entry = entries[i]
        local displayName = entry.context.rp and entry.context.rp.displayName
        local personaText = displayName and displayName:lower() ~= (canonicalName or ""):lower()
            and ("As " .. displayName) or nil
        local personaHeight = personaText and 16 or 0
        if font then self.measure:SetFont(font, size, flags) end
        self.measure:SetWidth(width)
        local noteHeight = 0
        local noteText
        if entry.note then
            noteText = self:NotePreview(entry.note, appearance)
            self.measure:SetText(ns.Escape(noteText))
            noteHeight = math.min(38, math.max(18, math.ceil(self.measure:GetStringHeight()) + 2))
        end
        local height = 62 + personaHeight + noteHeight
        if used + height > budget then pages[#pages + 1] = {}; used = 0 end
        pages[#pages][#pages[#pages] + 1] = { entry = entry, height = height, noteHeight = noteHeight,
            noteText = noteText, titleText = self:EntryTitle(entry),
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
    self.cached = { entries = entries, appearance = appearance,
        canonicalName = canonicalName, rpVisible = rpVisible, nameWrapped = nameWrapped,
        fingerprint = fingerprint, pages = pages }
    return pages
end
