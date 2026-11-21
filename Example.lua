--[[
    CornUi v1.9.4d (modular) — Example.lua
    A runnable tour of the library. Paste this WHOLE file into your executor:
    it loads CornUi itself (locked production URL below), then builds the
    tour UI — no pre-run loader step needed. Read it top to bottom as the
    canonical usage reference.

    The API below is the v1.9.4d surface exactly as shipped: Library:
    CreateWindow, window:CreateTab, tab:CreateSection, and every Create___
    element with Name/Flag/Default/Callback props. The two blocks marked
    "addition" (CommandPalette, Statusbar) are extras layered OVER the old
    window — everything else is stock v1.9.4d behavior.
]]

------------------------------------------------------------------
-- Library acquisition — the exact lines you paste into an executor
------------------------------------------------------------------

local CornUi = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/Loader.lua"
))()

local Library = CornUi

-- Weak device? Uncomment:
-- Library.SetQuality("Low")

------------------------------------------------------------------
-- Window shell (CreateWindow / CreateTab / CreateSection)
------------------------------------------------------------------

local window = Library:CreateWindow({
    Name = "CornUi Showcase",
    Theme = "Dark",
})

local mainTab = window:CreateTab("Main")
local visualTab = window:CreateTab("Visuals")

------------------------------------------------------------------
-- Main tab
------------------------------------------------------------------

local general = mainTab:CreateSection("General")

general:CreateToggle({
    Name = "God Mode",
    Flag = "GodMode",
    Default = false,
    Callback = function(value)
        print("god mode:", value)
    end,
})

general:CreateSlider({
    Name = "Walk Speed",
    Flag = "WalkSpeed",
    Min = 16,
    Max = 200,
    Default = 16,
    Callback = function(value)
        print("walk speed:", value)
    end,
})

general:CreateButton({
    Name = "Reset speed to 16",
    Callback = function()
        Library:SetFlag("WalkSpeed", 16)
    end,
})

local aim = mainTab:CreateSection("Aim")

aim:CreateDropdown({
    Name = "Target Part",
    Flag = "TargetPart",
    Options = { "Head", "Torso", "HumanoidRootPart" },
    Default = "Head",
})

aim:CreateKeybind({
    Name = "Aimbot Bind",
    Flag = "AimbotBind",
    Default = Enum.KeyCode.E,
})

aim:CreateTextbox({
    Name = "Log webhook",
    Flag = "Webhook",
    Placeholder = "https://discord.com/api/webhooks/...",
})

------------------------------------------------------------------
-- Visuals tab
------------------------------------------------------------------

local esp = visualTab:CreateSection("ESP")

esp:CreateToggle({
    Name = "Enabled",
    Flag = "ESPEnabled",
    Default = false,
})

esp:CreateColorPicker({
    Name = "ESP Color",
    Flag = "ESPColor",
    Default = Color3.fromRGB(255, 196, 48),
})

visualTab:CreateSection("Info")

visualTab:CreateLabel("All settings with a Flag save into configs.")

visualTab:CreateParagraph({
    Title = "Configs",
    Text = "Type 'save myconfig' in the hub title to store every flag, 'load myconfig' to restore them.",
})

visualTab:CreateDivider({ Name = "divider" })

visualTab:CreateProgressBar({
    Name = "Farm progress",
    Flag = "FarmProgress",
    Min = 0,
    Max = 100,
    Default = 40,
})

------------------------------------------------------------------
-- Window features (stock v1.9.4d)
------------------------------------------------------------------

window:Notify({
    Title = "CornUi ready",
    Content = "Every element above is stock v1.9.4d.",
    Type = "success",
})

-- Themes: pick a preset or register your own (custom colors, same shape).
-- window:SetTheme("Cyber")
-- Library:RegisterTheme("MyTheme", { Background = Color3.fromRGB(10,10,12), Accent = Color3.fromRGB(255,0,120) })

-- Skins: custom fonts + textures layered over any theme.
-- Library:RegisterSkin("Carbon", {
--     Theme = "Dark",
--     Fonts = { Header = Font.new("rbxasset://fonts/families/ScientificAtomic.json"),
--               Body   = Font.new("rbxasset://fonts/families/Roboto.json"),
--               Accent = Font.new("rbxasset://fonts/families/RobotoMono.json") },
-- })
-- window:SetSkin("Carbon")

-- Configs: save / restore every flag.
-- Library:SaveConfig("mysave")
-- Library:LoadConfig("mysave", window)

------------------------------------------------------------------
-- Additions (layered OVER the v1.9.4d window — never instead of it)
------------------------------------------------------------------

-- Command palette: fuzzy search over window commands, /cornelius commands
-- and flag toggles. Up/Down/Enter/Esc keyboard navigation, recents kept.
window:OpenCommandPalette({ Height = 300 })
window:ToggleCommandPalette() -- open then close again; bind it to a hotkey if you like

-- Statusbar: draggable FPS / memory / device-tier pill.
window:CreateStatusbar({})

-- Cornelius: built-in assistant commands, type in the hub title:
--   /cornelius help        /cornelius debug
--   /cornelius docs        /cornelius fact
