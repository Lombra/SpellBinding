local addonName, addon = ...

local frame = CreateFrame("Frame", addonName.."Frame", UIParent, "ButtonFrameTemplate")
addon.frame = frame
frame:SetPoint("CENTER")
frame:SetToplevel(true)
frame:EnableMouse(true)
frame:SetScript("OnShow", function(self)
	PlaySound("igCharacterInfoOpen")
	if not PanelTemplates_GetSelectedTab(self) then
		PanelTemplates_SetTab(self, 1)
	end
end)
frame:SetScript("OnHide", function(self)
	PlaySound("igCharacterInfoClose")
end)
frame.TitleText:SetText(addonName)
ButtonFrameTemplate_HidePortrait(frame)
ButtonFrameTemplate_HideButtonBar(frame)
tinsert(UISpecialFrames, frame:GetName())
UIPanelWindows[frame:GetName()] = {
	area = "left",
	pushable = 1,
	whileDead = true,
}

SlashCmdList["SPELLBINDING"] = function(msg)
	ToggleFrame(addon.frame)
end
SLASH_SPELLBINDING1 = "/spellbinding"
SLASH_SPELLBINDING2 = "/sb"

BINDING_HEADER_SPELLBINDING = "SpellBinding"
BINDING_NAME_SPELLBINDING_TOGGLE = "Toggle SpellBinding frame"

local tabs = {}

local function onClick(self)
	PanelTemplates_Tab_OnClick(self, frame)
	PlaySound("igCharacterInfoTab")
end

local function onEnable(self)
	self.frame:Hide()
end

local function onDisable(self)
	self.frame:Show()
end

local function createTab()
	local numTabs = #tabs + 1
	local tab = CreateFrame("Button", addonName.."FrameTab"..numTabs, frame, "CharacterFrameTabButtonTemplate")
	if numTabs == 1 then
		tab:SetPoint("BOTTOMLEFT", 19, -30)
	else
		tab:SetPoint("LEFT", tabs[numTabs - 1], "RIGHT", -15, 0)
	end
	tab:SetID(numTabs)
	tab:SetScript("OnClick", onClick)
	tab:SetScript("OnEnable", onEnable)
	tab:SetScript("OnDisable", onDisable)
	tabs[numTabs] = tab
	PanelTemplates_SetNumTabs(frame, numTabs)
	return tab
end

local modules = {}

function addon:GetSelectedTab()
	return tabs[PanelTemplates_GetSelectedTab(frame)].frame
end

function addon:NewModule(name)
	if modules[name] then
		error("Module '"..name.."' already exists.", 2)
	end
	
	local ui = CreateFrame("Frame", nil, frame)
	ui:SetAllPoints()
	ui:Hide()
	ui.name = name
	ui.Inset = frame.Inset
	modules[name] = ui
	
	-- for k, v in pairs(mixins) do module[k] = v end
	
	local tab = createTab()
	tab:SetText(name)
	tab.frame = ui
	return ui
end


local scopes = {
	"char",
	"realm",
	"class",
	"race",
	"faction",
	"factionrealm",
	"global",
	"profile",
}

local scopeLabels = {
	char = "Character",
	realm = "Realm",
	class = "Class",
	race = "Race",
	faction = "Faction",
	factionrealm = "Faction - realm",
	global = "Global",
	profile = "Profile",
}

local defaults = {}

for i, scope in ipairs(scopes) do
	defaults[scope] = {
		actions = {},
		bindings = {},
	}
end

defaults.global.scopes = {
	"global",
}

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:SetScript("OnEvent", function(self, event, ...)
	addon[event](addon, ...)
end)

function addon:ADDON_LOADED(addon)
	if addon ~= addonName then
		return
	end
	
	self.db = LibStub("AceDB-3.0"):New("SpellBindingDB", defaults)
	
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.db, "SpellBinding")
	
	self:UpdateScopeMenus()
	
	for k, module in pairs(modules) do
		if module.OnInitialize then
			module:OnInitialize()
		end
	end
end

function addon:PLAYER_LOGIN()
	self:ApplyBindings()
	self:Update()
end

function addon:RefreshConfig()
	self:UpdateScopeMenus()
	self:ApplyBindings()
	self:Update()
end

function addon:IsScopeUsed(scope)
	for i, v in ipairs(self.db.global.scopes) do
		if v == scope then
			return true
		end
	end
end

function addon:UPDATE_BINDINGS()
	for i = 1, NUM_BUTTONS do
		local button = buttons[i]
		button.hotKey:SetText(i)
		local binding = GetBindingByKey("F"..i)
		button.name:SetText(GetSpellInfo((select(2, GetActionInfo(i)))))
		button.icon:SetTexture(GetActionTexture(i))
	end
end

function addon:ApplyBindings()
	for i, v in ipairs(self.db.global.scopes) do
		for key, command in pairs(self.db[v].bindings) do
			SetOverrideBinding(frame, nil, key, command:gsub("(%d+)$", GetSpellInfo))
		end
	end
end

function addon:UpdateList()
	sort(self:GetList(), listSort)
	scrollFrame:update()
end

function addon:GetBindingKey(action2)
	for i = #self.db.global.scopes, 1, -1 do
		for key, action in pairs(self.db[self.db.global.scopes[i]].bindings) do
			if action == action2 then
				return key
			end
		end
	end
	return GetBindingKey(action2)
end

function addon:ClearBinding(action2)
	for key, action in pairs(addon.db.global.bindings) do
		if action == action2 then
			addon.db.global.bindings[key] = nil
			SetOverrideBinding(frame, nil, key, nil)
		end
	end
end

local getName = {
	SPELL = GetSpellInfo,
	ITEM = GetItemInfo,
	MACRO = function(data) return data end,
	COMMAND = function(data)
		return GetBindingText(data, "BINDING_NAME_")
	end,
}

function addon:GetActionName(binding)
	local type, data = binding:match("(%u+) (.+)")
	local get = getName[type]
	if get then
		return get(data)
	else
		getName["COMMAND"](binding)
	end
end

local getTexture = {
	SPELL = GetSpellTexture,
	ITEM = GetItemIcon,
	MACRO = function(data)
		return select(2, GetMacroInfo(data))
	end,
}

function addon:GetActionTexture(binding)
	local type, data = binding:match("(%u+) (.+)")
	local get = getTexture[type]
	return get and get(data)
end

function addon:GetScopes()
	return scopes
end

function addon:GetScopeLabel(scope)
	return scopeLabels[scope]
end


do return end
local Naga = addon:NewModule("Naga")

local function createButton()
	local button = CreateFrame("CheckButton", nil, Naga)
	button:SetSize(36, 36)
	
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