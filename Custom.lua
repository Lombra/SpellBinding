local addonName, addon = ...

local Custom = addon:NewModule("Custom")

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
	if not self.binding then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(addon:GetActionName(self.binding))
	listBindings(addon:GetBindingKey(self.binding))
	GameTooltip:Show()
	self.showingTooltip = true
end

local function onLeave(self)
	GameTooltip:Hide()
	self.showingTooltip = false
end

local function createButton()
	local button = CreateFrame("CheckButton", nil, Custom)
	button:SetSize(36, 36)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	
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

local keys = {
	"F3",
	"F5",
	"F6",
	"F7",
	"F8",
	"F9",
	"8",
	"9",
	"0",
	"BACKSPACE",
	"BUTTON5",
	"+",
}

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

function addon:UpdateCustomBindings()
	for i = 1, NUM_BUTTONS do
		local button = buttons[i]
		local key = keys[i]
		button.hotKey:SetText(GetBindingText(key, "KEY_"))
		local binding = GetBindingByKey(key)
		button.name:SetText(binding and self:GetActionName(binding))
		button.icon:SetTexture(binding and self:GetActionTexture(binding))
		button.binding = binding
	end
end