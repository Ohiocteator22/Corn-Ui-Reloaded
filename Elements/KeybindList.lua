--[[
    CreateKeybindList — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 5342-5468. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/KeybindList.lua
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
-- KEYBIND LIST
-- ============================================================

function TM:CreateKeybindList(config)
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
        create("UIListLayout", { Padding = UDim.new(0, compact and 2 or 4), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 6 or 10),
            PaddingLeft = UDim.new(0, compact and 6 or 10),
            PaddingRight = UDim.new(0, compact and 6 or 10),
            PaddingBottom = UDim.new(0, compact and 6 or 10),
        }),
    })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Keybind List")

    create("TextLabel", {
        Text = config.Name or "Active Keybinds",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 15)),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
    }).Parent = holder

    local emptyLabel = create("TextLabel", {
        Text = "No keybinds registered",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, touch and (compact and 14 or 18) or (compact and 10 or 15)),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    local rowFrames = {}
    local rowLabels = {}

    local function keyText(descriptor)
        local ok, key = pcall(descriptor.Get)
        if not ok or not key or key == Enum.KeyCode.Unknown then return "Unbound" end
        return key.Name
    end

    local function addRow(descriptor)
        if emptyLabel.Parent then emptyLabel.Parent = nil end

        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, touch and (compact and 18 or 22) or (compact and 14 or 18)),
            BackgroundTransparency = 1,
        })
        row.Parent = holder

        create("TextLabel", {
            Text = descriptor.Name,
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.6, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
        }).Parent = row

        local keyLabel = create("TextLabel", {
            Text = keyText(descriptor),
            Font = Enum.Font.GothamBold,
            TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
            TextColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.4, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        keyLabel.Parent = row

        rowFrames[descriptor] = row
        rowLabels[descriptor] = keyLabel
    end

    local function removeRow(descriptor)
        local row = rowFrames[descriptor]
        if row then row:Destroy() end
        rowFrames[descriptor] = nil
        rowLabels[descriptor] = nil
        if next(rowFrames) == nil then
            emptyLabel.Parent = holder
        end
    end

    local function rebuildAll()
        for descriptor in pairs(rowFrames) do removeRow(descriptor) end
        for _, descriptor in ipairs(Library.Keybinds) do addRow(descriptor) end
        if #Library.Keybinds == 0 then emptyLabel.Parent = holder end
    end

    rebuildAll()

    local registeredConn = Library.KeybindRegistered:Connect(addRow)
    local changedConn = Library.KeybindChanged:Connect(function(descriptor)
        local keyLabel = rowLabels[descriptor]
        if keyLabel then keyLabel.Text = keyText(descriptor) end
    end)
    local unregisteredConn = Library.KeybindUnregistered:Connect(removeRow)

    holder.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if registeredConn then registeredConn:Disconnect() end
            if changedConn then changedConn:Disconnect() end
            if unregisteredConn then unregisteredConn:Disconnect() end
        end
    end)

    return Library:_wrapElement(holder, { Refresh = function(_) rebuildAll() end })
end
end
