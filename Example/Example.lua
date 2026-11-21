--[[
    CornUi v2.2 — Example.lua
    A runnable tour of the library. Drop this in your executor after loading
    CornUi, or read it as the canonical usage reference.

    The v1.9.3 API is unchanged: Library:CreateWindow, window:CreateTab,
    tab:CreateSection, and every Create___ element, with Name/Content props.
    Everything below that starts at the "v2 additions" banner is optional new
    stuff layered on top (Stepper, Cycle, Plugins, Host, Statusbar, palette).

    local CornUi = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/Loader.lua"
    ))()
    loadstring(game:HttpGet(".../Example.lua"))()  -- or paste the body
]]

-- Weak device? Uncomment:
-- Library.SetQuality("Low")

------------------------------------------------------------------
-- Window shell (v1 API: CreateWindow / CreateTab / CreateSection)
------------------------------------------------------------------

local Library = CornUi

local window = Library:CreateWindow({
    Name = "CornUi Showcase",
    Size = UDim2.fromOffset(540, 380),
})

local mainTab = window:CreateTab("Main")
local visualTab = window:CreateTab("Visuals")
local miscTab = window:CreateTab("Misc")

------------------------------------------------------------------
-- Main tab
------------------------------------------------------------------

local general = mainTab:CreateSection("General")

general:CreateToggle({
    Name = "God Mode",
    Flag = "GodMode",
    Default = false,
    Callback = function(value)
        print("[Example] GodMode =", value)
    end,
})

local speedSlider = general:CreateSlider({
    Name = "Walk Speed",
    Flag = "WalkSpeed",
    Min = 16,
    Max = 200,
    Increment = 2,
    Default = 16,
    Callback = function(value)
        print("[Example] WalkSpeed =", value)
    end,
})

-- Assets: any icon prop accepts an asset id, an https URL, a local file or a
-- built-in embedded pack name. Corn:LoadImage resolves all of them:
--   Corn:LoadImage("https://myhost.com/logo.png")  -- HttpGet -> writefile -> getcustomasset (cached)
--   Corn:LoadImage("MyHub/logo.png")               -- file you already wrote
--   Corn:LoadImage("logo")                         -- built-in pack icon (zero hosting)
general:CreateButton({
    Name = "Reset speed to 16",
    Icon = "bolt",
    Callback = function()
        Library:SetFlag("WalkSpeed", 16)
    end,
})

general:CreateDivider("selection")

local aimSection = mainTab:CreateSection("Aim")

aimSection:CreateDropdown({
    Name = "Target Part",
    Flag = "TargetPart",
    Options = { "Head", "Torso", "Random" },
    Default = "Head",
})

-- v1 multi-select name; the v2 form (CreateDropdown with Multi = true) works
-- exactly the same:
aimSection:CreateMultiDropdown({
    Name = "Ignored Players",
    Flag = "Whitelist",
    Options = { "Alice", "Bob", "Charlie", "Dana", "Eve", "Frank" },
    Default = {},
})

aimSection:CreateKeybind({
    Name = "Aimbot Bind",
    Flag = "AimbotKey",
    Default = Enum.KeyCode.E,
    Callback = function()
        print("[Example] aimbot key fired")
    end,
})

aimSection:CreateKeybindList({
    Title = "Active binds",
    Flags = { "AimbotKey" },
    Labels = { AimbotKey = "Aimbot" },
})

local combat = mainTab:CreateSection("Combat")

combat:CreateColorPicker({
    Name = "ESP Color",
    Flag = "ESPColor",
    Default = Color3.fromRGB(232, 163, 61),
})

combat:CreateColorGradient({
    Name = "Tracer Gradient",
    Flag = "TracerGradient",
    Default = {
        { Time = 0, Color = Color3.fromRGB(232, 163, 61) },
        { Time = 1, Color = Color3.fromRGB(120, 70, 20) },
    },
})

combat:CreateRadioGroup({
    Name = "Aim Mode",
    Flag = "AimMode",
    Options = { "Hold", "Toggle", "Always" },
    Default = "Hold",
})

combat:CreateTextbox({
    Name = "Log webhook",
    Flag = "Webhook",
    Placeholder = "https://discord.com/api/webhooks/...",
})

------------------------------------------------------------------
-- v2 additions: widgets that layer on top of the same API
------------------------------------------------------------------

combat:CreateStepper({
    Title = "Aim FOV",
    Flag = "AimFOV",
    Min = 0,
    Max = 360,
    Step = 10,
    Default = 80,
    Suffix = "°",
    Callback = function(value)
        print("[Example] AimFOV =", value)
    end,
})

combat:CreateCycle({
    Title = "Priority",
    Flag = "AimPriority",
    Options = { "Distance", "Health", "Crosshair" },
    Default = "Crosshair",
    Callback = function(value)
        print("[Example] AimPriority =", value)
    end,
})

-- Checklist: independent checkboxes, one flag per item.
combat:CreateChecklist({
    Name = "ESP Targets",
    Items = {
        { Name = "Players", Flag = "ESPPlayers", Default = true },
        { Name = "NPCs", Flag = "ESPNPCs", Default = false },
    },
})

-- Meter: a read-only value bar driven by its flag.
local hpMeter = combat:CreateMeter({
    Name = "HP",
    Flag = "DisplayHP",
    Min = 0,
    Max = 100,
    ShowValue = true,
})

------------------------------------------------------------------
-- Visuals tab
------------------------------------------------------------------

local appearance = visualTab:CreateSection("Appearance")

appearance:CreateThemeEditor({ Title = "Skin System" })

local info = visualTab:CreateSection("Info")

info:CreateCard({ Name = "About" })
    :Add(Library.Render.New("Text", {
        Text = "CornUi v2.2 — mobile-first, quality-aware, zero image assets.",
        TextSize = 13,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Theme = "Muted",
    }))

info:CreateParagraph({
    Text = "Everything you see is drawn with plain frames and gradients — no textures to download, so first paint is instant even on slow connections.",
    Muted = true,
})

info:CreateProgressBar({
    Name = "Load progress",
    Flag = "LoadProgress",
    Min = 0,
    Max = 100,
})

------------------------------------------------------------------
-- Misc tab
------------------------------------------------------------------

local configSection = miscTab:CreateSection("Config")

configSection:CreateButton({
    Name = "Save config",
    Accent = true,
    Callback = function()
        local ok, err = Library:SaveConfig("showcase")
        window:Notify({
            Title = ok and "Config saved" or "Save failed",
            Content = ok and "Written to CornUi/Configs/showcase.json" or tostring(err),
            Type = ok and "Success" or "Error",
        })
    end,
})

configSection:CreateButton({
    Name = "Load config",
    Callback = function()
        Library:LoadConfig("showcase")
    end,
})

local pluginsSection = miscTab:CreateSection("Plugins")

-- v2 addition: register a plugin, then let the manager drive it.
Library.Plugins.Register("Greeter", function(ctx)
    return {
        Init = function()
            ctx.Window:Notify({ Title = "Greeter", Text = "Plugin online!", Type = "Success" })
        end,
    }
end)

pluginsSection:CreatePluginManager({ Title = "Installed" })

------------------------------------------------------------------
-- Sub-UIs (multi-window)
------------------------------------------------------------------

local subSection = miscTab:CreateSection("Sub-UIs")

subSection:CreateParagraph({
    Text = "Windows stack independently: the – chip minimizes to the title bar, and the newest window sits on top. Each sub-UI registers its own commands and releases them when destroyed.",
    Muted = true,
})

-- 1) Callback-built sub-window: the button spawns a full second window.
subSection:CreateButton({
    Name = "Open Player List (sub-window)",
    SubWindow = {
        Title = "Player List",
        Size = UDim2.fromOffset(320, 240),
        Build = function(sub, subSection2)
            subSection2:CreateLabel({ Name = "Spawned at " .. os.date("%H:%M:%S"), Muted = true })
            subSection2:CreateButton({
                Name = "Close this sub-UI",
                Command = false, -- close button stays out of the palette
                Callback = function()
                    sub:Destroy()
                end,
            })
        end,
    },
})

-- 2) Loadstring sub-UI: the button fetches + runs a separate UI script.
--    (Point this at any CornUi-based script — it calls CreateWindow itself.)
subSection:CreateButton({
    Name = "Run remote sub-UI",
    Loadstring = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/SubUI.lua",
})

-- 3) Inline code variant: same pipeline, no HTTP round-trip.
subSection:CreateButton({
    Name = "Run inline snippet",
    Loadstring = 'print("[Example] inline loadstring ran")',
})

------------------------------------------------------------------
-- Servers & device (v2 additions: Host integration)
------------------------------------------------------------------

local hostSection = miscTab:CreateSection("Servers & device")

-- Device: a draggable FPS / memory / device-tier pill, plus one-time
-- auto-detection that drops animation quality to Low on small touch devices.
window:CreateStatusbar()
window:EnableAutoQuality()

-- Servers: mirror every notification to a Discord-compatible webhook:
-- window:EnableWebhook("https://discord.com/api/webhooks/your-hook")

hostSection:CreateButton({
    Name = "Copy config as share string",
    Callback = function()
        local ok = Library.Config.CopyToString()
        if ok and window.NotifHolder then
            window:Notify({ Title = "Copied", Text = "Config share string is on your clipboard.", Type = "Success" })
        end
    end,
})

hostSection:CreateButton({
    Name = "Paste config from share string",
    Callback = function()
        local ok, err = Library.Config.PasteFromString()
        if not ok and window.NotifHolder then
            window:Notify({ Title = "Couldn't paste", Text = tostring(err), Type = "Error" })
        end
    end,
})

hostSection:CreateButton({
    Name = "Load remote config",
    Callback = function()
        -- Gist, repo raw file, or your own host — any JSON config blob.
        Library.Config.LoadFromUrl("https://raw.githubusercontent.com/you/YourHub/main/config.json")
    end,
})

hostSection:CreateButton({
    Name = "Show an actionable toast",
    Callback = function()
        window:Notify({
            Title = "CornUi v2.2",
            Text = "Toasts can carry buttons now.",
            Buttons = {
                { Text = "Nice", Callback = function() print("[Example] acknowledged") end },
                { Text = "Dismiss" },
            },
        })
    end,
})

-- Re-run the hub after teleports (server hops). Executor must support
-- queue_on_teleport:
-- window:PersistAcrossTeleports()

local links = miscTab:CreateSection("Links")

links:CreateDiscordButton({
    Invite = "https://discord.gg/your-invite",
    Title = "Join the Discord",
})

------------------------------------------------------------------
-- Services
------------------------------------------------------------------

window:CreateNotificationCenter()
window:Notify({
    Title = "CornUi v2.2",
    Content = "Showcase loaded. Press Ctrl+K (or the • • • chip) for the command palette.",
    Type = "Success",
    Duration = 6,
})

window:CreateCommandPalette()
window:CreateFloatingButton()
window:EnableAutoSave("showcase", 5)

-- Custom command for the palette (v2 addition):
Library.Commands.Register({
    Id = "Example.MaxSpeed",
    Title = "Max out walk speed",
    Keywords = "speed walk max",
    Run = function()
        Library:SetFlag("WalkSpeed", speedSlider.Max)
    end,
})

-- v1 window methods still work: skin, blur, spotlight, shadow.
-- window:SetTheme("Cyber")
-- window:SetBackground("rbxassetid://123456")
-- window:SetBlur(6)
-- window:SetShadow(true)

-- Simulated progress bar tick (uses the debounced autosave-safe flag path)
task.spawn(function()
    for i = 1, 4 do
        task.wait(0.5)
        Library:SetFlag("LoadProgress", i * 25)
    end
end)
