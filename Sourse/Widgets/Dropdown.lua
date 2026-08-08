-- ============================================================
-- CORNUI DROPDOWN WIDGET
-- ============================================================


local Dropdown = {}


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)



function Dropdown:Create(Tab, config)


	config = config or {}



	local dropdown = {

		Type = "Dropdown",

		Name = config.Name or "Dropdown",

		Options = config.Options or {},

		Value = config.Default,

		Callback = config.Callback or function() end,

		Flag = config.Flag,

		Open = false,

		Tab = Tab,

	}



	table.insert(
		Tab.Widgets,
		dropdown
	)



	-- Flag

	if dropdown.Flag then

		Tab.Window.Flags =
			Tab.Window.Flags or {}


		Tab.Window.Flags[dropdown.Flag] =
			dropdown.Value

	end



	-- ========================================================
	-- MAIN BUTTON
	-- ========================================================


	local button =
		Instance.new("TextButton")


	button.Name =
		dropdown.Name


	button.Size =
		UDim2.new(
			1,
			0,
			0,
			38
		)


	button.BackgroundColor3 =
		ThemeManager:GetColor("Element")


	button.Text =
		""


	button.Parent =
		Tab.Container





	local label =
		Instance.new("TextLabel")


	label.Size =
		UDim2.new(
			1,
			-35,
			1,
			0
		)


	label.Position =
		UDim2.new(
			0,
			12,
			0,
			0
		)


	label.BackgroundTransparency =
		1


	label.Text =
		dropdown.Name
		..
		": "
		..
		tostring(dropdown.Value or "None")


	label.TextColor3 =
		ThemeManager:GetColor("Text")


	label.Font =
		ThemeManager:GetFont("Main")


	label.TextXAlignment =
		Enum.TextXAlignment.Left


	label.Parent =
		button





	local arrow =
		Instance.new("TextLabel")


	arrow.Size =
		UDim2.new(
			0,
			25,
			1,
			0
		)


	arrow.Position =
		UDim2.new(
			1,
			-30,
			0,
			0
		)


	arrow.BackgroundTransparency =
		1


	arrow.Text =
		"▼"


	arrow.TextColor3 =
		ThemeManager:GetColor("SubText")


	arrow.Font =
		ThemeManager:GetFont("Bold")


	arrow.Parent =
		button





	-- ========================================================
	-- OPTION HOLDER
	-- ========================================================


	local holder =
		Instance.new("Frame")


	holder.Name =
		"Options"


	holder.Size =
		UDim2.new(
			1,
			0,
			0,
			0
		)


	holder.BackgroundColor3 =
		ThemeManager:GetColor("Header")


	holder.ClipsDescendants =
		true


	holder.Visible =
		false


	holder.Parent =
		Tab.Container





	local layout =
		Instance.new("UIListLayout")


	layout.Padding =
		UDim.new(
			0,
			2
		)


	layout.Parent =
		holder





	-- ========================================================
	-- SELECT OPTION
	-- ========================================================


	local function select(option)


		dropdown.Value =
			option



		label.Text =
			dropdown.Name
			..
			": "
			..
			tostring(option)



		if dropdown.Flag then

			Tab.Window.Flags[dropdown.Flag] =
				option

		end



		local success,err =
			pcall(
				dropdown.Callback,
				option
			)


		if not success then

			warn(
				"[CornUi Dropdown Error]",
				err
			)

		end


	end





	local function rebuild()


		for _,child in ipairs(holder:GetChildren()) do

			if child:IsA("TextButton") then

				child:Destroy()

			end

		end



		for _,option in ipairs(dropdown.Options) do


			local optionButton =
				Instance.new("TextButton")


			optionButton.Size =
				UDim2.new(
					1,
					0,
					0,
					30
				)


			optionButton.BackgroundColor3 =
				ThemeManager:GetColor("Element")


			optionButton.Text =
				tostring(option)


			optionButton.TextColor3 =
				ThemeManager:GetColor("Text")


			optionButton.Font =
				ThemeManager:GetFont("Main")


			optionButton.Parent =
				holder



			optionButton.MouseButton1Click:Connect(function()

				select(option)

			end)


		end


	end





	rebuild()



	-- ========================================================
	-- OPEN / CLOSE
	-- ========================================================


	button.MouseButton1Click:Connect(function()


		dropdown.Open =
			not dropdown.Open



		holder.Visible =
			dropdown.Open



		if dropdown.Open then

			holder.Size =
				UDim2.new(
					1,
					0,
					0,
					layout.AbsoluteContentSize.Y
				)

			arrow.Text =
				"▲"

		else

			holder.Size =
				UDim2.new(
					1,
					0,
					0,
					0
				)

			arrow.Text =
				"▼"

		end


	end)



	-- ========================================================
	-- PUBLIC API
	-- ========================================================


	function dropdown:SetValue(value)


		select(
			value
		)


	end





	function dropdown:GetValue()


		return dropdown.Value


	end





	function dropdown:Refresh(options)


		dropdown.Options =
			options or {}


		rebuild()


	end



	dropdown.Instance =
		button



	return dropdown

end



return Dropdown
