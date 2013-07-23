local addonName, addon = ...

local Custom = addon:NewModule("Custom")

local currentKey, currentIndex

local function createEditbox(name)
	local editbox = CreateFrame("EditBox", name, Custom, "InputBoxTemplate")
	_G[name] = nil
	editbox:SetSize(32, 20)
	editbox:SetFontObject("ChatFontSmall")
	editbox:SetAutoFocus(false)
	editbox:SetScript("OnEnterPressed", EditBox_ClearFocus)
	return editbox
end

local num = createEditbox(addonName.."GridSize")
num:SetPoint("TOPLEFT", 16, -33)
num:SetNumeric(true)
num:SetScript("OnEnterPressed", function(self)
	Custom.db.global.gridRows = self:GetNumber()
	Custom:UpdateGrid()
	self:ClearFocus()
end)

local width = createEditbox(addonName.."GridWidth")
width:SetPoint("LEFT", num, "RIGHT", 8, 0)
width:SetNumeric(true)
width:SetScript("OnEnterPressed", function(self)
	Custom.db.global.gridColumns = self:GetNumber()
	Custom:UpdateGrid()
	self:ClearFocus()
end)

local overlay = addon:CreateBindingOverlay(Custom)
overlay.OnAccept = function(self)
	Custom.db.global.keys[currentIndex] = currentKey
	Custom:UpdateCustomBindings()
end
overlay.OnBinding = function(self, keyPressed)
	self.actionName:SetText("Button "..currentIndex)
	self.key:SetFormattedText("Current key: %s", GetBindingText(keyPressed, "KEY_"))
	currentKey = keyPressed
end
overlay:SetScript("OnShow", function(self)
	self.actionName:SetText("Button "..currentIndex)
	self.key:SetFormattedText("Current key: %s", GetBindingText(Custom.db.global.keys[currentIndex], "KEY_"))
end)
overlay:SetScript("OnHide", function(self)
	currentKey = nil
end)

local info = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal", 1)
info:SetPoint("CENTER", 0, 24)
info:SetText("Press a key to bind")

overlay.actionName = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
overlay.actionName:SetPoint("CENTER")

overlay.key = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal", 1)
overlay.key:SetPoint("CENTER", 0, -24)

local function onClick(self, key, action)
	addon:AddBinding(key, action, self.value)
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
	
	for i, scope in ipairs(addon.db.global.scopes) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = addon:GetScopeLabel(scope)
		info.value = scope
		info.func = onClick
		info.arg1 = self.key
		info.arg2 = self.action
		info.notCheckable = true
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
		-- self.icon:SetTexture((select(2, addon:GetActionInfo(action))))
		selectScopeMenu.key = Custom.db.global.keys[self:GetID()]
		selectScopeMenu.action = action
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
		text = "Unbind",
		func = function(self, index)
			Custom.db.global.keys[index] = nil
			Custom:UpdateCustomBindings()
		end,
	},
	-- {
		-- text = "Remove",
		-- func = function(self, action, scope)
			-- addon:ClearBinding(action, scope)
			-- addon.db[scope].actions[action] = nil
			-- addon:Update()
		-- end,
	-- },
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

local function listBindings(key, ...)
	GameTooltip:AddLine(GetBindingText(key, "KEY_"))
	for i = 1, select("#", ...) do
		GameTooltip:AddLine(GetBindingText(select(i, ...), "KEY_"))
	end
end

local function onEnter(self)
	if not self.binding then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine((addon:GetActionInfo(self.binding)))
	listBindings(addon:GetBindingKey(self.binding))
	GameTooltip:Show()
	self.showingTooltip = true
end

local function onLeave(self)
	GameTooltip:Hide()
	self.showingTooltip = false
end

local buttons = {}

local function createButton()
	local button = CreateFrame("CheckButton", nil, Custom)
	button:SetSize(36, 36)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnReceiveDrag", dropAction)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	
	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
	button.name:SetSize(36, 10)
	button.name:SetPoint("BOTTOM", 0, 2)
	
	local icon = button:CreateTexture()
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER", 0, -1)
	button.icon = icon
	button:SetNormalTexture(icon)
	button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
	-- button:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	
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

local defaults = {
	global = {
		keys = {},
		hiddenButtons = {},
		gridRows = 4,
		gridColumns = 3,
	}
}

function Custom:OnInitialize()
	self.UPDATE_BINDINGS = self.UpdateCustomBindings
	
	self.db = addon.db:RegisterNamespace("Custom", defaults)
	
	num:SetNumber(self.db.global.gridRows)
	width:SetNumber(self.db.global.gridColumns)
	
	self:UpdateGrid()
end

function Custom:UpdateGrid()
	local gridColumns = self.db.global.gridColumns
	local numButtons = self.db.global.gridRows * gridColumns
	for i = 1, numButtons do
		local button = buttons[i] or createButton()
		button:SetID(i)
		button:Show()
		if i == 1 then
			button:SetPoint("TOPLEFT", 18, -72)
		elseif (i % gridColumns == 1) or (gridColumns == 1) then
			button:SetPoint("TOPLEFT", buttons[i - gridColumns], "BOTTOMLEFT", 0, -8)
		else
			button:SetPoint("TOPLEFT", buttons[i - 1], "TOPRIGHT", 10, 0)
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
		button.binding = binding
	end
end