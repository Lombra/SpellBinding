local addonName, addon = ...

local frame = CreateFrame("Frame", addonName.."Frame", UIParent, "ButtonFrameTemplate")
addon.frame = frame
frame:SetPoint("CENTER")
frame:SetToplevel(true)
frame:EnableMouse(true)
frame:SetScript("OnShow", function(self)
	PlaySound("igCharacterInfoOpen")
	if not PanelTemplates_GetSelectedTab(self) then
		PanelTemplates_SetTab(self, 1)
	end
end)
frame:SetScript("OnHide", function(self)
	PlaySound("igCharacterInfoClose")
end)
frame.TitleText:SetText(addonName)
ButtonFrameTemplate_HidePortrait(frame)
ButtonFrameTemplate_HideButtonBar(frame)
frame.Inset:SetPoint("BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET + 2)
tinsert(UISpecialFrames, frame:GetName())
UIPanelWindows[frame:GetName()] = {
	area = "left",
	pushable = 1,
	whileDead = true,
}

SlashCmdList["SPELLBINDING"] = function(msg)
	ToggleFrame(addon.frame)
end
SLASH_SPELLBINDING1 = "/spellbinding"
SLASH_SPELLBINDING2 = "/sb"

BINDING_HEADER_SPELLBINDING = "SpellBinding"
BINDING_NAME_SPELLBINDING_TOGGLE = "Toggle SpellBinding frame"

local backdrop = {
	bgFile = [[Interface\Buttons\WHITE8X8]],
	insets = {left = 4, right = 4, top = 0, bottom = 4}
}

function addon:CreateOverlay(parent, isBindingOverlay)
	local overlay = CreateFrame(isBindingOverlay and "Button" or "Frame", nil, parent)
	overlay:SetPoint("TOPLEFT", 0, -21)
	overlay:SetPoint("BOTTOMRIGHT")
	overlay:SetFrameStrata("HIGH")
	overlay:SetBackdrop(backdrop)
	overlay:SetBackdropColor(0, 0, 0, 0.7)
	overlay:EnableMouse(true)
	overlay:Hide()
	
	overlay.text = overlay:CreateFontString(nil, nil, "GameFontHighlightLarge")
	overlay.text:SetPoint("CENTER")
	
	return overlay
end

local function setBindingActionText(self, action)
	self.actionName:SetFormattedText("%s", action)
end

local function setBindingKeyText(self, key)
	self.key:SetFormattedText("Current key: %s", GetBindingText(key or NOT_BOUND, "KEY_"))
end

local buttonMappings = {
	LeftButton = "BUTTON1",
	RightButton = "BUTTON2",
	MiddleButton = "BUTTON3",
}

local ignoredKeys = {
	UNKNOWN = true,
	BUTTON1 = true,
	BUTTON2 = true,
	LSHIFT = true,
	RSHIFT = true,
	LCTRL = true,
	RCTRL = true,
	LALT = true,
	RALT = true,
}

local function onBinding(self, keyPressed)
	if GetBindingFromClick(keyPressed) == "TOGGLEGAMEMENU" then
		self:Hide()
		return
	end
	
	keyPressed = buttonMappings[keyPressed] or keyPressed
	
	if keyPressed:match("^Button%d+$") then
		keyPressed = keyPressed:upper()
		-- 4 - 31
	end

	if ignoredKeys[keyPressed] then
		return
	end

	if IsShiftKeyDown() then
		keyPressed = "SHIFT-"..keyPressed
	end
	if IsControlKeyDown() then
		keyPressed = "CTRL-"..keyPressed
	end
	if IsAltKeyDown() then
		keyPressed = "ALT-"..keyPressed
	end
	
	self:OnBinding(keyPressed)
end

local handlers = {
	OnKeyDown = onBinding,
	OnClick = onBinding,
	OnMouseWheel = function(self, delta)
		if delta > 0 then
			onBinding(self, "MOUSEWHEELUP")
		else
			onBinding(self, "MOUSEWHEELDOWN")
		end
	end,
}

local function onAccept(self)
	self.overlay:OnAccept()
	self.overlay:Hide()
end

function addon:CreateBindingOverlay(parent)
	local overlay = self:CreateOverlay(parent, true)
	overlay:RegisterForClicks("AnyUp")
	overlay.SetBindingActionText = setBindingActionText
	overlay.SetBindingKeyText = setBindingKeyText
	
	for event, handler in pairs(handlers) do
		overlay:SetScript(event, handler)
	end
	
	local info = overlay:CreateFontString(nil, nil, "GameFontNormal")
	info:SetPoint("CENTER", 0, 24)
	info:SetText("Press a key to bind")
	
	overlay.actionName = overlay.text
	
	overlay.key = overlay:CreateFontString(nil, nil, "GameFontNormal")
	overlay.key:SetPoint("CENTER", 0, -24)
	
	local acceptButton = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
	acceptButton:SetWidth(80)
	acceptButton:SetPoint("BOTTOMRIGHT", -16, 16)
	acceptButton:SetText(ACCEPT)
	acceptButton:SetScript("OnClick", onAccept)
	acceptButton.overlay = overlay
	
	return overlay
end

local combatBlock = addon:CreateOverlay(frame)

combatBlock.text:SetText("Keybinding blocked during combat")

local tabs = {}

local function onClick(self)
	PanelTemplates_Tab_OnClick(self, frame)
	PlaySound("igCharacterInfoTab")
end

local function onEnable(self)
	self.frame:Hide()
end

local function onDisable(self)
	self.frame:Show()
end

local function createTab()
	local numTabs = #tabs + 1
	local tab = CreateFrame("Button", addonName.."FrameTab"..numTabs, frame, "CharacterFrameTabButtonTemplate")
	if numTabs == 1 then
		tab:SetPoint("BOTTOMLEFT", 19, -30)
	else
		tab:SetPoint("LEFT", tabs[numTabs - 1], "RIGHT", -15, 0)
	end
	tab:SetID(numTabs)
	tab:SetScript("OnClick", onClick)
	tab:SetScript("OnEnable", onEnable)
	tab:SetScript("OnDisable", onDisable)
	tabs[numTabs] = tab
	PanelTemplates_SetNumTabs(frame, numTabs)
	return tab
end

local modules = {}

function addon:GetSelectedTab()
	return tabs[PanelTemplates_GetSelectedTab(frame)].frame
end

function addon:NewModule(name)
	if modules[name] then
		error("Module '"..name.."' already exists.", 2)
	end
	
	local ui = CreateFrame("Frame", nil, frame)
	ui:SetAllPoints()
	ui:Hide()
	ui.name = name
	ui.Inset = frame.Inset
	modules[name] = ui
	
	local tab = createTab()
	tab:SetText(name)
	tab.frame = ui
	return ui
end


local scopes = {
	"global",
	"realm",
	"faction",
	"factionrealm",
	"race",
	"class",
	"char",
	-- "profile",
}

local scopeLabels = {
	global = "Global",
	realm = "Realm",
	faction = "Faction",
	factionrealm = "Faction - realm",
	race = "Race",
	class = "Class",
	char = "Character",
	profile = "Profile",
	percharprofile = "Profile",
}

local defaults = {}

for i, scope in ipairs(scopes) do
	defaults[scope] = {
		bindings = {},
		secondaryBindings = {},
	}
end

defaults.global.scopes = {
	"global",
}

-- insert after so it doesn't get included in defaults since it's not a real datatype
tinsert(scopes, "percharprofile")

local percharDefaults = {
	profile = {
		bindings = {},
		secondaryBindings = {},
	}
}

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
	addon[event](addon, ...)
end)

function addon:ADDON_LOADED(addon)
	if addon ~= addonName then
		return
	end
	
	self.db = LibStub("AceDB-3.0"):New("SpellBindingDB", defaults)
	
	-- self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	-- self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	-- self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	self.perchardb = LibStub("AceDB-3.0"):New("SpellBindingPerCharDB", percharDefaults)
	
	self.perchardb.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.perchardb.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.perchardb.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.perchardb, "SpellBinding")
	
	self.db.percharprofile = self.perchardb.profile
	
	do	-- upgrade data (remove for beta/release)
		for i, scope in ipairs(scopes) do
			scope = self.db[scope]
			if scope.actions then
				local extraBindings = scope.bindings
				scope.bindings = scope.actions
				scope.actions = nil
				for key, action in pairs(extraBindings) do
					scope.bindings[action] = key
				end
			end
		end
	end
	
	self:Fire("OnInitialize")
	
	self:UpdateSortOrder()
end

function addon:PLAYER_LOGIN()
	self:ApplyBindings()
end

function addon:PLAYER_REGEN_DISABLED()
	combatBlock:Show()
end

function addon:PLAYER_REGEN_ENABLED()
	combatBlock:Hide()
end

function addon:RefreshConfig()
	do	-- upgrade data (remove for beta/release)
		for i, scope in ipairs(scopes) do
			scope = self.db[scope]
			if scope.actions then
				local extraBindings = scope.bindings
				scope.bindings = scope.actions
				scope.actions = nil
				for key, action in pairs(extraBindings) do
					scope.bindings[action] = key
				end
			end
		end
	end
	
	self.db.percharprofile = self.perchardb.profile
	self:ApplyBindings()
end

function addon:Fire(callback)
	for k, module in pairs(modules) do
		if module[callback] then
			module[callback](module)
		end
	end
end

function addon:IsScopeUsed(scope)
	for i, v in ipairs(self.db.global.scopes) do
		if v == scope then
			return true
		end
	end
end

function addon:ApplyBindings()
	ClearOverrideBindings(frame)
	for i, scope in ipairs(self.db.global.scopes) do
		scope = self.db[scope]
		for action, key in pairs(scope.bindings) do
			self:ApplyBinding(key, action)
			self:ApplyBinding(scope.secondaryBindings[action], action)
		end
	end
	self:Fire("UPDATE_BINDINGS")
end

function addon:ApplyBinding(key, action)
	if not (type(key) == "string" and action) then return end
	SetOverrideBinding(frame, nil, key, self:GetActionString(action))
end

function addon:SetBinding(action, scope, key, forcePrimary)
	if not key and self.db[scope].bindings[action] then
		return
	end
	
	if forcePrimary or type(self.db[scope].bindings[action]) ~= "string" then
		self.db[scope].bindings[action] = key or true
	else
		self.db[scope].secondaryBindings[action] = key
	end
	self:ApplyBindings()
end

function addon:SetPrimaryBinding(action, scope, key)
	key = key or self.db[scope].bindings[action]
	
	local action1, action2 = self:GetBindingsByKey(key, scope)
	if action1 ~= action then
		self:ClearBinding(action1, scope)
	end
	self:ClearBinding(action2, scope, true)
	
	self.db[scope].bindings[action] = key or true
	-- self:SetBinding(action, scope, key)
	self:ApplyBindings()
end

function addon:SetSecondaryBinding(action, scope, key)
	-- key = key or self.db[scope].bindings[action]
	
	local action1, action2 = self:GetBindingsByKey(key, scope)
	if action1 ~= action then
		self:ClearBinding(action1, scope)
	end
	if action2 ~= action then
		self:ClearBinding(action2, scope, true)
	end
	
	self.db[scope].secondaryBindings[action] = key
	-- self:SetBinding(action, scope, key)
	self:ApplyBindings()
end

function addon:ClearBindings(action, scope)
	scope = self.db[scope]
	scope.bindings[action] = true
	scope.secondaryBindings[action] = nil
end

function addon:ClearBinding(action, scope, secondary)
	if not action then return end
	scope = self.db[scope]
	if not secondary then
		-- if the primary binding was cleared, use the secondary binding as primary
		scope.bindings[action] = scope.secondaryBindings[action] or true
	end
	scope.secondaryBindings[action] = nil
end

function addon:UPDATE_BINDINGS()
	self:Fire("UPDATE_BINDINGS")
end

local bindings = {}

function addon:GetBindingKeys(action)
	wipe(bindings)
	for i, scope in ipairs(self.db.global.scopes) do
		local key1, key2 = self:GetBindings(action, scope)
		if key1 then
			tinsert(bindings, {key = key1, scope = scope})
		end
		if key2 then
			tinsert(bindings, {key = key2, scope = scope})
		end
	end
	action = self:GetActionString(action)
	for i = 1, select("#", GetBindingKey(action)) do
		tinsert(bindings, {key = select(i, GetBindingKey(action))})
	end
	return bindings
end

function addon:ListBindingKeys(action)
	GameTooltip:AddLine(addon:GetActionLabel(action), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	local bindings = self:GetBindingKeys(action)
	for i, binding in ipairs(bindings) do
		local key = binding.key
		local color = NORMAL_FONT_COLOR
		if GetBindingByKey(key) ~= self:GetActionString(action) then
			color = GRAY_FONT_COLOR
		end
		GameTooltip:AddDoubleLine(GetBindingText(key, "KEY_"), self:GetScopeLabel(binding.scope), color.r, color.g, color.b, color.r, color.g, color.b)
	end
	GameTooltip:Show()
end

function addon:GetBindingKey(action)
	local activeKey
	local scopes = self.db.global.scopes
	for i = #scopes, 1, -1 do
		local scope = self.db[scopes[i]]
		local key = scope.bindings[action] or scope.secondaryBindings[action]
		if type(key) == "string" then
			return key
		end
	end
	return GetBindingKey(action)
end

function addon:GetBindingsByKey(key, scope)
	local action1, action2
	scope = self.db[scope]
	for action, key2 in pairs(scope.bindings) do
		if key2 == key then
			action1 = action
			break
		end
	end
	for action, key2 in pairs(scope.secondaryBindings) do
		if key2 == key then
			action2 = action
			break
		end
	end
	return action1, action2
end

function addon:GetActiveScopeForKey(key)
	local scopes = self.db.global.scopes
	for i = #scopes, 1, -1 do
		local scope = scopes[i]
		for action, key2 in pairs(self:GetBindingsForScope(scope)) do
			if key2 == key then
				return scope
			end
		end
	end
end

function addon:GetActionString(action)
	if action:match("^SPELL %d+$") then
		action = action:gsub("%d+", GetSpellInfo)
	end
	return action
end

function addon:GetActionStringReverse(action)
	for i, scope in ipairs(self.db.global.scopes) do
		for action2 in pairs(self.db[scope].bindings) do
			if self:GetActionString(action2) == action then
				return action2
			end
		end
	end
end

local types = {
	SPELL = true,
	ITEM = true,
	MACRO = true,
	CLICK = true,
}

local typeLabels = {
	SPELL = "Spell",
	ITEM = "Item",
	MACRO = "Macro",
	CLICK = "Click",
}

local getName = {
	SPELL = GetSpellInfo,
	ITEM = GetItemInfo,
	COMMAND = function(data)
		return GetBindingText(data, "BINDING_NAME_")
	end,
}

local getTexture = {
	SPELL = GetSpellTexture,
	ITEM = GetItemIcon,
	MACRO = function(data)
		return select(2, GetMacroInfo(data))
	end,
	COMMAND = function()
		return ""
	end,
}

function addon:GetActionInfo(action)
	if not action then return end
	local type, data = action:match("^(%u+) (.+)$")
	local name, texture
	if not types[type] then
		type = "COMMAND"
		data = action
	end
	local getName = getName[type]
	name = getName and getName(data) or data or action
	local getTexture = getTexture[type]
	texture = getTexture and getTexture(data) or [[Interface\Icons\INV_Misc_QuestionMark]]
	return name, texture, typeLabels[type]
end

function addon:GetActionLabel(action, noColor)
	local name, _, type = self:GetActionInfo(action)
	if type then
		name = format("%s%s:|r %s", noColor and "" or LIGHTYELLOW_FONT_COLOR_CODE, type, name)
	end
	return name
end

function addon:GetScopes()
	return scopes
end

function addon:GetScopeLabel(scope)
	return scopeLabels[scope]
end

function addon:GetBindingsForScope(scope)
	return self.db[scope].bindings
end

function addon:GetBindings(action, scope)
	scope = self.db[scope]
	local key = scope.bindings[action]
	return key ~= true and key, scope.secondaryBindings[action]
end

function addon:GetPrimaryBinding(action, scope)
	return self.db[scope].bindings[action]
end

function addon:GetSecondaryBinding(action, scope)
	return self.db[scope].secondaryBindings[action]
end