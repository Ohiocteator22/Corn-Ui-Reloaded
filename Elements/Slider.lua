--[[
    CornUi v2.0 — Elements/Slider.lua
    Registers Section:CreateSlider(props).

    props = {
        Title = "Slider Name",
        Flag  = "MySliderFlag",
        Min = 0, Max = 100, Increment = 1,
        Default = 50,
        Callback = function(value) end,
    }

    Tap the value label to type an exact value (v1 parity, rebuilt): an
    inline editor replaces the label, commits on Enter/focus-loss, rejects
    garbage, and clamps/rounds to the slider's increment.
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Theme = Modules.Theme
    local Section = Modules.Window.Section

    local UserInputService = game:GetService("UserInputService")

    local Slider = {}
    Slider.__index = Slider

    local function round(value, increment)
        increment = increment or 1
        return math.floor((value / increment) + 0.5) * increment
    end

    local function clamp(value, min, max)
        return math.clamp(value, min, max)
    end

    function Slider.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()
        local min = props.Min or 0
        local max = props.Max or 100
        local increment = props.Increment or 1

        local self = setmetatable({}, Slider)
        self.Flag = props.Flag
        self.Min, self.Max, self.Increment = min, max, increment

        local row = Render.New("Frame", {
            Name = "Slider_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 44),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        self.Label = Render.New("Text", {
            Text = props.Title or props.Flag,
            TextSize = 14,
            Size = UDim2.new(1, -50, 0, 18),
            Theme = "Default",
            Parent = row,
        })

        self.ValueLabel = Render.New("Text", {
            Text = "",
            TextSize = 14,
            XAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.fromOffset(50, 18),
            Position = UDim2.new(1, -50, 0, 0),
            Theme = "Muted",
            Parent = row,
        })

        -- Inline exact-value editor: built lazily on first tap so sliders
        -- that are never typed into cost nothing. Takes the value label's
        -- place while active.
        local valueEditor

        local function commitEditor()
            if not valueEditor then return end
            local text = valueEditor.Text:gsub("%s", "")
            local number = tonumber(text)
            if number then
                Flags.SetFlag(props.Flag, clamp(round(number, increment), min, max))
            end
            valueEditor.Visible = false
            self.ValueLabel.Visible = true
        end

        local function openEditor()
            if not valueEditor then
                valueEditor = Instance.new("TextBox")
                valueEditor.Name = "ValueEditor"
                valueEditor.BackgroundTransparency = 1
                valueEditor.Size = UDim2.fromOffset(50, 18)
                valueEditor.Position = UDim2.new(1, -50, 0, 0)
                valueEditor.TextSize = 14
                valueEditor.ClearTextOnFocus = false
                valueEditor.TextXAlignment = Enum.TextXAlignment.Right
                valueEditor.Text = tostring(Flags.GetFlag(props.Flag, min))
                valueEditor.TextColor3 = Theme.GetStyle("Text", "Default").Color
                    or Color3.fromRGB(255, 255, 255)
                valueEditor.Visible = false
                valueEditor.Parent = row

                valueEditor.FocusLost:Connect(function(enterPressed)
                    if enterPressed then
                        commitEditor()
                    else
                        -- Focus moved elsewhere: keep the edit (it commits on
                        -- the next tap), but restore the numeric label.
                        commitEditor()
                    end
                end)
            end
            valueEditor.Text = tostring(Flags.GetFlag(props.Flag, min))
            self.ValueLabel.Visible = false
            valueEditor.Visible = true
            task.defer(function()
                valueEditor:CaptureFocus()
            end)
        end

        local valueTap = Instance.new("TextButton")
        valueTap.Name = "ValueTap"
        valueTap.BackgroundTransparency = 1
        valueTap.Text = ""
        valueTap.Size = UDim2.fromOffset(50, 18)
        valueTap.Position = UDim2.new(1, -50, 0, 0)
        valueTap.ZIndex = self.ValueLabel.ZIndex + 1
        valueTap.Parent = row
        valueTap.MouseButton1Click:Connect(openEditor)

        self.Track = Render.New("Frame", {
            Name = "Track",
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.fromOffset(0, 26),
            CornerRadius = 3,
            Theme = "Default",
            Parent = row,
        })

        self.Fill = Render.New("Frame", {
            Name = "Fill",
            Size = UDim2.new(0, 0, 1, 0),
            CornerRadius = 3,
            Theme = "Enabled",
            Parent = self.Track,
        })

        self.Knob = Render.New("Frame", {
            Name = "Knob",
            Size = UDim2.fromOffset(14, 14),
            Position = UDim2.new(0, -7, 0.5, -7),
            AnchorPoint = Vector2.new(0, 0),
            CornerRadius = 7,
            Color = Color3.fromRGB(255, 255, 255),
            Theme = false,
            Parent = self.Track,
        })

        local hitbox = Instance.new("TextButton")
        hitbox.BackgroundTransparency = 1
        hitbox.Text = ""
        hitbox.Size = UDim2.new(1, 0, 1, 12)
        hitbox.Position = UDim2.fromOffset(0, -6)
        hitbox.ZIndex = self.Track.ZIndex + 2
        hitbox.Parent = self.Track

        local function setVisual(value)
            local range = max - min
            local alpha = (range ~= 0) and (value - min) / range or 1
            alpha = clamp(alpha, 0, 1)
            self.Fill.Size = UDim2.new(alpha, 0, 1, 0)
            self.Knob.Position = UDim2.new(alpha, -7, 0.5, -7)
            self.ValueLabel.Text = tostring(value)
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
            setVisual(value)
            if props.Callback then
                task.spawn(props.Callback, value)
            end
        end

        local dragging = false

        local function updateFromInputX(inputX)
            local trackAbsPos = self.Track.AbsolutePosition.X
            local trackAbsSize = self.Track.AbsoluteSize.X
            if trackAbsSize <= 0 then return end -- not laid out yet / invisible
            local alpha = clamp((inputX - trackAbsPos) / trackAbsSize, 0, 1)
            local value = round(min + (max - min) * alpha, increment)
            value = clamp(value, min, max)
            Flags.SetFlag(props.Flag, value)
        end

        hitbox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromInputX(input.Position.X)
            end
        end)

        local changedConn = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromInputX(input.Position.X)
            end
        end)

        local endedConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        if section.Window then
            section.Window:OnCleanup(function()
                changedConn:Disconnect()
                endedConn:Disconnect()
            end)
        end

        local initial = clamp(Flags.GetFlag(props.Flag, props.Default or min), min, max)
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        setVisual(initial)

        return self
    end

    Section.CreateSlider = function(section, props)
        return Slider.New(section, props)
    end

    return Slider
end
