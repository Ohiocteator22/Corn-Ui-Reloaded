--[[
    CornUi v1.9.4d (modular) — Elements/Statusbar.lua

    ADDITION over the v1.9.4d window (the shell is untouched). Registers on
    WindowMethods:

        window:CreateStatusbar(props)   -- draggable FPS / memory / tier pill
        window:EnableAutoQuality()      -- drop to Low quality once, with a toast

    CreateStatusbar builds a small pill parented to the window's ScreenGui,
    styled from the live Theme table, dragged with the verbatim
    Render.makeDraggable helper:

      FPS   — RenderStepped frames counted, flushed every props.FpsWindow
              seconds (default 1)
      MEM   — gcinfo() in MB
      TIER  — Touch / PC / Pad, from UserInputService flags

    Poll-free by design: no while-loops and no scheduled work between
    frames — frames are counted on RenderStepped and the label is flushed
    inline when the sample window elapses. The standing cost is one
    connection plus one os.clock() call per frame.
]]

return function(Modules)

    local Library = Modules
    local Render = Modules.Render
    local Theme = Modules.Theme.Theme
    local WM = Modules.WindowMethods
    local RunService = Render.RunService
    local UserInputService = Render.UserInputService
    local create = Render.create
    local corner = Render.corner
    local stroke = Render.stroke
    local makeDraggable = Render.makeDraggable

    local autoQualityDone = false

    local function deviceTier()
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            return "Touch"
        elseif UserInputService.GamepadEnabled then
            return "Pad"
        elseif UserInputService.KeyboardEnabled then
            return "PC"
        end
        return "Roblox"
    end

    function WM:CreateStatusbar(props)
        props = props or {}
        local window = self
        local touch = self._touch

        local pill = create("Frame", {
            Name = "Statusbar",
            Size = UDim2.new(0, props.Width or (touch and 190 or 210), 0, props.Height or 30),
            Position = props.Position or UDim2.new(0, 12, 1, -42),
            BackgroundColor3 = Theme.Header,
            BorderSizePixel = 0,
            ZIndex = 200,
        }, { corner(10), stroke(Theme.Stroke, 1) })
        pill.Parent = self._screenGui

        local label = create("TextLabel", {
            Name = "Stats",
            Text = "FPS --  MEM --  " .. deviceTier(),
            Font = Enum.Font.GothamMedium,
            TextSize = touch and 12 or 13,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 201,
        })
        label.Parent = pill

        makeDraggable(pill, pill, false)

        local fpsWindow = props.FpsWindow or 1
        local frames = 0
        local windowStart = os.clock()
        local conn = RunService.RenderStepped:Connect(function()
            frames = frames + 1
            local now = os.clock()
            if now - windowStart >= fpsWindow then
                local fps = math.floor(frames / (now - windowStart) + 0.5)
                local mem = math.floor((gcinfo and gcinfo() or 0) / 1024 + 0.5)
                label.Text = ("FPS %d  MEM %dMB  %s"):format(fps, mem, deviceTier())
                frames = 0
                windowStart = now
            end
        end)

        pill.AncestryChanged:Connect(function(_, parent)
            if not parent and conn then conn:Disconnect() end
        end)

        return {
            Instance = pill,
            Destroy = function(_)
                if conn then conn:Disconnect() end
                if pill and pill.Parent then pill:Destroy() end
            end,
            SetVisible = function(_, visible)
                pill.Visible = visible and true or false
            end,
        }
    end

    function WM:EnableAutoQuality()
        if autoQualityDone then return false end
        autoQualityDone = true

        local camera = workspace.CurrentCamera
        local viewportY = camera and camera.ViewportSize and camera.ViewportSize.Y or 720
        local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

        if isTouch and viewportY < 700 then
            Library:SetFlag("PerformanceMode", true)
            Library:SetFlag("ReducedMotion", true)
            self:Notify({
                Title = "Auto Quality",
                Content = "Small touch device detected — effects reduced for smoother FPS.",
                Type = "info",
            })
            return true
        end
        return false
    end

    return { CreateStatusbar = WM.CreateStatusbar }
end
