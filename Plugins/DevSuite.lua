--[[
	DevSuite — CornUi plugin
	Live FPS / Ping / Memory meters, plus Rejoin Server, Copy JobId, and
	Copy UserId utilities. UI tab is the primary surface; a few of these
	are also exposed as command-palette commands for parity with the
	other plugins.

	Usage:
		local Corn = loadstring(game:HttpGet("<raw CornUi.lua url>"))()
		local Window = Corn:CreateWindow({ Name = "My Hub" })
		Corn:LoadPlugins({
			"https://raw.githubusercontent.com/you/plugins/main/DevSuite.lua",
		}, Window)

	Notes:
	- Clipboard writes go through setclipboard(), which is executor-provided
	  and not guaranteed to exist. If it's missing, the value is shown in a
	  Notify instead so you can still read/screenshot it.
	- "Rejoin" uses TeleportToPlaceInstance with the current JobId, which
	  puts you back in the *same* server (not a fresh matchmade one).
]]

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

return {
	Name = "Dev Suite",
	Version = "1.0.0",

	Init = function(ctx)
		local player = ctx.Player

		----------------------------------------------------------------
		-- Readouts
		----------------------------------------------------------------

		local function getPing()
			local ok, item = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			if ok and type(item) == "number" then return math.floor(item + 0.5) end
			return nil
		end

		local function getMemoryMb()
			local ok, mb = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
			if ok and type(mb) == "number" then return mb end
			return nil
		end

		----------------------------------------------------------------
		-- Actions
		----------------------------------------------------------------

		local function copyToClipboard(window, label, value)
			if type(setclipboard) == "function" then
				local ok = pcall(setclipboard, tostring(value))
				window:Notify({
					Title = label,
					Content = ok and ("Copied: " .. tostring(value)) or tostring(value),
					Type = ok and "success" or "info",
				})
			else
				-- No clipboard API on this executor — surface the value directly
				-- so it can still be read/screenshotted.
				window:Notify({ Title = label, Content = tostring(value), Type = "info" })
			end
		end

		local function rejoinServer(window)
			if window then
				window:Notify({ Title = "Rejoin", Content = "Reconnecting...", Type = "info" })
			end
			local ok, err = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
			end)
			if not ok then
				warn("[MobileUILib] Rejoin failed: " .. tostring(err))
				if window then
					window:Notify({ Title = "Rejoin", Content = "Failed — see console", Type = "error" })
				end
			end
		end

		----------------------------------------------------------------
		-- Command palette
		----------------------------------------------------------------

		ctx:RegisterCommand("rejoin", function(window)
			rejoinServer(window)
		end)

		ctx:RegisterCommand("copy-jobid", function(window)
			copyToClipboard(window, "Job ID", game.JobId)
		end)

		ctx:RegisterCommand("copy-userid", function(window)
			copyToClipboard(window, "User ID", player.UserId)
		end)

		----------------------------------------------------------------
		-- UI
		----------------------------------------------------------------

		if not ctx.Window then return end

		local tab = ctx:CreateTab("Developer")
		local statsSection = tab:CreateSection("Live Stats")

		local fpsLabel = statsSection:CreateLabel("FPS: --")
		local pingLabel = statsSection:CreateLabel("Ping: -- ms")
		local memLabel = statsSection:CreateLabel("Memory: -- MB")

		-- FPS: sampled every frame, displayed as a 0.5s rolling average so the
		-- number doesn't flicker.
		local frames, elapsed = 0, 0
		local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			frames += 1
			elapsed += dt
			if elapsed >= 0.5 then
				local fps = math.floor(frames / elapsed + 0.5)
				fpsLabel.Text = "FPS: " .. fps
				frames, elapsed = 0, 0
			end
		end)

		-- Ping/memory don't need per-frame updates — a slow poll is plenty and
		-- cheaper than querying Stats every Heartbeat.
		task.spawn(function()
			while fpsLabel and fpsLabel.Parent do
				local ping = getPing()
				pingLabel.Text = "Ping: " .. (ping and (ping .. " ms") or "n/a")

				local mem = getMemoryMb()
				memLabel.Text = "Memory: " .. (mem and (string.format("%.1f", mem) .. " MB") or "n/a")

				task.wait(1)
			end
		end)

		-- Stop polling if the tab's page gets destroyed (e.g. hub torn down).
		fpsLabel.AncestryChanged:Connect(function(_, parent)
			if not parent and heartbeatConn then
				heartbeatConn:Disconnect()
			end
		end)

		local actionsSection = tab:CreateSection("Actions")

		actionsSection:CreateButton({
			Name = "Rejoin Server",
			Callback = function() rejoinServer(ctx.Window) end,
		})

		actionsSection:CreateButton({
			Name = "Copy Job ID",
			Callback = function() copyToClipboard(ctx.Window, "Job ID", game.JobId) end,
		})

		actionsSection:CreateButton({
			Name = "Copy User ID",
			Callback = function() copyToClipboard(ctx.Window, "User ID", player.UserId) end,
		})
	end,
}
