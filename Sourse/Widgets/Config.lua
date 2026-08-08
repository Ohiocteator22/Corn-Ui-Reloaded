-- ============================================================
-- CORNUI CONFIG MANAGER
-- Extracted from CornUi v1.9.3
-- ============================================================

local Config = {}

local Services = require(script.Parent.Services)

local HttpService = Services.HttpService


-- Storage
Config.Flags = {}
Config.Configs = {}


-- ============================================================
-- FLAG SYSTEM
-- ============================================================

function Config:SetFlag(name, value)
	if not name then
		return
	end

	self.Flags[name] = value
end


function Config:GetFlag(name)
	return self.Flags[name]
end


function Config:ClearFlags()
	table.clear(self.Flags)
end



-- ============================================================
-- EXPORT
-- ============================================================

function Config:Export()
	local success, result = pcall(function()
		return HttpService:JSONEncode(self.Flags)
	end)

	if success then
		return result
	end

	warn("[CornUi Config] Export failed:", result)
	return nil
end



-- ============================================================
-- IMPORT
-- ============================================================

function Config:Import(json)
	if not json then
		return false
	end

	local success, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)


	if not success then
		warn("[CornUi Config] Invalid JSON")
		return false
	end


	if type(data) ~= "table" then
		return false
	end


	for k,v in pairs(data) do
		self.Flags[k] = v
	end


	return true
end



-- ============================================================
-- CONFIG STORAGE
-- ============================================================

function Config:Save(name)
	if not name then
		name = "Default"
	end

	self.Configs[name] = self:Export()

	return true
end



function Config:Load(name)

	local data = self.Configs[name]

	if not data then
		return false
	end


	return self:Import(data)
end



function Config:GetConfigs()

	local list = {}

	for name in pairs(self.Configs) do
		table.insert(list,name)
	end

	return list
end



function Config:Delete(name)

	self.Configs[name] = nil

end



return Config
