-- Settings pages: Interface > AddOns > ThreatManagement, with a "Crowd Control" sub-page
-- (or just /tm). Built from Blizzard's own option templates so they match the default UI.
-- Changes apply immediately; each page area is about 413x430, hence the compact layout.

local ADDON, ns = ...

local floor, format = math.floor, string.format

local module = {}
table.insert(ns.modules, module)

local panel -- the page the add* helpers below are currently building
local mainPanel, ccPanel
local controls = {} -- every control on every page has :Sync() to re-read its value

local COL1, COL2 = 16, 214
local SLIDER_WIDTH = 170
local PREFIX = "ThreatManagementOptions"

local function addText(template, text, x, y)
	local fs = panel:CreateFontString(nil, "ARTWORK", template)
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

local function addCheckbox(name, label, x, y, get, set)
	local cb = CreateFrame("CheckButton", PREFIX .. name, panel, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x, y)
	_G[cb:GetName() .. "Text"]:SetText(label)
	-- The template's OnClick plays Blizzard's checkbox sound, then calls setFunc("1"/"0").
	cb.setFunc = function(setting)
		set(setting == "1")
		ns.RefreshAll()
	end
	cb.Sync = function(self) self:SetChecked(get() and true or false) end
	controls[#controls + 1] = cb
	return cb
end

local function dbCheckbox(name, label, x, y, key)
	return addCheckbox(name, label, x, y,
		function() return ns.db[key] end,
		function(on) ns.db[key] = on end)
end

-- y is the top of the slider's label.
local function addSlider(name, label, x, y, low, high, step, fmt, key)
	local s = CreateFrame("Slider", PREFIX .. name, panel, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", x + 4, y - 15)
	s:SetWidth(SLIDER_WIDTH)
	s:SetMinMaxValues(low, high)
	s:SetValueStep(step)
	_G[s:GetName() .. "Low"]:SetText(format(fmt, low))
	_G[s:GetName() .. "High"]:SetText(format(fmt, high))
	local text = _G[s:GetName() .. "Text"]

	local function show(value) text:SetText(label .. ": " .. format(fmt, value)) end
	s:SetScript("OnValueChanged", function(_, value)
		value = floor(value / step + 0.5) * step
		show(value)
		if math.abs((ns.db[key] or 0) - value) > step * 0.01 then -- ignore float noise
			ns.db[key] = value
			ns.RefreshAll()
		end
	end)
	s.Sync = function(self)
		self:SetValue(ns.db[key])
		show(ns.db[key])
	end
	controls[#controls + 1] = s
	return s
end

local function addButton(name, label, x, y, width, onClick)
	local b = CreateFrame("Button", PREFIX .. name, panel, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

-- One choice of several for a setting; each radio re-syncs the whole page when clicked.
local function addRadio(name, label, x, y, key, value)
	local radio = CreateFrame("CheckButton", PREFIX .. name, panel, "UIRadioButtonTemplate")
	radio:SetPoint("TOPLEFT", x, y)
	local text = _G[radio:GetName() .. "Text"]
	text:SetFontObject(GameFontHighlight)
	text:SetText(label)
	radio:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		ns.db[key] = value
		ns.RefreshAll()
	end)
	radio.Sync = function(self) self:SetChecked(ns.db[key] == value) end
	controls[#controls + 1] = radio
	return radio
end

local function syncAll()
	for i = 1, #controls do controls[i]:Sync() end
end

local function build()
	panel = CreateFrame("Frame", PREFIX)
	mainPanel = panel
	panel.name = "ThreatManagement"
	panel:Hide()

	addText("GameFontNormalLarge", "ThreatManagement", COL1, -16)
	addText("GameFontHighlightSmall", "Your threat % on the target frame, aggro alerts, and optional nameplate numbers.", COL1, -38)

	-- Target frame
	addText("GameFontNormal", "Target frame", COL1, -62)
	dbCheckbox("TargetEnabled", "Show threat % under the target portrait", COL1, -78, "enabled")
	addCheckbox("HideBlizzard", "Hide Blizzard's threat box above the target frame", COL1, -104,
		function() return GetCVar("threatShowNumeric") == "0" end,
		function(on) SetCVar("threatShowNumeric", on and "0" or "1") end)
	addSlider("TargetSize", "Text size", COL1, -138, 0.5, 2, 0.05, "%.2f", "fontScale")
	addSlider("TargetX", "Left / right", COL2, -138, -60, 60, 1, "%d", "x")
	addSlider("TargetY", "Up / down", COL1, -182, -40, 20, 1, "%d", "y")
	addButton("Preview", "Preview for 20 s", COL2 + 4, -192, SLIDER_WIDTH, function() ns.StartPreview() end)

	-- Aggro alerts
	addText("GameFontNormal", "Aggro alerts", COL1, -238)
	addButton("AlertTest", "Test alert", COL1 + 100, -234, 90, function() ns.commands.alerts("test") end)
	dbCheckbox("Alerts", "Alert when a mob attacks me", COL1, -254, "alerts")
	dbCheckbox("AlertSound", "Raid warning sound", COL1, -280, "alertSound")
	addSlider("AlertSize", "Alert size", COL2, -258, 0.8, 2.5, 0.05, "%.2f", "alertScale")

	-- Nameplates
	addText("GameFontNormal", "Nameplates", COL1, -318)
	addText("GameFontDisableSmall", "(only visible while nameplates are shown, V)", COL1 + 80, -320)
	dbCheckbox("Plates", "Show threat % under enemy nameplates", COL1, -334, "plates")
	addSlider("PlateSize", "Text size", COL1, -368, 0.5, 2, 0.05, "%.2f", "plateFontScale")
	addSlider("PlateStale", "Keep last value (s)", COL2, -368, 0, 10, 1, "%d", "staleSeconds")

	panel.refresh = syncAll
	panel.default = function() ns.ResetDefaults() syncAll() end
	panel:SetScript("OnShow", syncAll)

	InterfaceOptions_AddCategory(panel)
end

local CC_KEYS = { "ccAlerts", "ccScope", "ccAnnounce", "ccPlaced", "ccFears", "ccRoots", "ccShort" }

local function buildCrowdControl()
	panel = CreateFrame("Frame", PREFIX .. "CC")
	ccPanel = panel
	panel.name = "Crowd Control"
	panel.parent = "ThreatManagement" -- shows as a sub-page under ThreatManagement
	panel:Hide()

	addText("GameFontNormalLarge", "Crowd control breaks", COL1, -16)
	addButton("CCTest", "Test alert", COL1 + 280, -12, 90, function() ns.commands.cc("test") end)
	local intro = addText("GameFontHighlightSmall",
		"\"Polymorph on X broken by Y\" in the alert spot, in orange. Uses the alert size and sound from the main page.",
		COL1, -40)
	intro:SetWidth(380)

	dbCheckbox("CCAlerts", "Alert when crowd control breaks", COL1, -70, "ccAlerts")

	addText("GameFontNormal", "Whose crowd control", COL1, -108)
	addRadio("CCScopeGroup", "My group's (yours and your party's or raid's)", COL1 + 4, -128, "ccScope", "group")
	addRadio("CCScopeMine", "Only mine", COL1 + 4, -150, "ccScope", "mine")

	addText("GameFontNormal", "Chat", COL1, -180)
	dbCheckbox("CCAnnounce", "Announce breaks of my placed CC in party / raid chat", COL1, -196, "ccAnnounce")

	-- Categories come from CCData.lua, generated from this client's spell data.
	addText("GameFontNormal", "Track", COL1, -232)
	local y = -248
	for _, c in ipairs({
		{ "CCPlaced", "Placed CC", "placed", "ccPlaced" },
		{ "CCFears", "Fears", "fear", "ccFears" },
		{ "CCRoots", "Roots", "root", "ccRoots" },
		{ "CCShort", "Short CC", "short", "ccShort" },
	}) do
		dbCheckbox(c[1], c[2], COL1, y, c[4])
		local names = addText("GameFontDisableSmall", table.concat(ns.TrackedCCNames(c[3]), ", "), COL1 + 110, y - 7)
		names:SetWidth(270)
		y = y - (c[3] == "placed" and 44 or 30)
	end
	local note = addText("GameFontDisableSmall",
		"Every crowd control on this client that damage can break, read from its spell data.", COL1, y - 6)
	note:SetWidth(380)

	panel.refresh = syncAll
	panel.default = function()
		for _, key in ipairs(CC_KEYS) do ns.db[key] = ns.DEFAULTS[key] end
		ns.RefreshAll()
		syncAll()
	end
	panel:SetScript("OnShow", syncAll)

	InterfaceOptions_AddCategory(panel)
end

function module:Init()
	build()
	buildCrowdControl()
end

function module:Refresh()
	if (mainPanel and mainPanel:IsShown()) or (ccPanel and ccPanel:IsShown()) then syncAll() end
end

function ns.OpenOptions(page)
	local target = (page == "cc") and ccPanel or mainPanel
	-- Twice on purpose: on a fresh session the first call only opens the window
	-- (whose OnShow selects "Controls"); the second selects this panel.
	InterfaceOptionsFrame_OpenToCategory(target)
	InterfaceOptionsFrame_OpenToCategory(target)
end
