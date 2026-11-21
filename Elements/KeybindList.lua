--[[
    CornUi v2.0 — Elements/KeybindList.lua
    Registers Section:CreateKeybindList(props).
    Displays a live, auto-updating list of currently bound keys, reading
    from any Flags whose name is registered via props.Flags (a list of
    flag names that hold Enum.KeyCode values set by Keybind elements).

    props = {
        Title = "Active Binds",
        Flags = { "AimbotKey", "ESPKey" },
        Labels = { AimbotKey = "Aimbot", ESPKey = "ESP" }, -- optional friendly names
    }
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Section = Modules.Window.Section

    local KeybindList = {}
    KeybindList.__index = KeybindList

    function KeybindList.New(section, props)
        assert(type(props.Flags) == "table", "CreateKeybindList: props.Flags is required")

        local self = setmetatable({}, KeybindList)
        self.Rows = {}

        self.Frame = Render.New("Frame", {
            Name = "KeybindList",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            CornerRadius = 6,
            Theme = "Card",
            Parent = section.Frame,
        })

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 2)
        layout.Parent = self.Frame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 6)
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = self.Frame

        if props.Title then
            Render.New("Text", {
                Text = props.Title,
                TextSize = 14,
                Theme = "Default",
                Size = UDim2.new(1, 0, 0, 18),
                LayoutOrder = 0,
                Parent = self.Frame,
            })
        end

        local labels = props.Labels or {}

        for i, flagName in ipairs(props.Flags) do
            local row = Render.New("Frame", {
                Name = "Row_" .. flagName,
                Size = UDim2.new(1, 0, 0, 18),
                LayoutOrder = i,
                Theme = false,
                Parent = self.Frame,
            })
            row.BackgroundTransparency = 1

            Render.New("Text", {
                Text = labels[flagName] or flagName,
                TextSize = 12,
                Size = UDim2.new(0.6, 0, 1, 0),
                Theme = "Muted",
                Parent = row,
            })

            local valueLabel = Render.New("Text", {
                Text = "",
                TextSize = 12,
                XAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                Theme = "Default",
                Parent = row,
            })

            self.Rows[flagName] = valueLabel

            local function refresh(value)
                valueLabel.Text = (value and value.Name) or "None"
            end

            refresh(Flags.GetFlag(flagName))
            Flags.OnFlagChanged(flagName, function(newValue)
                refresh(newValue)
            end)
        end

        return self
    end

    Section.CreateKeybindList = function(section, props)
        return KeybindList.New(section, props)
    end

    return KeybindList
end
