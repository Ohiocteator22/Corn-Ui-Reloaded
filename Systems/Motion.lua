--[[
    CornUi - Systems/Motion.lua  (Draft 3)

    Shared animation primitives for the v2.1 motion pass. Everything here
    respects Library.Flags.ReducedMotion / PerformanceMode (effects are skipped
    and properties are set instantly) and the window's animation-speed factor.

        Motion.tw(inst, props, time, style?, dir?)   tween with any easing style
        Motion.ripple(button, color)                 "Bloom" ripple (replaces Render.ripple)
        Motion.pressable(button, depth?)             squish on press, springy release
        Motion.burst(parent, center, color, size)    expanding ring + fade (toggle pop)

    Render.ripple delegates here, so every existing ripple(...) call in the
    library (buttons, Discord button, ...) picks up the new look automatically.
    Set Library.Motion = nil (or Library.Flags.ClassicRipple = true) to get the
    original centered ripple back.
]]

return function(Modules)
    local Library = Modules
    local Render = Modules.Render
    local create = Render.create
    local corner = Render.corner
    local TweenService = Render.TweenService
    local UserInputService = Render.UserInputService
    local GuiService = Render.GuiService

    local Motion = {}

    local function reduced()
        return Library.Flags.ReducedMotion or Library.Flags.PerformanceMode
    end

    local function speed()
        if Render.GetAnimationSpeed then return Render.GetAnimationSpeed() end
        return 1
    end

    function Motion.tw(inst, props, t, style, dir)
        if reduced() then
            for k, v in pairs(props) do inst[k] = v end
            return nil
        end
        local tween = TweenService:Create(
            inst,
            TweenInfo.new((t or 0.2) / speed(), style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
            props
        )
        tween:Play()
        return tween
    end

    -- Where the press happened, in the button's own scale space (0..1), or the
    -- centre if the pointer is not over the button (e.g. fired from code).
    local function pressPoint(button)
        local abs, pos = button.AbsoluteSize, button.AbsolutePosition
        if abs.X < 1 or abs.Y < 1 then return Vector2.new(0.5, 0.5), abs end
        local loc = UserInputService:GetMouseLocation()
        local gui = button:FindFirstAncestorOfClass("ScreenGui")
        local inset = Vector2.new(0, 0)
        if gui and not gui.IgnoreGuiInset then
            local ok, v = pcall(function() return GuiService:GetGuiInset() end)
            if ok then inset = v end
        end
        local p = loc - inset - pos
        if p.X < 0 or p.Y < 0 or p.X > abs.X or p.Y > abs.Y then
            return Vector2.new(0.5, 0.5), abs
        end
        return Vector2.new(p.X / abs.X, p.Y / abs.Y), abs
    end

    -- "Bloom": a soft disc grows out of the exact press point while a thin ring
    -- races ahead of it. Both are sized in X-relative scale so they stay round
    -- under the window's UIScale and on wide buttons.
    function Motion.ripple(button, color)
        if Library.Flags.ClassicRipple then
            return Render.classicRipple(button, color)
        end
        if reduced() then return end

        button.ClipsDescendants = true
        local origin, abs = pressPoint(button)

        local px, py = origin.X * abs.X, origin.Y * abs.Y
        local far = math.max(
            math.sqrt(px * px + py * py),
            math.sqrt((abs.X - px) ^ 2 + py * py),
            math.sqrt(px * px + (abs.Y - py) ^ 2),
            math.sqrt((abs.X - px) ^ 2 + (abs.Y - py) ^ 2)
        )
        local full = (2 * far) / abs.X -- diameter, as a multiple of the button's width

        local z = button.ZIndex + 5

        local disc = create("Frame", {
            BackgroundColor3 = color,
            BackgroundTransparency = 0.7,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(origin.X, origin.Y),
            Size = UDim2.fromScale(0, 0),
            SizeConstraint = Enum.SizeConstraint.RelativeXX,
            BorderSizePixel = 0,
            ZIndex = z,
        }, { corner(999) })
        disc.Parent = button

        local ringStroke = create("UIStroke", {
            Color = Color3.new(1, 1, 1),
            Thickness = 2,
            Transparency = 0.45,
        })
        local ring = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(origin.X, origin.Y),
            Size = UDim2.fromScale(0, 0),
            SizeConstraint = Enum.SizeConstraint.RelativeXX,
            BorderSizePixel = 0,
            ZIndex = z + 1,
        }, { corner(999), ringStroke })
        ring.Parent = button

        Motion.tw(disc, { Size = UDim2.fromScale(full, full), BackgroundTransparency = 1 }, 0.7, Enum.EasingStyle.Quint)
        Motion.tw(ring, { Size = UDim2.fromScale(full * 0.8, full * 0.8) }, 0.5, Enum.EasingStyle.Quart)
        Motion.tw(ringStroke, { Transparency = 1, Thickness = 0.5 }, 0.5, Enum.EasingStyle.Quad)

        task.delay(0.75 / speed(), function()
            disc:Destroy()
            ring:Destroy()
        end)
    end

    -- Squish on press, springy overshoot on release. Uses a UIScale so layout is
    -- unaffected. Safe to call once per button.
    function Motion.pressable(button, depth)
        if button:FindFirstChild("_Press") then return end
        local scale = create("UIScale", { Name = "_Press", Scale = 1 })
        scale.Parent = button
        local down = 1 - (depth or 0.035)

        local function press()
            Motion.tw(scale, { Scale = down }, 0.07, Enum.EasingStyle.Quad)
        end
        local function release()
            Motion.tw(scale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
        end

        button.MouseButton1Down:Connect(press)
        button.MouseButton1Up:Connect(release)
        button.MouseLeave:Connect(release)
    end

    -- Expanding, fading ring centred at `center` (a UDim2 inside `parent`).
    -- `size` is the diameter (px, local units) at the end of the animation.
    function Motion.burst(parent, center, color, size)
        if reduced() then return end
        local st = create("UIStroke", { Color = color, Thickness = 2, Transparency = 0.25 })
        local ring = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = center,
            Size = UDim2.fromOffset(size * 0.3, size * 0.3),
            BorderSizePixel = 0,
            ZIndex = parent.ZIndex + 3,
        }, { corner(999), st })
        ring.Parent = parent
        Motion.tw(ring, { Size = UDim2.fromOffset(size, size) }, 0.4, Enum.EasingStyle.Quart)
        Motion.tw(st, { Transparency = 1, Thickness = 0.5 }, 0.4, Enum.EasingStyle.Quad)
        task.delay(0.45 / speed(), function() ring:Destroy() end)
    end

    Library.Motion = Motion
    return Motion
end
