-- ============================================================
-- CORNUI CORE LIBRARY
-- Global State + Registries
-- ============================================================


local Library = {}


-- ============================================================
-- VERSION
-- ============================================================

Library.Name = "CornUi"
Library.Version = "2.0.0"


-- ============================================================
-- WINDOWS
-- ============================================================

Library.Windows = {}
Library.CurrentWindow = nil


-- ============================================================
-- FLAGS / CONFIG
-- ============================================================

Library.Flags = {}

Library.Configs = {}



-- ============================================================
-- PLUGIN SYSTEM
-- ============================================================

Library.Plugins = {}

Library.LoadedPlugins = {}



-- ============================================================
-- THEME SYSTEM
-- ============================================================

Library.Themes = {}

Library.CurrentTheme = "Dark"



-- ============================================================
-- INTERNAL REGISTRY
-- ============================================================

Library._registry = {

	Windows = {},
	Widgets = {},
	Notifications = {},
	Commands = {},

}



-- ============================================================
-- WINDOW REGISTRATION
-- ============================================================

function Library:RegisterWindow(window)

	if not window then
		return
	end

	table.insert(
		self.Windows,
		window
	)

	self.CurrentWindow = window

end



-- ============================================================
-- WINDOW REMOVAL
-- ============================================================

function Library:RemoveWindow(window)

	for index, value in ipairs(self.Windows) do

		if value == window then

			table.remove(
				self.Windows,
				index
			)

			break
		end

	end


	if self.CurrentWindow == window then
		self.CurrentWindow = nil
	end

end



-- ============================================================
-- WIDGET REGISTRY
-- ============================================================

function Library:RegisterWidget(widget)

	if not widget then
		return
	end

	table.insert(
		self._registry.Widgets,
		widget
	)

end



function Library:RemoveWidget(widget)

	for i,v in ipairs(self._registry.Widgets) do

		if v == widget then

			table.remove(
				self._registry.Widgets,
				i
			)

			break
		end

	end

end



-- ============================================================
-- PLUGINS
-- ============================================================

function Library:RegisterPlugin(name, plugin)

	if not name or not plugin then
		return false
	end


	self.Plugins[name] = plugin

	return true
end



function Library:GetPlugin(name)

	return self.Plugins[name]

end



-- ============================================================
-- COMMAND REGISTRY
-- ============================================================

function Library:RegisterCommand(name, callback)

	if type(callback) ~= "function" then
		return false
	end


	self._registry.Commands[name] = callback

	return true
end



function Library:GetCommand(name)

	return self._registry.Commands[name]

end



-- ============================================================
-- RESET
-- ============================================================

function Library:DestroyAll()

	for _,window in ipairs(self.Windows) do

		if window.Destroy then
			window:Destroy()
		end

	end


	self.Windows = {}
	self.CurrentWindow = nil

end



return Library
