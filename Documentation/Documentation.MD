# CornUi Documentation
> **Current API reference.** This section is the complete widget list for the current `Sourse/CornUi.lua`. Later sections provide more background on selected systems.
## Quick start
```lua
local Corn = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"))()
local Window = Corn:CreateWindow({ Name = "My Hub" })
local Tab = Window:CreateTab("Main")
local Section = Tab:CreateSection("Settings")
```
All widget methods work on a `Tab`, `Section`, or `Card` unless the table says otherwise. Configurable widgets may include `Keywords` (string or array) and `Description` to improve `CreateSearch` results.
## Complete widget API
| Widget | Call and configuration | Returned API / behavior |
|---|---|---|
| Section | `Tab:CreateSection(name)` | Container; supports all widget methods. |
| Label | `:CreateLabel(text)` | Returns a Roblox `TextLabel`. |
| Button | `:CreateButton({ Name, Callback = function() end })` | Click action. |
| Toggle | `:CreateToggle({ Name, Default, Flag, Callback = function(value) end })` | `:Set(boolean)`, `:Get()`. |
| Slider | `:CreateSlider({ Name, Min, Max, Default, Flag, Callback = function(value) end })` | `:Set(number)`. |
| Textbox | `:CreateTextbox({ Name, Default, Placeholder, Flag, Callback = function(text, enterPressed) end })` | `:Set(text)`, `:Get()`. `CreateTextBox` is an alias. |
| Keybind | `:CreateKeybind({ Name, Default = Enum.KeyCode..., Flag, Callback = function(key) end })` | `:Set(key)`, `:Get()`. |
| Color Picker | `:CreateColorPicker({ Name, Default = Color3..., Flag, Callback = function(color) end })` | `:Set(color)`, `:Get()`. |
| Dropdown | `:CreateDropdown({ Name, Options = {...}, Default, Flag, Callback = function(option) end })` | `:Set(option)`. |
| Search | `:CreateSearch({ Placeholder = "Search..." })` | Filters widgets in its parent Tab, Section, or Card. |
| Theme Editor | `:CreateThemeEditor({ Title, UIColorName, ToggleColorName })` | Adds color controls for the hub background and floating button. |
| Discord Button | `:CreateDiscordButton({ Name, Invite = "discord.gg/..." })` | Shows a selectable invite popup. |
| Divider | `:CreateDivider({ Name = "Optional label" })` | Visual separator. `Name` is optional. |
| Card | `:CreateCard({ Title, Subtitle })` | Container; supports all widget methods. |
| Paragraph | `:CreateParagraph({ Title, Text })` or `{ Content }` | `:Set(text)`, `:Get()`. |
| Image | `:CreateImage({ Image = assetId, Name, Height, ScaleType })` | `:Set(assetId)`, `:Get()`. `AssetId` and `Id` are aliases for `Image`. |
| Progress Bar | `:CreateProgressBar({ Name, Min, Max, Default, Flag })` | `:Set(number)`, `:Get()`. |
| Keybind List | `:CreateKeybindList({ Name })` | Live list of all hub keybinds; `:Refresh()`. |
| Color Gradient | `:CreateColorGradient({ Name, Stops = { Color3, ... }, Flag, Callback = function(sequence, colors) end })` | `:Set(colors)`, `:Get()`, `:GetSequence()`. |
| Notification Center | `:CreateNotificationCenter({ Name })` | Live `Window:Notify()` history; `:Refresh()`. |
| Plugin Manager | `:CreatePluginManager({ Name })` | Loaded-plugin controls; `:Refresh()`. |
## Widget examples
```lua
Section:CreateLabel("Changes apply immediately")
Section:CreateDivider({ Name = "Gameplay" })
Section:CreateButton({
    Name = "Reset",
    Callback = function() print("Reset clicked") end,
})
local enabled = Section:CreateToggle({
    Name = "Enabled", Default = false, Flag = "Enabled",
    Callback = function(value) print(value) end,
})
enabled:Set(true)
Section:CreateSlider({
    Name = "Power", Min = 0, Max = 100, Default = 50,
    Callback = function(value) print(value) end,
})
Section:CreateTextbox({
    Name = "Nickname", Placeholder = "Type here...",
    Callback = function(text, enterPressed) print(text, enterPressed) end,
})
Section:CreateKeybind({
    Name = "Action key", Default = Enum.KeyCode.F,
    Callback = function(key) print(key.Name) end,
})
Section:CreateColorPicker({
    Name = "Preview", Default = Color3.fromRGB(255, 196, 48),
    Callback = function(color) print(color) end,
})
Section:CreateDropdown({
    Name = "Mode", Options = { "Safe", "Fast" }, Default = "Safe",
    Callback = function(option) print(option) end,
})
```
```lua
local Card = Section:CreateCard({
    Title = "Account", Subtitle = "Nested controls live here.",
})
Card:CreateParagraph({ Title = "Welcome", Text = "This text wraps automatically." })
Card:CreateImage({ Image = 123456789, Name = "Banner", Height = 140 })
local progress = Card:CreateProgressBar({ Name = "Loading", Min = 0, Max = 100 })
progress:Set(75)
Card:CreateColorGradient({
