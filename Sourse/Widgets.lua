-- ============================================================
-- CORNUI WIDGET REGISTRY
-- ============================================================

local Widgets = {}

local Folder = script.Parent.Widgets


Widgets.Button =
	require(Folder.Button)

Widgets.Toggle =
	require(Folder.Toggle)

Widgets.Slider =
	require(Folder.Slider)

Widgets.Dropdown =
	require(Folder.Dropdown)

Widgets.ColorPicker =
	require(Folder.ColorPicker)

Widgets.Keybind =
	require(Folder.Keybind)

Widgets.Label =
	require(Folder.Label)

Widgets.Section =
	require(Folder.Section)

Widgets.Divider =
	require(Folder.Divider)

Widgets.Paragraph =
	require(Folder.Paragraph)

Widgets.Image =
	require(Folder.Image)

Widgets.ProgressBar =
	require(Folder.ProgressBar)

Widgets.Notification =
	require(Folder.Notification)


return Widgets
