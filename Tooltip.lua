local _, LG = ...

local BETTER = { { 0.6, 1, 0.6 }, { 0.1, 0.9, 0.1 }, { 0.2, 0.6, 1 }, { 0.65, 0.3, 1 }, { 0.95, 0.35, 1 } }
local WORSE = { { 1, 0.6, 0.6 }, { 1, 0.3, 0.3 }, { 0.9, 0.1, 0.1 }, { 0.75, 0.05, 0.05 }, { 0.6, 0.05, 0.05 } }

local function Tier(mag)
	if mag >= 200 then return 5 end
	if mag >= 100 then return 4 end
	if mag >= 50 then return 3 end
	if mag >= 25 then return 2 end
	return 1
end

local PREFIX = "|cff99e699LG Gear Upgrades - |r"

local function Colored(c, text)
	return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text)
end

local function AddLine(tooltip, link)
	if not (link and LG.db) then return end
	local ok, r = pcall(LG.Items.Rate, link)
	local verdict = ok and LG.Items.Verdict(r)
	if verdict == "better" then
		local c = BETTER[r.pct and Tier(r.pct) or 5]
		local text = r.pct and ("%.0f%% Better"):format(r.pct) or "Better (empty slot)"
		tooltip:AddLine(PREFIX .. Colored(c, text))
	elseif verdict == "worse" then
		local mag = -r.pct
		tooltip:AddLine(PREFIX .. Colored(WORSE[Tier(mag)], ("%.0f%% Worse"):format(mag)))
	end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if not tooltip.GetItem then return end
		local _, link = tooltip:GetItem()
		AddLine(tooltip, link or (data and data.hyperlink))
	end)
else
	for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
		tt:HookScript("OnTooltipSetItem", function(self)
			local _, link = self:GetItem()
			AddLine(self, link)
		end)
	end
end
