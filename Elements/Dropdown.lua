--[[
    CornUi v2.0 — Elements/Dropdown.lua
    Registers Section:CreateDropdown(props).

    props = {
        Title = "Dropdown Name",
        Flag  = "MyDropdownFlag",
        Options = { "A", "B", "C" },
        Multi = false,              -- if true, Flag value is an array of selected options
        Default = "A",
        Callback = function(value) end,
    }

    Design/perf notes:
      - OptionList is a capped ScrollingFrame (max 190px tall): a 50-option
        dropdown scrolls instead of stretching the whole section, and the
        section's AutomaticSize only ever sees the capped height.
      - Highlights/diamond paint straight from theme tables (no per-select
        Theme.Apply rebinding); an OnChanged hook resyncs after theme swaps.
      - The panel pops in with a single 0.12s UIScale tween on High quality.
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Theme = Modules.Theme
    local Section = Modules.Window.Section

    local Dropdown = {}
    Dropdown.__index = Dropdown

    local MAX_LIST_HEIGHT = 190

    local function formatDisplay(value, multi)
        if multi then
            if type(value) ~= "table" or #value == 0 then return "None" end
            return table.concat(value, ", ")
        end
        return tostring(value or "None")
    end

    function Dropdown.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()
        assert(type(props.Options) == "table", "CreateDropdown: props.Options is required")

        local self = setmetatable({}, Dropdown)
        self.Flag = props.Flag
        self.Multi = props.Multi or false
        self.Options = props.Options
        self.Open = false

        local container = Render.New("Frame", {
            Name = "Dropdown_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 44),
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

        self.Header = Render.New("Frame", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 26),
            Position = UDim2.fromOffset(0, props.Title and 20 or 0),
            CornerRadius = 6,
            Theme = "Default",
            Parent = container,
        })

        self.DisplayLabel = Render.New("Text", {
            Text = "",
            TextSize = 13,
            Size = UDim2.new(1, -32, 1, 0),
            Position = UDim2.fromOffset(8, 0),
            Theme = "Muted",
            Parent = self.Header,
        })

        -- Diamond direction marker: rotated 45° closed, 135° open. Painted
        -- from Text/Muted directly (no theme kind paints a bare Frame from
        -- a Text role), resynced on theme change alongside the highlights.
        self.Marker = Render.New("Frame", {
            Name = "Marker",
            Size = UDim2.fromOffset(6, 6),
            Position = UDim2.new(1, -16, 0.5, -3),
            Rotation = 45,
            CornerRadius = 1,
            Theme = false,
            Parent = self.Header,
        })

        local headerButton = Instance.new("TextButton")
        headerButton.BackgroundTransparency = 1
        headerButton.Text = ""
        headerButton.Size = UDim2.fromScale(1, 1)
        headerButton.ZIndex = self.Header.ZIndex + 1
        headerButton.Parent = self.Header

        -- Capped, scrollable option panel. AutomaticSize grows the frame to
        -- its canvas until the UISizeConstraint ceiling, then it scrolls.
        self.OptionList = Render.New("Scroll", {
            Name = "OptionList",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(0, self.Header.Position.Y.Offset + 28),
            Theme = "Card",
            CornerRadius = Theme.Tokens.PanelCorner,
            ScrollBarThickness = 2,
            Visible = false,
            Parent = container,
        })

        local listConstraint = Instance.new("UISizeConstraint")
        listConstraint.MaxSize = Vector2.new(math.huge, MAX_LIST_HEIGHT)
        listConstraint.Parent = self.OptionList

        local popScale = Instance.new("UIScale")
        popScale.Scale = 1
        popScale.Parent = self.OptionList

        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = self.OptionList

        local listPadding = Instance.new("UIPadding")
        listPadding.PaddingTop = UDim.new(0, 4)
        listPadding.PaddingBottom = UDim.new(0, 4)
        listPadding.Parent = self.OptionList

        local optionFrames = {}

        local function isSelected(option, currentValue)
            if self.Multi then
                if type(currentValue) ~= "table" then return false end
                for _, v in ipairs(currentValue) do
                    if v == option then return true end
                end
                return false
            end
            return currentValue == option
        end

        -- Direct theme-table reads instead of per-option Theme.Apply.
        local function refreshOptionHighlights(currentValue)
            local accentStyle = Theme.GetStyle("Frame", "Enabled")
            local accentColor = accentStyle and accentStyle.Color
            if not accentColor then return end
            for option, frame in pairs(optionFrames) do
                frame.BackgroundColor3 = accentColor
                frame.BackgroundTransparency = isSelected(option, currentValue) and 0.15 or 1
            end
        end

        local function refreshMarker()
            local mutedStyle = Theme.GetStyle("Text", "Muted")
            if mutedStyle and mutedStyle.Color then
                self.Marker.BackgroundColor3 = mutedStyle.Color
            end
        end

        local function setOpen(open)
            self.Open = open
            self.OptionList.Visible = open

            if Render.Motion() then
                local TweenService = game:GetService("TweenService")
                if open then
                    popScale.Scale = 0.97
                    self.Marker.Rotation = 45
                    TweenService:Create(popScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
                    TweenService:Create(self.Marker, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 135 }):Play()
                else
                    self.Marker.Rotation = 45
                end
            else
                self.Marker.Rotation = open and 135 or 45
            end
        end

        local function select(option)
            local current = Flags.GetFlag(props.Flag)

            if self.Multi then
                current = (type(current) == "table") and current or {}
                local newValue = {}
                local removed = false
                for _, v in ipairs(current) do
                    if v == option then
                        removed = true
                    else
                        table.insert(newValue, v)
                    end
                end
                if not removed then
                    table.insert(newValue, option)
                end
                Flags.SetFlag(props.Flag, newValue)
            else
                Flags.SetFlag(props.Flag, option)
                setOpen(false)
            end
        end

        for i, option in ipairs(self.Options) do
            local optFrame = Render.New("Frame", {
                Name = "Option_" .. tostring(option),
                Size = UDim2.new(1, 0, 0, 24),
                LayoutOrder = i,
                BackgroundTransparency = 1,
                Theme = false,
                Parent = self.OptionList,
            })

            Render.New("Text", {
                Text = tostring(option),
                TextSize = 13,
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                Theme = "Default",
                Parent = optFrame,
            })

            local optButton = Instance.new("TextButton")
            optButton.BackgroundTransparency = 1
            optButton.Text = ""
            optButton.Size = UDim2.fromScale(1, 1)
            optButton.ZIndex = optFrame.ZIndex + 1
            optButton.Parent = optFrame
            optButton.MouseButton1Click:Connect(function()
                select(option)
            end)

            optionFrames[option] = optFrame
        end

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local value = b
            if a ~= self then
                value = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, value, true) -- silent: programmatic Set also persists
            end
            self.DisplayLabel.Text = formatDisplay(value, self.Multi)
            refreshOptionHighlights(value)
            if props.Callback then
                task.spawn(props.Callback, value)
            end
        end

        headerButton.MouseButton1Click:Connect(function()
            setOpen(not self.Open)
        end)

        -- Theme switches repaint the bound frames automatically; the direct
        -- painted bits (option highlights, marker) resync here.
        if section.Window then
            local resync = Theme.OnChanged:Connect(function()
                refreshOptionHighlights(Flags.GetFlag(props.Flag))
                refreshMarker()
            end)
            section.Window:OnCleanup(function()
                resync:Disconnect()
            end)
        end

        local defaultValue = props.Default
        if defaultValue == nil then
            defaultValue = self.Multi and {} or self.Options[1]
        end
        local initial = Flags.GetFlag(props.Flag, defaultValue)

        refreshMarker()
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        self.DisplayLabel.Text = formatDisplay(initial, self.Multi)
        refreshOptionHighlights(initial)

        return self
    end

    Section.CreateDropdown = function(section, props)
        return Dropdown.New(section, props)
    end

    return Dropdown
end
