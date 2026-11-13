local _, LG = ...
local A = {}
LG.Auction = A

local Items = LG.Items
local AH = C_AuctionHouse
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local COOLDOWN = 15 * 60
local RESPONSE_TIMEOUT = 30
local LOAD_TIMEOUT = 10
local OTHER_SCAN_SETTLE = 3
local BATCH = 500
local MAX_ROWS = 500
local ROW_H, VISIBLE, TOP, STALE_H = 38, 12, 74, 15
local CARET = "Interface\\AddOns\\LGGearUpgrades\\Media\\CaretDown"

A.state = "idle" -- idle | waiting | reading
A.results = {}
A.display = {}
A.collapsed = {}
local top = TOP - STALE_H
local token = 0
local otherToken = 0
local lastRead = 0
local ui = {}

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local function Coins(c)
	c = math.floor(c)
	local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) .. GOLD end
	if g > 0 or s > 0 then parts[#parts + 1] = s .. SILVER end
	parts[#parts + 1] = cp .. COPPER
	return table.concat(parts, " ")
end

local function AgeText(sec)
	if sec < 3600 then return ("%d min"):format(math.max(1, math.floor(sec / 60))) end
	if sec < 86400 then return ("%dh %dm"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
	return ("%d days"):format(math.floor(sec / 86400))
end

local function Minutes(sec)
	local m = math.max(1, math.floor(sec / 60))
	return m == 1 and "1 minute" or (m .. " minutes")
end

-- one entry per item (and random suffix), whichever listing is cheapest
local function KeyOf(link)
	local id, suffix = link:match("item:(%-?%d+):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:(%-?%d*)")
	return id and (id .. ":" .. (suffix or "")) or link
end

local function SearchAH(name)
	if not (name and AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return end
	pcall(function()
		if AuctionHouseFrameDisplayMode then AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy) end
		local bar = AuctionHouseFrame.SearchBar
		bar.SearchBox:SetText(name)
		bar:StartSearch()
	end)
end

local function DataTime()
	return A.replicateAt or LG.db.lastScan or time()
end

---------------------------------------------------------------------------
-- Results window
---------------------------------------------------------------------------
function A:SetStatus(text)
	if ui.status then ui.status:SetText(text) end
end

local function Layout(hasStale)
	local t = hasStale and TOP or TOP - STALE_H
	if t == top then return end
	top = t
	ui.frame:SetHeight(top + VISIBLE * ROW_H + 14)
	ui.status:ClearAllPoints()
	ui.status:SetPoint("TOPLEFT", 14, 31 - top)
	ui.status:SetPoint("RIGHT", -14, 0)
	ui.info:ClearAllPoints()
	ui.info:SetPoint("TOPLEFT", 14, 17 - top)
	ui.info:SetPoint("RIGHT", -14, 0)
	for i, row in ipairs(ui.rows) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 12, -top - (i - 1) * ROW_H)
	end
	ui.slider:ClearAllPoints()
	ui.slider:SetPoint("TOPRIGHT", -10, -top)
	ui.slider:SetPoint("BOTTOMRIGHT", -10, 14)
end

function A:RefreshStale()
	if not ui.stale then return end
	local text = ""
	if #A.results > 0 and A.savedAt then
		if A.settingsChanged then
			text = "Settings changed since this scan - results may be out of date."
		elseif time() - A.savedAt > COOLDOWN then
			text = ("These results are out of date (scanned %s ago)."):format(AgeText(time() - A.savedAt))
		end
	end
	ui.stale:SetText(text)
	Layout(text ~= "")

	if not A.savedAt then
		ui.info:SetText("No scan yet - ready to scan.")
	else
		local age = time() - A.savedAt
		if age > COOLDOWN then
			ui.info:SetText(#A.results > 0 and "" or ("Last scan: %s ago - |cff40ff40ready to scan.|r"):format(Minutes(age)))
		else
			ui.info:SetText(("Last scan: %s ago - next scan available in %s."):format(
				age < 60 and "under a minute" or Minutes(age), Minutes(math.ceil((COOLDOWN - age) / 60) * 60)))
		end
	end
end

local function BuildDisplay()
	wipe(A.display)
	local list = A.results
	local i = 1
	while i <= #list do
		local group = list[i].group
		local j = i
		while j <= #list and list[j].group == group do j = j + 1 end
		local best
		for k = i, j - 1 do
			local e = list[k]
			e.best = nil
			if e.gain and (not best or e.gain > best.gain) then best = e end
		end
		if best then
			for k = i, j - 1 do
				local e = list[k]
				if e.gain and (best.gain - e.gain < 0.001 or e.pctText == best.pctText) then e.best = true end
			end
		end
		local key = group or "Other"
		local closed = A.collapsed[key]
		A.display[#A.display + 1] = { header = ("%s (%d)"):format(key, j - i), key = key, closed = closed }
		if not closed then
			for k = i, j - 1 do A.display[#A.display + 1] = list[k] end
		end
		i = j
	end
end

local function UpdateRows()
	if not ui.rows then return end
	local offset = A.offset or 0
	for i, row in ipairs(ui.rows) do
		local d = A.display[offset + i]
		if d and d.header then
			row.link = nil
			row.key = d.key
			row.glow:Hide()
			row.bg:Show()
			row.caret:Show()
			row.caret:SetTexCoord(0, 1, d.closed and 1 or 0, d.closed and 0 or 1)
			row.icon:Hide()
			row.info:SetText("")
			row.price:SetText("")
			row.name:SetFontObject(GameFontNormalLarge)
			row.name:SetText(d.header)
			row.name:ClearAllPoints()
			row.name:SetPoint("LEFT", row, "LEFT", 24, 0)
			row:Show()
		elseif d then
			row.link = d.link
			row.key = nil
			row.glow:SetShown(d.best == true)
			row.bg:Hide()
			row.caret:Hide()
			row.icon:Show()
			row.icon:SetTexture(select(5, GetInstant(d.link)))
			row.name:SetFontObject(GameFontNormal)
			row.name:ClearAllPoints()
			row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
			row.name:SetPoint("RIGHT", row, "RIGHT", -120, 0)
			row.name:SetText(d.link)
			row.info:SetText(("%s: %s"):format(d.pctText or "", d.info or ""))
			row.price:SetText(Coins(d.price))
			row:Show()
		else
			row.link = nil
			row.key = nil
			row.glow:Hide()
			row:Hide()
		end
	end
	local maxOffset = math.max(0, #A.display - VISIBLE)
	ui.slider:SetMinMaxValues(0, maxOffset)
	ui.slider:SetShown(maxOffset > 0)
end

local GLOW = { 0.25, 0.65, 1 }

local function MakeGlow(row)
	local g = CreateFrame("Frame", nil, row)
	g:SetAllPoints()
	local tint = g:CreateTexture(nil, "BACKGROUND")
	tint:SetAllPoints()
	tint:SetColorTexture(GLOW[1], GLOW[2], GLOW[3], 0.12)
	-- ring expanded e px beyond the row, t px thick, drawn inward from that edge
	local function ring(e, t, alpha)
		local function edge(p1, x1, y1, p2, x2, y2, w, h)
			local tex = g:CreateTexture(nil, "OVERLAY")
			tex:SetColorTexture(GLOW[1], GLOW[2], GLOW[3], alpha)
			tex:SetPoint(p1, g, p1, x1, y1)
			tex:SetPoint(p2, g, p2, x2, y2)
			if w then tex:SetWidth(w) end
			if h then tex:SetHeight(h) end
		end
		edge("TOPLEFT", -e, e, "TOPRIGHT", e, e, nil, t)
		edge("BOTTOMLEFT", -e, -e, "BOTTOMRIGHT", e, -e, nil, t)
		edge("TOPLEFT", -e, e, "BOTTOMLEFT", -e, -e, t, nil)
		edge("TOPRIGHT", e, e, "BOTTOMRIGHT", e, -e, t, nil)
	end
	ring(0, 2, 1)
	ring(3, 3, 0.3)
	local anim = g:CreateAnimationGroup()
	local pulse = anim:CreateAnimation("Alpha")
	if pulse.SetFromAlpha then
		pulse:SetFromAlpha(1)
		pulse:SetToAlpha(0.55)
	else
		pulse:SetChange(-0.45)
	end
	pulse:SetDuration(0.9)
	anim:SetLooping("BOUNCE")
	g:SetScript("OnShow", function() anim:Play() end)
	g:SetScript("OnHide", function() anim:Stop() end)
	g:Hide()
	return g
end

local function MakeRow(parent, i)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(376, ROW_H - 2)
	b:SetPoint("TOPLEFT", 12, -top - (i - 1) * ROW_H)
	b.glow = MakeGlow(b)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(1, 1, 1, 0.1)
	b.caret = b:CreateTexture(nil, "ARTWORK")
	b.caret:SetTexture(CARET)
	b.caret:SetSize(14, 14)
	b.caret:SetPoint("LEFT", 6, 0)
	b.caret:SetVertexColor(1, 0.82, 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(32, 32)
	b.icon:SetPoint("LEFT", 2, 0)
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.name:SetJustifyH("LEFT")
	b.name:SetWordWrap(false)
	b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.info:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 6, 1)
	b.info:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.info:SetJustifyH("LEFT")
	b.info:SetWordWrap(false)
	b.price = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.price:SetPoint("TOPRIGHT", -4, -3)
	b.price:SetJustifyH("RIGHT")
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b:SetScript("OnEnter", function(self)
		if not self.link then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		if self.key then
			A.collapsed[self.key] = not A.collapsed[self.key] or nil
			BuildDisplay()
			return UpdateRows()
		end
		if not self.link then return end
		if IsModifiedClick() and HandleModifiedItemClick then
			HandleModifiedItemClick(self.link)
		else
			SearchAH((GetInfo(self.link)))
		end
	end)
	return b
end

function A:CreateWindow()
	if ui.frame then return ui.frame end
	local f = CreateFrame("Frame", "LGGearUpgradesResults", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(424, top + VISIBLE * ROW_H + 14)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if AuctionHouseFrame then f:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0) else f:SetPoint("CENTER") end
	local title = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if not f.TitleText then title:SetPoint("TOP", 0, -6) end
	title:SetText("LG Gear Upgrades")

	ui.stale = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ui.stale:SetPoint("TOPLEFT", 14, -28)
	ui.stale:SetPoint("RIGHT", -14, 0)
	ui.stale:SetJustifyH("LEFT")
	ui.stale:SetTextColor(1, 0.2, 0.2)
	ui.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ui.status:SetPoint("TOPLEFT", 14, 31 - top)
	ui.status:SetPoint("RIGHT", -14, 0)
	ui.status:SetJustifyH("LEFT")
	ui.status:SetWordWrap(false)
	ui.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ui.info:SetPoint("TOPLEFT", 14, 17 - top)
	ui.info:SetPoint("RIGHT", -14, 0)
	ui.info:SetJustifyH("LEFT")
	ui.info:SetWordWrap(false)

	ui.rows = {}
	for i = 1, VISIBLE do ui.rows[i] = MakeRow(f, i) end

	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("VERTICAL")
	s:SetPoint("TOPRIGHT", -10, -top)
	s:SetPoint("BOTTOMRIGHT", -10, 14)
	s:SetWidth(14)
	s:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	s:GetThumbTexture():SetSize(14, 22)
	local bg = s:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.4)
	s:SetMinMaxValues(0, 0)
	s:SetValueStep(1)
	s:SetObeyStepOnDrag(true)
	s:SetValue(0)
	s:SetScript("OnValueChanged", function(_, v)
		A.offset = math.floor(v + 0.5)
		UpdateRows()
	end)
	ui.slider = s
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta) s:SetValue(s:GetValue() - delta * 3) end)

	local elapsed = 0
	f:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed > 15 then elapsed = 0 A:RefreshStale() end
	end)
	f:Hide()
	ui.frame = f
	return f
end

function A:ShowResults()
	self:CreateWindow():Show()
	UpdateRows()
	self:RefreshStale()
end

function A:ToggleResults()
	local f = self:CreateWindow()
	if f:IsShown() then f:Hide() else self:ShowResults() end
end

function A:MarkStale()
	if #A.results > 0 then
		A.settingsChanged = true
		A:RefreshStale()
	end
end

local function SetResults(list, savedAt)
	A.results = list
	A.savedAt = savedAt
	A.settingsChanged = false
	A.collapsed = {}
	A.offset = 0
	BuildDisplay()
	if ui.slider then ui.slider:SetValue(0) end
	UpdateRows()
	A:RefreshStale()
end

---------------------------------------------------------------------------
-- Scanning (C_AuctionHouse.ReplicateItems: one full scan per 15 minutes, read-only)
---------------------------------------------------------------------------
local function HasData() return (AH.GetNumReplicateItems() or 0) > 0 end

function A:Read(message)
	token = token + 1
	local t = token
	self.state = "reading"
	self:SetStatus(message)

	local db = LG.db
	local total = AH.GetNumReplicateItems() or 0
	local player = UnitName("player")
	local cap = db.useMaxGold and (db.maxGold * 10000) or math.huge
	local found = {}
	local waiting, allRead = 0, false
	local dataTime = DataTime()

	local function finish()
		if t ~= token then return end
		local list = {}
		for _, d in pairs(found) do
			local r = d.r
			list[#list + 1] = {
				link = d.link, price = d.price, group = r.group, slot = r.slot, gain = r.gain,
				pctText = Items.FormatPct(r), info = Items.FormatGains(r.deltas),
			}
		end
		local n = #list
		table.sort(list, function(a, b) return a.price < b.price end)
		for i = n, MAX_ROWS + 1, -1 do list[i] = nil end
		table.sort(list, function(a, b)
			local ga, gb = Items.GROUP_INDEX[a.group] or 99, Items.GROUP_INDEX[b.group] or 99
			if ga ~= gb then return ga < gb end
			return a.price < b.price
		end)
		A.state = "idle"
		lastRead = time()
		db.saved = { time = dataTime, list = list }
		SetResults(list, dataTime)
		A:SetStatus(n == 0 and ("No upgrades found among %d auctions."):format(total)
			or ("%d upgrades found among %d auctions%s."):format(n, total, n > MAX_ROWS and (" (cheapest " .. MAX_ROWS .. " shown)") or ""))
	end

	local function keep(link, price, r)
		local key = KeyOf(link)
		local cur = found[key]
		if not cur or price < cur.price then found[key] = { link = link, price = price, r = r } end
	end

	local function consider(link, price, itemID)
		local cur = found[KeyOf(link)]
		if cur and cur.price <= price then return end
		local r, pending = Items.Evaluate(link)
		if r then
			keep(link, price, r)
		elseif pending then
			waiting = waiting + 1
			Items.Load(itemID, function()
				if t ~= token then return end
				local r2 = Items.Evaluate(link)
				if r2 then keep(link, price, r2) end
				waiting = waiting - 1
				if waiting == 0 and allRead then finish() end
			end)
		end
	end

	local idx = 0
	local function step()
		if t ~= token then return end
		local stop = math.min(idx + BATCH, total) - 1
		for i = idx, stop do
			-- name, texture, count, quality, canUse, level, levelType, minBid, minIncrement, buyout,
			-- bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo
			local _, _, count, _, canUse, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = AH.GetReplicateItemInfo(i)
			if itemID and buyout and buyout > 0 and buyout <= cap and (count or 1) <= 1
				and canUse ~= false and owner ~= player then
				local _, _, _, equipLoc, _, classID, subclassID = GetInstant(itemID)
				if Items.PassesFilters(equipLoc, classID, subclassID) then
					local link = AH.GetReplicateItemLink(i)
					if link then consider(link, buyout, itemID) end
				end
			end
		end
		idx = stop + 1
		A:SetStatus(("Reading auctions... %d / %d"):format(idx, total))
		if idx < total then
			C_Timer.After(0, step)
		else
			allRead = true
			if waiting == 0 then finish() else C_Timer.After(LOAD_TIMEOUT, finish) end
		end
	end

	if total == 0 then return finish() end
	step()
end

local function AuctionatorReady()
	return _G.Auctionator ~= nil and LG.db.useAuctionator
end

local function StartAuctionator()
	local ref = Auctionator.State and Auctionator.State.FullScanFrameRef
	if not ref then error("Auctionator's scanner isn't ready") end
	if ref.CanInitiate and not ref:CanInitiate() then error("Auctionator is still on its own 15 minute limit") end
	ref:InitiateScan()
end

function A:Wait(message)
	token = token + 1
	local t = token
	self.state = "waiting"
	self:SetStatus(message)
	self:RefreshStale()
	C_Timer.After(RESPONSE_TIMEOUT, function()
		if t == token and A.state == "waiting" then
			A.state = "idle"
			if HasData() then
				A:Read("The server didn't answer - using the last scan...")
			else
				A:SetStatus("No answer - the scan is probably on cooldown.")
			end
		end
	end)
end

function A:Scan()
	if not self.open then return LG:Print("Open the auction house first.") end
	if self.state ~= "idle" then return LG:Print("A scan is already running.") end
	self:ShowResults()
	local left = COOLDOWN - (time() - (LG.db.lastScan or 0))
	if left > 0 and HasData() then
		return self:Read(("Using the last scan (new scan possible in %d:%02d)..."):format(math.floor(left / 60), left % 60))
	end

	if AuctionatorReady() then
		local ok, err = pcall(StartAuctionator)
		if ok then return self:Wait("Waiting for Auctionator's scan...") end
		self:SetStatus("Auctionator couldn't scan (" .. tostring(err) .. ") - scanning directly...")
	end
	local ok, err = pcall(AH.ReplicateItems)
	if not ok then return self:SetStatus("Couldn't start a scan: " .. tostring(err)) end
	self:Wait("Scanning - waiting for the server...")
end

---------------------------------------------------------------------------
-- Saved results, auction house button and events
---------------------------------------------------------------------------
LG:OnInit(function()
	local saved = LG.db.saved
	if saved and saved.list then
		A.results = saved.list
		A.savedAt = saved.time
		BuildDisplay()
	end
end)

local function EnsureButtons()
	if ui.button or not AuctionHouseFrame then return end
	local r = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
	r:SetSize(70, 22)
	r:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -4, 0)
	r:SetText("Results")
	r:SetScript("OnClick", function() A:ToggleResults() end)
	ui.resultsButton = r
	local b = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
	b:SetSize(190, 22)
	b:SetPoint("RIGHT", r, "LEFT", -2, 0)
	b:SetText("LG Gear Upgrades - Scan")
	b:SetScript("OnClick", function() A:Scan() end)
	ui.button = b
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event)
	if not LG.db then return end
	if event == "AUCTION_HOUSE_SHOW" then
		A.open = true
		EnsureButtons()
		C_Timer.After(1, function()
			if A.open and LG.db.useOtherScans and A.state == "idle" and A.replicateAt and HasData()
				and A.replicateAt > (A.savedAt or 0) then
				A:Read("Found data from an earlier scan - reading it...")
			end
		end)
	elseif event == "AUCTION_HOUSE_CLOSED" then
		A.open = false
		token = token + 1
		otherToken = otherToken + 1
		A.state = "idle"
		if ui.frame then ui.frame:Hide() end
	else
		A.replicateAt = time()
		LG.db.lastScan = A.replicateAt
		if A.state == "waiting" then
			A:Read("Reading auctions...")
		elseif A.state == "idle" and A.open and LG.db.useOtherScans and time() - lastRead > 20 then
			otherToken = otherToken + 1
			local t = otherToken
			C_Timer.After(OTHER_SCAN_SETTLE, function()
				if t == otherToken and A.open and A.state == "idle" then
					A:Read("Reading a scan made by another addon...")
				end
			end)
		end
	end
end)
