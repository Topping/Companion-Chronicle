local _, ns = ...
local Model = {}
ns.Model = Model

function Model.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Model.Copy(v) end
    return result
end

function Model.IdentityFields(identity)
    if not identity then return nil end
    return { key = identity.key, name = identity.name, realm = identity.realm, guid = identity.guid }
end

function Model.Identity(name, realm, guid)
    if type(name) ~= "string" or name == "" then return end
    guid = type(guid) == "string" and guid:match("^Player%-%d+%-%x+$") or nil
    realm = type(realm) == "string" and realm:gsub("%s", "") or ""
    if realm == "" and not guid then return end
    -- Chat can identify a character by GUID without supplying its realm.
    -- Keep full display names intact; never use a bare-name identity.
    local key = realm ~= "" and (name:lower() .. "-" .. realm:lower()) or ("guid:" .. guid)
    return { key = key, name = name, realm = realm, guid = guid }
end

function Model.SameIdentity(a, b)
    if not a or not b then return false end
    if a.guid and b.guid then return a.guid == b.guid end
    return a.key == b.key
end

function Model.IndexIdentity(index, identity)
    if identity.guid then index.byGUID[identity.guid] = identity end
    local bucket = index.byKey[identity.key]
    if not bucket then bucket = {}; index.byKey[identity.key] = bucket end
    bucket[#bucket + 1] = identity
end

function Model.IdentityIndex(identities)
    local index = { byGUID = {}, byKey = {} }
    for _, identity in ipairs(identities) do Model.IndexIdentity(index, identity) end
    return index
end

function Model.FindIdentity(index, identity)
    if identity.guid and index.byGUID[identity.guid] then return index.byGUID[identity.guid] end
    for _, candidate in ipairs(index.byKey[identity.key] or {}) do
        if Model.SameIdentity(candidate, identity) then return candidate end
    end
end

local function Finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local contextStrings = { "reason", "zone", "subzone", "instance", "instanceType", "group" }
local function ValidContext(context)
    if type(context) ~= "table" then return false end
    for _, field in ipairs(contextStrings) do
        if context[field] ~= nil and type(context[field]) ~= "string" then return false end
    end
    if context.sharedGroup ~= nil and type(context.sharedGroup) ~= "boolean" then return false end
    if context.roster ~= nil and (not Finite(context.roster) or context.roster < 0 or context.roster % 1 ~= 0) then return false end
    for _, field in ipairs({ "firstSeen", "lastSeen" }) do
        if context[field] ~= nil and not Finite(context[field]) then return false end
    end
    return true
end

local function DenseEntries(entries)
    if type(entries) ~= "table" then return false end
    local count = 0
    for index in pairs(entries) do
        if type(index) ~= "number" or not Finite(index) or index < 1 or index % 1 ~= 0 then return false end
        count = count + 1
    end
    for index = 1, count do if entries[index] == nil then return false end end
    return true
end

local function ValidRecordKey(key, record)
    local current = Model.Identity(record.name, record.realm, record.guid)
    if not current then return false end
    if key == current.key then return true end
    -- A GUID-only chat record keeps its original storage key when a realm
    -- becomes available later.
    if record.guid and key == "guid:" .. record.guid then return true end
    -- Earlier surname-as-realm records also retain their storage key after a
    -- verified full-name repair. Its two old name parts must still spell the
    -- corrected full name once whitespace is removed.
    if record.guid and record.realm == "" and key == key:lower() then
        local first, second = key:match("^([^-]+)%-(.+)$")
        if first and (first .. second):gsub("%s", "") == record.name:lower():gsub("%s", "") then
            return true
        end
    end
    return false
end

function Model.Open(saved, partition)
    if saved == nil then saved = { version = 1, partitions = {} } end
    if type(saved) ~= "table" or saved.version ~= 1 or type(saved.partitions) ~= "table" then
        return nil, "Unsupported saved-data format; existing data was preserved."
    end
    if saved.settings ~= nil and type(saved.settings) ~= "table" then
        return nil, "Invalid settings; existing data was preserved."
    end
    for _, field in ipairs({ "askForNotes", "chatMarkers", "groupReminders" }) do
        if saved.settings and saved.settings[field] ~= nil and type(saved.settings[field]) ~= "boolean" then
            return nil, "Invalid settings; existing data was preserved."
        end
    end
    local db = saved.partitions[partition]
    if db == nil then db = { characters = {}, nextEntry = 1 } end
    if type(db) ~= "table" or type(db.characters) ~= "table" or not Finite(db.nextEntry)
        or db.nextEntry < 1 or db.nextEntry % 1 ~= 0 then
        return nil, "Invalid saved-data partition; existing data was preserved."
    end
    local seenIDs = {}
    for key, record in pairs(db.characters) do
        if type(key) ~= "string" or key == "" or type(record) ~= "table"
            or type(record.name) ~= "string" or record.name == "" or type(record.realm) ~= "string"
            or record.key ~= key or not DenseEntries(record.entries) or type(record.ally) ~= "boolean"
            or (record.guid ~= nil and (type(record.guid) ~= "string" or not record.guid:match("^Player%-%d+%-%x+$")))
            or not ValidRecordKey(key, record) then
            return nil, "Invalid character record; existing data was preserved."
        end
        for _, entry in ipairs(record.entries) do
            if type(entry) ~= "table" or type(entry.id) ~= "number" or entry.id < 1
                or entry.id % 1 ~= 0 or entry.id >= db.nextEntry or seenIDs[entry.id]
                or (entry.delta ~= nil and entry.delta ~= 1 and entry.delta ~= -1)
                or (entry.note ~= nil and type(entry.note) ~= "string")
                or not Finite(entry.createdAt) or (entry.editedAt ~= nil and not Finite(entry.editedAt))
                or not ValidContext(entry.context) then
                return nil, "Invalid history entry; existing data was preserved."
            end
            seenIDs[entry.id] = true
        end
    end
    saved.partitions[partition] = db
    saved.settings = saved.settings or {}
    if saved.settings.appearance ~= "modern" and saved.settings.appearance ~= "immersive" then saved.settings.appearance = "immersive" end
    if saved.settings.askForNotes == nil then saved.settings.askForNotes = false end
    if saved.settings.chatMarkers == nil then saved.settings.chatMarkers = true end
    if saved.settings.groupReminders == nil then saved.settings.groupReminders = true end
    return setmetatable({ saved = saved, db = db, recent = {}, nextRecent = 1 }, { __index = Model })
end

function Model:Get(identity)
    if not identity then return end
    local record
    if identity.guid then
        for _, candidate in pairs(self.db.characters) do
            if candidate.guid == identity.guid then
                -- Ambiguous old data must not silently choose a history.
                if record then return nil, "Multiple records identify this character; existing data was preserved." end
                record = candidate
            end
        end
    end
    local keyed = self.db.characters[identity.key]
    if record and keyed and record ~= keyed and not keyed.guid then
        return nil, "Multiple records identify this character; existing data was preserved."
    end
    record = record or keyed
    if record and record.guid and identity.guid and record.guid ~= identity.guid then
        return nil, "Character identity changed. Review the existing record before adding another entry."
    end
    return record
end

local function ReconcileIdentity(record, identity)
    -- Only repair an old surname-as-realm record with matching GUID and full
    -- name evidence. Keep its storage key and history IDs stable.
    local repaired = record.guid and record.guid == identity.guid
        and record.realm ~= "" and identity.realm == ""
        and (record.name .. record.realm):gsub("%s", "") == identity.name:gsub("%s", "")
    if identity.guid and not record.guid then record.guid = identity.guid end
    -- A captured pre-repair identity retains the storage key. It cannot undo
    -- the correction merely because it still carries the old realm.
    if repaired or (record.realm == "" and identity.realm ~= "" and identity.key ~= record.key) then
        record.name, record.realm = identity.name, identity.realm
    end
end

function Model:Ensure(identity)
    if not identity or not identity.key then return end
    local record, err = self:Get(identity)
    if err then return nil, err end
    if not record then
        record = Model.Copy(identity)
        record.ally, record.entries = false, {}
        self.db.characters[identity.key] = record
    end
    ReconcileIdentity(record, identity)
    return record
end

function Model.Score(record)
    local score = 0
    for _, entry in ipairs(record and record.entries or {}) do score = score + (entry.delta or 0) end
    return score
end

function Model.Remembered(record)
    return record and (record.ally or #record.entries > 0) or false
end

function Model.Badge(record)
    if not Model.Remembered(record) then return nil end
    if record.ally then return "*", 1, 0.8, 0.25 end
    local score = Model.Score(record)
    if score > 0 then return "+", 0.4, 1, 0.6 end
    if score < 0 then return "-", 1, 0.5, 0.4 end
    return "=", 0.75, 0.8, 1
end

local function CleanNote(note)
    if type(note) ~= "string" then return nil end
    note = note:match("^%s*(.-)%s*$")
    if note == "" then return nil end
    return note
end

function Model:Add(identity, delta, note, context, now)
    note = CleanNote(note)
    if delta ~= nil and delta ~= 1 and delta ~= -1 then return nil, "Invalid rating." end
    if not delta and not note then return nil, "No note to save." end
    local record, err = self:Ensure(identity)
    if not record then return nil, err end
    local entry = {
        id = self.db.nextEntry, delta = delta, note = note,
        context = Model.Copy(context or {}), createdAt = now,
    }
    self.db.nextEntry = self.db.nextEntry + 1
    record.entries[#record.entries + 1] = entry
    return entry
end

function Model:Entry(identity, entryID)
    local record = self:Get(identity)
    for index, entry in ipairs(record and record.entries or {}) do
        if entry.id == entryID then return entry, index end
    end
end

function Model:Edit(identity, entryID, note, now)
    local entry = self:Entry(identity, entryID)
    if not entry then return false, "This entry no longer exists." end
    note = CleanNote(note)
    if not entry.delta and not note then return false, "Use Delete to remove an empty note-only entry." end
    entry.note, entry.editedAt = note, now
    return true
end

function Model:Delete(identity, entryID)
    local record = self:Get(identity)
    if not record then return false end
    for index, entry in ipairs(record.entries) do
        if entry.id == entryID then
            table.remove(record.entries, index)
            if not Model.Remembered(record) then self.db.characters[record.key] = nil end
            return true
        end
    end
    return false
end

function Model:SetAlly(identity, value)
    local record, err = self:Ensure(identity)
    if not record then return false, err end
    record.ally = value == true
    if not Model.Remembered(record) then self.db.characters[record.key] = nil end
    return true
end

function Model:Forget(identity)
    local record, err = self:Get(identity)
    if err then
        return false, "Character identity changed. Open the original record in Remembered to forget it."
    end
    if record then self.db.characters[record.key] = nil end
    for i = #self.recent, 1, -1 do
        if Model.SameIdentity(self.recent[i].identity, identity) then table.remove(self.recent, i) end
    end
    return true
end

function Model:Prune(now)
    for i = #self.recent, 1, -1 do
        if now - self.recent[i].context.lastSeen >= 1800 then table.remove(self.recent, i) end
    end
    while #self.recent > 200 do table.remove(self.recent, 1) end
end

local contextFields = { "reason", "zone", "subzone", "instance", "instanceType", "group", "sharedGroup", "roster" }
local function SameContext(a, b)
    for _, key in ipairs(contextFields) do if a[key] ~= b[key] then return false end end
    return true
end

function Model:Observe(identity, context, now)
    self:Prune(now)
    local record = self:Get(identity)
    if record then ReconcileIdentity(record, identity) end
    local bucket = math.floor(now / 300)
    for _, row in ipairs(self.recent) do
        if Model.SameIdentity(row.identity, identity)
            and row.bucket == bucket and SameContext(row.context, context) then
            row.context.lastSeen = now
            ReconcileIdentity(row.identity, identity)
            return row
        end
    end
    local snapshot = Model.Copy(context)
    snapshot.firstSeen, snapshot.lastSeen = now, now
    local row = { id = self.nextRecent, identity = Model.Copy(identity), context = snapshot, bucket = bucket }
    self.nextRecent = self.nextRecent + 1
    self.recent[#self.recent + 1] = row
    self:Prune(now)
    return row
end

function Model:List(query, alliesOnly)
    query = (query or ""):lower()
    local result = {}
    for _, record in pairs(self.db.characters) do
        if Model.Remembered(record) and (not alliesOnly or record.ally)
            and (record.name .. "-" .. record.realm):lower():find(query, 1, true) then
            result[#result + 1] = record
        end
    end
    table.sort(result, function(a, b)
        local an, bn = (a.name .. "-" .. a.realm):lower(), (b.name .. "-" .. b.realm):lower()
        if an == bn then return a.key < b.key end
        return an < bn
    end)
    return result
end

function Model.Latest(record)
    local entries = record and record.entries or {}
    for i = #entries, 1, -1 do if entries[i].note then return entries[i] end end
    return entries[#entries]
end

function Model.ContextText(context)
    context = context or {}
    local parts = { context.zone or "Location unknown" }
    if context.subzone and context.subzone ~= context.zone then parts[#parts + 1] = context.subzone end
    if context.instance then parts[#parts + 1] = context.instance end
    if context.instanceType then parts[#parts + 1] = context.instanceType end
    parts[#parts + 1] = context.group or "Group unknown"
    if context.sharedGroup == true then parts[#parts + 1] = "Together in group"
    elseif context.sharedGroup == false then parts[#parts + 1] = "Not in same group" end
    if context.reason then parts[#parts + 1] = context.reason end
    return table.concat(parts, " / ")
end
