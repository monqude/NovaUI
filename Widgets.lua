local _, ns = ...

-- Small flat widget kit used by the settings window.
local W = {}
ns.Widgets = W

local function Accent()
	local a = ns.db.accent
	return a[1], a[2], a[3]
end

local function Fade(tex, to)
	tex:SetAlpha(to)
end

function W.Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 140, 26)
	local panel = ns.CreatePanel(b, { 0.11, 0.115, 0.135, 1 }, true)

	b.hover = b:CreateTexture(nil, "ARTWORK")
	b.hover:SetTexture(ns.TEXTURE)
	b.hover:SetAllPoints()
	b.hover:SetVertexColor(Accent())
	b.hover:SetAlpha(0)

	b.label = ns.CreateText(b, 12)
	b.label:SetPoint("CENTER")
	b.label:SetText(text)

	b:SetScript("OnEnter", function()
		Fade(b.hover, 0.18)
		panel:SetBorderColor(Accent())
	end)
	b:SetScript("OnLeave", function()
		Fade(b.hover, 0)
		panel:SetBorderColor(0, 0, 0, 1)
	end)
	b:SetScript("OnMouseDown", function() b.label:SetPoint("CENTER", 0, -1) end)
	b:SetScript("OnMouseUp", function() b.label:SetPoint("CENTER", 0, 0) end)
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if onClick then onClick(self) end
	end)

	function b:SetText(t) self.label:SetText(t) end
	return b
end

-- Toggle switch with label. get/set are closures over the saved variable.
function W.Toggle(parent, text, get, set)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(360, 24)

	local track = CreateFrame("Frame", nil, f)
	track:SetSize(32, 16)
	track:SetPoint("LEFT")
	local tp = ns.CreatePanel(track, { 0.16, 0.17, 0.19, 1 }, true)

	local knob = track:CreateTexture(nil, "ARTWORK")
	knob:SetTexture(ns.TEXTURE)
	knob:SetSize(12, 12)

	local label = ns.CreateText(f, 12)
	label:SetPoint("LEFT", track, "RIGHT", 10, 0)
	label:SetText(text)
	label:SetTextColor(0.85, 0.86, 0.88)

	function f:Refresh()
		local on = get() and true or false
		knob:ClearAllPoints()
		if on then
			knob:SetPoint("RIGHT", -2, 0)
			knob:SetVertexColor(1, 1, 1)
			tp.bg:SetVertexColor(Accent())
		else
			knob:SetPoint("LEFT", 2, 0)
			knob:SetVertexColor(0.55, 0.57, 0.6)
			tp.bg:SetVertexColor(0.16, 0.17, 0.19, 1)
		end
	end

	f:SetScript("OnClick", function(self)
		set(not get())
		PlaySound(get() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		self:Refresh()
	end)
	f:SetScript("OnEnter", function() label:SetTextColor(1, 1, 1) end)
	f:SetScript("OnLeave", function() label:SetTextColor(0.85, 0.86, 0.88) end)

	f:Refresh()
	return f
end

function W.Slider(parent, text, minV, maxV, step, get, set, fmt)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(360, 40)

	local label = ns.CreateText(f, 12)
	label:SetPoint("TOPLEFT")
	label:SetText(text)
	label:SetTextColor(0.85, 0.86, 0.88)

	local value = ns.CreateText(f, 12)
	value:SetPoint("TOPRIGHT", f, "TOPLEFT", 260, 0)
	value:SetTextColor(Accent())

	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(260, 14)
	s:SetPoint("TOPLEFT", 0, -20)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(true)

	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(ns.TEXTURE)
	track:SetVertexColor(0.16, 0.17, 0.19, 1)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")

	local fill = s:CreateTexture(nil, "ARTWORK")
	fill:SetTexture(ns.TEXTURE)
	fill:SetVertexColor(Accent())
	fill:SetHeight(4)
	fill:SetPoint("LEFT")

	s:SetThumbTexture(ns.TEXTURE)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(10, 14)
	thumb:SetVertexColor(1, 1, 1)

	fmt = fmt or "%.2f"
	local function update(v)
		value:SetText(fmt:format(v))
		local pct = (v - minV) / (maxV - minV)
		fill:SetWidth(math.max(1, pct * s:GetWidth()))
	end

	s:SetScript("OnValueChanged", function(_, v, userInput)
		v = math.floor(v / step + 0.5) * step
		update(v)
		if userInput then set(v) end
	end)
	s:SetScript("OnMouseWheel", function(self, delta)
		local v = math.min(maxV, math.max(minV, self:GetValue() + delta * step))
		self:SetValue(v)
		set(v)
	end)

	function f:Refresh()
		s:SetValue(get())
		update(get())
	end
	f:Refresh()
	return f
end

-- Segmented selector: a row of mutually exclusive options.
function W.Segment(parent, text, options, get, set)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(360, 46)

	local label = ns.CreateText(f, 12)
	label:SetPoint("TOPLEFT")
	label:SetText(text)
	label:SetTextColor(0.85, 0.86, 0.88)

	local buttons = {}
	local x = 0
	for i, opt in ipairs(options) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(opt.width or 96, 22)
		b:SetPoint("TOPLEFT", x, -20)
		x = x + (opt.width or 96) - 1
		b.panel = ns.CreatePanel(b, { 0.11, 0.115, 0.135, 1 }, true)
		b.text = ns.CreateText(b, 11)
		b.text:SetPoint("CENTER")
		b.text:SetText(opt.label)
		b.value = opt.value
		b:SetScript("OnClick", function()
			set(opt.value)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			f:Refresh()
		end)
		buttons[i] = b
	end

	function f:Refresh()
		local cur = get()
		for _, b in ipairs(buttons) do
			if b.value == cur then
				b.panel.bg:SetVertexColor(Accent())
				b.text:SetTextColor(1, 1, 1)
			else
				b.panel.bg:SetVertexColor(0.11, 0.115, 0.135, 1)
				b.text:SetTextColor(0.65, 0.67, 0.7)
			end
		end
	end
	f:Refresh()
	return f
end

function W.Header(parent, text)
	local fs = ns.CreateText(parent, 14)
	fs:SetText(text)
	fs:SetTextColor(1, 1, 1)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(ns.TEXTURE)
	line:SetVertexColor(1, 1, 1, 0.08)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
	line:SetWidth(380)
	return fs
end

-- Live, numbered preview of an action bar grid. getCfg/getCount are closures.
function W.GridPreview(parent, getKey, getCfg, getCount)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(360, 132)
	local box = CreateFrame("Frame", nil, f)
	box:SetPoint("TOPLEFT", 0, -4)
	box:SetSize(340, 124)
	ns.CreatePanel(box, { 0.03, 0.03, 0.036, 1 }, true)
	local cells = {}
	local function cell(i)
		local c = cells[i]
		if c then return c end
		c = CreateFrame("Frame", nil, box)
		local p = ns.CreatePanel(c, { 0.13, 0.135, 0.16, 1 }, true)
		c.panel = p
		c.text = ns.CreateText(c, 10)
		c.text:SetPoint("CENTER")
		cells[i] = c
		return c
	end

	function f:Refresh()
		local AB = ns.ActionBars
		local cfg = getCfg()
		AB.Migrate(cfg)
		local n = AB.ButtonCount(getKey(), cfg, getCount())
		local grid, cols, rows = AB.Grid(cfg, n)
		-- Scale cells to fit the preview box.
		local unit = math.floor(math.min(22, (334 - 6) / math.max(cols, 1), (118 - 6) / math.max(rows, 1)))
		local size = math.max(6, unit - 3)
		local scaled = { corner = cfg.corner, spacing = unit - size, vspacing = unit - size }
		local w = cols * unit - (unit - size)
		local h = rows * unit - (unit - size)
		local r, g, b = Accent()
		for i, c in ipairs(cells) do c:Hide() end
		for i = 1, n do
			local c = cell(i)
			local x, y = ns.ActionBars.CellOffset(scaled, grid[i][1], grid[i][2], size)
			-- Place the whole grid centred in the box, then offset from its corner.
			local ox = (334 - w) / 2 + 3
			local oy = (118 - h) / 2 + 3
			local ax = cfg.corner:find("LEFT") and ox or -ox
			local ay = cfg.corner:find("TOP") and -oy or oy
			c:ClearAllPoints()
			c:SetPoint(cfg.corner, box, cfg.corner, ax + x, ay + y)
			c:SetSize(size, size)
			c.text:SetText(size >= 12 and tostring(i) or "")
			if i == 1 then
				c.panel.bg:SetVertexColor(r, g, b, 1)
			else
				c.panel.bg:SetVertexColor(0.13, 0.135, 0.16, 1)
			end
			c:Show()
		end
	end
	return f
end

-- Single-line text field.
function W.Input(parent, width, placeholder)
	local eb = CreateFrame("EditBox", nil, parent)
	eb:SetSize(width or 200, 26)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(32)
	eb:SetTextInsets(8, 8, 0, 0)
	eb:SetFontObject(ChatFontNormal)
	ns.SetFont(eb, 12)
	local p = ns.CreatePanel(eb, { 0.03, 0.03, 0.036, 1 }, true)
	local hint = ns.CreateText(eb, 12)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(placeholder or "")
	hint:SetTextColor(0.45, 0.47, 0.5)
	eb:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
	eb:SetScript("OnEditFocusGained", function() p:SetBorderColor(Accent()) end)
	eb:SetScript("OnEditFocusLost", function() p:SetBorderColor(0, 0, 0, 1) end)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return eb
end

