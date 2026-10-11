-- AddonManager: an in-game copy of the character-select AddOn List (GlueXML AddonList.xml),
-- plus a search box and an All / Enabled / Disabled filter. Addons can't change the
-- character-select screen itself, so this lives in game: open it from the Esc menu or /addons.
--
-- Ticking boxes only records pending changes; Okay applies them and reloads the UI (that's
-- when the client loads or unloads addons), Cancel throws them away.
-- The filter is a hand-built dropdown on Blizzard's dropdown art rather than UIDropDownMenu,
-- because addon use of UIDropDownMenu can taint Blizzard menus (the 3.3.5 "Set Focus" problem).

local ADDON = ...

local ROWS, ROW_HEIGHT = 19, 20 -- same as the glue list: MAX_ADDONS_DISPLAYED, 16px rows + 4px gap
local NAME = "AddonManagerFrame"
local FILTERS = {
	{ key = "all", label = "All" },
	{ key = "enabled", label = "Enabled" },
	{ key = "disabled", label = "Disabled" },
}

local pending = {} -- addon name -> true/false, applied on Okay
local shown = {}   -- addon indexes that pass the search and filter
local filter, query = "all", ""
local frame, scroll, searchBox, dropdown, menu, okayButton, enableButton, disableButton
local rows = {}

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local function plain(text) -- TOC titles may carry |cAARRGGBB colour codes
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Returns the addon's info plus whether it will be enabled after Okay.
local function info(i)
	local name, title, notes, enabled, loadable, reason = GetAddOnInfo(i)
	enabled = enabled and true or false
	local willBe = enabled
	if pending[name] ~= nil then willBe = pending[name] end
	return name, title or name, notes, enabled, loadable, reason, willBe
end

local function hasPending()
	return next(pending) ~= nil
end

-- Records a change only when it differs from the saved state. (Not the `a and b or c`
-- idiom: that turns a wanted `false` into nil.)
local function setPending(name, enabled, want)
	if want == enabled then
		pending[name] = nil
	else
		pending[name] = want
	end
end

local function rebuild()
	wipe(shown)
	local q = query:lower()
	for i = 1, GetNumAddOns() do
		local name, title, _, _, _, _, willBe = info(i)
		local passes = filter == "all" or (filter == "enabled") == willBe
		if passes and (q == "" or name:lower():find(q, 1, true) or plain(title):lower():find(q, 1, true)) then
			shown[#shown + 1] = i
		end
	end
end

---------------------------------------------------------------------------
-- List
---------------------------------------------------------------------------
local function updateButtons()
	local narrowed = filter ~= "all" or query ~= ""
	enableButton:SetText(narrowed and "Enable Shown" or "Enable All")
	disableButton:SetText(narrowed and "Disable Shown" or "Disable All")
	okayButton:SetText(hasPending() and "Reload UI" or OKAY)
end

local function updateRows()
	local offset = FauxScrollFrame_GetOffset(scroll)
	for r = 1, ROWS do
		local row = rows[r]
		local index = shown[offset + r]
		if index then
			local name, title, _, enabled, loadable, reason, willBe = info(index)
			row.index, row.name = index, name
			row.check:SetChecked(willBe)
			row.title:SetText(title)

			local status
			if pending[name] ~= nil then
				status = willBe and "Enabled after reload" or "Disabled after reload"
			elseif reason then
				status = _G["ADDON_" .. reason]
			end
			row.status:SetText(status or "")

			-- Colours as in GlueXML AddonList_Update (gold / red / grey), using the pending state.
			if not willBe or (pending[name] == nil and reason == "DEP_DISABLED") then
				row.title:SetTextColor(0.5, 0.5, 0.5)
			elseif not enabled or loadable or reason == "DEMAND_LOADED" or reason == "DEP_DEMAND_LOADED" then
				row.title:SetTextColor(1.0, 0.78, 0.0)
			else
				row.title:SetTextColor(1.0, 0.1, 0.1)
			end
			row:Show()
		else
			row:Hide()
		end
	end
	FauxScrollFrame_Update(scroll, #shown, ROWS, ROW_HEIGHT)
	updateButtons()
end

local function refresh()
	rebuild()
	FauxScrollFrame_SetOffset(scroll, 0)
	_G[scroll:GetName() .. "ScrollBar"]:SetValue(0)
	updateRows()
end

local function setShownEnabled(on)
	for _, index in ipairs(shown) do
		local name, _, _, enabled = info(index)
		setPending(name, enabled, on)
	end
	updateRows()
end

local function showTooltip(row)
	local name, title, notes = GetAddOnInfo(row.index)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(title or name)
	if notes then GameTooltip:AddLine(notes, 1, 1, 1, true) end
	local deps = { GetAddOnDependencies(row.index) }
	if #deps > 0 then
		GameTooltip:AddLine("Dependencies: " .. table.concat(deps, ", "), 0.75, 0.75, 0.75, true)
	end
	local version = GetAddOnMetadata(name, "Version")
	if version then GameTooltip:AddLine("Version: " .. version, 0.75, 0.75, 0.75) end
	if IsAddOnLoaded(row.index) then
		local kb = GetAddOnMemoryUsage(name)
		GameTooltip:AddLine(kb >= 1024 and string.format("Memory: %.2f MB", kb / 1024)
			or string.format("Memory: %.0f KB", kb), 0.75, 0.75, 0.75)
	end
	GameTooltip:Show()
end

local function createRow(i)
	local row = CreateFrame("Button", NAME .. "Entry" .. i, frame)
	row:SetSize(520, 16)
	row:SetPoint("TOPLEFT", 37, -80 - (i - 1) * ROW_HEIGHT)
	row:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
	row:GetHighlightTexture():SetBlendMode("ADD")
	row:GetHighlightTexture():SetAlpha(0.35)

	local check = CreateFrame("CheckButton", nil, row)
	check:SetSize(32, 32)
	check:SetPoint("LEFT", 5, 0)
	check:SetNormalTexture([[Interface\Buttons\UI-CheckBox-Up]])
	check:SetPushedTexture([[Interface\Buttons\UI-CheckBox-Down]])
	check:SetHighlightTexture([[Interface\Buttons\UI-CheckBox-Highlight]])
	check:GetHighlightTexture():SetBlendMode("ADD")
	check:SetCheckedTexture([[Interface\Buttons\UI-CheckBox-Check]])
	check:SetScript("OnClick", function(self)
		local name, _, _, enabled = info(row.index)
		local want = self:GetChecked() and true or false
		setPending(name, enabled, want)
		PlaySound(want and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		updateRows() -- deliberately no re-filter, so the row doesn't vanish under your cursor
	end)
	row.check = check

	row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.title:SetSize(220, 12)
	row.title:SetPoint("LEFT", 42, 0)
	row.title:SetJustifyH("LEFT")

	row.status = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	row.status:SetSize(220, 12)
	row.status:SetPoint("LEFT", row.title, "RIGHT", 30, 0)
	row.status:SetJustifyH("LEFT")

	row:SetScript("OnEnter", showTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetScript("OnClick", function() check:Click() end)
	rows[i] = row
end

---------------------------------------------------------------------------
-- Filter dropdown (Blizzard's dropdown art, no UIDropDownMenu)
---------------------------------------------------------------------------
local LABEL_FRAME = [[Interface\Glues\CharacterCreate\CharacterCreate-LabelFrame]]

local function setFilter(key)
	filter = key
	for _, f in ipairs(FILTERS) do
		if f.key == key then dropdown.text:SetText(f.label) end
	end
	menu:Hide()
	refresh()
end

local function createDropdown()
	-- Same pieces and offsets as UIDropDownMenuTemplate.
	dropdown = CreateFrame("Frame", NAME .. "Filter", frame)
	dropdown:SetSize(165, 32)
	local left = dropdown:CreateTexture(nil, "ARTWORK")
	left:SetTexture(LABEL_FRAME)
	left:SetTexCoord(0, 0.1953125, 0, 1)
	left:SetSize(25, 64)
	left:SetPoint("TOPLEFT", 0, 17)
	local middle = dropdown:CreateTexture(nil, "ARTWORK")
	middle:SetTexture(LABEL_FRAME)
	middle:SetTexCoord(0.1953125, 0.8046875, 0, 1)
	middle:SetSize(115, 64)
	middle:SetPoint("LEFT", left, "RIGHT")
	local right = dropdown:CreateTexture(nil, "ARTWORK")
	right:SetTexture(LABEL_FRAME)
	right:SetTexCoord(0.8046875, 1, 0, 1)
	right:SetSize(25, 64)
	right:SetPoint("LEFT", middle, "RIGHT")

	dropdown.text = dropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	dropdown.text:SetHeight(10)
	dropdown.text:SetPoint("RIGHT", right, "RIGHT", -43, 2)
	dropdown.text:SetJustifyH("RIGHT")
	dropdown.text:SetText(FILTERS[1].label)

	local arrow = CreateFrame("Button", nil, dropdown)
	arrow:SetSize(24, 24)
	arrow:SetPoint("TOPRIGHT", right, "TOPRIGHT", -16, -18)
	arrow:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
	arrow:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
	arrow:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
	arrow:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
	arrow:GetHighlightTexture():SetBlendMode("ADD")
	arrow:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		if menu:IsShown() then menu:Hide() else menu:Show() end
	end)

	-- The open list: same backdrop as Blizzard's DropDownList.
	menu = CreateFrame("Frame", NAME .. "FilterMenu", dropdown)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background-Dark]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 9 },
	})
	menu:SetSize(130, 16 * #FILTERS + 30)
	menu:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 16, 18)
	menu:Hide()
	for i, f in ipairs(FILTERS) do
		local item = CreateFrame("Button", nil, menu)
		item:SetSize(104, 16)
		item:SetPoint("TOPLEFT", 14, -15 - (i - 1) * 16)
		item:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
		item:GetHighlightTexture():SetBlendMode("ADD")
		local tick = item:CreateTexture(nil, "ARTWORK")
		tick:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
		tick:SetSize(16, 16)
		tick:SetPoint("LEFT")
		local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", 18, 0)
		label:SetText(f.label)
		item:SetScript("OnShow", function() if filter == f.key then tick:Show() else tick:Hide() end end)
		item:SetScript("OnClick", function() setFilter(f.key) end)
	end
	-- Close after the mouse has been away for 2 s, like Blizzard's dropdowns.
	local away = 0
	menu:SetScript("OnShow", function() away = 0 end)
	menu:SetScript("OnUpdate", function(self, elapsed)
		if MouseIsOver(self) or MouseIsOver(arrow) then
			away = 0
		else
			away = away + elapsed
			if away > 2 then self:Hide() end
		end
	end)
end

---------------------------------------------------------------------------
-- Window (art and layout copied from GlueXML AddonList.xml)
---------------------------------------------------------------------------
local function art(file, width, height, point, x, y, top, bottom)
	-- Textures in one draw layer have no guaranteed order on this client (no sublevels),
	-- so the divider strips go one layer above the base art, as Blizzard's ARTWORK strips do.
	local tex = frame:CreateTexture(nil, top and "BORDER" or "BACKGROUND")
	tex:SetTexture(file)
	tex:SetSize(width, height)
	tex:SetPoint(point, x, y)
	if top then tex:SetTexCoord(0, 1, top, bottom) end
	return tex
end

local function createButton(label, width, onClick)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local function createFrame()
	frame = CreateFrame("Frame", NAME, UIParent)
	frame:SetSize(640, 512)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:Hide()
	tinsert(UISpecialFrames, NAME) -- Esc closes it (same as Cancel)

	local H = [[Interface\HelpFrame\HelpFrame-]]
	art(H .. "TopLeft", 256, 256, "TOPLEFT", 0, 0)
	art(H .. "Top", 256, 256, "TOPLEFT", 256, 0)
	art(H .. "TopRight", 128, 256, "TOPRIGHT", 0, 0)
	art(H .. "BotLeft", 256, 256, "BOTTOMLEFT", 0, 0)
	art(H .. "Bottom", 256, 256, "BOTTOMLEFT", 256, 0)
	art(H .. "BotRight", 128, 256, "BOTTOMRIGHT", 0, 0)
	-- The divider under the controls: rows 31-60 of the top pieces, drawn over the base art.
	art(H .. "TopLeft", 256, 29, "TOPLEFT", 0, -50, 0.12109375, 0.234375)
	art(H .. "Top", 256, 29, "TOPLEFT", 256, -50, 0.12109375, 0.234375)
	art(H .. "TopRight", 128, 29, "TOPRIGHT", 0, -50, 0.12109375, 0.234375)

	local header = frame:CreateTexture(nil, "ARTWORK")
	header:SetTexture([[Interface\DialogFrame\UI-DialogBox-Header]])
	header:SetSize(256, 64)
	header:SetPoint("TOP", -22, 12)
	local headerText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	headerText:SetPoint("TOP", header, "TOP", 0, -14)
	headerText:SetText("AddOn List")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -42, -3)

	-- Search
	local searchLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	searchLabel:SetPoint("TOPLEFT", 24, -24)
	searchLabel:SetText(SEARCH .. ":")
	searchBox = CreateFrame("EditBox", NAME .. "Search", frame, "InputBoxTemplate")
	searchBox:SetSize(170, 20)
	searchBox:SetPoint("TOPLEFT", 30, -38)
	searchBox:SetAutoFocus(false) -- InputBoxTemplate would otherwise grab the keyboard on show
	searchBox:SetScript("OnTextChanged", function(self)
		query = self:GetText() or ""
		refresh()
	end)
	searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

	-- Filter
	local showLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	showLabel:SetPoint("TOPLEFT", 232, -24)
	showLabel:SetText("Show:")
	createDropdown()
	dropdown:SetPoint("TOPLEFT", 212, -36)

	-- Load out of date AddOns (only if this client exposes the switch in game)
	if type(IsAddonVersionCheckEnabled) == "function" and type(SetAddonVersionCheck) == "function" then
		local force = CreateFrame("CheckButton", NAME .. "ForceLoad", frame, "UICheckButtonTemplate")
		force:SetSize(32, 32)
		force:SetPoint("TOPLEFT", 400, -30)
		_G[force:GetName() .. "Text"]:SetFontObject(GameFontNormalSmall)
		_G[force:GetName() .. "Text"]:SetText("Load out of date AddOns")
		force:SetScript("OnShow", function(self) self:SetChecked(not IsAddonVersionCheckEnabled()) end)
		force:SetScript("OnClick", function(self)
			SetAddonVersionCheck(self:GetChecked() and 0 or 1)
			updateRows()
		end)
	end

	-- List
	for i = 1, ROWS do createRow(i) end
	scroll = CreateFrame("ScrollFrame", NAME .. "Scroll", frame, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 37, -78)
	scroll:SetSize(520, ROWS * ROW_HEIGHT)
	scroll:SetScript("OnVerticalScroll", function(self, value)
		FauxScrollFrame_OnVerticalScroll(self, value, ROW_HEIGHT, updateRows)
	end)
	-- The scroll frame only needs the mouse wheel; keep the rows above it for clicks/tooltips,
	-- and let a wheel over a row scroll the list too.
	for i = 1, ROWS do
		rows[i]:SetFrameLevel(scroll:GetFrameLevel() + 2)
		rows[i]:EnableMouseWheel(true)
		rows[i]:SetScript("OnMouseWheel", function(_, delta) ScrollFrameTemplate_OnMouseWheel(scroll, delta) end)
	end

	-- Bottom buttons
	disableButton = createButton("Disable All", 130, function() setShownEnabled(false) end)
	disableButton:SetPoint("BOTTOMLEFT", 20, 14)
	enableButton = createButton("Enable All", 130, function() setShownEnabled(true) end)
	enableButton:SetPoint("LEFT", disableButton, "RIGHT", 4, 0)
	local cancel = createButton(CANCEL, 110, function() frame:Hide() end)
	cancel:SetPoint("BOTTOMRIGHT", -48, 14)
	okayButton = createButton(OKAY, 110, function()
		local changed = hasPending()
		for name, on in pairs(pending) do
			if on then EnableAddOn(name) else DisableAddOn(name) end
		end
		wipe(pending)
		frame:Hide()
		if changed then ReloadUI() end
	end)
	okayButton:SetPoint("RIGHT", cancel, "LEFT", -4, 0)

	frame:SetScript("OnShow", function()
		UpdateAddOnMemoryUsage() -- once per open, for the tooltips
		refresh()
	end)
	frame:SetScript("OnHide", function()
		wipe(pending) -- closing without Okay (X, Esc, Cancel) discards changes
		menu:Hide()
		searchBox:ClearFocus()
	end)
end

local function toggle()
	if not frame then createFrame() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end

---------------------------------------------------------------------------
-- Esc menu button (between Macros and Logout) and /addons
---------------------------------------------------------------------------
local function addGameMenuButton()
	local button = CreateFrame("Button", "GameMenuButtonAddOns", GameMenuFrame, "GameMenuButtonTemplate")
	button:SetText(ADDONS)
	button:SetPoint("TOP", GameMenuButtonMacros, "BOTTOM", 0, -1)
	GameMenuButtonLogout:ClearAllPoints()
	GameMenuButtonLogout:SetPoint("TOP", button, "BOTTOM", 0, -1)
	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + button:GetHeight() + 1)
	button:SetScript("OnClick", function()
		PlaySound("igMainMenuOption")
		HideUIPanel(GameMenuFrame)
		toggle()
	end)
end

SLASH_ADDONMANAGER1 = "/addons"
SLASH_ADDONMANAGER2 = "/am"
SlashCmdList.ADDONMANAGER = toggle

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	addGameMenuButton()
end)
