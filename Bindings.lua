local _, SpellBinding = ...

local currentKey, currentAction, currentSet, newSet, isSecondary
local list

local Bindings = SpellBinding:NewModule("Bindings", CreateFrame("Frame"))

Bindings:EnableMouse(true)
Bindings:SetScript("OnMouseUp", dropAction)
Bindings:SetScript("OnReceiveDrag", dropAction)

local hintNoBindings = Bindings:CreateFontString(nil, nil, "GameFontNormalMed3")
hintNoBindings:SetPoint("CENTER", Bindings.Inset)
hintNoBindings:SetText("Drag something here to bind it")

local hintNoSets = Bindings:CreateFontString(nil, nil, "GameFontNormalMed3")
hintNoSets:SetPoint("CENTER", Bindings.Inset)
hintNoSets:SetText("No binding sets are active")

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
		local sets = SpellBinding.db.global.sets
		if not action or #sets == 0 then
			return
		end
		-- if dropped on empty space, use lowest priority active set
		SpellBinding:SetPrimaryBinding(action, self.set or sets[1])
		Bindings:UpdateList()
	end
	ClearCursor()
end

do	-- click binding
	local currentFocus
	
	local clickBind = SpellBinding:CreateOverlay(Bindings)
	
	local info = clickBind:CreateFontString(nil, nil, "GameFontNormal")
	info:SetPoint("CENTER", 0, 24)
	info:SetText("Click a button frame")
	
	local hintClose = clickBind:CreateFontString(nil, nil, "GameFontDisable")
	hintClose:SetPoint("CENTER", 0, -24)
	hintClose:SetText("Press Escape to cancel")
	
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
					SpellBinding:SetPrimaryBinding(format("CLICK %s:%s", currentFocus:GetName(), button), "global")
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

	local new = SpellBinding:CreateButton(Bindings)
	new:SetWidth(80)
	new:SetPoint("TOPLEFT", 16, -32)
	new:SetText("Bind click")
	new:SetScript("OnClick", function()
		clickBind:Show()
	end)
	new:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Bind the clicking of a button frame")
	end)
	new:SetScript("OnLeave", GameTooltip_Hide)
end

local overlay = SpellBinding:CreateBindingOverlay(Bindings)
overlay.OnAccept = function(self)
	if newSet ~= currentSet then
		SpellBinding:ClearBindings(currentAction, currentSet)
		SpellBinding.db[currentSet].bindings[currentAction] = nil
	end
	if isSecondary then
		SpellBinding:SetSecondaryBinding(currentAction, newSet, currentKey)
	else
		SpellBinding:SetPrimaryBinding(currentAction, newSet, currentKey)
	end
end
overlay.OnBinding = function(self, keyPressed)
	currentKey = keyPressed
	self:SetBindingKeyText(keyPressed)
	local previousAction, activeSet = SpellBinding:GetConflictState(currentKey)
	if previousAction and previousAction ~= SpellBinding:GetActionString(currentAction) then
		self.replace:SetFormattedText(SpellBinding:GetConflictText(activeSet, newSet), SpellBinding:GetActionLabel(previousAction, true))
	else
		self.replace:SetText()
	end
end
overlay:SetScript("OnShow", function(self)
	if isSecondary then
		currentKey = SpellBinding:GetSecondaryBinding(currentAction, currentSet)
	else
		currentKey = SpellBinding:GetPrimaryBinding(currentAction, currentSet)
	end
	self:SetBindingActionText(SpellBinding:GetActionLabel(currentAction))
	self:SetBindingKeyText(currentKey ~= true and currentKey)
	self.replace:SetText()
end)
overlay:SetScript("OnHide", function(self)
	currentKey = nil
	isSecondary = nil
end)

overlay.replace = overlay:CreateFontString(nil, nil, "GameFontRed")
overlay.replace:SetPoint("CENTER", 0, -48)

local hintClose = overlay:CreateFontString(nil, nil, "GameFontDisable")
hintClose:SetPoint("CENTER", 0, -72)
hintClose:SetText("Press Escape to cancel")

local function onClick(self, set)
	self.owner:SetText(SpellBinding:GetSetName(set))
	newSet = set
end

local setMenu = SpellBinding:CreateDropdown("Frame", overlay)
setMenu:SetWidth(128)
setMenu:SetLabel("Set")
setMenu:JustifyText("LEFT")
setMenu:SetPoint("BOTTOMLEFT", 0, 8)
setMenu.initialize = function(self)
	for i, v in pairs(SpellBinding.db.global.sets) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = SpellBinding:GetSetName(v)
		info.func = onClick
		info.arg1 = v
		info.checked = (v == newSet)
		self:AddButton(info)
	end
end

local scrollFrame

do
	local options = {
		{
			text = "Set secondary binding",
			func = function(self, action, set)
				currentAction = action
				currentSet = set
				newSet = set
				isSecondary = true
				setMenu:Hide()
				overlay:Show()
			end,
			primary = true,
		},
		{
			text = "Unbind",
			func = function(self, action, set)
				SpellBinding:ClearBindings(action, set)
				SpellBinding:ApplyBindings()
			end,
		},
		{
			text = "Unbind primary binding",
			func = function(self, action, set)
				SpellBinding:ClearBinding(action, set)
				SpellBinding:ApplyBindings()
			end,
			secondary = true,
		},
		{
			text = "Unbind secondary binding",
			func = function(self, action, set)
				SpellBinding:ClearBinding(action, set, true)
				SpellBinding:ApplyBindings()
			end,
			secondary = true,
		},
		{
			text = "Remove",
			func = function(self, action, set)
				SpellBinding:ClearBindings(action, set)
				SpellBinding.db[set].bindings[action] = nil
				SpellBinding:ApplyBindings()
			end,
		},
	}
	
	local menu = SpellBinding:CreateDropdown("Menu")
	menu.xOffset = 0
	menu.yOffset = 0
	menu.initialize = function(self)
		local button = UIDROPDOWNMENU_MENU_VALUE
		local key1, key2 = SpellBinding:GetBindings(button.binding, button.set)
		
		for i, option in ipairs(options) do
			if (not option.primary or key1) and (not option.secondary or key2) then
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.text
				info.func = option.func
				info.arg1 = button.binding
				info.arg2 = button.set
				info.notCheckable = true
				self:AddButton(info)
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
			currentSet = self.set
			newSet = self.set
			setMenu:SetText(SpellBinding:GetSetName(currentSet))
			setMenu:Show()
			overlay:Show()
		else
			menu:Toggle(self, self)
		end
	end
	
	local function onEnter(self)
		if self.isHeader then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 25, 0)
		SpellBinding:ListBindingKeys(self.binding)
		-- GameTooltip:AddLine(" ")
		-- GameTooltip:AddLine("Left click to set binding")
		-- GameTooltip:AddLine("Right click for options")
		GameTooltip:Show()
		self.showingTooltip = true
	end
	
	local function onLeave(self)
		GameTooltip:Hide()
		self.showingTooltip = false
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
			
			button.label:SetText(SpellBinding:GetSetName(object.set))
		else
			button:DisableDrawLayer("BACKGROUND")
			button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
			button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
			
			local key = SpellBinding:GetBindingKey(object.action)
			local isInactive = key and GetBindingByKey(key) ~= SpellBinding:GetActionString(object.action)
			local name, texture, type = SpellBinding:GetActionInfo(object.action)
			button.label:SetFontObject(isInactive and GameFontDisable or GameFontHighlight)
			button.label:SetText(SpellBinding:GetActionLabel(object.action))
			button.info:SetFontObject((isInactive or not key) and GameFontDisableSmall or GameFontNormalSmall)
			button.info:SetText(GetBindingText(key or NOT_BOUND, "KEY_"))
			button.icon:SetTexture(texture)
		end
		button.binding = object.action
		button.set = object.set
		button.isHeader = isHeader
		
		if button.showingTooltip then
			if isHeader then
				GameTooltip:Hide()
			else
				onEnter(button)
			end
		end
	end
	
	scrollFrame = SpellBinding:CreateScrollFrame("Hybrid", Bindings)
	scrollFrame:SetPoint("TOPLEFT", Bindings.Inset, 4, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", Bindings.Inset, -20, 4)
	scrollFrame:SetScript("OnMouseUp", dropAction)
	scrollFrame:SetScript("OnReceiveDrag", dropAction)
	scrollFrame:SetButtonHeight(18)
	scrollFrame.initialOffsetX = 2
	scrollFrame.initialOffsetY = -1
	scrollFrame.offsetY = -2
	scrollFrame.update = function()
		local offset = scrollFrame:GetOffset()
		local buttons = scrollFrame.buttons
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
		
		HybridScrollFrame_Update(scrollFrame, #list * scrollFrame.buttonHeight, numButtons * scrollFrame.buttonHeight)
	end
	scrollFrame.createButton = function(parent)
		local button = CreateFrame("Button", nil, parent)
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
	
	local scrollBar = scrollFrame.scrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", Bindings.Inset, 0, -18)
	scrollBar:SetPoint("BOTTOMRIGHT", Bindings.Inset, 0, 16)
	scrollBar.doNotHide = true
	
	scrollFrame:CreateButtons()
end

local customSort = {}
SpellBinding.setPriority = customSort

-- reverse the tables for easier use
function SpellBinding:UpdateSortOrder()
	wipe(customSort)
	for i, v in ipairs(self.db.global.sets) do
		customSort[v] = i
	end
end

local function listSort(a, b)
	if a.set == b.set then
		if not a.action and b.action then return true end
		if not SpellBinding:GetActionInfo(a.action) then if a.action then print(a.action) end return end
		if not SpellBinding:GetActionInfo(b.action) then if b.action then print(b.action) end return end
		return SpellBinding:GetActionInfo(a.action) < SpellBinding:GetActionInfo(b.action)
	else
		return customSort[a.set] > customSort[b.set]
	end
end

local usedActions = {}

function Bindings:UpdateList()
	list = {}
	wipe(usedActions)
	local sets = SpellBinding.db.global.sets
	for i = #sets, 1, -1 do
		local set = sets[i]
		if SpellBinding:IsSetActive(set) then
			local bindings = SpellBinding:GetBindingsForSet(set)
			if next(bindings) then
				tinsert(list, {
					set = set,
				})
			end
			for action in pairs(bindings) do
				-- don't duplicate if included in more than one set
				if not usedActions[action] then
					tinsert(list, {
						action = action,
						set = set,
					})
					usedActions[action] = true
				end
			end
		end
	end
	sort(list, listSort)
	scrollFrame:update()
	hintNoBindings:SetShown(#sets > 0 and #list == 0)
	hintNoSets:SetShown(#sets == 0)
end

Bindings.UPDATE_BINDINGS = Bindings.UpdateList