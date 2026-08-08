-- ============================================================
-- CORNUI THEME DATABASE
-- Theme Definitions
-- ============================================================


local Themes = {}



-- ============================================================
-- DARK DEFAULT THEME
-- ============================================================

Themes.Dark = {

	-- Backwards compatible colors
	Background = Color3.fromRGB(10,10,12),
	Header = Color3.fromRGB(16,16,19),
	Element = Color3.fromRGB(20,20,24),
	ElementHover = Color3.fromRGB(30,30,36),

	Accent = Color3.fromRGB(255,196,48),

	Text = Color3.fromRGB(240,240,245),
	SubText = Color3.fromRGB(140,140,148),

	Stroke = Color3.fromRGB(45,45,50),

	ToggleButton = Color3.fromRGB(35,35,40),

	TextOnAccent = Color3.fromRGB(0,0,0),



	-- Future skin support
	Colors = {

		Background = Color3.fromRGB(10,10,12),
		Header = Color3.fromRGB(16,16,19),
		Element = Color3.fromRGB(20,20,24),
		ElementHover = Color3.fromRGB(30,30,36),

		Accent = Color3.fromRGB(255,196,48),

		Text = Color3.fromRGB(240,240,245),
		SubText = Color3.fromRGB(140,140,148),

		Stroke = Color3.fromRGB(45,45,50),

	},



	Fonts = {

		Main = Enum.Font.Gotham,
		Bold = Enum.Font.GothamBold,
		Mono = Enum.Font.Code,

	},



	Assets = {

		WindowBackground = "",
		ButtonTexture = "",

	},



	Style = {

		CornerRadius = 12,
		StrokeSize = 1,

	},



	Animations = {

		Speed = 1,

	},



	Sounds = {

	},



	Icons = {

		Success = "✓",
		Error = "✕",
		Warning = "!",
		Info = "i",

	},



	Effects = {

		Blur = false,
		Glass = false,

	},

}



-- ============================================================
-- OCEAN THEME
-- ============================================================

Themes.Ocean = {

	Background = Color3.fromRGB(8,20,40),
	Header = Color3.fromRGB(12,30,50),

	Element = Color3.fromRGB(15,45,70),
	ElementHover = Color3.fromRGB(20,65,95),

	Accent = Color3.fromRGB(64,224,208),

	Text = Color3.fromRGB(255,255,255),
	SubText = Color3.fromRGB(170,190,210),

	Stroke = Color3.fromRGB(30,90,120),

	ToggleButton = Color3.fromRGB(20,70,90),

	TextOnAccent = Color3.fromRGB(0,0,0),



	Colors = {

		Background = Color3.fromRGB(8,20,40),
		Header = Color3.fromRGB(12,30,50),

		Element = Color3.fromRGB(15,45,70),
		ElementHover = Color3.fromRGB(20,65,95),

		Accent = Color3.fromRGB(64,224,208),

		Text = Color3.fromRGB(255,255,255),
		SubText = Color3.fromRGB(170,190,210),

		Stroke = Color3.fromRGB(30,90,120),

	},



	Fonts = {

		Main = Enum.Font.Gotham,
		Bold = Enum.Font.GothamBold,

	},



	Assets = {},

	Style = {

		CornerRadius = 12,
		StrokeSize = 1,

	},



	Animations = {

		Speed = 1,

	},


	Sounds = {},

	Icons = {},

	Effects = {},

}



-- ============================================================
-- REGISTER HELPERS
-- ============================================================

function Themes:Register(name,data)

	if type(name) ~= "string" then
		return false
	end


	if type(data) ~= "table" then
		return false
	end


	self[name] = data

	return true
end



function Themes:Get(name)

	return self[name]

end



function Themes:List()

	local list = {}

	for name,value in pairs(self) do

		if type(value) == "table" then
			table.insert(list,name)
		end

	end


	return list
end



return Themes
