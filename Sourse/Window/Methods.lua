-- ============================================================
-- CORNUI WINDOW METHODS
-- All public Window APIs
-- ============================================================


local Methods = {}



local Services = require(script.Parent.Parent.Core.Services)

local ThemeManager =
	require(script.Parent.Parent.Core.ThemeManager)

local Utils =
	require(script.Parent.Parent.Core.Utils)
local Widgets =
	require(script.Parent.Parent.Widgets)



-- ============================================================
-- CREATE TAB
-- ============================================================

function Methods:CreateTab(window, name, config)


	config = config or {}


	local Tab = {

	Name=name,

	Widgets={},

	Window=window,

	Container=nil,

}


	table.insert(
		window.Tabs,
		Tab
	)



	window.CurrentTab = Tab



	return Tab

end





-- ============================================================
-- NOTIFICATION
-- ============================================================

function Methods:Notify(window, config)


	config = config or {}


	local notif = {

		Title = config.Title or "Notification",

		Content = config.Content or "",

		Type = config.Type or "info",

		Duration = config.Duration or 4,

	}



	table.insert(
		window.Notifications,
		notif
	)



	-- Actual UI creation moves to Notifications module later

	print(
		"[CornUi Notify]",
		notif.Title,
		notif.Content
	)



end





-- ============================================================
-- THEME
-- ============================================================

function Methods:SetTheme(window, name)


	local success =
		ThemeManager:LoadTheme(name)



	if not success then

		warn(
			"[CornUi] Theme not found:",
			name
		)

		return false

	end



	window.Theme = name



	return true

end





-- ============================================================
-- COMMAND REGISTRATION
-- ============================================================

function Methods:RegisterCommand(window, keyword, callback)


	if type(keyword) ~= "string" then
		return
	end


	if type(callback) ~= "function" then
		return
	end



	window.Commands[
		string.lower(keyword)
	]
	=
	callback


end





-- ============================================================
-- ACTIVE TAB
-- ============================================================

function Methods:GetActiveTab(window)

	return window.CurrentTab

end





-- ============================================================
-- BACKGROUND
-- ============================================================

function Methods:SetBackground(window, image)


	if not window.Main then
		return
	end



	local bg =
		window.Main:FindFirstChild(
			"CornBackground"
		)



	if not bg then


		bg = Instance.new(
			"ImageLabel"
		)


		bg.Name =
			"CornBackground"


		bg.Size =
			UDim2.fromScale(
				1,
				1
			)


		bg.BackgroundTransparency =
			1


		bg.ZIndex =
			0


		bg.Parent =
			window.Main


	end



	bg.Image =
		image or ""


end





-- ============================================================
-- CLEAR BACKGROUND
-- ============================================================

function Methods:ClearBackground(window)


	if window.Main then


		local bg =
			window.Main:FindFirstChild(
				"CornBackground"
			)


		if bg then

			bg:Destroy()

		end

	end


end





-- ============================================================
-- ANIMATION SPEED
-- ============================================================

function Methods:SetAnimationSpeed(window, speed)


	window.AnimationSpeed =
		math.clamp(
			speed or 1,
			0.1,
			5
		)


end





-- ============================================================
-- OPACITY
-- ============================================================

function Methods:SetOpacity(window, transparency)


	if not window.Main then
		return
	end



	window.Main.BackgroundTransparency =
		transparency or 0


end





-- ============================================================
-- CORNER RADIUS
-- ============================================================

function Methods:SetCornerRadius(window, radius)


	if not window.Main then
		return
	end



	local corner =
		window.Main:FindFirstChildOfClass(
			"UICorner"
		)



	if corner then

		corner.CornerRadius =
			UDim.new(
				0,
				radius
			)

	end


end





-- ============================================================
-- DESTROY
-- ============================================================

function Methods:Destroy(window)


	window:Destroy()

end



return Methods
