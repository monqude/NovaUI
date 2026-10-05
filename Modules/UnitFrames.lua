local _, ns = ...
local L = ns.L

local UF = ns.RegisterModule("UnitFrames", { dbKey = "unitframes" })
ns.UnitFrames = UF

local UnitExists, UnitIsConnected, UnitIsDeadOrGhost, UnitIsGhost = UnitExists, UnitIsConnected, UnitIsDeadOrGhost, UnitIsGhost
local UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax = UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax
local IsSecret, Plain = ns.IsSecret, ns.Plain

UF.frames = {}

---------------------------------------------------------------------------
-- Fading helper (works on plain holder frames; alpha is never protected)
---------------------------------------------------------------------------

local fading = {}
local fader = CreateFrame("Frame")
fader:Hide()
fader:SetScript("OnUpdate", function(self, elapsed)
	local any = false
	for frame, info in pairs(fading) do
		info.t = info.t + elapsed
		local p = math.min(1, info.t / info.dur)
		frame:SetAlpha(info.from + (info.to - info.from) * p)
		if p >= 1 then fading[frame] = nil else any = true end
	end
	if not any then self:Hide() end
end)

function ns.FadeTo(frame, alpha, dur)
	local cur = frame:GetAlpha()
	if math.abs(cur - alpha) < 0.01 then
		fading[frame] = nil
		frame:SetAlpha(alpha)
		return
	end
	fading[frame] = { from = cur, to = alpha, t = 0, dur = dur or 0.25 }
	fader:Show()
end

---------------------------------------------------------------------------
-- Value helpers (secret-safe)
---------------------------------------------------------------------------

local function HealthColor(unit)
	local db = ns.db.unitframes
	local c = ns.colors
	if not UnitIsConnected(unit) then return unpack(c.offline) end

	if UnitIsPlayer(unit) then
		if db.classColor then
			local _, class = UnitClass(unit)
			if not IsSecret(class) and class then return ns.ClassColor(class) end
		end
		return unpack(c.health)
	end

	if UnitIsTapDenied(unit) then return unpack(c.tapped) end

	local reaction = UnitReaction(unit, "player")
	if Plain(reaction) and c.reaction[reaction] then
		return unpack(c.reaction[reaction])
	end
	return unpack(c.health)
end

local function PowerColor(unit)
	local _, token = UnitPowerType(unit)
	if not IsSecret(token) and token then
		local mine = ns.colors.power[token]
		if mine then return unpack(mine) end
		local blizz = PowerBarColor and PowerBarColor[token]
		if blizz then return blizz.r, blizz.g, blizz.b end
	end
	return unpack(ns.colors.power.MANA)
end

-- Health text. Values may be secret, so they go straight into the widget
-- through SetFormattedText, which accepts secrets.
local hasPercentAPI = UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100
local function SetHealthText(fs, unit, mode)
	local ok = pcall(function()
		local cur = UnitHealth(unit)
		local short = AbbreviateNumbers and AbbreviateNumbers(cur) or cur
		if mode == "percent" and hasPercentAPI then
			fs:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		elseif mode == "both" and hasPercentAPI then
			fs:SetFormattedText("%s | %.0f%%", short, UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		else
			fs:SetFormattedText("%s", short)
		end
	end)
	if not ok then fs:SetText("") end
end

ns.UnitHealthColor = HealthColor
ns.UnitPowerColor = PowerColor
ns.SetHealthText = SetHealthText

---------------------------------------------------------------------------
-- Health bar: crisp fill plus a trailing "damage" bar that eases down behind
-- it. Both take (possibly secret) values straight from the API.
---------------------------------------------------------------------------

function ns.CreateHealthBar(parent)
	-- Trailing bar (bottom layer) owns the background.
	local lag = CreateFrame("StatusBar", nil, parent)
	lag:SetStatusBarTexture(ns.TEXTURE)
	lag:SetStatusBarColor(0.95, 0.3, 0.25, 0.7)
	lag:SetMinMaxValues(0, 1)
	lag.bg = lag:CreateTexture(nil, "BACKGROUND")
	lag.bg:SetTexture(ns.TEXTURE)
	lag.bg:SetAllPoints()

	local bar = ns.CreateBar(parent)
	bar:SetAllPoints(lag)
	bar:SetFrameLevel(lag:GetFrameLevel() + 1)
	bar.bg:SetAlpha(0)
	bar.lag = lag
	lag:SetScript("OnSizeChanged", nil)

	local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

	-- Absorb shield (nanShield-style): a translucent white segment that
	-- continues from the end of the health fill; anything past the bar's end
	-- is clipped. Values may be secret and go straight into the bar.
	local absorb = CreateFrame("StatusBar", nil, bar)
	absorb:SetStatusBarTexture(ns.TEXTURE)
	absorb:SetStatusBarColor(1, 1, 1, 0.38)
	absorb:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
	absorb:SetPoint("BOTTOMLEFT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
	absorb:SetMinMaxValues(0, 1)
	absorb:SetValue(0)
	bar:SetClipsChildren(true)
	bar:HookScript("OnSizeChanged", function(_, w) absorb:SetWidth(math.max(1, w)) end)
	bar.absorb = absorb

	function bar:SetAbsorb(unit)
		if not UnitGetTotalAbsorbs or not ns.db.unitframes.absorbs then
			self.absorb:SetValue(0)
			return
		end
		local ok = pcall(function()
			self.absorb:SetMinMaxValues(0, UnitHealthMax(unit))
			self.absorb:SetValue(UnitGetTotalAbsorbs(unit))
		end)
		if not ok then self.absorb:SetValue(0) end
	end

	function bar:SetHealth(max, value, immediate)
		self:SetMinMaxValues(0, max)
		self.lag:SetMinMaxValues(0, max)
		self:SetValue(value)
		if immediate or not interp then
			self.lag:SetValue(value)
		else
			self.lag:SetValue(value, interp)
		end
	end

	-- Two looks: "colored" (softened class/reaction fill) and "dark"
	-- (slate fill, the missing part tinted in the unit's color).
	function bar:SetUnitColor(r, g, b)
		if ns.db.unitframes.style == "dark" then
			self:SetStatusBarColor(0.15, 0.155, 0.175)
			self.lag.bg:SetVertexColor(r * 0.55, g * 0.55, b * 0.55, 1)
		else
			self:SetStatusBarColor(r * 0.88, g * 0.88, b * 0.88)
			self.lag.bg:SetVertexColor(0.07, 0.072, 0.082, 1)
		end
	end

	return bar
end

local function LevelText(unit)
	local level = UnitLevel(unit)
	if not Plain(level) then return "" end
	local class = UnitClassification(unit)
	if IsSecret(class) then class = nil end

	local r, g, b = 1, 0.82, 0
	local text
	if level <= 0 or class == "worldboss" then
		text, r, g, b = "??", 0.95, 0.25, 0.25
	else
		local color = (GetCreatureDifficultyColor and GetCreatureDifficultyColor(level))
			or (GetQuestDifficultyColor and GetQuestDifficultyColor(level))
		if color then r, g, b = color.r, color.g, color.b end
		text = tostring(level)
		if class == "elite" or class == "rareelite" then text = text .. "+" end
		if class == "rare" or class == "rareelite" then text = text .. " R" end
	end
	return ("|cff%02x%02x%02x%s|r "):format(r * 255, g * 255, b * 255, text)
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------

local function OnEnter(self)
	self.highlight:Show()
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(self.unit)
	GameTooltip:Show()
end

local function OnLeave(self)
	self.highlight:Hide()
	GameTooltip:Hide()
end

local function CreateUnitFrame(key, unit, label, width, height, opts)
	opts = opts or {}
	local holder = ns.CreateHolder(key, width, height, label)
	holder:SetScale(ns.db.unitframes.scale)

	local f = CreateFrame("Button", "NovaUI_" .. key, holder, "SecureUnitButtonTemplate")
	f:SetAllPoints(holder)
	f:SetAttribute("unit", unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "togglemenu")
	f:RegisterForClicks("AnyUp")
	f.unit = unit
	f.key = key
	f.opts = opts

	ns.CreatePanel(f, ns.colors.bgDark)

	-- Portrait style: square 3D portrait on one side, bars fill the rest and
	-- the power bar runs only under the health bar.
	local side = ns.db.unitframes.style == "portrait" and opts.portrait
	local barLeft, barRight = 1, -1
	if side then
		local size = height - 2
		local pf = CreateFrame("Frame", nil, f)
		pf:SetSize(size, size)
		if side == "left" then
			pf:SetPoint("TOPLEFT", 1, -1)
			barLeft = size + 2
		else
			pf:SetPoint("TOPRIGHT", -1, -1)
			barRight = -(size + 2)
		end
		local bg = pf:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(ns.TEXTURE)
		bg:SetAllPoints()
		bg:SetVertexColor(0.05, 0.065, 0.13, 1)

		local model = CreateFrame("PlayerModel", nil, pf)
		model:SetAllPoints()
		f.Portrait = model

		-- 2D fallback when the unit is out of visual range.
		local flat = pf:CreateTexture(nil, "ARTWORK")
		flat:SetPoint("TOPLEFT", 2, -2)
		flat:SetPoint("BOTTOMRIGHT", -2, 2)
		flat:SetTexCoord(0.12, 0.88, 0.12, 0.88)
		flat:Hide()
		f.PortraitFlat = flat

		local divider = f:CreateTexture(nil, "BORDER", nil, 7)
		divider:SetTexture(ns.TEXTURE)
		divider:SetVertexColor(0, 0, 0, 1)
		divider:SetWidth(1)
		divider:SetPoint("TOP", pf, side == "left" and "TOPRIGHT" or "TOPLEFT", side == "left" and 0.5 or -0.5, 0)
		divider:SetPoint("BOTTOM", pf, side == "left" and "BOTTOMRIGHT" or "BOTTOMLEFT", side == "left" and 0.5 or -0.5, 0)
	end

	local powerH = opts.power and (opts.powerHeight or 8) or 0
	local health = ns.CreateHealthBar(f)
	health.lag:SetPoint("TOPLEFT", barLeft, -1)
	health.lag:SetPoint("TOPRIGHT", barRight, -1)
	health.lag:SetHeight(height - 2 - (powerH > 0 and powerH + (side and 0 or 1) or 0))
	f.Health = health

	if powerH > 0 then
		local power = ns.CreateBar(f, true)
		local gap = side and 0 or -1
		power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, gap)
		power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, gap)
		power:SetHeight(powerH)
		f.Power = power
	end

	-- Text layer above the bars.
	local overlay = CreateFrame("Frame", nil, f)
	overlay:SetAllPoints(health)
	overlay:SetFrameLevel(health:GetFrameLevel() + 3)

	-- Portrait style uses the reference look: bold text with a soft shadow.
	local fontSize = opts.fontSize or 13
	local flags = side and "" or "OUTLINE"
	f.Name = ns.CreateText(overlay, fontSize, "OVERLAY", flags)
	f.HealthText = ns.CreateText(overlay, fontSize, "OVERLAY", flags)
	if side then
		for _, fs in ipairs({ f.Name, f.HealthText }) do
			fs:SetShadowOffset(1, -1)
			fs:SetShadowColor(0, 0, 0, 1)
		end
	end
	f.HealthText:SetJustifyH("RIGHT")

	if opts.nameCentered then
		f.Name:SetPoint("LEFT", 4, 0)
		f.Name:SetPoint("RIGHT", -4, 0)
		f.Name:SetJustifyH("CENTER")
		f.HealthText:Hide()
	else
		f.HealthText:SetPoint("RIGHT", -6, 0)
		f.Name:SetPoint("LEFT", 6, 0)
		f.Name:SetPoint("RIGHT", f.HealthText, "LEFT", -6, 0)
		f.Name:SetJustifyH("LEFT")
	end

	f.highlight = overlay:CreateTexture(nil, "BACKGROUND")
	f.highlight:SetTexture(ns.TEXTURE)
	f.highlight:SetPoint("TOPLEFT", f, 1, -1)
	f.highlight:SetPoint("BOTTOMRIGHT", f, -1, 1)
	f.highlight:SetVertexColor(1, 1, 1, 0.06)
	f.highlight:SetBlendMode("ADD")
	f.highlight:Hide()

	f:SetScript("OnEnter", OnEnter)
	f:SetScript("OnLeave", OnLeave)

	f.holder = holder
	UF.frames[key] = f
	return f
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------

function UF:UpdateHealth(f, immediate)
	local unit = f.unit
	if not UnitExists(unit) then return end
	local bar = f.Health

	local dead = UnitIsDeadOrGhost(unit)
	local offline = not UnitIsConnected(unit)

	if dead or offline then
		bar:SetHealth(1, 0, true)
	else
		bar:SetHealth(UnitHealthMax(unit), UnitHealth(unit), immediate)
		bar:SetAbsorb(unit)
	end

	if f.opts.nameCentered then return end
	if offline then
		f.HealthText:SetText(L.OFFLINE)
		f.HealthText:SetTextColor(unpack(ns.colors.muted))
	elseif dead then
		f.HealthText:SetText(UnitIsGhost(unit) and L.GHOST or L.DEAD)
		f.HealthText:SetTextColor(unpack(ns.colors.muted))
	else
		f.HealthText:SetTextColor(unpack(ns.colors.text))
		local mode = f.opts.healthMode or "value"
		if mode == "both" and not ns.db.unitframes.showPercent then mode = "value" end
		SetHealthText(f.HealthText, unit, mode)
	end
end

function UF:UpdatePower(f, immediate)
	local bar = f.Power
	if not bar or not UnitExists(f.unit) then return end
	bar:SetMinMaxValues(0, UnitPowerMax(f.unit))
	if immediate then
		bar:SetValue(UnitPower(f.unit))
	else
		bar:SetSmoothValue(UnitPower(f.unit))
	end
	bar:SetColor(PowerColor(f.unit))
end

function UF:UpdateName(f)
	local unit = f.unit
	if not UnitExists(unit) then return end
	-- The name may be secret: never test it, only hand it to the widget.
	local name = UnitName(unit)
	if not ns.Exists(name) then name = "" end
	if f.opts.showLevel then
		f.Name:SetFormattedText("%s%s", LevelText(unit), name)
	else
		f.Name:SetText(name)
	end

	local r, g, b = HealthColor(unit)
	f.Health:SetUnitColor(r, g, b)
	-- Dark style: the name carries the unit's color instead of the bar.
	if ns.db.unitframes.style == "dark" then
		f.Name:SetTextColor(math.min(1, r + 0.1), math.min(1, g + 0.1), math.min(1, b + 0.1))
	else
		f.Name:SetTextColor(unpack(ns.colors.text))
	end

	-- Elite / rare frame accent on the target.
	if f.opts.showLevel then
		local class = UnitClassification(unit)
		if IsSecret(class) then class = nil end
		local p = f.novaPanel
		if class == "worldboss" or class == "elite" or class == "rareelite" then
			p:SetBorderColor(0.95, 0.75, 0.3, 1)
		elseif class == "rare" then
			p:SetBorderColor(0.75, 0.8, 0.9, 1)
		else
			p:SetBorderColor(0, 0, 0, 1)
		end
	end
end

-- 3D portrait while the unit is in visual range, flat portrait otherwise.
function UF:UpdatePortrait(f)
	local model = f.Portrait
	if not model or not UnitExists(f.unit) then return end
	local unit = f.unit
	if UnitIsVisible(unit) and UnitIsConnected(unit) then
		f.PortraitFlat:Hide()
		model:Show()
		model:SetUnit(unit)
		model:SetPortraitZoom(1)
		model:SetPosition(0, 0, 0)
	else
		model:Hide()
		model:ClearModel()
		SetPortraitTexture(f.PortraitFlat, unit)
		f.PortraitFlat:Show()
	end
end

function UF:UpdateAll(f)
	if not UnitExists(f.unit) then return end
	self:UpdatePortrait(f)
	self:UpdateName(f)
	self:UpdateHealth(f, true)
	self:UpdatePower(f, true)
	if f.UpdateExtra then f:UpdateExtra() end
end

local unitEvents = {
	UNIT_HEALTH = "Health", UNIT_MAXHEALTH = "Health", UNIT_CONNECTION = "All", UNIT_ABSORB_AMOUNT_CHANGED = "Health",
	UNIT_POWER_FREQUENT = "Power", UNIT_MAXPOWER = "Power", UNIT_DISPLAYPOWER = "Power",
	UNIT_NAME_UPDATE = "Name", UNIT_LEVEL = "Name", UNIT_FACTION = "Name", UNIT_CLASSIFICATION_CHANGED = "Name",
	UNIT_FLAGS = "Name",
	UNIT_MODEL_CHANGED = "Portrait", UNIT_PORTRAIT_UPDATE = "Portrait",
}

local function Watch(f, ...)
	local ev = CreateFrame("Frame")
	for event in pairs(unitEvents) do
		pcall(ev.RegisterUnitEvent, ev, event, f.unit)
	end
	for i = 1, select("#", ...) do
		ev:RegisterEvent((select(i, ...)))
	end
	ev:SetScript("OnEvent", function(_, event)
		local what = unitEvents[event]
		if what == "Health" then UF:UpdateHealth(f)
		elseif what == "Power" then UF:UpdatePower(f)
		elseif what == "Name" then UF:UpdateName(f)
		elseif what == "Portrait" then UF:UpdatePortrait(f)
		else UF:UpdateAll(f) end
	end)
	f.events = ev
	return ev
end

---------------------------------------------------------------------------
-- Player extras: combat border, resting tag, out-of-combat fade
---------------------------------------------------------------------------

function UF:UpdateFade()
	local db = ns.db.unitframes
	local active = not db.fadeOutOfCombat
		or UnitAffectingCombat("player")
		or UnitExists("target")
		or ns.Exists(UnitCastingInfo("player"))
		or ns.Exists(UnitChannelInfo("player"))
		or not ns.locked
	local alpha = active and 1 or db.fadeAlpha
	for _, key in ipairs({ "Player", "Pet" }) do
		local f = self.frames[key]
		if f then ns.FadeTo(f.holder, alpha, 0.3) end
	end
end

local function SetupPlayer(f)
	f.Rest = ns.CreateText(f.Health, 10, "OVERLAY", "OUTLINE")
	f.Rest:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 3)
	f.Rest:SetTextColor(0.6, 0.85, 1)
	f.Rest:SetText("zZ")

	function f:UpdateExtra()
		self.Rest:SetShown(IsResting())
		local panel = self.novaPanel
		if UnitAffectingCombat("player") then
			panel:SetBorderColor(0.75, 0.16, 0.16, 1)
		else
			panel:SetBorderColor(0, 0, 0, 1)
		end
	end

	local ev = Watch(f, "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_ENABLED",
		"PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	local base = ev:GetScript("OnEvent")
	ev:SetScript("OnEvent", function(self, event, ...)
		if unitEvents[event] then return base(self, event, ...) end
		if event == "PLAYER_ENTERING_WORLD" then UF:UpdateAll(f) else f:UpdateExtra() end
		UF:UpdateFade()
	end)
end

---------------------------------------------------------------------------
-- Target extras: combo points
---------------------------------------------------------------------------

local function SetupComboPoints(f)
	local _, class = UnitClass("player")
	if class ~= "ROGUE" and class ~= "DRUID" then return end

	local max = 5
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
	bar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 4)
	bar:SetHeight(5)
	f.Combo = bar

	local gap = 3
	local pips = {}
	for i = 1, max do
		local pip = ns.CreateBar(bar)
		ns.CreatePanel(pip, { 0, 0, 0, 0 }, true)
		pip:SetHeight(5)
		-- Each pip is its own 0..1 bar over the [i-1, i] range, so a single
		-- (possibly secret) combo value lights up the right pips without math.
		pip:SetMinMaxValues(i - 1, i)
		pip:SetColor(1, 0.78, 0.25)
		pips[i] = pip
	end
	bar:SetScript("OnSizeChanged", function(self, w)
		local pw = (w - gap * (max - 1)) / max
		for i, pip in ipairs(pips) do
			pip:SetWidth(pw)
			pip:ClearAllPoints()
			pip:SetPoint("LEFT", (i - 1) * (pw + gap), 0)
		end
	end)

	local function Update()
		if not UnitExists("target") then bar:Hide() return end
		local cp = GetComboPoints("player", "target")
		local show
		if Plain(cp) then
			show = cp > 0
		else
			-- Secret: keep pips visible while the player uses energy.
			local _, token = UnitPowerType("player")
			show = IsSecret(token) or token == "ENERGY"
		end
		bar:SetShown(show)
		if not ns.Exists(cp) then cp = 0 end
		for _, pip in ipairs(pips) do pip:SetValue(cp) end
	end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	ev:SetScript("OnEvent", Update)
	Update()
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function UF:DisableBlizzardFrames()
	ns.DisableBlizzard(PlayerFrame)
	ns.DisableBlizzard(TargetFrame)
	ns.DisableBlizzard(PetFrame)
	ns.DisableBlizzard(ComboFrame)
	ns.DisableBlizzard(FocusFrame)
	for i = 1, 5 do ns.DisableBlizzard(_G["Boss" .. i .. "TargetFrame"]) end
	ns.DisableBlizzard(BossTargetFrameContainer)
end

function UF:Build()
	self:DisableBlizzardFrames()

	-- Player
	-- Portrait style uses the larger reference layout.
	local portrait = ns.db.unitframes.style == "portrait"
	local mw, mh = portrait and 280 or 232, portrait and 62 or 46
	local fs = portrait and 15 or 13
	local ph = portrait and 6 or 8

	local player = CreateUnitFrame("Player", "player", L.PLAYER, mw, mh,
		{ power = true, powerHeight = ph, healthMode = "both", portrait = "left", fontSize = fs })
	SetupPlayer(player)

	-- Target
	local target = CreateUnitFrame("Target", "target", L.TARGET, mw, mh,
		{ power = true, powerHeight = ph, healthMode = "both", showLevel = true, portrait = "right", fontSize = fs })
	RegisterUnitWatch(target)
	Watch(target, "PLAYER_TARGET_CHANGED")
	SetupComboPoints(target)

	-- Target of target (no unit events exist for it, so poll lightly)
	local tot = CreateUnitFrame("TargetTarget", "targettarget", L.TARGETTARGET, 150, 28,
		{ fontSize = 11, healthMode = "percent" })
	RegisterUnitWatch(tot)
	-- No events exist for targettarget: poll lightly, and snap (no trailing
	-- animation) whenever it switches to a different unit.
	local elapsed, lastName = 0, nil
	tot:HookScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.15 then return end
		elapsed = 0
		local name = UnitName("targettarget")
		local changed = true
		if not IsSecret(name) and not IsSecret(lastName) then
			changed = name ~= lastName
		end
		lastName = name
		UF:UpdateName(tot)
		UF:UpdateHealth(tot, changed)
	end)
	tot:HookScript("OnShow", function() lastName = nil UF:UpdateAll(tot) end)
	local totEv = CreateFrame("Frame")
	totEv:RegisterEvent("PLAYER_TARGET_CHANGED")
	totEv:RegisterUnitEvent("UNIT_TARGET", "target")
	totEv:SetScript("OnEvent", function() lastName = nil if tot:IsVisible() then UF:UpdateAll(tot) end end)

	-- Pet
	local pet = CreateUnitFrame("Pet", "pet", L.PET, 150, 28,
		{ fontSize = 11, healthMode = "percent" })
	RegisterUnitWatch(pet)
	Watch(pet, "UNIT_PET")
	pet:HookScript("OnShow", function() UF:UpdateAll(pet) end)

	if ns.db.unitframes.personal then self:BuildPersonal() end

	-- Focus
	local focus = CreateUnitFrame("Focus", "focus", L.FOCUS, 180, 38,
		{ power = true, powerHeight = 6, healthMode = "both", showLevel = true, fontSize = 12 })
	RegisterUnitWatch(focus)
	Watch(focus, "PLAYER_FOCUS_CHANGED")

	-- Boss 1-5
	for i = 1, 5 do
		local boss = CreateUnitFrame("Boss" .. i, "boss" .. i, L.BOSS .. " " .. i, 190, 34,
			{ power = true, powerHeight = 5, healthMode = "percent", fontSize = 12 })
		RegisterUnitWatch(boss)
		Watch(boss, "INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		boss:HookScript("OnShow", function() UF:UpdateAll(boss) end)
	end

	for _, f in pairs(self.frames) do self:UpdateAll(f) end
	self:UpdateFade()
end

-- Personal resource display: a small health/power strip under your character,
-- shown in combat.
function UF:BuildPersonal()
	local holder = ns.CreateHolder("Personal", 170, 15, L.PERSONAL)
	local f = CreateFrame("Frame", "NovaUI_Personal", holder)
	f:SetAllPoints(holder)
	ns.CreatePanel(f, ns.colors.bgDark)
	local hb = ns.CreateHealthBar(f)
	hb.lag:SetPoint("TOPLEFT", 1, -1)
	hb.lag:SetPoint("TOPRIGHT", -1, -1)
	hb.lag:SetHeight(9)
	local pb = ns.CreateBar(f, true)
	pb:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -1)
	pb:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", 0, -1)
	pb:SetHeight(3)
	self.personal = { holder = holder, frame = f, health = hb, power = pb }

	local function Update(immediate)
		hb:SetHealth(UnitHealthMax("player"), UnitHealth("player"), immediate)
		hb:SetAbsorb("player")
		hb:SetUnitColor(HealthColor("player"))
		pb:SetMinMaxValues(0, UnitPowerMax("player"))
		pb:SetSmoothValue(UnitPower("player"))
		pb:SetColor(PowerColor("player"))
	end
	local function Visibility()
		f:SetShown(UnitAffectingCombat("player") or not ns.locked)
	end
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
		"UNIT_DISPLAYPOWER", "UNIT_ABSORB_AMOUNT_CHANGED" }) do
		pcall(ev.RegisterUnitEvent, ev, e, "player")
	end
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function(_, event)
		if event:find("^PLAYER") then Visibility() Update(true) else Update() end
	end)
	holder.OnUnlock = Visibility
	Update(true)
	Visibility()
end

function UF:SetScale()
	-- Holders contain secure buttons: apply now, or right after combat.
	ns.RunOOC("ufscale", function()
		for _, f in pairs(UF.frames) do f.holder:SetScale(ns.db.unitframes.scale) end
	end)
end

function UF:RefreshAll()
	if not self.frames.Player then return end
	for _, f in pairs(self.frames) do self:UpdateAll(f) end
	self:UpdateFade()
end

function UF:Init()
	if InCombatLockdown() then
		local wait = CreateFrame("Frame")
		wait:RegisterEvent("PLAYER_REGEN_ENABLED")
		wait:SetScript("OnEvent", function(self)
			self:UnregisterAllEvents()
			UF:Build()
		end)
		return
	end
	self:Build()
end
