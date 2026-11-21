--[[
    CornUi v2.0 — Elements/DiscordButton.lua
    Registers Section:CreateDiscordButton(props).

    props = {
        Title = "Join our Discord",
        Invite = "https://discord.gg/...",
        Icon = "rbxassetid://...",   -- optional custom icon, defaults to a generic icon-less layout
    }

    Clicking copies the invite link to clipboard (via setclipboard, if the
    executor supports it) and fires props.OnClick if provided — Roblox
    clients can't open external URLs directly from a script.
]]

return function(Modules)

    local Render = Modules.Render
    local Section = Modules.Window.Section

    local DiscordButton = {}
    DiscordButton.__index = DiscordButton

    local DISCORD_BLURPLE = Color3.fromRGB(88, 101, 242)

    function DiscordButton.New(section, props)
        assert(props.Invite, "CreateDiscordButton: props.Invite is required")

        local self = setmetatable({}, DiscordButton)

        self.Frame = Render.New("Frame", {
            Name = "DiscordButton",
            Size = UDim2.new(1, 0, 0, 32),
            CornerRadius = 6,
            Color = DISCORD_BLURPLE,
            Theme = false,
            Parent = section.Frame,
        })

        local labelOffset = props.Icon and 36 or 8

        if props.Icon then
            Render.New("Icon", {
                Image = props.Icon,
                Size = UDim2.fromOffset(18, 18),
                Position = UDim2.fromOffset(8, 7),
                Color = Color3.new(1, 1, 1),
                Theme = false,
                Parent = self.Frame,
            })
        end

        Render.New("Text", {
            Text = props.Title or "Join our Discord",
            TextSize = 14,
            Color = Color3.new(1, 1, 1),
            XAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.new(1, -labelOffset - 8, 1, 0),
            Position = UDim2.fromOffset(labelOffset, 0),
            Theme = false,
            Parent = self.Frame,
        })

        local button = Instance.new("TextButton")
        button.BackgroundTransparency = 1
        button.Text = ""
        button.Size = UDim2.fromScale(1, 1)
        button.ZIndex = self.Frame.ZIndex + 1
        button.Parent = self.Frame

        button.MouseButton1Click:Connect(function()
            -- Shared clipboard helper (Host): capability-detects the
            -- executor's copy global and degrades to a warn() when absent.
            local Host = Modules.Host
            if Host then
                Host.SetClipboard(props.Invite)
            end
            if props.OnClick then
                task.spawn(props.OnClick, props.Invite)
            end
        end)

        return self
    end

    Section.CreateDiscordButton = function(section, props)
        return DiscordButton.New(section, props)
    end

    return DiscordButton
end
