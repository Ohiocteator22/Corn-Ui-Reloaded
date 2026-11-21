--[[
    CornUi v2.2 — Elements/Statusbar.lua
    Registers Window:CreateStatusbar(props) and Window:EnableAutoQuality().

    CreateStatusbar makes a small draggable pill that reports live
    device/session stats:
      FPS   — counted from RunService.RenderStepped, flushed every
              props.FpsWindow seconds (default 1)
      MEM   — Lua GC usage from gcinfo(), formatted in MB
      TIER  — Touch / PC / Pad / Roblox, from UserInputService flags

    EnableAutoQuality detects touch devices with small viewports and drops
    the render quality to Low once, with a toast explaining why.

    Polling design: no while-loops and no scheduled work between frames —
    frames are counted on RenderStepped and flushed inline when the sample
    window elapses. The standing cost is one connection plus one os.clock()
    call per frame.
]]

return function(Modules)

    local Render = Modules.Render
    local Window = Modules.Window.Window
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local function deviceTier(uis)
        if uis.TouchEnabled then
            return "Touch"
        elseif uis.KeyboardEnabled then
            return "PC"
        elseif uis.GamepadEnabled then
            return "Pad"
        end
        return "Roblox"
    end

    ------------------------------------------------------------
    -- Statusbar
    ------------------------------------------------------------

    function Window:CreateStatusbar(props)
        props = props or {}
        local fpsWindow = props.FpsWindow or 1

        local bar = Render.New("Frame", {
            Name = "Statusbar",
            Size = UDim2.fromOffset(178, 28),
            Position = props.Position or UDim2.fromOffset(16, 72),
            CornerRadius = 14,
            Theme = "Window",
            Parent = self.ScreenGui,
        })

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = bar

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = bar

        local fpsText = Render.New("Text", {
            Name = "FPS", Text = "-- fps", TextSize = 12,
            Size = UDim2.fromOffset(52, 16), Theme = "Muted", Parent = bar,
        })
        local memText = Render.New("Text", {
            Name = "MEM", Text = "-- M", TextSize = 12,
            Size = UDim2.fromOffset(46, 16), Theme = "Muted", Parent = bar,
        })
        local tierText = Render.New("Text", {
            Name = "TIER", Text = deviceTier(UserInputService), TextSize = 12,
            Size = UDim2.fromOffset(44, 16), Theme = "Muted", Parent = bar,
        })

        -- Draggable via the window's shared drag implementation (the bar is
        -- its own handle; its text children don't sink input). Drag-end
        -- cleanup and off-screen recovery come along for free.
        self:_makeDraggable(bar, bar)

        local frames = 0
        local sampleStart = os.clock()

        local renderConn = RunService.RenderStepped:Connect(function()
            frames += 1
            local elapsed = os.clock() - sampleStart
            if elapsed >= fpsWindow then
                local fps = math.floor(frames / math.max(elapsed, 0.05) + 0.5)
                fpsText.Text = fps .. " fps"
                memText.Text = string.format("%.1fM", gcinfo() / 1024)
                frames = 0
                sampleStart = os.clock()
            end
        end)

        self:OnCleanup(function()
            renderConn:Disconnect()
        end)

        return bar
    end

    ------------------------------------------------------------
    -- Auto quality — one-time, opt-in: touch device + small viewport
    -- -> Low quality, with a toast so the user knows why animations
    -- disappeared.
    ------------------------------------------------------------

    function Window:EnableAutoQuality()
        local okTouch, touch = pcall(function() return UserInputService.TouchEnabled end)
        if not okTouch or not touch then
            return false
        end

        local camera = game:GetService("Workspace").CurrentCamera
        if not (camera and camera.ViewportSize) then
            return false
        end

        if camera.ViewportSize.Y >= 800 then
            return false
        end

        Render.SetQuality("Low")
        if self.NotifHolder and self.Notify then
            pcall(self.Notify, self, {
                Title = "CornUi",
                Text = "Small touch device detected — animation quality set to Low for performance.",
                Type = "Success",
            })
        end
        return true
    end
end
