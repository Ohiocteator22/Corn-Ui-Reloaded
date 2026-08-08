-- ============================================================
-- CORNUI WINDOW CORE
-- Handles Window creation and runtime references
-- ============================================================


local Services = require(
	script.Parent.Parent.Core.Services
)

local State = require(
	script.Parent.Parent.Core.State
)

local Signals = require(
	script.Parent.Parent.Core.Signals
)

local Utils = require(
	script.Parent.Parent.Core.Utils
)


local Window = {}
Window.__index = Window



-- ============================================================
-- CREATE WINDOW
-- ============================================================

function Window.new(Library, config)

	config = config or {}


	local self = setmetatable({}, Window)


	self.Library = Library


	--===========================================================
	-- CONFIG
	--===========================================================

	self.Name = config.Name or "CornUi"

	self.Subtitle = config.Subtitle or ""

	self.Icon = config.Icon

	self.Theme = config.Theme or "Dark"

	self._touch = Services.UserInputService.TouchEnabled



	--===========================================================
	-- INTERNAL STORAGE
	--===========================================================

	self._tabs = {}

	self._pages = {}

	self._widgets = {}

	self._commands = {}

	self._plugins = {}


	self._notifCount = 0



	--===========================================================
	-- SIGNALS
	--===========================================================

	self.Signals = Signals.new()



	--===========================================================
	-- CREATE GUI
	--===========================================================


	self.Gui = Instance.new("ScreenGui")

	self.Gui.Name = "CornUi"

	self.Gui.IgnoreGuiInset = true

	self.Gui.ResetOnSpawn = false

	self.Gui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling



	self.Gui.Parent =
		Services.CoreGui or game:GetService("CoreGui")



	--===========================================================
	-- ROOT FRAME
	--===========================================================


	self.Main = Utils.Create(
		"Frame",
		{
			Name = "Window",

			Size = UDim2.new(
				0,
				self._touch and 340 or 520,
				0,
				self._touch and 420 or 500
			),

			Position =
				UDim2.fromScale(
					0.5,
					0.5
				),

			AnchorPoint =
				Vector2.new(
					0.5,
					0.5
				),

			BackgroundTransparency = 0,

			ZIndex = 10,
		}
	)



	self.Main.Parent = self.Gui



	--===========================================================
	-- CONTAINERS
	--===========================================================


	self.TabHolder =
		Instance.new("Frame")

	self.TabHolder.Name =
		"Tabs"


	self.TabHolder.BackgroundTransparency =
		1


	self.TabHolder.Parent =
		self.Main



	self.PageHolder =
		Instance.new("Frame")

	self.PageHolder.Name =
		"Pages"


	self.PageHolder.BackgroundTransparency =
		1


	self.PageHolder.Parent =
		self.Main



	self.NotificationHolder =
		Instance.new("Frame")

	self.NotificationHolder.Name =
		"Notifications"


	self.NotificationHolder.BackgroundTransparency =
		1


	self.NotificationHolder.Parent =
		self.Gui



	--===========================================================
	-- REGISTER STATE
	--===========================================================


	State:AddWindow(self)



	return self

end




-- ============================================================
-- DESTROY
-- ============================================================

function Window:Destroy()


	if self.Gui then

		self.Gui:Destroy()

	end


	State:RemoveWindow(self)

end



return Window
