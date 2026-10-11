-- Optional nameplate threat % (off by default; /tm plates on). Only visible while
-- nameplates are shown (V).
--
-- 3.3.5 nameplates are unnamed WorldFrame children with no unit token, and threat can only be
-- queried for a unit token. So each plate is matched to a unit we *can* query: target (the one
-- full-alpha plate), mouseover (highlighted plate), raid markers, then name + health % against
-- focus / pet / party / raid targets. Unmatched plates show nothing.

local ADDON, ns = ...

local floor, abs, select, pairs, wipe = math.floor, math.abs, select, pairs, wipe
local GetTime, UnitExists, UnitGUID, UnitName, UnitCanAttack, UnitIsDead =
	GetTime, UnitExists, UnitGUID, UnitName, UnitCanAttack, UnitIsDead
local UnitHealth, UnitHealthMax, GetRaidTargetIndex = UnitHealth, UnitHealthMax, GetRaidTargetIndex
local UnitDetailedThreatSituation, GetThreatStatusColor = UnitDetailedThreatSituation, GetThreatStatusColor
local WorldFrame = WorldFrame

local PLATE_GLOW_TEXTURE = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]]
local UPDATE_INTERVAL = 0.1

local module = {}
table.insert(ns.modules, module)

local db
local driver
local plates = {}       -- plate frame -> record
local guidToPlate = {}  -- guid -> record
local unitByGUID = {}   -- guid -> queryable unit token (rebuilt every tick)
local knownChildren = {}
local numChildren = 0

---------------------------------------------------------------------------
-- Unit tokens we can ask about (built once, no per-tick string garbage)
---------------------------------------------------------------------------
local SOLO_UNITS = { "target", "focus", "mouseover", "pettarget" }
local PARTY_UNITS, RAID_UNITS = {}, {}
for i = 1, 4 do
	PARTY_UNITS[#PARTY_UNITS + 1] = "party" .. i .. "target"
	PARTY_UNITS[#PARTY_UNITS + 1] = "partypet" .. i .. "target"
end
for i = 1, 40 do
	RAID_UNITS[#RAID_UNITS + 1] = "raid" .. i .. "target"
end

local function addUnit(unit)
	if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit) then
		local guid = UnitGUID(unit)
		if guid and not unitByGUID[guid] then
			unitByGUID[guid] = unit
		end
	end
end

local function rebuildUnits()
	wipe(unitByGUID)
	for i = 1, #SOLO_UNITS do addUnit(SOLO_UNITS[i]) end
	if GetNumRaidMembers() > 0 then
		for i = 1, GetNumRaidMembers() do addUnit(RAID_UNITS[i]) end
	elseif GetNumPartyMembers() > 0 then
		for i = 1, #PARTY_UNITS do addUnit(PARTY_UNITS[i]) end
	end
end

---------------------------------------------------------------------------
-- Plates
---------------------------------------------------------------------------
local function isNamePlate(frame)
	if frame:GetName() then return false end
	local glow = frame:GetRegions()
	return glow and glow:GetObjectType() == "Texture" and glow:GetTexture() == PLATE_GLOW_TEXTURE
end

local function applyStyle(rec)
	local font, size = rec.level:GetFont()
	rec.text:SetFont(font or [[Fonts\FRIZQT__.TTF]], (size or 10) * db.plateFontScale, "OUTLINE")
	rec.text:ClearAllPoints()
	rec.text:SetPoint("TOPLEFT", rec.health, "BOTTOMRIGHT", db.plateX, db.plateY)
end

local function forget(rec)
	if rec.guid and guidToPlate[rec.guid] == rec then
		guidToPlate[rec.guid] = nil
	end
	rec.guid, rec.pct, rec.status, rec.seen = nil, nil, nil, nil
	rec.text:Hide()
end

local function setupPlate(frame)
	local health = frame:GetChildren()
	local _, _, _, _, _, highlight, name, level, _, raidIcon = frame:GetRegions()
	local rec = {
		frame = frame, health = health, highlight = highlight,
		name = name, level = level, raidIcon = raidIcon,
		text = frame:CreateFontString(nil, "OVERLAY"),
	}
	rec.text:Hide()
	applyStyle(rec)
	frame:HookScript("OnHide", function() forget(rec) end)
	plates[frame] = rec
end

local function scanWorldFrame()
	local n = select("#", WorldFrame:GetChildren()) -- same count DiabolicUI's 3.3.5 code uses
	if n == numChildren then return end
	numChildren = n
	local children = { WorldFrame:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		if not knownChildren[child] then
			knownChildren[child] = true
			if isNamePlate(child) then setupPlate(child) end
		end
	end
end

---------------------------------------------------------------------------
-- Matching plates to units
---------------------------------------------------------------------------
local function assign(rec, guid)
	local old = guidToPlate[guid]
	if old and old ~= rec then
		old.guid, old.pct = nil, nil
	end
	if rec.guid ~= guid then
		if rec.guid and guidToPlate[rec.guid] == rec then guidToPlate[rec.guid] = nil end
		rec.guid, rec.pct = guid, nil
	end
	guidToPlate[guid] = rec
end

-- Assigns guid to the single shown plate for which test(rec) is true.
local function assignUnique(guid, test)
	local found
	for _, rec in pairs(plates) do
		if rec.frame:IsShown() and test(rec) then
			if found then return end -- ambiguous
			found = rec
		end
	end
	if found then assign(found, guid) end
end

local function healthFraction(rec)
	local _, max = rec.health:GetMinMaxValues()
	if not max or max <= 0 then return nil end
	return rec.health:GetValue() / max
end

local function raidIconIndex(rec)
	if not rec.raidIcon:IsShown() or not rec.raidIcon.GetTexCoord then return nil end
	local left, top = rec.raidIcon:GetTexCoord()
	return floor(top * 4 + 0.5) * 4 + floor(left * 4 + 0.5) + 1
end

-- Matchers read these upvalues so the 10-per-second loop allocates no closures.
local matchIcon, matchName, matchHealth
local function isFullAlpha(rec) return rec.frame:GetAlpha() == 1 end
local function isHighlighted(rec) return rec.highlight:IsShown() end
local function hasMatchIcon(rec) return raidIconIndex(rec) == matchIcon end
local function hasMatchNameAndHealth(rec)
	if rec.guid or rec.name:GetText() ~= matchName then return false end
	local f = healthFraction(rec)
	return f and abs(f - matchHealth) < 0.01
end

local function identifyPlates()
	local guid = UnitExists("target") and UnitCanAttack("player", "target") and UnitGUID("target")
	if guid then assignUnique(guid, isFullAlpha) end

	guid = UnitExists("mouseover") and UnitCanAttack("player", "mouseover") and UnitGUID("mouseover")
	if guid then assignUnique(guid, isHighlighted) end

	for g, unit in pairs(unitByGUID) do
		matchIcon = GetRaidTargetIndex(unit)
		if matchIcon then assignUnique(g, hasMatchIcon) end
	end

	for g, unit in pairs(unitByGUID) do
		local rec = guidToPlate[g]
		matchName = UnitName(unit)
		if rec and rec.name:GetText() ~= matchName then
			forget(rec) -- plate now shows a different mob
			rec = nil
		end
		local max = UnitHealthMax(unit)
		if not rec and max > 0 then
			matchHealth = UnitHealth(unit) / max
			assignUnique(g, hasMatchNameAndHealth)
		end
	end
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------
local function show(rec, pct, status, alpha)
	rec.text:SetFormattedText("%d%%", floor(pct))
	rec.text:SetTextColor(GetThreatStatusColor(status))
	rec.text:SetAlpha(alpha)
	rec.text:Show()
end

local function render(rec, now)
	if ns.IsPreviewing() then
		show(rec, 75, 2, 1)
		return
	end
	local unit = rec.guid and unitByGUID[rec.guid]
	if unit then
		local _, status, pct = UnitDetailedThreatSituation("player", unit)
		if pct and pct > 0 then
			rec.pct, rec.status, rec.seen = pct, status, now
			show(rec, pct, status, 1)
		else
			rec.pct = nil
			rec.text:Hide()
		end
	elseif rec.pct and now - rec.seen <= db.staleSeconds then
		show(rec, rec.pct, rec.status, 0.5)
	else
		rec.text:Hide()
	end
end

local elapsedSince = 0
local function onUpdate(self, elapsed)
	elapsedSince = elapsedSince + elapsed
	if elapsedSince < UPDATE_INTERVAL then return end
	elapsedSince = 0

	scanWorldFrame()
	rebuildUnits()
	identifyPlates()

	local now = GetTime()
	for frame, rec in pairs(plates) do
		if frame:IsShown() then render(rec, now) end
	end
end

function module:Refresh()
	for _, rec in pairs(plates) do applyStyle(rec) end
	driver:SetScript("OnUpdate", db.plates and onUpdate or nil)
	if not db.plates then
		for _, rec in pairs(plates) do rec.text:Hide() end
	end
end

function module:Init()
	db = ns.db
	driver = CreateFrame("Frame")
	self:Refresh()
end
