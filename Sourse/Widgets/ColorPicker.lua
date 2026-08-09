-- ============================================================
-- CORNUI COLOR PICKER WIDGET
-- ============================================================

local ColorPicker = {}


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)


local Services =
	require(script.Parent.Parent.Core.Services)



function ColorPicker.new(Tab, config)


	config = config or {}



	local picker = {

		Type = "ColorPicker",

		Name =
			config.Name or "Color",


		Value =
			config.Default or Color3.fromRGB(
				255,
				255,
				255
			),


		Callback =
			config.Callback or function()
			end,


		Flag =
			config.Flag,


		Open = false,


		Tab = Tab,

	}



	table.insert(
		Tab.Elements,
		picker
	)



	-- Flag support

	if picker.Flag then

		Tab.Window.Flags =
			Tab.Window.Flags or {}


		Tab.Window.Flags[picker.Flag] =
			picker.Value

	end





	-- Main button

	local button =
		Tab.Window._create(
			"TextButton",
			{

				Name =
					picker.Name,


				Size =
					UDim2.new(
						1,
						0,
						0,
						38
					),


				BackgroundColor3 =
					ThemeManager:GetColor(
						"Element"
					),


				Text = "",


			}
		)



	button.Parent =
		Tab.Page





	local label =
		Tab.Window._create(
			"TextLabel",
			{

				Size =
					UDim2.new(
						1,
						-50,
						1,
						0
					),


				Position =
					UDim2.new(
						0,
						12,
						0,
						0
					),


				BackgroundTransparency = 1,


				Text =
					picker.Name,


				TextColor3 =
					ThemeManager:GetColor(
						"Text"
					),


				Font =
					ThemeManager:GetFont(
						"Main"
					),


				TextXAlignment =
					Enum.TextXAlignment.Left,

			}
		)



	label.Parent =
		button





	local preview =
		Tab.Window._create(
			"Frame",
			{

				Size =
					UDim2.new(
						0,
						25,
						0,
						25
					),


				Position =
					UDim2.new(
						1,
						-35,
						0.5,
						-12
					),


				BackgroundColor3 =
					picker.Value,

			}
		)



	preview.Parent =
		button





	local holder =
		Tab.Window._create(
			"Frame",
			{

				Name =
					picker.Name .. "_Picker",


				Size =
					UDim2.new(
						1,
						0,
						0,
						220
					),


				BackgroundColor3 =
					ThemeManager:GetColor(
						"Header"
					),


				Visible = false,

			}
		)



	holder.Parent =
		Tab.Page





	local svBox =
		Tab.Window._create(
			"Frame",
			{

				Size =
					UDim2.new(
						1,
						-30,
						0,
						170
					),


				BackgroundColor3 =
					Color3.fromRGB(
						255,
						0,
						0
					),

			}
		)



	svBox.Parent =
		holder





	local hue =
		Tab.Window._create(
			"Frame",
			{

				Size =
					UDim2.new(
						0,
						20,
						1,
						0
					),


				Position =
					UDim2.new(
						1,
						-20,
						0,
						0
					),

			}
		)



	hue.Parent =
		holder





	local hueGradient =
		Instance.new(
			UIGradient
		)



	hueGradient.Rotation = 90


	hueGradient.Color =
		ColorSequence.new({

			ColorSequenceKeypoint.new(
				0,
				Color3.fromRGB(
					255,
					0,
					0
				)
			),

			ColorSequenceKeypoint.new(
				0.33,
				Color3.fromRGB(
					0,
					255,
					0
				)
			),

			ColorSequenceKeypoint.new(
				0.66,
				Color3.fromRGB(
					0,
					0,
					255
				)
			),

			ColorSequenceKeypoint.new(
				1,
				Color3.fromRGB(
					255,
					0,
					0
				)
			),

		})


	hueGradient.Parent =
		hue





	local function update(color)


		picker.Value =
			color


		preview.BackgroundColor3 =
			color



		if picker.Flag then

			Tab.Window.Flags[picker.Flag] =
				color

		end



		local ok, err =
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





	button.MouseButton1Click:Connect(function()


		picker.Open =
			not picker.Open


		holder.Visible =
			picker.Open


	end)





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



			update(
				Color3.fromHSV(
					x,
					1-y,
					1
				)
			)

		end

	end)





	function picker:SetValue(color)

		update(color)

	end





	function picker:GetValue()

		return picker.Value

	end





	picker.Instance =
		button





	ThemeManager:RegisterWidget(
		picker,
		function(widget)

			if widget.Instance then

				widget.Instance.BackgroundColor3 =
					ThemeManager:GetColor(
						"Element"
					)

			end

		end
	)





	Tab.Window:RegisterWidget(
		picker
	)



	return picker

end



return ColorPicker
