-- Crowd-control break alerts: "Polymorph on X broken by Varian (Swipe)" in the aggro-alert
-- style (orange instead of red), optionally announced to party/raid chat for your own placed CC.
--
-- What counts as CC comes from CCData.lua, generated from this client's Spell.dbc: every
-- class/pet/talent CC that damage can break, in four categories (placed, fear, root, short) that
-- the settings page can switch on and off.
--
-- Two ways to see a break:
--   * SPELL_AURA_BROKEN / SPELL_AURA_BROKEN_SPELL, which name the breaker directly. The client
--     handles them, but no open-source 3.3.5 server core sends them (docs §26), so on Warmane
--     they may never fire;
--   * the CC being removed noticeably before it would have run out, within BREAK_WINDOW seconds
--     of the target taking damage; the last hitter is the breaker. The "before it would have run
--     out" check stops roots and fears that simply expire mid-fight from counting as breaks.
--     Fully absorbed hits count: the server breaks the CC before it checks the amount.

local ADDON, ns = ...

local band, format, pairs, select = bit.band, string.format, pairs, select
local GetTime, GetSpellInfo, GetPlayerInfoByGUID, UnitGUID, UnitExists, UnitAura =
	GetTime, GetSpellInfo, GetPlayerInfoByGUID, UnitGUID, UnitExists, UnitAura

local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local GROUP = bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)
local PET = COMBATLOG_OBJECT_TYPE_PET
local PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER

local BREAK_WINDOW = 1.0   -- seconds between the last hit and the CC disappearing
local EARLY_MARGIN = 0.75  -- must end at least this much before its expected end to be a break
local PVP_CAP = 10         -- CC on players lasts at most 10 s in 3.3.5
local FLUSH_INTERVAL = 0.25
local FORGET_AFTER = 90    -- seconds; no tracked CC lasts longer than 60
local CC_R, CC_G, CC_B = 1.0, 0.5, 0.1

-- Hungering Cold breaks on any damage except diseases (Spell.dbc dispel type 3):
-- Frost Fever, Blood Plague and Wandering Plague.
local HUNGERING_COLD = 51209
local DISEASES = { [55095] = true, [55078] = true, [50526] = true }

local CATEGORY_SETTING = { placed = "ccPlaced", fear = "ccFears", root = "ccRoots", short = "ccShort" }

local DAMAGE_EVENTS = {
	SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true,
	DAMAGE_SHIELD = true, DAMAGE_SPLIT = true,
}
-- Only their "ABSORB" form is damage; dodges, parries, misses and immunes don't break CC.
local MISSED_EVENTS = {
	SWING_MISSED = true, RANGE_MISSED = true, SPELL_MISSED = true, SPELL_PERIODIC_MISSED = true,
}

-- Units whose debuffs we can read to get a CC's real duration (talents, PvP limits, etc.).
local LOOKUP_UNITS = { "target", "focus", "mouseover", "pettarget" }
for i = 1, 4 do LOOKUP_UNITS[#LOOKUP_UNITS + 1] = "party" .. i .. "target" end

local module = {}
table.insert(ns.modules, module)

local active = {}   -- target guid -> { [spellId] = { cat, mine, group, seen, endsAt } }
local lastHit = {}  -- target guid -> { time, guid, name, flags, spell, ice = {same, non-disease hits} }
local pending = {}  -- grouped alerts waiting for the next flush
local playerGUID

---------------------------------------------------------------------------
-- Alert text
---------------------------------------------------------------------------
local function white(text) return "|cffffffff" .. text .. "|r" end

local function coloredBreaker(guid, name, flags)
	if band(flags, PET) > 0 then return white(name) .. " (pet)" end
	if guid and band(flags, PLAYER) > 0 then
		local _, class = GetPlayerInfoByGUID(guid)
		local c = class and RAID_CLASS_COLORS[class]
		if c then return format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name) end
	end
	return white(name)
end

local function queue(ccName, targetName, breakerGUID, breakerName, breakerFlags, breakSpell, entry)
	local key = ccName .. "\001" .. (breakerGUID or "") .. "\001" .. (breakSpell or "")
	local e = pending[key]
	if e then
		e.count = e.count + 1
		return
	end
	pending[key] = {
		cc = ccName, target = targetName or UNKNOWN, count = 1,
		announce = entry and entry.mine and entry.cat == "placed",
		guid = breakerGUID, name = breakerName or UNKNOWN, flags = breakerFlags or 0, spell = breakSpell,
	}
end

local function flush()
	for key, e in pairs(pending) do
		local target = e.count > 1 and format("%d targets", e.count) or e.target
		local how = e.spell and (" (" .. e.spell .. ")") or ""
		local text, chat
		if e.guid == playerGUID then
			text = format("You broke %s on %s%s", white(e.cc), white(target), how)
			chat = format("I broke %s on %s%s", e.cc, target, how)
		elseif band(e.flags, MINE) > 0 and band(e.flags, PET) > 0 then
			text = format("Your pet broke %s on %s%s", white(e.cc), white(target), how)
			chat = format("My pet broke %s on %s%s", e.cc, target, how)
		else
			text = format("%s on %s broken by %s%s", white(e.cc), white(target),
				coloredBreaker(e.guid, e.name, e.flags), how)
			chat = format("%s on %s broken by %s%s", e.cc, target, e.name, how)
		end
		ns.Announce(text, CC_R, CC_G, CC_B)

		if ns.db.ccAnnounce and e.announce then
			if GetNumRaidMembers() > 0 then
				SendChatMessage(chat, "RAID")
			elseif GetNumPartyMembers() > 0 then
				SendChatMessage(chat, "PARTY")
			end
		end
		pending[key] = nil
	end
end

---------------------------------------------------------------------------
-- Durations
---------------------------------------------------------------------------
-- The real remaining time if a visible unit token has the debuff, else the base duration.
local function expectedEnd(dstGUID, dstFlags, spellId, baseDuration)
	local now = GetTime()
	for i = 1, #LOOKUP_UNITS do
		local unit = LOOKUP_UNITS[i]
		if UnitExists(unit) and UnitGUID(unit) == dstGUID then
			for index = 1, 40 do
				local name, _, _, _, _, _, expirationTime, _, _, _, id = UnitAura(unit, index, "HARMFUL")
				if not name then break end
				if id == spellId and expirationTime and expirationTime > 0 then
					return expirationTime
				end
			end
		end
	end
	local secs = baseDuration
	if band(dstFlags, PLAYER) > 0 and secs > PVP_CAP then secs = PVP_CAP end
	return now + secs
end

---------------------------------------------------------------------------
-- Combat log
---------------------------------------------------------------------------
local function shouldReport(entry)
	if not ns.db.ccAlerts then return false end
	if entry and not ns.db[CATEGORY_SETTING[entry.cat]] then return false end
	if ns.db.ccScope == "mine" then return entry ~= nil and entry.mine end
	return entry == nil or entry.group
end

local function report(dstGUID, dstName, spellId, ccName, breakerGUID, breakerName, breakerFlags, breakSpell)
	local auras = active[dstGUID]
	local entry = auras and auras[spellId]
	if auras then
		auras[spellId] = nil
		if not next(auras) then active[dstGUID], lastHit[dstGUID] = nil, nil end
	end
	if entry == nil and not ns.CC_SPELLS[spellId] then return end
	if entry == nil and not ns.db[CATEGORY_SETTING[ns.CC_SPELLS[spellId][1]]] then return end
	if shouldReport(entry) then
		queue(ccName, dstName, breakerGUID, breakerName, breakerFlags, breakSpell, entry)
	end
end

local function onCombatLog(timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if not dstGUID then return end
	srcFlags, dstFlags = srcFlags or 0, dstFlags or 0

	if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
		local spellId, _, _, auraType = ...
		local data = ns.CC_SPELLS[spellId]
		if data and auraType == "DEBUFF" and band(dstFlags, HOSTILE) > 0 then
			active[dstGUID] = active[dstGUID] or {}
			active[dstGUID][spellId] = {
				cat = data[1], mine = band(srcFlags, MINE) > 0, group = band(srcFlags, GROUP) > 0,
				seen = GetTime(), endsAt = expectedEnd(dstGUID, dstFlags, spellId, data[2]),
			}
		end

	elseif DAMAGE_EVENTS[subevent] or MISSED_EVENTS[subevent] then
		if not active[dstGUID] then return end -- only CC'd targets matter
		local swing = subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED"
		if MISSED_EVENTS[subevent] then
			local missType = swing and ... or select(4, ...)
			if missType ~= "ABSORB" then return end
		end
		local spellId, spell
		if swing then spell = "melee" else spellId, spell = ... end
		local hit = lastHit[dstGUID] or {}
		lastHit[dstGUID] = hit
		hit.time, hit.guid, hit.name, hit.flags, hit.spell = timestamp, srcGUID, srcName, srcFlags, spell
		if not DISEASES[spellId] then
			hit.ice = hit.ice or {}
			local d = hit.ice
			d.time, d.guid, d.name, d.flags, d.spell = timestamp, srcGUID, srcName, srcFlags, spell
		end

	elseif subevent == "SPELL_AURA_BROKEN" then
		local spellId, spellName = ...
		report(dstGUID, dstName, spellId, spellName, srcGUID, srcName, srcFlags, "melee")

	elseif subevent == "SPELL_AURA_BROKEN_SPELL" then
		local spellId, spellName, _, _, breakSpell = ...
		report(dstGUID, dstName, spellId, spellName, srcGUID, srcName, srcFlags, breakSpell)

	elseif subevent == "SPELL_DISPEL" or subevent == "SPELL_STOLEN" then
		local _, _, _, removedId = ...
		local auras = active[dstGUID]
		if auras and removedId then auras[removedId] = nil end -- dispelled, not broken

	elseif subevent == "SPELL_AURA_REMOVED" then
		local spellId, spellName = ...
		local auras = active[dstGUID]
		local entry = auras and auras[spellId]
		if not entry then return end -- already reported, or not tracked
		local hit = lastHit[dstGUID]
		if hit and spellId == HUNGERING_COLD then hit = hit.ice end
		local early = GetTime() < entry.endsAt - EARLY_MARGIN
		if early and hit and timestamp - hit.time <= BREAK_WINDOW then
			report(dstGUID, dstName, spellId, spellName, hit.guid, hit.name, hit.flags, hit.spell)
		else
			auras[spellId] = nil -- ran its course (or no damage to blame)
		end

	elseif subevent == "UNIT_DIED" then
		active[dstGUID], lastHit[dstGUID] = nil, nil
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
function module:Init()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:SetScript("OnEvent", function(_, _, ...)
		playerGUID = playerGUID or UnitGUID("player")
		onCombatLog(...)
	end)

	local sinceFlush, sincePrune = 0, 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		sinceFlush, sincePrune = sinceFlush + elapsed, sincePrune + elapsed
		if sinceFlush >= FLUSH_INTERVAL then
			sinceFlush = 0
			if next(pending) then flush() end
		end
		if sincePrune >= 15 then -- forget CC we never saw end (target left range, etc.)
			sincePrune = 0
			local now = GetTime()
			for guid, auras in pairs(active) do
				for id, entry in pairs(auras) do
					if now - entry.seen > FORGET_AFTER then auras[id] = nil end
				end
				if not next(auras) then active[guid], lastHit[guid] = nil, nil end
			end
		end
	end)
end

function module:Preview()
	ns.Announce(format("%s on %s broken by %s (Swipe)", white("Polymorph"), white("Shattered Hand Reaver"),
		coloredBreaker(nil, "Varian", 0)), CC_R, CC_G, CC_B)
end

-- /tm cc opens the Crowd Control settings page; /tm cc test shows a sample alert.
ns.commands.cc = function(a)
	if a == "test" then
		module:Preview()
	elseif ns.OpenOptions then
		ns.OpenOptions("cc")
	end
end

-- Spell names per category as this client names them, for the settings page.
function ns.TrackedCCNames(category)
	local seen, list = {}, {}
	for id, data in pairs(ns.CC_SPELLS) do
		if data[1] == category then
			local name = GetSpellInfo(id)
			name = name and (name:match("^(.-) %- ") or name) -- "Polymorph - Penguin" is listed as Polymorph
			if name and not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
	end
	table.sort(list)
	return list
end
