--[[
    CreateCustom / CreateSection / CreateLabel / CreateButton / CreateDivider / CreateCard / CreateParagraph / CreateImage / CreateProgressBar / CreateMeter / CreateTimer / CreateChecklist — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3067-3206, 4486-4523, 4525-4599, 4601-4663, 4665-4719, 4721-4803, 4805-4894, 4896-5047, 5049-5185. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/Basics.lua
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

function TM:CreateCustom(name, config)
    local constructor = Library._customElements[name]
    if not constructor then
        warn("[MobileUILib] Unknown custom element: " .. tostring(name))
        return nil
    end
    return constructor(self, config)
end

-- ============================================================
-- SECTION
-- ============================================================

function TM:CreateSection(name)
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local container = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and 40 or 30),
        BackgroundColor3 = Theme.Header,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(12), stroke() })
    container.Parent = self._page

    -- Content lives in its own inner wrapper so `container` (the actual
    -- textured/colored surface) has no UIListLayout as a DIRECT child —
    -- WindowTexture skips any surface with one (see the note above
    -- _applyTiledOverlay) to avoid corrupting real layouts, and a Section's
    -- own UIListLayout for stacking its elements was getting caught by
    -- that same guard, silently excluding almost every panel in the UI.
    -- `container`'s AutomaticSize.Y still grows correctly to match this
    -- inner Frame's own AutomaticSize.Y — Roblox measures a parent's
    -- AutomaticSize from its children's resolved extents regardless of
    -- how those children compute their own size.
    local content = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, compact and 4 or 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 4 or 8),
            PaddingLeft = UDim.new(0, compact and 4 or 8),
            PaddingRight = UDim.new(0, compact and 4 or 8),
            PaddingBottom = UDim.new(0, compact and 4 or 8),
        }),
    })
    content.Parent = container

    create("TextLabel", {
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 16 or 20) or (compact and 12 or 16)),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
    }).Parent = content

    local Section = setmetatable({
        _page = content,
        _touch = touch,
        _window = self._window,
        _screenGui = self._screenGui,
    }, { __index = Library.TabMethods })

    return Library:_wrapElement(container, Section)
end

-- ============================================================
-- LABEL
-- ============================================================

function TM:CreateLabel(text)
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local label = create("TextLabel", {
        Text = text,
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 24) or (compact and 14 or 18)),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    label.Parent = self._page
    return label
end

-- ============================================================
-- BUTTON
-- ============================================================

function TM:CreateButton(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local callback = config.Callback or function() end
    local soundId = config.Sound
    local haptic = config.Haptic

    local btn = create("TextButton", {
        Text = "",
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        AutoButtonColor = false,
    }, { corner(12), stroke() })
    btn.Parent = self._page
    setSearchMeta(btn, config, "Button")

    local label = create("TextLabel", {
        Text = config.Name or "Button",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })
    label.Parent = btn

    btn.MouseButton1Click:Connect(function()
        ripple(btn, Theme.Accent)
        tween(btn, { BackgroundColor3 = Theme.Accent }, 0.1)
        task.delay(0.1, function()
            tween(btn, { BackgroundColor3 = Theme.Element }, 0.1)
        end)

        if soundId then Library:PlaySound(soundId) end
        if haptic then Library:PlayHaptic("short") end

        local ok, err = pcall(callback)
        if not ok then warn("[MobileUILib] Button callback error: " .. tostring(err)) end
    end)

    return Library:_wrapElement(btn)
end

-- ============================================================
-- DIVIDER
-- ============================================================

function TM:CreateDivider(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, config.Name and (touch and (compact and 18 or 24) or (compact and 14 or 20)) or (touch and (compact and 6 or 10) or (compact and 4 or 8))),
        BackgroundTransparency = 1,
    })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Divider")

    if config.Name then
        create("TextLabel", {
            Text = config.Name,
            Font = Enum.Font.GothamBold,
            TextSize = touch and (compact and 10 or 12) or (compact and 8 or 10),
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
            TextXAlignment = Enum.TextXAlignment.Left,
        }).Parent = holder
    end

    local line = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
    })
    line.Parent = holder

    return holder
end

-- ============================================================
-- CARD
-- ============================================================

function TM:CreateCard(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(14), stroke() })
    card.Parent = self._page
    setSearchMeta(card, config, "Card")

    -- Same reasoning as CreateSection: content lives in its own inner
    -- wrapper so `card` (the textured/colored surface) has no UIListLayout
    -- as a direct child, keeping it eligible for WindowTexture.
    local content = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, compact and 4 or 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 6 or 10),
            PaddingLeft = UDim.new(0, compact and 6 or 10),
            PaddingRight = UDim.new(0, compact and 6 or 10),
            PaddingBottom = UDim.new(0, compact and 6 or 10),
        }),
    })
    content.Parent = card

    if config.Title then
        create("TextLabel", {
            Text = config.Title,
            Font = Enum.Font.GothamBold,
            TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 22) or (compact and 14 or 18)),
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 0,
        }).Parent = content
    end

    if config.Subtitle then
        create("TextLabel", {
            Text = config.Subtitle,
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }).Parent = content
    end

    local Card = setmetatable({
        _page = content,
        _touch = touch,
        _window = self._window,
        _screenGui = self._screenGui,
    }, { __index = Library.TabMethods })

    return Card
end

-- ============================================================
-- PARAGRAPH
-- ============================================================

function TM:CreateParagraph(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        corner(12),
        stroke(),
        create("UIListLayout", {
            Padding = UDim.new(0, compact and 2 or 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 6 or 10),
            PaddingLeft = UDim.new(0, compact and 8 or 12),
            PaddingRight = UDim.new(0, compact and 8 or 12),
            PaddingBottom = UDim.new(0, compact and 6 or 10),
        }),
    })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Paragraph")

    if config.Title then
        create("TextLabel", {
            Text = config.Title,
            Font = Enum.Font.GothamBold,
            TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, touch and (compact and 16 or 20) or (compact and 12 or 16)),
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 0,
        }).Parent = holder
    end

    local body = create("TextLabel", {
        Text = config.Text or config.Content or "",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 1,
    })
    body.Parent = holder

    return {
        Set = function(_, text) body.Text = text end,
        Get = function() return body.Text end,
    }
end

-- ============================================================
-- IMAGE
-- ============================================================

function TM:CreateImage(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local function normalizeAsset(id)
        if type(id) == "number" then return "rbxassetid://" .. tostring(id) end
        if type(id) == "string" and id ~= "" and not id:match("^rbxassetid://") and not id:match("^https?://") then
            return "rbxassetid://" .. id
        end
        return id
    end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, config.Height or (touch and (compact and 120 or 160) or (compact and 100 or 140))),
        BackgroundColor3 = Theme.Element,
        ClipsDescendants = true,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Image")

    local img = create("ImageLabel", {
        Image = normalizeAsset(config.Image or config.AssetId or config.Id) or "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ScaleType = config.ScaleType or Enum.ScaleType.Crop,
    })
    img.Parent = holder
    img:SetAttribute("MUI_NoTheme", true)

    if config.Name then
        create("TextLabel", {
            Text = config.Name,
            Font = Enum.Font.GothamMedium,
            TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.35,
            Size = UDim2.new(1, 0, 0, touch and (compact and 20 or 26) or (compact and 16 or 22)),
            Position = UDim2.new(0, 0, 1, touch and (compact and -20 or -26) or (compact and -16 or -22)),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, {
            create("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
        }).Parent = holder
    end

    return {
        Set = function(_, newAsset) img.Image = normalizeAsset(newAsset) or "" end,
        Get = function() return img.Image end,
    }
end

-- ============================================================
-- PROGRESS BAR
-- ============================================================

function TM:CreateProgressBar(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local min = config.Min or 0
    local max = config.Max or 100
    local value = math.clamp(config.Default or min, min, max)

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 48) or (compact and 30 or 38)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Progress Bar")

    create("TextLabel", {
        Text = config.Name or "Progress",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
        Position = UDim2.new(0, 10, 0, compact and 2 or 6),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local percentLabel = create("TextLabel", {
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35, -10, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
        Position = UDim2.new(0.65, 0, 0, compact and 2 or 6),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    percentLabel.Parent = holder

    local track = create("Frame", {
        Size = UDim2.new(1, -20, 0, touch and (compact and 6 or 10) or (compact and 4 or 8)),
        Position = UDim2.new(0, 10, 1, touch and (compact and -12 or -16) or (compact and -10 or -14)),
        BackgroundColor3 = Color3.fromRGB(55, 55, 62),
    }, { corner(8) })
    track.Parent = holder

    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
    }, { corner(8) })
    fill.Parent = track
    fill:SetAttribute("MUI_AccentSurface", true) -- eligible for a Skin's AccentTexture; always accent-colored
    Library:_applyAccentOverlay(fill, true)

    local function render(v, animate)
        v = math.clamp(v, min, max)
        local relative = (max > min) and ((v - min) / (max - min)) or 0
        percentLabel.Text = math.floor(relative * 100 + 0.5) .. "%"
        if animate then
            tween(fill, { Size = UDim2.new(relative, 0, 1, 0) }, 0.25)
        else
            fill.Size = UDim2.new(relative, 0, 1, 0)
        end
        return v
    end
    value = render(value, false)

    local handle = {
        Set = function(_, v)
            value = render(v, true)
            if config.Flag then Library:SetFlag(config.Flag, value) end
        end,
        Get = function() return value end,
    }
    if config.Flag then
        Library:SetFlag(config.Flag, value)
        Library.FlagElements[config.Flag] = handle
    end
    return handle
end

-- ============================================================
-- METER
-- ============================================================

function TM:CreateMeter(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local min = config.Min or 0
    local max = config.Max or 100
    local value = math.clamp(config.Default or min, min, max)
    local color = config.Color or Theme.Accent
    local animated = config.Animated ~= false

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 48) or (compact and 30 or 38)),
        BackgroundColor3 = Theme.Element,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Meter")

    create("TextLabel", {
        Text = config.Name or "Meter",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
        Position = UDim2.new(0, 10, 0, compact and 2 or 6),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local valueLabel = create("TextLabel", {
        Text = tostring(value),
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35, -10, 0, touch and (compact and 14 or 18) or (compact and 10 or 14)),
        Position = UDim2.new(0.65, 0, 0, compact and 2 or 6),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    valueLabel.Parent = holder

    local track = create("Frame", {
        Size = UDim2.new(1, -20, 0, touch and (compact and 6 or 10) or (compact and 4 or 8)),
        Position = UDim2.new(0, 10, 1, touch and (compact and -12 or -16) or (compact and -10 or -14)),
        BackgroundColor3 = Color3.fromRGB(55, 55, 62),
    }, { corner(8) })
    track.Parent = holder

    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = color,
    }, { corner(8) })
    fill.Parent = track
    fill:SetAttribute("MUI_AccentSurface", true) -- eligible for a Skin's AccentTexture whenever its color happens to equal Theme.Accent
    Library:_applyAccentOverlay(fill, color == Theme.Accent)

    local function render(v)
        v = math.clamp(v, min, max)
        local relative = (max > min) and ((v - min) / (max - min)) or 0
        valueLabel.Text = tostring(v)
        if animated then
            tween(fill, { Size = UDim2.new(relative, 0, 1, 0) }, 0.3)
        else
            fill.Size = UDim2.new(relative, 0, 1, 0)
        end
        return v
    end
    value = render(value)

    local handle = {
        Set = function(_, v)
            value = render(v)
            if config.Flag then Library:SetFlag(config.Flag, value) end
        end,
        Get = function() return value end,
        SetColor = function(_, newColor)
            color = newColor
            fill.BackgroundColor3 = color
            Library:_applyAccentOverlay(fill, color == Theme.Accent)
        end,
    }
    if config.Flag then
        Library:SetFlag(config.Flag, value)
        Library.FlagElements[config.Flag] = handle
    end
    return handle
end

-- ============================================================
-- TIMER
-- ============================================================

function TM:CreateTimer(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local duration = config.Duration or 60
    local remaining = duration
    local running = false
    local paused = false

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 60 or 80) or (compact and 44 or 60)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Timer")

    local timeDisplay = create("TextLabel", {
        Text = string.format("%02d:%02d", remaining // 60, remaining % 60),
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 26 or 32) or (compact and 20 or 26),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 36) or (compact and 20 or 28)),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    timeDisplay.Parent = holder

    local btnRow = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 34) or (compact and 20 or 26)),
        Position = UDim2.new(0, 0, 1, touch and (compact and -28 or -34) or (compact and -20 or -26)),
        BackgroundTransparency = 1,
    }, {
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        }),
    })
    btnRow.Parent = holder

    local function updateDisplay()
        timeDisplay.Text = string.format("%02d:%02d", remaining // 60, remaining % 60)
    end

    local function resetTimer()
        running = false
        paused = false
        remaining = duration
        updateDisplay()
        if config.Callback then
            pcall(config.Callback, "reset", remaining)
        end
    end

    local function togglePause()
        if not running then
            running = true
            paused = false
            if config.Callback then
                pcall(config.Callback, "start", remaining)
            end
        else
            paused = not paused
            if config.Callback then
                pcall(config.Callback, paused and "pause" or "resume", remaining)
            end
        end
    end

    local startBtn = create("TextButton", {
        Text = "▶",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.ElementHover,
        Size = UDim2.new(0, touch and (compact and 50 or 60) or (compact and 40 or 50), 1, 0),
    }, { corner(8) })
    startBtn.Parent = btnRow

    local resetBtn = create("TextButton", {
        Text = "⟳",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 14 or 16) or (compact and 12 or 14),
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.ElementHover,
        Size = UDim2.new(0, touch and (compact and 50 or 60) or (compact and 40 or 50), 1, 0),
    }, { corner(8) })
    resetBtn.Parent = btnRow

    startBtn.MouseButton1Click:Connect(togglePause)
    resetBtn.MouseButton1Click:Connect(resetTimer)

    local connection
    local function startTimerLoop()
        if connection then connection:Disconnect() end
        connection = RunService.Heartbeat:Connect(function(delta)
            if running and not paused and remaining > 0 then
                remaining = remaining - delta
                if remaining <= 0 then
                    remaining = 0
                    running = false
                    if config.Callback then
                        pcall(config.Callback, "complete", remaining)
                    end
                end
                updateDisplay()
                startBtn.Text = paused and "▶" or "⏸"
            end
        end)
    end
    startTimerLoop()

    local handle = {
        Set = function(_, newDuration)
            duration = newDuration
            remaining = newDuration
            resetTimer()
        end,
        Get = function() return remaining end,
        Reset = resetTimer,
        Start = function()
            running = true
            paused = false
            startBtn.Text = "⏸"
        end,
        Pause = function()
            paused = true
            startBtn.Text = "▶"
        end,
        Resume = function()
            paused = false
            startBtn.Text = "⏸"
        end,
        Destroy = function()
            if connection then connection:Disconnect() end
            if holder then holder:Destroy() end
        end,
    }

    holder.AncestryChanged:Connect(function(_, parent)
        if not parent and connection then
            connection:Disconnect()
        end
    end)

    return Library:_wrapElement(holder, handle)
end

-- ============================================================
-- CHECKLIST
-- ============================================================

function TM:CreateChecklist(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local items = config.Items or {}

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Checklist")

    create("TextLabel", {
        Text = config.Name or "Checklist",
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

    local checkStates = {}
    local checkboxes = {}

    local function updateProgress()
        local total = #items
        local done = 0
        for _, state in pairs(checkStates) do
            if state then done = done + 1 end
        end
        if config.Callback then
            pcall(config.Callback, done, total, checkStates)
        end
    end

    for i, item in ipairs(items) do
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, touch and (compact and 22 or 28) or (compact and 18 or 22)),
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

        local checkBtn = create("TextButton", {
            Text = "□",
            Font = Enum.Font.GothamBold,
            TextSize = touch and (compact and 16 or 18) or (compact and 14 or 16),
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, touch and (compact and 20 or 24) or (compact and 16 or 20), 1, 0),
        })
        checkBtn.Parent = row

        local label = create("TextLabel", {
            Text = item,
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        label.Parent = row

        checkStates[i] = false
        checkboxes[i] = checkBtn

        checkBtn.MouseButton1Click:Connect(function()
            checkStates[i] = not checkStates[i]
            checkBtn.Text = checkStates[i] and "☑" or "□"
            checkBtn.TextColor3 = checkStates[i] and Theme.Accent or Theme.SubText
            updateProgress()
        end)
    end

    local handle = {
        Set = function(_, states)
            for i, state in ipairs(states) do
                if checkboxes[i] then
                    checkStates[i] = state
                    checkboxes[i].Text = state and "☑" or "□"
                    checkboxes[i].TextColor3 = state and Theme.Accent or Theme.SubText
                end
            end
            updateProgress()
        end,
        Get = function() return checkStates end,
        Toggle = function(index)
            if checkboxes[index] then
                checkStates[index] = not checkStates[index]
                checkboxes[index].Text = checkStates[index] and "☑" or "□"
                checkboxes[index].TextColor3 = checkStates[index] and Theme.Accent or Theme.SubText
                updateProgress()
            end
        end,
        Reset = function()
            for i in pairs(checkStates) do
                checkStates[i] = false
                checkboxes[i].Text = "□"
                checkboxes[i].TextColor3 = Theme.SubText
            end
            updateProgress()
        end,
    }

    return Library:_wrapElement(holder, handle)
end
end
