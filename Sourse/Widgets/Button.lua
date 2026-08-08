-- ============================================================
-- CORNUI BUTTON WIDGET
-- ============================================================


local Button = {}

local Utils =
	require(script.Parent.Parent.Core.Utils)


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)



function Button:Create(Tab, config)


	config = config or {}


	local button = {

		Type = "Button",

		Name = config.Name or "Button",

		Callback = config.Callback or function(){end},

		Tab = Tab,

	}


	table.insert(
		Tab.Widgets,
		button
	)



	-- UI creation will move here later

	local instance = Instance.new("TextButton")


	instance.Name =
		button.Name


	instance.Text =
		button.Name


	instance.BackgroundColor3 =
		ThemeManager:GetColor("Element")


	instance.Parent =
		Tab.Container



	instance.MouseButton1Click:Connect(function()


		local success,err =
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



	button.Instance =
		instance



	return button

end



return Button
