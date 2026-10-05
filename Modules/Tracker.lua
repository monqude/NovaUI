local _, ns = ...
local L = ns.L

-- Account-wide tracker (inspired by "Raid Reset Timers" and "Profession
-- Cooldown Tracker" on Wago): every character's raid lockouts and profession
-- cooldowns, shown in the bottom bar clock tooltip. Each character records its
-- own data when you log in on it.
local T = ns.RegisterModule("Tracker", { dbKey = "tracker" })
ns.Tracker = T

local IsSecret = ns.IsSecret

-- Classic profession cooldowns. Transmutes share one cooldown.
local PROF_SPELLS = {
	{ key = "transmute", ids = { 17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 25146 } },
	{ key = "mooncloth", ids = { 18560 } },
}
local PROF_ITEMS = {
	{ key = "saltshaker", item = 15846 },
}

local function Store()
	NovaUIProfiles = NovaUIProfiles or {}
	NovaUIProfiles.chars = NovaUIProfiles.chars or {}
	return NovaUIProfiles.chars
end

-- This character's record, or nil if its name can't be read right now
-- (names can be secret; never concatenate one).
local function Me()
	local name = UnitName("player")
	local realm = GetRealmName and GetRealmName() or ""
	if IsSecret(name) or IsSecret(realm) or type(name) ~= "string" then return nil end
	local key = name .. " - " .. realm
	local chars = Store()
	chars[key] = chars[key] or {}
	local _, class = UnitClass("player")
	chars[key].name, chars[key].class = name, class
	return chars[key], key
end

local function Left(sec)
	local tr = ns.db.language == "tr"
	sec = math.max(0, math.floor(sec))
	local d, h, m = math.floor(sec / 86400), math.floor(sec / 3600) % 24, math.floor(sec / 60) % 60
	if d > 0 then return tr and ("%dg %dsa"):format(d, h) or ("%dd %dh"):format(d, h) end
	if h > 0 then return tr and ("%dsa %ddk"):format(h, m) or ("%dh %dm"):format(h, m) end
	return tr and ("%ddk"):format(math.max(1, m)) or ("%dm"):format(math.max(1, m))
end

---------------------------------------------------------------------------
-- Scanning (this character)
---------------------------------------------------------------------------

function T:ScanLockouts()
	if not GetNumSavedInstances then return end
	local me = Me()
	if not me then return end
	local list = {}
	for i = 1, GetNumSavedInstances() do
		local name, _, reset, _, locked, _, _, _, _, difficultyName = GetSavedInstanceInfo(i)
		if locked and name and reset and reset > 0 then
			list[#list + 1] = { name = name, diff = difficultyName, resetAt = time() + reset }
		end
	end
	me.lockouts = list
end

local function Known(id)
	if not (C_SpellBook and C_SpellBook.IsSpellKnown) then return false end
	local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
	return ok and not IsSecret(known) and known
end

function T:ScanProfessions()
	if InCombatLockdown() then return end
	local me = Me()
	if not me then return end
	me.prof = me.prof or {}
	for _, def in ipairs(PROF_SPELLS) do
		local spell
		for _, id in ipairs(def.ids) do
			if Known(id) then spell = id break end
		end
		if spell then
			local info = C_Spell.GetSpellCooldown(spell)
			local start, dur = info and info.startTime, info and info.duration
			if not IsSecret(start) and not IsSecret(dur) and start and dur then
				local remaining = (dur > 2) and (start + dur - GetTime()) or 0
				local name = C_Spell.GetSpellInfo(spell)
				me.prof[def.key] = { name = name and name.name or def.key, readyAt = time() + math.max(0, remaining) }
			end
		else
			me.prof[def.key] = nil
		end
	end
	for _, def in ipairs(PROF_ITEMS) do
		if (C_Item.GetItemCount(def.item) or 0) > 0 and C_Container and C_Container.GetItemCooldown then
			local start, dur = C_Container.GetItemCooldown(def.item)
			if not IsSecret(start) and not IsSecret(dur) and start and dur then
				local remaining = (dur > 2) and (start + dur - GetTime()) or 0
				me.prof[def.key] = { name = C_Item.GetItemNameByID(def.item) or def.key, readyAt = time() + math.max(0, remaining) }
			end
		end
	end
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

local function SortedChars()
	local list = {}
	for key, data in pairs(Store()) do list[#list + 1] = { key = key, data = data } end
	table.sort(list, function(a, b) return a.key < b.key end)
	return list
end

-- Adds the account-wide sections to a tooltip.
function T:AddTooltip(tt)
	local now = time()
	local lockLines, profLines = {}, {}
	for _, c in ipairs(SortedChars()) do
		local r, g, b = ns.ClassColor(c.data.class)
		for _, l in ipairs(c.data.lockouts or {}) do
			if l.resetAt > now then
				lockLines[#lockLines + 1] = { ("%s  |cff8f99a8%s|r"):format(l.name, c.data.name or "?"), Left(l.resetAt - now), r, g, b }
			end
		end
		for _, p in pairs(c.data.prof or {}) do
			local ready = p.readyAt <= now
			profLines[#profLines + 1] = { ("%s  |cff8f99a8%s|r"):format(p.name, c.data.name or "?"),
				ready and L.TRACK_READY or Left(p.readyAt - now), ready }
		end
	end
	if #lockLines > 0 then
		tt:AddLine(" ")
		tt:AddLine(L.TRACK_LOCKOUTS, 1, 1, 1)
		for _, line in ipairs(lockLines) do tt:AddDoubleLine(line[1], line[2], line[3], line[4], line[5], 0.8, 0.8, 0.8) end
	end
	if #profLines > 0 then
		tt:AddLine(" ")
		tt:AddLine(L.TRACK_PROF, 1, 1, 1)
		for _, line in ipairs(profLines) do
			if line[3] then
				tt:AddDoubleLine(line[1], line[2], 0.85, 0.85, 0.85, 0.44, 0.86, 0.55)
			else
				tt:AddDoubleLine(line[1], line[2], 0.85, 0.85, 0.85, 0.8, 0.8, 0.8)
			end
		end
	end
end

-- On login: tell me which profession cooldowns are ready on any character.
function T:AnnounceReady()
	local now, ready = time(), {}
	for _, c in ipairs(SortedChars()) do
		for _, p in pairs(c.data.prof or {}) do
			if p.readyAt <= now then ready[#ready + 1] = ("%s (%s)"):format(p.name, c.data.name or "?") end
		end
	end
	if #ready > 0 then ns.Print(L.TRACK_READY_MSG:format(table.concat(ready, ", "))) end
end

function T:Init()
	Me()
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("UPDATE_INSTANCE_INFO")
	ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	local announced, pending = false, false
	local function ScanSoon()
		if pending then return end
		pending = true
		C_Timer.After(2, function() pending = false T:ScanProfessions() end)
	end
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			if RequestRaidInfo then RequestRaidInfo() end
			C_Timer.After(5, function()
				T:ScanProfessions()
				if not announced then
					announced = true
					T:AnnounceReady()
				end
			end)
		elseif event == "UPDATE_INSTANCE_INFO" then
			T:ScanLockouts()
		else
			ScanSoon()
		end
	end)
end
