local _, LG = ...
local Items = {}
LG.Items = Items

local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local GetUniqueness = (C_Item and C_Item.GetItemUniquenessByID) or GetItemUniquenessByID

Items.STATS = {
	{ key = "STRENGTH", label = "Strength" },
	{ key = "AGILITY", label = "Agility" },
	{ key = "STAMINA", label = "Stamina" },
	{ key = "INTELLECT", label = "Intellect" },
	{ key = "SPIRIT", label = "Spirit" },
	{ key = "ARMOR", label = "Armor" },
	{ key = "HEALING", label = "Healing" },
	{ key = "SPELLPOWER", label = "Magic Dmg/Healing" },
	{ key = "DPS", label = "DPS" },
}
local LABEL = {}
for _, s in ipairs(Items.STATS) do LABEL[s.key] = s.label end

local RAW = {
	STRENGTH = { "ITEM_MOD_STRENGTH_SHORT" },
	AGILITY = { "ITEM_MOD_AGILITY_SHORT" },
	STAMINA = { "ITEM_MOD_STAMINA_SHORT" },
	INTELLECT = { "ITEM_MOD_INTELLECT_SHORT" },
	SPIRIT = { "ITEM_MOD_SPIRIT_SHORT" },
	ARMOR = { "RESISTANCE0_NAME" },
	DPS = { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" },
	HEALING = { "ITEM_MOD_HEALING_POWER_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
}
local SPELL_POWER = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" }

-- Forever reports "damage and healing" spell power as spell damage only, so read the tooltip.
local function DamageOnly(link)
	if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
	local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
	if not ok or not data or not data.lines then return false end
	for _, line in ipairs(data.lines) do
		local t = line.leftText and line.leftText:lower()
		if t and t:find("spell") and t:find("damage") then return not t:find("heal") end
	end
	return false
end

local function Max(raw, keys)
	local m = 0
	for _, k in ipairs(keys) do if (raw[k] or 0) > m then m = raw[k] end end
	return m
end

local statCache = {}
local function ReadStats(link)
	local cached = statCache[link]
	if cached then return cached end
	local raw = GetStats(link)
	if not raw then return nil end
	local out = {}
	for key, keys in pairs(RAW) do out[key] = Max(raw, keys) end
	out.SPELLPOWER = 0
	if out.HEALING == 0 then
		local sp = Max(raw, SPELL_POWER)
		if sp > 0 and not DamageOnly(link) then out.SPELLPOWER = sp end
	end
	statCache[link] = out
	return out
end

local SLOT = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}
local WEAPON_CATEGORY = {
	INVTYPE_WEAPON = "mainhand", INVTYPE_WEAPONMAINHAND = "mainhand", INVTYPE_2HWEAPON = "twohand",
	INVTYPE_WEAPONOFFHAND = "offhand", INVTYPE_SHIELD = "offhand", INVTYPE_HOLDABLE = "offhand",
	INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "ranged",
}
local WEAPON_LOCS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONOFFHAND = true }
Items.GROUPS = {
	"Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
	"Ring", "Trinket", "One-Handed", "Two-Handed", "Ranged", "Misc",
}
local GROUP_OF = {
	INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulders", INVTYPE_CLOAK = "Back",
	INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands",
	INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Ring",
	INVTYPE_TRINKET = "Trinket", INVTYPE_WEAPON = "One-Handed", INVTYPE_WEAPONMAINHAND = "One-Handed",
	INVTYPE_2HWEAPON = "Two-Handed", INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged",
	INVTYPE_THROWN = "Ranged", INVTYPE_WEAPONOFFHAND = "Misc", INVTYPE_SHIELD = "Misc", INVTYPE_HOLDABLE = "Misc",
}
Items.GROUP_INDEX = {}
for i, g in ipairs(Items.GROUPS) do Items.GROUP_INDEX[g] = i end
local ARMOR_TYPE = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate" }

Items.SLOT_NAMES = {
	[1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
	[8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket",
	[14] = "Trinket", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}

local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
-- weapon subclasses: 0 axe, 1 2h axe, 2 bow, 3 gun, 4 mace, 5 2h mace, 6 polearm, 7 sword, 8 2h sword,
-- 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand
local WEAPONS = {
	WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
	PALADIN = set(0, 1, 4, 5, 6, 7, 8),
	HUNTER = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
	ROGUE = set(2, 3, 4, 7, 13, 15, 16, 18),
	PRIEST = set(4, 10, 15, 19),
	SHAMAN = set(0, 1, 4, 5, 10, 13, 15),
	MAGE = set(7, 10, 15, 19),
	WARLOCK = set(7, 10, 15, 19),
	DRUID = set(4, 5, 10, 13, 15),
}
-- armor subclasses: 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield
local ARMOR = {
	WARRIOR = set(1, 2, 3, 4, 6), PALADIN = set(1, 2, 3, 4, 6), HUNTER = set(1, 2, 3),
	SHAMAN = set(1, 2, 3, 6), ROGUE = set(1, 2), DRUID = set(1, 2),
	PRIEST = set(1), MAGE = set(1), WARLOCK = set(1),
}
local LEARNED_AT_40 = { HUNTER = 3, SHAMAN = 3, WARRIOR = 4, PALADIN = 4 }

local function CanUseType(classID, subclassID, equipLoc)
	local class = select(2, UnitClass("player"))
	if classID == 2 then
		local w = WEAPONS[class]
		return not w or w[subclassID] == true
	elseif classID == 4 then
		if subclassID == 0 or equipLoc == "INVTYPE_CLOAK" then return true end
		local a = ARMOR[class]
		if not a then return true end
		if not a[subclassID] then return false end
		return not (LEARNED_AT_40[class] == subclassID and UnitLevel("player") < 40)
	end
	return true
end

function Items.PassesFilters(equipLoc, classID, subclassID)
	if not SLOT[equipLoc] then return false end
	local db = LG.db
	local cat = WEAPON_CATEGORY[equipLoc]
	if cat and not db.weaponSlots[cat] then return false end
	if classID == 4 and equipLoc ~= "INVTYPE_CLOAK" and ARMOR_TYPE[subclassID] and not db.armorTypes[ARMOR_TYPE[subclassID]] then
		return false
	end
	return CanUseType(classID, subclassID, equipLoc)
end

local function SelectedStats()
	local list = {}
	for _, s in ipairs(Items.STATS) do
		if LG.db.stats[s.key] then list[#list + 1] = s.key end
	end
	return list
end

local WEIGHT = { ARMOR = 0.01 }
local TICK_ONLY = { DPS = true, HEALING = true, SPELLPOWER = true }
local OFF_STAT = 0.5

local function Compare(new, old, selected)
	local on = {}
	for _, key in ipairs(selected) do on[key] = true end
	local deltas, sumNew, sumOld = {}, 0, 0
	for _, s in ipairs(Items.STATS) do
		local key = s.key
		if on[key] or not TICK_ONLY[key] then
			local n, o = new[key] or 0, old[key] or 0
			local w = WEIGHT[key] or 1
			-- unticked stats only count (at a discount) on the gear you already own
			sumNew = sumNew + (on[key] and n * w or 0)
			sumOld = sumOld + o * w * (on[key] and 1 or OFF_STAT)
			if math.abs(n - o) > 0.001 then deltas[#deltas + 1] = { key = key, delta = n - o } end
		end
	end
	return deltas, sumNew, sumOld
end

local function Num(v)
	return v == math.floor(v) and tostring(v) or ("%.1f"):format(v)
end

function Items.FormatDelta(g)
	return ("%s%s %s"):format(g.delta > 0 and "+" or "-", Num(math.abs(g.delta)), LABEL[g.key])
end

function Items.FormatGains(deltas)
	local parts = {}
	for _, g in ipairs(deltas) do
		parts[#parts + 1] = ("%s%s %s"):format(g.delta > 0 and "+" or "-", Num(math.abs(g.delta)), LABEL[g.key])
	end
	return table.concat(parts, ", ")
end

-- gains under 1% count as equal
function Items.Verdict(r)
	if not r then return nil end
	if r.gain > 0.001 and (not r.pct or r.pct >= 1) then return "better" end
	if r.gain < -0.001 and r.pct and r.pct <= -1 then return "worse" end
end

function Items.IsHuge(r)
	return r ~= nil and (r.pct == nil or r.pct >= 100)
end

function Items.FormatPct(r)
	if not r.pct then return "NEW" end
	return r.pct >= 999 and ">999%" or ("+%.0f%%"):format(r.pct)
end

local function IsUniqueOwned(itemID, slots)
	if not (GetUniqueness and itemID) then return false end
	local ok, isUnique = pcall(GetUniqueness, itemID)
	if not (ok and isUnique) then return false end
	for _, slot in ipairs(slots) do
		local eq = GetInventoryItemLink("player", slot)
		if eq and GetInstant(eq) == itemID then return true end
	end
	return false
end

local DUAL_WIELD_CLASSES = { WARRIOR = true, ROGUE = true, HUNTER = true, SHAMAN = true, DEATHKNIGHT = true, DEMONHUNTER = true, MONK = true }
local function CanDualWield()
	if IsPlayerSpell then return IsPlayerSpell(674) == true end
	return DUAL_WIELD_CLASSES[select(2, UnitClass("player"))] == true
end

-- The tooltip shows requirements you fail in red (wrong armor/weapon type, class, ...); level lines are handled separately.
local usableCache = {}
function Items.Usable(link)
	local c = usableCache[link]
	if c ~= nil then return c end
	local usable = true
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
		if ok and data and data.lines then
			for _, line in ipairs(data.lines) do
				for _, side in ipairs({ "left", "right" }) do
					local text, col = line[side .. "Text"], line[side .. "Color"]
					if text and col and (col.r or 0) > 0.85 and (col.g or 1) < 0.25 and (col.b or 1) < 0.25
						and not text:find("%d") then
						usable = false
					end
				end
			end
		end
	end
	usableCache[link] = usable
	return usable
end

local cache = {}
function Items.ClearCache()
	wipe(usableCache) wipe(cache) end

-- Best comparison against your equipped gear (gain may be negative), nil, or nil + "pending".
function Items.Rate(link)
	local c = cache[link]
	if c ~= nil then return c or nil end

	local itemID, _, _, equipLoc, _, classID, subclassID = GetInstant(link)
	if not (itemID and Items.PassesFilters(equipLoc, classID, subclassID)) then
		cache[link] = false
		return nil
	end
	local reqLevel = select(5, GetInfo(link))
	local new = ReadStats(link)
	if not (reqLevel and new) then return nil, "pending" end

	local db = LG.db
	local maxLevel = UnitLevel("player") + (db.allowHigherLevel and db.levelsAbove or 0)
	local selected = SelectedStats()
	if reqLevel > maxLevel or #selected == 0 then
		cache[link] = false
		return nil
	end

	local slots = SLOT[equipLoc]
	if #slots > 1 and equipLoc ~= "INVTYPE_WEAPON" and IsUniqueOwned(itemID, slots) then
		cache[link] = false
		return nil
	end

	local result
	local mh = GetInventoryItemLink("player", 16)
	local mhLoc = mh and select(4, GetInstant(mh))
	for _, slot in ipairs(slots) do
		local own = GetInventoryItemLink("player", slot)
		local eq = own
		if slot == 17 and not own and equipLoc ~= "INVTYPE_WEAPON" and mhLoc == "INVTYPE_2HWEAPON" then
			-- empty off-hand under a two-hander: compare against the two-hander it would replace
			eq = mh
		end
		local skip = false
		if slot == 17 then
			local ownLoc = own and select(4, GetInstant(own))
			if equipLoc == "INVTYPE_WEAPON" then
				if own then
					skip = not WEAPON_LOCS[ownLoc]
				else
					skip = mhLoc == "INVTYPE_2HWEAPON" or not CanDualWield()
				end
			elseif equipLoc == "INVTYPE_WEAPONOFFHAND" then
				skip = not (own and WEAPON_LOCS[ownLoc]) and not CanDualWield()
			end
		end
		if not skip then
			local old = eq and ReadStats(eq)
			if eq and not old then return nil, "pending" end
			local deltas, sumNew, sumOld = Compare(new, old or {}, selected)
			local gain = sumNew - sumOld
			if not result or gain > result.gain then
				result = {
					link = link, slot = slot, group = GROUP_OF[equipLoc], deltas = deltas, gain = gain, equipped = eq, reqLevel = reqLevel,
					pct = sumOld > 0 and gain / sumOld * 100 or nil,
				}
			end
		end
	end
	cache[link] = result or false
	return result
end

-- Upgrade table, nil (not an upgrade), or nil + "pending" (item data not loaded yet).
function Items.Evaluate(link)
	local r, pending = Items.Rate(link)
	if Items.Verdict(r) == "better" and Items.Usable(link) then return r end
	return nil, pending
end

function Items.Load(itemID, fn)
	local item = Item:CreateFromItemID(itemID)
	item:ContinueOnItemLoad(fn)
end
