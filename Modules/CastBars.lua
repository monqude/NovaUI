local _, ns = ...
local L = ns.L

local CB = ns.RegisterModule("CastBars", { dbKey = "castbars" })
ns.CastBars = CB

local Exists, Plain, IsSecret = ns.Exists, ns.Plain, ns.IsSecret
local GetTime = GetTime

CB.bars = {}

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function CreateCastBar(key, unit, label, width, height)
	local holder = ns.CreateHolder(key, width, height, label)
	holder:SetScale(ns.db.castbars.scale)

	local f = CreateFrame("Frame", "NovaUI_" .. key, holder)
	f:SetAllPoints(holder)
	f:Hide()
	f.unit = unit
	f.holder = holder
	ns.CreatePanel(f, ns.colors.bgDark)

	-- Icon on the left, separated by a 1px divider.
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetSize(height - 2, height - 2)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Icon = icon

	local divider = f:CreateTexture(nil, "BORDER", nil, 7)
	divider:SetTexture(ns.TEXTURE)
	divider:SetVertexColor(0, 0, 0, 1)
	divider:SetPoint("TOPLEFT", icon, "TOPRIGHT")
	divider:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT")
	divider:SetWidth(1)

	f.Divider = divider

	local bar = ns.CreateBar(f)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	f.Bar = bar

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture(ns.TEXTURE)
	spark:SetBlendMode("ADD")
	spark:SetVertexColor(1, 1, 1, 0.75)
	spark:SetSize(2, height - 2)
	spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT")
	f.Spark = spark

	-- Latency ("safe zone") shading at the end of player casts.
	if unit == "player" then
		local safe = bar:CreateTexture(nil, "ARTWORK", nil, 6)
		safe:SetTexture(ns.TEXTURE)
		safe:SetVertexColor(0.9, 0.25, 0.25, 0.35)
		safe:SetPoint("TOPRIGHT")
		safe:SetPoint("BOTTOMRIGHT")
		safe:Hide()
		f.Safe = safe
	end

	f.Time = ns.CreateText(bar, 12)
	f.Time:SetPoint("RIGHT", -5, 0)
	f.Time:SetJustifyH("RIGHT")

	f.Text = ns.CreateText(bar, 12)
	f.Text:SetPoint("LEFT", 5, 0)
	f.Text:SetPoint("RIGHT", f.Time, "LEFT", -6, 0)
	f.Text:SetJustifyH("LEFT")

	CB.bars[key] = f
	CB:ApplyLayout(f)
	return f
end

-- Size, icon and font follow the settings live.
function CB:ApplyLayout(f)
	local db = ns.db.castbars
	local isPlayer = f.unit == "player"
	local width = isPlayer and db.playerWidth or db.targetWidth
	local height = isPlayer and db.playerHeight or db.targetHeight
	f.holder:SetSize(width, height)

	local showIcon = db.icon
	f.Icon:SetSize(height - 2, height - 2)
	f.Icon:SetShown(showIcon)
	f.Divider:SetShown(showIcon)
	f.Bar:ClearAllPoints()
	if showIcon then
		f.Bar:SetPoint("TOPLEFT", f.Divider, "TOPRIGHT")
	else
		f.Bar:SetPoint("TOPLEFT", 1, -1)
	end
	f.Bar:SetPoint("BOTTOMRIGHT", -1, 1)
	f.Spark:SetHeight(height - 2)

	local size = math.max(9, math.min(14, math.floor(height * 0.55 + 0.5)))
	ns.SetFont(f.Time, size)
	ns.SetFont(f.Text, size)
end

function CB:ApplyAll()
	for _, f in pairs(self.bars) do self:ApplyLayout(f) end
end

---------------------------------------------------------------------------
-- Cast state
---------------------------------------------------------------------------

local function SetBarColor(f, notInterruptible, channel)
	local c = ns.colors
	local normal = channel and c.channel or c.cast
	if IsSecret(notInterruptible) then
		-- Let the engine pick the color from a secret boolean.
		local ok = pcall(function()
			local color = C_CurveUtil.EvaluateColorFromBoolean(notInterruptible,
				CreateColor(unpack(c.noInterrupt)), CreateColor(unpack(normal)))
			f.Bar:SetStatusBarColor(color:GetRGB())
		end)
		if not ok then f.Bar:SetStatusBarColor(unpack(normal)) end
		f.Bar.bg:SetVertexColor(0.08, 0.08, 0.09, 1)
		return
	end
	f.Bar:SetColor(unpack(notInterruptible and c.noInterrupt or normal))
end

local function OnUpdatePlain(f, elapsed)
	local now = GetTime()
	if now >= f.endTime then
		f:SetScript("OnUpdate", nil)
		return
	end
	local value = f.channel and (f.endTime - now) or (now - f.startTime)
	f.Bar:SetValue(value)
	f.Time:SetFormattedText("%.1f", f.endTime - now)
end

local function OnUpdateSecret(f)
	if not f.duration then return end
	if not pcall(f.Time.SetFormattedText, f.Time, "%.1f", f.duration:GetRemainingDuration()) then
		f.Time:SetText("")
		f:SetScript("OnUpdate", nil)
	end
end

local function OnUpdateFade(f, elapsed)
	f.hold = f.hold - elapsed
	if f.hold > 0 then return end
	local a = f:GetAlpha() - elapsed * 3
	if a <= 0 then
		f:SetScript("OnUpdate", nil)
		f:Hide()
		f:SetAlpha(1)
	else
		f:SetAlpha(a)
	end
end

function CB:Start(f, channel)
	local unit = f.unit
	local name, text, texture, startMS, endMS, notInterruptible, castID, _
	if channel then
		name, text, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
	else
		name, text, texture, startMS, endMS, _, castID, notInterruptible = UnitCastingInfo(unit)
	end
	f.castID = castID
	if not Exists(name) then
		f:Hide()
		return
	end

	f.casting = true
	f.channel = channel
	f:SetAlpha(1)
	f.Icon:SetTexture(texture)
	if Exists(text) then f.Text:SetText(text) else f.Text:SetText(name) end
	f.Spark:Show()
	SetBarColor(f, notInterruptible, channel)

	if Plain(startMS) and Plain(endMS) then
		f.duration = nil
		f.startTime = startMS / 1000
		f.endTime = endMS / 1000
		local total = math.max(0.001, f.endTime - f.startTime)
		f.Bar:SetMinMaxValues(0, total)
		OnUpdatePlain(f, 0)
		f:SetScript("OnUpdate", OnUpdatePlain)

		if f.Safe and ns.db.castbars.latency then
			local _, _, _, world = GetNetStats()
			local ratio = math.min(1, (world or 0) / 1000 / total)
			if ratio > 0 then
				f.Safe:SetWidth(math.max(1, f.Bar:GetWidth() * ratio))
				f.Safe:ClearAllPoints()
				if channel then
					f.Safe:SetPoint("TOPLEFT")
					f.Safe:SetPoint("BOTTOMLEFT")
				else
					f.Safe:SetPoint("TOPRIGHT")
					f.Safe:SetPoint("BOTTOMRIGHT")
				end
				f.Safe:Show()
			else
				f.Safe:Hide()
			end
		end
	else
		-- Restricted cast: hand the engine a duration object and let it animate.
		if f.Safe then f.Safe:Hide() end
		local getDuration = channel and UnitChannelDuration or UnitCastingDuration
		local duration = getDuration and getDuration(unit)
		if duration and f.Bar.SetTimerDuration and Enum.StatusBarTimerDirection then
			f.duration = duration
			local dir = channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
			f.Bar:SetTimerDuration(duration, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0, dir)
			f:SetScript("OnUpdate", OnUpdateSecret)
		else
			f.Bar:SetMinMaxValues(0, 1)
			f.Bar:SetValue(1)
			f.Time:SetText("")
			f:SetScript("OnUpdate", nil)
		end
	end

	f:Show()
end

function CB:Update(f, channel)
	-- Delays / channel updates: just re-read the cast.
	if f.casting then self:Start(f, channel) end
end

function CB:Finish(f, result)
	if not f.casting then return end
	f.casting = false
	f.duration = nil
	if f.Safe then f.Safe:Hide() end
	f.Spark:Hide()

	local c = ns.colors
	if result == "failed" or result == "interrupted" then
		f.Bar:SetColor(unpack(c.failed))
		f.Text:SetText(result == "interrupted" and L.INTERRUPTED or L.FAILED)
		f.hold = 0.5
	else
		f.Bar:SetColor(unpack(c.success))
		f.hold = 0.05
	end
	f.Bar:SetMinMaxValues(0, 1)
	f.Bar:SetValue(1)
	f.Time:SetText("")
	f:SetScript("OnUpdate", OnUpdateFade)
end

function CB:Refresh(f)
	f.casting = false
	f:SetScript("OnUpdate", nil)
	f:SetAlpha(1)
	if Exists(UnitCastingInfo(f.unit)) then
		self:Start(f, false)
	elseif Exists(UnitChannelInfo(f.unit)) then
		self:Start(f, true)
	else
		f:Hide()
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Stop/fail events also fire for *other* attempts (pressing another ability
-- mid-cast fails that attempt). Only react if the event is about our cast:
-- compare cast GUIDs when readable, otherwise check the unit stopped casting.
local function IsOurCast(f, castGUID)
	if f.channel then
		return not Exists(UnitChannelInfo(f.unit))
	end
	if not IsSecret(castGUID) and not IsSecret(f.castID) and castGUID ~= nil and f.castID ~= nil then
		return castGUID == f.castID
	end
	return not Exists(UnitCastingInfo(f.unit))
end

local handlers = {
	UNIT_SPELLCAST_START = function(f) CB:Start(f, false) end,
	UNIT_SPELLCAST_CHANNEL_START = function(f) CB:Start(f, true) end,
	UNIT_SPELLCAST_DELAYED = function(f) CB:Update(f, false) end,
	UNIT_SPELLCAST_CHANNEL_UPDATE = function(f) CB:Update(f, true) end,
	UNIT_SPELLCAST_STOP = function(f, guid) if not f.channel and IsOurCast(f, guid) then CB:Finish(f, "success") end end,
	UNIT_SPELLCAST_CHANNEL_STOP = function(f) if f.channel then CB:Finish(f, "success") end end,
	UNIT_SPELLCAST_FAILED = function(f, guid) if not f.channel and IsOurCast(f, guid) then CB:Finish(f, "failed") end end,
	UNIT_SPELLCAST_INTERRUPTED = function(f, guid) if IsOurCast(f, guid) then CB:Finish(f, "interrupted") end end,
	UNIT_SPELLCAST_INTERRUPTIBLE = function(f) if f.casting then SetBarColor(f, false, f.channel) end end,
	UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(f) if f.casting then SetBarColor(f, true, f.channel) end end,
}

local function Watch(f, extraEvent)
	local ev = CreateFrame("Frame")
	for event in pairs(handlers) do
		pcall(ev.RegisterUnitEvent, ev, event, f.unit)
	end
	if extraEvent then ev:RegisterEvent(extraEvent) end
	ev:SetScript("OnEvent", function(_, event, _, castGUID)
		local h = handlers[event]
		if h then h(f, castGUID) else CB:Refresh(f) end
	end)
end

---------------------------------------------------------------------------
-- Preview while unlocked
---------------------------------------------------------------------------

local function ShowPreview(f, show)
	if f.casting then return end
	if show then
		f:SetScript("OnUpdate", nil)
		f:SetAlpha(1)
		f.Icon:SetTexture(136243) -- Interface\Icons\Spell_Holy_Heal
		f.Text:SetText(f.holder.label)
		f.Time:SetText("1.5")
		f.Bar:SetColor(unpack(ns.colors.cast))
		f.Bar:SetMinMaxValues(0, 1)
		f.Bar:SetValue(0.6)
		f.Spark:Show()
		f:Show()
	else
		f:Hide()
	end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

local function DisableBlizzardCastBar(frame)
	if not frame then return end
	if frame.SetUnit then
		pcall(frame.SetUnit, frame, nil)
	end
	ns.DisableBlizzard(frame)
end

function CB:Init()
	DisableBlizzardCastBar(PlayerCastingBarFrame)
	DisableBlizzardCastBar(PetCastingBarFrame)

	local db = ns.db.castbars
	local player = CreateCastBar("PlayerCast", "player", L.PLAYER_CAST, db.playerWidth, db.playerHeight)
	Watch(player, "PLAYER_ENTERING_WORLD")
	player.holder.OnUnlock = function(_, unlocked) ShowPreview(player, unlocked) end

	-- The target bar only makes sense alongside NovaUI's target frame.
	if ns.db.castbars.target and ns.db.unitframes.enabled then
		local target = CreateCastBar("TargetCast", "target", L.TARGET_CAST, db.targetWidth, db.targetHeight)
		Watch(target, "PLAYER_TARGET_CHANGED")
		target.holder.OnUnlock = function(_, unlocked) ShowPreview(target, unlocked) end
	end
end

function CB:SetScale(scale)
	for _, f in pairs(self.bars) do f.holder:SetScale(scale) end
end
