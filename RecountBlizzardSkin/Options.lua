-- Settings page: Interface > AddOns > Recount Blizzard Skin (or just /rbs).
-- Built from Blizzard's option templates; changes apply immediately.

local ADDON, ns = ...

local PREFIX = "RecountBlizzardSkinOptions"
local COL1 = 16

local panel = CreateFrame("Frame", PREFIX)
panel.name = "Recount Blizzard Skin"
panel:Hide()

local function addText(template, text, x, y, width)
	local fs = panel:CreateFontString(nil, "ARTWORK", template)
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	fs:SetText(text)
	return fs
end

local function addButton(name, label, x, y, width, onClick)
	local b = CreateFrame("Button", PREFIX .. name, panel, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

addText("GameFontNormalLarge", "Recount Blizzard Skin", COL1, -16)
addText("GameFontHighlightSmall", "Makes Recount look like the default UI. Changes apply immediately.", COL1, -38)

---------------------------------------------------------------------------
-- Header style (radio buttons)
---------------------------------------------------------------------------
addText("GameFontNormal", "Header style", COL1, -64)

local STYLES = {
	{ key = "banner", label = "Banner", note = "Gold-trimmed banner, like the Video and Interface options windows" },
	{ key = "bar", label = "Title bar", note = "Dark stone strip with the X in its slot, like the Character and Spellbook windows" },
	{ key = "plain", label = "Plain", note = "No header art, just the tooltip-style window" },
}
local radios = {}

local function syncRadios()
	for _, radio in ipairs(radios) do
		radio:SetChecked(ns.db.header == radio.style)
	end
end

for i, style in ipairs(STYLES) do
	local y = -84 - (i - 1) * 38
	local radio = CreateFrame("CheckButton", PREFIX .. "Header" .. i, panel, "UIRadioButtonTemplate")
	radio:SetPoint("TOPLEFT", COL1 + 4, y)
	radio.style = style.key
	local label = _G[radio:GetName() .. "Text"]
	label:SetFontObject(GameFontHighlight)
	label:SetText(style.label)
	addText("GameFontDisableSmall", style.note, COL1 + 25, y - 17, 360)
	radio:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		ns.SetHeader(self.style)
		syncRadios() -- radio behaviour: the clicked one stays on, the others go off
	end)
	radios[i] = radio
end

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------
addText("GameFontNormal", "Bars", COL1, -206)
local backing = CreateFrame("CheckButton", PREFIX .. "BarBacking", panel, "InterfaceOptionsCheckButtonTemplate")
backing:SetPoint("TOPLEFT", COL1, -222)
_G[backing:GetName() .. "Text"]:SetText("Dark strip behind each bar")
backing.setFunc = function(setting) ns.SetBarBacking(setting == "1") end

---------------------------------------------------------------------------
-- Recount's own colours / texture / font
---------------------------------------------------------------------------
addText("GameFontNormal", "Colours, bar texture and font", COL1, -266)
addText("GameFontHighlightSmall",
	"These live in Recount's own settings, so you can still fine-tune them in Recount's config. "
		.. "The window shape, header and title font above stay as they are.",
	COL1, -284, 380)
addButton("Apply", "Blizzard colours & bars", COL1, -320, 170, function()
	ns.ApplyBlizzard()
end)
addButton("Restore", "Recount colours & bars", COL1 + 186, -320, 170, function()
	ns.RestoreRecount()
end)
addText("GameFontDisableSmall",
	"Blizzard: grey outline, gold title, health-bar texture, Friz font. Recount: red outline, white title, "
		.. "Recount's bars and Arial font. For Recount's original window shape, disable this addon.",
	COL1, -352, 380)

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
local function sync()
	if not ns.db then return end
	syncRadios()
	backing:SetChecked(ns.db.barBacking and true or false)
end

panel.refresh = sync
panel.default = function()
	ns.SetHeader("banner")
	ns.SetBarBacking(true)
	sync()
end
panel:SetScript("OnShow", sync)

InterfaceOptions_AddCategory(panel)

function ns.OpenOptions()
	-- Twice on purpose: on a fresh session the first call only opens the window
	-- (whose OnShow selects "Controls"); the second selects this panel.
	InterfaceOptionsFrame_OpenToCategory(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
end
