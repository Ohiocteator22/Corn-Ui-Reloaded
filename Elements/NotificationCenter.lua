--[[
    CreateNotificationCenter — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 5470-5625. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/NotificationCenter.lua
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
-- NOTIFICATION CENTER
-- ============================================================

function TM:CreateNotificationCenter(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Notification Center")

    local headerRow = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 28 or 34) or (compact and 22 or 28)),
        BackgroundTransparency = 1,
    })
    headerRow.Parent = holder

    create("TextLabel", {
        Text = config.Name or "Notifications",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = headerRow

    local clearBtn = create("TextButton", {
        Text = "Clear",
        Font = Enum.Font.GothamMedium,
        TextSize = touch and (compact and 10 or 12) or (compact and 8 or 11),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 56, 1, 0),
        Position = UDim2.new(1, -60, 0, 0),
    })
    clearBtn.Parent = headerRow

    local list = create("Frame", {
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.new(0, 8, 0, touch and (compact and 30 or 36) or (compact and 24 or 30)),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, compact and 2 or 4), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingBottom = UDim.new(0, compact and 4 or 8) }),
    })
    list.Parent = holder

    local typeColors = {
        success = Color3.fromRGB(70, 200, 110),
        error = Color3.fromRGB(230, 75, 75),
        warning = Color3.fromRGB(255, 175, 45),
        info = Theme.Accent,
    }

    local emptyLabel = create("TextLabel", {
        Text = "No notifications yet",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local rowHeight = touch and (compact and 44 or 54) or (compact and 36 or 44)

    local function addRow(entry)
        if emptyLabel.Parent then emptyLabel.Parent = nil end

        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, rowHeight),
            BackgroundColor3 = Theme.ElementHover,
            LayoutOrder = -entry.Seq,
        }, {
            corner(8),
            create("UIPadding", {
                PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8),
                PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
            }),
        })
        row.Parent = list

        create("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            Position = UDim2.new(0, -8, 0, 0),
            BackgroundColor3 = typeColors[entry.Type] or Theme.Stroke,
            BorderSizePixel = 0,
        }, { corner(2) }).Parent = row

        create("TextLabel", {
            Text = entry.Title,
            Font = Enum.Font.GothamMedium,
            TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -56, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }).Parent = row

        create("TextLabel", {
            Text = entry.Content,
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 10 or 12) or (compact and 8 or 10),
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, touch and (compact and 14 or 18) or (compact and 11 or 15)),
            Size = UDim2.new(1, 0, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }).Parent = row

        create("TextLabel", {
            Text = os.date("%H:%M:%S", entry.Time),
            Font = Enum.Font.Gotham,
            TextSize = touch and (compact and 8 or 10) or (compact and 7 or 9),
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 54, 0, 12),
            Position = UDim2.new(1, -54, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        }).Parent = row
    end

    for _, entry in ipairs(Library.NotificationHistory) do
        addRow(entry)
    end
    if #Library.NotificationHistory == 0 then
        emptyLabel.Parent = list
    end

    local logConn = Library.NotificationLogged:Connect(addRow)

    clearBtn.MouseButton1Click:Connect(function()
        Library.NotificationHistory = {}
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        emptyLabel.Parent = list
    end)

    holder.AncestryChanged:Connect(function(_, parent)
        if not parent and logConn then logConn:Disconnect() end
    end)

    return holder
end
end
