local addonName, addon = ...

local Scoping = addon:NewModule("Scoping")

function Scoping:OnInitialize()
	self:UpdateScopeMenus()
end

local scopeMenus = {}

function Scoping:UpdateScopeMenus()
	local db = addon.db.global.scopes
	for i = 1, #db do
		local menu = self:GetScopeMenu(i)
		UIDropDownMenu_SetText(menu, addon:GetScopeLabel(db[i]))
		menu.moveUp:Show()
		menu.moveUp:SetEnabled(i ~= 1)
		menu.moveDown:Show()
		menu.moveDown:SetEnabled(i ~= #db)
	end
	local menu = self:GetScopeMenu(#db + 1)
	UIDropDownMenu_SetText(menu, "Add scope")
	menu.moveUp:Hide()
	menu.moveDown:Hide()
	for i = #db + 2, #scopeMenus do
		self:GetScopeMenu(i):Hide()
	end
	addon:UpdateSortOrder()
	addon:ApplyBindings()
end

function Scoping:GetScopeMenu(index)
	return scopeMenus[index] or self:CreateScopeMenu(index)
end

local function disableScope(self, scope)
	for i, v in ipairs(addon.db.global.scopes) do
		if v == scope then
			tremove(addon.db.global.scopes, i)
			Scoping:UpdateScopeMenus()
			return
		end
	end
end

local function onClick(self, scope)
	tinsert(addon.db.global.scopes, scope)
	Scoping:UpdateScopeMenus()
end

local function initializeScopeMenu(self)
	local scope = addon.db.global.scopes[self.index]
	if scope then
		local info = UIDropDownMenu_CreateInfo()
		info.text = "Disable"
		info.func = disableScope
		info.arg1 = scope
		info.notCheckable = true
		UIDropDownMenu_AddButton(info)
	end
	
	for i, v in ipairs(addon:GetScopes()) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = addon:GetScopeLabel(v)
		info.func = onClick
		info.arg1 = v
		info.notCheckable = not scope
		info.checked = v == scope
		info.disabled = addon:IsScopeUsed(v)
		UIDropDownMenu_AddButton(info)
	end
end

local function move(self)
	local db = addon.db.global.scopes
	local index = self.index
	local swapIndex = index + self.shiftMod
	db[index], db[swapIndex] = db[swapIndex], db[index]
	Scoping:UpdateScopeMenus()
end

function Scoping:CreateScopeMenu(index)
	local menu = CreateFrame("Frame", addonName.."ScopeMenu"..index, Scoping, "UIDropDownMenuTemplate")
	if index == 1 then
		menu:SetPoint("TOPLEFT", Scoping.Inset, 0, -16)
	else
		menu:SetPoint("TOP", scopeMenus[index - 1], "BOTTOM")
	end
	menu.initialize = initializeScopeMenu
	menu.index = index
	UIDropDownMenu_SetWidth(menu, 128)
	UIDropDownMenu_JustifyText(menu, "LEFT")
	scopeMenus[index] = menu
	
	menu.moveUp = CreateFrame("Button", nil, menu)
	menu.moveUp:SetSize(24, 24)
	menu.moveUp:SetPoint("LEFT", menu, "RIGHT", -12, 3)
	menu.moveUp:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Up]])
	menu.moveUp:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Down]])
	menu.moveUp:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Disabled]])
	menu.moveUp:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
	menu.moveUp:SetScript("OnClick", move)
	menu.moveUp.index = index
	menu.moveUp.shiftMod = -1
	
	menu.moveDown = CreateFrame("Button", nil, menu)
	menu.moveDown:SetSize(24, 24)
	menu.moveDown:SetPoint("LEFT", menu.moveUp, "RIGHT")
	menu.moveDown:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
	menu.moveDown:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
	menu.moveDown:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
	menu.moveDown:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
	menu.moveDown:SetScript("OnClick", move)
	menu.moveDown.index = index
	menu.moveDown.shiftMod = 1
	
	return menu
end