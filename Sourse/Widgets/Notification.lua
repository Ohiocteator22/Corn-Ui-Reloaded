-- ============================================================
-- CORNUI NOTIFICATION WIDGET
-- ============================================================

local Services =
	require(script.Parent.Parent.Core.Services)


local Utils =
	require(script.Parent.Parent.Core.Utils)


local Notification = {}

Notification.__index = Notification





-- ============================================================
-- TYPE DATA
-- ============================================================

local TypeColors = {

	success =
		Color3.fromRGB(
			70,
			200,
			110
		),

	error =
		Color3.fromRGB(
			230,
			75,
			75
		),

	warning =
		Color3.fromRGB(
			255,
			175,
			45
		),

	info =
		Color3.fromRGB(
			80,
			170,
			255
		),

}



local TypeIcons = {

	success = "✓",

	error = "✕",

	warning = "!",

	info = "i",

}







-- ============================================================
-- CREATE
-- ============================================================

function Notification.new(window, config)


	config =
		config or {}



	local self =
		setmetatable({}, Notification)



	self.Window =
		window



	self.Title =
		config.Title
		or "Notification"



	self.Content =
		config.Content
		or ""



	self.Duration =
		config.Duration
		or 4



	self.Type =
		config.Type
		or "info"



	self.Color =
		TypeColors[self.Type]
		or Color3.fromRGB(
			255,
			255,
			255
		)



	self.Icon =
		TypeIcons[self.Type]
		or "i"





	self:_Create()



	return self

end





-- ============================================================
-- BUILD UI
-- ============================================================

function Notification:_Create()



	local window =
		self.Window





	window.NotificationCount =
		(window.NotificationCount or 0)
		+
		1





	local frame =
		Utils.Create(
			"Frame",
			{

				Name =
					"Notification",


				Size =
					UDim2.new(
						0,
						window._touch and 300 or 360,
						0,
						70
					),


				BackgroundColor3 =
					window.Theme.Header
					or
					Color3.fromRGB(
						35,
						35,
						40
					),


				BackgroundTransparency =
					1,


				LayoutOrder =
					window.NotificationCount,


				ZIndex =
					200,


				ClipsDescendants =
					true,


			},

			{

				Utils.Corner(12),


				Utils.Stroke(
					self.Color,
					1
				),


				Utils.Create(
					"UIPadding",
					{

						PaddingTop =
							UDim.new(
								0,
								10
							),


						PaddingBottom =
							UDim.new(
								0,
								10
							),


						PaddingLeft =
							UDim.new(
								0,
								12
							),


						PaddingRight =
							UDim.new(
								0,
								12
							),

					}
				),


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





	self.Frame =
		frame





	frame.Parent =
		window.NotificationHolder





	local title =
		Utils.Create(
			"TextLabel",
			{

				Text =
					self.Icon
					..
					"  "
					..
					self.Title,


				Font =
					Enum.Font.GothamBold,


				TextSize =
					window._touch and 16 or 14,


				TextColor3 =
					Color3.fromRGB(
						255,
						255,
						255
					),


				BackgroundTransparency =
					1,


				Size =
					UDim2.new(
						1,
						0,
						0,
						22
					),


				TextXAlignment =
					Enum.TextXAlignment.Left,


				TextTransparency =
					1,


				LayoutOrder =
					1

			}
		)



	title.Parent =
		frame



	self.TitleLabel =
		title





	local content =
		Utils.Create(
			"TextLabel",
			{

				Text =
					self.Content,


				Font =
					Enum.Font.Gotham,


				TextSize =
					window._touch and 14 or 12,


				TextColor3 =
					Color3.fromRGB(
						180,
						180,
						180
					),


				BackgroundTransparency =
					1,


				AutomaticSize =
					Enum.AutomaticSize.Y,


				Size =
					UDim2.new(
						1,
						0,
						0,
						0
					),


				TextWrapped =
					true,


				TextXAlignment =
					Enum.TextXAlignment.Left,


				TextTransparency =
					1,


				LayoutOrder =
					2

			}
		)



	content.Parent =
		frame



	self.ContentLabel =
		content





	local bar =
		Utils.Create(
			"Frame",
			{

				Size =
					UDim2.new(
						1,
						0,
						0,
						3
					),


				BackgroundColor3 =
					self.Color,


				BackgroundTransparency =
					1,


				LayoutOrder =
					3

			},

			{

				Utils.Corner(2)

			}
		)



	bar.Parent =
		frame



	self.Bar =
		bar





	self:_Animate()

end







-- ============================================================
-- ANIMATION
-- ============================================================

function Notification:_Animate()



	Utils.Tween(
		self.Frame,
		{
			BackgroundTransparency = 0
		},
		0.2
	)



	Utils.Tween(
		self.TitleLabel,
		{
			TextTransparency = 0
		},
		0.2
	)



	Utils.Tween(
		self.ContentLabel,
		{
			TextTransparency = 0
		},
		0.2
	)



	Utils.Tween(
		self.Bar,
		{
			BackgroundTransparency = 0
		},
		0.2
	)





	task.delay(
		self.Duration,
		function()

			self:Destroy()

		end
	)

end





-- ============================================================
-- DESTROY
-- ============================================================

function Notification:Destroy()



	if not self.Frame then
		return
	end





	Utils.Tween(
		self.Frame,
		{
			BackgroundTransparency = 1
		},
		0.25
	)





	task.delay(
		0.3,
		function()


			if self.Frame then

				self.Frame:Destroy()

			end


		end
	)


end





return Notification
