local _, ns = ...
local L = ns.L

-- NovaUI moves Blizzard's own action buttons into its own bars. Each button
-- keeps its `.bar` reference, which is where the secure code reads the action
-- page from, so paging, stances, keybinds and macros keep working untouched.
local AB = ns.RegisterModule("ActionBars", { dbKey = "actionbars" })
ns.ActionBars = AB

AB.BARS = {
	{ key = "bar1", holder = "Bar1", prefix = "ActionButton", count = 12, blizz = { "MainActionBar", "MainMenuBar" } },
	{ key = "bar2", holder = "Bar2", prefix = "MultiBarBottomLeftButton", count = 12, blizz = { "MultiBarBottomLeft" } },
	{ key = "bar3", holder = "Bar3", prefix = "MultiBarBottomRightButton", count = 12, blizz = { "MultiBarBottomRight" } },
	{ key = "bar4", holder = "Bar4", prefix = "MultiBarRightButton", count = 12, blizz = { "MultiBarRight" } },
	{ key = "bar5", holder = "Bar5", prefix = "MultiBarLeftButton", count = 12, blizz = { "MultiBarLeft" } },
	{ key = "bar6", holder = "Bar6", prefix = "MultiBar5Button", count = 12, blizz = { "MultiBar5" } },
	{ key = "bar7", holder = "Bar7", prefix = "MultiBar6Button", count = 12, blizz = { "MultiBar6" } },
	{ key = "bar8", holder = "Bar8", prefix = "MultiBar7Button", count = 12, blizz = { "MultiBar7" } },
	{ key = "pet", holder = "PetBar", prefix = "PetActionButton", count = 10, blizz = { "PetActionBar" },
		driver = "[petbattle] hide; [pet,nopossessbar] show; hide" },
	{ key = "stance", holder = "StanceBar", prefix = "StanceButton", count = 10, blizz = { "StanceBar" } },
}

local skinned = setmetatable({}, { __mode = "k" })
AB.bars = {}

---------------------------------------------------------------------------
-- Button skin
---------------------------------------------------------------------------

local function Inset(region, parent)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
	region:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
end

-- Re-applied after every Blizzard art refresh.
local function ApplyArt(button)
	local normal = button.NormalTexture or button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	if button.SlotArt then button.SlotArt:SetAlpha(0) end
	if button.SlotBackground then button.SlotBackground:SetAlpha(0) end

	local pushed = button:GetPushedTexture()
	if pushed then
		pushed:SetTexture(ns.TEXTURE)
		pushed:SetVertexColor(1, 1, 1, 0.18)
		Inset(pushed, button)
	end
end

local function StyleText(button)
	local db = ns.db.actionbars
	local w = button:GetWidth()
	local size = math.max(8, math.floor(w * 0.3 + 0.5))

	if button.HotKey then
		ns.SetFont(button.HotKey, size, "OUTLINE")
		button.HotKey:ClearAllPoints()
		button.HotKey:SetPoint("TOPRIGHT", -2, -3)
		button.HotKey:SetWidth(w - 4)
		button.HotKey:SetJustifyH("RIGHT")
		button.HotKey:SetAlpha(db.hotkeys and 1 or 0)
	end
	if button.Count then
		ns.SetFont(button.Count, size + 1, "OUTLINE")
		button.Count:ClearAllPoints()
		button.Count:SetPoint("BOTTOMRIGHT", -2, 3)
	end
	if button.Name then
		ns.SetFont(button.Name, math.max(8, size - 1), "OUTLINE")
		button.Name:SetAlpha(db.macroNames and 1 or 0)
	end
end

-- Blizzard sizes these overlays for a 45px button; make them follow ours.
local FILL_REGIONS = { "Border", "Flash", "NewActionTexture", "SpellHighlightTexture", "QuickKeybindHighlightTexture", "AutoCastOverlay" }

local function SkinButton(button)
	if not button or skinned[button] then return end
	skinned[button] = true

	ns.CreatePanel(button, { 0.04, 0.04, 0.05, 0.9 })

	local icon = button.icon or button.Icon
	if icon then
		if button.IconMask then icon:RemoveMaskTexture(button.IconMask) end
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		Inset(icon, button)
	end

	local cd = button.cooldown
	if cd and icon then
		cd:ClearAllPoints()
		cd:SetAllPoints(icon)
		if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.7) end
	end

	local hl = button:GetHighlightTexture()
	if hl then
		hl:SetTexture(ns.TEXTURE)
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:SetBlendMode("ADD")
		Inset(hl, button)
	end

	local checked = button.GetCheckedTexture and button:GetCheckedTexture()
	if checked then
		local a = ns.db.accent
		checked:SetTexture(ns.TEXTURE)
		checked:SetVertexColor(a[1], a[2], a[3], 0.3)
		checked:SetBlendMode("ADD")
		Inset(checked, button)
	end

	for _, key in ipairs(FILL_REGIONS) do
		local region = button[key]
		if region and region.SetAllPoints then
			region:ClearAllPoints()
			region:SetAllPoints(button)
		end
	end

	ApplyArt(button)
	StyleText(button)

	if button.UpdateButtonArt then
		hooksecurefunc(button, "UpdateButtonArt", ApplyArt)
	end
	if button.UpdateHotkeys then
		hooksecurefunc(button, "UpdateHotkeys", StyleText)
	end
end

---------------------------------------------------------------------------
-- Blizzard bars: emptied and made invisible (never reparented, so Edit Mode
-- and the action bar controller keep working).
---------------------------------------------------------------------------

local function HideBlizzardBar(bar)
	if not bar then return end
	bar:SetAlpha(0)
	if bar.EnableMouse then bar:EnableMouse(false) end
	hooksecurefunc(bar, "SetAlpha", function(self, a)
		if a ~= 0 then self:SetAlpha(0) end
	end)
end

---------------------------------------------------------------------------
-- NovaUI bars
---------------------------------------------------------------------------

local function CreateSlot(bar)
	local slot = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
	slot:SetTexture(ns.TEXTURE)
	slot:SetVertexColor(0.04, 0.04, 0.05, 0.55)
	local border = {}
	for i = 1, 4 do
		local t = bar:CreateTexture(nil, "BACKGROUND", nil, -5)
		t:SetTexture(ns.TEXTURE)
		t:SetVertexColor(0, 0, 0, 0.8)
		border[i] = t
	end
	border[1]:SetPoint("TOPLEFT", slot) border[1]:SetPoint("TOPRIGHT", slot) border[1]:SetHeight(1)
	border[2]:SetPoint("BOTTOMLEFT", slot) border[2]:SetPoint("BOTTOMRIGHT", slot) border[2]:SetHeight(1)
	border[3]:SetPoint("TOPLEFT", slot) border[3]:SetPoint("BOTTOMLEFT", slot) border[3]:SetWidth(1)
	border[4]:SetPoint("TOPRIGHT", slot) border[4]:SetPoint("BOTTOMRIGHT", slot) border[4]:SetWidth(1)
	slot.border = border
	function slot:SetShownAll(show)
		self:SetShown(show)
		for _, t in ipairs(self.border) do t:SetShown(show) end
	end
	return slot
end

local function UpdateMouseover(bar)
	local cfg = ns.db.actionbars.bars[bar.info.key]
	bar.targetAlpha = nil
	if not cfg.mouseover then
		bar:SetScript("OnUpdate", nil)
		ns.FadeTo(bar, cfg.alpha, 0.2)
		return
	end
	local elapsed = 1
	bar:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed < 0.1 then return end
		elapsed = 0
		local over = self:IsMouseOver(4, -4, -4, 4)
			or (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:IsMouseOver())
			or not ns.locked
		local target = over and cfg.alpha or 0
		if self.targetAlpha ~= target then
			self.targetAlpha = target
			ns.FadeTo(self, target, 0.2)
		end
	end)
end

---------------------------------------------------------------------------
-- Grid: columns x rows, fill order (row by row / column by column) and the
-- corner button 1 starts from (which also decides where the bar grows).
-- Shared by the bars and the settings preview.
---------------------------------------------------------------------------

-- Older settings stored "buttons" + "per row"; convert once.
function AB.Migrate(cfg)
	if cfg.cols == nil then
		local buttons = cfg.buttons or 12
		cfg.cols = math.max(1, math.min(cfg.perRow or 12, buttons))
		cfg.rows = math.max(1, math.ceil(buttons / cfg.cols))
	end
	cfg.order = cfg.order or "row"
	cfg.corner = cfg.corner or "TOPLEFT"
	cfg.vspacing = cfg.vspacing or cfg.spacing or 4
end

-- Returns the cells {col, row} for n buttons and the used columns/rows.
function AB.Grid(cfg, n)
	local cells = {}
	if n <= 0 then return cells, 0, 0 end
	local cols, rows
	if cfg.order == "col" then
		rows = math.max(1, math.min(cfg.rows, n))
		cols = math.ceil(n / rows)
	else
		cols = math.max(1, math.min(cfg.cols, n))
		rows = math.ceil(n / cols)
	end
	for i = 1, n do
		if cfg.order == "col" then
			cells[i] = { math.floor((i - 1) / rows), (i - 1) % rows }
		else
			cells[i] = { (i - 1) % cols, math.floor((i - 1) / cols) }
		end
	end
	return cells, cols, rows
end

-- Offset of a cell from the start corner (x right/left, y up/down).
function AB.CellOffset(cfg, col, row, size)
	local corner = cfg.corner
	local sx = corner:find("LEFT") and 1 or -1
	local sy = corner:find("TOP") and -1 or 1
	return sx * col * (size + cfg.spacing), sy * row * (size + cfg.vspacing)
end

function AB.ButtonCount(key, cfg, count)
	local n = math.min(cfg.cols * cfg.rows, count)
	if key == "stance" then
		local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
		n = math.max(1, math.min(n, forms))
	end
	return n
end

function AB:Layout(key)
	local bar = self.bars[key]
	if not bar then return end
	ns.RunOOC("ablayout" .. key, function()
		local info = bar.info
		local cfg = ns.db.actionbars.bars[key]
		AB.Migrate(cfg)
		local size = cfg.size

		local n = AB.ButtonCount(key, cfg, info.count)
		local cells, cols, rows = AB.Grid(cfg, n)
		local w = math.max(size, cols * size + (cols - 1) * cfg.spacing)
		local h = math.max(size, rows * size + (rows - 1) * cfg.vspacing)
		bar.holder:SetSize(w, h)

		for i, button in ipairs(bar.buttons) do
			local slot = bar.slots[i]
			local cell = cells[i]
			if cfg.enabled and cell then
				local x, y = AB.CellOffset(cfg, cell[1], cell[2], size)
				button:SetParent(bar)
				button:ClearAllPoints()
				button:SetPoint(cfg.corner, bar, cfg.corner, x, y)
				button:SetSize(size, size)
				StyleText(button)
				slot:ClearAllPoints()
				slot:SetPoint(cfg.corner, bar, cfg.corner, x, y)
				slot:SetSize(size, size)
				slot:SetShownAll(ns.db.actionbars.emptySlots and key ~= "pet" and key ~= "stance")
			else
				button:SetParent(ns.hider)
				slot:SetShownAll(false)
			end
		end

		local visible = cfg.enabled
		if key == "stance" then
			visible = visible and (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) > 0
		end
		if info.driver then
			if visible then
				RegisterStateDriver(bar, "visibility", info.driver)
			else
				UnregisterStateDriver(bar, "visibility")
				bar:Hide()
			end
		else
			bar:SetShown(visible)
		end

		UpdateMouseover(bar)
	end)
end

function AB:LayoutAll()
	for _, info in ipairs(self.BARS) do self:Layout(info.key) end
end

function AB:Refresh()
	for button in pairs(skinned) do StyleText(button) end
	self:LayoutAll()
end

local function CreateBar(info)
	local holder = ns.CreateHolder(info.holder, 100, 30, L["BAR_" .. info.key])
	local bar = CreateFrame("Frame", "NovaUI_" .. info.holder, holder, "SecureHandlerStateTemplate")
	bar:SetAllPoints(holder)
	bar.info = info
	bar.holder = holder
	bar.buttons = {}
	bar.slots = {}
	for i = 1, info.count do
		local button = _G[info.prefix .. i]
		if button then
			SkinButton(button)
			bar.buttons[#bar.buttons + 1] = button
			bar.slots[#bar.buttons] = CreateSlot(bar)
		end
	end
	holder.OnUnlock = function() UpdateMouseover(bar) end
	AB.bars[info.key] = bar
	return bar
end

function AB:Init()
	if InCombatLockdown() then
		ns.RunOOC("abinit", function() AB:Init() end)
		return
	end

	for _, info in ipairs(self.BARS) do
		for _, name in ipairs(info.blizz) do
			local blizz = _G[name]
			if blizz then
				HideBlizzardBar(blizz)
				break
			end
		end
		if #(info.prefix) > 0 and _G[info.prefix .. "1"] then
			CreateBar(info)
		end
	end
	self:LayoutAll()

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function() AB:Layout("stance") end)
end
