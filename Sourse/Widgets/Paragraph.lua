-- ============================================================
-- CORNUI PARAGRAPH WIDGET
-- ============================================================


local Utils = require(
	script.Parent.Parent.Core.Utils
)

local State = require(
	script.Parent.Parent.Core.State
)



local Paragraph = {}

Paragraph.__index = Paragraph




-- ============================================================
-- CREATE
-- ============================================================

function Paragraph.new(parent, config)

	config = config or {}


	local self =
		setmetatable({}, Paragraph)



	self.Parent = parent


	self.Title =
		config.Title


	self.Text =
		config.Text
		or config.Content
		or ""



	self.TextSize =
		config.TextSize
		or 14



	self:_Create()



	return self

end





-- ============================================================
-- BUILD
-- ============================================================

function Paragraph:_Create()


	State:RegisterWidget(self)



	local holder = Utils.Create(
		"Frame",
		{

			Name = "Paragraph",


			BackgroundTransparency = 1,


			Size =
				UDim2.new(
					1,
					0,
					0,
					0
				),


			AutomaticSize =
				Enum.AutomaticSize.Y,


			LayoutOrder =
				#self.Parent:GetChildren()

		},

		{

			Utils.Create(
				"UIListLayout",
				{

					Padding =
						UDim.new(
							0,
							4
						),


					SortOrder =
						Enum.SortOrder.LayoutOrder

				}
			)

		}

	)



	holder.Parent =
		self.Parent



	self.Instance =
		holder





	-- ========================================================
	-- TITLE
	-- ========================================================


	if self.Title then


		local title = Utils.Create(
			"TextLabel",
			{

				Name = "Title",


				Text =
					self.Title,


				BackgroundTransparency = 1,


				Size =
					UDim2.new(
						1,
						0,
						0,
						22
					),


				TextColor3 =
					Color3.fromRGB(
						255,
						255,
						255
					),


				TextSize = 15,


				Font =
					Enum.Font.GothamBold,


				TextXAlignment =
					Enum.TextXAlignment.Left,


				LayoutOrder = 1

			}

		)



		title.Parent =
			holder



		self.TitleLabel =
			title


	end





	-- ========================================================
	-- CONTENT
	-- ========================================================


	local content = Utils.Create(
		"TextLabel",
		{

			Name = "Content",


			Text =
				self.Text,


			BackgroundTransparency = 1,


			Size =
				UDim2.new(
					1,
					0,
					0,
					0
				),


			AutomaticSize =
				Enum.AutomaticSize.Y,


			TextWrapped = true,


			TextYAlignment =
				Enum.TextYAlignment.Top,


			TextXAlignment =
				Enum.TextXAlignment.Left,


			TextColor3 =
				Color3.fromRGB(
					180,
					180,
					185
				),


			TextSize =
				self.TextSize,


			Font =
				Enum.Font.Gotham,


			LayoutOrder =
				2

		}

	)



	content.Parent =
		holder



	self.ContentLabel =
		content



end





-- ============================================================
-- METHODS
-- ============================================================


function Paragraph:SetText(text)


	self.Text = text


	if self.ContentLabel then

		self.ContentLabel.Text = text

	end


end





function Paragraph:SetTitle(text)


	self.Title = text


	if self.TitleLabel then

		self.TitleLabel.Text = text

	end


end





function Paragraph:SetTextSize(size)


	self.TextSize = size


	if self.ContentLabel then

		self.ContentLabel.TextSize = size

	end


end





function Paragraph:SetColor(color)


	if self.ContentLabel then

		self.ContentLabel.TextColor3 = color

	end


end





function Paragraph:Destroy()


	if self.Instance then

		self.Instance:Destroy()

	end


	self.Instance = nil


end





return Paragraph
