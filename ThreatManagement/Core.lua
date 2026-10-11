-- ThreatManagement core: settings, preview mode, slash command, module startup.
-- The number shown everywhere is the one Blizzard puts on the target frame:
-- UnitDetailedThreatSituation("player", unit) 3rd return, coloured by GetThreatStatusColor.

local ADDON, ns = ...

local SETTINGS_VERSION = 2 -- v0.1 stored nameplate offsets under x/y; start fresh

ns.DEFAULTS = {
	version = SETTINGS_VERSION,
	enabled = true,      -- target frame text
	x = 0,               -- offset from below the target portrait
	y = -8,
	fontScale = 1,
	plates = false,      -- nameplate text (only visible while nameplates are on, V)
	plateX = 3,
	plateY = -1,
	plateFontScale = 0.9,
	staleSeconds = 3,
	alerts = true,       -- "<Mob> is attacking you!" below Blizzard's error text
	alertSound = false,
	alertScale = 1.35,   -- relative to Blizzard's error text font (ErrorFont)
	ccAlerts = true,     -- "Polymorph on X broken by Y" (CCBreaks.lua)
	ccScope = "group",   -- "group" = anyone's CC in your party/raid, "mine" = only yours
	ccAnnounce = false,  -- also say breaks of your own placed CC in party/raid chat
	ccPlaced = true,     -- categories from CCData.lua (all tracked by default)
	ccFears = true,
	ccRoots = true,
	ccShort = true,
}

ns.modules = {}
ns.commands = {}         -- extra /tm sub-commands registered by modules
ns.previewUntil = 0

function ns.say(msg)
	print("|cffffd200ThreatManagement|r: " .. msg)
end

function ns.IsPreviewing()
	return GetTime() < ns.previewUntil
end

local function refreshAll()
	for _, module in ipairs(ns.modules) do
		if module.Refresh then module:Refresh() end
	end
end
ns.RefreshAll = refreshAll

function ns.StartPreview()
	ns.previewUntil = GetTime() + 20
	for _, module in ipairs(ns.modules) do
		if module.Preview then module:Preview() end
	end
end

function ns.ResetDefaults()
	wipe(ns.db)
	for k, v in pairs(ns.DEFAULTS) do ns.db[k] = v end
	refreshAll()
end

---------------------------------------------------------------------------
-- /tm
---------------------------------------------------------------------------
local function setNumber(key, value, low, high)
	value = tonumber(value)
	if not value then return false end
	if low then value = math.max(low, math.min(high, value)) end
	ns.db[key] = value
	return true
end

SLASH_THREATMANAGEMENT1 = "/tm"
SLASH_THREATMANAGEMENT2 = "/threatmanagement"
SlashCmdList.THREATMANAGEMENT = function(msg)
	local db = ns.db
	local cmd, a, b = strsplit(" ", msg:lower())
	if cmd == "" and ns.OpenOptions then
		ns.OpenOptions()
		return
	elseif ns.commands[cmd] then
		ns.commands[cmd](a, b)
	elseif cmd == "test" then
		ns.StartPreview()
		ns.say("showing a sample 75% for 20 seconds (target something to see it on the target frame).")
	elseif cmd == "pos" and setNumber("x", a) and setNumber("y", b) then
		ns.say(string.format("target frame text offset set to %d, %d.", db.x, db.y))
	elseif cmd == "size" and setNumber("fontScale", a, 0.5, 2) then
		ns.say(string.format("target frame text size set to %.2f.", db.fontScale))
	elseif cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
		ns.say("target frame threat " .. (db.enabled and "enabled." or "disabled."))
	elseif cmd == "plates" and (a == "on" or a == "off") then
		db.plates = (a == "on")
		ns.say("nameplate threat " .. (db.plates and "enabled (press V to show nameplates)." or "disabled."))
	elseif cmd == "platepos" and setNumber("plateX", a) and setNumber("plateY", b) then
		ns.say(string.format("nameplate text offset set to %d, %d.", db.plateX, db.plateY))
	elseif cmd == "platesize" and setNumber("plateFontScale", a, 0.5, 2) then
		ns.say(string.format("nameplate text size set to %.2f.", db.plateFontScale))
	elseif cmd == "stale" and setNumber("staleSeconds", a, 0, 30) then
		ns.say(string.format("nameplates keep a faded last value for %d seconds.", db.staleSeconds))
	elseif cmd == "blizzard" and (a == "on" or a == "off") then
		SetCVar("threatShowNumeric", a == "on" and "1" or "0")
		ns.say("Blizzard's threat box above the target frame turned " .. a .. ".")
	elseif cmd == "reset" then
		ns.ResetDefaults()
		ns.say("settings reset.")
	else -- "help" or anything unrecognised
		ns.say("/tm opens the settings panel (Interface > AddOns > ThreatManagement).")
		ns.say(string.format("target %s (pos %d %d, size %.2f) | nameplates %s (pos %d %d, size %.2f, stale %ds)",
			db.enabled and "on" or "off", db.x, db.y, db.fontScale,
			db.plates and "on" or "off", db.plateX, db.plateY, db.plateFontScale, db.staleSeconds))
		ns.say("/tm test | pos <x> <y> | size <n> | on | off | blizzard on|off")
		ns.say("/tm plates on|off | platepos <x> <y> | platesize <n> | stale <sec> | reset")
		ns.say("/tm alerts on|off | alerts sound on|off | alerts size <n> | alerts test")
		ns.say("/tm cc (crowd control settings) | cc test")
		return
	end
	refreshAll()
end

---------------------------------------------------------------------------
-- Startup: SavedVariables exist only once ADDON_LOADED fires for us.
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")

	local db = ThreatManagementDB
	if type(db) ~= "table" or db.version ~= SETTINGS_VERSION then
		db = {}
		ThreatManagementDB = db
	end
	for k, v in pairs(ns.DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	ns.db = db

	for _, module in ipairs(ns.modules) do module:Init() end
end)
