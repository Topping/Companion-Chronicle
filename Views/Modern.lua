local _, ns = ...
local M, C, W = ns.Model, ns.Controller, ns.Widgets
local Label, Rect, Button, Panel = W.Label, W.Rect, W.Button, W.Panel
local Modern = {}
ns.Views = ns.Views or {}
ns.Views.modern = Modern
local function Reputation(record)
    return (record and record.ally and "Ally  ·  " or "") .. string.format("Rep %+d", record and record.score or 0)
end

function Modern:Render(state)
    local rows, pages = state.rows, state.pageCount
    self.listPage:SetText(pages > 1 and ("Page " .. state.page .. " of " .. pages) or "")
    self.listPrevious:SetShown(pages > 1)
    self.listNext:SetShown(pages > 1)
    self.listPrevious:SetEnabled(state.page > 1)
    self.listNext:SetEnabled(state.page < pages)
    for i, button in ipairs(self.rows) do
        local row = rows[i]
        button.row = row
        button:SetShown(row ~= nil)
        if row then
            button.nameLabel:SetText(row.duplicateName and ns.DisplayName(row.identity) or ns.Escape(row.identity.name))
            local selected = state.selection and M.SameIdentity(state.selection.identity, row.identity)
            button.selectionMark:SetShown(selected == true)
            button.background:SetColorTexture(0.49, 0.33, 0.13, selected and 0.20 or 0.035)
            local summary = row.summary
            button.repLabel:SetText(summary and Reputation(summary) or "")
            if row.context then
                button.infoLabel:SetText(ns.Escape(row.context.zone or ""))
            else
                local latest = summary and summary.latest
                button.infoLabel:SetText(ns.Escape(latest and (latest.note or latest.context.instance or latest.context.zone) or ""))
            end
        end
    end
    self.empty:SetShown(state.total == 0)
    self.empty:SetText(state.query ~= "" and "No matching people." or (state.view == "Recent" and "No one here yet.\n\nGroup members appear here, along with players whose portrait or chat-name menu you open.\n\nCome back to add a note or mark someone Friendly or Unfriendly after an encounter.\n\nRecent entries last up to 30 minutes and clear when you reload or log out." or "No people saved yet.\n\nRight-click a player to add rep or a note."))
    local allies = state.view == "Remembered" and state.alliesOnly
    self.peopleTab:SetEnabled(state.view ~= "Remembered" or allies)
    self.recentTab:SetEnabled(state.view ~= "Recent")
    self.alliesTab:SetEnabled(not allies)
    self.enemiesTab:SetEnabled(state.view ~= "Enemies")
    self.peopleUnderline:SetShown(state.view == "Remembered" and not allies)
    self.recentUnderline:SetShown(state.view == "Recent")
    self.alliesUnderline:SetShown(allies)
    self.enemiesUnderline:SetShown(state.view == "Enemies")
    if state.query == "" and state.view == "Enemies" then self.empty:SetText("No people with negative reputation.") end
    if state.query == "" and allies then self.empty:SetText("No allies marked yet.") end
    self:RefreshDetails(state)
    self.status:SetText(ns.Escape(state.message))
    if self.search:GetText() ~= state.query then self.search:SetText(state.query) end
end

function Modern:RefreshDetails(state)
    local selection = state.selection
    self.details:SetShown(selection ~= nil)
    self.help:SetShown(selection == nil)
    if not selection then return end
    local identity = selection.identity
    local record = state.record
    self.detailTitle:SetText(state.showDetails and ns.DisplayName(identity) or ns.Escape(identity.name))
    self.detailScore:SetText(Reputation(record))
    self.detailsToggle:SetText(state.showDetails and "Hide details" or "Details")
    self.forget:SetShown(state.showDetails)
    self.ally:SetText(record and record.ally and "Unmark ally" or "Mark as ally")
    self.forget:SetText(state.forgetKey == identity.key and "Confirm forget" or "Forget character")
    W.RenderHistoryPager(self, state)
    local offset = 118
    for i, row in ipairs(self.entryRows) do
        offset = W.RenderHistoryRow(row, state.entries[i], self.details, offset, 490, 400, state.showDetails)
    end
end

function Modern:Create()
    if self.window then return end
    local window = Panel("CompanionChronicleModernWindow", 820, 500)
    self.window = window
    Label(window, "Companion Chronicle", 20, -10, 290, 28, "QuestTitleFont"):SetTextColor(0.97, 0.93, 0.83)
    Label(window, "A personal record of familiar faces", 315, -14, 300, 20, "GameFontHighlightSmall"):SetTextColor(0.90, 0.86, 0.76)
    Rect(window, "ARTWORK", 285, -44, 1, 444, 0.47, 0.33, 0.15, 0.45)
    Button(window, "Settings", 627, -14, 90, function() C:Settings(true) end)
    Button(window, "Close", 727, -14, 75, function() C:Close() end)
    self.alliesTab = Button(window, "Allies", 18, -48, 59, function() C:SetView("Allies") end)
    self.peopleTab = Button(window, "People", 81, -48, 60, function() C:SetView("Remembered") end)
    self.recentTab = Button(window, "Recent", 145, -48, 61, function() C:SetView("Recent") end)
    self.enemiesTab = Button(window, "Enemies", 210, -48, 66, function() C:SetView("Enemies") end)
    self.alliesUnderline = Rect(window, "OVERLAY", 18, -73, 59, 2, 0.48, 0.19, 0.10)
    self.peopleUnderline = Rect(window, "OVERLAY", 81, -73, 60, 2, 0.48, 0.19, 0.10)
    self.recentUnderline = Rect(window, "OVERLAY", 145, -73, 61, 2, 0.48, 0.19, 0.10)
    self.enemiesUnderline = Rect(window, "OVERLAY", 210, -73, 66, 2, 0.48, 0.19, 0.10)
    local search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    self.search = search
    search:SetSize(198, 24)
    search:SetPoint("TOPLEFT", window, "TOPLEFT", 78, -82)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    search:SetScript("OnTextChanged", function(box) if not ns.UI.rendering then C:SetQuery(box:GetText()) end end)
    Label(window, "Search", 18, -82, 54, 24)
    self.rows = {}
    for i = 1, 8 do
        local row = CreateFrame("Button", nil, window)
        row:SetSize(258, 38)
        row:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -114 - (i - 1) * 40)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row); bg:SetColorTexture(0.49, 0.33, 0.13, 0.035)
        row.background = bg
        row.selectionMark = Rect(row, "BORDER", 0, 0, 3, 38, 0.48, 0.19, 0.10)
        row.selectionMark:Hide()
        Rect(row, "BORDER", 0, -37, 258, 1, 0.47, 0.33, 0.15, 0.18)
        row.nameLabel = Label(row, "", 7, -1, 153, 18, "GameFontNormal")
        row.repLabel = Label(row, "", 164, -1, 90, 18, "GameFontHighlightSmall")
        row.infoLabel = Label(row, "", 7, -19, 245, 17, "GameFontHighlightSmall")
        row:SetScript("OnClick", function(button)
            if button.row then
                local identity = button.row.identity
                C:SelectRow(identity, button.row.context)
            end
        end)
        self.rows[i] = row
    end
    self.empty = Label(window, "", 24, -118, 245, 260)
    self.listPage = Label(window, "", 18, -438, 115, 20)
    self.listPrevious = Button(window, "<", 182, -436, 42, function() C:Page(-1) end)
    self.listNext = Button(window, ">", 234, -436, 42, function() C:Page(1) end)
    self.status = Label(window, "", 18, -466, 780, 20, "GameFontHighlightSmall")
    self.help = Label(window, "Choose a person to see their rep and notes.", 300, -100, 490, 60)
    local details = CreateFrame("Frame", nil, window)
    details:SetSize(502, 416); details:SetPoint("TOPLEFT", window, "TOPLEFT", 300, -48)
    self.details = details
    self.detailTitle = Label(details, "", 0, 0, 480, 25, "QuestTitleFont")
    self.detailScore = Label(details, "", 0, -27, 480, 20)
    self.ratePositive = Button(details, "Friendly", 0, -54, 78, function() if C.selection then C:Rate(C.selection.identity, 1, C.selection.context) end end)
    self.rateNegative = Button(details, "Unfriendly", 83, -54, 90, function() if C.selection then C:Rate(C.selection.identity, -1, C.selection.context) end end)
    Button(details, "Add note", 178, -54, 85, function() if C.selection then C:OpenEditor(C.selection.identity, C.selection.context) end end)
    self.ally = Button(details, "Mark as ally", 268, -54, 110, function() C:ToggleAlly() end)
    self.forget = Button(details, "Forget character", 0, -398, 145, function() C:Forget() end)
    Rect(details, "ARTWORK", 0, -84, 490, 1, 0.39, 0.25, 0.12, 0.3)
    Label(details, "WHAT IS REMEMBERED", 0, -89, 380, 20, "GameFontNormalSmall")
    self.detailsToggle = Button(details, "Details", 400, -87, 90, function() C:ToggleDetails() end)
    self.entryRows = {}
    for i = 1, 10 do
        local row = CreateFrame("Frame", nil, details)
        row:SetSize(490, 30)
        row.title = Label(row, "", 0, -3, 392, 20, "GameFontNormalSmall")
        local titleFont, _, titleFlags = row.title:GetFont()
        if titleFont then row.title:SetFont(titleFont, 12, titleFlags) end
        row.context = Label(row, "", 0, -28, 392, 50, "QuestFont")
        row.note = Label(row, "", 0, -24, 490, 42, "QuestFont")
        row.note:SetJustifyV("TOP")
        row.context:SetJustifyV("TOP")
        row.context:SetTextColor(0.38, 0.29, 0.19)
        local contextFont, _, contextFlags = row.context:GetFont()
        if contextFont then row.context:SetFont(contextFont, 10, contextFlags) end
        local font, _, flags = row.note:GetFont()
        if font then row.note:SetFont(font, 14, flags) end
        row.edit = Button(row, "Read / edit", 400, 0, 90, function()
            if row.entry and C.selection then C:OpenEditor(C.selection.identity, row.entry.context, row.entry.id) end
        end)
        row.delete = Button(row, "Delete", 400, -28, 90, function()
            if row.entry and C.selection then
                C:DeleteEntry(row.entry.id)
            end
        end)
        row.divider = Rect(row, "ARTWORK", 0, -80, 490, 1, 0.39, 0.25, 0.12, 0.3)
        self.entryRows[i] = row
    end
    self.historyPage = Label(details, "", 260, -400, 100, 20, "GameFontHighlightSmall")
    self.historyPrevious = Button(details, "<", 390, -398, 45, function() C:EntryPage(-1) end)
    self.historyNext = Button(details, ">", 445, -398, 45, function() C:EntryPage(1) end)

    window:SetScript("OnHide", function() search:ClearFocus(); if not ns.UI.rendering then C:Close() end end)

end
