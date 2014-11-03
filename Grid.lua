local _, SpellBinding = ...

local Grid = SpellBinding:NewModule("Grid", CreateFrame("Frame"))

local currentKey, currentIndex

local function onValueChanged(self, value, isUserInput)
	self.currentValue:SetText(value)
	if not isUserInput then return end
	Grid.db.global[self.setting] = value
	Grid:UpdateGrid()
end

local function createSlider(maxValue)
	local slider = SpellBinding:CreateSlider(Grid)
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

local overlay = SpellBinding:CreateBindingOverlay(Grid)
overlay.OnAccept = function(self)
	Grid.db.global.keys[currentIndex] = currentKey
	Grid:UpdateGridBindings()
end
overlay.OnBinding = function(self, keyPressed)
	self:SetBindingKeyText(keyPressed)
	currentKey = keyPressed
end
overlay:SetScript("OnShow", function(self)
	self:SetBindingActionText("Button "..currentIndex)
	self:SetBindingKeyText(Grid.db.global.keys[currentIndex])
end)
overlay:SetScript("OnHide", function(self)
	currentKey = nil
end)

local function onClick(self, key, action)
	SpellBinding:SetPrimaryBinding(action, self.value, key)
end

local selectSetMenu = SpellBinding:CreateDropdown("Menu")
selectSetMenu.initialize = function(self)
	local info = UIDropDownMenu_CreateInfo()
	info.text = "Select binding set"
	info.isTitle = true
	info.notCheckable = true
	self:AddButton(info)
	
	local activeAction, activeSet = SpellBinding:GetActiveActionForKey(self.key)
	
	for i, set in SpellBinding:IterateActiveSets() do
		local info = UIDropDownMenu_CreateInfo()
		info.text = SpellBinding:GetSetName(set)
		info.value = set
		info.func = onClick
		info.arg1 = self.key
		info.arg2 = self.action
		info.notCheckable = true
		if activeAction then
			info.colorCode = (set == activeSet) and LIGHTYELLOW_FONT_COLOR_CODE
			info.tooltipTitle = format("Bind %s to |cffffd200%s|r (%s)", 
										SpellBinding:GetActionLabel(self.action),
										GetBindingText(self.key),
										SpellBinding:GetSetName(set))
			local text1, text2 = SpellBinding:GetConflictText(self.key, self.action, set, activeAction, activeSet)
			info.tooltipText = (text1 or "").."\n"..(text2 or "")
			info.tooltipLines = true
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
		selectSetMenu.key = self.key
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
			Grid.db.global.keys[index] = nil
			Grid:UpdateGridBindings()
		end,
	},
}

local menu = SpellBinding:CreateDropdown("Menu")
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
	if self:GetID() ~= UIDROPDOWNMENU_MENU_VALUE then
		menu:Close()
	end
	menu:Toggle(self:GetID(), self)
end

local function onEnter(self)
	if not self.action then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(GetBindingText(self.key), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(SpellBinding:GetActionLabel(self.action), SpellBinding:GetSetName(self.set))
	GameTooltip:Show()
end

local buttons = setmetatable({}, {
	__index = function(table, index)
		local button = CreateFrame("CheckButton", nil, Grid)
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
		
		table[index] = button
		return button
	end
})

Grid:SetScript("OnHide", function(self)
	selectSetMenu:Close()
	menu:Close()
end)

local defaults = {
	global = {
		keys = {},
		-- hiddenButtons = {},
		gridRows = 4,
		gridColumns = 3,
	}
}

function Grid:OnInitialize()
	self.UPDATE_BINDINGS = self.UpdateGridBindings
	
	if SpellBinding.db.sv.namespaces and SpellBinding.db.sv.namespaces.Custom then
		SpellBinding.db.sv.namespaces.Grid = SpellBinding.db.sv.namespaces.Custom
		SpellBinding.db.sv.namespaces.Custom = nil
	end
	self.db = SpellBinding.db:RegisterNamespace("Grid", defaults)
	
	rowsSlider:SetValue(self.db.global.gridRows)
	columnsSlider:SetValue(self.db.global.gridColumns)
	
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("SPELLS_CHANGED", "UpdateGridBindings")
	self:RegisterEvent("UPDATE_MACROS", "UpdateGridBindings")
	
	self:UpdateGrid()
end

function Grid:PLAYER_REGEN_DISABLED()
	selectSetMenu:Close()
	menu:Close()
end

local XPADDING = 10
local YPADDING = 8

function Grid:UpdateGrid()
	local gridRows = self.db.global.gridRows
	local gridColumns = self.db.global.gridColumns
	local numButtons = gridRows * gridColumns
	for i = 1, numButtons do
		local button = buttons[i]
		button:SetID(i)
		button:Show()
		if i == 1 then
			-- position the grid in the center of the frame
			local gridWidth = gridColumns * (button:GetWidth() + XPADDING) - XPADDING
			local gridHeight = gridRows * (button:GetHeight() + YPADDING) - YPADDING
			button:SetPoint("TOPLEFT", Grid.Inset, "CENTER", -gridWidth / 2, gridHeight / 2)
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

function Grid:UpdateGridBindings()
	for i = 1, self.db.global.gridRows * self.db.global.gridColumns do
		local button = buttons[i]
		local key = self.db.global.keys[i]
		button.hotKey:SetText(GetBindingText(key, true))
		local action, set = SpellBinding:GetActiveActionForKey(key)
		local name, texture = SpellBinding:GetActionInfo(action)
		button.name:SetText(name)
		button.icon:SetTexture(texture)
		button.key = key
		button.action = SpellBinding:GetActionStringReverse(action) or action
		button.set = set
	end
end