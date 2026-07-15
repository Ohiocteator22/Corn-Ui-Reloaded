--[[
	PerformanceSuite — CornUi plugin
	Reduce UI animations, toggle blur, disable particles, low graphics mode,
	and streaming distance optimization.

	REQUIRES the ReducedMotion patch in CornUi.lua (tween() + intro block
	gated on Library.Flags.ReducedMotion) — see the patched CornUi.lua.
	Animations can't be disabled from a plugin alone because tween()/ripple()
	are local helpers inside CornUi.lua's closure, not exposed through ctx.

	Usage:
		local Corn = loadstring(game:HttpGet("<raw CornUi.lua url>"))()

		-- Optional: set this BEFORE CreateWindow if you also want the
		-- one-time intro animation skipped. Setting it later (e.g. from
		-- this plugin's UI toggle) still disables ripple/tab-switch/theme
		-- transition animations live, just not a retroactive intro.
		-- Corn:SetFlag("ReducedMotion", true)

		local Window = Corn:CreateWindow({ Name = "My Hub" })
		Corn:LoadPlugins({
			"https://raw.githubusercontent.com/you/plugins/main/PerformanceSuite.lua",
		}, Window)

	Notes:
	- Low Graphics flips Lighting.GlobalShadows off, disables post-processing
	  effects (Bloom/SunRays/DepthOfField/ColorCorrection/Atmosphere), and
	  drops the client's saved quality level to the lowest setting. All
	  original values are restored when toggled off.
	- Streaming Optimization only does anything if the place already has
	  StreamingEnabled — it can't be turned on at runtime, only tuned.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

return {
	Name = "Performance Suite",
	Version = "1.0.0",

	Init = function(ctx)
		----------------------------------------------------------------
		-- Reduce UI animations
		----------------------------------------------------------------

		local function setReducedMotion(on)
			ctx:SetFlag("ReducedMotion", on)
		end

		----------------------------------------------------------------
		-- Blur
		----------------------------------------------------------------

		local blurEffect = Lighting:FindFirstChild("MUI_PerfBlur")
		if not blurEffect then
			blurEffect = Instance.new("BlurEffect")
			blurEffect.Name = "MUI_PerfBlur"
			blurEffect.Size = 0
			blurEffect.Parent = Lighting
		end

		local function setBlur(on)
			blurEffect.Size = on and 24 or 0
		end

		----------------------------------------------------------------
		-- Particles (ParticleEmitters + Trails)
		----------------------------------------------------------------

		local particleConn

		local function setParticleEmitter(inst, enabled)
			if inst:IsA("ParticleEmitter") or inst:IsA("Trail") then
				inst.Enabled = enabled
			end
		end

		local function setParticles(on)
			-- "on" here means particles ENABLED (normal); disabling them is
			-- what the performance toggle actually does — kept as `on` for
			-- symmetry with the other setters, called with `not disabled`.
			for _, inst in ipairs(Workspace:GetDescendants()) do
				setParticleEmitter(inst, on)
			end

			if particleConn then particleConn:Disconnect(); particleConn = nil end
			if not on then
				-- Keep suppressing newly-streamed-in emitters while disabled.
				particleConn = Workspace.DescendantAdded:Connect(function(inst)
					setParticleEmitter(inst, false)
				end)
			end
		end

		----------------------------------------------------------------
		-- Low graphics mode
		----------------------------------------------------------------

		local savedLightingState
		local EFFECT_CLASSES = {
			"BloomEffect", "SunRaysEffect", "DepthOfFieldEffect",
			"ColorCorrectionEffect", "AtmosphereEffect",
		}

		local function setLowGraphics(on)
			if on then
				savedLightingState = {
					GlobalShadows = Lighting.GlobalShadows,
					effects = {},
				}
				for _, className in ipairs(EFFECT_CLASSES) do
					for _, inst in ipairs(Lighting:GetChildren()) do
						if inst.ClassName == className then
							savedLightingState.effects[inst] = inst.Enabled
							inst.Enabled = false
						end
					end
				end
				Lighting.GlobalShadows = false

				pcall(function()
					local userSettings = UserSettings():GetService("UserGameSettings")
					savedLightingState.quality = userSettings.SavedQualityLevel
					userSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
				end)
			else
				if savedLightingState then
					Lighting.GlobalShadows = savedLightingState.GlobalShadows
					for inst, wasEnabled in pairs(savedLightingState.effects) do
						if inst.Parent then inst.Enabled = wasEnabled end
					end
					if savedLightingState.quality then
						pcall(function()
							UserSettings():GetService("UserGameSettings").SavedQualityLevel = savedLightingState.quality
						end)
					end
				end
				savedLightingState = nil
			end
		end

		----------------------------------------------------------------
		-- Streaming optimization
		----------------------------------------------------------------

		local savedStreamingRadii

		local function setStreamingOptimization(on)
			if not Workspace.StreamingEnabled then return end -- can't enable at runtime

			if on then
				savedStreamingRadii = {
					min = Workspace.StreamingMinRadius,
					target = Workspace.StreamingTargetRadius,
				}
				Workspace.StreamingMinRadius = 64
				Workspace.StreamingTargetRadius = 128
			elseif savedStreamingRadii then
				Workspace.StreamingMinRadius = savedStreamingRadii.min
				Workspace.StreamingTargetRadius = savedStreamingRadii.target
				savedStreamingRadii = nil
			end
		end

		----------------------------------------------------------------
		-- UI
		----------------------------------------------------------------

		if not ctx.Window then return end

		local tab = ctx:CreateTab("Performance")
		local section = tab:CreateSection("Optimizations")

		section:CreateToggle({
			Name = "Reduce UI Animations",
			Default = false,
			Flag = "ReducedMotion",
			Callback = setReducedMotion,
		})

		section:CreateToggle({
			Name = "Blur",
			Default = false,
			Flag = "Blur",
			Callback = setBlur,
		})

		section:CreateToggle({
			Name = "Disable Particles",
			Default = false,
			Flag = "DisableParticles",
			Callback = function(state) setParticles(not state) end,
		})

		section:CreateToggle({
			Name = "Low Graphics Mode",
			Default = false,
			Flag = "LowGraphics",
			Callback = setLowGraphics,
		})

		section:CreateToggle({
			Name = "Streaming Optimization",
			Default = false,
			Flag = "StreamingOptimization",
			Callback = function(state)
				if state and not Workspace.StreamingEnabled then
					ctx:Notify({
						Title = "Streaming Optimization",
						Content = "This place doesn't have StreamingEnabled — nothing to tune",
						Type = "warning",
					})
					return
				end
				setStreamingOptimization(state)
			end,
		})
	end,
}
