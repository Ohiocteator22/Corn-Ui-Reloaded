--[[
    CornUi v2.0 — Elements/Basics.lua
    Groups the small, simple elements in one file: Divider, Label, Button,
    Card, Paragraph, Image, ProgressBar, RadioGroup, Stepper, Cycle. Only
    ProgressBar, RadioGroup, Stepper and Cycle are Flag-backed; the rest are
    display/static.

    Registers:
        Section:CreateDivider(props)
        Section:CreateLabel(props)
        Section:CreateButton(props)      -- Sub-UI spawner (SubWindow / Loadstring)
        Section:CreateCard(props)
        Section:CreateParagraph(props)
        Section:CreateImage(props)
        Section:CreateProgressBar(props)
        Section:CreateRadioGroup(props)
        Section:CreateStepper(props)     -- Flag number with −/+ taps
        Section:CreateCycle(props)       -- Flag cycler with ‹ › taps
]]

return function(Modules)

    local Render = Modules.Render
    local Theme = Modules.Theme
    local Flags = Modules.Flags
    local Section = Modules.Window.Section

    ------------------------------------------------------------
    -- Divider — plain line, or an interrupted line with a centered label
    ------------------------------------------------------------

    Section.CreateDivider = function(section, props)
        props = props or {}

        if not props.Title then
            return Render.New("Frame", {
                Name = "Divider",
                Size = UDim2.new(1, 0, 0, 1),
                Theme = "Default",
                Transparency = props.Transparency or 0.5,
                Parent = section.Frame,
            })
        end

        -- Line with a centered chip interrupting it (v1-style labeled divider).
        local row = Render.New("Frame", {
            Name = "Divider_" .. props.Title,
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Theme = false,
            Parent = section.Frame,
        })

        Render.New("Frame", {
            Name = "Line",
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0.5, 0),
            Theme = "Default",
            Transparency = props.Transparency or 0.5,
            Parent = row,
        })

        local chip = Render.New("Frame", {
            Name = "Chip",
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Theme = "Card",
            Parent = row,
        })

        local chipPadding = Instance.new("UIPadding")
        chipPadding.PaddingLeft = UDim.new(0, 8)
        chipPadding.PaddingRight = UDim.new(0, 8)
        chipPadding.Parent = chip

        Render.New("Text", {
            Text = props.Title,
            TextSize = 12,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Theme = "Muted",
            Parent = chip,
        })

        return row
    end

    ------------------------------------------------------------
    -- Label — single line of themed text (v1 CreateLabel parity)
    ------------------------------------------------------------

    Section.CreateLabel = function(section, props)
        props = props or {}
        return Render.New("Text", {
            Name = "Label_" .. (props.Title or "Label"),
            Text = props.Title or "",
            TextSize = props.TextSize or 14,
            TextWrapped = props.TextWrapped == true,
            XAlignment = props.XAlignment or Enum.TextXAlignment.Left,
            Size = props.Size or UDim2.new(1, 0, 0, 18),
            Theme = props.Muted and "Muted" or "Default",
            Parent = section.Frame,
        })
    end

    ------------------------------------------------------------
    -- Button — themed click target (Render "Button" kind), with an instant
    -- press-duck (two property writes, no tween) so touch users get feedback
    -- even on Low quality.
    --
    -- Sub-UIs: a button can spawn its own window (multi-window CornUi).
    --   SubWindow = {
    --       Title, Size, Position, Name,      -- window props (Size default 360x260)
    --       TabTitle, SectionTitle,           -- auto first tab/section ("Main")
    --       Intro,                            -- default false (subs skip the intro)
    --       Singleton = true,                 -- re-click refocuses the live window
    --       Build = function(sub, section) end, -- populate the sub-UI
    --   }
    --   Loadstring = "https://..." | "code" | function() -> code
    --       -- an http-prefixed string is HttpGet'd first, anything else is
    --       -- compiled as source directly
    --   Command = false                       -- opt out of the Cornelius entry
    -- The triggers compose: SubWindow, then Loadstring, then Callback.
    ------------------------------------------------------------

    local ButtonSeq = 0

    -- One shared failure surface for loadstring problems: a toast when this
    -- window has a notification center, a warn() always.
    local function notifyError(section, text, detail)
        warn("[CornUi] " .. text .. (detail and (": " .. tostring(detail)) or ""))
        local win = section.Window
        if win and win.NotifHolder and win.Notify then
            pcall(win.Notify, win, { Title = "CornUi", Text = text, Duration = 4 })
        end
    end

    -- Spawns (or refocuses) the button's sub-window. The live sub-window is
    -- remembered on the button's own props, so each button singletons its
    -- own window independently of every other button.
    local function openSubWindow(section, props)
        local subProps = props.SubWindow

        -- Singleton by default: a second click raises the live window
        -- instead of stacking clones.
        if subProps.Singleton ~= false and props._subWindow
            and props._subWindow.ScreenGui.Parent ~= nil then
            local sub = props._subWindow
            sub:SetMinimized(false)
            sub:SetVisible(true)
            sub:Focus()
            return sub
        end

        local sub = Modules.Window.New({
            Title = subProps.Title or "Sub window",
            Size = subProps.Size or UDim2.fromOffset(360, 260),
            Position = subProps.Position,
            Name = subProps.Name,
            Intro = subProps.Intro == true, -- subs skip the intro by default
        })
        props._subWindow = sub

        if subProps.Build ~= false then
            local tab = sub:AddTab(subProps.TabTitle or "Main")
            local firstSection = tab:AddSection(subProps.SectionTitle or subProps.TabTitle or "Main")
            if subProps.Build then
                subProps.Build(sub, firstSection)
            end
        end

        return sub
    end

    -- Runs the button's Loadstring payload: fetch (URL) -> compile -> run,
    -- every stage guarded, failures surfaced via notifyError.
    local function runLoadstring(section, payload)
        task.spawn(function()
            local source = payload
            if type(source) == "function" then
                local ok, result = pcall(source)
                if not ok then
                    notifyError(section, "Loadstring source function failed", result)
                    return
                end
                source = result
            end
            if type(source) ~= "string" or #source == 0 then
                notifyError(section, "Loadstring: expected source code, URL or function")
                return
            end

            if source:sub(1, 4):lower() == "http" then
                local ok, body = pcall(game.HttpGet, game, source)
                if not ok or type(body) ~= "string" then
                    notifyError(section, "Couldn't fetch loadstring URL", body)
                    return
                end
                source = body
            end

            local chunk, compileErr = loadstring(source)
            if not chunk then
                notifyError(section, "Loadstring compile error", compileErr)
                return
            end

            local ok, runErr = pcall(chunk)
            if not ok then
                notifyError(section, "Loadstring runtime error", runErr)
            end
        end)
    end

    Section.CreateButton = function(section, props)
        props = props or {}

        local btn = Render.New("Button", {
            Name = "Button_" .. (props.Title or "Button"),
            Text = props.Title or "Button",
            TextSize = props.TextSize or 14,
            Size = props.Size or UDim2.new(1, 0, 0, 30),
            Theme = props.Accent and "Enabled" or "Default",
            Parent = section.Frame,
        })

        -- Optional icon: rbxassetid number, URL, local file or embedded pack
        -- name (Systems/Assets.lua); Render's Icon builder resolves it.
        if props.Icon then
            Render.New("Icon", {
                Name = "ButtonIcon",
                Image = props.Icon,
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, 8, 0.5, -8),
                Theme = false,
                Parent = btn,
            })
            btn.TextXAlignment = Enum.TextXAlignment.Left
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 30)
            pad.Parent = btn
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                btn.BackgroundTransparency = 0.25
            end
        end)

        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                btn.BackgroundTransparency = 0
            end
        end)

        local function activate()
            if props.SubWindow then
                openSubWindow(section, props)
            end
            if props.Loadstring then
                runLoadstring(section, props.Loadstring)
            end
            if props.Callback then
                props.Callback()
            end
        end

        btn.MouseButton1Click:Connect(function()
            task.spawn(activate)
        end)

        -- Cornelius: the button's action is runnable from the palette.
        -- Opt out per-button with Command = false.
        if Modules.Commands and props.Command ~= false then
            ButtonSeq += 1
            Modules.Commands.Register({
                Id = ("CornUi.W%s.Button.%d"):format(
                    tostring(section.Window and section.Window.Id or 0),
                    ButtonSeq
                ),
                Title = props.Title or "Button",
                Keywords = "button " .. tostring(props.Title or ""),
                Owner = section.Window,
                Run = activate,
            })
        end

        return btn
    end

    ------------------------------------------------------------
    -- Card — a themed sub-container other content can be parented into
    ------------------------------------------------------------

    local Card = {}
    Card.__index = Card

    Section.CreateCard = function(section, props)
        props = props or {}

        local self = setmetatable({}, Card)

        self.Frame = Render.New("Frame", {
            Name = "Card_" .. (props.Title or "Card"),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            CornerRadius = 6,
            Theme = "Card",
            Parent = section.Frame,
        })

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 4)
        layout.Parent = self.Frame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = self.Frame

        if props.Title then
            -- Gold notch mark beside the card title (matches section titles).
            Render.New("Frame", {
                Name = "TitleNotch",
                Size = UDim2.fromOffset(2, 12),
                Position = UDim2.fromOffset(0, 3),
                CornerRadius = 1,
                Theme = "Enabled",
                LayoutOrder = 0,
                Parent = self.Frame,
            })

            Render.New("Text", {
                Text = props.Title,
                TextSize = 15,
                Theme = "Default",
                Size = UDim2.new(1, -10, 0, 18),
                Position = UDim2.fromOffset(10, 0),
                LayoutOrder = 1,
                Parent = self.Frame,
            })
        end

        function self:Add(inst)
            inst.Parent = self.Frame
            return inst
        end

        return self
    end

    ------------------------------------------------------------
    -- Paragraph — auto-grows with wrapped text (fixed Height still honored)
    ------------------------------------------------------------

    Section.CreateParagraph = function(section, props)
        props = props or {}
        return Render.New("Text", {
            Name = "Paragraph",
            Text = props.Text or "",
            TextSize = props.TextSize or 13,
            TextWrapped = true,
            XAlignment = Enum.TextXAlignment.Left,
            YAlignment = Enum.TextYAlignment.Top,
            Size = props.Height and UDim2.new(1, 0, 0, props.Height)
                or UDim2.new(1, 0, 0, 0), -- AutomaticSize grows to fit the text
            AutomaticSize = props.Height and nil or Enum.AutomaticSize.Y,
            Theme = props.Muted and "Muted" or "Default",
            Parent = section.Frame,
        })
    end

    ------------------------------------------------------------
    -- Image
    ------------------------------------------------------------

    Section.CreateImage = function(section, props)
        props = props or {}
        assert(props.Image, "CreateImage: props.Image is required")

        return Render.New("Icon", {
            Name = "Image",
            Image = props.Image,
            Size = props.Size or UDim2.fromOffset(64, 64),
            ScaleType = props.ScaleType,
            Theme = false,
            Parent = section.Frame,
        })
    end

    ------------------------------------------------------------
    -- ProgressBar
    ------------------------------------------------------------

    local ProgressBar = {}
    ProgressBar.__index = ProgressBar

    Section.CreateProgressBar = function(section, props)
        props = props or {}
        local min = props.Min or 0
        local max = props.Max or 100

        local self = setmetatable({}, ProgressBar)

        local row = Render.New("Frame", {
            Name = "ProgressBar_" .. (props.Title or "Progress"),
            Size = UDim2.new(1, 0, 0, props.Title and 36 or 14),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        if props.Title then
            Render.New("Text", {
                Text = props.Title,
                TextSize = 13,
                Size = UDim2.new(1, 0, 0, 16),
                Theme = "Default",
                Parent = row,
            })
        end

        self.Track = Render.New("Frame", {
            Name = "Track",
            Size = UDim2.new(1, 0, 0, 10),
            Position = UDim2.fromOffset(0, props.Title and 20 or 0),
            CornerRadius = 5,
            Theme = "Default",
            Parent = row,
        })

        self.Fill = Render.New("Frame", {
            Name = "Fill",
            Size = UDim2.new(0, 0, 1, 0),
            CornerRadius = 5,
            Theme = "Enabled",
            Parent = self.Track,
        })

        function self:Set(value)
            local range = max - min
            local alpha = (range ~= 0) and math.clamp((value - min) / range, 0, 1) or 1
            self.Fill.Size = UDim2.new(alpha, 0, 1, 0)
        end

        if props.Flag then
            Flags.RegisterElement(props.Flag, { Set = function(value) self:Set(value) end })
            self:Set(Flags.GetFlag(props.Flag, min))
        else
            self:Set(props.Default or min)
        end

        return self
    end

    ------------------------------------------------------------
    -- RadioGroup — single-select from a fixed option list, Flag-backed
    ------------------------------------------------------------

    local RadioGroup = {}
    RadioGroup.__index = RadioGroup

    Section.CreateRadioGroup = function(section, props)
        props = props or {}
        props.Flag = props.Flag or Flags.NextAutoFlag()
        assert(type(props.Options) == "table" and #props.Options > 0,
            "CreateRadioGroup: props.Options must be a non-empty array")

        local self = setmetatable({}, RadioGroup)
        self.Flag = props.Flag

        local container = Render.New("Frame", {
            Name = "RadioGroup_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Theme = false,
            Parent = section.Frame,
        })
        container.BackgroundTransparency = 1

        if props.Title then
            Render.New("Text", {
                Text = props.Title,
                TextSize = 14,
                Size = UDim2.new(1, 0, 0, 18),
                Theme = "Default",
                Parent = container,
            })
        end

        local dots = {}
        local function isSelected(option, currentValue)
            return currentValue == option
        end

        local function refresh(currentValue)
            for option, dot in pairs(dots) do
                dot.BackgroundTransparency = isSelected(option, currentValue) and 0 or 1
            end
        end

        for i, option in ipairs(props.Options) do
            local row = Render.New("Frame", {
                Name = "Radio_" .. tostring(option),
                Size = UDim2.new(1, 0, 0, 22),
                LayoutOrder = i,
                Theme = false,
                Parent = container,
            })
            row.BackgroundTransparency = 1

            -- Ring: a themed circle outline; the inner dot fills when selected.
            local ring = Render.New("Frame", {
                Name = "Ring",
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(0, 0, 0.5, -7),
                CornerRadius = 7,
                Theme = "Muted",
                Transparency = 0.6,
                Parent = row,
            })

            local dot = Render.New("Frame", {
                Name = "Dot",
                Size = UDim2.new(1, -6, 1, -6),
                Position = UDim2.fromOffset(3, 3),
                CornerRadius = 4,
                Theme = "Enabled",
                Parent = ring,
            })
            dots[option] = dot

            Render.New("Text", {
                Text = tostring(option),
                TextSize = 13,
                Size = UDim2.new(1, -22, 1, 0),
                Position = UDim2.fromOffset(22, 0),
                Theme = "Default",
                Parent = row,
            })

            local optButton = Instance.new("TextButton")
            optButton.BackgroundTransparency = 1
            optButton.Text = ""
            optButton.Size = UDim2.fromScale(1, 1)
            optButton.ZIndex = row.ZIndex + 1
            optButton.Parent = row
            optButton.MouseButton1Click:Connect(function()
                Flags.SetFlag(props.Flag, option)
            end)
        end

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local value = b
            if a ~= self then
                value = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, value, true) -- silent: programmatic Set also persists
            end
            refresh(value)
            if props.Callback then
                task.spawn(props.Callback, value)
            end
        end

        local initial = Flags.GetFlag(props.Flag, props.Default or props.Options[1])
        Flags.RegisterElement(props.Flag, self)
        Flags.SetFlag(props.Flag, initial, true)
        refresh(initial)

        return self
    end

    ------------------------------------------------------------
    -- Stepper — Flag-backed number field with − / + tap buttons: the
    -- mobile alternative to a drag slider when values move in fixed steps.
    --   { Flag, Title, Min, Max, Step, Default, Suffix, Callback }
    ------------------------------------------------------------

    local Stepper = {}
    Stepper.__index = Stepper

    Section.CreateStepper = function(section, props)
        props = props or {}
        props.Flag = props.Flag or Flags.NextAutoFlag()

        local min = props.Min or 0
        local max = props.Max or 100
        local step = props.Step or 1
        local suffix = props.Suffix and (" " .. props.Suffix) or ""

        local self = setmetatable({}, Stepper)
        self.Flag = props.Flag

        local row = Render.New("Frame", {
            Name = "Stepper_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, Theme.Tokens.RowHeight),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        Render.New("Text", {
            Text = props.Title or props.Flag,
            TextSize = 14,
            Size = UDim2.new(1, -160, 0, 18),
            Theme = "Default",
            Parent = row,
        })

        -- Right cluster: −  [value]  +  (26px buttons, 72px readout — all
        -- thumb-sized, no drag precision needed).
        self.Value = Render.New("Text", {
            Name = "Value",
            Text = "",
            TextSize = 13,
            XAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromOffset(72, 20),
            Position = UDim2.new(1, -102, 0.5, -10),
            Theme = "Default",
            Parent = row,
        })

        local minusBtn = Render.New("Button", {
            Name = "Minus",
            Text = "–",
            TextSize = 14,
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -132, 0.5, -13),
            CornerRadius = 7,
            Theme = "Card",
            Parent = row,
        })

        local plusBtn = Render.New("Button", {
            Name = "Plus",
            Text = "+",
            TextSize = 14,
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -26, 0.5, -13),
            CornerRadius = 7,
            Theme = "Card",
            Parent = row,
        })

        local function clamp(v)
            if v < min then return min end
            if v > max then return max end
            return v
        end

        -- Snaps to the step grid so Step = 0.1 doesn't accumulate float
        -- drift (0.30000000000004 shows up as "0.3").
        local function snapped(v)
            if step > 0 then
                v = math.round(v / step) * step
            end
            return clamp(v)
        end

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local value = b
            if a ~= self then
                value = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, value, true) -- silent: programmatic Set also persists
            end
            value = clamp(tonumber(value) or min)
            self.Value.Text = tostring(value) .. suffix
            if props.Callback then
                task.spawn(props.Callback, value)
            end
        end

        Flags.RegisterElement(props.Flag, self)
        local initial = snapped(Flags.GetFlag(props.Flag, props.Default or min))
        Flags.SetFlag(props.Flag, initial, true)
        self.Value.Text = tostring(initial) .. suffix -- silent initial paint

        minusBtn.MouseButton1Click:Connect(function()
            Flags.SetFlag(props.Flag, snapped(Flags.GetFlag(props.Flag, min) - step))
        end)
        plusBtn.MouseButton1Click:Connect(function()
            Flags.SetFlag(props.Flag, snapped(Flags.GetFlag(props.Flag, min) + step))
        end)

        return self
    end

    ------------------------------------------------------------
    -- Cycle — Flag-backed value cycler with ‹ › tap buttons: the compact
    -- dropdown alternative for short fixed option lists.
    --   { Flag, Title, Options = {...}, Default, Loop = true, Callback }
    ------------------------------------------------------------

    local Cycle = {}
    Cycle.__index = Cycle

    Section.CreateCycle = function(section, props)
        props = props or {}
        props.Flag = props.Flag or Flags.NextAutoFlag()
        assert(type(props.Options) == "table" and #props.Options > 0,
            "CreateCycle: props.Options must be a non-empty array")

        local self = setmetatable({}, Cycle)
        self.Flag = props.Flag

        local row = Render.New("Frame", {
            Name = "Cycle_" .. props.Flag,
            Size = UDim2.new(1, 0, 0, Theme.Tokens.RowHeight),
            Theme = false,
            Parent = section.Frame,
        })
        row.BackgroundTransparency = 1

        Render.New("Text", {
            Text = props.Title or props.Flag,
            TextSize = 14,
            Size = UDim2.new(1, -160, 0, 18),
            Theme = "Default",
            Parent = row,
        })

        self.ValueLabel = Render.New("Text", {
            Name = "Value",
            Text = "",
            TextSize = 13,
            XAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromOffset(88, 20),
            Position = UDim2.new(1, -122, 0.5, -10),
            Theme = "Default",
            Parent = row,
        })

        local prevBtn = Render.New("Button", {
            Name = "Prev",
            Text = "<",
            TextSize = 14,
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -152, 0.5, -13),
            CornerRadius = 7,
            Theme = "Card",
            Parent = row,
        })

        local nextBtn = Render.New("Button", {
            Name = "Next",
            Text = ">",
            TextSize = 14,
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -26, 0.5, -13),
            CornerRadius = 7,
            Theme = "Card",
            Parent = row,
        })

        local index = 1
        local function indexOf(value)
            for i, option in ipairs(props.Options) do
                if option == value then
                    return i
                end
            end
            return nil
        end

        function self.Set(a, b)
            -- accepts both .Set(value) (Flags sync) and :Set(value) (user calls)
            local value = b
            if a ~= self then
                value = a
            end
            if props.Flag then
                Flags.SetFlag(props.Flag, value, true) -- silent: programmatic Set also persists
            end
            local i = indexOf(value)
            if i then
                index = i
                self.ValueLabel.Text = tostring(value)
                if props.Callback then
                    task.spawn(props.Callback, value)
                end
            end
        end

        local initial = Flags.GetFlag(props.Flag, props.Default or props.Options[1])
        if indexOf(initial) == nil then
            initial = props.Options[1]
        end

        Flags.RegisterElement(props.Flag, self)
        -- suppressUI + manual paint: the initial value must not fire Callback.
        Flags.SetFlag(props.Flag, initial, true)
        index = indexOf(initial) or 1
        self.ValueLabel.Text = tostring(initial)

        local function move(delta)
            local nextIndex = index + delta
            if nextIndex > #props.Options then
                nextIndex = (props.Loop ~= false) and 1 or #props.Options
            elseif nextIndex < 1 then
                nextIndex = (props.Loop ~= false) and #props.Options or 1
            end
            Flags.SetFlag(props.Flag, props.Options[nextIndex])
        end

        prevBtn.MouseButton1Click:Connect(function() move(-1) end)
        nextBtn.MouseButton1Click:Connect(function() move(1) end)

        return self
    end

    return { Card = Card, ProgressBar = ProgressBar, RadioGroup = RadioGroup, Stepper = Stepper, Cycle = Cycle }
end
