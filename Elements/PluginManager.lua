--[[
    CreatePluginManager — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 5900-6057. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/PluginManager.lua
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
-- PLUGIN MANAGER
-- ============================================================

function TM:CreatePluginManager(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, touch and (compact and 38 or 46) or (compact and 28 or 34)),
        BackgroundColor3 = Theme.Element,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, { corner(12), stroke() })
    holder.Parent = self._page
    setSearchMeta(holder, config, "Plugin Manager")

    create("TextLabel", {
        Text = config.Name or "Plugins",
        Font = Enum.Font.GothamBold,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, touch and (compact and 24 or 30) or (compact and 18 or 24)),
        Position = UDim2.new(0, 10, 0, compact and 4 or 6),
        TextXAlignment = Enum.TextXAlignment.Left,
    }).Parent = holder

    local list = create("Frame", {
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.new(0, 8, 0, touch and (compact and 34 or 40) or (compact and 26 or 32)),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, compact and 4 or 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingBottom = UDim.new(0, compact and 4 or 8) }),
    })
    list.Parent = holder

    local emptyLabel = create("TextLabel", {
        Text = "No plugins loaded",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local rowHeight = touch and (compact and 52 or 62) or (compact and 42 or 50)

    local function smallBtn(parent, text, order)
        local b = create("TextButton", {
            Text = text,
            Font = Enum.Font.GothamMedium,
            TextSize = touch and (compact and 10 or 12) or (compact and 8 or 10),
            TextColor3 = Theme.Text,
            BackgroundColor3 = Theme.Element,
            Size = UDim2.new(0, touch and (compact and 60 or 70) or (compact and 50 or 58), 1, 0),
            LayoutOrder = order,
        }, { corner(6) })
        b.Parent = parent
        return b
    end

    local function rebuild()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local plugins = Library:ListPlugins()
        if #plugins == 0 then
            emptyLabel.Parent = list
            return
        end
        emptyLabel.Parent = nil

        for i, info in ipairs(plugins) do
            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, rowHeight),
                BackgroundColor3 = Theme.ElementHover,
                LayoutOrder = i,
            }, {
                corner(8),
                create("UIPadding", {
                    PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8),
                    PaddingTop = UDim.new(0, compact and 4 or 6), PaddingBottom = UDim.new(0, compact and 4 or 6),
                }),
            })
            row.Parent = list

            create("TextLabel", {
                Text = info.Name .. (info.Version and ("  v" .. tostring(info.Version)) or ""),
                Font = Enum.Font.GothamMedium,
                TextSize = touch and (compact and 11 or 13) or (compact and 9 or 11),
                TextColor3 = Theme.Text,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8, 0, touch and (compact and 12 or 16) or (compact and 10 or 14)),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }).Parent = row

            create("TextLabel", {
                Text = info.Enabled and "Enabled" or "Disabled",
                Font = Enum.Font.Gotham,
                TextSize = touch and (compact and 9 or 11) or (compact and 8 or 10),
                TextColor3 = info.Enabled and Color3.fromRGB(70, 200, 110) or Color3.fromRGB(230, 75, 75),
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, touch and (compact and 14 or 18) or (compact and 11 or 15)),
                Size = UDim2.new(1, -8, 0, touch and (compact and 10 or 14) or (compact and 8 or 12)),
                TextXAlignment = Enum.TextXAlignment.Left,
            }).Parent = row

            local btnRow = create("Frame", {
                Size = UDim2.new(1, 0, 0, touch and (compact and 20 or 26) or (compact and 14 or 20)),
                Position = UDim2.new(0, 0, 1, touch and (compact and -20 or -26) or (compact and -14 or -20)),
                BackgroundTransparency = 1,
            }, {
                create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, compact and 4 or 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
            })
            btnRow.Parent = row

            local toggleBtn = smallBtn(btnRow, info.Enabled and "Disable" or "Enable", 1)
            toggleBtn.MouseButton1Click:Connect(function()
                if info.Enabled then
                    Library:DisablePlugin(info.Name)
                else
                    Library:EnablePlugin(info.Name)
                end
            end)

            if info.Url then
                local reloadBtn = smallBtn(btnRow, "Reload", 2)
                reloadBtn.MouseButton1Click:Connect(function()
                    Library:ReloadPlugin(info.Name)
                end)
            end

            local unloadBtn = smallBtn(btnRow, "Unload", 3)
            unloadBtn.MouseButton1Click:Connect(function()
                Library:UnloadPlugin(info.Name)
            end)
        end
    end

    rebuild()
    local conn = Library.PluginRegistryChanged:Connect(rebuild)

    holder.AncestryChanged:Connect(function(_, parent)
        if not parent and conn then conn:Disconnect() end
    end)

    return holder
end
end
