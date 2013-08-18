local addonName, addon = ...

local Custom = addon:NewModule("Custom")

local currentKey, currentIndex

local function onValueChanged(self, value, isUserInput)
	self.currentValue:SetText(value)
	if not isUserInput then return end
	Custom.db.global[self.setting] = value
	Custom:UpdateGrid()
end

local function createSlider(name, maxValue)
	local slider = CreateFrame("Slider", name, Custom, "OptionsSliderTemplate")
	_G[name] = nil
	slider:SetWidth(96)
	slider:SetScript("OnValueChanged", onValueChanged)
	slider:SetMinMaxValues(1, maxValue)
	slider:SetValueStep(1)
	slider.label = _G[name.."Text"]
	_G[name.."Low"]:SetText(1)
	_G[name.."High"]:SetText(maxValue)
	-- slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", -4, 0)
	slider.currentValue = slider:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	slider.currentValue:SetPoint("CENTER", 0, -12)
	return slider
end

local rowsSlider = createSlider(addonName.."GridRows", 8)
rowsSlider:SetPoint("TOPLEFT", 16, -36)
rowsSlider.setting = "gridRows"
rowsSlider.label:SetText("Rows")

local columnsSlider = createSlider(addonName.."GridColumns", 7)
columnsSlider:SetPoint("LEFT", rowsSlider, "RIGHT", 16, 0)
columnsSlider.setting = "gridColumns"
columnsSlider.label:SetText("Columns")

local overlay = addon:CreateBindingOverlay(Custom)
overlay.OnAccept = function(self)
	Custom.db.global.keys[currentIndex] = currentKey
	Custom:UpdateCustomBindings()
end
overlay.OnBinding = function(self, keyPressed)
	self:SetBindingKeyText(keyPressed)
	currentKey = keyPressed
end
overlay:SetScript("OnShow", function(self)
	self:SetBindingActionText("Button "..currentIndex)
	self:SetBindingKeyText(Custom.db.global.keys[currentIndex])
end)
overlay:SetScript("OnHide", function(self)
	currentKey = nil
end)

local function onClick(self, key, action)
	addon:SetPrimaryBinding(action, self.value, key)
end

local selectScopeMenu = CreateFrame("Frame")
selectScopeMenu.displayMode = "MENU"
selectScopeMenu.xOffset = 0
selectScopeMenu.yOffset = 0
selectScopeMenu.initialize = function(self)
	local info = UIDropDownMenu_CreateInfo()
	info.text = "Select scope"
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	
	local currentAction, activeScope = addon:GetConflictState(self.key)
	
	for i, scope in ipairs(addon.db.global.scopes) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = addon:GetScopeLabel(scope)
		info.value = scope
		info.func = onClick
		info.arg1 = self.key
		info.arg2 = self.action
		info.notCheckable = true
		if currentAction then
			local conflict, color = addon:GetConflictText(activeScope, scope)
			info.colorCode = color
			info.tooltipTitle = format(conflict, addon:GetActionLabel(currentAction))
			-- info.tooltipText = format(conflict, currentAction)
			info.tooltipOnButton = true
		end
		UIDropDownMenu_AddButton(info)
	end
end

local function dropAction(self, button)
	-- button is always nil OnReceiveDrag, should never be nil OnClick
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
		selectScopeMenu.key = Custom.db.global.keys[self:GetID()]
		selectScopeMenu.action = action
		HideDropDownMenu(1)
		ToggleDropDownMenu(nil, nil, selectScopeMenu, self)
	end
	ClearCursor()
end

local options = {
	{
		text = "Set key",
		func = function(self, index)
			currentIndex = index
			overlay:Show()
		end,
	},
	{
		text = "Remove key",
		func = function(self, index)
			Custom.db.global.keys[index] = nil
			Custom:UpdateCustomBindings()
		end,
	},
}

local menu = CreateFrame("Frame")
menu.displayMode = "MENU"
menu.initialize = function(self)
	local index = UIDROPDOWNMENU_MENU_VALUE
	for i, option in ipairs(options) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = option.text
		info.func = option.func
		info.arg1 = index
		info.notCheckable = true
		UIDropDownMenu_AddButton(info)
	end
end

local function onClick(self, button)
	if GetCursorInfo() then
		dropAction(self, button)
		return
	end
	if button == "LeftButton" then
		-- currentIndex = self:GetID()
		-- overlay:Show()
	else
		ToggleDropDownMenu(nil, self:GetID(), menu, self, 0, 0)
	end
end

local function onEnter(self)
	if not self.binding then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	addon:ListBindingKeys(self.binding)
end

local buttons = {}

local function createButton()
	local button = CreateFrame("CheckButton", nil, Custom)
	button:SetSize(36, 36)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnReceiveDrag", dropAction)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
	
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(45, 45)
	bg:SetPoint("CENTER", 0, -1)
	bg:SetTexture([[Interface\Buttons\UI-EmptySlot-Disabled]])
	bg:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
	
	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
	button.name:SetSize(36, 10)
	button.name:SetPoint("BOTTOM", 0, 2)
	
	button.icon = button:CreateTexture()
	button.icon:SetSize(36, 36)
	button.icon:SetPoint("CENTER", 0, -1)
	
	button.hotKey = button:CreateFontString(nil, nil, "NumberFontNormalSmallGray")
	button.hotKey:SetSize(36, 10)
	button.hotKey:SetPoint("TOPLEFT", 1, -3)
	button.hotKey:SetJustifyH("RIGHT")
	
	return button
end

local defaults = {
	global = {
		keys = {},
		-- hiddenButtons = {},
		gridRows = 4,
		gridColumns = 3,
	}
}

function Custom:OnInitialize()
	self.UPDATE_BINDINGS = self.UpdateCustomBindings
	
	self.db = addon.db:RegisterNamespace("Custom", defaults)
	
	rowsSlider:SetValue(self.db.global.gridRows)
	columnsSlider:SetValue(self.db.global.gridColumns)
	
	self:UpdateGrid()
end

local XPADDING = 10
local YPADDING = 8

function Custom:UpdateGrid()
	local gridRows = self.db.global.gridRows
	local gridColumns = self.db.global.gridColumns
	local numButtons = gridRows * gridColumns
	for i = 1, numButtons do
		local button = buttons[i] or createButton()
		button:SetID(i)
		button:Show()
		if i == 1 then
			-- position the grid in the center of the frame
			local gridWidth = gridColumns * (button:GetWidth() + XPADDING) - XPADDING
			local gridHeight = gridRows * (button:GetHeight() + YPADDING) - YPADDING
			button:SetPoint("TOPLEFT", Custom.Inset, "CENTER", -gridWidth / 2, gridHeight / 2)
		elseif (i % gridColumns == 1) or (gridColumns == 1) then
			button:SetPoint("TOPLEFT", buttons[i - gridColumns], "BOTTOMLEFT", 0, -YPADDING)
		else
			button:SetPoint("TOPLEFT", buttons[i - 1], "TOPRIGHT", XPADDING, 0)
		end
		buttons[i] = button
	end
	for i = numButtons + 1, #buttons do
		buttons[i]:Hide()
	end
end

function Custom:UpdateCustomBindings()
	for i = 1, self.db.global.gridRows * self.db.global.gridColumns do
		local button = buttons[i]
		local key = self.db.global.keys[i]
		button.hotKey:SetText(GetBindingText(key, "KEY_"))
		local binding = key and GetBindingByKey(key)
		local name, texture = addon:GetActionInfo(binding)
		button.name:SetText(name)
		button.icon:SetTexture(texture)
		button.binding = addon:GetActionStringReverse(binding)
	end
end