local _, SpellBinding = ...

local newKey, currentAction, currentSet, newSet, isSecondary
local list

local Bindings = SpellBinding:NewModule("Bindings", CreateFrame("Frame"))

Bindings:EnableMouse(true)
Bindings:SetScript("OnMouseUp", dropAction)
Bindings:SetScript("OnReceiveDrag", dropAction)

local hintNoBindings = Bindings:CreateFontString(nil, nil, "GameFontNormalMed3")
hintNoBindings:SetPoint("CENTER", Bindings.Inset)
hintNoBindings:SetText("Drag something here to bind it")

local function dropAction(self, button)
	if button == "LeftButton" or not button then
		local action = SpellBinding:GetActionStringFromCursor()
		if not action then
			return
		end
		-- if dropped on empty space, use lowest priority active set
		SpellBinding:SetPrimaryBinding(action, self.set)
		Bindings:UpdateList()
	end
	ClearCursor()
end

do	-- click binding
	local currentFocus

	local clickBind = SpellBinding:CreateOverlay(Bindings)

	local info = clickBind:CreateFontString(nil, nil, "GameFontNormal")
	info:SetPoint("CENTER", 0, 48)
	info:SetText("Click a button frame")

	local hintClose = clickBind:CreateFontString(nil, nil, "GameFontDisable")
	hintClose:SetPoint("CENTER")
	hintClose:SetText("Press Escape to cancel")

	local mouseButtons = {
		"LeftButton",
		"RightButton",
		"MiddleButton",
	}

	local mouseFocusOverlay = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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
		local foci = GetMouseFoci()
		local focus = foci and foci[1]
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
					SpellBinding:SetPrimaryBinding(format("CLICK %s:%s", currentFocus:GetName(), button))
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

	local bindClickButton = SpellBinding:CreateButton(Bindings)
	bindClickButton:SetWidth(80)
	bindClickButton:SetPoint("TOPLEFT", 16, -32)
	bindClickButton:SetText("Bind click")
	bindClickButton:SetScript("OnClick", function()
		clickBind:Show()
	end)
	bindClickButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Bind the clicking of a button frame")
	end)
	bindClickButton:SetScript("OnLeave", GameTooltip_Hide)
end

local overlay = SpellBinding:CreateBindingOverlay(Bindings)
overlay.OnAccept = function(self)
	if newSet ~= currentSet then
		SpellBinding:ClearBindings(currentAction, currentSet)
		SpellBinding.db[currentSet].bindings[currentAction] = nil
	end
	if isSecondary then
		SpellBinding:SetSecondaryBinding(currentAction, newSet, newKey)
	else
		SpellBinding:SetPrimaryBinding(currentAction, newSet, newKey)
	end
end
overlay.OnBinding = function(self, keyPressed)
	newKey = keyPressed
	self:SetBindingKeyText(keyPressed)
	local activeAction, activeSet = SpellBinding:GetActiveActionForKey(newKey)
	local text1, text2 = SpellBinding:GetConflictText(newKey, currentAction, newSet, activeAction, activeSet)
	if not text1 then
		text1 = text2
		text2 = nil
	end
	self.conflict1:SetText(text1)
	self.conflict2:SetText(text2)
end
overlay:SetScript("OnShow", function(self)
	if isSecondary then
		newKey = SpellBinding:GetSecondaryBinding(currentAction, currentSet)
	else
		newKey = SpellBinding:GetPrimaryBinding(currentAction, currentSet)
	end
	self:SetBindingActionText(SpellBinding:GetActionLabel(currentAction))
	self:SetBindingKeyText(newKey ~= true and newKey)
	self.conflict1:SetText()
	self.conflict2:SetText()
end)
overlay:SetScript("OnHide", function(self)
	newKey = nil
	isSecondary = nil
end)

overlay.conflict1 = overlay:CreateFontString(nil, nil, "GameFontNormal")
overlay.conflict1:SetPoint("CENTER", 0, -48)

overlay.conflict2 = overlay:CreateFontString(nil, nil, "GameFontNormal")
overlay.conflict2:SetPoint("CENTER", 0, -72)

local function onClick(self, set)
	self.owner:SetText(SpellBinding:GetSetName(set))
	newSet = set
	if newKey and newKey ~= true then
		overlay:OnBinding(newKey)
	end
end

local setMenu = SpellBinding:CreateDropdown("Frame", overlay)
setMenu:SetWidth(128)
setMenu:SetLabel("Binding set")
setMenu:JustifyText("LEFT")
setMenu:SetPoint("BOTTOMLEFT", 0, 8)
setMenu.initialize = function(self)
	for i, v in SpellBinding:IterateActiveSets() do
		local info = UIDropDownMenu_CreateInfo()
		info.text = SpellBinding:GetSetName(v)
		info.func = onClick
		info.arg1 = v
		info.checked = (v == newSet)
		self:AddButton(info)
	end
end

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

local scrollFrame

do
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
	scrollFrame.getNumItems = function()
		return #list
	end
	scrollFrame.updateButton = function(button, index)
		local object = list[index]
		local isHeader = not object.action
		if isHeader then
			button:EnableDrawLayer("BACKGROUND")
			button:ClearHighlightTexture()
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
			local key1, key2 = SpellBinding:GetBindings(object.action, object.set)
			local key = key1 or key2
			local isInactive = key and C_KeyBindings.GetBindingByKey(key) ~= SpellBinding:GetActionString(object.action)
			local name, texture, type = SpellBinding:GetActionInfo(object.action)
			button.label:SetFontObject(isInactive and GameFontDisable or GameFontHighlight)
			button.label:SetText(SpellBinding:GetActionLabel(object.action, isInactive))
			button.info:SetFontObject((isInactive or not key) and GameFontDisableSmall or GameFontNormalSmall)
			button.info:SetText(GetBindingText(key or NOT_BOUND))
			button.icon:SetTexture(texture)
			button.icon:SetDesaturated(isInactive)
		end
		button.binding = object.action
		button.set = object.set
		button.isHeader = isHeader

		if button:IsMouseMotionFocus() then
			if isHeader then
				GameTooltip:Hide()
			else
				onEnter(button)
			end
		end
	end
	scrollFrame.createButton = function(parent)
		local button = CreateFrame("Button", nil, parent)
		button:SetPoint("RIGHT", -5, 0)
		button:SetScript("OnClick", onClick)
		button:SetScript("OnEnter", onEnter)
		button:SetScript("OnLeave", GameTooltip_Hide)
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
		button.label:SetWordWrap(false)

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
	scrollFrame:CreateButtons()

	local scrollBar = scrollFrame.scrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", Bindings.Inset, 0, -18)
	scrollBar:SetPoint("BOTTOMRIGHT", Bindings.Inset, 0, 16)
	scrollBar.doNotHide = true
end

Bindings:SetScript("OnHide", function(self)
	menu:Close()
end)

function Bindings:OnInitialize()
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("SPELLS_CHANGED", "UpdateScrollFrame")
	self:RegisterEvent("UPDATE_MACROS", "UpdateScrollFrame")
end

function Bindings:PLAYER_REGEN_DISABLED()
	menu:Close()
end

local customSort = {}
SpellBinding.setPriority = customSort

-- reverse the tables for easier use
function SpellBinding:UpdateSortOrder()
	wipe(customSort)
	for i, set in SpellBinding:IterateActiveSets() do
		customSort[set] = i
	end
end

local function listSort(a, b)
	if a.set ~= b.set then
		return customSort[a.set] < customSort[b.set]
	else
		if not a.action and b.action then return true end
		local actionA = SpellBinding:GetActionInfo(a.action)
		local actionB = SpellBinding:GetActionInfo(b.action)
		if not (actionA and actionB) then return end
		return actionA < actionB
	end
end

function Bindings:UpdateList()
	list = {}
	for i, set in SpellBinding:IterateActiveSets() do
		local bindings = SpellBinding:GetBindingsForSet(set)
		if next(bindings) then
			tinsert(list, {
				set = set,
			})
		end
		for action in pairs(bindings) do
			tinsert(list, {
				action = action,
				set = set,
			})
		end
	end
	sort(list, listSort)
	self:UpdateScrollFrame()
	hintNoBindings:SetShown(#list == 0)
end

function Bindings:UpdateScrollFrame()
	scrollFrame:update()
end

Bindings.UPDATE_BINDINGS = Bindings.UpdateList
