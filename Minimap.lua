local _, ns = ...

local iconPath = "Interface\\AddOns\\CompanionChronicle\\Art\\journal-icon"
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local function Place(button, angle)
    local radians = math.rad(angle)
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function MinimapButton:SetAngle(angle)
    angle = angle % 360
    ns.store.saved.settings.minimapAngle = angle
    Place(self.frame, angle)
end

function MinimapButton:UpdateDrag()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY or not scale or scale == 0 then return end
    self:SetAngle(math.deg(math.atan2(y / scale - centerY, x / scale - centerX)))
end

function MinimapButton:Create()
    if self.frame then return end
    local button = CreateFrame("Button", "CompanionChronicleMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconPath)
    button.icon = icon

    button:SetScript("OnMouseDown", function(self)
        self.wasDragged = false
    end)
    button:SetScript("OnClick", function(self)
        if not self.wasDragged then ns.Controller:ToggleWindow() end
    end)
    button:SetScript("OnDragStart", function(self)
        self.wasDragged = true
        self:SetScript("OnUpdate", function() MinimapButton:UpdateDrag() end)
        MinimapButton:UpdateDrag()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        MinimapButton:UpdateDrag()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Companion Chronicle")
        GameTooltip:AddLine("Click to open the journal. Drag to move around the minimap.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.frame = button
    Place(button, ns.store.saved.settings.minimapAngle)
end
