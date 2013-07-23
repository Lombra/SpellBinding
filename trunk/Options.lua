local addonName, addon = ...

local Options = addon:NewModule("Options")

function Options:OnInitialize()
	AceDBUI:CreateUI(addonName.."a", addon.perchardb, self):SetAllPoints(self.Inset)
end