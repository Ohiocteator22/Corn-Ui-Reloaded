-- ============================================================
-- CORNUI TOGGLE WIDGET
-- ============================================================


local Toggle = {}



local ThemeManager =
	require(
		script.Parent.Parent.Core.ThemeManager
	)



local Utils =
	require(
		script.Parent.Parent.Core.Utils
	)



local State =
	require(
		script.Parent.Parent.Core.State
	)





-- ============================================================
-- CREATE
-- ============================================================

function Toggle.new(parent, config)


	config = config or {}



	local self =
		setmetatable({}, Toggle)



	self.Parent =
		parent



	self.Name =
		config.Name
		or "Toggle"



	self.Value =
		config.Default
		or false



	self.Callback =
		config.Callback
		or function() end



	self.Flag =
		config.Flag



	self:_Create()



	return self


end







-- ============================================================
-- BUILD UI
-- ============================================================

function Toggle:_Create()



	State:RegisterWidget(
		self
	)



	local button =
		Utils.Create(
			"TextButton",
			{

				Name =
					self.Name,


				Size =
					UDim2.new(
						1,
						0,
						0,
						35
					),


				BackgroundColor3 =
					ThemeManager:GetColor(
						"Element"
					),


				Text = "",

			}
		)



	button.Parent =
		self.Parent



	self.Instance =
		button






	local label =
		Utils.Create(
			"TextLabel",
			{

				Name =
					"Label",


				Size =
					UDim2.new(
						0.7,
						0,
						1,
						0
					),


				BackgroundTransparency =
					1,


				Text =
					self.Name,


				TextColor3 =
					ThemeManager:GetColor(
						"Text"
					),


				Font =
					ThemeManager:GetFont(
						"Main"
					),


				TextXAlignment =
					Enum.TextXAlignment.Left

			}
		)



	label.Parent =
		button



	self.Label =
		label






	local indicator =
		Utils.Create(
			"Frame",
			{

				Name =
					"Indicator",


				Size =
					UDim2.new(
						0,
						22,
						0,
						22
					),


				Position =
					UDim2.new(
						1,
						-30,
						0.5,
						-11
					),


				BackgroundColor3 =
					self.Value
					and ThemeManager:GetColor(
						"Accent"
					)
					or ThemeManager:GetColor(
						"ToggleButton"
					)

			}
		)



	indicator.Parent =
		button



	self.Indicator =
		indicator





	-- Flag

	if self.Flag then


		State:SetFlag(
			self.Flag,
			self.Value
		)


	end






	button.MouseButton1Click:Connect(function()


		self:SetValue(
			not self.Value
		)


	end)



end







-- ============================================================
-- UPDATE
-- ============================================================

function Toggle:SetValue(value)



	self.Value =
		value



	if self.Indicator then


		self.Indicator.BackgroundColor3 =
			value
			and ThemeManager:GetColor(
				"Accent"
			)
			or ThemeManager:GetColor(
				"ToggleButton"
			)



	end





	if self.Flag then


		State:SetFlag(
			self.Flag,
			value
		)


	end





	local success,err =
		pcall(
			self.Callback,
			value
		)



	if not success then


		warn(
			"[CornUi Toggle Error]",
			err
		)


	end



end







-- ============================================================
-- GET VALUE
-- ============================================================

function Toggle:GetValue()


	return self.Value


end







-- ============================================================
-- DESTROY
-- ============================================================

function Toggle:Destroy()


	if self.Instance then

		self.Instance:Destroy()

	end



	self.Instance =
		nil


end







return Toggle
