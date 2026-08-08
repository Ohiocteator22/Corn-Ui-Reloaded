-- ============================================================
-- CORNUI COLOR PICKER WIDGET
-- ============================================================


local ColorPicker = {}


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)


local Services =
	require(script.Parent.Parent.Core.Services)



function ColorPicker:Create(Tab, config)


	config = config or {}


	local picker = {

		Type = "ColorPicker",

		Name = config.Name or "Color",

		Value = config.Default or Color3.fromRGB(255,255,255),

		Callback = config.Callback or function() end,

		Flag = config.Flag,

		Open = false,

		Tab = Tab,

	}



	table.insert(
		Tab.Widgets,
		picker
	)



	-- Flag

	if picker.Flag then

		Tab.Window.Flags =
			Tab.Window.Flags or {}

		Tab.Window.Flags[picker.Flag] =
			picker.Value

	end



	-- ========================================================
	-- MAIN BUTTON
	-- ========================================================


	local button =
		Instance.new("TextButton")


	button.Name =
		picker.Name


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
			-50,
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
		picker.Name


	label.TextColor3 =
		ThemeManager:GetColor("Text")


	label.Font =
		ThemeManager:GetFont("Main")


	label.TextXAlignment =
		Enum.TextXAlignment.Left


	label.Parent =
		button





	local preview =
		Instance.new("Frame")


	preview.Size =
		UDim2.new(
			0,
			25,
			0,
			25
		)


	preview.Position =
		UDim2.new(
			1,
			-35,
			0.5,
			-12
		)


	preview.BackgroundColor3 =
		picker.Value


	preview.Parent =
		button





	-- ========================================================
	-- PICKER HOLDER
	-- ========================================================


	local holder =
		Instance.new("Frame")


	holder.Size =
		UDim2.new(
			1,
			0,
			0,
			220
		)


	holder.BackgroundColor3 =
		ThemeManager:GetColor("Header")


	holder.Visible =
		false


	holder.Parent =
		Tab.Container





	-- ========================================================
	-- HSV BOX
	-- ========================================================


	local svBox =
		Instance.new("Frame")


	svBox.Size =
		UDim2.new(
			1,
			-30,
			0,
			170
		)


	svBox.BackgroundColor3 =
		Color3.fromRGB(
			255,
			0,
			0
		)


	svBox.Parent =
		holder





	local svWhite =
		Instance.new("UIGradient")


	svWhite.Color =
		ColorSequence.new({

			ColorSequenceKeypoint.new(
				0,
				Color3.new(1,1,1)
			),

			ColorSequenceKeypoint.new(
				1,
				Color3.new(1,1,1)
			)

		})


	svWhite.Parent =
		svBox





	-- ========================================================
	-- HUE BAR
	-- ========================================================


	local hue =
		Instance.new("Frame")


	hue.Size =
		UDim2.new(
			0,
			20,
			1,
			0
		)


	hue.Position =
		UDim2.new(
			1,
			-20,
			0,
			0
		)


	hue.BackgroundColor3 =
		Color3.fromHSV(
			0,
			1,
			1
		)


	hue.Parent =
		holder





	local hueGradient =
		Instance.new("UIGradient")


	hueGradient.Rotation =
		90


	hueGradient.Color =
		ColorSequence.new({

			ColorSequenceKeypoint.new(
				0,
				Color3.fromRGB(255,0,0)
			),

			ColorSequenceKeypoint.new(
				0.16,
				Color3.fromRGB(255,255,0)
			),

			ColorSequenceKeypoint.new(
				0.33,
				Color3.fromRGB(0,255,0)
			),

			ColorSequenceKeypoint.new(
				0.5,
				Color3.fromRGB(0,255,255)
			),

			ColorSequenceKeypoint.new(
				0.66,
				Color3.fromRGB(0,0,255)
			),

			ColorSequenceKeypoint.new(
				0.83,
				Color3.fromRGB(255,0,255)
			),

			ColorSequenceKeypoint.new(
				1,
				Color3.fromRGB(255,0,0)
			)

		})


	hueGradient.Parent =
		hue





	-- ========================================================
	-- COLOR UPDATE
	-- ========================================================


	local function update(color)


		picker.Value =
			color


		preview.BackgroundColor3 =
			color



		if picker.Flag then

			Tab.Window.Flags[picker.Flag] =
				color

		end



		local ok,err =
			pcall(
				picker.Callback,
				color
			)


		if not ok then

			warn(
				"[CornUi ColorPicker]",
				err
			)

		end

	end





	-- ========================================================
	-- CLICK OPEN
	-- ========================================================


	button.MouseButton1Click:Connect(function()


		picker.Open =
			not picker.Open


		holder.Visible =
			picker.Open


	end)





	-- ========================================================
	-- DRAG SUPPORT
	-- ========================================================


	local dragging = false



	svBox.InputBegan:Connect(function(input)

		if input.UserInputType ==
			Enum.UserInputType.MouseButton1
		then

			dragging = true

		end

	end)





	Services.UserInputService.InputEnded:Connect(function(input)

		if input.UserInputType ==
			Enum.UserInputType.MouseButton1
		then

			dragging = false

		end

	end)





	Services.UserInputService.InputChanged:Connect(function(input)


		if not dragging then
			return
		end



		if input.UserInputType ==
			Enum.UserInputType.MouseMovement
		then


			local x =
				math.clamp(
					(input.Position.X - svBox.AbsolutePosition.X)
					/
					svBox.AbsoluteSize.X,
					0,
					1
				)


			local y =
				math.clamp(
					(input.Position.Y - svBox.AbsolutePosition.Y)
					/
					svBox.AbsoluteSize.Y,
					0,
					1
				)



			local color =
				Color3.fromHSV(
					x,
					1-y,
					1
				)


			update(color)


		end


	end)





	-- ========================================================
	-- PUBLIC API
	-- ========================================================


	function picker:SetValue(color)


		update(
			color
		)


	end





	function picker:GetValue()

		return picker.Value

	end





	picker.Instance =
		button



	return picker

end



return ColorPicker
