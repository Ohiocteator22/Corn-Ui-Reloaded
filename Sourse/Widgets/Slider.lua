-- ============================================================
-- CORNUI SLIDER WIDGET
-- ============================================================


local Slider = {}


local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)


local Services =
	require(script.Parent.Parent.Core.Services)



function Slider:Create(Tab, config)


	config = config or {}



	local slider = {

		Type = "Slider",

		Name = config.Name or "Slider",

		Min = config.Min or 0,

		Max = config.Max or 100,

		Value = config.Default or config.Min or 0,

		Increment = config.Increment or 1,

		Callback = config.Callback or function() end,

		Flag = config.Flag,

		Tab = Tab,

	}



	table.insert(
		Tab.Widgets,
		slider
	)



	-- Flag system

	if slider.Flag then

		Tab.Window.Flags =
			Tab.Window.Flags or {}

		Tab.Window.Flags[slider.Flag] =
			slider.Value

	end



	-- ========================================================
	-- UI
	-- ========================================================


	local holder =
		Instance.new("Frame")


	holder.Name =
		slider.Name


	holder.Size =
		UDim2.new(
			1,
			0,
			0,
			45
		)


	holder.BackgroundTransparency =
		1


	holder.Parent =
		Tab.Container





	local title =
		Instance.new("TextLabel")


	title.Size =
		UDim2.new(
			1,
			0,
			0,
			18
		)


	title.BackgroundTransparency =
		1


	title.Text =
		slider.Name .. ": " .. slider.Value


	title.TextColor3 =
		ThemeManager:GetColor("Text")


	title.Font =
		ThemeManager:GetFont("Main")


	title.TextXAlignment =
		Enum.TextXAlignment.Left


	title.Parent =
		holder





	local bar =
		Instance.new("Frame")


	bar.Name =
		"SliderBar"


	bar.Position =
		UDim2.new(
			0,
			0,
			0,
			25
		)


	bar.Size =
		UDim2.new(
			1,
			0,
			0,
			8
		)


	bar.BackgroundColor3 =
		ThemeManager:GetColor("Element")


	bar.Parent =
		holder





	local fill =
		Instance.new("Frame")


	fill.Name =
		"Fill"


	fill.Size =
		UDim2.new(
			0,
			0,
			1,
			0
		)


	fill.BackgroundColor3 =
		ThemeManager:GetColor("Accent")


	fill.Parent =
		bar





	-- ========================================================
	-- VALUE HANDLING
	-- ========================================================


	local function round(value)


		local increment =
			slider.Increment


		return math.floor(
			value / increment + 0.5
		)
		*
		increment


	end





	local function update(value, fireCallback)


		value =
			math.clamp(
				value,
				slider.Min,
				slider.Max
			)


		value =
			round(value)



		slider.Value =
			value



		local percent =
			(value - slider.Min)
			/
			(slider.Max - slider.Min)



		fill.Size =
			UDim2.new(
				percent,
				0,
				1,
				0
			)



		title.Text =
			slider.Name
			..
			": "
			..
			tostring(value)



		if slider.Flag then

			Tab.Window.Flags[slider.Flag] =
				value

		end



		if fireCallback then

			local success,err =
				pcall(
					slider.Callback,
					value
				)


			if not success then

				warn(
					"[CornUi Slider Error]",
					err
				)

			end

		end

	end



	update(
		slider.Value,
		false
	)



	-- ========================================================
	-- DRAGGING
	-- ========================================================


	local dragging = false



	local function setFromInput(input)


		local position =
			input.Position.X



		local start =
			bar.AbsolutePosition.X



		local width =
			bar.AbsoluteSize.X



		local percent =
			math.clamp(
				(position - start) / width,
				0,
				1
			)



		local value =
			slider.Min
			+
			(
				slider.Max
				-
				slider.Min
			)
			*
			percent



		update(
			value,
			true
		)

	end





	bar.InputBegan:Connect(function(input)


		if input.UserInputType ==
			Enum.UserInputType.MouseButton1
			or
			input.UserInputType ==
			Enum.UserInputType.Touch
		then

			dragging = true

			setFromInput(input)

		end


	end)





	Services.UserInputService.InputChanged:Connect(function(input)


		if not dragging then
			return
		end



		if input.UserInputType ==
			Enum.UserInputType.MouseMovement
			or
			input.UserInputType ==
			Enum.UserInputType.Touch
		then

			setFromInput(input)

		end


	end)





	Services.UserInputService.InputEnded:Connect(function(input)


		if input.UserInputType ==
			Enum.UserInputType.MouseButton1
		then

			dragging = false

		end


	end)



	-- ========================================================
	-- PUBLIC API
	-- ========================================================


	function slider:SetValue(value)


		update(
			value,
			true
		)


	end





	function slider:GetValue()

		return slider.Value

	end



	slider.Instance =
		holder



	return slider

end



return Slider
