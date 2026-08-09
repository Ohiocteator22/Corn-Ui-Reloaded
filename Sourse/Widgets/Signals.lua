-- ============================================================
-- CORNUI SIGNAL SYSTEM
-- Internal Event Bus
-- ============================================================


local Signals = {}

Signals.__index = Signals



Signals._events = {}






-- ============================================================
-- CREATE SIGNAL
-- ============================================================

function Signals:Create(name)


	if self._events[name] then

		return self._events[name]

	end





	local signal = {}



	signal.Connections = {}





	function signal:Connect(callback)


		if type(callback) ~= "function" then

			return

		end





		local connection = {

			Connected = true

		}






		function connection:Disconnect()


			self.Connected = false



		end





		table.insert(

			signal.Connections,

			{

				Callback = callback,

				Connection = connection

			}

		)





		return connection


	end







	function signal:Fire(...)



		for _,entry in ipairs(signal.Connections) do



			if entry.Connection.Connected then



				task.spawn(

					entry.Callback,

					...

				)



			end



		end



	end







	function signal:Destroy()



		table.clear(

			signal.Connections

		)



	end







	self._events[name] = signal



	return signal


end







-- ============================================================
-- GET SIGNAL
-- ============================================================

function Signals:Get(name)


	return self._events[name]


end







-- ============================================================
-- FIRE SIGNAL
-- ============================================================

function Signals:Fire(name,...)



	local signal =
		self._events[name]



	if signal then


		signal:Fire(...)


	end



end







-- ============================================================
-- REMOVE SIGNAL
-- ============================================================

function Signals:Destroy(name)



	local signal =
		self._events[name]



	if signal then


		signal:Destroy()


	end





	self._events[name] =
		nil



end







-- ============================================================
-- DEFAULT EVENTS
-- ============================================================


Signals:Create(
	"ThemeChanged"
)


Signals:Create(
	"WindowCreated"
)


Signals:Create(
	"WindowDestroyed"
)


Signals:Create(
	"WidgetCreated"
)


Signals:Create(
	"ConfigChanged"
)


Signals:Create(
	"PluginLoaded"
)


Signals:Create(
	"PluginUnloaded"
)


Signals:Create(
	"NotificationCreated"
)






return Signals
