--[[
    CreateSlider — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3342-3443. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.

    Draft 3 motion pass: the fill glides to the pointer instead of snapping, a
    round handle sits on the track and swells while you hold it, and a value
    bubble pops above the handle during the drag (Back easing in and out).
    Handle:Set() animates too. The window-level InputChanged / InputEnded
    listeners are now disconnected when the slider is destroyed.
]]

-- CornUi v1.9.4d (modular) — Elements/Slider.lua
return function(Modules)
    -- Verbatim-body prelude (the only non-v1.9.4d code in this file): binds
    -- the monolith's file-local upvalues to the module system. The loader's
    -- shared table IS the facade, so `Library.X` below reads exactly like
    -- the v1.9.4d source; every extracted body is byte-identical to it.
    local Library = Modules
    local Render = Modules.Render
    local Theme = Modules.Theme.Theme
    local TM = Modules.TabMethods
    local UserInputService = Render.UserInputService
    local TweenService = Render.TweenService
    local RunService = Render.RunService
    local create = Render.create
    local corner = Render.corner
    local setSearchMeta = Render.setSearchMeta
    local stroke = Render.stroke
    local tween = Render.tween
    local playInteractionSound = Render.playInteractionSound
    local ripple = Render.ripple
    local shiftZIndex = Render.shiftZIndex

-- ============================================================
-- SLIDER
-- ============================================================

function TM:CreateSlider(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local min = config.Min or 0
    local max = config.Max or 100
    local default = config.Default or min
    local callback = config.Callback or function() end
    local Motion = Library.Motion

    local function tw(inst, props, t, style, dir)
        if Motion then
            Motion.tw(inst, props, t, style, dir)
        else
            for prop, value in pairs(props) do inst[prop] = value end
        end
    end

    local trackH = touch and (compact and 10 or 14) or (compact and 6 or 8)
    local restD = trackH + 2
    local activeD = trackH + 10
    local bubbleH = (compact and not touch) and 16 or 20

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 48 or 58) or (compact and 38 or 46)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Slider")

    if config.Flag then Library:SetFlag(config.Flag, default) end

    local label = create("TextLabel", {
        Text = (config.Name or "Slider") .. ": " .. tostring(default),
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.new(0, 12, 0, compact and 2 or 4),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    label.Parent = holder

    local track = create("Frame", {
        Size = UDim2.new(1, -24, 0, trackH),
        Position = UDim2.new(0, 12, 1, touch and (compact and -18 or -22) or (compact and -14 or -16)),
        BackgroundColor3 = Color3.fromRGB(55, 55, 62),
    }, { corner(10) })
    track.Parent = holder

    local fraction = (default - min) / (max - min)
    local fill = create("Frame", {
        Size = UDim2.new(fraction, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
    }, { corner(10) })
    fill.Parent = track
    fill:SetAttribute("MUI_AccentSurface", true) -- eligible for a Skin's AccentTexture; always accent-colored
    Library:_applyAccentOverlay(fill, true)

    -- round handle that rides the end of the fill
    local knob = create("Frame", {
        Size = UDim2.fromOffset(restD, restD),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(fraction, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, { corner(999), create("UIStroke", { Color = Theme.Accent, Thickness = 2 }) })
    knob.Parent = track

    -- value bubble shown while dragging
    local bubbleScale = create("UIScale", { Scale = 0.4 })
    local bubbleText = create("TextLabel", {
        Text = tostring(default),
        Font = Enum.Font.GothamBold,
        TextSize = touch and 13 or 11,
        TextColor3 = Theme.TextOnAccent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })
    local bubble = create("Frame", {
        Size = UDim2.fromOffset(28, bubbleH),
        AnchorPoint = Vector2.new(fraction, 1),
        Position = UDim2.new(fraction, 0, 0, trackH / 2 - activeD / 2 - 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
    }, { corner(6), bubbleScale })
    bubbleText.Parent = bubble
    bubble.Parent = track

    local hitArea = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 34 or 40) or (compact and 20 or 26)),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
    })
    hitArea.Parent = track

    local dragging = false

    local function show(relative, value, animate)
        local fillSize = UDim2.new(relative, 0, 1, 0)
        local knobPos = UDim2.new(relative, 0, 0.5, 0)
        if animate then
            tw(fill, { Size = fillSize }, 0.12, Enum.EasingStyle.Quad)
            tw(knob, { Position = knobPos }, 0.12, Enum.EasingStyle.Quad)
        else
            fill.Size = fillSize
            knob.Position = knobPos
        end
        label.Text = (config.Name or "Slider") .. ": " .. tostring(value)
        local txt = tostring(value)
        bubbleText.Text = txt
        bubble.Size = UDim2.fromOffset(math.max(28, 12 + 8 * #txt), bubbleH)
        bubble.AnchorPoint = Vector2.new(relative, 1)
        bubble.Position = UDim2.new(relative, 0, 0, trackH / 2 - activeD / 2 - 2)
    end

    local function grab()
        bubble.Visible = true
        tw(knob, { Size = UDim2.fromOffset(activeD, activeD) }, 0.2, Enum.EasingStyle.Back)
        tw(bubbleScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
    end

    local function drop()
        tw(knob, { Size = UDim2.fromOffset(restD, restD) }, 0.25, Enum.EasingStyle.Back)
        task.delay(0.15, function()
            if dragging then return end
            tw(bubbleScale, { Scale = 0.4 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.13, function()
                if not dragging then bubble.Visible = false end
            end)
        end)
    end

    local function setFromInputPosition(xPos)
        local relative = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * relative)
        show(relative, value, true)
        if config.Flag then Library:SetFlag(config.Flag, value) end
        local ok, err = pcall(callback, value)
        if not ok then warn("[MobileUILib] Slider callback error: " .. tostring(err)) end
    end

    hitArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            grab()
            setFromInputPosition(input.Position.X)
        end
    end)

    local changedConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInputPosition(input.Position.X)
        end
    end)

    local endedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                drop()
            end
        end
    end)

    holder.Destroying:Connect(function()
        changedConn:Disconnect()
        endedConn:Disconnect()
    end)

    local handle = { Set = function(_, value)
        local relative = math.clamp((value - min) / (max - min), 0, 1)
        show(relative, value, true)
        if config.Flag then Library:SetFlag(config.Flag, value) end
    end, Get = function() return config.Flag and Library:GetFlag(config.Flag) or nil end }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return Library:_wrapElement(holder, handle)
end
end
