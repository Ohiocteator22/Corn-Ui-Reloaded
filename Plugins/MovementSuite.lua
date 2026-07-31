--[[
	MovementSuite — CornUi plugin
	Speed / Fly / Noclip / Reset Character, wired to both the command
	palette ("speed 50", "fly on", "noclip", "reset-char") and a UI tab.

	Usage:
		local Corn = loadstring(game:HttpGet("<raw CornUi.lua url>"))()
		local Window = Corn:CreateWindow({ Name = "My Hub" })
		Corn:LoadPlugins({
			"https://raw.githubusercontent.com/you/plugins/main/MovementSuite.lua",
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

		local flyConn, flyForce

		local function stopFly()
			if flyConn then flyConn:Disconnect(); flyConn = nil end
			if flyForce then
				pcall(function() flyForce:Destroy() end)
				flyForce = nil
			end
			local hum = getHumanoid()
			if hum then
				pcall(function() hum.PlatformStand = false end)
			end
		end

		local function startFly()
			if flyConn then return end -- already flying
			local hum, root = getHumanoid(), getRoot()
			if not hum or not root then return end

			local ok = pcall(function()
				hum.PlatformStand = true
				flyForce = Instance.new("BodyVelocity")
				flyForce.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				flyForce.Velocity = Vector3.zero
				flyForce.Parent = root
			end)
			if not ok then
				-- Root/Humanoid got yanked out from under us (respawn race) —
				-- bail out cleanly instead of leaving a half-built fly state.
				stopFly()
				return
			end

			flyConn = RunService.RenderStepped:Connect(function()
				-- Wrapped: camera can change (CurrentCamera swap), and the
				-- character can disappear mid-frame on respawn/teleport.
				local stepOk, stepErr = pcall(function()
					if not flyForce or not flyForce.Parent then return end
					local cam = workspace.CurrentCamera
					if not cam then return end
					local speed = ctx:GetFlag("FlySpeed") or 50
					local moveDir = hum.MoveDirection -- magnitude 0..1, already input-relative
					if moveDir.Magnitude > 0.05 then
						-- Re-project onto the camera's facing so "forward" always
						-- means "where you're looking", flattened Y from moveDir's own Y.
						local look = cam.CFrame.LookVector
						local flatLook = Vector3.new(look.X, 0, look.Z)
						if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit end
						local right = cam.CFrame.RightVector
						flyForce.Velocity = (flatLook * -moveDir.Z + right * moveDir.X) * speed
					else
						flyForce.Velocity = flyForce.Velocity:Lerp(Vector3.zero, 0.2)
					end
				end)
				if not stepOk then
					warn("[MovementSuite] Fly step error, stopping fly: " .. tostring(stepErr))
					stopFly()
				end
			end)
		end

		local function setFly(on)
			ctx:SetFlag("Fly", on)
			if on then startFly() else stopFly() end
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
			local tab = ctx:CreateTab("Movement", {
    											  Icon = nil,
													})
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
