-- ============================================================
-- CORNUI WINDOW OBJECT
-- Handles Window creation and storage
-- ============================================================


local Window = {}
Window.__index = Window



-- Dependencies

local Services = require(script.Parent.Parent.Core.Services)

local Library = require(script.Parent.Parent.Core.Library)

local ThemeManager = require(script.Parent.Parent.Core.ThemeManager)

local Utils = require(script.Parent.Parent.Core.Utils)



local Theme = ThemeManager.Theme



-- ============================================================
-- CREATE NEW WINDOW
-- ============================================================

function Window.new(config)


	config = config or {}



	local self = setmetatable({}, Window)



	-- Basic data

	self.Name = config.Name or "CornUi"

	self.Subtitle = config.Subtitle or ""

	self.Icon = config.Icon

	self.Theme = config.Theme or "Dark"



	self.Tabs = {}

	self.CurrentTab = nil


	self.Widgets = {}

	self.Notifications = {}

	self.Commands = {}



	self.Destroyed = false



	return self

end





-- ============================================================
-- BUILD UI
-- ============================================================

function Window:Create()


	-- Apply theme

	ThemeManager:Load(
		self.Theme
	)



	-- ScreenGui

	local gui = Instance.new("ScreenGui")

	gui.Name = self.Name


	gui.ResetOnSpawn = false

	gui.IgnoreGuiInset = true


	gui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling



	gui.Parent =
		Services.PlayerGui



	self.Gui = gui





	-- Main Window Frame


	local main = Instance.new("Frame")

	main.Name = "MainWindow"


	main.Size =
		UDim2.fromOffset(
			600,
			400
		)


	main.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)


	main.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)


	main.BackgroundColor3 =
		Theme.Background



	main.BorderSizePixel = 0



	main.Parent = gui



	self.Main = main





	-- Store

	Library:RegisterWindow(
		self
	)



	return self

end





-- ============================================================
-- INTERNAL WIDGET REGISTRY
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
-- INTERNAL TAB STORAGE
-- ============================================================

function Window:RegisterTab(tab)


	table.insert(
		self.Tabs,
		tab
	)


	self.CurrentTab = tab


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
