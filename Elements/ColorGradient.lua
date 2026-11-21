--[[
    CreateColorGradient — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 5187-5340. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/ColorGradient.lua
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
-- COLOR GRADIENT
-- ============================================================

function TM:CreateColorGradient(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local stops = config.Stops or { Color3.fromRGB(255, 196, 48), Color3.fromRGB(255, 90, 90) }
    if #stops < 2 then
        stops = { stops[1] or Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0) }
    end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 32 or 40) or (compact and 24 or 30)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        corner(12),
        stroke(),
        create("UIListLayout", { Padding = UDim.new(0, compact and 4 or 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 6 or 10),
            PaddingLeft = UDim.new(0, compact and 6 or 10),
            PaddingRight = UDim.new(0, compact and 6 or 10),
            PaddingBottom = UDim.new(0, compact and 6 or 10),
        }),
    })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Color Gradient")

    -- Preset button
    local presetRow = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 34) or (compact and 20 or 26)),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
    })
    presetRow.Parent = holder

    local presets = {
        ["Rainbow"] = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,255,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,255,255), Color3.fromRGB(255,0,255)},
        ["Sunset"] = {Color3.fromRGB(255,100,0), Color3.fromRGB(255,200,0), Color3.fromRGB(255,255,0)},
        ["Ocean"] = {Color3.fromRGB(0,100,200), Color3.fromRGB(0,200,255), Color3.fromRGB(100,255,255)},
        ["Forest"] = {Color3.fromRGB(0,100,0), Color3.fromRGB(0,200,50), Color3.fromRGB(50,255,100)},
        ["Fire"] = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,100,0), Color3.fromRGB(255,200,0)},
        ["Ice"] = {Color3.fromRGB(100,200,255), Color3.fromRGB(150,220,255), Color3.fromRGB(200,240,255)},
    }

    local presetDropdown = create("TextButton", {
        Text = "Presets ▼",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 11 or 12) or (compact and 9 or 10),
        TextColor3 = Theme.SubText,
        BackgroundColor3 = Theme.ElementHover,
        Size = UDim2.new(0, 80, 1, 0),
    }, { corner(6) })
    presetDropdown.Parent = presetRow

    local GradientPage = setmetatable({
        _page = holder,
        _touch = touch,
        _window = self._window,
        _screenGui = self._screenGui,
    }, { __index = Library.TabMethods })

    presetDropdown.MouseButton1Click:Connect(function()
        local presetsList = {}
        for name in pairs(presets) do table.insert(presetsList, name) end
        local dropdown = GradientPage:CreateDropdown({
            Name = "Select Preset",
            Options = presetsList,
            Callback = function(selected)
                local colors = presets[selected]
                if colors then
                    handle:Set(colors)
                end
            end
        })
    end)

    create("TextLabel", {
        Text = config.Name or "Gradient",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -90, 0, touch and (compact and 16 or 20) or (compact and 12 or 16)),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
    }).Parent = holder

    local preview = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 24 or 32) or (compact and 18 or 26)),
        BackgroundColor3 = Color3.new(1, 1, 1),
        LayoutOrder = 1,
    }, { corner(8), stroke() })
    preview.Parent = holder

    local function buildSequence(colors)
        if #colors < 2 then return ColorSequence.new(colors[1] or Color3.new(1, 1, 1)) end
        local keypoints = {}
        for i, c in ipairs(colors) do
            table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
        end
        return ColorSequence.new(keypoints)
    end

    local previewGradient = create("UIGradient", { Color = buildSequence(stops) })
    previewGradient.Parent = preview

    local pickers = {}

    local function currentColors()
        local colors = {}
        for _, picker in ipairs(pickers) do table.insert(colors, picker:Get()) end
        return colors
    end

    for i, startColor in ipairs(stops) do
        local picker = GradientPage:CreateColorPicker({
            Name = "Stop " .. i,
            Default = startColor,
            Callback = function()
                local colors = currentColors()
                previewGradient.Color = buildSequence(colors)
                if config.Flag then Library:SetFlag(config.Flag, colors) end
                if config.Callback then
                    local ok, err = pcall(config.Callback, buildSequence(colors), colors)
                    if not ok then warn("[MobileUILib] ColorGradient callback error: " .. tostring(err)) end
                end
            end,
        })
        table.insert(pickers, picker)
    end

    local handle = {
        Set = function(_, newStops)
            for i, picker in ipairs(pickers) do
                if newStops[i] then picker:Set(newStops[i]) end
            end
            local colors = currentColors()
            previewGradient.Color = buildSequence(colors)
            if config.Flag then Library:SetFlag(config.Flag, colors) end
        end,
        Get = function() return currentColors() end,
        GetSequence = function() return buildSequence(currentColors()) end,
    }
    if config.Flag then
        Library:SetFlag(config.Flag, currentColors())
        Library.FlagElements[config.Flag] = handle
    end
    return handle
end
end
