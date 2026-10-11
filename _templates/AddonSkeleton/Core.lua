-- AddonSkeleton: starter template for the 3.3.5a client (build 12340, Interface 30300).
-- Every API used here exists in this client's FrameXML or in installed 30300 addons
-- (see docs/knowledge-base.md). Not yet run in game: test with /console scriptErrors 1.

local ADDON, ns = ...

local CreateFrame, InCombatLockdown, GetTime = CreateFrame, InCombatLockdown, GetTime
local pairs, type, wipe, tremove = pairs, type, wipe, tremove

local DEFAULTS = {
	shown = true,
	point = { "CENTER", nil, "CENTER", 0, 0 },
}

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

---------------------------------------------------------------------------
-- Events: ns:EVENT_NAME(...) methods are called automatically.
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	local handler = ns[event]
	if handler then handler(ns, ...) end
end)
function ns:RegisterEvent(event) eventFrame:RegisterEvent(event) end
function ns:UnregisterEvent(event) eventFrame:UnregisterEvent(event) end

---------------------------------------------------------------------------
-- Timers: 3.3.5 has no C_Timer, so one hidden OnUpdate frame drives them.
---------------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	for i = #timers, 1, -1 do
		local t = timers[i]
		if now >= t.at then
			tremove(timers, i)
			t.fn()
		end
	end
	if #timers == 0 then self:Hide() end
end)

function ns.After(delay, fn)
	timers[#timers + 1] = { at = GetTime() + delay, fn = fn }
	timerFrame:Show()
end

---------------------------------------------------------------------------
-- Combat queue: protected changes wait until PLAYER_REGEN_ENABLED.
-- InCombatLockdown() returns 1/nil on this client, so test truthiness.
---------------------------------------------------------------------------
local combatQueue = {}

function ns.RunOutOfCombat(fn)
	if InCombatLockdown() then
		combatQueue[#combatQueue + 1] = fn
	else
		fn()
	end
end

function ns:PLAYER_REGEN_ENABLED()
	for i = 1, #combatQueue do combatQueue[i]() end
	wipe(combatQueue)
end

---------------------------------------------------------------------------
-- Main window: plain frame + native SetBackdrop (no BackdropTemplate here).
---------------------------------------------------------------------------
function ns:CreateMainFrame()
	local f = CreateFrame("Frame", "AddonSkeletonFrame", UIParent)
	f:SetSize(220, 80)
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	f:SetBackdropColor(0, 0, 0, 0.8)
	f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		ns.db.point = { point, nil, relPoint, x, y }
	end)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -10)
	title:SetText(ADDON)

	local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER", 0, -6)
	f.text = text

	local p = ns.db.point
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	if ns.db.shown then f:Show() else f:Hide() end

	-- Throttled OnUpdate example: refresh twice a second, not every frame.
	local elapsedSince = 0
	f:SetScript("OnUpdate", function(self, elapsed)
		elapsedSince = elapsedSince + elapsed
		if elapsedSince < 0.5 then return end
		elapsedSince = 0
		self.text:SetFormattedText("Health: %d / %d", UnitHealth("player"), UnitHealthMax("player"))
	end)

	ns.frame = f
end

function ns:SetShown(shown)
	ns.db.shown = shown and true or false
	if ns.frame then
		if shown then ns.frame:Show() else ns.frame:Hide() end
	end
end

---------------------------------------------------------------------------
-- Options panel (Interface > AddOns). Template children are reached by
-- global name, so the check button needs one.
---------------------------------------------------------------------------
function ns:CreateOptions()
	local panel = CreateFrame("Frame", "AddonSkeletonOptions")
	panel.name = ADDON

	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", 16, -16)
	header:SetText(ADDON)

	local check = CreateFrame("CheckButton", "AddonSkeletonOptionsShown", panel, "InterfaceOptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -2, -12)
	_G[check:GetName() .. "Text"]:SetText("Show window")
	check:SetScript("OnClick", function(self)
		ns:SetShown(self:GetChecked())  -- GetChecked returns 1/nil here
	end)

	panel.refresh = function() check:SetChecked(ns.db.shown) end

	InterfaceOptions_AddCategory(panel)
	ns.optionsPanel = panel
end

function ns:OpenOptions()
	-- Called twice on purpose: the first call on a fresh session only opens
	-- the window (its OnShow selects "Controls"); the second selects our panel.
	InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
	InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
end

---------------------------------------------------------------------------
-- Slash command: /askel [show|hide|options]
---------------------------------------------------------------------------
SLASH_ADDONSKELETON1 = "/askel"
SlashCmdList.ADDONSKELETON = function(msg)
	msg = msg:lower()
	if msg == "show" then
		ns:SetShown(true)
	elseif msg == "hide" then
		ns:SetShown(false)
	elseif msg == "options" then
		ns:OpenOptions()
	else
		print("|cff33ff99" .. ADDON .. "|r: /askel show | hide | options")
	end
end

---------------------------------------------------------------------------
-- Startup: SavedVariables exist only once ADDON_LOADED fires for us.
---------------------------------------------------------------------------
function ns:ADDON_LOADED(name)
	if name ~= ADDON then return end
	AddonSkeletonDB = CopyDefaults(DEFAULTS, AddonSkeletonDB or {})
	ns.db = AddonSkeletonDB
	self:UnregisterEvent("ADDON_LOADED")

	ns:CreateMainFrame()
	ns:CreateOptions()
end

ns:RegisterEvent("ADDON_LOADED")
ns:RegisterEvent("PLAYER_REGEN_ENABLED")
