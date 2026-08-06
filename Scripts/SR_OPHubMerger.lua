--[[
	OP Slap Royale — CornUi v1.9.1b Port
	
	Features:
	- Main tab: Code search, Teleport Menu, Early Bus Jump, Infinite Jump, ESP, Auto Rejoin, Recommended Settings
	- Items tab: Auto collect, Auto pick up, Auto Heal, Auto Sort, Auto Use Permanent Items, Item usage buttons
	- Teleports tab: School Bus teleport
	- Combat tab: Hitbox Size, Expand Hitbox, Visualize Hitboxes, Slap Aura, Auto Slap, Player teleports
	- BETA tab: Collect Crates, Auto collect crates, Crate Aura, Early Auto Collect
	- Safety tab: Auto optimize cooldown, Anti-Staff, Hide under map, Anti-Ragdoll
	- Settings tab: Custom strikes, TP Debounce, F Lock, Disable Notifications, Theme
	
	Optimizations:
	- Removed redundant UI wrappers
	- Consolidated event listeners
	- Improved memory management
	- Reduced redundant function calls
	- Cached frequently accessed objects
]]

-- ============================================================
-- SERVICES & SETUP
-- ============================================================

local Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),
	MarketplaceService = game:GetService("MarketplaceService"),
	ContextActionService = game:GetService("ContextActionService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	TeleportService = game:GetService("TeleportService"),
	GuiService = game:GetService("GuiService"),
	ProximityPromptService = game:GetService("ProximityPromptService"),
	HttpService = game:GetService("HttpService"),
	VirtualInputManager = game:GetService("VirtualInputManager"),
}

local Players = Services.Players
local RunService = Services.RunService
local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local MarketplaceService = Services.MarketplaceService
local ContextActionService = Services.ContextActionService
local ReplicatedStorage = Services.ReplicatedStorage
local TeleportService = Services.TeleportService
local GuiService = Services.GuiService
local ProximityPromptService = Services.ProximityPromptService
local HttpService = Services.HttpService
local VirtualInputManager = Services.VirtualInputManager

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- CORNUI SETUP
-- ============================================================

local Corn = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"))()
local Window = Corn:CreateWindow({
	Name = "OP Slap Royale",
	Subtitle = "Made by- SlapSnyte, AstroLord, Allure, Interscription",
	Theme = "Ocean",
	Icon = 80406291512141, 
})

local MainTab = Window:CreateTab("Main")
local ItemsTab = Window:CreateTab("Items")
local TeleportsTab = Window:CreateTab("Teleports")
local CombatTab = Window:CreateTab("Combat")
local BETATab = Window:CreateTab("BETA")
local SafetyTab = Window:CreateTab("Safety")
local SettingsTab = Window:CreateTab("Settings")

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================

local NotificationsDisabled = false

local function Notify(title, content, type, duration)
	if NotificationsDisabled then return end
	Window:Notify({
		Title = title or "OP Slap Royale",
		Content = content or "",
		Type = type or "info",
		Duration = duration or 3.5,
	})
end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

local function normalizeName(text)
	return string.lower(tostring(text):gsub("’", "'"))
end

local function getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(660, 430)
end

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getRoot(character)
	character = character or getCharacter()
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
	character = character or getCharacter()
	return character:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- UNDER MAP PLATFORM
-- ============================================================

local UNDER_MAP_PLATFORM_Y = -35
local UNDER_MAP_PLATFORM_THICKNESS = 0.2
local UNDER_MAP_SAFE_OFFSET = 4
local UNDER_MAP_PLATFORM_SIZE = Vector3.new(12000, UNDER_MAP_PLATFORM_THICKNESS, 12000)
local UnderMapSafetyPlatform = nil

local function isUnderMapSafetyPlatform(object)
	return object:IsA("BasePart")
		and object.Name == "Part"
		and object.Transparency >= 1
		and object.Anchored
		and math.abs(object.Position.Y - UNDER_MAP_PLATFORM_Y) <= 1
		and object.Size.X >= UNDER_MAP_PLATFORM_SIZE.X * 0.9
		and object.Size.Z >= UNDER_MAP_PLATFORM_SIZE.Z * 0.9
end

local function clearUnderMapSafetyPlatform()
	if UnderMapSafetyPlatform and UnderMapSafetyPlatform.Parent then
		UnderMapSafetyPlatform.CanCollide = false
		UnderMapSafetyPlatform.CanTouch = false
		UnderMapSafetyPlatform.CanQuery = false
	end

	for _, object in ipairs(workspace:GetChildren()) do
		if isUnderMapSafetyPlatform(object) then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		end
	end

	UnderMapSafetyPlatform = nil
end

local function ensureUnderMapSafetyPlatform()
	if UnderMapSafetyPlatform and UnderMapSafetyPlatform.Parent then
		return UnderMapSafetyPlatform
	end

	for _, object in ipairs(workspace:GetChildren()) do
		if isUnderMapSafetyPlatform(object) then
			UnderMapSafetyPlatform = object
			return object
		end
	end

	local platform = Instance.new("Part")
	platform.Name = "Part"
	platform.Size = UNDER_MAP_PLATFORM_SIZE
	platform.Position = Vector3.new(0, UNDER_MAP_PLATFORM_Y, 0)
	platform.Anchored = true
	platform.CanCollide = false
	platform.CanTouch = false
	platform.CanQuery = false
	platform.Transparency = 1
	platform.Material = Enum.Material.SmoothPlastic
	platform.Parent = workspace

	UnderMapSafetyPlatform = platform
	return platform
end

clearUnderMapSafetyPlatform()

-- ============================================================
-- MAIN FEATURES — Code & Barn
-- ============================================================

local CodeKeywords = {
	"math", "equation", "problem", "code", "puzzle",
	"question", "solve", "answer", "number"
}

local CodeSearchOrigin = Vector3.new(464, 29, 323)
local CodeSearchRadius = 180
local KeypadSearchRadius = 170

function MainGetPuzzleSearchRoots()
	local roots = {}
	local seen = {}

	local function addRoot(object)
		if object and not seen[object] then
			seen[object] = true
			table.insert(roots, object)
		end
	end

	local map = workspace:FindFirstChild("Map")
	if map then
		for _, object in ipairs(map:GetChildren()) do
			local lower = string.lower(object.Name)
			for _, word in ipairs(CodeKeywords) do
				if string.find(lower, word, 1, true) then
					addRoot(object)
					break
				end
			end
		end
	end

	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(CodeSearchOrigin, CodeSearchRadius)
	end)

	if ok and parts then
		for _, part in ipairs(parts) do
			local object = part
			local chosen = nil

			while object and object ~= workspace do
				if (object:IsA("Folder") or object:IsA("Model")) then
					local lower = string.lower(object.Name)
					for _, word in ipairs(CodeKeywords) do
						if string.find(lower, word, 1, true) then
							chosen = object
							break
						end
					end
				end
				if chosen then break end
				object = object.Parent
			end

			addRoot(chosen or part)
		end
	end

	return roots
end

function MainGetPuzzleCode()
	local found = {}
	local ids = {}

	local function isRelevant(object)
		local full = string.lower(object:GetFullName())
		local name = string.lower(object.Name)
		for _, word in ipairs(CodeKeywords) do
			if string.find(full, word) or string.find(name, word) then
				return true
			end
		end
		return false
	end

	for _, root in ipairs(MainGetPuzzleSearchRoots()) do
		for _, object in ipairs(root:GetDescendants()) do
			local image = nil
			if object:IsA("ImageLabel") or object:IsA("ImageButton") then
				image = object.Image
			elseif object:IsA("Decal") or object:IsA("Texture") then
				image = object.Texture
			end

			if image and image ~= "" and isRelevant(object) then
				local id = tonumber(string.match(image, "%d+"))
				if id and not found[id] then
					found[id] = true
					table.insert(ids, id)
				end
			end
		end
	end

	local code = ""
	for _, id in ipairs(ids) do
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id)
		end)
		if ok and info and info.Name then
			local text = info.Name
			local exactNumber = string.match(text, "^%s*(%d+)%s*$")
			if exactNumber and #exactNumber <= 4 then
				code = code .. exactNumber
			else
				local labeled = string.match(text, "^%s*[Nn]umber%s*(%d)%s*$") or string.match(text, "^%s*[Dd]igit%s*(%d)%s*$")
				if labeled then code = code .. labeled end
			end
		end
	end

	return code
end

function MainGetBarnKeypadButtonText(object)
	local text = tostring(object.Name or "")
	local scanned = 0
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			text = text .. " " .. tostring(descendant.Text)
		end
		scanned = scanned + 1
		if scanned >= 120 then break end
	end
	return string.lower(text)
end

function MainTextMatchesDigit(text, digit)
	text = string.lower(tostring(text or ""))
	digit = tostring(digit)
	return text == digit
		or string.find(text, "number%s*" .. digit) ~= nil
		or string.find(text, "digit%s*" .. digit) ~= nil
		or string.find(text, "button%s*" .. digit) ~= nil
		or string.find(text, "key%s*" .. digit) ~= nil
		or string.find(text, "%f[%d]" .. digit .. "%f[%D]") ~= nil
end

function MainIsBarnSubmitButton(object, text)
	text = string.lower(tostring(text or object.Name or ""))
	if string.find(text, "green", 1, true)
		or string.find(text, "enter", 1, true)
		or string.find(text, "submit", 1, true)
		or string.find(text, "confirm", 1, true)
		or string.find(text, "accept", 1, true)
		or string.find(text, "check", 1, true) then
		return true
	end
	if object:IsA("BasePart") then
		local color = object.Color
		return color.G > 0.45 and color.G > color.R * 1.3 and color.G > color.B * 1.3
	end
	return false
end

function MainGetBarnKeypadSearchObjects()
	local objects = {}
	local seen = {}

	local function add(object)
		if object and object.Parent and not seen[object] then
			seen[object] = true
			table.insert(objects, object)
		end
	end

	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(CodeSearchOrigin, KeypadSearchRadius)
	end)

	if ok and parts then
		for _, part in ipairs(parts) do
			add(part)
			local current = part.Parent
			local depth = 0
			while current and current ~= workspace and depth < 4 do
				add(current)
				current = current.Parent
				depth = depth + 1
			end
		end
	end

	return objects
end

function MainFindBarnKeypadButton(target, isSubmit)
	local bestObject = nil
	local bestScore = -1

	for _, object in ipairs(MainGetBarnKeypadSearchObjects()) do
		local text = MainGetBarnKeypadButtonText(object)
		local full = string.lower(object:GetFullName())
		local score = -1

		if isSubmit then
			if MainIsBarnSubmitButton(object, text) then
				score = 25
			end
		elseif MainTextMatchesDigit(text, target) then
			score = 25
		end

		if score > 0 then
			if string.find(full, "keypad", 1, true) then score = score + 8 end
			if string.find(full, "button", 1, true) then score = score + 5 end
			if string.find(full, "barn", 1, true) then score = score + 4 end
			if object:IsA("BasePart") then score = score + 2 end
			if score > bestScore then
				bestScore = score
				bestObject = object
			end
		end
	end

	return bestObject
end

function MainActivateBarnKeypadButton(button)
	if not button or not button.Parent then return false end
	local clicked = false

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("ClickDetector") and type(fireclickdetector) == "function" then
			pcall(function() fireclickdetector(descendant) clicked = true end)
		elseif descendant:IsA("ProximityPrompt") then
			pcall(function()
				if type(fireproximityprompt) == "function" then
					fireproximityprompt(descendant)
				else
					descendant:InputHoldBegin()
					task.wait(math.max(descendant.HoldDuration, 0.05))
					descendant:InputHoldEnd()
				end
				clicked = true
			end)
		end
	end

	if button:IsA("ClickDetector") and type(fireclickdetector) == "function" then
		pcall(function() fireclickdetector(button) clicked = true end)
	elseif button:IsA("ProximityPrompt") then
		pcall(function()
			if type(fireproximityprompt) == "function" then
				fireproximityprompt(button)
			else
				button:InputHoldBegin()
				task.wait(math.max(button.HoldDuration, 0.05))
				button:InputHoldEnd()
			end
			clicked = true
		end)
	elseif button:IsA("BasePart") and type(firetouchinterest) == "function" then
		local root = getRoot()
		if root then
			pcall(function()
				firetouchinterest(root, button, 0)
				task.wait(0.04)
				firetouchinterest(root, button, 1)
				clicked = true
			end)
		end
	end

	return clicked
end

function MainEnterBarnKeypadCode(code)
	code = tostring(code or ""):gsub("%D", "")
	if code == "" then return false end

	local pressed = 0
	for digit in string.gmatch(code, "%d") do
		local button = MainFindBarnKeypadButton(digit, false)
		if not MainActivateBarnKeypadButton(button) then
			return false
		end
		pressed = pressed + 1
		task.wait(0.09)
	end

	local submitButton = MainFindBarnKeypadButton(nil, true)
	if not MainActivateBarnKeypadButton(submitButton) then
		return false
	end

	return pressed == #code
end

-- ============================================================
-- TELEPORT SYSTEM
-- ============================================================

local Teleport = {
	DefaultMaxStrikes = 4,
	DefaultCooldown = 3.5,
	DefaultDebounce = 0.5,
	DefaultPostFLock = 0.2,
	MaxStrikes = 4,
	Cooldown = 3.5,
	Debounce = 0.5,
	PostFLock = 0.2,
	Strikes = 0,
	LockedUntil = 0,
	LastClickAt = 0,
	BlockFUntil = 0,
	StabilityWait = 4,
	LastJumpAt = 0,
	LastRagdolledAt = 0,
	LastBusLandingAt = 0,
	StabilityCheckInterval = 0.3,
	LastStabilityCheckAt = 0,
	StabilityConnection = nil,
	BusTopRidePlatform = nil,
	BusTopRideConnection = nil,
	BusTopRideLastCFrame = nil,
	Locations = {
		{ Name = "Acid", Position = Vector3.new(-113, 14, -625) },
		{ Name = "Barn", Position = Vector3.new(477, 87, 318) },
		{ Name = "Beach", Position = Vector3.new(-463, 13, -702) },
		{ Name = "Bob Cave", Position = Vector3.new(315, 49, -576) },
		{ Name = "Bone Pit", Position = Vector3.new(-344, -150, -414) },
		{ Name = "Bunker", Position = Vector3.new(464, 29, 323) },
		{ Name = "Crystal", Position = Vector3.new(488, -50, -272) },
		{ Name = "Forest", Position = Vector3.new(7, 18, 4) },
		{ Name = "Lighthouse", Position = Vector3.new(113, 14, -625) },
		{ Name = "Saloon", Position = Vector3.new(-576, 17, -188) },
		{ Name = "School", Position = Vector3.new(494, 47, -322) },
		{ Name = "Shop", Position = Vector3.new(-575, 13, -481) },
		{ Name = "Towers", Position = Vector3.new(-31, 93, 428) },
		{ Name = "Tunnels", Position = Vector3.new(-561, -35, -234) },
		{ Name = "Volcano", Position = Vector3.new(-304, -26, 379) },
		{ Name = "Watch Tower", Position = Vector3.new(78, 124, 101) },
	},
}

function Teleport:GetCooldownLeft()
	return math.max(0, math.ceil(self.LockedUntil - os.clock()))
end

function Teleport:IsLocked()
	return os.clock() < self.LockedUntil
end

function Teleport:ResetStrikesIfReady()
	if self.LastClickAt == 0 or os.clock() - self.LastClickAt >= self.Cooldown then
		self.Strikes = 0
		self.LockedUntil = 0
	end
end

function Teleport:ShowWarning(secondsText)
	Notify("Cooldown", "Wait " .. secondsText .. " before teleporting again.", "warning", 2.2)
end

function Teleport:ShowStabilityWarning(reason, secondsLeft)
	Notify("Teleport", reason .. " Wait " .. tostring(math.max(1, math.ceil(secondsLeft))) .. " seconds.", "warning", 2.2)
end

function Teleport:IsRagdolled(character, humanoid)
	if not character or not humanoid then return false end

	local ragdollStatuses = {"Ragdoll", "Ragdolled", "IsRagdolled", "Knocked", "KnockedDown", "Downed"}
	for _, statusName in ipairs(ragdollStatuses) do
		if character:GetAttribute(statusName) == true or humanoid:GetAttribute(statusName) == true then
			return true
		end
	end

	local state = humanoid:GetState()
	return humanoid.PlatformStand
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown
end

function Teleport:UpdateLocalStability()
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	local root = getRoot(character)
	local now = os.clock()

	if not humanoid or not root or humanoid.Health <= 0 then
		self.LastRagdolledAt = now
		return
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		self.LastJumpAt = now
	end

	if self:IsRagdolled(character, humanoid) then
		self.LastRagdolledAt = now
	end
end

function Teleport:StartStabilityWatcher()
	if self.StabilityConnection then return end
	self.StabilityConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - self.LastStabilityCheckAt < self.StabilityCheckInterval then return end
		self.LastStabilityCheckAt = now
		self:UpdateLocalStability()
	end)
end

function Teleport:StopStabilityWatcher()
	if self.StabilityConnection then
		self.StabilityConnection:Disconnect()
		self.StabilityConnection = nil
	end
end

function Teleport:CanPassStabilityGate()
	local now = os.clock()
	local waitTime = self.StabilityWait or 4

	local jumpLeft = waitTime - (now - (self.LastJumpAt or 0))
	if jumpLeft > 0 then
		self:ShowStabilityWarning("Wait after jumping before teleporting.", jumpLeft)
		return false
	end

	local ragdollLeft = waitTime - (now - (self.LastRagdolledAt or now))
	if ragdollLeft > 0 then
		self:ShowStabilityWarning("Recover from ragdoll before teleporting.", ragdollLeft)
		return false
	end

	local busLandingLeft = waitTime - (now - (self.LastBusLandingAt or 0))
	if busLandingLeft > 0 then
		self:ShowStabilityWarning("Wait after landing from the bus.", busLandingLeft)
		return false
	end

	return true
end

function Teleport:CanTeleport(debounceOverride, ignoreStability, silent)
	if not ignoreStability and not self:CanPassStabilityGate() then
		return false
	end

	if self:IsLocked() then
		if not silent then
			self:ShowWarning(tostring(self:GetCooldownLeft()))
		end
		return false
	end

	local now = os.clock()
	local debounce = debounceOverride or self.Debounce
	local lastClickAt = self.LastClickAt
	local debounceLeft = debounce - (now - lastClickAt)

	if lastClickAt ~= 0 and debounceLeft > 0 then
		if not silent then
			self:ShowWarning(tostring(math.max(1, math.ceil(debounceLeft))))
		end
		return false
	end

	self:ResetStrikesIfReady()
	return true
end

function Teleport:AddStrike()
	self.LastClickAt = os.clock()
	self.Strikes = self.Strikes + 1
	if self.Strikes >= self.MaxStrikes then
		self.LockedUntil = os.clock() + self.Cooldown
		self.Strikes = 0
	end
end

function Teleport:StartFBlock(duration)
	local fLockDuration = duration or self.PostFLock
	local unlockAt = os.clock() + fLockDuration
	self.BlockFUntil = math.max(self.BlockFUntil or 0, unlockAt)
	self:RefreshPickupLock()
end

function Teleport:RefreshPickupLock()
	local unlockAt = self.BlockFUntil
	pcall(function() ProximityPromptService.Enabled = false end)
	task.delay(math.max(0.05, unlockAt - os.clock()), function()
		if self.BlockFUntil <= unlockAt + 0.02 then
			pcall(function() ProximityPromptService.Enabled = true end)
		end
	end)
end

function Teleport:ShowFBlockedWarning()
	local secondsLeft = math.max(0.1, self.BlockFUntil - os.clock())
	Notify("Cooldown", "Wait " .. string.format("%.1f", secondsLeft) .. " seconds before pressing F again.", "warning", 1.4)
end

function Teleport:MoveRoot(root, targetCFrame, lookAtPosition)
	if not root then return end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	if lookAtPosition then
		local flatLookAt = Vector3.new(lookAtPosition.X, targetCFrame.Position.Y, lookAtPosition.Z)
		if (flatLookAt - targetCFrame.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(targetCFrame.Position, flatLookAt)
		else
			root.CFrame = CFrame.new(targetCFrame.Position)
		end
	else
		local _, yRotation, _ = root.CFrame:ToOrientation()
		root.CFrame = CFrame.new(targetCFrame.Position) * CFrame.Angles(0, yRotation, 0)
	end

	task.wait()
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function Teleport:GetGroundCFrame(position, excludeInstances, stayClose)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeInstances or {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excludeInstances or {}

	local function hasRoom(candidatePosition)
		local touching = workspace:GetPartBoundsInBox(CFrame.new(candidatePosition + Vector3.new(0, 2, 0)), Vector3.new(4, 5, 4), overlapParams)
		for _, part in ipairs(touching) do
			if part.CanCollide and part.Transparency < 0.95 then
				return false
			end
		end
		return true
	end

	local offsets = stayClose and {
		Vector3.zero,
		Vector3.new(2, 0, 0), Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2), Vector3.new(0, 0, -2),
		Vector3.new(3, 0, 3), Vector3.new(-3, 0, 3),
		Vector3.new(3, 0, -3), Vector3.new(-3, 0, -3)
	} or {
		Vector3.zero,
		Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0),
		Vector3.new(0, 0, 6), Vector3.new(0, 0, -6),
		Vector3.new(8, 0, 8), Vector3.new(-8, 0, 8),
		Vector3.new(8, 0, -8), Vector3.new(-8, 0, -8)
	}

	for _, offset in ipairs(offsets) do
		local rayOrigin = position + offset + Vector3.new(0, 6, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -90, 0), params)
		local candidatePosition = result and (result.Position + Vector3.new(0, 4, 0)) or (position + offset + Vector3.new(0, 4, 0))
		if hasRoom(candidatePosition) then
			return CFrame.new(candidatePosition)
		end
	end

	return CFrame.new(position + Vector3.new(0, 4, 0))
end

function Teleport:ToLocation(locationName, position, forceTeleport)
	if forceTeleport then
		self.LockedUntil = 0
		self.LastClickAt = 0
		self.Strikes = 0
	elseif not self:CanTeleport() then
		return
	end

	if typeof(position) == "CFrame" then
		position = position.Position
	end

	if typeof(position) ~= "Vector3" then
		for _, loc in ipairs(self.Locations) do
			if loc.Name == locationName then
				position = loc.Position
				break
			end
		end
	end

	if typeof(position) ~= "Vector3" then
		Notify("Teleport", "Could not find location: " .. tostring(locationName), "error")
		return
	end

	local character = getCharacter()
	local root = getRoot(character)
	if not root then
		Notify("Teleport", "Could not find your character.", "error")
		return
	end

	local groundCFrame = self:GetGroundCFrame(position, { character })
	self:MoveRoot(root, groundCFrame)

	if not forceTeleport then
		self:AddStrike()
		self:StartFBlock()
	end

	Notify("Teleport", "Teleported to " .. locationName, "success")
end

-- ============================================================
-- BUS TELEPORT
-- ============================================================

function Teleport:GetBusCandidateFromObject(object)
	local current = object
	local candidate = nil
	while current and current ~= workspace do
		if string.find(normalizeName(current.Name), "bus", 1, true) and (current:IsA("Model") or current:IsA("BasePart")) then
			candidate = current
		end
		current = current.Parent
	end
	return candidate
end

function Teleport:GetBusParts(candidate)
	local parts = {}
	if not candidate or not candidate.Parent then return parts end
	if candidate:IsA("BasePart") then
		table.insert(parts, candidate)
		return parts
	end
	for _, object in ipairs(candidate:GetDescendants()) do
		if object:IsA("BasePart") then
			table.insert(parts, object)
		end
	end
	return parts
end

function Teleport:IsSchoolHouseBusCandidate(candidate)
	local position = nil
	if candidate:IsA("BasePart") then
		position = candidate.Position
	elseif candidate:IsA("Model") then
		local ok, pivot = pcall(function() return candidate:GetPivot() end)
		if ok then position = pivot.Position end
	end
	return position and (position - Vector3.new(494, 47, -322)).Magnitude <= 220
end

function Teleport:FindSchoolBusTopTarget()
	local character = getCharacter()
	local root = getRoot(character)
	local seen = {}
	local bestCandidate = nil
	local bestParts = nil
	local bestDistance = math.huge

	for _, object in ipairs(workspace:GetDescendants()) do
		local candidate = self:GetBusCandidateFromObject(object)
		if candidate and candidate.Parent and not seen[candidate] and not self:IsSchoolHouseBusCandidate(candidate) then
			seen[candidate] = true
			local parts = self:GetBusParts(candidate)
			local position = nil
			if candidate:IsA("BasePart") then
				position = candidate.Position
			elseif candidate:IsA("Model") then
				local ok, pivot = pcall(function() return candidate:GetPivot() end)
				if ok then position = pivot.Position end
			end
			if #parts > 0 and position then
				local distance = root and (root.Position - position).Magnitude or 0
				if distance < bestDistance then
					bestDistance = distance
					bestCandidate = candidate
					bestParts = parts
				end
			end
		end
	end

	return bestCandidate, bestParts
end

function Teleport:ClearBusTopRidePlatform()
	if self.BusTopRideConnection then
		self.BusTopRideConnection:Disconnect()
		self.BusTopRideConnection = nil
	end
	if self.BusTopRidePlatform and self.BusTopRidePlatform.Parent then
		self.BusTopRidePlatform:Destroy()
	end
	self.BusTopRidePlatform = nil
	self.BusTopRideLastCFrame = nil
end

function Teleport:CreateBusTopRidePlatform(candidate, parts, platformCFrame, topPart)
	self:ClearBusTopRidePlatform()
	if not platformCFrame then return end

	local platform = Instance.new("Part")
	platform.Name = "Part"
	platform.Size = Vector3.new(18, 0.3, 18)
	platform.CFrame = platformCFrame
	platform.Anchored = topPart == nil
	platform.Massless = true
	platform.CanCollide = true
	platform.CanTouch = false
	platform.CanQuery = false
	platform.Transparency = 1
	platform.Material = Enum.Material.SmoothPlastic
	platform.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1, 0, 100, 0)
	platform.Parent = workspace

	if topPart and topPart.Parent then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "Part"
		weld.Part0 = platform
		weld.Part1 = topPart
		weld.Parent = platform
	end

	self.BusTopRidePlatform = platform
	self.BusTopRideLastCFrame = platformCFrame
	self.BusTopRideConnection = RunService.Heartbeat:Connect(function(dt)
		if not platform.Parent or not candidate or not candidate.Parent or (topPart and not topPart.Parent) then
			self:ClearBusTopRidePlatform()
			return
		end

		local nextPlatformCFrame = nil
		if candidate:IsA("BasePart") then
			nextPlatformCFrame = CFrame.new(candidate.Position + Vector3.new(0, candidate.Size.Y * 0.5 + 0.15, 0))
		elseif candidate:IsA("Model") then
			local ok, boxCFrame, boxSize = pcall(function() return candidate:GetBoundingBox() end)
			if ok and boxCFrame and boxSize then
				nextPlatformCFrame = CFrame.new(boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.5 + 0.15, 0))
			end
		end

		if nextPlatformCFrame then
			local lastCFrame = self.BusTopRideLastCFrame or platform.CFrame
			local delta = nextPlatformCFrame.Position - lastCFrame.Position
			local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)

			if platform.Anchored then
				platform.CFrame = nextPlatformCFrame
			end

			local character = getCharacter()
			local root = getRoot(character)
			if root and horizontalDelta.Magnitude > 0.001 and horizontalDelta.Magnitude < 80 then
				root.CFrame = root.CFrame + horizontalDelta
				local velocity = root.AssemblyLinearVelocity
				local followDt = math.max(dt or 0, 1 / 240)
				root.AssemblyLinearVelocity = Vector3.new(horizontalDelta.X / followDt, velocity.Y, horizontalDelta.Z / followDt)
			end

			self.BusTopRideLastCFrame = nextPlatformCFrame
		end
	end)
end

function Teleport:ToSchoolBusTop()
	if not self:CanTeleport(self.DefaultDebounce) then
		return
	end

	local character = getCharacter()
	local root = getRoot(character)
	if not root then
		Notify("School Bus", "Could not find your character.", "error")
		return
	end

	local bus, parts = self:FindSchoolBusTopTarget()
	if not bus then
		Notify("School Bus", "Could not find a bus outside the schoolhouse area.", "warning")
		return
	end

	local targetPosition = nil
	local platformPosition = nil
	local topPart = nil

	if bus:IsA("BasePart") then
		targetPosition = bus.Position + Vector3.new(0, bus.Size.Y * 0.5 + 5, 0)
		platformPosition = bus.Position + Vector3.new(0, bus.Size.Y * 0.5 + 0.15, 0)
		topPart = bus
	elseif bus:IsA("Model") then
		local ok, boxCFrame, boxSize = pcall(function() return bus:GetBoundingBox() end)
		if ok and boxCFrame and boxSize then
			targetPosition = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.5 + 5, 0)
			platformPosition = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.5 + 0.15, 0)
			topPart = bus:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	if not targetPosition then
		Notify("School Bus", "Could not find a valid bus top position.", "error")
		return
	end

	self:CreateBusTopRidePlatform(bus, parts, CFrame.new(platformPosition), topPart)
	self:MoveRoot(root, CFrame.new(targetPosition))
	self:AddStrike()
	self:StartFBlock()
	Notify("School Bus", "Teleported on top of the bus.", "success")
end

-- ============================================================
-- ITEMS SYSTEM
-- ============================================================

local Items = {
	SearchRootName = "Items",
	SearchText = "",
	TeleportDebounce = 0.5,
	AutoCollectEnabled = false,
	AutoCollectThread = nil,
	AutoCollectToggle = nil,
	EarlyAutoCollectEnabled = false,
	EarlyAutoCollectThread = nil,
	EarlyAutoCollectToggle = nil,
	AutoPickupEnabled = false,
	AutoPickupToggle = nil,
	AutoPickupPart = nil,
	AutoPickupThread = nil,
	AutoPickupTouching = {},
	AutoPickupScanInterval = 0.25,
	AutoPickupFollowInterval = 0.05,
	LastAutoPickupFollowAt = 0,
	Crates = {},
	KnownCrates = {},
	CrateWatcherConnections = {},
	CrateWatcherStarted = false,
	CrateWatcherRoot = nil,
	CollectCratesBusy = false,
	CrateCollectPart = nil,
	FastCollectCratesEnabled = false,
	FastCollectCratesThread = nil,
	FastCollectCratesInterval = 0.08,
	FastCollectCratesBox = nil,
	FastCollectCratesBoxSize = Vector3.new(20, 20, 20),
	CrateAuraEnabled = false,
	CrateAuraThread = nil,
	CrateAuraInterval = 0.04,
	CratePartCache = {},
	CrateFireCache = {},
	CrateUsedCache = {},
	CrateFireCacheInterval = 0.35,
	CrateUsedCacheInterval = 0.08,
	CrateNotificationCooldown = 3,
	LastCrateNotificationAt = 0,
}

-- Item names
local itemNames = {
	"Apple", "Bandage", "Boba", "Bomb", "Bull's Essence",
	"Cube of Ice", "First Aid Kit", "Forcefield Crystal", "Frog Potion",
	"Gravitation Shard", "Healing Potion", "Lightning Potion",
	"Potion of Strength", "Speed Potion", "Sphere of Fury",
	"Tomahawk", "True Power", "Bombs"
}

local permanentUseItems = {
	"Potion of Strength", "Bull's Essence", "Boba", "Speed Potion", "Frog Potion",
}

local healingItems = {
	"First Aid Kit", "Healing Potion", "Apple", "Bandage",
}

-- ============================================================
-- ITEMS — Search & Discovery
-- ============================================================

Items.SearchCache = {}
Items.SearchCacheBusy = false
Items.LastSearchCacheAt = 0
Items.SearchCacheCooldown = 60
Items.SearchCacheDirty = true
Items.SearchCacheRoot = nil
Items.SearchCacheRootConnections = {}

function Items:GetSearchRoot()
	local exactRoot = workspace:FindFirstChild(self.SearchRootName)
	if exactRoot then return exactRoot end

	local wantedName = string.lower(self.SearchRootName)
	for _, child in ipairs(workspace:GetChildren()) do
		if string.lower(child.Name) == wantedName then
			return child
		end
	end
	return nil
end

function Items:MarkSearchCacheDirty()
	self.SearchCacheDirty = true
end

function Items:ClearSearchRootConnections()
	for _, connection in ipairs(self.SearchCacheRootConnections) do
		if connection then connection:Disconnect() end
	end
	self.SearchCacheRootConnections = {}
end

function Items:WatchSearchRoot(root)
	if self.SearchCacheRoot == root then return end
	self:ClearSearchRootConnections()
	self.SearchCacheRoot = root
	if not root then return end

	table.insert(self.SearchCacheRootConnections, root.ChildAdded:Connect(function()
		self:MarkSearchCacheDirty()
	end))
	table.insert(self.SearchCacheRootConnections, root.ChildRemoved:Connect(function()
		self:MarkSearchCacheDirty()
	end))
end

function Items:RebuildSearchCache()
	if self.SearchCacheBusy then return end
	self.SearchCacheBusy = true

	local root = self:GetSearchRoot()
	self:WatchSearchRoot(root)

	if not root then
		self.SearchCache = {}
		self.LastSearchCacheAt = os.clock()
		self.SearchCacheDirty = false
		self.SearchCacheBusy = false
		return
	end

	local children = root:GetChildren()
	local results = {}
	for _, object in ipairs(children) do
		table.insert(results, object)
	end

	self.SearchCache = results
	self.LastSearchCacheAt = os.clock()
	self.SearchCacheDirty = false
	self.SearchCacheBusy = false
end

function Items:GetSearchDescendants()
	if self.SearchCacheDirty or os.clock() - self.LastSearchCacheAt > self.SearchCacheCooldown then
		self:RebuildSearchCache()
	end
	return self.SearchCache
end

function Items:GetSearchChildren()
	if self.SearchCacheDirty or os.clock() - self.LastSearchCacheAt > self.SearchCacheCooldown then
		self:RebuildSearchCache()
	end
	return self.SearchCache
end

function Items:FindManualItem(itemName)
	local character = getCharacter()
	local root = getRoot(character)
	if not root then return nil, nil end

	local closestObject = nil
	local closestPart = nil
	local closestDistance = math.huge

	for _, object in ipairs(self:GetSearchDescendants()) do
		local displayName = object.Name
		if displayName == itemName then
			local part = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart", true)
			if part and part.Parent and part:IsDescendantOf(workspace) and part.Transparency < 0.95 then
				local distance = (root.Position - part.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestObject = object
					closestPart = part
				end
			end
		end
	end

	return closestObject, closestPart
end

function Items:TeleportTo(itemName)
	if not Teleport:CanTeleport(self.TeleportDebounce) then
		return
	end

	local character = getCharacter()
	local root = getRoot(character)
	if not root then
		Notify("Items", "Could not find your character.", "error")
		return
	end

	local itemObject, itemPart = self:FindManualItem(itemName)
	if not itemObject or not itemPart then
		Notify("Items", itemName .. " is not currently available.", "warning")
		return
	end

	task.wait(0.08)

	if not itemObject.Parent or not itemPart.Parent or not itemPart:IsDescendantOf(workspace) or itemPart.Transparency >= 0.95 then
		Notify("Items", itemName .. " disappeared before teleporting.", "warning")
		return
	end

	local groundCFrame = Teleport:GetItemCFrame(itemPart, { character, itemObject })
	Teleport:MoveRoot(root, groundCFrame, itemPart.Position)
	Teleport:AddStrike()
	Teleport:StartFBlock()
	Notify("Items", "Teleported to " .. itemName, "success")
end

function Teleport:GetItemCFrame(itemPart, excludeInstances)
	local position = itemPart.Position

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeInstances or {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excludeInstances or {}

	local function hasRoom(candidatePosition)
		local touching = workspace:GetPartBoundsInBox(CFrame.new(candidatePosition + Vector3.new(0, 1.8, 0)), Vector3.new(2.8, 4.4, 2.8), overlapParams)
		for _, part in ipairs(touching) do
			if part ~= itemPart and part.CanCollide and part.Transparency < 0.95 then
				return false
			end
		end
		return true
	end

	local function canSeeItem(candidatePosition)
		local itemFocus = position + Vector3.new(0, 1, 0)
		local viewPosition = candidatePosition + Vector3.new(0, 1.6, 0)
		local direction = itemFocus - viewPosition
		if direction.Magnitude <= 0.1 then return true end
		local result = workspace:Raycast(viewPosition, direction, params)
		return not result or (result.Position - itemFocus).Magnitude <= 1.5
	end

	local roofResult = workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), params)
	local hasRoofAbove = roofResult and roofResult.Instance and roofResult.Instance.CanCollide and roofResult.Instance.Transparency < 0.95

	local searchOffsets = hasRoofAbove and {
		Vector3.new(0.8, 0, 0), Vector3.new(-0.8, 0, 0),
		Vector3.new(0, 0, 0.8), Vector3.new(0, 0, -0.8),
		Vector3.new(1.4, 0, 1.4), Vector3.new(-1.4, 0, 1.4),
		Vector3.new(1.4, 0, -1.4), Vector3.new(-1.4, 0, -1.4),
	} or {
		Vector3.zero,
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	}

	for _, offset in ipairs(searchOffsets) do
		local rayOrigin = position + offset + Vector3.new(0, 1.5, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -35, 0), params)
		if result then
			local candidatePosition = result.Position + Vector3.new(0, 4, 0)
			if hasRoom(candidatePosition) and (not hasRoofAbove or canSeeItem(candidatePosition)) then
				return CFrame.new(candidatePosition)
			end
		end
	end

	return CFrame.new(position + Vector3.new(0, 4, 0))
end

function Teleport:GetItemCFrame(itemPart, excludeInstances)
	local position = itemPart.Position

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeInstances or {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excludeInstances or {}

	local function hasRoom(candidatePosition)
		local touching = workspace:GetPartBoundsInBox(CFrame.new(candidatePosition + Vector3.new(0, 1.8, 0)), Vector3.new(2.8, 4.4, 2.8), overlapParams)
		for _, part in ipairs(touching) do
			if part ~= itemPart and part.CanCollide and part.Transparency < 0.95 then
				return false
			end
		end
		return true
	end

	local function canSeeItem(candidatePosition)
		local itemFocus = position + Vector3.new(0, 1, 0)
		local viewPosition = candidatePosition + Vector3.new(0, 1.6, 0)
		local direction = itemFocus - viewPosition
		if direction.Magnitude <= 0.1 then return true end
		local result = workspace:Raycast(viewPosition, direction, params)
		return not result or (result.Position - itemFocus).Magnitude <= 1.5
	end

	local roofResult = workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), params)
	local hasRoofAbove = roofResult and roofResult.Instance and roofResult.Instance.CanCollide and roofResult.Instance.Transparency < 0.95

	local searchOffsets = hasRoofAbove and {
		Vector3.new(0.8, 0, 0), Vector3.new(-0.8, 0, 0),
		Vector3.new(0, 0, 0.8), Vector3.new(0, 0, -0.8),
		Vector3.new(1.4, 0, 1.4), Vector3.new(-1.4, 0, 1.4),
		Vector3.new(1.4, 0, -1.4), Vector3.new(-1.4, 0, -1.4),
	} or {
		Vector3.zero,
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	}

	for _, offset in ipairs(searchOffsets) do
		local rayOrigin = position + offset + Vector3.new(0, 1.5, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -35, 0), params)
		if result then
			local candidatePosition = result.Position + Vector3.new(0, 4, 0)
			if hasRoom(candidatePosition) and (not hasRoofAbove or canSeeItem(candidatePosition)) then
				return CFrame.new(candidatePosition)
			end
		end
	end

	return CFrame.new(position + Vector3.new(0, 4, 0))
end

-- ============================================================
-- ITEMS — Auto Collect
-- ============================================================

local autoPermanentEnabled = false
local autoPermanentToggle = nil
local autoHealEnabled = false
local autoHealConnection = nil
local autoSortEnabled = false
local autoSortBusy = false
local autoSortConnections = {}
local movementSave = nil
local visitedCollectPositions = {}
local ignoredCollectTargets = {}
local ignoredCollectPositions = {}
local AUTO_COLLECT_POSITION_RADIUS = 7
local collectibleSearchPoolCache = {}
local collectibleSearchPoolCacheAt = 0
local COLLECTIBLE_POOL_CACHE_TIME = 0.05

local function setMovementPaused(paused)
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not humanoid then return end

	if paused then
		if not movementSave then
			movementSave = {
				WalkSpeed = humanoid.WalkSpeed,
				JumpPower = humanoid.JumpPower,
				JumpHeight = humanoid.JumpHeight,
				AutoRotate = humanoid.AutoRotate,
			}
		end
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	elseif movementSave then
		humanoid.WalkSpeed = movementSave.WalkSpeed
		humanoid.JumpPower = movementSave.JumpPower
		humanoid.JumpHeight = movementSave.JumpHeight
		humanoid.AutoRotate = movementSave.AutoRotate
		movementSave = nil
	end
end

local function getLiveItemPart(object)
	if not object or not object.Parent or not object:IsDescendantOf(workspace) then
		return nil
	end

	if object:GetAttribute("Collected") == true or object:GetAttribute("PickedUp") == true then
		return nil
	end

	local part = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart", true)
	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return nil
	end

	if part.Transparency >= 0.95 or part.Size.X <= 0 or part.Size.Y <= 0 or part.Size.Z <= 0 then
		return nil
	end

	local characterModel = part:FindFirstAncestorOfClass("Model")
	if characterModel and Players:GetPlayerFromCharacter(characterModel) then
		return nil
	end

	return part
end

local function isVisitedCollectPosition(position)
	local now = os.clock()
	for index = #ignoredCollectPositions, 1, -1 do
		local entry = ignoredCollectPositions[index]
		if not entry or entry.Until <= now then
			table.remove(ignoredCollectPositions, index)
		elseif (entry.Position - position).Magnitude <= AUTO_COLLECT_POSITION_RADIUS * 1.75 then
			return true
		end
	end
	return false
end

local function getCollectibleSearchPool()
	local now = os.clock()
	if now - collectibleSearchPoolCacheAt <= COLLECTIBLE_POOL_CACHE_TIME then
		return collectibleSearchPoolCache
	end
	collectibleSearchPoolCache = Items:GetSearchDescendants()
	collectibleSearchPoolCacheAt = now
	return collectibleSearchPoolCache
end

local function itemNameMatches(object, wantedName)
	local current = object
	while current and current ~= workspace do
		if current.Name == wantedName then
			return true
		end
		current = current.Parent
	end
	return false
end

local function findLiveItemByName(wantedName)
	local character = getCharacter()
	local root = getRoot(character)
	if not root then return nil, nil, nil, nil, nil end

	local closestObject = nil
	local closestPart = nil
	local closestDistance = math.huge

	for _, object in ipairs(getCollectibleSearchPool()) do
		if itemNameMatches(object, wantedName) then
			local part = getLiveItemPart(object)
			if part and not isVisitedCollectPosition(part.Position) then
				local distance = (root.Position - part.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestObject = object
					closestPart = part
				end
			end
		end
	end

	if closestObject and closestPart then
		return wantedName, closestPart.CFrame, closestPart.Position, closestObject, closestPart
	end
	return nil, nil, nil, nil, nil
end

local function isItemScanLoading()
	return Items.SearchCacheBusy or Items.LastSearchCacheAt == 0
end

local function findNextCollectTarget()
	local collectOrder = permanentUseItems

	for _, wantedName in ipairs(collectOrder) do
		local itemName, _, _, itemObject, itemPart = findLiveItemByName(wantedName)
		if itemName and itemObject and itemPart then
			return itemName, itemPart.CFrame, itemPart.Position, itemObject, itemPart
		end
	end

	for _, wantedName in ipairs(itemNames) do
		local itemName, _, _, itemObject, itemPart = findLiveItemByName(wantedName)
		if itemName and itemObject and itemPart then
			return itemName, itemPart.CFrame, itemPart.Position, itemObject, itemPart
		end
	end

	return nil, nil, nil, nil, nil
end

function Items:RunAutoCollect()
	setMovementPaused(true)

	while self.AutoCollectEnabled do
		if not Teleport:CanTeleport(self.TeleportDebounce, true, true) then
			task.wait(0.15)
			continue
		end

		local itemName, _, _, itemObject, itemPart = findNextCollectTarget()

		if not itemName then
			if isItemScanLoading() then
				task.wait(0.05)
				continue
			end
			task.wait(0.1)
			continue
		end

		local character = getCharacter()
		local root = getRoot(character)

		if root then
			local groundCFrame = Teleport:GetItemCFrame(itemPart, { character, itemObject })
			Teleport:MoveRoot(root, groundCFrame, itemPart.Position)
			Teleport:AddStrike()
			Teleport:StartFBlock()

			local part = itemPart
			task.delay(0.05, function()
				if self.AutoCollectEnabled and part.Parent then
					local VirtualInputManager = Services.VirtualInputManager
					pcall(function()
						VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
						task.wait(0.05)
						VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
					end)
				end
			end)

			Notify("Auto collect", "Collected " .. itemName, "success")
		end

		task.wait(0.5)
	end

	setMovementPaused(false)
end

function Items:SetAutoCollect(state, silent)
	self.AutoCollectEnabled = state == true

	if self.AutoCollectEnabled then
		if self.AutoCollectThread then
			self.AutoCollectThread = nil
		end
		self.AutoCollectThread = task.spawn(function()
			self:RunAutoCollect()
			self.AutoCollectThread = nil
		end)
		if not silent then
			Notify("Auto collect", "Starting priority collection.", "info")
		end
	else
		setMovementPaused(false)
		if not silent then
			Notify("Auto collect", "Auto collect disabled.", "info")
		end
	end
end

-- ============================================================
-- ITEMS — Auto Pickup
-- ============================================================

function Items:GetAutoPickupRoot()
	local character = getCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Items:FindAutoPickupItemFromPart(touchedPart)
	if not touchedPart or not touchedPart.Parent then return nil end

	for _, object in ipairs(self:GetSearchDescendants()) do
		local itemPart = getLiveItemPart(object)
		if itemPart and (touchedPart == itemPart or touchedPart:IsDescendantOf(object)) then
			for _, itemName in ipairs(itemNames) do
				if itemNameMatches(object, itemName) then
					return object, itemPart, itemName
				end
			end
		end
	end
	return nil
end

function Items:IsPartInsideAutoPickupZone(itemPart, root)
	if not itemPart or not itemPart.Parent or not root then return false end
	local localPosition = root.CFrame:PointToObjectSpace(itemPart.Position)
	local halfSize = 15
	return math.abs(localPosition.X) <= halfSize
		and math.abs(localPosition.Y) <= halfSize
		and math.abs(localPosition.Z) <= halfSize
end

function Items:ClearAutoPickupPart()
	if self.AutoPickupPart then
		pcall(function() self.AutoPickupPart:Destroy() end)
		self.AutoPickupPart = nil
	end
	self.AutoPickupTouching = {}
end

function Items:EnsureAutoPickupPart()
	local root = self:GetAutoPickupRoot()
	if not root then
		self:ClearAutoPickupPart()
		return nil
	end

	if self.AutoPickupPart and self.AutoPickupPart.Parent then
		return self.AutoPickupPart
	end

	local pickupPart = Instance.new("Part")
	pickupPart.Name = "Part"
	pickupPart.Size = Vector3.new(30, 30, 30)
	pickupPart.Transparency = 1
	pickupPart.Anchored = true
	pickupPart.CanCollide = false
	pickupPart.CanQuery = false
	pickupPart.CanTouch = true
	pickupPart.CFrame = root.CFrame
	pickupPart.Parent = workspace

	pickupPart.Touched:Connect(function(hit)
		local itemObject, itemPart, itemName = self:FindAutoPickupItemFromPart(hit)
		if itemObject and itemPart and itemName then
			self.AutoPickupTouching[itemObject] = { Object = itemObject, Part = itemPart, Name = itemName }
		end
	end)

	pickupPart.TouchEnded:Connect(function(hit)
		local itemObject = self:FindAutoPickupItemFromPart(hit)
		if itemObject then
			self.AutoPickupTouching[itemObject] = nil
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - (self.LastAutoPickupFollowAt or 0) < (self.AutoPickupFollowInterval or 0.05) then
			return
		end
		self.LastAutoPickupFollowAt = now
		local currentRoot = self:GetAutoPickupRoot()
		if currentRoot and pickupPart.Parent then
			pickupPart.CFrame = currentRoot.CFrame
		end
	end)

	self.AutoPickupPart = pickupPart
	return pickupPart
end

function Items:StartAutoPickupThread()
	if self.AutoPickupThread then return end

	self.AutoPickupThread = task.spawn(function()
		while self.AutoPickupEnabled do
			self:EnsureAutoPickupPart()

			local root = self:GetAutoPickupRoot()
			local shouldPressPickup = false

			for itemObject, entry in pairs(self.AutoPickupTouching) do
				local itemPart = getLiveItemPart(itemObject)
				if not root or not itemPart or not self:IsPartInsideAutoPickupZone(itemPart, root) then
					self.AutoPickupTouching[itemObject] = nil
				else
					shouldPressPickup = true
				end
			end

			if shouldPressPickup then
				local VirtualInputManager = Services.VirtualInputManager
				pcall(function()
					VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
					task.wait(0.05)
					VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
				end)
			end

			task.wait(self.AutoPickupScanInterval or 0.25)
		end

		self.AutoPickupThread = nil
	end)
end

function Items:SetAutoPickup(state, silent)
	self.AutoPickupEnabled = state == true

	if self.AutoPickupEnabled then
		self:EnsureAutoPickupPart()
		self:StartAutoPickupThread()
		if not silent then
			Notify("Auto pick up", "Auto pick up enabled.", "success")
		end
	else
		self:ClearAutoPickupPart()
		if not silent then
			Notify("Auto pick up", "Auto pick up disabled.", "info")
		end
	end
end

-- ============================================================
-- ITEMS — Auto Heal
-- ============================================================

local function useTool(tool)
	if not tool or not tool:IsA("Tool") then return false end

	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not humanoid or humanoid.Health <= 0 then return false end

	if tool.Parent == player:FindFirstChild("Backpack") then
		humanoid:EquipTool(tool)
		task.wait(0.35)
	end

	if tool.Parent == character then
		pcall(function()
			tool:Activate()
		end)
		return true
	end

	return false
end

local function findMatchingTool(itemList)
	local character = getCharacter()
	local backpack = player:FindFirstChild("Backpack")

	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				for _, itemName in ipairs(itemList) do
					if tool.Name == itemName then
						return tool
					end
				end
			end
		end
	end

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				for _, itemName in ipairs(itemList) do
					if tool.Name == itemName then
						return tool
					end
				end
			end
		end
	end

	return nil
end

local function tryAutoHeal()
	if not autoHealEnabled then return end

	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not humanoid or humanoid.Health <= 0 then return end

	local threshold = math.max(30, humanoid.MaxHealth * 0.45)
	if humanoid.Health <= threshold then
		local tool = findMatchingTool(healingItems)
		if tool then
			useTool(tool)
		end
	end
end

function Items:SetAutoHeal(state, silent)
	autoHealEnabled = state == true

	if autoHealEnabled then
		if autoHealConnection then
			autoHealConnection:Disconnect()
		end
		local character = getCharacter()
		local humanoid = getHumanoid(character)
		if humanoid then
			autoHealConnection = humanoid.HealthChanged:Connect(tryAutoHeal)
		end
		if not silent then
			Notify("Auto Heal", "Auto Heal enabled.", "success")
		end
	else
		if autoHealConnection then
			autoHealConnection:Disconnect()
			autoHealConnection = nil
		end
		if not silent then
			Notify("Auto Heal", "Auto Heal disabled.", "info")
		end
	end
end

-- ============================================================
-- ITEMS — Auto Sort
-- ============================================================

local function getInventoryTools()
	local tools = {}
	local character = getCharacter()
	local backpack = player:FindFirstChild("Backpack")

	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	return tools
end

local function isLikelyGloveTool(tool)
	local name = normalizeName(tool.Name)
	if string.find(name, "glove") or string.find(name, "slap") then
		return true
	end
	for _, itemName in ipairs(itemNames) do
		if name == normalizeName(itemName) then
			return false
		end
	end
	return true
end

local function getToolSortRank(tool)
	if isLikelyGloveTool(tool) then
		return math.huge
	end

	if normalizeName(tool.Name) == normalizeName("True Power") then
		return 20
	end

	if normalizeName(tool.Name) == normalizeName("Tomahawk") then
		return 21
	end

	for index, itemName in ipairs(permanentUseItems) do
		if normalizeName(tool.Name) == normalizeName(itemName) then
			return 30 + index
		end
	end

	for index, itemName in ipairs(itemNames) do
		if normalizeName(tool.Name) == normalizeName(itemName) then
			return 60 + index
		end
	end

	return 80
end

local function sortInventory()
	if autoSortBusy then return end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	autoSortBusy = true
	local tools = {}
	local holdingFolder = Instance.new("Folder")
	holdingFolder.Name = "Part"

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and not isLikelyGloveTool(tool) then
			table.insert(tools, tool)
			tool.Parent = holdingFolder
		end
	end

	table.sort(tools, function(left, right)
		return getToolSortRank(left) < getToolSortRank(right)
	end)

	for _, tool in ipairs(tools) do
		tool.Parent = backpack
		task.wait()
	end

	holdingFolder:Destroy()
	autoSortBusy = false
	Notify("Auto Sort", "Glove first, priority items next.", "success")
end

function Items:SetAutoSort(state, silent)
	autoSortEnabled = state == true

	if autoSortEnabled then
		task.delay(0.5, sortInventory)
		if not silent then
			Notify("Auto Sort", "Auto Sort enabled.", "success")
		end
	else
		if not silent then
			Notify("Auto Sort", "Auto Sort disabled.", "info")
		end
	end
end

-- ============================================================
-- ITEMS — Auto Use Permanent Items
-- ============================================================

local function setAutoPermanentItems(state, silent)
	autoPermanentEnabled = state == true

	if autoPermanentEnabled then
		task.spawn(function()
			while autoPermanentEnabled do
				local tool = findMatchingTool(permanentUseItems)
				if tool then
					useTool(tool)
				end
				task.wait(0.25)
			end
		end)
		if not silent then
			Notify("Auto Use", "Auto Use Permanent Items enabled.", "success")
		end
	else
		if not silent then
			Notify("Auto Use", "Auto Use Permanent Items disabled.", "info")
		end
	end
end

-- ============================================================
-- ITEMS — Use/Drop Buttons
-- ============================================================

local function getMatchingInventoryTools(itemList)
	local tools = {}
	for _, tool in ipairs(getInventoryTools()) do
		if tool:IsA("Tool") then
			for _, itemName in ipairs(itemList) do
				if tool.Name == itemName then
					table.insert(tools, tool)
					break
				end
			end
		end
	end
	return tools
end

local function useAllMatchingTools(itemList, label, pluralName)
	task.spawn(function()
		local tools = getMatchingInventoryTools(itemList)
		if #tools == 0 then
			Notify(label, "No " .. pluralName .. " found.", "warning")
			return
		end

		local usedCount = 0
		for _, tool in ipairs(tools) do
			if useTool(tool) then
				usedCount = usedCount + 1
			end
			task.wait(0.04)
		end

		if usedCount > 0 then
			Notify(label, "Used " .. tostring(usedCount) .. " " .. pluralName .. ".", "success")
		else
			Notify(label, "Could not use any " .. pluralName .. ".", "warning")
		end
	end)
end

function Items:UseSpheres()
	useAllMatchingTools({ "Sphere of Fury" }, "Use Spheres", "Sphere(s) of Fury")
end

function Items:UseCubes()
	useAllMatchingTools({ "Cube of Ice" }, "Use Cubes", "Cube(s) of Ice")
end

function Items:UseAllItems()
	useAllMatchingTools(itemNames, "Use All Items", "item(s)")
end

local function dropTool(tool)
	if not tool or not tool:IsA("Tool") or not tool.Parent then return false end

	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not humanoid then return false end

	pcall(function() tool.CanBeDropped = true end)

	if tool.Parent ~= character then
		pcall(function() humanoid:EquipTool(tool) end)
		task.wait(0.012)
	end

	if tool.Parent ~= character then return false end

	local VirtualInputManager = Services.VirtualInputManager
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
		task.wait(0.006)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
	end)

	for _ = 1, 4 do
		if not tool.Parent then return true end
		task.wait(0.01)
	end

	return false
end

local function dropMatchingTools(itemList, label, pluralName)
	task.spawn(function()
		local tools = getMatchingInventoryTools(itemList)
		if #tools == 0 then
			Notify(label, "No " .. pluralName .. " found.", "warning")
			return
		end

		local droppedCount = 0
		for _, tool in ipairs(tools) do
			if dropTool(tool) then
				droppedCount = droppedCount + 1
			end
			task.wait(0.003)
		end

		if droppedCount > 0 then
			Notify(label, "Dropped " .. tostring(droppedCount) .. " " .. pluralName .. ".", "success")
		else
			Notify(label, "Could not drop any " .. pluralName .. ".", "warning")
		end
	end)
end

function Items:DropAllItems()
	dropMatchingTools(itemNames, "Drop All Items", "item(s)")
end

function Items:DropAllPermanents()
	dropMatchingTools(permanentUseItems, "Drop Permanent Items", "permanent item(s)")
end

function Items:DropTempItems()
	local tempItems = {}
	for _, itemName in ipairs(itemNames) do
		local isPermanent = false
		for _, permName in ipairs(permanentUseItems) do
			if itemName == permName then
				isPermanent = true
				break
			end
		end
		if not isPermanent then
			table.insert(tempItems, itemName)
		end
	end
	dropMatchingTools(tempItems, "Drop Temp Items", "temporary item(s)")
end

-- ============================================================
-- CRATE SYSTEM
-- ============================================================

function Items:GetShipmentCratesRoot()
	local shipments = workspace:FindFirstChild("Shipments")
	return shipments and shipments:FindFirstChild("Crates")
end

function Items:GetCratePart(crate)
	if not crate or not crate.Parent or not crate:IsDescendantOf(workspace) then
		return nil
	end

	if crate:IsA("BasePart") then
		self.CratePartCache[crate] = crate
		return crate
	end

	local cachedPart = self.CratePartCache[crate]
	if cachedPart and cachedPart.Parent and cachedPart:IsDescendantOf(crate) then
		return cachedPart
	end

	local part = nil
	if crate:IsA("Model") then
		part = crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart", true)
	else
		part = crate:FindFirstChildWhichIsA("BasePart", true)
	end

	if part then
		self.CratePartCache[crate] = part
	end
	return part
end

function Items:IsCrateCandidate(object)
	local cratesRoot = self:GetShipmentCratesRoot()
	if not cratesRoot or not object or not object:IsDescendantOf(cratesRoot) then
		return false
	end
	return object.Name == "Crate"
end

function Items:IsShipmentCrateObject(object)
	local cratesRoot = self:GetShipmentCratesRoot()
	if not cratesRoot or not object or not object:IsDescendantOf(cratesRoot) then
		return false
	end
	local current = object
	while current and current ~= cratesRoot do
		if current.Name == "Crate" and self:GetCratePart(current) then
			return true
		end
		current = current.Parent
	end
	return false
end

function Items:GetCrateRoot(object)
	local cratesRoot = self:GetShipmentCratesRoot()
	if cratesRoot and object and object:IsDescendantOf(cratesRoot) then
		local current = object
		while current and current ~= cratesRoot do
			if current.Name == "Crate" and self:GetCratePart(current) then
				return current
			end
			current = current.Parent
		end
	end
	return nil
end

function Items:TrackCrate(crate, notify)
	local crateRoot = self:GetCrateRoot(crate)
	if not crateRoot then return end

	local current = crateRoot.Parent
	while current and current ~= workspace do
		if self.KnownCrates[current] then
			return
		end
		current = current.Parent
	end

	if self.KnownCrates[crateRoot] then
		return
	end

	self.KnownCrates[crateRoot] = true
	self.CratePartCache[crateRoot] = self:GetCratePart(crateRoot)
	table.insert(self.Crates, crateRoot)

	if notify then
		local now = os.clock()
		if now - (self.LastCrateNotificationAt or 0) >= self.CrateNotificationCooldown then
			self.LastCrateNotificationAt = now
			Notify("Meteor Crate", "Crate detected.", "info")
		end
	end

	table.insert(self.CrateWatcherConnections, crateRoot.AncestryChanged:Connect(function()
		if not crateRoot.Parent then
			self.KnownCrates[crateRoot] = nil
			self.CratePartCache[crateRoot] = nil
		end
	end))
end

function Items:RefreshCrates()
	local liveCrates = {}
	for _, crate in ipairs(self.Crates) do
		if self:GetCratePart(crate) then
			table.insert(liveCrates, crate)
		else
			self.KnownCrates[crate] = nil
			self.CratePartCache[crate] = nil
		end
	end
	self.Crates = liveCrates
end

function Items:StartCrateWatcher()
	if self.CrateWatcherStarted then return end

	local root = self:GetShipmentCratesRoot()
	if not root then
		task.spawn(function()
			for _ = 1, 300 do
				task.wait(1)
				root = self:GetShipmentCratesRoot()
				if root then
					self:StartCrateWatcher()
					return
				end
			end
		end)
		return
	end

	self.CrateWatcherRoot = root
	self.CrateWatcherStarted = true

	local function trackShipmentCrate(object)
		if object.Name ~= "Crate" then return end
		task.defer(function() self:TrackCrate(object, true) end)
	end

	table.insert(self.CrateWatcherConnections, root.ChildAdded:Connect(trackShipmentCrate))
	table.insert(self.CrateWatcherConnections, root.ChildRemoved:Connect(function(object)
		self.KnownCrates[object] = nil
		self.CratePartCache[object] = nil
		self:RefreshCrates()
	end))

	task.spawn(function()
		for _, object in ipairs(root:GetChildren()) do
			if object.Name == "Crate" then
				self:TrackCrate(object, false)
			end
		end
		self:RefreshCrates()
	end)
end

function Items:IsCrateUsedUp(crate)
	if not crate or not crate.Parent or not crate:IsDescendantOf(workspace) then
		return true
	end

	local durability = crate:GetAttribute("Durability") or crate:GetAttribute("Health")
	if type(durability) == "number" and durability <= 0 then
		return true
	end

	local part = self:GetCratePart(crate)
	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return true
	end

	if part:GetAttribute("Durability") == 0 or part:GetAttribute("Health") == 0 then
		return true
	end

	return false
end

function Items:CrateHasActiveFire(crate)
	if not crate or not crate.Parent then return false end

	local function isFireObject(object)
		if object:IsA("Fire") and object.Enabled ~= false then
			return true
		end
		if object:IsA("ParticleEmitter") and object.Enabled ~= false then
			local name = string.lower(object.Name)
			return string.find(name, "fire", 1, true)
				or string.find(name, "flame", 1, true)
		end
		return false
	end

	if isFireObject(crate) then return true end

	for _, object in ipairs(crate:GetDescendants()) do
		if isFireObject(object) then
			return true
		end
	end

	return false
end

function Items:SlapCrate(cratePart)
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Slap")
	if not remote or not cratePart or not cratePart.Parent then
		return false
	end

	if self:CrateHasActiveFire(cratePart) then
		return false
	end

	pcall(function() remote:FireServer(cratePart) end)

	local tool = getCharacter() and getCharacter():FindFirstChildOfClass("Tool")
	if tool then
		pcall(function() tool:Activate() end)
	end

	return true
end

function Items:TeleportToCrate()
	if not Teleport:CanTeleport(self.TeleportDebounce) then
		return
	end

	local root = getRoot()
	if not root then return end

	local nearestCrate = nil
	local nearestPart = nil
	local nearestDistance = math.huge

	for _, crate in ipairs(self.Crates) do
		local part = self:GetCratePart(crate)
		if part then
			local distance = (root.Position - part.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestCrate = crate
				nearestPart = part
			end
		end
	end

	if not nearestCrate or not nearestPart then
		Notify("Meteor Crate", "No crate found.", "warning")
		return
	end

	local targetPosition = nearestPart.Position + Vector3.new(0, (nearestPart.Size.Y / 2) + 4, 0)
	Teleport:MoveRoot(root, CFrame.new(targetPosition))
	Teleport:AddStrike()
	Teleport:StartFBlock()
	Notify("Meteor Crate", "Teleported to nearest crate.", "success")
end

function Items:CollectCrates()
	if self.CollectCratesBusy then
		Notify("Collect Crates", "Already collecting crates.", "info")
		return
	end

	self.CollectCratesBusy = true
	self:StartCrateWatcher()
	setMovementPaused(true)

	task.spawn(function()
		local targets = {}
		for _, crate in ipairs(self.Crates) do
			if crate and crate.Parent then
				table.insert(targets, crate)
			end
		end

		if #targets == 0 then
			Notify("Collect Crates", "No crates found.", "warning")
			self.CollectCratesBusy = false
			setMovementPaused(false)
			return
		end

		local crateCount = #targets
		Notify("Collect Crates", "Collecting " .. tostring(crateCount) .. " crate(s).", "info")

		for _, crate in ipairs(targets) do
			if not self.CollectCratesBusy then break end
			if self:IsCrateUsedUp(crate) then
				continue
			end

			local part = self:GetCratePart(crate)
			if not part then continue end

			local targetPosition = part.Position + Vector3.new(0, (part.Size.Y / 2) + 4, 0)
			local root = getRoot()

			if root then
				Teleport:MoveRoot(root, CFrame.new(targetPosition), part.Position)
				task.wait(0.08)
			end

			local startedAt = os.clock()
			while not self:IsCrateUsedUp(crate) and self.CollectCratesBusy do
				if os.clock() - startedAt > 8 then break end

				if not self:CrateHasActiveFire(crate) then
					self:SlapCrate(part)
				end

				task.wait(0.12)
			end
		end

		self:RefreshCrates()
		self.CollectCratesBusy = false
		setMovementPaused(false)
		Notify("Collect Crates", "Finished collecting crates.", "success")
	end)
end

function Items:SetFastCollectCrates(state, silent)
	self.FastCollectCratesEnabled = state == true

	if self.FastCollectCratesEnabled then
		self:StartCrateWatcher()

		if self.FastCollectCratesThread then
			self.FastCollectCratesThread = nil
		end
		self.FastCollectCratesThread = task.spawn(function()
			while self.FastCollectCratesEnabled do
				local root = getRoot()
				if root then
					for _, crate in ipairs(self.Crates) do
						local part = self:GetCratePart(crate)
						if part and not self:CrateHasActiveFire(crate) then
							self:SlapCrate(part)
						end
					end
				end
				task.wait(self.FastCollectCratesInterval)
			end
			self.FastCollectCratesThread = nil
		end)

		if not silent then
			Notify("Auto collect crates", "Auto collect crates enabled.", "success")
		end
	else
		if not silent then
			Notify("Auto collect crates", "Auto collect crates disabled.", "info")
		end
	end
end

function Items:SetCrateAura(state, silent)
	self.CrateAuraEnabled = state == true

	if self.CrateAuraEnabled then
		if self.CrateAuraThread then
			self.CrateAuraThread = nil
		end
		self.CrateAuraThread = task.spawn(function()
			while self.CrateAuraEnabled do
				local root = getRoot()
				if root then
					local auraRange = 20
					for _, crate in ipairs(self.Crates) do
						local part = self:GetCratePart(crate)
						if part and (root.Position - part.Position).Magnitude <= auraRange then
							self:SlapCrate(part)
						end
					end
				end
				task.wait(self.CrateAuraInterval)
			end
			self.CrateAuraThread = nil
		end)

		if not silent then
			Notify("Crate Aura", "Crate Aura enabled.", "success")
		end
	else
		if not silent then
			Notify("Crate Aura", "Crate Aura disabled.", "info")
		end
	end
end

-- ============================================================
-- EARLY AUTO COLLECT
-- ============================================================

local function getTimerNumber()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return nil end

	for _, object in ipairs(playerGui:GetDescendants()) do
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			local text = tostring(object.Text)
			local number = tonumber(string.match(text, "^%s*(%d+)%s*$"))
			if number then
				local fullName = string.lower(object:GetFullName())
				if string.find(fullName, "timer", 1, true) or string.find(fullName, "countdown", 1, true) then
					return number
				end
			end
		end
	end
	return nil
end

local function isLocalPlayerInBus()
	local character = getCharacter()
	local root = getRoot(character)
	if not root then return false end

	for _, object in ipairs(workspace:GetDescendants()) do
		if string.find(normalizeName(object.Name), "bus", 1, true) then
			local position = nil
			if object:IsA("BasePart") then
				position = object.Position
			elseif object:IsA("Model") then
				local ok, pivot = pcall(function() return object:GetPivot() end)
				if ok then position = pivot.Position end
			end
			if position and (root.Position - position).Magnitude <= 30 then
				return true
			end
		end
	end
	return false
end

function Items:SetEarlyAutoCollect(state, silent)
	self.EarlyAutoCollectEnabled = state == true

	if self.EarlyAutoCollectEnabled then
		local timerNumber = getTimerNumber()
		if not timerNumber then
			Notify("Early Auto Collect", "No countdown detected.", "warning")
			task.defer(function()
				if self.EarlyAutoCollectToggle then
					self.EarlyAutoCollectToggle.Set(false, false)
				end
			end)
			return
		end

		if timerNumber <= 3 then
			Notify("Early Auto Collect", "Must be activated before there are 3 seconds left.", "warning")
			task.defer(function()
				if self.EarlyAutoCollectToggle then
					self.EarlyAutoCollectToggle.Set(false, false)
				end
			end)
			return
		end

		if self.AutoCollectEnabled then
			Notify("Early Auto Collect", "Turn Auto collect off first.", "warning")
			task.defer(function()
				if self.EarlyAutoCollectToggle then
					self.EarlyAutoCollectToggle.Set(false, false)
				end
			end)
			return
		end

		if not silent then
			Notify("Early Auto Collect", "Waiting for countdown to end.", "info")
		end

		task.spawn(function()
			while self.EarlyAutoCollectEnabled do
				local timer = getTimerNumber()
				if timer and timer <= 3 then
					break
				end
				task.wait(0.1)
			end

			if self.EarlyAutoCollectEnabled then
				task.wait(1)
				self:SetAutoCollect(true, silent)
				self.EarlyAutoCollectEnabled = false
				if self.EarlyAutoCollectToggle then
					self.EarlyAutoCollectToggle.Set(false, false)
				end
				Notify("Early Auto Collect", "Auto collect started.", "success")
			end
		end)

		if not silent then
			Notify("Early Auto Collect", "Early Auto Collect enabled.", "success")
		end
	else
		if not silent then
			Notify("Early Auto Collect", "Early Auto Collect disabled.", "info")
		end
	end
end

-- ============================================================
-- EARLY BUS JUMP
-- ============================================================

local AutoEarlyBusJumpEnabled = false
local AutoEarlyBusJumpThread = nil
local AutoEarlyBusJumpFiredInBus = false
local JumpBusExitSent = false
local JumpBusTrackedObject = nil
local JumpBusSearchActive = false
local LastAutoEarlyBusJumpAt = 0
local LastJumpBusSeenAt = 0

local function fireEarlyBusJump()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("BusJumping")
	if remote and remote:IsA("RemoteEvent") then
		pcall(function() remote:FireServer(true) end)
		JumpBusExitSent = true
		LastAutoEarlyBusJumpAt = os.clock()
		Notify("Early Bus Jump", "Jumped out of the bus!", "success")
		return true
	end
	return false
end

local function getBusCandidates(rootPosition)
	if not rootPosition then return {} end
	local results = {}
	local seen = {}

	local ok, nearbyParts = pcall(function()
		return workspace:GetPartBoundsInBox(CFrame.new(rootPosition), Vector3.new(180, 130, 180))
	end)

	if ok then
		for _, part in ipairs(nearbyParts) do
			local current = part
			while current and current ~= workspace do
				if string.find(normalizeName(current.Name), "bus", 1, true) and (current:IsA("Model") or current:IsA("BasePart")) then
					if not seen[current] then
						seen[current] = true
						table.insert(results, current)
					end
					break
				end
				current = current.Parent
			end
		end
	end

	return results
end

local function isLocalPlayerInBus()
	local character = getCharacter()
	local root = getRoot(character)
	if not root then return false end

	local busObjects = getBusCandidates(root.Position)
	for _, bus in ipairs(busObjects) do
		if bus.Parent then
			local position = nil
			if bus:IsA("BasePart") then
				position = bus.Position
			elseif bus:IsA("Model") then
				local ok, pivot = pcall(function() return bus:GetPivot() end)
				if ok then position = pivot.Position end
			end
			if position and (root.Position - position).Magnitude <= 25 then
				JumpBusTrackedObject = bus
				LastJumpBusSeenAt = os.clock()
				return true
			end
		end
	end

	if JumpBusExitSent then
		return false
	end

	return false
end

function UI.SetAutoEarlyBusJump(state, silent)
	AutoEarlyBusJumpEnabled = state == true

	if AutoEarlyBusJumpEnabled then
		JumpBusSearchActive = true
		JumpBusExitSent = false
		AutoEarlyBusJumpFiredInBus = false

		if AutoEarlyBusJumpThread then
			AutoEarlyBusJumpThread = nil
		end
		AutoEarlyBusJumpThread = task.spawn(function()
			while AutoEarlyBusJumpEnabled do
				local inBus = isLocalPlayerInBus()
				if inBus and not AutoEarlyBusJumpFiredInBus and os.clock() - LastAutoEarlyBusJumpAt >= 1 then
					if fireEarlyBusJump() then
						AutoEarlyBusJumpFiredInBus = true
						LastAutoEarlyBusJumpAt = os.clock()
					end
				elseif not inBus and not JumpBusExitSent then
					AutoEarlyBusJumpFiredInBus = false
				end
				task.wait(0.15)
			end
			AutoEarlyBusJumpThread = nil
			JumpBusSearchActive = false
		end)

		if not silent then
			Notify("Early Bus Jump", "Auto bus jump enabled.", "success")
		end
	else
		JumpBusSearchActive = false
		JumpBusExitSent = false
		if not silent then
			Notify("Early Bus Jump", "Auto bus jump disabled.", "info")
		end
	end
end

-- ============================================================
-- INFINITE JUMP
-- ============================================================

local InfiniteJumpEnabled = false
local InfiniteJumpConnection = nil

function UI.SetInfiniteJump(state, silent)
	InfiniteJumpEnabled = state == true

	if InfiniteJumpEnabled then
		if InfiniteJumpConnection then
			InfiniteJumpConnection:Disconnect()
		end
		InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
			if InfiniteJumpEnabled then
				local character = getCharacter()
				local humanoid = getHumanoid(character)
				if humanoid and humanoid.Health > 0 then
					pcall(function()
						humanoid.Jump = true
						humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end)
				end
			end
		end)
		if not silent then
			Notify("Infinite Jump", "Infinite Jump enabled.", "success")
		end
	else
		if InfiniteJumpConnection then
			InfiniteJumpConnection:Disconnect()
			InfiniteJumpConnection = nil
		end
		if not silent then
			Notify("Infinite Jump", "Infinite Jump disabled.", "info")
		end
	end
end

-- ============================================================
-- PLAYER STATS ESP
-- ============================================================

local ESP = {
	Enabled = false,
	Folder = nil,
	Billboards = {},
	Highlights = {},
	Connections = {},
	UpdateInterval = 1,
}

function ESP:EnsureFolder()
	if self.Folder and self.Folder.Parent then return self.Folder end
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Part"
	self.Folder.Parent = PlayerGui
	return self.Folder
end

function ESP:GetStatValue(targetPlayer, statNames)
	local leaderstats = targetPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		for _, statName in ipairs(statNames) do
			local stat = leaderstats:FindFirstChild(statName)
			if stat and stat:IsA("ValueBase") then
				return stat.Value
			end
		end
	end

	for _, statName in ipairs(statNames) do
		local attribute = targetPlayer:GetAttribute(statName)
		if attribute ~= nil then
			return attribute
		end
	end

	local character = targetPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and statNames[1] == "Speed" then
			return math.floor(humanoid.WalkSpeed)
		end
	end

	return "?"
end

function ESP:Remove(targetPlayer)
	local existingBillboard = self.Billboards[targetPlayer]
	if existingBillboard then
		existingBillboard:Destroy()
	end
	self.Billboards[targetPlayer] = nil

	local existingHighlight = self.Highlights[targetPlayer]
	if existingHighlight then
		existingHighlight:Destroy()
	end
	self.Highlights[targetPlayer] = nil
end

function ESP:Create(targetPlayer)
	if targetPlayer == player then return end

	self:Remove(targetPlayer)

	local character = targetPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not character or not head or not humanoid or humanoid.Health <= 0 then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "Part"
	highlight.FillColor = Color3.fromRGB(0, 170, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.75
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	self.Highlights[targetPlayer] = highlight

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Part"
	billboard.Size = UDim2.fromOffset(360, 170)
	billboard.StudsOffset = Vector3.new(0, 5.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 10000
	billboard.Adornee = head
	billboard.Parent = self:EnsureFolder()
	self.Billboards[targetPlayer] = billboard

	local label = Instance.new("TextLabel")
	label.Name = "Part"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 28
	label.TextWrapped = true
	label.RichText = true
	label.Parent = billboard

	task.spawn(function()
		while self.Enabled and billboard.Parent do
			local liveCharacter = targetPlayer.Character
			local liveHumanoid = liveCharacter and liveCharacter:FindFirstChildOfClass("Humanoid")
			if not liveHumanoid or liveHumanoid.Health <= 0 then
				self:Remove(targetPlayer)
				break
			end

			local health = math.floor(liveHumanoid.Health) .. "/" .. math.floor(liveHumanoid.MaxHealth)
			local kills = self:GetStatValue(targetPlayer, { "Kills", "Kill", "KOs" })
			local power = self:GetStatValue(targetPlayer, { "Power", "Strength", "Slaps" })
			local speed = self:GetStatValue(targetPlayer, { "Speed" })

			label.Text =
				'<font color="rgb(255,255,255)">' .. targetPlayer.Name .. '</font>'
				.. '\n<font color="rgb(80,255,120)">Health: ' .. tostring(health) .. '</font>'
				.. '\n<font color="rgb(80,170,255)">Kills: ' .. tostring(kills) .. '</font>'
				.. '\n<font color="rgb(255,80,80)">Strength: ' .. tostring(power) .. '</font>'
				.. '\n<font color="rgb(255,235,70)">Speed: ' .. tostring(speed) .. '</font>'

			task.wait(self.UpdateInterval or 1)
		end
	end)
end

function ESP:Refresh()
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if self.Enabled then
			self:Create(targetPlayer)
		else
			self:Remove(targetPlayer)
		end
	end
end

function ESP:ClearConnections()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}
end

function ESP:Enable()
	if self.Enabled then return end
	self.Enabled = true
	self:EnsureFolder()
	self:Refresh()

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		table.insert(self.Connections, targetPlayer.CharacterAdded:Connect(function()
			task.wait(0.5)
			if self.Enabled then
				self:Create(targetPlayer)
			end
		end))
	end

	table.insert(self.Connections, Players.PlayerAdded:Connect(function(targetPlayer)
		table.insert(self.Connections, targetPlayer.CharacterAdded:Connect(function()
			task.wait(0.5)
			if self.Enabled then
				self:Create(targetPlayer)
			end
		end))
	end))

	table.insert(self.Connections, Players.PlayerRemoving:Connect(function(targetPlayer)
		self:Remove(targetPlayer)
	end))
end

function ESP:Disable()
	self.Enabled = false
	self:ClearConnections()
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		self:Remove(targetPlayer)
	end
end

function UI.SetPlayerStatsESP(state, silent)
	if state then
		ESP:Enable()
		if not silent then
			Notify("ESP", "Player Stats ESP enabled.", "success")
		end
	else
		ESP:Disable()
		if not silent then
			Notify("ESP", "Player Stats ESP disabled.", "info")
		end
	end
end

-- ============================================================
-- ITEM ESP
-- ============================================================

local ItemESP = {
	Enabled = false,
	Folder = nil,
	Rows = {},
	Thread = nil,
	RefreshDelay = 2.5,
	KnownNameLookup = {},
}

local itemESPColors = {
	Default = Color3.fromRGB(235, 245, 255),
	TruePower = Color3.fromRGB(255, 255, 255),
	Power = Color3.fromRGB(255, 72, 86),
	Speed = Color3.fromRGB(255, 226, 82),
	Jump = Color3.fromRGB(92, 170, 255),
	Heal = Color3.fromRGB(98, 255, 142),
	Defense = Color3.fromRGB(96, 245, 255),
	Utility = Color3.fromRGB(190, 116, 255),
	Danger = Color3.fromRGB(255, 145, 72),
}

local itemESPColorLookup = {}
for _, itemName in ipairs(itemNames) do
	local key = normalizeName(itemName)
	if string.find(key, "true power") then
		itemESPColorLookup[key] = itemESPColors.TruePower
	elseif string.find(key, "strength") or string.find(key, "bull") or string.find(key, "sphere") then
		itemESPColorLookup[key] = itemESPColors.Power
	elseif string.find(key, "speed") or string.find(key, "boba") then
		itemESPColorLookup[key] = itemESPColors.Speed
	elseif string.find(key, "frog") then
		itemESPColorLookup[key] = itemESPColors.Jump
	elseif string.find(key, "heal") or string.find(key, "bandage") or string.find(key, "apple") then
		itemESPColorLookup[key] = itemESPColors.Heal
	elseif string.find(key, "forcefield") or string.find(key, "cube") then
		itemESPColorLookup[key] = itemESPColors.Defense
	elseif string.find(key, "gravitation") or string.find(key, "lightning") then
		itemESPColorLookup[key] = itemESPColors.Utility
	elseif string.find(key, "bomb") or string.find(key, "tomahawk") then
		itemESPColorLookup[key] = itemESPColors.Danger
	else
		itemESPColorLookup[key] = itemESPColors.Default
	end
end

function ItemESP:GetColor(itemName)
	return itemESPColorLookup[normalizeName(itemName)] or itemESPColors.Default
end

function ItemESP:Clear()
	for object in pairs(self.Rows) do
		local row = self.Rows[object]
		if row and row.Highlight then row.Highlight:Destroy() end
		if row and row.Billboard then row.Billboard:Destroy() end
	end
	self.Rows = {}
	if self.Folder then
		self.Folder:Destroy()
		self.Folder = nil
	end
end

function ItemESP:EnsureFolder()
	if self.Folder and self.Folder.Parent then return self.Folder end
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Part"
	self.Folder.Parent = PlayerGui
	return self.Folder
end

function ItemESP:CreateOrUpdate(object, itemName, part)
	self:EnsureFolder()

	local row = self.Rows[object]
	if not row then
		row = {}
		self.Rows[object] = row

		row.Highlight = Instance.new("Highlight")
		row.Highlight.Name = "Part"
		row.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		row.Highlight.FillTransparency = 0.72
		row.Highlight.OutlineTransparency = 0
		row.Highlight.Parent = self.Folder

		row.Billboard = Instance.new("BillboardGui")
		row.Billboard.Name = "Part"
		row.Billboard.Size = UDim2.fromOffset(240, 48)
		row.Billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		row.Billboard.AlwaysOnTop = true
		row.Billboard.MaxDistance = 1200
		row.Billboard.Parent = self.Folder

		row.Label = Instance.new("TextLabel")
		row.Label.Name = "Part"
		row.Label.Size = UDim2.fromScale(1, 1)
		row.Label.BackgroundTransparency = 1
		row.Label.Font = Enum.Font.GothamBlack
		row.Label.TextSize = 20
		row.Label.TextStrokeTransparency = 0.12
		row.Label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		row.Label.TextWrapped = true
		row.Label.Parent = row.Billboard
	end

	local color = self:GetColor(itemName)
	row.Highlight.Adornee = object:IsA("Model") and object or part
	row.Highlight.FillColor = color
	row.Highlight.OutlineColor = color
	row.Billboard.Adornee = part
	row.Label.Text = itemName
	row.Label.TextColor3 = color
end

function ItemESP:Refresh()
	local seen = {}

	for _, object in ipairs(Items:GetSearchDescendants()) do
		local part = getLiveItemPart(object)
		if part then
			for _, itemName in ipairs(itemNames) do
				if object.Name == itemName then
					seen[object] = true
					self:CreateOrUpdate(object, itemName, part)
					break
				end
			end
		end
	end

	for object in pairs(self.Rows) do
		if not seen[object] then
			local row = self.Rows[object]
			if row and row.Highlight then row.Highlight:Destroy() end
			if row and row.Billboard then row.Billboard:Destroy() end
			self.Rows[object] = nil
		end
	end
end

function ItemESP:Start()
	if self.Thread then return end
	self.Thread = task.spawn(function()
		while self.Enabled do
			self:Refresh()
			task.wait(self.RefreshDelay)
		end
		self.Thread = nil
	end)
end

function UI.SetItemESP(state, silent)
	ItemESP.Enabled = state == true

	if ItemESP.Enabled then
		ItemESP:Start()
		ItemESP:Refresh()
		if not silent then
			Notify("Item ESP", "Item ESP enabled.", "success")
		end
	else
		ItemESP:Clear()
		if not silent then
			Notify("Item ESP", "Item ESP disabled.", "info")
		end
	end
end

-- ============================================================
-- AUTO REJOIN
-- ============================================================

local AutoRejoinEnabled = false
local AutoRejoinConnections = {}
local AutoRejoinBusy = false
local AutoRejoinPlaceId = 9426795465
local AutoRejoinServerPageLimit = 4

function UI:DisconnectAutoRejoin()
	for _, connection in ipairs(AutoRejoinConnections) do
		if connection then
			pcall(function() connection:Disconnect() end)
		end
	end
	table.clear(AutoRejoinConnections)
end

function UI:FetchAutoRejoinServers(placeId, cursor)
	local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"
	if type(cursor) == "string" and cursor ~= "" then
		local encodedCursor = cursor
		pcall(function() encodedCursor = HttpService:UrlEncode(cursor) end)
		url = url .. "&cursor=" .. tostring(encodedCursor)
	end

	local body = nil
	local ok, result = pcall(function() return game:HttpGet(url) end)
	if ok and type(result) == "string" and result ~= "" then
		body = result
	else
		local requestFunction = nil
		if type(syn) == "table" and type(syn.request) == "function" then
			requestFunction = syn.request
		elseif type(http) == "table" and type(http.request) == "function" then
			requestFunction = http.request
		elseif type(http_request) == "function" then
			requestFunction = http_request
		elseif type(request) == "function" then
			requestFunction = request
		end

		if type(requestFunction) == "function" then
			local requestOk, response = pcall(function()
				return requestFunction({
					Url = url,
					Method = "GET",
				})
			end)
			if requestOk and type(response) == "table" then
				body = response.Body or response.body
			end
		end
	end

	if type(body) ~= "string" or body == "" then return nil end

	local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
	if decodeOk and type(decoded) == "table" then
		return decoded
	end
	return nil
end

function UI:GetHighestPlayerAutoRejoinServer(placeId)
	local bestServerId = nil
	local bestPlaying = -1
	local cursor = nil

	for _ = 1, AutoRejoinServerPageLimit do
		local decoded = self:FetchAutoRejoinServers(placeId, cursor)
		if type(decoded) ~= "table" then break end

		for _, server in ipairs(decoded.data or {}) do
			local serverId = tostring(server.id or "")
			local playing = tonumber(server.playing) or 0
			if serverId ~= "" and serverId ~= game.JobId and playing < 30 and playing > bestPlaying then
				bestServerId = serverId
				bestPlaying = playing
			end
		end

		if bestServerId then break end
		cursor = decoded.nextPageCursor
		if type(cursor) ~= "string" or cursor == "" then break end
	end

	return bestServerId, bestPlaying
end

function UI:TeleportAutoRejoin(reason)
	if AutoRejoinBusy then return end
	AutoRejoinBusy = true
	Notify("Auto Rejoin", "Finding fullest server after " .. tostring(reason) .. ".", "info")

	task.spawn(function()
		local placeId = tonumber(AutoRejoinPlaceId) or game.PlaceId
		local serverId, playing = self:GetHighestPlayerAutoRejoinServer(placeId)
		local joinedServer = false

		if serverId then
			Notify("Auto Rejoin", "Joining fullest server (" .. tostring(playing) .. " players).", "info")
			joinedServer = pcall(function()
				TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
			end)
		end

		if not joinedServer then
			Notify("Auto Rejoin", "Joining place " .. tostring(placeId) .. ".", "info")
			pcall(function() TeleportService:Teleport(placeId, player) end)
		end

		task.wait(3)
		AutoRejoinBusy = false
	end)
end

function UI:HookAutoRejoinCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	table.insert(AutoRejoinConnections, humanoid.Died:Connect(function()
		if AutoRejoinEnabled then
			self:TeleportAutoRejoin("death")
		end
	end))
end

function UI.SetAutoRejoin(state, silent)
	AutoRejoinEnabled = state == true
	self:DisconnectAutoRejoin()

	if AutoRejoinEnabled then
		AutoRejoinBusy = false
		self:HookAutoRejoinCharacter(getCharacter())

		table.insert(AutoRejoinConnections, player.CharacterAdded:Connect(function(character)
			task.wait(0.3)
			if AutoRejoinEnabled then
				self:HookAutoRejoinCharacter(character)
			end
		end))

		pcall(function()
			table.insert(AutoRejoinConnections, GuiService.ErrorMessageChanged:Connect(function()
				if AutoRejoinEnabled then
					self:TeleportAutoRejoin("disconnect")
				end
			end))
		end)

		if not silent then
			Notify("Auto Rejoin", "Auto rejoin enabled.", "success")
		end
	else
		AutoRejoinBusy = false
		if not silent then
			Notify("Auto Rejoin", "Auto rejoin disabled.", "info")
		end
	end
end

-- ============================================================
-- RECOMMENDED SETTINGS
-- ============================================================

function UI.SetRecommendedSettings(state, silent)
	local enabled = state == true

	local function setToggle(key, value)
		local ref = UI.ToggleRefs[key]
		if ref and ref.Set then
			ref.Set(value, false)
		end
	end

	setToggle("SlapAura", enabled)
	setToggle("AutoHeal", enabled)
	setToggle("AntiRagdoll", enabled)
	setToggle("AutoSort", enabled)
	setToggle("PlayerESP", enabled)
	setToggle("ItemESP", enabled)
	setToggle("AutoRejoin", enabled)

	if enabled then
		setToggle("EarlyBusJump", true)
		UI.SetAutoEarlyBusJump(true, true)
		Notify("Recommended Settings", "Applied recommended settings.", "success")
	else
		setToggle("EarlyBusJump", false)
		UI.SetAutoEarlyBusJump(false, true)
		Notify("Recommended Settings", "Disabled recommended settings.", "info")
	end
end

-- ============================================================
-- COMBAT SYSTEM
-- ============================================================

local Combat = {
	HitboxSize = 10,
	HitboxMinSize = 10,
	HitboxMaxSize = 20,
	HitboxTransparency = 0.7,
	HitboxColor = Color3.fromRGB(0, 170, 255),
	HitboxExpanded = false,
	HitboxVisible = true,
	SavedHitboxes = {},
	HitboxConnection = nil,
	HitboxRefreshInterval = 0.35,
	LastHitboxRefresh = 0,
	AutoGloveTapEnabled = false,
	AutoGloveTapThread = nil,
	AutoGloveTapDebounce = 0.12,
	AutoGloveTapScanInterval = 0.22,
	LastAutoGloveTap = 0,
	SlapAuraEnabled = false,
	SlapAuraThread = nil,
	SlapAuraRange = 20,
	SlapAuraInterval = 0.45,
	AntiSlapEnabled = false,
	AntiSlapBoxFolder = nil,
	AntiSlapWasRagdolled = false,
	AntiSlapEnabledAt = 0,
	AntiSlapActiveUntil = 0,
	LastAntiSlapBoxAt = 0,
	LastAntiSlapCheckAt = 0,
	AntiSlapCheckInterval = 0.35,
	AntiSlapBoxDuration = 1,
	AntiSlapConnections = {},
}

function Combat:GetEnemyRoot(otherPlayer)
	if otherPlayer == player then return nil end
	local character = otherPlayer.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

function Combat:GetPlayerHumanoid(targetPlayer)
	local character = targetPlayer.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

function Combat:IsRagdolledTarget(character, humanoid)
	if not character or not humanoid then return false end

	local ragdollStatuses = {"Ragdoll", "Ragdolled", "IsRagdolled", "Knocked", "KnockedDown", "Downed"}
	for _, statusName in ipairs(ragdollStatuses) do
		if character:GetAttribute(statusName) == true or humanoid:GetAttribute(statusName) == true then
			return true
		end
	end

	local state = humanoid:GetState()
	return humanoid.PlatformStand
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown
end

function Combat:SaveOriginalHitbox(otherPlayer, root)
	if self.SavedHitboxes[otherPlayer] then return end
	self.SavedHitboxes[otherPlayer] = {
		Size = root.Size,
		Transparency = root.Transparency,
		Color = root.Color,
		Material = root.Material,
		CanCollide = root.CanCollide,
	}
end

function Combat:ApplyHitbox(otherPlayer)
	local root = self:GetEnemyRoot(otherPlayer)
	if not root then return end

	local humanoid = self:GetPlayerHumanoid(otherPlayer)
	if not humanoid or humanoid.Health <= 0 or self:IsRagdolledTarget(otherPlayer.Character, humanoid) then
		self:ResetHitbox(otherPlayer)
		return
	end

	self:SaveOriginalHitbox(otherPlayer, root)
	root.Size = Vector3.new(self.HitboxSize, self.HitboxSize, self.HitboxSize)
	root.Transparency = self.HitboxVisible and self.HitboxTransparency or 1
	root.Color = self.HitboxColor
	root.Material = Enum.Material.Neon
	root.CanCollide = false
end

function Combat:ResetHitbox(otherPlayer)
	local root = self:GetEnemyRoot(otherPlayer)
	local saved = self.SavedHitboxes[otherPlayer]

	if root and saved then
		root.Size = saved.Size
		root.Transparency = saved.Transparency
		root.Color = saved.Color
		root.Material = saved.Material
		root.CanCollide = saved.CanCollide
	end

	self.SavedHitboxes[otherPlayer] = nil
end

function Combat:StartHitboxLoop()
	if self.HitboxConnection then return end
	self.HitboxConnection = RunService.Heartbeat:Connect(function()
		if not self.HitboxExpanded then return end

		local now = os.clock()
		if now - self.LastHitboxRefresh < self.HitboxRefreshInterval then return end
		self.LastHitboxRefresh = now

		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			local humanoid = self:GetPlayerHumanoid(otherPlayer)
			if humanoid and humanoid.Health > 0 then
				self:ApplyHitbox(otherPlayer)
			else
				self:ResetHitbox(otherPlayer)
			end
		end
	end)
end

function Combat:StopHitboxLoop()
	if self.HitboxConnection then
		self.HitboxConnection:Disconnect()
		self.HitboxConnection = nil
	end
end

function Combat:RefreshHitboxes()
	if self.HitboxExpanded then
		self:StartHitboxLoop()
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			local humanoid = self:GetPlayerHumanoid(otherPlayer)
			if humanoid and humanoid.Health > 0 then
				self:ApplyHitbox(otherPlayer)
			else
				self:ResetHitbox(otherPlayer)
			end
		end
	else
		self:StopHitboxLoop()
	end
end

function Combat:SetHitboxSize(newSize)
	self.HitboxSize = math.clamp(newSize, self.HitboxMinSize, self.HitboxMaxSize)
	if self.HitboxExpanded then
		self:RefreshHitboxes()
	end
	Notify("Hitbox Size", "Set to " .. tostring(self.HitboxSize), "info")
end

function Combat:SetHitboxExpanded(state)
	self.HitboxExpanded = state == true
	self:RefreshHitboxes()
end

function Combat:SetHitboxVisible(state)
	self.HitboxVisible = state == true
	self:RefreshHitboxes()
end

-- ============================================================
-- COMBAT — Slap Aura
-- ============================================================

function Combat:GetSlapRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("Slap")
end

function Combat:CanUseSlapAuraTarget(targetPlayer)
	if targetPlayer == player then return nil end

	local localCharacter = getCharacter()
	local localRoot = getRoot(localCharacter)
	local targetCharacter = targetPlayer.Character
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

	if not localCharacter or not localRoot or not targetCharacter or not targetRoot then
		return nil
	end

	if targetCharacter:GetAttribute("inBus") == true or localCharacter:GetAttribute("inBus") == true then
		return nil
	end

	if localCharacter:GetAttribute("Ragdolled") ~= false then
		return nil
	end

	if (localRoot.Position - targetRoot.Position).Magnitude > self.SlapAuraRange then
		return nil
	end

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return targetRoot
end

function Combat:StartSlapAura()
	if self.SlapAuraThread then return end
	self.SlapAuraThread = task.spawn(function()
		while self.SlapAuraEnabled do
			local remote = self:GetSlapRemote()
			if remote then
				for _, targetPlayer in ipairs(Players:GetPlayers()) do
					local targetRoot = self:CanUseSlapAuraTarget(targetPlayer)
					if targetRoot then
						pcall(function() remote:FireServer(targetRoot) end)
					end
				end
			end
			task.wait(self.SlapAuraInterval)
		end
		self.SlapAuraThread = nil
	end)
end

function Combat:SetSlapAura(state, silent)
	self.SlapAuraEnabled = state == true

	if self.SlapAuraEnabled then
		self:StartSlapAura()
		if not silent then
			Notify("Slap Aura", "Slap Aura enabled.", "success")
		end
	else
		if not silent then
			Notify("Slap Aura", "Slap Aura disabled.", "info")
		end
	end
end

-- ============================================================
-- COMBAT — Auto Slap
-- ============================================================

function Combat:IsEquippedGloveTool(tool)
	if not tool or not tool:IsA("Tool") then return false end

	local toolName = normalizeName(tool.Name)
	if string.find(toolName, "glove") or string.find(toolName, "slap") then
		return true
	end

	for _, object in ipairs(tool:GetDescendants()) do
		if string.find(normalizeName(object.Name), "glove", 1, true) then
			return true
		end
		if object:IsA("BasePart") then
			return true
		end
	end

	return false
end

function Combat:GetEquippedTool()
	local character = getCharacter()
	if not character then return nil end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end

function Combat:IsValidAutoTapTarget(targetPlayer)
	if targetPlayer == player then return nil, nil, nil end

	local character = targetPlayer.Character
	if not character then return nil, nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	if self:IsRagdolledTarget(character, humanoid) then
		return nil, nil, nil
	end

	return character, humanoid, root
end

function Combat:GetEquippedGloveParts(tool)
	local parts = {}
	if not self:IsEquippedGloveTool(tool) then return parts end

	for _, object in ipairs(tool:GetDescendants()) do
		if object:IsA("BasePart") then
			table.insert(parts, object)
		end
	end

	return parts
end

function Combat:IsPartInsideHitbox(part, hitboxRoot, hitboxSize)
	if not part or not part.Parent or not hitboxRoot or not hitboxRoot.Parent then
		return false
	end

	local localPosition = hitboxRoot.CFrame:PointToObjectSpace(part.Position)
	local halfSize = hitboxSize * 0.5
	local partPadding = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5

	return math.abs(localPosition.X) <= halfSize.X + partPadding
		and math.abs(localPosition.Y) <= halfSize.Y + partPadding
		and math.abs(localPosition.Z) <= halfSize.Z + partPadding
end

function Combat:FindAutoGloveTapTarget()
	local tool = self:GetEquippedTool()
	local gloveParts = self:GetEquippedGloveParts(tool)
	if #gloveParts == 0 then return nil end

	local character = getCharacter()
	local root = getRoot(character)
	local hitboxSize = Vector3.new(self.HitboxSize, self.HitboxSize, self.HitboxSize)

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local _, _, targetRoot = self:IsValidAutoTapTarget(targetPlayer)
		if targetRoot then
			local localPosition = targetRoot.CFrame:PointToObjectSpace(root.Position)
			local distance = math.abs(localPosition.X) + math.abs(localPosition.Y) + math.abs(localPosition.Z)

			if distance <= 15 then
				return targetPlayer
			end
		end
	end

	return nil
end

function Combat:TapEquippedGlove()
	local now = os.clock()
	if now - self.LastAutoGloveTap < self.AutoGloveTapDebounce then
		return false
	end

	local tool = self:GetEquippedTool()
	if not self:IsEquippedGloveTool(tool) then
		return false
	end

	self.LastAutoGloveTap = now
	pcall(function() tool:Activate() end)
	return true
end

function Combat:StartAutoGloveTap()
	if self.AutoGloveTapThread then return end
	self.AutoGloveTapThread = task.spawn(function()
		while self.AutoGloveTapEnabled do
			if self:FindAutoGloveTapTarget() then
				self:TapEquippedGlove()
			end
			task.wait(self.AutoGloveTapScanInterval)
		end
		self.AutoGloveTapThread = nil
	end)
end

function Combat:SetAutoGloveTap(state, silent)
	self.AutoGloveTapEnabled = state == true

	if self.AutoGloveTapEnabled then
		self:StartAutoGloveTap()
		if not silent then
			Notify("Auto Slap", "Auto Slap enabled.", "success")
		end
	else
		if not silent then
			Notify("Auto Slap", "Auto Slap disabled.", "info")
		end
	end
end

-- ============================================================
-- COMBAT — Anti-Ragdoll
-- ============================================================

function Combat:SpawnAntiSlapBox()
	if self.AntiSlapBoxFolder and self.AntiSlapBoxFolder.Parent then
		return
	end

	local character = getCharacter()
	local root = getRoot(character)
	if not root then return end

	self.LastAntiSlapBoxAt = os.clock()

	local folder = Instance.new("Folder")
	folder.Name = "Part"
	folder.Parent = workspace
	self.AntiSlapBoxFolder = folder

	local center = root.CFrame
	local innerWidth = 8
	local innerHeight = 8
	local innerDepth = 8
	local thickness = 40

	local function createPart(cframe, size)
		local part = Instance.new("Part")
		part.Name = "Part"
		part.Size = size
		part.CFrame = cframe
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 1
		part.Parent = folder
		return part
	end

	createPart(center * CFrame.new(0, -(innerHeight / 2 + thickness / 2), 0), Vector3.new(outerWidth, thickness, outerDepth))
	createPart(center * CFrame.new(0, innerHeight / 2 + thickness / 2, 0), Vector3.new(outerWidth, thickness, outerDepth))
	createPart(center * CFrame.new(innerWidth / 2 + thickness / 2, 0, 0), Vector3.new(thickness, outerHeight, outerDepth))
	createPart(center * CFrame.new(-(innerWidth / 2 + thickness / 2), 0, 0), Vector3.new(thickness, outerHeight, outerDepth))
	createPart(center * CFrame.new(0, 0, innerDepth / 2 + thickness / 2), Vector3.new(outerWidth, outerHeight, thickness))
	createPart(center * CFrame.new(0, 0, -(innerDepth / 2 + thickness / 2)), Vector3.new(outerWidth, outerHeight, thickness))
end

function Combat:ClearAntiSlapBox()
	if self.AntiSlapBoxFolder then
		self.AntiSlapBoxFolder:Destroy()
		self.AntiSlapBoxFolder = nil
	end
end

function Combat:IsLocalAntiSlapRagdolled(character, humanoid)
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local ragdollStatuses = {"Ragdoll", "Ragdolled", "IsRagdolled", "IsInRagdoll", "Ragdolling"}
	for _, statusName in ipairs(ragdollStatuses) do
		if player:GetAttribute(statusName) == true
			or character:GetAttribute(statusName) == true
			or humanoid:GetAttribute(statusName) == true then
			return true
		end
	end

	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown
end

function Combat:IsLocalAntiSlapKnockbacked(character, humanoid, root)
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	if os.clock() - self.AntiSlapEnabledAt < 0.75 then
		return false
	end

	local state = humanoid:GetState()
	if not (humanoid.PlatformStand
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown) then
		return false
	end

	local velocity = root.AssemblyLinearVelocity or Vector3.zero
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	return horizontalVelocity >= 38 or math.abs(velocity.Y) >= 50
end

function Combat:UpdateAntiSlapBox(character, humanoid)
	if not self.AntiSlapEnabled then
		self:ClearAntiSlapBox()
		return
	end

	local root = character and character:FindFirstChild("HumanoidRootPart")
	local isRagdolled = self:IsLocalAntiSlapRagdolled(character, humanoid)
	local isKnockbacked = self:IsLocalAntiSlapKnockbacked(character, humanoid, root)
	local now = os.clock()

	if isRagdolled or isKnockbacked then
		self.AntiSlapActiveUntil = math.max(self.AntiSlapActiveUntil, now + 1)
	end

	local shouldBox = isRagdolled or isKnockbacked or now < self.AntiSlapActiveUntil

	if shouldBox then
		self:SpawnAntiSlapBox()
	else
		self:ClearAntiSlapBox()
	end
end

function Combat:ClearAntiSlapConnections()
	for _, connection in ipairs(self.AntiSlapConnections) do
		connection:Disconnect()
	end
	self.AntiSlapConnections = {}
end

function Combat:HookAntiSlapCharacter()
	self:ClearAntiSlapConnections()

	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not character or not humanoid then return end

	self:ClearAntiSlapBox()
	self.AntiSlapWasRagdolled = false
	self.AntiSlapEnabledAt = os.clock()
	self.AntiSlapActiveUntil = 0

	table.insert(self.AntiSlapConnections, humanoid.StateChanged:Connect(function()
		self:UpdateAntiSlapBox(character, humanoid)
	end))

	for _, statusName in ipairs({"Ragdoll", "Ragdolled", "IsRagdolled"}) do
		table.insert(self.AntiSlapConnections, character:GetAttributeChangedSignal(statusName):Connect(function()
			self:UpdateAntiSlapBox(character, humanoid)
		end))
	end

	table.insert(self.AntiSlapConnections, RunService.Heartbeat:Connect(function()
		if not self.AntiSlapEnabled then
			self:ClearAntiSlapBox()
			return
		end

		local now = os.clock()
		if now - self.LastAntiSlapCheckAt < self.AntiSlapCheckInterval then return end
		self.LastAntiSlapCheckAt = now
		self:UpdateAntiSlapBox(character, humanoid)
	end))
end

function Combat:SetAntiSlap(state, silent)
	self.AntiSlapEnabled = state == true

	if self.AntiSlapEnabled then
		self.AntiSlapWasRagdolled = false
		self.AntiSlapEnabledAt = os.clock()
		self.AntiSlapActiveUntil = 0
		self:HookAntiSlapCharacter()
		if not silent then
			Notify("Anti-Ragdoll", "Anti-Ragdoll enabled.", "success")
		end
	else
		self:ClearAntiSlapConnections()
		self:ClearAntiSlapBox()
		if not silent then
			Notify("Anti-Ragdoll", "Anti-Ragdoll disabled.", "info")
		end
	end
end

-- ============================================================
-- COMBAT — Teleport to Players
-- ============================================================

function Combat:GetValidPlayerTarget(targetPlayer)
	if targetPlayer == player then return nil, nil, nil end

	local character = targetPlayer.Character
	if not character then return nil, nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	if self:IsRagdolledTarget(character, humanoid) then
		return nil, nil, nil
	end

	return character, humanoid, root
end

function Combat:TeleportToPlayer(targetPlayer)
	if not Teleport:CanTeleport() then
		return false
	end

	local character = getCharacter()
	local root = getRoot(character)
	if not root then
		Notify("Players", "Could not find your character.", "error")
		return false
	end

	local _, _, targetRoot = self:GetValidPlayerTarget(targetPlayer)
	if not targetRoot then
		Notify("Players", "Target player is unavailable or ragdolled.", "warning")
		return false
	end

	local targetCFrame = Teleport:GetGroundCFrame(targetRoot.Position, { character, targetPlayer.Character }, true)
	Teleport:MoveRoot(root, targetCFrame)
	Teleport:AddStrike()
	Teleport:StartFBlock()
	Notify("Players", "Teleported to " .. targetPlayer.Name, "success")
	return true
end

function Combat:TeleportToLowestHealthPlayer()
	local lowestPlayer = nil
	local lowestHealth = math.huge

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local _, humanoid, _ = self:GetValidPlayerTarget(targetPlayer)
		if humanoid and humanoid.Health < lowestHealth then
			lowestHealth = humanoid.Health
			lowestPlayer = targetPlayer
		end
	end

	if lowestPlayer then
		self:TeleportToPlayer(lowestPlayer)
	else
		Notify("Players", "No valid lowest health player found.", "warning")
	end
end

function Combat:TeleportToNearestPlayer()
	local character = getCharacter()
	local root = getRoot(character)
	if not root then
		Notify("Players", "Could not find your character.", "error")
		return
	end

	local nearestPlayer = nil
	local nearestDistance = math.huge

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local _, _, targetRoot = self:GetValidPlayerTarget(targetPlayer)
		if targetRoot then
			local distance = (root.Position - targetRoot.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = targetPlayer
			end
		end
	end

	if nearestPlayer then
		self:TeleportToPlayer(nearestPlayer)
	else
		Notify("Players", "No valid nearest player found.", "warning")
	end
end

-- ============================================================
-- SAFETY — Anti-Staff
-- ============================================================

local AntiStaff = {
	Enabled = false,
	Connections = {},
	Keywords = {
		"record", "recording", "rec", "clip", "proof", "evidence", "caught", "exposed",
		"screenshot", "screen record", "obs", "shadowplay", "nvidia", "stream",
		"staff", "admin", "mod", "moderator", "report", "reported", "ticket", "discord",
		"grava", "prova", "video", "aufnahme", "beweis",
		"enregistrer", "preuve", "registrare", "录制", "录像", "証拠"
	}
}

function AntiStaff:GetStaffKeyword(message)
	local lowerMessage = string.lower(tostring(message or ""))
	for _, keyword in ipairs(self.Keywords) do
		if string.find(lowerMessage, string.lower(keyword), 1, true) then
			return keyword
		end
	end
	return nil
end

function AntiStaff:HandleStaffChat(speaker, message)
	if not self.Enabled or speaker == player then return end

	local keyword = self:GetStaffKeyword(message)
	if keyword then
		Notify("Anti-Staff", "Detected: " .. keyword .. " from " .. speaker.Name, "error")
		player:Kick("Anti-Staff: " .. speaker.Name .. " said: " .. message)
	end
end

function AntiStaff:HookStaffPlayer(targetPlayer)
	if targetPlayer == player then return end

	table.insert(self.Connections, targetPlayer.Chatted:Connect(function(message)
		self:HandleStaffChat(targetPlayer, message)
	end))
end

function AntiStaff:ClearConnections()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}
end

function AntiStaff:SetEnabled(state, silent)
	self.Enabled = state == true
	self:ClearConnections()

	if self.Enabled then
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			self:HookStaffPlayer(targetPlayer)
		end
		table.insert(self.Connections, Players.PlayerAdded:Connect(function(targetPlayer)
			self:HookStaffPlayer(targetPlayer)
		end))
		if not silent then
			Notify("Anti-Staff", "Anti-Staff enabled.", "success")
		end
	else
		if not silent then
			Notify("Anti-Staff", "Anti-Staff disabled.", "info")
		end
	end
end

-- ============================================================
-- SAFETY — Hide Under Map
-- ============================================================

local HideUnderMapEnabled = false

function AntiStaff:SetHideUnderMap(state, silent)
	local character = getCharacter()
	local root = getRoot(character)

	if not root then
		Notify("Hide under map", "Could not find your character.", "error")
		return
	end

	if state and not Teleport:CanPassStabilityGate() then
		return
	end

	local targetCFrame = nil

	if state then
		local platform = ensureUnderMapSafetyPlatform()
		platform.CanCollide = true
		platform.CanTouch = false
		platform.CanQuery = false
		HideUnderMapEnabled = true
		targetCFrame = CFrame.new(root.Position.X, platform.Position.Y + (platform.Size.Y * 0.5) + UNDER_MAP_SAFE_OFFSET, root.Position.Z)
		if not silent then
			Notify("Hide under map", "Moved under the map.", "success")
		end
	else
		local platform = UnderMapSafetyPlatform
		HideUnderMapEnabled = false

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }

		local origin = Vector3.new(root.Position.X, 320, root.Position.Z)
		local result = workspace:Raycast(origin, Vector3.new(0, -520, 0), params)

		if result and result.Position.Y > -80 and result.Position.Y < 260 then
			targetCFrame = CFrame.new(root.Position.X, result.Position.Y + UNDER_MAP_SAFE_OFFSET, root.Position.Z)
		else
			targetCFrame = CFrame.new(root.Position.X, 30 + UNDER_MAP_SAFE_OFFSET, root.Position.Z)
		end

		if not silent then
			Notify("Hide under map", "Moved back above ground.", "info")
		end

		if platform and platform.Parent then
			platform.CanCollide = false
			platform.CanTouch = false
			platform.CanQuery = false
		end
	end

	Teleport:MoveRoot(root, targetCFrame)
end

-- ============================================================
-- SAFETY — Auto Optimize Cooldown Settings
-- ============================================================

local function readCurrentPing()
	local ok, rawPing = pcall(function()
		return player:GetNetworkPing()
	end)

	if ok and rawPing and rawPing > 0 then
		local milliseconds = rawPing <= 10 and (rawPing * 1000) or rawPing
		if milliseconds >= 1 and milliseconds <= 500 then
			return milliseconds
		end
	end

	return 131
end

function AntiStaff:RunAutoOptimizeCooldownSettings(silent)
	if Teleport.AutoOptimizeCooldownApplying then
		if not silent then
			Notify("Cooldown settings", "Already checking ping.", "info")
		end
		return
	end

	Teleport.AutoOptimizeCooldownApplying = true

	task.spawn(function()
		local ping = readCurrentPing() or 131
		local settings = nil

		if ping <= 80 then
			settings = { FLock = 0.1, TPDebounce = 0.1, MaxStrikes = 10 }
		elseif ping <= 130 then
			settings = { FLock = 0.2, TPDebounce = 0.3, MaxStrikes = 5 }
		else
			settings = { FLock = 0.5, TPDebounce = 1, MaxStrikes = 4 }
		end

		Teleport.PostFLock = settings.FLock
		Teleport.Debounce = settings.TPDebounce
		Teleport.MaxStrikes = settings.MaxStrikes
		Items.TeleportDebounce = settings.TPDebounce

		if not silent then
			Notify("Cooldown settings", "Optimized for " .. tostring(math.floor(ping + 0.5)) .. " ms ping.", "success")
		end

		Teleport.AutoOptimizeCooldownApplying = false
	end)

	if not silent then
		Notify("Cooldown settings", "Checking ping and optimizing settings.", "info")
	end
end

-- ============================================================
-- TELEPORT MENU (CornUi Native)
-- ============================================================

local TeleportMenu = {
	ActiveTab = "Items",
	Rows = {},
}

local function buildTeleportMenuItems()
	local items = {}
	local seen = {}
	local liveNames = {}

	for _, itemName in ipairs(itemNames) do
		if not seen[normalizeName(itemName)] then
			seen[normalizeName(itemName)] = true
			table.insert(items, itemName)
		end
	end

	Items:RefreshCrates()
	if #Items.Crates > 0 then
		liveNames[normalizeName("Meteor Crate")] = true
	end

	return items, liveNames
end

local function createTeleportMenu()
	-- This will be built using CornUi's native UI elements
	-- Since CornUi doesn't have a built-in side menu, we'll use a card with buttons
end

-- ============================================================
-- CORNUI UI ELEMENTS
-- ============================================================

-- Store toggle references for cross-tab control
UI.ToggleRefs = {}

-- Create Main Tab elements
local MainSection = MainTab:CreateSection("Core Features")

MainSection:CreateButton({
	Name = "Get Code + Go Barn",
	Description = "Teleports to Barn and scans for puzzle code",
	Callback = function()
		Teleport:ToLocation("Bunker", CodeSearchOrigin, true)
		Notify("Code", "Searching...", "info", 2.2)

		task.spawn(function()
			task.wait(0.45)
			local code = MainGetPuzzleCode()
			Notify("Code Found", code ~= "" and code or "No code found.", code ~= "" and "success" or "info", 4)

			if code ~= "" then
				task.wait(0.2)
				if MainEnterBarnKeypadCode(code) then
					Notify("Barn Keypad", "Entered and submitted " .. code .. ".", "success", 3.5)
				else
					Notify("Barn Keypad", "Found code, but could not press every keypad button.", "warning", 4)
				end
			end
		end)
	end
})

MainSection:CreateButton({
	Name = "Open Teleport Menu",
	Description = "Items, players, and map locations",
	Callback = function()
		-- Build teleport menu inline
		local menuTab = Window:CreateTab("Teleport Menu", { Icon = "📍" })
		local menuSection = menuTab:CreateSection("Items")

		local itemNamesList, liveNames = buildTeleportMenuItems()
		for _, itemName in ipairs(itemNamesList) do
			menuSection:CreateButton({
				Name = itemName,
				Callback = function()
					if itemName == "Meteor Crate" then
						Items:TeleportToCrate()
					else
						Items:TeleportTo(itemName)
					end
				end
			})
		end

		local playersSection = menuTab:CreateSection("Players")
		playersSection:CreateButton({
			Name = "Teleport To Nearest",
			Callback = function() Combat:TeleportToNearestPlayer() end
		})
		playersSection:CreateButton({
			Name = "Teleport To Lowest Health",
			Callback = function() Combat:TeleportToLowestHealthPlayer() end
		})

		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player then
				playersSection:CreateButton({
					Name = targetPlayer.Name,
					Callback = function() Combat:TeleportToPlayer(targetPlayer) end
				})
			end
		end

		local locSection = menuTab:CreateSection("Locations")
		for _, location in ipairs(Teleport.Locations) do
			locSection:CreateButton({
				Name = location.Name,
				Callback = function() Teleport:ToLocation(location.Name, location.Position) end
			})
		end
	end
})

MainSection:CreateToggle({
	Name = "Early Bus Jump",
	Description = "Automatically jumps out when you are seated in the bus",
	Default = false,
	Callback = function(state)
		UI.SetAutoEarlyBusJump(state, false)
	end,
	Flag = "EarlyBusJump"
})
UI.ToggleRefs.EarlyBusJump = MainSection._lastToggle

MainSection:CreateToggle({
	Name = "Infinite Jump",
	Description = "Lets you jump again while airborne",
	Default = false,
	Callback = function(state)
		UI.SetInfiniteJump(state, false)
	end,
	Flag = "InfiniteJump"
})
UI.ToggleRefs.InfiniteJump = MainSection._lastToggle

MainSection:CreateToggle({
	Name = "Player Stats ESP",
	Description = "Shows player health, kills, strength, and speed",
	Default = false,
	Callback = function(state)
		UI.SetPlayerStatsESP(state, false)
	end,
	Flag = "PlayerESP"
})
UI.ToggleRefs.PlayerESP = MainSection._lastToggle

MainSection:CreateToggle({
	Name = "Item ESP",
	Description = "Highlights dropped items with color tags",
	Default = false,
	Callback = function(state)
		UI.SetItemESP(state, false)
	end,
	Flag = "ItemESP"
})
UI.ToggleRefs.ItemESP = MainSection._lastToggle

MainSection:CreateToggle({
	Name = "Auto Rejoin",
	Description = "Rejoins after death or disconnect",
	Default = false,
	Callback = function(state)
		UI.SetAutoRejoin(state, false)
	end,
	Flag = "AutoRejoin"
})
UI.ToggleRefs.AutoRejoin = MainSection._lastToggle

MainSection:CreateToggle({
	Name = "Recommended Settings",
	Description = "Slap Aura, ESP, anti-ragdoll, sorting, rejoin, and item menu",
	Default = false,
	Callback = function(state)
		UI.SetRecommendedSettings(state, false)
	end,
	Flag = "RecommendedSettings"
})
UI.ToggleRefs.RecommendedSettings = MainSection._lastToggle

-- Items Tab
local ItemsSection = ItemsTab:CreateSection("Item Management")

local autoCollectRef = ItemsSection:CreateToggle({
	Name = "Auto collect",
	Description = "Collects priority items without waiting for the round countdown",
	Default = false,
	Callback = function(state)
		Items:SetAutoCollect(state, false)
	end,
	Flag = "AutoCollect"
})
Items.AutoCollectToggle = autoCollectRef

local autoPickupRef = ItemsSection:CreateToggle({
	Name = "Auto pick up",
	Description = "Creates an invisible pickup zone around you",
	Default = false,
	Callback = function(state)
		Items:SetAutoPickup(state, false)
	end,
	Flag = "AutoPickup"
})
Items.AutoPickupToggle = autoPickupRef

ItemsSection:CreateToggle({
	Name = "Auto Heal",
	Description = "Uses healing items when HP drops",
	Default = false,
	Callback = function(state)
		Items:SetAutoHeal(state, false)
	end,
	Flag = "AutoHeal"
})

ItemsSection:CreateToggle({
	Name = "Auto Sort",
	Description = "Glove in slot 1, priority items next",
	Default = false,
	Callback = function(state)
		Items:SetAutoSort(state, false)
	end,
	Flag = "AutoSort"
})

local permanentRef = ItemsSection:CreateToggle({
	Name = "Auto Use Permanent Items",
	Description = "Uses permanent boosts on pickup",
	Default = false,
	Callback = function(state)
		setAutoPermanentItems(state, false)
	end,
	Flag = "AutoPermanentItems"
})
autoPermanentToggle = permanentRef

ItemsSection:CreateDivider()

ItemsSection:CreateButton({
	Name = "Use Spheres",
	Description = "Uses all Sphere of Fury tools in your inventory",
	Callback = function() Items:UseSpheres() end
})

ItemsSection:CreateButton({
	Name = "Use Cubes",
	Description = "Uses all Cube of Ice tools in your inventory",
	Callback = function() Items:UseCubes() end
})

ItemsSection:CreateButton({
	Name = "Use All Items",
	Description = "Uses every held game item quickly",
	Callback = function() Items:UseAllItems() end
})

ItemsSection:CreateButton({
	Name = "Drop All Items",
	Description = "Drops every held game item quickly",
	Callback = function() Items:DropAllItems() end
})

ItemsSection:CreateButton({
	Name = "Drop Permanent Items",
	Description = "Drops all permanent boost items quickly",
	Callback = function() Items:DropAllPermanents() end
})

ItemsSection:CreateButton({
	Name = "Drop Temp Items",
	Description = "Drops non-permanent held items quickly",
	Callback = function() Items:DropTempItems() end
})

ItemsSection:CreateButton({
	Name = "Meteor Crate",
	Description = "Teleports to nearest meteor crate",
	Callback = function() Items:TeleportToCrate() end
})

-- Teleports Tab
local TeleportsSection = TeleportsTab:CreateSection("Teleport Locations")

TeleportsSection:CreateButton({
	Name = "Teleport On School Bus",
	Description = "Teleports you on top of the school bus",
	Callback = function() Teleport:ToSchoolBusTop() end
})

for _, location in ipairs(Teleport.Locations) do
	TeleportsSection:CreateButton({
		Name = location.Name,
		Callback = function() Teleport:ToLocation(location.Name, location.Position) end
	})
end

-- Combat Tab
local CombatSection = CombatTab:CreateSection("Combat Settings")

CombatSection:CreateSlider({
	Name = "Hitbox Size",
	Min = Combat.HitboxMinSize,
	Max = Combat.HitboxMaxSize,
	Default = Combat.HitboxSize,
	Callback = function(value)
		Combat:SetHitboxSize(value)
	end,
	Flag = "HitboxSize"
})

CombatSection:CreateToggle({
	Name = "Expand Hitbox",
	Description = "Applies expanded hitbox to players",
	Default = false,
	Callback = function(state)
		Combat:SetHitboxExpanded(state)
	end,
	Flag = "ExpandHitbox"
})
UI.ToggleRefs.ExpandHitbox = CombatSection._lastToggle

CombatSection:CreateToggle({
	Name = "Visualize Hitboxes",
	Description = "Shows neon hitbox preview",
	Default = Combat.HitboxVisible,
	Callback = function(state)
		Combat:SetHitboxVisible(state)
	end,
	Flag = "VisualizeHitboxes"
})
UI.ToggleRefs.VisualizeHitboxes = CombatSection._lastToggle

CombatSection:CreateToggle({
	Name = "Slap Aura",
	Description = "Slaps valid nearby match players",
	Default = false,
	Callback = function(state)
		Combat:SetSlapAura(state, false)
	end,
	Flag = "SlapAura"
})
UI.ToggleRefs.SlapAura = CombatSection._lastToggle

CombatSection:CreateToggle({
	Name = "Auto Slap",
	Description = "Taps when enemy enters hitbox",
	Default = false,
	Callback = function(state)
		Combat:SetAutoGloveTap(state, false)
	end,
	Flag = "AutoSlap"
})
UI.ToggleRefs.AutoSlap = CombatSection._lastToggle

CombatSection:CreateDivider()

CombatSection:CreateButton({
	Name = "Teleport To Lowest Health",
	Description = "Teleports you behind the player with the lowest HP",
	Callback = function() Combat:TeleportToLowestHealthPlayer() end
})

CombatSection:CreateButton({
	Name = "Teleport To Nearest",
	Description = "Teleports you behind the closest player",
	Callback = function() Combat:TeleportToNearestPlayer() end
})

-- BETA Tab
local BETASection = BETATab:CreateSection("Experimental Features")

BETASection:CreateButton({
	Name = "Collect Crates",
	Description = "Teleports under each crate and collects them in order",
	Callback = function() Items:CollectCrates() end
})

BETASection:CreateToggle({
	Name = "Auto collect crates",
	Description = "Rapidly slaps tracked meteor crates",
	Default = false,
	Callback = function(state)
		Items:SetFastCollectCrates(state, false)
	end,
	Flag = "FastCollectCrates"
})
UI.ToggleRefs.FastCollectCrates = BETASection._lastToggle

BETASection:CreateToggle({
	Name = "Crate Aura",
	Description = "Slaps nearby meteor crates without teleporting",
	Default = false,
	Callback = function(state)
		Items:SetCrateAura(state, false)
	end,
	Flag = "CrateAura"
})
UI.ToggleRefs.CrateAura = BETASection._lastToggle

local earlyCollectRef = BETASection:CreateToggle({
	Name = "Early Auto Collect",
	Description = "Starts collecting items before round begins",
	Default = false,
	Callback = function(state)
		Items:SetEarlyAutoCollect(state, false)
	end,
	Flag = "EarlyAutoCollect"
})
Items.EarlyAutoCollectToggle = earlyCollectRef

-- Safety Tab
local SafetySection = SafetyTab:CreateSection("Safety Features")

SafetySection:CreateButton({
	Name = "Auto optimize cooldown settings",
	Description = "Checks ping and updates cooldown settings",
	Callback = function()
		AntiStaff:RunAutoOptimizeCooldownSettings(false)
	end
})

SafetySection:CreateToggle({
	Name = "Anti-Staff",
	Description = "Leaves when recording keywords detected",
	Default = false,
	Callback = function(state)
		AntiStaff:SetEnabled(state, false)
	end,
	Flag = "AntiStaff"
})
UI.ToggleRefs.AntiStaff = SafetySection._lastToggle

SafetySection:CreateToggle({
	Name = "Hide under map",
	Description = "Hides your character below the map",
	Default = false,
	Callback = function(state)
		AntiStaff:SetHideUnderMap(state, false)
	end,
	Flag = "HideUnderMap"
})
UI.ToggleRefs.HideUnderMap = SafetySection._lastToggle

SafetySection:CreateToggle({
	Name = "Anti-Ragdoll / Anti-Slap",
	Description = "Invisible cage on knockback",
	Default = false,
	Callback = function(state)
		Combat:SetAntiSlap(state, false)
	end,
	Flag = "AntiRagdoll"
})
UI.ToggleRefs.AntiRagdoll = SafetySection._lastToggle

-- Settings Tab
local SettingsSection = SettingsTab:CreateSection("Preferences")

SettingsSection:CreateToggle({
	Name = "Disable Notifications",
	Description = "Turns off all notifications",
	Default = false,
	Callback = function(state)
		NotificationsDisabled = state == true
	end,
	Flag = "DisableNotifications"
})

SettingsSection:CreateDivider()

SettingsSection:CreateButton({
	Name = "Reset to default settings",
	Description = "Resets custom strikes, teleport debounce, and F lock",
	Callback = function()
		Teleport.MaxStrikes = Teleport.DefaultMaxStrikes
		Teleport.Debounce = Teleport.DefaultDebounce
		Teleport.PostFLock = Teleport.DefaultPostFLock
		Items.TeleportDebounce = Teleport.DefaultDebounce
		Notify("Settings", "Custom teleport settings reset to defaults.", "success")
	end
})

SettingsSection:CreateLabel("Custom Strikes: " .. Teleport.DefaultMaxStrikes)
SettingsSection:CreateLabel("Custom TP Debounce: " .. Teleport.DefaultDebounce)
SettingsSection:CreateLabel("Custom F Lock: " .. Teleport.DefaultPostFLock)

-- ============================================================
-- STARTUP
-- ============================================================

-- Ensure crates are tracked
task.defer(function()
	Items:StartCrateWatcher()
end)

-- Cleanup on script end
if getgenv and getgenv() then
	local env = getgenv()
	env.OPSlapRoyaleCleanup = function()
		Items:SetAutoCollect(false, true)
		Items:SetAutoPickup(false, true)
		Items:SetFastCollectCrates(false, true)
		Items:SetCrateAura(false, true)
		Combat:SetSlapAura(false, true)
		Combat:SetHitboxExpanded(false)
		Combat:SetAntiSlap(false, true)
		UI.SetPlayerStatsESP(false, true)
		UI.SetItemESP(false, true)
		UI.SetAutoRejoin(false, true)
		UI.SetInfiniteJump(false, true)
		AntiStaff:SetEnabled(false, true)
		AntiStaff:SetHideUnderMap(false, true)
		Teleport:ClearBusTopRidePlatform()
		clearUnderMapSafetyPlatform()
		if Window and Window.Destroy then
			Window:Destroy()
		end
	end
end

Notify("OP Slap Royale", "Loaded successfully! v1.9.1b Port", "success", 5)
