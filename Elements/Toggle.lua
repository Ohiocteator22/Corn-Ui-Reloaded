--[[
    CornUi v2.0 — Elements/Toggle.lua
    Registers Section:CreateToggle(props).

    props = {
        Title = "Toggle Name",
        Description = "Optional second line", -- muted, wrapped
        Flag  = "MyToggleFlag",   -- required, key into Flags
        Default = false,
        Callback = function(value) end,
    }

    Perf note: the per-click visual update reads the theme's current colors
    directly instead of re-running Theme.Apply (which rebinds + repaints).
    Track stays bound to Frame/"Default" for theme-switch repaints; an
    OnChanged hook resyncs enabled tracks after a switch.
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Theme = Modules.Theme
    local Section = Modules.Window.Section

    local Toggle = {}
    Toggle.__index = Toggle

    local TweenService = game:GetService("TweenService")
    local SLIDE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    function Toggle.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()

        local self = setmetatable({}, Toggle)
        self.Flag = props.Flag

        local row = Render.New("Frame", {
            Name = "Toggle_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, props.Description and Theme.Tokens.RowWithDescription or Theme.Tokens.RowHeight),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        local labelWidth = UDim2.new(1, -46, 0, 18)
        Render.New("Text", {
            Text = props.Title or props.Flag,
            TextSize = 14,
            Size = labelWidth,
            Theme = "Default",
            Parent = row,
        })

        if props.Description then
            Render.New("Text", {
                Text = props.Description,
                TextSize = 12,
                TextWrapped = true,
                Size = UDim2.new(1, -46, 0, 20),
                Position = UDim2.fromOffset(0, 19),
                Theme = "Muted",
                Parent = row,
            })
        end

        self.Track = Render.New("Frame", {
            Name = "Track",
            Size = UDim2.fromOffset(38, 20),
            Position = UDim2.new(1, -38, props.Description and 0 or 0.5, props.Description and 0 or -10),
            CornerRadius = 10,
            Theme = "Default",
            Parent = row,
        })

        self.Knob = Render.New("Frame", {
            Name = "Knob",
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.new(0, 2, 0.5, -8),
            CornerRadius = 8,
            Color = Color3.fromRGB(255, 255, 255),
            Theme = false,
            Parent = self.Track,
        })

        local button = Instance.new("TextButton")
        button.BackgroundTransparency = 1
        button.Text = ""
        button.Size = UDim2.fromScale(1, 1)
        button.ZIndex = self.Track.ZIndex + 1
        button.Parent = self.Track

        local function setVisual(value)
            if Render.Motion() then
                local targetPos = value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                TweenService:Create(self.Knob, SLIDE_INFO, { Position = targetPos }):Play()
            else
                self.Knob.Position = value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            end

            -- Direct color read instead of Theme.Apply: no rebinding, no
            -- paint() pass, no Bindings churn on every click.
            local style = Theme.GetStyle("Frame", value and "Enabled" or "Default")
            if style and style.Color then
                self.Track.BackgroundColor3 = style.Color
            end
        end

        -- After a theme switch the track repaints to Frame/Default (its
        -- binding); if the toggle is currently ON, resync to Enabled.
        if section.Window then
            local resync = Theme.OnChanged:Connect(function()
                setVisual(Flags.GetFlag(props.Flag, false))
            end)
            section.Window:OnCleanup(function()
                resync:Disconnect()
            end)
        end

        local initial = Flags.GetFlag(props.Flag, props.Default or false)

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local value = b
            if a ~= self then
                value = a
            end
            setVisual(value)
            if props.Callback then
                task.spawn(props.Callback, value)
            end
        end

        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        setVisual(initial)

        button.MouseButton1Click:Connect(function()
            local current = Flags.GetFlag(props.Flag, false)
            Flags.SetFlag(props.Flag, not current)
        end)

        -- Cornelius: expose the toggle as a runnable command. The Hint is a
        -- function so the palette always shows the live On/Off state. The id
        -- is per-flag (flags are global across windows); Owner ties the
        -- entry to this window so Destroy releases it.
        if Modules.Commands then
            Modules.Commands.Register({
                Id = "CornUi.Toggle." .. props.Flag,
                Title = "Toggle: " .. (props.Title or props.Flag),
                Keywords = "toggle switch on off " .. props.Flag,
                Hint = function()
                    return Flags.GetFlag(props.Flag, false) and "On" or "Off"
                end,
                Owner = section.Window,
                Run = function()
                    local current = Flags.GetFlag(props.Flag, false)
                    Flags.SetFlag(props.Flag, not current)
                end,
            })
        end

        return self
    end

    -- Attach sugar method onto Section so callers write section:CreateToggle{...}
    Section.CreateToggle = function(section, props)
        return Toggle.New(section, props)
    end

    return Toggle
end
