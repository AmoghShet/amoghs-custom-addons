-- Aggro alerts: "<Mob> is attacking you!" in the same style and screen area as Blizzard's
-- red error text (and DBM's warnings), on a separate frame just below UIErrorsFrame so error
-- spam can't push the alert out.
--
-- A mob counts as attacking you when either:
--   * the combat log shows it melee/ranged auto-attacking you (works for every mob), or
--   * a unit we can see (target, focus, mouseover, party/raid targets) is targeting you.
-- Spell damage alone doesn't count, because boss AoE would then look like aggro.
-- Each mob alerts once per "aggro episode" (no contact for EPISODE_GAP seconds ends it).
-- Solo, a mob you hit first doesn't alert (you pulled it); in a group every new attacker does.

local ADDON, ns = ...

local band, format, wipe = bit.band, string.format, wipe
local GetTime, UnitGUID, UnitName, UnitExists, UnitIsUnit, UnitCanAttack, UnitIsDead, UnitAffectingCombat =
	GetTime, UnitGUID, UnitName, UnitExists, UnitIsUnit, UnitCanAttack, UnitIsDead, UnitAffectingCombat

local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local NPC = COMBATLOG_OBJECT_CONTROL_NPC
local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local EPISODE_GAP = 10
local POLL_INTERVAL = 0.25
local ALERT_R, ALERT_G, ALERT_B = 1.0, 0.1, 0.1 -- Blizzard's UI_ERROR_MESSAGE red

local AUTO_ATTACKS = { SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true, RANGE_MISSED = true }

local module = {}
table.insert(ns.modules, module)

local messages
local playerGUID
local lastContact = {} -- mob guid -> last time it hit or targeted the player
local hitByMe = {}     -- mob guid -> true once the player or their pet acted on it
local pending, pendingCount = {}, 0

-- { unit, unit .. "target" } pairs, built once so polling makes no strings
local WATCHED = {}
local function watch(unit) WATCHED[#WATCHED + 1] = { unit, unit .. "target" } end
for _, unit in ipairs({ "target", "focus", "mouseover", "pettarget" }) do watch(unit) end
for i = 1, 4 do
	watch("party" .. i .. "target")
	watch("partypet" .. i .. "target")
end
for i = 1, 40 do watch("raid" .. i .. "target") end

local function inGroup()
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

local function noteAttacker(guid, name, now)
	local last = lastContact[guid]
	lastContact[guid] = now
	if last and now - last <= EPISODE_GAP then return end -- same aggro episode
	if not ns.db.alerts then return end
	if not inGroup() and hitByMe[guid] then return end    -- solo: you pulled it yourself
	pendingCount = pendingCount + 1
	pending[pendingCount] = name or UNKNOWN
end

local function announce(msg, r, g, b)
	messages:AddMessage(msg, r or ALERT_R, g or ALERT_G, b or ALERT_B, 1.0)
	if ns.db.alertSound then PlaySound("RaidWarning") end
end
ns.Announce = announce -- shared with other alert modules (e.g. CCBreaks.lua)

local function flush()
	if pendingCount == 0 then return end
	local first = "|cffffffff" .. pending[1] .. "|r"
	if pendingCount == 1 then
		announce(format("%s is attacking you!", first))
	elseif pendingCount == 2 then
		announce(format("%s and |cffffffff%s|r are attacking you!", first, pending[2]))
	else
		announce(format("%s and %d others are attacking you!", first, pendingCount - 1))
	end
	wipe(pending)
	pendingCount = 0
end

local function poll(now)
	for i = 1, #WATCHED do
		local unit, unitTarget = WATCHED[i][1], WATCHED[i][2]
		if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit)
			and UnitAffectingCombat(unit) and UnitIsUnit(unitTarget, "player") then
			noteAttacker(UnitGUID(unit), UnitName(unit), now)
		end
	end
end

local function onCombatLog(timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags)
	playerGUID = playerGUID or UnitGUID("player")
	srcFlags, dstFlags = srcFlags or 0, dstFlags or 0 -- e.g. environmental events have no real source
	if not dstGUID then return end
	if subevent == "UNIT_DIED" then
		lastContact[dstGUID], hitByMe[dstGUID] = nil, nil
	elseif dstGUID == playerGUID and AUTO_ATTACKS[subevent] and srcGUID
		and band(srcFlags, HOSTILE) > 0 and band(srcFlags, NPC) > 0 then
		noteAttacker(srcGUID, srcName, GetTime())
	elseif band(srcFlags, MINE) > 0 and band(dstFlags, HOSTILE) > 0 then
		hitByMe[dstGUID] = true
	end
end

function module:Init()
	messages = CreateFrame("MessageFrame", "ThreatManagementAlertFrame", UIParent)
	messages:SetSize(512, 60)
	messages:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, 0)
	messages:SetFrameStrata("HIGH")
	messages:SetFontObject(ErrorFont)
	messages:SetJustifyH("CENTER")
	messages:SetInsertMode("TOP")
	messages:SetTimeVisible(5)
	self:Refresh()

	local elapsedSince = 0
	messages:SetScript("OnUpdate", function(_, elapsed)
		elapsedSince = elapsedSince + elapsed
		if elapsedSince < POLL_INTERVAL then return end
		elapsedSince = 0
		if UnitAffectingCombat("player") then poll(GetTime()) end
		flush()
	end)

	messages:SetScript("OnEvent", function(_, event, ...)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			onCombatLog(...)
		else -- PLAYER_REGEN_ENABLED: combat over, every mob starts a fresh episode next time
			wipe(lastContact)
			wipe(hitByMe)
		end
	end)
	messages:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	messages:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Same font as Blizzard's error text, scaled up so it stands out in combat.
function module:Refresh()
	local font, size, flags = ErrorFont:GetFont()
	local scale = ns.db.alertScale
	messages:SetFont(font or [[Fonts\FRIZQT__.TTF]], (size or 16) * scale, flags)
	messages:SetHeight(60 * scale)
end

function module:Preview()
	announce("|cffffffffDeranged Helboar|r is attacking you!")
end

ns.commands.alerts = function(a, b)
	local db = ns.db
	if a == "on" or a == "off" then
		db.alerts = (a == "on")
		ns.say("aggro alerts " .. (db.alerts and "enabled." or "disabled."))
	elseif a == "sound" and (b == "on" or b == "off") then
		db.alertSound = (b == "on")
		ns.say("aggro alert sound " .. b .. ".")
	elseif a == "size" and tonumber(b) then
		db.alertScale = math.max(0.8, math.min(2.5, tonumber(b)))
		module:Refresh()
		module:Preview()
	elseif a == "test" then
		module:Preview()
	else
		ns.say(format("aggro alerts %s, sound %s, size %.2f. /tm alerts on|off | sound on|off | size <n> | test",
			db.alerts and "on" or "off", db.alertSound and "on" or "off", db.alertScale))
	end
end
