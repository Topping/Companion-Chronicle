local _, ns = ...

function ns.Public(value)
    return not (issecretvalue and issecretvalue(value))
end

-- Restricted APIs may return secrets or reject a unit token altogether.
-- Only the first, demonstrably public result is exposed by this helper.
function ns.Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and ns.Public(value) then return value end
end

function ns.Text(value)
    if ns.Public(value) and type(value) == "string" and value ~= "" then return value end
end

function ns.UnitIdentity(unit)
    if not ns.Text(unit) then return nil end
    if ns.Read(UnitIsPlayer, unit) ~= true then return nil end
    if ns.Read(UnitIsUnit, unit, "player") ~= false then return nil end
    local ok, name, realm = pcall(UnitFullName, unit)
    if not ok then return nil end
    name = ns.Text(name)
    if not ns.Public(realm) then return nil end
    realm = type(realm) == "string" and realm or nil
    local guid = ns.Text(ns.Read(UnitGUID, unit))
    return ns.Client.UnitName(name, realm, guid, unit)
end

function ns.MenuIdentity(data)
    if not data or not ns.Public(data) then return nil end
    if not ns.Public(data.unit) then return nil end
    if data.unit ~= nil then return ns.UnitIdentity(data.unit) end
    if not ns.Public(data.name) or not ns.Public(data.server) or not ns.Public(data.guid) then return nil end
    local name, realm = ns.Text(data.name), ns.Text(data.server)
    if not name or name == UNKNOWN then return nil end
    local guid = ns.Text(data.guid)
    -- The native chat menu passes a line ID, not a GUID. Resolve that line
    -- without recording chat content or subscribing to a chat stream.
    if data.lineID ~= nil then
        if not C_ChatInfo or not ns.Public(data.lineID) then return nil end
        local lineID = tonumber(data.lineID)
        if lineID then
            local senderGUID = ns.Text(ns.Read(C_ChatInfo.GetChatLineSenderGUID, lineID))
            if guid and senderGUID and guid ~= senderGUID then return nil end
            guid = guid or senderGUID
            local sender = ns.Text(ns.Read(C_ChatInfo.GetChatLineSenderName, lineID))
            -- A line ID without a public sender and GUID cannot establish the
            -- identity of the original chat author.
            if not sender or not senderGUID then return nil end
            local menuIdentity = ns.Client.MenuName(name, realm, guid)
            local lineIdentity = ns.Client.MenuName(sender, nil, senderGUID)
            if not menuIdentity or not lineIdentity or not ns.Model.SameIdentity(menuIdentity, lineIdentity)
                or menuIdentity.name ~= lineIdentity.name
                or (menuIdentity.realm ~= "" and lineIdentity.realm ~= "" and menuIdentity.realm ~= lineIdentity.realm) then return nil end
            name, realm = lineIdentity.name, lineIdentity.realm
        else return nil end
    end
    local identity = ns.Client.MenuName(name, realm, guid)
    if not identity then return nil end
    local ok, selfName, selfRealm = pcall(UnitFullName, "player")
    if not ok then return nil end
    local selfGUID = ns.Text(ns.Read(UnitGUID, "player"))
    if not ns.Public(selfRealm) then return nil end
    local selfIdentity = ns.Client.UnitName(ns.Text(selfName), type(selfRealm) == "string" and selfRealm or nil, selfGUID, "player")
    if not selfIdentity or ns.Model.SameIdentity(selfIdentity, identity) then return nil end
    if identity.realm == "" and not selfGUID then return nil end
    return identity
end

-- Opt-in, one-menu probe for client differences. Never reads chat message text
-- or persists output. Secrets are checked before formatting or comparing.
function ns.DebugMenu(data, identity)
    if not ns.debugNextMenu then return end
    ns.debugNextMenu = nil
    local function describe(value)
        if not ns.Public(value) then return "<restricted>" end
        if value == nil then return "<nil>" end
        if type(value) == "string" then return '"' .. ns.Escape(value) .. '"' end
        if type(value) == "number" then return tostring(value) end
        return "<" .. type(value) .. ">"
    end
    if not ns.Public(data) or type(data) ~= "table" then
        print("Companion Chronicle menu: unavailable context")
        return
    end
    print("Companion Chronicle menu: name=" .. describe(data.name) .. " server=" .. describe(data.server)
        .. " unit=" .. describe(data.unit) .. " line=" .. describe(data.lineID)
        .. " resolved=" .. (identity and "yes" or "no")
        .. " name=" .. describe(identity and identity.name)
        .. " realm=" .. describe(identity and identity.realm))
    local lineID = ns.Public(data.lineID) and tonumber(data.lineID)
    local sender, guid
    if lineID and C_ChatInfo then
        sender = ns.Read(C_ChatInfo.GetChatLineSenderName, lineID)
        guid = ns.Text(ns.Read(C_ChatInfo.GetChatLineSenderGUID, lineID))
    end
    guid = ns.Text(data.guid) or guid
    local record = identity and ns.store and ns.store:Get(identity)
    print("Companion Chronicle lookup: sender=" .. describe(sender) .. " guid=" .. (guid and "present" or "missing")
        .. " stored name=" .. describe(record and record.name)
        .. " realm=" .. describe(record and record.realm))
    if ns.Public(data.unit) and type(data.unit) == "string" then
        local function probe(fn, ...)
            if type(fn) ~= "function" then return "<unavailable>", "<unavailable>" end
            local ok, first, second = pcall(fn, ...)
            if not ok then return "<error>", "<error>" end
            return describe(first), describe(second)
        end
        local function guidState(unit)
            local ok, value = pcall(UnitGUID, unit)
            if not ok then return "error" end
            if not ns.Public(value) then return "restricted" end
            return ns.Text(value) and "present" or "missing"
        end
        local unit = data.unit
        local name, server = probe(UnitFullName, unit)
        print("Companion Chronicle unit: player=" .. probe(UnitIsPlayer, unit)
            .. " self=" .. probe(UnitIsUnit, unit, "player")
            .. " name=" .. name .. " server=" .. server
            .. " relation=" .. probe(UnitRealmRelationship, unit)
            .. " guid=" .. guidState(unit))
        local selfName, selfServer = probe(UnitFullName, "player")
        print("Companion Chronicle self: name=" .. selfName .. " server=" .. selfServer
            .. " localRealm=" .. probe(GetNormalizedRealmName)
            .. " guid=" .. guidState("player"))
    end
end

function ns.GroupSnapshot()
    local units, identities, keys = {}, ns.Model.IdentityIndex({}), {}
    local raid = ns.Read(IsInRaid)
    local grouped = ns.Read(IsInGroup)
    local group = grouped == false and "Solo" or nil
    if grouped == true and type(raid) == "boolean" then group = raid and "Raid" or "Party" end
    local count = ns.Read(GetNumGroupMembers)
    local complete = grouped == false
    if grouped == true and type(count) == "number" and type(raid) == "boolean" then
        complete = true
        for i = 1, (raid and count or count - 1) do
            local unit = (raid and "raid" or "party") .. i
            if ns.Read(UnitIsUnit, unit, "player") ~= true then
                local identity = ns.UnitIdentity(unit)
                if identity then
                    units[#units + 1] = { unit = unit, identity = identity }
                    ns.Model.IndexIdentity(identities, identity)
                    keys[#keys + 1] = identity.key
                else complete = false end
            end
        end
    end
    table.sort(keys)
    local signature = (group or "unknown") .. ":" .. table.concat(keys, ",")
    if signature ~= ns.rosterSignature then
        ns.rosterSignature = signature
        ns.rosterVersion = (ns.rosterVersion or 0) + 1
    end
    return units, identities, group, complete, ns.rosterVersion
end

local function ContextBatch(members, group, complete, roster)
    local batch = {
        members = members, group = group, complete = complete, roster = roster,
        zone = ns.Text(ns.Read(GetZoneText)), subzone = ns.Text(ns.Read(GetSubZoneText)),
    }
    local ok, instanceName, instanceType = pcall(GetInstanceInfo)
    if ok then
        instanceType = ns.Text(instanceType)
        if instanceType and instanceType ~= "none" then
            batch.instance, batch.instanceType = ns.Text(instanceName), instanceType
        end
    end
    return batch
end

function ns.Context(identity, reason, batch)
    if not batch then
        local _, members, group, complete, roster = ns.GroupSnapshot()
        batch = ContextBatch(members, group, complete, roster)
    end
    local context = {
        reason = reason, zone = batch.zone, subzone = batch.subzone,
        group = batch.group, roster = batch.roster,
        instance = batch.instance, instanceType = batch.instanceType,
    }
    if ns.Model.FindIdentity(batch.members, identity) then context.sharedGroup = true
    elseif batch.complete then context.sharedGroup = false end
    return context
end

function ns.Now()
    return GetServerTime()
end

function ns.Observe(identity, reason)
    if not ns.store or not identity then return nil end
    return ns.store:Observe(identity, ns.Context(identity, reason), ns.Now())
end

function ns.ObserveGroup()
    if not ns.store then return end
    local units, members, group, complete, roster = ns.GroupSnapshot()
    if #units > 0 then
        local batch = ContextBatch(members, group, complete, roster)
        local now = ns.Now()
        for _, entry in ipairs(units) do
            ns.store:Observe(entry.identity, ns.Context(entry.identity, "Group member", batch), now)
        end
    end
    ns.Social:CheckGroup(units, group, complete)
end

function ns.Escape(text)
    -- Notes are plain text, never executable hyperlinks or texture markup.
    return (text or ""):gsub("|", "||")
end

function ns.DisplayName(identity)
    return ns.Escape(identity.name .. (identity.realm ~= "" and ("-" .. identity.realm) or ""))
end

function ns.When(timestamp)
    return timestamp and date("%d %b %H:%M", timestamp) or "Time unknown"
end
