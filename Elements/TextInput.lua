--[[
    CreateTextbox (+CreateTextBox alias) — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3445-3504. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/TextInput.lua
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
-- TEXTBOX
-- ============================================================

function TM:CreateTextbox(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local callback = config.Callback or function() end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Input")

    if config.Flag then Library:SetFlag(config.Flag, config.Default or "") end

    create("TextLabel", {
        Text = config.Name or "Input",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.4, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local box = create("TextBox", {
        Text = config.Default or "",
        PlaceholderText = config.Placeholder or "Enter text...",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.SubText,
        BackgroundColor3 = Theme.ElementHover,
        Size = UDim2.new(0.55, -12, 0, touch and (compact and 28 or 34) or (compact and 18 or 24)),
        Position = UDim2.new(0.45, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ClearTextOnFocus = false,
    }, { corner(10) })
    box.Parent = holder

    box.FocusLost:Connect(function(enterPressed)
        if config.Flag then Library:SetFlag(config.Flag, box.Text) end
        local ok, err = pcall(callback, box.Text, enterPressed)
        if not ok then warn("[MobileUILib] Textbox callback error: " .. tostring(err)) end
    end)

    local handle = { Set = function(_, value)
        box.Text = value
        if config.Flag then Library:SetFlag(config.Flag, value) end
    end, Get = function() return box.Text end }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return Library:_wrapElement(holder, handle)
end

TM.CreateTextBox = TM.CreateTextbox
end
