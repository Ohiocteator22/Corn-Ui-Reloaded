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

function Methods:CreateTab(window, config)
		return window.TabManager:CreateTab(config)  
end


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
-- WIDGET CREATION
-- ============================================================


function Methods:CreateWidget(tab, widgetType, config)

	if not Widgets[widgetType] then
		
		warn(
			"[CornUi] Unknown widget:",
			widgetType
		)

		return nil
	end


	local widget =
		Widgets[widgetType].new(
			tab.Container,
			config
		)


	table.insert(
		tab.Widgets,
		widget
	)


	return widget

end

-- ============================================================
-- BUTTON
-- ============================================================
function Methods:CreateButton(tab, config)

	return self:CreateWidget(
		tab,
		"Button",
		config
	)

end
-- ============================================================
-- TOGGLE
-- ============================================================
function Methods:CreateToggle(tab, config)

	return self:CreateWidget(
		tab,
		"Toggle",
		config
	)

end
-- ============================================================
-- SLIDER
-- ============================================================

function Methods:CreateSlider(tab, config)

	return self:CreateWidget(
		tab,
		"Slider",
		config
	)

end



-- ============================================================
-- DROPDOWN
-- ============================================================


function Methods:CreateDropdown(tab, config)

	return self:CreateWidget(
		tab,
		"Dropdown",
		config
	)

end



-- ============================================================
-- COLOR PICKER
-- ============================================================
function Methods:CreateColorPicker(tab, config)

	return self:CreateWidget(
		tab,
		"ColorPicker",
		config
	)

end

-- ============================================================
-- LABEL
-- ============================================================
function Methods:CreateLabel(tab, config)

	return self:CreateWidget(
		tab,
		"Label",
		config
	)

end

-- ============================================================
-- SECTION
-- ============================================================
function Methods:CreateSection(tab, config)

	return self:CreateWidget(
		tab,
		"Section",
		config
	)

end

-- ============================================================
-- DIVIDER
-- ============================================================
function Methods:CreateDivider(tab, config)

	return self:CreateWidget(
		tab,
		"Divider",
		config
	)

end
-- ============================================================
-- KEYBIND
-- ============================================================
function Methods:CreateKeybind(tab, config)

	return self:CreateWidget(
		tab,
		"Keybind",
		config
	)

end

-- ============================================================
-- PARAGRAPHS
-- ============================================================
function Methods:CreateParagraph(tab, config)

	return self:CreateWidget(
		tab,
		"Paragraph",
		config
	)

end

-- ============================================================
-- IMAGE
-- ============================================================
function Methods:CreateImage(tab, config)

	return self:CreateWidget(
		tab,
		"Image",
		config
	)

end
-- ============================================================
-- PROGRESS BAR
-- ============================================================
function Methods:CreateProgressBar(tab, config)

	return self:CreateWidget(
		tab,
		"ProgressBar",
		config
	)

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

function Methods:SetTheme(window,name)

	local success =
		ThemeManager:LoadTheme(name)


	if success then

		window.ThemeName = name
		window.Theme = ThemeManager.Theme

	end


	return success

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
