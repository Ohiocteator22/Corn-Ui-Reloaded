-- ============================================================
-- CORNUI SLIDER WIDGET
-- ============================================================


local Utils =
	require(script.Parent.Parent.Core.Utils)


local Services =
	require(script.Parent.Parent.Core.Services)



local Slider = {}

Slider.__index = Slider






-- ============================================================
-- CREATE
-- ============================================================

function Slider.new(Tab, config)


	config =
		config or {}



	local self =
		setmetatable({}, Slider)



	self.Type =
		"Slider"



	self.Tab =
		Tab



	self.Parent =
		Tab.Page



	self.Name =
		config.Name
		or "Slider"



	self.Min =
		config.Min
		or 0



	self.Max =
		config.Max
		or 100



	self.Value =
		config.Default
		or self.Min



	self.Increment =
		config.Increment
		or 1



	self.Callback =
		config.Callback
		or function() end



	self.Flag =
		config.Flag



	self:_Create()



	table.insert(
		Tab.Elements,
		self
	)



	Tab.Window:RegisterWidget(
		self
	)



	return self

end







-- ============================================================
-- BUILD
-- ============================================================

function Slider:_Create()



	local holder =
		Utils.Create(
			"Frame",
			{

				Name =
					self.Name,


				Size =
					UDim2.new(
						1,
						0,
						0,
						45
					),


				BackgroundTransparency =
					1,


				LayoutOrder =
					#self.Parent:GetChildren()

			}
		)





	holder.Parent =
		self.Parent



	self.Instance =
		holder







	local title =
		Utils.Create(
			"TextLabel",
			{

				Size =
					UDim2.new(
						1,
						0,
						0,
						18
					),


				BackgroundTransparency =
					1,


				Text =
					self.Name
					.. ": "
					.. self.Value,


				TextColor3 =
					Color3.fromRGB(
						220,
						220,
						220
					),


				Font =
					Enum.Font.Gotham,


				TextSize =
					14,


				TextXAlignment =
					Enum.TextXAlignment.Left

			}
		)




	title.Parent =
		holder



	self.Title =
		title







	local bar =
		Utils.Create(
			"Frame",
			{

				Name =
					"SliderBar",


				Position =
					UDim2.new(
						0,
						0,
						0,
						25
					),


				Size =
					UDim2.new(
						1,
						0,
						0,
						8
					),


				BackgroundColor3 =
					Color3.fromRGB(
						45,
						45,
						50
					),


				BorderSizePixel =
					0

			}
		)



	bar.Parent =
		holder



	self.Bar =
		bar







	local fill =
		Utils.Create(
			"Frame",
			{

				Name =
					"Fill",


				Size =
					UDim2.new(
						0,
						0,
						1,
						0
					),


				BackgroundColor3 =
					Color3.fromRGB(
						255,
						196,
						48
					),


				BorderSizePixel =
					0

			}
		)



	fill.Parent =
		bar



	self.Fill =
		fill





	self:_Update(
		self.Value,
		false
	)







	-- ========================================================
	-- INPUT
	-- ========================================================


	local dragging =
		false





	local function setFromInput(input)



		local percent =
			math.clamp(
				(
					input.Position.X
					-
					bar.AbsolutePosition.X
				)
				/
				bar.AbsoluteSize.X,
				0,
				1
			)




		local value =
			self.Min
			+
			(
				self.Max
				-
				self.Min
			)
			*
			percent




		self:_Update(
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


			dragging =
				true



			setFromInput(
				input
			)


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


			setFromInput(
				input
			)


		end


	end)







	Services.UserInputService.InputEnded:Connect(function(input)


		if input.UserInputType ==
			Enum.UserInputType.MouseButton1
		then


			dragging =
				false


		end


	end)



end







-- ============================================================
-- UPDATE
-- ============================================================

function Slider:_Update(value, fire)



	value =
		math.clamp(
			value,
			self.Min,
			self.Max
		)





	value =
		math.floor(
			value / self.Increment + 0.5
		)
		*
		self.Increment





	self.Value =
		value





	local percent =
		(
			value
			-
			self.Min
		)
		/
		(
			self.Max
			-
			self.Min
		)





	self.Fill.Size =
		UDim2.new(
			percent,
			0,
			1,
			0
		)





	self.Title.Text =
		self.Name
		..
		": "
		..
		value





	if self.Flag then


		self.Tab.Window.Flags =
			self.Tab.Window.Flags
			or {}



		self.Tab.Window.Flags[self.Flag] =
			value


	end






	if fire then


		local success,err =
			pcall(
				self.Callback,
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







-- ============================================================
-- METHODS
-- ============================================================

function Slider:SetValue(value)



	self:_Update(
		value,
		true
	)



end






function Slider:GetValue()


	return self.Value


end






function Slider:SetRange(min,max)



	self.Min =
		min



	self.Max =
		max



	self:_Update(
		self.Value,
		false
	)



end






function Slider:Destroy()



	if self.Instance then

		self.Instance:Destroy()

	end



	self.Instance =
		nil



end






return Slider
