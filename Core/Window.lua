--[[
    Window shell, intro animation, window/tab methods — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 111-113, 1418-2295, 2301-3061 (2797-2799 seam-forwarded). The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Core/Window.lua
return function(Modules)
    -- Verbatim-body prelude (the only non-v1.9.4d code in this file): binds
    -- the monolith's file-local upvalues to the module system. The loader's
    -- shared table IS the facade, so `Library.X` below reads exactly like
    -- the v1.9.4d source; every extracted body is byte-identical to it.
    local Library = Modules
    local Render = Modules.Render
    local Themes = Modules.Theme.Themes
    local Theme = Modules.Theme.Theme
    local UserInputService = Render.UserInputService
    local TweenService = Render.TweenService
    local GuiService = Render.GuiService
    local PlayerGui = Render.PlayerGui
    local LocalPlayer = Render.LocalPlayer
    local isTouchDevice = Render.isTouchDevice
    local create = Render.create
    local corner = Render.corner
    local setSearchMeta = Render.setSearchMeta
    local stroke = Render.stroke
    local tween = Render.tween
    local hasChildLayout = Render.hasChildLayout
    local makeDraggable = Render.makeDraggable
    local startBreathingGlow = Render.startBreathingGlow
    local stopBreathingGlow = Render.stopBreathingGlow
    local ripple = Render.ripple
    local shiftZIndex = Render.shiftZIndex

-- ============ COMMAND HISTORY STATE (v1.9.4d lines 111-113) ============

Library.CommandHistory = {}
Library.MAX_COMMAND_HISTORY = 20
local commandIndex = 0

-- ============ WINDOW CREATION (lines 1418-2295, intro included) ============

function Library:CreateWindow(config)
    config = config or {}

    if Library.Flags.PerformanceMode then
        config.Intro = false
    end

    if not Library.Flags.ShowIntro then
        config.Intro = false
    end

    local windowName = config.Name or "UI Library"
    local guiName = config.GuiName or "MobileUILib"
    local windowPosition = config.Position or UDim2.new(0.5, 0, 0.5, 0)
    local subtitle = config.Subtitle
    local iconId = config.Icon
    if iconId and type(iconId) == "number" then
        iconId = "rbxassetid://" .. tostring(iconId)
    elseif iconId and type(iconId) == "string" and not iconId:match("^rbxassetid://") then
        iconId = "rbxassetid://" .. iconId
    end

    local preset = Themes[config.Theme] or Themes.Ocean
    for k, v in pairs(preset) do Theme[k] = v end
    Library._currentThemeName = Themes[config.Theme] and config.Theme or "Ocean"

    if #Library._themeHistory >= 5 then
        table.remove(Library._themeHistory, 1)
    end
    table.insert(Library._themeHistory, Library._currentThemeName)

    local existing = PlayerGui:FindFirstChild(guiName)
    if existing then existing:Destroy() end

    local screenGui = create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = false,
    })
    screenGui.Parent = PlayerGui

    local uiScale = create("UIScale", { Scale = 1 })

    local touch = isTouchDevice()
    local compact = Library.Flags.CompactMode
    local togglePosition = config.TogglePosition or UDim2.new(1, -(touch and 68 or 58), 0, 16)

    local mainSizeScale
    if compact then
        mainSizeScale = touch and UDim2.new(0.95, 0, 0.75, 0) or UDim2.new(0, 480, 0, 400)
    else
        mainSizeScale = touch and UDim2.new(0.92, 0, 0.82, 0) or UDim2.new(0, 560, 0, 460)
    end

    local main = create("Frame", {
        Name = "Main",
        Size = mainSizeScale,
        Position = windowPosition,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, { corner(16), stroke(), uiScale })
    main.Parent = screenGui

    local function applyAutoScale()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local scale = Library.Flags.UIScale or 1
        uiScale.Scale = math.clamp((viewport.Y / 720) * scale, 0.5, 1.5)
    end
    applyAutoScale()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyAutoScale)
    end

    local isLight = (preset == Themes.Light)

    main.BackgroundTransparency = isLight and 0.06 or 0.1
    if not Library.Flags.PerformanceMode then
        local glassSheen = create("Frame", {
            Name = "GlassSheen",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 1,
        }, { corner(16) })
        glassSheen.Parent = main
        create("UIGradient", {
            Rotation = 115,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.45, isLight and 0.82 or 0.9),
                NumberSequenceKeypoint.new(0.5, isLight and 0.6 or 0.75),
                NumberSequenceKeypoint.new(0.55, isLight and 0.82 or 0.9),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }).Parent = glassSheen
    end

    local headerHeight = touch and 50 or 40
    if subtitle then
        headerHeight = touch and 64 or 52
    end

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, headerHeight),
        BackgroundColor3 = Theme.Header,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, { corner(16) })
    header.Parent = main

    local titleOffset = 15
    if iconId then
        local iconSize = touch and 36 or 30
        local icon = create("ImageLabel", {
            Image = iconId,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, iconSize, 0, iconSize),
            Position = UDim2.new(0, 12, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 2,
        }, { corner(10) })
        icon.Parent = header
        icon:SetAttribute("MUI_NoTheme", true)
        titleOffset = 12 + iconSize + 8
    end

    local titleBox

    if subtitle then
        titleBox = create("TextBox", {
            Text = windowName,
            Font = Enum.Font.GothamBold,
            TextSize = touch and 17 or 14,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(titleOffset + 90), 0, touch and 22 or 18),
            Position = UDim2.new(0, titleOffset, 0, touch and 8 or 6),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 2,
        })
        titleBox.Parent = header

        create("TextLabel", {
            Text = subtitle,
            Font = Enum.Font.Gotham,
            TextSize = touch and 12 or 11,
            TextColor3 = Theme.SubText,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(titleOffset + 90), 0, touch and 16 or 14),
            Position = UDim2.new(0, titleOffset, 0, touch and 32 or 26),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        }).Parent = header
    else
        titleBox = create("TextBox", {
            Text = windowName,
            Font = Enum.Font.GothamBold,
            TextSize = touch and 18 or 15,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(titleOffset + 90), 1, 0),
            Position = UDim2.new(0, titleOffset, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 2,
        })
        titleBox.Parent = header
    end

    local minimizeBtn = create("TextButton", {
        Text = "—",
        Font = Enum.Font.GothamBold,
        TextSize = touch and 22 or 18,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(0, touch and 44 or 32, 0, touch and 44 or 32),
        Position = UDim2.new(1, touch and -52 or -38, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 2,
    }, { corner(12) })
    minimizeBtn.Parent = header

    local currentThemeName = isLight and "Light" or "Ocean"
    local themeBtn = create("TextButton", {
        Text = isLight and "🌙" or "☀",
        Font = Enum.Font.GothamBold,
        TextSize = touch and 18 or 15,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(0, touch and 44 or 32, 0, touch and 44 or 32),
        Position = UDim2.new(1, touch and -104 or -76, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 2,
    }, { corner(12) })
    themeBtn.Parent = header

    makeDraggable(header, main, true)

    local floatSize = touch and 52 or 42
    local floatBtn
    if iconId then
        floatBtn = create("ImageButton", {
            Name = "FloatToggle",
            Image = "",
            BackgroundColor3 = Theme.ToggleButton,
            Size = UDim2.new(0, floatSize, 0, floatSize),
            Position = togglePosition,
            ZIndex = 50,
        }, { corner(floatSize / 2), stroke(Theme.Accent, 1.5) })

        local floatIconSize = math.floor(floatSize * 0.72)
        local floatIcon = create("ImageLabel", {
            Name = "Icon",
            Image = iconId,
            ScaleType = Enum.ScaleType.Fit,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, floatIconSize, 0, floatIconSize),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 51,
        })
        floatIcon.Parent = floatBtn
        floatIcon:SetAttribute("MUI_NoTheme", true)
    else
        floatBtn = create("TextButton", {
            Name = "FloatToggle",
            Text = "☰",
            Font = Enum.Font.GothamBold,
            TextSize = touch and 22 or 18,
            TextColor3 = Theme.Text,
            BackgroundColor3 = Theme.ToggleButton,
            Size = UDim2.new(0, floatSize, 0, floatSize),
            Position = togglePosition,
            ZIndex = 50,
        }, { corner(floatSize / 2), stroke(Theme.Accent, 1.5) })
    end
    floatBtn.Parent = screenGui

    makeDraggable(floatBtn, floatBtn, false)

    floatBtn.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    local body = create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -headerHeight),
        Position = UDim2.new(0, 0, 0, headerHeight),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, {
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 6 or 12),
            PaddingBottom = UDim.new(0, compact and 6 or 12),
            PaddingLeft = UDim.new(0, compact and 4 or 8),
            PaddingRight = UDim.new(0, compact and 4 or 8),
        }),
    })
    body.Parent = main

    local tabList = create("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(touch and 0.32 or 0.28, 0, 1, 0),
        BackgroundColor3 = Theme.Header,
        BorderSizePixel = 0,
        ScrollBarThickness = touch and 6 or 4,
        ScrollBarImageColor3 = Theme.Accent,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, {
        corner(12),
        create("UIListLayout", {
            Padding = UDim.new(0, compact and 2 or 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, compact and 4 or 8),
            PaddingBottom = UDim.new(0, compact and 4 or 8),
            PaddingLeft = UDim.new(0, compact and 4 or 8),
            PaddingRight = UDim.new(0, compact and 4 or 8),
        }),
    })
    tabList.Parent = body

    local pages = create("Frame", {
        Name = "Pages",
        Size = UDim2.new(1 - (touch and 0.32 or 0.28), 0, 1, 0),
        Position = UDim2.new(touch and 0.32 or 0.28, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    })
    pages.Parent = body

    local minimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        tween(main, { Size = minimized and UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, headerHeight) or mainSizeScale }, 0.2)
        body.Visible = not minimized
    end)

    local notifHolder = create("Frame", {
        Name = "NotifHolder",
        Size = UDim2.new(0, touch and 280 or 260, 1, -20),
        Position = UDim2.new(1, -16, 1, -10),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
		ZIndex = 150,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    notifHolder.Parent = screenGui

    local spotlightOverlay = create("Frame", {
        Name = "Spotlight",
        Size = body.Size,
        Position = body.Position,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 5,
    })
    spotlightOverlay.Parent = main

    local Window = setmetatable({
        _screenGui = screenGui,
        _main = main,
        _tabList = tabList,
        _pages = pages,
        _tabs = {},
        _touch = touch,
        _firstTab = true,
        _notifHolder = notifHolder,
        _notifCount = 0,
        _currentPageEntry = nil,
        _spotlightOverlay = spotlightOverlay,
        _spotlightCount = 0,
        _animationSpeed = 1.0,
        _shadowEnabled = false,
        _blurAmount = 0,
        _commands = {
            ["t-notif"] = function(w)
                w:Notify({ Title = "Test Notification", Content = "This is a test notification.", Type = "info" })
            end,
            ["theme"] = function(w, argString)
                local theme = argString:match("^(%S+)")
                if theme and Themes[theme] then
                    w:SetTheme(theme)
                    w:Notify({ Title = "Theme", Content = "Switched to " .. theme, Type = "success" })
                else
                    local themes = {}
                    for name in pairs(Themes) do
                        table.insert(themes, name)
                    end
                    w:Notify({ Title = "Themes", Content = "Available: " .. table.concat(themes, ", "), Type = "info" })
                end
            end,
            ["save"] = function(w, argString)
                local name = argString ~= "" and argString or "default"
                local success = Library:SaveConfig(name)
                if success then
                    w:Notify({ Title = "Config Saved", Content = "Saved as '" .. name .. "'", Type = "success" })
                else
                    w:Notify({ Title = "Error", Content = "Failed to save config", Type = "error" })
                end
            end,
            ["load"] = function(w, argString)
                local name = argString ~= "" and argString or "default"
                local success = Library:LoadConfig(name, w)
                if success then
                    w:Notify({ Title = "Config Loaded", Content = "Loaded '" .. name .. "'", Type = "success" })
                else
                    w:Notify({ Title = "Error", Content = "Failed to load config", Type = "error" })
                end
            end,
            ["list"] = function(w)
                local configs = Library:ListConfigs()
                if #configs > 0 then
                    w:Notify({ Title = "Configs", Content = table.concat(configs, ", "), Type = "info" })
                else
                    w:Notify({ Title = "Configs", Content = "No saved configs", Type = "info" })
                end
            end,
            ["minimize"] = function(w)
                minimized = not minimized
                tween(main, { Size = minimized and UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, headerHeight) or mainSizeScale }, 0.2)
                body.Visible = not minimized
            end,
            ["export"] = function(w)
                local json = Library:ExportConfig()

                if not json or json == "" then
                    json = "{}"
                end

                local popup = create("Frame", {
                    Size = UDim2.new(0, 400, 0, 300),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Theme.Header,
                    ZIndex = 201,
                }, { corner(14), stroke(Theme.Accent, 1.5) })
                popup.Parent = screenGui

                create("TextLabel", {
                    Text = "Export Config",
                    Font = Enum.Font.GothamBold,
                    TextSize = 16,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 30),
                    Position = UDim2.new(0, 0, 0, 8),
                }).Parent = popup

                local scrollFrame = create("ScrollingFrame", {
                    Size = UDim2.new(1, -20, 1, -70),
                    Position = UDim2.new(0, 10, 0, 40),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 6,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                }, { corner(8) })
                scrollFrame.Parent = popup

                local textBox = create("TextBox", {
                    Text = json,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    MultiLine = true,
                    ClearTextOnFocus = false,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                })
                textBox.Parent = scrollFrame

                local copyBtn = create("TextButton", {
                    Text = "📋 Copy",
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Accent,
                    Size = UDim2.new(0, 70, 0, 28),
                    Position = UDim2.new(1, -80, 1, -38),
                }, { corner(8) })
                copyBtn.Parent = popup
                copyBtn.MouseButton1Click:Connect(function()
                    local copyPopup = create("Frame", {
                        Size = UDim2.new(0, 380, 0, 80),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Theme.Header,
                        ZIndex = 300,
                    }, { corner(14), stroke(Theme.Accent, 1.5) })
                    copyPopup.Parent = screenGui

                    create("TextLabel", {
                        Text = "Select and copy the text below:",
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextColor3 = Theme.SubText,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, -20, 0, 20),
                        Position = UDim2.new(0, 10, 0, 8),
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }).Parent = copyPopup

                    local copyBox = create("TextBox", {
                        Text = json,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextColor3 = Theme.Text,
                        BackgroundColor3 = Theme.Element,
                        Size = UDim2.new(1, -20, 0, 30),
                        Position = UDim2.new(0, 10, 0, 32),
                        MultiLine = true,
                        ClearTextOnFocus = false,
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, { corner(6) })
                    copyBox.Parent = copyPopup

                    local closeCopyBtn = create("TextButton", {
                        Text = "Close",
                        Font = Enum.Font.GothamBold,
                        TextSize = 12,
                        TextColor3 = Theme.Text,
                        BackgroundColor3 = Theme.Accent,
                        Size = UDim2.new(0, 60, 0, 24),
                        Position = UDim2.new(0.5, -30, 1, -30),
                    }, { corner(6) })
                    closeCopyBtn.Parent = copyPopup
                    closeCopyBtn.MouseButton1Click:Connect(function()
                        copyPopup:Destroy()
                    end)
                end)

                local closeBtn = create("TextButton", {
                    Text = "Close",
                    Font = Enum.Font.GothamBold,
                    TextSize = 14,
                    TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Accent,
                    Size = UDim2.new(0, 70, 0, 28),
                    Position = UDim2.new(0.5, -35, 1, -38),
                }, { corner(8) })
                closeBtn.Parent = popup
                closeBtn.MouseButton1Click:Connect(function()
                    popup:Destroy()
                end)
            end,
            ["screenshot"] = function(w)
                local success = false
                if type(GuiService.CaptureScreenshot) == "function" then
                    success = pcall(function() GuiService:CaptureScreenshot() end)
                end
                if success then
                    w:Notify({ Title = "Screenshot", Content = "Captured!", Type = "success" })
                else
                    w:Notify({ Title = "Screenshot", Content = "Not supported in this executor", Type = "warning" })
                end
            end,
            ["help"] = function(w)
                local cmds = {}
                for cmd in pairs(w._commands) do
                    table.insert(cmds, cmd)
                end
                for cmd in pairs(Cornelius.Commands) do
                    table.insert(cmds, "/cornelius " .. cmd)
                end
                w:Notify({ Title = "Commands", Content = "Available: " .. table.concat(cmds, ", "), Type = "info" })
            end,
            ["reset"] = function(w)
                w:Notify({ Title = "Reset", Content = "Are you sure? Type 'reset confirm' to proceed", Type = "warning" })
                w._pendingReset = true
                task.delay(10, function()
                    w._pendingReset = false
                end)
            end,
            ["reset confirm"] = function(w)
                if w._pendingReset then
                    for name in pairs(Library.Flags) do
                        Library:SetFlag(name, nil)
                    end
                    w:Notify({ Title = "Reset", Content = "All flags reset to default", Type = "success" })
                    w._pendingReset = false
                end
            end,
            ["cornelius"] = function(w, argString)
                Cornelius:HandleCommand(w, "/cornelius " .. (argString or ""))
            end,
        },
    }, { __index = Library.WindowMethods })

    Cornelius._window = Window

    titleBox.Focused:Connect(function()
        titleBox.Text = ""
    end)

    titleBox.FocusLost:Connect(function()
        local raw = titleBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if raw ~= "" then
            if raw:match("^/cornelius") then
                Cornelius:HandleCommand(Window, raw)
                titleBox.Text = windowName
                return
            end

            table.insert(Library.CommandHistory, raw)
            if #Library.CommandHistory > Library.MAX_COMMAND_HISTORY then
                table.remove(Library.CommandHistory, 1)
            end
            commandIndex = #Library.CommandHistory

            local words = {}
            for word in raw:gmatch("%S+") do
                table.insert(words, word)
            end
            local cmd = table.remove(words, 1):lower()
            local action = Window._commands[cmd]
            if action then
                local argString = table.concat(words, " ")
                local ok, err = pcall(action, Window, argString, words)
                if not ok then warn("[MobileUILib] Command palette error: " .. tostring(err)) end
            else
                local suggestions = {}
                for c in pairs(Window._commands) do
                    if c:find(cmd, 1, true) then
                        table.insert(suggestions, c)
                    end
                end
                if #suggestions > 0 then
                    Window:Notify({ Title = "Command Not Found", Content = "Did you mean: " .. table.concat(suggestions, ", "), Type = "warning" })
                else
                    Window:Notify({ Title = "Command Not Found", Content = "Type 'help' for available commands", Type = "error" })
                end
            end
        end
        titleBox.Text = windowName
    end)

    titleBox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Up then
            if #Library.CommandHistory > 0 then
                commandIndex = math.max(1, commandIndex - 1)
                titleBox.Text = Library.CommandHistory[commandIndex]
                titleBox.CursorPosition = #titleBox.Text
            end
        elseif input.KeyCode == Enum.KeyCode.Down then
            if commandIndex < #Library.CommandHistory then
                commandIndex = commandIndex + 1
                titleBox.Text = Library.CommandHistory[commandIndex]
                titleBox.CursorPosition = #titleBox.Text
            else
                commandIndex = #Library.CommandHistory
                titleBox.Text = ""
            end
        end
    end)

    themeBtn.MouseButton1Click:Connect(function()
        local themes = {"Ocean", "Dark", "Light", "Amethyst", "Ruby", "Frost", "Candy", "Midnight", "Cyber"}
        local idx = 1
        for i, t in ipairs(themes) do
            if t == currentThemeName then
                idx = i % #themes + 1
                break
            end
        end
        currentThemeName = themes[idx]
        themeBtn.Text = (currentThemeName == "Light") and "🌙" or "☀"
        Window:SetTheme(currentThemeName)
    end)

    if Library.Flags.AutoSaveInterval and Library.Flags.AutoSaveInterval > 0 then
        task.spawn(function()
            while main.Parent do
                task.wait(Library.Flags.AutoSaveInterval)
                pcall(function() Library:SaveConfig("autosave") end)
            end
        end)
    end

    -- ============================================================
    -- INTRO ANIMATION
    -- ============================================================

    if Library.Flags.ReducedMotion or not Library.Flags.ShowIntro then
        return Window
    end

    local introConfig = config.Intro or {}
    local introImage = introConfig.Image
    if introImage == nil then
        introImage = 80406291512141
    elseif introImage == false then
        introImage = nil
    end
    if introImage and type(introImage) == "number" then
        introImage = "rbxassetid://" .. tostring(introImage)
    elseif introImage and type(introImage) == "string" and not introImage:match("^rbxassetid://") then
        introImage = "rbxassetid://" .. introImage
    end
    local introText = introConfig.Text or "-By Lifeless"
    local introHold = introConfig.Duration or 1.4
    local normalIntroTooltips = {
        "Tip: click the hub name to open the command palette.",
        "Tip: click the floating button to hide or restore the hub.",
        "Tip: use the theme button to switch between light and dark mode.",
        "Tip: settings with a Flag can be saved and restored with configs.",
        "Tip: tabs and the hub window can be dragged on desktop and touch.",
        "Create your own themes! using the gradient feature",
        "tired of a new key daily, get a weekly key now!",
        "Type 'help' to see all commands!",
        "Type 'export' to share your config!",
        "Type '/cornelius help' to see Cornelius commands!",
    }
    local funnyIntroTooltips = {
        "Downloading more RAM...",
        "Cleaning the toilet...",
        "C:????????????????????????: Something happened.",
        "Teaching the corn how to code...",
        "Convincing the buttons to behave...",
        "Calibrating the cat launcher...",
        "gooning....Wait",
        "Yes i used claude for debugging, SMD if you have problem",
        "Alt+F4 gives free bobux",
        "v1.9.3 - Stable Release",
        "Type 'screenshot' for free photos",
        "Cornelius is watching...",
    }
    local introTooltips = introConfig.Funny == true and funnyIntroTooltips or normalIntroTooltips
    local lastIntroTooltip
    local function nextIntroTooltip()
        if #introTooltips == 1 then return introTooltips[1] end
        local tooltip
        repeat
            tooltip = introTooltips[math.random(1, #introTooltips)]
        until tooltip ~= lastIntroTooltip
        lastIntroTooltip = tooltip
        return tooltip
    end

    local introBg = isLight and Color3.fromRGB(250, 250, 252) or Color3.fromRGB(0, 0, 0)
    local introLineColor = isLight and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(255, 255, 255)
    local introTextColor = Color3.fromRGB(255, 196, 48)

    local introOverlay = create("Frame", {
        Name = "IntroOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 300,
        Active = true,
    })
    introOverlay.Parent = screenGui

    local skipBtn = create("TextButton", {
        Text = "Skip",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(150, 150, 150),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 60, 0, 30),
        Position = UDim2.new(1, -80, 1, -50),
        ZIndex = 303,
    })
    skipBtn.Parent = introOverlay
    skipBtn.MouseButton1Click:Connect(function()
        introOverlay:Destroy()
    end)

    local wipe = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = introBg,
        BorderSizePixel = 0,
        ZIndex = 300,
    })
    wipe.Parent = introOverlay

    local introHolder = create("Frame", {
        Size = UDim2.new(0, 280, 0, 260),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 302,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 16),
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    introHolder.Parent = introOverlay

    local introImgLabel
    if introImage then
        introImgLabel = create("ImageLabel", {
            Image = introImage,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            Size = UDim2.new(0, 140, 0, 140),
            ZIndex = 302,
        })
        introImgLabel.Parent = introHolder
    end

    local introTextLabel = create("TextLabel", {
        Text = introText,
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextColor3 = introTextColor,
        TextTransparency = 1,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32),
        ZIndex = 302,
    })
    introTextLabel.Parent = introHolder

    local introTooltipLabel = create("TextLabel", {
        Name = "Tooltip",
        Text = nextIntroTooltip(),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = isLight and Color3.fromRGB(85, 85, 92) or Color3.fromRGB(190, 190, 198),
        TextTransparency = 1,
        TextWrapped = true,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 38),
        ZIndex = 302,
    })
    introTooltipLabel.Parent = introHolder

    task.spawn(function()
        tween(wipe, { Size = UDim2.new(1, 0, 1, 0) }, 0.5)
        task.wait(0.5)

        if introImgLabel then
            tween(introImgLabel, { ImageTransparency = 0 }, 0.5)
            task.wait(0.3)
        end
        tween(introTextLabel, { TextTransparency = 0 }, 0.5)
        tween(introTooltipLabel, { TextTransparency = 0 }, 0.5)

        local elapsed = 0
        while elapsed < introHold do
            local waitTime = math.min(2, introHold - elapsed)
            task.wait(waitTime)
            elapsed = elapsed + waitTime
            if elapsed < introHold then
                introTooltipLabel.Text = nextIntroTooltip()
            end
        end

        tween(introTextLabel, { TextTransparency = 1 }, 0.3)
        tween(introTooltipLabel, { TextTransparency = 1 }, 0.3)
        if introImgLabel then tween(introImgLabel, { ImageTransparency = 1 }, 0.3) end
        task.wait(0.3)

        wipe.Visible = false

        local topHalf = create("Frame", {
            Size = UDim2.new(1, 0, 0.5, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = introBg,
            BorderSizePixel = 0,
            ZIndex = 300,
        })
        topHalf.Parent = introOverlay

        local bottomHalf = create("Frame", {
            Size = UDim2.new(1, 0, 0.5, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = introBg,
            BorderSizePixel = 0,
            ZIndex = 300,
        })
        bottomHalf.Parent = introOverlay

        local centerLine = create("Frame", {
            Size = UDim2.new(1, 0, 0, 3),
            Position = UDim2.new(0, 0, 0.5, -1),
            BackgroundColor3 = introLineColor,
            BorderSizePixel = 0,
            ZIndex = 301,
        })
        centerLine.Parent = introOverlay

        tween(topHalf, { Position = UDim2.new(0, 0, -0.5, 0) }, 0.55)
        tween(bottomHalf, { Position = UDim2.new(0, 0, 1, 0) }, 0.55)
        tween(centerLine, { BackgroundTransparency = 1 }, 0.4)

        task.wait(0.6)
        introOverlay:Destroy()
    end)

    return Window
end

-- ============ WINDOW METHODS (lines 2301-2795) ============

Library.WindowMethods = {}
local WM = Library.WindowMethods

-- ============================================================
-- NOTIFY (FIXED: Proper sizing with clipping)
-- ============================================================

function WM:Notify(config)
    config = config or {}
    local touch = self._touch
    local title = config.Title or "Notification"
    local content = config.Content or ""
    local duration = config.Duration or 4
    local notifType = config.Type

    local typeColors = {
        success = Color3.fromRGB(70, 200, 110),
        error = Color3.fromRGB(230, 75, 75),
        warning = Color3.fromRGB(255, 175, 45),
        info = Theme.Accent,
    }
    local typeIcons = {
        success = "✓",
        error = "✕",
        warning = "!",
        info = "i",
    }
    local barColor = typeColors[notifType] or Theme.Accent
    local iconChar = typeIcons[notifType]

    self._notifCount += 1

    -- ✅ FIXED: Create() includes ALL children, including UISizeConstraint
    local notif = create("Frame", {
    Name = "Notification",
    Size = UDim2.new(0, touch and 300 or 360, 0, 70),
    BackgroundColor3 = Theme.Header,
    BackgroundTransparency = 1,
    LayoutOrder = self._notifCount,
    ZIndex = 150,
    ClipsDescendants = true,
}, {
    corner(12),
    stroke(barColor, 1),

    create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }),

    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

notif.Parent = self._notifHolder

    -- Title row
    local titleRow = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
    }, {
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    titleRow.Parent = notif

    if iconChar then
        local iconLabel = create("TextLabel", {
            Text = iconChar,
            Font = Enum.Font.GothamBold,
            TextSize = touch and 15 or 13,
            TextColor3 = barColor,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 16, 1, 0),
            TextTransparency = 1,
            ZIndex = 151,
        })
        iconLabel.Parent = titleRow
        tween(iconLabel, { TextTransparency = 0 }, 0.2)
    end

    local titleLabel = create("TextLabel", {
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = touch and 16 or 14,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, iconChar and -22 or 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextTransparency = 1,
        ZIndex = 151,
    })
    titleLabel.Parent = titleRow

    local contentLabel = create("TextLabel", {
        Text = content,
        Font = Enum.Font.Gotham,
        TextSize = touch and 14 or 12,
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTransparency = 1,
        LayoutOrder = 2,
        ZIndex = 151,
    })
    contentLabel.Parent = notif

    -- Progress bar
    local progressColor = typeColors[notifType] or Color3.fromRGB(140, 140, 148)
    local progressTrack = create("Frame", {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        ZIndex = 151,
    }, { corner(2) })
    progressTrack.Parent = notif

    local progressBar = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = progressColor,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 152,
    }, { corner(2) })
    progressBar.Parent = progressTrack   
 

    -- ✅ Fade in
    tween(notif, { BackgroundTransparency = 0 }, 0.2)
    tween(titleLabel, { TextTransparency = 0 }, 0.2)
    tween(contentLabel, { TextTransparency = 0 }, 0.2)
    tween(progressTrack, { BackgroundTransparency = 0.7 }, 0.2)
    tween(progressBar, { BackgroundTransparency = 0 }, 0.2)

    -- Animate progress bar
    TweenService:Create(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) }):Play()

    -- Auto‑dismiss
    task.delay(duration, function()
        if notif and notif.Parent then
            tween(notif, { BackgroundTransparency = 1 }, 0.25)
            tween(titleLabel, { TextTransparency = 1 }, 0.25)
            tween(contentLabel, { TextTransparency = 1 }, 0.25)
            tween(progressTrack, { BackgroundTransparency = 1 }, 0.25)
            tween(progressBar, { BackgroundTransparency = 1 }, 0.25)
            task.delay(0.3, function()
                if notif then notif:Destroy() end
            end)
        end
    end)
end
-- ============================================================
-- WINDOW: SET THEME
-- ============================================================

function WM:SetTheme(name)
    local newPreset = Themes[name]
    if not newPreset then return end

    Library._currentThemeName = name

    if #Library._themeHistory >= 5 then
        table.remove(Library._themeHistory, 1)
    end
    table.insert(Library._themeHistory, name)

    local reverseMap = {}
    for k, v in pairs(Theme) do reverseMap[tostring(v)] = k end

    for _, inst in ipairs(self._screenGui:GetDescendants()) do
        if inst:IsA("GuiObject") then
            local ok, bg = pcall(function() return inst.BackgroundColor3 end)
            if ok then
                local key = reverseMap[tostring(bg)]
                if key and newPreset[key] then
                    tween(inst, { BackgroundColor3 = newPreset[key] }, 0.35)
                end
            end
            if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                local key2 = reverseMap[tostring(inst.TextColor3)]
                if key2 and newPreset[key2] then
                    tween(inst, { TextColor3 = newPreset[key2] }, 0.35)
                end
            end
            if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and not inst:GetAttribute("MUI_NoTheme") then
                local key3 = reverseMap[tostring(inst.ImageColor3)]
                if key3 and newPreset[key3] then
                    tween(inst, { ImageColor3 = newPreset[key3] }, 0.35)
                end
            end
        elseif inst:IsA("UIStroke") then
            local key4 = reverseMap[tostring(inst.Color)]
            if key4 and newPreset[key4] then
                tween(inst, { Color = newPreset[key4] }, 0.35)
            end
        end
    end

    for k, v in pairs(newPreset) do Theme[k] = v end
end

-- ============================================================
-- WINDOW: SET THEME COLOR
-- ============================================================

local THEME_EDITOR_KEYS = { Background = true, ToggleButton = true }

function WM:SetThemeColor(key, color)
    if not THEME_EDITOR_KEYS[key] then return end
    local oldColor = Theme[key]
    if not oldColor then return end

    for _, inst in ipairs(self._screenGui:GetDescendants()) do
        if inst:IsA("GuiObject") then
            local ok, bg = pcall(function() return inst.BackgroundColor3 end)
            if ok and bg == oldColor then
                inst.BackgroundColor3 = color
            end
            if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and not inst:GetAttribute("MUI_NoTheme") then
                if inst.ImageColor3 == oldColor then
                    inst.ImageColor3 = color
                end
            end
        elseif inst:IsA("UIStroke") then
            if inst.Color == oldColor then
                inst.Color = color
            end
        end
    end

    Theme[key] = color
end

-- ============================================================
-- WINDOW: SET BACKGROUND
-- ============================================================

function WM:SetBackground(input)
    local config = type(input) == "table" and input or { Texture = input }

    local texture = config.Texture or config.Source or config.Image
    if type(texture) == "number" then
        texture = "rbxassetid://" .. tostring(texture)
    end
    if type(texture) ~= "string" then
        warn("[MobileUILib] SetBackground requires a Texture/source string or numeric asset id")
        return
    end

    texture = texture:gsub("^%s+", ""):gsub("%s+$", "")
    if texture == "" then
        warn("[MobileUILib] SetBackground requires a non-empty image source")
        return
    end

    local lower = texture:lower()
    if not (lower:match("^rbxassetid://") or lower:match("^rbxasset://")) then
        local looksLikeImage = lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$") or lower:match("%.gif$") or lower:match("%.img$")
        if looksLikeImage and type(getcustomasset) == "function" then
            local ok, resolved = pcall(getcustomasset, texture)
            if ok and type(resolved) == "string" and resolved ~= "" then
                texture = resolved
            end
        end
    end

    self:ClearBackground()

    local kind = config.Type or "Image"
    local bg
    if kind == "Video" then
        bg = create("VideoFrame", {
            Name = "MUI_Background",
            Video = texture,
            Looped = true,
            Playing = true,
            Volume = config.Volume or 0,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 0,
        }, { corner(16) })
    else
        bg = create("ImageLabel", {
            Name = "MUI_Background",
            Image = texture,
            ScaleType = config.ScaleType or Enum.ScaleType.Crop,
            TileSize = config.TileSize or UDim2.new(0, 128, 0, 128),
            ImageTransparency = config.Transparency or config.ImageTransparency or 0,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 0,
        }, { corner(16) })
    end
    bg:SetAttribute("MUI_NoTheme", true)
    bg.Parent = self._main

    self._background = bg
    return bg
end

function WM:ClearBackground()
    if self._background then
        self._background:Destroy()
        self._background = nil
    end
end

-- ============================================================
-- WINDOW: SET SKIN
-- ============================================================
-- Applies a Skin registered via Library:RegisterSkin. See the "SKIN
-- SYSTEM" comment block near the top of the file for the full shape and
-- the stated scope of what AccentTexture currently reaches.
function WM:SetSkin(name)
    local skin = Library.Skins[name]
    if not skin then
        warn("[MobileUILib] SetSkin: no skin registered as '" .. tostring(name) .. "'")
        return
    end

    -- 1. Accent + Selected-option texture passes FIRST, while Theme still
    -- holds the OLD/current values — SetTheme (step 2) only mutates Theme
    -- in place at the very end of its own run, so this is the same
    -- "compare against what's still on screen right now" trick SetTheme
    -- itself uses for colors, just for these two attribute-tagged layers.
    Library._currentAccentTexture = skin.AccentTexture
    Library._currentSelectedTexture = skin.SelectedOptionTexture
    Library._currentAccentTextureTransparency = skin.AccentTextureTransparency or 0.25
    Library._currentSelectedTextureTransparency = skin.SelectedOptionTextureTransparency or 0.25
    for _, inst in ipairs(self._screenGui:GetDescendants()) do
        if inst:IsA("GuiObject") then
            local ok, bg = pcall(function() return inst.BackgroundColor3 end)
            local isAccentColored = ok and tostring(bg) == tostring(Theme.Accent)

            if inst:GetAttribute("MUI_AccentSurface") then
                Library:_applyAccentOverlay(inst, isAccentColored)
            end
            if inst:GetAttribute("MUI_SelectedSurface") then
                Library:_applySelectedOverlay(inst, isAccentColored)
            end
        end
    end

    -- 2. Whole-UI texture pass — every currently-on-screen surface whose
    -- fill is one of the "container" theme colors (header bar, sidebar,
    -- panels, cards) gets the overlay, NOT just attribute-tagged ones.
    -- Unlike AccentTexture/SelectedOptionTexture this needs no per-element
    -- tagging: virtually every Frame in this file is colored directly from
    -- one of these Theme keys at creation, so a plain color-match already
    -- catches everything currently visible. Deliberately excludes Accent
    -- (that's AccentTexture/SelectedOptionTexture's job) and Text/SubText/
    -- Stroke (texturing a text color or a 1px border isn't meaningful).
    local SURFACE_KEYS = { "Background", "Header", "Element", "ElementHover", "ToggleButton" }
    local surfaceColorSet = {}
    for _, key in ipairs(SURFACE_KEYS) do
        surfaceColorSet[tostring(Theme[key])] = true
    end
    local windowTextureApplied, windowTextureSkippedLayout = 0, 0
    for _, inst in ipairs(self._screenGui:GetDescendants()) do
        if inst:IsA("GuiObject") and inst.Name ~= "MUI_WindowTexture" then
            local ok, bg = pcall(function() return inst.BackgroundColor3 end)
            local isSurface = ok and surfaceColorSet[tostring(bg)]
            if isSurface and skin.WindowTexture then
                if hasChildLayout(inst) then
                    windowTextureSkippedLayout += 1
                else
                    windowTextureApplied += 1
                end
            end
            Library:_applyTiledOverlay(inst, "MUI_WindowTexture", isSurface, skin.WindowTexture, skin.WindowTextureTransparency or 0.12)
        end
    end
    if skin.WindowTexture then
        print("[MobileUILib] SetSkin: WindowTexture applied to " .. windowTextureApplied .. " surface(s), skipped " .. windowTextureSkippedLayout .. " (layout-managed)")
    end

    -- 3. Colors — delegate entirely to the existing theme machinery so
    -- color-swapping behavior doesn't change at all.
    if type(skin.Theme) == "string" then
        self:SetTheme(skin.Theme)
    elseif type(skin.Theme) == "table" then
        Library:RegisterTheme("__skin_" .. name, skin.Theme)
        self:SetTheme("__skin_" .. name)
    end

    -- 4. Fonts — same reverse-lookup trick SetTheme uses for colors, but
    -- keyed on Font instead of Color3. Every label/button/textbox in this
    -- file only ever uses a small handful of Enum.Font values
    -- (Gotham/GothamMedium/GothamBold), so this needs no per-element
    -- tagging to work. Tries FontFace (the modern custom-font datatype)
    -- first, falls back to legacy Font for values that are plain
    -- Enum.Font entries rather than Font.new(...) objects.
    if skin.Fonts then
        local fontMap = {
            [tostring(Enum.Font.GothamBold)] = skin.Fonts.Header,
            [tostring(Enum.Font.GothamMedium)] = skin.Fonts.Accent,
            [tostring(Enum.Font.Gotham)] = skin.Fonts.Body,
        }
        for _, inst in ipairs(self._screenGui:GetDescendants()) do
            if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                local newFont = fontMap[tostring(inst.Font)]
                if newFont then
                    local success, err = pcall(function()
                        inst.FontFace = newFont -- Custom Font datatype
                    end)
                    if not success then
                        local fallbackSuccess = pcall(function()
                            inst.Font = newFont -- Legacy Enum.Font fallback
                        end)
                        if not fallbackSuccess then
                            warn("[MobileUILib] Failed to apply font to " .. inst:GetFullName() .. ": " .. tostring(err))
                        end
                    end
                end
            end
        end
    end

    -- 5. Window BACKGROUND texture — reuses SetBackground wholesale
    -- (tiled, dulled by default) instead of a second parallel image-overlay
    -- system. This is what used to be called WindowTexture. Only touches
    -- the background if this skin actually specifies one — an unrelated
    -- background set independently is left alone otherwise.
    if skin.WindowBGTexture then
        self:SetBackground({
            Texture = skin.WindowBGTexture,
            Type = "Image",
            ScaleType = Enum.ScaleType.Tile,
            Transparency = skin.WindowBGTextureTransparency or 0.85,
        })
    end

    Library._currentSkinName = name
end

-- ============================================================
-- WINDOW: COMMANDS
-- ============================================================

function WM:RegisterCommand(keyword, fn)
    self._commands[tostring(keyword):lower()] = fn
end

function WM:SetSpotlight(active)
    if active then
        self._spotlightCount += 1
    else
        self._spotlightCount = math.max(0, self._spotlightCount - 1)
    end
    local shouldShow = self._spotlightCount > 0
    self._spotlightOverlay.Active = shouldShow
    tween(self._spotlightOverlay, { BackgroundTransparency = shouldShow and 0.5 or 1 }, 0.2)
end

function WM:SetCornerRadius(radius)
    local main = self._main
    local corners = main:FindFirstChild("UICorner")
    if corners then
        corners.CornerRadius = UDim.new(0, radius)
    end

    for _, child in ipairs(main:GetDescendants()) do
        if child:IsA("UICorner") then
            child.CornerRadius = UDim.new(0, radius)
        end
    end
end

function WM:SetOpacity(transparency)
    local main = self._main
    if transparency >= 0 and transparency <= 1 then
        main.BackgroundTransparency = transparency
    end
end

function WM:GetActiveTab()
    return self._currentPageEntry
end

-- (seam) v1.9.4d lines 2797-2799 set the file-local `animationSpeed`

-- directly; that local lives in Render now, so this forwards. Behavior

-- identical, one line adapted:

function WM:SetAnimationSpeed(factor)

    Render.SetAnimationSpeed(factor)

end

-- ============ WINDOW METHODS cont. (lines 2801-3061) ============

function WM:SetBlur(amount)
    self._blurAmount = math.clamp(amount, 0, 1)
    local main = self._main
    if amount > 0 then
        main.BackgroundTransparency = math.min(main.BackgroundTransparency + amount * 0.3, 0.95)
    else
        main.BackgroundTransparency = 0.1
    end
end

function WM:SetShadow(enable)
    self._shadowEnabled = enable
    local main = self._main
    local shadow = main:FindFirstChild("_Shadow")
    if enable then
        if not shadow then
            shadow = create("Frame", {
                Name = "_Shadow",
                Size = UDim2.new(1, 0, 1, 0),
                Position = UDim2.new(0, 3, 0, 3),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.7,
                BorderSizePixel = 0,
                ZIndex = -1,
            }, { corner(16) })
            shadow.Parent = main
        end
    else
        if shadow then shadow:Destroy() end
    end
end

function WM:ExportConfig(name)
    return Library:ExportConfig(name)
end

function WM:ImportConfig(jsonText)
    return Library:ImportConfig(jsonText, self)
end

-- ============================================================
-- WINDOW: CREATE TAB
-- ============================================================

function WM:CreateTab(name, config)
    config = config or {}
    local touch = self._touch
    local iconId = config.Icon
    if iconId and type(iconId) == "number" then
        iconId = "rbxassetid://" .. tostring(iconId)
    elseif iconId and type(iconId) == "string" and not iconId:match("^rbxassetid://") then
        iconId = "rbxassetid://" .. iconId
    end

    local tabButton = create("TextButton", {
        Text = "",
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(1, 0, 0, touch and 40 or 30),
        AutoButtonColor = false,
    }, { corner(10) })
    tabButton.Parent = self._tabList
    tabButton:SetAttribute("MUI_SelectedSurface", true) -- eligible for a Skin's SelectedOptionTexture while this tab is active

    local contentRow = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, {
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
    })
    contentRow.Parent = tabButton

    local iconLabel
    if iconId then
        local iconSize = touch and 20 or 16
        iconLabel = create("ImageLabel", {
            Image = iconId,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, iconSize, 0, iconSize),
            ImageColor3 = Theme.SubText,
            ScaleType = Enum.ScaleType.Fit,
        })
        iconLabel.Parent = contentRow
    end

    local tabLabel = create("TextLabel", {
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = touch and 15 or 13,
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, iconId and -34 or -10, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    tabLabel.Parent = contentRow

    local page = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = touch and 6 or 4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
        }),
    })
    page.Parent = self._pages

    local Tab = setmetatable({
        _page = page,
        _touch = touch,
        _window = self,
        _screenGui = self._screenGui,
        _tabIndex = #self._tabs + 1,
    }, { __index = Library.TabMethods })

    local tabEntry = { button = tabButton, page = page, label = tabLabel, icon = iconLabel, glow = nil, glowTween = nil }
    table.insert(self._tabs, tabEntry)

    local function selectTab()
        if self._currentPageEntry == tabEntry then return end

        for _, t in pairs(self._tabs) do
            if t ~= tabEntry then
                tween(t.button, { BackgroundColor3 = Theme.Element }, 0.1)
                tween(t.label, { TextColor3 = Theme.SubText }, 0.1)
                if t.icon then tween(t.icon, { ImageColor3 = Theme.SubText }, 0.1) end
                if t.glow then
                    stopBreathingGlow(t.glow, t.glowTween)
                    t.glow, t.glowTween = nil, nil
                end
                Library:_applySelectedOverlay(t.button, false)
            end
        end

        tween(tabButton, { BackgroundColor3 = Theme.Accent }, 0.1)
        tween(tabLabel, { TextColor3 = Theme.TextOnAccent }, 0.1)
        if iconLabel then tween(iconLabel, { ImageColor3 = Theme.TextOnAccent }, 0.1) end
        tabEntry.glow, tabEntry.glowTween = startBreathingGlow(tabButton, Theme.Accent)
        Library:_applySelectedOverlay(tabButton, true)

        local previousEntry = self._currentPageEntry
        if previousEntry and previousEntry.page ~= page then
            local oldPage = previousEntry.page
            oldPage.Position = UDim2.new(0, 0, 0, 0)
            page.Position = UDim2.new(1, 0, 0, 0)
            page.Visible = true
            tween(oldPage, { Position = UDim2.new(-1, 0, 0, 0) }, 0.25)
            tween(page, { Position = UDim2.new(0, 0, 0, 0) }, 0.25)
            task.delay(0.25, function()
                oldPage.Visible = false
                oldPage.Position = UDim2.new(0, 0, 0, 0)
            end)
        else
            page.Position = UDim2.new(0, 0, 0, 0)
            page.Visible = true
        end

        self._currentPageEntry = tabEntry
    end

    tabButton.MouseButton1Click:Connect(selectTab)

    tabButton.MouseEnter:Connect(function()
        if self._currentPageEntry ~= tabEntry and not tabButton:FindFirstChild("_HoverGlow") then
            create("UIStroke", { Name = "_HoverGlow", Color = Theme.Accent, Thickness = 1.5, Transparency = 0.5 }).Parent = tabButton
        end
    end)
    tabButton.MouseLeave:Connect(function()
        local s = tabButton:FindFirstChild("_HoverGlow")
        if s then s:Destroy() end
    end)

    if self._firstTab then
        self._firstTab = false
        selectTab()
    end

    return Tab
end

-- ============================================================
-- TAB METHODS
-- ============================================================

Library.TabMethods = {}
local TM = Library.TabMethods

-- ============================================================
-- WRAP ELEMENT
-- ============================================================

function Library:_wrapElement(root, value)
    local handle
    if type(value) == "table" then
        handle = value
    else
        handle = {}
    end
    if handle.Instance == nil then handle.Instance = root end

    handle.Destroy = handle.Destroy or function(_)
        if root and root.Parent then root:Destroy() end
    end

    handle.SetVisible = handle.SetVisible or function(_, visible)
        if root then root.Visible = visible end
    end

    handle.SetDisabled = handle.SetDisabled or function(_, disabled)
        if not root then return end
        local overlay = root:FindFirstChild("MUI_DisabledOverlay")
        if disabled then
            if not overlay then
                overlay = create("Frame", {
                    Name = "MUI_DisabledOverlay",
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Theme.Background,
                    BackgroundTransparency = 0.45,
                    ZIndex = 1000,
                    Active = true,
                })
                overlay.Parent = root
            end
        elseif overlay then
            overlay:Destroy()
        end
    end

    handle.Refresh = handle.Refresh or function(self_)
        if self_.Set and self_.Get then
            local ok, current = pcall(self_.Get, self_)
            if ok then pcall(self_.Set, self_, current) end
        end
    end

    handle.PlaySound = function(_, soundId, volume)
        Library:PlaySound(soundId, volume)
    end

    handle.PlayHaptic = function(_, variant)
        Library:PlayHaptic(variant)
    end

    return handle
end

    -- Module export (ours): the shell entry points for the other modules.
    return {
        CreateWindow = Library.CreateWindow,
        WindowMethods = Library.WindowMethods,
        TabMethods = Library.TabMethods,
        _wrapElement = Library._wrapElement,
    }

end
