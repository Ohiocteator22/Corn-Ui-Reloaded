--[[
    CreateToggle (incl. three-state) — v1.9.4d logic + draft-3 motion pass.

    Draft 3: the knob now springs (Back easing) with a stretch pulse, the track
    color eases, a ring bursts from the knob and the row blooms. Also fixes the
    two known defects: the three-state click crashed on a nil `stateLabel`, and
    handle.Set called MouseButton1Click:Fire() (signals have no Fire). Three-state
    values are now the strings "off" / "auto" / "on", matching Default and Set.
    Set() applies the value (callback + flag, no click sound); a real click
    plays the sound.

    (Original header follows.)

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
    local Motion = Library.Motion

    local sw = touch and (compact and 42 or 50) or (compact and 34 or 40) -- switch width
    local sh = touch and (compact and 24 or 28) or (compact and 18 or 22) -- switch height
    local k = touch and (compact and 18 or 22) or (compact and 14 or 16)  -- knob size
    local OFF_COLOR = Color3.fromRGB(60, 60, 68)
    local MID_COLOR = Color3.fromRGB(150, 150, 150)

    local callback = config.Callback or function() end

    local function normalize(value)
        if threeState then
            if value == "on" or value == true then return "on" end
            if value == "off" or value == false then return "off" end
            return "auto"
        end
        return value and true or false
    end

    local state = normalize(config.Default)
    if threeState and config.Default == nil then state = "auto" end

    -- tween through Motion when available, otherwise assign directly
    local function tw(inst, props, t, style)
        if Motion then
            Motion.tw(inst, props, t, style)
        else
            for prop, value in pairs(props) do inst[prop] = value end
        end
    end

    local function look(s)
        if threeState then
            if s == "on" then
                return Theme.Accent, UDim2.new(1, -(k + 3), 0.5, 0), "+"
            elseif s == "auto" then
                return MID_COLOR, UDim2.new(0.5, -k / 2, 0.5, 0), "−"
            end
            return OFF_COLOR, UDim2.new(0, 3, 0.5, 0), "×"
        end
        if s then
            return Theme.Accent, UDim2.new(1, -(k + 3), 0.5, 0), nil
        end
        return OFF_COLOR, UDim2.new(0, 3, 0.5, 0), nil
    end

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

    local startColor, startPos, startGlyph = look(state)

    local switchBg = create("Frame", {
        Size = UDim2.new(0, sw, 0, sh),
        Position = UDim2.new(1, touch and (compact and -52 or -60) or (compact and -42 or -48), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = startColor,
    }, { corner(18) })
    switchBg.Parent = holder
    switchBg:SetAttribute("MUI_AccentSurface", true) -- eligible for a Skin's AccentTexture whenever it's actually accent-colored
    Library:_applyAccentOverlay(switchBg, startColor == Theme.Accent)

    local knob = create("Frame", {
        Size = UDim2.fromOffset(k, k),
        Position = startPos,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    }, { corner(15) })
    knob.Parent = switchBg

    local stateLabel
    if threeState then
        stateLabel = create("TextLabel", {
            Text = startGlyph,
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

    -- Visuals only: animates when `animate` is true. No flag / callback here.
    local function apply(newState, animate)
        state = newState
        local color, pos, glyph = look(state)
        if stateLabel and glyph then stateLabel.Text = glyph end

        if animate then
            tw(switchBg, { BackgroundColor3 = color }, 0.22, Enum.EasingStyle.Sine)
            tw(knob, { Position = pos }, 0.34, Enum.EasingStyle.Back)
            -- liquid stretch while travelling
            tw(knob, { Size = UDim2.fromOffset(k + 6, k - 2) }, 0.08, Enum.EasingStyle.Quad)
            task.delay(0.08, function()
                tw(knob, { Size = UDim2.fromOffset(k, k) }, 0.26, Enum.EasingStyle.Back)
            end)
            if Motion then
                local cx = pos.X.Scale * sw + pos.X.Offset + k / 2
                local burstColor = (color == Theme.Accent) and Theme.Accent or Color3.fromRGB(220, 220, 230)
                Motion.burst(switchBg, UDim2.fromOffset(cx, sh / 2), burstColor, k * 2.6)
                if color == Theme.Accent then ripple(holder, Theme.Accent) end
            end
        else
            switchBg.BackgroundColor3 = color
            knob.Position = pos
        end
        Library:_applyAccentOverlay(switchBg, color == Theme.Accent)
    end

    local function commit(newState, playSound)
        apply(newState, newState ~= state)
        if config.Flag then Library:SetFlag(config.Flag, state) end
        if playSound then playInteractionSound("toggle") end
        local ok, err = pcall(callback, state)
        if not ok then warn("[MobileUILib] Toggle callback error: " .. tostring(err)) end
    end

    local NEXT = { off = "auto", auto = "on", on = "off" }

    hitArea.MouseButton1Click:Connect(function()
        if threeState then
            commit(NEXT[state], true)
        else
            commit(not state, true)
        end
    end)

    local handle = {
        Set = function(_, value)
            commit(normalize(value), false)
        end,
        Get = function() return state end
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return Library:_wrapElement(holder, handle)
end
end
