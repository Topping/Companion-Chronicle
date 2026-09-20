local ns = _G.CompanionChronicle
if type(ns) ~= "table" or type(ns.RP) ~= "table" then return end
local RP = {}

local function CharacterID(identity)
    if type(identity) ~= "table" or not ns.Public(identity)
        or not ns.Public(identity.name) or not ns.Public(identity.realm)
        or not ns.Public(identity.guid) or not ns.Public(identity.key)
        or type(identity.name) ~= "string" or type(identity.realm) ~= "string"
        or identity.name == "" or identity.realm == "" or identity.name:find("-", 1, true)
        or identity.name:find("%s") then return nil end
    local canonical = ns.Model.Identity(identity.name, identity.realm, identity.guid)
    if not canonical or canonical.key ~= identity.key or canonical.realm ~= identity.realm then return nil end
    return identity.name .. "-" .. identity.realm
end
RP.CharacterID = CharacterID

function RP.IdentityFromCharacterID(characterID)
    if not ns.Public(characterID) or type(characterID) ~= "string" then return nil end
    local name, realm = characterID:match("^([^-]+)%-(.+)$")
    if not name or name:find("%s") or realm:find("%s") then return nil end
    local identity = ns.Client.MenuName(name, realm)
    if identity and CharacterID(identity) == characterID then return identity end
end

local function Scalar(player, method)
    local found, getter = pcall(function() return player[method] end)
    if not found or type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, player)
    if ok and ns.Public(value) and (type(value) == "number"
        or (type(value) == "string" and value ~= "")) then return value end
end

local function TextField(player, method)
    local value = Scalar(player, method)
    if type(value) == "string" then return value end
end

function RP.Current(identity)
    local characterID = CharacterID(identity)
    local api, addon = _G.TRP3_API, _G.AddOn_TotalRP3
    local playerClass = type(addon) == "table" and addon.Player
    local factory = type(playerClass) == "table" and playerClass.static
    if not characterID or type(factory) ~= "table" or type(factory.CreateFromCharacterID) ~= "function"
        or not api or type(api) ~= "table" then return nil end
    local ok, player = pcall(factory.CreateFromCharacterID, characterID)
    if not ok or type(player) ~= "table" then return nil end
    local profileID = TextField(player, "GetProfileID")
    if not profileID then return nil end
    -- A known register ID can precede the profile payload. Avoid displaying
    -- TRP's fallback game name as though it were an RP persona.
    local found, getProfile = pcall(function() return player.GetProfile end)
    if not found or type(getProfile) ~= "function" then return nil end
    local profileOK, profile = pcall(getProfile, player)
    if not profileOK or not profile or not ns.Public(profile) then return nil end
    return {
        provider = "TotalRP3", profileID = profileID,
        displayName = TextField(player, "GetRoleplayingName"),
        pronouns = TextField(player, "GetCustomPronouns"),
        roleplayStatus = Scalar(player, "GetRoleplayStatus"),
        walkup = Scalar(player, "GetWalkup"),
        currently = TextField(player, "GetCurrentlyText"),
    }
end

local subscribed, installedAPI = {}, nil
function RP.Install()
    local api, addon = _G.TRP3_API, _G.TRP3_Addon
    if type(api) ~= "table" or type(api.RegisterCallback) ~= "function"
        or type(addon) ~= "table" or type(addon.Events) ~= "table" then return end
    if api ~= installedAPI then subscribed, installedAPI = {}, api end
    local events = addon.Events
    local function Subscribe(key, event, callback)
        if event and not subscribed[key] then
            local ok, err = pcall(api.RegisterCallback, addon, event, callback)
            if ok then subscribed[key] = true end
            if not ok then print("Companion Chronicle: TRP3 callback registration failed: " .. tostring(err)) end
        end
    end
    if events.REGISTER_DATA_UPDATED then
        Subscribe("data", events.REGISTER_DATA_UPDATED, function(_, characterID)
            ns.RP.ProfileUpdated(RP.IdentityFromCharacterID(characterID))
        end)
    end
    if events.WORKFLOW_ON_LOADED then
        Subscribe("workflow", events.WORKFLOW_ON_LOADED, function()
            local target = api.target
            local model = _G.AddOn_TotalRP3
            local enums = type(model) == "table" and model.Enums
            local unitTypes = type(enums) == "table" and enums.UNIT_TYPE
            local characterType = type(unitTypes) == "table" and unitTypes.CHARACTER
            if type(target) ~= "table" or type(target.registerButton) ~= "function" or not characterType then return end
            local globals = type(api.globals) == "table" and api.globals
            local playerID = globals and globals.player_id
            if not ns.Public(playerID) or type(playerID) ~= "string" or playerID == "" then return end
            local ok, err = pcall(target.registerButton, {
                id = "companion_chronicle", configText = "Companion Chronicle",
                tooltip = "Open Companion Chronicle", iconFile = "Interface\\AddOns\\CompanionChronicle\\Art\\journal-icon.tga",
                onlyForType = characterType,
                condition = function(_, characterID)
                    local identity = RP.IdentityFromCharacterID(characterID)
                    return identity ~= nil and characterID ~= playerID
                end,
                onClick = function(characterID)
                    local identity = RP.IdentityFromCharacterID(characterID)
                    if not identity or characterID == playerID or not ns.store then return end
                    ns.RP.OpenTarget(identity)
                end,
            })
            if not ok then print("Companion Chronicle: TRP3 target action registration failed: " .. tostring(err)) end
        end)
    end
end

ns.RP.RegisterProvider(RP)
