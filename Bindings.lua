local addonName, addon = ...

local widgetIndex = 1
local function getWidgetName()
	local name = addonName.."Widget"..widgetIndex
	widgetIndex = widgetIndex + 1
	return name
end

local currentKey, currentAction, currentScope, previousScope
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
		addon:AddBinding(nil, action, self.scope or "global")
		Bindings:UpdateList()
	end
	ClearCursor()
end

-- local new = CreateFrame("Button", "SpellBindingAddBinding", Bindings, "UIMenuButtonStretchTemplate")
-- new:SetWidth(40)
-- new:SetPoint("LEFT", button, "RIGHT", -6, 2)
-- new:SetText("Add")
-- new:SetScript("OnClick", function()
-- end)

local overlay = addon:CreateBindingOverlay(Bindings)
overlay.OnAccept = function(self)
	if not currentKey then
		-- return
	end
	if previousScope ~= currentScope then
		-- local key = addon:GetBindingKey(currentAction)
		-- if not key or key == currentKey then
			addon:ClearBinding(currentAction, previousScope)
			addon:GetActions(previousScope)[currentAction] = nil
		-- end
	end
	addon:AddBinding(currentKey, currentAction, currentScope)
end
overlay.OnBinding = function(self, keyPressed)
	currentKey = keyPressed
	self:SetBindingText(addon:GetActionInfo(currentAction), keyPressed)
	local previousAction = currentKey and GetBindingByKey(currentKey)
	if previousAction and previousAction ~= currentAction then
		local name, _, type = addon:GetActionInfo(previousAction)
		self.replace:SetFormattedText("Will replace %s.", name)
	else
		self.replace:SetText()
	end
end
overlay:SetScript("OnShow", function(self)
	currentKey = addon:GetBindingKey(currentAction)
	self:SetBindingText(addon:GetActionInfo(currentAction), currentKey)
end)
overlay:SetScript("OnHide", function(self)
	currentKey = nil
end)

overlay.replace = overlay:CreateFontString(nil, nil, "GameFontNormal")
overlay.replace:SetPoint("CENTER", 0, -48)
overlay.replace:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)

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

do
	local BUTTON_HEIGHT = 18
	local BUTTON_OFFSET = 2
	
	local options = {
		-- {
			-- text = "Add binding",
			-- func = function(self, action)
				-- addon:ClearBinding(action)
				-- addon:Update()
			-- end,
		-- },
		{
			text = "Unbind",
			func = function(self, action, scope)
				addon:ClearBinding(action, scope)
				Bindings:UpdateList()
			end,
		},
		{
			text = "Remove",
			func = function(self, action, scope)
				addon:ClearBinding(action, scope)
				addon.db[scope].actions[action] = nil
				Bindings:UpdateList()
			end,
		},
	}
	
	local menu = CreateFrame("Frame")
	menu.displayMode = "MENU"
	menu.initialize = function(self)
		local button = UIDROPDOWNMENU_MENU_VALUE
		for i, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.text
			info.func = option.func
			info.arg1 = button.binding
			info.arg2 = button.scope
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
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
			previousScope = self.scope
			currentScope = self.scope
			UIDropDownMenu_SetText(scope, addon:GetScopeLabel(currentScope))
			overlay:Show()
		else
			ToggleDropDownMenu(nil, self, menu, self, 0, 0)
		end
	end
	
	local function onEnter(self)
		if self.isHeader then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 28, 0)
		GameTooltip:AddLine(addon:GetActionLabel(self.binding), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddLine(GetBindingText(addon:GetBindingKey(self.binding), "KEY_"))
		GameTooltip:Show()
		self.showingTooltip = true
	end

	local function createButton(frame)
		local button = CreateFrame("Button", nil, frame)
		button:SetHeight(BUTTON_HEIGHT)
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
		
		button.label = button:CreateFontString(nil, nil, "GameFontHighlightLeft")
		button:SetFontString(button.label)
		-- button.label = button:CreateFontString(nil, nil, "GameFontNormal")
		-- button.label:SetWordWrap(false)
		local label = button.label
		-- label:SetJustifyH("LEFT")
		-- label:SetJustifyV("TOP")
		-- label:SetPoint("TOP", 0, -1)
		-- label:SetPoint("LEFT", button.icon, "TOPRIGHT", 4, 0)
		-- label:SetPoint("RIGHT", -21, 0)
		-- label:SetPoint("BOTTOM", 0, 3)
		
		button.info = button:CreateFontString(nil, nil, "GameFontHighlightSmallRight")
		button.info:SetPoint("RIGHT", -3, 0)
		label:SetPoint("RIGHT", button.info, "LEFT")
		
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
			button.label:SetText(addon:GetScopeLabel(object.scope))
			
			button:SetNormalFontObject(GameFontNormal)
			button:EnableDrawLayer("BACKGROUND")
			button:SetHighlightTexture(nil)
			button.info:SetText("")
			button.icon:SetTexture("")
			button.label:SetPoint("LEFT", 11, 0)
		else
			local binding = object
			local name, texture, type = addon:GetActionInfo(binding.action)
			button.label:SetText(addon:GetActionLabel(binding.action))
			button.info:SetText(GetBindingText(addon:GetBindingKey(binding.action) or NOT_BOUND, "KEY_"))
			button.icon:SetTexture(texture)
			
			button:SetNormalFontObject(GameFontHighlight)
			button:DisableDrawLayer("BACKGROUND")
			button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
			button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
		end
		button.binding = object.action
		button.scope = object.scope
		button.isHeader = isHeader
		
		if GameTooltip:IsOwned(button) then
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
			if next(addon:GetActions(scope)) then
				tinsert(list, {
					scope = scope,
				})
			end
			for action in pairs(addon:GetActions(scope)) do
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