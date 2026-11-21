--[[
    CreateDropdown + CreateMultiDropdown + CreateRadioGroup — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3938-4310. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/Dropdown.lua
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
-- DROPDOWN
-- ============================================================

function TM:CreateDropdown(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local options = config.Options or {}
    local selected = config.Default or options[1]
    local callback = config.Callback or function() end
    local open = false

    local closedH = touch and (compact and 38 or 46) or (compact and 28 or 34)
    local itemHeight = touch and (compact and 34 or 40) or (compact and 24 or 30)
    local maxVisibleItems = 6
    local totalHeight = #options * itemHeight
    local panelHeight = math.min(totalHeight, maxVisibleItems * itemHeight)

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, closedH),
        BackgroundColor3 = Theme.Element,
        ClipsDescendants = true,
        ZIndex = 2,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Dropdown")

    if config.Flag then Library:SetFlag(config.Flag, selected) end

    local mainBtn = create("TextButton", {
        Text = (config.Name or "Dropdown") .. ": " .. tostring(selected),
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, closedH),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, {
        create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
    })
    mainBtn.Parent = holder

    local optionsFrame = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, panelHeight),
        Position = UDim2.new(0, 0, 0, closedH),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = touch and 6 or 4,
        CanvasSize = UDim2.new(0, 0, 0, totalHeight),
        ZIndex = 2,
    }, {
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    optionsFrame.Parent = holder

    for _, opt in ipairs(options) do
        local optBtn = create("TextButton", {
            Text = tostring(opt),
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
            TextColor3 = Theme.SubText,
            BackgroundColor3 = Theme.ElementHover,
            Size = UDim2.new(1, 0, 0, itemHeight),
            ZIndex = 2,
        })
        optBtn.Parent = optionsFrame

        optBtn.MouseButton1Click:Connect(function()
            selected = opt
            mainBtn.Text = (config.Name or "Dropdown") .. ": " .. tostring(selected)
            open = false
            if self._window then
                self._window:SetSpotlight(false)
                shiftZIndex(holder, -50)
            end
            tween(holder, { Size = UDim2.new(1, 0, 0, closedH) }, 0.15)
            if config.Flag then Library:SetFlag(config.Flag, selected) end
            playInteractionSound("dropdown")
            local ok, err = pcall(callback, selected)
            if not ok then warn("[MobileUILib] Dropdown callback error: " .. tostring(err)) end
        end)
    end

    mainBtn.MouseButton1Click:Connect(function()
        open = not open
        if self._window then
            self._window:SetSpotlight(open)
            shiftZIndex(holder, open and 50 or -50)
        end
        tween(holder, { Size = UDim2.new(1, 0, 0, open and (closedH + panelHeight) or closedH) }, 0.15)
        playInteractionSound("dropdown")
    end)

    local handle = { Set = function(_, value)
        selected = value
        mainBtn.Text = (config.Name or "Dropdown") .. ": " .. tostring(selected)
        if config.Flag then Library:SetFlag(config.Flag, selected) end
    end }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return handle
end

-- ============================================================
-- MULTI-SELECT DROPDOWN
-- ============================================================

function TM:CreateMultiDropdown(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local options = config.Options or {}
    local selected = config.Default or {}
    if type(selected) ~= "table" then selected = {} end
    local callback = config.Callback or function() end
    local open = false

    local closedH = touch and (compact and 38 or 46) or (compact and 28 or 34)
    local itemHeight = touch and (compact and 34 or 40) or (compact and 24 or 30)
    local maxVisibleItems = 6
    local totalHeight = #options * itemHeight
    local panelHeight = math.min(totalHeight, maxVisibleItems * itemHeight)

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, closedH),
        BackgroundColor3 = Theme.Element,
        ClipsDescendants = true,
        ZIndex = 2,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Multi-Select")

    if config.Flag then Library:SetFlag(config.Flag, selected) end

    local selectedText = #selected > 0 and table.concat(selected, ", ") or "None selected"
    local mainBtn = create("TextButton", {
        Text = (config.Name or "Select") .. ": " .. selectedText,
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, closedH),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    }, {
        create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
    })
    mainBtn.Parent = holder

    local optionsFrame = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, panelHeight),
        Position = UDim2.new(0, 0, 0, closedH),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = touch and 6 or 4,
        CanvasSize = UDim2.new(0, 0, 0, totalHeight),
        ZIndex = 2,
    }, {
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    optionsFrame.Parent = holder

    local optionStates = {}

    for _, opt in ipairs(options) do
        local isSelected = false
        for _, s in ipairs(selected) do
            if s == opt then isSelected = true break end
        end
        optionStates[opt] = isSelected

        local optBtn = create("TextButton", {
            Text = (isSelected and "☑ " or "☐ ") .. tostring(opt),
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
            TextColor3 = isSelected and Theme.Accent or Theme.SubText,
            BackgroundColor3 = Theme.ElementHover,
            Size = UDim2.new(1, 0, 0, itemHeight),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        }, {
            create("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
        })
        optBtn.Parent = optionsFrame

        optBtn.MouseButton1Click:Connect(function()
            optionStates[opt] = not optionStates[opt]
            local isNowSelected = optionStates[opt]
            optBtn.Text = (isNowSelected and "☑ " or "☐ ") .. tostring(opt)
            optBtn.TextColor3 = isNowSelected and Theme.Accent or Theme.SubText

            selected = {}
            for o, s in pairs(optionStates) do
                if s then table.insert(selected, o) end
            end

            local selectedTextNew = #selected > 0 and table.concat(selected, ", ") or "None selected"
            mainBtn.Text = (config.Name or "Select") .. ": " .. selectedTextNew

            if config.Flag then Library:SetFlag(config.Flag, selected) end
            playInteractionSound("click")
            local ok, err = pcall(callback, selected)
            if not ok then warn("[MobileUILib] MultiDropdown callback error: " .. tostring(err)) end
        end)
    end

    mainBtn.MouseButton1Click:Connect(function()
        open = not open
        if self._window then
            self._window:SetSpotlight(open)
            shiftZIndex(holder, open and 50 or -50)
        end
        tween(holder, { Size = UDim2.new(1, 0, 0, open and (closedH + panelHeight) or closedH) }, 0.15)
        playInteractionSound("dropdown")
    end)

    local handle = {
        Set = function(_, newSelected)
            if type(newSelected) ~= "table" then newSelected = {} end
            selected = newSelected
            for opt, btn in pairs(optionStates) do
                local isSelected = false
                for _, s in ipairs(selected) do
                    if s == opt then isSelected = true break end
                end
                optionStates[opt] = isSelected
                for _, child in ipairs(optionsFrame:GetChildren()) do
                    if child:IsA("TextButton") and child.Text:match(tostring(opt)) then
                        child.Text = (isSelected and "☑ " or "☐ ") .. tostring(opt)
                        child.TextColor3 = isSelected and Theme.Accent or Theme.SubText
                    end
                end
            end
            local selectedTextNew = #selected > 0 and table.concat(selected, ", ") or "None selected"
            mainBtn.Text = (config.Name or "Select") .. ": " .. selectedTextNew
            if config.Flag then Library:SetFlag(config.Flag, selected) end
        end,
        Get = function() return selected end,
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return handle
end

-- ============================================================
-- RADIO GROUP
-- ============================================================

function TM:CreateRadioGroup(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local options = config.Options or {}
    local selected = config.Default or options[1]
    local callback = config.Callback or function() end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Radio Group")

    if config.Flag then Library:SetFlag(config.Flag, selected) end

    create("TextLabel", {
        Text = config.Name or "Select Option",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 24) or (compact and 14 or 18)),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
    }).Parent = holder

    local list = create("Frame", {
        Size = UDim2.new(1, -10, 0, 0),
        Position = UDim2.new(0, 5, 0, touch and (compact and 22 or 28) or (compact and 18 or 22)),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, compact and 2 or 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", {
            PaddingBottom = UDim.new(0, compact and 4 or 6),
        }),
    })
    list.Parent = holder

    local radioButtons = {}

    for i, opt in ipairs(options) do
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, touch and (compact and 24 or 30) or (compact and 18 or 24)),
            BackgroundTransparency = 1,
            LayoutOrder = i,
        }, {
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 8),
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),
        })
        row.Parent = list

        local radioBtn = create("TextButton", {
            Text = (opt == selected) and "◉" or "○",
            Font = Enum.Font.GothamBold,
            TextSize = touch and (compact and 18 or 20) or (compact and 16 or 18),
            TextColor3 = (opt == selected) and Theme.Accent or Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, touch and (compact and 22 or 26) or (compact and 18 or 22), 1, 0),
        })
        radioBtn.Parent = row

        local label = create("TextLabel", {
            Text = tostring(opt),
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
            TextColor3 = (opt == selected) and Theme.Text or Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        label.Parent = row

        radioButtons[opt] = { btn = radioBtn, label = label }

        radioBtn.MouseButton1Click:Connect(function()
            if opt == selected then return end

            for oldOpt, data in pairs(radioButtons) do
                data.btn.Text = "○"
                data.btn.TextColor3 = Theme.SubText
                data.label.TextColor3 = Theme.SubText
            end

            selected = opt
            radioBtn.Text = "◉"
            radioBtn.TextColor3 = Theme.Accent
            label.TextColor3 = Theme.Text

            if config.Flag then Library:SetFlag(config.Flag, selected) end
            playInteractionSound("click")
            local ok, err = pcall(callback, selected)
            if not ok then warn("[MobileUILib] RadioGroup callback error: " .. tostring(err)) end
        end)
    end

    local handle = {
        Set = function(_, value)
            if not radioButtons[value] then return end
            for oldOpt, data in pairs(radioButtons) do
                data.btn.Text = "○"
                data.btn.TextColor3 = Theme.SubText
                data.label.TextColor3 = Theme.SubText
            end
            selected = value
            radioButtons[value].btn.Text = "◉"
            radioButtons[value].btn.TextColor3 = Theme.Accent
            radioButtons[value].label.TextColor3 = Theme.Text
            if config.Flag then Library:SetFlag(config.Flag, selected) end
        end,
        Get = function() return selected end,
    }
    if config.Flag then Library.FlagElements[config.Flag] = handle end
    return Library:_wrapElement(holder, handle)
end
end
