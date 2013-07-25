local addonName, addon = ...

local Options = addon:NewModule("Options")

function Options:OnInitialize()
	AceDBUI:CreateUI(addonName.."Options", addon.perchardb, self):SetAllPoints(self.Inset)
end