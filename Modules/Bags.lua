local _, ns = ...
local L = ns.L

-- One clean inventory window. Item buttons use Blizzard's own
-- ContainerFrameItemButtonTemplate, so using, dragging, selling, splitting and
-- tooltips behave exactly like the default bags.
local B = ns.RegisterModule("Bags", { dbKey = "bags" })
ns.Bags = B

local BACKPACK = Enum.BagIndex and Enum.BagIndex.Backpack or 0
local NUM_BAGS = NUM_BAG_SLOTS or 4
local REAGENT = Enum.BagIndex and Enum.BagIndex.ReagentBag

local function PlayerBags()
	local bags = {}
	for bag = BACKPACK, NUM_BAGS do bags[#bags + 1] = bag end
	if REAGENT and C_Container.GetContainerNumSlots(REAGENT) > 0 then bags[#bags + 1] = REAGENT end
	return bags
end

local function IsPlayerBag(id)
	if not id then return false end
	return (id >= BACKPACK and id <= NUM_BAGS) or (REAGENT ~= nil and id == REAGENT)
end

B.bagFrames = {}
B.buttons = {}

---------------------------------------------------------------------------
-- Item buttons
---------------------------------------------------------------------------

local function SkinItemButton(button)
	ns.CreatePanel(button, { 0.04, 0.04, 0.05, 0.85 }, true)
	local icon = button.icon or button.Icon
	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	local normal = button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	if button.IconBorder then button.IconBorder:SetAlpha(0) end
	if button.ItemSlotBackground then button.ItemSlotBackground:SetAlpha(0) end
	local hl = button:GetHighlightTexture()
	if hl then
		hl:SetTexture(ns.TEXTURE)
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:SetBlendMode("ADD")
		hl:ClearAllPoints()
		hl:SetPoint("TOPLEFT", 1, -1)
		hl:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	local pushed = button:GetPushedTexture()
	if pushed then
		pushed:SetTexture(ns.TEXTURE)
		pushed:SetVertexColor(1, 1, 1, 0.18)
		pushed:SetAllPoints(icon)
	end
	if button.Count then
		ns.SetFont(button.Count, 12, "OUTLINE")
		button.Count:ClearAllPoints()
		button.Count:SetPoint("BOTTOMRIGHT", -2, 2)
	end
	for _, key in ipairs({ "NewItemTexture", "BattlepayItemTexture", "IconQuestTexture", "searchOverlay", "ItemContextOverlay" }) do
		local r = button[key]
		if r and r.ClearAllPoints then
			r:ClearAllPoints()
			r:SetAllPoints(icon)
		end
	end
	if button.cooldown or button.Cooldown then
		local cd = button.cooldown or button.Cooldown
		cd:ClearAllPoints()
		cd:SetAllPoints(icon)
	end
end

local function GetButton(bag, slot)
	B.buttons[bag] = B.buttons[bag] or {}
	local b = B.buttons[bag][slot]
	if b then return b end
	local parent = B.bagFrames[bag]
	local name = ("NovaUI_Bag%dSlot%d"):format(bag < 0 and 100 - bag or bag, slot)
	b = CreateFrame("ItemButton", name, parent, "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	SkinItemButton(b)
	B.buttons[bag][slot] = b
	return b
end

local function Call(button, method, ...)
	local fn = button[method]
	if fn then pcall(fn, button, ...) end
end

function B:UpdateButton(button, bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local texture = info and info.iconFileID
	local quality = info and info.quality
	local link = info and info.hyperlink

	if ClearItemButtonOverlay then ClearItemButtonOverlay(button) end
	Call(button, "SetHasItem", texture)
	Call(button, "SetItemButtonTexture", texture)
	if SetItemButtonQuality then SetItemButtonQuality(button, quality, link, false, info and info.isBound) end
	SetItemButtonCount(button, info and info.stackCount)
	SetItemButtonDesaturated(button, info and info.isLocked)

	local q = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
	if q then Call(button, "UpdateQuestItem", q.isQuestItem, q.questID, q.isActive) end
	Call(button, "UpdateNewItem", quality)
	Call(button, "UpdateJunkItem", quality, info and info.hasNoValue)
	Call(button, "UpdateCooldown", texture)
	Call(button, "SetReadable", info and info.isReadable)
	if button.IconBorder then button.IconBorder:SetAlpha(0) end

	-- Quality-colored frame; quest items get gold.
	local p = button.novaPanel
	if q and (q.isQuestItem or q.questID) then
		p:SetBorderColor(1, 0.82, 0.2, 1)
	elseif quality and quality >= 2 and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		p:SetBorderColor(r, g, b, 1)
	else
		p:SetBorderColor(0, 0, 0, 1)
	end

	-- Search highlighting.
	local query = self.query
	if query and query ~= "" then
		local match = false
		if link then
			local name = C_Item.GetItemNameByID and info.itemID and C_Item.GetItemNameByID(info.itemID)
			name = name or link
			match = name:lower():find(query, 1, true) ~= nil
		end
		button:SetAlpha(match and 1 or 0.2)
	else
		button:SetAlpha(1)
	end
	return texture ~= nil
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

function B:Update()
	local f = self.frame
	if not f or not f:IsShown() then return end
	local db = ns.db.bags
	local size, spacing, cols = db.size, db.spacing, db.columns
	local index, used, total = 0, 0, 0

	for _, bag in ipairs(PlayerBags()) do
		if not self.bagFrames[bag] then
			local bf = CreateFrame("Frame", nil, f.content)
			bf:SetID(bag)
			bf:SetAllPoints()
			self.bagFrames[bag] = bf
		end
		local slots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, slots do
			local b = GetButton(bag, slot)
			local col = index % cols
			local row = math.floor(index / cols)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f.content, "TOPLEFT", col * (size + spacing), -row * (size + spacing))
			b:SetSize(size, size)
			b:Show()
			if self:UpdateButton(b, bag, slot) then used = used + 1 end
			index = index + 1
			total = total + 1
		end
		-- Hide buttons left over from a smaller bag.
		for slot, b in pairs(self.buttons[bag] or {}) do
			if slot > slots then b:Hide() end
		end
	end

	local rows = math.max(1, math.ceil(index / cols))
	local w = cols * size + (cols - 1) * spacing
	local h = rows * size + (rows - 1) * spacing
	f.content:SetSize(w, h)
	f:SetSize(w + 24, h + 96)

	f.slots:SetFormattedText("%d / %d", used, total)
	local free = total - used
	f.slots:SetTextColor(free <= 2 and 1 or 0.75, free <= 2 and 0.35 or 0.78, free <= 2 and 0.35 or 0.82)
	f.money:SetText(GetMoneyString(GetMoney(), true))
	self:UpdateBagSlots()
end

function B:UpdateLocks(bag, slot)
	local b = self.buttons[bag] and self.buttons[bag][slot]
	if b then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		SetItemButtonDesaturated(b, info and info.isLocked)
	end
end

function B:UpdateCooldowns()
	for bag, list in pairs(self.buttons) do
		for slot, b in pairs(list) do
			if b:IsShown() then Call(b, "UpdateCooldown", C_Container.HasContainerItem(bag, slot)) end
		end
	end
end

---------------------------------------------------------------------------
-- Equipped bag slots (drag a bag here to equip it)
---------------------------------------------------------------------------

local function CreateBagSlot(parent, bag)
	local s = CreateFrame("Button", nil, parent)
	s:SetSize(22, 22)
	s.bag = bag
	s.invID = C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bag)
	ns.CreatePanel(s, { 0.04, 0.04, 0.05, 0.9 }, true)
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetPoint("TOPLEFT", 1, -1)
	s.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	s:RegisterForDrag("LeftButton")
	s:RegisterForClicks("AnyUp")
	s:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if self.invID and not GameTooltip:SetInventoryItem("player", self.invID) then
			GameTooltip:SetText(EQUIP_CONTAINER or L.MM_BAGS, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	s:SetScript("OnLeave", GameTooltip_Hide)
	local function put(self)
		if self.invID then PutItemInBag(self.invID) end
	end
	s:SetScript("OnReceiveDrag", put)
	s:SetScript("OnClick", function(self)
		if CursorHasItem() then put(self) elseif self.invID then PickupBagFromSlot(self.invID) end
	end)
	s:SetScript("OnDragStart", function(self) if self.invID then PickupBagFromSlot(self.invID) end end)
	return s
end

function B:UpdateBagSlots()
	for _, s in ipairs(self.frame.bagSlots) do
		local tex = s.invID and GetInventoryItemTexture("player", s.invID)
		s.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
		s.icon:SetDesaturated(tex == nil)
	end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function SmallButton(parent, label, onClick, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(22, 22)
	local p = ns.CreatePanel(b, { 0.1, 0.105, 0.125, 1 }, true)
	b.text = ns.CreateText(b, 12)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetScript("OnEnter", function(self)
		p:SetBorderColor(unpack(ns.db.accent))
		if tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function() p:SetBorderColor(0, 0, 0, 1) GameTooltip:Hide() end)
	b:SetScript("OnClick", onClick)
	return b
end

function B:Build()
	local f = CreateFrame("Frame", "NovaUI_Bags", UIParent)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		ns.db.bags.pos = { point, relPoint, x, y }
	end)
	local pos = ns.db.bags.pos
	if pos then
		f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 60)
	end
	f:Hide()
	ns.CreatePanel(f, { 0.045, 0.047, 0.056, 0.96 })
	tinsert(UISpecialFrames, "NovaUI_Bags")

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetTexture(ns.TEXTURE)
	line:SetPoint("TOPLEFT", 1, -1)
	line:SetPoint("TOPRIGHT", -1, -1)
	line:SetHeight(2)
	line:SetVertexColor(unpack(ns.db.accent))

	local title = ns.CreateText(f, 14)
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetText(L.MM_BAGS)

	f.slots = ns.CreateText(f, 11)
	f.slots:SetPoint("LEFT", title, "RIGHT", 10, 0)

	local close = SmallButton(f, "×", function() B:Close() end)
	close:SetPoint("TOPRIGHT", -8, -8)
	local sort = SmallButton(f, "", function()
		PlaySound(SOUNDKIT.UI_BAG_SORTING_01 or 1)
		C_Container.SortBags()
	end, L.BAG_SORT)
	sort:SetPoint("RIGHT", close, "LEFT", -4, 0)
	local sortIcon = sort:CreateTexture(nil, "ARTWORK")
	sortIcon:SetPoint("TOPLEFT", 3, -3)
	sortIcon:SetPoint("BOTTOMRIGHT", -3, 3)
	if not pcall(sortIcon.SetAtlas, sortIcon, "bags-button-autosort-up") then
		sortIcon:SetTexture("Interface\\Icons\\INV_Pet_Broom")
		sortIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	-- Search.
	local search = CreateFrame("EditBox", nil, f)
	search:SetHeight(22)
	search:SetPoint("TOPLEFT", 12, -36)
	search:SetPoint("TOPRIGHT", -12, -36)
	search:SetAutoFocus(false)
	search:SetTextInsets(8, 8, 0, 0)
	search:SetFontObject(ChatFontNormal)
	ns.SetFont(search, 12)
	ns.CreatePanel(search, { 0.03, 0.03, 0.035, 1 }, true)
	local hint = ns.CreateText(search, 12)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(L.BAG_SEARCH)
	hint:SetTextColor(0.45, 0.47, 0.5)
	search:SetScript("OnTextChanged", function(self)
		local t = self:GetText()
		hint:SetShown(t == "")
		B.query = t:lower()
		B:Update()
	end)
	search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.search = search

	f.content = CreateFrame("Frame", nil, f)
	f.content:SetPoint("TOPLEFT", 12, -66)

	-- Footer: bag slots on the left, money on the right.
	f.bagSlots = {}
	local prev
	for bag = 1, NUM_BAGS do
		local s = CreateBagSlot(f, bag)
		if prev then s:SetPoint("LEFT", prev, "RIGHT", 4, 0) else s:SetPoint("BOTTOMLEFT", 12, 10) end
		prev = s
		f.bagSlots[#f.bagSlots + 1] = s
	end
	if REAGENT and C_Container.ContainerIDToInventoryID then
		local s = CreateBagSlot(f, REAGENT)
		s:SetPoint("LEFT", prev, "RIGHT", 10, 0)
		f.bagSlots[#f.bagSlots + 1] = s
	end

	f.money = ns.CreateText(f, 12)
	f.money:SetPoint("BOTTOMRIGHT", -12, 15)

	f:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		B:Update()
	end)
	f:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		f.search:ClearFocus()
	end)

	self.frame = f
end

---------------------------------------------------------------------------
-- Replacing Blizzard's bags. Their frames keep running invisibly (parented
-- to a hidden frame), so the whole open/close logic — keybinds, merchants,
-- mail, ESC — stays Blizzard's; our window simply mirrors whether bags are open.
---------------------------------------------------------------------------

local function AnyPlayerBagOpen()
	if not IsBagOpen then return false end
	for _, bag in ipairs(PlayerBags()) do
		if IsBagOpen(bag) then return true end
	end
	return false
end

function B:Sync()
	local open = AnyPlayerBagOpen()
	if open and not self.frame:IsShown() then
		self.frame:Show()
		self.frame:Raise()
	elseif not open and self.frame:IsShown() then
		self.syncing = true
		self.frame:Hide()
		self.syncing = false
	end
end

function B:Close()
	CloseAllBags()
	self:Sync()
	if self.frame:IsShown() then
		self.syncing = true
		self.frame:Hide()
		self.syncing = false
	end
end

function B:Init()
	self:Build()

	-- If our window is closed directly (ESC), tell Blizzard too.
	self.frame:HookScript("OnHide", function()
		if not B.syncing and AnyPlayerBagOpen() then CloseAllBags() end
	end)

	-- The bag bar is replaced by the footer of this window.
	if BagsBar then BagsBar:SetParent(ns.hider) end

	if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(ns.hider) end
	if ContainerFrame_GenerateFrame then
		hooksecurefunc("ContainerFrame_GenerateFrame", function(frame, _, id)
			-- Player bags stay hidden; bank and other containers display normally.
			frame:SetParent(IsPlayerBag(id) and ns.hider or UIParent)
		end)
	end

	local function sync() B:Sync() end
	for _, fn in ipairs({ "ToggleAllBags", "OpenAllBags", "CloseAllBags", "ToggleBackpack", "OpenBackpack",
		"CloseBackpack", "ToggleBag", "OpenBag", "CloseBag" }) do
		if _G[fn] then hooksecurefunc(fn, sync) end
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
		"QUEST_ACCEPTED", "UNIT_QUEST_LOG_CHANGED", "BAG_NEW_ITEMS_UPDATED", "BAG_CONTAINER_UPDATE",
		"PLAYER_EQUIPMENT_CHANGED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event, a1, a2)
		if not B.frame:IsShown() then return end
		if event == "ITEM_LOCK_CHANGED" then
			if a2 then B:UpdateLocks(a1, a2) end
		elseif event == "BAG_UPDATE_COOLDOWN" then
			B:UpdateCooldowns()
		elseif event == "PLAYER_MONEY" then
			B.frame.money:SetText(GetMoneyString(GetMoney(), true))
		else
			B:Update()
		end
	end)
end
