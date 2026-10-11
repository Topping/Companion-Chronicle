local _, ns = ...
local M, C, W = ns.Model, ns.Controller, ns.Widgets
local Label, Rect = W.Label, W.Rect
local Chronicle = {}
ns.Views.immersive = Chronicle

-- Typography only: never reinterpret the realm, key or GUID as part of a name.
local function NameLines(identity)
    local name = identity.name:gsub("%s+", " "):match("^%s*(.-)%s*$")
    local first, surname = name:match("^(%S+)%s+(.+)$")
    return ns.Escape(first or name), ns.Escape(surname or "")
end

local function Ink(parent, text, x, y, width, height, size)
    local label = Label(parent, text, x, y, width, height, "QuestFont")
    if size then local font, _, flags = label:GetFont(); if font then label:SetFont(font, size, flags) end end
    label:SetTextColor(0.19, 0.12, 0.065)
    return label
end
local function Center(parent, text, x, y, width, height, size)
    local label = Ink(parent, text, x, y, width, height, size); label:SetJustifyH("CENTER"); return label
end
local function Rule(parent, x, y, width) return Rect(parent, "ARTWORK", x, y, width, 1, 0.39, 0.25, 0.12, 0.3) end
local function FitLabel(label, text, maximum, minimum, width)
    label:SetText(text)
    local font, _, flags = label:GetFont()
    if not font then return false end
    for size = maximum, minimum, -1 do
        label:SetFont(font, size, flags)
        local measured = label.GetUnboundedStringWidth
            and label:GetUnboundedStringWidth() or label:GetStringWidth()
        if measured <= width then return true end
    end
    return false
end
local function Link(parent, text, x, y, width, callback, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = Ink(button, text, 2, 0, width - 4, 24, size or 13)
    label:SetTextColor(0.43, 0.17, 0.09); button:SetFontString(label); button:SetText(text)
    button:SetScript("OnEnter", function() label:SetTextColor(0.65, 0.25, 0.10) end)
    button:SetScript("OnLeave", function() label:SetTextColor(0.43, 0.17, 0.09) end)
    button:SetScript("OnClick", callback)
    return button
end

local function ActionButton(parent, text, x, y, width, callback, style)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local dark = style == "write"
    button.fill = Rect(button, "BACKGROUND", 1, -1, width - 2, 22,
        dark and 0.38 or 0.89, dark and 0.23 or 0.80, dark and 0.14 or 0.62, dark and 0.96 or 0.70)
    Rect(button, "ARTWORK", 0, 0, width, 1, 0.53, 0.36, 0.19, 0.70)
    Rect(button, "ARTWORK", 0, -23, width, 1, 0.53, 0.36, 0.19, 0.70)
    Rect(button, "ARTWORK", 0, 0, 1, 24, 0.53, 0.36, 0.19, 0.70)
    Rect(button, "ARTWORK", width - 1, 0, 1, 24, 0.53, 0.36, 0.19, 0.70)
    local inset = style == "ally" and 20 or 2
    button.caption = Ink(button, text, inset, 0, width - inset - 2, 24, 10)
    button.caption:SetJustifyH("CENTER")
    button.caption:SetTextColor(dark and 0.97 or 0.36, dark and 0.88 or 0.21, dark and 0.69 or 0.11)
    button:SetFontString(button.caption); button:SetText(text)
    if style == "ally" then
        -- SetFontString reanchors the label across the whole button. Restore
        -- the inset so the word starts clear of the dot.
        button.caption:ClearAllPoints()
        button.caption:SetPoint("TOPLEFT", button, "TOPLEFT", 20, 0)
        button.caption:SetSize(width - 22, 24)
        button.dot = CreateFrame("Frame", nil, button)
        button.dot:SetSize(8, 8); button.dot:SetPoint("LEFT", button, "LEFT", 5, 0)
        local ring = {
            {3, 0, 2, 1}, {1, -1, 2, 1}, {5, -1, 2, 1},
            {0, -2, 1, 4}, {7, -2, 1, 4},
            {1, -6, 2, 1}, {5, -6, 2, 1}, {3, -7, 2, 1},
        }
        for _, part in ipairs(ring) do
            Rect(button.dot, "ARTWORK", part[1], part[2], part[3], part[4], 0.41, 0.21, 0.10, 0.95)
        end
        button.dotFill = {}
        for _, part in ipairs({ {3, -2, 2, 1}, {2, -3, 4, 2}, {3, -5, 2, 1} }) do
            local fill = Rect(button.dot, "ARTWORK", part[1], part[2], part[3], part[4],
                0.41, 0.21, 0.10, 0.95)
            fill:Hide()
            button.dotFill[#button.dotFill + 1] = fill
        end
    end
    button:SetScript("OnClick", callback)
    return button
end

local function Bookmark(parent, text, y, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(110, 40)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", -28, y)
    button.leather = button:CreateTexture(nil, "BACKGROUND")
    button.leather:SetAllPoints(button)
    button.leather:SetTexture("Interface\\AddOns\\CompanionChronicle\\Art\\chronicle-bookmark.tga")
    button.caption = Ink(button, text, 25, 0, 78, 40, 14)
    button.caption:SetJustifyH("CENTER")
    button:SetFontString(button.caption)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    button:SetScript("OnEnter", function()
        if not button.selected then button.leather:SetVertexColor(0.9, 0.8, 0.7) end
    end)
    button:SetScript("OnLeave", function()
        if not button.selected then button.leather:SetVertexColor(0.62, 0.57, 0.51) end
    end)
    return button
end

local function SelectBookmark(button, selected)
    button.selected = selected
    button:SetEnabled(not selected)
    if selected then
        button.leather:SetVertexColor(1, 1, 1)
        button.caption:SetTextColor(1, 0.89, 0.64)
    else
        button.leather:SetVertexColor(0.62, 0.57, 0.51)
        button.caption:SetTextColor(0.82, 0.75, 0.61)
    end
end

function Chronicle:Create()
    local window = CreateFrame("Frame", nil, UIParent)
    self.window = window
    window:SetSize(960, 640); window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:SetFrameStrata("DIALOG"); window:EnableMouse(true); window:SetMovable(true)
    window:SetClampedToScreen(true); window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    window:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)
    self.book = window:CreateTexture(nil, "BACKGROUND")
    self.book:SetAllPoints(window); self.book:SetTexture("Interface\\AddOns\\CompanionChronicle\\Art\\chronicle-book.tga")
    -- Live text is inset from the baked page-edge wear and central gutter.
    Ink(window, "THE ROADS OF AZEROTH", 86, -69, 226, 18, 10)
    Ink(window, "A PRIVATE RECORD", 312, -69, 124, 18, 10):SetJustifyH("RIGHT")
    Rule(window, 86, -93, 350)
    Center(window, "The Companion", 86, -112, 350, 28, 19)
    Center(window, "Chronicle", 86, -139, 350, 45, 34)
    self.indexTitle = Ink(window, "INDEX OF COMPANIONS", 86, -271, 350, 22, 10)
    self.search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    self.search:SetSize(290, 24); self.search:SetPoint("TOPLEFT", window, "TOPLEFT", 143, -242)
    self.search:SetAutoFocus(false); self.search:SetMaxLetters(100)
    self.search:SetFontObject("QuestFont"); self.search:SetTextColor(0.19, 0.12, 0.065)
    Ink(window, "Find", 86, -242, 48, 24, 13)
    self.search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.search:SetScript("OnTextChanged", function(box) if not ns.UI.rendering then C:SetQuery(box:GetText()) end end)
    self.rows = {}
    for i = 1, 8 do
        local column, line = (i - 1) % 2, math.floor((i - 1) / 2)
        local row = CreateFrame("Button", nil, window)
        row:SetSize(164, 51); row:SetPoint("TOPLEFT", window, "TOPLEFT", 86 + column * 186, -304 - line * 53)
        row.nameLabel = Ink(row, "", 6, 0, 158, 20, 16)
        row.surnameLabel = Ink(row, "", 6, -19, 158, 15, 12)
        row.infoLabel = Ink(row, "", 6, -24, 158, 20, 10)
        row.nameLabel:SetMaxLines(1)
        row.surnameLabel:SetMaxLines(1)
        row.infoLabel:SetMaxLines(1)
        row.selectionMark = Rect(row, "ARTWORK", 0, -4, 2, 36, 0.45, 0.16, 0.08, 0.8)
        Rule(row, 5, -49, 157)
        row:SetScript("OnClick", function(button)
            if not button.row then return end
            local identity = button.row.identity
            C:SelectRow(identity, button.row.context)
        end)
        self.rows[i] = row
    end
    self.empty = Ink(window, "", 92, -310, 330, 178, 14)
    self.listPage = Ink(window, "", 86, -532, 255, 22, 11)
    self.listPrevious = Link(window, "<", 359, -528, 32, function() C:Page(-1) end)
    self.listNext = Link(window, ">", 405, -528, 32, function() C:Page(1) end)
    Center(window, "i · The index", 86, -564, 350, 20, 11)
    -- Narrow leather bookmarks sit at the outside edge, never across the prose.
    self.alliesTab = Bookmark(window, "Allies", -176, function() C:SetView("Allies") end)
    self.peopleTab = Bookmark(window, "People", -222, function() C:SetView("Remembered") end)
    self.recentTab = Bookmark(window, "Recent", -268, function() C:SetView("Recent") end)
    self.enemiesTab = Bookmark(window, "Enemies", -314, function() C:SetView("Enemies") end)
    Link(window, "Settings", 763, -66, 72, function() C:Settings(true) end)
    Link(window, "Close", 839, -66, 50, function() C:Close() end)
    Rule(window, 520, -93, 350)
    self.help = Center(window, "A name on the road.\n\nChoose a companion from the index\nto read the memories you have kept.", 535, -213, 320, 170, 18)
    self.details = CreateFrame("Frame", nil, window)
    self.details:SetSize(350, 450); self.details:SetPoint("TOPLEFT", window, "TOPLEFT", 520, -105)
    self.detailTitle = Ink(self.details, "", 0, 0, 265, 36, 30)
    self.detailTitle:SetMaxLines(1)
    self.detailSurname = Ink(self.details, "", 0, -43, 350, 30, 18)
    self.detailSurname:Hide()
    self.detailTitle:SetJustifyV("TOP")
    self.detailRealm = Ink(self.details, "", 0, -43, 350, 18, 12)
    self.detailRealm:SetMaxLines(1)
    self.detailScore = Ink(self.details, "", 270, -2, 80, 30, 23)
    self.detailScore:SetJustifyH("RIGHT")
    self.detailScore:SetTextColor(0.22, 0.10, 0.04)
    self.detailScore:SetShadowColor(1, 0.91, 0.74, 0.95)
    self.detailScore:SetShadowOffset(1, -1)
    self.scoreCaption = Ink(self.details, "REPUTATION", 270, -28, 80, 13, 8)
    self.scoreCaption:SetJustifyH("RIGHT")
    self.detailRP = Ink(self.details, "", 0, -62, 350, 18, 11)
    self.detailRP:SetMaxLines(1)
    self.ally = ActionButton(self.details, "Ally", 0, -77, 52, function() C:ToggleAlly() end, "ally")
    self.ratePositive = ActionButton(self.details, "+ Rep", 56, -77, 45,
        function() if C.selection then C:Rate(C.selection.identity, 1, C.selection.context) end end)
    self.rateNegative = ActionButton(self.details, "- Rep", 105, -77, 45,
        function() if C.selection then C:Rate(C.selection.identity, -1, C.selection.context) end end)
    self.write = ActionButton(self.details, "Add memory", 154, -77, 92,
        function() if C.selection then C:OpenEditor(C.selection.identity, C.selection.context) end end, "write")
    self.forget = ActionButton(self.details, "Delete character", 250, -77, 100, function() C:Forget() end)
    self.historyRule = Rule(self.details, 0, -113, 350)
    self.entryRows = {}
    for i = 1, 10 do
        local row = CreateFrame("Button", nil, self.details)
        row.title = Ink(row, "", 12, -8, 326, 20, 10)
        row.title:SetMaxLines(1)
        row.persona = Ink(row, "", 0, -24, 240, 16, 10)
        row.persona:SetMaxLines(1)
        row.title:SetTextColor(0.42, 0.30, 0.18)
        row.note = Ink(row, "", 0, -24, 350, 43, 15)
        row.noteWidth = 326
        row.note:SetJustifyV("TOP")
        row.edit = Link(row, "Read / edit", 12, -48, 100, function()
            if row.entry and C.selection then C:OpenEditor(C.selection.identity, row.entry.context, row.entry.id) end
        end, 11)
        row.delete = Link(row, "Delete", 260, -72, 90, function() if row.entry then C:DeleteEntry(row.entry.id) end end, 11)
        row:SetScript("OnClick", function(button)
            if button.entry and C.selection then
                C:OpenEditor(C.selection.identity, button.entry.context, button.entry.id)
            end
        end)
        row.divider = Rule(row, 0, -80, 350)
        self.entryRows[i] = row
    end
    self.historyPage = Ink(self.details, "", 200, -432, 70, 24, 11)
    self.historyPrevious = Link(self.details, "<", 278, -432, 30, function() C:EntryPage(-1) end)
    self.historyNext = Link(self.details, ">", 321, -432, 30, function() C:EntryPage(1) end)
    self.status = Center(window, "", 89, -603, 780, 24, 11)
    self.status:SetTextColor(0.96, 0.86, 0.65)
    window:SetScript("OnHide", function() self.search:ClearFocus(); if not ns.UI.rendering then C:Close() end end)
    window:Hide()
end

function Chronicle:Render(state)
    if self.search:GetText() ~= state.query then self.search:SetText(state.query) end
    local allies = state.view == "Remembered" and state.alliesOnly
    local enemies = state.view == "Enemies"
    self.indexTitle:SetText(enemies and "ENEMIES" or (allies and "TRUSTED ALLIES" or "INDEX OF COMPANIONS"))
    SelectBookmark(self.peopleTab, state.view == "Remembered" and not allies)
    SelectBookmark(self.recentTab, state.view == "Recent")
    SelectBookmark(self.alliesTab, allies)
    SelectBookmark(self.enemiesTab, enemies)
    self.status:SetText(ns.Escape(state.message))
    for i, button in ipairs(self.rows) do
        local row = state.rows[i]; button.row = row; button:SetShown(row ~= nil)
        if row then
            local first, surname = NameLines(row.identity)
            local rep = row.summary and string.format(" · %+d", row.summary.score) or ""
            local repInInfo = false
            if not FitLabel(button.nameLabel, first .. (surname == "" and rep or ""), 16, 10, 158) then
                FitLabel(button.nameLabel, first, 16, 10, 158)
                repInInfo = surname == ""
            end
            if surname ~= "" and not FitLabel(button.surnameLabel, surname .. rep, 12, 10, 158) then
                FitLabel(button.surnameLabel, surname, 12, 10, 158)
                repInInfo = true
            end
            button.surnameLabel:SetShown(surname ~= "")
            button.infoLabel:ClearAllPoints()
            button.infoLabel:SetPoint("TOPLEFT", button, "TOPLEFT", 6, surname ~= "" and -34 or -24)
            button.infoLabel:SetSize(158, surname ~= "" and 14 or 20)
            local selected = state.selection and M.SameIdentity(state.selection.identity, row.identity)
            button.selectionMark:SetShown(selected == true)
            button.nameLabel:SetTextColor(selected and 0.47 or 0.19, selected and 0.16 or 0.12, 0.065)
            local info = ns.Escape(row.identity.realm)
            if row.summary and row.summary.ally then info = info .. (info ~= "" and " · " or "") .. "Ally" end
            if repInInfo then info = info .. (info ~= "" and " · " or "") .. rep:sub(5) end
            button.infoLabel:SetText(info)
        end
    end
    self.empty:SetShown(state.total == 0)
    self.empty:SetText(state.query ~= "" and "No matching people." or (state.view == "Recent" and "No recent encounters.\n\nGroup members and people whose player menus you open appear here for up to 30 minutes. Recent encounters clear on reload." or "No names written yet.\n\nRight-click a player portrait or chat name to add reputation or a note."))
    if allies and state.query == "" then self.empty:SetText("No allies marked yet.\n\nChoose a companion and mark them as an ally to keep them here.") end
    if enemies and state.query == "" then self.empty:SetText("No enemies recorded.\n\nPeople with reputation below zero appear here.") end
    self.listPage:SetText(state.total .. (enemies and " enemies" or (allies and " allies" or (state.view == "Recent" and " recent encounters" or " remembered"))) .. (state.pageCount > 1 and (" · " .. state.page .. " / " .. state.pageCount) or ""))
    self.listPrevious:SetShown(state.pageCount > 1); self.listNext:SetShown(state.pageCount > 1)
    self.listPrevious:SetEnabled(state.page > 1); self.listNext:SetEnabled(state.page < state.pageCount)
    self.details:SetShown(state.selection ~= nil); self.help:SetShown(state.selection == nil)
    if not state.selection then return end
    local identity, record = state.selection.identity, state.record
    local nameLayout = state.chronicleName or ns.Layout:ChronicleName(identity.name)
    local wrapped = nameLayout.surname ~= nil
    self.detailTitle:SetText(ns.Escape(nameLayout.first))
    self.detailSurname:SetText(ns.Escape(nameLayout.surname or ""))
    self.detailSurname:SetShown(wrapped)
    local font, _, flags = self.detailTitle:GetFont()
    if font then self.detailTitle:SetFont(font, nameLayout.firstSize, flags) end
    font, _, flags = self.detailSurname:GetFont()
    if font and wrapped then self.detailSurname:SetFont(font, nameLayout.surnameSize, flags) end
    self.detailSurname:ClearAllPoints()
    self.detailSurname:SetPoint("TOPLEFT", self.details, "TOPLEFT", 0, -43)
    local subtitleParts = {}
    for _, part in ipairs({ identity.realm or "", identity.race or "", identity.class or "" }) do
        if part and part ~= "" then subtitleParts[#subtitleParts + 1] = part end
    end
    local subtitle = table.concat(subtitleParts, ", ")
    FitLabel(self.detailRealm, ns.Escape(subtitle), 12, 10, 350)
    self.detailRealm:SetShown(subtitle ~= "")
    self.detailRealm:ClearAllPoints()
    self.detailRealm:SetPoint("TOPLEFT", self.details, "TOPLEFT", 0, wrapped and -74 or -43)
    self.detailScore:SetText(string.format("%+d", record and record.score or 0))
    local rpVisible = state.rp and state.rp.displayName ~= nil
    self.detailRP:SetShown(rpVisible == true)
    self.detailRP:SetText(rpVisible and ns.Escape("As " .. state.rp.displayName) or "")
    self.detailRP:ClearAllPoints()
    self.detailRP:SetPoint("TOPLEFT", self.details, "TOPLEFT", 0, wrapped and -93 or -62)
    local extra = (wrapped and 24 or 0) + (rpVisible and 20 or 0)
    for _, button in ipairs({ self.ally, self.ratePositive, self.rateNegative, self.write, self.forget }) do
        local _, _, _, x = button:GetPoint()
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.details, "TOPLEFT", x, -77 - extra)
    end
    self.historyRule:ClearAllPoints()
    self.historyRule:SetPoint("TOPLEFT", self.details, "TOPLEFT", 0, -113 - extra)
    for _, fill in ipairs(self.ally.dotFill) do fill:SetShown(record ~= nil and record.ally == true) end
    self.forget:SetShown(record ~= nil)
    self.forget:SetText(state.forgetKey == identity.key and "Confirm delete" or "Delete character")
    local offset = 126 + extra
    for i, row in ipairs(self.entryRows) do
        local item = state.entries[i]
        offset = W.RenderHistoryRow(row, item, self.details, offset, 350, 260)
        if item then
            local entry = item.entry
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 12, 0)
            row.title:SetWidth(326)
            row.persona:ClearAllPoints()
            row.persona:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -24)
            row.note:ClearAllPoints()
            row.note:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -24 - item.personaHeight)
            row.note:SetWidth(326)
            local actionY = -24 - item.personaHeight - (entry.note and item.noteHeight or 0)
            row.edit:ClearAllPoints()
            row.edit:SetPoint("TOPLEFT", row, "TOPLEFT", 12, actionY)
            row.delete:ClearAllPoints()
            row.delete:SetPoint("TOPLEFT", row, "TOPLEFT", 260, actionY)
            row.divider:Show()
        end
    end
    W.RenderHistoryPager(self, state)
end
