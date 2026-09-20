local _, ns = ...
local M = ns.Model
local Recognition = { plates = {}, deferredClear = {} }
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

local function BlankMarker(label, icon)
    -- Text/texture setters are not protected state changes. Clearing the
    -- artwork also avoids showing a recycled plate's old identity when Hide
    -- itself is unavailable until combat ends.
    label:SetText("")
    icon:SetTexture(nil)
end

local function CanUpdate(region)
    -- Instance restrictions can apply outside combat too. During combat,
    -- visibility also needs an explicit protected-state result.
    if not region or not ns.CanCallProtected(region) then return false end
    if ns.Read(InCombatLockdown) == false then return true end
    return ns.Read(region.CanChangeProtectedState, region) == true
end

function Recognition:Clear(plate)
    if not plate then return true end
    if ns.Read(plate.IsForbidden, plate) ~= false or not plate.alliesBadge then
        self.deferredClear[plate] = nil
        return true
    end
    if not CanUpdate(plate.alliesBadge)
        or (plate.alliesIcon and not CanUpdate(plate.alliesIcon)) then
        if plate.alliesIcon then BlankMarker(plate.alliesBadge, plate.alliesIcon)
        else plate.alliesBadge:SetText("") end
        self.deferredClear[plate] = true
        return false
    end
    plate.alliesBadge:Hide()
    if plate.alliesIcon then plate.alliesIcon:Hide() end
    self.deferredClear[plate] = nil
    return true
end

function Recognition:Remove(unit)
    if not ns.Text(unit) then return end
    self:Clear(self.plates[unit])
    self.plates[unit] = nil
end

function Recognition:RenderPlate(unit)
    if not ns.Text(unit) or not ns.store then return end
    local plate = ns.Read(C_NamePlate.GetNamePlateForUnit, unit)
    if not plate or ns.Read(plate.IsForbidden, plate) ~= false then self:Remove(unit); return end
    if self.plates[unit] and self.plates[unit] ~= plate then self:Clear(self.plates[unit]) end
    for oldUnit, oldPlate in pairs(self.plates) do
        if oldUnit ~= unit and oldPlate == plate then self.plates[oldUnit] = nil end
    end
    self.plates[unit] = plate
    if not self:Clear(plate) then return end
    if ns.Read(UnitIsFriend, "player", unit) ~= true then return end
    local identity = ns.UnitIdentity(unit)
    local symbol, r, g, b = M.Badge(identity and ns.store:Get(identity))
    if not symbol then return end
    if not plate.alliesBadge then
        -- A new child and its anchors are not established during lockdown.
        if ns.Read(InCombatLockdown) ~= false or not ns.CanCallProtected(plate) then return end
        local label, icon = CreateMarker(plate)
        label:SetPoint("RIGHT", plate, "LEFT", -5, 0)
        icon:SetPoint("RIGHT", plate, "LEFT", -5, 0)
        plate.alliesBadge, plate.alliesIcon = label, icon
    end
    if not CanUpdate(plate.alliesBadge) or not CanUpdate(plate.alliesIcon) then return end
    RenderMarker(plate.alliesBadge, plate.alliesIcon, symbol, r, g, b)
end

function Recognition:CreateTarget()
    if self.target or not TargetFrame or ns.Read(TargetFrame.IsForbidden, TargetFrame) ~= false then return end
    local bars = TargetFrame.TargetFrameContent
        and TargetFrame.TargetFrameContent.TargetFrameContentMain
        and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
    -- Forever's target frame layout is not established by Retail UI source.
    local anchor = bars or (ns.Client.flavor == "forever" and TargetFrame)
    if not anchor or ns.Read(InCombatLockdown) ~= false
        or not ns.CanCallProtected(TargetFrame) or not ns.CanCallProtected(anchor) then return end
    local target = CreateFrame("Frame", nil, UIParent)
    target:SetSize(24, 24)
    if bars then target:SetPoint("LEFT", bars, "RIGHT", 5, 0)
    else target:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -4, -4) end
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
    if not CanUpdate(self.target) then
        BlankMarker(self.targetLabel, self.targetIcon)
        return
    end
    self.target:Hide()
    if not ns.store or not TargetFrame
        or ns.Read(TargetFrame.IsForbidden, TargetFrame) ~= false
        or ns.Read(TargetFrame.IsShown, TargetFrame) ~= true then return end
    local identity = ns.UnitIdentity("target")
    local symbol, r, g, b = M.Badge(identity and ns.store:Get(identity))
    if symbol then
        RenderMarker(self.targetLabel, self.targetIcon, symbol, r, g, b)
        self.target:Show()
    end
end

function Recognition:AddTooltip(tooltip)
    if not ns.store or ns.Read(tooltip.IsForbidden, tooltip) ~= false then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok then return end
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
    for plate in pairs(self.deferredClear) do self:Clear(plate) end
    self:RenderTarget()
    for unit in pairs(self.plates) do self:RenderPlate(unit) end
end

function Recognition:Discover()
    -- Reloads may happen while plates are already visible. This is display
    -- discovery only; it does not populate the Recent encounter buffer.
    local plates = ns.Read(C_NamePlate.GetNamePlates)
    if type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        if ns.Public(plate) and ns.Read(plate.IsForbidden, plate) == false
            and ns.Text(plate.unitToken) then
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
