-- ============================================================
-- CORNUI TOGGLE WIDGET
-- ============================================================


local Toggle = {}


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)



local Utils =
	require(script.Parent.Parent.Core.Utils)



function Toggle:Create(Tab, config)


	config = config or {}



	local toggle = {

		Type = "Toggle",

		Name = config.Name or "Toggle",

		Value = config.Default or false,

		Callback = config.Callback or function() end,

		Flag = config.Flag,

		Tab = Tab,

	}



	-- Register flag

	if toggle.Flag then

		Tab.Window.Flags =
			Tab.Window.Flags or {}


		Tab.Window.Flags[toggle.Flag] =
			toggle.Value

	end



	table.insert(
		Tab.Widgets,
		toggle
	)



	-- ========================================================
	-- UI
	-- ========================================================


	local button =
		Instance.new("TextButton")


	button.Name =
		toggle.Name


	button.Size =
		UDim2.new(
			1,
			0,
			0,
			35
		)


	button.BackgroundColor3 =
		ThemeManager:GetColor("Element")


	button.Text =
		""


	button.Parent =
		Tab.Container



	local label =
		Instance.new("TextLabel")


	label.Name =
		"Label"


	label.Size =
		UDim2.new(
			0.7,
			0,
			1,
			0
		)


	label.BackgroundTransparency =
		1


	label.Text =
		toggle.Name


	label.TextColor3 =
		ThemeManager:GetColor("Text")


	label.Font =
		ThemeManager:GetFont("Main")


	label.TextXAlignment =
		Enum.TextXAlignment.Left


	label.Parent =
		button





	local indicator =
		Instance.new("Frame")


	indicator.Name =
		"Indicator"


	indicator.Size =
		UDim2.new(
			0,
			22,
			0,
			22
		)


	indicator.Position =
		UDim2.new(
			1,
			-30,
			0.5,
			-11
		)


	indicator.BackgroundColor3 =
		toggle.Value
		and ThemeManager:GetColor("Accent")
		or ThemeManager:GetColor("ToggleButton")


	indicator.Parent =
		button



	-- ========================================================
	-- STATE UPDATE
	-- ========================================================


	local function update(value)


		toggle.Value =
			value



		indicator.BackgroundColor3 =
			value
			and ThemeManager:GetColor("Accent")
			or ThemeManager:GetColor("ToggleButton")



		if toggle.Flag then

			Tab.Window.Flags[toggle.Flag] =
				value

		end



		local success,err =
			pcall(
				toggle.Callback,
				value
			)


		if not success then

			warn(
				"[CornUi Toggle Error]",
				err
			)

		end


	end




	button.MouseButton1Click:Connect(function()


		update(
			not toggle.Value
		)


	end)



	-- ========================================================
	-- PUBLIC METHODS
	-- ========================================================


	function toggle:SetValue(value)


		update(
			value
		)


	end



	function toggle:GetValue()


		return toggle.Value


	end



	toggle.Instance =
		button



	return toggle

end



return Toggle
