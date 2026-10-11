-- ClientProbe: records facts about this 3.3.5a client into ClientProbeDB.
-- Results are written to WTF\Account\<ACCT>\SavedVariables\ClientProbe.lua on /reload or logout.
-- Every risky call is wrapped in pcall so the probe itself never breaks.

local ADDON = ...
local LUA_MARKER = "B" -- changed between login and /reload to test what /reload re-reads

local floor, pcall, select, type, tostring = math.floor, pcall, select, type, tostring

local function repr(v)
	local t = type(v)
	if t == "nil" then return "nil" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" or t == "string" then return t .. ":" .. tostring(v) end
	return t
end

local hasProfiler = type(debugprofilestop) == "function"
local t0 = hasProfiler and debugprofilestop() or 0
local function elapsedMs()
	return hasProfiler and floor(debugprofilestop() - t0) or -1
end

local function talentPoints()
	local ok, _, _, points = pcall(GetTalentTabInfo, 1)
	return ok and repr(points) or "error"
end

---------------------------------------------------------------------------
-- Event order (events before our ADDON_LOADED are buffered)
---------------------------------------------------------------------------
local run
local pending = {}
local function logEvent(event, info)
	local entry = { e = event, ms = elapsedMs(), t = GetTime(), talents = talentPoints(), info = info }
	if run then
		run.events[#run.events + 1] = entry
	else
		pending[#pending + 1] = entry
	end
end

---------------------------------------------------------------------------
-- Probes
---------------------------------------------------------------------------
local GLOBALS = {
	"os", "io", "bit", "coroutine", "debug", "loadstring", "getfenv", "setfenv", "collectgarbage",
	"gcinfo", "newproxy", "debugprofilestart", "debugprofilestop", "date", "time", "difftime", "print",
	"wipe", "tContains", "strsplit", "strjoin", "strtrim", "hooksecurefunc", "issecurevariable",
	"securecall", "C_Timer", "Mixin", "CreateFromMixins", "GetNumGroupMembers", "IsInGroup", "IsInRaid",
	"GetNumRaidMembers", "GetNumPartyMembers", "RegisterAddonMessagePrefix", "SendAddonMessage",
	"CombatLogGetCurrentEventInfo", "UnitGetIncomingHeals", "RegisterAttributeDriver", "RegisterStateDriver",
	"RegisterUnitWatch", "GetFunctionCPUUsage", "GetFrameCPUUsage", "GetEventCPUUsage", "GetAddOnCPUUsage",
	"UpdateAddOnMemoryUsage", "GetAddOnMetadata", "InterfaceOptions_AddCategory", "UnitIsTapDenied",
}

local function probeEnvironment()
	local env = { _VERSION = _VERSION, build = { GetBuildInfo() }, globals = {} }
	for i = 1, #GLOBALS do
		env.globals[GLOBALS[i]] = type(_G[GLOBALS[i]])
	end
	if type(bit) == "table" then
		local names = {}
		for k in pairs(bit) do names[#names + 1] = k end
		table.sort(names)
		env.bitFunctions = table.concat(names, ",")
	end
	env.InCombatLockdown_outOfCombat = repr(InCombatLockdown())
	return env
end

local function hasMethod(obj, name) return type(obj[name]) == "function" end

local function probeWidgets()
	local w = {}
	local f = CreateFrame("Frame", nil, UIParent)
	f:Hide()
	for _, m in ipairs({ "SetSize", "SetShown", "SetBackdrop", "SetMinResize", "SetMaxResize", "SetResizeBounds",
		"SetClampRectInsets", "HookScript", "IsEventRegistered", "SetClipsChildren", "CreateAnimationGroup" }) do
		w["Frame:" .. m] = hasMethod(f, m)
	end

	local tex = f:CreateTexture(nil, "ARTWORK")
	for _, m in ipairs({ "SetColorTexture", "SetGradient", "SetGradientAlpha", "SetDesaturated", "SetRotation",
		"SetAtlas", "SetBlendMode", "SetVertexColor" }) do
		w["Texture:" .. m] = hasMethod(tex, m)
	end
	w["Texture:SetTexture(r,g,b,a)"] = pcall(tex.SetTexture, tex, 1, 0, 0, 1)
	w["Texture:SetDrawLayer(layer, sublevel)"] = pcall(tex.SetDrawLayer, tex, "ARTWORK", 2)
	w["Texture:GetDrawLayer #returns"] = select("#", tex:GetDrawLayer())

	local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	w["FontString:SetFormattedText"] = hasMethod(fs, "SetFormattedText")

	local ag = f:CreateAnimationGroup()
	for _, kind in ipairs({ "Alpha", "Scale", "Translation", "Translate", "Rotation", "Path" }) do
		w["CreateAnimation(" .. kind .. ")"] = pcall(ag.CreateAnimation, ag, kind)
	end
	local okAlpha, alpha = pcall(ag.CreateAnimation, ag, "Alpha")
	if okAlpha then
		w["Alpha:SetChange"] = hasMethod(alpha, "SetChange")
		w["Alpha:SetFromAlpha"] = hasMethod(alpha, "SetFromAlpha")
	end
	return w
end

-- Which way does implicit protection flow? Must run out of combat.
local function probeProtection()
	local p = {}
	local function prot(frame)
		local a, b = frame:IsProtected()
		return repr(a) .. " | " .. repr(b)
	end
	local plain = CreateFrame("Frame", nil, UIParent)
	local secure = CreateFrame("Button", "ClientProbeSecure1", UIParent, "SecureActionButtonTemplate")
	local anchorTarget = CreateFrame("Frame", nil, UIParent)
	local anchoredToSecure = CreateFrame("Frame", nil, UIParent)
	local parentOfSecure = CreateFrame("Frame", nil, UIParent)
	local childSecure = CreateFrame("Button", "ClientProbeSecure2", parentOfSecure, "SecureActionButtonTemplate")
	local insecureChildOfSecure = CreateFrame("Frame", nil, secure)

	secure:SetPoint("CENTER", anchorTarget, "CENTER")
	anchoredToSecure:SetPoint("CENTER", secure, "CENTER")

	p.plainFrame = prot(plain)
	p.secureButton = prot(secure)
	p.frameSecureIsAnchoredTo = prot(anchorTarget)
	p.frameAnchoredToSecure = prot(anchoredToSecure)
	p.parentOfSecure = prot(parentOfSecure)
	p.insecureChildOfSecure = prot(insecureChildOfSecure)
	p.childSecure = prot(childSecure)

	for _, fr in ipairs({ plain, secure, anchorTarget, anchoredToSecure, parentOfSecure }) do fr:Hide() end
	return p
end

local function countReturns(fn, ...)
	if type(fn) ~= "function" then return "missing" end
	local results = { pcall(fn, ...) }
	if not results[1] then return "error: " .. tostring(results[2]) end
	return select("#", unpack(results)) - 1
end

local function probeReturns()
	local r = {}
	r["GetSpellInfo(6603) #"] = countReturns(GetSpellInfo, 6603)
	r["GetItemInfo(6948) #"] = countReturns(GetItemInfo, 6948)
	r["GetTalentTabInfo(1) #"] = countReturns(GetTalentTabInfo, 1)
	r["GetTalentInfo(1,1) #"] = countReturns(GetTalentInfo, 1, 1)
	r["GetBuildInfo #"] = countReturns(GetBuildInfo)
	for i = 1, 40 do
		if UnitAura("player", i, "HELPFUL") then
			r["UnitAura(player) #"] = select("#", UnitAura("player", i, "HELPFUL"))
			r["UnitAura(player) name"] = repr((UnitAura("player", i, "HELPFUL")))
			r["UnitAura(player) 11th (spellId?)"] = repr((select(11, UnitAura("player", i, "HELPFUL"))))
			break
		end
	end
	if not r["UnitAura(player) #"] then r["UnitAura(player) #"] = "no buff on player" end
	return r
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local seenSpellsChanged, seenPEW = false, 0

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		logEvent("ADDON_LOADED", name)
		if name ~= ADDON then return end

		ClientProbeDB = ClientProbeDB or {}
		ClientProbeDB.runs = ClientProbeDB.runs or {}
		while #ClientProbeDB.runs >= 10 do table.remove(ClientProbeDB.runs, 1) end
		run = {
			started = date("%Y-%m-%d %H:%M:%S"),
			tocMarker = repr(GetAddOnMetadata(ADDON, "X-ProbeMarker")),
			luaMarker = LUA_MARKER,
			events = pending,
		}
		ClientProbeDB.runs[#ClientProbeDB.runs + 1] = run

		local ok, env = pcall(probeEnvironment); run.environment = ok and env or ("error: " .. tostring(env))
		local okW, w = pcall(probeWidgets); run.widgets = okW and w or ("error: " .. tostring(w))
		local okP, p = pcall(probeProtection); run.protection = okP and p or ("error: " .. tostring(p))
	elseif event == "PLAYER_ENTERING_WORLD" then
		seenPEW = seenPEW + 1
		logEvent(event, "args=" .. select("#", ...))
		if seenPEW == 1 and run then
			local ok, r = pcall(probeReturns); run.returns = ok and r or ("error: " .. tostring(r))
		end
	elseif event == "SPELLS_CHANGED" then
		if not seenSpellsChanged then
			seenSpellsChanged = true
			logEvent(event)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		logEvent(event, "InCombatLockdown=" .. repr(InCombatLockdown()))
	else
		logEvent(event)
	end
end)

for _, e in ipairs({ "ADDON_LOADED", "VARIABLES_LOADED", "SPELLS_CHANGED", "PLAYER_LOGIN", "PLAYER_ALIVE",
	"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	frame:RegisterEvent(e)
end

-- Records InCombatLockdown()'s value once the player is actually in combat.
local combatRecorded = false
frame:SetScript("OnUpdate", function()
	if not combatRecorded and run and UnitAffectingCombat("player") and InCombatLockdown() ~= nil then
		combatRecorded = true
		run.InCombatLockdown_inCombat = repr(InCombatLockdown())
	end
end)
