-- ============================================================
-- CORNUI TAB SYSTEM
-- Handles Window:CreateTab()
-- ============================================================

local Tabs = {}



function Tabs.new(window)

	local self = {}

	self.Window = window
	self.Tabs = {}
	self.Current = nil


	-- ========================================================
	-- CREATE TAB
	-- ========================================================

	function self:CreateTab(config)

		config = config or {}

		local name = config.Name or "Tab"
		local icon = config.Icon


	local tab = {
			Name = name,
			Icon = icon,
			Elements = {},
			Widgets = {},
			Window = window,
			Container = nil,
				}


		-- Create tab button

		local button = window._create("TextButton", {

			Name = name .. "_Tab",

			Size = UDim2.new(
				1,
				0,
				0,
				36
			),

			BackgroundTransparency = 1,

			Text = name,

			TextColor3 = window.Theme.Text,

			Font = window.Theme.Font,

			TextSize = 14,

			LayoutOrder = #self.Tabs + 1,

		})


		button.Parent = window._tabHolder



		-- Page container

		local page = window._create("ScrollingFrame", {

				Name = name .. "_Page",
			
				Size = UDim2.fromScale(
					1,
					1
				),
			
				BackgroundTransparency = 1,
			
				Visible = false,
			
				ScrollBarThickness = 3,
			
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			
				CanvasSize = UDim2.new(
					0,
					0,
					0,
					0
				),
			
			})


		page.Parent = window._pageHolder

		
		tab.Container = page



		tab.Button = button
		tab.Page = page



		-- Button switching

		button.MouseButton1Click:Connect(function()

			self:Select(tab)

		end)



		table.insert(
			self.Tabs,
			tab
		)


		-- First tab auto-select

		if not self.Current then

			self:Select(tab)

		end


		return tab

	end

	local layout = window._create(
	"UIListLayout",
	{
		Padding = UDim.new(0,6),
		SortOrder = Enum.SortOrder.LayoutOrder
	}
)
		
		layout.Parent = page


	-- ========================================================
	-- SELECT TAB
	-- ========================================================

	function self:Select(tab)

		if not tab then
			return
		end


		for _,other in ipairs(self.Tabs) do

			other.Page.Visible = false

		end


		tab.Page.Visible = true

		self.Current = tab


		if window.Signals then

			window.Signals:Fire(
				"TabChanged",
				tab
			)

		end

	end




	-- ========================================================
	-- GET ACTIVE TAB
	-- ========================================================

	function self:GetActive()

		return self.Current

	end




	-- ========================================================
	-- REMOVE TAB
	-- ========================================================

	function self:Remove(tab)

		for i,v in ipairs(self.Tabs) do

			if v == tab then

				table.remove(
					self.Tabs,
					i
				)

				break

			end

		end


		if tab.Button then
			tab.Button:Destroy()
		end


		if tab.Page then
			tab.Page:Destroy()
		end


		if self.Current == tab then

			self.Current = nil

		end

	end



	return self

end


return Tabs
