-- ============================================================
-- CORNUI WIDGET REGISTRY
-- ============================================================

local Widgets = {}

local Folder = script.Parent.Widgets


local function LoadWidget(name)

	local module = Folder:FindFirstChild(name)

	if not module then
		warn("[CornUi] Missing widget module:", name)
		return nil
	end

	return require(module)

end


Widgets.Button =
	LoadWidget("Button")

Widgets.Toggle =
	LoadWidget("Toggle")

Widgets.Slider =
	LoadWidget("Slider")

Widgets.Dropdown =
	LoadWidget("Dropdown")

Widgets.ColorPicker =
	LoadWidget("ColorPicker")

Widgets.Keybind =
	LoadWidget("Keybind")

Widgets.Label =
	LoadWidget("Label")

Widgets.Section =
	LoadWidget("Section")

Widgets.Divider =
	LoadWidget("Divider")

Widgets.Paragraph =
	LoadWidget("Paragraph")

Widgets.Image =
	LoadWidget("Image")

Widgets.ProgressBar =
	LoadWidget("ProgressBar")

Widgets.Notification =
	LoadWidget("Notification")


return Widgets
