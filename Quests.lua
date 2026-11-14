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
	local list, seen = {}, {}
	local function add(b)
		if b and not seen[b] then seen[b] = true list[#list + 1] = b end
	end
	local frame = _G.QuestInfoRewardsFrame
	if frame and frame.RewardButtons then
		for _, b in ipairs(frame.RewardButtons) do add(b) end
	end
	for i = 1, 30 do add(_G["QuestInfoRewardsFrameQuestInfoItem" .. i]) end
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
		local anyUpgrade, unknown, best, bestPrice = false, false, nil, 0
		for _, c in ipairs(choices) do
			anyUpgrade = anyUpgrade or c.upgrade
			local sell = select(11, GetInfo(c.link))
			if sell == nil then
				unknown = true
			elseif sell > bestPrice then
				best, bestPrice = c.button, sell
			end
		end
		if unknown then pending = true end
		if not anyUpgrade and not unknown and best then Mark(best, "coin") end
	end
	if pending and retries < 6 then
		retries = retries + 1
		C_Timer.After(0.5, function() Quests:Update() end)
	elseif not pending then
		retries = 0
	end
end

-- Blizzard's quest templates keep their own reference to QuestInfo_ShowRewards, so hook the
-- entry points that are called by name and the frame's own show/events as well.
local function Schedule()
	retries = 0
	C_Timer.After(0, function() pcall(Quests.Update, Quests) end)
end

local function Hook()
	if not Quests.hooked and _G.QuestInfo_Display then
		Quests.hooked = true
		hooksecurefunc("QuestInfo_Display", Schedule)
		if _G.QuestInfo_ShowRewards then hooksecurefunc("QuestInfo_ShowRewards", Schedule) end
	end
	local frame = _G.QuestInfoRewardsFrame
	if frame and not Quests.frameHooked then
		Quests.frameHooked = true
		frame:HookScript("OnShow", Schedule)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_ITEM_UPDATE")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent", function(_, event)
	if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
		Hook()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if _G.QuestInfoRewardsFrame and _G.QuestInfoRewardsFrame:IsVisible() then Schedule() end
	else
		Hook()
		Schedule()
	end
end)
