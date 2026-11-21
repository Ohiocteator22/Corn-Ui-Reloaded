--[[
    CornUi v2.0 — Elements/TextInput.lua
    Registers Section:CreateTextInput(props). Plain string entry — used by
    the Theme Editor for pasting asset ids (textures, fonts) but generic
    enough for any raw-text need (webhook URLs, labels, etc).

    props = {
        Title = "Label",
        Flag  = "MyTextFlag",
        Placeholder = "rbxassetid://...",
        Default = "",
        Callback = function(text) end,   -- fires on FocusLost (not every keystroke)
    }
]]

return function(Modules)

    local Render = Modules.Render
    local Flags = Modules.Flags
    local Section = Modules.Window.Section

    local TextInput = {}
    TextInput.__index = TextInput

    function TextInput.New(section, props)
        props.Flag = props.Flag or Flags.NextAutoFlag()

        local self = setmetatable({}, TextInput)
        self.Flag = props.Flag

        local row = Render.New("Frame", {
            Name = "TextInput_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 44),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        if props.Title then
            Render.New("Text", {
                Text = props.Title,
                TextSize = 13,
                Size = UDim2.new(1, 0, 0, 16),
                Theme = "Muted",
                Parent = row,
            })
        end

        self.Box = Render.New("Frame", {
            Name = "Box",
            Size = UDim2.new(1, 0, 0, 24),
            Position = UDim2.fromOffset(0, props.Title and 20 or 0),
            CornerRadius = 5,
            Theme = "Default",
            Parent = row,
        })

        local textBox = Instance.new("TextBox")
        textBox.BackgroundTransparency = 1
        textBox.Size = UDim2.new(1, -16, 1, 0)
        textBox.Position = UDim2.fromOffset(8, 0)
        textBox.PlaceholderText = props.Placeholder or ""
        textBox.Text = ""
        textBox.TextSize = 13
        textBox.ClearTextOnFocus = false
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.Parent = self.Box
        self.Input = textBox

        Modules.Theme.Apply(textBox, "Text", { Theme = "Default" })

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local value = b
            if a ~= self then
                value = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, value, true) -- silent: programmatic Set also persists
            end
            textBox.Text = value or ""
            if props.Callback then
                task.spawn(props.Callback, textBox.Text)
            end
        end

        textBox.FocusLost:Connect(function()
            Flags.SetFlag(props.Flag, textBox.Text, true)
            if props.Callback then
                task.spawn(props.Callback, textBox.Text)
            end
        end)

        local initial = Flags.GetFlag(props.Flag, props.Default or "")
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        textBox.Text = initial

        return self
    end

    Section.CreateTextInput = function(section, props)
        return TextInput.New(section, props)
    end

    return TextInput
end
