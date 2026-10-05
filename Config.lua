local _, ns = ...
local L = ns.L
local W = ns.Widgets

local Config = {}
ns.Config = Config

local WIDTH, HEIGHT, SIDEBAR = 660, 560, 160
local frameCount = 0

local function Accent() return unpack(ns.db.accent) end

---------------------------------------------------------------------------
-- Scrollable page: widgets stack top to bottom; the wheel scrolls.
---------------------------------------------------------------------------

local function NewPage(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT", SIDEBAR + 24, -66)
	scroll:SetPoint("BOTTOMRIGHT", -18, 56)
	scroll:Hide()

	local page = CreateFrame("Frame", nil, scroll)
	page:SetSize(WIDTH - SIDEBAR - 48, 10)
	scroll:SetScrollChild(page)
	scroll.page = page

	-- Thin scroll indicator.
	local track = scroll:CreateTexture(nil, "OVERLAY")
	track:SetTexture(ns.TEXTURE)
	track:SetVertexColor(1, 1, 1, 0.05)
	track:SetPoint("TOPRIGHT", 6, 0)
	track:SetPoint("BOTTOMRIGHT", 6, 0)
	track:SetWidth(3)
	local thumb = scroll:CreateTexture(nil, "OVERLAY", nil, 1)
	thumb:SetTexture(ns.TEXTURE)
	thumb:SetVertexColor(Accent())
	thumb:SetWidth(3)

	local function UpdateThumb()
		local range = scroll:GetVerticalScrollRange()
		local h = scroll:GetHeight()
		local show = range > 1
		track:SetShown(show)
		thumb:SetShown(show)
		if not show then return end
		local th = math.max(20, h * h / (h + range))
		thumb:SetHeight(th)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -(h - th) * (scroll:GetVerticalScroll() / range))
	end

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		local v = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40))
		self:SetVerticalScroll(v)
		UpdateThumb()
	end)
	scroll:SetScript("OnShow", function(self)
		self:SetVerticalScroll(0)
		C_Timer.After(0, UpdateThumb)
	end)

	page.y = 0
	page.widgets = {}

	function page:Add(widget, spacing)
		widget:SetPoint("TOPLEFT", 0, -self.y)
		self.y = self.y + widget:GetHeight() + (spacing or 8)
		self.widgets[#self.widgets + 1] = widget
		self:SetHeight(self.y + 10)
		return widget
	end

	function page:AddHeader(text)
		if self.y > 0 then self.y = self.y + 14 end
		local h = W.Header(self, text)
		h:SetPoint("TOPLEFT", 0, -self.y)
		self.y = self.y + 28
	end

	function page:AddNote(text)
		local fs = ns.CreateText(self, 11)
		fs:SetPoint("TOPLEFT", 0, -self.y)
		fs:SetWidth(self:GetWidth() - 10)
		fs:SetWordWrap(true)
		fs:SetJustifyH("LEFT")
		fs:SetTextColor(unpack(ns.colors.muted))
		fs:SetText(text)
		self.y = self.y + math.max(14, fs:GetStringHeight()) + 10
		self:SetHeight(self.y + 10)
	end

	function page:Refresh()
		for _, w in ipairs(self.widgets) do
			if w.Refresh then w:Refresh() end
		end
		C_Timer.After(0, UpdateThumb)
	end

	scroll.Refresh = function() page:Refresh() end
	return page, scroll
end

---------------------------------------------------------------------------
-- Bindings. `tbl` is a function returning the settings table, so a page can
-- re-point its widgets (e.g. the action bar selector).
---------------------------------------------------------------------------

local function Toggle(page, text, tbl, key, apply, reload)
	return page:Add(W.Toggle(page, text,
		function() return tbl()[key] end,
		function(v)
			tbl()[key] = v
			if apply then apply(v) end
			if reload then Config:NeedReload() end
		end))
end

local function Slider(page, text, tbl, key, minV, maxV, step, apply, fmt)
	return page:Add(W.Slider(page, text, minV, maxV, step,
		function() return tbl()[key] end,
		function(v)
			tbl()[key] = v
			if apply then apply(v) end
		end, fmt), 12)
end

local function DB(section) return function() return section == "_root" and ns.db or ns.db[section] end end

local function Call(mod, method, ...)
	if mod and mod[method] then mod[method](mod, ...) end
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local function BuildGeneral(page)
	page:AddHeader(L.TAB_GENERAL)

	local langs = {}
	for _, l in ipairs(ns.languages) do langs[#langs + 1] = { value = l[1], label = l[2] } end
	page:Add(W.Segment(page, L.LANGUAGE, langs,
		function() return ns.db.language end,
		function(v)
			ns.db.language = v
			C_Timer.After(0, function() Config:Rebuild() end)
		end))

	local fonts = {}
	for _, f in ipairs(ns.FONTS) do fonts[#fonts + 1] = { value = f.path, label = f.label, width = 100 } end
	page:Add(W.Segment(page, L.FONT, fonts, function() return ns.db.font end, function(v)
		ns.db.font = v
		Config:NeedReload()
	end))
	Toggle(page, L.GLOBAL_FONT, DB("_root"), "globalFont", nil, true)

	Toggle(page, L.SKINS, DB("skins"), "enabled", nil, true)

	page:AddHeader(L.UNLOCK)
	local row = CreateFrame("Frame", nil, page)
	row:SetSize(420, 26)
	local unlock = W.Button(row, ns.locked and L.UNLOCK or L.LOCK, 130, function()
		ns.SetLocked(not ns.locked)
	end)
	unlock:SetPoint("LEFT")
	function row:Refresh() unlock:SetText(ns.locked and L.UNLOCK or L.LOCK) end
	local reset = W.Button(row, L.RESET_POS, 140, function()
		ns.ResetPositions()
		ns.Print(L.POSITIONS_RESET)
	end)
	reset:SetPoint("LEFT", unlock, "RIGHT", 8, 0)
	local reload = W.Button(row, L.RELOAD, 120, ReloadUI)
	reload:SetPoint("LEFT", reset, "RIGHT", 8, 0)
	page:Add(row)
	page:AddNote(L.MOVER_HINT .. "\n" .. L.HINT_FOOTER)

end

local function BuildUnits(page)
	local UF = ns.UnitFrames
	page:AddHeader(L.TAB_UNITS)
	Toggle(page, L.ENABLE_MODULE, DB("unitframes"), "enabled", nil, true)
	Slider(page, L.SCALE, DB("unitframes"), "scale", 0.6, 1.6, 0.05, function(v) Call(UF, "SetScale", v) end)
	page:Add(W.Segment(page, L.BAR_STYLE, {
		{ value = "portrait", label = L.STYLE_PORTRAIT, width = 100 },
		{ value = "colored", label = L.STYLE_COLORED, width = 100 },
		{ value = "dark", label = L.STYLE_DARK, width = 100 },
	}, function() return ns.db.unitframes.style end, function(v)
		local old = ns.db.unitframes.style
		ns.db.unitframes.style = v
		-- The portrait layout is built at load time.
		if old == "portrait" or v == "portrait" then Config:NeedReload() end
		Call(UF, "RefreshAll")
		Call(ns.Group, "RefreshAll")
	end))
	Toggle(page, L.CLASS_COLOR, DB("unitframes"), "classColor", function() Call(UF, "RefreshAll") end)
	Toggle(page, L.SHOW_PERCENT, DB("unitframes"), "showPercent", function() Call(UF, "RefreshAll") end)
	Toggle(page, L.FADE_OOC, DB("unitframes"), "fadeOutOfCombat", function() Call(UF, "UpdateFade") end)
	Toggle(page, L.ABSORBS, DB("unitframes"), "absorbs", function() Call(UF, "RefreshAll") Call(ns.Group, "RefreshAll") end)
	Toggle(page, L.PERSONAL_ON, DB("unitframes"), "personal", nil, true)
	Slider(page, L.FADE_ALPHA, DB("unitframes"), "fadeAlpha", 0, 1, 0.05, function() Call(UF, "UpdateFade") end)

	page:AddHeader(L.TARGET_AURAS)
	Toggle(page, L.AURAS_TARGET, DB("auras"), "target", nil, true)
	Toggle(page, L.AURAS_MINE, DB("auras"), "onlyMine", nil, true)
	Slider(page, L.AURA_SIZE, DB("auras"), "targetSize", 16, 40, 1, function() Config:NeedReload() end, "%d")
	Slider(page, L.AURA_PER_ROW, DB("auras"), "targetPerRow", 4, 16, 1, function() Config:NeedReload() end, "%d")
	Toggle(page, L.AURAS_SKIN, DB("auras"), "skinPlayer", nil, true)
	Toggle(page, L.MY_BUFFS_ON, DB("auras"), "playerShort", nil, true)

	page:AddHeader(L.NAMEPLATES)
	Toggle(page, L.ENABLE_MODULE, DB("nameplates"), "enabled", nil, true)
	local function np() Call(ns.Nameplates, "Refresh") end
	Toggle(page, L.NP_PERCENT, DB("nameplates"), "percent", np)
	Toggle(page, L.NP_OUTLINE, DB("nameplates"), "outline", np)
	Toggle(page, L.NP_ARROWS, DB("nameplates"), "arrows", np)
	Toggle(page, L.NP_QUEST, DB("nameplates"), "quest", np)
	Toggle(page, L.NP_EXECUTE, DB("nameplates"), "execute", np)
	Slider(page, L.NP_EXECUTE_PCT, DB("nameplates"), "executePct", 10, 40, 5, function() Config:NeedReload() end, "%d%%")
	Slider(page, L.NP_NAME_SIZE, DB("nameplates"), "nameSize", 6, 16, 1, np, "%d")
	Slider(page, L.NP_TEXT_SIZE, DB("nameplates"), "textSize", 6, 14, 1, np, "%d")
	Slider(page, L.NP_CAST_SIZE, DB("nameplates"), "castSize", 6, 14, 1, np, "%d")
end

local function BuildChatBags(page)
	page:AddHeader(L.CHAT)
	Toggle(page, L.ENABLE_MODULE, DB("chat"), "enabled", nil, true)
	Slider(page, L.CHAT_ALPHA, DB("chat"), "alpha", 0, 1, 0.05, function(v)
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local f = _G[name]
			if f and f.novaBg and f.novaBg.novaPanel then f.novaBg.novaPanel.bg:SetVertexColor(0.035, 0.037, 0.045, v) end
		end
	end)

	local function bags() if ns.Bags and ns.Bags.frame then ns.Bags:Update() end end
	page:AddHeader(L.BAGS)
	Toggle(page, L.ENABLE_MODULE, DB("bags"), "enabled", nil, true)
	Slider(page, L.BAG_COLUMNS, DB("bags"), "columns", 6, 20, 1, bags, "%d")
	Slider(page, L.SLOT_SIZE, DB("bags"), "size", 26, 48, 1, bags, "%d")
	Slider(page, L.SPACING, DB("bags"), "spacing", 0, 10, 1, bags, "%d")
end

local function BuildCast(page)
	local CB = ns.CastBars
	local function apply() Call(CB, "ApplyAll") end
	page:AddHeader(L.CASTBARS)
	Toggle(page, L.ENABLE_MODULE, DB("castbars"), "enabled", nil, true)
	Toggle(page, L.CAST_TARGET, DB("castbars"), "target", nil, true)
	Toggle(page, L.CAST_ICON, DB("castbars"), "icon", apply)
	Toggle(page, L.CAST_LATENCY, DB("castbars"), "latency")
	Slider(page, L.PLAYER_WIDTH, DB("castbars"), "playerWidth", 120, 500, 2, apply, "%d")
	Slider(page, L.PLAYER_HEIGHT, DB("castbars"), "playerHeight", 10, 40, 1, apply, "%d")
	Slider(page, L.TARGET_WIDTH, DB("castbars"), "targetWidth", 120, 500, 2, apply, "%d")
	Slider(page, L.TARGET_HEIGHT, DB("castbars"), "targetHeight", 10, 40, 1, apply, "%d")
	Slider(page, L.SCALE, DB("castbars"), "scale", 0.6, 1.6, 0.05, function(v) Call(CB, "SetScale", v) end)

	local SW = ns.SwingTimer
	local function swing() Call(SW, "UpdateVisibility") end
	page:AddHeader(L.SWING)
	Toggle(page, L.ENABLE_MODULE, DB("swing"), "enabled", nil, true)
	Toggle(page, L.SWING_OFFHAND, DB("swing"), "offhand", swing)
	Toggle(page, L.SWING_RANGED_OPT, DB("swing"), "ranged", swing)
	Slider(page, L.WIDTH, DB("swing"), "width", 100, 400, 2, swing, "%d")
	Slider(page, L.HEIGHT, DB("swing"), "height", 3, 20, 1, swing, "%d")
end

local function BuildBars(page)
	local AB = ns.ActionBars
	local selected = "bar1"
	local function cfg()
		local c = ns.db.actionbars.bars[selected]
		ns.ActionBars.Migrate(c)
		return c
	end
	local function layout() Call(AB, "Layout", selected) end

	page:AddHeader(L.TAB_BARS)
	Toggle(page, L.ENABLE_MODULE, DB("actionbars"), "enabled", nil, true)
	Toggle(page, L.HOTKEYS, DB("actionbars"), "hotkeys", function() Call(AB, "Refresh") end)
	Toggle(page, L.MACRO_NAMES, DB("actionbars"), "macroNames", function() Call(AB, "Refresh") end)
	Toggle(page, L.EMPTY_SLOTS, DB("actionbars"), "emptySlots", function() Call(AB, "LayoutAll") end)
	page:AddNote(L.EDITMODE_NOTE)

	page:AddHeader(L.SELECT_BAR)
	local options = {}
	for i = 1, 8 do options[#options + 1] = { value = "bar" .. i, label = tostring(i), width = 34 } end
	options[#options + 1] = { value = "pet", label = "Pet", width = 46 }
	options[#options + 1] = { value = "stance", label = L.BAR_stance:match("^(%S+)") or "Stance", width = 64 }
	page:Add(W.Segment(page, L.SELECT_BAR, options,
		function() return selected end,
		function(v)
			selected = v
			page:Refresh()
		end))

	Toggle(page, L.ENABLE_BAR, cfg, "enabled", layout)

	-- Grid: preview first, then the controls that shape it.
	local function count() return (selected == "pet" or selected == "stance") and 10 or 12 end
	local preview = page:Add(W.GridPreview(page, function() return selected end, cfg, count), 10)
	local function relayout() layout() preview:Refresh() end

	local presets = {}
	for _, p in ipairs({ { 12, 1 }, { 6, 2 }, { 4, 3 }, { 3, 4 }, { 2, 6 }, { 1, 12 } }) do
		presets[#presets + 1] = { value = p[1] .. "x" .. p[2], label = p[1] .. "×" .. p[2], width = 56 }
	end
	page:Add(W.Segment(page, L.GRID_PRESET, presets,
		function() local c = cfg() ns.ActionBars.Migrate(c) return c.cols .. "x" .. c.rows end,
		function(v)
			local c = cfg()
			local cols, rows = v:match("(%d+)x(%d+)")
			c.cols, c.rows = tonumber(cols), tonumber(rows)
			relayout()
			page:Refresh()
		end))
	Slider(page, L.GRID_COLS, cfg, "cols", 1, 12, 1, relayout, "%d")
	Slider(page, L.GRID_ROWS, cfg, "rows", 1, 12, 1, relayout, "%d")
	page:Add(W.Segment(page, L.GRID_ORDER, {
		{ value = "row", label = L.GRID_ORDER_ROW, width = 120 },
		{ value = "col", label = L.GRID_ORDER_COL, width = 120 },
	}, function() return cfg().order end, function(v) cfg().order = v relayout() end))
	page:Add(W.Segment(page, L.GRID_CORNER, {
		{ value = "TOPLEFT", label = L.CORNER_TL, width = 84 },
		{ value = "TOPRIGHT", label = L.CORNER_TR, width = 84 },
		{ value = "BOTTOMLEFT", label = L.CORNER_BL, width = 84 },
		{ value = "BOTTOMRIGHT", label = L.CORNER_BR, width = 84 },
	}, function() return cfg().corner end, function(v) cfg().corner = v relayout() end))
	Slider(page, L.BUTTON_SIZE, cfg, "size", 18, 64, 1, relayout, "%d")
	Slider(page, L.SPACING_X, cfg, "spacing", 0, 20, 1, relayout, "%d")
	Slider(page, L.SPACING_Y, cfg, "vspacing", 0, 20, 1, relayout, "%d")
	Slider(page, L.OPACITY, cfg, "alpha", 0.1, 1, 0.05, layout)
	Toggle(page, L.MOUSEOVER, cfg, "mouseover", layout)
end

local function BuildGroup(page)
	local G = ns.Group
	page:AddHeader(L.PARTY_FRAMES)
	Toggle(page, L.ENABLE_MODULE, DB("party"), "enabled", nil, true)
	Toggle(page, L.SHOW_PLAYER, DB("party"), "showPlayer", function() Call(G, "ApplySize", "party") end)
	Slider(page, L.WIDTH, DB("party"), "width", 100, 320, 2, function() Call(G, "ApplySize", "party") end, "%d")
	Slider(page, L.HEIGHT, DB("party"), "height", 20, 80, 1, function() Call(G, "ApplySize", "party") end, "%d")
	Slider(page, L.SPACING, DB("party"), "spacing", 0, 24, 1, function() Call(G, "ApplySize", "party") end, "%d")

	page:AddHeader(L.RAID_FRAMES)
	Toggle(page, L.ENABLE_MODULE, DB("raid"), "enabled", nil, true)
	Toggle(page, L.RANGE_FADE, DB("raid"), "rangeFade", function() Call(G, "RefreshAll") end)
	Slider(page, L.WIDTH, DB("raid"), "width", 50, 160, 1, function() Call(G, "ApplySize", "raid") end, "%d")
	Slider(page, L.HEIGHT, DB("raid"), "height", 20, 80, 1, function() Call(G, "ApplySize", "raid") end, "%d")
	Slider(page, L.SPACING, DB("raid"), "spacing", 0, 16, 1, function() Call(G, "ApplySize", "raid") end, "%d")
end

local function BuildMenu(page)
	local XP, MM = ns.XPBar, ns.MicroMenu
	page:AddHeader(L.XPBAR)
	Toggle(page, L.ENABLE_MODULE, DB("xpbar"), "enabled", nil, true)
	Slider(page, L.XP_HEIGHT, DB("xpbar"), "height", 4, 24, 1, function() Call(XP, "ApplyLayout") end, "%d")
	Toggle(page, L.XP_TICKS, DB("xpbar"), "ticks", function() Call(XP, "ApplyLayout") end)
	Toggle(page, L.XP_TEXT, DB("xpbar"), "showText", function() Call(XP, "Update") end)
	Toggle(page, L.XP_REP, DB("xpbar"), "reputation", function() Call(XP, "Update") end)

	page:AddHeader(L.MICROMENU)
	Toggle(page, L.ENABLE_MODULE, DB("micromenu"), "enabled", nil, true)
	Toggle(page, L.MM_LABELS, DB("micromenu"), "labels", function() Call(MM, "Layout") end)
	Slider(page, L.MM_SIZE, DB("micromenu"), "size", 14, 34, 1, function() Call(MM, "Layout") end, "%d")
	Slider(page, L.MM_HEIGHT, DB("micromenu"), "height", 22, 44, 1, function() Call(MM, "Layout") end, "%d")
	Toggle(page, L.CLOCK24, DB("micromenu"), "clock24", function() Call(MM, "UpdateFast") end)
	Slider(page, L.MM_ALPHA, DB("micromenu"), "alpha", 0.2, 1, 0.05, function() Call(MM, "Sleep") end)
end

local function BuildMap(page)
	page:AddHeader(L.TAB_MAP)
	Toggle(page, L.ENABLE_MODULE, DB("minimap"), "enabled", nil, true)
	Slider(page, L.MAP_SIZE, DB("minimap"), "size", 140, 260, 2, function() Call(ns.Minimap, "Refresh") end, "%d")
	Toggle(page, L.ZONE_TEXT, DB("minimap"), "zoneText", function() Call(ns.Minimap, "UpdateZone") end)

end

local function BuildTooltip(page)
	page:AddHeader(L.TAB_TOOLTIP)
	Toggle(page, L.ENABLE_MODULE, DB("tooltip"), "enabled", nil, true)
	Toggle(page, L.TT_CURSOR, DB("tooltip"), "cursor")
	Toggle(page, L.TT_QUALITY, DB("tooltip"), "qualityBorder")
end

local function BuildProfiles(page)
	local P = ns.Profiles
	page:AddHeader(L.PROFILE)

	local current = CreateFrame("Frame", nil, page)
	current:SetSize(420, 20)
	local cur = ns.CreateText(current, 13)
	cur:SetPoint("LEFT")
	function current:Refresh()
		cur:SetText(("%s: |cff4fc3f7%s|r"):format(L.PROFILE_ACTIVE, P.CurrentName()))
	end
	page:Add(current)

	-- Save the current setup under a name.
	local saveRow = CreateFrame("Frame", nil, page)
	saveRow:SetSize(420, 26)
	local nameBox = W.Input(saveRow, 220, L.PROFILE_NAME_HINT)
	nameBox:SetPoint("LEFT")
	local status = ns.CreateText(page, 11)
	local function Say(text, ok)
		status:SetText(text or "")
		if ok then status:SetTextColor(0.44, 0.86, 0.55) else status:SetTextColor(0.92, 0.34, 0.34) end
	end
	local save = W.Button(saveRow, L.PROFILE_SAVE, 110, function()
		local name = nameBox:GetText()
		if name == "" then name = P.CurrentName() end
		local ok, err = P.Save(name)
		if ok then
			Say(L.PROFILE_SAVED:format(name), true)
			nameBox:SetText("")
			nameBox:ClearFocus()
			page:Refresh()
		else
			Say(err, false)
		end
	end)
	save:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
	nameBox:SetScript("OnEnterPressed", function() save:Click() end)
	page:Add(saveRow, 4)
	status:SetPoint("TOPLEFT", 0, -page.y)
	page.y = page.y + 18

	local io = CreateFrame("Frame", nil, page)
	io:SetSize(420, 26)
	local imp = W.Button(io, L.PROFILE_IMPORT, 130, function() P.ShowImport() end)
	imp:SetPoint("LEFT")
	local exp = W.Button(io, L.PROFILE_EXPORT_CURRENT, 160, function() P.ShowExport() end)
	exp:SetPoint("LEFT", imp, "RIGHT", 8, 0)
	page:Add(io)
	page:AddNote(L.PROFILE_NOTE)

	page:AddHeader(L.PROFILE_SAVED_LIST)
	local list = CreateFrame("Frame", nil, page)
	list:SetSize(420, 20)
	list:SetPoint("TOPLEFT", 0, -page.y)
	local listTop = page.y
	local rows = {}
	local empty = ns.CreateText(list, 11)
	empty:SetPoint("TOPLEFT")
	empty:SetText(L.PROFILE_NONE)
	empty:SetTextColor(unpack(ns.colors.muted))

	local function Row(i)
		if rows[i] then return rows[i] end
		local r = CreateFrame("Frame", nil, list)
		r:SetSize(420, 30)
		ns.CreatePanel(r, { 0.07, 0.074, 0.087, 1 }, true)
		r.name = ns.CreateText(r, 12)
		r.name:SetPoint("TOPLEFT", 8, -5)
		r.name:SetWidth(170)
		r.name:SetJustifyH("LEFT")
		r.date = ns.CreateText(r, 10)
		r.date:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -1)
		r.date:SetTextColor(unpack(ns.colors.muted))
		r.del = W.Button(r, L.PROFILE_DELETE, 56, function()
			-- Two clicks to delete.
			if r.armed then
				P.Delete(r.profile)
				Say(L.PROFILE_DELETED:format(r.profile), true)
				page:Refresh()
			else
				r.armed = true
				r.del:SetText(L.PROFILE_SURE)
				C_Timer.After(3, function() r.armed = false r.del:SetText(L.PROFILE_DELETE) end)
			end
		end)
		r.del:SetPoint("RIGHT", -4, 0)
		r.exp = W.Button(r, L.PROFILE_EXPORT, 84, function() P.ShowExport(r.profile) end)
		r.exp:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
		r.load = W.Button(r, L.PROFILE_LOAD, 70, function()
			local ok, err = P.Load(r.profile)
			if ok then
				Say(L.PROFILE_LOADED:format(r.profile), true)
				Config:NeedReload()
				page:Refresh()
			else
				Say(err, false)
			end
		end)
		r.load:SetPoint("RIGHT", r.exp, "LEFT", -4, 0)
		for _, b in ipairs({ r.del, r.exp, r.load }) do b:SetHeight(22) end
		rows[i] = r
		return r
	end

	function list:Refresh()
		local items = P.List()
		for _, r in ipairs(rows) do r:Hide() end
		empty:SetShown(#items == 0)
		local active = P.CurrentName()
		for i, item in ipairs(items) do
			local r = Row(i)
			r.profile = item.name
			r.armed = false
			r.del:SetText(L.PROFILE_DELETE)
			r.name:SetText(item.name == active and ("|cff4fc3f7%s|r"):format(item.name) or item.name)
			r.date:SetText(("%s  ·  v%s"):format(item.created or "?", item.version or "?"))
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
			r:Show()
		end
		local h = math.max(20, #items * 34)
		list:SetHeight(h)
		page:SetHeight(listTop + h + 20)
	end
	page.widgets[#page.widgets + 1] = list
	P.OnChanged = function() page:Refresh() end
end

local function BuildAlerts(page)
	local AL = ns.Alerts
	page:AddHeader(L.TAB_ALERTS)
	Toggle(page, L.ENABLE_MODULE, DB("alerts"), "enabled", nil, true)
	page:AddNote(L.ALERTS_NOTE)

	page:AddHeader(L.ALERT_LOWHEALTH)
	Toggle(page, L.ALERT_LOWHEALTH_ON, DB("alerts"), "lowHealthOn", nil, true)
	Slider(page, L.ALERT_THRESHOLD, DB("alerts"), "lowHealth", 10, 60, 5, function() Config:NeedReload() end, "%d%%")

	page:AddHeader(L.ALERT_BUFFS)
	Toggle(page, L.ALERT_BUFFS_ON, DB("alerts"), "buffs", nil, true)

	page:AddHeader(L.ALERT_COOLDOWNS)
	Toggle(page, L.ALERT_COOLDOWNS_ON, DB("alerts"), "cooldowns", nil, true)
	Slider(page, L.BUTTON_SIZE, DB("alerts"), "cdSize", 22, 56, 1, function() Call(AL, "LayoutCooldowns") end, "%d")
	Slider(page, L.ALERT_IDLE_ALPHA, DB("alerts"), "cdIdleAlpha", 0, 1, 0.05, function() Call(AL, "UpdateCooldowns") end)

	page:AddHeader(L.ALERT_OTHER)
	Toggle(page, L.ALERT_PROCS_ON, DB("alerts"), "procs", nil, true)
	Toggle(page, L.ALERT_COMBAT_ON, DB("alerts"), "combatText", nil, true)

	local function warn() Call(AL, "UpdateWarnings") end
	page:AddHeader(L.ALERT_WARNINGS)
	page:AddNote(L.WARNINGS_NOTE)
	Toggle(page, L.ENABLE_MODULE, DB("alerts"), "warnings", nil, true)
	Toggle(page, L.W_REPAIR_ON, DB("alerts"), "wRepair", warn)
	Slider(page, L.W_REPAIR_PCT, DB("alerts"), "repairPct", 5, 50, 5, warn, "%d%%")
	Toggle(page, L.W_GEAR_ON, DB("alerts"), "wGear", warn)
	Toggle(page, L.W_FOOD_ON, DB("alerts"), "wFood", warn)
	Toggle(page, L.W_WEAPON_ON, DB("alerts"), "wWeapon", warn)
	Toggle(page, L.W_AMMO_ON, DB("alerts"), "wAmmo", warn)
	Slider(page, L.W_AMMO_LOW, DB("alerts"), "ammoLow", 50, 1000, 50, warn, "%d")
	Toggle(page, L.W_ATTACK_ON, DB("alerts"), "wAttack", warn)
	Toggle(page, L.W_PET_ON, DB("alerts"), "wPet", nil, true)

	page:AddHeader(L.TRACKER)
	page:AddNote(L.TRACKER_NOTE)
	Toggle(page, L.ENABLE_MODULE, DB("tracker"), "enabled", nil, true)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

function Config:Build()
	frameCount = frameCount + 1
	local name = "NovaUIConfig" .. frameCount
	local f = CreateFrame("Frame", name, UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, name)
	ns.CreatePanel(f, { 0.045, 0.047, 0.056, 0.97 })

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetTexture(ns.TEXTURE)
	line:SetPoint("TOPLEFT", 1, -1)
	line:SetPoint("TOPRIGHT", -1, -1)
	line:SetHeight(2)
	line:SetVertexColor(Accent())

	local side = f:CreateTexture(nil, "BACKGROUND", nil, -6)
	side:SetTexture(ns.TEXTURE)
	side:SetPoint("TOPLEFT", 1, -3)
	side:SetPoint("BOTTOMLEFT", 1, 1)
	side:SetWidth(SIDEBAR)
	side:SetVertexColor(0.07, 0.074, 0.087, 1)

	local title = ns.CreateText(f, 20)
	title:SetPoint("TOPLEFT", 20, -20)
	title:SetText("|cff4fc3f7Nova|r|cffffffffUI|r")

	local sub = ns.CreateText(f, 10)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetText(L.SUBTITLE)
	sub:SetTextColor(unpack(ns.colors.muted))

	local version = ns.CreateText(f, 10)
	version:SetPoint("BOTTOMLEFT", 20, 18)
	version:SetText("v" .. ns.Nova.version)
	version:SetTextColor(unpack(ns.colors.muted))

	local close = CreateFrame("Button", nil, f)
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -10, -10)
	local x = ns.CreateText(close, 16)
	x:SetPoint("CENTER")
	x:SetText("×")
	x:SetTextColor(0.6, 0.62, 0.66)
	close:SetScript("OnEnter", function() x:SetTextColor(1, 0.4, 0.4) end)
	close:SetScript("OnLeave", function() x:SetTextColor(0.6, 0.62, 0.66) end)
	close:SetScript("OnClick", function() f:Hide() end)

	local notice = CreateFrame("Frame", nil, f)
	notice:SetPoint("BOTTOMLEFT", SIDEBAR + 24, 14)
	notice:SetPoint("BOTTOMRIGHT", -24, 14)
	notice:SetHeight(28)
	notice:Hide()
	local nText = ns.CreateText(notice, 11)
	nText:SetPoint("LEFT")
	nText:SetText(L.RELOAD_NEEDED)
	nText:SetTextColor(1, 0.8, 0.35)
	local nBtn = W.Button(notice, L.RELOAD, 120, ReloadUI)
	nBtn:SetPoint("RIGHT")
	f.notice = notice

	local tabs = {
		{ L.TAB_GENERAL, BuildGeneral },
		{ L.TAB_UNITS, BuildUnits },
		{ L.CASTBARS, BuildCast },
		{ L.TAB_BARS, BuildBars },
		{ L.TAB_GROUP, BuildGroup },
		{ L.TAB_MENU, BuildMenu },
		{ L.TAB_CHATBAGS, BuildChatBags },
		{ L.TAB_MAP, BuildMap },
		{ L.TAB_TOOLTIP, BuildTooltip },
		{ L.TAB_ALERTS, BuildAlerts },
		{ L.PROFILE, BuildProfiles },
	}
	f.pages, f.tabs = {}, {}

	local function Select(index)
		for i, tab in ipairs(f.tabs) do
			local on = i == index
			f.pages[i]:SetShown(on)
			tab.marker:SetShown(on)
			tab.bg:SetAlpha(on and 0.07 or 0)
			tab.text:SetTextColor(on and 1 or 0.62, on and 1 or 0.64, on and 1 or 0.68)
		end
		f.pages[index]:Refresh()
		Config.selected = index
	end

	for i, info in ipairs(tabs) do
		local tab = CreateFrame("Button", nil, f)
		tab:SetSize(SIDEBAR, 32)
		tab:SetPoint("TOPLEFT", 1, -76 - (i - 1) * 34)

		tab.bg = tab:CreateTexture(nil, "BACKGROUND")
		tab.bg:SetTexture(ns.TEXTURE)
		tab.bg:SetAllPoints()
		tab.bg:SetVertexColor(1, 1, 1)
		tab.bg:SetAlpha(0)

		tab.marker = tab:CreateTexture(nil, "ARTWORK")
		tab.marker:SetTexture(ns.TEXTURE)
		tab.marker:SetPoint("TOPLEFT")
		tab.marker:SetPoint("BOTTOMLEFT")
		tab.marker:SetWidth(3)
		tab.marker:SetVertexColor(Accent())
		tab.marker:Hide()

		tab.text = ns.CreateText(tab, 13)
		tab.text:SetPoint("LEFT", 18, 0)
		tab.text:SetText(info[1])

		tab:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			Select(i)
		end)
		tab:SetScript("OnEnter", function() if Config.selected ~= i then tab.bg:SetAlpha(0.04) end end)
		tab:SetScript("OnLeave", function() if Config.selected ~= i then tab.bg:SetAlpha(0) end end)

		local page, scroll = NewPage(f)
		info[2](page)
		f.pages[i] = scroll
		f.tabs[i] = tab
	end

	f:SetScript("OnShow", function()
		Select(Config.selected or 1)
		f.notice:SetShown(Config.reloadNeeded == true)
	end)

	self.frame = f
	return f
end

function Config:NeedReload()
	self.reloadNeeded = true
	if self.frame then self.frame.notice:Show() end
end

function Config:Refresh()
	local f = self.frame
	if f and f:IsShown() and self.selected then
		f.pages[self.selected]:Refresh()
	end
end

function Config:Rebuild()
	local wasShown = self.frame and self.frame:IsShown()
	if self.frame then self.frame:Hide() end
	self.frame = nil
	self:Build()
	if wasShown then self.frame:Show() end
end

function Config:Toggle()
	local f = self.frame or self:Build()
	f:SetShown(not f:IsShown())
end

---------------------------------------------------------------------------
-- Entry in the game's AddOns settings list
---------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
	local panel = CreateFrame("Frame")
	local text = ns.CreateText(panel, 14)
	text:SetPoint("TOPLEFT", 16, -16)
	text:SetText("|cff4fc3f7Nova|rUI")
	local btn = W.Button(panel, "/nova", 140, function()
		if SettingsPanel then HideUIPanel(SettingsPanel) end
		Config:Toggle()
	end)
	btn:SetPoint("TOPLEFT", 16, -44)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "NovaUI")
	Settings.RegisterAddOnCategory(category)
end)
