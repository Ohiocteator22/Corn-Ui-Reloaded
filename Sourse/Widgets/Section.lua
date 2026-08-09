-- ============================================================
-- CORNUI SECTION WIDGET
-- ============================================================


local Utils = require(
	script.Parent.Parent.Core.Utils
)

local State = require(
	script.Parent.Parent.Core.State
)


local Section = {}

Section.__index = Section



-- ============================================================
-- CREATE
-- ============================================================

function Section.new(parent, config)

	config = config or {}


	local self =
		setmetatable({}, Section)



	self.Parent = parent


	self.Title =
		config.Name
		or config.Title
		or "Section"



	self.Collapsible =
		config.Collapsible
		or false



	self.Open =
		true



	self:_Create()



	return self

end




-- ============================================================
-- BUILD
-- ============================================================

function Section:_Create()


	State:RegisterWidget(self)



	local container = Utils.Create(
		"Frame",
		{

			Name = self.Title,


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
							6
						),


					SortOrder =
						Enum.SortOrder.LayoutOrder

				}
			)

		}

	)



	container.Parent =
		self.Parent



	self.Container =
		container




	-- ============================
	-- TITLE
	-- ============================


	local title = Utils.Create(
		"TextLabel",
		{

			Name = "SectionTitle",


			Text =
				self.Title,


			BackgroundTransparency = 1,


			Size =
				UDim2.new(
					1,
					0,
					0,
					24
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
		container



	self.TitleLabel =
		title




	-- ============================
	-- CONTENT HOLDER
	-- ============================


	local content = Utils.Create(
		"Frame",
		{

			Name = "Content",


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


			LayoutOrder = 2

		},

		{


			Utils.Create(
				"UIListLayout",
				{

					Padding =
						UDim.new(
							0,
							6
						),

					SortOrder =
						Enum.SortOrder.LayoutOrder

				}
			)

		}

	)



	content.Parent =
		container



	self.Content =
		content



end





-- ============================================================
-- METHODS
-- ============================================================


function Section:SetTitle(text)


	self.Title = text


	if self.TitleLabel then

		self.TitleLabel.Text = text

	end

end




function Section:SetVisible(state)


	self.Container.Visible =
		state


end




function Section:Add(widget)


	if widget.Instance then

		widget.Instance.Parent =
			self.Content

	end


end




function Section:Destroy()


	if self.Container then

		self.Container:Destroy()

	end


	self.Container = nil


end



return Section
