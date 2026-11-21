--[[
    CornUi v2.0 - Loader.lua
    This is the ONE file users loadstring. It burst-fetches every module
    over HTTP in parallel, then executes them in dependency order (fetch
    being parallel is just an I/O win (Lua execution is still serial,
    so order here is what actually matters for correctness).

    Usage (v1.9.3 API, unchanged):
        local Library = loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/Loader.lua"
        ))()

        local window = Library:CreateWindow({ Name = "My Hub", Theme = "Dark" })
        local tab = window:CreateTab("Main")
        local section = tab:CreateSection("General")

        section:CreateToggle({ Name = "Enable Thing", Flag = "MyFlag", Default = false,
            Callback = function(value) end })
        section:CreateButton({ Name = "Do Thing", Callback = function() end })
        section:CreateSlider({ Name = "Amount", Flag = "Amount", Min = 0, Max = 100,
            Increment = 5, Default = 50 })
        window:Notify({ Title = "Loaded", Content = "CornUi ready." })

    v2 additions ride on top of that surface: Stepper, Cycle, CommandPalette,
    Statusbar, Plugins, Host, Theme.Set("Cyber"), window:EnableWebhook(url),
    window:EnableAutoSave(name, seconds), CornUi.SetQuality("Low"), and more.
]]

local BASE = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/"

-- Order matters: each entry's chunk runs `return function(Modules) ... end`
-- and many of them read Modules.<Dependency> at the TOP of that function,
-- immediately on execution (not lazily), so dependencies must already be
-- populated in Modules by the time a later entry executes.
--
--   Render, Theme, Window  -> no inter-dependencies, but everything after needs them
--   Flags                  -> independent
--   Host                   -> independent (executor HTTP / clipboard / teleport queue)
--   Commands               -> independent
--   Config                 -> reads Modules.Flags + Modules.Host at exec time
--   Plugins                -> independent (reads Modules.* lazily, inside functions)
--   Elements/*             -> read Modules.Render / Modules.Theme / Modules.Flags /
--                             Modules.Window.Section / Modules.Window.Window at exec time
local Manifest = {
    { Name = "Render",             Path = "Core/Render.lua" },
    { Name = "Theme",              Path = "Core/Theme.lua" },
    { Name = "Flags",              Path = "Systems/Flags.lua" },
    { Name = "AssetsEmbed",        Path = "Systems/AssetsEmbed.lua" },
    { Name = "Assets",             Path = "Systems/Assets.lua" },
    { Name = "Host",               Path = "Systems/Host.lua" },
    { Name = "Commands",           Path = "Systems/Commands.lua" },
    { Name = "Window",             Path = "Core/Window.lua" },
    { Name = "Config",             Path = "Systems/Config.lua" },
    { Name = "Plugins",            Path = "Systems/Plugins.lua" },
    { Name = "Toggle",             Path = "Elements/Toggle.lua" },
    { Name = "Slider",             Path = "Elements/Slider.lua" },
    { Name = "Dropdown",           Path = "Elements/Dropdown.lua" },
    { Name = "ColorPicker",        Path = "Elements/ColorPicker.lua" },
    { Name = "Keybind",            Path = "Elements/Keybind.lua" },
    { Name = "Search",             Path = "Elements/Search.lua" },
    { Name = "DiscordButton",      Path = "Elements/DiscordButton.lua" },
    { Name = "TextInput",          Path = "Elements/TextInput.lua" },
    { Name = "Basics",             Path = "Elements/Basics.lua" },
    { Name = "KeybindList",        Path = "Elements/KeybindList.lua" },
    { Name = "ColorGradient",      Path = "Elements/ColorGradient.lua" },
    { Name = "NotificationCenter", Path = "Elements/NotificationCenter.lua" },
    { Name = "Statusbar",          Path = "Elements/Statusbar.lua" },
    { Name = "ThemeEditor",        Path = "Elements/ThemeEditor.lua" },
    { Name = "PluginManager",      Path = "Elements/PluginManager.lua" },
    { Name = "CommandPalette",     Path = "Elements/CommandPalette.lua" },
    -- Compat LAST: attaches the full v1.9.3 API (Library:CreateWindow,
    -- window:CreateTab, tab:CreateSection, every Create___ element method on
    -- tab/section/card, Flags/Config/Theme shims) on top of the modules.
    { Name = "Compat",             Path = "Systems/Compat.lua" },
}

------------------------------------------------------------
-- Phase 1: burst-fetch every module's source in parallel.
------------------------------------------------------------

local Sources = {}
local FetchErrors = {}
local pending = #Manifest

for _, entry in ipairs(Manifest) do
    task.spawn(function()
        -- One retry per module: raw.githubusercontent occasionally 5xx/404s
        -- transiently, and a single failed request used to kill the whole load.
        local ok, result = pcall(game.HttpGet, game, BASE .. entry.Path)
        if not ok then
            task.wait(0.5)
            ok, result = pcall(game.HttpGet, game, BASE .. entry.Path)
        end
        if ok then
            Sources[entry.Name] = result
        else
            FetchErrors[entry.Name] = result
        end
        pending -= 1
    end)
end

while pending > 0 do
    task.wait()
end

if next(FetchErrors) then
    local lines = { "CornUi v2.0 failed to fetch required modules:" }
    for name, err in pairs(FetchErrors) do
        table.insert(lines, ("  - %s: %s"):format(name, tostring(err)))
    end
    error(table.concat(lines, "\n"))
end

------------------------------------------------------------
-- Phase 2: execute in dependency order, building the shared Modules table.
------------------------------------------------------------

local Modules = {}

for _, entry in ipairs(Manifest) do
    local chunk, compileErr = loadstring(Sources[entry.Name], "CornUi/" .. entry.Name)
    if not chunk then
        error(("CornUi v2.0 failed to compile module '%s': %s"):format(entry.Name, tostring(compileErr)))
    end

    -- Every module file is `return function(Modules) ... end`: the chunk
    -- returns the factory, and the factory must then RUN with the shared
    -- Modules table to produce the module itself. Skipping the second call
    -- stores bare functions and the whole library never boots.
    local ok, factory = pcall(chunk)
    if not ok then
        error(("CornUi v2.0 failed to load module '%s': %s"):format(entry.Name, tostring(factory)))
    end

    local ok2, result = pcall(factory, Modules)
    if not ok2 then
        error(("CornUi v2.0 failed to load module '%s': %s"):format(entry.Name, tostring(result)))
    end

    Modules[entry.Name] = result
end

Modules.Version = "2.2.0"

-- Top-level convenience: quality switch for weak devices.
--   CornUi.SetQuality("Low")   -- no tweens, no intro, no strokes
--   CornUi.SetQuality("High")  -- full polish (default)
Modules.SetQuality = function(level)
    Modules.Render.SetQuality(level)
end

return Modules
