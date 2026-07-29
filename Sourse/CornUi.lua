--[[
	MobileUILib
	A lightweight, mobile-compatible Roblox UI library (Orion-style: window, tabs, buttons, toggles, sliders, dropdowns)

	Usage:
		local Library = require(path.to.MobileUILib)
		local Window = Library:CreateWindow({ Name = "My Hub" })
		local Tab = Window:CreateTab("Main")
		Tab:CreateButton({ Name = "Click me", Callback = function() print("clicked") end })
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Library = {}
Library.__index = Library

-- ===================== FLAG MANAGER =====================
-- A shared value store so any element (Toggle, Slider, Dropdown, etc.) can be
-- tagged with a config.Flag string and have its value auto-synced here, the
-- same idea as "ESP flags" in other UI libs. Library.FlagChanged fires
-- (flagName, value) any time a flagged element changes, so external scripts
-- can react without needing a reference to the element itself.
Library.Flags = {}
local flagChangedEvent = Instance.new("BindableEvent")
Library.FlagChanged = flagChangedEvent.Event

function Library:GetFlag(name)
	return Library.Flags[name]
end

function Library:SetFlag(name, value)
	if not name then return end
	Library.Flags[name] = value
	flagChangedEvent:Fire(name, value)
end

-- Elements created with a config.Flag register their {Set, Get} handle here
-- too (see setSearchMeta's siblings below), so Config:Load can push a saved
-- value back into the *element itself* — updating what's on screen, not just
-- Library.Flags — via Library.FlagElements[name]:Set(value). Populated by
-- each element-creation function; not meant to be written to directly.
Library.FlagElements = {}

-- ===================== KEYBIND REGISTRY =====================
-- Every Tab:CreateKeybind() registers a { Name, Get } descriptor here so
-- Tab:CreateKeybindList() can display "what's bound to what" without
-- needing references to the individual Keybind elements themselves.
Library.Keybinds = {}
local keybindRegisteredEvent = Instance.new("BindableEvent")
Library.KeybindRegistered = keybindRegisteredEvent.Event -- fires (descriptor) when a new Keybind is created
local keybindChangedEvent = Instance.new("BindableEvent")
Library.KeybindChanged = keybindChangedEvent.Event -- fires (descriptor) when an existing Keybind's key changes
local keybindUnregisteredEvent = Instance.new("BindableEvent")
Library.KeybindUnregistered = keybindUnregisteredEvent.Event -- fires (descriptor) when a Keybind element is :Destroy()'d

-- ===================== NOTIFICATION HISTORY =====================
-- WM:Notify (below) pushes every notification it shows into this capped
-- history so Tab:CreateNotificationCenter() can display past notifications,
-- not just the toasts that are currently fading in/out on screen.
Library.NotificationHistory = {}
Library.MAX_NOTIFICATION_HISTORY = 50
local notificationLoggedEvent = Instance.new("BindableEvent")
Library.NotificationLogged = notificationLoggedEvent.Event -- fires (entry) whenever Notify logs one

-- ===================== CONFIG SYSTEM =====================
-- Persists Library.Flags (+ the active theme name) to a JSON file on disk,
-- and restores them on load. Two things make this more than a plain
-- JSONEncode(Library.Flags):
--   1. Color3 and Enum values (from ColorPickers/Keybinds) aren't JSON-safe
--      on their own, so they're wrapped/unwrapped through the two helpers
--      below.
--   2. Loading a flag doesn't just poke Library.Flags — if the flag belongs
--      to a live element (tracked in Library.FlagElements, populated by
--      every Toggle/Slider/Dropdown/Textbox/Keybind/ColorPicker), it calls
--      that element's :Set() instead, so the UI visually updates too.
--
-- IMPORTANT ordering note: every element sets its own default value into
-- Library.Flags the moment it's created (config.Flag + config.Default), so
-- calling LoadConfig *before* your tabs/elements exist will just get
-- overwritten as each element is built. Call Corn:LoadConfig(name, Window)
-- AFTER your whole UI (all tabs/sections/elements) has been created —
-- typically the very last line before handing control back to the user.
--
-- Files are flat, matching the convention already used by KeySystem.lua's
-- SAVE_PATH ("CornUi_Key.txt") rather than introducing folder APIs
-- (makefolder/isfolder) that not every executor implements consistently.

local CONFIG_PREFIX = "CornUi_Config_"
local CONFIG_SUFFIX = ".json"

local function configPath(name)
	-- Keep filenames boring and predictable — strip anything that isn't
	-- alphanumeric/underscore/dash so a bad `name` can't escape the prefix
	-- or produce a path Roblox's file API rejects outright.
	local safeName = tostring(name or "default"):gsub("[^%w_%-]", "_")
	if safeName == "" then safeName = "default" end
	return CONFIG_PREFIX .. safeName .. CONFIG_SUFFIX
end

local function serializeFlagValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __type = "Color3", r = value.R, g = value.G, b = value.B }
	elseif kind == "EnumItem" then
		-- e.g. Enum.KeyCode.F -> { __type = "Enum", enum = "KeyCode", name = "F" }
		local enumName = tostring(value.EnumType):gsub("^Enum%.", "")
		return { __type = "Enum", enum = enumName, name = value.Name }
	elseif kind == "number" or kind == "string" or kind == "boolean" then
		return value
	elseif kind == "table" then
		-- Generic array support (e.g. CreateColorGradient's list of Color3
		-- stops) — recurse per element instead of falling through to
		-- tostring(), which would silently lose the data.
		local out = {}
		for i, v in ipairs(value) do
			out[i] = serializeFlagValue(v)
		end
		return { __type = "Array", items = out }
	else
		-- Anything else (Vector3, UDim2, nil, ...) isn't currently produced by
		-- a flag-bearing element, but fall back to a readable string instead
		-- of letting JSONEncode error out the whole save.
		return tostring(value)
	end
end

local function deserializeFlagValue(value)
	if type(value) == "table" and value.__type == "Color3" then
		return Color3.new(value.r, value.g, value.b)
	elseif type(value) == "table" and value.__type == "Enum" then
		local ok, enumType = pcall(function() return Enum[value.enum] end)
		if not ok or not enumType then return nil end
		local ok2, item = pcall(function() return enumType[value.name] end)
		if ok2 then return item end
		return nil
	elseif type(value) == "table" and value.__type == "Array" then
		local out = {}
		for i, v in ipairs(value.items or {}) do
			out[i] = deserializeFlagValue(v)
		end
		return out
	else
		return value
	end
end

-- Library:SaveConfig(name?) — writes every current flag (plus the active
-- theme name) to CornUi_Config_<name>.json. Returns true/false.
function Library:SaveConfig(name)
	if not (writefile) then
		warn("[MobileUILib] SaveConfig: this executor doesn't expose writefile")
		return false
	end

	local data = { Flags = {}, Theme = Library._currentThemeName or "Dark" }
	for flagName, value in pairs(Library.Flags) do
		data.Flags[flagName] = serializeFlagValue(value)
	end

	local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then
		warn("[MobileUILib] SaveConfig: JSONEncode failed — " .. tostring(json))
		return false
	end

	local wok, werr = pcall(writefile, configPath(name), json)
	if not wok then
		warn("[MobileUILib] SaveConfig: writefile failed — " .. tostring(werr))
		return false
	end
	return true
end

-- Library:LoadConfig(name?, window?) — reads back a config saved with
-- SaveConfig. `window` is optional but needed to restore the theme (theme
-- switching is a Window method, not a Library one); flags restore either
-- way. See the ordering note above the Config System header.
function Library:LoadConfig(name, window)
	if not (isfile and readfile) then
		warn("[MobileUILib] LoadConfig: this executor doesn't expose isfile/readfile")
		return false
	end

	local path = configPath(name)
	local existsOk, exists = pcall(isfile, path)
	if not existsOk or not exists then
		return false -- not an error — just nothing saved under this name yet
	end

	local readOk, raw = pcall(readfile, path)
	if not readOk then
		warn("[MobileUILib] LoadConfig: readfile failed — " .. tostring(raw))
		return false
	end

	local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not decodeOk or type(data) ~= "table" then
		warn("[MobileUILib] LoadConfig: malformed config file, ignoring — " .. tostring(data))
		return false
	end

	if data.Theme and window then
		pcall(function() window:SetTheme(data.Theme) end)
	end

	if type(data.Flags) == "table" then
		for flagName, rawValue in pairs(data.Flags) do
			local value = deserializeFlagValue(rawValue)
			local elem = Library.FlagElements[flagName]
			if elem and elem.Set then
				pcall(function() elem:Set(value) end)
			else
				-- No live element for this flag (e.g. it was set purely via
				-- ctx:SetFlag by a plugin) — still restore the raw value.
				Library:SetFlag(flagName, value)
			end
		end
	end

	return true
end

-- Library:ListConfigs() — best-effort list of saved config names (without
-- the CornUi_Config_ prefix / .json suffix). Depends on the executor
-- exposing listfiles with root-directory support, which isn't universal —
-- returns an empty table rather than erroring if it's unavailable.
function Library:ListConfigs()
	if not listfiles then return {} end
	local ok, files = pcall(listfiles, "")
	if not ok or type(files) ~= "table" then return {} end

	local names = {}
	for _, path in ipairs(files) do
		local fileName = path:match("[^/\\]+$") or path
		local name = fileName:match("^" .. CONFIG_PREFIX .. "(.+)" .. CONFIG_SUFFIX .. "$")
		if name then table.insert(names, name) end
	end
	return names
end

-- Library:DeleteConfig(name?) — removes a saved config file. Returns true/false.
function Library:DeleteConfig(name)
	if not (delfile and isfile) then
		warn("[MobileUILib] DeleteConfig: this executor doesn't expose delfile/isfile")
		return false
	end
	local path = configPath(name)
	local existsOk, exists = pcall(isfile, path)
	if not existsOk or not exists then return false end
	local ok, err = pcall(delfile, path)
	if not ok then
		warn("[MobileUILib] DeleteConfig: delfile failed — " .. tostring(err))
		return false
	end
	return true
end

-- ===================== THEME =====================
local Themes = {
	Dark = {
		Background = Color3.fromRGB(10, 10, 12),
		Header = Color3.fromRGB(16, 16, 19),
		Accent = Color3.fromRGB(255, 196, 48), -- corn yellow
		TextOnAccent = Color3.fromRGB(20, 20, 24),
		Text = Color3.fromRGB(240, 240, 245),
		SubText = Color3.fromRGB(140, 140, 148),
		Element = Color3.fromRGB(20, 20, 24),
		ElementHover = Color3.fromRGB(28, 28, 33),
		Stroke = Color3.fromRGB(38, 38, 44),
		ToggleButton = Color3.fromRGB(20, 20, 24), -- floating toggle button bg; decoupled from Element so the theme editor can recolor it independently
	},
	Light = {
		Background = Color3.fromRGB(246, 246, 249),
		Header = Color3.fromRGB(255, 255, 255),
		Accent = Color3.fromRGB(255, 178, 30),
		TextOnAccent = Color3.fromRGB(40, 28, 8),
		Text = Color3.fromRGB(25, 25, 28),
		SubText = Color3.fromRGB(110, 110, 118),
		Element = Color3.fromRGB(233, 233, 238),
		ElementHover = Color3.fromRGB(221, 221, 228),
		Stroke = Color3.fromRGB(212, 212, 220),
		ToggleButton = Color3.fromRGB(233, 233, 238),
	},
}

-- Library:RegisterTheme("Name", { Background = Color3..., Accent = ... }) —
-- adds a custom preset alongside the built-in Dark/Light so it can be passed
-- to CreateWindow({ Theme = "Name" }) or Window:SetTheme("Name"). Any key you
-- don't specify falls back to the Dark preset's value, so you only need to
-- override what actually changes. Intended for plugins (e.g. a "brand theme"
-- plugin) as well as direct use.
function Library:RegisterTheme(name, themeTable)
	if type(name) ~= "string" or type(themeTable) ~= "table" then
		warn("[MobileUILib] RegisterTheme requires a name string and a table of colors")
		return
	end
	local merged = {}
	for k, v in pairs(Themes.Dark) do merged[k] = v end
	for k, v in pairs(themeTable) do merged[k] = v end
	Themes[name] = merged
end

-- Active theme, mutated in place by CreateWindow based on config.Theme.
-- Every element-creation function below reads from this same table, so
-- swapping presets before building the window is all that's needed.
local Theme = {}
for k, v in pairs(Themes.Dark) do Theme[k] = v end

-- ===================== HELPERS =====================
local function isTouchDevice()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

-- Tags an element with search metadata: MUI_Name (kept for back-compat / display
-- purposes) plus MUI_Search, a single lowercased blob combining the name,
-- optional config.Keywords (string or array of strings), and optional
-- config.Description. Tab:CreateSearch matches against MUI_Search so results
-- surface on keyword/description hits too, not just the visible name.
local function setSearchMeta(inst, config, defaultName)
	config = config or {}
	local name = config.Name or defaultName or ""
	inst:SetAttribute("MUI_Name", name)

	local parts = { name }
	if config.Keywords then
		if type(config.Keywords) == "table" then
			for _, kw in ipairs(config.Keywords) do
				table.insert(parts, tostring(kw))
			end
		else
			table.insert(parts, tostring(config.Keywords))
		end
	end
	if config.Description then
		table.insert(parts, tostring(config.Description))
	end
	inst:SetAttribute("MUI_Search", table.concat(parts, " "):lower())
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
	})
end

local function tween(inst, props, duration)
	if Library.Flags.ReducedMotion then
		-- Performance mode: skip TweenService entirely and jump straight to
		-- the end state. This is the single choke point nearly every UI
		-- animation in this file goes through (ripple, tab switching, theme
		-- transitions, and the intro), so gating it here disables all of
		-- them at once instead of patching each call site individually.
		for prop, value in pairs(props) do
			inst[prop] = value
		end
		return
	end
	TweenService:Create(inst, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- Pulsing outline for the currently-selected tab ("breathing" bloom)
local function startBreathingGlow(guiObject, color)
	local glow = create("UIStroke", { Color = color, Thickness = 2, Transparency = 0.3 })
	glow.Parent = guiObject
	local glowTween = TweenService:Create(
		glow,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.85 }
	)
	glowTween:Play()
	return glow, glowTween
end

local function stopBreathingGlow(glow, glowTween)
	if glowTween then glowTween:Cancel() end
	if glow then glow:Destroy() end
end

-- Static (non-pulsing) outline shown on mouse hover — desktop only, since
-- touch devices have no hover concept; simply never fires on mobile.
local function attachHoverGlow(guiObject, color)
	guiObject.MouseEnter:Connect(function()
		if guiObject:FindFirstChild("_HoverGlow") then return end
		local s = create("UIStroke", { Name = "_HoverGlow", Color = color, Thickness = 1.5, Transparency = 0.5 })
		s.Parent = guiObject
	end)
	guiObject.MouseLeave:Connect(function()
		local s = guiObject:FindFirstChild("_HoverGlow")
		if s then s:Destroy() end
	end)
end

-- Expanding circular ripple from the center of a button, clipped to its bounds
local function ripple(button, color)
	button.ClipsDescendants = true
	local circle = create("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.55,
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 5,
	}, { corner(999) })
	circle.Parent = button
	local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.8
	tween(circle, { Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1 }, 0.5)
	task.delay(0.5, function()
		circle:Destroy()
	end)
end

-- Temporarily shifts every GuiObject under `root` (plus root itself) by `offset`
-- ZIndex. Used to lift an open dropdown/color-picker panel above the spotlight
-- dimmer; calling it again with the negated offset restores the original values
-- exactly, so no snapshot bookkeeping is needed.
local function shiftZIndex(root, offset)
	if root:IsA("GuiObject") then
		root.ZIndex += offset
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex += offset
		end
	end
end

-- Makes a frame draggable via mouse OR touch, and clamps it on-screen.
local function makeDraggable(dragHandle, target)
	local dragging = false
	local dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		local newPos = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
		target.Position = newPos
	end

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)

	-- Global input for touch move events fired on UserInputService (more reliable on mobile)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Touch then
			update(input)
		end
	end)
end

-- ===================== LIBRARY =====================
function Library:CreateWindow(config)
	config = config or {}
	local windowName = config.Name or "UI Library"
	-- Each GUI name owns one window. Keeping the default preserves the original
	-- single-window behavior, while an external/secondary script can provide a
	-- different GuiName and coexist with the primary hub.
	local guiName = config.GuiName or "MobileUILib"
	local windowPosition = config.Position or UDim2.new(0.5, 0, 0.5, 0)
	local subtitle = config.Subtitle -- optional second line under the title
	local iconId = config.Icon -- can be a raw asset id number, or a full "rbxassetid://" string
	if iconId and type(iconId) == "number" then
		iconId = "rbxassetid://" .. tostring(iconId)
	elseif iconId and type(iconId) == "string" and not iconId:match("^rbxassetid://") then
		iconId = "rbxassetid://" .. iconId
	end

	-- Apply theme preset (defaults to Dark) before building anything
	local preset = Themes[config.Theme] or Themes.Dark
	for k, v in pairs(preset) do Theme[k] = v end
	Library._currentThemeName = Themes[config.Theme] and config.Theme or "Dark"

	-- Replace only the window using this GUI identity. This lets independently
	-- hosted scripts create a secondary CornUi window with another GuiName.
	local existing = PlayerGui:FindFirstChild(guiName)
	if existing then existing:Destroy() end

	local screenGui = create("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		-- Global mode compares ZIndex across the WHOLE tree, not just siblings.
		-- Needed so overlays (spotlight dimmer, intro, dropdown panels) can
		-- reliably sit above/below arbitrarily nested content.
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		IgnoreGuiInset = false, -- respects mobile safe-area / notch
	})
	screenGui.Parent = PlayerGui

	-- UIScale makes the whole UI scale with actual screen size (see auto-scale below)
	local uiScale = create("UIScale", { Scale = 1 })

	local touch = isTouchDevice()
	local togglePosition = config.TogglePosition or UDim2.new(1, -(touch and 68 or 58), 0, 16)
	-- Base size: wider % of screen on mobile since screens are smaller/portrait.
	-- Bumped taller than before so ~3 tabs fit before the tab list needs to scroll.
	local mainSizeScale = touch and UDim2.new(0.92, 0, 0.82, 0) or UDim2.new(0, 560, 0, 460)

	-- NOTE: this used to be a CanvasGroup so the whole hub could fade in as one
	-- unit via GroupTransparency. Reverted to a plain Frame: CanvasGroups have
	-- a known Roblox rendering issue where Text on GuiObjects nested inside a
	-- ScrollingFrame (like dropdown options) can render blank. Not worth it.
	-- The hub is simply built fully visible from the start; the opaque intro
	-- overlay (created further down) sits on top and hides it until it parts.
	local main = create("Frame", {
		Name = "Main",
		Size = mainSizeScale,
		Position = windowPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, { corner(16), stroke(), uiScale })
	main.Parent = screenGui

	-- Auto-scale for the actual device screen. ViewportSize is the real,
	-- reliable way to read the player's screen/window resolution (a plain
	-- ScreenGui's AbsoluteSize needs the gui already laid out, so the camera's
	-- viewport is used instead — it reflects the same physical screen size).
	-- Clamped so tiny phones don't shrink text unreadably small and big
	-- monitors don't blow the hub up huge.
	local function applyAutoScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		uiScale.Scale = math.clamp(viewport.Y / 720, 0.78, 1.3)
	end
	applyAutoScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyAutoScale)
	end

	local isLight = (preset == Themes.Light)


	-- Stylized "glass" sheen: Roblox's 2D GUI layer has no real background-blur
	-- API, so this is a subtle transparency + diagonal light-streak approximation
	-- rather than a literal frosted/acrylic blur.
	main.BackgroundTransparency = isLight and 0.06 or 0.1
	local glassSheen = create("Frame", {
		Name = "GlassSheen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, { corner(16) })
	glassSheen.Parent = main
	create("UIGradient", {
		Rotation = 115,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, isLight and 0.82 or 0.9),
			NumberSequenceKeypoint.new(0.5, isLight and 0.6 or 0.75),
			NumberSequenceKeypoint.new(0.55, isLight and 0.82 or 0.9),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}).Parent = glassSheen

	local headerHeight = touch and 50 or 40
	if subtitle then
		headerHeight = touch and 64 or 52
	end

	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = Theme.Header,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		corner(16),
	})
	header.Parent = main

	local titleOffset = 15
	if iconId then
		-- Bumped up from 28/22 — the old size was hard to see on phone screens
		-- and could be nearly invisible on a PC monitor.
		local iconSize = touch and 36 or 30
		local icon = create("ImageLabel", {
			Image = iconId,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, iconSize, 0, iconSize),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 2,
		}, { corner(10) })
		icon.Parent = header
		-- SetTheme does a reverse color-lookup: it tweens any instance whose
		-- current color happens to match a color in the OLD theme to the
		-- equivalent slot in the NEW theme. This icon's ImageColor3 starts at
		-- the Roblox default (white), which can coincidentally equal a theme
		-- color (Light.Header is pure white), causing SetTheme to retint it
		-- by accident and make it seem to "disappear". Flagging it opts it out.
		icon:SetAttribute("MUI_NoTheme", true)
		titleOffset = 12 + iconSize + 8
	end

	-- The title doubles as a lightweight command palette: tap/click it, type
	-- a keyword (e.g. "T-notif"), and it fires a registered action, then
	-- reverts back to showing the hub's name. See Window:RegisterCommand.
	local titleBox

	if subtitle then
		titleBox = create("TextBox", {
			Text = windowName,
			Font = Enum.Font.GothamBold,
			TextSize = touch and 17 or 14,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -(titleOffset + 90), 0, touch and 22 or 18),
			Position = UDim2.new(0, titleOffset, 0, touch and 8 or 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			ZIndex = 2,
		})
		titleBox.Parent = header

		create("TextLabel", {
			Text = subtitle,
			Font = Enum.Font.Gotham,
			TextSize = touch and 12 or 11,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -(titleOffset + 90), 0, touch and 16 or 14),
			Position = UDim2.new(0, titleOffset, 0, touch and 32 or 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}).Parent = header
	else
		titleBox = create("TextBox", {
			Text = windowName,
			Font = Enum.Font.GothamBold,
			TextSize = touch and 18 or 15,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -(titleOffset + 90), 1, 0),
			Position = UDim2.new(0, titleOffset, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			ZIndex = 2,
		})
		titleBox.Parent = header
	end

	-- Minimize / show-hide button (essential on mobile - no keybind to toggle UI)
	local minimizeBtn = create("TextButton", {
		Text = "—",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 22 or 18,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(0, touch and 44 or 32, 0, touch and 44 or 32),
		Position = UDim2.new(1, touch and -52 or -38, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 2,
	}, { corner(12) })
	minimizeBtn.Parent = header

	-- In-hub theme switch (Dark/Light), transitions with a fade instead of snapping
	local currentThemeName = isLight and "Light" or "Dark"
	local themeBtn = create("TextButton", {
		Text = isLight and "🌙" or "☀",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 18 or 15,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(0, touch and 44 or 32, 0, touch and 44 or 32),
		Position = UDim2.new(1, touch and -104 or -76, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 2,
	}, { corner(12) })
	themeBtn.Parent = header

	makeDraggable(header, main)

	-- Floating toggle button: always on-screen, brings the whole UI back
	-- even if it's fully hidden. Placed top-right — bottom corners are where
	-- the mobile joystick (bottom-left) and jump button (bottom-right) live.
	local floatSize = touch and 52 or 42
	local floatBtn
	if iconId then
		-- The icon used to be set directly as this ImageButton's own `Image`
		-- property, which UIPadding can't inset (padding only affects layout
		-- of children, not an instance's own Image), so the icon looked cut
		-- off flush against the circular edge. Now the ImageButton itself
		-- carries no Image; a separate child ImageLabel sized ~72% and
		-- centered provides the padded icon instead.
		floatBtn = create("ImageButton", {
			Name = "FloatToggle",
			Image = "",
			BackgroundColor3 = Theme.ToggleButton,
			Size = UDim2.new(0, floatSize, 0, floatSize),
			Position = togglePosition,
			ZIndex = 50,
		}, { corner(floatSize / 2), stroke(Theme.Accent, 1.5) })

		local floatIconSize = math.floor(floatSize * 0.72)
		local floatIcon = create("ImageLabel", {
			Name = "Icon",
			Image = iconId,
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, floatIconSize, 0, floatIconSize),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 51,
		})
		floatIcon.Parent = floatBtn
		-- Same accidental-retint issue as the header icon — see the note there.
		floatIcon:SetAttribute("MUI_NoTheme", true)
	else
		floatBtn = create("TextButton", {
			Name = "FloatToggle",
			Text = "☰",
			Font = Enum.Font.GothamBold,
			TextSize = touch and 22 or 18,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.ToggleButton,
			Size = UDim2.new(0, floatSize, 0, floatSize),
			Position = togglePosition,
			ZIndex = 50,
		}, { corner(floatSize / 2), stroke(Theme.Accent, 1.5) })
	end
	floatBtn.Parent = screenGui

	makeDraggable(floatBtn, floatBtn)

	floatBtn.MouseButton1Click:Connect(function()
		main.Visible = not main.Visible
	end)

	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -headerHeight),
		Position = UDim2.new(0, 0, 0, headerHeight),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, {
		create("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	body.Parent = main

	-- Dedicated scroll region for the tab list: fits ~3 tabs comfortably before
	-- scrolling, with its own visible scrollbar (separate from each page's own
	-- content scrolling) so a long tab list never spills outside the window.
	local tabList = create("ScrollingFrame", {
		Name = "TabList",
		Size = UDim2.new(touch and 0.32 or 0.28, 0, 1, 0),
		BackgroundColor3 = Theme.Header,
		BorderSizePixel = 0,
		ScrollBarThickness = touch and 6 or 4,
		ScrollBarImageColor3 = Theme.Accent,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	tabList.Parent = body

	local pages = create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1 - (touch and 0.32 or 0.28), 0, 1, 0),
		Position = UDim2.new(touch and 0.32 or 0.28, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	pages.Parent = body

	local minimized = false
	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		tween(main, { Size = minimized and UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, headerHeight) or mainSizeScale }, 0.2)
		body.Visible = not minimized
	end)

	local notifHolder = create("Frame", {
		Name = "NotifHolder",
		Size = UDim2.new(0, touch and 280 or 260, 1, -20),
		Position = UDim2.new(1, -16, 1, -10),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	notifHolder.Parent = screenGui

	-- Spotlight overlay: dims the tab list + page content while a dropdown,
	-- color picker, or other popover is open, drawing focus to it.
	local spotlightOverlay = create("Frame", {
		Name = "Spotlight",
		Size = body.Size,
		Position = body.Position,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 5,
	})
	spotlightOverlay.Parent = main

	local Window = setmetatable({
		_screenGui = screenGui,
		_main = main,
		_tabList = tabList,
		_pages = pages,
		_tabs = {},
		_touch = touch,
		_firstTab = true,
		_notifHolder = notifHolder,
		_notifCount = 0,
		_currentPageEntry = nil,
		_spotlightOverlay = spotlightOverlay,
		_spotlightCount = 0,
		_commands = {
			["t-notif"] = function(w)
				w:Notify({ Title = "Test Notification", Content = "This is a test notification.", Type = "info" })
			end,
		},
	}, { __index = Library.WindowMethods })

	-- Command palette: typing a registered keyword into the title and
	-- pressing Enter (or clicking away) fires that command, then the title
	-- reverts to showing the hub's name again. Anything after the first word
	-- is passed along as arguments, so plugins can build admin-panel-style
	-- commands like "speed 50" or "fly on".
	titleBox.Focused:Connect(function()
		titleBox.Text = ""
	end)
	titleBox.FocusLost:Connect(function()
		local raw = titleBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if raw ~= "" then
			local words = {}
			for word in raw:gmatch("%S+") do
				table.insert(words, word)
			end
			local cmd = table.remove(words, 1):lower()
			local action = Window._commands[cmd]
			if action then
				local argString = table.concat(words, " ")
				local ok, err = pcall(action, Window, argString, words)
				if not ok then warn("[MobileUILib] Command palette error: " .. tostring(err)) end
			end
		end
		titleBox.Text = windowName
	end)

	themeBtn.MouseButton1Click:Connect(function()
		currentThemeName = (currentThemeName == "Dark") and "Light" or "Dark"
		themeBtn.Text = (currentThemeName == "Light") and "🌙" or "☀"
		Window:SetTheme(currentThemeName)
	end)

	-- ===================== INTRO ANIMATION =====================
	-- Plays on top of the hub (already fully built by this point, just faded
	-- out via GroupTransparency) so it overlaps instead of blocking
	-- construction. No sound. Wipe-in reveal, then a split-panel exit with
	-- the hub fading in underneath as the panels part.
	if Library.Flags.ReducedMotion then
		-- Performance mode: the intro is built from task.wait()'d phases, so
		-- an instant-tween alone can't shortcut it — skip building it at all.
		-- Set this flag with Library:SetFlag("ReducedMotion", true) BEFORE
		-- calling CreateWindow for it to take effect (the intro only plays once).
		return Window
	end
	local introConfig = config.Intro or {}
	local introImage = introConfig.Image
	if introImage == nil then
		introImage = 80406291512141 -- default intro image asset
	elseif introImage == false then
		introImage = nil -- explicit opt-out: Intro = { Image = false }
	end
	if introImage and type(introImage) == "number" then
		introImage = "rbxassetid://" .. tostring(introImage)
	elseif introImage and type(introImage) == "string" and not introImage:match("^rbxassetid://") then
		introImage = "rbxassetid://" .. introImage
	end
	local introText = introConfig.Text or "-By Lifeless"
	local introHold = introConfig.Duration or 1.4 -- seconds the intro stays fully visible
	local normalIntroTooltips = {
		"Tip: click the hub name to open the command palette.",
		"Tip: click the floating button to hide or restore the hub.",
		"Tip: use the theme button to switch between light and dark mode.",
		"Tip: settings with a Flag can be saved and restored with configs.",
		"Tip: tabs and the hub window can be dragged on desktop and touch.",
	}
	local funnyIntroTooltips = {
		"Downloading more RAM...",
		"Cleaning the toilet...",
		"C:????????????????????????: Something happened.",
		"Teaching the corn how to code...",
		"Convincing the buttons to behave...",
		"Calibrating the cat launcher...",
	}
	local introTooltips = introConfig.Funny == true and funnyIntroTooltips or normalIntroTooltips
	local lastIntroTooltip
	local function nextIntroTooltip()
		if #introTooltips == 1 then return introTooltips[1] end
		local tooltip
		repeat
			tooltip = introTooltips[math.random(1, #introTooltips)]
		until tooltip ~= lastIntroTooltip
		lastIntroTooltip = tooltip
		return tooltip
	end

	local introBg = isLight and Color3.fromRGB(250, 250, 252) or Color3.fromRGB(0, 0, 0)
	local introLineColor = isLight and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(255, 255, 255)
	local introTextColor = Color3.fromRGB(255, 196, 48) -- corn yellow, fixed regardless of theme

	local introOverlay = create("Frame", {
		Name = "IntroOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1, -- container only; the wipe/panels below carry the color
		BorderSizePixel = 0,
		ZIndex = 300,
		Active = true, -- blocks input to the hub underneath while the intro plays
	})
	introOverlay.Parent = screenGui

	-- Wipe-in: a colored panel grows left-to-right like a brush stroke painting the screen
	local wipe = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = introBg,
		BorderSizePixel = 0,
		ZIndex = 300,
	})
	wipe.Parent = introOverlay

	local introHolder = create("Frame", {
		Size = UDim2.new(0, 280, 0, 260),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 302,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 16),
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	introHolder.Parent = introOverlay

	local introImgLabel
	if introImage then
		introImgLabel = create("ImageLabel", {
			Image = introImage,
			BackgroundTransparency = 1,
			ImageTransparency = 1,
			Size = UDim2.new(0, 140, 0, 140),
			ZIndex = 302,
		})
		introImgLabel.Parent = introHolder
	end

	local introTextLabel = create("TextLabel", {
		Text = introText,
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextColor3 = introTextColor,
		TextTransparency = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		ZIndex = 302,
	})
	introTextLabel.Parent = introHolder

	local introTooltipLabel = create("TextLabel", {
		Name = "Tooltip",
		Text = nextIntroTooltip(),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = isLight and Color3.fromRGB(85, 85, 92) or Color3.fromRGB(190, 190, 198),
		TextTransparency = 1,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 38),
		ZIndex = 302,
	})
	introTooltipLabel.Parent = introHolder

	task.spawn(function()
		-- Phase 1: brush-stroke wipe reveal
		tween(wipe, { Size = UDim2.new(1, 0, 1, 0) }, 0.5)
		task.wait(0.5)

		-- Phase 2: logo + brand text fade in
		if introImgLabel then
			tween(introImgLabel, { ImageTransparency = 0 }, 0.5)
			task.wait(0.3)
		end
		tween(introTextLabel, { TextTransparency = 0 }, 0.5)
		tween(introTooltipLabel, { TextTransparency = 0 }, 0.5)

		-- A normal intro shows one useful tip; longer custom intros rotate through
		-- the selected normal/funny list without extending the configured duration.
		local elapsed = 0
		while elapsed < introHold do
			local waitTime = math.min(2, introHold - elapsed)
			task.wait(waitTime)
			elapsed = elapsed + waitTime
			if elapsed < introHold then
				introTooltipLabel.Text = nextIntroTooltip()
			end
		end

		-- Phase 3: fade out logo/text, then split the panel in two and part it
		tween(introTextLabel, { TextTransparency = 1 }, 0.3)
		tween(introTooltipLabel, { TextTransparency = 1 }, 0.3)
		if introImgLabel then tween(introImgLabel, { ImageTransparency = 1 }, 0.3) end
		task.wait(0.3)

		wipe.Visible = false

		local topHalf = create("Frame", {
			Size = UDim2.new(1, 0, 0.5, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = introBg,
			BorderSizePixel = 0,
			ZIndex = 300,
		})
		topHalf.Parent = introOverlay

		local bottomHalf = create("Frame", {
			Size = UDim2.new(1, 0, 0.5, 0),
			Position = UDim2.new(0, 0, 0.5, 0),
			BackgroundColor3 = introBg,
			BorderSizePixel = 0,
			ZIndex = 300,
		})
		bottomHalf.Parent = introOverlay

		local centerLine = create("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 0.5, -1),
			BackgroundColor3 = introLineColor,
			BorderSizePixel = 0,
			ZIndex = 301,
		})
		centerLine.Parent = introOverlay

		-- Hub is already fully built underneath — the panels parting is the reveal
		tween(topHalf, { Position = UDim2.new(0, 0, -0.5, 0) }, 0.55)
		tween(bottomHalf, { Position = UDim2.new(0, 0, 1, 0) }, 0.55)
		tween(centerLine, { BackgroundTransparency = 1 }, 0.4)

		task.wait(0.6)
		introOverlay:Destroy()
	end)

	return Window
end

Library.WindowMethods = {}
local WM = Library.WindowMethods

-- Window:Notify({ Title = "Saved", Content = "...", Duration = 4, Type = "success" })
-- Type is optional: "success" | "error" | "warning" | "info" (defaults to plain accent)
function WM:Notify(config)
	config = config or {}
	local touch = self._touch
	local title = config.Title or "Notification"
	local content = config.Content or ""
	local duration = config.Duration or 4
	local notifType = config.Type

	local typeColors = {
		success = Color3.fromRGB(70, 200, 110),
		error = Color3.fromRGB(230, 75, 75),
		warning = Color3.fromRGB(255, 175, 45),
		info = Theme.Accent,
	}
	local typeIcons = {
		success = "✓",
		error = "✕",
		warning = "!",
		info = "i",
	}
	local barColor = typeColors[notifType] or Theme.Accent
	local iconChar = typeIcons[notifType]

	self._notifCount += 1

	-- Log to the shared history before building the visual toast, so a
	-- NotificationCenter element (which may live on a different tab, or
	-- be created after this call) always has the full record.
	Library._notifSeq = (Library._notifSeq or 0) + 1
	local historyEntry = {
		Title = title,
		Content = content,
		Type = notifType,
		Time = os.time(),
		Seq = Library._notifSeq,
	}
	table.insert(Library.NotificationHistory, historyEntry)
	if #Library.NotificationHistory > Library.MAX_NOTIFICATION_HISTORY then
		table.remove(Library.NotificationHistory, 1)
	end
	Library.NotificationLogged:Fire(historyEntry)

	local notif = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Header,
		BackgroundTransparency = 1,
		LayoutOrder = self._notifCount,
	}, {
		corner(12),
		stroke(barColor, 1),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
		}),
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	notif.Parent = self._notifHolder

	local titleRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	titleRow.Parent = notif

	if iconChar then
		local iconLabel = create("TextLabel", {
			Text = iconChar,
			Font = Enum.Font.GothamBold,
			TextSize = touch and 15 or 13,
			TextColor3 = barColor,
			TextTransparency = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 16, 1, 0),
		})
		iconLabel.Parent = titleRow
		tween(iconLabel, { TextTransparency = 0 }, 0.2)
	end

	local titleLabel = create("TextLabel", {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = touch and 16 or 14,
		TextColor3 = Theme.Text,
		TextTransparency = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, iconChar and -22 or 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	titleLabel.Parent = titleRow

	local contentLabel = create("TextLabel", {
		Text = content,
		Font = Enum.Font.Gotham,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.SubText,
		TextTransparency = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	contentLabel.Parent = notif

	-- Countdown bar: shrinks over the notification's lifetime. Grey when no
	-- Type is given, otherwise matches the type's color.
	local progressColor = typeColors[notifType] or Color3.fromRGB(140, 140, 148)
	local progressTrack = create("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, { corner(2) })
	progressTrack.Parent = notif

	local progressBar = create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = progressColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, { corner(2) })
	progressBar.Parent = progressTrack

	tween(notif, { BackgroundTransparency = 0 }, 0.2)
	tween(titleLabel, { TextTransparency = 0 }, 0.2)
	tween(contentLabel, { TextTransparency = 0 }, 0.2)
	tween(progressTrack, { BackgroundTransparency = 0.7 }, 0.2)
	tween(progressBar, { BackgroundTransparency = 0 }, 0.2)
	TweenService:Create(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) }):Play()

	task.delay(duration, function()
		tween(notif, { BackgroundTransparency = 1 }, 0.3)
		tween(titleLabel, { TextTransparency = 1 }, 0.3)
		tween(contentLabel, { TextTransparency = 1 }, 0.3)
		tween(progressTrack, { BackgroundTransparency = 1 }, 0.3)
		tween(progressBar, { BackgroundTransparency = 1 }, 0.3)
		task.delay(0.3, function()
			if notif then notif:Destroy() end
		end)
	end)
end

-- Window:SetTheme("Light" | "Dark") — live-swaps every instance whose current
-- color matches a known color in the OLD theme to the corresponding color in
-- the NEW theme, tweened. This avoids needing a manual registry: it works by
-- diffing against the theme table itself rather than tracking every instance.
function WM:SetTheme(name)
	local newPreset = Themes[name]
	if not newPreset then return end

	-- Every theme switch (light/dark toggle, plugins, Config:Load) goes
	-- through here, so this is the one place that needs to remember the
	-- active preset name for the Config System to save/restore later.
	Library._currentThemeName = name

	local reverseMap = {}
	for k, v in pairs(Theme) do reverseMap[tostring(v)] = k end

	for _, inst in ipairs(self._screenGui:GetDescendants()) do
		if inst:IsA("GuiObject") then
			local ok, bg = pcall(function() return inst.BackgroundColor3 end)
			if ok then
				local key = reverseMap[tostring(bg)]
				if key and newPreset[key] then
					tween(inst, { BackgroundColor3 = newPreset[key] }, 0.35)
				end
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				local key2 = reverseMap[tostring(inst.TextColor3)]
				if key2 and newPreset[key2] then
					tween(inst, { TextColor3 = newPreset[key2] }, 0.35)
				end
			end
			if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and not inst:GetAttribute("MUI_NoTheme") then
				local key3 = reverseMap[tostring(inst.ImageColor3)]
				if key3 and newPreset[key3] then
					tween(inst, { ImageColor3 = newPreset[key3] }, 0.35)
				end
			end
		elseif inst:IsA("UIStroke") then
			local key4 = reverseMap[tostring(inst.Color)]
			if key4 and newPreset[key4] then
				tween(inst, { Color = newPreset[key4] }, 0.35)
			end
		end
	end

	for k, v in pairs(newPreset) do Theme[k] = v end
end

-- Keys the in-hub Theme Editor is allowed to touch. The yellow Accent is the
-- fixed "corn" brand color and is deliberately left out here so it can never
-- be recolored through the editor.
local THEME_EDITOR_KEYS = { Background = true, ToggleButton = true }

-- Window:SetThemeColor(key, color) — single-key version of SetTheme's reverse
-- lookup tween. Used by Tab:CreateThemeEditor() so picking a new "UI Color"
-- or "Toggle Button Color" only retints instances currently using that one
-- theme slot, instead of re-running the full theme diff.
function WM:SetThemeColor(key, color)
	if not THEME_EDITOR_KEYS[key] then return end
	local oldColor = Theme[key]
	if not oldColor then return end

	-- NOTE: this runs on every color-picker drag frame (many times a
	-- second), not just once on release. It used to tween() each match over
	-- 0.25s, but that meant an instance's live color usually hadn't finished
	-- animating to `oldColor` by the time the next drag-frame's exact-match
	-- check ran — so the match failed and the instance silently stopped
	-- updating. That's why dragging only ever seemed to "take" on the very
	-- first tap. Setting instantly keeps every instance's live color exactly
	-- equal to Theme[key] between calls, so matching stays reliable for the
	-- whole drag.
	for _, inst in ipairs(self._screenGui:GetDescendants()) do
		if inst:IsA("GuiObject") then
			local ok, bg = pcall(function() return inst.BackgroundColor3 end)
			if ok and bg == oldColor then
				inst.BackgroundColor3 = color
			end
			if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and not inst:GetAttribute("MUI_NoTheme") then
				if inst.ImageColor3 == oldColor then
					inst.ImageColor3 = color
				end
			end
		elseif inst:IsA("UIStroke") then
			if inst.Color == oldColor then
				inst.Color = color
			end
		end
	end

	Theme[key] = color
end

-- Window:SetBackground(SourceOrConfig) — sits behind everything else inside
-- the hub as a backdrop. You can pass either:
--   * a bare asset/source string or number:
--       Window:SetBackground(123456789)
--       Window:SetBackground("rbxassetid://123456789")
--       Window:SetBackground(getcustomasset("cat.png"))
--   * or the old config table form:
--       Window:SetBackground({ Type = "Video", Texture = "rbxassetid://...", Volume = 0 })
--
-- If you pass a bare local filename and the executor exposes getcustomasset(),
-- it will be resolved automatically before being assigned to the ImageLabel or
-- VideoFrame. Otherwise, any valid Roblox content-id string is accepted as-is.
function WM:SetBackground(input)
	local config = type(input) == "table" and input or { Texture = input }

	local texture = config.Texture or config.Source or config.Image
	if type(texture) == "number" then
		texture = "rbxassetid://" .. tostring(texture)
	end
	if type(texture) ~= "string" then
		warn("[MobileUILib] SetBackground requires a Texture/source string or numeric asset id")
		return
	end

	texture = texture:gsub("^%s+", ""):gsub("%s+$", "")
	if texture == "" then
		warn("[MobileUILib] SetBackground requires a non-empty image source")
		return
	end

	-- Convenience: if someone passes a local filename directly (cat.png,
	-- wallpaper.jpg, etc.) and the executor supports getcustomasset(), resolve
	-- it here. Any already-resolved asset URI (rbxassetid://..., rbxasset://...)
	-- is left untouched.
	local lower = texture:lower()
	if not (lower:match("^rbxassetid://") or lower:match("^rbxasset://")) then
		local looksLikeImage = lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$") or lower:match("%.gif$") or lower:match("%.img$")
		if looksLikeImage and type(getcustomasset) == "function" then
			local ok, resolved = pcall(getcustomasset, texture)
			if ok and type(resolved) == "string" and resolved ~= "" then
				texture = resolved
			end
		end
	end

	self:ClearBackground()

	local kind = config.Type or "Image"
	local bg
	if kind == "Video" then
		bg = create("VideoFrame", {
			Name = "MUI_Background",
			Video = texture,
			Looped = true,
			Playing = true,
			Volume = config.Volume or 0,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, { corner(16) })
	else
		bg = create("ImageLabel", {
			Name = "MUI_Background",
			Image = texture,
			ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = config.Transparency or config.ImageTransparency or 0,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, { corner(16) })
	end
	bg:SetAttribute("MUI_NoTheme", true)
	bg.Parent = self._main

	self._background = bg
	return bg
end

-- Window:ClearBackground() — removes whatever SetBackground added, if anything.
function WM:ClearBackground()
	if self._background then
		self._background:Destroy()
		self._background = nil
	end
end

-- Window:RegisterCommand("keyword", function(window, argString, args) ... end)
-- adds a command the title-bar command palette runs when that first word
-- (case-insensitive) is typed and confirmed. Anything typed after the
-- keyword is handed back as `argString` (raw text) and `args` (a table of
-- whitespace-split words) — e.g. typing "speed 50" calls the "speed"
-- command with argString "50" and args {"50"}. A "T-notif" test command is
-- registered by default; call this to add your own (e.g. ESP toggles, or
-- see the AdminCommands example plugin for a fuller admin-panel pattern).
function WM:RegisterCommand(keyword, fn)
	self._commands[tostring(keyword):lower()] = fn
end

-- Window:SetSpotlight(true/false) — dims the rest of the hub while a
-- dropdown, color picker, or similar popover is open, drawing focus to it.
-- Reference-counted so two popovers opening/closing don't fight each other.
function WM:SetSpotlight(active)
	if active then
		self._spotlightCount += 1
	else
		self._spotlightCount = math.max(0, self._spotlightCount - 1)
	end
	local shouldShow = self._spotlightCount > 0
	self._spotlightOverlay.Active = shouldShow
	tween(self._spotlightOverlay, { BackgroundTransparency = shouldShow and 0.5 or 1 }, 0.2)
end

function WM:CreateTab(name, config)
	config = config or {}
	local touch = self._touch
	local iconId = config.Icon
	if iconId and type(iconId) == "number" then
		iconId = "rbxassetid://" .. tostring(iconId)
	elseif iconId and type(iconId) == "string" and not iconId:match("^rbxassetid://") then
		iconId = "rbxassetid://" .. iconId
	end

	local tabButton = create("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and 40 or 30),
		AutoButtonColor = false,
	}, { corner(10) })
	tabButton.Parent = self._tabList

	local contentRow = create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
	})
	contentRow.Parent = tabButton

	local iconLabel
	if iconId then
		local iconSize = touch and 20 or 16
		iconLabel = create("ImageLabel", {
			Image = iconId,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, iconSize, 0, iconSize),
			ImageColor3 = Theme.SubText,
			ScaleType = Enum.ScaleType.Fit,
		})
		iconLabel.Parent = contentRow
	end

	local tabLabel = create("TextLabel", {
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, iconId and -34 or -10, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	tabLabel.Parent = contentRow

	local page = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = touch and 6 or 4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
	page.Parent = self._pages

	local Tab = setmetatable({
		_page = page,
		_touch = touch,
		_window = self,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	local tabEntry = { button = tabButton, page = page, label = tabLabel, icon = iconLabel, glow = nil, glowTween = nil }
	table.insert(self._tabs, tabEntry)

	local function selectTab()
		if self._currentPageEntry == tabEntry then return end

		for _, t in pairs(self._tabs) do
			if t ~= tabEntry then
				tween(t.button, { BackgroundColor3 = Theme.Element }, 0.1)
				tween(t.label, { TextColor3 = Theme.SubText }, 0.1)
				if t.icon then tween(t.icon, { ImageColor3 = Theme.SubText }, 0.1) end
				if t.glow then
					stopBreathingGlow(t.glow, t.glowTween)
					t.glow, t.glowTween = nil, nil
				end
			end
		end

		tween(tabButton, { BackgroundColor3 = Theme.Accent }, 0.1)
		tween(tabLabel, { TextColor3 = Theme.TextOnAccent }, 0.1)
		if iconLabel then tween(iconLabel, { ImageColor3 = Theme.TextOnAccent }, 0.1) end
		tabEntry.glow, tabEntry.glowTween = startBreathingGlow(tabButton, Theme.Accent)

		local previousEntry = self._currentPageEntry
		if previousEntry and previousEntry.page ~= page then
			local oldPage = previousEntry.page
			oldPage.Position = UDim2.new(0, 0, 0, 0)
			page.Position = UDim2.new(1, 0, 0, 0)
			page.Visible = true
			tween(oldPage, { Position = UDim2.new(-1, 0, 0, 0) }, 0.25)
			tween(page, { Position = UDim2.new(0, 0, 0, 0) }, 0.25)
			task.delay(0.25, function()
				oldPage.Visible = false
				oldPage.Position = UDim2.new(0, 0, 0, 0)
			end)
		else
			page.Position = UDim2.new(0, 0, 0, 0)
			page.Visible = true
		end

		self._currentPageEntry = tabEntry
	end

	tabButton.MouseButton1Click:Connect(selectTab)

	-- Static glow on hover (desktop only — MouseEnter/Leave never fire on touch),
	-- skipped while this tab is the selected one (already has the breathing glow)
	tabButton.MouseEnter:Connect(function()
		if self._currentPageEntry ~= tabEntry and not tabButton:FindFirstChild("_HoverGlow") then
			create("UIStroke", { Name = "_HoverGlow", Color = Theme.Accent, Thickness = 1.5, Transparency = 0.5 }).Parent = tabButton
		end
	end)
	tabButton.MouseLeave:Connect(function()
		local s = tabButton:FindFirstChild("_HoverGlow")
		if s then s:Destroy() end
	end)

	if self._firstTab then
		self._firstTab = false
		selectTab()
	end

	return Tab
end

-- ===================== TAB ELEMENTS =====================
Library.TabMethods = {}
local TM = Library.TabMethods

-- ===================== ELEMENT MANAGEMENT =====================
-- Most element-creation functions below funnel their return value through
-- Library:_wrapElement(root, value) so every element gains the same four
-- methods, regardless of whether it normally returns a {Set,Get} handle, a
-- Section/Card-style nested-page object, or (for a few elements) a raw
-- Instance:
--   :Destroy()             — removes the element's UI entirely
--   :SetVisible(bool)       — shows/hides it
--   :SetDisabled(bool)      — dims it and blocks input via a small overlay,
--                              with no per-element wiring required
--   :Refresh()               — for elements with Set/Get, re-applies
--                              Get() through Set() to force a visual
--                              resync; KeybindList/NotificationCenter/
--                              PluginManager override this with their own
--                              rebuild-from-source logic instead
--
-- KNOWN, DELIBERATE EXCEPTION: Tab:CreateLabel() keeps returning the raw
-- TextLabel Instance, unwrapped. DevSuite.lua (already shipped) depends on
-- that — it does `fpsLabel.Text = ...` and `fpsLabel.AncestryChanged:Connect(...)`
-- directly on the return value. Wrapping it would silently break that
-- plugin. :Destroy() and .Visible already work on it natively (real
-- Instance methods/properties) either way; :SetDisabled()/:Refresh() are
-- the only things a label genuinely loses by keeping this shape — and a
-- static label rarely needs either. CreateThemeEditor is also left
-- unwrapped: it's a composite of a label + two color pickers with no
-- single root to hang one overlay/visibility toggle on.
function Library:_wrapElement(root, value)
	local handle
	if type(value) == "table" then
		handle = value
	else
		handle = {}
	end
	if handle.Instance == nil then handle.Instance = root end

	handle.Destroy = handle.Destroy or function(_)
		if root and root.Parent then root:Destroy() end
	end

	handle.SetVisible = handle.SetVisible or function(_, visible)
		if root then root.Visible = visible end
	end

	handle.SetDisabled = handle.SetDisabled or function(_, disabled)
		if not root then return end
		local overlay = root:FindFirstChild("MUI_DisabledOverlay")
		if disabled then
			if not overlay then
				overlay = create("Frame", {
					Name = "MUI_DisabledOverlay",
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = Theme.Background,
					BackgroundTransparency = 0.45,
					ZIndex = 1000,
					Active = true, -- swallows clicks/touches so nothing underneath is reachable
				})
				overlay.Parent = root
			end
		elseif overlay then
			overlay:Destroy()
		end
	end

	handle.Refresh = handle.Refresh or function(self_)
		if self_.Set and self_.Get then
			local ok, current = pcall(self_.Get, self_)
			if ok then pcall(self_.Set, self_, current) end
		end
	end

	return handle
end

-- Sections group elements visually inside a tab, like Orion's :AddSection
function TM:CreateSection(name)
	local touch = self._touch

	local container = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 40 or 30), -- grows via AutomaticSize
		BackgroundColor3 = Theme.Header,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	})
	container.Parent = self._page

	create("TextLabel", {
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 20 or 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = container

	-- A Section behaves just like a Tab (same element methods), but nests inside the tab's page
	local Section = setmetatable({
		_page = container,
		_touch = touch,
		_window = self._window,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	return Library:_wrapElement(container, Section)
end

function TM:CreateLabel(text)
	local touch = self._touch
	local label = create("TextLabel", {
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 24 or 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = self._page
	return label
end

function TM:CreateButton(config)
	config = config or {}
	local touch = self._touch
	local callback = config.Callback or function() end

	-- NOTE: the stroke lives on this wrapper Frame (Text = "" by definition,
	-- since Frames have no Text property), not on the TextButton itself.
	-- Roblox's UIStroke outlines BOTH a frame's border and any text glyphs
	-- when applied directly to a Text-bearing instance, which produced an
	-- orange-ish fringe around the label in Light mode. Keeping the stroke on
	-- a non-text holder and the label as a separate child avoids that.
	local btn = create("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and 46 or 34), -- tall enough for a finger tap
		AutoButtonColor = false,
	}, { corner(12), stroke() })
	btn.Parent = self._page
	setSearchMeta(btn, config, "Button")

	local label = create("TextLabel", {
		Text = config.Name or "Button",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 16 or 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	})
	label.Parent = btn

	btn.MouseButton1Click:Connect(function()
		ripple(btn, Theme.Accent)
		tween(btn, { BackgroundColor3 = Theme.Accent }, 0.1)
		task.delay(0.1, function()
			tween(btn, { BackgroundColor3 = Theme.Element }, 0.1)
		end)
		local ok, err = pcall(callback)
		if not ok then warn("[MobileUILib] Button callback error: " .. tostring(err)) end
	end)

	return Library:_wrapElement(btn)
end

function TM:CreateToggle(config)
	config = config or {}
	local touch = self._touch
	local state = config.Default or false
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 46 or 34),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Toggle")

	if config.Flag then Library:SetFlag(config.Flag, state) end

	create("TextLabel", {
		Text = config.Name or "Toggle",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 16 or 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	-- Big touch-friendly switch (min 44x24 hit target)
	local switchBg = create("Frame", {
		Size = UDim2.new(0, touch and 50 or 40, 0, touch and 28 or 22),
		Position = UDim2.new(1, touch and -60 or -48, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 68),
	}, { corner(18) })
	switchBg.Parent = holder

	local knob = create("Frame", {
		Size = UDim2.new(0, touch and 22 or 16, 0, touch and 22 or 16),
		Position = state and UDim2.new(1, -((touch and 22 or 16) + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	}, { corner(15) })
	knob.Parent = switchBg

	local hitArea = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	})
	hitArea.Parent = holder

	hitArea.MouseButton1Click:Connect(function()
		state = not state
		ripple(holder, Theme.Accent)
		tween(switchBg, { BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 68) }, 0.15)
		tween(knob, {
			Position = state
				and UDim2.new(1, -((touch and 22 or 16) + 3), 0.5, 0)
				or UDim2.new(0, 3, 0.5, 0)
		}, 0.15)
		if config.Flag then Library:SetFlag(config.Flag, state) end
		local ok, err = pcall(callback, state)
		if not ok then warn("[MobileUILib] Toggle callback error: " .. tostring(err)) end
	end)

	local handle = { Set = function(_, value)
		-- Was previously only updating `state` + the flag with no visual
		-- change — a saved/loaded Toggle value would be correct in
		-- Library.Flags but the switch itself would look untouched.
		state = value
		switchBg.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 68)
		knob.Position = state
			and UDim2.new(1, -((touch and 22 or 16) + 3), 0.5, 0)
			or UDim2.new(0, 3, 0.5, 0)
		if config.Flag then Library:SetFlag(config.Flag, state) end
	end, Get = function() return state end }
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return Library:_wrapElement(holder, handle)
end

function TM:CreateSlider(config)
	config = config or {}
	local touch = self._touch
	local min = config.Min or 0
	local max = config.Max or 100
	local default = config.Default or min
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 58 or 46),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Slider")

	if config.Flag then Library:SetFlag(config.Flag, default) end

	local label = create("TextLabel", {
		Text = (config.Name or "Slider") .. ": " .. tostring(default),
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.new(0, 12, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = holder

	-- Bigger track height on mobile so it's easy to grab with a finger
	local track = create("Frame", {
		Size = UDim2.new(1, -24, 0, touch and 14 or 8),
		Position = UDim2.new(0, 12, 1, touch and -22 or -16),
		BackgroundColor3 = Color3.fromRGB(55, 55, 62),
	}, { corner(10) })
	track.Parent = holder

	local fraction = (default - min) / (max - min)
	local fill = create("Frame", {
		Size = UDim2.new(fraction, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
	}, { corner(10) })
	fill.Parent = track

	-- Invisible larger hit area around the thin track, for easier touch dragging
	local hitArea = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 40 or 26),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	})
	hitArea.Parent = track

	local dragging = false

	local function setFromInputPosition(xPos)
		local relative = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		local value = math.floor(min + (max - min) * relative)
		label.Text = (config.Name or "Slider") .. ": " .. tostring(value)
		if config.Flag then Library:SetFlag(config.Flag, value) end
		local ok, err = pcall(callback, value)
		if not ok then warn("[MobileUILib] Slider callback error: " .. tostring(err)) end
	end

	hitArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromInputPosition(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			setFromInputPosition(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local handle = { Set = function(_, value)
		local relative = math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		label.Text = (config.Name or "Slider") .. ": " .. tostring(value)
		if config.Flag then Library:SetFlag(config.Flag, value) end
	end, Get = function() return config.Flag and Library:GetFlag(config.Flag) or nil end }
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return Library:_wrapElement(holder, handle)
end

function TM:CreateTextbox(config)
	config = config or {}
	local touch = self._touch
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 46 or 34),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Input")

	if config.Flag then Library:SetFlag(config.Flag, config.Default or "") end

	create("TextLabel", {
		Text = config.Name or "Input",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local box = create("TextBox", {
		Text = config.Default or "",
		PlaceholderText = config.Placeholder or "Enter text...",
		Font = Enum.Font.Gotham,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0.55, -12, 0, touch and 34 or 24),
		Position = UDim2.new(0.45, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ClearTextOnFocus = false,
	}, { corner(10) })
	box.Parent = holder

	box.FocusLost:Connect(function(enterPressed)
		if config.Flag then Library:SetFlag(config.Flag, box.Text) end
		local ok, err = pcall(callback, box.Text, enterPressed)
		if not ok then warn("[MobileUILib] Textbox callback error: " .. tostring(err)) end
	end)

	local handle = { Set = function(_, value)
		box.Text = value
		if config.Flag then Library:SetFlag(config.Flag, value) end
	end, Get = function() return box.Text end }
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return Library:_wrapElement(holder, handle)
end

-- Alias so the API is consistent regardless of casing preference —
-- Tab:CreateTextBox() and Tab:CreateTextbox() are the same function.
TM.CreateTextBox = TM.CreateTextbox

-- Note: keybinds are a PC concept (no physical keys on mobile) but are included
-- for parity since dev panels are often used with a keyboard connected either way.
function TM:CreateKeybind(config)
	config = config or {}
	local touch = self._touch
	local currentKey = config.Default or Enum.KeyCode.Unknown
	local callback = config.Callback or function() end
	local listening = false
	-- Declared before the closures below so they can capture it; populated
	-- with a real .Get() once `handle` exists, and registered into
	-- Library.Keybinds at the end of this function.
	local keybindDescriptor = { Name = config.Name or "Keybind" }

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 46 or 34),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Keybind")

	if config.Flag then Library:SetFlag(config.Flag, currentKey) end

	create("TextLabel", {
		Text = config.Name or "Keybind",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local keyBtn = create("TextButton", {
		Text = (currentKey ~= Enum.KeyCode.Unknown) and currentKey.Name or "None",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0, touch and 80 or 70, 0, touch and 34 or 24),
		Position = UDim2.new(1, touch and -90 or -80, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	}, { corner(10) })
	keyBtn.Parent = holder

	keyBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyBtn.Text = "..."
		local conn
		conn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				currentKey = input.KeyCode
				keyBtn.Text = currentKey.Name
				listening = false
				conn:Disconnect()
				if config.Flag then Library:SetFlag(config.Flag, currentKey) end
				Library.KeybindChanged:Fire(keybindDescriptor)
				local ok, err = pcall(callback, currentKey)
				if not ok then warn("[MobileUILib] Keybind callback error: " .. tostring(err)) end
			end
		end)
	end)

	local handle = {
		Set = function(_, keyCode)
			currentKey = keyCode
			keyBtn.Text = keyCode.Name
			if config.Flag then Library:SetFlag(config.Flag, keyCode) end
			Library.KeybindChanged:Fire(keybindDescriptor)
		end,
		Get = function() return currentKey end,
		-- Custom Destroy (checked by _wrapElement before it supplies the
		-- generic one): a destroyed Keybind shouldn't linger in
		-- CreateKeybindList forever, so unregister it first.
		Destroy = function(_)
			for i, d in ipairs(Library.Keybinds) do
				if d == keybindDescriptor then
					table.remove(Library.Keybinds, i)
					break
				end
			end
			Library.KeybindUnregistered:Fire(keybindDescriptor)
			if holder and holder.Parent then holder:Destroy() end
		end,
	}
	if config.Flag then Library.FlagElements[config.Flag] = handle end

	-- Register so Tab:CreateKeybindList() can list this binding (and stay in
	-- sync with it) without needing to know it exists ahead of time.
	keybindDescriptor.Get = handle.Get
	table.insert(Library.Keybinds, keybindDescriptor)
	Library.KeybindRegistered:Fire(keybindDescriptor)

	return Library:_wrapElement(holder, handle)
end

function TM:CreateColorPicker(config)
	config = config or {}
	local touch = self._touch
	local color = config.Default or Color3.fromRGB(255, 0, 0)
	local callback = config.Callback or function() end
	local open = false
	local hue, sat, val = color:ToHSV()

	local closedH = touch and 46 or 34
	local panelHeight = touch and 150 or 130

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Color")

	if config.Flag then Library:SetFlag(config.Flag, color) end

	create("TextLabel", {
		Text = config.Name or "Color",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, closedH),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local swatch = create("TextButton", {
		Text = "",
		BackgroundColor3 = color,
		Size = UDim2.new(0, touch and 34 or 26, 0, touch and 34 or 26),
		Position = UDim2.new(1, touch and -44 or -34, 0, (closedH - (touch and 34 or 26)) / 2),
	}, { corner(10), stroke() })
	swatch.Parent = holder

	local panel = create("Frame", {
		Size = UDim2.new(1, -20, 0, panelHeight),
		Position = UDim2.new(0, 10, 0, closedH + 4),
		BackgroundTransparency = 1,
	})
	panel.Parent = holder

	local svHeight = touch and 100 or 84
	local svSquare = create("Frame", {
		Size = UDim2.new(1, 0, 0, svHeight),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
	}, { corner(10) })
	svSquare.Parent = panel

	local svGradient = create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1)),
	})
	svGradient.Parent = svSquare

	local blackOverlay = create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
	}, { corner(10) })
	blackOverlay.Parent = svSquare
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}).Parent = blackOverlay

	local svCursor = create("Frame", {
		Size = UDim2.new(0, 10, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(sat, 0, 1 - val, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, { corner(8), stroke(Color3.new(0, 0, 0), 1) })
	svCursor.Parent = svSquare

	local svHit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 4 })
	svHit.Parent = svSquare

	local hueStrip = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 22 or 16),
		Position = UDim2.new(0, 0, 0, svHeight + 10),
	}, { corner(10) })
	hueStrip.Parent = panel

	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
			ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
			ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
			ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
			ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
	}).Parent = hueStrip

	local hueCursor = create("Frame", {
		Size = UDim2.new(0, 6, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(hue, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, { stroke(Color3.new(0, 0, 0), 1) })
	hueCursor.Parent = hueStrip

	local hueHit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 4 })
	hueHit.Parent = hueStrip

	local function updateColor()
		color = Color3.fromHSV(hue, sat, val)
		swatch.BackgroundColor3 = color
		svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
		if config.Flag then Library:SetFlag(config.Flag, color) end
		local ok, err = pcall(callback, color)
		if not ok then warn("[MobileUILib] ColorPicker callback error: " .. tostring(err)) end
	end

	local draggingSV, draggingHue = false, false

	svHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSV = true
		end
	end)
	hueHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingHue = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSV, draggingHue = false, false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if draggingSV then
			local relX = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
			local relY = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
			sat, val = relX, 1 - relY
			svCursor.Position = UDim2.new(relX, 0, relY, 0)
			updateColor()
		elseif draggingHue then
			local relX = math.clamp((input.Position.X - hueStrip.AbsolutePosition.X) / hueStrip.AbsoluteSize.X, 0, 1)
			hue = relX
			hueCursor.Position = UDim2.new(relX, 0, 0.5, 0)
			updateColor()
		end
	end)

	swatch.MouseButton1Click:Connect(function()
		open = not open
		if self._window then
			self._window:SetSpotlight(open)
			shiftZIndex(holder, open and 50 or -50)
		end
		tween(holder, { Size = UDim2.new(1, 0, 0, open and (closedH + panelHeight + 8) or closedH) }, 0.2)
	end)

	local handle = {
		Set = function(_, newColor)
			hue, sat, val = newColor:ToHSV()
			color = newColor
			swatch.BackgroundColor3 = color
			svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			updateColor()
		end,
		Get = function() return color end,
	}
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return handle
end

-- Tab:CreateThemeEditor() — exposes two color pickers wired to
-- Window:SetThemeColor: "UI Color" (Theme.Background) and "Toggle Button
-- Color" (Theme.ToggleButton — kept separate from Theme.Element so this
-- doesn't also recolor every button/toggle/dropdown in the hub). The yellow
-- Accent is deliberately not exposed here; it's the fixed "corn" brand color.
function TM:CreateThemeEditor(config)
	config = config or {}
	local window = self._window

	self:CreateLabel(config.Title or "Theme Editor")

	self:CreateColorPicker({
		Name = config.UIColorName or "UI Color",
		Default = Theme.Background,
		Keywords = { "theme", "background" },
		Description = "Recolors the hub's main background",
		Callback = function(color)
			if window then window:SetThemeColor("Background", color) end
		end,
	})

	self:CreateColorPicker({
		Name = config.ToggleColorName or "Toggle Button Color",
		Default = Theme.ToggleButton,
		Keywords = { "theme", "float button", "toggle" },
		Description = "Recolors the floating show/hide button",
		Callback = function(color)
			if window then window:SetThemeColor("ToggleButton", color) end
		end,
	})
end

function TM:CreateDropdown(config)
	config = config or {}
	local touch = self._touch
	local options = config.Options or {}
	local selected = config.Default or options[1]
	local callback = config.Callback or function() end
	local open = false

	local closedH = touch and 46 or 34
	local itemHeight = touch and 40 or 30
	local maxVisibleItems = 6 -- caps the panel height regardless of option count
	local totalHeight = #options * itemHeight
	local panelHeight = math.min(totalHeight, maxVisibleItems * itemHeight)

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
		ZIndex = 2,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Dropdown")

	if config.Flag then Library:SetFlag(config.Flag, selected) end

	local mainBtn = create("TextButton", {
		Text = (config.Name or "Dropdown") .. ": " .. tostring(selected),
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, closedH),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, {
		create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
	})
	mainBtn.Parent = holder

	-- Scrollable + height-capped so long option lists (e.g. 50 items) don't blow up the UI
	local optionsFrame = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, panelHeight),
		Position = UDim2.new(0, 0, 0, closedH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = touch and 6 or 4,
		CanvasSize = UDim2.new(0, 0, 0, totalHeight),
		ZIndex = 2,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	optionsFrame.Parent = holder

	for _, opt in ipairs(options) do
		local optBtn = create("TextButton", {
			Text = tostring(opt),
			Font = Enum.Font.Gotham,
			TextSize = touch and 14 or 12,
			TextColor3 = Theme.SubText,
			BackgroundColor3 = Theme.ElementHover,
			Size = UDim2.new(1, 0, 0, itemHeight),
			ZIndex = 2,
		})
		optBtn.Parent = optionsFrame

		optBtn.MouseButton1Click:Connect(function()
			selected = opt
			mainBtn.Text = (config.Name or "Dropdown") .. ": " .. tostring(selected)
			open = false
			if self._window then
				self._window:SetSpotlight(false)
				shiftZIndex(holder, -50)
			end
			tween(holder, { Size = UDim2.new(1, 0, 0, closedH) }, 0.15)
			if config.Flag then Library:SetFlag(config.Flag, selected) end
			local ok, err = pcall(callback, selected)
			if not ok then warn("[MobileUILib] Dropdown callback error: " .. tostring(err)) end
		end)
	end

	mainBtn.MouseButton1Click:Connect(function()
		open = not open
		if self._window then
			self._window:SetSpotlight(open)
			shiftZIndex(holder, open and 50 or -50)
		end
		tween(holder, { Size = UDim2.new(1, 0, 0, open and (closedH + panelHeight) or closedH) }, 0.15)
	end)

	local handle = { Set = function(_, value)
		selected = value
		mainBtn.Text = (config.Name or "Dropdown") .. ": " .. tostring(selected)
		if config.Flag then Library:SetFlag(config.Flag, selected) end
	end }
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return handle
end

-- Tab:CreateSearch() — filters this tab/section's own elements by name as you type.
-- Roblox has no fuzzy "search across the whole hub" primitive without a manual
-- index, so this searches within the tab/section it's placed in.
function TM:CreateSearch(config)
	config = config or {}
	local touch = self._touch
	local page = self._page

	local box = create("TextBox", {
		PlaceholderText = config.Placeholder or "Search...",
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and 42 or 32),
		ClearTextOnFocus = false,
	}, {
		corner(10), stroke(),
		create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
	})
	box.Parent = page

	local noResults = create("TextLabel", {
		Text = "The searched feature is not available or removed",
		Font = Enum.Font.Gotham,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		TextWrapped = true,
		Visible = false,
	})
	noResults.Parent = page

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local query = box.Text:lower()
		local anyVisible = false
		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("GuiObject") and child ~= box and child ~= noResults then
				-- MUI_Search covers name + keywords + description; MUI_Name is the
				-- older, name-only fallback for any element that predates it.
				local haystack = child:GetAttribute("MUI_Search") or child:GetAttribute("MUI_Name")
				if haystack then
					local match = query == "" or haystack:lower():find(query, 1, true) ~= nil
					child.Visible = match
					if match then anyVisible = true end
				end
			end
		end
		noResults.Visible = (query ~= "" and not anyVisible)
	end)

	return box
end

-- Tab:CreateDiscordButton({ Name = "Join Discord", Invite = "discord.gg/xxxx" })
-- IMPORTANT: Roblox gives LocalScripts no way to write to the OS clipboard —
-- that API exists only for Studio plugins, not live games, for security
-- reasons. This can't be faked as a real one-tap copy. Instead it opens a
-- popup with a selectable text field so the player can copy it manually
-- (long-press → select all → copy on mobile, or click + Ctrl+C on PC).
function TM:CreateDiscordButton(config)
	config = config or {}
	local touch = self._touch
	local invite = config.Invite or "discord.gg/your-invite"
	local screenGui = self._screenGui

	-- See CreateButton for why the stroke sits on this non-text wrapper
	-- instead of directly on a TextButton with Text set.
	local btn = create("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and 46 or 34),
		AutoButtonColor = false,
	}, { corner(12), stroke() })
	btn.Parent = self._page
	setSearchMeta(btn, config, "Join Discord")

	create("TextLabel", {
		Text = config.Name or "Join Discord",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 16 or 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	}).Parent = btn

	btn.MouseButton1Click:Connect(function()
		ripple(btn, Theme.Accent)
		if not screenGui then return end

		local backdrop = create("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 200,
			Active = true,
		})
		backdrop.Parent = screenGui
		tween(backdrop, { BackgroundTransparency = 0.5 }, 0.2)

		local popup = create("Frame", {
			Size = UDim2.new(0, touch and 280 or 260, 0, 100),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Header,
			ZIndex = 201,
		}, { corner(14), stroke(Theme.Accent, 1.5) })
		popup.Parent = backdrop

		create("TextLabel", {
			Text = "Long-press the box, select all, then copy",
			Font = Enum.Font.Gotham,
			TextSize = touch and 12 or 11,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -24, 0, 16),
			Position = UDim2.new(0.5, 0, 0, 12),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 201,
		}).Parent = popup

		create("TextBox", {
			Text = invite,
			Font = Enum.Font.GothamMedium,
			TextSize = touch and 15 or 13,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.Element,
			Size = UDim2.new(1, -24, 0, 38),
			Position = UDim2.new(0.5, 0, 0, 36),
			AnchorPoint = Vector2.new(0.5, 0),
			ClearTextOnFocus = false,
			ZIndex = 201,
		}, { corner(8) }).Parent = popup

		local closeBtn = create("TextButton", {
			Text = "✕",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(1, -30, 0, 4),
			ZIndex = 201,
		})
		closeBtn.Parent = popup

		local function closePopup()
			tween(backdrop, { BackgroundTransparency = 1 }, 0.15)
			task.delay(0.15, function() backdrop:Destroy() end)
		end
		closeBtn.MouseButton1Click:Connect(closePopup)
		backdrop.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local mousePos = input.Position
				local popupPos, popupSize = popup.AbsolutePosition, popup.AbsoluteSize
				local insidePopup = mousePos.X >= popupPos.X and mousePos.X <= popupPos.X + popupSize.X
					and mousePos.Y >= popupPos.Y and mousePos.Y <= popupPos.Y + popupSize.Y
				if not insidePopup then closePopup() end
			end
		end)
	end)

	return btn
end

-- ===================== BASIC ELEMENTS =====================
-- Lighter-weight, mostly-static elements for laying out and grouping
-- content rather than taking input. Same conventions as everything else
-- above: create()/corner()/stroke() helpers, Theme table, touch-aware
-- sizing, setSearchMeta for Tab:CreateSearch integration.

-- Tab:CreateDivider(config?) — a plain 1px separator line, or a labeled
-- one (small caption above the line) if config.Name is given.
function TM:CreateDivider(config)
	config = config or {}
	local touch = self._touch

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, config.Name and (touch and 24 or 20) or (touch and 10 or 8)),
		BackgroundTransparency = 1,
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Divider")

	if config.Name then
		create("TextLabel", {
			Text = config.Name,
			Font = Enum.Font.GothamBold,
			TextSize = touch and 12 or 10,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, touch and 16 or 14),
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = holder
	end

	local line = create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
	})
	line.Parent = holder

	return holder
end

-- Tab:CreateCard(config?) — a visually distinct container (optional Title/
-- Subtitle) that behaves exactly like a Section: the object it returns
-- supports every Tab/Section method, so you can build normal elements
-- inside it. Useful for grouping related info/controls with more visual
-- weight than a plain Section, e.g. "Account" or "Server Info" blocks.
function TM:CreateCard(config)
	config = config or {}
	local touch = self._touch

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 40 or 30), -- grows via AutomaticSize
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(14),
		stroke(),
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
	card.Parent = self._page
	setSearchMeta(card, config, "Card")

	if config.Title then
		create("TextLabel", {
			Text = config.Title,
			Font = Enum.Font.GothamBold,
			TextSize = touch and 16 or 14,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, touch and 22 or 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}).Parent = card
	end

	if config.Subtitle then
		create("TextLabel", {
			Text = config.Subtitle,
			Font = Enum.Font.Gotham,
			TextSize = touch and 13 or 11,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}).Parent = card
	end

	-- Behaves just like a Section: same element methods, nested one level deeper
	local Card = setmetatable({
		_page = card,
		_touch = touch,
		_window = self._window,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	return Card
end

-- Tab:CreateParagraph(config?) — { Title?, Text } multi-line, auto-wrapping
-- body text. Unlike CreateLabel (single line, fixed height), this element's
-- height grows with content via AutomaticSize.
function TM:CreateParagraph(config)
	config = config or {}
	local touch = self._touch

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 40 or 30),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Paragraph")

	if config.Title then
		create("TextLabel", {
			Text = config.Title,
			Font = Enum.Font.GothamBold,
			TextSize = touch and 15 or 13,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, touch and 20 or 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}).Parent = holder
	end

	local body = create("TextLabel", {
		Text = config.Text or config.Content or "",
		Font = Enum.Font.Gotham,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 1,
	})
	body.Parent = holder

	return {
		Set = function(_, text) body.Text = text end,
		Get = function() return body.Text end,
	}
end

-- Tab:CreateImage(config?) — { Image | AssetId, Name?, Height?, ScaleType? }.
-- `Image`/`AssetId` accepts a raw numeric id, a bare id string, or a full
-- "rbxassetid://..." string. Optional Name renders as a caption bar along
-- the bottom edge, like a thumbnail card.
function TM:CreateImage(config)
	config = config or {}
	local touch = self._touch

	local function normalizeAsset(id)
		if type(id) == "number" then return "rbxassetid://" .. tostring(id) end
		if type(id) == "string" and id ~= "" and not id:match("^rbxassetid://") and not id:match("^https?://") then
			return "rbxassetid://" .. id
		end
		return id
	end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, config.Height or (touch and 160 or 140)),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Image")

	local img = create("ImageLabel", {
		Image = normalizeAsset(config.Image or config.AssetId or config.Id) or "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ScaleType = config.ScaleType or Enum.ScaleType.Crop,
	})
	img.Parent = holder
	-- Decorative content — SetTheme's reverse color-lookup shouldn't try to
	-- retint an arbitrary picture (same MUI_NoTheme convention used to fix
	-- the floating-button icon disappearing on theme switch).
	img:SetAttribute("MUI_NoTheme", true)

	if config.Name then
		create("TextLabel", {
			Text = config.Name,
			Font = Enum.Font.GothamMedium,
			TextSize = touch and 13 or 11,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 0, touch and 26 or 22),
			Position = UDim2.new(0, 0, 1, touch and -26 or -22),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			create("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
		}).Parent = holder
	end

	return {
		Set = function(_, newAsset) img.Image = normalizeAsset(newAsset) or "" end,
		Get = function() return img.Image end,
	}
end

-- Tab:CreateProgressBar(config?) — { Name?, Min?, Max?, Default?, Flag? }.
-- Animated fill (tweened, and automatically instant under ReducedMotion
-- since it goes through the shared tween() helper) plus a live percentage
-- readout.
function TM:CreateProgressBar(config)
	config = config or {}
	local touch = self._touch
	local min = config.Min or 0
	local max = config.Max or 100
	local value = math.clamp(config.Default or min, min, max)

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 48 or 38),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Progress Bar")

	create("TextLabel", {
		Text = config.Name or "Progress",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, 0, 0, touch and 18 or 14),
		Position = UDim2.new(0, 10, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local percentLabel = create("TextLabel", {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 13 or 11,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.35, -10, 0, touch and 18 or 14),
		Position = UDim2.new(0.65, 0, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	percentLabel.Parent = holder

	local track = create("Frame", {
		Size = UDim2.new(1, -20, 0, touch and 10 or 8),
		Position = UDim2.new(0, 10, 1, touch and -16 or -14),
		BackgroundColor3 = Color3.fromRGB(55, 55, 62),
	}, { corner(8) })
	track.Parent = holder

	local fill = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
	}, { corner(8) })
	fill.Parent = track

	local function render(v, animate)
		v = math.clamp(v, min, max)
		local relative = (max > min) and ((v - min) / (max - min)) or 0
		percentLabel.Text = math.floor(relative * 100 + 0.5) .. "%"
		if animate then
			tween(fill, { Size = UDim2.new(relative, 0, 1, 0) }, 0.25)
		else
			fill.Size = UDim2.new(relative, 0, 1, 0)
		end
		return v
	end
	value = render(value, false)

	local handle = {
		Set = function(_, v)
			value = render(v, true)
			if config.Flag then Library:SetFlag(config.Flag, value) end
		end,
		Get = function() return value end,
	}
	if config.Flag then
		Library:SetFlag(config.Flag, value)
		Library.FlagElements[config.Flag] = handle
	end
	return handle
end

-- ===================== ADVANCED ELEMENTS =====================
-- Unlike the basic elements above, these three read/write shared Library
-- state (Library.Keybinds, Library.NotificationHistory) populated by other
-- parts of the file, so they behave more like live dashboards than
-- standalone inputs.

-- Tab:CreateKeybindList(config?) — displays every keybind registered via
-- Tab:CreateKeybind() across the whole hub (any tab, any plugin), and stays
-- live-updated as bindings are added or rebound.
function TM:CreateKeybindList(config)
	config = config or {}
	local touch = self._touch

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 40 or 30),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		}),
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Keybind List")

	create("TextLabel", {
		Text = config.Name or "Active Keybinds",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 18 or 15),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = holder

	local emptyLabel = create("TextLabel", {
		Text = "No keybinds registered",
		Font = Enum.Font.Gotham,
		TextSize = touch and 13 or 11,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 18 or 15),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})

	local rowFrames = {} -- descriptor -> its row Frame, so unregistering can remove exactly one row
	local rowLabels = {} -- descriptor -> its key-value TextLabel, for live updates

	local function keyText(descriptor)
		local ok, key = pcall(descriptor.Get)
		if not ok or not key or key == Enum.KeyCode.Unknown then return "Unbound" end
		return key.Name
	end

	local function addRow(descriptor)
		if emptyLabel.Parent then emptyLabel.Parent = nil end

		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, touch and 22 or 18),
			BackgroundTransparency = 1,
		})
		row.Parent = holder

		create("TextLabel", {
			Text = descriptor.Name,
			Font = Enum.Font.Gotham,
			TextSize = touch and 13 or 11,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.6, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		local keyLabel = create("TextLabel", {
			Text = keyText(descriptor),
			Font = Enum.Font.GothamBold,
			TextSize = touch and 13 or 11,
			TextColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.4, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		keyLabel.Parent = row

		rowFrames[descriptor] = row
		rowLabels[descriptor] = keyLabel
	end

	local function removeRow(descriptor)
		local row = rowFrames[descriptor]
		if row then row:Destroy() end
		rowFrames[descriptor] = nil
		rowLabels[descriptor] = nil
		if next(rowFrames) == nil then
			emptyLabel.Parent = holder
		end
	end

	local function rebuildAll()
		for descriptor in pairs(rowFrames) do removeRow(descriptor) end
		for _, descriptor in ipairs(Library.Keybinds) do addRow(descriptor) end
		if #Library.Keybinds == 0 then emptyLabel.Parent = holder end
	end

	rebuildAll()

	local registeredConn = Library.KeybindRegistered:Connect(addRow)
	local changedConn = Library.KeybindChanged:Connect(function(descriptor)
		local keyLabel = rowLabels[descriptor]
		if keyLabel then keyLabel.Text = keyText(descriptor) end
	end)
	local unregisteredConn = Library.KeybindUnregistered:Connect(removeRow)

	-- Stop listening once this list is torn down (tab destroyed, hub closed).
	holder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if registeredConn then registeredConn:Disconnect() end
			if changedConn then changedConn:Disconnect() end
			if unregisteredConn then unregisteredConn:Disconnect() end
		end
	end)

	return Library:_wrapElement(holder, { Refresh = function(_) rebuildAll() end })
end

-- Tab:CreateColorGradient(config?) — { Name?, Stops = {Color3, Color3, ...},
-- Flag?, Callback? }. Renders a live gradient preview plus one
-- Tab:CreateColorPicker per stop (reusing that element wholesale rather
-- than re-implementing an HSV wheel), nested inside its own holder so
-- pickers stack visually within the gradient card instead of spilling
-- onto the parent tab/section.
function TM:CreateColorGradient(config)
	config = config or {}
	local touch = self._touch

	local stops = config.Stops or { Color3.fromRGB(255, 196, 48), Color3.fromRGB(255, 90, 90) }
	if #stops < 2 then
		stops = { stops[1] or Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0) }
	end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 40 or 30),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		}),
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Color Gradient")

	create("TextLabel", {
		Text = config.Name or "Gradient",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 20 or 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = holder

	local preview = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 32 or 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 1,
	}, { corner(8), stroke() })
	preview.Parent = holder

	local function buildSequence(colors)
		if #colors < 2 then return ColorSequence.new(colors[1] or Color3.new(1, 1, 1)) end
		local keypoints = {}
		for i, c in ipairs(colors) do
			table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		return ColorSequence.new(keypoints)
	end

	local previewGradient = create("UIGradient", { Color = buildSequence(stops) })
	previewGradient.Parent = preview

	-- Nested page so each stop's ColorPicker parents inside `holder` (this
	-- gradient's own frame) instead of self._page (the tab/section's).
	local GradientPage = setmetatable({
		_page = holder,
		_touch = touch,
		_window = self._window,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	local pickers = {}

	local function currentColors()
		local colors = {}
		for _, picker in ipairs(pickers) do table.insert(colors, picker:Get()) end
		return colors
	end

	for i, startColor in ipairs(stops) do
		local picker = GradientPage:CreateColorPicker({
			Name = "Stop " .. i,
			Default = startColor,
			Callback = function()
				local colors = currentColors()
				previewGradient.Color = buildSequence(colors)
				if config.Flag then Library:SetFlag(config.Flag, colors) end
				if config.Callback then
					local ok, err = pcall(config.Callback, buildSequence(colors), colors)
					if not ok then warn("[MobileUILib] ColorGradient callback error: " .. tostring(err)) end
				end
			end,
		})
		table.insert(pickers, picker)
	end

	local handle = {
		Set = function(_, newStops)
			for i, picker in ipairs(pickers) do
				if newStops[i] then picker:Set(newStops[i]) end
			end
			local colors = currentColors()
			previewGradient.Color = buildSequence(colors)
			if config.Flag then Library:SetFlag(config.Flag, colors) end
		end,
		Get = function() return currentColors() end,
		GetSequence = function() return buildSequence(currentColors()) end,
	}
	if config.Flag then
		Library:SetFlag(config.Flag, currentColors())
		Library.FlagElements[config.Flag] = handle
	end
	return handle
end

-- Tab:CreateNotificationCenter(config?) — { Name? }. Lists every
-- notification logged via Window:Notify / ctx:Notify (newest first, capped
-- at Library.MAX_NOTIFICATION_HISTORY), with a Clear button. Updates live
-- as new notifications come in, even ones fired from a different tab.
function TM:CreateNotificationCenter(config)
	config = config or {}
	local touch = self._touch

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 46 or 34),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Notification Center")

	local headerRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 34 or 28),
		BackgroundTransparency = 1,
	})
	headerRow.Parent = holder

	create("TextLabel", {
		Text = config.Name or "Notifications",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 14 or 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = headerRow

	local clearBtn = create("TextButton", {
		Text = "Clear",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and 12 or 11,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 56, 1, 0),
		Position = UDim2.new(1, -60, 0, 0),
	})
	clearBtn.Parent = headerRow

	local list = create("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.new(0, 8, 0, touch and 36 or 30),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingBottom = UDim.new(0, 8) }),
	})
	list.Parent = holder

	local typeColors = {
		success = Color3.fromRGB(70, 200, 110),
		error = Color3.fromRGB(230, 75, 75),
		warning = Color3.fromRGB(255, 175, 45),
		info = Theme.Accent,
	}

	local emptyLabel = create("TextLabel", {
		Text = "No notifications yet",
		Font = Enum.Font.Gotham,
		TextSize = touch and 13 or 11,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local rowHeight = touch and 54 or 44

	local function addRow(entry)
		if emptyLabel.Parent then emptyLabel.Parent = nil end

		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, rowHeight),
			BackgroundColor3 = Theme.ElementHover,
			-- Negative so higher Seq (more recent) sorts first under
			-- SortOrder.LayoutOrder's ascending order.
			LayoutOrder = -entry.Seq,
		}, {
			corner(8),
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
			}),
		})
		row.Parent = list

		create("Frame", {
			Size = UDim2.new(0, 3, 1, 0),
			Position = UDim2.new(0, -8, 0, 0),
			BackgroundColor3 = typeColors[entry.Type] or Theme.Stroke,
			BorderSizePixel = 0,
		}, { corner(2) }).Parent = row

		create("TextLabel", {
			Text = entry.Title,
			Font = Enum.Font.GothamMedium,
			TextSize = touch and 13 or 11,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -56, 0, touch and 16 or 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent = row

		create("TextLabel", {
			Text = entry.Content,
			Font = Enum.Font.Gotham,
			TextSize = touch and 12 or 10,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, touch and 18 or 15),
			Size = UDim2.new(1, 0, 0, touch and 16 or 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent = row

		create("TextLabel", {
			Text = os.date("%H:%M:%S", entry.Time),
			Font = Enum.Font.Gotham,
			TextSize = touch and 10 or 9,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 54, 0, 12),
			Position = UDim2.new(1, -54, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}).Parent = row
	end

	for _, entry in ipairs(Library.NotificationHistory) do
		addRow(entry)
	end
	if #Library.NotificationHistory == 0 then
		emptyLabel.Parent = list
	end

	local logConn = Library.NotificationLogged:Connect(addRow)

	clearBtn.MouseButton1Click:Connect(function()
		Library.NotificationHistory = {}
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		emptyLabel.Parent = list
	end)

	holder.AncestryChanged:Connect(function(_, parent)
		if not parent and logConn then logConn:Disconnect() end
	end)

	return holder
end

-- ===================== PLUGIN SYSTEM =====================
-- Plugins are separate Lua files hosted externally (GitHub raw, Pastefy,
-- etc.) that extend the hub without touching this file. Load them with:
--
--   local Corn = loadstring(game:HttpGet("https://.../CornUi.lua"))()
--   local Window = Corn:CreateWindow({ Name = "My Hub" })
--
--   local Plugins = {
--       "https://raw.githubusercontent.com/you/plugins/main/AdminCommands.lua",
--       "https://raw.githubusercontent.com/you/plugins/main/VideoBackground.lua",
--   }
--   Corn:LoadPlugins(Plugins, Window)
--
-- A plugin file just returns a table:
--
--   return {
--       Name = "Admin Commands",   -- optional, used for Library.Plugins[] + warn() messages
--       Version = "1.0.0",         -- optional, informational only
--       Init = function(ctx)       -- called once, right after the plugin loads
--           ctx:RegisterCommand("speed", function(window, argString)
--               -- ...
--           end)
--       end,
--       Unload = function(ctx)     -- optional — called on Disable/Reload/Unload
--           -- disconnect RunService connections, turn off effects this
--           -- plugin turned on, etc. See the Plugin Manager section below
--           -- for what Unload can and can't clean up.
--       end,
--   }
--
-- `ctx` (the "plugin context") is the only thing a plugin should touch — a
-- small, stable surface over Library/Window internals so plugins don't
-- reach into private fields that might change between versions of this file:
--
--   ctx.Library                                  -- the Library table, for advanced use
--   ctx.Window                                    -- the Window this plugin was loaded against (may be nil)
--   ctx.Player                                     -- Players.LocalPlayer
--   ctx:GetFlag(name) / ctx:SetFlag(name, value)   -- Flag Manager (see top of file)
--   ctx.FlagChanged                                -- Library.FlagChanged event
--   ctx:RegisterTheme(name, themeTable)             -- Custom Themes
--   ctx:RegisterCommand(keyword, fn)                -- Command Palette, needs a window
--   ctx:SetBackground(sourceOrConfig) / ctx:ClearBackground() -- Image/Video background FX, needs a window
--   ctx:CreateTab(name, tabConfig)                  -- adds a tab to the hub, needs a window
--   ctx:Notify(notifConfig)                          -- fires a notification, needs a window
--
-- Every plugin call (loading, Init, and anything routed through ctx) is
-- wrapped in pcall, so one broken or malicious plugin can't take down the
-- hub or the other plugins loaded alongside it.

Library.Plugins = {} -- name (or url, if unnamed) -> the table the plugin returned

-- Richer per-plugin bookkeeping for the Plugin Manager (below), kept
-- separate from Library.Plugins above so that existing/simple usage
-- (`Library.Plugins[name]` = the plugin's own returned table) doesn't
-- change shape. Library.PluginRegistry is an ordered array of records:
--   { Name, Url, Version, Enabled, Result, Context, Window }
Library.PluginRegistry = {}
local pluginRegistryChangedEvent = Instance.new("BindableEvent")
Library.PluginRegistryChanged = pluginRegistryChangedEvent.Event -- fires () on any load/enable/disable/reload/unload

local function findPluginRecord(name)
	for _, record in ipairs(Library.PluginRegistry) do
		if record.Name == name then return record end
	end
	return nil
end

function Library:_makePluginContext(window)
	local self_ = self
	return {
		Library = self_,
		Window = window,
		Player = LocalPlayer,

		GetFlag = function(_, name) return self_:GetFlag(name) end,
		SetFlag = function(_, name, value) self_:SetFlag(name, value) end,
		FlagChanged = self_.FlagChanged,

		SaveConfig = function(_, name) return self_:SaveConfig(name) end,
		LoadConfig = function(_, name) return self_:LoadConfig(name, window) end,
		ListConfigs = function(_) return self_:ListConfigs() end,
		DeleteConfig = function(_, name) return self_:DeleteConfig(name) end,

		ListPlugins = function(_) return self_:ListPlugins() end,
		DisablePlugin = function(_, name) return self_:DisablePlugin(name) end,
		EnablePlugin = function(_, name) return self_:EnablePlugin(name) end,
		ReloadPlugin = function(_, name) return self_:ReloadPlugin(name) end,
		UnloadPlugin = function(_, name) return self_:UnloadPlugin(name) end,

		RegisterTheme = function(_, name, themeTable)
			self_:RegisterTheme(name, themeTable)
		end,

		RegisterCommand = function(_, keyword, fn)
			if not window then
				warn("[MobileUILib] RegisterCommand needs a Window — pass one to LoadPlugin/LoadPlugins")
				return
			end
			window:RegisterCommand(keyword, fn)
		end,

		SetBackground = function(_, config)
			if not window then
				warn("[MobileUILib] SetBackground needs a Window — pass one to LoadPlugin/LoadPlugins")
				return
			end
			return window:SetBackground(config)
		end,
		ClearBackground = function(_)
			if window then window:ClearBackground() end
		end,

		CreateTab = function(_, name, tabConfig)
			if not window then return nil end
			return window:CreateTab(name, tabConfig)
		end,

		Notify = function(_, notifConfig)
			if window then window:Notify(notifConfig) end
		end,
	}
end

-- Library:LoadPlugin(url, window) — fetches, compiles, and runs a single
-- plugin file, returning whatever table it returned (or nil on failure).
-- `window` is optional; pass one so the plugin can use RegisterCommand,
-- SetBackground, CreateTab, and Notify. Plugins that only need Flags/Themes
-- work fine without one.
function Library:LoadPlugin(url, window)
	local fetchOk, source = pcall(game.HttpGet, game, url)
	if not fetchOk then
		warn("[MobileUILib] Plugin fetch failed (" .. tostring(url) .. "): " .. tostring(source))
		return nil
	end

	local chunk, compileErr = loadstring(source)
	if not chunk then
		warn("[MobileUILib] Plugin failed to compile (" .. tostring(url) .. "): " .. tostring(compileErr))
		return nil
	end

	local context = self:_makePluginContext(window)
	local runOk, result = pcall(chunk, context)
	if not runOk then
		warn("[MobileUILib] Plugin errored while loading (" .. tostring(url) .. "): " .. tostring(result))
		return nil
	end

	if type(result) == "table" then
		local name = result.Name or url
		self.Plugins[name] = result

		local record = findPluginRecord(name)
		if not record then
			record = { Name = name }
			table.insert(self.PluginRegistry, record)
		end
		record.Url = url
		record.Version = result.Version
		record.Result = result
		record.Context = context
		record.Window = window
		record.Enabled = true

		if type(result.Init) == "function" then
			local initOk, initErr = pcall(result.Init, context)
			if not initOk then
				warn("[MobileUILib] Plugin Init error (" .. tostring(name) .. "): " .. tostring(initErr))
			end
		end

		pluginRegistryChangedEvent:Fire()
	end

	return result
end

-- Library:LoadPlugins({ url1, url2, ... }, window) — convenience wrapper
-- that loads a whole list in order, e.g.:
--   local Plugins = { "https://.../AdminCommands.lua" }
--   Corn:LoadPlugins(Plugins, Window)
function Library:LoadPlugins(urls, window)
	local loaded = {}
	for _, url in ipairs(urls or {}) do
		loaded[#loaded + 1] = self:LoadPlugin(url, window)
	end
	return loaded
end

-- ===================== PLUGIN MANAGER =====================
-- Enable/Disable/Reload/Unload built on top of LoadPlugin above. An
-- HONEST LIMITATION, not swept under the rug: CornUi.lua currently has no
-- element-teardown API (no Tab:Destroy(), etc. — that's a separate,
-- not-yet-built roadmap item). That means none of the functions below can
-- remove UI a plugin already created (tabs, toggles, ...). What they CAN
-- do reliably:
--   - stop a plugin's *behavior* going forward, if the plugin cooperates
--     by implementing an optional `Unload = function(ctx) ... end` in its
--     returned table (disconnect RunService connections, turn off noclip/
--     fly, etc.) — same shape as `Init`, called on Disable/Reload/Unload.
--   - track what's loaded, its version/url, and whether it's "enabled"
--     for a Plugin Manager UI to display and toggle.
--   - re-run Init on Enable/Reload, which is safe for plugins that don't
--     duplicate UI on repeat Init calls, and will visibly duplicate tabs/
--     elements for plugins that do. This is a real gap, not a bug in the
--     Manager — write Init idempotently (check ctx.Window for an existing
--     tab by name before creating a new one) if you plan to reload often.

-- Library:ListPlugins() — snapshot of every loaded plugin for a Plugin
-- Manager UI: { Name, Version, Url, Enabled }[]
function Library:ListPlugins()
	local list = {}
	for _, record in ipairs(self.PluginRegistry) do
		table.insert(list, {
			Name = record.Name,
			Version = record.Version,
			Url = record.Url,
			Enabled = record.Enabled,
		})
	end
	return list
end

-- Library:DisablePlugin(name) — calls the plugin's Unload(ctx) if it has
-- one, then marks it disabled. Returns true/false. See the limitation note
-- above: this does not remove UI the plugin already created.
function Library:DisablePlugin(name)
	local record = findPluginRecord(name)
	if not record or not record.Enabled then return false end

	if record.Result and type(record.Result.Unload) == "function" then
		local ok, err = pcall(record.Result.Unload, record.Context)
		if not ok then
			warn("[MobileUILib] Plugin Unload error (" .. tostring(name) .. "): " .. tostring(err))
		end
	end

	record.Enabled = false
	pluginRegistryChangedEvent:Fire()
	return true
end

-- Library:EnablePlugin(name) — re-runs Init(ctx) for a previously-disabled
-- plugin. See the Init-duplication caveat above.
function Library:EnablePlugin(name)
	local record = findPluginRecord(name)
	if not record or record.Enabled then return false end

	if record.Result and type(record.Result.Init) == "function" then
		local ok, err = pcall(record.Result.Init, record.Context)
		if not ok then
			warn("[MobileUILib] Plugin Init error on re-enable (" .. tostring(name) .. "): " .. tostring(err))
		end
	end

	record.Enabled = true
	pluginRegistryChangedEvent:Fire()
	return true
end

-- Library:ReloadPlugin(name) — Unload (if present) + re-fetch the plugin's
-- source from its original Url + re-run it fresh, replacing the old
-- Result/Context in place. Only works for plugins loaded via LoadPlugin/
-- LoadPlugins (i.e. anything with a known Url). Returns true/false.
function Library:ReloadPlugin(name)
	local record = findPluginRecord(name)
	if not record or not record.Url then return false end

	if record.Result and type(record.Result.Unload) == "function" then
		pcall(record.Result.Unload, record.Context)
	end

	local fetchOk, source = pcall(game.HttpGet, game, record.Url)
	if not fetchOk then
		warn("[MobileUILib] Plugin reload fetch failed (" .. tostring(name) .. "): " .. tostring(source))
		return false
	end

	local chunk, compileErr = loadstring(source)
	if not chunk then
		warn("[MobileUILib] Plugin reload compile failed (" .. tostring(name) .. "): " .. tostring(compileErr))
		return false
	end

	local context = self:_makePluginContext(record.Window)
	local runOk, result = pcall(chunk, context)
	if not runOk then
		warn("[MobileUILib] Plugin reload run error (" .. tostring(name) .. "): " .. tostring(result))
		return false
	end

	if type(result) == "table" then
		self.Plugins[name] = result
		record.Result = result
		record.Context = context
		record.Version = result.Version
		record.Enabled = true

		if type(result.Init) == "function" then
			local initOk, initErr = pcall(result.Init, context)
			if not initOk then
				warn("[MobileUILib] Plugin Init error on reload (" .. tostring(name) .. "): " .. tostring(initErr))
			end
		end
	end

	pluginRegistryChangedEvent:Fire()
	return true
end

-- Library:UnloadPlugin(name) — Unload (if present) + removes it from the
-- registry and Library.Plugins entirely. Same UI-teardown caveat applies.
function Library:UnloadPlugin(name)
	local record = findPluginRecord(name)
	if not record then return false end

	if record.Result and type(record.Result.Unload) == "function" then
		local ok, err = pcall(record.Result.Unload, record.Context)
		if not ok then
			warn("[MobileUILib] Plugin Unload error (" .. tostring(name) .. "): " .. tostring(err))
		end
	end

	self.Plugins[name] = nil
	for i, r in ipairs(self.PluginRegistry) do
		if r.Name == name then
			table.remove(self.PluginRegistry, i)
			break
		end
	end

	pluginRegistryChangedEvent:Fire()
	return true
end

-- Tab:CreatePluginManager(config?) — lists every loaded plugin (name,
-- version, enabled state) with Enable/Disable, Reload, and Unload buttons,
-- live-updated via Library.PluginRegistryChanged. See the caveat above the
-- Library:Disable/Enable/Reload/UnloadPlugin functions: none of these
-- remove UI a plugin already created — there's no element-teardown API
-- yet. Reload is hidden for any plugin without a known Url (i.e. anything
-- not loaded through LoadPlugin/LoadPlugins).
function TM:CreatePluginManager(config)
	config = config or {}
	local touch = self._touch

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 46 or 34),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Plugin Manager")

	create("TextLabel", {
		Text = config.Name or "Plugins",
		Font = Enum.Font.GothamBold,
		TextSize = touch and 15 or 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, touch and 30 or 24),
		Position = UDim2.new(0, 10, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local list = create("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.new(0, 8, 0, touch and 40 or 32),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingBottom = UDim.new(0, 8) }),
	})
	list.Parent = holder

	local emptyLabel = create("TextLabel", {
		Text = "No plugins loaded",
		Font = Enum.Font.Gotham,
		TextSize = touch and 13 or 11,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local rowHeight = touch and 62 or 50

	local function smallBtn(parent, text, order)
		local b = create("TextButton", {
			Text = text,
			Font = Enum.Font.GothamMedium,
			TextSize = touch and 12 or 10,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.Element,
			Size = UDim2.new(0, touch and 70 or 58, 1, 0),
			LayoutOrder = order,
		}, { corner(6) })
		b.Parent = parent
		return b
	end

	-- Full rebuild on every registry change rather than diffing — plugin
	-- counts are small (single digits to low dozens), so this stays cheap
	-- and avoids a whole class of stale-row bugs.
	local function rebuild()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		local plugins = Library:ListPlugins()
		if #plugins == 0 then
			emptyLabel.Parent = list
			return
		end
		emptyLabel.Parent = nil

		for i, info in ipairs(plugins) do
			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, rowHeight),
				BackgroundColor3 = Theme.ElementHover,
				LayoutOrder = i,
			}, {
				corner(8),
				create("UIPadding", {
					PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
				}),
			})
			row.Parent = list

			create("TextLabel", {
				Text = info.Name .. (info.Version and ("  v" .. tostring(info.Version)) or ""),
				Font = Enum.Font.GothamMedium,
				TextSize = touch and 13 or 11,
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, touch and 16 or 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}).Parent = row

			create("TextLabel", {
				Text = info.Enabled and "Enabled" or "Disabled",
				Font = Enum.Font.Gotham,
				TextSize = touch and 11 or 10,
				TextColor3 = info.Enabled and Color3.fromRGB(70, 200, 110) or Color3.fromRGB(230, 75, 75),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, touch and 18 or 15),
				Size = UDim2.new(1, -8, 0, touch and 14 or 12),
				TextXAlignment = Enum.TextXAlignment.Left,
			}).Parent = row

			local btnRow = create("Frame", {
				Size = UDim2.new(1, 0, 0, touch and 26 or 20),
				Position = UDim2.new(0, 0, 1, touch and -26 or -20),
				BackgroundTransparency = 1,
			}, {
				create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			btnRow.Parent = row

			local toggleBtn = smallBtn(btnRow, info.Enabled and "Disable" or "Enable", 1)
			toggleBtn.MouseButton1Click:Connect(function()
				if info.Enabled then
					Library:DisablePlugin(info.Name)
				else
					Library:EnablePlugin(info.Name)
				end
			end)

			if info.Url then
				local reloadBtn = smallBtn(btnRow, "Reload", 2)
				reloadBtn.MouseButton1Click:Connect(function()
					Library:ReloadPlugin(info.Name)
				end)
			end

			local unloadBtn = smallBtn(btnRow, "Unload", 3)
			unloadBtn.MouseButton1Click:Connect(function()
				Library:UnloadPlugin(info.Name)
			end)
		end
	end

	rebuild()
	local conn = Library.PluginRegistryChanged:Connect(rebuild)

	holder.AncestryChanged:Connect(function(_, parent)
		if not parent and conn then conn:Disconnect() end
	end)

	return holder
end

--[[
	EXAMPLE PLUGIN — Admin Commands
	(reference only — this is what a plugin FILE would contain; it isn't run
	by this library on its own. Save it separately, host it, and load it via
	Corn:LoadPlugins({ "https://.../AdminCommands.lua" }, Window).)

	Demonstrates turning the title-bar command palette into a small admin
	panel using RegisterCommand's argument support: typing "speed 50" calls
	the "speed" command with argString "50".

	return {
		Name = "Admin Commands",
		Version = "1.0.0",
		Init = function(ctx)
			local player = ctx.Player

			local function getHumanoid()
				local char = player.Character
				return char and char:FindFirstChildOfClass("Humanoid")
			end

			ctx:RegisterCommand("speed", function(window, argString)
				local n = math.clamp(tonumber(argString) or 16, 1, 100)
				local hum = getHumanoid()
				if hum then hum.WalkSpeed = n end
				window:Notify({ Title = "Speed", Content = "Set to " .. n, Type = "success" })
			end)

			ctx:RegisterCommand("jp", function(window, argString)
				local n = math.clamp(tonumber(argString) or 50, 1, 100)
				local hum = getHumanoid()
				if hum then hum.JumpPower = n end
				window:Notify({ Title = "Jump Power", Content = "Set to " .. n, Type = "success" })
			end)

			ctx:RegisterCommand("fly", function(window, argString)
				-- Left intentionally simple: this just flips a flag other
				-- code (e.g. a RenderStepped connection elsewhere in the
				-- plugin) can read via ctx:GetFlag("Fly"). Wire up the actual
				-- BodyVelocity/AlignPosition movement to taste.
				local on = argString:lower() ~= "off"
				ctx:SetFlag("Fly", on)
				window:Notify({ Title = "Fly", Content = on and "Enabled" or "Disabled", Type = "info" })
			end)

			ctx:RegisterCommand("reset-char", function(window)
				local hum = getHumanoid()
				if hum then hum.Health = 0 end
				window:Notify({ Title = "Character", Content = "Reset", Type = "warning" })
			end)
		end,
	}
]]

--[[
	EXAMPLE PLUGIN — Video Background
	(reference only, same deal as above)

	return {
		Name = "Video Background",
		Init = function(ctx)
			ctx:SetBackground({
				Type = "Video",
				Texture = "rbxassetid://0000000000", -- your video's content id
				Volume = 0,
			})
		end,
	}
]]

return Library
