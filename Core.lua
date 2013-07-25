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
	-- overlay:SetAllPoints()
	overlay:SetPoint("TOPLEFT", 0, -21)
	overlay:SetPoint("BOTTOMRIGHT")
	overlay:SetFrameStrata("HIGH")
	overlay:SetBackdrop(backdrop)
	overlay:SetBackdropColor(0, 0, 0, 0.7)
	overlay:Hide()
	
	return overlay
end

local function setBindingText(self, action, key)
	self.actionName:SetFormattedText("%s", action)
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
	overlay.SetBindingText = setBindingText
	
	for event, handler in pairs(handlers) do
		overlay:SetScript(event, handler)
	end
	
	local info = overlay:CreateFontString(nil, nil, "GameFontNormal")
	info:SetPoint("CENTER", 0, 24)
	info:SetText("Press a key to bind")
	
	overlay.actionName = overlay:CreateFontString(nil, nil, "GameFontNormalLarge")
	overlay.actionName:SetPoint("CENTER")
	
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

local info = combatBlock:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge", 1)
info:SetPoint("CENTER")
info:SetText("Keybinding blocked during combat")

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
	"profile",
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
	percharprofile = "Profile (per char)",
}

local defaults = {}

for i, scope in ipairs(scopes) do
	defaults[scope] = {
		actions = {},
		bindings = {},
	}
end

defaults.global.scopes = {
	"global",
}

-- insert after so it doesn't get included in defaults since it's not a real datatype
tinsert(scopes, "percharprofile")

local percharDefaults = {
	profile = {
		actions = {},
		bindings = {},
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
	for i, v in ipairs(self.db.global.scopes) do
		for key, action in pairs(self:GetBindings(v)) do
			self:SetBinding(key, action)
		end
	end
	self:Fire("UPDATE_BINDINGS")
end

function addon:UPDATE_BINDINGS()
	self:Fire("UPDATE_BINDINGS")
end

function addon:GetBindingKey(action2)
	for i = #self.db.global.scopes, 1, -1 do
		for key, action in pairs(self:GetBindings(self.db.global.scopes[i])) do
			if action == action2 then
				return key
			end
		end
	end
	return GetBindingKey(action2)
end

function addon:SetBinding(key, action)
	if action:match("^%u+") == "SPELL" then
		action = action:gsub("%d+", GetSpellInfo)
	end
	SetOverrideBinding(frame, nil, key, action)
end

function addon:AddBinding(key, action, scope)
	self.db[scope].actions[action] = true
	if key then
		self.db[scope].bindings[key] = action
		self:ApplyBindings()
	end
end

function addon:ClearBinding(action2, scope)
	for key, action in pairs(self:GetBindings(scope)) do
		if action == action2 then
			addon.db[scope].bindings[key] = nil
		end
	end
	self:ApplyBindings()
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
	-- COMMAND = "",
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

function addon:GetActionInfo(binding)
	if not binding then return end
	local type, data = binding:match("^(%u+) (.+)$")
	local name, texture
	if not types[type] then
		type = "COMMAND"
		data = binding
	end
	local getName = getName[type]
	name = getName and getName(data) or data or binding
	local getTexture = getTexture[type]
	texture = getTexture and getTexture(data) or [[Interface\Icons\INV_Misc_QuestionMark]]
	return name, texture, typeLabels[type]
end

function addon:GetScopes()
	return scopes
end

function addon:GetScopeLabel(scope)
	return scopeLabels[scope]
end

function addon:GetActions(scope)
	return self.db[scope].actions
end

function addon:GetBindings(scope)
	return self.db[scope].bindings
end