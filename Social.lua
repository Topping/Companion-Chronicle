local _, ns = ...
local M = ns.Model
local Social = { members = {} }
ns.Social = Social

local chatEvents = {
    CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true,
    CHAT_MSG_TEXT_EMOTE = true, CHAT_MSG_WHISPER = true, CHAT_MSG_CHANNEL = true,
    CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true, CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true, CHAT_MSG_INSTANCE_CHAT = true,
    CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}

function Social.ChatMarker(event, sender, guid)
    if not ns.store or not ns.store.saved.settings.chatMarkers then return end
    if not ns.Public(event) or not chatEvents[event] then return end
    sender, guid = ns.Text(sender), ns.Text(guid)
    if not sender or not guid then return end
    -- Require the event GUID; never resolve a chat author by bare name.
    -- A chat sender may include a realm while an older saved record has no
    -- GUID. Preserve that exact realm for the keyed lookup; GUID-only names
    -- still resolve through the GUID without guessing a realm.
    local identity = ns.Client.MenuName(sender, nil, guid)
    local symbol = M.Badge(identity and ns.store:Get(identity))
    if symbol == "*" then return "|TInterface\\AddOns\\CompanionChronicle\\Art\\ally.tga:16:16|t" end
    if symbol == "+" then return "|TInterface\\AddOns\\CompanionChronicle\\Art\\positive.tga:16:16|t" end
    if symbol == "-" then return "|cffff8080[-]|r" end
    if symbol == "=" then return "|cffbfcce6[=]|r" end
end

function Social.SenderFilter(event, decoratedName, ...)
    if not ns.Text(decoratedName) then return end
    local marker = Social.ChatMarker(event, select(2, ...), select(12, ...))
    if marker then return marker .. " " .. decoratedName end
end

function Social.MessageFilter(_, event, message, sender, ...)
    if not ns.Text(message) then return end
    local marker = Social.ChatMarker(event, sender, select(10, ...))
    -- Preserve author, line ID and every trailing argument, including nils.
    if marker then return false, marker .. " " .. message, sender, ... end
end

function Social:Install()
    if self.chatInstalled then return end
    if ChatFrameUtil and type(ChatFrameUtil.AddSenderNameFilter) == "function" then
        ChatFrameUtil.AddSenderNameFilter(self.SenderFilter)
        self.chatInstalled = "sender"
        return
    end
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(addFilter) ~= "function" then return end
    for event in pairs(chatEvents) do addFilter(event, self.MessageFilter) end
    self.chatInstalled = "message"
end

local function Impression(record)
    if not record then return end
    if record.ally then return "Ally" end
    local rated = false
    for _, entry in ipairs(record.entries) do if entry.delta then rated = true; break end end
    if not rated then return end
    local score = M.Score(record)
    return score > 0 and "Friendly" or (score < 0 and "Unfriendly" or "Mixed impressions")
end

local function ShortNote(note)
    local words, length = {}, 0
    for word in note:gmatch("%S+") do
        length = length + #word + 1
        if length > 120 then words[#words + 1] = "…"; break end
        words[#words + 1] = word
    end
    return table.concat(words, " ")
end

function Social:CheckGroup(units, group, complete)
    if group == "Solo" and complete then self.members = {}; return end
    local current, reminders, count = {}, {}, 0
    local previous = M.IdentityIndex(self.members)
    for _, entry in ipairs(units) do
        local identity = entry.identity
        current[#current + 1] = M.IdentityFields(identity)
        if not M.FindIdentity(previous, identity) and ns.store.saved.settings.groupReminders then
            local record = ns.store:Get(identity)
            local impression = Impression(record)
            if impression then
                count = count + 1
                if count <= 3 then
                    local text = ns.DisplayName(identity) .. " (" .. impression .. ")"
                    local latest = M.Latest(record)
                    if latest and latest.note then text = text .. ": " .. ns.Escape(ShortNote(latest.note)) end
                    reminders[#reminders + 1] = text
                end
            end
        end
    end
    -- Missing/restricted units are not evidence that someone left the group.
    if complete then
        self.members = current
    else
        for _, identity in ipairs(current) do
            local known = M.FindIdentity(previous, identity)
            if known then
                if identity.guid and not known.guid then
                    known.guid = identity.guid
                    previous.byGUID[identity.guid] = known
                end
            else
                self.members[#self.members + 1] = identity
                M.IndexIdentity(previous, identity)
            end
        end
    end
    if count > 3 then reminders[#reminders + 1] = (count - 3) .. " more remembered players" end
    if count > 0 then print("Companion Chronicle — In your group: " .. table.concat(reminders, "; ")) end
end
