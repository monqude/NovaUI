local _, ns = ...
local L = ns.L

-- NovaUI's own WeakAuras-style alerts, built for Forever's restrictions:
--   * low health vignette   - driven by a curve, so it works with secret health
--   * missing-buff reminder - out of combat; click the icon to cast the buff
--   * key cooldowns          - class defensives/interrupts with live swipes
--   * proc alert             - Blizzard's spell activation events
--   * combat enter/leave     - short centre text
local A = ns.RegisterModule("Alerts", { dbKey = "alerts" })
ns.Alerts = A

local IsSecret = ns.IsSecret

---------------------------------------------------------------------------
-- Class data (rank-1 spell IDs; names are resolved in the client language)
---------------------------------------------------------------------------

-- Each entry is a list of alternatives: having any one of them is enough.
local BUFFS = {
	MAGE    = { { 1459 }, { 168, 7302, 6117 } },               -- Arcane Intellect; Frost/Ice/Mage Armor
	PRIEST  = { { 1243 }, { 588 } },                            -- Fortitude; Inner Fire
	DRUID   = { { 1126 } },                                     -- Mark of the Wild
	PALADIN = { { 19740, 19742, 20217, 1038 } },                -- any Blessing
	WARLOCK = { { 706, 687 } },                                 -- Demon Armor / Skin
	SHAMAN  = { { 324 } },                                      -- Lightning Shield
	HUNTER  = { { 13165, 13163, 5118, 13159 } },                -- any Aspect
	WARRIOR = { { 6673 } },                                     -- Battle Shout
}

-- Click-to-summon when the pet is missing (first known wins).
local PET_SUMMONS = {
	HUNTER  = { 883 },                                          -- Call Pet
	WARLOCK = { 691, 712, 697, 688 },                           -- Felhunter, Succubus, Voidwalker, Imp
}

local COOLDOWNS = {
	WARRIOR = { 6552, 72, 100, 20252, 871, 1719, 2687 },        -- Pummel, Shield Bash, Charge, Intercept, Shield Wall, Recklessness, Bloodrage
	ROGUE   = { 1766, 1776, 2094, 5277, 2983, 1856 },           -- Kick, Gouge, Blind, Evasion, Sprint, Vanish
	MAGE    = { 2139, 1953, 122, 11958, 12051 },                -- Counterspell, Blink, Frost Nova, Ice Block, Evocation
	PRIEST  = { 8122, 586, 14751, 10060 },                      -- Psychic Scream, Fade, Inner Focus, Power Infusion
	WARLOCK = { 6789, 5484, 18288 },                            -- Death Coil, Howl of Terror, Amplify Curse
	HUNTER  = { 5384, 781, 1499, 3045, 19263 },                 -- Feign Death, Disengage, Freezing Trap, Rapid Fire, Deterrence
	DRUID   = { 5211, 22812, 1850, 29166, 20484 },              -- Bash, Barkskin, Dash, Innervate, Rebirth
	PALADIN = { 853, 498, 642, 1022, 633 },                     -- HoJ, Divine Protection, Divine Shield, BoP, Lay on Hands
	SHAMAN  = { 8042, 8177, 16188, 2825 },                      -- Earth Shock, Grounding Totem, Nature's Swiftness, Bloodlust
}

local function SpellName(id)
	local info = C_Spell.GetSpellInfo(id)
	return info and info.name
end

local function Known(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
		if ok and not IsSecret(known) then return known end
	end
	return false
end

local function Icon(id)
	return C_Spell.GetSpellTexture(id)
end

local function PlayerClass()
	local _, class = UnitClass("player")
	return class
end

---------------------------------------------------------------------------
-- Shared icon widget
---------------------------------------------------------------------------

local function CreateIcon(parent, size, secureSpell)
	local b
	if secureSpell then
		b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
		b:SetAttribute("type", "spell")
		b:SetAttribute("unit", "player")
		b:SetAttribute("useOnKeyDown", false)
		b:RegisterForClicks("AnyUp")
	else
		b = CreateFrame("Frame", nil, parent)
	end
	b:SetSize(size, size)
	ns.CreatePanel(b, { 0.04, 0.04, 0.05, 0.9 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.label = ns.CreateText(b, 10, "OVERLAY", "OUTLINE")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
	return b
end

local function Pulse(region, from, to, dur)
	local ag = region:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(dur)
	a:SetSmoothing("IN_OUT")
	return ag
end

---------------------------------------------------------------------------
-- 1) Low health vignette
---------------------------------------------------------------------------

function A:BuildVignette()
	local db = ns.db.alerts
	local v = CreateFrame("Frame", "NovaUI_LowHealth", UIParent)
	v:SetAllPoints(UIParent)
	v:SetFrameStrata("BACKGROUND")
	v:EnableMouse(false)
	v:SetAlpha(0)

	-- Four red edges fading inwards.
	local inner = CreateFrame("Frame", nil, v)
	inner:SetAllPoints()
	local function edge(p1, p2, horizontal, size, gradDir, flip)
		local t = inner:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(ns.TEXTURE)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if horizontal then t:SetHeight(size) else t:SetWidth(size) end
		local solid, clear = CreateColor(0.85, 0.05, 0.05, 0.85), CreateColor(0.85, 0.05, 0.05, 0)
		if flip then t:SetGradient(gradDir, clear, solid) else t:SetGradient(gradDir, solid, clear) end
	end
	edge("TOPLEFT", "BOTTOMLEFT", false, 140, "HORIZONTAL", false)
	edge("TOPRIGHT", "BOTTOMRIGHT", false, 140, "HORIZONTAL", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true, 110, "VERTICAL", false)
	edge("TOPLEFT", "TOPRIGHT", true, 110, "VERTICAL", true)
	Pulse(inner, 1, 0.55, 0.7):Play()

	-- Health percent -> vignette alpha. Evaluated by the engine, so it also
	-- works while health is secret.
	local threshold = db.lowHealth / 100
	local curve = C_CurveUtil.CreateCurve()
	curve:AddPoint(0, 1)
	curve:AddPoint(threshold * 0.5, 0.9)
	curve:AddPoint(threshold, 0.35)
	curve:AddPoint(math.min(1, threshold + 0.05), 0)
	curve:AddPoint(1, 0)
	self.vignette, self.healthCurve = v, curve

	local ev = CreateFrame("Frame")
	ev:RegisterUnitEvent("UNIT_HEALTH", "player")
	ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function() A:UpdateVignette() end)
	self:UpdateVignette()
end

function A:UpdateVignette()
	local v = self.vignette
	if not v then return end
	if UnitIsDeadOrGhost("player") then v:SetAlpha(0) return end
	local ok = pcall(function()
		v:SetAlpha(UnitHealthPercent("player", true, self.healthCurve))
	end)
	if not ok then v:SetAlpha(0) end
end

---------------------------------------------------------------------------
-- 2) Missing buff reminder (click to cast)
---------------------------------------------------------------------------

local function HasAnyBuff(ids)
	for _, id in ipairs(ids) do
		local name = SpellName(id)
		if name then
			local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
			if not ok or IsSecret(aura) then return true end -- can't tell: stay quiet
			if aura then
				local exp = aura.expirationTime
				-- Treat "expires within 5 minutes" as missing.
				if not IsSecret(exp) and exp and exp > 0 and exp - GetTime() < 300 then return false, true end
				return true
			end
		end
	end
	return false
end

function A:BuildReminders()
	local class = PlayerClass()
	local list = BUFFS[class]
	local holder = ns.CreateHolder("Reminders", 120, 40, L.ALERT_BUFFS)
	-- Secure parent: hidden automatically in combat (buttons can't toggle then).
	local frame = CreateFrame("Frame", "NovaUI_Reminders", holder, "SecureHandlerStateTemplate")
	frame:SetAllPoints(holder)
	RegisterStateDriver(frame, "visibility", "[combat][dead] hide; show")
	self.reminders = { holder = holder, frame = frame, buttons = {} }

	list = list and { unpack(list) } or {}
	if ns.db.alerts.wPet and PET_SUMMONS[class] then list[#list + 1] = { pet = true, unpack(PET_SUMMONS[class]) } end
	for i, group in ipairs(list) do
		local b = CreateIcon(frame, 36, true)
		b.group = group
		local glow = b:CreateTexture(nil, "OVERLAY")
		glow:SetTexture(ns.TEXTURE)
		glow:SetAllPoints()
		glow:SetBlendMode("ADD")
		glow:SetVertexColor(1, 0.8, 0.3, 0.25)
		Pulse(glow, 0.1, 1, 0.6):Play()
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
			if self.spellID then GameTooltip:SetSpellByID(self.spellID) end
			GameTooltip:AddLine(L.ALERT_CLICK_CAST, 0.5, 0.8, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		b:Hide()
		self.reminders.buttons[i] = b
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "UNIT_AURA", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
		"UNIT_PET", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
		if e == "UNIT_AURA" or e == "UNIT_PET" then ev:RegisterUnitEvent(e, "player") else pcall(ev.RegisterEvent, ev, e) end
	end
	ev:SetScript("OnEvent", function() A:UpdateReminders() end)
	-- Expiry is time based: re-check periodically while out of combat.
	C_Timer.NewTicker(15, function() A:UpdateReminders() end)
	self:UpdateReminders()
end

function A:UpdateReminders()
	local r = self.reminders
	if not r or InCombatLockdown() then return end
	local shown = 0
	for _, b in ipairs(r.buttons) do
		-- Use the first alternative the player actually knows.
		local spell
		for _, id in ipairs(b.group) do
			if Known(id) then spell = id break end
		end
		local has, expiring
		if b.group.pet then
			has = UnitExists("pet") or IsMounted() or UnitOnTaxi("player")
		else
			has, expiring = HasAnyBuff(b.group)
		end
		if spell and not has then
			b.spellID = spell
			b:SetAttribute("spell", SpellName(spell))
			b.icon:SetTexture(Icon(spell))
			b.label:SetText(b.group.pet and L.W_PET or (expiring and L.ALERT_EXPIRING or L.ALERT_MISSING))
			b.label:SetTextColor(expiring and 1 or 1, expiring and 0.8 or 0.35, expiring and 0.3 or 0.35)
			b:ClearAllPoints()
			b:SetPoint("LEFT", r.frame, "LEFT", shown * 44, 0)
			b:Show()
			shown = shown + 1
		else
			b:Hide()
		end
	end
	r.holder:SetSize(math.max(36, shown * 44 - 8), 40)
end

---------------------------------------------------------------------------
-- 3) Key cooldowns
---------------------------------------------------------------------------

function A:BuildCooldowns()
	local db = ns.db.alerts
	local holder = ns.CreateHolder("Cooldowns", 200, db.cdSize, L.ALERT_COOLDOWNS)
	local frame = CreateFrame("Frame", "NovaUI_Cooldowns", holder)
	frame:SetAllPoints(holder)
	self.cds = { holder = holder, frame = frame, icons = {} }
	holder.OnUnlock = function() A:UpdateCooldowns() end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	ev:RegisterEvent("SPELLS_CHANGED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then A:LayoutCooldowns() end
		A:UpdateCooldowns()
	end)
	self:LayoutCooldowns()
end

function A:LayoutCooldowns()
	local c = self.cds
	if not c then return end
	local size = ns.db.alerts.cdSize
	local list = COOLDOWNS[PlayerClass()] or {}
	local n = 0
	for _, id in ipairs(list) do
		if Known(id) then
			n = n + 1
			local ic = c.icons[n]
			if not ic then
				ic = CreateIcon(c.frame, size)
				ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
				ic.cd:SetPoint("TOPLEFT", 1, -1)
				ic.cd:SetPoint("BOTTOMRIGHT", -1, 1)
				ic.cd:SetDrawEdge(false)
				c.icons[n] = ic
			end
			ic.spellID = id
			ic.spellName = SpellName(id)
			ic.icon:SetTexture(Icon(id))
			ic:SetSize(size, size)
			ic:ClearAllPoints()
			ic:SetPoint("LEFT", c.frame, "LEFT", (n - 1) * (size + 4), 0)
			ic:Show()
		end
	end
	for i = n + 1, #c.icons do c.icons[i]:Hide() end
	c.count = n
	c.holder:SetSize(math.max(size, n * (size + 4) - 4), size)
	self:UpdateCooldowns()
end

function A:UpdateCooldowns()
	local c = self.cds
	if not c then return end
	local inCombat = UnitAffectingCombat("player")
	c.frame:SetAlpha((inCombat or not ns.locked) and 1 or ns.db.alerts.cdIdleAlpha)
	for i = 1, c.count or 0 do
		local ic = c.icons[i]
		local name = ic.spellName or ic.spellID
		local info = C_Spell.GetSpellCooldown(name)
		local start, dur = info and info.startTime, info and info.duration
		if start ~= nil and dur ~= nil and not IsSecret(start) and not IsSecret(dur) then
			-- Readable: skip the global cooldown so only real cooldowns show.
			if dur > 1.6 then
				ic.cd:SetCooldown(start, dur)
				ic.icon:SetDesaturated(true)
			else
				ic.cd:Clear()
				ic.icon:SetDesaturated(false)
			end
		else
			-- Restricted: let the engine animate from a duration object.
			local okDur, duration = pcall(C_Spell.GetSpellCooldownDuration, name, true)
			if okDur and duration then pcall(ic.cd.SetCooldownFromDurationObject, ic.cd, duration) end
			ic.icon:SetDesaturated(false)
		end
	end
end

---------------------------------------------------------------------------
-- 4) Proc alert
---------------------------------------------------------------------------

function A:BuildProcs()
	local holder = ns.CreateHolder("Procs", 200, 56, L.ALERT_PROCS)
	local frame = CreateFrame("Frame", "NovaUI_Procs", holder)
	frame:SetAllPoints(holder)
	self.procs = { holder = holder, frame = frame, icons = {}, active = {} }

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
		"SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event, spellID)
		if spellID == nil and event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
			wipe(A.procs.active)
			A:UpdateProcs()
			return
		end
		if IsSecret(spellID) or type(spellID) ~= "number" then return end
		local active = A.procs.active
		if event:find("_SHOW$") then active[spellID] = true else active[spellID] = nil end
		A:UpdateProcs()
	end)
end

function A:UpdateProcs()
	local p = self.procs
	local n = 0
	for spellID in pairs(p.active) do
		n = n + 1
		local ic = p.icons[n]
		if not ic then
			ic = CreateIcon(p.frame, 52)
			local glow = ic:CreateTexture(nil, "OVERLAY")
			glow:SetTexture(ns.TEXTURE)
			glow:SetAllPoints()
			glow:SetBlendMode("ADD")
			glow:SetVertexColor(1, 0.85, 0.35, 0.35)
			Pulse(glow, 0.15, 1, 0.35):Play()
			p.icons[n] = ic
		end
		ic.icon:SetTexture(Icon(spellID))
		ic.label:SetText(SpellName(spellID) or "")
		ic:ClearAllPoints()
		ic:SetPoint("LEFT", p.frame, "LEFT", (n - 1) * 60, 0)
		ic:Show()
		if n >= 3 then break end
	end
	for i = n + 1, #p.icons do p.icons[i]:Hide() end
	p.holder:SetSize(math.max(52, n * 60 - 8), 56)
end

---------------------------------------------------------------------------
-- 5) Combat enter / leave text
---------------------------------------------------------------------------

function A:BuildCombatText()
	local t = UIParent:CreateFontString(nil, "OVERLAY")
	ns.SetFont(t, 22, "OUTLINE")
	t:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	t:SetAlpha(0)
	local ag = t:CreateAnimationGroup()
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.15)
	local a2 = ag:CreateAnimation("Alpha")
	a2:SetFromAlpha(1) a2:SetToAlpha(0) a2:SetStartDelay(0.9) a2:SetDuration(0.5)
	ag:SetScript("OnFinished", function() t:SetAlpha(0) end)

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			t:SetText("+ " .. L.ALERT_COMBAT)
			t:SetTextColor(1, 0.35, 0.35)
		else
			t:SetText("− " .. L.ALERT_COMBAT)
			t:SetTextColor(0.45, 0.95, 0.6)
		end
		ag:Stop()
		ag:Play()
	end)
end


---------------------------------------------------------------------------
-- 6) Classic reminders (inspired by the most-installed Classic WeakAuras):
--    repair, wrong gear, food buff, weapon poison/imbue, ammo, soul shards,
--    auto-attack. Plain warnings (no clicks), so they may also show in combat.
---------------------------------------------------------------------------

local CARROT = 11122                     -- Carrot on a Stick
local WELL_FED = 19705                   -- "Well Fed"
local SOUL_SHARD = 6265
local AUTO_ATTACK = 6603
local IMBUES = { 8017, 8024, 8033, 8232 } -- Rockbiter, Flametongue, Frostbrand, Windfury
local POISONS = 2842                     -- Poisons (rogue skill)
local MELEE = { WARRIOR = true, ROGUE = true, PALADIN = true }

local ICON_REPAIR = "Interface\\Minimap\\Tracking\\Repair"
local ICON_FOOD = 133971
local ICON_SHARD = 134075
local ICON_ATTACK = 135641

local function Lowest()
	local low
	for slot = 1, 18 do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 and (not low or cur / max < low) then low = cur / max end
	end
	return low
end

local function HasBuff(id)
	local name = SpellName(id)
	if not name then return true end
	local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
	if not ok or IsSecret(aura) then return true end -- unknown: stay quiet
	return aura ~= nil
end

local function IsFishingPole(itemID)
	if not itemID then return false end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
	return classID == 2 and subclassID == 20
end

local function AnyKnown(ids)
	for _, id in ipairs(ids) do if Known(id) then return id end end
end

-- Returns a list of { icon, text, r, g, b } warnings for the current state.
function A:CollectWarnings()
	local db = ns.db.alerts
	local out = {}
	local class = PlayerClass()
	local inCombat = UnitAffectingCombat("player")
	local inInstance, kind = IsInInstance()
	local grouped = inInstance and (kind == "party" or kind == "raid")
	local tr = ns.db.language == "tr"
	local function add(icon, text, r, g, b) out[#out + 1] = { icon, text, r or 1, g or 0.82, b or 0.3 } end

	if UnitIsDeadOrGhost("player") then return out end

	-- Repair
	if db.wRepair then
		local low = Lowest()
		if low and low * 100 < db.repairPct then
			add(ICON_REPAIR, ("%s %s"):format(L.W_REPAIR, tr and ("%" .. math.floor(low * 100)) or (math.floor(low * 100) .. "%")), 1, 0.35, 0.35)
		end
	end

	-- Wrong gear: carrot when it can't help, fishing pole where you fight
	if db.wGear then
		local t1, t2 = GetInventoryItemID("player", 13), GetInventoryItemID("player", 14)
		if (t1 == CARROT or t2 == CARROT) and not IsMounted() and (grouped or inCombat) then
			add(C_Item.GetItemIconByID(CARROT), L.W_CARROT, 1, 0.6, 0.2)
		end
		if IsFishingPole(GetInventoryItemID("player", 16)) and (grouped or inCombat) then
			add(GetInventoryItemTexture("player", 16), L.W_FISHING, 1, 0.6, 0.2)
		end
	end

	-- Food buff before pulling in dungeons/raids
	if db.wFood and grouped and not inCombat and not HasBuff(WELL_FED) then
		add(ICON_FOOD, L.W_FOOD)
	end

	-- Weapon poison (rogue) / weapon imbue (shaman)
	if db.wWeapon and not inCombat then
		local hasMH
		if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
			hasMH = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND or 16) ~= nil
		elseif GetWeaponEnchantInfo then
			hasMH = GetWeaponEnchantInfo()
		else
			hasMH = true -- can't tell; don't nag
		end
		if not IsSecret(hasMH) and not hasMH and GetInventoryItemID("player", 16) then
			if class == "ROGUE" and Known(POISONS) then
				add(GetInventoryItemTexture("player", 16), L.W_POISON)
			elseif class == "SHAMAN" and AnyKnown(IMBUES) then
				add(GetInventoryItemTexture("player", 16), L.W_IMBUE)
			end
		end
	end

	-- Ammo (hunter) / soul shards (warlock)
	if db.wAmmo then
		if class == "HUNTER" and GetInventoryItemID("player", 18) then
			local ammo = GetInventoryItemID("player", 0) and GetInventoryItemCount("player", 0) or 0
			if ammo < db.ammoLow then
				add(GetInventoryItemTexture("player", 0) or GetInventoryItemTexture("player", 18),
					ammo == 0 and L.W_AMMO_NONE or ("%s %d"):format(L.W_AMMO, ammo), 1, 0.35, 0.35)
			end
		elseif class == "WARLOCK" and Known(697) then
			local shards = C_Item.GetItemCount(SOUL_SHARD) or 0
			if shards < 3 then add(ICON_SHARD, ("%s %d"):format(L.W_SHARDS, shards), 0.75, 0.45, 1) end
		end
	end

	-- Forgot to auto-attack in melee
	if db.wAttack and inCombat then
		local melee = MELEE[class]
		if class == "DRUID" then
			local form = GetShapeshiftFormID and GetShapeshiftFormID()
			melee = form == 1 or form == 5 or form == 8 -- cat / bear / dire bear
		end
		if melee and UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
			local okRange, near = pcall(CheckInteractDistance, "target", 3)
			local attacking = C_Spell.IsCurrentSpell(AUTO_ATTACK)
			if okRange and near == true and not IsSecret(attacking) and not attacking then
				add(ICON_ATTACK, L.W_ATTACK, 1, 0.25, 0.25)
			end
		end
	end
	return out
end

function A:BuildWarnings()
	local holder = ns.CreateHolder("Warnings", 160, 40, L.ALERT_WARNINGS)
	local frame = CreateFrame("Frame", "NovaUI_Warnings", holder)
	frame:SetAllPoints(holder)
	self.warn = { holder = holder, frame = frame, icons = {} }

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED",
		"UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
		"PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_MOUNT_DISPLAY_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
	ev:SetScript("OnEvent", function() A:UpdateWarnings() end)

	-- Auto-attack and ammo change fast in combat: poll lightly.
	local elapsed = 0
	frame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.3 then return end
		elapsed = 0
		A:UpdateWarnings()
	end)
	self:UpdateWarnings()
end

function A:UpdateWarnings()
	local w = self.warn
	if not w then return end
	local ok, list = pcall(self.CollectWarnings, self)
	if not ok then list = {} end
	for i, item in ipairs(list) do
		local ic = w.icons[i]
		if not ic then
			ic = CreateIcon(w.frame, 34)
			ic.pulse = Pulse(ic, 1, 0.55, 0.6)
			w.icons[i] = ic
		end
		ic.icon:SetTexture(item[1])
		ic.label:SetText(item[2])
		ic.label:SetTextColor(item[3], item[4], item[5])
		ic:ClearAllPoints()
		ic:SetPoint("LEFT", w.frame, "LEFT", (i - 1) * 84, 0)
		if not ic:IsShown() then ic:Show() ic.pulse:Play() end
	end
	for i = #list + 1, #w.icons do
		w.icons[i]:Hide()
		w.icons[i].pulse:Stop()
	end
	w.holder:SetSize(math.max(34, #list * 84 - 50), 40)
end

---------------------------------------------------------------------------

function A:Init()
	local db = ns.db.alerts
	if InCombatLockdown() then
		ns.RunOOC("alertsinit", function() A:Init() end)
		return
	end
	if db.lowHealthOn then pcall(self.BuildVignette, self) end
	if db.buffs then self:BuildReminders() end
	if db.cooldowns then self:BuildCooldowns() end
	if db.procs then self:BuildProcs() end
	if db.combatText then self:BuildCombatText() end
	if db.warnings then self:BuildWarnings() end
end
