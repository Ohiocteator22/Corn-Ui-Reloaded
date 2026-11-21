--[[
    CreateSlider — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3342-3443. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
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
        Size = UDim2.new(1, -24, 0, touch and (compact and 10 or 14) or (compact and 6 or 8)),
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

    local hitArea = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 34 or 40) or (compact and 20 or 26)),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
    })
    hitArea.Parent = track

    local dragging = false

    local function setFromInputPosition(xPos)
        local relative = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(relative, 0, 1, 0)
        local value = math.floor(min + (max - min) * relative)
        label.Text = (config.Name or "Slider") .. ": " .. tostring(value)
        if config.Flag then Library:SetFlag(config.Flag, value) end
        local ok, err = pcall(callback, value)
        if not ok then warn("[MobileUILib] Slider callback error: " .. tostring(err)) end
    end

    hitArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInputPosition(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInputPosition(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local handle = { Set = function(_, value)
        local relative = math.clamp((value - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(relative, 0, 1, 0)
        label.Text = (config.Name or "Slider") .. ": " .. tostring(value)
        if config.Flag then Library:SetFlag(config.Flag, value) end
    end, Get = function() return config.Flag and Library:GetFlag(config.Flag) or nil end }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return Library:_wrapElement(holder, handle)
end
end
