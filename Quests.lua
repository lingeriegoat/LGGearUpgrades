local _, LG = ...
local Quests = {}
LG.Quests = Quests

local ARROW = "Interface\\AddOns\\LGGearUpgrades\\Media\\UpArrow"
local COIN = "Interface\\Icons\\INV_Misc_Coin_01"
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local marks = setmetatable({}, { __mode = "k" })
local retries = 0

local function Mark(button, kind)
	local m = marks[button]
	if not kind then
		if m then m.arrow:Hide() m.coin:Hide() end
		return
	end
	if not m then
		local host = button.Icon or button.icon or button
		m = { arrow = button:CreateTexture(nil, "OVERLAY", nil, 7), coin = button:CreateTexture(nil, "OVERLAY", nil, 7) }
		m.arrow:SetTexture(ARROW)
		m.arrow:SetSize(16, 16)
		m.arrow:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 2, 2)
		m.coin:SetTexture(COIN)
		m.coin:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		m.coin:SetSize(16, 16)
		m.coin:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 2, 2)
		marks[button] = m
	end
	m.arrow:SetShown(kind == "arrow")
	m.coin:SetShown(kind == "coin")
end

local function RewardButtons()
	local list = {}
	local frame = _G.QuestInfoRewardsFrame
	if frame and frame.RewardButtons then
		for _, b in ipairs(frame.RewardButtons) do list[#list + 1] = b end
	else
		for i = 1, 30 do
			local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
			if not b then break end
			list[#list + 1] = b
		end
	end
	return list
end

local function LinkOf(button)
	local kind, id = button.type, button:GetID()
	if not (kind and id) then return nil end
	if QuestInfoFrame and QuestInfoFrame.questLog and GetQuestLogItemLink then
		return GetQuestLogItemLink(kind, id)
	end
	return GetQuestItemLink and GetQuestItemLink(kind, id)
end

function Quests:Update()
	if not LG.db then return end
	local choices, pending = {}, false
	local all = RewardButtons()
	for _, b in ipairs(all) do
		Mark(b, nil)
		if b:IsShown() and b.type then
			local link = LinkOf(b)
			if link then
				local r, p = LG.Items.Evaluate(link)
				if p then pending = true end
				if r then Mark(b, "arrow") end
				if b.type == "choice" then choices[#choices + 1] = { button = b, link = link, upgrade = r ~= nil } end
			end
		end
	end
	if #choices > 1 then
		local anyUpgrade, best, bestPrice = false, nil, -1
		for _, c in ipairs(choices) do
			anyUpgrade = anyUpgrade or c.upgrade
			local sell = select(11, GetInfo(c.link)) or 0
			if sell > bestPrice then best, bestPrice = c.button, sell end
		end
		if not anyUpgrade and best then Mark(best, "coin") end
	end
	if pending and retries < 3 then
		retries = retries + 1
		C_Timer.After(0.5, function() Quests:Update() end)
	elseif not pending then
		retries = 0
	end
end

local function Hook()
	if Quests.hooked or not _G.QuestInfo_ShowRewards then return end
	Quests.hooked = true
	hooksecurefunc("QuestInfo_ShowRewards", function() retries = 0 pcall(Quests.Update, Quests) end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", Hook)
