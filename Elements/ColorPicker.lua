--[[
    CornUi v2.0 — Elements/ColorPicker.lua
    Registers Section:CreateColorPicker(props).

    props = {
        Title = "Color Name",
        Flag  = "MyColorFlag",
        Default = Color3.fromRGB(255, 255, 255),
        Callback = function(color) end,
    }

    Note: v1.x had a drag-input bug in this exact element — a tween's
    mid-animation values never matched an exact equality check used to
    detect drag completion. This build never tweens the picker's own
    drag handles; only Toggle/Slider track animations use TweenService.
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Theme = Modules.Theme
    local Section = Modules.Window.Section
    local UserInputService = game:GetService("UserInputService")

    local ColorPicker = {}
    ColorPicker.__index = ColorPicker

    local function clamp01(n) return math.clamp(n, 0, 1) end

    function ColorPicker.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()

        local self = setmetatable({}, ColorPicker)
        self.Flag = props.Flag
        self.Hue, self.Sat, self.Val = 0, 1, 1

        local container = Render.New("Frame", {
            Name = "ColorPicker_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 44),
            AutomaticSize = Enum.AutomaticSize.Y, -- grows/shrinks with the panel
            Clip = false,
            Theme = false,
            Parent = section.Frame,
        })
        container.BackgroundTransparency = 1

        Render.New("Text", {
            Text = props.Title or props.Flag,
            TextSize = 14,
            Size = UDim2.new(1, -40, 0, 18),
            Theme = "Default",
            Parent = container,
        })

        self.Preview = Render.New("Frame", {
            Name = "Preview",
            Size = UDim2.fromOffset(28, 18),
            Position = UDim2.new(1, -28, 0, 0),
            CornerRadius = 4,
            Theme = false,
            Parent = container,
        })

        local previewButton = Instance.new("TextButton")
        previewButton.BackgroundTransparency = 1
        previewButton.Text = ""
        previewButton.Size = UDim2.fromScale(1, 1)
        previewButton.ZIndex = self.Preview.ZIndex + 1
        previewButton.Parent = self.Preview

        self.Panel = Render.New("Frame", {
            Name = "Panel",
            Size = UDim2.new(1, 0, 0, 140),
            Position = UDim2.fromOffset(0, 22),
            CornerRadius = Theme.Tokens.PanelCorner,
            Theme = "Card",
            Visible = false,
            Parent = container,
        })

        -- Single-instance pop-in (0.12s) — skipped on Low quality.
        local popScale = Instance.new("UIScale")
        popScale.Scale = 1
        popScale.Parent = self.Panel

        -- Saturation/Value square
        self.SVMap = Render.New("Frame", {
            Name = "SVMap",
            Size = UDim2.new(1, -16, 0, 100),
            Position = UDim2.fromOffset(8, 8),
            CornerRadius = 4,
            Color = Color3.fromRGB(255, 0, 0),
            Theme = false,
            Parent = self.Panel,
        })

        local satGradient = Render.New("Gradient", {
            Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = self.SVMap,
        })
        satGradient.Name = "SatGradient"

        local valFrame = Instance.new("Frame")
        valFrame.BackgroundColor3 = Color3.new(0, 0, 0)
        valFrame.BackgroundTransparency = 1
        valFrame.Size = UDim2.fromScale(1, 1)
        valFrame.BorderSizePixel = 0
        valFrame.Parent = self.SVMap
        Render.New("Gradient", {
            Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Rotation = 90,
            Parent = valFrame,
        })

        self.SVCursor = Render.New("Frame", {
            Name = "Cursor",
            Size = UDim2.fromOffset(8, 8),
            CornerRadius = 4,
            Color = Color3.new(1, 1, 1),
            Theme = false,
            Parent = self.SVMap,
        })

        -- Hue strip
        self.HueBar = Render.New("Frame", {
            Name = "HueBar",
            Size = UDim2.new(1, -16, 0, 16),
            Position = UDim2.fromOffset(8, 116),
            CornerRadius = 4,
            Theme = false,
            Parent = self.Panel,
        })
        Render.New("Gradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.000, Color3.fromHSV(0.000, 1, 1)),
                ColorSequenceKeypoint.new(0.166, Color3.fromHSV(0.166, 1, 1)),
                ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
                ColorSequenceKeypoint.new(0.500, Color3.fromHSV(0.500, 1, 1)),
                ColorSequenceKeypoint.new(0.666, Color3.fromHSV(0.666, 1, 1)),
                ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
                ColorSequenceKeypoint.new(1.000, Color3.fromHSV(1.000, 1, 1)),
            }),
            Parent = self.HueBar,
        })

        self.HueCursor = Render.New("Frame", {
            Name = "HueCursor",
            Size = UDim2.fromOffset(8, 8),
            CornerRadius = 4,
            Color = Color3.new(1, 1, 1),
            Theme = false,
            Parent = self.HueBar,
        })

        local function currentColor()
            return Color3.fromHSV(self.Hue, self.Sat, self.Val)
        end

        local function redraw()
            local color = currentColor()
            self.Preview.BackgroundColor3 = color
            self.SVMap.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
            self.SVCursor.Position = UDim2.new(self.Sat, -4, 1 - self.Val, -4)
            self.HueCursor.Position = UDim2.new(self.Hue, -4, 0.5, -4)
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
            local h, s, v = Color3.toHSV(value)
            self.Hue, self.Sat, self.Val = h, s, v
            redraw()
            if props.Callback then
                task.spawn(props.Callback, value)
            end
        end

        previewButton.MouseButton1Click:Connect(function()
            self.Panel.Visible = not self.Panel.Visible
            if self.Panel.Visible and Render.Motion() then
                local TweenService = game:GetService("TweenService")
                popScale.Scale = 0.97
                TweenService:Create(popScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            end
        end)

        local draggingSV, draggingHue = false, false

        local function updateSV(pos)
            local abs = self.SVMap.AbsolutePosition
            local size = self.SVMap.AbsoluteSize
            self.Sat = clamp01((pos.X - abs.X) / size.X)
            self.Val = 1 - clamp01((pos.Y - abs.Y) / size.Y)
            Flags.SetFlag(props.Flag, currentColor())
        end

        local function updateHue(pos)
            local abs = self.HueBar.AbsolutePosition
            local size = self.HueBar.AbsoluteSize
            self.Hue = clamp01((pos.X - abs.X) / size.X)
            Flags.SetFlag(props.Flag, currentColor())
        end

        local svButton = Instance.new("TextButton")
        svButton.BackgroundTransparency = 1
        svButton.Text = ""
        svButton.Size = UDim2.fromScale(1, 1)
        svButton.ZIndex = self.SVMap.ZIndex + 2
        svButton.Parent = self.SVMap
        svButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                draggingSV = true
                updateSV(input.Position)
            end
        end)

        local hueButton = Instance.new("TextButton")
        hueButton.BackgroundTransparency = 1
        hueButton.Text = ""
        hueButton.Size = UDim2.fromScale(1, 1)
        hueButton.ZIndex = self.HueBar.ZIndex + 1
        hueButton.Parent = self.HueBar
        hueButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                draggingHue = true
                updateHue(input.Position)
            end
        end)

        local changedConn = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if draggingSV then updateSV(input.Position) end
            if draggingHue then updateHue(input.Position) end
        end)

        local endedConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                draggingSV = false
                draggingHue = false
            end
        end)

        -- Disconnect the global input listeners when the host window dies,
        -- instead of leaking them for the rest of the session.
        if section.Window then
            section.Window:OnCleanup(function()
                changedConn:Disconnect()
                endedConn:Disconnect()
            end)
        end

        local initial = Flags.GetFlag(props.Flag, props.Default or Color3.fromRGB(255, 255, 255))
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        self.Set(initial)

        return self
    end

    Section.CreateColorPicker = function(section, props)
        return ColorPicker.New(section, props)
    end

    return ColorPicker
end
