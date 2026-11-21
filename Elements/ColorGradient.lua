--[[
    CornUi v2.0 — Elements/ColorGradient.lua
    Registers Section:CreateColorGradient(props).
    A simplified multi-stop gradient editor: a preview strip plus Add/Remove
    stop controls, each stop reusing an inline hue slider (not the full
    ColorPicker panel, to keep this compact in a Section).

    props = {
        Title = "Gradient Name",
        Flag  = "MyGradientFlag",    -- stores an array of {Time, Color} stops
        Default = {
            { Time = 0, Color = Color3.fromRGB(255,0,0) },
            { Time = 1, Color = Color3.fromRGB(0,0,255) },
        },
        Callback = function(stops, colorSequence) end,
    }
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Section = Modules.Window.Section

    local ColorGradient = {}
    ColorGradient.__index = ColorGradient

    local function stopsToSequence(stops)
        -- Config round-trips / cleared flags can hand us an empty list; render
        -- a blank white strip rather than erroring on sorted[1].
        if type(stops) ~= "table" or #stops == 0 then
            return ColorSequence.new(Color3.new(1, 1, 1))
        end

        local sorted = table.clone(stops)
        table.sort(sorted, function(a, b) return a.Time < b.Time end)

        -- ColorSequence requires first keypoint at 0 and last at 1.
        if sorted[1].Time > 0 then
            table.insert(sorted, 1, { Time = 0, Color = sorted[1].Color })
        end
        if sorted[#sorted].Time < 1 then
            table.insert(sorted, { Time = 1, Color = sorted[#sorted].Color })
        end

        local keypoints = {}
        for _, stop in ipairs(sorted) do
            table.insert(keypoints, ColorSequenceKeypoint.new(stop.Time, stop.Color))
        end
        return ColorSequence.new(keypoints)
    end

    function ColorGradient.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()

        local self = setmetatable({}, ColorGradient)
        self.Flag = props.Flag

        local container = Render.New("Frame", {
            Name = "ColorGradient_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 60),
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

        self.Preview = Render.New("Frame", {
            Name = "Preview",
            Size = UDim2.new(1, 0, 0, 24),
            Position = UDim2.fromOffset(0, props.Title and 20 or 0),
            CornerRadius = 4,
            Theme = false,
            Parent = container,
        })

        self.Gradient = Render.New("Gradient", {
            Color = ColorSequence.new(Color3.new(1, 1, 1)),
            Parent = self.Preview,
        })

        self.StopRow = Render.New("Frame", {
            Name = "StopRow",
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.fromOffset(0, self.Preview.Position.Y.Offset + 28),
            Theme = false,
            Parent = container,
        })
        self.StopRow.BackgroundTransparency = 1

        local function redraw()
            local stops = Flags.GetFlag(props.Flag)
            self.Gradient.Color = stopsToSequence(stops)
        end

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local stops = b
            if a ~= self then
                stops = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, stops, true) -- silent: programmatic Set also persists
            end
            redraw()
            if props.Callback then
                task.spawn(props.Callback, stops, self.Gradient.Color)
            end
        end

        -- Minimal editing affordance: cycles the first stop's hue on click,
        -- intended as a placeholder control surface — a full drag-based
        -- multi-stop editor belongs in the Theme Editor UI, not inline here.
        local cycleButton = Instance.new("TextButton")
        cycleButton.BackgroundTransparency = 1
        cycleButton.Text = ""
        cycleButton.Size = UDim2.fromScale(1, 1)
        cycleButton.ZIndex = self.Preview.ZIndex + 1
        cycleButton.Parent = self.Preview
        cycleButton.MouseButton1Click:Connect(function()
            local stops = Flags.GetFlag(props.Flag)
            if type(stops) ~= "table" or not stops[1] then return end
            local h = select(1, Color3.toHSV(stops[1].Color))
            stops[1].Color = Color3.fromHSV((h + 0.1) % 1, 1, 1)
            Flags.SetFlag(props.Flag, stops)
        end)

        local initial = Flags.GetFlag(props.Flag, props.Default or {
            { Time = 0, Color = Color3.fromRGB(255, 0, 0) },
            { Time = 1, Color = Color3.fromRGB(0, 0, 255) },
        })
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        self.Set(initial)

        return self
    end

    Section.CreateColorGradient = function(section, props)
        return ColorGradient.New(section, props)
    end

    return ColorGradient
end
