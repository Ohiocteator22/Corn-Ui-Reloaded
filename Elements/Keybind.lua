--[[
    CreateKeybind + CreateHotkey — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3506-3717. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/Keybind.lua
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
-- KEYBIND
-- ============================================================

function TM:CreateKeybind(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local currentKey = config.Default or Enum.KeyCode.Unknown
    local callback = config.Callback or function() end
    local listening = false
    local keybindDescriptor = { Name = config.Name or "Keybind" }

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Keybind")

    if config.Flag then Library:SetFlag(config.Flag, currentKey) end

    create("TextLabel", {
        Text = config.Name or "Keybind",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local keyBtn = create("TextButton", {
        Text = (currentKey ~= Enum.KeyCode.Unknown) and currentKey.Name or "None",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.ElementHover,
        Size = UDim2.new(0, touch and (compact and 70 or 80) or (compact and 60 or 70), 0, touch and (compact and 28 or 34) or (compact and 18 or 24)),
        Position = UDim2.new(1, touch and (compact and -80 or -90) or (compact and -70 or -80), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
    }, { corner(10) })
    keyBtn.Parent = holder

    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyBtn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = input.KeyCode
                keyBtn.Text = currentKey.Name
                listening = false
                conn:Disconnect()
                if config.Flag then Library:SetFlag(config.Flag, currentKey) end
                Library.KeybindChanged:Fire(keybindDescriptor)
                local ok, err = pcall(callback, currentKey)
                if not ok then warn("[MobileUILib] Keybind callback error: " .. tostring(err)) end
            end
        end)
    end)

    local handle = {
        Set = function(_, keyCode)
            currentKey = keyCode
            keyBtn.Text = keyCode.Name
            if config.Flag then Library:SetFlag(config.Flag, keyCode) end
            Library.KeybindChanged:Fire(keybindDescriptor)
        end,
        Get = function() return currentKey end,
        Destroy = function(_)
            for i, d in ipairs(Library.Keybinds) do
                if d == keybindDescriptor then
                    table.remove(Library.Keybinds, i)
                    break
                end
            end
            Library.KeybindUnregistered:Fire(keybindDescriptor)
            if holder and holder.Parent then holder:Destroy() end
        end,
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end

    keybindDescriptor.Get = handle.Get
    table.insert(Library.Keybinds, keybindDescriptor)
    Library.KeybindRegistered:Fire(keybindDescriptor)

    return Library:_wrapElement(holder, handle)
end

-- ============================================================
-- HOTKEY
-- ============================================================

function TM:CreateHotkey(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local currentKey = config.Default or Enum.KeyCode.Unknown
    local callback = config.Callback or function() end
    local listening = false
    local isPressed = false
    local holdTimer = nil
    local keybindDescriptor = { Name = config.Name or "Hotkey" }

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Hotkey")

    if config.Flag then Library:SetFlag(config.Flag, currentKey) end

    create("TextLabel", {
        Text = config.Name or "Hotkey",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local keyBtn = create("TextButton", {
        Text = (currentKey ~= Enum.KeyCode.Unknown) and currentKey.Name or "None",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.ElementHover,
        Size = UDim2.new(0, touch and (compact and 70 or 80) or (compact and 60 or 70), 0, touch and (compact and 28 or 34) or (compact and 18 or 24)),
        Position = UDim2.new(1, touch and (compact and -80 or -90) or (compact and -70 or -80), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
    }, { corner(10) })
    keyBtn.Parent = holder

    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyBtn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = input.KeyCode
                keyBtn.Text = currentKey.Name
                listening = false
                conn:Disconnect()
                if config.Flag then Library:SetFlag(config.Flag, currentKey) end
                local ok, err = pcall(callback, "bind", currentKey)
                if not ok then warn("[MobileUILib] Hotkey callback error: " .. tostring(err)) end
            end
        end)
    end)

    local pressConn
    local function startListening()
        if pressConn then pressConn:Disconnect() end
        pressConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey and not listening then
                isPressed = true
                keyBtn.BackgroundColor3 = Theme.Accent
                keyBtn.TextColor3 = Theme.TextOnAccent
                local ok, err = pcall(callback, "press", currentKey)
                if not ok then warn("[MobileUILib] Hotkey callback error: " .. tostring(err)) end

                if holdTimer then holdTimer:Cancel() end
                holdTimer = task.delay(0.5, function()
                    if isPressed then
                        local ok2, err2 = pcall(callback, "hold", currentKey)
                        if not ok2 then warn("[MobileUILib] Hotkey callback error: " .. tostring(err2)) end
                    end
                end)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey and isPressed then
                isPressed = false
                keyBtn.BackgroundColor3 = Theme.ElementHover
                keyBtn.TextColor3 = Theme.Text
                if holdTimer then holdTimer:Cancel() end
                local ok, err = pcall(callback, "release", currentKey)
                if not ok then warn("[MobileUILib] Hotkey callback error: " .. tostring(err)) end
            end
        end)
    end
    startListening()

    local handle = {
        Set = function(_, keyCode)
            currentKey = keyCode
            keyBtn.Text = keyCode.Name
            if config.Flag then Library:SetFlag(config.Flag, keyCode) end
            startListening()
        end,
        Get = function() return currentKey end,
        Destroy = function(_)
            if pressConn then pressConn:Disconnect() end
            if holdTimer then holdTimer:Cancel() end
            if holder and holder.Parent then holder:Destroy() end
        end,
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end

    return Library:_wrapElement(holder, handle)
end
end
