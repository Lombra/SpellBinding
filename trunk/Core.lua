local addonName, addon = ...

local widgetIndex = 1
local function getWidgetName()
	local name = addonName.."Widget"..widgetIndex
	widgetIndex = widgetIndex + 1
	return name
end

SlashCmdList["SPELLBINDING"] = function(msg)
	ToggleFrame(addon.frame)
end
SLASH_SPELLBINDING1 = "/spellbinding"
SLASH_SPELLBINDING2 = "/sb"

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
tinsert(UISpecialFrames, frame:GetName())
UIPanelWindows[frame:GetName()] = {
	area = "left",
	pushable = 1,
	whileDead = true,
}

local tabs = {}

local function onClick(self)
	PanelTemplates_Tab_OnClick(self, frame)
	PlaySound("igCharacterInfoTab")
end

local function onEnable(self)
	local frame = self.frame
	frame:Hide()
end

local function onDisable(self)
	local frame = self.frame
	frame:Show()
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

function addon:CreateUI(name)
	local ui = CreateFrame("Frame", nil, frame)
	ui:SetAllPoints()
	ui:Hide()
	ui.name = name
	ui.filterArgs = {}
	
	local tab = createTab()
	tab:SetText(name)
	tab.frame = ui
	return ui
end

function addon:GetSelectedTab()
	return tabs[PanelTemplates_GetSelectedTab(frame)].frame
end

function addon:OnInitialize()
	-- self.db = LibStub("AceDB-3.0"):New("LootLibraryDB", defaults, true)
end

function addon:NewModule(name, table)
	if modules[name] then
		error("Module '"..name.."' already exists.", 2)
	end
	
	local module = self:CreateUI(name)
	-- for k, v in pairs(mixins) do module[k] = v end
	modules[name] = module
	return module
end


local datatypes = {
	"char",
	"realm",
	"class",
	"race",
	"faction",
	"factionrealm",
	"global",
	"profile",
}

local scopeLabels = {
	char = "Character",
	realm = "Realm",
	class = "Class",
	race = "Race",
	faction = "Faction",
	factionrealm = "Faction - realm",
	global = "Global",
	profile = "Profile",
}

--[[
	item = "item:<itemID>"
	spell
]]

local Bindings = addon:NewModule("Bindings")

Bindings:EnableMouse(true)
Bindings:SetScript("OnReceiveDrag", function(self)
	local type, data, subType, subData = GetCursorInfo()
	if type == "item" then
		addon.db.global.actions["ITEM item:"..data] = true
	elseif type == "spell" then
		addon.db.global.actions["SPELL "..subData] = true
	elseif type == "macro" then
		addon.db.global.actions["MACRO "..GetMacroInfo(data)] = true
	end
	ClearCursor()
	addon:Update()
	print(type, data, subType, subData)
end)

local overlay = CreateFrame("Button", nil, frame)
overlay:SetAllPoints()
overlay:SetToplevel(true)
overlay:RegisterForClicks("AnyUp")
overlay:Hide()

local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge", 1)
text:SetPoint("CENTER")

local currentAction

local OK = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
OK:SetPoint("BOTTOMRIGHT", -16, 16)
OK:SetWidth(80)
OK:SetText("OK")
OK:SetScript("OnClick", function()
	print(text:GetText(), currentAction)
	SetOverrideBinding(frame, nil, text:GetText(), currentAction:gsub("(%d+)$", GetSpellInfo))
	addon.db.global.bindings[text:GetText()] = currentAction
	overlay:Hide()
	addon:Update()
end)

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

local function onBinding(keyOrButton)
	if GetBindingFromClick(keyOrButton) == "TOGGLEGAMEMENU" then
		overlay:Hide()
		return
	end
	
	local keyPressed = keyOrButton

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
	
	print(GetBindingFromClick(keyPressed), GetBindingText(GetBindingFromClick(keyPressed), "BINDING_NAME_"))
	text:SetText(GetBindingText(keyPressed, "KEY_"))
	text:SetText(keyPressed)
end

overlay:SetScript("OnClick", function(self, button)
	onBinding(button)
end)

overlay:SetScript("OnMouseWheel", function(self, delta)
	if delta > 0 then
		onBinding("MOUSEWHEELUP")
	else
		onBinding("MOUSEWHEELDOWN")
	end
end)

overlay:SetScript("OnKeyDown", function(self, key)
	onBinding(key)
end)

local bg = overlay:CreateTexture(nil, "OVERLAY")
bg:SetAllPoints()
bg:SetTexture(0, 0, 0, 0.5)

local scrollFrame
local list

do
	local BUTTON_HEIGHT = 18
	local BUTTON_OFFSET = 2
	
	local getName = {
		SPELL = GetSpellInfo,
		ITEM = GetItemInfo,
		MACRO = function(data) return data end,
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
	}
	
	local function listBindings(key, ...)
		GameTooltip:AddLine(GetBindingText(key, "KEY_"))
		for i = 1, select("#", ...) do
			GameTooltip:AddLine(GetBindingText(select(i, ...), "KEY_"))
		end
	end
	
	local options = {
		{
			text = "Remove",
			func = function(self, action)
				addon.db.global.actions[action] = nil
				addon:Update()
			end,
		},
		{
			text = "Unbind",
			func = function(self, action2)
				addon:ClearBinding(key)
				addon:Update()
			end,
		},
	}
	
	local menu = CreateFrame("Frame")
	menu.displayMode = "MENU"
	menu.initialize = function(self)
		for i, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.text
			info.func = option.func
			info.arg1 = UIDROPDOWNMENU_MENU_VALUE
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
		end
	end
	
	local function onClick(self, button)
		if button == "LeftButton" then
			currentAction = self.binding
			overlay:Show()
		else
			overlay:Hide()
			ToggleDropDownMenu(nil, self.binding, menu, self, 0, 0)
		end
	end
	
	local function onEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 28, 0)
		local type, data = self.binding:match("(%u+) (.+)")
		GameTooltip:AddLine((getName[type] or getName["COMMAND"])(data))
		listBindings(GetBindingKey(self.binding))
		GameTooltip:Show()
		self.showingTooltip = true
	end

	local function onLeave(self)
		GameTooltip:Hide()
		self.showingTooltip = false
	end
	
	local function createButton(frame)
		local button = CreateFrame("Button", nil, frame)
		button:SetHeight(BUTTON_HEIGHT)
		button:SetPoint("RIGHT", -5, 0)
		button:SetScript("OnClick", onClick)
		button:SetScript("OnEnter", onEnter)
		button:SetScript("OnLeave", onLeave)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
		button:SetPushedTextOffset(0, 0)

		button.icon = button:CreateTexture()
		button.icon:SetPoint("LEFT", 3, 0)
		button.icon:SetSize(16, 16)
		
		-- button.label = button:CreateFontString(nil, nil, "GameFontNormal")
		-- button.label:SetWordWrap(false)
		-- button:SetFontString(button.label)
		
		button.label = button:CreateFontString(nil, nil, "GameFontHighlightLeft")
		button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
		button:SetFontString(button.label)
		
		local label = button.label
		
		label:SetJustifyH("LEFT")
		label:SetJustifyV("TOP")
		
		-- label:SetPoint("TOP", 0, -1)
		-- label:SetPoint("LEFT", button.icon, "TOPRIGHT", 4, 0)
		-- label:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", 4, 0)
		-- label:SetPoint("RIGHT", -21, 0)
		-- label:SetPoint("BOTTOM", 0, 3)
		
		button.source = button:CreateFontString(nil, nil, "GameFontHighlightSmallLeft")
		button.source:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMRIGHT", 4, 0)
		
		button.info = button:CreateFontString(nil, nil, "GameFontHighlightSmallRight")
		button.info:SetPoint("RIGHT", -3, 0)
		
		return button
	end
	
	local function createHeader(frame)
		local button = createButton(frame)
		
		button:SetNormalFontObject(GameFontNormal)
		
		local left = button:CreateTexture(nil, "BORDER")
		left:SetPoint("LEFT")
		left:SetSize(76, 16)
		left:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		left:SetTexCoord(0.17578125, 0.47265625, 0.29687500, 0.54687500)
		
		local right = button:CreateTexture(nil, "BORDER")
		right:SetPoint("RIGHT")
		right:SetSize(76, 16)
		right:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		right:SetTexCoord(0.17578125, 0.47265625, 0.01562500, 0.26562500)
		
		local middle = button:CreateTexture(nil, "BORDER")
		middle:SetPoint("LEFT", left, "RIGHT", -20, 0)
		middle:SetPoint("RIGHT", right, "LEFT", 20, 0)
		middle:SetHeight(16)
		middle:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		middle:SetTexCoord(0.48046875, 0.98046875, 0.01562500, 0.26562500)
		
		local left = button:CreateTexture(nil, "HIGHLIGHT")
		left:SetBlendMode("ADD")
		left:SetPoint("LEFT", -5, 0)
		left:SetSize(26, 18)
		left:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		left:SetTexCoord(18 / 256, 44 / 256, 18 / 64, 36 / 64)
		
		local right = button:CreateTexture(nil, "HIGHLIGHT")
		right:SetBlendMode("ADD")
		right:SetPoint("RIGHT", 5, 0)
		right:SetSize(26, 18)
		right:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		right:SetTexCoord(18 / 256, 44 / 256, 0, 18 / 64)
		
		local middle = button:CreateTexture(nil, "HIGHLIGHT")
		middle:SetBlendMode("ADD")
		middle:SetPoint("LEFT", left, "RIGHT")
		middle:SetPoint("RIGHT", right, "LEFT")
		middle:SetHeight(18)
		middle:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		middle:SetTexCoord(0, 18 / 256, 0, 18 / 64)
		
		-- local highlight = button:CreateTexture()
		-- highlight:SetPoint("TOPLEFT", 3, -2)
		-- highlight:SetPoint("BOTTOMRIGHT", -3, 2)
		-- highlight:SetTexture([[Interface\TokenFrame\UI-TokenFrame-CategoryButton]])
		-- highlight:SetTexCoord(0, 1, 0.609375, 0.796875)
		-- button:SetHighlightTexture(highlight)
		
		return button
	end
	
	local function updateButton(button, object)
		local isHeader = type(object) == "table"
		if isHeader then
			button.info:SetText("")
			button.icon:SetTexture("")
			button.label:SetText(object.name)
			button.label:SetFontObject("GameFontNormal")
			button.itemID = nil
		else
			local binding = object
			local type, data = binding:match("(%u+) (.+)")
			button.label:SetText((getName[type] or getName["COMMAND"])(data))
			button.info:SetText(GetBindingText(addon:GetBindingKey(binding) or NOT_BOUND, "KEY_"))
			button.binding = binding
			local texture = getTexture[type]
			texture = texture and texture(data)
			button.icon:SetTexture(texture)
		end
		
		if button.showingTooltip then
			if not isHeader then
				-- GameTooltip:SetItemByID(button.itemID)
			else
				GameTooltip:Hide()
			end
		end

		-- button.index = index
		button.isHeader = isHeader
	end
	
	local function update(self)
		local offset = HybridScrollFrame_GetOffset(self)
		local buttons = self.buttons
		local numButtons = #buttons
		for i = 1, numButtons do
			local index = offset + i
			local object = list[index]
			local button = buttons[i]
			if object then
				updateButton(button, object, list)
			end
			button:SetShown(object ~= nil)
		end
		
		HybridScrollFrame_Update(self, #list * BUTTON_HEIGHT, numButtons * BUTTON_HEIGHT)
	end
	
	local name = getWidgetName()
	scrollFrame = CreateFrame("ScrollFrame", name, Bindings, "HybridScrollFrameTemplate")
	scrollFrame:SetPoint("TOP", frame.Inset, 0, -4)
	scrollFrame:SetPoint("LEFT", frame.Inset, 4, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame.Inset, -23, 4)
	scrollFrame.update = function()
		update(scrollFrame)
	end
	_G[name] = nil
	
	scrollFrame:SetScript("OnReceiveDrag", Bindings:GetScript("OnReceiveDrag"))
	
	local scrollBar = CreateFrame("Slider", nil, scrollFrame, "HybridScrollBarTemplate")
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOP", frame.Inset, 0, -16)
	scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 11)
	scrollBar.doNotHide = true
	
	local buttons = {}
	scrollFrame.buttons = buttons
	
	for i = 1, (ceil(scrollFrame:GetHeight() / BUTTON_HEIGHT) + 1) do
		local button = createButton(scrollFrame.scrollChild)
		if i == 1 then
			button:SetPoint("TOPLEFT", 1, -2)
		else
			button:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, -BUTTON_OFFSET)
		end
		buttons[i] = button
	end
	
	HybridScrollFrame_CreateButtons(scrollFrame, nil, nil, nil, nil, nil, nil, -BUTTON_OFFSET)
end

local function onClick(self, v)
	UIDropDownMenu_SetText(SpellBindingDatatypeMenu, v)
	addon:Update()
end

local button = CreateFrame("Frame", "SpellBindingCurrentScopeMenu", Bindings, "UIDropDownMenuTemplate")
-- button:SetWidth(96)
UIDropDownMenu_SetWidth(button, 96)
button:SetPoint("TOPLEFT", 0, -29)
-- button:SetText("Characters")
button.initialize = function(self, level)
	local info = UIDropDownMenu_CreateInfo()
	info.text = "All"
	info.func = onClick
	info.arg1 = "All"
	UIDropDownMenu_AddButton(info)
	
	for i, v in pairs(addon.db.global.scopes) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = scopeLabels[v]
		info.func = onClick
		info.arg1 = v
		UIDropDownMenu_AddButton(info)
	end
end

local new = CreateFrame("Button", "SpellBindingAddBinding", Bindings, "UIMenuButtonStretchTemplate")
new:SetWidth(40)
new:SetPoint("LEFT", button, "RIGHT", -6, 2)
new:SetText("Add")
new:SetScript("OnClick", function()
end)

local function onEditFocusLost(self)
	self:SetFontObject("ChatFontSmall")
	self:SetTextColor(0.5, 0.5, 0.5)
end

local function onEditFocusGained(self)
	self:SetTextColor(1, 1, 1)
end

local name = getWidgetName()
local searchBox = CreateFrame("EditBox", name, Bindings, "SearchBoxTemplate")
_G[name] = nil
searchBox:SetSize(128, 20)
searchBox:SetPoint("TOPRIGHT", -16, -33)
searchBox:SetFontObject("ChatFontSmall")
searchBox:SetTextColor(0.5, 0.5, 0.5)
searchBox:HookScript("OnEditFocusLost", onEditFocusLost)
searchBox:HookScript("OnEditFocusGained", onEditFocusGained)
searchBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
searchBox:SetScript("OnTextChanged", function(self, isUserInput)
	if not isUserInput then
		return
	end
	local text = self:GetText():lower()
end)


local Options = addon:NewModule("Options")

local defaults = {}

for i, scope in ipairs(datatypes) do
	defaults[scope] = {
		actions = {},
		bindings = {},
	}
end

defaults.global.scopes = {
	"global",
}

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:SetScript("OnEvent", function(self, event, ...)
	addon[event](addon, ...)
end)

function addon:ADDON_LOADED(addon)
	if addon ~= addonName then
		return
	end
	
	self.db = LibStub("AceDB-3.0"):New("SpellBindingDB", defaults)
	
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	LibStub('LibDualSpec-1.0'):EnhanceDatabase(self.db, "SpellBinding")
	
	for k, module in pairs(modules) do
		if module.OnInitialize then
			module:OnInitialize()
		end
	end
	
	self:UpdateScopeMenus()
end

function addon:PLAYER_LOGIN()
	self:ApplyBindings()
	self:Update()
end

function addon:RefreshConfig()
end

function addon:IsScopeUsed(scope)
	for i, v in ipairs(self.db.global.scopes) do
		if v == scope then
			return true
		end
	end
end

function addon:Update()
	list = {}
	for i, scope in ipairs(datatypes) do
		if self:IsScopeUsed(scope) then
			for k, v in pairs(self.db[scope].actions) do
				tinsert(list, k)
			end
		end
	end
	sort(list, listSort)
	scrollFrame:update()
end

addon.UPDATE_BINDINGS = addon.Update

function addon:ApplyBindings()
	for i, v in ipairs(self.db.global.scopes) do
		for key, command in pairs(self.db[v].bindings) do
			-- local type, binding = command:match("(%u-):?(.+)")
			print(GetBindingByKey(key))
			SetOverrideBinding(frame, nil, key, command:gsub("(%d+)$", GetSpellInfo))
		end
	end
end

local scopeMenus = {}

function addon:UpdateScopeMenus()
	local db = self.db.global.scopes
	for i = 1, #db do
		local menu = self:GetScopeMenu(i)
		UIDropDownMenu_SetText(menu, scopeLabels[db[i]])
		menu.moveUp:Show()
		menu.moveUp:SetEnabled(i ~= 1)
		menu.moveDown:Show()
		menu.moveDown:SetEnabled(i ~= #db)
	end
	local menu = self:GetScopeMenu(#db + 1)
	UIDropDownMenu_SetText(menu, "Add scope")
	menu.moveUp:Hide()
	menu.moveDown:Hide()
	for i = #db + 2, #scopeMenus do
		self:GetScopeMenu(i):Hide()
	end
end

function addon:GetScopeMenu(index)
	return scopeMenus[index] or self:CreateScopeMenu(index)
end

local function disableScope(self, scope)
	for i, v in ipairs(addon.db.global.scopes) do
		if v == scope then
			tremove(addon.db.global.scopes, i)
			addon:UpdateScopeMenus()
			return
		end
	end
end

local function onClick(self, scope)
	tinsert(addon.db.global.scopes, scope)
	addon:UpdateScopeMenus()
end

local function initializeScopeMenu(self)
	local scope = addon.db.global.scopes[self.index]
	if scope then
		local info = UIDropDownMenu_CreateInfo()
		info.text = "Disable"
		info.func = disableScope
		info.arg1 = scope
		info.notCheckable = true
		UIDropDownMenu_AddButton(info)
	end
	
	for i, v in ipairs(datatypes) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = scopeLabels[v]
		info.func = onClick
		info.arg1 = v
		info.checked = v == scope
		info.disabled = addon:IsScopeUsed(v)
		UIDropDownMenu_AddButton(info)
	end
end

local function move(self)
	local db = addon.db.global.scopes
	local index = self.index
	local swapIndex = index + self.shiftMod
	db[index], db[swapIndex] = db[swapIndex], db[index]
	addon:UpdateScopeMenus()
end

function addon:CreateScopeMenu(index)
	local menu = CreateFrame("Frame", addonName.."ScopeMenu"..index, Options, "UIDropDownMenuTemplate")
	if index == 1 then
		menu:SetPoint("TOPLEFT", frame.Inset, 0, -16)
	else
		menu:SetPoint("TOP", scopeMenus[index - 1], "BOTTOM")
	end
	menu.initialize = initializeScopeMenu
	menu.index = index
	UIDropDownMenu_SetWidth(menu, 128)
	UIDropDownMenu_JustifyText(menu, "LEFT")
	scopeMenus[index] = menu
	
	menu.moveUp = CreateFrame("Button", nil, menu)
	menu.moveUp:SetSize(24, 24)
	menu.moveUp:SetPoint("LEFT", menu, "RIGHT", -12, 3)
	menu.moveUp:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Up]])
	menu.moveUp:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Down]])
	menu.moveUp:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Disabled]])
	menu.moveUp:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIcon-BlinkHilight]])
	menu.moveUp:SetScript("OnClick", move)
	menu.moveUp.index = index
	menu.moveUp.shiftMod = -1
	
	menu.moveDown = CreateFrame("Button", nil, menu)
	menu.moveDown:SetSize(24, 24)
	menu.moveDown:SetPoint("LEFT", menu.moveUp, "RIGHT")
	menu.moveDown:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
	menu.moveDown:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
	menu.moveDown:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
	menu.moveDown:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
	menu.moveDown:SetScript("OnClick", move)
	menu.moveDown.index = index
	menu.moveDown.shiftMod = 1
	
	return menu
end

local sortPriority = {
	"quality",
	"slot",
	"type",
	"name",
	"itemLevel",
}

local sortAscending = {
	name = true,
	slot = true,
	type = true,
}

local function listSort(a, b)
	a, b = items[a], items[b]
	if not (a and b) then return end
	for i, v in ipairs(sortPriority) do
		if a[v] ~= b[v] then
			if sortAscending[v] then
				a, b = b, a
			end
			if not (a[v] and b[v]) then
				return a[v]
			end
			return a[v] > b[v]
		end
	end
end

function addon:UpdateList()
	sort(self:GetList(), listSort)
	scrollFrame:update()
end


local Naga = addon:NewModule("Naga")

local function createButton()
	local button = CreateFrame("CheckButton", nil, Naga)
	button:SetSize(36, 36)
	
	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
	button.name:SetSize(36, 10)
	button.name:SetPoint("BOTTOM", 0, 2)
	
	local icon = button:CreateTexture()
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER", 0, -1)
	button.icon = icon
	button:SetNormalTexture(icon)
	button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
	button:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(45, 45)
	bg:SetPoint("CENTER", 0, -1)
	bg:SetTexture([[Interface\Buttons\UI-EmptySlot-Disabled]])
	bg:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
	
	button.hotKey = button:CreateFontString(nil, nil, "NumberFontNormalSmallGray")--, 2)
	button.hotKey:SetSize(36, 10)
	button.hotKey:SetPoint("TOPLEFT", 1, -3)
	button.hotKey:SetJustifyH("RIGHT")
	
	return button
end

local NUM_BUTTONS = 12
local GRID_WIDTH = 3

local buttons = {}

for i = 1, NUM_BUTTONS do
	local button = createButton()
	-- button:SetID(i)
	if i == 1 then
		button:SetPoint("TOPLEFT", 18, -72)
	elseif i % GRID_WIDTH == 1 then
		button:SetPoint("TOP", buttons[i - GRID_WIDTH], "BOTTOM", 0, -8)
	else
		button:SetPoint("LEFT", buttons[i - 1], "RIGHT", 10, 0)
	end
	buttons[i] = button
end

local getTexture = {
	SPELL = GetSpellTexture,
	ITEM = GetItemIcon,
	MACRO = function(data)
		return select(2, GetMacroInfo(data))
	end,
}

function addon:UPDATE_BINDINGS()
	list = {}
	for i, scope in ipairs(datatypes) do
		if self:IsScopeUsed(scope) then
			for k, v in pairs(self.db[scope].actions) do
				tinsert(list, k)
			end
		end
	end
	sort(list)
	scrollFrame:update()
	
	for i = 1, NUM_BUTTONS do
		local button = buttons[i]
		button.hotKey:SetText(i)
		local binding = GetBindingByKey("F"..i)
		button.name:SetText(GetSpellInfo((select(2, GetActionInfo(i)))))
		button.icon:SetTexture(GetActionTexture(i))
	end
end

function addon:GetBindingKey(action2)
	for i = #self.db.global.scopes, 1, -1 do
		for key, action in pairs(self.db[self.db.global.scopes[i]].bindings) do
			if action == action2 then
				return key
			end
		end
	end
	return GetBindingKey(action2)
end

function addon:ClearBinding(action2)
	for key, action in pairs(addon.db.global.bindings) do
		if action == action2 then
			addon.db.global.bindings[key] = nil
			SetOverrideBinding(frame, nil, key, nil)
		end
	end
end