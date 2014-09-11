local Libra = LibStub("Libra")

local SpellBinding = Libra:NewAddon(...)
_G.SpellBinding = SpellBinding
Libra:EmbedWidgets(SpellBinding)

local frame = SpellBinding:CreateUIPanel("SpellBindingFrame")
frame:SetPoint("CENTER")
frame:SetToplevel(true)
frame:EnableMouse(true)
frame:SetTitleText("SpellBinding")
frame:HidePortrait(frame)
frame:HideButtonBar(frame)
frame:SetScript("OnShow", function(self)
	PlaySound("igCharacterInfoOpen")
	if not self:GetSelectedTab() then
		self:SelectTab(1)
	end
end)
frame:SetScript("OnHide", function(self)
	SpellBinding:HideOverlays()
	PlaySound("igCharacterInfoClose")
end)

SlashCmdList["SPELLBINDING"] = function(msg)
	ToggleFrame(frame)
end
SLASH_SPELLBINDING1 = "/spellbinding"
SLASH_SPELLBINDING2 = "/sb"

BINDING_HEADER_SPELLBINDING = "SpellBinding"
BINDING_NAME_SPELLBINDING_TOGGLE = "Toggle SpellBinding frame"

local dataobj = LibStub("LibDataBroker-1.1"):NewDataObject("SpellBinding", {
	type = "launcher",
	label = "SpellBinding",
	icon = [[Interface\Icons\INV_Pet_LilSmokey2]],
	OnClick = function(self, button)
		ToggleFrame(frame)
	end,
})

local overlays = {}

local backdrop = {
	bgFile = [[Interface\Buttons\WHITE8X8]],
	insets = {left = 4, right = 4, top = 0, bottom = 4}
}

function SpellBinding:CreateOverlay(parent, isBindingOverlay)
	local overlay = CreateFrame(isBindingOverlay and "Button" or "Frame", nil, parent)
	overlay:SetPoint("TOPLEFT", 0, -21)
	overlay:SetPoint("BOTTOMRIGHT")
	overlay:SetFrameStrata("HIGH")
	overlay:SetBackdrop(backdrop)
	overlay:SetBackdropColor(0, 0, 0, 0.8)
	overlay:EnableMouse(true)
	overlay:Hide()
	
	overlay.text = overlay:CreateFontString(nil, nil, "GameFontHighlightLarge")
	overlay.text:SetPoint("CENTER", 0, 24)
	
	tinsert(overlays, overlay)
	
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

function SpellBinding:CreateBindingOverlay(parent)
	local overlay = self:CreateOverlay(parent, true)
	overlay:RegisterForClicks("AnyDown")
	overlay.SetBindingActionText = setBindingActionText
	overlay.SetBindingKeyText = setBindingKeyText
	
	for event, handler in pairs(handlers) do
		overlay:SetScript(event, handler)
	end
	
	local info = overlay:CreateFontString(nil, nil, "GameFontNormal")
	info:SetPoint("CENTER", 0, 48)
	info:SetText("Press a key to bind")
	
	overlay.actionName = overlay.text
	
	overlay.key = overlay:CreateFontString(nil, nil, "GameFontNormal")
	overlay.key:SetPoint("CENTER")
	
	local closeHint = overlay:CreateFontString(nil, nil, "GameFontDisable")
	closeHint:SetPoint("CENTER", 0, -24)
	closeHint:SetText("Press Escape to cancel")
	
	local acceptButton = self:CreateButton(overlay)
	acceptButton:SetWidth(80)
	acceptButton:SetPoint("BOTTOMRIGHT", -16, 16)
	acceptButton:SetText(ACCEPT)
	acceptButton:SetScript("OnClick", onAccept)
	acceptButton.overlay = overlay
	
	return overlay
end

function SpellBinding:HideOverlays()
	for i, overlay in ipairs(overlays) do
		if not overlay.noHide then
			overlay:Hide()
		end
	end
end

local combatBlock = SpellBinding:CreateOverlay(frame)
combatBlock.text:SetFontObject("GameFontNormalMed3")
combatBlock.text:SetText("Keybinding blocked during combat")
combatBlock.noHide = true

function frame:OnTabSelected(id)
	self.tabs[id].frame:Show()
end

function frame:OnTabDeselected(id)
	self.tabs[id].frame:Hide()
	SpellBinding:HideOverlays()
end


local sets = {
	-- "profile",
	"char",
	"class",
	"race",
	"factionrealm",
	"faction",
	"realm",
	"global",
}

local setNames = {
	percharprofile = "Profile",
	profile = "Profile",
	char = "Character",
	class = "Class",
	race = "Race",
	factionrealm = "Faction - realm",
	faction = "Faction",
	realm = "Realm",
	global = "Global",
}

local defaults = {}

for i, set in ipairs(sets) do
	defaults[set] = {
		bindings = {},
		secondaryBindings = {},
	}
end

defaults.global.sets = {
	"global",
}

-- insert after so it doesn't get included in defaults since it's not a real datatype
tinsert(sets, 1, "percharprofile")

local percharDefaults = {
	profile = {
		bindings = {},
		secondaryBindings = {},
	}
}

function SpellBinding:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SpellBindingDB", defaults)
	
	if self.db.global.scopes then
		self.db.global.sets = self.db.global.scopes
		self.db.global.scopes = nil
	end
	
	-- self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	-- self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	-- self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	self.perchardb = LibStub("AceDB-3.0"):New("SpellBindingPerCharDB", percharDefaults)
	
	self.perchardb.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.perchardb.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.perchardb.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.perchardb, "SpellBinding")
	
	self.db.percharprofile = self.perchardb.profile
	
	self:RegisterEvent("PLAYER_LOGIN", "ApplyBindings")
	self:RegisterEvent("UPDATE_BINDINGS")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	
	self:UpdateSortOrder()
	
	self:CreateAceDBControls(self.perchardb, self:NewModule("Profile", CreateFrame("Frame"))):SetPoint("CENTER", frame.Inset)
end

function SpellBinding:OnModuleCreated(name, module)
	module:SetParent(frame)
	module:SetAllPoints()
	module:Hide()
	module.name = name
	module.Inset = frame.Inset
	
	local tab = frame:CreateTab()
	tab:SetText(name)
	tab.frame = module
end

function SpellBinding:PLAYER_REGEN_DISABLED()
	SpellBinding:HideOverlays()
	combatBlock:Show()
end

function SpellBinding:PLAYER_REGEN_ENABLED()
	combatBlock:Hide()
end

function SpellBinding:RefreshConfig()
	self.db.percharprofile = self.perchardb.profile
	self:ApplyBindings()
end

function SpellBinding:Fire(callback)
	for k, module in self:IterateModules() do
		if module[callback] then
			module[callback](module)
		end
	end
end

function SpellBinding:IsSetActive(set)
	for i, v in SpellBinding:IterateActiveSets() do
		if v == set then
			return true
		end
	end
end

function SpellBinding:ApplyBindings()
	ClearOverrideBindings(frame)
	local sets = SpellBinding.db.global.sets
	for i = #sets, 1, -1 do
		local set = self.db[sets[i]]
		for action, key in pairs(set.bindings) do
			self:ApplyBinding(key, action)
			self:ApplyBinding(set.secondaryBindings[action], action)
		end
	end
	self:Fire("UPDATE_BINDINGS")
end

function SpellBinding:ApplyBinding(key, action)
	if not (type(key) == "string" and action) then return end
	SetOverrideBinding(frame, nil, key, self:GetActionString(action))
end

function SpellBinding:SetBinding(action, set, key, forcePrimary)
	if not key and self.db[set].bindings[action] then
		return
	end
	
	if forcePrimary or type(self.db[set].bindings[action]) ~= "string" then
		self.db[set].bindings[action] = key or true
	else
		self.db[set].secondaryBindings[action] = key
	end
	self:ApplyBindings()
end

function SpellBinding:SetPrimaryBinding(action, set, key)
	local sets = self:GetActiveSets()
	set = set or sets[#sets]
	key = key or self.db[set].bindings[action]
	
	local currentAction, isSecondary = self:GetActionByKey(key, set)
	if currentAction ~= action or isSecondary then
		self:ClearBinding(currentAction, set, isSecondary)
	end
	
	self.db[set].bindings[action] = key or true
	-- self:SetBinding(action, set, key)
	self:ApplyBindings()
end

function SpellBinding:SetSecondaryBinding(action, set, key)
	local sets = self:GetActiveSets()
	set = set or sets[#sets]
	-- key = key or self.db[set].bindings[action]
	
	local currentAction, isSecondary = self:GetActionByKey(key, set)
	if currentAction ~= action then
		self:ClearBinding(currentAction, set, isSecondary)
	end
	
	self.db[set].secondaryBindings[action] = key
	-- self:SetBinding(action, set, key)
	self:ApplyBindings()
end

function SpellBinding:ClearBindings(action, set)
	set = self.db[set]
	set.bindings[action] = true
	set.secondaryBindings[action] = nil
end

function SpellBinding:ClearBinding(action, set, isSecondary)
	if not action then return end
	set = self.db[set]
	if not isSecondary then
		-- if the primary binding was cleared, use the secondary binding as primary
		set.bindings[action] = set.secondaryBindings[action] or true
	end
	set.secondaryBindings[action] = nil
end

function SpellBinding:UPDATE_BINDINGS()
	self:Fire("UPDATE_BINDINGS")
end

local function addBinding(action, key, set)
	if not key then return end
	local color = NORMAL_FONT_COLOR
	if GetBindingByKey(key) ~= SpellBinding:GetActionString(action) then
		color = GRAY_FONT_COLOR
	end
	GameTooltip:AddDoubleLine(GetBindingText(key, "KEY_"), SpellBinding:GetSetName(set), color.r, color.g, color.b, color.r, color.g, color.b)
	GameTooltip.hasBinding = true
end

function SpellBinding:ListBindingKeys(action)
	GameTooltip.hasBinding = nil
	GameTooltip:AddLine(self:GetActionLabel(action), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	for i, set in SpellBinding:IterateActiveSets() do
		local key1, key2 = self:GetBindings(action, set)
		addBinding(action, key1, set)
		addBinding(action, key2, set)
	end
	action = self:GetActionString(action)
	for i = 1, select("#", GetBindingKey(action)) do
		addBinding(action, select(i, GetBindingKey(action)))
	end
	if not GameTooltip.hasBinding then
		GameTooltip:AddLine(NOT_BOUND, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	end
	GameTooltip:Show()
end

-- get the first active key bound to the given action
function SpellBinding:GetBindingKey(action)
	local activeKey
	for i, set in SpellBinding:IterateActiveSets() do
		local key1, key2 = self:GetBindings(action, set)
		local key = key1 or key2
		if key then
			return key
		end
	end
	return GetBindingKey(action)
end

-- get the binding bound to the given key in the given set
function SpellBinding:GetActionByKey(key, set)
	set = self.db[set]
	for action, key2 in pairs(set.bindings) do
		if key2 == key then
			return action
		end
		if set.secondaryBindings[action] == key then
			return action, true
		end
	end
end

function SpellBinding:GetActiveActionForKey(key)
	if not key then return end
	local activeSet
	for i, set in SpellBinding:IterateActiveSets() do
		local action = self:GetActionByKey(key, set)
		if action then
			return self:GetActionString(action), set
		end
	end
	local action = GetBindingAction(key)
	return action ~= "" and action
end

function SpellBinding:GetConflictText(key, action, newSet, activeAction, currentSet)
	local text1, text2
	local currentSetPriority = self.setPriority[currentSet] or math.huge
	local newSetPriority = self.setPriority[newSet] or math.huge
	local currentAction = self:GetActionByKey(key, newSet)
	if activeAction and activeAction ~= self:GetActionString(action) and (not currentAction or self:GetActionString(currentAction) ~= activeAction) then
		if newSetPriority > currentSetPriority then
			text1 = "%s (%s) overrides this"
		else
			if currentSetPriority > math.huge then
				text1 = "Overrides %s (%s)"
			else
				text1 = "Overrides %s"
			end
		end
		text1 = format(YELLOW_FONT_COLOR_CODE..text1, self:GetActionLabel(activeAction, true), self:GetSetName(currentSet))
	end
	-- only care about unbinding if it's actually a different action
	if currentAction and currentAction ~= action then
		text2 = format(RED_FONT_COLOR_CODE.."Unbinds %s (%s)", self:GetActionLabel(currentAction, true), self:GetSetName(newSet))
	end
	return text1, text2
end

function SpellBinding:GetActionString(action)
	if action:match("^SPELL %d+$") then
		action = action:gsub("%d+", GetSpellInfo)
	end
	return action
end

function SpellBinding:GetActionStringReverse(action)
	for i, set in SpellBinding:IterateActiveSets() do
		for k in pairs(self.db[set].bindings) do
			if self:GetActionString(k) == action then
				return k
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
	MACRO = function(data) return select(2, GetMacroInfo(data)) end,
	COMMAND = function() return [[Interface\MacroFrame\MacroFrame-Icon]] end,
	CLICK = function() return [[Interface\Icons\INV_Pet_LilSmokey2]] end,
}

function SpellBinding:GetActionInfo(action)
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

function SpellBinding:GetActionLabel(action, noColor)
	local name, _, type = self:GetActionInfo(action)
	if type then
		name = format("%s%s:%s %s", noColor and "" or LIGHTYELLOW_FONT_COLOR_CODE, type, noColor and "" or "|r", name)
	end
	return name
end

function SpellBinding:GetAvailableSets()
	return sets
end

function SpellBinding:GetActiveSets()
	return self.db.global.sets
end

function SpellBinding:IterateActiveSets()
	return ipairs(self:GetActiveSets())
end

function SpellBinding:GetNumActiveSets()
	return #self:GetActiveSets()
end

function SpellBinding:GetSetName(set)
	return setNames[set]
end

function SpellBinding:GetBindingsForSet(set)
	return self.db[set].bindings
end

function SpellBinding:GetBindings(action, set)
	set = self.db[set]
	local key = set.bindings[action]
	return key ~= true and key, set.secondaryBindings[action]
end

function SpellBinding:GetPrimaryBinding(action, set)
	return self.db[set].bindings[action]
end

function SpellBinding:GetSecondaryBinding(action, set)
	return self.db[set].secondaryBindings[action]
end