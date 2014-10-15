local _, SpellBinding = ...

local Sets = SpellBinding:NewModule("Binding sets", CreateFrame("Frame"))

local info = Sets:CreateFontString(nil, nil, "GameFontHighlightSmall")
info:SetHeight(30)
-- info:SetPoint("BOTTOMLEFT", Sets.Inset, 9, 6)
-- info:SetPoint("BOTTOMRIGHT", Sets.Inset, -9, 6)
info:SetPoint("TOPLEFT", 8, -26)
info:SetPoint("TOPRIGHT", -8, -26)
info:SetJustifyH("LEFT")
info:SetJustifyV("TOP")
info:SetText("The priority of binding sets determines how to solve binding conflicts by using the higher priority set's binding. The higher the set is in this list, the higher its priority.")

local function deactivateSet(self, set)
	local sets = SpellBinding:GetActiveSets()
	for i, v in ipairs(sets) do
		if v == set then
			tremove(sets, i)
			Sets:UpdateSetMenus()
			return
		end
	end
end

local function onClick(self, set, currentSet)
	local sets = SpellBinding:GetActiveSets()
	-- if this slot already had a set, replace it with the selected set
	if currentSet then
		for i, v in SpellBinding:IterateActiveSets() do
			if v == currentSet then
				sets[i] = set
				break
			end
		end
	else
		tinsert(sets, set)
	end
	Sets:UpdateSetMenus()
end

local function initializeSetMenu(self)
	local set = SpellBinding.db.global.sets[self.index]
	if set then
		local info = UIDropDownMenu_CreateInfo()
		info.text = "Deactivate this set"
		info.func = deactivateSet
		info.arg1 = set
		info.notCheckable = true
		info.colorCode = RED_FONT_COLOR_CODE
		info.disabled = (SpellBinding:GetNumActiveSets() == 1)
		info.tooltipTitle = info.disabled and "At least one set must be active at all times."
		info.tooltipOnButton = true
		info.tooltipWhileDisabled = true
		self:AddButton(info)
	end
	
	for i, v in ipairs(SpellBinding:GetAvailableSets()) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = SpellBinding:GetSetName(v)
		info.func = onClick
		info.arg1 = v
		info.arg2 = set
		info.notCheckable = not set
		info.checked = (v == set)
		info.disabled = SpellBinding:IsSetActive(v)
		self:AddButton(info)
	end
end

local function move(self)
	local sets = SpellBinding:GetActiveSets()
	local index = self:GetParent().index
	local swapIndex = index + self.shiftMod
	sets[index], sets[swapIndex] = sets[swapIndex], sets[index]
	Sets:UpdateSetMenus()
end

local setMenus = setmetatable({}, {
	__index = function(table, index)
		local menu = SpellBinding:CreateDropdown("Frame", Sets)
		if index == 1 then
			menu:SetPoint("TOPLEFT", Sets.Inset, 0, -16)
		else
			menu:SetPoint("TOP", table[index - 1], "BOTTOM")
		end
		menu.initialize = initializeSetMenu
		menu:SetWidth(196)
		menu:JustifyText("LEFT")
		
		menu.moveUp = CreateFrame("Button", nil, menu)
		menu.moveUp:SetSize(24, 24)
		menu.moveUp:SetPoint("LEFT", menu, "RIGHT", -12, 3)
		menu.moveUp:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Up]])
		menu.moveUp:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Down]])
		menu.moveUp:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Disabled]])
		menu.moveUp:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
		menu.moveUp:SetScript("OnClick", move)
		menu.moveUp.shiftMod = -1
		
		menu.moveDown = CreateFrame("Button", nil, menu)
		menu.moveDown:SetSize(24, 24)
		menu.moveDown:SetPoint("LEFT", menu.moveUp, "RIGHT")
		menu.moveDown:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
		menu.moveDown:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
		menu.moveDown:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
		menu.moveDown:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
		menu.moveDown:SetScript("OnClick", move)
		menu.moveDown.shiftMod = 1
		
		table[index] = menu
		return menu
	end
})

function Sets:OnInitialize()
	self:UpdateSetMenus()
	-- self.SET_ACTIVATED = self.UpdateSetMenus
end

function Sets:UpdateSetMenus()
	local numActiveSets = SpellBinding:GetNumActiveSets()
	for i, set in SpellBinding:IterateActiveSets() do
		local menu = setMenus[i]
		menu:SetText(SpellBinding:GetSetName(set))
		menu.moveUp:Show()
		menu.moveUp:SetEnabled(i > 1)
		menu.moveDown:Show()
		menu.moveDown:SetEnabled(i < numActiveSets)
		menu.index = i
	end
	local menu = setMenus[numActiveSets + 1]
	menu:SetText(GREEN_FONT_COLOR_CODE.."Activate a set...|r")
	menu:Show()
	menu.moveUp:Hide()
	menu.moveDown:Hide()
	menu.index = nil
	for i = numActiveSets + 2, #setMenus do
		setMenus[i]:Hide()
	end
	SpellBinding:UpdateSortOrder()
	SpellBinding:ApplyBindings()
end

local reverse = SpellBinding:CreateButton(Sets)
reverse:SetWidth(80)
reverse:SetPoint("BOTTOMLEFT", 12, 14)
reverse:SetText("Reverse")
reverse:SetScript("OnClick", function()
	local sets = {}
	for i, v in ipairs(SpellBinding:GetActiveSets()) do
		tinsert(sets, 1, v)
	end
	SpellBinding.db.global.sets = sets
	Sets:UpdateSetMenus()
end)