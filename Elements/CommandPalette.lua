--[[
    CornUi v2.0 — Elements/CommandPalette.lua
    Cornelius: the command palette. v1.x shipped a broken version of this
    feature; this is the from-scratch rewrite.

    Call Window:CreateCommandPalette() once, then:
      - tap the "• • •" chip in the title bar,
      - press Ctrl+K (desktop),
      - or run the "Open Cornelius" command.

    Type to filter every registered command (toggles, tabs, configs, themes,
    plugins — anything that called Commands.Register), tap a result or press
    Enter to run it, Escape to close.

    Perf contract: rows are pooled (max 10, created once on first open and
    reused for every keystroke — zero instance churn while typing), the
    whole UI is only built when the hub opts in, and pop/fade tweens are
    skipped on Low quality.
]]

return function(Modules)

    local Render = Modules.Render
    local Commands = Modules.Commands
    local Theme = Modules.Theme
    local Window = Modules.Window.Window

    assert(Commands, "CommandPalette requires Systems/Commands.lua to be loaded first")

    local MAX_ROWS = 10
    local RESULT_HEIGHT = 28

    function Window:CreateCommandPalette(props)
        props = props or {}
        if self._palette then return self._palette end

        local TweenService = game:GetService("TweenService")
        local UserInputService = game:GetService("UserInputService")

        local isOpen = false
        local rows = {}
        local emptyLabel

        ------------------------------------------------------------
        -- UI (built once, on first CreateCommandPalette call)
        ------------------------------------------------------------

        local overlay = Render.New("Frame", {
            Name = "CorneliusOverlay",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            Theme = false,
            Visible = false,
            ZIndex = 100,
            Parent = self.ScreenGui,
        })

        -- Click anywhere outside the panel closes the palette.
        local overlayButton = Instance.new("TextButton")
        overlayButton.BackgroundTransparency = 1
        overlayButton.Text = ""
        overlayButton.Size = UDim2.fromScale(1, 1)
        overlayButton.ZIndex = 100
        overlayButton.Parent = overlay
        overlayButton.MouseButton1Click:Connect(function()
            if isOpen then self:CloseCommandPalette() end
        end)

        local panel = Render.New("Frame", {
            Name = "CorneliusPanel",
            Size = UDim2.fromOffset(props.Width or 400, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.new(0.5, 0, 0, props.TopOffset or 110),
            AnchorPoint = Vector2.new(0.5, 0),
            CornerRadius = 10,
            Theme = "Window",
            Visible = false,
            ZIndex = 101,
            Parent = overlay,
        })

        local panelLayout = Instance.new("UIListLayout")
        panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
        panelLayout.Padding = UDim.new(0, 6)
        panelLayout.Parent = panel

        local panelPadding = Instance.new("UIPadding")
        panelPadding.PaddingTop = UDim.new(0, 8)
        panelPadding.PaddingBottom = UDim.new(0, 8)
        panelPadding.PaddingLeft = UDim.new(0, 8)
        panelPadding.PaddingRight = UDim.new(0, 8)
        panelPadding.Parent = panel

        local panelPop = Instance.new("UIScale")
        panelPop.Scale = 1
        panelPop.Parent = panel

        -- Search row
        local searchRow = Render.New("Frame", {
            Name = "SearchRow",
            Size = UDim2.new(1, -16, 0, 30),
            CornerRadius = 6,
            Theme = "Card",
            LayoutOrder = 0,
            ZIndex = 102,
            Parent = panel,
        })

        local searchBox = Instance.new("TextBox")
        searchBox.BackgroundTransparency = 1
        searchBox.Size = UDim2.new(1, -16, 1, 0)
        searchBox.Position = UDim2.fromOffset(8, 0)
        searchBox.PlaceholderText = props.Placeholder or "Type a command..."
        searchBox.Text = ""
        searchBox.TextSize = 14
        searchBox.ClearTextOnFocus = false
        searchBox.TextXAlignment = Enum.TextXAlignment.Left
        searchBox.ZIndex = 103
        searchBox.Parent = searchRow
        Modules.Theme.Apply(searchBox, "Text", { Theme = "Default" })

        -- Results (pooled rows inside a capped scroll)
        local resultList = Render.New("Scroll", {
            Name = "Results",
            Size = UDim2.new(1, -16, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            CornerRadius = 6,
            ScrollBarThickness = 2,
            Theme = false,
            LayoutOrder = 1,
            ZIndex = 102,
            Visible = false,
            Parent = panel,
        })

        local resultConstraint = Instance.new("UISizeConstraint")
        resultConstraint.MaxSize = Vector2.new(math.huge, props.MaxListHeight or 220)
        resultConstraint.Parent = resultList

        local resultLayout = Instance.new("UIListLayout")
        resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
        resultLayout.Padding = UDim.new(0, 2)
        resultLayout.Parent = resultList

        emptyLabel = Render.New("Text", {
            Name = "EmptyState",
            Text = "No matching commands",
            TextSize = 13,
            XAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.new(1, -16, 0, 24),
            Theme = "Muted",
            LayoutOrder = 2,
            ZIndex = 102,
            Visible = false,
            Parent = panel,
        })

        local function buildRow(index)
            local rowFrame = Render.New("Frame", {
                Name = "Command_" .. index,
                Size = UDim2.new(1, 0, 0, RESULT_HEIGHT),
                CornerRadius = 6,
                BackgroundTransparency = 1,
                Theme = false,
                LayoutOrder = index,
                ZIndex = 103,
                Parent = resultList,
            })

            local title = Render.New("Text", {
                Text = "",
                TextSize = 14,
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                Theme = "Default",
                ZIndex = 104,
                Parent = rowFrame,
            })

            local hint = Render.New("Text", {
                Text = "",
                TextSize = 12,
                XAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(0, 80, 1, 0),
                Position = UDim2.new(1, -88, 0, 0),
                Theme = "Muted",
                ZIndex = 104,
                Parent = rowFrame,
            })

            local btn = Instance.new("TextButton")
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.Size = UDim2.fromScale(1, 1)
            btn.ZIndex = 105
            btn.Parent = rowFrame

            local row = { Frame = rowFrame, Title = title, Hint = hint, Entry = nil }
            btn.MouseButton1Click:Connect(function()
                if row.Entry then
                    self:CloseCommandPalette()
                    Commands.Run(row.Entry.Id)
                end
            end)
            -- Subtle hover affordance (desktop); instant, no tween.
            btn.MouseEnter:Connect(function()
                rowFrame.BackgroundTransparency = 0.85
            end)
            btn.MouseLeave:Connect(function()
                rowFrame.BackgroundTransparency = 1
            end)
            return row
        end

        local function resolveHint(entry)
            if type(entry.Hint) == "function" then
                local ok, value = pcall(entry.Hint)
                return ok and tostring(value) or ""
            end
            return entry.Hint and tostring(entry.Hint) or ""
        end

        local function refresh(query)
            local results = Commands.Search(query, MAX_ROWS)

            resultList.Visible = (#results > 0)
            emptyLabel.Visible = (#results == 0)

            while #rows < math.min(#results, MAX_ROWS) do
                table.insert(rows, buildRow(#rows + 1))
            end

            for i, row in ipairs(rows) do
                local entry = results[i]
                row.Frame.Visible = entry ~= nil
                row.Entry = entry
                if entry then
                    row.Title.Text = entry.Title
                    row.Hint.Text = resolveHint(entry)
                end
            end
        end

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            if isOpen then
                refresh(searchBox.Text)
            end
        end)

        ------------------------------------------------------------
        -- Open / close
        ------------------------------------------------------------

        function self:OpenCommandPalette()
            if isOpen then return end
            isOpen = true

            searchBox.Text = ""
            refresh("")

            overlay.Visible = true
            panel.Visible = true
            overlay.BackgroundTransparency = 1

            if Render.Motion() then
                panelPop.Scale = 0.97
                TweenService:Create(overlay, TweenInfo.new(0.12), { BackgroundTransparency = 0.45 }):Play()
                TweenService:Create(panelPop, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            else
                overlay.BackgroundTransparency = 0.45
            end

            task.defer(function()
                searchBox:CaptureFocus()
            end)
        end

        function self:CloseCommandPalette()
            if not isOpen then return end
            isOpen = false

            searchBox:ReleaseFocus()

            if Render.Motion() then
                local fade = TweenService:Create(overlay, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
                fade:Play()
                fade.Completed:Wait()
            end

            if not isOpen then -- re-opened during the fade: leave it up
                overlay.Visible = false
                panel.Visible = false
            end
        end

        function self.IsCommandPaletteOpen()
            return isOpen
        end

        ------------------------------------------------------------
        -- Keyboard: Enter runs the first result, Escape closes, Ctrl+K toggles
        ------------------------------------------------------------

        local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

            if not isOpen then
                if input.KeyCode == Enum.KeyCode.K
                    and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
                    self:OpenCommandPalette()
                end
                return
            end

            if input.KeyCode == Enum.KeyCode.Escape then
                self:CloseCommandPalette()
            elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
                for _, row in ipairs(rows) do
                    if row.Entry and row.Frame.Visible then
                        self:CloseCommandPalette()
                        Commands.Run(row.Entry.Id)
                        break
                    end
                end
            end
        end)

        self:OnCleanup(function()
            inputConn:Disconnect()
        end)

        ------------------------------------------------------------
        -- Title-bar chip ("• • •") + command registration
        ------------------------------------------------------------

        local chip = Render.New("Button", {
            Name = "CorneliusChip",
            Text = "\u{2022} \u{2022} \u{2022}",
            TextSize = 11,
            Size = UDim2.fromOffset(34, 24),
            Position = UDim2.new(1, -42, 0, 5),
            CornerRadius = 8,
            Theme = "Card",
            Parent = self.Root,
        })
        chip.MouseButton1Click:Connect(function()
            if isOpen then
                self:CloseCommandPalette()
            else
                self:OpenCommandPalette()
            end
        end)

        Commands.Register({
            Id = "CornUi.W" .. self.Id .. ".OpenCornelius",
            Title = "Open Cornelius (command palette)",
            Keywords = "cornelius command palette search run",
            Owner = self,
            Run = function()
                self:OpenCommandPalette()
            end,
        })

        self._palette = {
            Open = function() self:OpenCommandPalette() end,
            Close = function() self:CloseCommandPalette() end,
            IsOpen = function() return isOpen end,
        }
        return self._palette
    end

    return { MAX_ROWS = MAX_ROWS }
end
