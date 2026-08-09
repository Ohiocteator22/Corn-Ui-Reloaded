-- ============================================================
-- CORNUI LABEL WIDGET
-- ============================================================

local Utils = require(
	script.Parent.Parent.Core.Utils
)

local State = require(
	script.Parent.Parent.Core.State
)


local Label = {}

Label.__index = Label



-- ============================================================
-- CREATE
-- ============================================================

function Label.new(parent, config)

	config = config or {}

	local self =
		setmetatable({}, Label)



	self.Parent = parent


	self.Text =
		config.Text or ""


	self.Size =
		config.Size


	self.TextSize =
		config.TextSize


	self.Color =
		config.Color


	self.Font =
		config.Font



	self:_Create()



	return self

end



-- ============================================================
-- BUILD
-- ============================================================

function Label:_Create()


	State:RegisterWidget(self)



	local parent = self.Parent



	local label = Utils.Create(
		"TextLabel",
		{

			Name = "Label",


			Text = self.Text,


			BackgroundTransparency = 1,


			Size =
				self.Size
				or UDim2.new(
					1,
					0,
					0,
					22
				),



			TextColor3 =
				self.Color
				or Color3.fromRGB(
					220,
					220,
					220
				),



			TextSize =
				self.TextSize
				or 14,



			Font =
				self.Font
				or Enum.Font.Gotham,



			TextXAlignment =
				Enum.TextXAlignment.Left,



			TextWrapped = true,



			LayoutOrder =
				#parent:GetChildren()

		}

	)



	label.Parent = parent



	self.Instance = label


end



-- ============================================================
-- METHODS
-- ============================================================

function Label:SetText(text)

	self.Text = text


	if self.Instance then

		self.Instance.Text = text

	end

end



function Label:SetColor(color)

	self.Color = color


	if self.Instance then

		self.Instance.TextColor3 = color

	end

end



function Label:SetFont(font)

	self.Font = font


	if self.Instance then

		self.Instance.Font = font

	end

end



function Label:Destroy()

	if self.Instance then

		self.Instance:Destroy()

	end


	self.Instance = nil

end



return Label
