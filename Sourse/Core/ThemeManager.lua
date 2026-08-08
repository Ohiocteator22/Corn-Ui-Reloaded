-- ============================================================
-- CORNUI THEME MANAGER
-- Controls active theme + theme updates
-- ============================================================


local ThemeManager = {}


local Themes = require(script.Parent.Themes)
local Library = require(script.Parent.Library)



-- ============================================================
-- STATE
-- ============================================================

ThemeManager.Current = nil

ThemeManager.CurrentName = "Dark"

ThemeManager.Listeners = {}



-- ============================================================
-- BACKWARD COMPATIBILITY PROXY
-- Allows:
-- Theme.Background
-- Theme.Accent
--
-- while supporting:
-- Theme.Colors.Background
-- ============================================================

local ThemeProxy = {}



setmetatable(ThemeProxy, {

	__index = function(_,key)

		local theme = ThemeManager.Current


		if not theme then
			return nil
		end



		-- New system
		if theme.Colors and theme.Colors[key] ~= nil then

			return theme.Colors[key]

		end



		-- Old system
		if theme[key] ~= nil then

			return theme[key]

		end



		-- fallback

		local dark = Themes.Dark


		if dark.Colors and dark.Colors[key] ~= nil then
			return dark.Colors[key]
		end


		return dark[key]

	end

})



ThemeManager.Theme = ThemeProxy



-- ============================================================
-- LOAD THEME
-- ============================================================

function ThemeManager:Load(name)


	local theme = Themes:Get(name)


	if not theme then

		warn(
			"[CornUi] Theme not found:",
			name
		)

		return false

	end



	self.Current = theme

	self.CurrentName = name


	Library.CurrentTheme = name



	self:Update()


	return true

end



-- ============================================================
-- GETTERS
-- ============================================================


function ThemeManager:GetColor(name)

	local theme = self.Current


	if not theme then
		return nil
	end



	if theme.Colors then

		return theme.Colors[name]

	end


	return theme[name]

end



function ThemeManager:GetFont(name)

	local theme = self.Current


	if theme and theme.Fonts then

		return theme.Fonts[name]

	end


	return Enum.Font.Gotham

end



function ThemeManager:GetAsset(name)

	local theme = self.Current


	if theme and theme.Assets then

		return theme.Assets[name] or ""

	end


	return ""

end



function ThemeManager:GetStyle(name)

	local theme = self.Current


	if theme and theme.Style then

		return theme.Style[name]

	end


	return nil

end



-- ============================================================
-- REGISTER CUSTOM THEME
-- ============================================================

function ThemeManager:Register(name,data)


	return Themes:Register(
		name,
		data
	)

end



-- ============================================================
-- LISTENERS
-- Widgets register here
-- ============================================================

function ThemeManager:Connect(callback)


	if type(callback) ~= "function" then
		return
	end


	table.insert(
		self.Listeners,
		callback
	)

end



function ThemeManager:Update()


	for _,callback in ipairs(self.Listeners) do

		pcall(
			callback,
			self.Current
		)

	end


end



-- ============================================================
-- INITIALIZE
-- ============================================================

ThemeManager:Load("Dark")



return ThemeManager
