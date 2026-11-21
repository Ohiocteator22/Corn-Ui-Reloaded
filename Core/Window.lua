--[[
    CornUi v2.0 — Core/Window.lua
    Window -> Tab -> Section shell, built entirely on Render.New / Theme.

    Visual identity (restored to the CornUi v1.9.x look — near-black window,
    gold accent, left sidebar tabs):
      - 34px header: title left, optional icon, minimize chip right
      - 98px sidebar rail: tab pills, the active one fills gold (Enabled)
      - scrollable page area right of the rail, sections as dark cards

    Layout engine (executor-proof):
      NO UIListLayout, NO AutomaticSize anywhere in the shell. Every row /
      section / page is placed by explicit Y arithmetic in ChildAdded hooks
      (Render sets Size before Parent, so heights are final at hook time).
      Nested list layouts + AutomaticSize stack elements on one spot on
      several executors; arithmetic cannot fail.

    Perf contract (mobile-first):
      - ZIndexBehavior.Sibling (cheaper than Global resolution)
      - intro is a 0.2s fade — the v2 frost/shatter overlay stranded windows
        on some executors and is gone
      - tweens skipped entirely on Render.SetQuality("Low")

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
    -- attachStack — the explicit-Y stacking engine (executor-proof).
    -- Children are placed by arithmetic, never by UIListLayout or
    -- AutomaticSize: nested list layouts stack every element on one spot on
    -- several executors. Render guarantees Size is final before Parent
    -- fires ChildAdded, and any later Size change (a nested Card growing,
    -- for example) re-runs the whole pass through its property signal.
    -- Height for zero-height guests falls back to one row.
    ------------------------------------------------------------

    local function attachStack(frame, opts)
        opts = opts or {}
        local kids = {}

        local function relayout()
            local padX = opts.PadX or 8
            local y = opts.Top or 6
            for _, child in ipairs(kids) do
                if child.Parent == frame then
                    child.Position = UDim2.fromOffset(padX, y)
                    if child.Size.X.Scale == 1 and child.Size.X.Offset == 0 then
                        child.Size = UDim2.new(1, -(padX * 2), child.Size.Y.Scale, child.Size.Y.Offset)
                    end
                    local h = child.Size.Y.Offset
                    if h <= 0 then h = opts.RowFallback or 26 end
                    y = y + h + (opts.Gap or 6)
                end
            end
            frame.Size = UDim2.new(1, 0, 0, y - (opts.Gap or 6) + (opts.Bottom or 2))
            if opts.OnGrow then opts.OnGrow(frame) end
        end

        frame.ChildAdded:Connect(function(child)
            if child:IsA("GuiObject") then
                kids[#kids + 1] = child
                child:GetPropertyChangedSignal("Size"):Connect(relayout)
                relayout()
            end
        end)

        return frame
    end

    ------------------------------------------------------------
    -- Section — dark card, rows stacked by attachStack arithmetic
    ------------------------------------------------------------

    local Section = {}
    Section.__index = Section

    function Section.New(parent, props, window)
        props = props or {}

        local self = setmetatable({}, Section)
        self.Window = window -- back-ref so elements can register cleanup hooks
        self._cursor = 6     -- stacked content height, kept in sync for pages

        self.Frame = Render.New("Frame", {
            Name = "Section_" .. (props.Title or "Unnamed"),
            Size = UDim2.new(1, 0, 0, 30), -- recomputed by the stack engine
            Theme = "Card",
            Parent = parent,
        })

        attachStack(self.Frame, {
            Top = 6,
            Gap = 6,
            OnGrow = function()
                self._cursor = self.Frame.Size.Y.Offset
                if window and window._syncCanvas then
                    window:_syncCanvas()
                end
            end,
        })

        if props.Title then
            Render.New("Text", {
                Name = "SectionTitle",
                Text = props.Title,
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                Size = UDim2.new(1, -16, 0, 16),
                Theme = "Muted",
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
    -- Tab — sidebar pill + full-size page container
    ------------------------------------------------------------

    local Tab = {}
    Tab.__index = Tab

    function Tab.New(window, props)
        props = props or {}

        local self = setmetatable({}, Tab)
        self.Window = window
        self.Sections = {}

        -- Stacked pill in the sidebar rail, placed by index (explicit math).
        local index = #window.Tabs + 1
        self.Pill = Render.New("Frame", {
            Name = "TabPill_" .. (props.Title or "Tab"),
            Size = UDim2.fromOffset(Tokens.SidebarWidth - 12, Tokens.SidebarTabHeight),
            Position = UDim2.fromOffset(6, 6 + (index - 1) * (Tokens.SidebarTabHeight + Tokens.SidebarTabGap)),
            CornerRadius = Tokens.PillCorner,
            Theme = "Card",
            BackgroundTransparency = 1,
            Parent = window.Sidebar,
        })

        self.Label = Render.New("Text", {
            Name = "TabLabel_" .. (props.Title or "Tab"),
            Text = props.Title or "Tab",
            TextSize = 12,
            Font = Enum.Font.Gotham,
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            Theme = "Muted",
            Parent = self.Pill,
        })

        self.Page = Render.New("Frame", {
            Name = "TabPage_" .. (props.Title or "Tab"),
            Size = UDim2.new(1, 0, 0, 40),
            Theme = false, -- transparent passthrough container
            Visible = false,
            Parent = window.PageHolder,
        })
        self.Page.BackgroundTransparency = 1
        self._cursor = 8 -- stacked sections height, synced into the canvas

        attachStack(self.Page, {
            PadX = 10,
            Top = 8,
            Gap = 10,
            Bottom = 8,
            OnGrow = function()
                self._cursor = self.Page.Size.Y.Offset
                window:_syncCanvas()
            end,
        })

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

        ------------------------------------------------------------
        -- Header: title (+ optional icon) left, minimize chip right
        ------------------------------------------------------------

        self.Header = Render.New("Frame", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, Tokens.TitleHeight),
            Theme = false,
            Parent = self.Root,
        })
        self.Header.BackgroundTransparency = 1

        local titleOffset = 14
        if props.Icon then
            Render.New("Icon", {
                Name = "TitleIcon",
                Image = props.Icon,
                Size = UDim2.fromOffset(18, 18),
                Position = UDim2.fromOffset(12, 8),
                Theme = false,
                Parent = self.Header,
            })
            titleOffset = 36
        end

        if props.Title then
            Render.New("Text", {
                Name = "TitleBar",
                Text = props.Title,
                TextSize = 15,
                Font = Enum.Font.GothamBold,
                Size = UDim2.new(1, -(titleOffset + 44), 0, Tokens.TitleHeight),
                Position = UDim2.fromOffset(titleOffset, 0),
                Theme = "Default",
                Parent = self.Header,
            })
        end

        -- Minimize chip: collapses the window to its header strip.
        local minimizeChip = Render.New("Button", {
            Name = "MinimizeChip",
            Text = "–",
            TextSize = 13,
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.new(1, -30, 0, 6),
            CornerRadius = Tokens.PillCorner,
            Theme = "Card",
            Parent = self.Header,
        })
        minimizeChip.MouseButton1Click:Connect(function()
            self:SetMinimized(not self:IsMinimized())
        end)

        -- Invisible drag handle across the header. The window itself is
        -- draggable (mobile-first: no header drag means no way to move the
        -- window at all on touch).
        self:_makeDraggable(self.Root, Render.New("Frame", {
            Name = "DragHandle",
            Size = UDim2.new(1, 0, 0, Tokens.TitleHeight),
            BackgroundTransparency = 1,
            Theme = false,
            ZIndex = 50,
            Parent = self.Header,
        }))

        ------------------------------------------------------------
        -- Body: 98px sidebar rail + scrollable page area
        ------------------------------------------------------------

        self.Sidebar = Render.New("Frame", {
            Name = "Sidebar",
            Size = UDim2.new(0, Tokens.SidebarWidth, 1, -Tokens.TitleHeight),
            Position = UDim2.fromOffset(0, Tokens.TitleHeight),
            Theme = false,
            Parent = self.Root,
        })
        self.Sidebar.BackgroundTransparency = 1

        -- Hairline divider between the rail and the page area.
        Render.New("Frame", {
            Name = "SidebarDivider",
            Size = UDim2.new(0, 1, 1, 0),
            Position = UDim2.fromOffset(Tokens.SidebarWidth - 1, 0),
            Theme = "Card",
            Parent = self.Sidebar,
        })

        -- Scrollable page holder: overflowing tab content scrolls instead of
        -- clipping at the window edge. Canvas height is driven explicitly by
        -- _syncCanvas — no AutomaticCanvasSize, no list layouts.
        self.PageHolder = Render.New("Scroll", {
            Name = "PageHolder",
            Size = UDim2.new(1, -Tokens.SidebarWidth, 1, -Tokens.TitleHeight),
            Position = UDim2.fromOffset(Tokens.SidebarWidth, Tokens.TitleHeight),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.None,
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

        -- Theme switches repaint pill/label bindings; re-run SelectTab so
        -- the active pill keeps its gold fill + dark label under the new
        -- palette. Disconnected on Destroy.
        local themeResync = Theme.OnChanged:Connect(function()
            if self.ActiveTab then
                self:SelectTab(self.ActiveTab, true)
            end
        end)
        self:OnCleanup(function()
            themeResync:Disconnect()
        end)

        return self
    end

    -- Raises this window above every other CornUi window. Called on creation
    -- and by sub-UI buttons re-opening an existing sub-window.
    function Window:Focus()
        TopOrder += 1
        self.ScreenGui.DisplayOrder = TopOrder
        return self
    end

    -- Keeps the scroll canvas equal to the active page's stacked height.
    function Window:_syncCanvas()
        local active = self.ActiveTab
        if active and self.PageHolder then
            self.PageHolder.CanvasSize = UDim2.fromOffset(0, active._cursor + 8)
        end
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

    function Window:SelectTab(target, instant)
        for _, tab in ipairs(self.Tabs) do
            local active = (tab == target)
            tab.Page.Visible = active
            -- Active pill fills gold (Enabled role); inactive pills vanish.
            -- Rebinding lets Theme.Set repaint the right role per state.
            Modules.Theme.Apply(tab.Pill, "Frame", { Theme = active and "Enabled" or "Card" })
            tab.Pill.BackgroundTransparency = active and 0 or 1
            if active then
                -- Dark label on the gold pill: use the Window (darkest) color
                -- so the pairing holds on every theme.
                local dark = Theme.GetStyle("Frame", "Window")
                if dark and dark.Color then
                    tab.Label.TextColor3 = dark.Color
                end
            else
                Modules.Theme.Apply(tab.Label, "Text", { Theme = "Muted" })
            end
        end
        self.ActiveTab = target
        self:_syncCanvas()
        return self
    end

    -- Registers a function to run when the window is destroyed — elements
    -- and sub-systems use this to disconnect their global UserInputService
    -- connections instead of leaking them for the rest of the session.
    function Window:OnCleanup(fn)
        table.insert(self._cleanups, fn)
        return fn
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
            if dragging then
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
    -- width and the header strip always stay visible. Pure clamp, no tween:
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
            -- Default face: a small gold dot. (Keeps the "KernelChip" name —
            -- compat hides it when a custom float icon is configured.)
            Render.New("Frame", {
                Name = "KernelChip",
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.fromOffset(17, 17),
                CornerRadius = 5,
                Theme = "Enabled",
                Parent = self.FloatButton,
            })
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
    -- Intro — a 0.2s fade-in, nothing more. The v2 frost/shatter overlay
    -- (full-screen navy box + 9 shard tweens gating Root.Visible) stranded
    -- windows on several executors and is gone for good: the window is
    -- NEVER hidden by the intro, with or without motion.
    ------------------------------------------------------------

    function Window:PlayIntro(props)
        props = props or {}
        self.Root.Visible = true

        if not Render.Motion() then
            self.Root.BackgroundTransparency = 0
            return
        end

        self.Root.BackgroundTransparency = 1
        local TweenService = game:GetService("TweenService")
        TweenService:Create(self.Root, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
        }):Play()
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

    -- Minimize: collapse the window to its header strip (drag stays). The
    -- body (sidebar + page holder) is hidden and the Root shrinks to a
    -- header-tall bar; restoring puts the exact original size back. Instant
    -- on Low quality, one tween otherwise.
    function Window:SetMinimized(minimized)
        -- Titleless windows have no chip to restore from — never collapse them.
        if not self.Header:FindFirstChild("MinimizeChip") then return end
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
        local collapsedHeight = Tokens.TitleHeight + 8

        self.Sidebar.Visible = not minimized
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
    WindowModule.Stack = { Attach = attachStack } -- for Cards / custom hosts

    return WindowModule
end
