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
			local hum = char:WaitForChild("Humanoid")
			local speed = ctx:GetFlag("Speed")
			if speed then hum.WalkSpeed = speed end
		end)

		----------------------------------------------------------------
		-- Fly
		----------------------------------------------------------------

		local flyConn, flyForce

		local function stopFly()
			if flyConn then flyConn:Disconnect(); flyConn = nil end
			if flyForce then flyForce:Destroy(); flyForce = nil end
			local hum = getHumanoid()
			if hum then hum.PlatformStand = false end
		end

		local function startFly()
			if flyConn then return end -- already flying
			local hum, root = getHumanoid(), getRoot()
			if not hum or not root then return end

			hum.PlatformStand = true
			flyForce = Instance.new("BodyVelocity")
			flyForce.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			flyForce.Velocity = Vector3.zero
			flyForce.Parent = root

			flyConn = RunService.RenderStepped:Connect(function()
				if not flyForce or not flyForce.Parent then return end
				local speed = ctx:GetFlag("FlySpeed") or 50
				local moveDir = hum.MoveDirection -- magnitude 0..1, already input-relative
				if moveDir.Magnitude > 0.05 then
					-- Re-project onto the camera's facing so "forward" always
					-- means "where you're looking", flattened Y from moveDir's own Y.
					local look = camera.CFrame.LookVector
					local flatLook = Vector3.new(look.X, 0, look.Z)
					if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit end
					local right = camera.CFrame.RightVector
					local forwardAmt = moveDir:Dot(Vector3.new(flatLook.X, 0, flatLook.Z))
					flyForce.Velocity = (flatLook * -moveDir.Z + right * moveDir.X) * speed
				else
					flyForce.Velocity = flyForce.Velocity:Lerp(Vector3.zero, 0.2)
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
				setFly(true)
			end
		end)

		----------------------------------------------------------------
		-- Noclip
		----------------------------------------------------------------

		local noclipConn

		local function applyNoclip(char, on)
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = not on
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
						inst.CanCollide = false
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
			if hum then hum.Health = 0 end
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
			local tab = ctx:CreateTab("Movement")
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
