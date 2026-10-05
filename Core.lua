local ADDON, ns = ...

local Nova = CreateFrame("Frame", "NovaUI")
ns.Nova = Nova
Nova.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "1.0.0"

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

ns.defaults = {
	language = "tr",
	font = "Interface\\AddOns\\NovaUI\\Media\\Fonts\\Inter.ttf",
	globalFont = true,
	accent = { 0.31, 0.76, 0.97 },

	unitframes = {
		enabled = true,
		scale = 1,
		classColor = true,
		fadeOutOfCombat = true,
		fadeAlpha = 0.45,
		showPercent = true,
		style = "portrait",
		absorbs = true,
		personal = true,
	},
	castbars = {
		enabled = true,
		scale = 1,
		target = true,
		playerWidth = 260,
		playerHeight = 22,
		targetWidth = 232,
		targetHeight = 18,
		icon = true,
		latency = true,
	},
	swing = {
		enabled = true,
		width = 260,
		height = 7,
		offhand = true,
		ranged = true,
	},
	actionbars = {
		enabled = true,
		hotkeys = true,
		macroNames = false,
		emptySlots = true,
		bars = {
			bar1 = { enabled = true, buttons = 12, perRow = 12, size = 36, spacing = 4, alpha = 1, mouseover = false },
			bar2 = { enabled = true, buttons = 12, perRow = 12, size = 36, spacing = 4, alpha = 1, mouseover = false },
			bar3 = { enabled = true, buttons = 12, perRow = 12, size = 36, spacing = 4, alpha = 1, mouseover = false },
			bar4 = { enabled = true, buttons = 12, perRow = 1, size = 34, spacing = 4, alpha = 1, mouseover = false },
			bar5 = { enabled = true, buttons = 12, perRow = 1, size = 34, spacing = 4, alpha = 1, mouseover = false },
			bar6 = { enabled = false, buttons = 12, perRow = 1, size = 34, spacing = 4, alpha = 1, mouseover = false },
			bar7 = { enabled = false, buttons = 12, perRow = 1, size = 34, spacing = 4, alpha = 1, mouseover = false },
			bar8 = { enabled = false, buttons = 12, perRow = 12, size = 34, spacing = 4, alpha = 1, mouseover = false },
			pet = { enabled = true, buttons = 10, perRow = 10, size = 28, spacing = 3, alpha = 1, mouseover = false },
			stance = { enabled = true, buttons = 6, perRow = 6, size = 28, spacing = 3, alpha = 1, mouseover = false },
		},
	},
	xpbar = {
		enabled = true,
		height = 10,
		reputation = true,
		ticks = true,
		showText = true,
	},
	micromenu = {
		enabled = true,
		labels = true,
		clock24 = true,
		height = 30,
		size = 18,
		alpha = 0.75,
		hideBags = false,
	},
	nameplates = {
		enabled = true,
		percent = true,
		nameSize = 9,
		textSize = 8,
		castSize = 8,
		outline = true,
		arrows = true,
		quest = true,
		execute = true,
		executePct = 20,
	},
	tracker = {
		enabled = true,
	},
	edit = {
		grid = 32,
		snapGrid = true,
		snapFrames = true,
	},
	alerts = {
		enabled = true,
		lowHealthOn = true,
		lowHealth = 30,
		buffs = true,
		cooldowns = true,
		cdSize = 34,
		cdIdleAlpha = 0.5,
		procs = true,
		combatText = true,
		warnings = true,
		wRepair = true,
		repairPct = 20,
		wGear = true,
		wFood = true,
		wWeapon = true,
		wAmmo = true,
		ammoLow = 200,
		wAttack = true,
		wPet = true,
	},
	skins = {
		enabled = true,
	},
	chat = {
		enabled = true,
		alpha = 0.55,
	},
	auras = {
		enabled = true,
		skinPlayer = true,
		target = true,
		onlyMine = false,
		targetSize = 24,
		targetPerRow = 8,
		playerShort = true,
	},
	bags = {
		enabled = true,
		columns = 10,
		size = 36,
		spacing = 4,
	},
	party = {
		enabled = true,
		showPlayer = true,
		width = 180,
		height = 40,
		spacing = 6,
	},
	raid = {
		enabled = true,
		width = 84,
		height = 40,
		spacing = 4,
		rangeFade = true,
	},
	minimap = {
		enabled = true,
		size = 190,
		zoneText = true,
	},
	tooltip = {
		enabled = true,
		cursor = false,
		qualityBorder = true,
	},

	positions = {},
}

-- Default anchor of every movable element, relative to UIParent.
ns.defaultPositions = {
	Player       = { "BOTTOM", "UIParent", "BOTTOM", -270, 247 },
	Target       = { "BOTTOM", "UIParent", "BOTTOM",  270, 247 },
	TargetTarget = { "BOTTOM", "UIParent", "BOTTOM",  493, 281 },
	Pet          = { "BOTTOM", "UIParent", "BOTTOM", -493, 281 },
	PlayerCast   = { "BOTTOM", "UIParent", "BOTTOM",    0, 207 },
	TargetCast   = { "BOTTOM", "UIParent", "BOTTOM",  270, 223 },
	Swing        = { "BOTTOM", "UIParent", "BOTTOM",    0, 234 },
	Bar1         = { "BOTTOM", "UIParent", "BOTTOM",    0, 48 },
	Bar2         = { "BOTTOM", "UIParent", "BOTTOM",    0, 90 },
	Bar3         = { "BOTTOM", "UIParent", "BOTTOM",    0, 132 },
	Bar4         = { "RIGHT",  "UIParent", "RIGHT",    -6, 0 },
	Bar5         = { "RIGHT",  "UIParent", "RIGHT",   -46, 0 },
	Bar6         = { "LEFT",   "UIParent", "LEFT",      6, 0 },
	Bar7         = { "LEFT",   "UIParent", "LEFT",     46, 0 },
	Bar8         = { "BOTTOM", "UIParent", "BOTTOM",    0, 332 },
	PetBar       = { "BOTTOM", "UIParent", "BOTTOM",    0, 174 },
	StanceBar    = { "BOTTOM", "UIParent", "BOTTOM", -340, 174 },
	Focus        = { "BOTTOM", "UIParent", "BOTTOM", -270, 321 },
	Boss1        = { "CENTER", "UIParent", "CENTER",  520, 140 },
	Boss2        = { "CENTER", "UIParent", "CENTER",  520, 94 },
	Boss3        = { "CENTER", "UIParent", "CENTER",  520, 48 },
	Boss4        = { "CENTER", "UIParent", "CENTER",  520, 2 },
	Boss5        = { "CENTER", "UIParent", "CENTER",  520, -44 },
	Reminders    = { "TOP", "UIParent", "TOP",           0, -120 },
	Cooldowns    = { "BOTTOM", "UIParent", "BOTTOM",    0, 270 },
	Warnings     = { "TOP", "UIParent", "TOP",           0, -175 },
	Procs        = { "CENTER", "UIParent", "CENTER",    0, 110 },
	Personal     = { "CENTER", "UIParent", "CENTER",    0, -150 },
	PlayerBuffs  = { "BOTTOM", "UIParent", "BOTTOM",    0, 312 },
	TargetAuras  = { "BOTTOM", "UIParent", "BOTTOM",  262, 314 },
	Party        = { "TOPLEFT", "UIParent", "TOPLEFT", 24, -240 },
	Raid         = { "TOPLEFT", "UIParent", "TOPLEFT", 24, -240 },
}


---------------------------------------------------------------------------
-- Fonts. The English client's fonts have no Turkish letters (ş ğ ı İ), so
-- NovaUI ships open-licensed fonts that do.
---------------------------------------------------------------------------

local FONT_DIR = "Interface\\AddOns\\NovaUI\\Media\\Fonts\\"
ns.FONTS = {
	{ key = "inter", label = "Inter", path = FONT_DIR .. "Inter.ttf" },
	{ key = "roboto", label = "Roboto", path = FONT_DIR .. "Roboto.ttf" },
	{ key = "opensans", label = "Open Sans", path = FONT_DIR .. "OpenSans.ttf" },
}

-- Older NovaUI versions defaulted to game fonts without Turkish glyphs.
local OLD_FONTS = { ["Fonts\\ARIALN.TTF"] = true, ["Fonts\\FRIZQT__.TTF"] = true, ["Fonts\\ARIAL.TTF"] = true }

-- Replaces the face of every game font object, keeping size and outline.
function ns.ApplyGlobalFont()
	if not ns.db.globalFont then return end
	local locale = GetLocale()
	if locale == "koKR" or locale == "zhCN" or locale == "zhTW" then return end
	local path = ns.db.font
	local names = GetFonts and GetFonts() or {}
	for _, name in ipairs(names) do
		local obj = _G[name]
		if type(obj) == "table" and obj.GetFont and obj.SetFont then
			pcall(function()
				local _, size, flags = obj:GetFont()
				if size and size > 0 then obj:SetFont(path, size, flags or "") end
			end)
		end
	end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Forever runs on the modern engine: many unit values are "secret" for addons.
-- Secrets may be passed straight to widgets, but never compared or used in math.
local issecretvalue = issecretvalue
function ns.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- True when v holds something, without ever comparing a secret.
function ns.Exists(v)
	if ns.IsSecret(v) then return true end
	return v ~= nil
end

-- A usable plain number (not secret, not nil).
function ns.Plain(v)
	return v ~= nil and not ns.IsSecret(v) and type(v) == "number"
end

function ns.CopyDefaults(src, dst)
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = ns.CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function ns.Print(...)
	print("|cff4fc3f7Nova|rUI:", ...)
end

ns.TEXTURE = "Interface\\Buttons\\WHITE8X8"

ns.colors = {
	bg       = { 0.055, 0.058, 0.07, 0.88 },
	bgDark   = { 0.03, 0.03, 0.035, 0.95 },
	border   = { 0, 0, 0, 1 },
	shadow   = { 0, 0, 0, 0.45 },
	text     = { 0.92, 0.93, 0.95 },
	muted    = { 0.55, 0.58, 0.63 },
	tapped   = { 0.45, 0.45, 0.48 },
	offline  = { 0.38, 0.38, 0.4 },
	health   = { 0.30, 0.78, 0.42 },
	cast     = { 0.31, 0.76, 0.97 },
	channel  = { 0.55, 0.85, 0.45 },
	noInterrupt = { 0.62, 0.62, 0.66 },
	failed   = { 0.92, 0.28, 0.28 },
	success  = { 0.38, 0.86, 0.48 },
	reaction = {
		[1] = { 0.86, 0.26, 0.24 },
		[2] = { 0.86, 0.26, 0.24 },
		[3] = { 0.90, 0.45, 0.22 },
		[4] = { 0.95, 0.82, 0.30 },
		[5] = { 0.36, 0.80, 0.40 },
		[6] = { 0.36, 0.80, 0.40 },
		[7] = { 0.36, 0.80, 0.40 },
		[8] = { 0.36, 0.80, 0.40 },
	},
	power = {
		MANA        = { 0.0, 0.58, 1.0 },
		RAGE        = { 0.90, 0.24, 0.24 },
		FOCUS       = { 0.95, 0.60, 0.30 },
		ENERGY      = { 0.98, 0.86, 0.34 },
		RUNIC_POWER = { 0.20, 0.78, 0.95 },
	},
}

function ns.ClassColor(class)
	local c = class and (C_ClassColor and C_ClassColor.GetClassColor(class) or RAID_CLASS_COLORS[class])
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

function ns.SetFont(fs, size, flags)
	fs:SetFont(ns.db and ns.db.font or ns.defaults.font, size or 12, flags or "")
	if flags == nil or flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.9)
	else
		fs:SetShadowOffset(0, 0)
	end
end

function ns.CreateText(parent, size, layer, flags)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	ns.SetFont(fs, size, flags)
	fs:SetTextColor(unpack(ns.colors.text))
	fs:SetWordWrap(false)
	return fs
end

-- Flat panel: dark body, crisp 1px border, soft drop shadow.
-- Built from plain textures so it works on any frame type (incl. secure ones).
function ns.CreatePanel(frame, bg, noShadow)
	if frame.novaPanel then return frame.novaPanel end
	local p = {}

	p.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	p.bg:SetTexture(ns.TEXTURE)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(unpack(bg or ns.colors.bg))

	local function edge(point1, point2, horizontal)
		local t = frame:CreateTexture(nil, "BORDER", nil, 7)
		t:SetTexture(ns.TEXTURE)
		t:SetVertexColor(unpack(ns.colors.border))
		t:SetPoint(point1, frame, point1, horizontal and 0 or 0, 0)
		t:SetPoint(point2, frame, point2, 0, 0)
		if horizontal then t:SetHeight(1) else t:SetWidth(1) end
		if t.SetSnapToPixelGrid then
			t:SetSnapToPixelGrid(false)
			t:SetTexelSnappingBias(0)
		end
		return t
	end
	p.top    = edge("TOPLEFT", "TOPRIGHT", true)
	p.bottom = edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	p.left   = edge("TOPLEFT", "BOTTOMLEFT", false)
	p.right  = edge("TOPRIGHT", "BOTTOMRIGHT", false)

	if not noShadow then
		-- Soft shadow made of stacked translucent rings outside the frame.
		p.shadow = {}
		for i = 1, 3 do
			local s = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			s:SetTexture(ns.TEXTURE)
			s:SetVertexColor(0, 0, 0, 0.16 - i * 0.04)
			s:SetPoint("TOPLEFT", -i, i)
			s:SetPoint("BOTTOMRIGHT", i, -i)
			p.shadow[i] = s
		end
	end

	function p:SetBorderColor(r, g, b, a)
		for _, t in ipairs({ self.top, self.bottom, self.left, self.right }) do
			t:SetVertexColor(r, g, b, a or 1)
		end
	end

	frame.novaPanel = p
	return p
end

-- Status bar with flat texture, dark backdrop and a subtle top-light gradient.
function ns.CreateBar(parent, smooth)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(ns.TEXTURE)
	bar:GetStatusBarTexture():SetHorizTile(false)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetTexture(ns.TEXTURE)
	bar.bg:SetAllPoints()
	bar.bg:SetVertexColor(0.08, 0.08, 0.09, 1)

	local gloss = bar:CreateTexture(nil, "ARTWORK", nil, 7)
	gloss:SetTexture(ns.TEXTURE)
	gloss:SetAllPoints(bar:GetStatusBarTexture())
	if gloss.SetGradient and CreateColor then
		gloss:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.28), CreateColor(1, 1, 1, 0.07))
	else
		gloss:SetVertexColor(1, 1, 1, 0.05)
	end
	bar.gloss = gloss

	-- Smooth fill using the engine's native interpolation (secret-safe).
	if smooth and Enum.StatusBarInterpolation then
		bar.interp = Enum.StatusBarInterpolation.ExponentialEaseOut
	end

	function bar:SetColor(r, g, b)
		self:SetStatusBarColor(r, g, b)
		self.bg:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 0.95)
	end

	function bar:SetSmoothValue(v)
		if self.interp then
			self:SetValue(v, self.interp)
		else
			self:SetValue(v)
		end
	end

	return bar
end

---------------------------------------------------------------------------
-- Blizzard frame disabling (oUF-style, out of combat at load)
---------------------------------------------------------------------------

local hider = CreateFrame("Frame", "NovaUIHider", UIParent)
hider:Hide()
ns.hider = hider

function ns.DisableBlizzard(frame)
	if not frame then return end
	frame:UnregisterAllEvents()
	frame:Hide()
	frame:SetParent(hider)

	for _, key in ipairs({ "healthbar", "healthBar", "HealthBar", "manabar", "manaBar", "PowerBar", "spellbar", "SpellBar", "powerBarAlt" }) do
		local child = frame[key]
		if child and child.UnregisterAllEvents then
			child:UnregisterAllEvents()
		end
	end
end

---------------------------------------------------------------------------
-- Holders & movers
---------------------------------------------------------------------------

ns.holders = {}

-- Every movable element lives inside a plain holder so it can be scaled and
-- repositioned without touching protected frames directly.
function ns.CreateHolder(key, width, height, label)
	local holder = CreateFrame("Frame", "NovaUI_" .. key .. "Holder", UIParent)
	holder:SetSize(width, height)
	holder:SetClampedToScreen(true)
	holder:SetMovable(true)
	holder.key = key
	holder.label = label or key
	ns.holders[key] = holder
	ns.PlaceHolder(holder)
	return holder
end

function ns.PlaceHolder(holder)
	local pos = ns.db.positions[holder.key] or ns.defaultPositions[holder.key]
	if not pos then return end
	holder:ClearAllPoints()
	holder:SetPoint(pos[1], _G[pos[2]] or UIParent, pos[3], pos[4], pos[5])
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

ns.modules = {}

function ns.RegisterModule(name, mod)
	mod.name = name
	ns.modules[#ns.modules + 1] = mod
	return mod
end

local function SafeCall(mod, method, ...)
	if not mod[method] then return end
	local ok, err = pcall(mod[method], mod, ...)
	if not ok then
		geterrorhandler()(("NovaUI [%s:%s] %s"):format(mod.name, method, tostring(err)))
	end
end
ns.SafeCall = SafeCall

-- Runs fn now, or right after combat if protected frames are locked.
local oocQueue = {}
function ns.RunOOC(key, fn)
	if InCombatLockdown() then
		oocQueue[key] = fn
	else
		fn()
	end
end

---------------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------------

Nova:RegisterEvent("ADDON_LOADED")
Nova:RegisterEvent("PLAYER_LOGIN")
Nova:RegisterEvent("PLAYER_REGEN_DISABLED")
Nova:RegisterEvent("PLAYER_REGEN_ENABLED")
Nova:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		local fresh = NovaUIDB == nil
		NovaUIDB = ns.CopyDefaults(ns.defaults, NovaUIDB)
		ns.db = NovaUIDB
		ns.fresh = fresh
		if OLD_FONTS[ns.db.font] then ns.db.font = ns.defaults.font end
		-- v1.8.1: the minimap info bar is gone; keep its clock preference.
		if ns.db.infobar then
			if ns.db.infobar.clock24 == false then ns.db.micromenu.clock24 = false end
			ns.db.infobar = nil
		end
		-- v1.6: one-time switch to the portrait layout (class-colored bars).
		if not ns.db.unitframes.portraitIntro then
			ns.db.unitframes.portraitIntro = true
			ns.db.unitframes.style = "portrait"
			ns.db.unitframes.classColor = true
		end
		ns.ApplyGlobalFont()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		for _, mod in ipairs(ns.modules) do
			local cfg = ns.db[mod.dbKey or ""]
			if not cfg or cfg.enabled then
				SafeCall(mod, "Init")
			end
		end
		-- Greet only on first install or after an update.
		if ns.db.lastVersion ~= Nova.version then
			ns.db.lastVersion = Nova.version
			ns.Print(ns.L.LOADED:format(Nova.version))
			if ns.fresh then ns.Print(ns.db.language == "tr" and "For English: |cff4fc3f7/nova en|r" or "Türkçe için: |cff4fc3f7/nova tr|r") end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		for key, fn in pairs(oocQueue) do
			oocQueue[key] = nil
			local ok, err = pcall(fn)
			if not ok then geterrorhandler()(err) end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if not ns.locked then
			ns.SetLocked(true)
			ns.Print(ns.L.LOCKED_COMBAT)
		end
	end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_NOVAUI1 = "/nova"
SLASH_NOVAUI2 = "/novaui"
SlashCmdList.NOVAUI = function(msg)
	msg = (msg or ""):lower():trim()
	if msg == "unlock" or msg == "move" then
		ns.SetLocked(false)
	elseif msg == "lock" then
		ns.SetLocked(true)
	elseif msg == "tr" or msg == "en" then
		if ns.db.language ~= msg then
			ns.db.language = msg
			ReloadUI()
		end
	elseif msg == "export" then
		ns.Profiles.ShowExport()
	elseif msg == "import" then
		ns.Profiles.ShowImport()
	elseif msg == "reset" then
		ns.ResetPositions()
		ns.Print(ns.L.POSITIONS_RESET)
	else
		if ns.Config then ns.Config:Toggle() end
	end
end
