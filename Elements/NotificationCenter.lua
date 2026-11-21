--[[
    CornUi v2.0 — Elements/NotificationCenter.lua
    Unlike other elements, this isn't attached to a Section — it's a
    screen-level overlay. Call Window:CreateNotificationCenter() once per
    window, then Window:Notify({...}) to push toasts.

    Window:Notify({
        Title = "Saved",
        Text = "Config saved successfully.",
        Duration = 4,        -- seconds, default 4
        Type = "Success",    -- "Default" | "Success" | "Warning" | "Error"
    })
]]

return function(Modules)

    local Render = Modules.Render
    local Window = Modules.Window.Window
    local TweenService = game:GetService("TweenService")

    local TYPE_COLORS = {
        Default = Color3.fromRGB(70, 70, 70),
        Success = Color3.fromRGB(80, 170, 120),
        Warning = Color3.fromRGB(210, 170, 60),
        Error   = Color3.fromRGB(200, 70, 70),
    }

    local MAX_VISIBLE_TOASTS = 5

    function Window:CreateNotificationCenter(props)
        props = props or {}

        self.NotifHolder = Render.New("Frame", {
            Name = "NotificationCenter",
            Size = UDim2.new(0, 260, 1, -16),
            Position = UDim2.new(1, -268, 0, 8),
            Theme = false,
            Parent = self.ScreenGui,
        })
        self.NotifHolder.BackgroundTransparency = 1
        self.NotifHolder.ClipsDescendants = false

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.Parent = self.NotifHolder
    end

    function Window:Notify(toast)
        assert(self.NotifHolder, "Notify: call Window:CreateNotificationCenter() first")
        toast = toast or {}

        local accent = TYPE_COLORS[toast.Type] or TYPE_COLORS.Default
        local duration = toast.Duration or 4
        local fadeables = {} -- text instances faded in/out with the card

        local card = Render.New("Frame", {
            Name = "Toast",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            CornerRadius = 6,
            Theme = "Card",
            Parent = self.NotifHolder,
        })
        card.BackgroundTransparency = 1 -- fades in via tween below

        -- Cap the stack: the oldest toast dies when we exceed the limit —
        -- keeps the holder bounded and spares weak devices the layout churn.
        local visibleToasts = {}
        for _, child in ipairs(self.NotifHolder:GetChildren()) do
            if child:IsA("GuiObject") and child ~= card then
                table.insert(visibleToasts, child)
            end
        end
        while #visibleToasts >= MAX_VISIBLE_TOASTS do
            local oldest = table.remove(visibleToasts, 1)
            oldest:Destroy()
        end

        local cardPop = Instance.new("UIScale")
        cardPop.Scale = 1
        cardPop.Parent = card

        local accentBar = Render.New("Frame", {
            Name = "Accent",
            Size = UDim2.new(0, 3, 1, 0),
            Color = accent,
            Theme = false,
            Parent = card,
        })

        local textHolder = Render.New("Frame", {
            Name = "TextHolder",
            Size = UDim2.new(1, -12, 0, 0),
            Position = UDim2.fromOffset(10, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Theme = false,
            Parent = card,
        })
        textHolder.BackgroundTransparency = 1

        local textLayout = Instance.new("UIListLayout")
        textLayout.SortOrder = Enum.SortOrder.LayoutOrder
        textLayout.Padding = UDim.new(0, 2)
        textLayout.Parent = textHolder

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.Parent = textHolder

        if toast.Title then
            local titleText = Render.New("Text", {
                Text = toast.Title,
                TextSize = 14,
                Theme = "Default",
                Size = UDim2.new(1, 0, 0, 16),
                Parent = textHolder,
            })
            titleText.TextTransparency = 1
            table.insert(fadeables, titleText)
        end

        if toast.Text then
            local bodyText = Render.New("Text", {
                Text = toast.Text,
                TextSize = 12,
                TextWrapped = true,
                Theme = "Muted",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = textHolder,
            })
            bodyText.TextTransparency = 1
            table.insert(fadeables, bodyText)
        end

        -- Action buttons: up to two thumb-sized buttons under the text
        -- (e.g. "Copy config" / "Ignore"). Clicking runs the callback and
        -- dismisses the toast immediately.
        if type(toast.Buttons) == "table" and #toast.Buttons > 0 then
            local buttonRow = Render.New("Frame", {
                Name = "ToastButtons",
                Size = UDim2.new(1, 0, 0, 24),
                Theme = false,
                Parent = textHolder,
            })
            buttonRow.BackgroundTransparency = 1

            local rowLayout = Instance.new("UIListLayout")
            rowLayout.FillDirection = Enum.FillDirection.Horizontal
            rowLayout.Padding = UDim.new(0, 6)
            rowLayout.Parent = buttonRow

            local function dismissToast()
                if not card.Parent then return end
                local tween = TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
                TweenService:Create(accentBar, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                for _, textInst in ipairs(fadeables) do
                    TweenService:Create(textInst, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
                end
                tween:Play()
                task.spawn(function()
                    tween.Completed:Wait()
                    card:Destroy()
                end)
            end

            for i, action in ipairs(toast.Buttons) do
                if i > 2 then break end
                local labelText = action.Text or ("Action " .. i)
                local actionBtn = Render.New("Button", {
                    Name = "ToastAction_" .. labelText,
                    Text = labelText,
                    TextSize = 12,
                    Size = UDim2.fromOffset(math.max(48, 14 + #labelText * 6), 24),
                    CornerRadius = 6,
                    Theme = "Card",
                    Parent = buttonRow,
                })
                actionBtn.MouseButton1Click:Connect(function()
                    if action.Callback then
                        task.spawn(action.Callback)
                    end
                    dismissToast()
                end)
            end
        end

        accentBar.BackgroundTransparency = 1

        -- Fade everything in together (card background, accent bar, text) —
        -- fading only the card left the text floating on nothing during the
        -- animation. A tiny scale pop rides along on High quality.
        local motion = Render.Motion()
        if motion then
            cardPop.Scale = 0.96
            TweenService:Create(cardPop, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
        TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
        TweenService:Create(accentBar, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
        for _, textInst in ipairs(fadeables) do
            TweenService:Create(textInst, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
        end

        task.delay(duration, function()
            if not card.Parent then return end
            local tween = TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
            TweenService:Create(accentBar, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            for _, textInst in ipairs(fadeables) do
                TweenService:Create(textInst, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
            end
            tween:Play()
            tween.Completed:Wait()
            card:Destroy()
        end)

        -- Servers: mirror the toast to a Discord-compatible webhook when
        -- one is configured (opt-in via Window:EnableWebhook).
        if self._webhook then
            self:_dispatchWebhook(toast)
        end

        return card
    end

    ------------------------------------------------------------
    -- Webhook mirror — every toast is POSTed (JSON) to the URL via the
    -- host's request impl. Rate-limited to one send per MinInterval
    -- seconds; excess toasts queue (capped) and drain between sends.
    -- Send failures warn() but never touch the UI.
    ------------------------------------------------------------

    local WEBHOOK_QUEUE_CAP = 10

    function Window:EnableWebhook(url, props)
        assert(type(url) == "string" and #url > 0, "EnableWebhook: url must be a non-empty string")
        props = props or {}

        self._webhook = {
            Url = url,
            MinInterval = props.MinInterval or 2,
            Queue = {},
            Draining = false,
        }
        return self._webhook
    end

    function Window:DisableWebhook()
        self._webhook = nil
    end

    function Window:_dispatchWebhook(toast)
        local hook = self._webhook
        local Host = Modules.Host
        if not hook or not Host then return end

        if #hook.Queue >= WEBHOOK_QUEUE_CAP then
            table.remove(hook.Queue, 1) -- drop the oldest; notifications are ephemeral
        end
        table.insert(hook.Queue, {
            Type = toast.Type or "Default",
            Title = toast.Title or "",
            Text = toast.Text or "",
        })

        if hook.Draining then return end
        hook.Draining = true

        local function drain()
            if not self._webhook then
                hook.Draining = false
                return
            end
            local item = table.remove(hook.Queue, 1)
            if not item then
                hook.Draining = false
                return
            end

            -- Plain content string instead of embeds: works on every
            -- webhook-compatible host without special headers or wrappers.
            local content = ("[%s] %s %s"):format(item.Type, item.Title, item.Text)

            task.spawn(function()
                local ok, err = Host.Request({
                    Url = hook.Url,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = { username = "CornUi", content = content },
                })
                if not ok then
                    warn("[CornUi] Webhook send failed: " .. tostring(err))
                end
                task.delay(hook.MinInterval, drain)
            end)
        end
        drain()
    end

    return { TYPE_COLORS = TYPE_COLORS }
end
