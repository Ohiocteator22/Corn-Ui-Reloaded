-- ============================================================
-- CORNUI BUTTON WIDGET
-- ============================================================

local Button = {}


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)



function Button.new(Tab, config)


	config = config or {}



	local button = {


		Type = "Button",


		Name =
			config.Name or "Button",


		Callback =
			config.Callback or function()
			end,


		Tab = Tab,


	}



	table.insert(
		Tab.Elements,
		button
	)



	-- Create UI

	local instance =
		Tab.Window._create(
			"TextButton",
			{


				Name =
					button.Name,


				Size =
					UDim2.new(
						1,
						0,
						0,
						36
					),


				BackgroundColor3 =
					ThemeManager:GetColor(
						"Element"
					),


				Text =
					button.Name,


				TextColor3 =
					ThemeManager:GetColor(
						"Text"
					),


				Font =
					ThemeManager:GetFont(
						"Main"
					),


				TextSize = 14,


				BorderSizePixel = 0,


			}
		)



	instance.Parent =
		Tab.Page



	button.Instance =
		instance



	instance.MouseButton1Click:Connect(function()


		local success, err =
			pcall(
				button.Callback
			)


		if not success then

			warn(
				"[CornUi Button Error]",
				err
			)

		end


	end)



	-- Theme auto update

	ThemeManager:RegisterWidget(
		button,
		function(widget)

			if widget.Instance then

				widget.Instance.BackgroundColor3 =
					ThemeManager:GetColor(
						"Element"
					)


				widget.Instance.TextColor3 =
					ThemeManager:GetColor(
						"Text"
					)


				widget.Instance.Font =
					ThemeManager:GetFont(
						"Main"
					)

			end

		end
	)



	Tab.Window:RegisterWidget(
		button
	)



	return button

end



return Button
