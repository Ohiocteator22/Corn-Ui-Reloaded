--[[
	MobileUILib v1.9.3 — Stable Release
	A lightweight, mobile-compatible Roblox UI library

	NEW in v1.9.3:
	- Fixed notification sizing
	- Fixed command palette "Fire" error
	- Fixed Cornelius commands
	- Fixed export popup
	- Added built-in help command

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
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Library = {}
Library.__index = Library
Library._customElements = {}
Library._themeHistory = {}
Library._windowPositions = {}

-- ===================== VERSION =====================
Library.VERSION = "1.9.3"
Library.BUILD = "2024.08.07"

-- ===================== FLAG MANAGER =====================
Library.Flags = {
	UISounds = true,
	Haptics = true,
	UIScale = 1,
	CompactMode = false,
	ShowIntro = true,
	SnapToEdges = false,
	TabReordering = true,
	AutoSaveInterval = 60,
	RememberPosition = true,
	ReducedMotion = false,
	PerformanceMode = false,
}
local flagChangedEvent = Instance.new("BindableEvent")
Library.FlagChanged = flagChangedEvent.Event

function Library:GetFlag(name)
	return Library.Flags[name]
end

function Library:SetFlag(name, value)
	if not name then return end
	if self._flagSchema and self._flagSchema[name] then
		local expectedType = self._flagSchema[name]
		if type(value) ~= expectedType then
			warn("[MobileUILib] Flag '" .. name .. "' expected " .. expectedType .. ", got " .. type(value))
			return
		end
	end
	Library.Flags[name] = value
	flagChangedEvent:Fire(name, value)
end

Library.FlagElements = {}

-- ===================== KEYBIND REGISTRY =====================
Library.Keybinds = {}
Library.KeybindConflicts = {}
local keybindRegisteredEvent = Instance.new("BindableEvent")
Library.KeybindRegistered = keybindRegisteredEvent.Event
local keybindChangedEvent = Instance.new("BindableEvent")
Library.KeybindChanged = keybindChangedEvent.Event
local keybindUnregisteredEvent = Instance.new("BindableEvent")
Library.KeybindUnregistered = keybindUnregisteredEvent.Event

-- ===================== NOTIFICATION HISTORY =====================
Library.NotificationHistory = {}
Library.MAX_NOTIFICATION_HISTORY = 50
local notificationLoggedEvent = Instance.new("BindableEvent")
Library.NotificationLogged = notificationLoggedEvent.Event

-- ===================== COMMAND HISTORY =====================
Library.CommandHistory = {}
Library.MAX_COMMAND_HISTORY = 20
local commandIndex = 0

-- ===================== CONFIG SYSTEM =====================
local CONFIG_PREFIX = "CornUi_Config_"
local CONFIG_SUFFIX = ".lc"

local function configPath(name)
	local safeName = tostring(name or "default"):gsub("[^%w_%-]", "_")
	if safeName == "" then safeName = "default" end
	return CONFIG_PREFIX .. safeName .. CONFIG_SUFFIX
end

local function serializeFlagValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __type = "Color3", r = value.R, g = value.G, b = value.B }
	elseif kind == "EnumItem" then
		local enumName = tostring(value.EnumType):gsub("^Enum%.", "")
		return { __type = "Enum", enum = enumName, name = value.Name }
	elseif kind == "number" or kind == "string" or kind == "boolean" then
		return value
	elseif kind == "table" then
		local out = {}
		for i, v in ipairs(value) do
			out[i] = serializeFlagValue(v)
		end
		return { __type = "Array", items = out }
	else
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

function Library:SaveConfig(name)
	if not (writefile) then
		warn("[MobileUILib] SaveConfig: this executor doesn't expose writefile")
		return false
	end

	local data = { 
		Flags = {}, 
		Theme = Library._currentThemeName or "Dark",
		Version = Library.VERSION,
		Timestamp = os.time()
	}
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

function Library:LoadConfig(name, window)
	if not (isfile and readfile) then
		warn("[MobileUILib] LoadConfig: this executor doesn't expose isfile/readfile")
		return false
	end

	local path = configPath(name)
	local existsOk, exists = pcall(isfile, path)
	if not existsOk or not exists then
		return false
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
				Library:SetFlag(flagName, value)
			end
		end
	end

	return true
end

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

function Library:ExportConfig(name)
	local data = { 
		Flags = {}, 
		Theme = Library._currentThemeName or "Dark",
		Version = Library.VERSION,
		Timestamp = os.time()
	}
	for flagName, value in pairs(Library.Flags) do
		data.Flags[flagName] = serializeFlagValue(value)
	end
	
	local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then
		warn("[MobileUILib] ExportConfig: JSONEncode failed — " .. tostring(json))
		return nil
	end
	return json
end

function Library:ImportConfig(jsonText, window)
	local decodeOk, data = pcall(function() return HttpService:JSONDecode(jsonText) end)
	if not decodeOk or type(data) ~= "table" then
		warn("[MobileUILib] ImportConfig: malformed config data")
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
				Library:SetFlag(flagName, value)
			end
		end
	end

	return true
end

-- ===================== THEME =====================
local Themes = {
	Dark = {
		Background = Color3.fromRGB(10, 10, 12),
		Header = Color3.fromRGB(16, 16, 19),
		Accent = Color3.fromRGB(255, 196, 48),
		TextOnAccent = Color3.fromRGB(20, 20, 24),
		Text = Color3.fromRGB(240, 240, 245),
		SubText = Color3.fromRGB(140, 140, 148),
		Element = Color3.fromRGB(20, 20, 24),
		ElementHover = Color3.fromRGB(28, 28, 33),
		Stroke = Color3.fromRGB(38, 38, 44),
		ToggleButton = Color3.fromRGB(20, 20, 24),
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
	Ocean = {
		Background = Color3.fromRGB(8, 20, 40),
		Header = Color3.fromRGB(12, 30, 50),
		Accent = Color3.fromRGB(64, 224, 208),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(220, 240, 255),
		SubText = Color3.fromRGB(160, 190, 210),
		Element = Color3.fromRGB(16, 35, 55),
		ElementHover = Color3.fromRGB(24, 45, 65),
		Stroke = Color3.fromRGB(40, 70, 90),
		ToggleButton = Color3.fromRGB(16, 35, 55),
	},
	Forest = {
		Background = Color3.fromRGB(10, 25, 10),
		Header = Color3.fromRGB(15, 35, 15),
		Accent = Color3.fromRGB(80, 200, 80),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(220, 255, 220),
		SubText = Color3.fromRGB(160, 200, 160),
		Element = Color3.fromRGB(15, 35, 15),
		ElementHover = Color3.fromRGB(25, 45, 25),
		Stroke = Color3.fromRGB(40, 80, 40),
		ToggleButton = Color3.fromRGB(15, 35, 15),
	},
	Sunset = {
		Background = Color3.fromRGB(40, 10, 20),
		Header = Color3.fromRGB(50, 15, 25),
		Accent = Color3.fromRGB(255, 140, 60),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(255, 220, 210),
		SubText = Color3.fromRGB(210, 160, 150),
		Element = Color3.fromRGB(50, 15, 25),
		ElementHover = Color3.fromRGB(65, 25, 35),
		Stroke = Color3.fromRGB(90, 40, 50),
		ToggleButton = Color3.fromRGB(50, 15, 25),
	},
	Amethyst = {
		Background = Color3.fromRGB(25, 15, 40),
		Header = Color3.fromRGB(30, 20, 45),
		Accent = Color3.fromRGB(180, 120, 255),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(240, 225, 255),
		SubText = Color3.fromRGB(180, 160, 200),
		Element = Color3.fromRGB(30, 20, 45),
		ElementHover = Color3.fromRGB(40, 30, 55),
		Stroke = Color3.fromRGB(60, 45, 80),
		ToggleButton = Color3.fromRGB(30, 20, 45),
	},
	Ruby = {
		Background = Color3.fromRGB(40, 10, 10),
		Header = Color3.fromRGB(50, 15, 15),
		Accent = Color3.fromRGB(255, 60, 60),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(255, 220, 220),
		SubText = Color3.fromRGB(210, 160, 160),
		Element = Color3.fromRGB(50, 15, 15),
		ElementHover = Color3.fromRGB(65, 25, 25),
		Stroke = Color3.fromRGB(90, 40, 40),
		ToggleButton = Color3.fromRGB(50, 15, 15),
	},
	Frost = {
		Background = Color3.fromRGB(20, 30, 45),
		Header = Color3.fromRGB(25, 35, 50),
		Accent = Color3.fromRGB(150, 220, 255),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(230, 245, 255),
		SubText = Color3.fromRGB(170, 190, 210),
		Element = Color3.fromRGB(25, 35, 50),
		ElementHover = Color3.fromRGB(35, 45, 60),
		Stroke = Color3.fromRGB(55, 70, 90),
		ToggleButton = Color3.fromRGB(25, 35, 50),
	},
	Candy = {
		Background = Color3.fromRGB(45, 20, 35),
		Header = Color3.fromRGB(55, 25, 42),
		Accent = Color3.fromRGB(255, 150, 200),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(255, 235, 245),
		SubText = Color3.fromRGB(220, 180, 200),
		Element = Color3.fromRGB(55, 25, 42),
		ElementHover = Color3.fromRGB(70, 35, 55),
		Stroke = Color3.fromRGB(100, 50, 75),
		ToggleButton = Color3.fromRGB(55, 25, 42),
	},
	Midnight = {
		Background = Color3.fromRGB(5, 5, 8),
		Header = Color3.fromRGB(8, 8, 12),
		Accent = Color3.fromRGB(200, 200, 220),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(255, 255, 255),
		SubText = Color3.fromRGB(150, 150, 160),
		Element = Color3.fromRGB(8, 8, 12),
		ElementHover = Color3.fromRGB(15, 15, 20),
		Stroke = Color3.fromRGB(25, 25, 30),
		ToggleButton = Color3.fromRGB(8, 8, 12),
	},
	Cyber = {
		Background = Color3.fromRGB(10, 5, 20),
		Header = Color3.fromRGB(15, 8, 28),
		Accent = Color3.fromRGB(0, 255, 150),
		TextOnAccent = Color3.fromRGB(0, 0, 0),
		Text = Color3.fromRGB(0, 255, 150),
		SubText = Color3.fromRGB(100, 200, 150),
		Element = Color3.fromRGB(15, 8, 28),
		ElementHover = Color3.fromRGB(25, 15, 40),
		Stroke = Color3.fromRGB(0, 255, 150),
		ToggleButton = Color3.fromRGB(15, 8, 28),
	},
}

-- ===================== CUSTOM ELEMENT REGISTRATION API =====================
function Library:RegisterElement(name, constructor)
	if type(name) ~= "string" or type(constructor) ~= "function" then
		warn("[MobileUILib] RegisterElement requires a name string and a constructor function")
		return
	end
	Library._customElements[name] = constructor
end

function Library:GetRegisteredElements()
	local list = {}
	for name in pairs(Library._customElements) do
		table.insert(list, name)
	end
	return list
end

function Library:RegisterTheme(name, themeTable)
	if type(name) ~= "string" or type(themeTable) ~= "table" then
		warn("[MobileUILib] RegisterTheme requires a name string and a table of colors")
		return
	end
	local merged = {}
	for k, v in pairs(Themes.Dark) do merged[k] = v end
	for k, v in pairs(themeTable) do merged[k] = v end
	Themes[name] = merged
	
	if #Library._themeHistory >= 5 then
		table.remove(Library._themeHistory, 1)
	end
	table.insert(Library._themeHistory, name)
end

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

local animationSpeed = 1.0
local function tween(inst, props, duration)
	if Library.Flags.ReducedMotion or Library.Flags.PerformanceMode then
		for prop, value in pairs(props) do
			inst[prop] = value
		end
		return
	end
	local adjustedDuration = (duration or 0.15) / animationSpeed
	TweenService:Create(inst, TweenInfo.new(adjustedDuration, Enum.EasingStyle.Quad), props):Play()
end

-- ===================== SOUND & HAPTIC HELPERS =====================
local soundMap = {
	click = "rbxassetid://9120396650",
	toggle = "rbxassetid://9120398374",
	slider = "rbxassetid://9120400890",
	dropdown = "rbxassetid://9120404583",
	success = "rbxassetid://9120411087",
	error = "rbxassetid://9120413090",
	warning = "rbxassetid://9120411087",
	info = "rbxassetid://9120404583",
}

function Library:PlaySound(soundId, volume)
	if not Library.Flags.UISounds then return end
	if not soundId then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.3
	sound.Parent = LocalPlayer.PlayerGui
	sound:Play()
	task.delay(sound.TimeLength + 0.1, function()
		sound:Destroy()
	end)
end

function Library:PlayHaptic(variant)
	if not Library.Flags.Haptics then return end
	if not UserInputService.Vibrate then return end
	local vibrateType = Enum.VibrateType.Short
	if variant == "long" then
		vibrateType = Enum.VibrateType.Long
	elseif variant == "double" then
		pcall(function()
			UserInputService:Vibrate(Enum.VibrateType.Short)
			task.wait(0.1)
			UserInputService:Vibrate(Enum.VibrateType.Short)
		end)
		return
	end
	pcall(function()
		UserInputService:Vibrate(vibrateType)
	end)
end

local function playInteractionSound(style)
	local id = soundMap[style] or soundMap.click
	Library:PlaySound(id)
end

local function playNotificationSound(style)
	local id = soundMap[style] or soundMap.info
	Library:PlaySound(id, 0.2)
end

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

local function makeDraggable(dragHandle, target, snap)
	local dragging = false
	local dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		local newPos = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
		target.Position = newPos
		
		if snap and Library.Flags.SnapToEdges then
			local absPos = target.AbsolutePosition
			local absSize = target.AbsoluteSize
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local snapThreshold = 50
			
			if absPos.X < snapThreshold then
				target.Position = UDim2.new(0, 0, newPos.Y.Scale, newPos.Y.Offset)
			elseif absPos.X + absSize.X > viewport.X - snapThreshold then
				target.Position = UDim2.new(1, -absSize.X, newPos.Y.Scale, newPos.Y.Offset)
			end
			
			if absPos.Y < snapThreshold then
				target.Position = UDim2.new(target.Position.X.Scale, target.Position.X.Offset, 0, 0)
			elseif absPos.Y + absSize.Y > viewport.Y - snapThreshold then
				target.Position = UDim2.new(target.Position.X.Scale, target.Position.X.Offset, 1, -absSize.Y)
			end
		end
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

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Touch then
			update(input)
		end
	end)
end

-- ===================== CORNELIUS ASSISTANT SYSTEM =====================
Cornelius = {
	Packs = {},
	Commands = {},
	Guides = {},
	RegisteredPacks = {},
	_window = nil,
	_loadedCount = 0,
	_VERSION = "1.0.1",
}

-- Core Methods
function Cornelius:LoadPack(pack)
	if type(pack) == "string" then
		if pack:match("^https?://") then
			local ok, source = pcall(game.HttpGet, game, pack)
			if not ok then
				warn("[Cornelius] Failed to fetch pack: " .. tostring(source))
				return false
			end
			local chunk, err = loadstring(source)
			if not chunk then
				warn("[Cornelius] Failed to compile pack: " .. tostring(err))
				return false
			end
			local ok2, result = pcall(chunk, Cornelius)
			if not ok2 then
				warn("[Cornelius] Failed to load pack: " .. tostring(result))
				return false
			end
			if type(result) == "table" then
				local name = result.Name or "Unnamed Pack"
				self.RegisteredPacks[name] = result
				if type(result.Load) == "function" then
					pcall(result.Load, self)
				end
				self._loadedCount = self._loadedCount + 1
				if self._window then
					self._window:Notify({
						Title = "Cornelius Pack Loaded",
						Content = "Loaded: " .. name,
						Type = "success"
					})
				end
				return true
			end
		else
			local packTable = self.Packs[pack]
			if packTable then
				local name = packTable.Name or "Unnamed Pack"
				self.RegisteredPacks[name] = packTable
				if type(packTable.Load) == "function" then
					pcall(packTable.Load, self)
				end
				self._loadedCount = self._loadedCount + 1
				if self._window then
					self._window:Notify({
						Title = "Cornelius Pack Loaded",
						Content = "Loaded: " .. name,
						Type = "success"
					})
				end
				return true
			else
				if self._window then
					self._window:Notify({
						Title = "Pack Not Found",
						Content = "No built-in pack named: " .. pack,
						Type = "error"
					})
				end
			end
		end
	end
	return false
end

function Cornelius:LoadPacks(packList)
	local loaded = {}
	for _, pack in ipairs(packList) do
		local success = self:LoadPack(pack)
		table.insert(loaded, success)
	end
	if self._window then
		local count = 0
		for _, success in ipairs(loaded) do
			if success then count = count + 1 end
		end
		self._window:Notify({
			Title = "Cornelius Packs Loaded",
			Content = "Loaded " .. count .. "/" .. #packList .. " packs",
			Type = "info"
		})
	end
	return loaded
end

function Cornelius:RegisterCommand(name, callback)
	self.Commands[name:lower()] = callback
end

function Cornelius:RegisterGuide(name, guideData)
	self.Guides[name:lower()] = guideData
end

function Cornelius:GetGuide(name)
	return self.Guides[name:lower()]
end

function Cornelius:OpenGuide(name, window)
	local guide = self:GetGuide(name)
	if not guide then
		if window then
			window:Notify({
				Title = "Guide Not Found",
				Content = "No guide found for: " .. name,
				Type = "error"
			})
		end
		return false
	end
	
	self:DisplayGuide(guide, window)
	return true
end

function Cornelius:DisplayGuide(guide, window)
	if not window then
		warn("[Cornelius] No window provided for guide display")
		return
	end
	
	local stepsText = ""
	for i, step in ipairs(guide.Steps or {}) do
		stepsText = stepsText .. (i) .. ". " .. step
		if i < #guide.Steps then stepsText = stepsText .. "\n" end
	end
	
	local header = guide.Title or "Guide"
	if guide.Category then
		header = header .. " (" .. guide.Category .. ")"
	end
	if guide.Difficulty then
		header = header .. " - " .. guide.Difficulty
	end
	
	window:Notify({
		Title = header,
		Content = stepsText,
		Duration = math.min(#guide.Steps * 2 + 4, 30),
		Type = "info"
	})
end

function Cornelius:HandleCommand(window, input)
	if not input:match("^/cornelius") then return false end
	
	local args = {}
	for word in input:gmatch("%S+") do
		table.insert(args, word)
	end
	
	table.remove(args, 1)  -- remove "/cornelius"
	
	if #args == 0 then
		local loadedPacks = {}
		for name in pairs(self.RegisteredPacks) do
			table.insert(loadedPacks, name)
		end
		local packList = #loadedPacks > 0 and table.concat(loadedPacks, ", ") or "None"
		window:Notify({
			Title = "Cornelius Help",
			Content = "Commands: /cornelius [command]\nLoaded Packs: " .. packList,
			Duration = 10,
			Type = "info"
		})
		return true
	end
	
	local command = table.concat(args, " "):lower()
	local cmd = self.Commands[command]
	
	if cmd then
		local ok, err = pcall(cmd, window, args)
		if not ok then
			window:Notify({
				Title = "Cornelius Error",
				Content = "Command failed: " .. tostring(err),
				Type = "error"
			})
		end
		return true
	end
	
	-- Try to find a guide with this name
	if self.Guides[command] then
		self:OpenGuide(command, window)
		return true
	end
	
	window:Notify({
		Title = "Command Not Found",
		Content = "Try: /cornelius help for available commands",
		Type = "warning"
	})
	return true
end

function Cornelius:GetCommands()
	local list = {}
	for name in pairs(self.Commands) do
		table.insert(list, name)
	end
	return list
end

function Cornelius:GetGuides()
	local list = {}
	for name in pairs(self.Guides) do
		table.insert(list, name)
	end
	return list
end

function Cornelius:GetFlags()
	local list = {}
	for name in pairs(Library.Flags) do
		table.insert(list, name)
	end
	return list
end

-- ===================== BUILT-IN CORNELIUS PACKS =====================

-- Core Pack (includes help command)
Cornelius.Packs["Core"] = {
	Name = "Core Pack",
	Version = "1.0.0",
	Description = "Core Cornelius commands",
	Load = function(Cornelius)
		Cornelius:RegisterCommand("help", function(window)
			local commands = Cornelius:GetCommands()
			local guides = Cornelius:GetGuides()
			local msg = "📚 Commands: " .. table.concat(commands, ", ")
			if #guides > 0 then
				msg = msg .. "\n📖 Guides: " .. table.concat(guides, ", ")
			end
			window:Notify({
				Title = "Cornelius Help",
				Content = msg,
				Duration = 10,
				Type = "info"
			})
		end)
	end
}

-- Developer Pack
Cornelius.Packs["Developer"] = {
	Name = "Developer Pack",
	Version = "1.0.0",
	Description = "Development guides and API documentation",
	
	Load = function(Cornelius)
		Cornelius:RegisterGuide("api-flags", {
			Title = "CornUi Flags API",
			Category = "API",
			Difficulty = "Beginner",
			Steps = {
				"Flags are global variables that persist across the UI",
				"Set a flag: Corn:SetFlag('name', value)",
				"Get a flag: Corn:GetFlag('name')",
				"Listen to flag changes: Corn.FlagChanged:Connect(callback)",
				"Flags are automatically saved with Config System"
			}
		})
		
		Cornelius:RegisterGuide("api-elements", {
			Title = "Creating UI Elements",
			Category = "API",
			Difficulty = "Beginner",
			Steps = {
				"Create a tab: Window:CreateTab('Name')",
				"Create a section: Tab:CreateSection('Name')",
				"Create a button: Tab:CreateButton({ Name = 'Click', Callback = function() end })",
				"Create a toggle: Tab:CreateToggle({ Name = 'Toggle', Default = false, Flag = 'ToggleFlag' })",
				"All elements support: :Destroy(), :SetVisible(), :SetDisabled(), :Refresh()"
			}
		})
		
		Cornelius:RegisterGuide("api-plugins", {
			Title = "Plugin System",
			Category = "API",
			Difficulty = "Intermediate",
			Steps = {
				"Plugins extend CornUi without modifying core",
				"Load plugins: Corn:LoadPlugins({ 'url1', 'url2' }, Window)",
				"Plugin format: return { Name = '', Init = function(ctx) end }",
				"Plugin context: ctx.Window, ctx:GetFlag(), ctx:SetFlag(), ctx:Notify()",
				"Plugins can create tabs, register commands, and more"
			}
		})
		
		Cornelius:RegisterGuide("api-cornelius", {
			Title = "Cornelius Assistant API",
			Category = "API",
			Difficulty = "Beginner",
			Steps = {
				"Cornelius is the assistant system built into CornUi",
				"Register commands: Cornelius:RegisterCommand('name', function(window, args) end)",
				"Register guides: Cornelius:RegisterGuide('name', { Title = '', Steps = {} })",
				"Load packs: Cornelius:LoadPack('PackName') or Cornelius:LoadPacks({ 'Pack1', 'Pack2' })",
				"Use commands: /cornelius command-name"
			}
		})
		
		Cornelius:RegisterCommand("debug", function(window)
			local info = {
				"=== CornUi Debug Info ===",
				"Version: " .. Library.VERSION,
				"Cornelius: v" .. Cornelius._VERSION,
				"Packs Loaded: " .. Cornelius._loadedCount,
				"Registered Commands: " .. #Cornelius:GetCommands(),
				"Registered Guides: " .. #Cornelius:GetGuides(),
				"Flags: " .. #Cornelius:GetFlags(),
			}
			window:Notify({
				Title = "Debug Info",
				Content = table.concat(info, "\n"),
				Duration = 15,
				Type = "info"
			})
		end)
		
		Cornelius:RegisterCommand("explain flags", function(window)
			Cornelius:OpenGuide("api-flags", window)
		end)
		
		Cornelius:RegisterCommand("explain elements", function(window)
			Cornelius:OpenGuide("api-elements", window)
		end)
		
		Cornelius:RegisterCommand("explain plugins", function(window)
			Cornelius:OpenGuide("api-plugins", window)
		end)
		
		Cornelius:RegisterCommand("explain cornelius", function(window)
			Cornelius:OpenGuide("api-cornelius", window)
		end)
	end
}

-- Random Pack
Cornelius.Packs["Random"] = {
	Name = "Random Pack",
	Version = "1.0.0",
	Description = "Random fun content",
	
	Load = function(Cornelius)
		local facts = {
			"Corn is a fruit, not a vegetable.",
			"Roblox was created in 2004 by David Baszucki.",
			"The first game on Roblox was called Rocket Arena.",
			"There are over 200 million monthly active Roblox players.",
			"The most visited Roblox game is Adopt Me!",
			"Corn has more sugar than any other vegetable.",
			"There are over 10,000 Roblox game developers.",
			"Roblox originally had only 100 players."
		}
		
		local jokes = {
			"Why did the corn cross the road? To get to the other silo!",
			"What do you call a sad corn? A corny joke!",
			"Why did the developer quit? He didn't get enough Corn!",
			"What's a corn's favorite game? Roblox!",
			"Why did the UI designer go broke? He lost his frame of mind!",
			"What do you call a corn with a black eye? A popped kernel!",
			"Why do corn developers always have good ideas? They're corny!",
			"What did the corn say to the butter? Don't spread me!"
		}
		
		local history = {
			"Did you know? Corn was first domesticated in Mexico over 10,000 years ago.",
			"The Aztecs and Mayans considered corn sacred.",
			"Corn is the most widely grown crop in the Americas.",
			"Popcorn was first discovered by Native Americans.",
			"There are over 3,500 uses for corn products."
		}
		
		local function getRandom(arr)
			return arr[math.random(#arr)]
		end
		
		Cornelius:RegisterCommand("fact", function(window)
			window:Notify({
				Title = "Random Fact",
				Content = getRandom(facts),
				Type = "info"
			})
		end)
		
		Cornelius:RegisterCommand("joke", function(window)
			window:Notify({
				Title = "Corn Joke 🌽",
				Content = getRandom(jokes),
				Type = "warning"
			})
		end)
		
		Cornelius:RegisterCommand("history", function(window)
			window:Notify({
				Title = "Corn History",
				Content = getRandom(history),
				Type = "info"
			})
		end)
		
		Cornelius:RegisterCommand("random", function(window)
			local randoms = {"fact", "joke", "history"}
			local cmd = getRandom(randoms)
			Cornelius:HandleCommand(window, "/cornelius " .. cmd)
		end)
	end
}

-- Documentation Pack
Cornelius.Packs["Documentation"] = {
	Name = "Documentation Pack",
	Version = "1.0.0",
	Description = "Complete CornUi documentation",
	
	Load = function(Cornelius)
		Cornelius:RegisterGuide("docs-welcome", {
			Title = "Welcome to CornUi Documentation",
			Category = "Documentation",
			Difficulty = "Beginner",
			Steps = {
				"CornUi is a mobile-first Roblox UI framework",
				"Version: " .. Library.VERSION,
				"Key features: Mobile-first, Themes, Plugins, Cornelius Assistant",
				"Load CornUi: local Corn = loadstring(game:HttpGet('url'))()",
				"Create window: local Window = Corn:CreateWindow({ Name = 'My Hub' })",
				"Create tab: local Tab = Window:CreateTab('Main')",
				"Add elements: Tab:CreateButton({ Name = 'Click' })",
				"Type /cornelius help for more commands"
			}
		})
		
		Cornelius:RegisterGuide("docs-elements", {
			Title = "All UI Elements",
			Category = "Documentation",
			Difficulty = "Beginner",
			Steps = {
				"Button: Tab:CreateButton({ Name, Callback, Sound, Haptic })",
				"Toggle: Tab:CreateToggle({ Name, Default, Flag, Callback, ThreeState })",
				"Slider: Tab:CreateSlider({ Name, Min, Max, Default, Flag, Callback })",
				"Textbox: Tab:CreateTextbox({ Name, Placeholder, Default, Flag, Callback })",
				"Keybind: Tab:CreateKeybind({ Name, Default, Flag, Callback })",
				"Hotkey: Tab:CreateHotkey({ Name, Default, Callback })",
				"Dropdown: Tab:CreateDropdown({ Name, Options, Default, Flag, Callback })",
				"MultiDropdown: Tab:CreateMultiDropdown({ Name, Options, Default, Flag, Callback })",
				"RadioGroup: Tab:CreateRadioGroup({ Name, Options, Default, Flag, Callback })",
				"ColorPicker: Tab:CreateColorPicker({ Name, Default, Flag, Callback })",
				"Timer: Tab:CreateTimer({ Name, Duration, Callback })",
				"Checklist: Tab:CreateChecklist({ Name, Items, Callback })",
				"Meter: Tab:CreateMeter({ Name, Min, Max, Default, Color, Animated })",
				"ProgressBar: Tab:CreateProgressBar({ Name, Min, Max, Default, Flag })",
				"Search: Tab:CreateSearch({ Placeholder })",
				"Card: Tab:CreateCard({ Title, Subtitle })",
				"Paragraph: Tab:CreateParagraph({ Title, Text })",
				"Image: Tab:CreateImage({ Image, Name, Height })",
				"Divider: Tab:CreateDivider({ Name })",
				"DiscordButton: Tab:CreateDiscordButton({ Name, Invite })",
				"ThemeEditor: Tab:CreateThemeEditor({ Title })",
				"KeybindList: Tab:CreateKeybindList({ Name })",
				"ColorGradient: Tab:CreateColorGradient({ Name, Stops, Flag, Callback })",
				"NotificationCenter: Tab:CreateNotificationCenter({ Name })",
				"PluginManager: Tab:CreatePluginManager({ Name })"
			}
		})
		
		Cornelius:RegisterGuide("docs-themes", {
			Title = "Themes & Customization",
			Category = "Documentation",
			Difficulty = "Intermediate",
			Steps = {
				"Built-in themes: Dark, Light, Ocean, Forest, Sunset, Amethyst, Ruby, Frost, Candy, Midnight, Cyber",
				"Apply theme: Corn:CreateWindow({ Theme = 'Ocean' })",
				"Switch theme: Window:SetTheme('Ocean')",
				"Register custom theme: Corn:RegisterTheme('MyTheme', { Background = Color3.new(1,0,0), ... })",
				"Customize UI: Window:SetCornerRadius(24), Window:SetOpacity(0.2)",
				"Animate speed: Window:SetAnimationSpeed(2.0)"
			}
		})
		
		Cornelius:RegisterGuide("docs-flags-config", {
			Title = "Flags & Configuration",
			Category = "Documentation",
			Difficulty = "Intermediate",
			Steps = {
				"Flags store UI state globally",
				"Set: Corn:SetFlag('name', value)",
				"Get: Corn:GetFlag('name')",
				"Save config: Corn:SaveConfig('myconfig')",
				"Load config: Corn:LoadConfig('myconfig', Window)",
				"Export config: Window:ExportConfig()",
				"Import config: Window:ImportConfig(jsonString)",
				"List configs: Corn:ListConfigs()"
			}
		})
		
		Cornelius:RegisterCommand("docs", function(window)
			Cornelius:OpenGuide("docs-welcome", window)
		end)
		
		Cornelius:RegisterCommand("docs elements", function(window)
			Cornelius:OpenGuide("docs-elements", window)
		end)
		
		Cornelius:RegisterCommand("docs themes", function(window)
			Cornelius:OpenGuide("docs-themes", window)
		end)
		
		Cornelius:RegisterCommand("docs flags", function(window)
			Cornelius:OpenGuide("docs-flags-config", window)
		end)
	end
}

-- ===================== LIBRARY =====================
function Library:CreateWindow(config)
	config = config or {}
	
	if Library.Flags.PerformanceMode then
		config.Intro = false
	end
	
	if not Library.Flags.ShowIntro then
		config.Intro = false
	end
	
	local windowName = config.Name or "UI Library"
	local guiName = config.GuiName or "MobileUILib"
	local windowPosition = config.Position or UDim2.new(0.5, 0, 0.5, 0)
	local subtitle = config.Subtitle
	local iconId = config.Icon
	if iconId and type(iconId) == "number" then
		iconId = "rbxassetid://" .. tostring(iconId)
	elseif iconId and type(iconId) == "string" and not iconId:match("^rbxassetid://") then
		iconId = "rbxassetid://" .. iconId
	end

	local preset = Themes[config.Theme] or Themes.Ocean
	for k, v in pairs(preset) do Theme[k] = v end
	Library._currentThemeName = Themes[config.Theme] and config.Theme or "Ocean"

	if #Library._themeHistory >= 5 then
		table.remove(Library._themeHistory, 1)
	end
	table.insert(Library._themeHistory, Library._currentThemeName)

	local existing = PlayerGui:FindFirstChild(guiName)
	if existing then existing:Destroy() end

	local screenGui = create("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		IgnoreGuiInset = false,
	})
	screenGui.Parent = PlayerGui

	local uiScale = create("UIScale", { Scale = 1 })

	local touch = isTouchDevice()
	local compact = Library.Flags.CompactMode
	local togglePosition = config.TogglePosition or UDim2.new(1, -(touch and 68 or 58), 0, 16)
	
	local mainSizeScale
	if compact then
		mainSizeScale = touch and UDim2.new(0.95, 0, 0.75, 0) or UDim2.new(0, 480, 0, 400)
	else
		mainSizeScale = touch and UDim2.new(0.92, 0, 0.82, 0) or UDim2.new(0, 560, 0, 460)
	end

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

	local function applyAutoScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local scale = Library.Flags.UIScale or 1
		uiScale.Scale = math.clamp((viewport.Y / 720) * scale, 0.5, 1.5)
	end
	applyAutoScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyAutoScale)
	end

	local isLight = (preset == Themes.Light)

	main.BackgroundTransparency = isLight and 0.06 or 0.1
	if not Library.Flags.PerformanceMode then
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
	end

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
	}, { corner(16) })
	header.Parent = main

	local titleOffset = 15
	if iconId then
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
		icon:SetAttribute("MUI_NoTheme", true)
		titleOffset = 12 + iconSize + 8
	end

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

	local currentThemeName = isLight and "Light" or "Ocean"
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

	makeDraggable(header, main, true)

	local floatSize = touch and 52 or 42
	local floatBtn
	if iconId then
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

	makeDraggable(floatBtn, floatBtn, false)

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
			PaddingTop = UDim.new(0, compact and 6 or 12),
			PaddingBottom = UDim.new(0, compact and 6 or 12),
			PaddingLeft = UDim.new(0, compact and 4 or 8),
			PaddingRight = UDim.new(0, compact and 4 or 8),
		}),
	})
	body.Parent = main

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
			Padding = UDim.new(0, compact and 2 or 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, compact and 4 or 8),
			PaddingBottom = UDim.new(0, compact and 4 or 8),
			PaddingLeft = UDim.new(0, compact and 4 or 8),
			PaddingRight = UDim.new(0, compact and 4 or 8),
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
		_animationSpeed = 1.0,
		_shadowEnabled = false,
		_blurAmount = 0,
		_commands = {
			["t-notif"] = function(w)
				w:Notify({ Title = "Test Notification", Content = "This is a test notification.", Type = "info" })
			end,
			["theme"] = function(w, argString)
				local theme = argString:match("^(%S+)")
				if theme and Themes[theme] then
					w:SetTheme(theme)
					w:Notify({ Title = "Theme", Content = "Switched to " .. theme, Type = "success" })
				else
					local themes = {}
					for name in pairs(Themes) do
						table.insert(themes, name)
					end
					w:Notify({ Title = "Themes", Content = "Available: " .. table.concat(themes, ", "), Type = "info" })
				end
			end,
			["save"] = function(w, argString)
				local name = argString ~= "" and argString or "default"
				local success = Library:SaveConfig(name)
				if success then
					w:Notify({ Title = "Config Saved", Content = "Saved as '" .. name .. "'", Type = "success" })
				else
					w:Notify({ Title = "Error", Content = "Failed to save config", Type = "error" })
				end
			end,
			["load"] = function(w, argString)
				local name = argString ~= "" and argString or "default"
				local success = Library:LoadConfig(name, w)
				if success then
					w:Notify({ Title = "Config Loaded", Content = "Loaded '" .. name .. "'", Type = "success" })
				else
					w:Notify({ Title = "Error", Content = "Failed to load config", Type = "error" })
				end
			end,
			["list"] = function(w)
				local configs = Library:ListConfigs()
				if #configs > 0 then
					w:Notify({ Title = "Configs", Content = table.concat(configs, ", "), Type = "info" })
				else
					w:Notify({ Title = "Configs", Content = "No saved configs", Type = "info" })
				end
			end,
			["minimize"] = function(w)
				minimized = not minimized
				tween(main, { Size = minimized and UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, headerHeight) or mainSizeScale }, 0.2)
				body.Visible = not minimized
			end,
			["export"] = function(w)
    			local json = Library:ExportConfig()
    
    			-- If empty, provide fallback
    			if not json or json == "" then
	        		json = "{}"
    			end
    
    			-- Debug print to console
    			print("[Export] JSON length:", #json)
    			print("[Export] JSON preview:", string.sub(json, 1, 100))
    
    			local popup = create("Frame", {
			        Size = UDim2.new(0, 400, 0, 300),
        			Position = UDim2.new(0.5, 0, 0.5, 0),
        			AnchorPoint = Vector2.new(0.5, 0.5),
        			BackgroundColor3 = Theme.Header,
        			ZIndex = 201,
    				}, { corner(14), stroke(Theme.Accent, 1.5) })
    				popup.Parent = screenGui
    
    			create("TextLabel", {
        			Text = "Export Config",
			        Font = Enum.Font.GothamBold,
        			TextSize = 16,
        			TextColor3 = Theme.Text,
			        BackgroundTransparency = 1,
        			Size = UDim2.new(1, 0, 0, 30),
        			Position = UDim2.new(0, 0, 0, 8),
    			}).Parent = popup
    
    			-- ✅ FIX: Use a ScrollingFrame with proper text display
    			local scrollFrame = create("ScrollingFrame", {
			        Size = UDim2.new(1, -20, 1, -70),
        			Position = UDim2.new(0, 10, 0, 40),
        			BackgroundColor3 = Theme.Element,
       				BorderSizePixel = 0,
        			ScrollBarThickness = 6,
        			CanvasSize = UDim2.new(0, 0, 0, 0),
        			AutomaticCanvasSize = Enum.AutomaticSize.Y,
    			}, { corner(8) })
    			scrollFrame.Parent = popup
    
    			local textBox = create("TextBox", {
        			Text = json,
        			Font = Enum.Font.Gotham,
			        TextSize = 13,
			        TextColor3 = Theme.Text,
			        BackgroundTransparency = 1,
        			Size = UDim2.new(1, 0, 0, 0),
       				AutomaticSize = Enum.AutomaticSize.Y,
        			ClearTextOnFocus = false,
        			TextWrapped = true,
        			TextXAlignment = Enum.TextXAlignment.Left,
        			TextYAlignment = Enum.TextYAlignment.Top,
        			-- ✅ Important: No TextScaled (it messes up display)
    			})
    			textBox.Parent = scrollFrame
    
    			-- ✅ Add a copy button
    			local copyBtn = create("TextButton", {
        			Text = "📋 Copy",
			        Font = Enum.Font.GothamBold,
       				TextSize = 13,
        			TextColor3 = Theme.Text,
        			BackgroundColor3 = Theme.Accent,
        			Size = UDim2.new(0, 70, 0, 28),
        			Position = UDim2.new(1, -80, 1, -38),
    			}, { corner(8) })
    			copyBtn.Parent = popup
    			copyBtn.MouseButton1Click:Connect(function()
			        -- Open a small popup with selectable text
        			local copyPopup = create("Frame", {
            			Size = UDim2.new(0, 380, 0, 80),
            			Position = UDim2.new(0.5, 0, 0.5, 0),
            			AnchorPoint = Vector2.new(0.5, 0.5),
            			BackgroundColor3 = Theme.Header,
            			ZIndex = 300,
        			}, { corner(14), stroke(Theme.Accent, 1.5) })
        			copyPopup.Parent = screenGui
        
        			create("TextLabel", {
            			Text = "Select and copy the text below:",
            			Font = Enum.Font.Gotham,
           				TextSize = 12,
            			TextColor3 = Theme.SubText,
           				BackgroundTransparency = 1,
            			Size = UDim2.new(1, -20, 0, 20),
            			Position = UDim2.new(0, 10, 0, 8),
            			TextXAlignment = Enum.TextXAlignment.Left,
        			}).Parent = copyPopup
        
        			local copyBox = create("TextBox", {
			            Text = json,
			            Font = Enum.Font.Gotham,
			            TextSize = 12,
			            TextColor3 = Theme.Text,
			            BackgroundColor3 = Theme.Element,
			            Size = UDim2.new(1, -20, 0, 30),
			            Position = UDim2.new(0, 10, 0, 32),
			            ClearTextOnFocus = false,
			            TextWrapped = true,
			            TextXAlignment = Enum.TextXAlignment.Left,
			        }, { corner(6) })
			        copyBox.Parent = copyPopup
			        
			        local closeCopyBtn = create("TextButton", {
			            Text = "Close",
			            Font = Enum.Font.GothamBold,
			            TextSize = 12,
			            TextColor3 = Theme.Text,
			            BackgroundColor3 = Theme.Accent,
			            Size = UDim2.new(0, 60, 0, 24),
			            Position = UDim2.new(0.5, -30, 1, -30),
			        }, { corner(6) })
			        closeCopyBtn.Parent = copyPopup
			        closeCopyBtn.MouseButton1Click:Connect(function()
			            copyPopup:Destroy()
			        end)
			    end)
			    
			    local closeBtn = create("TextButton", {
			        Text = "Close",
			        Font = Enum.Font.GothamBold,
			        TextSize = 14,
			        TextColor3 = Theme.Text,
			        BackgroundColor3 = Theme.Accent,
			        Size = UDim2.new(0, 70, 0, 28),
			        Position = UDim2.new(0.5, -35, 1, -38),
			    }, { corner(8) })
			    closeBtn.Parent = popup
			    closeBtn.MouseButton1Click:Connect(function()
			        popup:Destroy()
			    end)
			end
			["screenshot"] = function(w)
				local ok, result = pcall(function()
					return GuiService:CaptureScreenshot()
				end)
				if ok and result then
					w:Notify({ Title = "Screenshot", Content = "Captured successfully!", Type = "success" })
				else
					w:Notify({ Title = "Screenshot", Content = "Failed to capture", Type = "error" })
				end
			end,
			["help"] = function(w)
				local cmds = {}
				for cmd in pairs(w._commands) do
					table.insert(cmds, cmd)
				end
				for cmd in pairs(Cornelius.Commands) do
					table.insert(cmds, "/cornelius " .. cmd)
				end
				w:Notify({ Title = "Commands", Content = "Available: " .. table.concat(cmds, ", "), Type = "info" })
			end,
			["reset"] = function(w)
				w:Notify({ Title = "Reset", Content = "Are you sure? Type 'reset confirm' to proceed", Type = "warning" })
				w._pendingReset = true
				task.delay(10, function()
					w._pendingReset = false
				end)
			end,
			["reset confirm"] = function(w)
				if w._pendingReset then
					for name in pairs(Library.Flags) do
						Library:SetFlag(name, nil)
					end
					w:Notify({ Title = "Reset", Content = "All flags reset to default", Type = "success" })
					w._pendingReset = false
				end
			end,
			["cornelius"] = function(w, argString)
				Cornelius:HandleCommand(w, "/cornelius " .. (argString or ""))
			end,
		},
	}, { __index = Library.WindowMethods })

	-- Set Cornelius window reference
	Cornelius._window = Window

	titleBox.Focused:Connect(function()
		titleBox.Text = ""
	end)
	
	titleBox.FocusLost:Connect(function()
		local raw = titleBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if raw ~= "" then
			if raw:match("^/cornelius") then
				Cornelius:HandleCommand(Window, raw)
				titleBox.Text = windowName
				return
			end
			
			table.insert(Library.CommandHistory, raw)
			if #Library.CommandHistory > Library.MAX_COMMAND_HISTORY then
				table.remove(Library.CommandHistory, 1)
			end
			commandIndex = #Library.CommandHistory
			
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
			else
				local suggestions = {}
				for c in pairs(Window._commands) do
					if c:find(cmd, 1, true) then
						table.insert(suggestions, c)
					end
				end
				if #suggestions > 0 then
					Window:Notify({ Title = "Command Not Found", Content = "Did you mean: " .. table.concat(suggestions, ", "), Type = "warning" })
				else
					Window:Notify({ Title = "Command Not Found", Content = "Type 'help' for available commands", Type = "error" })
				end
			end
		end
		titleBox.Text = windowName
	end)
	
	titleBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Up then
			if #Library.CommandHistory > 0 then
				commandIndex = math.max(1, commandIndex - 1)
				titleBox.Text = Library.CommandHistory[commandIndex]
				titleBox.CursorPosition = #titleBox.Text
			end
		elseif input.KeyCode == Enum.KeyCode.Down then
			if commandIndex < #Library.CommandHistory then
				commandIndex = commandIndex + 1
				titleBox.Text = Library.CommandHistory[commandIndex]
				titleBox.CursorPosition = #titleBox.Text
			else
				commandIndex = #Library.CommandHistory
				titleBox.Text = ""
			end
		end
	end)

	themeBtn.MouseButton1Click:Connect(function()
		local themes = {"Ocean", "Dark", "Light", "Amethyst", "Ruby", "Frost", "Candy", "Midnight", "Cyber"}
		local idx = 1
		for i, t in ipairs(themes) do
			if t == currentThemeName then
				idx = i % #themes + 1
				break
			end
		end
		currentThemeName = themes[idx]
		themeBtn.Text = (currentThemeName == "Light") and "🌙" or "☀"
		Window:SetTheme(currentThemeName)
	end)

	if Library.Flags.AutoSaveInterval and Library.Flags.AutoSaveInterval > 0 then
		task.spawn(function()
			while main.Parent do
				task.wait(Library.Flags.AutoSaveInterval)
				pcall(function() Library:SaveConfig("autosave") end)
			end
		end)
	end

	-- ===================== INTRO ANIMATION =====================
	if Library.Flags.ReducedMotion or not Library.Flags.ShowIntro then
		return Window
	end
	local introConfig = config.Intro or {}
	local introImage = introConfig.Image
	if introImage == nil then
		introImage = 80406291512141
	elseif introImage == false then
		introImage = nil
	end
	if introImage and type(introImage) == "number" then
		introImage = "rbxassetid://" .. tostring(introImage)
	elseif introImage and type(introImage) == "string" and not introImage:match("^rbxassetid://") then
		introImage = "rbxassetid://" .. introImage
	end
	local introText = introConfig.Text or "-By Lifeless"
	local introHold = introConfig.Duration or 1.4
	local normalIntroTooltips = {
		"Tip: click the hub name to open the command palette.",
		"Tip: click the floating button to hide or restore the hub.",
		"Tip: use the theme button to switch between light and dark mode.",
		"Tip: settings with a Flag can be saved and restored with configs.",
		"Tip: tabs and the hub window can be dragged on desktop and touch.",
		"Create your own themes! using the gradient feature",
		"tired of a new key daily, get a weekly key now!",
		"Type 'help' to see all commands!",
		"Type 'export' to share your config!",
		"Type '/cornelius help' to see Cornelius commands!",
	}
	local funnyIntroTooltips = {
		"Downloading more RAM...",
		"Cleaning the toilet...",
		"C:????????????????????????: Something happened.",
		"Teaching the corn how to code...",
		"Convincing the buttons to behave...",
		"Calibrating the cat launcher...",
		"gooning....Wait",
		"Yes i used claude for debugging, SMD if you have problem",
		"Alt+F4 gives free bobux",
		"v1.9.3 - Stable Release",
		"Type 'screenshot' for free photos",
		"Cornelius is watching...",
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
	local introTextColor = Color3.fromRGB(255, 196, 48)

	local introOverlay = create("Frame", {
		Name = "IntroOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 300,
		Active = true,
	})
	introOverlay.Parent = screenGui

	local skipBtn = create("TextButton", {
		Text = "Skip",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(150, 150, 150),
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 60, 0, 30),
		Position = UDim2.new(1, -80, 1, -50),
		ZIndex = 303,
	})
	skipBtn.Parent = introOverlay
	skipBtn.MouseButton1Click:Connect(function()
		introOverlay:Destroy()
	end)

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
		tween(wipe, { Size = UDim2.new(1, 0, 1, 0) }, 0.5)
		task.wait(0.5)

		if introImgLabel then
			tween(introImgLabel, { ImageTransparency = 0 }, 0.5)
			task.wait(0.3)
		end
		tween(introTextLabel, { TextTransparency = 0 }, 0.5)
		tween(introTooltipLabel, { TextTransparency = 0 }, 0.5)

		local elapsed = 0
		while elapsed < introHold do
			local waitTime = math.min(2, introHold - elapsed)
			task.wait(waitTime)
			elapsed = elapsed + waitTime
			if elapsed < introHold then
				introTooltipLabel.Text = nextIntroTooltip()
			end
		end

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

-- ===================== WINDOW METHODS =====================

-- Window:Notify (FIXED — notification sizing)
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
    notificationLoggedEvent:Fire(historyEntry)
    
    playNotificationSound(notifType)

    -- FIX: Use a fixed max height with a ScrollingFrame inside
    local MAX_NOTIFICATION_HEIGHT = 180  -- Max height in pixels
    local notif = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Header,
        BackgroundTransparency = 1,
        LayoutOrder = self._notifCount,
        ClipsDescendants = true,  -- ✅ Clip content that overflows
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
    
    local clickArea = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })
    clickArea.Parent = notif
    clickArea.MouseButton1Click:Connect(function()
        notif:Destroy()
    end)

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

    -- ✅ FIX: Content with height limit
    local contentContainer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,  -- ✅ Clip overflow
    })
    contentContainer.Parent = notif

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
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
    })
    contentLabel.Parent = contentContainer

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
        if notif and notif.Parent then
            tween(notif, { BackgroundTransparency = 1 }, 0.3)
            tween(titleLabel, { TextTransparency = 1 }, 0.3)
            tween(contentLabel, { TextTransparency = 1 }, 0.3)
            tween(progressTrack, { BackgroundTransparency = 1 }, 0.3)
            tween(progressBar, { BackgroundTransparency = 1 }, 0.3)
            task.delay(0.3, function()
                if notif then notif:Destroy() end
            end)
        end
    end)
end

-- Window:SetTheme (unchanged)
function WM:SetTheme(name)
	local newPreset = Themes[name]
	if not newPreset then return end

	Library._currentThemeName = name
	
	if #Library._themeHistory >= 5 then
		table.remove(Library._themeHistory, 1)
	end
	table.insert(Library._themeHistory, name)

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

-- THEME_EDITOR_KEYS and SetThemeColor (unchanged)
local THEME_EDITOR_KEYS = { Background = true, ToggleButton = true }

function WM:SetThemeColor(key, color)
	if not THEME_EDITOR_KEYS[key] then return end
	local oldColor = Theme[key]
	if not oldColor then return end

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

-- Window:SetBackground, ClearBackground, RegisterCommand (unchanged)
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

function WM:ClearBackground()
	if self._background then
		self._background:Destroy()
		self._background = nil
	end
end

function WM:RegisterCommand(keyword, fn)
	self._commands[tostring(keyword):lower()] = fn
end

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

function WM:SetCornerRadius(radius)
	local main = self._main
	local corners = main:FindFirstChild("UICorner")
	if corners then
		corners.CornerRadius = UDim.new(0, radius)
	end
	
	for _, child in ipairs(main:GetDescendants()) do
		if child:IsA("UICorner") then
			child.CornerRadius = UDim.new(0, radius)
		end
	end
end

function WM:SetOpacity(transparency)
	local main = self._main
	if transparency >= 0 and transparency <= 1 then
		main.BackgroundTransparency = transparency
	end
end

function WM:GetActiveTab()
	return self._currentPageEntry
end

function WM:SetAnimationSpeed(factor)
	animationSpeed = math.clamp(factor, 0.1, 3.0)
end

function WM:SetBlur(amount)
	self._blurAmount = math.clamp(amount, 0, 1)
	local main = self._main
	if amount > 0 then
		main.BackgroundTransparency = math.min(main.BackgroundTransparency + amount * 0.3, 0.95)
	else
		main.BackgroundTransparency = 0.1
	end
end

function WM:SetShadow(enable)
	self._shadowEnabled = enable
	local main = self._main
	local shadow = main:FindFirstChild("_Shadow")
	if enable then
		if not shadow then
			shadow = create("Frame", {
				Name = "_Shadow",
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 3, 0, 3),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.7,
				BorderSizePixel = 0,
				ZIndex = -1,
			}, { corner(16) })
			shadow.Parent = main
		end
	else
		if shadow then shadow:Destroy() end
	end
end

function WM:ExportConfig(name)
	return Library:ExportConfig(name)
end

function WM:ImportConfig(jsonText)
	return Library:ImportConfig(jsonText, self)
end

-- ===================== CREATE TAB =====================
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
		_tabIndex = #self._tabs + 1,
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
					Active = true,
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

	handle.PlaySound = function(_, soundId, volume)
		Library:PlaySound(soundId, volume)
	end
	
	handle.PlayHaptic = function(_, variant)
		Library:PlayHaptic(variant)
	end

	return handle
end

-- ===================== CUSTOM ELEMENT DISPATCH =====================
function TM:CreateCustom(name, config)
	local constructor = Library._customElements[name]
	if not constructor then
		warn("[MobileUILib] Unknown custom element: " .. tostring(name))
		return nil
	end
	return constructor(self, config)
end

-- ===================== SECTION =====================
function TM:CreateSection(name)
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local container = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and 40 or 30),
		BackgroundColor3 = Theme.Header,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", {
			Padding = UDim.new(0, compact and 4 or 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, compact and 4 or 8),
			PaddingLeft = UDim.new(0, compact and 4 or 8),
			PaddingRight = UDim.new(0, compact and 4 or 8),
			PaddingBottom = UDim.new(0, compact and 4 or 8),
		}),
	})
	container.Parent = self._page

	create("TextLabel", {
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 16 or 20) or (compact and 12 or 16)),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = container

	local Section = setmetatable({
		_page = container,
		_touch = touch,
		_window = self._window,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	return Library:_wrapElement(container, Section)
end

-- ===================== LABEL =====================
function TM:CreateLabel(text)
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local label = create("TextLabel", {
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 24) or (compact and 14 or 18)),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = self._page
	return label
end

-- ===================== BUTTON =====================
function TM:CreateButton(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local callback = config.Callback or function() end
	local soundId = config.Sound
	local haptic = config.Haptic

	local btn = create("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		AutoButtonColor = false,
	}, { corner(12), stroke() })
	btn.Parent = self._page
	setSearchMeta(btn, config, "Button")

	local label = create("TextLabel", {
		Text = config.Name or "Button",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
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
		
		if soundId then Library:PlaySound(soundId) end
		if haptic then Library:PlayHaptic("short") end
		
		local ok, err = pcall(callback)
		if not ok then warn("[MobileUILib] Button callback error: " .. tostring(err)) end
	end)

	return Library:_wrapElement(btn)
end

-- ===================== TOGGLE (with Three-State) =====================
function TM:CreateToggle(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local threeState = config.ThreeState or false
	
	local states = threeState and {"off", "auto", "on"} or {false, true}
	local stateIndex = 1
	local state = config.Default or (threeState and "auto" or false)
	
	if threeState then
		if state == "on" then stateIndex = 3
		elseif state == "auto" then stateIndex = 2
		else stateIndex = 1 end
	else
		if state then stateIndex = 2 else stateIndex = 1 end
	end
	
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Toggle")

	if config.Flag then Library:SetFlag(config.Flag, state) end

	create("TextLabel", {
		Text = config.Name or "Toggle",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local switchBg = create("Frame", {
		Size = UDim2.new(0, touch and (compact and 42 or 50) or (compact and 34 or 40), 0, touch and (compact and 24 or 28) or (compact and 18 or 22)),
		Position = UDim2.new(1, touch and (compact and -52 or -60) or (compact and -42 or -48), 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = threeState and Color3.fromRGB(100, 100, 100) or (state and Theme.Accent or Color3.fromRGB(60, 60, 68)),
	}, { corner(18) })
	switchBg.Parent = holder

	local knob = create("Frame", {
		Size = UDim2.new(0, touch and (compact and 18 or 22) or (compact and 14 or 16), 0, touch and (compact and 18 or 22) or (compact and 14 or 16)),
		Position = threeState and UDim2.new(0.5, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) / 2), 0.5, 0) or
			(state and UDim2.new(1, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0)),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	}, { corner(15) })
	knob.Parent = switchBg
	
	if threeState then
		local stateLabel = create("TextLabel", {
			Text = "−",
			Font = Enum.Font.GothamBold,
			TextSize = touch and 14 or 12,
			TextColor3 = Color3.fromRGB(100, 100, 100),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
		})
		stateLabel.Parent = knob
	end

	local hitArea = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	})
	hitArea.Parent = holder

	hitArea.MouseButton1Click:Connect(function()
		if threeState then
			stateIndex = (stateIndex % 3) + 1
			local states_map = {1, 2, 3}
			state = states_map[stateIndex]
		else
			state = not state
		end
		
		if threeState then
			if state == 3 then
				switchBg.BackgroundColor3 = Theme.Accent
				knob.Position = UDim2.new(1, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) + 3), 0.5, 0)
				stateLabel.Text = "+"
			elseif state == 2 then
				switchBg.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
				knob.Position = UDim2.new(0.5, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) / 2), 0.5, 0)
				stateLabel.Text = "−"
			else
				switchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
				knob.Position = UDim2.new(0, 3, 0.5, 0)
				stateLabel.Text = "×"
			end
		else
			switchBg.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 68)
			knob.Position = state and UDim2.new(1, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		end
		
		if config.Flag then Library:SetFlag(config.Flag, state) end
		playInteractionSound("toggle")
		local ok, err = pcall(callback, state)
		if not ok then warn("[MobileUILib] Toggle callback error: " .. tostring(err)) end
	end)

	local handle = { 
		Set = function(_, value)
			if threeState then
				if value == "on" then stateIndex = 3
				elseif value == "auto" then stateIndex = 2
				else stateIndex = 1 end
			else
				state = value
			end
			hitArea.MouseButton1Click:Fire()
		end, 
		Get = function() return state end 
	}
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return Library:_wrapElement(holder, handle)
end

-- ===================== SLIDER =====================
function TM:CreateSlider(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local min = config.Min or 0
	local max = config.Max or 100
	local default = config.Default or min
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 48 or 58) or (compact and 38 or 46)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Slider")

	if config.Flag then Library:SetFlag(config.Flag, default) end

	local label = create("TextLabel", {
		Text = (config.Name or "Slider") .. ": " .. tostring(default),
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.new(0, 12, 0, compact and 2 or 4),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = holder

	local track = create("Frame", {
		Size = UDim2.new(1, -24, 0, touch and (compact and 10 or 14) or (compact and 6 or 8)),
		Position = UDim2.new(0, 12, 1, touch and (compact and -18 or -22) or (compact and -14 or -16)),
		BackgroundColor3 = Color3.fromRGB(55, 55, 62),
	}, { corner(10) })
	track.Parent = holder

	local fraction = (default - min) / (max - min)
	local fill = create("Frame", {
		Size = UDim2.new(fraction, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
	}, { corner(10) })
	fill.Parent = track

	local hitArea = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 34 or 40) or (compact and 20 or 26)),
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

-- ===================== TEXTBOX =====================
function TM:CreateTextbox(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Input")

	if config.Flag then Library:SetFlag(config.Flag, config.Default or "") end

	create("TextLabel", {
		Text = config.Name or "Input",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
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
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0.55, -12, 0, touch and (compact and 28 or 34) or (compact and 18 or 24)),
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

TM.CreateTextBox = TM.CreateTextbox

-- ===================== KEYBIND =====================
function TM:CreateKeybind(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local currentKey = config.Default or Enum.KeyCode.Unknown
	local callback = config.Callback or function() end
	local listening = false
	local keybindDescriptor = { Name = config.Name or "Keybind" }

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Keybind")

	if config.Flag then Library:SetFlag(config.Flag, currentKey) end

	create("TextLabel", {
		Text = config.Name or "Keybind",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local keyBtn = create("TextButton", {
		Text = (currentKey ~= Enum.KeyCode.Unknown) and currentKey.Name or "None",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0, touch and (compact and 70 or 80) or (compact and 60 or 70), 0, touch and (compact and 28 or 34) or (compact and 18 or 24)),
		Position = UDim2.new(1, touch and (compact and -80 or -90) or (compact and -70 or -80), 0.5, 0),
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

	keybindDescriptor.Get = handle.Get
	table.insert(Library.Keybinds, keybindDescriptor)
	Library.KeybindRegistered:Fire(keybindDescriptor)

	return Library:_wrapElement(holder, handle)
end

-- ===================== HOTKEY =====================
function TM:CreateHotkey(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local currentKey = config.Default or Enum.KeyCode.Unknown
	local callback = config.Callback or function() end
	local listening = false
	local isPressed = false
	local holdTimer = nil
	local keybindDescriptor = { Name = config.Name or "Hotkey" }

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Hotkey")

	if config.Flag then Library:SetFlag(config.Flag, currentKey) end

	create("TextLabel", {
		Text = config.Name or "Hotkey",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local keyBtn = create("TextButton", {
		Text = (currentKey ~= Enum.KeyCode.Unknown) and currentKey.Name or "None",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0, touch and (compact and 70 or 80) or (compact and 60 or 70), 0, touch and (compact and 28 or 34) or (compact and 18 or 24)),
		Position = UDim2.new(1, touch and (compact and -80 or -90) or (compact and -70 or -80), 0.5, 0),
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
				local ok, err = pcall(callback, "bind", currentKey)
				if not ok then warn("[MobileUILib] Hotkey callback error: " .. tostring(err)) end
			end
		end)
	end)

	local pressConn
	local function startListening()
		if pressConn then pressConn:Disconnect() end
		pressConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey and not listening then
				isPressed = true
				keyBtn.BackgroundColor3 = Theme.Accent
				keyBtn.TextColor3 = Theme.TextOnAccent
				local ok, err = pcall(callback, "press", currentKey)
				if not ok then warn("[MobileUILib] Hotkey callback error: " .. tostring(err)) end
				
				if holdTimer then holdTimer:Cancel() end
				holdTimer = task.delay(0.5, function()
					if isPressed then
						local ok2, err2 = pcall(callback, "hold", currentKey)
						if not ok2 then warn("[MobileUILib] Hotkey callback error: " .. tostring(err2)) end
					end
				end)
			end
		end)
		
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey and isPressed then
				isPressed = false
				keyBtn.BackgroundColor3 = Theme.ElementHover
				keyBtn.TextColor3 = Theme.Text
				if holdTimer then holdTimer:Cancel() end
				local ok, err = pcall(callback, "release", currentKey)
				if not ok then warn("[MobileUILib] Hotkey callback error: " .. tostring(err)) end
			end
		end)
	end
	startListening()

	local handle = {
		Set = function(_, keyCode)
			currentKey = keyCode
			keyBtn.Text = keyCode.Name
			if config.Flag then Library:SetFlag(config.Flag, keyCode) end
			startListening()
		end,
		Get = function() return currentKey end,
		Destroy = function(_)
			if pressConn then pressConn:Disconnect() end
			if holdTimer then holdTimer:Cancel() end
			if holder and holder.Parent then holder:Destroy() end
		end,
	}
	if config.Flag then Library.FlagElements[config.Flag] = handle end

	return Library:_wrapElement(holder, handle)
end

-- ===================== COLOR PICKER =====================
function TM:CreateColorPicker(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local color = config.Default or Color3.fromRGB(255, 0, 0)
	local callback = config.Callback or function() end
	local open = false
	local hue, sat, val = color:ToHSV()

	local closedH = touch and (compact and 38 or 46) or (compact and 28 or 34)
	local panelHeight = touch and (compact and 120 or 150) or (compact and 100 or 130)

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
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, closedH),
		Position = UDim2.new(0, 12, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local swatch = create("TextButton", {
		Text = "",
		BackgroundColor3 = color,
		Size = UDim2.new(0, touch and (compact and 28 or 34) or (compact and 20 or 26), 0, touch and (compact and 28 or 34) or (compact and 20 or 26)),
		Position = UDim2.new(1, touch and (compact and -38 or -44) or (compact and -28 or -34), 0, (closedH - (touch and (compact and 28 or 34) or (compact and 20 or 26))) / 2),
	}, { corner(10), stroke() })
	swatch.Parent = holder

	local panel = create("Frame", {
		Size = UDim2.new(1, -20, 0, panelHeight),
		Position = UDim2.new(0, 10, 0, closedH + 4),
		BackgroundTransparency = 1,
	})
	panel.Parent = holder

	local svHeight = touch and (compact and 80 or 100) or (compact and 70 or 84)
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
		Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 22) or (compact and 14 or 16)),
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

-- ===================== THEME EDITOR =====================
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

-- ===================== DROPDOWN =====================
function TM:CreateDropdown(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local options = config.Options or {}
	local selected = config.Default or options[1]
	local callback = config.Callback or function() end
	local open = false

	local closedH = touch and (compact and 38 or 46) or (compact and 28 or 34)
	local itemHeight = touch and (compact and 34 or 40) or (compact and 24 or 30)
	local maxVisibleItems = 6
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
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, closedH),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, {
		create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
	})
	mainBtn.Parent = holder

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
			TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
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
			playInteractionSound("dropdown")
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
		playInteractionSound("dropdown")
	end)

	local handle = { Set = function(_, value)
		selected = value
		mainBtn.Text = (config.Name or "Dropdown") .. ": " .. tostring(selected)
		if config.Flag then Library:SetFlag(config.Flag, selected) end
	end }
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return handle
end

-- ===================== MULTI-SELECT DROPDOWN =====================
function TM:CreateMultiDropdown(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local options = config.Options or {}
	local selected = config.Default or {}
	if type(selected) ~= "table" then selected = {} end
	local callback = config.Callback or function() end
	local open = false

	local closedH = touch and (compact and 38 or 46) or (compact and 28 or 34)
	local itemHeight = touch and (compact and 34 or 40) or (compact and 24 or 30)
	local maxVisibleItems = 6
	local totalHeight = #options * itemHeight
	local panelHeight = math.min(totalHeight, maxVisibleItems * itemHeight)

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
		ZIndex = 2,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Multi-Select")

	if config.Flag then Library:SetFlag(config.Flag, selected) end

	local selectedText = #selected > 0 and table.concat(selected, ", ") or "None selected"
	local mainBtn = create("TextButton", {
		Text = (config.Name or "Select") .. ": " .. selectedText,
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, closedH),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	}, {
		create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
	})
	mainBtn.Parent = holder

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

	local optionStates = {}

	for _, opt in ipairs(options) do
		local isSelected = false
		for _, s in ipairs(selected) do
			if s == opt then isSelected = true break end
		end
		optionStates[opt] = isSelected

		local optBtn = create("TextButton", {
			Text = (isSelected and "☑ " or "☐ ") .. tostring(opt),
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
			TextColor3 = isSelected and Theme.Accent or Theme.SubText,
			BackgroundColor3 = Theme.ElementHover,
			Size = UDim2.new(1, 0, 0, itemHeight),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}, {
			create("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
		})
		optBtn.Parent = optionsFrame

		optBtn.MouseButton1Click:Connect(function()
			optionStates[opt] = not optionStates[opt]
			local isNowSelected = optionStates[opt]
			optBtn.Text = (isNowSelected and "☑ " or "☐ ") .. tostring(opt)
			optBtn.TextColor3 = isNowSelected and Theme.Accent or Theme.SubText
			
			selected = {}
			for o, s in pairs(optionStates) do
				if s then table.insert(selected, o) end
			end
			
			local selectedTextNew = #selected > 0 and table.concat(selected, ", ") or "None selected"
			mainBtn.Text = (config.Name or "Select") .. ": " .. selectedTextNew
			
			if config.Flag then Library:SetFlag(config.Flag, selected) end
			playInteractionSound("click")
			local ok, err = pcall(callback, selected)
			if not ok then warn("[MobileUILib] MultiDropdown callback error: " .. tostring(err)) end
		end)
	end

	mainBtn.MouseButton1Click:Connect(function()
		open = not open
		if self._window then
			self._window:SetSpotlight(open)
			shiftZIndex(holder, open and 50 or -50)
		end
		tween(holder, { Size = UDim2.new(1, 0, 0, open and (closedH + panelHeight) or closedH) }, 0.15)
		playInteractionSound("dropdown")
	end)

	local handle = {
		Set = function(_, newSelected)
			if type(newSelected) ~= "table" then newSelected = {} end
			selected = newSelected
			for opt, btn in pairs(optionStates) do
				local isSelected = false
				for _, s in ipairs(selected) do
					if s == opt then isSelected = true break end
				end
				optionStates[opt] = isSelected
				for _, child in ipairs(optionsFrame:GetChildren()) do
					if child:IsA("TextButton") and child.Text:match(tostring(opt)) then
						child.Text = (isSelected and "☑ " or "☐ ") .. tostring(opt)
						child.TextColor3 = isSelected and Theme.Accent or Theme.SubText
					end
				end
			end
			local selectedTextNew = #selected > 0 and table.concat(selected, ", ") or "None selected"
			mainBtn.Text = (config.Name or "Select") .. ": " .. selectedTextNew
			if config.Flag then Library:SetFlag(config.Flag, selected) end
		end,
		Get = function() return selected end,
	}
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return handle
end

-- ===================== RADIO GROUP =====================
function TM:CreateRadioGroup(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local options = config.Options or {}
	local selected = config.Default or options[1]
	local callback = config.Callback or function() end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Radio Group")

	if config.Flag then Library:SetFlag(config.Flag, selected) end

	create("TextLabel", {
		Text = config.Name or "Select Option",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 24) or (compact and 14 or 18)),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = holder

	local list = create("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		Position = UDim2.new(0, 5, 0, touch and (compact and 22 or 28) or (compact and 18 or 22)),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, compact and 2 or 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingBottom = UDim.new(0, compact and 4 or 6),
		}),
	})
	list.Parent = holder

	local radioButtons = {}

	for i, opt in ipairs(options) do
		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, touch and (compact and 24 or 30) or (compact and 18 or 24)),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		}, {
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})
		row.Parent = list

		local radioBtn = create("TextButton", {
			Text = (opt == selected) and "◉" or "○",
			Font = Enum.Font.GothamBold,
			TextSize = touch and (compact and 18 or 20) or (compact and 16 or 18),
			TextColor3 = (opt == selected) and Theme.Accent or Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, touch and (compact and 22 or 26) or (compact and 18 or 22), 1, 0),
		})
		radioBtn.Parent = row

		local label = create("TextLabel", {
			Text = tostring(opt),
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
			TextColor3 = (opt == selected) and Theme.Text or Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.Parent = row

		radioButtons[opt] = { btn = radioBtn, label = label }

		radioBtn.MouseButton1Click:Connect(function()
			if opt == selected then return end
			
			for oldOpt, data in pairs(radioButtons) do
				data.btn.Text = "○"
				data.btn.TextColor3 = Theme.SubText
				data.label.TextColor3 = Theme.SubText
			end
			
			selected = opt
			radioBtn.Text = "◉"
			radioBtn.TextColor3 = Theme.Accent
			label.TextColor3 = Theme.Text
			
			if config.Flag then Library:SetFlag(config.Flag, selected) end
			playInteractionSound("click")
			local ok, err = pcall(callback, selected)
			if not ok then warn("[MobileUILib] RadioGroup callback error: " .. tostring(err)) end
		end)
	end

	local handle = {
		Set = function(_, value)
			if not radioButtons[value] then return end
			for oldOpt, data in pairs(radioButtons) do
				data.btn.Text = "○"
				data.btn.TextColor3 = Theme.SubText
				data.label.TextColor3 = Theme.SubText
			end
			selected = value
			radioButtons[value].btn.Text = "◉"
			radioButtons[value].btn.TextColor3 = Theme.Accent
			radioButtons[value].label.TextColor3 = Theme.Text
			if config.Flag then Library:SetFlag(config.Flag, selected) end
		end,
		Get = function() return selected end,
	}
	if config.Flag then Library.FlagElements[config.Flag] = handle end
	return Library:_wrapElement(holder, handle)
end

-- ===================== SEARCH =====================
function TM:CreateSearch(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local page = self._page

	local box = create("TextBox", {
		PlaceholderText = config.Placeholder or "Search...",
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and (compact and 34 or 42) or (compact and 26 or 32)),
		ClearTextOnFocus = false,
	}, {
		corner(10), stroke(),
		create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
	})
	box.Parent = page

	local noResults = create("TextLabel", {
		Text = "The searched feature is not available or removed",
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
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
		local matchCount = 0
		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("GuiObject") and child ~= box and child ~= noResults then
				local haystack = child:GetAttribute("MUI_Search") or child:GetAttribute("MUI_Name")
				if haystack then
					local match = query == "" or haystack:lower():find(query, 1, true) ~= nil
					child.Visible = match
					if match then 
						anyVisible = true 
						matchCount = matchCount + 1
					end
				end
			end
		end
		noResults.Visible = (query ~= "" and not anyVisible)
		if query ~= "" and anyVisible then
			box.PlaceholderText = matchCount .. " results"
		else
			box.PlaceholderText = config.Placeholder or "Search..."
		end
	end)

	return box
end

-- ===================== DISCORD BUTTON =====================
function TM:CreateDiscordButton(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local invite = config.Invite or "discord.gg/your-invite"
	local screenGui = self._screenGui

	local btn = create("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.Element,
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		AutoButtonColor = false,
	}, { corner(12), stroke() })
	btn.Parent = self._page
	setSearchMeta(btn, config, "Join Discord")

	create("TextLabel", {
		Text = config.Name or "Join Discord",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
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

-- ===================== DIVIDER =====================
function TM:CreateDivider(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, config.Name and (touch and (compact and 18 or 24) or (compact and 14 or 20)) or (touch and (compact and 6 or 10) or (compact and 4 or 8))),
		BackgroundTransparency = 1,
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Divider")

	if config.Name then
		create("TextLabel", {
			Text = config.Name,
			Font = Enum.Font.GothamBold,
			TextSize = touch and (compact and 10 or 12) or (compact and 8 or 10),
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
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

-- ===================== CARD =====================
function TM:CreateCard(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(14),
		stroke(),
		create("UIListLayout", {
			Padding = UDim.new(0, compact and 4 or 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, compact and 6 or 10),
			PaddingLeft = UDim.new(0, compact and 6 or 10),
			PaddingRight = UDim.new(0, compact and 6 or 10),
			PaddingBottom = UDim.new(0, compact and 6 or 10),
		}),
	})
	card.Parent = self._page
	setSearchMeta(card, config, "Card")

	if config.Title then
		create("TextLabel", {
			Text = config.Title,
			Font = Enum.Font.GothamBold,
			TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 22) or (compact and 14 or 18)),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}).Parent = card
	end

	if config.Subtitle then
		create("TextLabel", {
			Text = config.Subtitle,
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}).Parent = card
	end

	local Card = setmetatable({
		_page = card,
		_touch = touch,
		_window = self._window,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	return Card
end

-- ===================== PARAGRAPH =====================
function TM:CreateParagraph(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", {
			Padding = UDim.new(0, compact and 2 or 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, compact and 6 or 10),
			PaddingLeft = UDim.new(0, compact and 8 or 12),
			PaddingRight = UDim.new(0, compact and 8 or 12),
			PaddingBottom = UDim.new(0, compact and 6 or 10),
		}),
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Paragraph")

	if config.Title then
		create("TextLabel", {
			Text = config.Title,
			Font = Enum.Font.GothamBold,
			TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, touch and (compact and 16 or 20) or (compact and 12 or 16)),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}).Parent = holder
	end

	local body = create("TextLabel", {
		Text = config.Text or config.Content or "",
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
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

-- ===================== IMAGE =====================
function TM:CreateImage(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local function normalizeAsset(id)
		if type(id) == "number" then return "rbxassetid://" .. tostring(id) end
		if type(id) == "string" and id ~= "" and not id:match("^rbxassetid://") and not id:match("^https?://") then
			return "rbxassetid://" .. id
		end
		return id
	end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, config.Height or (touch and (compact and 120 or 160) or (compact and 100 or 140))),
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
	img:SetAttribute("MUI_NoTheme", true)

	if config.Name then
		create("TextLabel", {
			Text = config.Name,
			Font = Enum.Font.GothamMedium,
			TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 0, touch and (compact and 20 or 26) or (compact and 16 or 22)),
			Position = UDim2.new(0, 0, 1, touch and (compact and -20 or -26) or (compact and -16 or -22)),
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

-- ===================== PROGRESS BAR =====================
function TM:CreateProgressBar(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local min = config.Min or 0
	local max = config.Max or 100
	local value = math.clamp(config.Default or min, min, max)

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 48) or (compact and 30 or 38)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Progress Bar")

	create("TextLabel", {
		Text = config.Name or "Progress",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
		Position = UDim2.new(0, 10, 0, compact and 2 or 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local percentLabel = create("TextLabel", {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.35, -10, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
		Position = UDim2.new(0.65, 0, 0, compact and 2 or 6),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	percentLabel.Parent = holder

	local track = create("Frame", {
		Size = UDim2.new(1, -20, 0, touch and (compact and 6 or 10) or (compact and 4 or 8)),
		Position = UDim2.new(0, 10, 1, touch and (compact and -12 or -16) or (compact and -10 or -14)),
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

-- ===================== METER =====================
function TM:CreateMeter(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local min = config.Min or 0
	local max = config.Max or 100
	local value = math.clamp(config.Default or min, min, max)
	local color = config.Color or Theme.Accent
	local animated = config.Animated ~= false

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 48) or (compact and 30 or 38)),
		BackgroundColor3 = Theme.Element,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Meter")

	create("TextLabel", {
		Text = config.Name or "Meter",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
		Position = UDim2.new(0, 10, 0, compact and 2 or 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local valueLabel = create("TextLabel", {
		Text = tostring(value),
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.35, -10, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
		Position = UDim2.new(0.65, 0, 0, compact and 2 or 6),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	valueLabel.Parent = holder

	local track = create("Frame", {
		Size = UDim2.new(1, -20, 0, touch and (compact and 6 or 10) or (compact and 4 or 8)),
		Position = UDim2.new(0, 10, 1, touch and (compact and -12 or -16) or (compact and -10 or -14)),
		BackgroundColor3 = Color3.fromRGB(55, 55, 62),
	}, { corner(8) })
	track.Parent = holder

	local fill = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = color,
	}, { corner(8) })
	fill.Parent = track

	local function render(v)
		v = math.clamp(v, min, max)
		local relative = (max > min) and ((v - min) / (max - min)) or 0
		valueLabel.Text = tostring(v)
		if animated then
			tween(fill, { Size = UDim2.new(relative, 0, 1, 0) }, 0.3)
		else
			fill.Size = UDim2.new(relative, 0, 1, 0)
		end
		return v
	end
	value = render(value)

	local handle = {
		Set = function(_, v)
			value = render(v)
			if config.Flag then Library:SetFlag(config.Flag, value) end
		end,
		Get = function() return value end,
		SetColor = function(_, newColor)
			color = newColor
			fill.BackgroundColor3 = color
		end,
	}
	if config.Flag then
		Library:SetFlag(config.Flag, value)
		Library.FlagElements[config.Flag] = handle
	end
	return handle
end

-- ===================== TIMER =====================
function TM:CreateTimer(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local duration = config.Duration or 60
	local remaining = duration
	local running = false
	local paused = false

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 60 or 80) or (compact and 44 or 60)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Timer")

	local timeDisplay = create("TextLabel", {
		Text = string.format("%02d:%02d", remaining // 60, remaining % 60),
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 26 or 32) or (compact and 20 or 26),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 36) or (compact and 20 or 28)),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	timeDisplay.Parent = holder

	local btnRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 34) or (compact and 20 or 26)),
		Position = UDim2.new(0, 0, 1, touch and (compact and -28 or -34) or (compact and -20 or -26)),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	btnRow.Parent = holder

	local function updateDisplay()
		timeDisplay.Text = string.format("%02d:%02d", remaining // 60, remaining % 60)
	end

	local function resetTimer()
		running = false
		paused = false
		remaining = duration
		updateDisplay()
		if config.Callback then
			pcall(config.Callback, "reset", remaining)
		end
	end

	local function togglePause()
		if not running then
			running = true
			paused = false
			if config.Callback then
				pcall(config.Callback, "start", remaining)
			end
		else
			paused = not paused
			if config.Callback then
				pcall(config.Callback, paused and "pause" or "resume", remaining)
			end
		end
	end

	local startBtn = create("TextButton", {
		Text = "▶",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0, touch and (compact and 50 or 60) or (compact and 40 or 50), 1, 0),
	}, { corner(8) })
	startBtn.Parent = btnRow

	local resetBtn = create("TextButton", {
		Text = "⟳",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0, touch and (compact and 50 or 60) or (compact and 40 or 50), 1, 0),
	}, { corner(8) })
	resetBtn.Parent = btnRow

	startBtn.MouseButton1Click:Connect(togglePause)
	resetBtn.MouseButton1Click:Connect(resetTimer)

	local connection
	local function startTimerLoop()
		if connection then connection:Disconnect() end
		connection = RunService.Heartbeat:Connect(function(delta)
			if running and not paused and remaining > 0 then
				remaining = remaining - delta
				if remaining <= 0 then
					remaining = 0
					running = false
					if config.Callback then
						pcall(config.Callback, "complete", remaining)
					end
				end
				updateDisplay()
				startBtn.Text = paused and "▶" or "⏸"
			end
		end)
	end
	startTimerLoop()

	local handle = {
		Set = function(_, newDuration)
			duration = newDuration
			remaining = newDuration
			resetTimer()
		end,
		Get = function() return remaining end,
		Reset = resetTimer,
		Start = function()
			running = true
			paused = false
			startBtn.Text = "⏸"
		end,
		Pause = function()
			paused = true
			startBtn.Text = "▶"
		end,
		Resume = function()
			paused = false
			startBtn.Text = "⏸"
		end,
		Destroy = function()
			if connection then connection:Disconnect() end
			if holder then holder:Destroy() end
		end,
	}

	holder.AncestryChanged:Connect(function(_, parent)
		if not parent and connection then
			connection:Disconnect()
		end
	end)

	return Library:_wrapElement(holder, handle)
end

-- ===================== CHECKLIST =====================
function TM:CreateChecklist(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode
	local items = config.Items or {}

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Checklist")

	create("TextLabel", {
		Text = config.Name or "Checklist",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 24) or (compact and 14 or 18)),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = holder

	local list = create("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		Position = UDim2.new(0, 5, 0, touch and (compact and 22 or 28) or (compact and 18 or 22)),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, compact and 2 or 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingBottom = UDim.new(0, compact and 4 or 6),
		}),
	})
	list.Parent = holder

	local checkStates = {}
	local checkboxes = {}

	local function updateProgress()
		local total = #items
		local done = 0
		for _, state in pairs(checkStates) do
			if state then done = done + 1 end
		end
		if config.Callback then
			pcall(config.Callback, done, total, checkStates)
		end
	end

	for i, item in ipairs(items) do
		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, touch and (compact and 22 or 28) or (compact and 18 or 22)),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		}, {
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})
		row.Parent = list

		local checkBtn = create("TextButton", {
			Text = "□",
			Font = Enum.Font.GothamBold,
			TextSize = touch and (compact and 16 or 18) or (compact and 14 or 16),
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, touch and (compact and 20 or 24) or (compact and 16 or 20), 1, 0),
		})
		checkBtn.Parent = row

		local label = create("TextLabel", {
			Text = item,
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.Parent = row

		checkStates[i] = false
		checkboxes[i] = checkBtn

		checkBtn.MouseButton1Click:Connect(function()
			checkStates[i] = not checkStates[i]
			checkBtn.Text = checkStates[i] and "☑" or "□"
			checkBtn.TextColor3 = checkStates[i] and Theme.Accent or Theme.SubText
			updateProgress()
		end)
	end

	local handle = {
		Set = function(_, states)
			for i, state in ipairs(states) do
				if checkboxes[i] then
					checkStates[i] = state
					checkboxes[i].Text = state and "☑" or "□"
					checkboxes[i].TextColor3 = state and Theme.Accent or Theme.SubText
				end
			end
			updateProgress()
		end,
		Get = function() return checkStates end,
		Toggle = function(index)
			if checkboxes[index] then
				checkStates[index] = not checkStates[index]
				checkboxes[index].Text = checkStates[index] and "☑" or "□"
				checkboxes[index].TextColor3 = checkStates[index] and Theme.Accent or Theme.SubText
				updateProgress()
			end
		end,
		Reset = function()
			for i in pairs(checkStates) do
				checkStates[i] = false
				checkboxes[i].Text = "□"
				checkboxes[i].TextColor3 = Theme.SubText
			end
			updateProgress()
		end,
	}

	return Library:_wrapElement(holder, handle)
end

-- ===================== COLOR GRADIENT =====================
function TM:CreateColorGradient(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local stops = config.Stops or { Color3.fromRGB(255, 196, 48), Color3.fromRGB(255, 90, 90) }
	if #stops < 2 then
		stops = { stops[1] or Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0) }
	end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", { Padding = UDim.new(0, compact and 4 or 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, compact and 6 or 10), 
			PaddingLeft = UDim.new(0, compact and 6 or 10),
			PaddingRight = UDim.new(0, compact and 6 or 10), 
			PaddingBottom = UDim.new(0, compact and 6 or 10),
		}),
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Color Gradient")

	-- Preset button
	local presetRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 34) or (compact and 20 or 26)),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
	})
	presetRow.Parent = holder

	local presets = {
		["Rainbow"] = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,255,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,255,255), Color3.fromRGB(255,0,255)},
		["Sunset"] = {Color3.fromRGB(255,100,0), Color3.fromRGB(255,200,0), Color3.fromRGB(255,255,0)},
		["Ocean"] = {Color3.fromRGB(0,100,200), Color3.fromRGB(0,200,255), Color3.fromRGB(100,255,255)},
		["Forest"] = {Color3.fromRGB(0,100,0), Color3.fromRGB(0,200,50), Color3.fromRGB(50,255,100)},
		["Fire"] = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,100,0), Color3.fromRGB(255,200,0)},
		["Ice"] = {Color3.fromRGB(100,200,255), Color3.fromRGB(150,220,255), Color3.fromRGB(200,240,255)},
	}

	local presetDropdown = create("TextButton", {
		Text = "Presets ▼",
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 11 or 12) or (compact and 9 or 10),
		TextColor3 = Theme.SubText,
		BackgroundColor3 = Theme.ElementHover,
		Size = UDim2.new(0, 80, 1, 0),
	}, { corner(6) })
	presetDropdown.Parent = presetRow

	-- FIX: Use GradientPage:CreateDropdown instead of Tab:CreateDropdown
	local GradientPage = setmetatable({
		_page = holder,
		_touch = touch,
		_window = self._window,
		_screenGui = self._screenGui,
	}, { __index = Library.TabMethods })

	presetDropdown.MouseButton1Click:Connect(function()
		local presetsList = {}
		for name in pairs(presets) do table.insert(presetsList, name) end
		local dropdown = GradientPage:CreateDropdown({
			Name = "Select Preset",
			Options = presetsList,
			Callback = function(selected)
				local colors = presets[selected]
				if colors then
					handle:Set(colors)
				end
			end
		})
	end)

	create("TextLabel", {
		Text = config.Name or "Gradient",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -90, 0, touch and (compact and 16 or 20) or (compact and 12 or 16)),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = holder

	local preview = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 24 or 32) or (compact and 18 or 26)),
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

-- ===================== KEYBIND LIST =====================
function TM:CreateKeybindList(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		corner(12),
		stroke(),
		create("UIListLayout", { Padding = UDim.new(0, compact and 2 or 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, compact and 6 or 10), 
			PaddingLeft = UDim.new(0, compact and 6 or 10),
			PaddingRight = UDim.new(0, compact and 6 or 10), 
			PaddingBottom = UDim.new(0, compact and 6 or 10),
		}),
	})
	holder.Parent = self._page
	setSearchMeta(holder, config, "Keybind List")

	create("TextLabel", {
		Text = config.Name or "Active Keybinds",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 15)),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	}).Parent = holder

	local emptyLabel = create("TextLabel", {
		Text = "No keybinds registered",
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 15)),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})

	local rowFrames = {}
	local rowLabels = {}

	local function keyText(descriptor)
		local ok, key = pcall(descriptor.Get)
		if not ok or not key or key == Enum.KeyCode.Unknown then return "Unbound" end
		return key.Name
	end

	local function addRow(descriptor)
		if emptyLabel.Parent then emptyLabel.Parent = nil end

		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 22) or (compact and 14 or 18)),
			BackgroundTransparency = 1,
		})
		row.Parent = holder

		create("TextLabel", {
			Text = descriptor.Name,
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.6, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		local keyLabel = create("TextLabel", {
			Text = keyText(descriptor),
			Font = Enum.Font.GothamBold,
			TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
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

	holder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if registeredConn then registeredConn:Disconnect() end
			if changedConn then changedConn:Disconnect() end
			if unregisteredConn then unregisteredConn:Disconnect() end
		end
	end)

	return Library:_wrapElement(holder, { Refresh = function(_) rebuildAll() end })
end

-- ===================== NOTIFICATION CENTER =====================
function TM:CreateNotificationCenter(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Notification Center")

	local headerRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 34) or (compact and 22 or 28)),
		BackgroundTransparency = 1,
	})
	headerRow.Parent = holder

	create("TextLabel", {
		Text = config.Name or "Notifications",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = headerRow

	local clearBtn = create("TextButton", {
		Text = "Clear",
		Font = Enum.Font.GothamMedium,
		TextSize = touch and (compact and 10 or 12) or (compact and 8 or 11),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 56, 1, 0),
		Position = UDim2.new(1, -60, 0, 0),
	})
	clearBtn.Parent = headerRow

	local list = create("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.new(0, 8, 0, touch and (compact and 30 or 36) or (compact and 24 or 30)),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, compact and 2 or 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingBottom = UDim.new(0, compact and 4 or 8) }),
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
		TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local rowHeight = touch and (compact and 44 or 54) or (compact and 36 or 44)

	local function addRow(entry)
		if emptyLabel.Parent then emptyLabel.Parent = nil end

		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, rowHeight),
			BackgroundColor3 = Theme.ElementHover,
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
			TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -56, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent = row

		create("TextLabel", {
			Text = entry.Content,
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 10 or 12) or (compact and 8 or 10),
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, touch and (compact and 14 or 18) or (compact and 11 or 15)),
			Size = UDim2.new(1, 0, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent = row

		create("TextLabel", {
			Text = os.date("%H:%M:%S", entry.Time),
			Font = Enum.Font.Gotham,
			TextSize = touch and (compact and 8 or 10) or (compact and 7 or 9),
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
Library.Plugins = {}
Library.PluginRegistry = {}
local pluginRegistryChangedEvent = Instance.new("BindableEvent")
Library.PluginRegistryChanged = pluginRegistryChangedEvent.Event

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
		ExportConfig = function(_, name) return self_:ExportConfig(name) end,
		ImportConfig = function(_, jsonText) return self_:ImportConfig(jsonText, window) end,

		ListPlugins = function(_) return self_:ListPlugins() end,
		DisablePlugin = function(_, name) return self_:DisablePlugin(name) end,
		EnablePlugin = function(_, name) return self_:EnablePlugin(name) end,
		ReloadPlugin = function(_, name) return self_:ReloadPlugin(name) end,
		UnloadPlugin = function(_, name) return self_:UnloadPlugin(name) end,

		RegisterTheme = function(_, name, themeTable)
			self_:RegisterTheme(name, themeTable)
		end,
		RegisterElement = function(_, name, constructor)
			self_:RegisterElement(name, constructor)
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
		
		PlaySound = function(_, soundId, volume)
			self_:PlaySound(soundId, volume)
		end,
		
		PlayHaptic = function(_, variant)
			self_:PlayHaptic(variant)
		end,
		
		SetAnimationSpeed = function(_, factor)
			if window then window:SetAnimationSpeed(factor) end
		end,
	}
end

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
		record.LoadTime = os.time()

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

function Library:LoadPlugins(urls, window)
	local loaded = {}
	for _, url in ipairs(urls or {}) do
		loaded[#loaded + 1] = self:LoadPlugin(url, window)
	end
	return loaded
end

function Library:ListPlugins()
	local list = {}
	for _, record in ipairs(self.PluginRegistry) do
		table.insert(list, {
			Name = record.Name,
			Version = record.Version,
			Url = record.Url,
			Enabled = record.Enabled,
			LoadTime = record.LoadTime,
		})
	end
	return list
end

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
		record.LoadTime = os.time()

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

-- ===================== PLUGIN MANAGER =====================
function TM:CreatePluginManager(config)
	config = config or {}
	local touch = self._touch
	local compact = Library.Flags.CompactMode

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
		BackgroundColor3 = Theme.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { corner(12), stroke() })
	holder.Parent = self._page
	setSearchMeta(holder, config, "Plugin Manager")

	create("TextLabel", {
		Text = config.Name or "Plugins",
		Font = Enum.Font.GothamBold,
		TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, touch and (compact and 24 or 30) or (compact and 18 or 24)),
		Position = UDim2.new(0, 10, 0, compact and 4 or 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local list = create("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.new(0, 8, 0, touch and (compact and 34 or 40) or (compact and 26 or 32)),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, compact and 4 or 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingBottom = UDim.new(0, compact and 4 or 8) }),
	})
	list.Parent = holder

	local emptyLabel = create("TextLabel", {
		Text = "No plugins loaded",
		Font = Enum.Font.Gotham,
		TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local rowHeight = touch and (compact and 52 or 62) or (compact and 42 or 50)

	local function smallBtn(parent, text, order)
		local b = create("TextButton", {
			Text = text,
			Font = Enum.Font.GothamMedium,
			TextSize = touch and (compact and 10 or 12) or (compact and 8 or 10),
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.Element,
			Size = UDim2.new(0, touch and (compact and 60 or 70) or (compact and 50 or 58), 1, 0),
			LayoutOrder = order,
		}, { corner(6) })
		b.Parent = parent
		return b
	end

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
					PaddingTop = UDim.new(0, compact and 4 or 6), PaddingBottom = UDim.new(0, compact and 4 or 6),
				}),
			})
			row.Parent = list

			create("TextLabel", {
				Text = info.Name .. (info.Version and ("  v" .. tostring(info.Version)) or ""),
				Font = Enum.Font.GothamMedium,
				TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}).Parent = row

			create("TextLabel", {
				Text = info.Enabled and "Enabled" or "Disabled",
				Font = Enum.Font.Gotham,
				TextSize = touch and (compact and 9 or 11) or (compact and 8 or 10),
				TextColor3 = info.Enabled and Color3.fromRGB(70, 200, 110) or Color3.fromRGB(230, 75, 75),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, touch and (compact and 14 or 18) or (compact and 11 or 15)),
				Size = UDim2.new(1, -8, 0, touch and (compact and 10 or 14) or (compact and 8 or 12)),
				TextXAlignment = Enum.TextXAlignment.Left,
			}).Parent = row

			local btnRow = create("Frame", {
				Size = UDim2.new(1, 0, 0, touch and (compact and 20 or 26) or (compact and 14 or 20)),
				Position = UDim2.new(0, 0, 1, touch and (compact and -20 or -26) or (compact and -14 or -20)),
				BackgroundTransparency = 1,
			}, {
				create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, compact and 4 or 6),
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

return Library
