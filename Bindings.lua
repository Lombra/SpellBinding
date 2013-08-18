local addonName, addon = ...

local widgetIndex = 1
local function getWidgetName()
	local name = addonName.."Widget"..widgetIndex
	widgetIndex = widgetIndex + 1
	return name
end

local currentKey, currentAction, currentScope, newScope, isSecondary
local list

local Bindings = addon:NewModule("Bindings")

Bindings:EnableMouse(true)
Bindings:SetScript("OnMouseUp", dropAction)
Bindings:SetScript("OnReceiveDrag", dropAction)

local function dropAction(self, button)
	if button == "LeftButton" or not button then
		local action
		local type, data, subType, subData = GetCursorInfo()
		if type == "item" then
			action = "ITEM item:"..data
		elseif type == "spell" then
			action = "SPELL "..subData
		elseif type == "macro" then
			action = "MACRO "..GetMacroInfo(data)
		end
		addon:SetPrimaryBinding(action, self.scope or "global")
		Bindings:UpdateList()
	end
	ClearCursor()
end

do	-- click binding
	local currentFocus
	
	local clickBind = addon:CreateOverlay(Bindings)
	
	local info = clickBind:CreateFontString(nil, nil, "GameFontNormal")
	info:SetPoint("CENTER", 0, 24)
	info:SetText("Press Escape to cancel")
	
	local mouseButtons = {
		"LeftButton",
		"RightButton",
		"MiddleButton",
	}
	
	local mouseFocusOverlay = CreateFrame("Frame", nil, UIParent)
	mouseFocusOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
	mouseFocusOverlay:SetBackdrop({
		bgFile = [[Interface\Buttons\WHITE8X8]],
		edgeFile = [[Interface\Buttons\WHITE8X8]],
		edgeSize = 2,
	})
	mouseFocusOverlay:SetBackdropColor(1, 1, 1, 0.2)
	mouseFocusOverlay:Hide()
	
	local function cancelFrameSelection()
		clickBind:Hide()
		mouseFocusOverlay:Hide()
	end
	
	clickBind:SetScript("OnUpdate", function(self)
		local focus = GetMouseFocus()
		local focusName = focus and focus:GetName()
		local isButton = focus and focus:IsObjectType("Button")
		local isValid = focusName and isButton
		
		if focus ~= currentFocus then
			currentFocus = focus
			mouseFocusOverlay:SetAllPoints(focus)
			local isWorldFrame = focus == WorldFrame
			mouseFocusOverlay:SetShown(not isWorldFrame)
			if isWorldFrame then
				self.text:SetText("Select frame")
				self.text:SetFontObject("GameFontHighlightLarge")
			else
				if isValid then
					self.text:SetText(focusName)
					self.text:SetFontObject("GameFontHighlightLarge")
					mouseFocusOverlay:SetBackdropBorderColor(0, 1, 0)
				else
					if not focusName then
						self.text:SetText("Frame is unnamed")
					elseif not isButton then
						self.text:SetText(focusName.." is not a button")
					end
					self.text:SetFontObject("GameFontRedLarge")
					mouseFocusOverlay:SetBackdropBorderColor(1, 0, 0)
				end
			end
		end
		if isValid then
			for i = 1, 31 do
				local button = mouseButtons[i] or "Button"..i
				if IsMouseButtonDown(button) then
					addon:SetPrimaryBinding(format("CLICK %s:%s", currentFocus:GetName(), button), "global")
					Bindings:UpdateList()
					cancelFrameSelection()
					break
				end
			end
		end
	end)
	
	clickBind:SetScript("OnKeyDown", function(self, keyPressed)
		if GetBindingFromClick(keyPressed) == "TOGGLEGAMEMENU" then
			cancelFrameSelection()
		end
	end)

	local new = CreateFrame("Button", "SpellBindingAddBinding", Bindings, "UIMenuButtonStretchTemplate")
	new:SetWidth(80)
	new:SetPoint("TOPLEFT", 8, -32)
	new:SetText("Bind click")
	new:SetScript("OnClick", function()
		clickBind:Show()
	end)
end

local overlay = addon:CreateBindingOverlay(Bindings)
overlay.OnAccept = function(self)
	if newScope ~= currentScope then
		addon:ClearBindings(currentAction, currentScope)
	end
	if isSecondary then
		addon:SetSecondaryBinding(currentAction, newScope, currentKey)
	else
		addon:SetPrimaryBinding(currentAction, newScope, currentKey)
	end
end
overlay.OnBinding = function(self, keyPressed)
	currentKey = keyPressed
	self:SetBindingKeyText(keyPressed)
	local previousAction, activeScope = addon:GetConflictState(currentKey)
	if previousAction and previousAction ~= addon:GetActionString(currentAction) then
		self.replace:SetFormattedText(addon:GetConflictText(activeScope, newScope), addon:GetActionLabel(previousAction, true))
	else
		self.replace:SetText()
	end
end
overlay:SetScript("OnShow", function(self)
	if isSecondary then
		currentKey = addon:GetSecondaryBinding(currentAction, currentScope)
	else
		currentKey = addon:GetPrimaryBinding(currentAction, currentScope)
	end
	self:SetBindingActionText(addon:GetActionLabel(currentAction))
	self:SetBindingKeyText(currentKey ~= true and currentKey)
	self.replace:SetText()
end)
overlay:SetScript("OnHide", function(self)
	currentKey = nil
	isSecondary = nil
end)

overlay.replace = overlay:CreateFontString(nil, nil, "GameFontNormal")
overlay.replace:SetPoint("CENTER", 0, -48)
overlay.replace:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)

local function onClick(self, scope)
	UIDropDownMenu_SetText(self.owner, addon:GetScopeLabel(scope))
	newScope = scope
end

local scopeMenu = CreateFrame("Frame", "SpellBindingSelectScopeMenu", overlay, "UIDropDownMenuTemplate")
UIDropDownMenu_SetWidth(scopeMenu, 128)
UIDropDownMenu_JustifyText(scopeMenu, "LEFT")
scopeMenu:SetPoint("BOTTOMLEFT", 0, 8)
scopeMenu.initialize = function(self)
	for i, v in pairs(addon.db.global.scopes) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = addon:GetScopeLabel(v)
		info.func = onClick
		info.arg1 = v
		info.checked = (v == newScope)
		info.owner = self
		UIDropDownMenu_AddButton(info)
	end
end

local label = scopeMenu:CreateFontString(nil, nil, "GameFontNormalSmall")
label:SetPoint("BOTTOMLEFT", scopeMenu, "TOPLEFT", 16, 3)
label:SetText("Scope")

do
	local BUTTON_HEIGHT = 18
	local BUTTON_OFFSET = 2
	
	local options = {
		{
			text = "Set secondary binding",
			func = function(self, action, scope)
				currentAction = action
				currentScope = scope
				newScope = scope
				isSecondary = true
				scopeMenu:Hide()
				overlay:Show()
			end,
			primary = true,
		},
		{
			text = "Unbind",
			func = function(self, action, scope)
				addon:ClearBindings(action, scope)
				addon:ApplyBindings()
			end,
		},
		{
			text = "Unbind primary binding",
			func = function(self, action, scope)
				addon:ClearBinding(action, scope)
				addon:ApplyBindings()
			end,
			secondary = true,
		},
		{
			text = "Unbind secondary binding",
			func = function(self, action, scope)
				addon:ClearBinding(action, scope, true)
				addon:ApplyBindings()
			end,
			secondary = true,
		},
		{
			text = "Remove",
			func = function(self, action, scope)
				addon:ClearBindings(action, scope)
				addon.db[scope].bindings[action] = nil
				addon:ApplyBindings()
			end,
		},
	}
	
	local menu = CreateFrame("Frame")
	menu.displayMode = "MENU"
	menu.initialize = function(self)
		local button = UIDROPDOWNMENU_MENU_VALUE
		local key1, key2 = addon:GetBindings(button.binding, button.scope)
		
		for i, option in ipairs(options) do
			if (not option.primary or key1) and (not option.secondary or key2) then
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.text
			info.func = option.func
			info.arg1 = button.binding
			info.arg2 = button.scope
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
			end
		end
	end
	
	local function onClick(self, button)
		if GetCursorInfo() then
			dropAction(self, button)
			return
		end
		if self.isHeader then return end
		if button == "LeftButton" then
			currentAction = self.binding
			currentScope = self.scope
			newScope = self.scope
			UIDropDownMenu_SetText(scopeMenu, addon:GetScopeLabel(currentScope))
			scopeMenu:Show()
			overlay:Show()
		else
			ToggleDropDownMenu(nil, self, menu, self, 0, 0)
		end
	end
	
	local function onEnter(self)
		if self.isHeader then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 28, 0)
		addon:ListBindingKeys(self.binding)
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
		button:SetScript("OnReceiveDrag", dropAction)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:SetPushedTextOffset(0, 0)

		button.icon = button:CreateTexture()
		button.icon:SetPoint("LEFT", 3, 0)
		button.icon:SetSize(16, 16)
		
		button.info = button:CreateFontString(nil, nil, "GameFontHighlightSmallRight")
		button.info:SetPoint("RIGHT", -3, 0)
		
		button.label = button:CreateFontString()
		button.label:SetPoint("RIGHT", button.info, "LEFT", -4, 0)
		button.label:SetJustifyH("LEFT")
		
		local left = button:CreateTexture(nil, "BACKGROUND")
		left:SetPoint("LEFT")
		left:SetSize(76, 16)
		left:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		left:SetTexCoord(0.17578125, 0.47265625, 0.29687500, 0.54687500)
		
		local right = button:CreateTexture(nil, "BACKGROUND")
		right:SetPoint("RIGHT")
		right:SetSize(76, 16)
		right:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		right:SetTexCoord(0.17578125, 0.47265625, 0.01562500, 0.26562500)
		
		local middle = button:CreateTexture(nil, "BACKGROUND")
		middle:SetPoint("LEFT", left, "RIGHT", -20, 0)
		middle:SetPoint("RIGHT", right, "LEFT", 20, 0)
		middle:SetHeight(16)
		middle:SetTexture([[Interface\Buttons\CollapsibleHeader]])
		middle:SetTexCoord(0.48046875, 0.98046875, 0.01562500, 0.26562500)
		
		return button
	end
	
	local function updateButton(button, object)
		local isHeader = not object.action
		if isHeader then
			button:EnableDrawLayer("BACKGROUND")
			button:SetHighlightTexture(nil)
			button.label:SetFontObject(GameFontNormal)
			button.label:SetPoint("LEFT", 11, 0)
			button.info:SetText("")
			button.icon:SetTexture("")
			
			button.label:SetText(addon:GetScopeLabel(object.scope))
		else
			button:DisableDrawLayer("BACKGROUND")
			button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
			button.label:SetFontObject(GameFontHighlight)
			button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
			
			local name, texture, type = addon:GetActionInfo(object.action)
			button.label:SetText(addon:GetActionLabel(object.action))
			button.info:SetText(GetBindingText(addon:GetBindingKey(object.action) or NOT_BOUND, "KEY_"))
			button.icon:SetTexture(texture)
		end
		button.binding = object.action
		button.scope = object.scope
		button.isHeader = isHeader
		
		if button.showingTooltip then
			if isHeader then
				GameTooltip:Hide()
			else
				onEnter(button)
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
		
		HybridScrollFrame_Update(self, #list * self.buttonHeight, numButtons * self.buttonHeight)
	end
	
	local name = getWidgetName()
	scrollFrame = CreateFrame("ScrollFrame", name, Bindings, "HybridScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", Bindings.Inset, 4, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", Bindings.Inset, -23, 4)
	scrollFrame:SetScript("OnMouseUp", dropAction)
	scrollFrame:SetScript("OnReceiveDrag", dropAction)
	scrollFrame.update = function()
		update(scrollFrame)
	end
	_G[name] = nil
	
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
			button:SetPoint("TOPLEFT", 2, -1)
		else
			button:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, -BUTTON_OFFSET)
		end
		buttons[i] = button
	end
	
	HybridScrollFrame_CreateButtons(scrollFrame, nil, nil, nil, nil, nil, nil, -BUTTON_OFFSET)
end

local customSort = {}
addon.scopePriority = customSort

-- reverse the tables for easier use
function addon:UpdateSortOrder()
	wipe(customSort)
	for i, v in ipairs(self.db.global.scopes) do
		customSort[v] = i
	end
end

local function listSort(a, b)
	if a.scope == b.scope then
		if not a.action and b.action then return true end
		if not addon:GetActionInfo(a.action) then if a.action then print(a.action) end return end
		if not addon:GetActionInfo(b.action) then if b.action then print(b.action) end return end
		return addon:GetActionInfo(a.action) < addon:GetActionInfo(b.action)
	else
		return customSort[a.scope] < customSort[b.scope]
	end
end

local usedActions = {}

function Bindings:UpdateList()
	list = {}
	wipe(usedActions)
	local scopes = addon.db.global.scopes
	for i = #scopes, 1, -1 do
		local scope = scopes[i]
		if addon:IsScopeUsed(scope) then
			local bindings = addon:GetBindingsForScope(scope)
			if next(bindings) then
				tinsert(list, {
					scope = scope,
				})
			end
			for action in pairs(bindings) do
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

Bindings.UPDATE_BINDINGS = Bindings.UpdateList