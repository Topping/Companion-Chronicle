local _, ns = ...
local M = ns.Model
-- Application state and actions. No frame handles or widget reads belong here.
local C = { view = "Remembered", page = 1, entryPage = 1, query = "", alliesOnly = false,
    showDetails = false, visible = false, settingsOpen = false, message = "" }
ns.Controller = C

function C:Refresh() if ns.UI then ns.UI:Render(self:Snapshot()) end end
function C:Message(message)
    self.message = message or ""
    if not self.visible then print("Companion Chronicle: " .. ns.Escape(self.message)) end
    self:Refresh()
end
function C:Create() ns.UI:Create(); self:Refresh() end
function C:ToggleWindow() self.visible = not self.visible; self.forgetKey = nil; self:Refresh() end
function C:Close() self.visible = false; self.forgetKey = nil; self:Refresh() end
function C:Select(identity, context)
    self.selection = { identity = M.Copy(identity), context = M.Copy(context or {}) }
    self.entryPage, self.showDetails, self.forgetKey, self.message = 1, false, nil, ""
    self.entryAnchor = nil
    self:Refresh()
end
function C:SelectRow(identity, context)
    context = M.Copy(context or ns.Context(identity, "Manual record"))
    if not context.firstSeen then context.firstSeen = ns.Now(); context.lastSeen = context.firstSeen end
    self:Select(identity, context)
end
function C:ShowPlayer(identity, context) self.visible = true; self:Select(identity, context) end
function C:SetView(view)
    self.alliesOnly = view == "Allies"
    self.view, self.page = view == "Allies" and "Remembered" or view, 1
    self:Refresh()
end
function C:SetQuery(query) self.query, self.page = query, 1; self:Refresh() end
function C:ToggleFilter() self.alliesOnly = not self.alliesOnly; self.view, self.page = "Remembered", 1; self:Refresh() end
function C:ToggleDetails() self.showDetails, self.entryPage, self.entryAnchor = not self.showDetails, 1, nil; self:Refresh() end
function C:Page(delta) self.page = math.max(1, self:Snapshot().page + delta); self:Refresh() end
function C:EntryPage(delta) self.entryPage = math.max(1, self:Snapshot().entryPage + delta); self.entryAnchor = nil; self:Refresh() end
function C:Settings(open) self.settingsOpen = open; self:Refresh() end
function C:ToggleSetting(key)
    if key ~= "askForNotes" and key ~= "chatMarkers" and key ~= "groupReminders" then return end
    ns.store.saved.settings[key] = not ns.store.saved.settings[key]; self:Refresh()
end
function C:ToggleNotePrompt() self:ToggleSetting("askForNotes") end
function C:RefreshSettings() self:Refresh() end
function C:SetAppearance(appearance)
    if appearance ~= "immersive" and appearance ~= "modern" then return false end
    if ns.store.saved.settings.appearance == appearance then return true end
    -- Retain the current entry even when a different font/width repaginates it.
    local current = self:Snapshot().entries[1]
    self.entryAnchor = self.entryAnchor or (current and current.entry.id)
    ns.store.saved.settings.appearance = appearance
    self:Refresh()
    return true
end
function C:Rate(identity, delta, context)
    if not ns.store then return end
    local entry, err = ns.store:Add(identity, delta, nil, context, ns.Now())
    if not entry then self:Message(err or "Unable to save rating."); return end
    self.confirmation = { identity = M.Copy(identity), entryID = entry.id, context = M.Copy(entry.context) }
    ns.Changed()
    if ns.store.saved.settings.askForNotes == true and not self.editing then self:OpenEditor(identity, entry.context, entry.id) end
end
function C:UndoRating(action)
    if not action or not ns.store then return end
    ns.store:Delete(action.identity, action.entryID)
    if self.confirmation == action then self.confirmation = nil end
    if self.editing and M.SameIdentity(self.editing.identity, action.identity) and self.editing.entryID == action.entryID then self.editing = nil end
    ns.Changed()
end
function C:OpenEditor(identity, context, entryID)
    local entry = entryID and ns.store:Entry(identity, entryID)
    if entryID and not entry then self:Message("This entry no longer exists."); return end
    -- Opening the same editor preserves its draft; target/selection changes do not redirect it.
    if self.editing and M.SameIdentity(self.editing.identity, identity) and self.editing.entryID == entryID then self:Refresh(); return end
    if self.editing then self:Message("Save or cancel the open note before editing another person."); return end
    self.editing = { identity = M.Copy(identity), context = M.Copy(context or {}), entryID = entryID, text = entry and entry.note or "", error = "" }
    self:Refresh()
end
function C:UpdateDraft(text) if self.editing then self.editing.text = text end end
function C:CancelEditor() self.editing = nil; self:Refresh() end
function C:SaveEditor()
    local editing = self.editing
    if not editing then return end
    local ok, err
    if editing.entryID then ok, err = ns.store:Edit(editing.identity, editing.entryID, editing.text, ns.Now())
    elseif not editing.text:find("%S") then self:CancelEditor(); return
    else ok, err = ns.store:Add(editing.identity, nil, editing.text, editing.context, ns.Now()) end
    if not ok then editing.error = err or "Unable to save note."; self:Refresh(); return end
    self.editing = nil; ns.Changed()
end
function C:ToggleAlly()
    if not self.selection then return end
    local identity = self.selection.identity
    local record = ns.store:Get(identity)
    local ok, err = ns.store:SetAlly(identity, not (record and record.ally))
    if not ok then self.message = err or "Unable to change ally status." end
    ns.Changed()
end
function C:DeleteEntry(entryID)
    if not self.selection then return end
    local identity = self.selection.identity
    ns.store:Delete(identity, entryID)
    if self.editing and M.SameIdentity(self.editing.identity, identity) and self.editing.entryID == entryID then self.editing = nil end
    if self.confirmation and M.SameIdentity(self.confirmation.identity, identity) and self.confirmation.entryID == entryID then self.confirmation = nil end
    ns.Changed()
end
function C:Forget()
    if not self.selection then return end
    local identity = self.selection.identity
    if self.forgetKey ~= identity.key then
        self.forgetKey = identity.key
        self:Message("Click Confirm forget to delete all ratings, notes and ally status for " .. identity.name .. "."); return
    end
    local ok, err = ns.store:Forget(identity)
    if not ok then self.forgetKey = nil; self:Message(err); return end
    if self.editing and M.SameIdentity(self.editing.identity, identity) then self.editing = nil end
    if self.confirmation and M.SameIdentity(self.confirmation.identity, identity) then self.confirmation = nil end
    self.selection, self.forgetKey, self.message = nil, nil, "Character forgotten."
    ns.Changed()
end

function C:Snapshot()
    local s = { view = self.view, query = self.query, alliesOnly = self.alliesOnly, showDetails = self.showDetails,
        visible = self.visible, settingsOpen = self.settingsOpen, message = self.message, selection = self.selection,
        editing = self.editing, forgetKey = self.forgetKey, rows = {}, settings = ns.store.saved.settings }
    local rows = {}
    if self.view == "Recent" then
        for i = #ns.store.recent, 1, -1 do
            local row = ns.store.recent[i]
            if (row.identity.name .. "-" .. row.identity.realm):lower():find(self.query:lower(), 1, true) then rows[#rows + 1] = row end
        end
    else
        for _, record in ipairs(ns.store:List(self.query, self.alliesOnly)) do
            if self.view ~= "Enemies" or M.Score(record) < 0 then rows[#rows + 1] = { identity = record } end
        end
    end
    local names = {}
    for _, row in ipairs(rows) do names[row.identity.name] = (names[row.identity.name] or 0) + 1 end
    s.pageCount = math.max(1, math.ceil(#rows / 8)); s.page = math.min(self.page, s.pageCount); s.total = #rows
    for i = (s.page - 1) * 8 + 1, math.min(s.page * 8, #rows) do
        local row = rows[i]
        s.rows[#s.rows + 1] = { identity = row.identity, context = row.context, record = ns.store:Get(row.identity), duplicateName = names[row.identity.name] > 1 }
    end
    s.record = self.selection and ns.store:Get(self.selection.identity)
    local pages = ns.Layout:Pages(s.record and s.record.entries or {}, self.showDetails, s.settings.appearance)
    s.entryPageCount = #pages; s.entryPage = math.min(self.entryPage, #pages)
    if self.entryAnchor then
        for page, items in ipairs(pages) do
            for _, item in ipairs(items) do if item.entry.id == self.entryAnchor then s.entryPage = page end end
        end
    end
    s.entries = pages[s.entryPage]
    -- Defensive copy: a renderer cannot mutate persisted records or controller drafts.
    return M.Copy(s)
end
