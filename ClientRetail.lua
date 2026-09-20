local _, ns = ...
local client = { flavor = "retail", partition = "retail:1", minimapIconSize = 20 }
ns.Client = client

function client.UnitName(name, realm, guid, unit)
    if not name or name == UNKNOWN then return nil end
    if (realm == nil or realm == "") and type(LE_REALM_RELATION_SAME) == "number"
        and ns.Read(UnitRealmRelationship, unit) == LE_REALM_RELATION_SAME then
        realm = ns.Text(ns.Read(GetNormalizedRealmName))
    end
    if not realm or realm == "" then return nil end
    return ns.Model.Identity(name, realm, guid)
end

function client.MenuName(name, realm, guid)
    if not name or name == UNKNOWN then return nil end
    local splitName, splitRealm = name:match("^([^-]+)%-(.+)$")
    if splitName then
        if realm and realm:gsub("%s", "") ~= splitRealm:gsub("%s", "") then return nil end
        name, realm = splitName, splitRealm
    end
    return ns.Model.Identity(name, realm, guid)
end

function client.RegisterMenus(callback)
    if not Menu or type(Menu.ModifyMenu) ~= "function" then return false end
    for _, tag in ipairs({ "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND" }) do
        Menu.ModifyMenu("MENU_UNIT_" .. tag, callback)
    end
    return true
end
