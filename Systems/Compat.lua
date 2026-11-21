--[[
    CornUi v2.x - Systems/Compat.lua
    v1.9.3 compatibility layer. Loaded LAST by Loader.lua, after every other
    module exists. Nothing in here renames or replaces v2 internals: it only
    ATTACHES the v1 public API on top of them, so scripts written for v1.9.3
    run unchanged while all v2 widgets (Stepper, Cycle, CommandPalette,
    Statusbar, Plugins, Host...) stay available as additions.

    What v1.9.3 scripts expect, and where it maps:

      Library:CreateWindow(config)        -> Window.New + prop shims
      Library:SetFlag / GetFlag           -> Flags.SetFlag / GetFlag
      Library.Flags (value table)         -> live proxy over the flag store
      Library.FlagChanged.Event           -> Flags.FlagChanged
      Library:SaveConfig/LoadConfig/...   -> Config.* (same names already)
      Library:RegisterTheme/RegisterSkin  -> Theme.Register
      Library:RegisterElement + CreateCustom -> custom element registry
      window:CreateTab(name, config)      -> Window.AddTab + tab icon support
      window:SetTheme / SetThemeColor     -> Theme.Set / Theme.PatchRole
      window:Notify{Title, Content}       -> lazy NotificationCenter + shim
      window:SetBackground/SetSkin/SetSpotlight/SetBlur/SetShadow/
              SetCornerRadius/SetOpacity/SetAnimationSpeed/RegisterCommand/
              GetActiveTab/ExportConfig/ImportConfig -> shims below
      tab:CreateSection(name)             -> nested Section.New
      tab:Create___ / section:Create___ / card:Create___ (all 28 v1 element
              names incl. Textbox, MultiDropdown, Hotkey, Checklist, Meter,
              Timer, Custom) -> v2 element modules + prop normalization
              (v1 config.Name maps to v2 props.Title, v1 Notify Content maps
              to Text, CreateLabel takes a bare string)
]]

return function(Modules)

    local Render = Modules.Render
    local Theme = Modules.Theme
    local Flags = Modules.Flags
    local Config = Modules.Config
    local Commands = Modules.Commands
    local WindowModule = Modules.Window

    local warnOnce = {}
    local function noteOnce(key, msg)
        if warnOnce[key] then return end
        warnOnce[key] = true
        warn("[CornUi compat] " .. msg)
    end

    -- Registry backing Library:RegisterElement / section:CreateCustom.
    local CustomElements = {}

    local function normalizeAsset(id)
        if type(id) == "number" then return "rbxassetid://" .. tostring(id) end
        if type(id) == "string" and id ~= "" and not id:match("^rbxasset") and not id:match("^https?://") then
            -- Pure digits are asset ids. Anything else (embedded pack name,
            -- local file path) passes through for Assets.Resolve in Render.
            if id:match("^%d+$") then return "rbxassetid://" .. id end
            return id
        end
        return id
    end

    -- v1 element methods ran on Tab, Section AND Card objects through the
    -- shared TabMethods mixin. v2 element modules expect a Section-like host
    -- (something with .Frame to parent into, .Window for cleanup/hooks).
    local function asSection(host)
        if host.Frame and host.Window then
            return host
        end
        return {
            Frame = host.Page or host.Frame,
            Window = host.Window,
        }
    end

    local function props(config)
        if type(config) == "string" then
            return { Title = config }
        end
        return config or {}
    end

    local function titleOf(config, fallback)
        return config.Title or config.Name or fallback
    end

    ------------------------------------------------------------
    -- TabMethods: the v1 mixin, rebuilt on v2 element modules
    ------------------------------------------------------------

    local TM = {}

    function TM.CreateSection(host, name)
        local pseudo = asSection(host)
        local section = WindowModule.Section.New(pseudo.Frame, { Title = name }, pseudo.Window)
        if host.Sections then
            table.insert(host.Sections, section)
        end
        return section
    end

    function TM.CreateToggle(host, config)
        config = props(config)
        return Modules.Toggle.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Toggle"),
            Default = config.Default,
            Callback = config.Callback,
        })
    end

    function TM.CreateButton(host, config)
        config = props(config)
        return WindowModule.Section.CreateButton(asSection(host), {
            Title = titleOf(config, "Button"),
            Callback = config.Callback,
            Accent = config.Accent,
        })
    end

    function TM.CreateLabel(host, config)
        config = props(config)
        return WindowModule.Section.CreateLabel(asSection(host), {
            Title = config.Title or config.Name or config.Text or "",
            TextSize = config.TextSize,
            Muted = config.Muted,
        })
    end

    function TM.CreateParagraph(host, config)
        config = props(config)
        return WindowModule.Section.CreateParagraph(asSection(host), {
            Text = config.Text or config.Content or "",
            Height = config.Height,
            Muted = config.Muted,
        })
    end

    function TM.CreateDivider(host, config)
        config = props(config)
        return WindowModule.Section.CreateDivider(asSection(host), {
            Title = config.Name or config.Title,
            Transparency = config.Transparency,
        })
    end

    function TM.CreateCard(host, config)
        config = props(config)
        return WindowModule.Section.CreateCard(asSection(host), {
            Title = config.Name or config.Title,
        })
    end

    function TM.CreateImage(host, config)
        config = props(config)
        return WindowModule.Section.CreateImage(asSection(host), {
            Image = normalizeAsset(config.Image or config.Icon or config.Id),
            Size = config.Size,
        })
    end

    function TM.CreateProgressBar(host, config)
        config = props(config)
        return WindowModule.Section.CreateProgressBar(asSection(host), {
            Title = config.Name or config.Title,
            Min = config.Min,
            Max = config.Max,
            Flag = config.Flag,
            Default = config.Default,
        })
    end

    function TM.CreateRadioGroup(host, config)
        config = props(config)
        return WindowModule.Section.CreateRadioGroup(asSection(host), {
            Flag = config.Flag,
            Title = config.Name or config.Title,
            Options = config.Options,
            Default = config.Default,
            Callback = config.Callback,
        })
    end

    function TM.CreateDropdown(host, config)
        config = props(config)
        return Modules.Dropdown.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Dropdown"),
            Options = config.Options,
            Default = config.Default,
            Callback = config.Callback,
            Multi = false,
        })
    end

    function TM.CreateMultiDropdown(host, config)
        config = props(config)
        return Modules.Dropdown.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Dropdown"),
            Options = config.Options,
            Default = config.Default,
            Callback = config.Callback,
            Multi = true,
        })
    end

    function TM.CreateTextbox(host, config)
        config = props(config)
        return Modules.TextInput.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Input"),
            Placeholder = config.Placeholder,
            Default = config.Default,
            Callback = config.Callback,
        })
    end

    function TM.CreateKeybind(host, config)
        config = props(config)
        return Modules.Keybind.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Keybind"),
            Default = config.Default,
            Callback = config.Callback,
        })
    end

    -- v1 Hotkey fired while the key was held; v2 Keybind's OnPress mode is
    -- the equivalent, so Hotkey is Keybind with OnPress defaulted on.
    function TM.CreateHotkey(host, config)
        config = props(config)
        return Modules.Keybind.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Hotkey"),
            Default = config.Default,
            Callback = config.Callback,
            OnPress = config.OnPress == nil or config.OnPress,
        })
    end

    function TM.CreateColorPicker(host, config)
        config = props(config)
        return Modules.ColorPicker.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Color"),
            Default = config.Default or config.Color,
            Callback = config.Callback,
        })
    end

    function TM.CreateColorGradient(host, config)
        config = props(config)
        return Modules.ColorGradient.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Gradient"),
            Callback = config.Callback,
        })
    end

    function TM.CreateSearch(host, config)
        config = props(config)
        return Modules.Search.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Search"),
            Callback = config.Callback,
        })
    end

    function TM.CreateDiscordButton(host, config)
        config = props(config)
        return Modules.DiscordButton.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Discord"),
            Callback = config.Callback,
        })
    end

    function TM.CreateKeybindList(host, config)
        config = props(config)
        return Modules.KeybindList.New(asSection(host), {
            Title = titleOf(config, "Keybinds"),
            Flags = config.Flags or config.List or {},
        })
    end

    function TM.CreateThemeEditor(host, config)
        config = props(config)
        return Modules.ThemeEditor.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Theme"),
        })
    end

    function TM.CreatePluginManager(host, config)
        config = props(config)
        return Modules.PluginManager.New(asSection(host), {
            Flag = config.Flag,
            Title = titleOf(config, "Plugins"),
        })
    end

    -- v1 let any page host a notification center; v2 attaches it to the
    -- window. Compat routes the section-level call to the window-level one.
    function TM.CreateNotificationCenter(host, config)
        local pseudo = asSection(host)
        if pseudo.Window and pseudo.Window.CreateNotificationCenter then
            return pseudo.Window:CreateNotificationCenter(props(config))
        end
        noteOnce("notifcenter", "CreateNotificationCenter needs a window parent (tab/section)")
        return nil
    end

    function TM.CreateCustom(host, name, config)
        local ctor = CustomElements[name]
        assert(ctor, ("CreateCustom: no element registered as '%s' (use Library:RegisterElement)"):format(tostring(name)))
        return ctor(asSection(host), config)
    end

    ------------------------------------------------------------
    -- v1-only elements, implemented fresh on the v2 render layer
    ------------------------------------------------------------

    -- Checklist: list of independent checkboxes. Items:
    --   { Name = "Label", Flag = "flagName", Default = bool, Callback = fn(value) }
    function TM.CreateChecklist(host, config)
        config = props(config)

        local holder = Render.New("Frame", {
            Name = "Checklist_" .. titleOf(config, "Checklist"),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Theme = false,
            Parent = asSection(host).Frame,
        })
        holder.BackgroundTransparency = 1

        local headText = titleOf(config, "Checklist")
        if config.Title ~= nil or config.Name ~= nil then
            Render.New("Text", {
                Text = headText,
                TextSize = 14,
                Size = UDim2.new(1, 0, 0, 18),
                Theme = "Default",
                Parent = holder,
            })
        end

        local items = {}
        local marks = {}

        local function paintItem(item)
            marks[item].Visible = (Flags.GetFlag(item.Flag, item.Default) == true)
        end

        for i, item in ipairs(config.Items or {}) do
            item.Flag = item.Flag or ("Checklist_" .. tostring(item.Name or i))
            items[item.Name or tostring(i)] = item

            local row = Render.New("Frame", {
                Name = "Check_" .. tostring(item.Name or i),
                Size = UDim2.new(1, 0, 0, 24),
                LayoutOrder = i,
                Theme = false,
                Parent = holder,
            })
            row.BackgroundTransparency = 1

            local box = Render.New("Frame", {
                Name = "Box",
                Size = UDim2.fromOffset(18, 18),
                Position = UDim2.new(0, 0, 0.5, -9),
                CornerRadius = 4,
                Theme = "Card",
                Parent = row,
            })

            marks[item] = Render.New("Frame", {
                Name = "Mark",
                Size = UDim2.new(1, -6, 1, -6),
                Position = UDim2.fromOffset(3, 3),
                CornerRadius = 3,
                Theme = "Enabled",
                Parent = box,
            })

            Render.New("Text", {
                Text = tostring(item.Name or ""),
                TextSize = 13,
                Size = UDim2.new(1, -26, 1, 0),
                Position = UDim2.fromOffset(26, 0),
                Theme = "Default",
                Parent = row,
            })

            local tap = Instance.new("TextButton")
            tap.BackgroundTransparency = 1
            tap.Text = ""
            tap.Size = UDim2.fromScale(1, 1)
            tap.ZIndex = row.ZIndex + 1
            tap.Parent = row
            tap.MouseButton1Click:Connect(function()
                local value = not (Flags.GetFlag(item.Flag, item.Default) == true)
                Flags.SetFlag(item.Flag, value)
                paintItem(item)
                if item.Callback then
                    task.spawn(item.Callback, value)
                end
            end)

            Flags.SetFlag(item.Flag, item.Default == true, true)
            paintItem(item)
        end

        local controller = { Frame = holder, Items = items }
        function controller.SetItem(name, value)
            local item = items[name]
            if item then
                Flags.SetFlag(item.Flag, value == true)
                paintItem(item)
            end
        end
        function controller.SetAll(value)
            for _, item in pairs(items) do
                controller.SetItem(item.Name, value)
            end
        end
        return controller
    end

    -- Meter: read-only value bar. { Name, Min, Max, Default, Color, Animated,
    -- Flag, ShowValue, Callback }. Set it with :Set(value) or through Flag.
    function TM.CreateMeter(host, config)
        config = props(config)
        local min = config.Min or 0
        local max = config.Max or 100
        local suffix = config.Suffix and (" " .. config.Suffix) or ""

        local row = Render.New("Frame", {
            Name = "Meter_" .. titleOf(config, "Meter"),
            Size = UDim2.new(1, 0, 0, Theme.Tokens.RowHeight),
            Theme = false,
            Parent = asSection(host).Frame,
        })
        row.BackgroundTransparency = 1

        local valueText
        if config.ShowValue ~= false then
            valueText = Render.New("Text", {
                Text = "",
                TextSize = 13,
                XAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(0, 64, 0, 18),
                Position = UDim2.new(1, -64, 0, 0),
                Theme = "Default",
                Parent = row,
            })
        end

        if config.Name or config.Title then
            Render.New("Text", {
                Text = titleOf(config, "Meter"),
                TextSize = 14,
                Size = UDim2.new(1, valueText and -70 or 0, 0, 18),
                Theme = "Default",
                Parent = row,
            })
        end

        local track = Render.New("Frame", {
            Name = "Track",
            Size = UDim2.new(1, 0, 0, 10),
            Position = UDim2.fromOffset(0, Theme.Tokens.RowHeight - 14),
            CornerRadius = 5,
            Theme = "Default",
            Parent = row,
        })

        local fill = Render.New("Frame", {
            Name = "Fill",
            Size = UDim2.new(0, 0, 1, 0),
            CornerRadius = 5,
            Theme = config.Color and false or "Enabled",
            BackgroundColor3 = config.Color,
            Parent = track,
        })

        local self = {}
        -- Callable BOTH ways: Flags sync calls element.Set(value) with a dot,
        -- users naturally call meter:Set(value) with a colon. Detect the
        -- colon form (first arg is the controller itself) and unwrap it.
        function self.Set(a, b)
            local value = (a == self) and b or a
            value = tonumber(value) or min
            local alpha = (max ~= min) and math.clamp((value - min) / (max - min), 0, 1) or 1
            if config.Animated ~= false and Render.Motion() then
                game:GetService("TweenService"):Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(alpha, 0, 1, 0),
                }):Play()
            else
                fill.Size = UDim2.new(alpha, 0, 1, 0)
            end
            if valueText then
                valueText.Text = tostring(math.round(value * 100) / 100) .. suffix
            end
            if config.Callback then
                task.spawn(config.Callback, value)
            end
        end

        if config.Flag then
            Flags.RegisterElement(config.Flag, self)
            self:Set(Flags.GetFlag(config.Flag, config.Default or min))
        else
            self:Set(config.Default or min)
        end

        self.Frame = row
        return self
    end

    -- Timer: countdown row with Start / Pause / Reset taps.
    -- { Name, Duration = 60, AutoStart = false, Callback = fn() }
    function TM.CreateTimer(host, config)
        config = props(config)
        local duration = config.Duration or 60

        local row = Render.New("Frame", {
            Name = "Timer_" .. titleOf(config, "Timer"),
            Size = UDim2.new(1, 0, 0, 56),
            Theme = false,
            Parent = asSection(host).Frame,
        })
        row.BackgroundTransparency = 1

        Render.New("Text", {
            Text = titleOf(config, "Timer"),
            TextSize = 14,
            Size = UDim2.new(1, -120, 0, 18),
            Theme = "Default",
            Parent = row,
        })

        local readout = Render.New("Text", {
            Text = "",
            TextSize = 18,
            XAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(0, 110, 0, 22),
            Position = UDim2.new(1, -110, 0, -2),
            Theme = "Enabled",
            Parent = row,
        })

        local self = {
            Duration = duration,
            Remaining = duration,
            Running = false,
        }

        local function paint()
            local t = math.max(0, math.floor(self.Remaining + 0.5))
            readout.Text = ("%d:%02d"):format(math.floor(t / 60), t % 60)
        end
        paint()

        function self.SetRemaining(seconds)
            self.Remaining = tonumber(seconds) or duration
            paint()
        end

        function self.Stop()
            self.Running = false
        end

        function self.Start()
            if self.Running then return end
            if self.Remaining <= 0 then
                self.Remaining = duration
            end
            self.Running = true
            task.spawn(function()
                while self.Running and self.Remaining > 0 do
                    task.wait(1)
                    if not self.Running then break end
                    self.Remaining = math.max(0, self.Remaining - 1)
                    paint()
                end
                if self.Running and self.Remaining <= 0 then
                    self.Running = false
                    if config.Callback then
                        task.spawn(config.Callback)
                    end
                end
            end)
        end

        function self.Pause()
            self.Running = false
        end

        function self.Reset()
            self.Running = false
            self.Remaining = duration
            paint()
        end

        local function chip(label, x, action)
            local btn = Render.New("Button", {
                Name = label,
                Text = label,
                TextSize = 12,
                Size = UDim2.fromOffset(34, 24),
                Position = UDim2.new(1, x, 0, 26),
                CornerRadius = 6,
                Theme = "Card",
                Parent = row,
            })
            btn.MouseButton1Click:Connect(action)
        end
        chip("Start", -150, function() self.Start() end)
        chip("Pause", -112, function() self.Pause() end)
        chip("Reset", -74, function() self.Reset() end)

        if config.AutoStart then
            self.Start()
        end

        self.Frame = row
        return self
    end

    -- Normalizes v1 prop names onto the v2 sugar: Name feeds Title, Content
    -- feeds Text. The full config passes through untouched, so every v2-only
    -- prop (Description, Multi, SubWindow, Loadstring, Labels, Buttons, ...)
    -- keeps working exactly as before.
    local function normalize(config)
        config = props(config)
        if config.Name ~= nil and config.Title == nil then
            config.Title = config.Name
        end
        if config.Content ~= nil and config.Text == nil then
            config.Text = config.Content
        end
        return config
    end

    -- Originals: the v2 sugar already attached to Section by the element
    -- modules. They stay the IMPLEMENTATION; Compat only wraps them so v1
    -- prop names resolve, then exposes the wrapper on Tab, Section and Card
    -- (v1's TabMethods mixin ran on all three).
    local Originals = {}
    for name, fn in pairs(WindowModule.Section) do
        if type(fn) == "function" and name:sub(1, 6) == "Create" then
            Originals[name] = fn
        end
    end

    -- Names with a v2 original win: original + normalized props. This covers
    -- Toggle, Button, Label, Paragraph, Divider, Card, Image, ProgressBar,
    -- RadioGroup, Stepper, Cycle, Dropdown, ColorPicker, Keybind, Search,
    -- TextInput, DiscordButton, KeybindList, ThemeEditor, PluginManager.
    for name, orig in pairs(Originals) do
        TM[name] = function(host, config)
            return orig(asSection(host), normalize(config))
        end
    end

    -- KeybindList special case: v1 auto-lists binds and needs no Flags table,
    -- while v2's sugar asserts one. Default to an empty list; explicit Flags
    -- calls behave exactly as v2 users expect.
    if Originals.CreateKeybindList then
        TM.CreateKeybindList = function(host, config)
            config = normalize(config)
            if type(config.Flags) ~= "table" then
                config.Flags = {}
            end
            return Modules.KeybindList.New(asSection(host), config)
        end
    end

    -- Names WITHOUT a v2 original keep their explicit Compat shims above
    -- (CreateTextbox, CreateMultiDropdown, CreateHotkey, CreateChecklist,
    -- CreateMeter, CreateTimer, CreateCustom, CreateNotificationCenter,
    -- CreateSection).

    -- Attach the mixin everywhere v1 allowed element creation: Tab pages,
    -- Sections, and Cards.
    for name, fn in pairs(TM) do
        WindowModule.Tab[name] = fn
        WindowModule.Section[name] = fn
        if Modules.Basics and Modules.Basics.Card then
            Modules.Basics.Card[name] = fn
        end
    end

    ------------------------------------------------------------
    -- Window-level v1 methods (the WM surface)
    ------------------------------------------------------------

    local Window = WindowModule.Window

    -- Captured before the shim below replaces Window.Notify: the v2 Notify
    -- asserts a notification center exists, while v1 scripts call Notify
    -- without ever creating one.
    local rawNotify = Window.Notify

    function Window:CreateTab(name, config)
        config = config or {}
        local tab = self:AddTab(name)

        if config.Icon then
            local label = tab.Label
            if label then
                label.Position = UDim2.fromOffset(18, 0)
                label.ZIndex = tab.Pill.ZIndex + 2
            end
            Render.New("Icon", {
                Name = "TabIcon",
                Image = normalizeAsset(config.Icon),
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(0, 0, 0.5, -7),
                Theme = false,
                ZIndex = tab.Pill.ZIndex + 2,
                Parent = tab.Pill,
            })
        end

        return tab
    end

    function Window:Notify(config)
        config = config or {}
        if not self.NotifHolder and self.CreateNotificationCenter then
            self:CreateNotificationCenter({})
        end
        return rawNotify(self, {
            Title = config.Title or "Notification",
            Text = config.Text or config.Content or "",
            Duration = config.Duration or 4,
            Type = config.Type,
        })
    end

    function Window:SetTheme(name)
        return Theme.Set(name)
    end

    -- v1 color keys mapped onto the v2 Kind/Role system. Unknown keys warn
    -- once instead of erroring, so old scripts never hard-crash on a typo.
    local ColorKeyMap = {
        Accent = { "Frame", "Enabled" },
        Kernel = { "Frame", "Enabled" },
        Element = { "Frame", "Card" },
        Card = { "Frame", "Card" },
        Background = { "Frame", "Window" },
        Window = { "Frame", "Window" },
        Header = { "Frame", "Window" },
        TextMain = { "Text", "Default" },
        Text = { "Text", "Default" },
        TextSub = { "Text", "Muted" },
        Muted = { "Text", "Muted" },
    }

    function Window:SetThemeColor(key, color)
        local mapped = ColorKeyMap[key]
        if not mapped then
            noteOnce("color_" .. tostring(key),
                ("SetThemeColor: unknown color key '%s' (known: Accent, Element, Background, TextMain, TextSub)"):format(tostring(key)))
            return false
        end
        Theme.PatchRole(Theme.Get(), mapped[1], mapped[2], { Color = color })
        return true
    end

    function Window:SetSkin(name)
        noteOnce("skin", "SetSkin maps onto the v2 theme system (Theme.Set)")
        return Theme.Set(name)
    end

    function Window:SetBackground(input)
        self:ClearBackground()
        if not input then return end

        if typeof and typeof(input) == "Color3" then
            self._bg = Render.New("Frame", {
                Name = "WindowBackground",
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = input,
                Theme = false,
                ZIndex = 0,
                Parent = self.Root,
            })
        else
            self._bg = Render.New("Icon", {
                Name = "WindowBackground",
                Image = normalizeAsset(input),
                Size = UDim2.fromScale(1, 1),
                ScaleType = Enum.ScaleType.Stretch,
                Theme = false,
                ZIndex = 0,
                Parent = self.Root,
            })
        end
        return self._bg
    end

    function Window:ClearBackground()
        if self._bg then
            self._bg:Destroy()
            self._bg = nil
        end
    end

    function Window:RegisterCommand(keyword, fn)
        return Commands.Register({
            Id = ("CornUi.W%s.Cmd.%s"):format(tostring(self.Id), tostring(keyword)),
            Title = tostring(keyword),
            Keywords = tostring(keyword),
            Owner = self,
            Run = function()
                if fn then
                    local ok, err = pcall(fn, keyword)
                    if not ok then
                        warn("[CornUi] command '" .. tostring(keyword) .. "' failed: " .. tostring(err))
                    end
                end
            end,
        })
    end

    function Window:SetSpotlight(active)
        if active and not self.Spotlight and self.CreateSpotlight then
            self:CreateSpotlight({})
        end
        if self.Spotlight then
            self.Spotlight.BackgroundTransparency = active and (self.SpotlightMaxTransparency or 0.5) or 1
        end
    end

    function Window:SetCornerRadius(radius)
        if self._rootCorner then
            self._rootCorner:Destroy()
        end
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, tonumber(radius) or 10)
        corner.Parent = self.Root
        self._rootCorner = corner
    end

    function Window:SetOpacity(transparency)
        self.Root.BackgroundTransparency = math.clamp(tonumber(transparency) or 0, 0, 1)
    end

    -- Speed 0 (or anything <= 0.01) flips the whole UI to Low quality, which
    -- skips tweens and the intro; anything else restores High.
    function Window:SetAnimationSpeed(factor)
        self._animationSpeed = factor
        if (tonumber(factor) or 1) <= 0.01 then
            Render.SetQuality("Low")
        else
            Render.SetQuality("High")
        end
    end

    function Window:SetBlur(amount)
        local Lighting = game:GetService("Lighting")
        local blur = Lighting:FindFirstChild("CornUiBlur")
        amount = tonumber(amount) or 0
        if amount <= 0 then
            if blur then blur.Enabled = false end
            return
        end
        if not blur then
            blur = Instance.new("BlurEffect")
            blur.Name = "CornUiBlur"
            blur.Parent = Lighting
        end
        blur.Size = math.clamp(amount, 0, 20)
        blur.Enabled = true
    end

    function Window:SetShadow(enable)
        if not enable then
            if self._shadow then
                self._shadow:Destroy()
                self._shadow = nil
            end
            return
        end
        if self._shadow and self._shadow.Parent then return end

        local shadow = Render.New("Frame", {
            Name = "WindowShadow",
            Size = self.Root.Size,
            Position = self.Root.Position + UDim2.fromOffset(4, 5),
            AnchorPoint = self.Root.AnchorPoint,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.75,
            BorderSizePixel = 0,
            Theme = false,
            ZIndex = math.max(1, (self.Root.ZIndex or 1)) - 1,
            Parent = self.ScreenGui,
        })
        self._shadow = shadow
    end

    function Window:GetActiveTab()
        return self.ActiveTab
    end

    function Window:ExportConfig(name)
        if type(name) == "string" and isfile and readfile
            and pcall(isfile, "CornUi_Configs/" .. name .. ".json") then
            local ok, json = pcall(readfile, "CornUi_Configs/" .. name .. ".json")
            if ok then
                return json
            end
        end
        return Config.ExportConfig()
    end

    function Window:ImportConfig(jsonText)
        return Config.ImportConfig(jsonText)
    end

    ------------------------------------------------------------
    -- Library-level v1 surface on the returned CornUi table
    ------------------------------------------------------------

    local M = Modules

    -- Resolve any image source (asset id, URL, local file, embedded pack
    -- name) to paintable content. Returns nil when the environment can't
    -- load it — elements hide the icon instead of erroring.
    function M:LoadImage(source, name)
        if not Modules.Assets then return nil end
        return Modules.Assets.Get(source, name)
    end

    -- CreateWindow accepts both v1 config keys (Name, Subtitle, Icon, Theme,
    -- GuiName, TogglePosition, Intro, Position) and v2 keys (Title, Size).
    function M:CreateWindow(config)
        config = config or {}

        if config.Theme and Theme.List then
            local known = false
            for _, themeName in ipairs(Theme.List()) do
                if themeName == config.Theme then
                    known = true
                    break
                end
            end
            if known then
                Theme.Set(config.Theme)
            end
        end

        local window = WindowModule.New({
            Title = config.Title or config.Name or "UI Library",
            Name = config.GuiName,
            Size = config.Size,
            Position = config.Position,
            Icon = config.Icon, -- rendered by the native header chrome
            Intro = config.Intro,
        })

        -- Subtitle: small muted line, right-aligned inside the header.
        if config.Subtitle then
            Render.New("Text", {
                Name = "Subtitle",
                Text = tostring(config.Subtitle),
                TextSize = 11,
                XAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Position = UDim2.new(1, -36, 0, 0),
                Theme = "Muted",
                Parent = window.Header,
            })
        end

        if config.TogglePosition then
            window:CreateFloatingButton({ Position = config.TogglePosition })
        end

        return window
    end

    -- Flags. v1 called them on the Library object; both call styles work.
    function M:SetFlag(name, value)
        return Flags.SetFlag(name, value)
    end

    function M:GetFlag(name)
        return Flags.GetFlag(name)
    end

    -- v1 exposed Library.Flags as a plain value table. The Flags module
    -- occupies that name, so give the module table a pass-through: reading a
    -- missing key reads the store, writing a missing key writes the store.
    -- Real module functions (SetFlag, GetFlag, ...) are unaffected.
    setmetatable(Flags, {
        __index = function(_, key)
            return Flags.GetFlag(key)
        end,
        __newindex = function(_, key, value)
            Flags.SetFlag(key, value)
        end,
        __iter = function()
            -- Snapshot iteration: for k, v in CornUi.Flags do ... (Luau
            -- generalized iteration; best-effort for v1 scripts that walked
            -- the flag table with pairs).
            local snapshot = Flags.GetAllFlags()
            local keys = {}
            for key in pairs(snapshot) do
                table.insert(keys, key)
            end
            table.sort(keys)
            local i = 0
            return function()
                i += 1
                local key = keys[i]
                if key then return key, snapshot[key] end
            end
        end,
    })

    -- v1 Library.FlagChanged was an object with .Event; Flags.FlagChanged is
    -- already the Event itself, so wrap it in the same shape.
    M.FlagChanged = { Event = Flags.FlagChanged }

    -- Config: v1 called these on Library with the same names.
    function M:SaveConfig(name) return Config.SaveConfig(name) end
    function M:LoadConfig(name, window) return Config.LoadConfig(name) end
    function M:ListConfigs() return Config.ListConfigs() end
    function M:DeleteConfig(name) return Config.DeleteConfig(name) end
    function M:ImportConfig(jsonText, window) return Config.ImportConfig(jsonText) end

    function M:ExportConfig(name)
        if type(name) == "string" and isfile and readfile
            and pcall(isfile, "CornUi_Configs/" .. name .. ".json") then
            local ok, json = pcall(readfile, "CornUi_Configs/" .. name .. ".json")
            if ok then
                return json
            end
        end
        return Config.ExportConfig()
    end

    -- Themes / skins.
    function M:RegisterTheme(name, definition)
        return Theme.Register(name, definition)
    end

    function M:RegisterSkin(name, definition)
        noteOnce("skin", "RegisterSkin maps onto the v2 theme system")
        return Theme.Register(name, definition)
    end

    -- Custom elements: Library:RegisterElement(name, constructor) then
    -- section:CreateCustom(name, config). The constructor receives
    -- (section, config), same as v1.
    function M:RegisterElement(name, constructor)
        assert(type(name) == "string" and type(constructor) == "function",
            "RegisterElement: expected (string name, function constructor)")
        CustomElements[name] = constructor
    end

    function M:GetRegisteredElements()
        local out = {}
        for name in pairs(CustomElements) do
            table.insert(out, name)
        end
        table.sort(out)
        return out
    end

    function M:PlaySound(soundId, volume)
        pcall(function()
            local SoundService = game:GetService("SoundService")
            local sound = Instance.new("Sound")
            sound.SoundId = normalizeAsset(soundId)
            sound.Volume = tonumber(volume) or 1
            sound.Parent = SoundService
            sound:Play()
            task.delay(6, function()
                sound:Destroy()
            end)
        end)
    end

    function M:PlayHaptic(variant)
        pcall(function()
            local HapticService = game:GetService("HapticService")
            if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
                local power = variant == "Heavy" and 1 or 0.5
                HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, power)
                task.delay(0.15, function()
                    HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
                end)
            end
        end)
    end

    -- v1 exposed the mixin itself for advanced use.
    M.TabMethods = TM

    -- Cornelius (v1 command helper) mapped onto the v2 command system.
    M.Cornelius = {
        RegisterCommand = function(name, callback)
            return Commands.Register({
                Id = "Cornelius." .. tostring(name),
                Title = tostring(name),
                Keywords = tostring(name),
                Run = function()
                    if callback then task.spawn(callback) end
                end,
            })
        end,
        GetFlags = function()
            return Flags.GetAllFlags()
        end,
        LoadPack = function()
            noteOnce("pack", "command packs were folded into the v2 command system; RegisterCommand is the path now")
            return false
        end,
        LoadPacks = function()
            noteOnce("pack", "command packs were folded into the v2 command system; RegisterCommand is the path now")
            return false
        end,
    }

    return {
        TabMethods = TM,
        CustomElements = CustomElements,
    }
end
