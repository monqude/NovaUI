local _, ns = ...

-- Export / import of the whole NovaUI setup (all settings + frame positions)
-- as one copyable text code:  "!NUI1!" + Base64( Deflate( CBOR(profile) ) )
local P = {}
ns.Profiles = P

local PREFIX = "!NUI1!"
local MAX_DEPTH = 8

local function L() return ns.L end

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------

-- Deep copy that keeps only plain data (strings, numbers, booleans, tables
-- with string/number keys). Anything else is dropped, so an import can never
-- inject functions or oversized junk into the saved variables.
local function Clean(value, depth)
	local t = type(value)
	if t == "string" then
		return #value <= 512 and value or nil
	elseif t == "number" then
		return (value == value and value ~= math.huge and value ~= -math.huge) and value or nil
	elseif t == "boolean" then
		return value
	elseif t == "table" and depth < MAX_DEPTH then
		local out = {}
		for k, v in pairs(value) do
			local kt = type(k)
			if kt == "string" or kt == "number" then
				local cv = Clean(v, depth + 1)
				if cv ~= nil then out[k] = cv end
			end
		end
		return out
	end
	return nil
end

---------------------------------------------------------------------------
-- Named profiles (account wide, in NovaUIProfiles)
---------------------------------------------------------------------------

local function Store()
	NovaUIProfiles = NovaUIProfiles or {}
	NovaUIProfiles.list = NovaUIProfiles.list or {}
	return NovaUIProfiles.list
end

function P.CurrentName()
	return ns.db.profileName or L().PROFILE_DEFAULT_NAME
end

local function ValidName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or #name > 32 then return nil end
	return name
end

-- Sorted list of { name, created, version }.
function P.List()
	local out = {}
	for name, entry in pairs(Store()) do
		out[#out + 1] = { name = name, created = entry.created, version = entry.version }
	end
	table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
	return out
end

-- Saves the current setup under a name (overwrites a profile of that name).
function P.Save(name)
	name = ValidName(name)
	if not name then return false, L().PROFILE_BAD_NAME end
	ns.db.profileName = name
	Store()[name] = { created = date("%Y-%m-%d %H:%M"), version = ns.Nova.version, data = Clean(ns.db, 0) }
	return true
end

-- Drops values whose type differs from the default (CopyDefaults then
-- restores the default), so a broken code can't break a module.
local function FixTypes(data, defaults)
	for k, def in pairs(defaults) do
		local v = data[k]
		if v ~= nil then
			if type(v) ~= type(def) then
				data[k] = nil
			elseif type(def) == "table" and def[1] == nil then
				FixTypes(v, def)
			end
		end
	end
end

local ANCHORS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function ValidPosition(pos)
	return type(pos) == "table" and ANCHORS[pos[1]] and pos[2] == "UIParent" and ANCHORS[pos[3]]
		and type(pos[4]) == "number" and type(pos[5]) == "number"
end

-- Makes a saved profile the active setup. Takes effect on reload.
local function Apply(data, name)
	data = Clean(data, 0)
	if type(data) ~= "table" then data = {} end
	FixTypes(data, ns.defaults)
	if type(data.positions) == "table" then
		for key, pos in pairs(data.positions) do
			if not ValidPosition(pos) then data.positions[key] = nil end
		end
	end
	data = ns.CopyDefaults(ns.defaults, data)
	data.unitframes.portraitIntro = true
	data.profileName = name
	-- Personal, not part of a shared layout.
	data.language, data.lastVersion = ns.db.language, ns.db.lastVersion
	wipe(NovaUIDB)
	for k, v in pairs(data) do NovaUIDB[k] = v end
	ns.db = NovaUIDB
end

function P.Load(name)
	local entry = Store()[name]
	if not entry then return false, L().PROFILE_NOT_FOUND end
	if InCombatLockdown() then return false, L().IN_COMBAT end
	Apply(entry.data, name)
	return true
end

function P.Delete(name)
	Store()[name] = nil
	return true
end

-- A free name: "Raid", "Raid (2)", ...
local function UniqueName(name)
	name = ValidName(name) or L().PROFILE_IMPORTED_NAME
	if not Store()[name] then return name end
	for i = 2, 99 do
		local candidate = ("%s (%d)"):format(name:sub(1, 27), i)
		if not Store()[candidate] then return candidate end
	end
	return name
end

---------------------------------------------------------------------------
-- Export / import codes
---------------------------------------------------------------------------

-- Exports the current setup, or a saved profile when a name is given.
function P.Export(name)
	local E = C_EncodingUtil
	if not (E and E.SerializeCBOR and E.CompressString and E.EncodeBase64) then
		return nil, L().PROFILE_UNSUPPORTED
	end
	local source = name and Store()[name]
	local payload = {
		addon = "NovaUI",
		name = name or P.CurrentName(),
		version = source and source.version or ns.Nova.version,
		created = source and source.created or date("%Y-%m-%d %H:%M"),
		data = Clean(source and source.data or ns.db, 0),
	}
	local ok, result = pcall(function()
		return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(payload)))
	end)
	if not ok then return nil, tostring(result) end
	return result
end

-- Returns the decoded profile table, or nil + a user-facing reason.
function P.Decode(text)
	local E = C_EncodingUtil
	if not (E and E.DeserializeCBOR and E.DecompressString and E.DecodeBase64) then
		return nil, L().PROFILE_UNSUPPORTED
	end
	text = (text or ""):gsub("%s+", "")
	if text == "" then return nil, L().PROFILE_EMPTY end
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, L().PROFILE_NOT_NOVA end

	local ok, payload = pcall(function()
		return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(text:sub(#PREFIX + 1))))
	end)
	if not ok or type(payload) ~= "table" then return nil, L().PROFILE_BROKEN end
	if payload.addon ~= "NovaUI" or type(payload.data) ~= "table" then return nil, L().PROFILE_NOT_NOVA end
	return payload
end

-- Saves the imported code as a named profile and makes it active.
-- Takes effect on reload.
function P.Import(text, name)
	local payload, err = P.Decode(text)
	if not payload then return false, err end
	if InCombatLockdown() then return false, L().IN_COMBAT end

	name = UniqueName(name or payload.name)
	Store()[name] = {
		created = tostring(payload.created or date("%Y-%m-%d %H:%M")),
		version = tostring(payload.version or "?"),
		data = Clean(payload.data, 0),
	}
	-- Fill anything the exporting version didn't have yet; the imported
	-- layout is deliberate, so one-time migrations must not override it.
	Apply(payload.data, name)
	return true, payload, name
end

---------------------------------------------------------------------------
-- Dialog
---------------------------------------------------------------------------

local dialog

local function BuildDialog()
	local W = ns.Widgets
	local f = CreateFrame("Frame", "NovaUI_ProfileDialog", UIParent)
	f:SetSize(560, 380)
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f:Hide()
	tinsert(UISpecialFrames, "NovaUI_ProfileDialog")
	ns.CreatePanel(f, { 0.045, 0.047, 0.056, 0.98 })

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetTexture(ns.TEXTURE)
	line:SetPoint("TOPLEFT", 1, -1)
	line:SetPoint("TOPRIGHT", -1, -1)
	line:SetHeight(2)
	line:SetVertexColor(unpack(ns.db.accent))

	f.title = ns.CreateText(f, 15)
	f.title:SetPoint("TOPLEFT", 16, -16)
	f.hint = ns.CreateText(f, 11)
	f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
	f.hint:SetPoint("RIGHT", -16, 0)
	f.hint:SetJustifyH("LEFT")
	f.hint:SetWordWrap(true)
	f.hint:SetTextColor(0.6, 0.63, 0.68)

	-- Scrollable multi-line text box.
	local box = CreateFrame("Frame", nil, f)
	box:SetPoint("TOPLEFT", 16, -64)
	f.box = box

	local nameRow = CreateFrame("Frame", nil, f)
	nameRow:SetPoint("TOPLEFT", 16, -62)
	nameRow:SetPoint("TOPRIGHT", -16, -62)
	nameRow:SetHeight(24)
	local nameLabel = ns.CreateText(nameRow, 12)
	nameLabel:SetPoint("LEFT")
	nameLabel:SetText(L().PROFILE_NAME)
	local nameBox = CreateFrame("EditBox", nil, nameRow)
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
	nameBox:SetSize(240, 22)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(32)
	nameBox:SetTextInsets(6, 6, 0, 0)
	nameBox:SetFontObject(ChatFontNormal)
	ns.SetFont(nameBox, 12)
	ns.CreatePanel(nameBox, { 0.025, 0.026, 0.03, 1 }, true)
	nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.nameRow, f.nameBox = nameRow, nameBox
	box:SetPoint("BOTTOMRIGHT", -16, 56)
	ns.CreatePanel(box, { 0.025, 0.026, 0.03, 1 }, true)

	local scroll = CreateFrame("ScrollFrame", nil, box)
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -8, 8)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 30))
		self:SetVerticalScroll(v)
	end)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(0)
	edit:SetWidth(510)
	edit:SetFontObject(ChatFontNormal)
	ns.SetFont(edit, 11)
	edit:SetTextColor(0.85, 0.88, 0.92)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
		if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, x, y, w, h) end
	end)
	edit:SetScript("OnUpdate", function(self, elapsed)
		if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, scroll) end
	end)
	scroll:SetScrollChild(edit)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() edit:SetFocus() end)
	f.edit = edit

	f.status = ns.CreateText(f, 12)
	f.status:SetPoint("BOTTOMLEFT", 16, 22)
	f.status:SetPoint("RIGHT", f, "RIGHT", -300, 0)
	f.status:SetJustifyH("LEFT")

	f.close = W.Button(f, L().CLOSE, 90, function() f:Hide() end)
	f.close:SetPoint("BOTTOMRIGHT", -16, 16)
	f.action = W.Button(f, "", 130, function() end)
	f.action:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
	f.reload = W.Button(f, L().RELOAD, 120, ReloadUI)
	f.reload:SetPoint("RIGHT", f.action, "LEFT", -8, 0)
	return f
end

local function Status(text, ok)
	dialog.status:SetText(text or "")
	if ok == nil then
		dialog.status:SetTextColor(0.6, 0.63, 0.68)
	elseif ok then
		dialog.status:SetTextColor(0.44, 0.86, 0.55)
	else
		dialog.status:SetTextColor(0.92, 0.34, 0.34)
	end
end

local function NameRow(show)
	dialog.nameRow:SetShown(show)
	dialog.box:SetPoint("TOPLEFT", 16, show and -94 or -64)
end

function P.ShowExport(name)
	dialog = dialog or BuildDialog()
	local code, err = P.Export(name)
	NameRow(false)
	dialog.title:SetText(("%s  |cff8f99a8%s|r"):format(L().PROFILE_EXPORT, name or P.CurrentName()))
	dialog.hint:SetText(L().PROFILE_EXPORT_HINT)
	dialog.reload:Hide()
	dialog.edit:SetText(code or "")
	dialog.edit:SetScript("OnTextChanged", function(self, user)
		-- Keep the export read-only: undo any typing.
		if user then self:SetText(code or "") self:HighlightText() end
	end)
	dialog.action:SetText(L().PROFILE_SELECT_ALL)
	dialog.action:SetScript("OnClick", function()
		dialog.edit:SetFocus()
		dialog.edit:HighlightText()
	end)
	if code then
		Status(L().PROFILE_EXPORT_READY:format(#code), true)
	else
		Status(err, false)
	end
	dialog:Show()
	dialog.edit:SetFocus()
	dialog.edit:HighlightText()
end

function P.ShowImport()
	dialog = dialog or BuildDialog()
	dialog.title:SetText(L().PROFILE_IMPORT)
	NameRow(true)
	dialog.nameBox:SetText("")
	dialog.hint:SetText(L().PROFILE_IMPORT_HINT)
	dialog.reload:Hide()
	dialog.edit:SetText("")
	dialog.edit:SetScript("OnTextChanged", function(self, user)
		if not user then return end
		-- Preview what the pasted code contains before importing it.
		local payload, err = P.Decode(self:GetText())
		if payload then
			Status(L().PROFILE_VALID:format(tostring(payload.version or "?"), tostring(payload.created or "?")), nil)
			-- Suggest the name stored in the code.
			if dialog.nameBox:GetText() == "" and type(payload.name) == "string" then
				dialog.nameBox:SetText(payload.name)
			end
		elseif self:GetText():gsub("%s+", "") ~= "" then
			Status(err, false)
		else
			Status("")
		end
	end)
	dialog.action:SetText(L().PROFILE_IMPORT_BUTTON)
	dialog.action:SetScript("OnClick", function()
		if InCombatLockdown() then Status(L().IN_COMBAT, false) return end
		local ok, result, savedAs = P.Import(dialog.edit:GetText(), dialog.nameBox:GetText())
		if ok then
			Status(L().PROFILE_IMPORTED:format(savedAs), true)
			if P.OnChanged then P.OnChanged() end
			dialog.reload:Show()
		else
			Status(result, false)
		end
	end)
	Status("")
	dialog:Show()
	dialog.edit:SetFocus()
end
