local _, ns = ...

-- Layout editor: full-screen grid, magnetic snapping to the grid, the screen
-- centre and other NovaUI frames (with visible guide lines), live
-- coordinates, arrow-key nudging and a small toolbar.
local E = {}
ns.EditMode = E

local SNAP = 7          -- snap distance in UI pixels
local movers = {}
ns.locked = true

local function Accent() return unpack(ns.db.accent) end

---------------------------------------------------------------------------
-- Geometry (everything in UIParent units)
---------------------------------------------------------------------------

local function Ratio(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function Rect(frame)
	local l, b, w, h = frame:GetRect()
	if not l then return nil end
	local r = Ratio(frame)
	return l * r, b * r, w * r, h * r
end

local function Round(v) return math.floor(v + 0.5) end

local function Screen()
	return UIParent:GetWidth(), UIParent:GetHeight()
end

local function MoveTo(holder, left, bottom)
	local r = Ratio(holder)
	holder:ClearAllPoints()
	holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / r, bottom / r)
end

-- Saves the position against the nearest screen anchor, so layouts survive
-- resolution and UI-scale changes.
local function Save(holder)
	local l, b, w, h = Rect(holder)
	if not l then return end
	local W, H = Screen()
	local cx, cy = l + w / 2, b + h / 2
	local hp = (cx < W / 3 and "LEFT") or (cx > W * 2 / 3 and "RIGHT") or ""
	local vp = (cy < H / 3 and "BOTTOM") or (cy > H * 2 / 3 and "TOP") or ""
	local point = vp .. hp
	if point == "" then point = "CENTER" end

	local px = (hp == "LEFT" and l) or (hp == "RIGHT" and l + w) or cx
	local py = (vp == "BOTTOM" and b) or (vp == "TOP" and b + h) or cy
	local ax = (hp == "LEFT" and 0) or (hp == "RIGHT" and W) or W / 2
	local ay = (vp == "BOTTOM" and 0) or (vp == "TOP" and H) or H / 2
	local r = Ratio(holder)
	ns.db.positions[holder.key] = { point, "UIParent", point, Round((px - ax) / r), Round((py - ay) / r) }
	ns.PlaceHolder(holder)
end

---------------------------------------------------------------------------
-- Grid
---------------------------------------------------------------------------

local grid
local function BuildGrid()
	if not grid then
		grid = CreateFrame("Frame", "NovaUI_EditGrid", UIParent)
		grid:SetAllPoints(UIParent)
		grid:SetFrameStrata("BACKGROUND")
		grid:EnableMouse(false)
		grid.lines = {}
	end
	for _, t in ipairs(grid.lines) do t:Hide() end

	local size = ns.db.edit.grid
	if size <= 0 then return end
	local W, H = Screen()
	local n = 0
	local function line(vertical, offset, major, center)
		n = n + 1
		local t = grid.lines[n]
		if not t then
			t = grid:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(ns.TEXTURE)
			grid.lines[n] = t
		end
		t:ClearAllPoints()
		if vertical then
			t:SetPoint("TOP", grid, "TOP", offset, 0)
			t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
			t:SetWidth(1)
		else
			t:SetPoint("LEFT", grid, "LEFT", 0, offset)
			t:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
			t:SetHeight(1)
		end
		if center then
			local r, g, b = Accent()
			t:SetVertexColor(r, g, b, 0.55)
		else
			t:SetVertexColor(1, 1, 1, major and 0.11 or 0.05)
		end
		t:Show()
	end
	-- Lines radiate from the screen centre so the centre is always a line.
	for i = 0, math.ceil(W / 2 / size) do
		line(true, i * size, i % 4 == 0, i == 0)
		if i > 0 then line(true, -i * size, i % 4 == 0, false) end
	end
	for i = 0, math.ceil(H / 2 / size) do
		line(false, i * size, i % 4 == 0, i == 0)
		if i > 0 then line(false, -i * size, i % 4 == 0, false) end
	end
end

---------------------------------------------------------------------------
-- Guides & snapping
---------------------------------------------------------------------------

local guides
local function Guides()
	if guides then return guides end
	guides = CreateFrame("Frame", nil, UIParent)
	guides:SetAllPoints(UIParent)
	guides:SetFrameStrata("FULLSCREEN_DIALOG")
	local function make(vertical)
		local t = guides:CreateTexture(nil, "OVERLAY")
		t:SetTexture(ns.TEXTURE)
		t:SetVertexColor(1, 0.35, 0.6, 0.95)
		if vertical then t:SetWidth(1) else t:SetHeight(1) end
		t:Hide()
		return t
	end
	guides.v = make(true)
	guides.h = make(false)
	return guides
end

local function ShowGuide(vertical, pos)
	local g = Guides()
	local t = vertical and g.v or g.h
	if not pos then t:Hide() return end
	t:ClearAllPoints()
	if vertical then
		t:SetPoint("TOP", UIParent, "TOPLEFT", pos, 0)
		t:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", pos, 0)
	else
		t:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, pos)
		t:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, pos)
	end
	t:Show()
end

-- Finds the closest alignment for an axis: own edges/centre against targets.
local function Best(own, targets)
	local bestD, bestLine
	for _, o in ipairs(own) do
		for _, t in ipairs(targets) do
			local d = t - o
			if math.abs(d) <= SNAP and (not bestD or math.abs(d) < math.abs(bestD)) then
				bestD, bestLine = d, t
			end
		end
	end
	return bestD, bestLine
end

local function Snap(holder, l, b, w, h)
	local db = ns.db.edit
	local W, H = Screen()
	local xs, ys = {}, {}

	if db.snapFrames then
		xs[#xs + 1], ys[#ys + 1] = W / 2, H / 2
		xs[#xs + 1], xs[#xs + 1] = 0, W
		ys[#ys + 1], ys[#ys + 1] = 0, H
		for _, other in pairs(ns.holders) do
			if other ~= holder and movers[other.key] and movers[other.key]:IsShown() then
				local ol, ob, ow, oh = Rect(other)
				if ol then
					xs[#xs + 1], xs[#xs + 1], xs[#xs + 1] = ol, ol + ow / 2, ol + ow
					ys[#ys + 1], ys[#ys + 1], ys[#ys + 1] = ob, ob + oh / 2, ob + oh
				end
			end
		end
	end

	local dx, gx = Best({ l, l + w / 2, l + w }, xs)
	local dy, gy = Best({ b, b + h / 2, b + h }, ys)

	-- Fall back to the grid when nothing else is close.
	local size = db.grid
	if db.snapGrid and size > 0 then
		if not dx then
			local edges = {}
			for _, e in ipairs({ l, l + w / 2, l + w }) do
				edges[#edges + 1] = W / 2 + Round((e - W / 2) / size) * size
			end
			dx = Best({ l, l + w / 2, l + w }, edges)
		end
		if not dy then
			local edges = {}
			for _, e in ipairs({ b, b + h / 2, b + h }) do
				edges[#edges + 1] = H / 2 + Round((e - H / 2) / size) * size
			end
			dy = Best({ b, b + h / 2, b + h }, edges)
		end
	end

	return l + (dx or 0), b + (dy or 0), gx, gy
end

---------------------------------------------------------------------------
-- Movers
---------------------------------------------------------------------------

local function StopDrag(m)
	m:SetScript("OnUpdate", nil)
	m.dragging = false
	ShowGuide(true, nil)
	ShowGuide(false, nil)
	m.coords:Hide()
	Save(m.holder)
end

local function StartDrag(m)
	if InCombatLockdown() then return end
	local holder = m.holder
	local l, b = Rect(holder)
	if not l then return end
	local s = UIParent:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	m.offX, m.offY = cx / s - l, cy / s - b
	m.dragging = true
	m.coords:Show()

	m:SetScript("OnUpdate", function(self)
		if not IsMouseButtonDown("LeftButton") then StopDrag(self) return end
		local x, y = GetCursorPosition()
		local _, _, w, h = Rect(holder)
		local nl, nb = x / s - self.offX, y / s - self.offY
		local gx, gy
		if not IsShiftKeyDown() then -- Shift = free move, no snapping
			nl, nb, gx, gy = Snap(holder, nl, nb, w, h)
		end
		MoveTo(holder, nl, nb)
		ShowGuide(true, gx)
		ShowGuide(false, gy)
		local W, H = Screen()
		self.coords:SetFormattedText("%d, %d", Round(nl + w / 2 - W / 2), Round(nb + h / 2 - H / 2))
	end)
end

local function Nudge(m, dx, dy)
	local holder = m.holder
	local l, b = Rect(holder)
	if not l then return end
	MoveTo(holder, l + dx, b + dy)
	Save(holder)
end

local function CreateMover(holder)
	local m = CreateFrame("Frame", nil, UIParent)
	m.holder = holder
	m:SetFrameStrata("DIALOG")
	m:SetAllPoints(holder)
	m:EnableMouse(true)
	m:Hide()

	local r, g, b = Accent()
	m.bg = m:CreateTexture(nil, "BACKGROUND")
	m.bg:SetTexture(ns.TEXTURE)
	m.bg:SetAllPoints()
	m.bg:SetVertexColor(r, g, b, 0.22)
	m.panel = ns.CreatePanel(m, { 0, 0, 0, 0 }, true)
	m.panel:SetBorderColor(r, g, b, 0.9)

	m.label = ns.CreateText(m, 11, "OVERLAY", "OUTLINE")
	m.label:SetPoint("CENTER")
	m.label:SetText(holder.label)

	m.coords = ns.CreateText(m, 10, "OVERLAY", "OUTLINE")
	m.coords:SetPoint("BOTTOM", m, "TOP", 0, 3)
	m.coords:SetTextColor(1, 0.35, 0.6)
	m.coords:Hide()

	m:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then StartDrag(self) end
	end)
	m:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.dragging then
			StopDrag(self)
		elseif button == "RightButton" and not InCombatLockdown() then
			ns.db.positions[holder.key] = nil
			ns.PlaceHolder(holder)
		end
	end)

	-- Arrow keys nudge the hovered frame (Shift = 10 px).
	m:SetScript("OnKeyDown", function(self, key)
		local step = IsShiftKeyDown() and 10 or 1
		local moves = { UP = { 0, step }, DOWN = { 0, -step }, LEFT = { -step, 0 }, RIGHT = { step, 0 } }
		local mv = moves[key]
		if mv and not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false)
			Nudge(self, mv[1], mv[2])
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	m:SetScript("OnEnter", function(self)
		self.bg:SetVertexColor(r, g, b, 0.38)
		if not InCombatLockdown() then
			self:EnableKeyboard(true)
			self:SetPropagateKeyboardInput(true)
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(holder.label, 1, 1, 1)
		GameTooltip:AddLine(ns.L.MOVER_HINT, 0.7, 0.7, 0.7, true)
		GameTooltip:AddLine(ns.L.EDIT_HINT, 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function(self)
		self.bg:SetVertexColor(r, g, b, 0.22)
		if not InCombatLockdown() then self:EnableKeyboard(false) end
		GameTooltip:Hide()
	end)
	return m
end

---------------------------------------------------------------------------
-- Toolbar
---------------------------------------------------------------------------

local GRID_STEPS = { 0, 8, 16, 32, 64 }
local toolbar

local function GridLabel()
	local size = ns.db.edit.grid
	return size > 0 and ("%s: %d"):format(ns.L.GRID, size) or ("%s: %s"):format(ns.L.GRID, ns.L.OFF)
end

local function OnOff(v) return v and ns.L.ON or ns.L.OFF end

local function BuildToolbar()
	if toolbar then return toolbar end
	local W = ns.Widgets
	toolbar = CreateFrame("Frame", "NovaUI_EditToolbar", UIParent)
	toolbar:SetFrameStrata("FULLSCREEN_DIALOG")
	toolbar:SetSize(560, 40)
	toolbar:SetPoint("TOP", UIParent, "TOP", 0, -70)
	toolbar:EnableMouse(true)
	toolbar:SetMovable(true)
	toolbar:RegisterForDrag("LeftButton")
	toolbar:SetScript("OnDragStart", toolbar.StartMoving)
	toolbar:SetScript("OnDragStop", toolbar.StopMovingOrSizing)
	toolbar:SetClampedToScreen(true)
	ns.CreatePanel(toolbar, { 0.045, 0.047, 0.056, 0.96 })
	local line = toolbar:CreateTexture(nil, "ARTWORK")
	line:SetTexture(ns.TEXTURE)
	line:SetPoint("TOPLEFT", 1, -1)
	line:SetPoint("TOPRIGHT", -1, -1)
	line:SetHeight(2)
	line:SetVertexColor(Accent())

	local title = ns.CreateText(toolbar, 12)
	title:SetPoint("LEFT", 12, 0)
	title:SetText("|cff4fc3f7Nova|rUI  " .. ns.L.EDIT_MODE)

	local gridBtn, snapBtn, frameBtn
	local function refresh()
		gridBtn:SetText(GridLabel())
		snapBtn:SetText(("%s: %s"):format(ns.L.SNAP_GRID, OnOff(ns.db.edit.snapGrid)))
		frameBtn:SetText(("%s: %s"):format(ns.L.SNAP_FRAMES, OnOff(ns.db.edit.snapFrames)))
	end

	gridBtn = W.Button(toolbar, "", 96, function()
		local cur, nextSize = ns.db.edit.grid, GRID_STEPS[1]
		for i, v in ipairs(GRID_STEPS) do
			if v == cur then nextSize = GRID_STEPS[i % #GRID_STEPS + 1] end
		end
		ns.db.edit.grid = nextSize
		BuildGrid()
		refresh()
	end)
	gridBtn:SetPoint("LEFT", title, "RIGHT", 14, 0)

	snapBtn = W.Button(toolbar, "", 120, function()
		ns.db.edit.snapGrid = not ns.db.edit.snapGrid
		refresh()
	end)
	snapBtn:SetPoint("LEFT", gridBtn, "RIGHT", 6, 0)

	frameBtn = W.Button(toolbar, "", 130, function()
		ns.db.edit.snapFrames = not ns.db.edit.snapFrames
		refresh()
	end)
	frameBtn:SetPoint("LEFT", snapBtn, "RIGHT", 6, 0)

	local done = W.Button(toolbar, ns.L.LOCK, 70, function() ns.SetLocked(true) end)
	done:SetPoint("RIGHT", -8, 0)

	toolbar.Refresh = refresh
	refresh()
	return toolbar
end

---------------------------------------------------------------------------
-- Lock / unlock
---------------------------------------------------------------------------

function ns.SetLocked(locked)
	if not locked and InCombatLockdown() then
		ns.Print(ns.L.IN_COMBAT)
		return
	end
	ns.locked = locked
	for key, holder in pairs(ns.holders) do
		if not movers[key] then movers[key] = CreateMover(holder) end
		local m = movers[key]
		if locked and m.dragging then StopDrag(m) end
		m:SetShown(not locked)
		if locked then m:EnableKeyboard(false) end
		if holder.OnUnlock then holder:OnUnlock(not locked) end
	end

	BuildGrid()
	grid:SetShown(not locked)
	BuildToolbar():SetShown(not locked)
	if not locked then toolbar.Refresh() end

	if ns.UnitFrames and ns.UnitFrames.frames.Player then ns.UnitFrames:UpdateFade() end
	if ns.Config and ns.Config.Refresh then ns.Config:Refresh() end
end

function ns.ResetPositions()
	if InCombatLockdown() then ns.Print(ns.L.IN_COMBAT) return end
	wipe(ns.db.positions)
	for _, holder in pairs(ns.holders) do ns.PlaceHolder(holder) end
end
