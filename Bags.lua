local _, LG = ...
local Bags = {}
LG.Bags = Bags

local GetLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local MAX_BAG = NUM_BAG_SLOTS or 4
local ARROW = "Interface\\AddOns\\LGGearUpgrades\\Media\\UpArrow"

local arrows = setmetatable({}, { __mode = "k" })
local external = setmetatable({}, { __mode = "k" })
local retries = {}
local known

local function UpgradeFor(link)
	if not (link and LG.db) then return nil end
	local r, pending = LG.Items.Evaluate(link)
	if pending and (retries[link] or 0) < 3 then
		retries[link] = (retries[link] or 0) + 1
		local itemID = GetInstant(link)
		if itemID then LG.Items.Load(itemID, function() Bags:Refresh() end) end
	end
	return r
end

local function Paint(button, link, host)
	local show = link and UpgradeFor(link)
	local tex = arrows[button]
	if show then
		if not tex then
			tex = (host or button):CreateTexture(nil, "OVERLAY", nil, 7)
			tex:SetTexture(ARROW)
			tex:SetSize(16, 16)
			tex:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
			arrows[button] = tex
		end
		tex:Show()
	elseif tex then
		tex:Hide()
	end
end

local function PaintExternal(button, link, host)
	external[button] = { link = link, host = host }
	Paint(button, link, host)
end

local function BagFrames()
	local list = {}
	for i = 1, 13 do
		local f = _G["ContainerFrame" .. i]
		if f then list[#list + 1] = f end
	end
	if _G.ContainerFrameCombinedBags then list[#list + 1] = _G.ContainerFrameCombinedBags end
	return list
end

local function ButtonsOf(frame)
	local list = {}
	if frame.EnumerateValidItems then
		for _, b in frame:EnumerateValidItems() do list[#list + 1] = b end
	elseif frame.Items then
		for _, b in ipairs(frame.Items) do list[#list + 1] = b end
	elseif frame.GetName and frame:GetName() then
		for j = 1, 40 do
			local b = _G[frame:GetName() .. "Item" .. j]
			if not b then break end
			list[#list + 1] = b
		end
	end
	return list
end

local function BagAndSlot(button)
	local bag = button.GetBagID and button:GetBagID()
	if not bag then
		local p = button:GetParent()
		bag = p and p.GetID and p:GetID()
	end
	return bag, button.GetID and button:GetID()
end

function Bags:UpdateButtons()
	for _, frame in ipairs(BagFrames()) do
		if frame:IsShown() then
			for _, button in ipairs(ButtonsOf(frame)) do
				local link
				if button:IsShown() then
					local bag, slot = BagAndSlot(button)
					link = bag and slot and GetLink(bag, slot)
				end
				Paint(button, link)
			end
		end
	end
	for button, e in pairs(external) do
		if button:IsShown() then Paint(button, e.link, e.host) end
	end
end

local queued
local settingsDirty
function Bags:Refresh(clearRetries)
	if clearRetries then wipe(retries) settingsDirty = true end
	if queued then return end
	queued = true
	C_Timer.After(0.2, function()
		queued = false
		Bags:UpdateButtons()
		if settingsDirty then
			settingsDirty = false
			pcall(Bags.RederiveBetterBags, Bags)
		end
	end)
end

local function Announce(link, r)
	if not LG.db.chatAlert then return end
	local vs = r.equipped or "an empty slot"
	LG:Print(("Better item: %s  (%s) vs %s [%s]"):format(link, LG.Items.FormatPct(r) .. ": " .. LG.Items.FormatGains(r.deltas), vs, LG.Items.SLOT_NAMES[r.slot]))
end

local function Snapshot()
	local now = {}
	for bag = 0, MAX_BAG do
		for slot = 1, NumSlots(bag) or 0 do
			local link = GetLink(bag, slot)
			if link then now[link] = true end
		end
	end
	return now
end

function Bags:CheckNew()
	local now = Snapshot()
	if known then
		local huge
		for link in pairs(now) do
			if not known[link] then
				local r = UpgradeFor(link)
				if r then
					Announce(link, r)
					huge = huge or LG.Items.IsHuge(r)
				end
			end
		end
		if huge then LG:PlayUpgradeSound() end
	end
	known = now
end

local hooked = {}
function Bags:Hook()
	for _, frame in ipairs(BagFrames()) do
		if not hooked[frame] then
			hooked[frame] = true
			frame:HookScript("OnShow", function() Bags:Refresh() end)
			if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", function() Bags:Refresh() end) end
		end
	end
	if _G.ContainerFrame_Update and not hooked.global then
		hooked.global = true
		hooksecurefunc("ContainerFrame_Update", function() Bags:Refresh() end)
	end
end

-- Bagnon: every slot button is a BagBrother.Item; hyperlink is in button.info
function Bags:HookBagnon()
	local Item = _G.BagBrother and _G.BagBrother.Item
	if hooked.bagnon or type(Item) ~= "table" or type(Item.Update) ~= "function" then return end
	hooked.bagnon = true
	hooksecurefunc(Item, "Update", function(button)
		local cached = button.IsCached and button:IsCached()
		PaintExternal(button, not cached and button.info and button.info.hyperlink or nil)
	end)
	Bags:Refresh()
end

local function SafeHooks()
	pcall(Bags.Hook, Bags)
	pcall(Bags.HookBagnon, Bags)
	pcall(Bags.HookBetterBags, Bags)
end
Bags.SafeHooks = SafeHooks

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function(_, event)
	if event == "ADDON_LOADED" then
		SafeHooks()
	elseif event == "PLAYER_ENTERING_WORLD" then
		SafeHooks()
		f:UnregisterEvent("PLAYER_ENTERING_WORLD")
		for _, delay in ipairs({ 1, 3, 8 }) do C_Timer.After(delay, SafeHooks) end
		C_Timer.After(3, function()
			known = Snapshot()
			Bags:Refresh()
		end)
	elseif LG.db and known then
		pcall(Bags.HookBetterBags, Bags)
		Bags:CheckNew()
		Bags:Refresh()
	end
end)

-- BetterBags: register as an upgrade provider (BetterBags wipes its provider list at startup, so re-check).
local function BetterBagsAddon()
	return LibStub and LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("BetterBags", true)
end

function Bags:HookBetterBags()
	local addon = BetterBagsAddon()
	local items = addon and addon:GetModule("Items", true)
	if not (items and items.RegisterUpgradeProvider and items.upgradeProviders) then return end
	if items.upgradeProviders.LGGearUpgrades then return end
	items:RegisterUpgradeProvider("LGGearUpgrades", function(data)
		local link = data and not data.isItemEmpty and data.itemInfo and data.itemInfo.itemLink
		if not (link and LG.db) then return false end
		local r, pending = LG.Items.Evaluate(link)
		if pending then return nil end
		return r ~= nil
	end)
	Bags.betterBagsItems = items
	local frame = addon:GetModule("ItemFrame", true)
	if frame and frame.itemProto and not Bags.betterBagsStyled then
		Bags.betterBagsStyled = true
		hooksecurefunc(frame.itemProto, "UpdateUpgrade", function(self, ctx)
			if items:GetActiveUpgradeProvider() ~= "LGGearUpgrades" then return end
			local decoration = self:GetDecoration(ctx)
			local icon = decoration and decoration.UpgradeIcon
			if not icon then return end
			icon:SetTexture(ARROW)
			icon:SetTexCoord(0, 1, 0, 1)
			icon:SetScale(1)
			icon:SetSize(16, 16)
			icon:ClearAllPoints()
			icon:SetPoint("BOTTOMLEFT", decoration, "BOTTOMLEFT", 2, 2)
		end)
	end
	if LG.db and not LG.db.betterBagsSelected then
		local database = addon:GetModule("Database", true)
		if database and database.SetUpgradeIconProvider and database.data and database.data.profile then
			database:SetUpgradeIconProvider("LGGearUpgrades")
			LG.db.betterBagsSelected = true
		end
	end
	Bags:RederiveBetterBags()
end

function Bags:RederiveBetterBags()
	local addon = BetterBagsAddon()
	if not (self.betterBagsItems and addon) then return end
	local ctx = addon:GetModule("Context"):New("LGGearUpgrades")
	addon:GetModule("Events"):SendMessage(ctx, "bags/Rederive", { buttons = true, categoriesUnchanged = true })
end
