--[[
	MovementSuite — CornUi plugin
	Speed / Fly / Noclip / Reset Character, wired to both the command
	palette ("speed 50", "fly on", "noclip", "reset-char") and a UI tab.

	Usage:
		local Corn = loadstring(game:HttpGet("<raw CornUi.lua url>"))()
		local Window = Corn:CreateWindow({ Name = "My Hub" })
		Corn:LoadPlugins({
			"https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Plugins/MovementSuite.lua",
		}, Window)

	Notes:
	- Flags used: "Speed", "Fly", "FlySpeed", "Noclip" — read them elsewhere
	  with ctx:GetFlag(name) / Library:GetFlag(name) if other plugins or UI
	  need to react to the same state.
	- Fly reads Humanoid.MoveDirection (works with WASD, mobile thumbstick,
	  and gamepad alike) and steers a BodyVelocity off the camera's look
	  vector, so it needs no per-platform input branching.
	- Respawn/teardown timing (character dying mid-fly, noclip parts
	  streaming out, camera swapping) is the main source of runtime errors
	  here, so those paths are pcall-wrapped rather than left to error out
	  and silently kill a RunService connection.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

return {
	Name = "Movement Suite",
	Version = "1.0.0",

	Init = function(ctx)
		local player = ctx.Player
		local camera = workspace.CurrentCamera

		local function getChar()
			return player.Character
		end

		local function getHumanoid()
			local char = getChar()
			return char and char:FindFirstChildOfClass("Humanoid")
		end

		local function getRoot()
			local char = getChar()
			return char and char:FindFirstChild("HumanoidRootPart")
		end

		----------------------------------------------------------------
		-- Speed
		----------------------------------------------------------------

		local function setSpeed(n)
			n = math.clamp(tonumber(n) or 16, 1, 200)
			ctx:SetFlag("Speed", n)
			local hum = getHumanoid()
			if hum then hum.WalkSpeed = n end
			return n
		end

		-- Re-apply after every respawn, since a fresh Humanoid resets to default.
		player.CharacterAdded:Connect(function(char)
			local ok, hum = pcall(function() return char:WaitForChild("Humanoid", 5) end)
			if not ok or not hum then return end
			local speed = ctx:GetFlag("Speed")
			if speed then hum.WalkSpeed = speed end
		end)

		----------------------------------------------------------------
		-- Fly
		----------------------------------------------------------------

	

local flyVelocity
local flyOrientation
local flyAttachment
local flyConn

local stopFly -- forward declaration

local function startFly()
	if flyConn then return end

	local char = getChar()
	local hum = getHumanoid()
	local root = getRoot()

	if not char or not hum or not root then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "CornFlyAttachment"
	attachment.Parent = root

	flyAttachment = attachment

	flyVelocity = Instance.new("LinearVelocity")
	flyVelocity.Name = "CornFlyVelocity"
	flyVelocity.MaxForce = math.huge
	flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	flyVelocity.Attachment0 = attachment
	flyVelocity.VectorVelocity = Vector3.zero
	flyVelocity.Parent = root


	flyOrientation = Instance.new("AlignOrientation")
	flyOrientation.Name = "CornFlyOrientation"
	flyOrientation.MaxTorque = math.huge
	flyOrientation.Responsiveness = 200
	flyOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flyOrientation.Attachment0 = attachment
	flyOrientation.Parent = root


	hum:ChangeState(Enum.HumanoidStateType.Flying)


	flyConn = RunService.RenderStepped:Connect(function()

		if not flyVelocity or not root.Parent then
			stopFly()
			return
		end


		local cam = workspace.CurrentCamera
		if not cam then return end


		local move = hum.MoveDirection


		local direction = Vector3.zero


		if move.Magnitude > 0 then
			direction =
					(cam.CFrame.RightVector * move.X)
						+
					(cam.CFrame.LookVector * move.Z)
		end


		-- Mobile / PC vertical controls
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			direction += Vector3.new(0,1,0)
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			direction -= Vector3.new(0,1,0)
		end


		local speed = ctx:GetFlag("FlySpeed") or 50

		if direction.Magnitude > 0 then
			flyVelocity.VectorVelocity = direction.Unit * speed
		else
			flyVelocity.VectorVelocity = Vector3.zero
		end


		flyOrientation.CFrame = cam.CFrame
	end)
end



 function stopFly()

	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end


	if flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end


	if flyOrientation then
		flyOrientation:Destroy()
		flyOrientation = nil
	end


	if flyAttachment then
		flyAttachment:Destroy()
		flyAttachment = nil
	end


	local hum = getHumanoid()

	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end



local function setFly(on)

	ctx:SetFlag("Fly", on)

	if on then
		startFly()
	else
		stopFly()
	end

end

		player.CharacterAdded:Connect(function()
			-- Flying doesn't survive a respawn (BodyVelocity/root are gone);
			-- re-enable next frame once the new character has settled.
			if ctx:GetFlag("Fly") then
				task.wait(0.5)
				pcall(setFly, true)
			end
		end)

		----------------------------------------------------------------
		-- Noclip
		----------------------------------------------------------------

		local noclipConn

		local function applyNoclip(char, on)
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					pcall(function() part.CanCollide = not on end)
				end
			end
		end

		local function setNoclip(on)
			ctx:SetFlag("Noclip", on)
			local char = getChar()
			if not char then return end

			if on then
				applyNoclip(char, true)
				if noclipConn then noclipConn:Disconnect() end
				-- Parts respawn/stream in while noclip is active (e.g. accessories,
				-- tools); keep re-applying so nothing suddenly collides again.
				noclipConn = char.DescendantAdded:Connect(function(inst)
					if inst:IsA("BasePart") then
						pcall(function() inst.CanCollide = false end)
					end
				end)
			else
				if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
				applyNoclip(char, false)
			end
		end

		player.CharacterAdded:Connect(function(char)
			if ctx:GetFlag("Noclip") then
				task.wait(0.2)
				applyNoclip(char, true)
			end
		end)

		----------------------------------------------------------------
		-- Reset character
		----------------------------------------------------------------

		local function resetChar()
			local hum = getHumanoid()
			if hum then
				pcall(function() hum.Health = 0 end)
			end
		end

		----------------------------------------------------------------
		-- Command palette
		----------------------------------------------------------------

		ctx:RegisterCommand("speed", function(window, argString)
			local n = setSpeed(argString)
			window:Notify({ Title = "Speed", Content = "Set to " .. n, Type = "success" })
		end)

		ctx:RegisterCommand("fly", function(window, argString)
			local on = argString:lower() ~= "off"
			setFly(on)
			window:Notify({ Title = "Fly", Content = on and "Enabled" or "Disabled", Type = "info" })
		end)

		ctx:RegisterCommand("flyspeed", function(window, argString)
			local n = math.clamp(tonumber(argString) or 50, 1, 300)
			ctx:SetFlag("FlySpeed", n)
			window:Notify({ Title = "Fly Speed", Content = "Set to " .. n, Type = "success" })
		end)

		ctx:RegisterCommand("noclip", function(window, argString)
			local on = argString:lower() ~= "off"
			setNoclip(on)
			window:Notify({ Title = "Noclip", Content = on and "Enabled" or "Disabled", Type = "info" })
		end)

		ctx:RegisterCommand("reset-char", function(window)
			resetChar()
			window:Notify({ Title = "Character", Content = "Reset", Type = "warning" })
		end)

		----------------------------------------------------------------
		-- UI tab (mirrors the commands above; both stay in sync via flags)
		----------------------------------------------------------------

		if ctx.Window then
			local tab = ctx:CreateTab("Movement",{Icon = nil})
			local section = tab:CreateSection("Character")

			section:CreateSlider({
				Name = "Walk Speed",
				Min = 1,
				Max = 200,
				Default = 16,
				Flag = "Speed",
				Callback = function(value) setSpeed(value) end,
			})

			section:CreateToggle({
				Name = "Fly",
				Default = false,
				Flag = "Fly",
				Callback = function(state) setFly(state) end,
			})

			section:CreateSlider({
				Name = "Fly Speed",
				Min = 10,
				Max = 300,
				Default = 50,
				Flag = "FlySpeed",
			})

			section:CreateToggle({
				Name = "Noclip",
				Default = false,
				Flag = "Noclip",
				Callback = function(state) setNoclip(state) end,
			})

			section:CreateButton({
				Name = "Reset Character",
				Callback = function()
					resetChar()
					ctx:Notify({ Title = "Character", Content = "Reset", Type = "warning" })
				end,
			})
		end
	end,
}
