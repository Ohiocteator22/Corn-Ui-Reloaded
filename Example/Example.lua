--[[
	CornUi — Complete Widget Showcase
	Demonstrates every UI element available in CornUi v1.9.2
	
	Categories:
	- Core: Window, Tabs, Sections
	- Basic: Label, Button, Toggle, Slider, Textbox
	- Input: Keybind, Hotkey, Dropdown, MultiDropdown, RadioGroup
	- Visual: ColorPicker, ThemeEditor, Image, Divider, Card, Paragraph
	- Progress: ProgressBar, Meter, Timer, Checklist
	- Advanced: ColorGradient, KeybindList, NotificationCenter
	- System: Search, PluginManager, Cornelius
]]

local Corn = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"))()

-- ============================================================
-- WINDOW CREATION
-- ============================================================

local Window = Corn:CreateWindow({
	Name = "⭐ CornUi Showcase",
	Subtitle = "All Widgets Demo — v1.9.2",
	Theme = "Ocean",  -- Dark, Light, Ocean, Forest, Sunset, Amethyst, Ruby, Frost, Candy, Midnight, Cyber
	Icon = nil,  -- Optional: your icon asset ID
	Intro = {
		Image = nil,
		Text = "-By Lifeless",
		Duration = 1.4,
		Funny = true,
	}
})

-- ============================================================
-- TAB 1: BASIC ELEMENTS
-- ============================================================

local BasicTab = Window:CreateTab("📝 Basic")

local BasicSection1 = BasicTab:CreateSection("Labels")

-- Label
BasicSection1:CreateLabel("This is a plain label.")

-- Paragraph
BasicSection1:CreateParagraph({
	Title = "Paragraph Element",
	Text = "This is a multi-line paragraph with automatic wrapping. Great for descriptions, tutorials, and longer text content.",
})

-- Divider
BasicSection1:CreateDivider({ Name = "Buttons" })

-- ============================================================
-- BUTTONS
-- ============================================================

local ButtonSection = BasicTab:CreateSection("Buttons")

-- Standard Button
local btn1 = ButtonSection:CreateButton({
	Name = "Standard Button",
	Keywords = {"click", "action", "trigger"},
	Description = "A regular clickable button",
	Callback = function()
		print("Button clicked!")
		Window:Notify({
			Title = "Button",
			Content = "You clicked me!",
			Type = "success"
		})
	end
})

-- Button with Sound & Haptic
ButtonSection:CreateButton({
	Name = " Button ",
	Sound = nil,
	Haptic = true,
	Callback = function()
		print("haptic feedback!")
	end
})

-- ============================================================
-- TOGGLES (Including Three-State)
-- ============================================================

local ToggleSection = BasicTab:CreateSection("Toggles")

-- Standard Toggle
local toggle1 = ToggleSection:CreateToggle({
	Name = "Standard Toggle",
	Default = false,
	Flag = "DemoToggle",
	Callback = function(state)
		print("Toggle state:", state)
	end
})

-- Three-State Toggle (On/Off/Auto)
ToggleSection:CreateToggle({
	Name = "Three-State Toggle",
	Default = "auto",  -- "on", "off", "auto"
	ThreeState = true,
	Callback = function(state)
		print("Three-state value:", state)
	end
})

-- ============================================================
-- SLIDER
-- ============================================================

local SliderSection = BasicTab:CreateSection("Sliders")

SliderSection:CreateSlider({
	Name = "Volume",
	Min = 0,
	Max = 100,
	Default = 50,
	Flag = "VolumeSlider",
	Callback = function(value)
		print("Volume:", value)
	end
})

SliderSection:CreateSlider({
	Name = "Speed",
	Min = 1,
	Max = 10,
	Default = 5,
	Callback = function(value)
		print("Speed:", value)
	end
})

-- ============================================================
-- TEXTBOX
-- ============================================================

local TextboxSection = BasicTab:CreateSection("Text Input")

TextboxSection:CreateTextbox({
	Name = "Username",
	Placeholder = "Enter your username...",
	Default = "Player",
	Flag = "Username",
	Callback = function(text, enterPressed)
		print("Text entered:", text, "Enter pressed:", enterPressed)
	end
})

TextboxSection:CreateTextbox({
	Name = "Password",
	Placeholder = "Enter password...",
	Callback = function(text)
		print("Password entered (hidden)")
	end
})

-- ============================================================
-- TAB 2: INPUT ELEMENTS
-- ============================================================

local InputTab = Window:CreateTab("⌨️ Input")

-- ============================================================
-- KEYBIND
-- ============================================================

local KeybindSection = InputTab:CreateSection("Keybinds")

KeybindSection:CreateKeybind({
	Name = "Toggle Menu",
	Default = Enum.KeyCode.RightShift,
	Flag = "MenuKeybind",
	Callback = function(key)
		print("Keybind pressed:", key.Name)
		Window:Notify({
			Title = "Keybind",
			Content = "Pressed: " .. key.Name,
			Type = "info"
		})
	end
})

-- ============================================================
-- HOTKEY (Press & Hold)
-- ============================================================

local HotkeySection = InputTab:CreateSection("Hotkeys (Press & Hold)")

HotkeySection:CreateHotkey({
	Name = "Sprint",
	Default = Enum.KeyCode.LeftShift,
	Callback = function(event, key)
		print("Hotkey event:", event, "Key:", key and key.Name)
		if event == "press" then
			Window:Notify({ Title = "Sprint", Content = "Sprint started!", Type = "info" })
		elseif event == "release" then
			Window:Notify({ Title = "Sprint", Content = "Sprint stopped!", Type = "warning" })
		elseif event == "hold" then
			print("Sprinting...")
		end
	end
})

-- ============================================================
-- DROPDOWN
-- ============================================================

local DropdownSection = InputTab:CreateSection("Dropdowns")

DropdownSection:CreateDropdown({
	Name = "Select Mode",
	Options = {"Easy", "Normal", "Hard", "Expert"},
	Default = "Normal",
	Flag = "GameMode",
	Callback = function(selected)
		print("Selected mode:", selected)
	end
})

-- ============================================================
-- MULTI-SELECT DROPDOWN
-- ============================================================

local MultiDropdownSection = InputTab:CreateSection("Multi-Select Dropdowns")

MultiDropdownSection:CreateMultiDropdown({
	Name = "Select Features",
	Options = {"Auto-Farm", "Auto-Collect", "Auto-Battle", "Auto-Heal"},
	Default = {"Auto-Farm", "Auto-Collect"},
	Flag = "Features",
	Callback = function(selected)
		print("Selected features:", table.concat(selected, ", "))
	end
})

-- ============================================================
-- RADIO GROUP
-- ============================================================

local RadioSection = InputTab:CreateSection("Radio Groups")

RadioSection:CreateRadioGroup({
	Name = "Choose Difficulty",
	Options = {"Easy", "Normal", "Hard"},
	Default = "Normal",
	Flag = "Difficulty",
	Callback = function(selected)
		print("Selected difficulty:", selected)
	end
})

-- ============================================================
-- TAB 3: VISUAL ELEMENTS
-- ============================================================

local VisualTab = Window:CreateTab("🎨 Visual")

-- ============================================================
-- COLOR PICKER
-- ============================================================

local ColorSection = VisualTab:CreateSection("Color Picker")

ColorSection:CreateColorPicker({
	Name = "Choose Color",
	Default = Color3.fromRGB(255, 0, 0),
	Flag = "CustomColor",
	Callback = function(color)
		print("Color selected:", color)
	end
})

-- ============================================================
-- THEME EDITOR
-- ============================================================

local ThemeSection = VisualTab:CreateSection("Theme Editor")

ThemeSection:CreateThemeEditor({
	Title = "Customize Theme",
	UIColorName = "Background Color",
	ToggleColorName = "Float Button Color"
})

-- ============================================================
-- IMAGE
-- ============================================================

local ImageSection = VisualTab:CreateSection("Images")

ImageSection:CreateImage({
	Image = 80406291512141,  -- Asset ID
	Name = "CornUi Logo",
	Height = 150,
	ScaleType = Enum.ScaleType.Fit,
})

-- ============================================================
-- CARD
-- ============================================================

local CardSection = VisualTab:CreateSection("Cards")

local Card = CardSection:CreateCard({
	Title = "📊 Stats Card",
	Subtitle = "This is a card with custom content"
})

Card:CreateLabel("Inside Card: You can put any elements here")
Card:CreateButton({
	Name = "Card Button",
	Callback = function()
		print("Card button clicked!")
	end
})

-- ============================================================
-- PARAGRAPH
-- ============================================================

local ParagraphSection = VisualTab:CreateSection("Paragraphs")

ParagraphSection:CreateParagraph({
	Title = "What is CornUi?",
	Text = "CornUi is a mobile-first Roblox UI framework designed for modern exploit hubs. It features a clean interface, smooth animations, and a powerful plugin system."
})

-- ============================================================
-- DIVIDER
-- ============================================================

VisualTab:CreateDivider({ Name = "End of Visual Elements" })

-- ============================================================
-- TAB 4: PROGRESS & TIMERS
-- ============================================================

local ProgressTab = Window:CreateTab("⏳ Progress")

-- ============================================================
-- PROGRESS BAR
-- ============================================================

local ProgressSection = ProgressTab:CreateSection("Progress Bars")

local progressBar = ProgressSection:CreateProgressBar({
	Name = "Loading",
	Min = 0,
	Max = 100,
	Default = 0,
	Flag = "Progress",
})

-- Auto-increment the progress bar
task.spawn(function()
	while true do
		local current = progressBar:Get()
		if current >= 100 then
			progressBar:Set(0)
		else
			progressBar:Set(current + 1)
		end
		task.wait(0.1)
	end
end)

-- ============================================================
-- METER
-- ============================================================

local MeterSection = ProgressTab:CreateSection("Meters")

local meter = MeterSection:CreateMeter({
	Name = "Health",
	Min = 0,
	Max = 100,
	Default = 75,
	Color = Color3.fromRGB(255, 50, 50),
	Animated = true,
})

-- Auto-fluctuate the meter
task.spawn(function()
	local direction = 1
	while true do
		local current = meter:Get()
		if current >= 100 then direction = -1
		elseif current <= 0 then direction = 1 end
		meter:Set(current + direction * 0.5)
		task.wait(0.05)
	end
end)

-- ============================================================
-- TIMER
-- ============================================================

local TimerSection = ProgressTab:CreateSection("Timers")

TimerSection:CreateTimer({
	Name = "Cooldown Timer",
	Duration = 60,
	Callback = function(event, remaining)
		if event == "complete" then
			Window:Notify({
				Title = "Timer Done!",
				Content = "Cooldown finished",
				Type = "success"
			})
		elseif event == "start" then
			print("Timer started")
		elseif event == "pause" then
			print("Timer paused")
		elseif event == "resume" then
			print("Timer resumed")
		elseif event == "reset" then
			print("Timer reset")
		end
	end
})

-- ============================================================
-- CHECKLIST
-- ============================================================

local ChecklistSection = ProgressTab:CreateSection("Checklists")

ChecklistSection:CreateChecklist({
	Name = "Daily Tasks",
	Items = {"Collect daily rewards", "Complete 3 quests", "Farm for 30 minutes", "Join a party"},
	Callback = function(done, total, states)
		print(done .. "/" .. total .. " completed")
	end
})

-- ============================================================
-- TAB 5: ADVANCED ELEMENTS
-- ============================================================

local AdvancedTab = Window:CreateTab("🔧 Advanced")

-- ============================================================
-- COLOR GRADIENT
-- ============================================================

local GradientSection = AdvancedTab:CreateSection("Color Gradient")

GradientSection:CreateColorGradient({
	Name = "Custom Gradient",
	Stops = {
		Color3.fromRGB(255, 0, 0),
		Color3.fromRGB(255, 255, 0),
		Color3.fromRGB(0, 255, 0),
		Color3.fromRGB(0, 255, 255),
		Color3.fromRGB(255, 0, 255),
	},
	Flag = "GradientColors",
	Callback = function(sequence, colors)
		print("Gradient updated! Colors:", #colors)
	end
})

-- ============================================================
-- KEYBIND LIST
-- ============================================================

local KeybindListSection = AdvancedTab:CreateSection("Keybind List")

KeybindListSection:CreateKeybindList({
	Name = "Active Keybinds"
})

-- Register some keybinds to show in the list
local KeybindListDemoTab = Window:CreateTab("🔑 Demo Keybinds")
local KLDemoSection = KeybindListDemoTab:CreateSection("Register Some Keybinds")

KLDemoSection:CreateKeybind({
	Name = "Demo Keybind 1",
	Default = Enum.KeyCode.LeftControl,
})

KLDemoSection:CreateKeybind({
	Name = "Demo Keybind 2",
	Default = Enum.KeyCode.X,
})

KLDemoSection:CreateKeybind({
	Name = "Demo Keybind 3",
	Default = Enum.KeyCode.K,
})

-- ============================================================
-- NOTIFICATION CENTER
-- ============================================================

local NotificationSection = AdvancedTab:CreateSection("Notification Center")

NotificationSection:CreateNotificationCenter({
	Name = "Notification History"
})

-- Send some demo notifications
task.spawn(function()
	task.wait(1)
	Window:Notify({ Title = "Welcome", Content = "This is a demo notification!", Type = "success" })
	task.wait(1.5)
	Window:Notify({ Title = "Warning", Content = "Something needs your attention.", Type = "warning" })
	task.wait(1.5)
	Window:Notify({ Title = "Error", Content = "Something went wrong!", Type = "error" })
	task.wait(1.5)
	Window:Notify({ Title = "Info", Content = "Here's some information for you.", Type = "info" })
end)

-- ============================================================
-- SEARCH
-- ============================================================

local SearchSection = AdvancedTab:CreateSection("Search")

SearchSection:CreateSearch({
	Placeholder = "Search features..."
})

-- ============================================================
-- TAB 6: SYSTEM
-- ============================================================

local SystemTab = Window:CreateTab("⚙️ System")

-- ============================================================
-- PLUGIN MANAGER
-- ============================================================

local PluginSection = SystemTab:CreateSection("Plugin Manager")

PluginSection:CreatePluginManager({
	Name = "Loaded Plugins"
})

-- ============================================================
-- CORNELIUS (Assistant System)
-- ============================================================

local CorneliusSection = SystemTab:CreateSection("Cornelius Assistant")

CorneliusSection:CreateParagraph({
	Title = "Cornelius Commands",
	Text = "Type /cornelius help in the command palette (click the hub name) to see available commands."
})

CorneliusSection:CreateButton({
	Name = "Load Cornelius Packs",
	Callback = function()
		Cornelius:LoadPacks({
			"Developer",
			"Random",
			"Documentation"
		})
		Window:Notify({
			Title = "Cornelius",
			Content = "Packs loaded! Try: /cornelius help",
			Type = "success"
		})
	end
})

CorneliusSection:CreateButton({
	Name = "Show Guide Example",
	Callback = function()
		Cornelius:OpenGuide("api-flags", Window)
	end
})

-- ============================================================
-- TAB 7: TEST & DEMO
-- ============================================================

local TestTab = Window:CreateTab("🧪 Test")

-- ============================================================
-- TEST BUTTONS
-- ============================================================

local TestSection = TestTab:CreateSection("Test Actions")

TestSection:CreateButton({
	Name = "Send Success Notification",
	Callback = function()
		Window:Notify({
			Title = "Success!",
			Content = "Operation completed successfully",
			Type = "success"
		})
	end
})

TestSection:CreateButton({
	Name = "Send Error Notification",
	Callback = function()
		Window:Notify({
			Title = "Error!",
			Content = "Something went wrong",
			Type = "error"
		})
	end
})

TestSection:CreateButton({
	Name = "Send Warning Notification",
	Callback = function()
		Window:Notify({
			Title = "Warning!",
			Content = "This is a warning message",
			Type = "warning"
		})
	end
})

TestSection:CreateButton({
	Name = "Send Info Notification",
	Callback = function()
		Window:Notify({
			Title = "Info",
			Content = "This is an informational message",
			Type = "info"
		})
	end
})

TestSection:CreateDivider()

TestSection:CreateButton({
	Name = "Switch to Light Theme",
	Callback = function()
		Window:SetTheme("Light")
	end
})

TestSection:CreateButton({
	Name = "Switch to Dark Theme",
	Callback = function()
		Window:SetTheme("Dark")
	end
})

TestSection:CreateButton({
	Name = "Switch to Ocean Theme",
	Callback = function()
		Window:SetTheme("Ocean")
	end
})

TestSection:CreateDivider()

TestSection:CreateButton({
	Name = "Spam 10 Notifications",
	Callback = function()
		for i = 1, 10 do
			task.wait(0.3)
			Window:Notify({
				Title = "Notification #" .. i,
				Content = "This is spam test " .. i,
				Type = i % 2 == 0 and "success" or "warning"
			})
		end
	end
})

-- ============================================================
-- WINDOW CUSTOMIZATION DEMO
-- ============================================================

local CustomSection = TestTab:CreateSection("Window Customization")

CustomSection:CreateSlider({
	Name = "Corner Radius",
	Min = 0,
	Max = 50,
	Default = 16,
	Callback = function(value)
		Window:SetCornerRadius(value)
	end
})

CustomSection:CreateSlider({
	Name = "Opacity",
	Min = 0,
	Max = 100,
	Default = 10,
	Callback = function(value)
		Window:SetOpacity(value / 100)
	end
})

CustomSection:CreateSlider({
	Name = "Animation Speed",
	Min = 1,
	Max = 30,
	Default = 10,
	Callback = function(value)
		Window:SetAnimationSpeed(value / 10)
	end
})

CustomSection:CreateToggle({
	Name = "Enable Shadow",
	Default = true,
	Callback = function(state)
		Window:SetShadow(state)
	end
})

-- ============================================================
-- STARTUP
-- ============================================================

print("✅ CornUi Showcase loaded successfully!")
print("📊 All widgets demonstrated")
print("🌽 CornUi v1.9.2")

-- ============================================================
-- RETURN
-- ============================================================

return Window
