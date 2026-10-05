local _, ns = ...

-- Square, borderless minimap. Blizzard's frames stay where Edit Mode puts them;
-- only the art is replaced, so nothing fights the layout system.
local MM = ns.RegisterModule("Minimap", { dbKey = "minimap" })
ns.Minimap = MM

local MASK = "Interface\\Buttons\\WHITE8X8"

local function Hide(region)
	if region then region:SetAlpha(0) end
end

local function ZoneColor()
	local pvpType = C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo() or (GetZonePVPInfo and GetZonePVPInfo())
	if pvpType == "sanctuary" then return 0.41, 0.8, 0.94 end
	if pvpType == "arena" or pvpType == "hostile" or pvpType == "combat" then return 1, 0.32, 0.32 end
	if pvpType == "friendly" then return 0.4, 0.92, 0.45 end
	if pvpType == "contested" then return 1, 0.75, 0.25 end
	return 0.95, 0.95, 0.95
end

function MM:ApplyShape()
	Minimap:SetMaskTexture(MASK)
	Hide(MinimapCompassTexture)
	Hide(MinimapCompassTextureUnderlay)
	if MinimapCluster.DielFrame then Hide(MinimapCluster.DielFrame) end
end

function MM:ApplySize()
	local size = ns.db.minimap.size
	Minimap:SetSize(size, size)
	if MinimapBackdrop then MinimapBackdrop:SetSize(size, size) end
	-- Force the engine to re-render the map texture at the new size.
	local zoom = Minimap:GetZoom()
	Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
	Minimap:SetZoom(zoom)
end

function MM:UpdateZone()
	if not self.zone then return end
	self.zone:SetText(GetMinimapZoneText())
	self.zone:SetTextColor(ZoneColor())
	self.zone:SetShown(ns.db.minimap.zoneText)
end

function MM:CreateDayNight()
	-- Forever's day/night cycle, shown as a small corner badge instead of the ring.
	if not (C_DateAndTime and C_DateAndTime.IsDayTime) then return end
	local badge = Minimap:CreateTexture(nil, "OVERLAY", nil, 7)
	badge:SetSize(20, 20)
	badge:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)

	local function Set(isDay)
		local ok = pcall(badge.SetAtlas, badge, isDay and "UI-HUD-Minimap-DayCycle" or "UI-HUD-Minimap-NightCycle")
		badge:SetShown(ok)
	end
	Set(C_DateAndTime.IsDayTime())

	local ev = CreateFrame("Frame")
	if pcall(ev.RegisterEvent, ev, "DIEL_CYCLE_CHANGED") then
		ev:SetScript("OnEvent", function(_, _, isDay) Set(isDay) end)
	end
end

function MM:Init()
	if not Minimap or not MinimapCluster then return end

	-- Lets LibDBIcon & co. place their buttons for a square map.
	if not GetMinimapShape then
		function GetMinimapShape() return "SQUARE" end
	end

	self:ApplyShape()
	-- Blizzard re-applies its mask when the rotate setting changes.
	if CVarCallbackRegistry then
		CVarCallbackRegistry:RegisterCallback("rotateMinimap", function()
			C_Timer.After(0, function() MM:ApplyShape() end)
		end, self)
	end

	-- Strip the circular frame art and the zone pill.
	Hide(MinimapCluster.BorderTop)
	Hide(MinimapCluster.ZoneTextButton)
	if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:EnableMouse(false) end
	Hide(Minimap.ZoomIn)
	Hide(Minimap.ZoomOut)
	if Minimap.ZoomIn then Minimap.ZoomIn:EnableMouse(false) end
	if Minimap.ZoomOut then Minimap.ZoomOut:EnableMouse(false) end
	if Minimap.ZoomHitArea then Minimap.ZoomHitArea:EnableMouse(false) end

	self:ApplySize()
	ns.CreatePanel(Minimap, { 0, 0, 0, 0 })

	-- Zone name inside the top edge.
	local overlay = CreateFrame("Frame", nil, Minimap)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	local zone = ns.CreateText(overlay, 12, "OVERLAY", "OUTLINE")
	zone:SetPoint("TOP", 0, -6)
	zone:SetWidth(ns.db.minimap.size - 50)
	zone:SetJustifyH("CENTER")
	self.zone = zone
	self.overlay = overlay

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function() MM:UpdateZone() end)
	self:UpdateZone()

	-- Right-click opens tracking, middle-click opens the world map,
	-- left-click still pings.
	Minimap:SetScript("OnMouseUp", function(map, button)
		if button == "RightButton" then
			local tracking = MinimapCluster.Tracking and MinimapCluster.Tracking.Button
			if tracking and tracking.OpenMenu then
				tracking:OpenMenu()
			end
		elseif button == "MiddleButton" then
			ToggleWorldMap()
		elseif MinimapMixin and MinimapMixin.OnClick then
			MinimapMixin.OnClick(map)
		end
	end)
	Minimap:EnableMouseWheel(true)

	self:CreateDayNight()

	-- Coordinates live on the bottom bar; hide Blizzard's line under the map.
	local coords = MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords
	if coords then coords:SetAlpha(0) end
end

function MM:Refresh()
	if not self.zone then return end
	self:ApplySize()
	self.zone:SetWidth(ns.db.minimap.size - 50)
	self:UpdateZone()
end
