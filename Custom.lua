local _, SpellBinding = ...

local Custom = SpellBinding:NewModule("Custom", CreateFrame("Frame"))

local currentKey, currentIndex

local function onValueChanged(self, value, isUserInput)
	self.currentValue:SetText(value)
	if not isUserInput then return end
	Custom.db.global[self.setting] = value
	Custom:UpdateGrid()
end

local function createSlider(maxValue)
	local slider = SpellBinding:CreateSlider(Custom)
	slider:SetWidth(96)
	slider.min:ClearAllPoints()
	slider.min:SetPoint("LEFT", -12, 0)
	slider.max:ClearAllPoints()
	slider.max:SetPoint("RIGHT", 12, 0)
	slider.currentValue:ClearAllPoints()
	slider.currentValue:SetPoint("LEFT", slider.label, "RIGHT")
	slider.currentValue:SetFontObject("GameFontHighlight")
	slider:SetMinMaxValues(1, maxValue)
	slider:SetValueStep(1)
	slider.min:SetText(1)
	slider.max:SetText(maxValue)
	slider:SetScript("OnValueChanged", onValueChanged)
	return slider
end

local rowsSlider = createSlider(8)
rowsSlider:SetPoint("TOPLEFT", 40, -40)
rowsSlider.setting = "gridRows"
rowsSlider.label:SetText("Rows: ")

local columnsSlider = createSlider(7)
columnsSlider:SetPoint("TOPRIGHT", -40, -40)
columnsSlider.setting = "gridColumns"
columnsSlider.label:SetText("Columns: ")

local overlay = SpellBinding:CreateBindingOverlay(Custom)
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

local hintClose = overlay:CreateFontString(nil, nil, "GameFontDisable")
hintClose:SetPoint("CENTER", 0, -48)
hintClose:SetText("Press Escape to cancel")

local function onClick(self, key, action)
	SpellBinding:SetPrimaryBinding(action, self.value, key)
end

local selectSetMenu = SpellBinding:CreateDropdown("Menu")
selectSetMenu.xOffset = 0
selectSetMenu.yOffset = 0
selectSetMenu.initialize = function(self)
	local info = UIDropDownMenu_CreateInfo()
	info.text = "Select set"
	info.isTitle = true
	info.notCheckable = true
	self:AddButton(info)
	
	local currentAction, activeSet = SpellBinding:GetConflictState(self.key)
	
	local sets = SpellBinding.db.global.sets
	for i = #sets, 1, -1 do
		local set = sets[i]
		local info = UIDropDownMenu_CreateInfo()
		info.text = SpellBinding:GetSetName(set)
		info.value = set
		info.func = onClick
		info.arg1 = self.key
		info.arg2 = self.action
		info.notCheckable = true
		if currentAction then
			local conflict, color = SpellBinding:GetConflictText(activeSet, set)
			info.colorCode = color
			info.tooltipTitle = format(conflict, SpellBinding:GetActionLabel(currentAction))
			-- info.tooltipText = format(conflict, currentAction)
			info.tooltipOnButton = true
		end
		self:AddButton(info)
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
		selectSetMenu.key = Custom.db.global.keys[self:GetID()]
		selectSetMenu.action = action
		HideDropDownMenu(1)
		selectSetMenu:Toggle(nil, self)
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

local menu = SpellBinding:CreateDropdown("Menu")
menu.xOffset = 0
menu.yOffset = 0
menu.initialize = function(self)
	local index = UIDROPDOWNMENU_MENU_VALUE
	for i, option in ipairs(options) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = option.text
		info.func = option.func
		info.arg1 = index
		info.notCheckable = true
		self:AddButton(info)
	end
end

local function onClick(self, button)
	if GetCursorInfo() then
		dropAction(self, button)
		return
	end
	-- if button == "LeftButton" then
		-- currentIndex = self:GetID()
		-- overlay:Show()
	-- else
	if self:GetID() ~= UIDROPDOWNMENU_MENU_VALUE then
		menu:Close()
	end
		menu:Toggle(self:GetID(), self)
	-- end
end

local function onEnter(self)
	if not self.binding then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	SpellBinding:ListBindingKeys(self.binding)
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
	
	self.db = SpellBinding.db:RegisterNamespace("Custom", defaults)
	
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
		local name, texture = SpellBinding:GetActionInfo(binding)
		button.name:SetText(name)
		button.icon:SetTexture(texture)
		button.binding = SpellBinding:GetActionStringReverse(binding) or binding
	end
end