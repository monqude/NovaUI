local _, ns = ...
local L = ns.L

-- Full-width bottom bar, like a taskbar:
--   left   : the game menu (secure clicks on Blizzard's own micro buttons)
--   centre : zone + coordinates
--   right  : data panels - gold, bags, durability, social, performance, clock
local MM = ns.RegisterModule("MicroMenu", { dbKey = "micromenu" })
ns.MicroMenu = MM

local MUTED = { 0.56, 0.6, 0.66 }

local ENTRIES = {
	{ button = "CharacterMicroButton", label = "MM_CHARACTER", portrait = true },
	{ button = "SpellbookMicroButton", label = "MM_SPELLBOOK", atlas = "SpellbookAbilities" },
	{ button = "TalentMicroButton", label = "MM_TALENTS", atlas = "SpecTalents" },
	{ button = "ProfessionMicroButton", label = "MM_PROFESSIONS", atlas = "Professions" },
	{ button = "LegacyMicroButton", label = "MM_LEGACY", atlas = "Achievements" },
	{ button = "QuestLogMicroButton", label = "MM_QUESTS", atlas = "Questlog" },
	{ button = "GuildMicroButton", label = "MM_GUILD", atlas = "GuildCommunities" },
	{ button = "LFDMicroButton", label = "MM_GROUP", atlas = "Groupfinder" },
	{ button = "CollectionsMicroButton", label = "MM_COLLECTIONS", atlas = "Collections" },
	{ bags = true, label = "MM_BAGS" },
	{ button = "StoreMicroButton", label = "MM_SHOP", atlas = "Shop" },
	{ button = "MainMenuMicroButton", label = "MM_MENU", atlas = "GameMenu" },
}

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------

local function TR() return ns.db.language == "tr" end

local function Thousands(n)
	local sep = TR() and "." or ","
	local str = tostring(math.floor(math.abs(n) + 0.5))
	local out = str:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse():gsub("^%" .. sep, "")
	return (n < 0 and "-" or "") .. out
end

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

local function Money(copper, full)
	local neg = copper < 0
	copper = math.abs(copper)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local out
	if g > 0 then
		out = Thousands(g) .. GOLD
		if full or g < 100 then out = out .. " " .. s .. SILVER end
		if full then out = out .. " " .. c .. COPPER end
	elseif s > 0 then
		out = s .. SILVER .. " " .. c .. COPPER
	else
		out = c .. COPPER
	end
	return (neg and "-" or "") .. out
end

local function Hex(r, g, b) return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) end
local function Grade(v, good, okay) -- higher is better
	if v >= good then return 0.44, 0.86, 0.55 elseif v >= okay then return 0.95, 0.79, 0.3 end
	return 0.92, 0.34, 0.34
end

---------------------------------------------------------------------------
-- Menu entries (left)
---------------------------------------------------------------------------

local function SetIcon(icon, entry)
	if entry.portrait then
		local _, class = UnitClass("player")
		local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
		if coords then
			icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
			icon:SetTexCoord(unpack(coords))
			return
		end
		SetPortraitTexture(icon, "player")
		return
	end
	if entry.bags then
		if not pcall(icon.SetAtlas, icon, "bag-main") then
			icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
		end
		return
	end
	if not pcall(icon.SetAtlas, icon, "UI-HUD-MicroMenu-" .. entry.atlas .. "-Up") then
		icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	end
end

-- Shared hover look for every clickable cell on the bar.
local function Hoverable(b)
	b.hover = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.hover:SetTexture(ns.TEXTURE)
	b.hover:SetAllPoints()
	b.hover:SetVertexColor(1, 1, 1, 0.06)
	b.hover:Hide()
	b.underline = b:CreateTexture(nil, "ARTWORK")
	b.underline:SetTexture(ns.TEXTURE)
	b.underline:SetPoint("TOPLEFT", 6, -1)
	b.underline:SetPoint("TOPRIGHT", -6, -1)
	b.underline:SetHeight(2)
	b.underline:SetVertexColor(unpack(ns.db.accent))
	b.underline:Hide()
	b:HookScript("OnEnter", function(self) self.hover:Show() self.underline:Show() end)
	b:HookScript("OnLeave", function(self)
		self.hover:Hide() self.underline:Hide() GameTooltip:Hide()
		if MM.frame and not MM.frame:IsMouseOver() then MM:Sleep() end
	end)
end

local function CreateEntry(parent, entry)
	local blizz = entry.button and _G[entry.button]
	local b
	if blizz then
		b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
		b:SetAttribute("type", "click")
		b:SetAttribute("clickbutton", blizz)
		-- Secure buttons follow the "cast on key down" CVar unless told
		-- otherwise; a mouse menu must always fire on release.
		b:SetAttribute("useOnKeyDown", false)
		b:RegisterForClicks("AnyUp")
	else
		b = CreateFrame("Button", nil, parent)
		b:RegisterForClicks("AnyUp")
		b:SetScript("OnClick", function() if ToggleAllBags then ToggleAllBags() end end)
	end
	b.entry, b.blizz = entry, blizz
	Hoverable(b)

	b.icon = b:CreateTexture(nil, "ARTWORK")
	SetIcon(b.icon, entry)
	b.label = ns.CreateText(b, 11)
	b.label:SetText(L[entry.label])

	b:HookScript("OnEnter", function(self)
		self.label:SetTextColor(1, 1, 1)
		GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
		GameTooltip:AddLine(blizz and blizz.tooltipText or L[entry.label], 1, 1, 1)
		local reason = blizz and blizz.disabledTooltip
		if blizz and not blizz:IsEnabled() and type(reason) == "string" then
			GameTooltip:AddLine(reason, 1, 0.3, 0.3, true)
		end
		GameTooltip:Show()
	end)
	b:HookScript("OnLeave", function(self) self:UpdateState() end)

	function b:UpdateState()
		local enabled = not self.blizz or self.blizz:IsEnabled()
		self.icon:SetDesaturated(not enabled)
		self.icon:SetAlpha(enabled and 1 or 0.45)
		self.label:SetTextColor(enabled and 0.8 or 0.45, enabled and 0.82 or 0.46, enabled and 0.86 or 0.5)
	end
	return b
end

---------------------------------------------------------------------------
-- Data panels (right)
---------------------------------------------------------------------------

local function CreateData(parent, key, icon, onClick, tooltip)
	local b = CreateFrame("Button", nil, parent)
	b:RegisterForClicks("AnyUp")
	b.key = key
	Hoverable(b)
	if icon then
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(16, 16)
		b.icon:SetPoint("LEFT", 8, 0)
		if type(icon) == "table" then
			b.icon:SetTexture(icon[1])
			b.icon:SetTexCoord(icon[2], icon[3], icon[4], icon[5])
		elseif not pcall(b.icon.SetAtlas, b.icon, icon) then
			b.icon:SetTexture(icon)
		end
	end
	b.text = ns.CreateText(b, 12)
	b.text:SetPoint("LEFT", b.icon or b, b.icon and "RIGHT" or "LEFT", b.icon and 5 or 8, 0)
	if onClick then b:SetScript("OnClick", onClick) end
	b:HookScript("OnEnter", function(self)
		if not tooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
		tooltip(GameTooltip)
		GameTooltip:Show()
	end)
	function b:Set(text)
		self.text:SetText(text)
		local w = math.ceil(self.text:GetStringWidth()) + (self.icon and 37 or 16)
		if w ~= self.width then
			self.width = w
			MM:LayoutData()
		end
	end
	return b
end

local session = { money = nil }

local function Durability()
	local lowest, total, count = nil, 0, 0
	for slot = 1, 18 do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then
			local pct = cur / max
			total, count = total + pct, count + 1
			if not lowest or pct < lowest then lowest = pct end
		end
	end
	return lowest, count > 0 and total / count or nil
end

local function FreeSlots()
	local free, total = 0, 0
	local last = NUM_BAG_SLOTS or 4
	for bag = 0, last do
		local n = C_Container.GetContainerNumSlots(bag)
		total = total + n
		free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
	end
	return free, total
end

local function GuildOnline()
	if not IsInGuild() or not GetNumGuildMembers then return nil end
	local _, online = GetNumGuildMembers()
	return online or 0
end

function MM:BuildData(bar)
	local tr = TR()
	self.data = {}
	local add = function(b) self.data[#self.data + 1] = b return b end

	-- Gold, with this session's profit/loss in the tooltip.
	self.gold = add(CreateData(bar, "gold", nil, function() ToggleAllBags() end, function(tt)
		tt:AddLine(tr and "Para" or "Money", 1, 1, 1)
		tt:AddDoubleLine(tr and "Mevcut" or "Current", Money(GetMoney(), true), 0.8, 0.8, 0.8, 1, 1, 1)
		local diff = GetMoney() - (session.money or GetMoney())
		local r, g = diff >= 0 and 0.44 or 0.92, diff >= 0 and 0.86 or 0.34
		tt:AddDoubleLine(tr and "Bu oturum" or "This session", Money(diff, true), 0.8, 0.8, 0.8, r, g, 0.4)
	end))

	-- Free bag slots.
	self.bagsData = add(CreateData(bar, "bags", "bag-main", function() ToggleAllBags() end, function(tt)
		local free, total = FreeSlots()
		tt:AddLine(L.MM_BAGS, 1, 1, 1)
		tt:AddDoubleLine(tr and "Boş slot" or "Free slots", ("%d / %d"):format(free, total), 0.8, 0.8, 0.8, 1, 1, 1)
	end))

	-- Durability: lowest item, average in the tooltip.
	self.dura = add(CreateData(bar, "dura", { "Interface\\Minimap\\Tracking\\Repair", 0, 1, 0, 1 },
		function() ToggleCharacter("PaperDollFrame") end, function(tt)
			local low, avg = Durability()
			tt:AddLine(L.DURABILITY, 1, 1, 1)
			if low then
				tt:AddDoubleLine(tr and "En düşük" or "Lowest", ("%d%%"):format(math.floor(low * 100 + 0.5)), 0.8, 0.8, 0.8, Grade(low, 0.5, 0.2))
				tt:AddDoubleLine(tr and "Ortalama" or "Average", ("%d%%"):format(math.floor(avg * 100 + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
			end
		end))

	-- Friends & guild online.
	self.social = add(CreateData(bar, "social", { "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon", 0, 1, 0, 1 },
		function() if ToggleFriendsFrame then ToggleFriendsFrame() end end, function(tt)
			tt:AddLine(tr and "Sosyal" or "Social", 1, 1, 1)
			local friends = C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
			tt:AddDoubleLine(tr and "Çevrimiçi arkadaş" or "Friends online", friends, 0.8, 0.8, 0.8, 1, 1, 1)
			local shown = 0
			for i = 1, (C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0) do
				local info = C_FriendList.GetFriendInfoByIndex(i)
				if info and info.connected and shown < 12 then
					shown = shown + 1
					local cr, cg, cb = ns.ClassColor(info.className and info.className:upper():gsub(" ", ""))
					tt:AddDoubleLine("  " .. (info.name or "?"), info.area or "", cr, cg, cb, 0.6, 0.6, 0.6)
				end
			end
			local guild = GuildOnline()
			if guild then
				tt:AddDoubleLine(tr and "Çevrimiçi lonca" or "Guild online", guild, 0.8, 0.8, 0.8, 1, 1, 1)
			end
			tt:AddLine(" ")
			tt:AddLine(tr and "Tıkla: arkadaş listesi" or "Click: friends list", unpack(MUTED))
		end))

	-- Framerate & latency.
	self.perf = add(CreateData(bar, "perf", nil, nil, function(tt)
		local _, _, home, world = GetNetStats()
		tt:AddLine(tr and "Performans" or "Performance", 1, 1, 1)
		tt:AddDoubleLine(L.FRAMERATE, ("%.0f fps"):format(GetFramerate()), 0.8, 0.8, 0.8, 1, 1, 1)
		tt:AddDoubleLine(L.LATENCY_HOME, ("%d ms"):format(home or 0), 0.8, 0.8, 0.8, 1, 1, 1)
		tt:AddDoubleLine(L.LATENCY_WORLD, ("%d ms"):format(world or 0), 0.8, 0.8, 0.8, 1, 1, 1)
	end))

	-- Clock (local), realm time in the tooltip.
	self.clock = add(CreateData(bar, "clock", nil, function()
		if ToggleCalendar then ToggleCalendar() elseif ToggleTimeManager then ToggleTimeManager() end
	end, function(tt)
		local h, m = GetGameTime()
		tt:AddLine(tr and "Saat" or "Time", 1, 1, 1)
		tt:AddDoubleLine(tr and "Yerel" or "Local", date("%H:%M"), 0.8, 0.8, 0.8, 1, 1, 1)
		tt:AddDoubleLine(tr and "Sunucu" or "Realm", ("%02d:%02d"):format(h, m), 0.8, 0.8, 0.8, 1, 1, 1)
		if ns.Tracker and ns.db.tracker.enabled then ns.Tracker:AddTooltip(tt) end
		tt:AddLine(" ")
		tt:AddLine(tr and "Tıkla: takvim" or "Click: calendar", unpack(MUTED))
	end))

	-- Centre: zone and coordinates.
	local zone = CreateFrame("Button", nil, bar)
	zone:RegisterForClicks("AnyUp")
	zone:SetScript("OnClick", function() ToggleWorldMap() end)
	Hoverable(zone)
	zone.text = ns.CreateText(zone, 12)
	zone.text:SetPoint("LEFT", 12, 0)
	zone.text:SetPoint("RIGHT", -12, 0)
	zone.text:SetJustifyH("CENTER")
	self.zone = zone
end

-- Right-aligned row of data panels with dividers.
function MM:LayoutData()
	local bar = self.frame
	if not bar or not self.data then return end
	local x = -1
	for i = #self.data, 1, -1 do
		local b = self.data[i]
		b:ClearAllPoints()
		b:SetPoint("TOPRIGHT", bar, "TOPRIGHT", x, -1)
		b:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", x, 1)
		b:SetWidth(b.width or 40)
		x = x - (b.width or 40) - 1
		local d = self.dataDividers[i]
		d:ClearAllPoints()
		d:SetPoint("TOPRIGHT", bar, "TOPRIGHT", x + 1, -7)
		d:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", x + 1, 7)
	end
	self.dataWidth = -x
	self:LayoutCenter()

	-- Data grew into the menu (e.g. more gold digits): refit the menu.
	if self.menuRight and not self.refitting and self.menuRight + self.dataWidth + 8 > bar:GetWidth() then
		self.refitting = true
		self:Layout()
		self.refitting = false
	end
end

-- Zone text sits centred in the free gap between the menu and the data
-- panels; it truncates when tight and hides when there is no room at all.
function MM:LayoutCenter()
	local bar, zone = self.frame, self.zone
	if not bar or not zone then return end
	local left = (self.menuRight or 0) + 8
	local right = bar:GetWidth() - (self.dataWidth or 0) - 8
	local gap = right - left
	local want = math.ceil(zone.text:GetStringWidth()) + 24
	if gap < 80 then
		zone:Hide()
		return
	end
	local w = math.min(want, gap)
	zone:ClearAllPoints()
	zone:SetPoint("TOP", bar, "TOPLEFT", left + gap / 2, -1)
	zone:SetPoint("BOTTOM", bar, "BOTTOMLEFT", left + gap / 2, 1)
	zone:SetWidth(w)
	zone:Show()
end

function MM:UpdateData()
	if not self.data then return end
	local tr = TR()

	self.gold:Set(Money(GetMoney()))

	local free, total = FreeSlots()
	local fr, fg, fb = Grade(free, 10, 3)
	self.bagsData:Set(("%s%d|r |cff8f99a8/ %d|r"):format(Hex(fr, fg, fb), free, total))

	local low = Durability()
	if low then
		local pct = math.floor(low * 100 + 0.5)
		self.dura:Set(Hex(Grade(low, 0.5, 0.2)) .. (tr and ("%" .. pct) or (pct .. "%")) .. "|r")
	else
		self.dura:Set("—")
	end

	local friends = C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
	local guild = GuildOnline()
	self.social:Set(guild and ("%d |cff8f99a8·|r %d"):format(friends, guild) or tostring(friends))
end

function MM:UpdateFast()
	if not self.data then return end
	local fps = math.floor(GetFramerate() + 0.5)
	local _, _, home, world = GetNetStats()
	local ms = math.max(home or 0, world or 0)
	self.perf:Set(("%s%d|r |cff8f99a8fps|r  %s%d|r |cff8f99a8ms|r"):format(
		Hex(Grade(fps, 50, 25)), fps, Hex(Grade(-ms, -100, -250)), ms))
	if ns.db.micromenu.clock24 == false then
		self.clock:Set(date("%I:%M %p"))
	else
		self.clock:Set(date("%H:%M"))
	end

	-- Zone + coordinates (coordinates are unavailable inside instances).
	local text = GetMinimapZoneText() or ""
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if pos then
		local x, y = pos:GetXY()
		if x and y and (x > 0 or y > 0) then
			text = ("%s  |cff8f99a8%.1f, %.1f|r"):format(text, x * 100, y * 100)
		end
	end
	self.zone.text:SetText(text)
	self:LayoutCenter()
end

---------------------------------------------------------------------------
-- Bar
---------------------------------------------------------------------------

function MM:Layout()
	local db = ns.db.micromenu
	local f = self.frame
	if not f then return end
	ns.RunOOC("mmlayout", function()
		f:SetHeight(db.height)
		local size = db.size

		-- Progressive fit: roomy labels -> tight labels -> icons only.
		-- (The zone text in the middle gives way before the labels do.)
		local W = f:GetWidth()
		local dataW = self.dataWidth or 420
		local function menuWidth(pad, gap)
			local need = 4
			for _, b in ipairs(self.buttons) do
				need = need + pad + size + gap + math.ceil(b.label:GetStringWidth()) + pad + 2
			end
			return need
		end
		local mode
		if not db.labels then
			mode = "icons"
		elseif menuWidth(8, 6) + dataW + 120 <= W then
			mode = "roomy"
		elseif menuWidth(5, 4) + dataW + 16 <= W then
			mode = "tight"
		else
			mode = "icons"
		end
		self.compact = mode == "icons"
		local pad, gap = (mode == "roomy" and 8 or 5), (mode == "roomy" and 6 or 4)

		local x = 4
		for _, b in ipairs(self.buttons) do
			b.icon:ClearAllPoints()
			b.icon:SetSize(size, size)
			b.label:ClearAllPoints()
			local w
			if mode ~= "icons" then
				b.icon:SetPoint("LEFT", pad, 0)
				b.label:SetPoint("LEFT", b.icon, "RIGHT", gap, 0)
				b.label:Show()
				w = pad + size + gap + math.ceil(b.label:GetStringWidth()) + pad + 2
			else
				b.icon:SetPoint("CENTER")
				b.label:Hide()
				w = size + 16
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -1)
			b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 1)
			b:SetWidth(w)
			x = x + w
		end
		self.menuRight = x
		self:LayoutData()
	end)
end

function MM:Refresh()
	for _, b in ipairs(self.buttons or {}) do b:UpdateState() end
	self:Layout()
	self:UpdateData()
end

-- Kept for the settings slider ("resting opacity").
function MM:Wake() if self.frame then self.frame:SetAlpha(1) end end
function MM:Sleep() if self.frame then self.frame:SetAlpha(ns.db.micromenu.alpha) end end

function MM:Init()
	if InCombatLockdown() then
		ns.RunOOC("mminit", function() MM:Init() end)
		return
	end
	local db = ns.db.micromenu
	session.money = GetMoney()

	local f = CreateFrame("Frame", "NovaUI_MicroMenu", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	f:SetHeight(db.height)
	f:EnableMouse(true)
	self.frame = f

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(ns.TEXTURE)
	bg:SetAllPoints()
	bg:SetVertexColor(0.035, 0.037, 0.045, 0.94)

	-- Accent hairline on top, with a soft shadow above it.
	local line = f:CreateTexture(nil, "BORDER")
	line:SetTexture(ns.TEXTURE)
	line:SetPoint("TOPLEFT")
	line:SetPoint("TOPRIGHT")
	line:SetHeight(1)
	local a = ns.db.accent
	line:SetVertexColor(a[1], a[2], a[3], 0.55)
	local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	shadow:SetTexture(ns.TEXTURE)
	shadow:SetPoint("BOTTOMLEFT", f, "TOPLEFT")
	shadow:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT")
	shadow:SetHeight(5)
	if shadow.SetGradient and CreateColor then
		shadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0))
	else
		shadow:SetVertexColor(0, 0, 0, 0.25)
	end

	self.buttons = {}
	for _, entry in ipairs(ENTRIES) do
		local blizz = entry.button and _G[entry.button]
		-- Skip entries this client hides (game rules, disabled features).
		if entry.bags or (blizz and blizz:IsShown()) then
			self.buttons[#self.buttons + 1] = CreateEntry(f, entry)
		end
	end

	self:BuildData(f)
	self.dataDividers = {}
	for i = 1, #self.data do
		local d = f:CreateTexture(nil, "ARTWORK")
		d:SetTexture(ns.TEXTURE)
		d:SetVertexColor(1, 1, 1, 0.08)
		d:SetWidth(1)
		self.dataDividers[i] = d
	end

	-- Hide Blizzard's micro menu and bag bar; their buttons stay alive for
	-- our secure clicks.
	if MicroMenuContainer then
		MicroMenuContainer:SetParent(ns.hider)
	elseif MicroMenu then
		MicroMenu:SetParent(ns.hider)
	end
	if BagsBar then BagsBar:SetParent(ns.hider) end

	self:Refresh()
	self:UpdateFast()
	self:Sleep()

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "PLAYER_MONEY",
		"BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE",
		"ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_BINDINGS" then
			for _, b in ipairs(MM.buttons) do b:UpdateState() end
		end
		MM:UpdateData()
		if event:find("^ZONE") then MM:UpdateFast() end
	end)

	local elapsed = 0
	f:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 1 then return end
		elapsed = 0
		MM:UpdateFast()
	end)
	f:SetScript("OnSizeChanged", function() MM:Layout() end)
	f:SetScript("OnEnter", function() MM:Wake() end)
	f:SetScript("OnLeave", function() if not f:IsMouseOver() then MM:Sleep() end end)
end
