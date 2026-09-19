local _, ns = ...
local M = ns.Model
local Recognition = { plates = {} }
ns.Recognition = Recognition

local textures = {
    ["+"] = "Interface\\AddOns\\CompanionChronicle\\Art\\positive.tga",
    ["*"] = "Interface\\AddOns\\CompanionChronicle\\Art\\ally.tga",
}

local function CreateMarker(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local font = label:GetFont()
    if font then label:SetFont(font, 22, "OUTLINE") end
    label:SetSize(24, 24)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    label:Hide(); icon:Hide()
    return label, icon
end

local function RenderMarker(label, icon, symbol, r, g, b)
    label:Hide(); icon:Hide()
    if not symbol then return end
    local path = textures[symbol]
    if path and icon:SetTexture(path) then
        icon:Show()
    else
        label:SetText(symbol)
        label:SetTextColor(r, g, b)
        label:Show()
    end
end

function Recognition:Clear(plate)
    if plate and not plate:IsForbidden() and plate.alliesBadge then
        plate.alliesBadge:Hide()
        if plate.alliesIcon then plate.alliesIcon:Hide() end
    end
end

function Recognition:Remove(unit)
    if not ns.Text(unit) then return end
    self:Clear(self.plates[unit])
    self.plates[unit] = nil
end

function Recognition:RenderPlate(unit)
    if not ns.Text(unit) or not ns.store then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then self:Remove(unit); return end
    if self.plates[unit] and self.plates[unit] ~= plate then self:Clear(self.plates[unit]) end
    for oldUnit, oldPlate in pairs(self.plates) do
        if oldUnit ~= unit and oldPlate == plate then self.plates[oldUnit] = nil end
    end
    self.plates[unit] = plate
    self:Clear(plate)
    if ns.Read(UnitIsFriend, "player", unit) ~= true then return end
    local identity = ns.UnitIdentity(unit)
    local symbol, r, g, b = M.Badge(identity and ns.store:Get(identity))
    if not symbol then return end
    if not plate.alliesBadge then
        local label, icon = CreateMarker(plate)
        label:SetPoint("RIGHT", plate, "LEFT", -5, 0)
        icon:SetPoint("RIGHT", plate, "LEFT", -5, 0)
        plate.alliesBadge, plate.alliesIcon = label, icon
    end
    RenderMarker(plate.alliesBadge, plate.alliesIcon, symbol, r, g, b)
end

function Recognition:CreateTarget()
    if self.target or not TargetFrame or TargetFrame:IsForbidden() then return end
    if ns.Read(InCombatLockdown) then return end
    local target = CreateFrame("Frame", nil, UIParent)
    target:SetSize(24, 24)
    target:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -4, -4)
    target:EnableMouse(false)
    local label, icon = CreateMarker(target)
    label:SetAllPoints(target)
    icon:SetAllPoints(target)
    self.target, self.targetLabel, self.targetIcon = target, label, icon
    target:Hide()
end

function Recognition:RenderTarget()
    self:CreateTarget()
    if not self.target then return end
    self.target:Hide()
    if not ns.store or not TargetFrame or TargetFrame:IsForbidden() or not TargetFrame:IsShown() then return end
    local identity = ns.UnitIdentity("target")
    local symbol, r, g, b = M.Badge(identity and ns.store:Get(identity))
    if symbol then
        RenderMarker(self.targetLabel, self.targetIcon, symbol, r, g, b)
        self.target:Show()
    end
end

function Recognition:AddTooltip(tooltip)
    if not ns.store or tooltip:IsForbidden() then return end
    local _, unit = tooltip:GetUnit()
    local identity = ns.UnitIdentity(unit)
    local record = identity and ns.store:Get(identity)
    if not M.Remembered(record) then return end
    tooltip:AddLine(string.format("Companion Chronicle: %sPersonal rep %+d", record.ally and "Ally / " or "", M.Score(record)), 0.75, 0.85, 1, true)
    local entry = M.Latest(record)
    if entry then
        if entry.note then tooltip:AddLine(ns.Escape(entry.note), 1, 1, 1, true) end
        tooltip:AddLine(ns.Escape(M.ContextText(entry.context)), 0.7, 0.7, 0.7, true)
        tooltip:AddLine("Encounter: " .. ns.When(entry.context.firstSeen), 0.7, 0.7, 0.7, true)
    end
end

function Recognition:Refresh()
    self:RenderTarget()
    for unit in pairs(self.plates) do self:RenderPlate(unit) end
end

function Recognition:Discover()
    -- Reloads may happen while plates are already visible. This is display
    -- discovery only; it does not populate the Recent encounter buffer.
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if not plate:IsForbidden() and ns.Text(plate.unitToken) then
            self:RenderPlate(plate.unitToken)
        end
    end
end

function Recognition:Install()
    if self.installed then return end
    self.installed = true
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip) self:AddTooltip(tooltip) end)
    end
    self:CreateTarget()
end
