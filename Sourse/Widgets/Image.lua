-- ============================================================
-- CORNUI IMAGE WIDGET
-- ============================================================

local Utils =
	require(script.Parent.Parent.Core.Utils)


local Image = {}

Image.__index = Image





-- ============================================================
-- CREATE
-- ============================================================

function Image.new(Tab, config)


	config = config or {}



	local self =
		setmetatable({}, Image)



	self.Type =
		"Image"



	self.Tab =
		Tab



	self.Parent =
		Tab.Page



	self.Image =
		config.Image
		or config.ImageId
		or ""



	self.Size =
		config.Size
		or UDim2.new(
			0,
			100,
			0,
			100
		)



	self.Transparency =
		config.Transparency
		or 0



	self.Rotation =
		config.Rotation
		or 0



	self.CornerRadius =
		config.CornerRadius
		or 0





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

function Image:_Create()



	local holder =
		Utils.Create(
			"Frame",
			{

				Name =
					"ImageHolder",


				BackgroundTransparency =
					1,


				Size =
					self.Size,


				LayoutOrder =
					#self.Parent:GetChildren()

			}
		)



	holder.Parent =
		self.Parent



	self.Instance =
		holder





	local image =
		Utils.Create(
			"ImageLabel",
			{

				Name =
					"Image",


				Image =
					self.Image,


				BackgroundTransparency =
					1,


				Size =
					UDim2.fromScale(
						1,
						1
					),


				ImageTransparency =
					self.Transparency,


				Rotation =
					self.Rotation,


				ScaleType =
					Enum.ScaleType.Stretch,


				BorderSizePixel =
					0,

			}
		)



	image.Parent =
		holder



	self.ImageObject =
		image





	if self.CornerRadius > 0 then


		local corner =
			Utils.Create(
				"UICorner",
				{

					CornerRadius =
						UDim.new(
							0,
							self.CornerRadius
						)

				}
			)



		corner.Parent =
			image



		self.Corner =
			corner


	end



end





-- ============================================================
-- METHODS
-- ============================================================

function Image:SetImage(id)


	self.Image =
		id



	if self.ImageObject then

		self.ImageObject.Image =
			id

	end


end





function Image:SetSize(size)


	self.Size =
		size



	if self.Instance then

		self.Instance.Size =
			size

	end


end





function Image:SetTransparency(value)


	self.Transparency =
		value



	if self.ImageObject then

		self.ImageObject.ImageTransparency =
			value

	end


end





function Image:SetRotation(value)


	self.Rotation =
		value



	if self.ImageObject then

		self.ImageObject.Rotation =
			value

	end


end





function Image:SetCornerRadius(value)


	self.CornerRadius =
		value



	if self.Corner then

		self.Corner.CornerRadius =
			UDim.new(
				0,
				value
			)

	end


end





function Image:Destroy()


	if self.Instance then

		self.Instance:Destroy()

	end



	self.Instance =
		nil


end





return Image
