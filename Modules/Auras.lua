local _, ns = ...
local L = ns.L

-- Player buffs/debuffs: Blizzard's own frames, restyled (right-click cancel,
-- weapon enchants and Edit Mode positioning keep working).
-- Target auras: Forever's CustomAuraContainer, the engine's secure aura
-- display for addons, so they keep working in combat when aura data is secret.
local A = ns.RegisterModule("Auras", { dbKey = "auras" })
ns.Auras = A

local skinned = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------------
-- Player buff frame skin
---------------------------------------------------------------------------

local function StyleDuration(fs)
	ns.SetFont(fs, 10, "OUTLINE")
	fs:SetTextColor(0.9, 0.92, 0.95)
end

local function SkinAuraButton(button)
	-- The aura list also holds private-aura anchors whose "Icon" is a Frame,
	-- not a Texture; those are drawn by the engine and must be left alone.
	if skinned[button] or not button.Icon or not button.Icon.SetTexCoord then return end
	skinned[button] = true

	local icon = button.Icon
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Border frame hugging the icon.
	local holder = CreateFrame("Frame", nil, button)
	holder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	holder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	holder:SetFrameLevel(button:GetFrameLevel())
	ns.CreatePanel(holder, { 0, 0, 0, 0 })

	-- Debuff-type border: keep Blizzard's colored atlas but fit it to the icon.
	if button.DebuffBorder then
		button.DebuffBorder:ClearAllPoints()
		button.DebuffBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
		button.DebuffBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
	end
	if button.TempEnchantBorder then
		button.TempEnchantBorder:ClearAllPoints()
		button.TempEnchantBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
		button.TempEnchantBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
		button.TempEnchantBorder:SetVertexColor(0.7, 0.35, 1)
	end

	if button.Duration then
		StyleDuration(button.Duration)
		hooksecurefunc(button.Duration, "SetFontObject", StyleDuration)
	end
	if button.Count then
		ns.SetFont(button.Count, 12, "OUTLINE")
		button.Count:ClearAllPoints()
		button.Count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 1)
	end
end

local function SkinAuraFrame(frame)
	if not frame or not frame.auraFrames then return end
	for _, button in ipairs(frame.auraFrames) do SkinAuraButton(button) end
end

function A:SkinPlayer()
	SkinAuraFrame(BuffFrame)
	SkinAuraFrame(DebuffFrame)
	-- Blizzard may add frames later (consolidation, edit mode changes).
	for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
		if frame and frame.UpdateAuraButtons then
			hooksecurefunc(frame, "UpdateAuraButtons", SkinAuraFrame)
		end
	end
	if BuffFrame and BuffFrame.CollapseAndExpandButton then
		BuffFrame.CollapseAndExpandButton:SetAlpha(0.5)
	end
end

---------------------------------------------------------------------------
-- Target auras
---------------------------------------------------------------------------

local DISPEL_COLORS = {
	None    = { 0.75, 0.15, 0.15 },
	Magic   = { 0.2, 0.6, 1.0 },
	Curse   = { 0.6, 0.0, 1.0 },
	Disease = { 0.6, 0.4, 0.0 },
	Poison  = { 0.0, 0.6, 0.0 },
}

local function InitAuraButton(button, isDebuff)
	local size = ns.db.auras.targetSize
	button:SetSize(size, size)

	-- Border texture recolored by dispel type (debuffs) or black (buffs).
	local border = button:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(ns.TEXTURE)
	border:SetAllPoints()
	border:SetVertexColor(0, 0, 0, 1)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button:SetIcon(icon)

	local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cd:SetAllPoints(icon)
	cd:SetDrawEdge(false)
	cd:SetReverse(true)
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
	pcall(button.SetDurationCooldown, button, cd)

	local textLayer = CreateFrame("Frame", nil, button)
	textLayer:SetAllPoints()
	textLayer:SetFrameLevel(cd:GetFrameLevel() + 2)

	local count = textLayer:CreateFontString(nil, "OVERLAY")
	ns.SetFont(count, math.max(9, math.floor(size * 0.42)), "OUTLINE")
	count:SetPoint("BOTTOMRIGHT", 1, 0)
	pcall(button.SetApplicationCount, button, count)

	local duration = textLayer:CreateFontString(nil, "OVERLAY")
	ns.SetFont(duration, math.max(8, math.floor(size * 0.38)), "OUTLINE")
	duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
	pcall(button.SetDurationText, button, duration)

	if isDebuff then
		local map = {}
		for k, c in pairs(DISPEL_COLORS) do map[k] = CreateColor(c[1], c[2], c[3]) end
		local style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3
		pcall(button.AddDispelTypeTexture, button, border, {
			style = style,
			showWhenHarmful = true,
			showWithoutDispelType = true,
			customDispelColorMap = map,
		})
	end
end

function A:BuildTarget()
	local db = ns.db.auras
	local width = db.targetPerRow * (db.targetSize + 3)
	local holder = ns.CreateHolder("TargetAuras", width, db.targetSize * 2 + 14, L.TARGET_AURAS)

	local ok, container = pcall(CreateFrame, "AuraContainer", "NovaUI_TargetAuras", holder, "CustomAuraContainerTemplate")
	if not ok or not container then return end
	self.container = container

	local ok2, err = pcall(function()
		container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT")
		container:SetUnit("target")
		if AnchorUtil and AnchorUtil.FlowDirection then
			container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
			container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
		end
		container:SetFlowLayoutMaximumLineSize(width)

		local layout = {
			elementWidth = db.targetSize, elementHeight = db.targetSize,
			elementSpacing = 3, lineSpacing = 12,
		}
		local debuffFilter = db.onlyMine and "HARMFUL|PLAYER" or "HARMFUL"
		container:AddAuraGroup("debuffs", debuffFilter, {
			maxFrameCount = db.targetPerRow * 2,
			initializeFrame = function(button) InitAuraButton(button, true) end,
			layout = layout,
		})
		container:AddAuraGroup("buffs", "HELPFUL", {
			maxFrameCount = db.targetPerRow,
			initializeFrame = function(button) InitAuraButton(button, false) end,
			layout = { elementWidth = db.targetSize, elementHeight = db.targetSize,
				elementSpacing = 3, lineSpacing = 12, forceNewLine = true },
		})
	end)
	if not ok2 then
		geterrorhandler()("NovaUI target auras: " .. tostring(err))
		return
	end

	-- The container only listens to UNIT_AURA for "target"; switching targets
	-- fires no aura event, so the old target's auras would stay on screen.
	-- Rebuild on every target change and hide the area while there is none.
	local function Refresh()
		holder:SetShown(UnitExists("target") or not ns.locked)
		pcall(container.UpdateAllAuras, container)
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", Refresh)
	holder.OnUnlock = Refresh
	Refresh()
end

-- My own short buffs & procs (seals, Slice and Dice, shields, Clearcasting...):
-- everything I cast on myself lasting 2 minutes or less, with timers.
function A:BuildPlayerShort()
	local db = ns.db.auras
	local width = db.targetPerRow * (db.targetSize + 3)
	local holder = ns.CreateHolder("PlayerBuffs", width, db.targetSize + 14, L.MY_BUFFS)
	local ok, container = pcall(CreateFrame, "AuraContainer", "NovaUI_PlayerShortBuffs", holder, "CustomAuraContainerTemplate")
	if not ok or not container then return end
	local ok2, err = pcall(function()
		container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT")
		container:SetUnit("player")
		if AnchorUtil and AnchorUtil.FlowDirection then
			container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
			container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
		end
		container:SetFlowLayoutMaximumLineSize(width)
		container:AddAuraGroup("short", "HELPFUL|PLAYER", {
			maxFrameCount = db.targetPerRow,
			candidateFilters = { maxDuration = 120 },
			initializeFrame = function(button) InitAuraButton(button, false) end,
			layout = { elementWidth = db.targetSize, elementHeight = db.targetSize, elementSpacing = 3, lineSpacing = 12 },
		})
	end)
	if not ok2 then geterrorhandler()("NovaUI my buffs: " .. tostring(err)) end
end

function A:Init()
	local db = ns.db.auras
	if db.playerShort then self:BuildPlayerShort() end
	if db.skinPlayer then self:SkinPlayer() end
	if db.target and ns.db.unitframes.enabled then self:BuildTarget() end
end
