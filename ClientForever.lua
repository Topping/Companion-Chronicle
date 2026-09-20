local _, ns = ...
local client = { flavor = "forever", partition = "forever:1" }
ns.Client = client

function client.UnitName(name, surname, guid)
    if not name or name == UNKNOWN or not surname then return nil end
    -- Live Forever unit probes returned first name and surname separately.
    -- A full name already supplied by the client retains a separate realm.
    if not name:find("%s") then
        if not guid then return nil end
        return ns.Model.Identity(name .. " " .. surname, nil, guid)
    end
    return ns.Model.Identity(name, surname, guid)
end

function client.MenuName(name, realm, guid)
    if not name or name == UNKNOWN then return nil end
    local splitName, splitRealm = name:match("^([^-]+)%-(.+)$")
    if splitName then
        if realm and realm:gsub("%s", "") ~= splitRealm:gsub("%s", "") then return nil end
        name, realm = splitName, splitRealm
    end
    -- A full Forever name without a realm is safe only with the original GUID.
    return ns.Model.Identity(name, realm, guid)
end

function client.RegisterMenus(callback)
    if not Menu or type(Menu.ModifyMenu) ~= "function" then return false end
    for _, tag in ipairs({ "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND" }) do
        Menu.ModifyMenu("MENU_UNIT_" .. tag, callback)
    end
    return true
end
