local _, LG = ...
local Options = {}
LG.Options = Options

local controls = {}
local panel

local function Changed() LG:SettingsChanged() end

local function Label(parent, text, x, y, font)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(text)
	return fs
end

local function Check(parent, text, x, y, get, set, quiet)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x, y)
	cb:SetSize(26, 26)
	local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
	fs:SetText(text)
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		if not quiet then Changed() end
	end)
	cb.refresh = function() cb:SetChecked(get()) end
	controls[#controls + 1] = cb
	return cb, fs
end

local function NumberBox(parent, width, get, set, minV, maxV)
	local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	eb:SetSize(width, 20)
	eb:SetAutoFocus(false)
	eb:SetNumeric(true)
	eb:SetMaxLetters(7)
	local function commit(self)
		local n = tonumber(self:GetText())
		if n then set(math.max(minV, math.min(maxV, n))) Changed() end
		self:SetText(tostring(get()))
	end
	eb:SetScript("OnEnterPressed", function(self) commit(self) self:ClearFocus() end)
	eb:SetScript("OnEditFocusLost", commit)
	eb.refresh = function() eb:SetText(tostring(get())) end
	controls[#controls + 1] = eb
	return eb
end

local function Section(parent, text, y)
	Label(parent, text, 16, y)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 0.15)
	line:SetPoint("TOPLEFT", 16, y - 18)
	line:SetSize(480, 1)
end

function Options:Create()
	local outer = CreateFrame("Frame")
	outer.name = "LG Gear Upgrades"
	local scroll = CreateFrame("ScrollFrame", nil, outer, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -28, 4)
	local p = CreateFrame("Frame", nil, scroll)
	p:SetSize(560, 680)
	scroll:SetScrollChild(p)
	scroll:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then p:SetWidth(w) end end)
	Label(p, "LG Gear Upgrades", 16, -16, "GameFontNormalLarge")
	local db = LG.db

	Section(p, "Stats to compare (armor and weapons)", -48)
	local col, row = 0, 0
	for _, s in ipairs(LG.Items.STATS) do
		if s.key ~= "DPS" then
			Check(p, s.label, 20 + col * 160, -72 - row * 26,
				function() return db.stats[s.key] end, function(v) db.stats[s.key] = v end)
			col = col + 1
			if col == 3 then col, row = 0, row + 1 end
		end
	end

	Section(p, "Weapons (also use the stats above)", -176)
	local weapons = { { "mainhand", "Main hand" }, { "offhand", "Offhand" }, { "twohand", "Two handed" }, { "ranged", "Ranged" } }
	for i, w in ipairs(weapons) do
		Check(p, w[2], 20 + (i - 1) * 120, -200,
			function() return db.weaponSlots[w[1]] end, function(v) db.weaponSlots[w[1]] = v end)
	end
	Check(p, "DPS (a higher DPS counts as an upgrade)", 20, -228,
		function() return db.stats.DPS end, function(v) db.stats.DPS = v end)

	Section(p, "Armor types", -268)
	local types = { { "cloth", "Cloth" }, { "leather", "Leather" }, { "mail", "Mail" }, { "plate", "Plate" } }
	for i, t in ipairs(types) do
		Check(p, t[2], 20 + (i - 1) * 120, -292,
			function() return db.armorTypes[t[1]] end, function(v) db.armorTypes[t[1]] = v end)
	end

	Section(p, "Auction house", -332)
	Check(p, "Only show items costing at most", 20, -356,
		function() return db.useMaxGold end, function(v) db.useMaxGold = v end)
	local gold = NumberBox(p, 70, function() return db.maxGold end, function(v) db.maxGold = v end, 0, 9999999)
	gold:SetPoint("TOPLEFT", 270, -359)
	Label(p, "gold", 346, -362, "GameFontHighlight")
	Check(p, "Use Auctionator to run the scan (when installed)", 20, -382,
		function() return db.useAuctionator end, function(v) db.useAuctionator = v end)
	Check(p, "Build results from scans made by other addons", 20, -408,
		function() return db.useOtherScans end, function(v) db.useOtherScans = v end)

	Section(p, "Level requirement", -448)
	Check(p, "Also include items up to", 20, -472,
		function() return db.allowHigherLevel end, function(v) db.allowHigherLevel = v end)
	local lv = NumberBox(p, 40, function() return db.levelsAbove end, function(v) db.levelsAbove = v end, 1, 100)
	lv:SetPoint("TOPLEFT", 230, -475)
	Label(p, "levels above my level", 278, -478, "GameFontHighlight")

	Section(p, "Alerts", -512)
	Check(p, "Show a chat alert when a better item enters your bags", 20, -536,
		function() return db.chatAlert end, function(v) db.chatAlert = v end, true)
	Check(p, "Play a sound when a new bag item is 100% or more better", 20, -562,
		function() return db.playSound end, function(v) db.playSound = v end, true)

	Section(p, "Interface", -602)
	local _, mmLabel = Check(p, "Show the minimap button", 20, -626,
		function() return not LG.global.minimapHide end,
		function(v) LG.global.minimapHide = not v LG.Minimap:Refresh() end, true)
	local note = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetPoint("LEFT", mmLabel, "RIGHT", 8, 0)
	note:SetText("(all characters)")

	outer:SetScript("OnShow", function() for _, c in ipairs(controls) do c.refresh() end end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		Options.category = Settings.RegisterCanvasLayoutCategory(outer, outer.name)
		Settings.RegisterAddOnCategory(Options.category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(outer)
	end
	panel = outer
end

function Options:Open()
	if self.category and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

LG:OnInit(function() Options:Create() end)
