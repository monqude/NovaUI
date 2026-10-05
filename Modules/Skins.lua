local _, ns = ...

-- Restyles Blizzard's windows (character, spellbook, quests, merchant, mail,
-- trainers, dialogs...) in NovaUI's flat look. Almost every Forever window is
-- built from the same few templates (PortraitFrame / ButtonFrame / DefaultPanel
-- / Dialog), so one walker recognises their parts and swaps the art. Purely
-- cosmetic: only alpha, textures and fonts change, never behaviour.
local S = ns.RegisterModule("Skins", { dbKey = "skins" })
ns.Skins = S

local done = setmetatable({}, { __mode = "k" })

local function Accent() return unpack(ns.db.accent) end

local function Hide(region)
	if region and region.SetAlpha then region:SetAlpha(0) end
end

-- NineSlice frames are recognisable by their corner pieces.
local function IsNineSlice(f)
	return f and (f.TopLeftCorner or f.TopLeft) and (f.BottomRightCorner or f.BottomRight) and f.Center ~= nil
end

local function HideNineSlice(f)
	if f and f.NineSlice then Hide(f.NineSlice) end
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------

function S:Close(btn)
	if not btn or done[btn] then return end
	done[btn] = true
	for _, t in ipairs({ btn:GetNormalTexture(), btn:GetPushedTexture(), btn:GetHighlightTexture(), btn:GetDisabledTexture() }) do
		Hide(t)
	end
	local x = btn:CreateFontString(nil, "OVERLAY")
	ns.SetFont(x, 16)
	x:SetPoint("CENTER", 0, 0)
	x:SetText("×")
	x:SetTextColor(0.65, 0.67, 0.72)
	btn:HookScript("OnEnter", function() x:SetTextColor(1, 0.4, 0.4) end)
	btn:HookScript("OnLeave", function() x:SetTextColor(0.65, 0.67, 0.72) end)
end

function S:Button(btn)
	if not btn or done[btn] then return end
	done[btn] = true
	for _, key in ipairs({ "Left", "Middle", "Right", "Center", "LeftSeparator", "RightSeparator" }) do
		Hide(btn[key])
	end
	local name = btn:GetName()
	if name then
		Hide(_G[name .. "Left"]) Hide(_G[name .. "Middle"]) Hide(_G[name .. "Right"])
	end
	Hide(btn:GetNormalTexture())
	Hide(btn:GetPushedTexture())
	Hide(btn:GetDisabledTexture())

	local skin = CreateFrame("Frame", nil, btn)
	skin:SetPoint("TOPLEFT", 1, -1)
	skin:SetPoint("BOTTOMRIGHT", -1, 1)
	skin:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
	local p = ns.CreatePanel(skin, { 0.11, 0.115, 0.135, 0.95 }, true)

	local hl = btn:GetHighlightTexture()
	if hl then
		hl:SetTexture(ns.TEXTURE)
		hl:SetVertexColor(1, 1, 1, 0.07)
		hl:SetBlendMode("ADD")
		hl:ClearAllPoints()
		hl:SetAllPoints(skin)
	end
	btn:HookScript("OnEnter", function(self) if self:IsEnabled() then p:SetBorderColor(Accent()) end end)
	btn:HookScript("OnLeave", function() p:SetBorderColor(0, 0, 0, 1) end)
	local function state(self)
		p.bg:SetVertexColor(0.11, 0.115, 0.135, self:IsEnabled() and 0.95 or 0.45)
	end
	btn:HookScript("OnEnable", state)
	btn:HookScript("OnDisable", state)
	state(btn)
end

local TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
	"LeftHighlight", "MiddleHighlight", "RightHighlight", "SquareBackground", "SquareBackgroundActive",
	"SquareBackgroundActiveGlow" }

function S:Tab(tab)
	if not tab or done[tab] then return end
	done[tab] = true
	for _, key in ipairs(TAB_ART) do Hide(tab[key]) end
	for _, list in ipairs({ tab.TabTextures, tab.RotatedTextures }) do
		if type(list) == "table" then for _, t in ipairs(list) do Hide(t) end end
	end
	local hl = tab:GetHighlightTexture()
	if hl then Hide(hl) end

	local skin = CreateFrame("Frame", nil, tab)
	skin:SetPoint("TOPLEFT", 3, -3)
	skin:SetPoint("BOTTOMRIGHT", -3, 3)
	skin:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 1))
	local p = ns.CreatePanel(skin, { 0.08, 0.083, 0.098, 0.95 }, true)
	local line = skin:CreateTexture(nil, "OVERLAY")
	line:SetTexture(ns.TEXTURE)
	line:SetHeight(2)
	line:SetPoint("BOTTOMLEFT", 1, 1)
	line:SetPoint("BOTTOMRIGHT", -1, 1)
	line:SetVertexColor(Accent())

	local function update()
		local selected = (tab.LeftActive and tab.LeftActive:IsShown()) or tab.isSelected
		line:SetShown(selected and true or false)
		p.bg:SetVertexColor(selected and 0.13 or 0.08, selected and 0.135 or 0.083, selected and 0.16 or 0.098, 0.95)
		local text = tab.Text or (tab.GetFontString and tab:GetFontString())
		if text then
			if selected then text:SetTextColor(1, 1, 1) else text:SetTextColor(0.7, 0.72, 0.76) end
		end
	end
	-- Both tab systems toggle LeftActive on selection: hook that.
	if tab.LeftActive then
		hooksecurefunc(tab.LeftActive, "Show", update)
		hooksecurefunc(tab.LeftActive, "Hide", update)
		hooksecurefunc(tab.LeftActive, "SetShown", update)
	end
	if tab.SetTabSelected then hooksecurefunc(tab, "SetTabSelected", update) end
	tab:HookScript("OnShow", update)
	update()
end

function S:EditBox(eb)
	if not eb or done[eb] then return end
	done[eb] = true
	for _, key in ipairs({ "Left", "Middle", "Right", "Mid" }) do Hide(eb[key]) end
	local name = eb:GetName()
	if name then Hide(_G[name .. "Left"]) Hide(_G[name .. "Middle"]) Hide(_G[name .. "Right"]) Hide(_G[name .. "Mid"]) end
	local skin = CreateFrame("Frame", nil, eb)
	skin:SetPoint("TOPLEFT", -4, 0)
	skin:SetPoint("BOTTOMRIGHT", 0, 0)
	skin:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
	ns.CreatePanel(skin, { 0.03, 0.03, 0.036, 1 }, true)
end

-- Inner panels (insets, list backgrounds): subtle darker area, no art.
function S:Inset(f)
	if not f or done[f] then return end
	done[f] = true
	HideNineSlice(f)
	if IsNineSlice(f) then Hide(f) return end
	Hide(f.Bg)
	ns.CreatePanel(f, { 0, 0, 0, 0.22 }, true)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function Walk(frame, depth)
	if depth > 6 then return end
	local children = { frame:GetChildren() }
	for _, child in ipairs(children) do
		if not (child.IsForbidden and child:IsForbidden()) and not done[child] then
			local t = child:GetObjectType()
			if child == frame.CloseButton or (t == "Button" and child:GetNormalTexture()
				and child:GetNormalTexture():GetAtlas() == "RedButton-Exit") then
				S:Close(child)
			elseif child.TabTextures or child.RotatedTextures or (child.LeftActive and child.MiddleActive) then
				S:Tab(child)
			elseif t == "Button" and child:GetFontString() and child.Left and child.Right and (child.Middle or child.Center) then
				S:Button(child)
			elseif t == "EditBox" and (child.Left or child.Middle) and child.Right then
				S:EditBox(child)
			elseif t == "Frame" and IsNineSlice(child) then
				Hide(child)
				done[child] = true
			elseif t == "Frame" and child.NineSlice then
				S:Inset(child)
			end
			Walk(child, depth + 1)
		end
	end
end

function S:Window(frame)
	if not frame or done[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
	done[frame] = true

	HideNineSlice(frame)
	for _, key in ipairs({ "Bg", "TopTileStreaks", "PortraitContainer", "PortraitFrame", "portrait", "BG", "Border" }) do
		local r = frame[key]
		if r then
			if r.GetObjectType and r:GetObjectType() == "Frame" and IsNineSlice(r) then
				Hide(r)
			else
				Hide(r)
			end
		end
	end
	if frame.Header then
		for _, region in ipairs({ frame.Header:GetRegions() }) do
			if region:GetObjectType() == "Texture" then Hide(region) end
		end
	end
	local name = frame:GetName()
	if name then Hide(_G[name .. "Bg"]) Hide(_G[name .. "Portrait"]) end

	local p = ns.CreatePanel(frame, { 0.045, 0.047, 0.056, 0.97 })
	if not frame.novaAccent then
		local line = frame:CreateTexture(nil, "BORDER", nil, 6)
		line:SetTexture(ns.TEXTURE)
		line:SetPoint("TOPLEFT", 1, -1)
		line:SetPoint("TOPRIGHT", -1, -1)
		line:SetHeight(2)
		line:SetVertexColor(Accent())
		frame.novaAccent = line
	end

	local title = frame.TitleContainer and frame.TitleContainer.TitleText or (name and _G[name .. "TitleText"])
	if title then
		ns.SetFont(title, 13)
		title:SetTextColor(1, 1, 1)
	end

	if frame.Inset then S:Inset(frame.Inset) end
	if frame.CloseButton then S:Close(frame.CloseButton) end
	if frame.Tabs then for _, tab in ipairs(frame.Tabs) do S:Tab(tab) end end
	if name then
		for i = 1, 12 do
			local tab = _G[name .. "Tab" .. i]
			if not tab then break end
			S:Tab(tab)
		end
	end

	Walk(frame, 1)
end

-- Windows whose contents appear later (lists, pages) get a second pass.
local function SkinSoon(frame)
	S:Window(frame)
	if not frame.novaRewalk then
		frame.novaRewalk = true
		frame:HookScript("OnShow", function(self)
			C_Timer.After(0, function() Walk(self, 1) end)
		end)
	end
end

---------------------------------------------------------------------------
-- Which windows
---------------------------------------------------------------------------

S.FRAMES = {
	"CharacterFrame", "SpellBookFrame", "FriendsFrame", "MerchantFrame", "MailFrame", "OpenMailFrame",
	"GossipFrame", "QuestFrame", "QuestLogFrame", "QuestLogDetailFrame", "QuestLogPopupDetailFrame",
	"ProfessionsBookFrame", "PVEFrame", "PVPFrame", "AddonList", "DressUpFrame", "LootFrame", "BankFrame",
	"TradeFrame", "TabardFrame", "ItemTextFrame", "PetitionFrame", "GuildRegistrarFrame", "RaidParentFrame",
	"ChannelFrame", "PetStableFrame", "StableFrame", "TaxiFrame", "HelpFrame", "ModelPreviewFrame",
	"GameMenuFrame", "LegacySystemFrame", "GroupLootHistoryFrame", "MasterLooterFrame",
	-- Load-on-demand (skinned once their addon loads)
	"PlayerSpellsFrame", "ClassTrainerFrame", "CommunitiesFrame", "CollectionsJournal", "InspectFrame",
	"MacroFrame", "AuctionHouseFrame", "TimeManagerFrame", "ItemSocketingFrame", "GuildBankFrame",
	"ItemUpgradeFrame", "ItemInteractionFrame", "LFGBrowseFrame", "LFGListingFrame", "ProfessionsFrame",
	"ProfessionsCustomerOrdersFrame", "TransmogFrame", "CalendarFrame", "ArchaeologyFrame", "ClickBindingFrame",
}

function S:SkinKnown()
	for _, name in ipairs(self.FRAMES) do
		local f = _G[name]
		if f and f.GetObjectType then pcall(SkinSoon, f) end
	end
	for i = 1, 4 do
		local popup = _G["StaticPopup" .. i]
		if popup then pcall(S.Window, S, popup) end
	end
end

function S:Init()
	self:SkinKnown()

	-- Anything opened through the panel manager gets the same treatment,
	-- which also covers windows not in the list above.
	if ShowUIPanel then
		hooksecurefunc("ShowUIPanel", function(frame)
			if frame and not done[frame] and frame.GetObjectType and (frame.NineSlice or frame.PortraitContainer) then
				pcall(SkinSoon, frame)
			end
		end)
	end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("ADDON_LOADED")
	ev:SetScript("OnEvent", function(_, _, addon)
		if type(addon) == "string" and addon:find("^Blizzard_") then
			C_Timer.After(0, function() S:SkinKnown() end)
		end
	end)

	-- Breath / fatigue / feign death bars.
	local MIRROR_COLORS = {
		BREATH = { 0.25, 0.6, 1 }, EXHAUSTION = { 1, 0.6, 0.15 }, FEIGNDEATH = { 0.7, 0.7, 0.75 },
	}
	local container = MirrorTimerContainer
	if container and container.mirrorTimers then
		for _, timer in ipairs(container.mirrorTimers) do
			local bar = timer.StatusBar
			if bar then
				Hide(timer.TextBorder or bar.TextBorder)
				Hide(timer.Border or bar.Border)
				ns.CreatePanel(bar, { 0.05, 0.05, 0.06, 0.9 })
				local text = timer.Text or bar.Text
				if text then ns.SetFont(text, 11, "OUTLINE") end
				local function restyle(self, kind)
					self.StatusBar:SetStatusBarTexture(ns.TEXTURE)
					local c = MIRROR_COLORS[kind] or MIRROR_COLORS.BREATH
					self.StatusBar:SetStatusBarColor(c[1], c[2], c[3])
				end
				if timer.Setup then hooksecurefunc(timer, "Setup", restyle) end
			end
		end
	end

	-- Quest/objective tracker: drop header art, keep text.
	local tracker = ObjectiveTrackerFrame
	if tracker and tracker.Header then
		for _, region in ipairs({ tracker.Header:GetRegions() }) do
			if region:GetObjectType() == "Texture" then Hide(region) end
		end
	end
end
