-- Recount Blizzard Skin: restyles Recount without editing its files.
--
-- Two kinds of change:
--  * Window chrome (border, header art, scrollbars, resize grips, bar backing). Recount has no
--    settings for these, so they are applied every session. Recount builds its main, detail and
--    graph windows in OnInitialize, i.e. before this addon loads, so those are skinned directly
--    at load; later windows are caught by wrapping Recount:AddWindow. Disable this addon and the
--    chrome reverts.
--  * Colours, bar texture and font. These are written into Recount's own profile through
--    Recount's API, once per profile, so Recount's config keeps working on top of them.
--    /rbs restore puts Recount's original values back; /rbs apply re-applies these.
--
-- Header styles (settings page or /rbs header banner|bar|plain):
--  banner - the gold-trimmed banner from the Video/Interface options windows (default)
--  bar    - the dark stone title strip from the Character/Spellbook windows, X in its square slot
--  plain  - no header art, tooltip window only

local ADDON, ns = ...
local Recount = Recount -- guaranteed by ## Dependencies

local SETTINGS_VERSION = 2 -- v2: banner became the default header

local BACKDROP = { -- the default GameTooltip backdrop
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local ROW_INSET = 5 -- keeps bars clear of the tooltip border
local BAR_BACKING_ALPHA = 0.35

-- Blizzard values: TOOLTIP_DEFAULT_COLOR, TOOLTIP_DEFAULT_BACKGROUND_COLOR, NORMAL_FONT_COLOR
local BLIZZARD = {
	border = { r = 1, g = 1, b = 1, a = 1 },
	background = { r = 0.09, g = 0.09, b = 0.19, a = 1 },
	titleText = { r = 1, g = 0.82, b = 0, a = 1 },
	barTexture = "Blizzard",          -- LibSharedMedia: Interface\TargetingFrame\UI-StatusBar
	font = "Friz Quadrata TT",        -- LibSharedMedia: Fonts\FRIZQT__.TTF
}
-- Recount's shipped defaults (Recount.lua), for /rbs restore
local RECOUNT = {
	border = { r = 1, g = 0, b = 0, a = 1 },
	background = { r = 24 / 255, g = 24 / 255, b = 24 / 255, a = 1 },
	titleText = { r = 1, g = 1, b = 1, a = 1 },
	barTexture = "BantoBar",
	font = "Arial Narrow",
}

-- Texel measurements taken from the client's own textures (see _reference/tools/blp2png.py).
-- UI-Character-General-TopRight is 128x256: the header strip is rows 13-33, the plain strip
-- is x 0-64, the square close-button slot is x 69-92 (centre x 81), the slot's outer bevel x 89-92.
local STRIP_TEX = [[Interface\PaperDollInfoFrame\UI-Character-General-TopRight]]
local STRIP_TOP, STRIP_BOTTOM, STRIP_ROWS = 13 / 256, 34 / 256, 21
local STRIP_HEIGHT = 22
-- UI-DialogBox-Header is 256x64: the banner is x 59-196, rows 1-38, with 16-texel end caps.
local BANNER_TEX = [[Interface\DialogFrame\UI-DialogBox-Header]]
local BANNER_TOP, BANNER_BOTTOM, BANNER_ROWS = 1 / 64, 39 / 64, 38
local BANNER_HEIGHT = 32

local db
local skinned = {}
local windows = {} -- every skinned window, for re-laying out headers

---------------------------------------------------------------------------
-- Settings preset (written through Recount's own API)
---------------------------------------------------------------------------
local function applyPreset(p)
	for _, branch in ipairs({ "Window", "Other Windows" }) do
		Recount.Colors:SetColor(branch, "Title", p.border)
		Recount.Colors:SetColor(branch, "Background", p.background)
		Recount.Colors:SetColor(branch, "Title Text", p.titleText)
	end
	Recount:SetBarTextures(p.barTexture)
	Recount:SetFont(p.font)
end

local function applyPresetOncePerProfile()
	db.applied = db.applied or {}
	local key = Recount.db:GetCurrentProfile() or "Default"
	if not db.applied[key] then
		db.applied[key] = true
		applyPreset(BLIZZARD)
	end
end

---------------------------------------------------------------------------
-- Bars, scrollbars, resize grips
---------------------------------------------------------------------------
local function insetRows()
	local main = Recount.MainWindow
	if not (main and main.Rows) then return end
	local width = main:GetWidth() - 2 * ROW_INSET
	for _, row in pairs(main.Rows) do
		local point, relativeTo, relativePoint, _, y = row:GetPoint(1)
		if point then row:SetPoint(point, relativeTo, relativePoint, ROW_INSET, y) end
		row:SetWidth(width)
	end
end

local function addBarBacking(row)
	if not row or not row.StatusBar or row.RBSBacking then return end
	local backing = row.StatusBar:CreateTexture(nil, "BACKGROUND")
	backing:SetAllPoints(row.StatusBar)
	backing:SetTexture(0, 0, 0, BAR_BACKING_ALPHA)
	if db and not db.barBacking then backing:Hide() end
	row.RBSBacking = backing
end

local function setBarBacking(on)
	db.barBacking = on
	local main = Recount.MainWindow
	if not (main and main.Rows) then return end
	for _, row in pairs(main.Rows) do
		if row.RBSBacking then
			if on then row.RBSBacking:Show() else row.RBSBacking:Hide() end
		end
	end
end

local function skinResizeGrip(button, mirrored)
	if not button then return end
	button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
	button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down]])
	button:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]])
	if mirrored then
		for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
			tex:SetTexCoord(1, 0, 0, 1)
		end
	end
end

-- Recount swaps Blizzard's scrollbar art for red-tinted copies; put Blizzard's back.
local function skinArrow(button, direction)
	if not button then return end
	local base = [[Interface\Buttons\UI-ScrollBar-Scroll]] .. direction .. "Button-"
	button:SetNormalTexture(base .. "Up")
	button:SetPushedTexture(base .. "Down")
	button:SetDisabledTexture(base .. "Disabled")
	button:SetHighlightTexture(base .. "Highlight")
	if button.Overlay then button.Overlay:Hide() end
end

local function skinScrollbar(name)
	local thumb = _G[name .. "ScrollBarThumbTexture"]
	if thumb then thumb:SetTexture([[Interface\Buttons\UI-ScrollBar-Knob]]) end
	skinArrow(_G[name .. "ScrollBarScrollUpButton"], "Up")
	skinArrow(_G[name .. "ScrollBarScrollDownButton"], "Down")
end

---------------------------------------------------------------------------
-- Header art
---------------------------------------------------------------------------
local function newPiece(window, file, left, right, top, bottom)
	local tex = window:CreateTexture(nil, "ARTWORK")
	tex:SetTexture(file)
	tex:SetTexCoord(left, right, top, bottom)
	return tex
end

local function buildBar(window)
	local k = STRIP_HEIGHT / STRIP_ROWS
	-- Left end: the slot's outer bevel (x 89-92), mirrored.
	local left = newPiece(window, STRIP_TEX, 93 / 128, 89 / 128, STRIP_TOP, STRIP_BOTTOM)
	left:SetSize(4 * k, STRIP_HEIGHT)
	left:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -4)
	-- Right end: plain strip, the junction bevel and the square close slot (x 40-92).
	local right = newPiece(window, STRIP_TEX, 40 / 128, 93 / 128, STRIP_TOP, STRIP_BOTTOM)
	right:SetSize(53 * k, STRIP_HEIGHT)
	right:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -4)
	-- Middle: plain strip (x 8-40) stretched between the ends.
	local middle = newPiece(window, STRIP_TEX, 8 / 128, 40 / 128, STRIP_TOP, STRIP_BOTTOM)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	return { left = left, middle = middle, right = right, slotOffset = (93 - 81) * k }
end

local function buildBanner(window)
	local k = BANNER_HEIGHT / BANNER_ROWS
	local left = newPiece(window, BANNER_TEX, 59 / 256, 75 / 256, BANNER_TOP, BANNER_BOTTOM)
	left:SetSize(16 * k, BANNER_HEIGHT)
	local right = newPiece(window, BANNER_TEX, 181 / 256, 197 / 256, BANNER_TOP, BANNER_BOTTOM)
	right:SetSize(16 * k, BANNER_HEIGHT)
	local middle = newPiece(window, BANNER_TEX, 75 / 256, 181 / 256, BANNER_TOP, BANNER_BOTTOM)
	middle:SetHeight(BANNER_HEIGHT)
	-- Centred on the window's top edge, mostly above it, like Blizzard's dialog headers.
	middle:SetPoint("BOTTOM", window, "TOP", 0, -10)
	left:SetPoint("RIGHT", middle, "LEFT")
	right:SetPoint("LEFT", middle, "RIGHT")
	return { left = left, middle = middle, right = right }
end

local function showPieces(set, shown)
	if not set then return end
	for _, piece in pairs({ set.left, set.middle, set.right }) do
		if shown then piece:Show() else piece:Hide() end
	end
end

-- Banner width follows the title text (Recount retitles the main window per mode).
local function fitBanner(window)
	local banner = window.RBSBanner
	if banner and window.Title then
		banner.middle:SetWidth(math.max(40, window.Title:GetStringWidth() + 12))
	end
end

-- Window titles always use Blizzard's font, whatever font Recount's bars use.
local TITLE_FONT = [[Fonts\FRIZQT__.TTF]]
local function lockTitleFont(window)
	local title = window.Title
	if not title then return end
	local _, size, flags = title:GetFont()
	title:SetFont(TITLE_FONT, size or 12, flags)
	fitBanner(window)
end

local function layoutHeader(window)
	local style = db.header
	if style == "bar" and not window.RBSBar then window.RBSBar = buildBar(window) end
	if style == "banner" and not window.RBSBanner then window.RBSBanner = buildBanner(window) end
	showPieces(window.RBSBar, style == "bar")
	showPieces(window.RBSBanner, style == "banner")

	local title, close = window.Title, window.CloseButton
	if title then title:ClearAllPoints() end
	if close then close:ClearAllPoints() end

	if style == "bar" then
		local bar = window.RBSBar
		if title then title:SetPoint("LEFT", bar.left, "RIGHT", 4, 0) end
		if close then
			close:SetSize(24, 24)
			close:SetPoint("CENTER", bar.right, "RIGHT", -bar.slotOffset, 0)
		end
	elseif style == "banner" then
		if title then title:SetPoint("CENTER", window.RBSBanner.middle, "CENTER", 0, 1) end
		if close then
			close:SetSize(20, 20)
			close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -11)
		end
		fitBanner(window)
	else -- plain
		if title then title:SetPoint("TOPLEFT", window, "TOPLEFT", 9, -10) end
		if close then
			close:SetSize(20, 20)
			close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -5)
		end
	end

	-- Main window: leave a little air between the X and Recount's other header buttons.
	if window == Recount.MainWindow and window.RightButton and close then
		window.RightButton:ClearAllPoints()
		window.RightButton:SetPoint("RIGHT", close, "LEFT", style == "bar" and -4 or 0, 0)
	end
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
local function skinWindow(window)
	if not window or skinned[window] then return end
	skinned[window] = true
	windows[#windows + 1] = window

	window:SetBackdrop(BACKDROP)
	-- SetBackdrop resets colours, so re-read Recount's current ones.
	local branch = (window == Recount.MainWindow) and "Window" or "Other Windows"
	local border = Recount.Colors:GetColor(branch, "Title")
	local background = Recount.Colors:GetColor(branch, "Background")
	window:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
	window:SetBackdropColor(background.r, background.g, background.b, background.a or 1)

	if window.Title then
		hooksecurefunc(window.Title, "SetText", function() fitBanner(window) end)
	end
	lockTitleFont(window)
	layoutHeader(window)

	if window == Recount.MainWindow then
		skinResizeGrip(window.DragBottomRight, false)
		skinResizeGrip(window.DragBottomLeft, true)
		if window.Rows then
			for _, row in pairs(window.Rows) do addBarBacking(row) end
		end
		insetRows()
	end
end

local function relayoutAll()
	for i = 1, #windows do layoutHeader(windows[i]) end
end

---------------------------------------------------------------------------
-- Hooks: wrap Recount's builders so later windows/bars/scrollbars are skinned as they're made
---------------------------------------------------------------------------
local function wrap(methodName, after)
	local original = Recount[methodName]
	if type(original) ~= "function" then return end
	Recount[methodName] = function(self, ...)
		local a, b, c = original(self, ...)
		after(self, ...)
		return a, b, c
	end
end

wrap("AddWindow", function(_, window) if db then skinWindow(window) end end)
wrap("SetupBar", function(_, row) addBarBacking(row) end)
wrap("SetupScrollbar", function(_, name) skinScrollbar(name) end)
wrap("ResizeMainWindow", function() insetRows() end)
-- Recount:SetFont re-fonts every registered string, titles included; put the titles back.
wrap("SetFont", function()
	for i = 1, #windows do lockTitleFont(windows[i]) end
end)

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")
	RecountBlizzardSkinDB = RecountBlizzardSkinDB or {}
	db = RecountBlizzardSkinDB
	if db.version ~= SETTINGS_VERSION then
		db.header = "banner"
		db.version = SETTINGS_VERSION
	end
	if db.barBacking == nil then db.barBacking = true end
	ns.db = db

	-- Built during Recount's OnInitialize, before this addon loaded.
	skinWindow(Recount.MainWindow)
	skinWindow(Recount.DetailWindow)
	skinWindow(Recount.GraphWindow)
	-- Their scrollbars were set up then too; find them once by Recount's naming pattern.
	for globalName in pairs(_G) do
		if type(globalName) == "string" then
			local base = globalName:match("^(Recount.-)ScrollBarThumbTexture$")
			if base then skinScrollbar(base) end
		end
	end
	applyPresetOncePerProfile()
end)

---------------------------------------------------------------------------
-- API for the settings page, and /rbs
---------------------------------------------------------------------------
function ns.SetHeader(style)
	db.header = style
	relayoutAll()
end
ns.SetBarBacking = setBarBacking
function ns.ApplyBlizzard() applyPreset(BLIZZARD) end
function ns.RestoreRecount() applyPreset(RECOUNT) end

local function say(msg) print("|cffffd200Recount Blizzard Skin|r: " .. msg) end

SLASH_RECOUNTBLIZZARDSKIN1 = "/rbs"
SlashCmdList.RECOUNTBLIZZARDSKIN = function(msg)
	local cmd, arg = strsplit(" ", msg:lower())
	if cmd == "" and ns.OpenOptions then
		ns.OpenOptions()
	elseif cmd == "apply" then
		ns.ApplyBlizzard()
		say("Blizzard colours, bar texture and font applied to Recount.")
	elseif cmd == "restore" then
		ns.RestoreRecount()
		say("Recount's original colours, bars and font restored. Disable this addon to also restore the window borders.")
	elseif cmd == "header" and (arg == "banner" or arg == "bar" or arg == "plain") then
		ns.SetHeader(arg)
		say("header style set to " .. arg .. ".")
	else
		say("/rbs opens the settings page (Interface > AddOns > Recount Blizzard Skin).")
		say("/rbs header banner|bar|plain (now: " .. db.header .. ") | apply | restore")
	end
end
