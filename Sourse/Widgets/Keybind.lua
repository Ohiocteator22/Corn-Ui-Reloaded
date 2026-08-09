-- ============================================================
-- CORNUI KEYBIND WIDGET
-- ============================================================


local Services = require(
	script.Parent.Parent.Core.Services
)


local Utils = require(
	script.Parent.Parent.Core.Utils
)


local State = require(
	script.Parent.Parent.Core.State
)



local Keybind = {}

Keybind.__index = Keybind



-- ============================================================
-- CREATE
-- ============================================================

function Keybind.new(parent, config)

	config = config or {}


	local self =
		setmetatable({}, Keybind)



	self.Parent = parent


	self.Name =
		config.Name or "Keybind"



	self.Key =
		config.Key or Enum.KeyCode.Unknown



	self.Callback =
		config.Callback or function() end



	self.Listening = false



	self:_Create()


	self:_Connect()



	return self

end




-- ============================================================
-- BUILD UI
-- ============================================================

function Keybind:_Create()


	State:RegisterWidget(self)



	local holder = Utils.Create(
		"Frame",
		{

			Name = self.Name,


			BackgroundTransparency = 1,


			Size =
				UDim2.new(
					1,
					0,
					0,
					32
				),


			LayoutOrder =
				#self.Parent:GetChildren()

		},

		{

			Utils.Create(
				"UIListLayout",
				{

					FillDirection =
						Enum.FillDirection.Horizontal,


					HorizontalAlignment =
						Enum.HorizontalAlignment.Right,


					VerticalAlignment =
						Enum.VerticalAlignment.Center

				}
			)

		}

	)



	holder.Parent =
		self.Parent



	self.Instance =
		holder




	local label = Utils.Create(
		"TextLabel",
		{

			Text =
				self.Name,


			BackgroundTransparency = 1,


			Size =
				UDim2.new(
					0.7,
					0,
					1,
					0
				),


			TextColor3 =
				Color3.fromRGB(
					220,
					220,
					220
				),


			Font =
				Enum.Font.Gotham,


			TextSize = 14,


			TextXAlignment =
				Enum.TextXAlignment.Left

		}

	)



	label.Parent =
		holder



	self.Label =
		label





	local button = Utils.Create(
		"TextButton",
		{

			Text =
				self:_KeyName(),


			BackgroundColor3 =
				Color3.fromRGB(
					40,
					40,
					45
				),


			Size =
				UDim2.new(
					0,
					80,
					0,
					26
				),


			Font =
				Enum.Font.GothamBold,


			TextSize = 13,


			TextColor3 =
				Color3.fromRGB(
					255,
					255,
					255
				)

		},

		{

			Utils.Corner(6)

		}

	)



	button.Parent =
		holder



	self.Button =
		button



	button.MouseButton1Click:Connect(
		function()

			self:BeginBind()

		end
	)


end




-- ============================================================
-- INPUT
-- ============================================================

function Keybind:_Connect()


	self.Connection =
		Services.UserInputService.InputBegan:Connect(
			function(input, processed)

				if processed then
					return
				end



				if self.Listening then


					if input.KeyCode ~= Enum.KeyCode.Unknown then

						self:SetKey(
							input.KeyCode
						)


						self.Listening = false


					end


					return

				end





				if input.KeyCode == self.Key then

					self.Callback()

				end


			end
		)


end




-- ============================================================
-- REBIND
-- ============================================================

function Keybind:BeginBind()


	self.Listening = true


	self.Button.Text =
		"..."


end




function Keybind:SetKey(key)


	self.Key = key


	self.Button.Text =
		self:_KeyName()



end



function Keybind:_KeyName()


	if self.Key == Enum.KeyCode.Unknown then

		return "None"

	end


	return self.Key.Name

end




-- ============================================================
-- METHODS
-- ============================================================


function Keybind:SetCallback(callback)

	self.Callback =
		callback or function() end

end



function Keybind:GetKey()

	return self.Key

end




function Keybind:Destroy()


	if self.Connection then

		self.Connection:Disconnect()

	end



	if self.Instance then

		self.Instance:Destroy()

	end



end



return Keybind
