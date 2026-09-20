local _, ns = ...
local C, W, M = ns.Controller, ns.Widgets, ns.Model
local Label, Button, Panel = W.Label, W.Button, W.Panel
local UI = {}
ns.UI = UI

local function PaintChoice(button)
    local selected = button.selected
    button.selectionMark:SetShown(selected)
    if selected then
        button.fill:SetColorTexture(0.30, 0.21, 0.11)
        button:GetFontString():SetTextColor(1, 0.95, 0.82)
    else
        button.fill:SetColorTexture(0.85, 0.76, 0.58)
        button:GetFontString():SetTextColor(0.14, 0.095, 0.055)
    end
end

local function SelectChoice(button, selected)
    button.selected = selected
    -- SetEnabled can synchronously fire OnLeave; hover handlers only paint.
    button:SetEnabled(not selected)
    PaintChoice(button)
end

local function Choice(parent, text, x, callback)
    local button = Button(parent, text, x, -29, 96, callback)
    button.selected = false
    button.fill = W.Rect(button, "ARTWORK", 1, -1, 94, 22, 0.85, 0.76, 0.58)
    button.selectionMark = W.Rect(button, "OVERLAY", 8, -22, 80, 2, 1, 0.85, 0.48)
    button:SetScript("OnEnter", function()
        if not button.selected then button.fill:SetColorTexture(0.95, 0.86, 0.67) end
    end)
    button:SetScript("OnLeave", function() PaintChoice(button) end)
    return button
end

local function SettingsRow(parent, y, title, description, height)
    height = height or 72
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    row:SetSize(572, height)
    W.Rect(row, "BACKGROUND", 0, 0, 572, height, 0.98, 0.92, 0.76, 0.40)
    W.Rect(row, "BORDER", 0, 1 - height, 572, 1, 0.46, 0.33, 0.16, 0.35)
    row.title = Label(row, title, 12, -10, 338, 22)
    row.description = Label(row, description, 12, -35, 338, 34, "GameFontHighlightSmall")
    row.description:SetJustifyV("TOP")
    return row
end

function UI:ApplyJournalScale(view, size)
    local width, height = view.window:GetWidth(), view.window:GetHeight()
    local leftReach = view == ns.Views.immersive and 28 or 0
    local chosen = size / 100
    local availableWidth = UIParent:GetWidth() - 32
    local availableHeight = UIParent:GetHeight() - 32
    local applied = chosen
    if availableWidth > 0 and availableHeight > 0 then
        applied = math.min(chosen, availableWidth / (width + leftReach), availableHeight / height)
    end
    view.window:SetScale(math.max(0.01, applied))
    if view.appliedScale ~= applied then
        view.window:ClearAllPoints()
        view.window:SetPoint("CENTER", UIParent, "CENTER", leftReach / 2, 0)
        view.appliedScale = applied
    end
end

function UI:RefreshJournalScale()
    if ns.store and self.active and self.active.window then
        local size = tonumber(ns.store.saved.settings.journalSize) or 100
        self:ApplyJournalScale(self.active, size)
    end
end

function UI:Create()
    if self.editor then return end
    self.editor = Panel("CompanionChronicleNoteEditor", 580, 350)
    self.editor:SetFrameStrata("FULLSCREEN_DIALOG")
    self.editorTitle = Label(self.editor, "", 18, -12, 540, 25, "GameFontNormalLarge")
    self.editorTitle:SetTextColor(0.97, 0.93, 0.83)
    self.editorContext = Label(self.editor, "", 18, -42, 540, 45, "GameFontHighlightSmall")
    Label(self.editor, "What would you like to remember?", 18, -90, 535, 20)
    local scroll = CreateFrame("ScrollFrame", nil, self.editor, "InputScrollFrameTemplate")
    self.noteScroll = scroll
    scroll:SetPoint("TOPLEFT", self.editor, "TOPLEFT", 24, -120); scroll:SetSize(528, 146)
    local note = scroll.EditBox
    self.noteBox = note
    note:SetWidth(504); note:SetAutoFocus(false); note:SetMaxLetters(500); note:SetFontObject("QuestFont")
    -- InputScrollFrameTemplate has a dark fill, unlike the surrounding parchment.
    note:SetTextColor(0.97, 0.93, 0.83, 1); note:SetShadowOffset(0, 0); note.Instructions:SetText("")
    local nativeTextChanged = note:GetScript("OnTextChanged")
    note:SetScript("OnTextChanged", function(box, ...)
        if nativeTextChanged then nativeTextChanged(box, ...) end
        if not self.rendering then C:UpdateDraft(box:GetText()) end
    end)
    note:SetScript("OnEscapePressed", function() C:CancelEditor() end)
    self.editorError = Label(self.editor, "", 18, -276, 540, 22, "GameFontNormalSmall")
    self.saveNote = Button(self.editor, "Save", 18, -310, 90, function() C:SaveEditor() end)
    self.cancelNote = Button(self.editor, "Cancel", 118, -310, 90, function() C:CancelEditor() end)
    self.editor:SetScript("OnHide", function() note:ClearFocus(); if not self.rendering then C:CancelEditor() end end)

    self.settings = Panel("CompanionChronicleSettings", 620, 448)
    self.settings:SetFrameStrata("FULLSCREEN_DIALOG")
    Label(self.settings, "Companion Chronicle settings", 18, -12, 420, 26, "GameFontNormalLarge"):SetTextColor(0.97, 0.93, 0.83)
    local appearance = SettingsRow(self.settings, -56, "Appearance", "Choose the look of your journal.", 112)
    self.immersiveToggle = Choice(appearance, "Immersive", 364, function() C:SetAppearance("immersive") end)
    self.modernToggle = Choice(appearance, "Modern", 464, function() C:SetAppearance("modern") end)
    self.sizeValue = Label(appearance, "Journal size: 100%", 12, -76, 338, 22)
    W.Rect(appearance, "BORDER", 382, -82, 160, 4, 0.40, 0.27, 0.13)
    local slider = CreateFrame("Slider", nil, appearance)
    self.sizeSlider = slider
    slider:SetPoint("TOPLEFT", appearance, "TOPLEFT", 382, -76)
    slider:SetSize(160, 16)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetMinMaxValues(1, #M.journalSizes)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(24, 24)
    for i, size in ipairs(M.journalSizes) do
        W.Rect(appearance, "ARTWORK", 381 + (i - 1) * 40, -79, 2, 10, 0.53, 0.34, 0.16)
        local tick = Label(appearance, size .. "%", 366 + (i - 1) * 40, -95, 32, 14, "GameFontHighlightSmall")
        tick:SetJustifyH("CENTER")
    end
    slider:SetScript("OnValueChanged", function(_, value)
        if self.rendering or slider.adjusting then return end
        local index = math.max(1, math.min(#M.journalSizes, math.floor(value + 0.5)))
        if value ~= index then
            slider.adjusting = true
            slider:SetValue(index)
            slider.adjusting = false
        end
        C:SetJournalSize(M.journalSizes[index])
    end)
    self.settingRows = {}
    local options = {
        { "askForNotes", "Ask for notes after rating", "Open a note after Friendly or Unfriendly.\nWhen off, save the rating without a prompt." },
        { "chatMarkers", "Recognize people in chat", "Mark new chat messages from people\nyou have remembered." },
        { "groupReminders", "Group reminders", "Show a private chat reminder when you group\nwith allies or people you have rated." },
    }
    for i, option in ipairs(options) do
        local key = option[1]
        local row = SettingsRow(self.settings, -96 - i * 76, option[2], option[3])
        row.on = Choice(row, "On", 364, function() C:SetSetting(key, true) end)
        row.off = Choice(row, "Off", 464, function() C:SetSetting(key, false) end)
        self.settingRows[key] = row
    end
    Label(self.settings, "Changes are saved automatically.", 36, -411, 400, 20, "GameFontHighlightSmall")
    self.settingsClose = Button(self.settings, "Close", 494, -408, 90, function() C:Settings(false) end)
    self.settings:SetScript("OnHide", function() if not self.rendering then C:Settings(false) end end)
end

function UI:Render(state, skipJournal)
    if not self.editor then return end
    self.rendering = true
    local ok, err = pcall(function()
        local view = ns.Views[state.settings.appearance] or ns.Views.immersive
        if not view.window then view:Create() end
        self:ApplyJournalScale(view, state.settings.journalSize)
        if self.active ~= view and self.active then self.active.window:Hide() end
        self.active = view
        W.StylePanel(self.editor, state.settings.appearance)
        W.StylePanel(self.settings, state.settings.appearance)
        if not skipJournal then view:Render(state) end
        view.window:SetShown(state.visible)
        SelectChoice(self.immersiveToggle, state.settings.appearance == "immersive")
        SelectChoice(self.modernToggle, state.settings.appearance == "modern")
        self.sizeValue:SetText("Journal size: " .. state.settings.journalSize .. "%")
        self.sizeSlider:SetValue((state.settings.journalSize - 70) / 10 + 1)
        for key, row in pairs(self.settingRows) do
            SelectChoice(row.on, state.settings[key])
            SelectChoice(row.off, not state.settings[key])
        end
        self.settings:SetShown(state.settingsOpen)
        local editing = state.editing
        local wasOpen = self.editor:IsShown()
        if editing then
            self.editorTitle:SetText("Note for " .. ns.DisplayName(editing.identity))
            self.editorContext:SetText(ns.Escape(editing.context.zone or ""))
            self.editorError:SetText(ns.Escape(editing.error))
            if self.noteBox:GetText() ~= editing.text then self.noteBox:SetText(editing.text) end
        end
        self.editor:SetShown(editing ~= nil)
        if editing and not wasOpen then self.noteBox:SetCursorPosition(0); self.noteScroll:SetVerticalScroll(0); self.noteBox:SetFocus() end
    end)
    self.rendering = false
    if not ok then error(err, 0) end
end
