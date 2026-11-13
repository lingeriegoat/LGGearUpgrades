local ADDON, LG = ...
_G.LGGearUpgrades = LG

local DEFAULTS = {
	stats = { ARMOR = true, STAMINA = true },
	armorTypes = { cloth = true, leather = true, mail = true, plate = true },
	weaponSlots = { mainhand = true, offhand = true, twohand = true, ranged = true },
	useMaxGold = false,
	maxGold = 100,
	allowHigherLevel = false,
	levelsAbove = 2,
	lastScan = 0,
	useAuctionator = true,
	useOtherScans = true,
	playSound = true,
}

local GLOBAL_DEFAULTS = { minimapHide = false, minimapAngle = 215 }

local UPGRADE_SOUND = "Interface\\AddOns\\LGGearUpgrades\\Media\\gruntling_horn_bb.ogg"
local ACCOUNT_ONLY = { saved = true, lastScan = true, betterBagsSelected = true, minimapHide = true, minimapAngle = true }

local initHooks = {}
function LG:OnInit(fn) initHooks[#initHooks + 1] = fn end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function LG:Print(msg)
	print("|cff33ff99LG Gear Upgrades:|r " .. msg)
end

function LG:PlayUpgradeSound()
	if not LG.db.playSound then return end
	PlaySoundFile(UPGRADE_SOUND, "Master")
end

local pending
function LG:SettingsChanged()
	if pending then return end
	pending = true
	C_Timer.After(0.3, function()
		pending = false
		LG.Items.ClearCache()
		LG.Bags:Refresh(true)
		LG.Auction:MarkStale()
	end)
end

SLASH_LGGEARUPGRADES1 = "/lgg"
SLASH_LGGEARUPGRADES2 = "/lggearupgrades"
SlashCmdList.LGGEARUPGRADES = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "scan" then
		LG.Auction:Scan()
	elseif msg == "sound" then
		PlaySoundFile(UPGRADE_SOUND, "Master")
	elseif msg == "" or msg == "options" or msg == "config" then
		LG.Options:Open()
	else
		LG:Print("/lgg - open settings; /lgg scan - scan the auction house (while it is open); /lgg sound - test the upgrade sound")
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		LGGearUpgradesDB = LGGearUpgradesDB or {}
		LG.global = LGGearUpgradesDB
		CopyDefaults(GLOBAL_DEFAULTS, LG.global)
		if not LGGearUpgradesCharDB then
			LGGearUpgradesCharDB = {}
			local legacy = {}
			for k, v in pairs(LGGearUpgradesDB or {}) do
				if not ACCOUNT_ONLY[k] then legacy[k] = v end
			end
			CopyDefaults(legacy, LGGearUpgradesCharDB)
		end
		LG.db = LGGearUpgradesCharDB
		CopyDefaults(DEFAULTS, LG.db)
		for _, fn in ipairs(initHooks) do fn() end
		f:UnregisterEvent("ADDON_LOADED")
	else
		LG:SettingsChanged()
	end
end)
