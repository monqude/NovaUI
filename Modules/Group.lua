local _, ns = ...
local L = ns.L

-- Party and raid frames built on SecureGroupHeaderTemplate, so membership,
-- sorting and clicks are handled by the secure engine even in combat.
local G = ns.RegisterModule("Group", {})
ns.Group = G

local IsSecret, Exists = ns.IsSecret, ns.Exists

G.buttons = {}
G.byUnit = {}
G.headers = {}

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

local function CreateBorder(parent, thickness, r, g, b)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()
	f:SetFrameLevel(parent:GetFrameLevel() + 6)
	local function edge(p1, p2, horiz)
		local t = f:CreateTexture(nil, "OVERLAY")
		t:SetTexture(ns.TEXTURE)
		t:SetVertexColor(r, g, b, 1)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if horiz then t:SetHeight(thickness) else t:SetWidth(thickness) end
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT", false)
	edge("TOPRIGHT", "BOTTOMRIGHT", false)
	f:SetAlpha(0)
	return f
end

-- Called from the XML template's OnLoad for every spawned unit button.
function NovaUI_InitGroupButton(self, kind)
	self.kind = kind
	ns.CreatePanel(self, ns.colors.bgDark)

	local isParty = kind == "party"
	local health = ns.CreateHealthBar(self)
	health.lag:SetPoint("TOPLEFT", 1, -1)
	health.lag:SetPoint("BOTTOMRIGHT", -1, isParty and 6 or 1)
	self.Health = health

	if isParty then
		local power = ns.CreateBar(self)
		power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -1)
		power:SetPoint("BOTTOMRIGHT", -1, 1)
		self.Power = power
	end

	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetAllPoints(health)
	overlay:SetFrameLevel(health:GetFrameLevel() + 3)
	self.overlay = overlay

	self.Name = ns.CreateText(overlay, isParty and 12 or 11, "OVERLAY", "OUTLINE")
	self.Status = ns.CreateText(overlay, isParty and 12 or 10, "OVERLAY", "OUTLINE")
	if isParty then
		self.Status:SetPoint("RIGHT", -6, 0)
		self.Status:SetJustifyH("RIGHT")
		self.Name:SetPoint("LEFT", 6, 0)
		self.Name:SetPoint("RIGHT", self.Status, "LEFT", -4, 0)
		self.Name:SetJustifyH("LEFT")
	else
		self.Name:SetPoint("TOPLEFT", 3, -4)
		self.Name:SetPoint("TOPRIGHT", -3, -4)
		self.Name:SetJustifyH("CENTER")
		self.Status:SetPoint("BOTTOM", 0, 4)
		self.Status:SetTextColor(unpack(ns.colors.muted))
	end

	self.Leader = overlay:CreateTexture(nil, "OVERLAY")
	self.Leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	self.Leader:SetSize(12, 12)
	self.Leader:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 4)
	self.Leader:SetAlpha(0)

	self.Ready = overlay:CreateTexture(nil, "OVERLAY")
	self.Ready:SetSize(16, 16)
	self.Ready:SetPoint("CENTER", self, "CENTER")
	self.Ready:Hide()

	self.TargetBorder = CreateBorder(self, 2, 1, 1, 1)

	self.highlight = overlay:CreateTexture(nil, "BACKGROUND")
	self.highlight:SetTexture(ns.TEXTURE)
	self.highlight:SetAllPoints(self)
	self.highlight:SetVertexColor(1, 1, 1, 0.07)
	self.highlight:SetBlendMode("ADD")
	self.highlight:Hide()

	self:HookScript("OnEnter", function(btn)
		btn.highlight:Show()
		if btn.unit then
			GameTooltip_SetDefaultAnchor(GameTooltip, btn)
			GameTooltip:SetUnit(btn.unit)
			GameTooltip:Show()
		end
	end)
	self:HookScript("OnLeave", function(btn)
		btn.highlight:Hide()
		GameTooltip:Hide()
	end)
	self:HookScript("OnAttributeChanged", function(btn, name, value)
		if name == "unit" then G:SetUnit(btn, value) end
	end)
	self:HookScript("OnShow", function(btn) G:UpdateButton(btn) end)

	G.buttons[#G.buttons + 1] = self
	G:SetUnit(self, self:GetAttribute("unit"))
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------

function G:SetUnit(b, unit)
	if b.unit and self.byUnit[b.unit] then self.byUnit[b.unit][b] = nil end
	b.unit = unit
	b.snap = true
	if unit then
		self.byUnit[unit] = self.byUnit[unit] or {}
		self.byUnit[unit][b] = true
	end
	self:UpdateButton(b)
end

local function SetBoolAlpha(region, value, onAlpha, offAlpha)
	if IsSecret(value) then
		if region.SetAlphaFromBoolean then region:SetAlphaFromBoolean(value, onAlpha, offAlpha) end
	else
		region:SetAlpha(value and onAlpha or offAlpha)
	end
end

function G:UpdateHealth(b)
	local unit = b.unit
	local dead, offline = UnitIsDeadOrGhost(unit), not UnitIsConnected(unit)
	if dead or offline then
		b.Health:SetHealth(1, 0, true)
	else
		b.Health:SetHealth(UnitHealthMax(unit), UnitHealth(unit), b.snap)
		b.Health:SetAbsorb(unit)
	end
	b.snap = nil

	if offline then
		b.Status:SetText(L.OFFLINE)
		b.Status:SetTextColor(unpack(ns.colors.muted))
	elseif dead then
		b.Status:SetText(UnitIsGhost(unit) and L.GHOST or L.DEAD)
		b.Status:SetTextColor(unpack(ns.colors.muted))
	elseif b.kind == "party" then
		b.Status:SetTextColor(unpack(ns.colors.text))
		ns.SetHealthText(b.Status, unit, "percent")
	else
		b.Status:SetText("")
	end
end

function G:UpdatePower(b)
	if not b.Power then return end
	b.Power:SetMinMaxValues(0, UnitPowerMax(b.unit))
	b.Power:SetSmoothValue(UnitPower(b.unit))
	b.Power:SetColor(ns.UnitPowerColor(b.unit))
end

function G:UpdateName(b)
	local name = UnitName(b.unit)
	if not Exists(name) then name = "" end
	b.Name:SetText(name)
	local r, g, bl = ns.UnitHealthColor(b.unit)
	b.Health:SetUnitColor(r, g, bl)
	if ns.db.unitframes.style == "dark" then
		b.Name:SetTextColor(math.min(1, r + 0.1), math.min(1, g + 0.1), math.min(1, bl + 0.1))
	else
		b.Name:SetTextColor(unpack(ns.colors.text))
	end
end

function G:UpdateRange(b)
	if not ns.db.raid.rangeFade or b.unit == "player" then
		b:SetAlpha(1)
		return
	end
	local inRange, checked = UnitInRange(b.unit)
	if IsSecret(inRange) then
		SetBoolAlpha(b, inRange, 1, 0.4)
	elseif checked == false then
		b:SetAlpha(1)
	else
		b:SetAlpha(inRange and 1 or 0.4)
	end
end

function G:UpdateTarget(b)
	SetBoolAlpha(b.TargetBorder, UnitIsUnit(b.unit, "target"), 0.9, 0)
end

function G:UpdateLeader(b)
	SetBoolAlpha(b.Leader, UnitIsGroupLeader(b.unit), 1, 0)
end

local READY = {
	ready = READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady",
	waiting = READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

function G:UpdateReady(b, finished)
	if finished then b.Ready:Hide() return end
	local status = GetReadyCheckStatus and GetReadyCheckStatus(b.unit)
	if IsSecret(status) or not status or not READY[status] then
		b.Ready:Hide()
	else
		b.Ready:SetTexture(READY[status])
		b.Ready:Show()
	end
end

function G:UpdateButton(b)
	if not b or not b.unit or not UnitExists(b.unit) then return end
	pcall(function()
		G:UpdateName(b)
		G:UpdateHealth(b)
		G:UpdatePower(b)
		G:UpdateRange(b)
		G:UpdateTarget(b)
		G:UpdateLeader(b)
	end)
end

local function ForUnit(unit, fn)
	local set = unit and G.byUnit[unit]
	if not set then return end
	for b in pairs(set) do
		if b:IsVisible() and b.unit == unit then pcall(fn, G, b) end
	end
end

local function ForAll(fn, ...)
	for _, b in ipairs(G.buttons) do
		if b:IsVisible() and b.unit and UnitExists(b.unit) then pcall(fn, G, b, ...) end
	end
end

---------------------------------------------------------------------------
-- Headers
---------------------------------------------------------------------------

local INIT = [[
	local header = self:GetParent()
	self:SetWidth(header:GetAttribute("unitWidth"))
	self:SetHeight(header:GetAttribute("unitHeight"))
	self:SetAttribute("*type1", "target")
	self:SetAttribute("*type2", "togglemenu")
]]

local function HolderSize(kind)
	local cfg = ns.db[kind]
	if kind == "party" then
		return cfg.width, 5 * cfg.height + 4 * cfg.spacing
	end
	return 8 * cfg.width + 7 * cfg.spacing, 5 * cfg.height + 4 * cfg.spacing
end

local function CreateHeader(kind)
	local cfg = ns.db[kind]
	local key = kind == "party" and "Party" or "Raid"
	local w, h = HolderSize(kind)
	local holder = ns.CreateHolder(key, w, h, kind == "party" and L.PARTY or L.RAID)

	local header = CreateFrame("Frame", "NovaUI_" .. key .. "Header", holder, "SecureGroupHeaderTemplate")
	header:SetPoint("TOPLEFT", holder, "TOPLEFT")
	header:SetAttribute("template", kind == "party" and "NovaUI_PartyButtonTemplate" or "NovaUI_RaidButtonTemplate")
	header:SetAttribute("templateType", "Button")
	header:SetAttribute("initialConfigFunction", INIT)
	header:SetAttribute("unitWidth", cfg.width)
	header:SetAttribute("unitHeight", cfg.height)
	header:SetAttribute("point", "TOP")
	header:SetAttribute("yOffset", -cfg.spacing)
	header:SetAttribute("sortMethod", "INDEX")

	local max
	if kind == "party" then
		header:SetAttribute("showParty", true)
		header:SetAttribute("showPlayer", cfg.showPlayer)
		header:SetAttribute("showSolo", false)
		max = 5
	else
		header:SetAttribute("showRaid", true)
		header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
		header:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
		header:SetAttribute("groupBy", "GROUP")
		header:SetAttribute("maxColumns", 8)
		header:SetAttribute("unitsPerColumn", 5)
		header:SetAttribute("columnSpacing", cfg.spacing)
		header:SetAttribute("columnAnchorPoint", "LEFT")
		max = 40
	end

	-- Spawn every button now, out of combat, so nothing is created mid-fight.
	header:SetAttribute("startingIndex", -max + 1)
	header:Show()
	header:SetAttribute("startingIndex", 1)
	header:Hide()

	local driver = kind == "party" and "[group:raid] hide; [group:party] show; hide" or "[group:raid] show; hide"
	RegisterAttributeDriver(header, "state-visibility", driver)

	header.holder = holder
	G.headers[kind] = header
	return header
end

function G:ApplySize(kind)
	local header = self.headers[kind]
	if not header then return end
	ns.RunOOC("groupsize" .. kind, function()
		local cfg = ns.db[kind]
		header.holder:SetSize(HolderSize(kind))
		header:SetAttribute("unitWidth", cfg.width)
		header:SetAttribute("unitHeight", cfg.height)
		for _, b in ipairs(G.buttons) do
			if b.kind == kind then b:SetSize(cfg.width, cfg.height) end
		end
		if kind == "party" then header:SetAttribute("showPlayer", cfg.showPlayer) end
		if kind == "raid" then header:SetAttribute("columnSpacing", cfg.spacing) end
		header:SetAttribute("yOffset", -cfg.spacing)
	end)
end

function G:RefreshAll()
	ForAll(G.UpdateButton)
end

---------------------------------------------------------------------------
-- Blizzard frames
---------------------------------------------------------------------------

local function DisableBlizzardParty()
	if not PartyFrame then return end
	if PartyFrame.PartyMemberFramePool then
		for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
			ns.DisableBlizzard(frame)
		end
	end
	ns.DisableBlizzard(PartyFrame)
end

local function DisableBlizzardRaid()
	if CompactRaidFrameContainer then
		ns.DisableBlizzard(CompactRaidFrameContainer)
	end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function G:Init()
	local db = ns.db
	if not db.party.enabled and not db.raid.enabled then return end
	if InCombatLockdown() then
		ns.RunOOC("groupinit", function() G:Init() end)
		return
	end

	if db.party.enabled then
		DisableBlizzardParty()
		CreateHeader("party")
	end
	if db.raid.enabled then
		DisableBlizzardRaid()
		CreateHeader("raid")
	end

	local unitEvents = {
		UNIT_HEALTH = G.UpdateHealth, UNIT_MAXHEALTH = G.UpdateHealth, UNIT_ABSORB_AMOUNT_CHANGED = G.UpdateHealth, UNIT_CONNECTION = G.UpdateButton,
		UNIT_NAME_UPDATE = G.UpdateName, UNIT_FLAGS = G.UpdateHealth,
		UNIT_POWER_FREQUENT = G.UpdatePower, UNIT_MAXPOWER = G.UpdatePower, UNIT_DISPLAYPOWER = G.UpdatePower,
		UNIT_IN_RANGE_UPDATE = G.UpdateRange, READY_CHECK_CONFIRM = G.UpdateReady,
	}
	local ev = CreateFrame("Frame")
	for event in pairs(unitEvents) do pcall(ev.RegisterEvent, ev, event) end
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
		"PLAYER_ENTERING_WORLD", "READY_CHECK", "READY_CHECK_FINISHED" }) do
		pcall(ev.RegisterEvent, ev, event)
	end
	ev:SetScript("OnEvent", function(_, event, unit)
		local fn = unitEvents[event]
		if fn then
			ForUnit(unit, fn)
		elseif event == "PLAYER_TARGET_CHANGED" then
			ForAll(G.UpdateTarget)
		elseif event == "PARTY_LEADER_CHANGED" then
			ForAll(G.UpdateLeader)
		elseif event == "READY_CHECK" then
			ForAll(G.UpdateReady)
		elseif event == "READY_CHECK_FINISHED" then
			C_Timer.After(4, function() ForAll(G.UpdateReady, true) end)
		else
			ForAll(G.UpdateButton)
		end
	end)

	-- Safety net: some aliases (raidN == player) don't get their own events.
	C_Timer.NewTicker(0.5, function()
		ForAll(G.UpdateRange)
		ForAll(G.UpdateHealth)
	end)
end
