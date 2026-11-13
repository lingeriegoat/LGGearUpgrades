local _, LG = ...
local MM = {}
LG.Minimap = MM

local ICON = "Interface\\AddOns\\LGGearUpgrades\\Media\\Icon"
local button

local function UpdatePosition()
	if not button then return end
	local angle = math.rad(LG.global.minimapAngle)
	local x, y = math.cos(angle), math.sin(angle)
	local w, h = Minimap:GetWidth() / 2 + 5, Minimap:GetHeight() / 2 + 5
	if GetMinimapShape and GetMinimapShape() == "SQUARE" then
		x = math.max(-w, math.min(w, x * w * 1.4142))
		y = math.max(-h, math.min(h, y * h * 1.4142))
	else
		x, y = x * w, y * h
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate()
	local mx, my = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = Minimap:GetCenter()
	LG.global.minimapAngle = math.deg(math.atan2(my / scale - cy, mx / scale - cx)) % 360
	UpdatePosition()
end

local function Create()
	button = CreateFrame("Button", "LGGearUpgradesMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 7, -5)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(50, 50)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function() LG.Options:Open() end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", OnDragUpdate)
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("LG Gear Upgrades")
		GameTooltip:AddLine("Click to open the options.", 1, 1, 1)
		GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Minimap:HookScript("OnSizeChanged", UpdatePosition)
end

function MM:Refresh()
	if not button then Create() end
	UpdatePosition()
	button:SetShown(not LG.global.minimapHide)
end

LG:OnInit(function() MM:Refresh() end)
