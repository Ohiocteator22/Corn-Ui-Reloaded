--[[
    CornUi v2.0 — Elements/Keybind.lua
    Registers Section:CreateKeybind(props).

    props = {
        Title = "Keybind Name",
        Flag  = "MyKeybindFlag",
        Default = Enum.KeyCode.F,
        Callback = function(keyCode) end,       -- fires on rebind
        OnPress = function() end,               -- fires when the bound key is pressed
    }
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Section = Modules.Window.Section
    local UserInputService = game:GetService("UserInputService")

    local Keybind = {}
    Keybind.__index = Keybind

    function Keybind.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()

        local self = setmetatable({}, Keybind)
        self.Flag = props.Flag
        self.Listening = false

        local row = Render.New("Frame", {
            Name = "Keybind_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 28),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        Render.New("Text", {
            Text = props.Title or props.Flag,
            TextSize = 14,
            Size = UDim2.new(1, -70, 1, 0),
            Theme = "Default",
            Parent = row,
        })

        self.Box = Render.New("Frame", {
            Name = "Box",
            Size = UDim2.fromOffset(64, 22),
            Position = UDim2.new(1, -64, 0.5, -11),
            CornerRadius = 5,
            Theme = "Default",
            Parent = row,
        })

        self.BoxLabel = Render.New("Text", {
            Text = "",
            TextSize = 12,
            XAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromScale(1, 1),
            Theme = "Muted",
            Parent = self.Box,
        })

        local button = Instance.new("TextButton")
        button.BackgroundTransparency = 1
        button.Text = ""
        button.Size = UDim2.fromScale(1, 1)
        button.ZIndex = self.Box.ZIndex + 1
        button.Parent = self.Box

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local keyCode = b
            if a ~= self then
                keyCode = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, keyCode, true) -- silent: programmatic Set also persists
            end
            self.BoxLabel.Text = self.Listening and "..." or (keyCode and keyCode.Name or "None")
            if props.Callback and not self.Listening then
                task.spawn(props.Callback, keyCode)
            end
        end

        button.MouseButton1Click:Connect(function()
            self.Listening = true
            self.BoxLabel.Text = "..."
        end)

        local beganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if self.Listening then
                -- Escape always cancels a rebind in progress (checked before
                -- gameProcessed: Escape often reports gameProcessed=true when
                -- the Roblox menu handles it, and cancel must still work).
                if input.KeyCode == Enum.KeyCode.Escape then
                    self.Listening = false
                    local bound = Flags.GetFlag(props.Flag)
                    self.BoxLabel.Text = bound and bound.Name or "None"
                    return
                end
                if gameProcessed then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    self.Listening = false
                    Flags.SetFlag(props.Flag, input.KeyCode)
                end
                return
            end

            if gameProcessed then return end

            local bound = Flags.GetFlag(props.Flag)
            if bound and input.KeyCode == bound and props.OnPress then
                task.spawn(props.OnPress)
            end
        end)

        if section.Window then
            section.Window:OnCleanup(function()
                beganConn:Disconnect()
            end)
        end

        local initial = Flags.GetFlag(props.Flag, props.Default)
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        self.Set(initial)

        return self
    end

    Section.CreateKeybind = function(section, props)
        return Keybind.New(section, props)
    end

    return Keybind
end
