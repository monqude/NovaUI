local _, ns = ...
local L = ns.L

-- Auto-attack ("white hit") timer driven by Forever's PLAYER_SWING event.
local SW = ns.RegisterModule("SwingTimer", { dbKey = "swing" })
ns.SwingTimer = SW

local GetTime = GetTime
local TYPES = Enum.PlayerSwingType or { MainHand = 0, OffHand = 1, Ranged = 2 }

local STYLE = {
	[TYPES.MainHand] = { color = { 0.95, 0.78, 0.35 }, label = "SWING_MH", key = "mh" },
	[TYPES.OffHand]  = { color = { 0.85, 0.55, 0.30 }, label = "SWING_OH", key = "oh" },
	[TYPES.Ranged]   = { color = { 0.45, 0.85, 0.55 }, label = "SWING_RANGED", key = "ranged" },
}

SW.bars = {}

-- UnitAttackSpeed can be secret while stats are restricted (in combat), so the
-- last readable value per swing type is cached and used as a fallback.
local speedCache = {}

local function AttackSpeed(swingType)
	local mh, oh, ranged = UnitAttackSpeed("player")
	local speed = mh
	if swingType == TYPES.OffHand then speed = oh end
	if swingType == TYPES.Ranged then speed = ranged end
	if ns.Plain(speed) then
		speedCache[swingType] = speed
		return speed
	end
	-- Only a readable nil means "no weapon"; a secret is never compared.
	if not ns.IsSecret(speed) and speed == nil then
		speedCache[swingType] = 0
		return 0
	end
	return speedCache[swingType]
end

local function HasWeapon(swingType)
	local speed = AttackSpeed(swingType)
	if speed == nil then
		-- Unknown (secret and never read): main hand always has an auto attack.
		return swingType == TYPES.MainHand
	end
	return speed > 0
end

local function Enabled(swingType)
	local db = ns.db.swing
	if swingType == TYPES.OffHand then return db.offhand end
	if swingType == TYPES.Ranged then return db.ranged end
	return true
end

local function OnUpdate(bar)
	local remaining = bar.endTime - GetTime()
	if remaining <= 0 then
		bar.endTime = nil
		bar:SetScript("OnUpdate", nil)
		bar.Bar:SetValue(1)
		bar.Time:SetText("")
		SW:UpdateVisibility()
		return
	end
	bar.Bar:SetValue(1 - remaining / bar.duration)
	bar.Time:SetFormattedText("%.1f", remaining)
end

local function CreateSwingBar(parent, swingType)
	local style = STYLE[swingType]
	local f = CreateFrame("Frame", nil, parent)
	f.swingType = swingType
	ns.CreatePanel(f, ns.colors.bgDark)

	local bar = ns.CreateBar(f)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	bar:SetColor(unpack(style.color))
	bar:SetMinMaxValues(0, 1)
	f.Bar = bar

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture(ns.TEXTURE)
	spark:SetBlendMode("ADD")
	spark:SetVertexColor(1, 1, 1, 0.8)
	spark:SetWidth(2)
	spark:SetPoint("TOP", bar:GetStatusBarTexture(), "TOPRIGHT")
	spark:SetPoint("BOTTOM", bar:GetStatusBarTexture(), "BOTTOMRIGHT")

	f.Time = ns.CreateText(f, 10, "OVERLAY", "OUTLINE")
	f.Time:SetPoint("LEFT", f, "RIGHT", 4, 0)
	f.Label = ns.CreateText(f, 9, "OVERLAY", "OUTLINE")
	f.Label:SetPoint("RIGHT", f, "LEFT", -4, 0)
	f.Label:SetText(L[style.label])
	f.Label:SetTextColor(unpack(ns.colors.muted))

	SW.bars[swingType] = f
	return f
end

function SW:Start(swingType, duration)
	local bar = self.bars[swingType]
	if not bar or not Enabled(swingType) then return end
	if not ns.Plain(duration) then duration = AttackSpeed(swingType) end
	if not duration or duration <= 0 then return end
	bar.duration = duration
	bar.endTime = GetTime() + duration
	bar.Bar:SetValue(0)
	bar:SetScript("OnUpdate", OnUpdate)
	self:UpdateVisibility()
end

-- Haste changes mid-swing: keep the same progress, rescale what's left.
function SW:Rescale()
	for swingType, bar in pairs(self.bars) do
		if bar.endTime then
			local mh, oh, ranged = UnitAttackSpeed("player")
			local speed = (swingType == TYPES.OffHand and oh) or (swingType == TYPES.Ranged and ranged) or mh
			if ns.Plain(speed) and speed > 0 and bar.duration > 0 then
				speedCache[swingType] = speed
				local remaining = bar.endTime - GetTime()
				local newRemaining = remaining * speed / bar.duration
				bar.duration = speed
				bar.endTime = GetTime() + newRemaining
			end
		end
	end
end

function SW:Layout()
	local db = ns.db.swing
	local holder = self.holder
	if not holder then return end
	local y, shown = 0, 0
	for _, swingType in ipairs({ TYPES.MainHand, TYPES.OffHand, TYPES.Ranged }) do
		local bar = self.bars[swingType]
		if bar:IsShown() then
			bar:ClearAllPoints()
			bar:SetPoint("TOP", holder, "TOP", 0, -y)
			bar:SetSize(db.width, db.height)
			y = y + db.height + 3
			shown = shown + 1
		end
	end
	holder:SetSize(db.width, math.max(db.height, y - 3))
end

function SW:UpdateVisibility()
	local inCombat = UnitAffectingCombat("player")
	for swingType, bar in pairs(self.bars) do
		local swinging = bar.endTime ~= nil
		local show
		if swingType == TYPES.Ranged then
			-- Only while actually shooting.
			show = Enabled(swingType) and swinging
		else
			-- A running swing always shows; otherwise idle in combat if armed.
			show = Enabled(swingType) and (swinging or (inCombat and HasWeapon(swingType)))
		end
		show = show or (not ns.locked and Enabled(swingType))
		bar:SetShown(show)
	end
	self:Layout()
end

function SW:SetOutOfRange(swingType, out)
	local bar = self.bars[swingType]
	if bar then bar:SetAlpha(out and 0.4 or 1) end
end

local function DisableBlizzardSwing()
	for _, name in ipairs({ "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }) do
		local f = _G[name]
		if f then
			f:SetAlpha(0)
			hooksecurefunc(f, "SetAlpha", function(self, a) if a ~= 0 then self:SetAlpha(0) end end)
		end
	end
end

function SW:Init()
	DisableBlizzardSwing()

	local holder = ns.CreateHolder("Swing", ns.db.swing.width, ns.db.swing.height, L.SWING)
	self.holder = holder
	for _, swingType in ipairs({ TYPES.MainHand, TYPES.OffHand, TYPES.Ranged }) do
		CreateSwingBar(holder, swingType)
	end
	holder.OnUnlock = function() SW:UpdateVisibility() end

	-- The client only dispatches PLAYER_SWING while the swing timer option is on.
	-- Blizzard's own bars stay invisible either way.
	if GetCVar and SetCVar and GetCVar("showSwingTimer") ~= nil and GetCVar("showSwingTimer") ~= "1" then
		pcall(SetCVar, "showSwingTimer", "1")
	end

	if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
		pcall(C_SwingTimer.EnableRangeCheck, TYPES.MainHand, true)
		pcall(C_SwingTimer.EnableRangeCheck, TYPES.Ranged, true)
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
		"PLAYER_ENTERING_WORLD", "WEAPON_SLOT_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	pcall(ev.RegisterUnitEvent, ev, "UNIT_ATTACK_SPEED", "player")
	ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
		if SW.debug and (event == "PLAYER_SWING" or event == "PLAYER_SWING_RANGE_UPDATE") then
			ns.Print(event, tostring(a1), tostring(a2), tostring(a3))
		end
		if event == "PLAYER_SWING" then
			SW:Start(a2, a1)
		elseif event == "PLAYER_SWING_RANGE_UPDATE" then
			SW:SetOutOfRange(a1, a3 and not a2)
		elseif event == "UNIT_ATTACK_SPEED" then
			SW:Rescale()
		else
			SW:UpdateVisibility()
		end
	end)
	self:UpdateVisibility()
end
