local _, ns = ...

local TT = ns.RegisterModule("Tooltip", { dbKey = "tooltip" })

local IsSecret = ns.IsSecret
local styled = setmetatable({}, { __mode = "k" })

local function ResetBorder(tt)
	local p = styled[tt]
	if p then p:SetBorderColor(0, 0, 0, 1) end
end

local function Style(tt)
	if not tt or styled[tt] then return end
	if tt.NineSlice then tt.NineSlice:SetAlpha(0) end
	local p = ns.CreatePanel(tt, { 0.05, 0.052, 0.062, 0.94 })
	styled[tt] = p
	tt:HookScript("OnTooltipCleared", ResetBorder)
end

local function StyleStatusBar()
	local bar = GameTooltipStatusBar or (GameTooltip and GameTooltip.StatusBar)
	if not bar then return end
	bar:SetStatusBarTexture(ns.TEXTURE)
	bar:SetHeight(4)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -2)
	bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -2)
	if not bar.novaPanel then
		ns.CreatePanel(bar, { 0.05, 0.05, 0.06, 0.9 }, true)
	end
end

local function OnUnit(tt)
	local p = styled[tt]
	if not p or not tt.GetUnit then return end
	local _, unit = tt:GetUnit()
	if IsSecret(unit) or not unit then return end

	local r, g, b
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		if not IsSecret(class) and class then r, g, b = ns.ClassColor(class) end
	else
		local reaction = UnitReaction(unit, "player")
		if ns.Plain(reaction) and ns.colors.reaction[reaction] then
			r, g, b = unpack(ns.colors.reaction[reaction])
		end
	end
	if not r then return end

	local name = _G[tt:GetName() .. "TextLeft1"]
	if name then name:SetTextColor(r, g, b) end
	p:SetBorderColor(r * 0.8, g * 0.8, b * 0.8, 1)

	local bar = GameTooltipStatusBar
	if bar and tt == GameTooltip then bar:SetStatusBarColor(r, g, b) end
end

local function OnItem(tt)
	local p = styled[tt]
	if not p or not ns.db.tooltip.qualityBorder or not tt.GetItem then return end
	local _, link = tt:GetItem()
	if not link or IsSecret(link) then return end
	local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
	if not ns.Plain(quality) or quality < 2 then return end
	local r, g, b = C_Item.GetItemQualityColor(quality)
	if r then p:SetBorderColor(r, g, b, 1) end
end

function TT:Init()
	for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
		"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip" }) do
		local tt = _G[name]
		if tt and not tt.IsEmbedded then Style(tt) end
	end
	StyleStatusBar()

	-- Blizzard re-applies its nine-slice whenever a style is set.
	if SharedTooltip_SetBackdropStyle then
		hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tt)
			if styled[tt] and tt.NineSlice then tt.NineSlice:SetAlpha(0) end
		end)
	end

	if TooltipDataProcessor and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
			pcall(OnUnit, tt)
		end)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
			pcall(OnItem, tt)
		end)
	end

	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
		if ns.db.tooltip.cursor and parent then
			tt:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 24, 6)
		end
	end)
end
