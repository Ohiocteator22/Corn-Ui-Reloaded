--[[
    CornUi v2.0 — Elements/PluginManager.lua
    Registers Section:CreatePluginManager(props).
    Lists every plugin registered with Plugins.Register and offers per-row
    Enable/Disable — v1's plugin manager rebuilt on the v2 plugin lifecycle
    (with pcalled Init/Unload and clean ctx injection instead of v1's raw
    loadstring-and-pray).

    props = {
        Title = "Plugins",
        EmptyText = "No plugins registered",  -- shown when the registry is empty
    }
]]

return function(Modules)

    local Render = Modules.Render
    local Plugins = Modules.Plugins
    local Section = Modules.Window.Section

    assert(Plugins, "PluginManager requires Systems/Plugins.lua to be loaded first")

    local PluginManager = {}
    PluginManager.__index = PluginManager

    function PluginManager.New(section, props)
        props = props or {}

        local self = setmetatable({}, PluginManager)
        self.Rows = {}

        local container = Render.New("Frame", {
            Name = "PluginManager",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Theme = false,
            Parent = section.Frame,
        })
        container.BackgroundTransparency = 1

        if props.Title then
            Render.New("Text", {
                Text = props.Title,
                TextSize = 14,
                Size = UDim2.new(1, 0, 0, 18),
                Theme = "Default",
                Parent = container,
            })
        end

        local names = Plugins.ListPlugins()
        if #names == 0 then
            Render.New("Text", {
                Text = props.EmptyText or "No plugins registered",
                TextSize = 12,
                Size = UDim2.new(1, 0, 0, 18),
                Theme = "Muted",
                Parent = container,
            })
            return self
        end

        local function statusText(entry)
            return entry.Enabled and "On" or "Off"
        end

        for i, item in ipairs(names) do
            local name = item.Name
            local entry = Plugins.GetPlugin(name)
            if entry then
                local row = Render.New("Frame", {
                    Name = "PluginRow_" .. name,
                    Size = UDim2.new(1, 0, 0, 26),
                    LayoutOrder = i,
                    Theme = false,
                    Parent = container,
                })
                row.BackgroundTransparency = 1

                Render.New("Text", {
                    Text = name,
                    TextSize = 13,
                    Size = UDim2.new(1, -110, 1, 0),
                    Theme = "Default",
                    Parent = row,
                })

                local status = Render.New("Text", {
                    Text = statusText(entry),
                    TextSize = 12,
                    XAlignment = Enum.TextXAlignment.Right,
                    Size = UDim2.fromOffset(30, 18),
                    Position = UDim2.new(1, -76, 0.5, -9),
                    Theme = "Muted",
                    Parent = row,
                })

                local toggleBtn = Render.New("Button", {
                    Name = "TogglePlugin",
                    Text = "Enable",
                    TextSize = 12,
                    Size = UDim2.fromOffset(64, 20),
                    Position = UDim2.new(1, -64, 0.5, -10),
                    Theme = "Default",
                    Parent = row,
                })

                self.Rows[name] = { Frame = row, Status = status, Button = toggleBtn }

                toggleBtn.MouseButton1Click:Connect(function()
                    local current = Plugins.GetPlugin(name)
                    if not current then return end
                    if current.Enabled then
                        Plugins.DisablePlugin(name)
                    else
                        Plugins.EnablePlugin(name)
                    end
                    local after = Plugins.GetPlugin(name)
                    status.Text = statusText(after)
                    toggleBtn.Text = after.Enabled and "Disable" or "Enable"
                end)
            end
        end

        return self
    end

    Section.CreatePluginManager = function(section, props)
        return PluginManager.New(section, props)
    end

    return PluginManager
end
