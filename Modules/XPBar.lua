local _, ns = ...
local L = ns.L

-- Full-width experience strip along the very top of the screen.
-- Gradient fill, rested overlay, 10% ticks, a glowing edge and a shimmer on gain.
-- At max level it turns into the watched reputation bar.
local XP = ns.RegisterModule("XPBar", { dbKey = "xpbar" })
ns.XPBar = XP

local XP_FROM, XP_TO = { 0.56, 0.33, 0.95 }, { 0.31, 0.76, 0.97 }

local function FormatNumber(n)
	if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
	return tostring(n)
end

local function AtMaxLevel()
	if IsPlayerAtEffectiveMaxLevel then return IsPlayerAtEffectiveMaxLevel() end
	local max = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
	return UnitLevel("player") >= max
end

local function IsXPDisabled()
	return IsXPUserDisabled and IsXPUserDisabled()
end

local function WatchedFaction()
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local d = C_Reputation.GetWatchedFactionData()
		if d and d.name then
			return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding
		end
	elseif GetWatchedFactionInfo then
		local name, reaction, minV, maxV, value = GetWatchedFactionInfo()
		if name then return name, reaction, minV, maxV, value end
	end
end

local function SetGradient(tex, from, to)
	if tex.SetGradient and CreateColor then
		tex:SetGradient("HORIZONTAL", CreateColor(from[1], from[2], from[3], 1), CreateColor(to[1], to[2], to[3], 1))
	else
		tex:SetVertexColor(to[1], to[2], to[3])
	end
end

function XP:Build()
	local db = ns.db.xpbar
	local f = CreateFrame("Frame", "NovaUI_XPBar", UIParent)
	f:SetFrameStrata("LOW")
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	f:SetHeight(db.height)
	f:EnableMouse(true)
	self.frame = f

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(ns.TEXTURE)
	bg:SetAllPoints()
	bg:SetVertexColor(0.035, 0.037, 0.045, 0.92)

	local bottom = f:CreateTexture(nil, "BORDER")
	bottom:SetTexture(ns.TEXTURE)
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(1)
	bottom:SetVertexColor(0, 0, 0, 1)

	-- Soft drop shadow below the strip.
	local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	shadow:SetTexture(ns.TEXTURE)
	shadow:SetPoint("TOPLEFT", f, "BOTTOMLEFT")
	shadow:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT")
	shadow:SetHeight(4)
	if shadow.SetGradient and CreateColor then
		shadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.45))
	else
		shadow:SetVertexColor(0, 0, 0, 0.25)
	end

	-- Rested projection sits behind the main fill.
	local rested = CreateFrame("StatusBar", nil, f)
	rested:SetPoint("TOPLEFT", 0, 0)
	rested:SetPoint("BOTTOMRIGHT", 0, 1)
	rested:SetStatusBarTexture(ns.TEXTURE)
	rested:SetStatusBarColor(0.31, 0.76, 0.97, 0.25)
	rested:SetMinMaxValues(0, 1)
	self.rested = rested

	local bar = CreateFrame("StatusBar", nil, f)
	bar:SetAllPoints(rested)
	bar:SetFrameLevel(rested:GetFrameLevel() + 1)
	bar:SetStatusBarTexture(ns.TEXTURE)
	bar:SetMinMaxValues(0, 1)
	SetGradient(bar:GetStatusBarTexture(), XP_FROM, XP_TO)
	self.bar = bar

	-- Glowing leading edge.
	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture(ns.TEXTURE)
	spark:SetBlendMode("ADD")
	spark:SetSize(2, db.height)
	spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT")
	spark:SetVertexColor(1, 1, 1, 0.9)
	local glow = bar:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(ns.TEXTURE)
	glow:SetBlendMode("ADD")
	glow:SetSize(40, db.height)
	glow:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
	if glow.SetGradient and CreateColor then
		glow:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.35))
	end
	self.spark, self.glow = spark, glow

	-- Shimmer that sweeps the fill when experience is gained.
	local shimmer = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	shimmer:SetTexture(ns.TEXTURE)
	shimmer:SetBlendMode("ADD")
	shimmer:SetAllPoints(bar:GetStatusBarTexture())
	shimmer:SetVertexColor(1, 1, 1, 1)
	shimmer:SetAlpha(0)
	local anim = shimmer:CreateAnimationGroup()
	local a1 = anim:CreateAnimation("Alpha")
	a1:SetFromAlpha(0) a1:SetToAlpha(0.35) a1:SetDuration(0.12) a1:SetOrder(1)
	local a2 = anim:CreateAnimation("Alpha")
	a2:SetFromAlpha(0.35) a2:SetToAlpha(0) a2:SetDuration(0.6) a2:SetOrder(2)
	self.shimmer = anim

	-- 10% ticks.
	self.ticks = {}
	local tickLayer = CreateFrame("Frame", nil, f)
	tickLayer:SetAllPoints(bar)
	tickLayer:SetFrameLevel(bar:GetFrameLevel() + 2)
	for i = 1, 9 do
		local t = tickLayer:CreateTexture(nil, "OVERLAY")
		t:SetTexture(ns.TEXTURE)
		t:SetVertexColor(0, 0, 0, 0.55)
		t:SetWidth(1)
		self.ticks[i] = t
	end
	-- Pin each tick by its left edge only, so its 1px width is respected.
	tickLayer:SetScript("OnSizeChanged", function(_, w)
		for i, t in ipairs(XP.ticks) do
			local x = math.floor(w * i / 10 + 0.5)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", tickLayer, "TOPLEFT", x, 0)
			t:SetPoint("BOTTOMLEFT", tickLayer, "BOTTOMLEFT", x, 0)
		end
	end)
	self.tickLayer = tickLayer

	-- Inline text, only when the strip is tall enough to hold it.
	local text = ns.CreateText(tickLayer, 10, "OVERLAY", "OUTLINE")
	text:SetPoint("CENTER", 0, 0)
	self.text = text

	self:BuildInfo(f)

	f:SetScript("OnEnter", function(frame) XP:ShowTooltip(frame) end)
	f:SetScript("OnLeave", GameTooltip_Hide)
end

function XP:ApplyLayout()
	local db = ns.db.xpbar
	local f = self.frame
	if not f then return end
	f:SetHeight(db.height)
	self.spark:SetHeight(db.height)
	self.glow:SetHeight(db.height)
	self.tickLayer:SetShown(true)
	for _, t in ipairs(self.ticks) do t:SetShown(db.ticks) end
	self.inline = db.height >= 12
	ns.SetFont(self.text, math.min(13, math.max(9, db.height - 3)), "OUTLINE")
	self:Update()
end

-- "%46,3" in Turkish, "46.3%" in English.
local function Percent(v, decimals)
	local str = ("%." .. (decimals or 1) .. "f"):format(v)
	if ns.db.language == "tr" then
		return "%" .. (str:gsub("%.", ","))
	end
	return str .. "%"
end

-- 9800 -> "9.800" (Turkish) / "9,800" (English).
local function Thousands(n)
	local sep = ns.db.language == "tr" and "." or ","
	local str = tostring(math.floor(n + 0.5))
	local out = str:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
	return (out:gsub("^%" .. sep, ""))
end

local function Duration(sec)
	local tr = ns.db.language == "tr"
	local m = math.floor(sec / 60 + 0.5)
	if m < 1 then return tr and "<1 dk" or "<1m" end
	local h = math.floor(m / 60)
	if tr then
		if m < 60 then return ("%d dk"):format(m) end
		return ("%d sa %d dk"):format(h, m % 60)
	end
	if m < 60 then return ("%dm"):format(m) end
	return ("%dh %dm"):format(h, m % 60)
end

---------------------------------------------------------------------------
-- Info panel hanging under a thin bar:
-- [ level badge ] [ %46,3  4.512 / 9.800 ] [ rested ] [ ~38 min to level ]
---------------------------------------------------------------------------

local MUTED = { 0.56, 0.6, 0.66 }
local RESTED = { 0.5, 0.8, 1 }

function XP:BuildInfo(f)
	local info = CreateFrame("Frame", "NovaUI_XPInfo", f)
	info:SetPoint("TOP", f, "BOTTOM", 0, -2)
	info:SetHeight(24)
	info:EnableMouse(true)
	ns.CreatePanel(info, { 0.035, 0.037, 0.045, 0.92 })
	info:SetScript("OnEnter", function(frame) XP:ShowTooltip(frame) end)
	info:SetScript("OnLeave", GameTooltip_Hide)

	-- Level badge in the bar's own gradient.
	local badge = CreateFrame("Frame", nil, info)
	badge:SetPoint("TOPLEFT", 1, -1)
	badge:SetPoint("BOTTOMLEFT", 1, 1)
	badge:SetWidth(26)
	local bt = badge:CreateTexture(nil, "ARTWORK")
	bt:SetTexture(ns.TEXTURE)
	bt:SetAllPoints()
	if bt.SetGradient and CreateColor then
		bt:SetGradient("VERTICAL", CreateColor(XP_FROM[1], XP_FROM[2], XP_FROM[3], 1), CreateColor(XP_TO[1], XP_TO[2], XP_TO[3], 1))
	else
		bt:SetVertexColor(XP_TO[1], XP_TO[2], XP_TO[3])
	end
	badge.text = ns.CreateText(badge, 13, "OVERLAY", "OUTLINE")
	badge.text:SetPoint("CENTER", 0, 0)
	info.badge = badge

	info.pct = ns.CreateText(info, 13)
	info.pct:SetTextColor(1, 1, 1)
	info.nums = ns.CreateText(info, 11)
	info.nums:SetTextColor(unpack(MUTED))

	info.restIcon = info:CreateTexture(nil, "ARTWORK")
	info.restIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	info.restIcon:SetTexCoord(0, 0.5, 0, 0.421875)
	info.restIcon:SetSize(16, 16)
	info.restText = ns.CreateText(info, 11)
	info.restText:SetTextColor(unpack(RESTED))

	info.eta = ns.CreateText(info, 11)
	info.eta:SetTextColor(unpack(MUTED))

	info.dividers = {}
	for i = 1, 3 do
		local d = info:CreateTexture(nil, "ARTWORK")
		d:SetTexture(ns.TEXTURE)
		d:SetVertexColor(1, 1, 1, 0.08)
		d:SetWidth(1)
		info.dividers[i] = d
	end

	-- "+350" that floats up and fades on every gain.
	local gain = ns.CreateText(info, 12, "OVERLAY", "OUTLINE")
	gain:SetTextColor(0.45, 0.95, 0.6)
	gain:SetPoint("LEFT", info, "RIGHT", 8, 0)
	gain:SetAlpha(0)
	local ag = gain:CreateAnimationGroup()
	local up = ag:CreateAnimation("Translation")
	up:SetOffset(0, 14)
	up:SetDuration(1.4)
	up:SetSmoothing("OUT")
	local fadeIn = ag:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.15)
	local fadeOut = ag:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetStartDelay(0.7)
	fadeOut:SetDuration(0.7)
	ag:SetScript("OnFinished", function() gain:SetAlpha(0) end)
	info.gain, info.gainAnim = gain, ag

	self.info = info
end

-- Lays the segments out left to right, hiding empty ones.
function XP:LayoutInfo(d)
	local info = self.info
	local x = 1
	local div = 0
	local function divider()
		div = div + 1
		local t = info.dividers[div]
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", info, "TOPLEFT", x + 1, -5)
		t:SetPoint("BOTTOMLEFT", info, "BOTTOMLEFT", x + 1, 5)
		t:Show()
		x = x + 3
	end
	for _, t in ipairs(info.dividers) do t:Hide() end

	info.badge:SetShown(d.level ~= nil)
	if d.level then
		info.badge.text:SetText(d.level)
		x = x + 26
	end

	x = x + 9
	info.pct:ClearAllPoints()
	info.pct:SetPoint("LEFT", info, "LEFT", x, 0)
	info.pct:SetText(d.pct)
	x = x + math.ceil(info.pct:GetStringWidth()) + 7
	info.nums:ClearAllPoints()
	info.nums:SetPoint("LEFT", info, "LEFT", x, 0)
	info.nums:SetText(d.nums)
	x = x + math.ceil(info.nums:GetStringWidth()) + 9

	local hasRest = d.rested ~= nil
	info.restIcon:SetShown(hasRest)
	info.restText:SetShown(hasRest)
	if hasRest then
		divider()
		info.restIcon:ClearAllPoints()
		info.restIcon:SetPoint("LEFT", info, "LEFT", x + 5, 0)
		info.restText:ClearAllPoints()
		info.restText:SetPoint("LEFT", info.restIcon, "RIGHT", 3, 0)
		info.restText:SetText(d.rested)
		x = x + 5 + 16 + 3 + math.ceil(info.restText:GetStringWidth()) + 9
	end

	info.eta:SetShown(d.eta ~= nil)
	if d.eta then
		divider()
		info.eta:ClearAllPoints()
		info.eta:SetPoint("LEFT", info, "LEFT", x + 6, 0)
		info.eta:SetText(d.eta)
		x = x + 6 + math.ceil(info.eta:GetStringWidth()) + 9
	end

	info:SetWidth(x + 1)
end

function XP:ShowGain(amount)
	local info = self.info
	if not info or amount <= 0 then return end
	info.gain:SetText("+" .. Thousands(amount))
	info.gainAnim:Stop()
	info.gainAnim:Play()
end

-- Shows the data inside a tall bar, or on the info panel under a thin one.
function XP:SetLabel(d)
	local db = ns.db.xpbar
	local show = db.showText and d ~= nil
	self.text:SetShown(show and self.inline)
	self.info:SetShown(show and not self.inline)
	if not show then return end
	if self.inline then
		local text = d.level and ("%s %s  ·  |cffffffff%s|r"):format(L.LEVEL, d.level, d.pct)
			or ("%s  ·  %s"):format(d.nums, d.pct)
		if d.rested then text = text .. "  ·  |cff7fd3ff" .. L.XP_RESTED .. " " .. d.rested .. "|r" end
		self.text:SetText(text)
	else
		self:LayoutInfo(d)
	end
end

function XP:Update()
	local f = self.frame
	if not f then return end
	local db = ns.db.xpbar

	if AtMaxLevel() or IsXPDisabled() then
		local name, reaction, minV, maxV, value = WatchedFaction()
		if not (db.reputation and name) then
			f:Hide()
			return
		end
		f:Show()
		self.mode = "rep"
		local range = math.max(1, (maxV or 1) - (minV or 0))
		local cur = (value or 0) - (minV or 0)
		self.bar:SetMinMaxValues(0, range)
		self.bar:SetValue(cur)
		self.rested:SetValue(0)
		local c = (FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]) or { r = 0.4, g = 0.8, b = 0.4 }
		SetGradient(self.bar:GetStatusBarTexture(), { c.r * 0.6, c.g * 0.6, c.b * 0.6 }, { c.r, c.g, c.b })
		self:SetLabel({ pct = Percent(cur / range * 100), nums = ("%s  %s / %s"):format(name, Thousands(cur), Thousands(range)) })
		self.repInfo = { name = name, reaction = reaction, cur = cur, range = range }
		return
	end

	f:Show()
	self.mode = "xp"
	local cur, max = UnitXP("player"), UnitXPMax("player")
	if not max or max <= 0 then max = 1 end
	local restedXP = GetXPExhaustion and GetXPExhaustion() or 0

	-- Session XP rate (a level-up counts the old bar's remainder too).
	local sess = self.session
	if self.lastXP then
		local delta = cur - self.lastXP
		if delta < 0 and self.lastMax then delta = (self.lastMax - self.lastXP) + cur end
		if delta > 0 then
			sess.gained = sess.gained + delta
			self.shimmer:Play()
			self:ShowGain(delta)
		end
	end
	self.lastXP, self.lastMax = cur, max

	SetGradient(self.bar:GetStatusBarTexture(), XP_FROM, XP_TO)
	self.bar:SetMinMaxValues(0, max)
	self.bar:SetValue(cur)
	self.rested:SetMinMaxValues(0, max)
	self.rested:SetValue(math.min(max, cur + (restedXP or 0)))

	local d = {
		level = tostring(UnitLevel("player")),
		pct = Percent(cur / max * 100),
		nums = ("%s / %s"):format(Thousands(cur), Thousands(max)),
	}
	if restedXP and restedXP > 0 then
		d.rested = Percent(math.min(150, restedXP / max * 100), 0)
	end
	local elapsed = GetTime() - sess.start
	if sess.gained > 0 and elapsed > 60 then
		local secs = (max - cur) / (sess.gained / elapsed)
		if secs < 100 * 3600 then
			d.eta = ns.db.language == "tr" and ("Seviyeye ~%s"):format(Duration(secs))
				or ("~%s to level"):format(Duration(secs))
		end
	end
	self:SetLabel(d)
end

function XP:ShowTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -6)
	if self.mode == "rep" and self.repInfo then
		local r = self.repInfo
		local standing = _G["FACTION_STANDING_LABEL" .. (r.reaction or 4)] or ""
		GameTooltip:AddLine(r.name, 1, 1, 1)
		GameTooltip:AddDoubleLine(standing, ("%s / %s  (%d%%)"):format(FormatNumber(r.cur), FormatNumber(r.range), r.cur / r.range * 100),
			0.8, 0.8, 0.8, 1, 1, 1)
	else
		local cur, max = UnitXP("player"), math.max(1, UnitXPMax("player"))
		local rested = GetXPExhaustion and GetXPExhaustion() or 0
		GameTooltip:AddLine(("%s %d"):format(LEVEL or "Level", UnitLevel("player")), 1, 1, 1)
		GameTooltip:AddDoubleLine(L.XP_CURRENT, ("%s / %s  (%.1f%%)"):format(FormatNumber(cur), FormatNumber(max), cur / max * 100),
			0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine(L.XP_REMAINING, FormatNumber(max - cur), 0.8, 0.8, 0.8, 1, 1, 1)
		if rested and rested > 0 then
			GameTooltip:AddDoubleLine(L.XP_RESTED, ("%s  (%.0f%%)"):format(FormatNumber(rested), rested / max * 100),
				0.8, 0.8, 0.8, 0.5, 0.83, 1)
		end
	end
	GameTooltip:Show()
end

local function HideBlizzardTracking()
	-- The bottom XP/reputation strips are replaced entirely.
	if StatusTrackingBarManager then
		ns.DisableBlizzard(StatusTrackingBarManager)
	end
	for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
		local c = _G[name]
		if c then
			c:SetAlpha(0)
			if c.EnableMouse then c:EnableMouse(false) end
		end
	end
end

function XP:Init()
	self.session = { start = GetTime(), gained = 0 }
	HideBlizzardTracking()
	self:Build()
	self:ApplyLayout()

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD",
		"UPDATE_FACTION", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event)
		XP:Update()
	end)
end
