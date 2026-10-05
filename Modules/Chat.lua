local _, ns = ...

-- Purely cosmetic chat restyle: flat panel, text tabs, clean edit box and
-- side buttons that only appear on hover. Chat behaviour is untouched.
local C = ns.RegisterModule("Chat", { dbKey = "chat" })
ns.Chat = C

local styled = {}

local function Kill(region)
	if type(region) ~= "table" or not region.SetAlpha then return end
	if region.SetTexture then region:SetTexture(nil) end
	region:SetAlpha(0)
end

local TAB_TEXTURES = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight" }

local function StyleTab(tab, selected)
	if not tab then return end
	for _, key in ipairs(TAB_TEXTURES) do Kill(tab[key]) end
	local text = tab.Text or (tab.GetFontString and tab:GetFontString())
	if text then
		ns.SetFont(text, 12, "")
		if selected then
			text:SetTextColor(unpack(ns.db.accent))
		else
			text:SetTextColor(0.7, 0.72, 0.76)
		end
	end
	if not tab.novaLine then
		local line = tab:CreateTexture(nil, "OVERLAY")
		line:SetTexture(ns.TEXTURE)
		line:SetHeight(2)
		line:SetPoint("BOTTOMLEFT", 10, 4)
		line:SetPoint("BOTTOMRIGHT", -10, 4)
		tab.novaLine = line
	end
	tab.novaLine:SetVertexColor(unpack(ns.db.accent))
	tab.novaLine:SetShown(selected and true or false)
end

local function UpdateTabs()
	for _, name in ipairs(CHAT_FRAMES or {}) do
		local frame = _G[name]
		local tab = _G[name .. "Tab"]
		if frame and tab then
			local selected = SELECTED_CHAT_FRAME == frame or (GeneralDockManager and FCFDock_GetSelectedWindow
				and FCFDock_GetSelectedWindow(GeneralDockManager) == frame)
			StyleTab(tab, selected)
		end
	end
end

local function StyleEditBox(frame)
	local name = frame:GetName()
	local eb = frame.editBox or _G[name .. "EditBox"]
	if not eb then return end
	for _, suffix in ipairs({ "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }) do
		Kill(_G[eb:GetName() .. suffix])
	end
	Kill(eb.focusLeft) Kill(eb.focusRight) Kill(eb.focusMid)
	if not eb.novaSkin then
		local skin = CreateFrame("Frame", nil, eb)
		skin:SetPoint("TOPLEFT", 4, -3)
		skin:SetPoint("BOTTOMRIGHT", -4, 3)
		skin:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
		ns.CreatePanel(skin, { 0.04, 0.042, 0.05, 0.92 })
		-- Accent underline while typing.
		local line = skin:CreateTexture(nil, "OVERLAY")
		line:SetTexture(ns.TEXTURE)
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT", 1, 1)
		line:SetPoint("BOTTOMRIGHT", -1, 1)
		line:SetVertexColor(unpack(ns.db.accent))
		eb.novaSkin = skin
	end
end

local function StyleFrame(frame)
	if not frame or styled[frame] then return end
	styled[frame] = true
	local name = frame:GetName()

	-- Blizzard's border art and fading background.
	for _, tex in ipairs(CHAT_FRAME_TEXTURES or {}) do
		local region = _G[name .. tex]
		if region then
			Kill(region)
			region:Hide()
		end
	end

	-- Our own quiet panel behind the text.
	if not frame.novaBg then
		local bg = CreateFrame("Frame", nil, frame)
		bg:SetPoint("TOPLEFT", -6, 6)
		bg:SetPoint("BOTTOMRIGHT", 6, -6)
		bg:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
		ns.CreatePanel(bg, { 0.035, 0.037, 0.045, ns.db.chat.alpha })
		frame.novaBg = bg
	end

	-- Side button column: hidden, chat scrolls with the wheel anyway.
	local buttonFrame = frame.buttonFrame or _G[name .. "ButtonFrame"]
	if buttonFrame then
		buttonFrame:SetAlpha(0)
		buttonFrame:EnableMouse(false)
		hooksecurefunc(buttonFrame, "SetAlpha", function(self, a) if a ~= 0 then self:SetAlpha(0) end end)
	end

	-- Turkish-capable face for the message text (keeps the user's size).
	if ns.db.globalFont then
		local _, size, flags = frame:GetFont()
		if size then frame:SetFont(ns.db.font, size, flags or "") end
	end

	StyleEditBox(frame)
	StyleTab(_G[name .. "Tab"])
end

-- Chat menu / channel / voice buttons fade in only while hovering the chat.
local HOVER_BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
	"ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton", "TextToSpeechButton" }

local function SetupHoverButtons()
	local buttons = {}
	for _, n in ipairs(HOVER_BUTTONS) do
		local b = _G[n]
		if b then
			b:SetAlpha(0)
			buttons[#buttons + 1] = b
		end
	end
	local shown = false
	local elapsed = 0
	local watcher = CreateFrame("Frame")
	watcher:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.15 then return end
		elapsed = 0
		local over = ChatFrame1 and ChatFrame1:IsMouseOver(30, -10, -40, 10)
		if not over then
			for _, b in ipairs(buttons) do
				if b:IsShown() and b:IsMouseOver() then over = true break end
			end
		end
		if over ~= shown then
			shown = over
			for _, b in ipairs(buttons) do ns.FadeTo(b, over and 1 or 0, 0.2) end
		end
	end)
end

function C:Init()
	for _, name in ipairs(CHAT_FRAMES or {}) do StyleFrame(_G[name]) end
	if not CHAT_FRAMES then
		for i = 1, (NUM_CHAT_WINDOWS or 10) do StyleFrame(_G["ChatFrame" .. i]) end
	end
	UpdateTabs()
	SetupHoverButtons()

	-- New windows (whispers, pet battle log...) and tab state changes.
	if FCF_OpenTemporaryWindow then
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			for _, name in ipairs(CHAT_FRAMES or {}) do StyleFrame(_G[name]) end
			UpdateTabs()
		end)
	end
	if FCF_SetChatWindowFontSize then
		hooksecurefunc("FCF_SetChatWindowFontSize", function(_, frame)
			frame = frame or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
			if frame and ns.db.globalFont then
				local _, size, flags = frame:GetFont()
				if size then frame:SetFont(ns.db.font, size, flags or "") end
			end
		end)
	end
	for _, fn in ipairs({ "FCF_Tab_OnClick", "FCFTab_UpdateColors", "FCF_DockUpdate", "FCF_SelectDockFrame" }) do
		if _G[fn] then hooksecurefunc(fn, UpdateTabs) end
	end
	if GeneralDockManager then
		Kill(GeneralDockManager.insertHighlight)
		if GeneralDockManager.overflowButton then GeneralDockManager.overflowButton:SetAlpha(0.4) end
	end
end
