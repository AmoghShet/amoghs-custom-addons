-- Target frame threat %: a line of text below the target portrait (or below the
-- target-of-target frame when that is showing), in the font Blizzard uses for its own
-- numeric threat box. TargetFrame is a secure unit button, so everything lives on our own
-- insecure child frame; an insecure child of a secure frame stays unprotected (verified by
-- ClientProbe), so updating it in combat is allowed.

local ADDON, ns = ...

local floor = math.floor
local UnitDetailedThreatSituation, GetThreatStatusColor = UnitDetailedThreatSituation, GetThreatStatusColor

local UPDATE_INTERVAL = 0.2

local module = {}
table.insert(ns.modules, module)

local host, underPortrait, underToT

local function styleText(text)
	local font, size, flags = GameFontHighlight:GetFont()
	text:SetFont(font or [[Fonts\FRIZQT__.TTF]], (size or 12) * ns.db.fontScale, flags)
end

function module:Refresh()
	local db = ns.db
	styleText(underPortrait)
	styleText(underToT)
	-- Anchors only change on load or via /tm; combat updates just change the text.
	underPortrait:ClearAllPoints()
	underPortrait:SetPoint("TOP", TargetFramePortrait, "BOTTOM", db.x, db.y)
	underToT:ClearAllPoints()
	if TargetFrameToT then
		underToT:SetPoint("TOP", TargetFrameToT, "BOTTOM", db.x, db.y + 6)
	else
		underToT:SetPoint("TOP", TargetFramePortrait, "BOTTOM", db.x, db.y)
	end
	self:Update()
end

function module:Update()
	local totShown = TargetFrameToT and TargetFrameToT:IsShown()
	local text = totShown and underToT or underPortrait
	local other = totShown and underPortrait or underToT
	other:SetText("")

	local pct, status
	if ns.IsPreviewing() then
		pct, status = 75, 2
	elseif ns.db.enabled then
		local _
		_, status, pct = UnitDetailedThreatSituation("player", "target")
	end

	if pct and pct > 0 then
		text:SetFormattedText("%d%%", floor(pct))
		text:SetTextColor(GetThreatStatusColor(status))
	else
		text:SetText("")
	end
end

function module:Init()
	-- Parented to TargetFrame so it shows, hides and scales with it; its OnUpdate only
	-- runs while the target frame is visible.
	host = CreateFrame("Frame", nil, TargetFrame)
	host:SetAllPoints(TargetFrame)
	host:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)

	underPortrait = host:CreateFontString(nil, "OVERLAY")
	underPortrait:SetFontObject(GameFontHighlight)
	underToT = host:CreateFontString(nil, "OVERLAY")
	underToT:SetFontObject(GameFontHighlight)

	local elapsedSince = 0
	host:SetScript("OnUpdate", function(_, elapsed)
		elapsedSince = elapsedSince + elapsed
		if elapsedSince >= UPDATE_INTERVAL then
			elapsedSince = 0
			module:Update()
		end
	end)
	host:SetScript("OnEvent", function() module:Update() end)
	host:RegisterEvent("PLAYER_TARGET_CHANGED")
	host:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
	host:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")

	self:Refresh()
end
