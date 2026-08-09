-- ============================================================
-- CORNUI GLOBAL STATE
-- Runtime storage manager
-- ============================================================


local State = {}




-- ============================================================
-- VERSION
-- ============================================================

State.Version =
	"2.0.0"



State.Initialized =
	false






-- ============================================================
-- WINDOWS
-- ============================================================

State.Windows = {}

State.ActiveWindow = nil





function State:AddWindow(window)


	if not window then
		return
	end



	table.insert(
		self.Windows,
		window
	)



	self.ActiveWindow =
		window


end





function State:RemoveWindow(window)



	for i,v in ipairs(self.Windows) do


		if v == window then


			table.remove(
				self.Windows,
				i
			)


			break


		end


	end




	if self.ActiveWindow == window then


		self.ActiveWindow =
			self.Windows[#self.Windows]


	end



end





function State:GetWindows()


	return self.Windows


end







-- ============================================================
-- WIDGETS
-- ============================================================

State.Widgets = {}





function State:RegisterWidget(widget)


	if not widget then
		return
	end



	table.insert(
		self.Widgets,
		widget
	)


end






function State:RemoveWidget(widget)



	for i,v in ipairs(self.Widgets) do


		if v == widget then


			table.remove(
				self.Widgets,
				i
			)


			break


		end


	end


end







-- ============================================================
-- PLUGINS
-- ============================================================

State.Plugins = {}





function State:RegisterPlugin(name,data)


	if not name then
		return
	end



	self.Plugins[name] =
		data


end






function State:RemovePlugin(name)


	self.Plugins[name] =
		nil


end






function State:GetPlugin(name)


	return self.Plugins[name]


end







-- ============================================================
-- THEMES
-- ============================================================

State.CurrentTheme =
	"Dark"





function State:SetTheme(name)


	self.CurrentTheme =
		name


end






function State:GetTheme()


	return self.CurrentTheme


end







-- ============================================================
-- FLAGS
-- ============================================================

State.Flags = {}





function State:SetFlag(name,value)


	if not name then
		return
	end



	self.Flags[name] =
		value


end






function State:GetFlag(name)


	return self.Flags[name]


end






function State:ClearFlags()


	table.clear(
		self.Flags
	)


end







-- ============================================================
-- NOTIFICATIONS
-- ============================================================

State.Notifications = {}





function State:AddNotification(notification)


	table.insert(
		self.Notifications,
		notification
	)


end






function State:RemoveNotification(notification)


	for i,v in ipairs(self.Notifications) do


		if v == notification then


			table.remove(
				self.Notifications,
				i
			)


			break


		end


	end


end






function State:ClearNotifications()


	table.clear(
		self.Notifications
	)


end







-- ============================================================
-- RESET
-- ============================================================

function State:Reset()



	table.clear(
		self.Windows
	)



	table.clear(
		self.Widgets
	)



	table.clear(
		self.Plugins
	)



	table.clear(
		self.Flags
	)



	table.clear(
		self.Notifications
	)




	self.ActiveWindow =
		nil



	self.Initialized =
		false



end






return State
