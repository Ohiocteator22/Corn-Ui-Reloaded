--[[
    Cornelius assistant: command/guide/pack system + built-in packs — verbatim v1.9.4d (global Cornelius).

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 882-1412. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Systems/Commands.lua
return function(Modules)
    local Library = Modules

-- ============ CORNELIUS ASSISTANT SYSTEM (v1.9.4d lines 882-1412) ============
-- ============================================================
-- CORNELIUS ASSISTANT SYSTEM
-- ============================================================

Cornelius = {
    Packs = {},
    Commands = {},
    Guides = {},
    RegisteredPacks = {},
    _window = nil,
    _loadedCount = 0,
    _VERSION = "1.0.1",
}

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

-- ============================================================
-- BUILT-IN CORNELIUS PACKS
-- ============================================================

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
end
