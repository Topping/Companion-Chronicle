local _, ns = ...

local iconPath = "Interface\\AddOns\\CompanionChronicle\\Art\\journal-icon"
local objectName = "CompanionChronicle"
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local function CanUpdateTooltip()
    if not GameTooltip or not ns.CanCallProtected(GameTooltip) then return false end
    return ns.Read(InCombatLockdown) == false
        or ns.Read(GameTooltip.CanChangeProtectedState, GameTooltip) == true
end

local function Toggle(_, mouseButton)
    if mouseButton == nil or mouseButton == "LeftButton" then ns.Controller:ToggleWindow() end
end

local function ShowTooltip(frame)
    if not CanUpdateTooltip() then return end
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine("Companion Chronicle")
    GameTooltip:AddLine("Click to open the journal. Drag to move around the minimap.", 1, 1, 1)
    GameTooltip:Show()
end

local function HideTooltip()
    if CanUpdateTooltip() then GameTooltip:Hide() end
end

local function CanPlace(button)
    return ns.Read(InCombatLockdown) == false
        and ns.CanCallProtected(button) and ns.CanCallProtected(Minimap)
end

local function Place(button, angle)
    if not button or not CanPlace(button) then return false end
    local ok = pcall(MinimapButton.iconLibrary.SetButtonToPosition,
        MinimapButton.iconLibrary, button, angle)
    return ok
end

function MinimapButton:SetAngle(angle)
    angle = angle % 360
    local settings = ns.store.saved.settings
    settings.minimapAngle = angle
    if self.iconSettings then self.iconSettings.minimapPos = angle end
    self.pendingAngle = not Place(self.frame, angle)
end

function MinimapButton:Create()
    if self.frame then return end
    if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(Minimap) then return end

    local broker = LibStub:GetLibrary("LibDataBroker-1.1")
    local iconLibrary = LibStub:GetLibrary("LibDBIcon-1.0")
    local dataObject = broker:GetDataObjectByName(objectName)
    if not dataObject then
        dataObject = broker:NewDataObject(objectName, {
            type = "launcher",
            text = "Companion Chronicle",
            label = "Companion Chronicle",
            icon = iconPath,
            OnClick = Toggle,
            OnEnter = ShowTooltip,
            OnLeave = HideTooltip,
        })
    end

    self.iconSettings = self.iconSettings or { minimapPos = ns.store.saved.settings.minimapAngle }
    if not iconLibrary:IsRegistered(objectName) then
        iconLibrary:Register(objectName, dataObject, self.iconSettings)
    end

    local button = iconLibrary:GetMinimapButton(objectName)
    button:HookScript("OnDragStop", function(self)
        local angle = self.db and self.db.minimapPos
        if type(angle) == "number" then ns.store.saved.settings.minimapAngle = angle end
    end)

    self.dataObject = dataObject
    self.iconLibrary = iconLibrary
    self.frame = button
    self.pendingAngle = not Place(button, ns.store.saved.settings.minimapAngle)
end

function MinimapButton:Resume()
    if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(Minimap) then return end
    if not self.frame then
        self:Create()
    elseif self.pendingAngle then
        self.pendingAngle = not Place(self.frame, ns.store.saved.settings.minimapAngle)
    end
end

_G.CompanionChronicle_OnAddonCompartmentClick = function(_, mouseButton)
    Toggle(nil, mouseButton)
end
