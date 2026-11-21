--[[
    CornUi v2.0 — Core/Window.lua
    Window -> Tab -> Section shell, built entirely on Render.New / Theme.
    Elements attach to Sections via Section:Add(instance) or the element
    modules' own Section:CreateX(...) sugar (registered by Elements/*).

    Shell design (the corn identity, drawn with plain frames — zero image
    assets to download, zero texture memory):
      - a gold "kernel chip" beside the window title (Enabled role + sheen)
      - a soft gold accent line under the title bar
      - pill-shaped tabs with a sliding gold underline indicator
      - gold notch marks on section titles

    Perf contract (mobile-first):
      - ZIndexBehavior.Sibling (cheaper than Global resolution)
      - the intro animation is lighter (9 shards) and skipped entirely on
        Render.SetQuality("Low")
      - no ClipsDescendants on auto-sizing containers
      - tab indicator tween is one property pair, skipped on Low quality

    Usage:
        local window = WindowModule.New({ Title = "CornUi v2.0" })
        local tab = window:AddTab("Main")
        local section = tab:AddSection("General")
        section:Add(someInstance)
]]

return function(Modules)

    local Render = Modules.Render
    local Theme = Modules.Theme
    local Players = game:GetService("Players")
    local Tokens = Theme.Tokens

    local WindowModule = {}

    -- Multi-window: CornUi allows any number of live windows (main UI +
    -- button-spawned sub-UIs). Each New() gets a unique instance Id used to
    -- namespace its commands, and DisplayOrder is managed so the window you
    -- last touched sits on top.
    local WindowCount = 0
    local TopOrder = 0

    ------------------------------------------------------------
    -- Shared: the kernel chip (gold rounded square with a sheen gradient)
    ------------------------------------------------------------

    local function buildKernelChip(name, parent, sizePx, position)
        local chip = Render.New("Frame", {
            Name = name,
            Size = UDim2.fromOffset(sizePx, sizePx),
            Position = position,
            CornerRadius = Tokens.ChipCorner,
            Theme = "Enabled",
            Parent = parent,
        })
        -- A white->warm-dark vertical gradient multiplies the themed Enabled
        -- color into a roasted-kernel sheen, whatever theme is active.
        Render.New("Gradient", {
            Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 158, 92)),
            Rotation = 90,
            Parent = chip,
        })
        return chip
    end

    ------------------------------------------------------------
    -- Section
    ------------------------------------------------------------

    local Section = {}
    Section.__index = Section

    function Section.New(parent, props, window)
        props = props or {}

        local self = setmetatable({}, Section)
        self.Window = window -- back-ref so elements can register cleanup hooks

        self.Frame = Render.New("Frame", {
            Name = "Section_" .. (props.Title or "Unnamed"),
            Size = UDim2.new(1, 0, 0, 0), -- auto-grows via UIListLayout below
            AutomaticSize = Enum.AutomaticSize.Y,
            Theme = "Card",
            Parent = parent,
        })

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.Parent = self.Frame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = self.Frame

        if props.Title then
            -- Gold notch beside the section title — a small identity mark,
            -- two instances instead of an icon asset.
            Render.New("Frame", {
                Name = "TitleNotch",
                Size = UDim2.fromOffset(2, 12),
                Position = UDim2.fromOffset(0, 3),
                CornerRadius = 1,
                Theme = "Enabled",
                Parent = self.Frame,
            })

            Render.New("Text", {
                Text = props.Title,
                TextSize = 14,
                Size = UDim2.new(1, -10, 0, 18),
                Position = UDim2.fromOffset(10, 0),
                Theme = "Muted",
                LayoutOrder = 0,
                Parent = self.Frame,
            })
        end

        return self
    end

    function Section:Add(inst)
        inst.Parent = self.Frame
        return inst
    end

    ------------------------------------------------------------
    -- Tab — pill button + full-size page container
    ------------------------------------------------------------

    local Tab = {}
    Tab.__index = Tab

    function Tab.New(window, props)
        props = props or {}

        local self = setmetatable({}, Tab)
        self.Window = window
        self.Sections = {}

        -- Pill: bound to the Card role so theme switches repaint its fill;
        -- SelectTab toggles BackgroundTransparency (paint never touches it).
        self.Pill = Render.New("Frame", {
            Name = "TabPill_" .. (props.Title or "Tab"),
            Size = UDim2.new(0, 0, 0, Tokens.TabBarHeight - 6),
            AutomaticSize = Enum.AutomaticSize.X,
            CornerRadius = math.floor((Tokens.TabBarHeight - 6) / 2),
            Theme = "Card",
            BackgroundTransparency = 1,
            Parent = window.TabBar,
        })

        local pillPadding = Instance.new("UIPadding")
        pillPadding.PaddingLeft = UDim.new(0, 12)
        pillPadding.PaddingRight = UDim.new(0, 12)
        pillPadding.Parent = self.Pill

        self.Label = Render.New("Text", {
            Name = "TabLabel_" .. (props.Title or "Tab"),
            Text = props.Title or "Tab",
            TextSize = 14,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Theme = "Muted",
            Parent = self.Pill,
        })

        self.Page = Render.New("Frame", {
            Name = "TabPage_" .. (props.Title or "Tab"),
            Size = UDim2.fromScale(1, 1),
            Theme = false, -- transparent passthrough container
            Visible = false,
            Parent = window.PageHolder,
        })
        self.Page.BackgroundTransparency = 1

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = self.Page

        local btn = Instance.new("TextButton")
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Size = UDim2.fromScale(1, 1)
        btn.ZIndex = self.Pill.ZIndex + 1
        btn.Parent = self.Pill
        btn.MouseButton1Click:Connect(function()
            window:SelectTab(self)
        end)

        return self
    end

    function Tab:AddSection(title)
        local section = Section.New(self.Page, { Title = title }, self.Window)
        table.insert(self.Sections, section)
        return section
    end

    ------------------------------------------------------------
    -- Window
    ------------------------------------------------------------

    local Window = {}
    Window.__index = Window

    function WindowModule.New(props)
        props = props or {}

        local self = setmetatable({}, Window)
        self.Tabs = {}
        self._cleanups = {} -- functions run on Destroy (disconnect global input connections)

        WindowCount += 1
        self.Id = WindowCount

        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

        self.ScreenGui = Instance.new("ScreenGui")
        self.ScreenGui.Name = props.Name or ("CornUi_" .. self.Id)
        self.ScreenGui.ResetOnSpawn = false
        -- Sibling resolution is the modern default and cheaper than Global —
        -- low-end devices resolve far fewer cross-branch ZIndex pairs.
        self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        self.ScreenGui.Parent = playerGui

        self.Root = Render.New("Frame", {
            Name = "Root",
            Size = props.Size or UDim2.fromOffset(520, 360),
            Position = props.Position or UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Theme = "Window",
            Parent = self.ScreenGui,
        })

        if props.Title then
            buildKernelChip("KernelChip", self.Root, 22, UDim2.fromOffset(8, 6))

            Render.New("Text", {
                Name = "TitleBar",
                Text = props.Title,
                TextSize = 15,
                Size = UDim2.new(1, -100, 0, Tokens.TitleHeight),
                Position = UDim2.fromOffset(38, 6),
                Theme = "Default",
                Parent = self.Root,
            })

            -- Soft gold accent line under the title bar: a solid Enabled-role
            -- bar whose transparency gradient fades the ends out.
            local accent = Render.New("Frame", {
                Name = "AccentLine",
                Size = UDim2.new(1, -16, 0, Tokens.AccentLineHeight),
                Position = UDim2.fromOffset(8, 6 + Tokens.TitleHeight + 4),
                CornerRadius = 1,
                Transparency = 0.25,
                Theme = "Enabled",
                Parent = self.Root,
            })
            Render.New("Gradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.15, 0),
                    NumberSequenceKeypoint.new(0.85, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = accent,
            })

            -- Minimize chip: collapses the window to its title bar. Sits left
            -- of the Cornelius chip (which lives in Elements/CommandPalette).
            local minimizeChip = Render.New("Button", {
                Name = "MinimizeChip",
                Text = "–",
                TextSize = 14,
                Size = UDim2.fromOffset(24, 24),
                Position = UDim2.new(1, -74, 0, 5),
                CornerRadius = 8,
                Theme = "Card",
                Parent = self.Root,
            })
            minimizeChip.MouseButton1Click:Connect(function()
                self:SetMinimized(not self:IsMinimized())
            end)
        end

        -- Invisible drag handle across the title bar. The window itself is
        -- draggable (mobile-first: no title bar drag means no way to move
        -- the window at all on touch).
        self:_makeDraggable(self.Root, Render.New("Frame", {
            Name = "DragHandle",
            Size = UDim2.new(1, -16, 0, 6 + Tokens.TitleHeight + 4),
            Position = UDim2.fromOffset(8, 6),
            BackgroundTransparency = 1,
            Theme = false,
            ZIndex = 50,
            Parent = self.Root,
        }))

        self.TabBar = Render.New("Frame", {
            Name = "TabBar",
            Size = UDim2.new(1, -16, 0, Tokens.TabBarHeight),
            Position = UDim2.fromOffset(8, 6 + Tokens.TitleHeight + 4 + Tokens.AccentLineHeight + 8),
            Theme = false,
            Parent = self.Root,
        })
        self.TabBar.BackgroundTransparency = 1

        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Horizontal
        tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Padding = UDim.new(0, 6)
        tabLayout.Parent = self.TabBar

        -- Sliding gold underline for the active tab (one instance, one
        -- Position+Size tween per switch; instant on Low quality).
        self.TabIndicator = Render.New("Frame", {
            Name = "TabIndicator",
            Size = UDim2.fromOffset(0, Tokens.IndicatorHeight),
            Position = UDim2.fromOffset(0, Tokens.TabBarHeight - Tokens.IndicatorHeight),
            CornerRadius = 2,
            Theme = "Enabled",
            Visible = false,
            Parent = self.TabBar,
        })

        -- Scrollable page holder: overflowing tab content scrolls instead of
        -- clipping at the window edge (Render "Scroll" keeps ClipsDescendants
        -- off, which ScrollingFrame needs for input to work).
        self.PageHolder = Render.New("Scroll", {
            Name = "PageHolder",
            Size = UDim2.new(1, -16, 1, -(6 + Tokens.TitleHeight + 4 + Tokens.AccentLineHeight + 8 + Tokens.TabBarHeight + 6)),
            Position = UDim2.fromOffset(8, 6 + Tokens.TitleHeight + 4 + Tokens.AccentLineHeight + 8 + Tokens.TabBarHeight + 6),
            Theme = false,
            Parent = self.Root,
        })

        if props.Intro ~= false and Render.Motion() then
            task.defer(function()
                self:PlayIntro()
            end)
        end

        -- Cornelius: window-level commands (Commands loads before Window).
        -- The Id carries the instance number so parallel windows never
        -- collide, and Owner ties the entry to this window's lifetime.
        if Modules.Commands then
            Modules.Commands.Register({
                Id = "CornUi.W" .. self.Id .. ".ToggleVisible",
                Title = "Toggle window visibility",
                Keywords = "window show hide cornui",
                Owner = self,
                Run = function()
                    self:SetVisible(not self.Root.Visible)
                end,
            })
        end

        -- Newest window lands on top of the stack (multi-window z-order).
        self:Focus()

        return self
    end

    -- Raises this window above every other CornUi window. Called on creation
    -- and by sub-UI buttons re-opening an existing sub-window.
    function Window:Focus()
        TopOrder += 1
        self.ScreenGui.DisplayOrder = TopOrder
        return self
    end

    function Window:AddTab(title)
        local tab = Tab.New(self, { Title = title })
        table.insert(self.Tabs, tab)

        if #self.Tabs == 1 then
            self:SelectTab(tab)
        end

        -- Cornelius: every tab is reachable as a command.
        if Modules.Commands then
            Modules.Commands.Register({
                Id = "CornUi.W" .. self.Id .. ".Tab." .. title,
                Title = "Go to tab: " .. title,
                Keywords = "tab switch open " .. title,
                Hint = "Tab",
                Owner = self,
                Run = function()
                    self:SelectTab(tab)
                end,
            })
        end

        return tab
    end

    function Window:SelectTab(target)
        for _, tab in ipairs(self.Tabs) do
            tab.Page.Visible = (tab == target)
            -- Active pill fills with the Card color; inactive pills vanish.
            -- (paint() manages only the color; transparency stays ours.)
            tab.Pill.BackgroundTransparency = (tab == target) and 0 or 1
            Modules.Theme.Apply(tab.Label, "Text", {
                Theme = (tab == target) and "Default" or "Muted",
            })
        end
        self.ActiveTab = target
        self:_moveIndicator(target, not Render.Motion())
    end

    -- Slides the gold underline under the active tab pill. `instant` skips
    -- the tween (Low quality / first placement).
    function Window:_moveIndicator(tab, instant)
        local indicator = self.TabIndicator
        local width = tab.Pill.AbsoluteSize.X
        local x = tab.Pill.AbsolutePosition.X - self.TabBar.AbsolutePosition.X

        indicator.Visible = true
        local targetPos = UDim2.fromOffset(x, Tokens.TabBarHeight - Tokens.IndicatorHeight)
        local targetSize = UDim2.fromOffset(width, Tokens.IndicatorHeight)

        if instant or width <= 0 then
            indicator.Position = targetPos
            indicator.Size = targetSize
            return
        end

        local TweenService = game:GetService("TweenService")
        TweenService:Create(indicator, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = targetPos,
            Size = targetSize,
        }):Play()
    end

    -- Registers a function to run when the window is destroyed — elements and
    -- sub-systems use this to disconnect their global UserInputService
    -- connections instead of leaking them for the rest of the session.
    function Window:OnCleanup(fn)
        table.insert(self._cleanups, fn)
    end

    -- Debounced config autosave tied to this window's lifetime: flags are
    -- written to disk `intervalSeconds` after the last change.
    function Window:EnableAutoSave(configName, intervalSeconds)
        assert(Modules.Config, "EnableAutoSave: Config system not loaded")
        local stop = Modules.Config.EnableAutoSave(configName, intervalSeconds)
        self:OnCleanup(stop)
        return stop
    end

    -- Shared drag implementation: moves `target` by following input on
    -- `handle` (works for mouse and touch). Connections are registered for
    -- cleanup so Destroy() doesn't leak them.
    function Window:_makeDraggable(target, handle)
        local UserInputService = game:GetService("UserInputService")
        local dragging, dragStart, startPos = false, nil, nil

        local began = handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = target.Position
            end
        end)

        local changed = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)

        local ended = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                self:_snapIntoView()
            end
        end)

        self:OnCleanup(function()
            began:Disconnect()
            changed:Disconnect()
            ended:Disconnect()
        end)
    end

    -- Off-screen recovery: after a drag (and callable manually), clamps the
    -- window position so it can never get lost on small screens — 48px of
    -- width and the title strip always stay visible. Pure clamp, no tween:
    -- instant correction costs nothing, even on Low quality.
    function Window:_snapIntoView()
        local camera = game:GetService("Workspace").CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize

        local size = self.Root.Size
        local pos = self.Root.Position

        local x = math.clamp(pos.X.Offset, 48 - size.X.Offset, viewport.X - 48)
        local y = math.clamp(pos.Y.Offset, 0, viewport.Y - 60)

        self.Root.Position = UDim2.new(pos.X.Scale, x, pos.Y.Scale, y)
    end

    -- Re-runs the hub after a game teleport by queueing a loader fetch with
    -- the host's teleport queue (when the executor supports it). Pass your
    -- own loader URL, or nil for the CornUi default.
    function Window:PersistAcrossTeleports(loaderUrl)
        local Host = Modules.Host
        if not Host then
            return false, "Host module not loaded"
        end

        local url = loaderUrl or "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/Loader.lua"
        return Host.QueueOnTeleport(function()
            local fetchOk, source = Host.HttpGet(url)
            if not fetchOk then
                warn("[CornUi] Teleport reload fetch failed: " .. tostring(source))
                return
            end
            local chunk, err = loadstring(source)
            if not chunk then
                warn("[CornUi] Teleport reload compile error: " .. tostring(err))
                return
            end
            chunk()
        end)
    end

    function Window:Destroy()
        for _, fn in ipairs(self._cleanups or {}) do
            pcall(fn)
        end
        self._cleanups = {}
        -- Multi-window: drop every command this window (and its elements)
        -- registered, so the palette never runs something owned by a dead UI.
        if Modules.Commands then
            Modules.Commands.Release(self)
        end
        self.ScreenGui:Destroy()
    end

    ------------------------------------------------------------
    -- Floating toggle button — shows/hides the Root window.
    ------------------------------------------------------------

    function Window:CreateFloatingButton(props)
        props = props or {}

        self.FloatButton = Render.New("Frame", {
            Name = "FloatButton",
            Size = UDim2.fromOffset(44, 44),
            Position = props.Position or UDim2.fromOffset(16, 16),
            CornerRadius = 22,
            Theme = "Window",
            Parent = self.ScreenGui,
        })

        if props.Icon then
            Render.New("Icon", {
                Image = props.Icon,
                Size = UDim2.fromOffset(22, 22),
                Position = UDim2.fromOffset(11, 11),
                Theme = false,
                Parent = self.FloatButton,
            })
        else
            -- Default face: a mini kernel chip instead of a bare letter.
            buildKernelChip("KernelChip", self.FloatButton, 18, UDim2.fromOffset(13, 13))
        end

        local button = Instance.new("TextButton")
        button.BackgroundTransparency = 1
        button.Text = ""
        button.Size = UDim2.fromScale(1, 1)
        button.ZIndex = self.FloatButton.ZIndex + 1
        button.Parent = self.FloatButton

        local open = true
        local UserInputService = game:GetService("UserInputService")

        -- Drag-to-reposition, since it floats on screen persistently. A press
        -- that moves less than 6px still counts as a click (toggles window
        -- visibility); anything further is a drag and must not toggle.
        local dragging, dragStart, startPos = false, nil, nil
        local moved = false

        button.MouseButton1Click:Connect(function()
            if moved then
                moved = false
                return
            end
            open = not open
            self:SetVisible(open)
        end)

        local began = button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                dragStart = input.Position
                startPos = self.FloatButton.Position
            end
        end)

        local changed = UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if math.abs(delta.X) + math.abs(delta.Y) > 6 then
                    moved = true
                end
                self.FloatButton.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)

        local ended = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        self:OnCleanup(function()
            began:Disconnect()
            changed:Disconnect()
            ended:Disconnect()
        end)
    end

    ------------------------------------------------------------
    -- Spotlight dimming — darkens the background behind the Root window.
    ------------------------------------------------------------

    function Window:CreateSpotlight(props)
        props = props or {}

        self.Spotlight = Instance.new("Frame")
        self.Spotlight.Name = "Spotlight"
        self.Spotlight.Size = UDim2.fromScale(1, 1)
        self.Spotlight.BackgroundColor3 = Color3.new(0, 0, 0)
        self.Spotlight.BackgroundTransparency = 1
        self.Spotlight.BorderSizePixel = 0
        self.Spotlight.ZIndex = self.Root.ZIndex - 1
        self.Spotlight.Parent = self.ScreenGui

        self.SpotlightMaxTransparency = 1 - (props.Dimness or 0.5)

        local blockInput = Instance.new("TextButton")
        blockInput.BackgroundTransparency = 1
        blockInput.Text = ""
        blockInput.Size = UDim2.fromScale(1, 1)
        blockInput.ZIndex = self.Spotlight.ZIndex
        blockInput.Parent = self.Spotlight
    end

    ------------------------------------------------------------
    -- Intro animation — Christmas release: "Merry Christmas!" greeting,
    -- frosts over, then shatters to reveal the Window underneath.
    -- Lighter than the first pass: 9 shards instead of 24, shorter holds,
    -- and skipped entirely on Low quality (a full-screen overlay plus a
    -- dozen tweens at startup is exactly the hitch weak phones feel).
    ------------------------------------------------------------

    function Window:PlayIntro(props)
        props = props or {}
        local TweenService = game:GetService("TweenService")

        self.Root.Visible = false -- revealed by the shatter at the end

        task.spawn(function()
            local overlay = Instance.new("Frame")
            overlay.Name = "IntroOverlay"
            overlay.Size = self.Root.Size
            overlay.Position = self.Root.Position
            overlay.AnchorPoint = self.Root.AnchorPoint
            overlay.BackgroundColor3 = Color3.fromRGB(18, 30, 46)
            overlay.BorderSizePixel = 0
            overlay.ZIndex = self.Root.ZIndex + 50
            overlay.Parent = self.ScreenGui

            local overlayCorner = Instance.new("UICorner")
            overlayCorner.CornerRadius = UDim.new(0, 10)
            overlayCorner.Parent = overlay

            local greeting = Instance.new("TextLabel")
            greeting.BackgroundTransparency = 1
            greeting.Size = UDim2.fromScale(1, 1)
            greeting.Text = props.Greeting or "Merry Christmas!"
            greeting.TextColor3 = Color3.fromRGB(235, 245, 255)
            greeting.TextSize = 28
            greeting.Font = Enum.Font.GothamBold
            greeting.TextTransparency = 1
            greeting.ZIndex = overlay.ZIndex + 1
            greeting.Parent = overlay

            TweenService:Create(greeting, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
            task.wait(0.9) -- hold the greeting on screen

            -- Frostbite: an icy layer creeps over the text.
            local frost = Instance.new("Frame")
            frost.Name = "Frostbite"
            frost.BackgroundColor3 = Color3.fromRGB(197, 232, 255)
            frost.BackgroundTransparency = 1
            frost.Size = UDim2.fromScale(1, 1)
            frost.BorderSizePixel = 0
            frost.ZIndex = overlay.ZIndex + 2
            frost.Parent = overlay

            local frostCorner = Instance.new("UICorner")
            frostCorner.CornerRadius = UDim.new(0, 10)
            frostCorner.Parent = frost

            local frostGradient = Instance.new("UIGradient")
            frostGradient.Rotation = 90
            frostGradient.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 0.1),
            })
            frostGradient.Parent = frost

            TweenService:Create(frost, TweenInfo.new(0.45, Enum.EasingStyle.Sine), {
                BackgroundTransparency = 0.05,
            }):Play()
            task.wait(0.55)

            -- Shatter: tile into a grid of shards, fling outward + fade,
            -- revealing the real Window once every shard is gone.
            overlay.Visible = false

            local screenOrigin = self.ScreenGui.AbsolutePosition
            local overlaySize = overlay.AbsoluteSize
            local overlayOrigin = overlay.AbsolutePosition - screenOrigin

            local COLS, ROWS = 3, 3
            local tileW = overlaySize.X / COLS
            local tileH = overlaySize.Y / ROWS

            local remaining = COLS * ROWS

            for row = 0, ROWS - 1 do
                for col = 0, COLS - 1 do
                    local shard = Instance.new("Frame")
                    shard.Name = "Shard"
                    shard.BackgroundColor3 = frost.BackgroundColor3
                    shard.BorderSizePixel = 0
                    shard.Size = UDim2.fromOffset(tileW + 1, tileH + 1)
                    shard.Position = UDim2.fromOffset(
                        overlayOrigin.X + col * tileW,
                        overlayOrigin.Y + row * tileH
                    )
                    shard.ZIndex = overlay.ZIndex + 3
                    shard.Parent = self.ScreenGui

                    local dirX = (col - COLS / 2) + (math.random() - 0.5)
                    local dirY = (row - ROWS / 2) + (math.random() - 0.5)
                    local mag = math.sqrt(dirX * dirX + dirY * dirY) + 0.001
                    local travel = 120 + math.random(0, 60)

                    local targetPos = shard.Position + UDim2.fromOffset(
                        (dirX / mag) * travel,
                        (dirY / mag) * travel
                    )

                    local tween = TweenService:Create(
                        shard,
                        TweenInfo.new(0.4 + math.random() * 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        {
                            Position = targetPos,
                            BackgroundTransparency = 1,
                            Rotation = (math.random() - 0.5) * 180,
                        }
                    )
                    tween:Play()
                    tween.Completed:Connect(function()
                        shard:Destroy()
                        remaining -= 1
                        if remaining <= 0 then
                            overlay:Destroy()
                            self.Root.Visible = true
                        end
                    end)
                end
            end
        end)
    end

    -- Shared by the floating button and manual calls — shows/hides Root
    -- and fades the Spotlight dimmer (if created) to match.
    function Window:SetVisible(visible)
        self.Root.Visible = visible

        if not visible and self.CloseCommandPalette then
            pcall(self.CloseCommandPalette, self)
        end

        if self.Spotlight then
            local TweenService = game:GetService("TweenService")
            TweenService:Create(self.Spotlight, TweenInfo.new(0.2), {
                BackgroundTransparency = visible and self.SpotlightMaxTransparency or 1,
            }):Play()
        end
    end

    -- Minimize: collapse the window to its title bar (chip stays, drag
    -- stays). The body (tab strip + page holder) is hidden and the Root
    -- shrinks to a title-bar-tall strip; restoring puts the exact original
    -- size back. Instant on Low quality, one tween otherwise.
    function Window:SetMinimized(minimized)
        -- Titleless windows have no chip to restore from — never collapse them.
        if not self.Root:FindFirstChild("MinimizeChip") then return end
        minimized = minimized and true or false
        if self._minimized == minimized then return end
        self._minimized = minimized

        if minimized then
            self._restoreSize = self.Root.Size
            if self.CloseCommandPalette then
                pcall(self.CloseCommandPalette, self)
            end
        end

        local restore = self._restoreSize or self.Root.Size
        local collapsedHeight = 6 + Tokens.TitleHeight + 4 + Tokens.AccentLineHeight + 6

        self.TabBar.Visible = not minimized
        self.PageHolder.Visible = not minimized

        local targetSize = minimized
            and UDim2.new(restore.X.Scale, restore.X.Offset, 0, collapsedHeight)
            or restore

        if Render.Motion() then
            local TweenService = game:GetService("TweenService")
            TweenService:Create(self.Root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = targetSize,
            }):Play()
        else
            self.Root.Size = targetSize
        end
    end

    function Window:IsMinimized()
        return self._minimized and true or false
    end

    -- Exposed so Elements/* can attach sugar methods, e.g.:
    --   Modules.Window.Section.CreateToggle = function(section, props) ... end
    WindowModule.Section = Section
    WindowModule.Tab = Tab
    WindowModule.Window = Window

    return WindowModule
end
