local addonName, ns = ...
-- Shared with the optional companion addon and available for diagnostics.
_G.CompanionChronicle = ns

function ns.Changed()
    ns.Controller:Refresh()
    ns.Recognition:Refresh()
    -- Remove stale tooltip text after a rating/note is edited or forgotten.
    -- WoW rebuilds the tooltip normally on the next hover.
    if GameTooltip and not GameTooltip:IsForbidden() then
        local _, unit = GameTooltip:GetUnit()
        if ns.Text(unit) then GameTooltip:Hide() end
    end
end

function ns.BuildMenu(_, root, data)
    if not ns.store then return end
    local identity = ns.MenuIdentity(data)
    ns.DebugMenu(data, identity)
    if not identity then return end
    local observation = ns.Observe(identity, "Opened player menu")
    local snapshot = ns.Model.Copy(observation.context)
    root:CreateDivider()
    root:CreateTitle("Companion Chronicle")
    root:CreateButton("Friendly", function() ns.Controller:Rate(identity, 1, snapshot) end)
    root:CreateButton("Unfriendly", function() ns.Controller:Rate(identity, -1, snapshot) end)
    local last = ns.Controller.confirmation
    if last and ns.Model.SameIdentity(last.identity, identity) then
        root:CreateButton("Undo last", function() ns.Controller:UndoRating(last) end)
    end
    root:CreateButton("Add note...", function() ns.Controller:OpenEditor(identity, snapshot) end)
    root:CreateButton("View history...", function() ns.Controller:ShowPlayer(identity, snapshot) end)
end

function ns.InstallMenus()
    if not ns.menusInstalled then ns.menusInstalled = ns.Client.RegisterMenus(ns.BuildMenu) end
end

local function Initialize()
    if ns.store or ns.initError then return end
    -- Stable flavor partitions survive future client build and Interface updates.
    ns.partition = ns.Client.partition
    local store, err = ns.Model.Open(AlliesDB, ns.partition)
    if not store then ns.initError = err; print("Companion Chronicle: " .. err); return end
    ns.store, AlliesDB = store, store.saved
    if ns.RP then ns.RP.Install() end
    ns.Controller:Create()
    ns.MinimapButton:Create()
    ns.Recognition:Install()
    ns.Social:Install()
    ns.InstallMenus()
end

local events = CreateFrame("Frame")
ns.events = events
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_NAME_UPDATE", "PLAYER_REGEN_ENABLED",
    "UI_SCALE_CHANGED",
}) do events:RegisterEvent(event) end

events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == addonName then Initialize() end
        if ns.store then ns.InstallMenus(); ns.Social:Install(); if ns.RP then ns.RP.Install() end end
        return
    end
    if not ns.store then return end
    if event == "UI_SCALE_CHANGED" then ns.UI:RefreshJournalScale(); return end
    if event == "NAME_PLATE_UNIT_ADDED" then ns.Recognition:RenderPlate(arg)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then ns.Recognition:Remove(arg)
    elseif event == "PLAYER_TARGET_CHANGED" then ns.Recognition:RenderTarget()
    elseif event == "UNIT_NAME_UPDATE" then
        if ns.Public(arg) and type(arg) == "string" then
            if ns.Recognition.plates[arg] then ns.Recognition:RenderPlate(arg) end
        end
        ns.Recognition:RenderTarget()
        ns.ObserveGroup()
    elseif event == "PLAYER_REGEN_ENABLED" then ns.Recognition:Refresh()
    else
        ns.ObserveGroup()
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then ns.Recognition:Discover() end
        ns.Recognition:Refresh()
    end
    ns.Controller:Refresh(true)
end)

local elapsedTotal = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not ns.store then return end
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 15 then return end
    elapsedTotal = 0
    ns.store:Prune(ns.Now())
    ns.ObserveGroup()
    ns.Controller:Refresh(true)
end)

SLASH_COMPANIONCHRONICLE1 = "/companionchronicle"
SLASH_COMPANIONCHRONICLE2 = "/cchron"
SlashCmdList["COMPANIONCHRONICLE"] = function(message)
    if not ns.store then print("Companion Chronicle: " .. (ns.initError or "Not initialized.")); return end
    if message and message:match("^%s*debugmenu%s*$") then
        ns.debugNextMenu = true
        print("Companion Chronicle: right-click a player name now. The next supported player menu will print two diagnostic lines.")
        return
    end
    ns.Controller:ToggleWindow()
end
