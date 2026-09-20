local _, ns = ...
local RP = {}
ns.RP = RP

function RP.RegisterProvider(provider)
    if RP.provider or type(provider) ~= "table"
        or type(provider.Current) ~= "function" or type(provider.Install) ~= "function" then return false end
    RP.provider = provider
    if ns.store then RP.Install() end
    return true
end

function RP.Install()
    if RP.provider then RP.provider.Install() end
end

function RP.Current(identity)
    if RP.provider then return RP.provider.Current(identity) end
end

function RP.Snapshot(identity)
    local current = RP.Current(identity)
    if not current or not current.profileID and not current.displayName then return nil end
    return { provider = current.provider, profileID = current.profileID,
        displayName = current.displayName }
end

function RP.ProfileUpdated(identity)
    local controller = ns.Controller
    if controller.visible and controller.selection
        and ns.Model.SameIdentity(controller.selection.identity, identity) then controller:Refresh() end
end

function RP.OpenTarget(identity)
    if not ns.store then return end
    local observation = ns.Observe(identity, "Opened RP target")
    if observation then ns.Controller:ShowPlayer(identity, ns.Model.Copy(observation.context)) end
end
