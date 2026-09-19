local _, ns = ...
local C, W = ns.Controller, ns.Widgets
local Label, Button, Panel = W.Label, W.Button, W.Panel
local UI = {}
ns.UI = UI

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
    note:SetTextColor(0.14, 0.095, 0.055); note:SetShadowOffset(0, 0); note.Instructions:SetText("")
    note:SetScript("OnTextChanged", function(box) if not self.rendering then C:UpdateDraft(box:GetText()) end end)
    note:SetScript("OnEscapePressed", function() C:CancelEditor() end)
    self.editorError = Label(self.editor, "", 18, -276, 540, 22, "GameFontNormalSmall")
    self.saveNote = Button(self.editor, "Save", 18, -310, 90, function() C:SaveEditor() end)
    self.cancelNote = Button(self.editor, "Cancel", 118, -310, 90, function() C:CancelEditor() end)
    self.editor:SetScript("OnHide", function() note:ClearFocus(); if not self.rendering then C:CancelEditor() end end)

    self.settings = Panel("CompanionChronicleSettings", 460, 395)
    self.settings:SetFrameStrata("FULLSCREEN_DIALOG")
    Label(self.settings, "Companion Chronicle settings", 18, -12, 420, 26, "GameFontNormalLarge"):SetTextColor(0.97, 0.93, 0.83)
    Label(self.settings, "Appearance", 18, -55, 150, 25)
    self.immersiveToggle = Button(self.settings, "Immersive", 175, -55, 125, function() C:SetAppearance("immersive") end)
    self.modernToggle = Button(self.settings, "Modern", 310, -55, 130, function() C:SetAppearance("modern") end)
    Label(self.settings, "Ask for a note after Friendly / Unfriendly", 18, -95, 325, 40)
    self.notePromptToggle = Button(self.settings, "Off", 355, -101, 85, function() C:ToggleNotePrompt() end)
    Label(self.settings, "Off: save quietly. Add a note whenever you like.", 18, -145, 422, 30, "GameFontHighlightSmall")
    Label(self.settings, "Recognize people in chat", 18, -185, 325, 26)
    self.chatMarkersToggle = Button(self.settings, "On", 355, -185, 85, function() C:ToggleSetting("chatMarkers") end)
    Label(self.settings, "Markers appear on new messages from remembered players.", 18, -217, 422, 30, "GameFontHighlightSmall")
    Label(self.settings, "Remind me when we group together", 18, -263, 325, 26)
    self.groupRemindersToggle = Button(self.settings, "On", 355, -263, 85, function() C:ToggleSetting("groupReminders") end)
    Label(self.settings, "A private chat reminder for allies and people you have rated.", 18, -295, 422, 30, "GameFontHighlightSmall")
    Button(self.settings, "Close", 350, -355, 90, function() C:Settings(false) end)
    self.settings:SetScript("OnHide", function() if not self.rendering then C:Settings(false) end end)
end

function UI:Render(state)
    if not self.editor then return end
    self.rendering = true
    local view = ns.Views[state.settings.appearance] or ns.Views.immersive
    if not view.window then view:Create() end
    if self.active ~= view and self.active then self.active.window:Hide() end
    self.active = view
    W.StylePanel(self.editor, state.settings.appearance)
    W.StylePanel(self.settings, state.settings.appearance)
    view:Render(state)
    view.window:SetShown(state.visible)
    self.immersiveToggle:SetEnabled(state.settings.appearance ~= "immersive")
    self.modernToggle:SetEnabled(state.settings.appearance ~= "modern")
    self.notePromptToggle:SetText(state.settings.askForNotes and "On" or "Off")
    self.chatMarkersToggle:SetText(state.settings.chatMarkers and "On" or "Off")
    self.groupRemindersToggle:SetText(state.settings.groupReminders and "On" or "Off")
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
    self.rendering = false
end
