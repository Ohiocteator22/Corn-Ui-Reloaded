-- ============================================================
-- CORNUI WINDOW OBJECT
-- Handles Window creation and storage
-- ============================================================

local Window = {}
Window.__index = Window


local Services =
	require(script.Parent.Parent.Core.Services)

local Library =
	require(script.Parent.Parent.Core.Library)

local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)

local Utils =
	require(script.Parent.Parent.Core.Utils)

local Signal =
	require(script.Parent.Parent.Core.Signal)

local Tabs =
	require(script.Parent.Tabs)

local Methods =
	require(script.Parent.Methods)



-- ============================================================
-- CREATE WINDOW
-- ============================================================

function Window.new(config)

	config = config or {}


	local self =
		setmetatable({}, Window)



	self.Name =
		config.Name or "CornUi"


	self.Subtitle =
		config.Subtitle or ""


	self.Icon =
		config.Icon



	self.ThemeName =
    config.Theme or "Dark"

		self.Theme =
		    ThemeManager



	self.Tabs = {}

	self.CurrentTab = nil

	self.Widgets = {}

	self.Notifications = {}

	self.Commands = {}

	self.Destroyed = false



	self.Signals =
		Signal.new()



	self._create =
		Utils.Create



	return self

end





-- ============================================================
-- BUILD WINDOW UI
-- ============================================================

function Window:Create()


		ThemeManager:LoadTheme(
	    self.ThemeName
	)



	local gui =
		Instance.new("ScreenGui")


	gui.Name =
		self.Name


	gui.ResetOnSpawn =
		false


	gui.IgnoreGuiInset =
		true


	gui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling



	gui.Parent =
		Services.PlayerGui



	self.Gui =
		gui





	-- Main frame

	local main =
		self._create(
			"Frame",
			{

				Name =
					"MainWindow",

				Size =
					UDim2.fromOffset(
						600,
						400
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

				BackgroundColor3 =
					ThemeManager:GetColor(
						"Background"
					),

				BorderSizePixel = 0,

			}
		)



	main.Parent =
		gui


	self.Main =
		main





	-- Tab holder

	local tabHolder =
		self._create(
			"Frame",
			{

				Name =
					"TabHolder",

				Size =
					UDim2.new(
						0,
						150,
						1,
						0
					),

				BackgroundTransparency = 1,

			}
		)


	tabHolder.Parent =
		main
	self._create(
	    "UIListLayout",
	    {
	      Padding = UDim.new(0,6),
	      SortOrder = Enum.SortOrder.LayoutOrder
	    }
	).Parent = tabHolder


	self._tabHolder =
		tabHolder





	-- Page holder

	local pageHolder =
		self._create(
			"Frame",
			{

				Name =
					"PageHolder",

				Position =
					UDim2.new(
						0,
						160,
						0,
						0
					),

				Size =
					UDim2.new(
						1,
						-160,
						1,
						0
					),

				BackgroundTransparency = 1,

			}
		)


	pageHolder.Parent =
		main



	self._pageHolder =
		pageHolder





	-- Attach tab system

	self.TabManager =
		Tabs.new(self)





	-- Attach methods

	for name,func in pairs(Methods) do

		self[name] = function(_, ...)

			return func(
				self,
				...
			)

		end

	end





	Library:RegisterWindow(
		self
	)



	return self

end





-- ============================================================
-- WIDGET REGISTRY
-- ============================================================

function Window:RegisterWidget(widget)

	table.insert(
		self.Widgets,
		widget
	)


	Library:RegisterWidget(
		widget
	)

end





-- ============================================================
-- DESTROY
-- ============================================================

function Window:Destroy()


	if self.Destroyed then
		return
	end


	self.Destroyed = true



	if self.Gui then

		self.Gui:Destroy()

	end



	Library:RemoveWindow(
		self
	)



	table.clear(
		self.Tabs
	)


	table.clear(
		self.Widgets
	)

end


return Window
