local _, ns = ...

local iconPath = "Interface\\AddOns\\CompanionChronicle\\Art\\journal-icon"
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local function CanUpdateTooltip()
    if not GameTooltip or not ns.CanCallProtected(GameTooltip) then return false end
    return ns.Read(InCombatLockdown) == false
        or ns.Read(GameTooltip.CanChangeProtectedState, GameTooltip) == true
end

local function Place(button, angle)
    if ns.Read(InCombatLockdown) ~= false
        or not ns.CanCallProtected(button) or not ns.CanCallProtected(Minimap) then return false end
    local width = ns.Read(Minimap.GetWidth, Minimap)
    if type(width) ~= "number" or width <= 0 then return false end
    local radians = math.rad(angle)
    local radius = width / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
    return true
end

function MinimapButton:SetAngle(angle)
    angle = angle % 360
    ns.store.saved.settings.minimapAngle = angle
    self.pendingAngle = not self.frame or not Place(self.frame, angle)
end

function MinimapButton:UpdateDrag()
    if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(Minimap) then return end
    local cursorOk, x, y = pcall(GetCursorPosition)
    local scale = ns.Read(Minimap.GetEffectiveScale, Minimap)
    local centerOk, centerX, centerY = pcall(Minimap.GetCenter, Minimap)
    if not cursorOk or not centerOk or not ns.Public(x) or not ns.Public(y)
        or not ns.Public(centerX) or not ns.Public(centerY)
        or type(x) ~= "number" or type(y) ~= "number"
        or type(centerX) ~= "number" or type(centerY) ~= "number"
        or type(scale) ~= "number" or scale == 0 then return end
    self:SetAngle(math.deg(math.atan2(y / scale - centerY, x / scale - centerX)))
end

function MinimapButton:Create()
    if self.frame then return end
    -- The button inherits Minimap as its parent, and positioning uses the
    -- protected SetPoint API. A combat reload can initialize it after regen.
    if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(Minimap) then return end
    local frameLevel = ns.Read(Minimap.GetFrameLevel, Minimap)
    if type(frameLevel) ~= "number" then return end
    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(32, 32)
    button:SetFrameLevel(frameLevel + 5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    local iconSize = ns.Client.minimapIconSize or 32
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", button, "CENTER")
    icon:SetTexture(iconPath)
    button.icon = icon

    button:SetScript("OnMouseDown", function(self)
        self.wasDragged = false
    end)
    button:SetScript("OnClick", function(self)
        if not self.wasDragged then ns.Controller:ToggleWindow() end
    end)
    button:SetScript("OnDragStart", function(self)
        if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(self) then return end
        self.wasDragged = true
        self:SetScript("OnUpdate", function() MinimapButton:UpdateDrag() end)
        MinimapButton:UpdateDrag()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        MinimapButton:UpdateDrag()
    end)
    button:SetScript("OnEnter", function(self)
        if not CanUpdateTooltip() then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Companion Chronicle")
        GameTooltip:AddLine("Click to open the journal. Drag to move around the minimap.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if CanUpdateTooltip() then GameTooltip:Hide() end
    end)

    self.frame = button
    self.pendingAngle = not Place(button, ns.store.saved.settings.minimapAngle)
end

function MinimapButton:Resume()
    if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(Minimap) then return end
    if not self.frame then self:Create()
    elseif self.pendingAngle then self.pendingAngle = not Place(self.frame, ns.store.saved.settings.minimapAngle) end
end
