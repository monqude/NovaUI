local _, ns = ...

-- Modern look for Blizzard's nameplates. The plates themselves stay
-- Blizzard's, so everything the engine computes from secret data — threat
-- colors, raid markers, auras, cast types — keeps working; only the art is
-- replaced: flat bar, crisp 1px border, white target ring, outlined text and
-- a health percent readout. Forbidden plates (e.g. friendly ones in
-- instances) are left untouched, as addons may not modify them.
local NP = ns.RegisterModule("Nameplates", { dbKey = "nameplates" })
ns.Nameplates = NP

local styled = setmetatable({}, { __mode = "k" })

-- Sizes come straight from the settings (names, bar text, cast text), so long
-- names can be made to fit.
local function SetFace(fs, size)
	if not fs or not fs.SetFont then return end
	fs:SetFont(ns.db.font, size, ns.db.nameplates.outline and "OUTLINE" or "")
	if ns.db.nameplates.outline then
		fs:SetShadowOffset(0, 0)
	else
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	end
end

---------------------------------------------------------------------------
-- Health bar
---------------------------------------------------------------------------

local function ApplyHealth(uf)
	local hb = uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar
	if not hb then return end

	hb:SetStatusBarTexture(ns.TEXTURE)

	local bg = hb.bgTexture
	if bg then
		bg:SetTexture(ns.TEXTURE)
		bg:SetTexCoord(0, 1, 0, 1)
		if bg.SetTextureSliceMargins then pcall(bg.SetTextureSliceMargins, bg, 0, 0, 0, 0) end
		bg:SetVertexColor(0.035, 0.037, 0.045, 0.92)
		bg:SetDrawLayer("BACKGROUND", -1)
		bg:ClearAllPoints()
		bg:SetPoint("TOPLEFT", hb, "TOPLEFT", -1, 1)
		bg:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 1, -1)
	end

	-- Shown by Blizzard only on the current target: a clean white ring.
	local sel = hb.selectedBorder
	if sel then
		sel:SetTexture(ns.TEXTURE)
		sel:SetTexCoord(0, 1, 0, 1)
		if sel.SetTextureSliceMargins then pcall(sel.SetTextureSliceMargins, sel, 0, 0, 0, 0) end
		sel:SetVertexColor(1, 1, 1, 0.95)
		sel:SetDrawLayer("BACKGROUND", -2)
		sel:ClearAllPoints()
		sel:SetPoint("TOPLEFT", hb, "TOPLEFT", -2, 2)
		sel:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 2, -2)
	end

	SetFace(uf.name, ns.db.nameplates.nameSize)
	SetFace(hb.Text, ns.db.nameplates.textSize)
	SetFace(hb.LeftText, ns.db.nameplates.textSize)
	SetFace(hb.RightText, ns.db.nameplates.textSize)
	if uf.LevelFrame and uf.LevelFrame.LevelText then SetFace(uf.LevelFrame.LevelText, ns.db.nameplates.textSize) end
	if uf.novaPct then SetFace(uf.novaPct, ns.db.nameplates.textSize) end
end

local function DecorateHealth(uf)
	local hb = uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar
	if not hb or hb.novaGloss then return end

	-- Soft top-light gradient over the fill.
	local gloss = hb:CreateTexture(nil, "ARTWORK", nil, 7)
	gloss:SetTexture(ns.TEXTURE)
	gloss:SetAllPoints(hb:GetStatusBarTexture())
	if gloss.SetGradient and CreateColor then
		gloss:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.25), CreateColor(1, 1, 1, 0.08))
	else
		gloss:SetAlpha(0)
	end
	hb.novaGloss = gloss

	local layer = CreateFrame("Frame", nil, hb)
	layer:SetAllPoints()
	layer:SetFrameLevel(hb:GetFrameLevel() + 5)
	local pct = layer:CreateFontString(nil, "OVERLAY")
	pct:SetFont(ns.db.font, 9, "OUTLINE")
	pct:SetPoint("RIGHT", hb, "RIGHT", -3, 0)
	pct:SetJustifyH("RIGHT")
	uf.novaPct = pct

	-- Execute range: red wash over the bar, alpha driven by a health curve.
	local exec = hb:CreateTexture(nil, "ARTWORK", nil, 6)
	exec:SetTexture(ns.TEXTURE)
	exec:SetAllPoints(hb)
	exec:SetBlendMode("ADD")
	exec:SetVertexColor(1, 0.1, 0.1, 1)
	exec:SetAlpha(0)
	uf.novaExec = exec

	-- Quest mob marker.
	local quest = layer:CreateTexture(nil, "OVERLAY")
	quest:SetSize(14, 14)
	quest:SetPoint("RIGHT", hb, "LEFT", -3, 0)
	if not pcall(quest.SetAtlas, quest, "QuestNormal") then
		quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
	end
	quest:Hide()
	uf.novaQuest = quest

	-- Target arrows on both sides.
	local function arrow(glyph, point, rel, x)
		local a = layer:CreateFontString(nil, "OVERLAY")
		a:SetFont(ns.db.font, 16, "OUTLINE")
		a:SetText(glyph)
		a:SetTextColor(unpack(ns.db.accent))
		a:SetPoint(point, hb, rel, x, 0)
		a:Hide()
		return a
	end
	uf.novaArrowL = arrow("▶", "RIGHT", "LEFT", -18)
	uf.novaArrowR = arrow("◀", "LEFT", "RIGHT", 6)
end

local execCurve
local function ExecCurve()
	if execCurve or not (C_CurveUtil and C_CurveUtil.CreateCurve) then return execCurve end
	local t = ns.db.nameplates.executePct / 100
	execCurve = C_CurveUtil.CreateCurve()
	execCurve:AddPoint(0, 0.45)
	execCurve:AddPoint(t, 0.45)
	execCurve:AddPoint(math.min(1, t + 0.002), 0)
	execCurve:AddPoint(1, 0)
	return execCurve
end

local function UpdateExecute(uf, unit)
	local exec = uf.novaExec
	if not exec then return end
	if not ns.db.nameplates.execute or not unit or not UnitCanAttack("player", unit) then
		exec:SetAlpha(0)
		return
	end
	local curve = ExecCurve()
	if not curve or not pcall(function() exec:SetAlpha(UnitHealthPercent(unit, true, curve)) end) then
		exec:SetAlpha(0)
	end
end

local function UpdateQuest(uf, unit)
	local q = uf.novaQuest
	if not q then return end
	local show = false
	if ns.db.nameplates.quest and unit and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
		local ok, rel = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
		show = ok and not ns.IsSecret(rel) and rel == true
	end
	q:SetShown(show)
end

local function UpdateArrows()
	local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local uf = plate.UnitFrame
		if uf and uf.novaArrowL then
			local on = ns.db.nameplates.arrows and plate == targetPlate
			uf.novaArrowL:SetShown(on)
			uf.novaArrowR:SetShown(on)
		end
	end
end

---------------------------------------------------------------------------
-- Cast bar (Blizzard's colored fill is kept: it encodes the cast type,
-- which may be secret)
---------------------------------------------------------------------------

local function ApplyCast(cb)
	if cb.Background then
		cb.Background:SetTexture(ns.TEXTURE)
		cb.Background:SetVertexColor(0.035, 0.037, 0.045, 0.9)
	end
	if cb.Border then cb.Border:SetAlpha(0) end
	if cb.Icon then cb.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	SetFace(cb.Text, ns.db.nameplates.castSize)
	SetFace(cb.CastTargetNameText, ns.db.nameplates.castSize)
	if cb.Spark then cb.Spark:SetAlpha(0.8) end
end

local function DecorateCast(cb)
	if cb.novaFrame then return end
	local f = CreateFrame("Frame", nil, cb)
	f:SetPoint("TOPLEFT", -1, 1)
	f:SetPoint("BOTTOMRIGHT", 1, -1)
	f:SetFrameLevel(cb:GetFrameLevel() + 2)
	ns.CreatePanel(f, { 0, 0, 0, 0 }, true)
	cb.novaFrame = f
end

---------------------------------------------------------------------------
-- Per unit frame (frames are pooled, so each is set up once)
---------------------------------------------------------------------------

local function UpdatePercent(uf, unit)
	local pct = uf.novaPct
	if not pct then return end
	if not ns.db.nameplates.percent or not unit then
		pct:SetText("")
		return
	end
	ns.SetHealthText(pct, unit, "percent")
end

local function Setup(uf)
	if styled[uf] then return end
	styled[uf] = true
	DecorateHealth(uf)
	ApplyHealth(uf)
	if uf.UpdateAnchors then hooksecurefunc(uf, "UpdateAnchors", ApplyHealth) end
	if uf.ApplyFrameOptions then hooksecurefunc(uf, "ApplyFrameOptions", ApplyHealth) end

	local cb = uf.CastBarsContainer and uf.CastBarsContainer.castBar
	if cb then
		DecorateCast(cb)
		ApplyCast(cb)
		if cb.ApplyStyleAndAnchoring then hooksecurefunc(cb, "ApplyStyleAndAnchoring", ApplyCast) end
	end
end

function NP:OnAdded(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	local uf = plate and plate.UnitFrame
	if not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
	pcall(Setup, uf)
	pcall(ApplyHealth, uf)
	UpdatePercent(uf, unit)
	UpdateExecute(uf, unit)
	UpdateQuest(uf, unit)
	UpdateArrows()
end

function NP:Refresh()
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local uf = plate.UnitFrame
		if uf and styled[uf] then
			pcall(ApplyHealth, uf)
			local cb = uf.CastBarsContainer and uf.CastBarsContainer.castBar
			if cb then pcall(ApplyCast, cb) end
			UpdatePercent(uf, plate.namePlateUnitToken or (uf.unit))
			UpdateExecute(uf, plate.namePlateUnitToken)
			UpdateQuest(uf, plate.namePlateUnitToken)
		end
	end
end

function NP:Init()
	if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end

	-- Plates already on screen (e.g. after /reload).
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local unit = plate.namePlateUnitToken
		if unit then self:OnAdded(unit) end
	end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	ev:RegisterEvent("UNIT_HEALTH")
	ev:RegisterEvent("UNIT_MAXHEALTH")
	ev:SetScript("OnEvent", function(_, event, unit)
		if type(unit) ~= "string" or not unit:find("^nameplate") then return end
		if event == "NAME_PLATE_UNIT_ADDED" then
			NP:OnAdded(unit)
			return
		end
		local plate = C_NamePlate.GetNamePlateForUnit(unit)
		local uf = plate and plate.UnitFrame
		if uf and styled[uf] then
			UpdatePercent(uf, unit)
			UpdateExecute(uf, unit)
		end
	end)

	local ev2 = CreateFrame("Frame")
	ev2:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev2:RegisterEvent("QUEST_LOG_UPDATE")
	ev2:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
	ev2:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_TARGET_CHANGED" then UpdateArrows() return end
		for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
			if plate.UnitFrame and styled[plate.UnitFrame] then UpdateQuest(plate.UnitFrame, plate.namePlateUnitToken) end
		end
	end)
end
