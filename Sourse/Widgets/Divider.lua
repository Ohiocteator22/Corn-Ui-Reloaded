-- ============================================================
-- CORNUI DIVIDER WIDGET
-- ============================================================


local Utils = require(
	script.Parent.Parent.Core.Utils
)

local State = require(
	script.Parent.Parent.Core.State
)


local Divider = {}

Divider.__index = Divider



-- ============================================================
-- CREATE
-- ============================================================

function Divider.new(parent, config)

	config = config or {}


	local self =
		setmetatable({}, Divider)



	self.Parent = parent


	self.Color =
		config.Color


	self.Thickness =
		config.Thickness
		or 1


	self.Margin =
		config.Margin
		or 6



	self:_Create()



	return self

end




-- ============================================================
-- BUILD
-- ============================================================

function Divider:_Create()


	State:RegisterWidget(self)



	local holder = Utils.Create(
		"Frame",
		{

			Name = "Divider",


			BackgroundTransparency = 1,


			Size =
				UDim2.new(
					1,
					0,
					0,
					self.Thickness + self.Margin * 2
				),


			LayoutOrder =
				#self.Parent:GetChildren()

		}

	)



	holder.Parent =
		self.Parent




	local line = Utils.Create(
		"Frame",
		{

			Name = "Line",


			BackgroundColor3 =
				self.Color
				or Color3.fromRGB(
					60,
					60,
					65
				),


			BorderSizePixel = 0,


			Position =
				UDim2.new(
					0,
					0,
					0.5,
					0
				),


			AnchorPoint =
				Vector2.new(
					0,
					0.5
				),


			Size =
				UDim2.new(
					1,
					0,
					0,
					self.Thickness
				)

		}

	)



	line.Parent =
		holder



	self.Instance =
		holder


	self.Line =
		line


end




-- ============================================================
-- METHODS
-- ============================================================

function Divider:SetColor(color)


	self.Color = color


	if self.Line then

		self.Line.BackgroundColor3 =
			color

	end


end



function Divider:SetThickness(value)


	self.Thickness = value


	if self.Line then

		self.Line.Size =
			UDim2.new(
				1,
				0,
				0,
				value
			)

	end


end




function Divider:Destroy()


	if self.Instance then

		self.Instance:Destroy()

	end


	self.Instance = nil


end



return Divider
