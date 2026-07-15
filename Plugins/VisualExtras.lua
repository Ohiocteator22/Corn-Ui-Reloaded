--[[
	VisualExtras — CornUi plugin
	Registers a couple of extra color themes and adds an "Appearance" tab
	for switching theme/background live, plus a free-text field for any
	rbxassetid a user wants to drop in.

	Usage:
		local Corn = loadstring(game:HttpGet("<raw CornUi.lua url>"))()
		local Window = Corn:CreateWindow({ Name = "My Hub" })
		Corn:LoadPlugins({
			"https://raw.githubusercontent.com/you/plugins/main/VisualExtras.lua",
		}, Window)

	Notes:
	- RegisterTheme only needs the keys you want to override; anything left
	  out falls back to the Dark preset (see CornUi.lua's RegisterTheme).
	- Background presets below use rbxassetid 0 as placeholders — swap in
	  real asset ids for images/videos you actually own the rights to use.
	- ctx.Window is used directly for SetTheme, since that's a Window method
	  and not part of the small ctx wrapper surface (RegisterTheme is, since
	  it can be called before a window even exists).
]]

return {
	Name = "Visual Extras",
	Version = "1.0.0",

	Init = function(ctx)
		----------------------------------------------------------------
		-- Custom themes
		----------------------------------------------------------------

		ctx:RegisterTheme("Midnight", {
			Background = Color3.fromRGB(8, 10, 18),
			Header = Color3.fromRGB(13, 15, 26),
			Accent = Color3.fromRGB(90, 140, 255),
			TextOnAccent = Color3.fromRGB(10, 10, 14),
			Text = Color3.fromRGB(235, 238, 245),
			SubText = Color3.fromRGB(130, 138, 155),
			Element = Color3.fromRGB(18, 21, 34),
			ElementHover = Color3.fromRGB(26, 30, 46),
			Stroke = Color3.fromRGB(40, 45, 64),
			ToggleButton = Color3.fromRGB(18, 21, 34),
		})

		ctx:RegisterTheme("Sunset", {
			Background = Color3.fromRGB(20, 12, 14),
			Header = Color3.fromRGB(28, 17, 19),
			Accent = Color3.fromRGB(255, 110, 70),
			TextOnAccent = Color3.fromRGB(30, 12, 8),
			Text = Color3.fromRGB(245, 235, 232),
			SubText = Color3.fromRGB(160, 130, 125),
			Element = Color3.fromRGB(34, 21, 23),
			ElementHover = Color3.fromRGB(45, 28, 30),
			Stroke = Color3.fromRGB(60, 38, 40),
			ToggleButton = Color3.fromRGB(34, 21, 23),
		})

		ctx:RegisterTheme("Forest", {
			Background = Color3.fromRGB(10, 16, 12),
			Header = Color3.fromRGB(15, 22, 17),
			Accent = Color3.fromRGB(110, 200, 120),
			TextOnAccent = Color3.fromRGB(10, 16, 10),
			Text = Color3.fromRGB(232, 240, 233),
			SubText = Color3.fromRGB(130, 150, 132),
			Element = Color3.fromRGB(19, 27, 21),
			ElementHover = Color3.fromRGB(27, 37, 29),
			Stroke = Color3.fromRGB(42, 56, 44),
			ToggleButton = Color3.fromRGB(19, 27, 21),
		})

		local THEME_NAMES = { "Dark", "Light", "Midnight", "Sunset", "Forest" }

		----------------------------------------------------------------
		-- Background presets — replace the asset ids with real ones
		----------------------------------------------------------------

		local BACKGROUNDS = {
			["None"] = nil,
			["Stars (image)"] = { Type = "Image", Texture = "rbxassetid://0" },
			["Clouds (image)"] = { Type = "Image", Texture = "rbxassetid://0" },
			["Loop (video)"] = { Type = "Video", Texture = "rbxassetid://0", Volume = 0 },
		}
		local BACKGROUND_NAMES = { "None", "Stars (image)", "Clouds (image)", "Loop (video)" }

		----------------------------------------------------------------
		-- UI
		----------------------------------------------------------------

		if not ctx.Window then return end -- everything below needs a window

		local tab = ctx:CreateTab("Appearance")
		local themeSection = tab:CreateSection("Theme")

		themeSection:CreateDropdown({
			Name = "Preset",
			Options = THEME_NAMES,
			Default = "Dark",
			Callback = function(choice)
				ctx.Window:SetTheme(choice)
			end,
		})

		local bgSection = tab:CreateSection("Background")

		bgSection:CreateDropdown({
			Name = "Preset",
			Options = BACKGROUND_NAMES,
			Default = "None",
			Callback = function(choice)
				local preset = BACKGROUNDS[choice]
				if preset then
					ctx:SetBackground(preset)
				else
					ctx:ClearBackground()
				end
			end,
		})

		bgSection:CreateTextbox({
			Name = "Custom ID",
			Placeholder = "rbxassetid://... or plain number",
			Callback = function(text)
				text = text:gsub("^%s+", ""):gsub("%s+$", "")
				if text == "" then return end
				ctx:SetBackground(text)
			end,
		})

		bgSection:CreateButton({
			Name = "Clear Background",
			Callback = function()
				ctx:ClearBackground()
			end,
		})
	end,
}
