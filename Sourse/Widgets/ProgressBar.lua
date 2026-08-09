-- ============================================================
-- CORNUI PROGRESS BAR WIDGET
-- ============================================================


local Utils = require(
	script.Parent.Parent.Core.Utils
)

local Services = require(
	script.Parent.Parent.Core.Services
)

local ProgressBar = {}

ProgressBar.__index = ProgressBar



-- ============================================================
-- CREATE
-- ============================================================

function ProgressBar.new(parent, config)

	config = config or {}


	local self =
		setmetatable({}, ProgressBar)



	self.Parent = parent


	self.Min =
		config.Min
		or 0


	self.Max =
		config.Max
		or 100


	self.Value =
		config.Value
		or 0


	self.Size =
		config.Size
		or UDim2.new(
			1,
			0,
			0,
			20
		)



	self.Background =
		config.Background
		or Color3.fromRGB(
			40,
			40,
			45
		)



	self.Color =
		config.Color
		or Color3.fromRGB(
			255,
			196,
			48
		)



	self.ShowText =
		config.ShowText ~= false



	self:_Create()



	return self

end




-- ============================================================
-- BUILD
-- ============================================================

function ProgressBar:_Create()


	local holder =
		Utils.Create(
			"Frame",
			{

				Name =
					"ProgressBar",


				Size =
					self.Size,


				BackgroundColor3 =
					self.Background,


				BorderSizePixel = 0,


			}

		)



	holder.Parent =
		self.Parent



	local corner =
		Utils.Create(
			"UICorner",
			{

				CornerRadius =
					UDim.new(
						0,
						6
					)

			}
		)


	corner.Parent =
		holder



	self.Instance =
		holder





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
					self.Color,


				BorderSizePixel = 0,


			}
		)



	fill.Parent =
		holder



	local fillCorner =
		Utils.Create(
			"UICorner",
			{

				CornerRadius =
					UDim.new(
						0,
						6
					)

			}
		)


	fillCorner.Parent =
		fill



	self.Fill =
		fill





	if self.ShowText then


		local label =
			Utils.Create(
				"TextLabel",
				{

					Name =
						"ProgressText",


					BackgroundTransparency = 1,


					Size =
						UDim2.fromScale(
							1,
							1
						),


					Text =
						"",


					TextColor3 =
						Color3.fromRGB(
							255,
							255,
							255
						),


					Font =
						Enum.Font.GothamBold,


					TextSize = 12

				}
			)



		label.Parent =
			holder



		self.Label =
			label


	end



	self:_Update()

end




-- ============================================================
-- UPDATE
-- ============================================================

function ProgressBar:_Update(animated)


	local percent =
		math.clamp(
			(self.Value - self.Min)
			/
			(self.Max - self.Min),
			0,
			1
		)



	local size =
		UDim2.new(
			percent,
			0,
			1,
			0
		)



	if animated then


		local tween =
			Services.TweenService:Create(

				self.Fill,

				TweenInfo.new(
					0.25,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Size = size
				}

			)



		tween:Play()



	else


		self.Fill.Size =
			size


	end





	if self.Label then

		self.Label.Text =
			math.floor(
				percent * 100
			)
			.. "%"

	end


end




-- ============================================================
-- METHODS
-- ============================================================

function ProgressBar:SetValue(value)


	self.Value =
		math.clamp(
			value,
			self.Min,
			self.Max
		)


	self:_Update(true)


end





function ProgressBar:SetColor(color)


	self.Color =
		color


	if self.Fill then

		self.Fill.BackgroundColor3 =
			color

	end


end





function ProgressBar:SetRange(min,max)


	self.Min =
		min


	self.Max =
		max


	self:_Update()


end





function ProgressBar:Destroy()


	if self.Instance then

		self.Instance:Destroy()

	end


	self.Instance = nil


end





return ProgressBar
