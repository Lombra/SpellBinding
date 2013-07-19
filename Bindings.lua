local addonName, addon = ...

local widgetIndex = 1
local function getWidgetName()
	local name = addonName.."Widget"..widgetIndex
	widgetIndex = widgetIndex + 1
	return name
end

local currentKey, currentAction, currentScope
local list

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

local function dropAction()
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
	-- print(type, data, subType, subData)
end

local Bindings = addon:NewModule("Bindings")

Bindings:EnableMouse(true)
Bindings:SetScript("OnMouseUp", dropAction)
Bindings:SetScript("OnReceiveDrag", dropAction)

local function onClick(self, v)
	UIDropDownMenu_SetText(SpellBindingCurrentScopeMenu, addon:GetScopeLabel(v) or v)
	addon:Update()
end

local button = CreateFrame("Frame", "SpellBindingCurrentScopeMenu", Bindings, "UIDropDownMenuTemplate")
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
		info.text = addon:GetScopeLabel(v)
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

local overlay = CreateFrame("Button", nil, Bindings)
overlay:SetAllPoints()
overlay:SetToplevel(true)
overlay:RegisterForClicks("AnyUp")
overlay:Hide()
overlay:SetBackdrop({
	bgFile = [[Interface\Buttons\WHITE8X8]],
	insets = {left = 4, right = 4, top = 21, bottom = 4}
})
overlay:SetBackdropColor(0, 0, 0, 0.7)

local function onBinding(keyPressed)
	if GetBindingFromClick(keyPressed) == "TOGGLEGAMEMENU" then
		overlay:Hide()
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
	
	-- print(GetBindingFromClick(keyPressed), GetBindingText(GetBindingFromClick(keyPressed), "BINDING_NAME_"))
	addon:SetOverlayText(addon:GetActionName(currentAction), GetBindingText(keyPressed, "KEY_"))
	currentKey = keyPressed
end

local handlers = {
	OnKeyDown = function(self, key)
		onBinding(key)
	end,
	OnClick = function(self, button)
		onBinding(button)
	end,
	OnMouseWheel = function(self, delta)
		if delta > 0 then
			onBinding("MOUSEWHEELUP")
		else
			onBinding("MOUSEWHEELDOWN")
		end
	end,
	OnShow = function(self)
		addon:SetOverlayText(addon:GetActionName(currentAction), GetBindingText(addon:GetBindingKey(currentAction) or NOT_BOUND, "KEY_"))
	end,
	OnHide = function(self)
		currentKey = nil
	end,
}

for event, handler in pairs(handlers) do
	overlay:SetScript(event, handler)
end

local info = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal", 1)
info:SetPoint("CENTER", 0, 24)
info:SetText("Press a key to bind")

overlay.actionName = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge", 1)
overlay.actionName:SetPoint("CENTER")

overlay.key = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal", 1)
overlay.key:SetPoint("CENTER", 0, -24)

local function onClick(self, scope)
	UIDropDownMenu_SetText(self.owner, addon:GetScopeLabel(scope))
	currentScope = scope
end

local scope = CreateFrame("Frame", "SpellBindingSelectScopeMenu", overlay, "UIDropDownMenuTemplate")
UIDropDownMenu_SetWidth(scope, 128)
UIDropDownMenu_JustifyText(scope, "LEFT")
scope:SetPoint("BOTTOMLEFT", 0, 8)
scope.initialize = function(self)
	for i, v in pairs(addon.db.global.scopes) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = addon:GetScopeLabel(v)
		info.func = onClick
		info.arg1 = v
		info.checked = (v == currentScope)
		info.owner = self
		UIDropDownMenu_AddButton(info)
	end
end

local label = scope:CreateFontString(nil, nil, "GameFontNormalSmall")
label:SetPoint("BOTTOMLEFT", scope, "TOPLEFT", 16, 3)
label:SetText("Scope")

local OK = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
OK:SetPoint("BOTTOMRIGHT", -16, 16)
OK:SetWidth(80)
OK:SetText(ACCEPT)
OK:SetScript("OnClick", function()
	SetOverrideBinding(Bindings, nil, currentKey, currentAction:gsub("(%d+)$", GetSpellInfo))
	addon.db[currentScope].actions[currentAction] = true
	addon.db[currentScope].bindings[currentKey] = currentAction
	overlay:Hide()
	addon:Update()
end)

do
	local BUTTON_HEIGHT = 18
	local BUTTON_OFFSET = 2
	
	local options = {
		{
			text = "Add binding",
			-- func = function(self, action)
				-- addon:ClearBinding(action)
				-- addon:Update()
			-- end,
		},
		{
			text = "Unbind",
			func = function(self, action)
				addon:ClearBinding(action)
				addon:Update()
			end,
		},
		{
			text = "Remove",
			func = function(self, action)
				addon.db.global.actions[action] = nil
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
			currentScope = self.scope or "global"
			overlay:Show()
		else
			ToggleDropDownMenu(nil, self.binding, menu, self, 0, 0)
		end
	end
	
	local function listBindings(key, ...)
		GameTooltip:AddLine(GetBindingText(key, "KEY_"))
		for i = 1, select("#", ...) do
			GameTooltip:AddLine(GetBindingText(select(i, ...), "KEY_"))
		end
	end
	
	local function onEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 28, 0)
		GameTooltip:AddLine(addon:GetActionName(self.binding))
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
		local isHeader = type(object) ~= "table"
		if isHeader then
			button.label:SetText(object.name)
			button.label:SetFontObject("GameFontNormal")
			button.info:SetText("")
			button.icon:SetTexture("")
		else
			local binding = object
			button.label:SetText("["..addon:GetScopeLabel(binding.scope).."] "..addon:GetActionName(binding.action))
			button.info:SetText(GetBindingText(addon:GetBindingKey(binding.action) or NOT_BOUND, "KEY_"))
			button.icon:SetTexture(addon:GetActionTexture(binding.action))
			button.binding = binding.action
			button.scope = binding.scope
		end
		
		if button.showingTooltip then
			if not isHeader then
				-- GameTooltip:SetItemByID(button.itemID)
			else
				GameTooltip:Hide()
			end
		end
	end
	
	local function update(self)
		local offset = HybridScrollFrame_GetOffset(self)
		local buttons = self.buttons
		local numButtons = #buttons
		for i = 1, numButtons do
			local button = buttons[i]
			local index = offset + i
			local object = list[index]
			if object then
				updateButton(button, object)
			end
			button:SetShown(object ~= nil)
		end
		
		HybridScrollFrame_Update(self, #list * BUTTON_HEIGHT, numButtons * BUTTON_HEIGHT)
	end
	
	local name = getWidgetName()
	scrollFrame = CreateFrame("ScrollFrame", name, Bindings, "HybridScrollFrameTemplate")
	scrollFrame:SetPoint("TOP", Bindings.Inset, 0, -4)
	scrollFrame:SetPoint("LEFT", Bindings.Inset, 4, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", Bindings.Inset, -23, 4)
	scrollFrame.update = function()
		update(scrollFrame)
	end
	_G[name] = nil
	
	scrollFrame:SetScript("OnMouseUp", dropAction)
	scrollFrame:SetScript("OnReceiveDrag", dropAction)
	
	local scrollBar = CreateFrame("Slider", nil, scrollFrame, "HybridScrollBarTemplate")
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOP", Bindings.Inset, 0, -16)
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

local sortPriority = {
	"type",
	"name",
}

local sortAscending = {
	name = true,
	type = true,
}

local function listSort(a, b)
	if a.scope == b.scope then
		return addon:GetActionName(a.action) < addon:GetActionName(b.action)
	else
		return a.scope > b.scope
	end
	-- a, b = items[a], items[b]
	-- if not (a and b) then return end
	-- for i, v in ipairs(sortPriority) do
		-- if a[v] ~= b[v] then
			-- if sortAscending[v] then
				-- a, b = b, a
			-- end
			-- if not (a[v] and b[v]) then
				-- return a[v]
			-- end
			-- return a[v] > b[v]
		-- end
	-- end
end

local usedActions = {}

function addon:Update()
	list = {}
	wipe(usedActions)
	local scopes = self.db.global.scopes
	for i = #scopes, 1, -1 do
		local scope = scopes[i]
		if self:IsScopeUsed(scope) then
			for action in pairs(self.db[scope].actions) do
				-- don't duplicate if included in more than one scope
				if not usedActions[action] then
					tinsert(list, {
						action = action,
						scope = scope,
					})
					usedActions[action] = true
				end
			end
		end
	end
	sort(list, listSort)
	scrollFrame:update()
end

addon.UPDATE_BINDINGS = addon.Update

function addon:SetOverlayText(action, key)
	overlay.actionName:SetFormattedText("%s", action)
	overlay.key:SetFormattedText("%s", key)
end