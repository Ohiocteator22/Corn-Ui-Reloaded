--[[
    CreateColorPicker — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3719-3905. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/ColorPicker.lua
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
-- COLOR PICKER
-- ============================================================

function TM:CreateColorPicker(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local color = config.Default or Color3.fromRGB(255, 0, 0)
    local callback = config.Callback or function() end
    local open = false
    local hue, sat, val = color:ToHSV()

    local closedH = touch and (compact and 38 or 46) or (compact and 28 or 34)
    local panelHeight = touch and (compact and 120 or 150) or (compact and 100 or 130)

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, closedH),
        BackgroundColor3 = Theme.Element,
        ClipsDescendants = true,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Color")

    if config.Flag then Library:SetFlag(config.Flag, color) end

    create("TextLabel", {
        Text = config.Name or "Color",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -60, 0, closedH),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local swatch = create("TextButton", {
        Text = "",
        BackgroundColor3 = color,
        Size = UDim2.new(0, touch and (compact and 28 or 34) or (compact and 20 or 26), 0, touch and (compact and 28 or 34) or (compact and 20 or 26)),
        Position = UDim2.new(1, touch and (compact and -38 or -44) or (compact and -28 or -34), 0, (closedH - (touch and (compact and 28 or 34) or (compact and 20 or 26))) / 2),
    }, { corner(10), stroke() })
    swatch.Parent = holder

    local panel = create("Frame", {
        Size = UDim2.new(1, -20, 0, panelHeight),
        Position = UDim2.new(0, 10, 0, closedH + 4),
        BackgroundTransparency = 1,
    })
    panel.Parent = holder

    local svHeight = touch and (compact and 80 or 100) or (compact and 70 or 84)
    local svSquare = create("Frame", {
        Size = UDim2.new(1, 0, 0, svHeight),
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
    }, { corner(10) })
    svSquare.Parent = panel

    local svGradient = create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1)),
    })
    svGradient.Parent = svSquare

    local blackOverlay = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, { corner(10) })
    blackOverlay.Parent = svSquare
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }).Parent = blackOverlay

    local svCursor = create("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(sat, 0, 1 - val, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 3,
    }, { corner(8), stroke(Color3.new(0, 0, 0), 1) })
    svCursor.Parent = svSquare

    local svHit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 4 })
    svHit.Parent = svSquare

    local hueStrip = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 22) or (compact and 14 or 16)),
        Position = UDim2.new(0, 0, 0, svHeight + 10),
    }, { corner(10) })
    hueStrip.Parent = panel

    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
            ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
            ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
            ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
            ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
    }).Parent = hueStrip

    local hueCursor = create("Frame", {
        Size = UDim2.new(0, 6, 1, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(hue, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 3,
    }, { stroke(Color3.new(0, 0, 0), 1) })
    hueCursor.Parent = hueStrip

    local hueHit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 4 })
    hueHit.Parent = hueStrip

    local function updateColor()
        color = Color3.fromHSV(hue, sat, val)
        swatch.BackgroundColor3 = color
        svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        svGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
        if config.Flag then Library:SetFlag(config.Flag, color) end
        local ok, err = pcall(callback, color)
        if not ok then warn("[MobileUILib] ColorPicker callback error: " .. tostring(err)) end
    end

    local draggingSV, draggingHue = false, false

    svHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = true
        end
    end)
    hueHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV, draggingHue = false, false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if draggingSV then
            local relX = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
            local relY = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
            sat, val = relX, 1 - relY
            svCursor.Position = UDim2.new(relX, 0, relY, 0)
            updateColor()
        elseif draggingHue then
            local relX = math.clamp((input.Position.X - hueStrip.AbsolutePosition.X) / hueStrip.AbsoluteSize.X, 0, 1)
            hue = relX
            hueCursor.Position = UDim2.new(relX, 0, 0.5, 0)
            updateColor()
        end
    end)

    swatch.MouseButton1Click:Connect(function()
        open = not open
        if self._window then
            self._window:SetSpotlight(open)
            shiftZIndex(holder, open and 50 or -50)
        end
        tween(holder, { Size = UDim2.new(1, 0, 0, open and (closedH + panelHeight + 8) or closedH) }, 0.2)
    end)

    local handle = {
        Set = function(_, newColor)
            hue, sat, val = newColor:ToHSV()
            color = newColor
            swatch.BackgroundColor3 = color
            svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
            hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
            updateColor()
        end,
        Get = function() return color end,
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return handle
end
end
