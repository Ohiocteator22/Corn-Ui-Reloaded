--[[
    CreateToggle (incl. three-state) — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3208-3340. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/Toggle.lua
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
-- TOGGLE (with Three-State)
-- ============================================================

function TM:CreateToggle(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local threeState = config.ThreeState or false

    local states = threeState and {"off", "auto", "on"} or {false, true}
    local stateIndex = 1
    local state = config.Default or (threeState and "auto" or false)

    if threeState then
        if state == "on" then stateIndex = 3
        elseif state == "auto" then stateIndex = 2
        else stateIndex = 1 end
    else
        if state then stateIndex = 2 else stateIndex = 1 end
    end

    local callback = config.Callback or function() end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Toggle")

    if config.Flag then Library:SetFlag(config.Flag, state) end

    create("TextLabel", {
        Text = config.Name or "Toggle",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local switchBg = create("Frame", {
        Size = UDim2.new(0, touch and (compact and 42 or 50) or (compact and 34 or 40), 0, touch and (compact and 24 or 28) or (compact and 18 or 22)),
        Position = UDim2.new(1, touch and (compact and -52 or -60) or (compact and -42 or -48), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = threeState and Color3.fromRGB(100, 100, 100) or (state and Theme.Accent or Color3.fromRGB(60, 60, 68)),
    }, { corner(18) })
    switchBg.Parent = holder
    switchBg:SetAttribute("MUI_AccentSurface", true) -- eligible for a Skin's AccentTexture whenever it's actually accent-colored
    Library:_applyAccentOverlay(switchBg, switchBg.BackgroundColor3 == Theme.Accent)

    local knob = create("Frame", {
        Size = UDim2.new(0, touch and (compact and 18 or 22) or (compact and 14 or 16), 0, touch and (compact and 18 or 22) or (compact and 14 or 16)),
        Position = threeState and UDim2.new(0.5, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) / 2), 0.5, 0) or
            (state and UDim2.new(1, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0)),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    }, { corner(15) })
    knob.Parent = switchBg

    if threeState then
        local stateLabel = create("TextLabel", {
            Text = "−",
            Font = Enum.Font.GothamBold,
            TextSize = touch and 14 or 12,
            TextColor3 = Color3.fromRGB(100, 100, 100),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
        })
        stateLabel.Parent = knob
    end

    local hitArea = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })
    hitArea.Parent = holder

    hitArea.MouseButton1Click:Connect(function()
        if threeState then
            stateIndex = (stateIndex % 3) + 1
            local states_map = {1, 2, 3}
            state = states_map[stateIndex]
        else
            state = not state
        end

        if threeState then
            if state == 3 then
                switchBg.BackgroundColor3 = Theme.Accent
                knob.Position = UDim2.new(1, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) + 3), 0.5, 0)
                stateLabel.Text = "+"
            elseif state == 2 then
                switchBg.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
                knob.Position = UDim2.new(0.5, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) / 2), 0.5, 0)
                stateLabel.Text = "−"
            else
                switchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
                knob.Position = UDim2.new(0, 3, 0.5, 0)
                stateLabel.Text = "×"
            end
        else
            switchBg.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 68)
            knob.Position = state and UDim2.new(1, -((touch and (compact and 18 or 22) or (compact and 14 or 16)) + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        end
        Library:_applyAccentOverlay(switchBg, switchBg.BackgroundColor3 == Theme.Accent)

        if config.Flag then Library:SetFlag(config.Flag, state) end
        playInteractionSound("toggle")
        local ok, err = pcall(callback, state)
        if not ok then warn("[MobileUILib] Toggle callback error: " .. tostring(err)) end
    end)

    local handle = {
        Set = function(_, value)
            if threeState then
                if value == "on" then stateIndex = 3
                elseif value == "auto" then stateIndex = 2
                else stateIndex = 1 end
            else
                state = value
            end
            hitArea.MouseButton1Click:Fire()
        end,
        Get = function() return state end
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return Library:_wrapElement(holder, handle)
end
end
