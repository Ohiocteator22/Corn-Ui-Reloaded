--[[
    CornUi - Elements/CommandPalette.lua  (Draft 2: title-bar dropdown)

    The palette is no longer a floating panel. It is a scrollable dropdown that
    is LOCKED to the window's own title text box (the hub name in the header):
    tap/click the title, start typing, and the dropdown opens right under it,
    follows the window while it is dragged, and closes when focus leaves.

    What it lists (fuzzy-filtered as you type):
      - Window       Toggle window visibility
      - Tab          Go to tab: <each tab>              (tag "Current" on the open one)
      - Theme        Theme: <every preset + registered theme>   <- appended, with a
                     colour swatch of the theme's accent; tag "Active" on the live one
      - Skin         Skin: <every registered skin>
      - Toggle       Toggle: <flag>                     (tag shows On / Off)
      - Button       every CreateButton in the hub (opt out with Palette = false)
      - Command      window commands (help, list, minimize, export, screenshot, ...)
      - Config       Save config (fills "save ") / Load config: <each saved config>
      - Cornelius    /cornelius <command>
      - anything you add with window:RegisterPaletteItem{...}

    Keys: Up/Down move, Enter runs, Esc closes. Tap/click a row to run it.
    Typed commands with arguments ("theme Ocean", "save mycfg", "/cornelius help")
    still work exactly as before - Enter on those bypasses the list.

    API (unchanged names):
        window:OpenCommandPalette({ Query = "theme " })   -- focuses the title box
        window:ToggleCommandPalette()
        window:IsCommandPaletteOpen()
    New:
        window:RegisterPaletteItem({ Name =, Tag =, Keywords = {..}, Run = fn })
]]

return function(Modules)

    local Library = Modules
    local Render = Modules.Render
    local Theme = Modules.Theme.Theme
    local Themes = Modules.Theme.Themes
    local WM = Modules.WindowMethods
    local create = Render.create
    local corner = Render.corner
    local stroke = Render.stroke
    local tween = Render.tween

    local stateByWindow = setmetatable({}, { __mode = "k" })

    local MAX_ROWS = 60

    -- built-in command labels; commands not listed here use their keyword
    local COMMAND_LABELS = {
        ["t-notif"] = "Send test notification",
        ["list"] = "List saved configs",
        ["minimize"] = "Minimize window",
        ["export"] = "Export config",
        ["screenshot"] = "Take screenshot",
        ["help"] = "Show all commands",
        ["reset"] = "Reset all flags",
    }
    -- handled by dedicated entries (themes / configs / cornelius) or unsafe to run bare
    local COMMAND_HIDDEN = {
        ["theme"] = true, ["save"] = true, ["load"] = true,
        ["cornelius"] = true, ["reset confirm"] = true,
    }

    ------------------------------------------------------------
    -- Fuzzy scoring: nil = no match, higher = better.
    ------------------------------------------------------------
    local function score(query, text)
        query = query:lower()
        text = text:lower()
        if #query == 0 then return 1 end

        local at = text:find(query, 1, true)
        if at then
            return 1000 - at
        end

        local s, i, streak = 0, 1, 0
        for ci = 1, #query do
            local char = query:sub(ci, ci)
            local found
            for j = i, #text do
                if text:sub(j, j) == char then found = j break end
            end
            if not found then return nil end
            if ci == 1 and found == 1 then s = s + 30 end
            if found == i and ci > 1 then
                streak = streak + 1
                s = s + 15 + streak * 5
            else
                streak = 0
                s = s - (found - i) * 2
            end
            i = found + 1
        end
        return s
    end

    local function itemScore(query, item)
        local best = score(query, item.Name)
        if item.Keywords then
            for _, kw in ipairs(item.Keywords) do
                local s = score(query, kw)
                if s and (not best or s - 15 > best) then best = s - 15 end
            end
        end
        if not best and item.Tag then
            local s = score(query, item.Tag)
            if s then best = s - 40 end
        end
        return best
    end

    local function titleCase(s)
        return (tostring(s):gsub("^%l", string.upper))
    end

    ------------------------------------------------------------
    -- Item collection
    ------------------------------------------------------------
    local ORDER = { window = 1, tab = 2, theme = 3, skin = 4, toggle = 5, button = 6, command = 7, config = 8, cornelius = 9 }

    local function collect(window, state)
        local items = {}
        local function add(it)
            it.Seq = #items + 1
            it.Order = ORDER[it.Kind] or 10
            items[#items + 1] = it
        end

        add({
            Name = "Toggle window visibility", Kind = "window", Tag = "Window",
            Keywords = { "hide", "show", "close", "open" },
            Run = function() window._main.Visible = not window._main.Visible end,
        })

        for _, tabEntry in ipairs(window._tabs or {}) do
            local label = tabEntry.label and tabEntry.label.Text or "?"
            local current = window._currentPageEntry == tabEntry
            add({
                Name = "Go to tab: " .. label, Kind = "tab",
                Tag = current and "Current" or "Tab",
                Keywords = { label },
                Run = function() if tabEntry.select then tabEntry.select() end end,
            })
        end

        local themeNames = {}
        for name in pairs(Themes) do themeNames[#themeNames + 1] = name end
        table.sort(themeNames)
        for _, name in ipairs(themeNames) do
            local active = Library._currentThemeName == name
            add({
                Name = "Theme: " .. name, Kind = "theme",
                Tag = active and "Active" or "Theme",
                Swatch = Themes[name].Accent,
                Keywords = { name .. " theme", "colors" },
                Run = function() window:SetTheme(name) end,
            })
        end

        local skinNames = {}
        for name in pairs(Library.Skins or {}) do skinNames[#skinNames + 1] = name end
        table.sort(skinNames)
        for _, name in ipairs(skinNames) do
            add({
                Name = "Skin: " .. name, Kind = "skin",
                Tag = (Library._currentSkinName == name) and "Active" or "Skin",
                Run = function() window:SetSkin(name) end,
            })
        end

        local flagNames = {}
        for flag, handle in pairs(Library.FlagElements or {}) do
            if type(handle) == "table" and type(handle.Set) == "function" and type(handle.Get) == "function" then
                local ok, current = pcall(handle.Get, handle)
                if ok and (current == true or current == false) then
                    flagNames[#flagNames + 1] = { flag = tostring(flag), handle = handle, current = current }
                end
            end
        end
        table.sort(flagNames, function(a, b) return a.flag < b.flag end)
        for _, f in ipairs(flagNames) do
            add({
                Name = "Toggle: " .. f.flag, Kind = "toggle",
                Tag = f.current and "On" or "Off", TagAccent = f.current,
                Run = function()
                    local okGet, cur = pcall(f.handle.Get, f.handle)
                    if okGet then pcall(f.handle.Set, f.handle, not cur) end
                end,
            })
        end

        for _, extra in ipairs(window._paletteItems or {}) do
            add({
                Name = extra.Name, Kind = extra.Kind or "button", Tag = extra.Tag or "Button",
                Keywords = extra.Keywords, Run = extra.Run,
            })
        end

        local cmdNames = {}
        for kw in pairs(window._commands or {}) do
            if not COMMAND_HIDDEN[kw] then cmdNames[#cmdNames + 1] = kw end
        end
        table.sort(cmdNames)
        for _, kw in ipairs(cmdNames) do
            local fn = window._commands[kw]
            add({
                Name = COMMAND_LABELS[kw] or titleCase(kw), Kind = "command", Tag = "Command",
                Keywords = { kw },
                Run = function()
                    local ok, err = pcall(fn, window, "", {})
                    if not ok then warn("[CornUi] palette command error: " .. tostring(err)) end
                end,
            })
        end

        add({
            Name = "Save config", Kind = "config", Tag = "Config",
            Keywords = { "save" }, Fill = "save ",
        })
        local okList, configs = pcall(function() return Library:ListConfigs() end)
        if okList and type(configs) == "table" then
            table.sort(configs)
            for _, cname in ipairs(configs) do
                add({
                    Name = "Load config: " .. cname, Kind = "config", Tag = "Config",
                    Keywords = { "load " .. cname },
                    Run = function() Library:LoadConfig(cname, window) end,
                })
            end
        end

        local C = Library.Cornelius
        if type(C) == "table" and type(C.Commands) == "table" then
            local names = {}
            for name in pairs(C.Commands) do names[#names + 1] = tostring(name) end
            table.sort(names)
            for _, name in ipairs(names) do
                add({
                    Name = "/cornelius " .. name, Kind = "cornelius", Tag = "Cornelius",
                    Run = function() C:HandleCommand(window, "/cornelius " .. name) end,
                })
            end
        end

        return items
    end

    ------------------------------------------------------------
    -- Results
    ------------------------------------------------------------
    local function computeResults(state, query)
        local results = {}
        if query == "" then
            local byName = {}
            for _, item in ipairs(state.items) do byName[item.Name] = item end
            local seen = {}
            for _, name in ipairs(state.recents) do
                local item = byName[name]
                if item then
                    results[#results + 1] = item
                    seen[item] = true
                end
            end
            for _, item in ipairs(state.items) do
                if not seen[item] then results[#results + 1] = item end
            end
        else
            local scored = {}
            for _, item in ipairs(state.items) do
                local s = itemScore(query, item)
                if s then scored[#scored + 1] = { item = item, s = s } end
            end
            table.sort(scored, function(a, b)
                if a.s ~= b.s then return a.s > b.s end
                if a.item.Order ~= b.item.Order then return a.item.Order < b.item.Order end
                return a.item.Seq < b.item.Seq
            end)
            for _, e in ipairs(scored) do results[#results + 1] = e.item end
        end
        while #results > MAX_ROWS do table.remove(results) end
        return results
    end

    ------------------------------------------------------------
    -- Dropdown UI
    ------------------------------------------------------------
    local function rowHeight(state) return state.touch and 38 or 32 end

    local function reposition(state)
        local tb, sg = state.titleBox, state.window._screenGui
        if not (tb.Parent and sg.Parent) then return end
        local origin = tb.AbsolutePosition - sg.AbsolutePosition
        local sgSize = sg.AbsoluteSize
        local w = math.clamp(tb.AbsoluteSize.X, 260, 420)
        w = math.min(w, math.max(160, sgSize.X - 16))
        local x = math.clamp(origin.X - 8, 8, math.max(8, sgSize.X - w - 8))
        local y = origin.Y + tb.AbsoluteSize.Y + 6
        state.maxH = math.clamp(sgSize.Y - y - 12, 80, 340)
        state.width = w
        state.frame.Position = UDim2.fromOffset(x, y)
        state.frame.Size = UDim2.fromOffset(w, state.frame.Size.Y.Offset)
    end

    local function paintSelection(state)
        for i, row in ipairs(state.rows) do
            local sel = (i == state.selected)
            row.frame.BackgroundTransparency = sel and 0.72 or 1
            row.bar.Visible = sel
        end
    end

    local function scrollIntoView(state)
        local rh = rowHeight(state)
        local top = (state.selected - 1) * (rh + 2) + 4
        local viewH = state.list.AbsoluteSize.Y
        local cp = state.list.CanvasPosition.Y
        if top < cp then
            cp = math.max(0, top - 2)
        elseif top + rh > cp + viewH then
            cp = top + rh - viewH + 2
        end
        state.list.CanvasPosition = Vector2.new(0, cp)
    end

    local function render(state)
        for _, row in ipairs(state.rows) do row.frame:Destroy() end
        state.rows = {}
        if state.empty then state.empty:Destroy() state.empty = nil end

        local rh = rowHeight(state)
        local n = #state.results

        for i, item in ipairs(state.results) do
            local frame = create("TextButton", {
                Name = "Row_" .. i,
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, rh),
                LayoutOrder = i,
                ZIndex = 502,
            }, { corner(8) })
            frame.Parent = state.list

            local bar = create("Frame", {
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Size = UDim2.new(0, 3, 1, -12),
                Position = UDim2.new(0, 3, 0, 6),
                Visible = false,
                ZIndex = 504,
            }, { corner(2) })
            bar.Parent = frame

            local textX = 12
            if item.Swatch then
                create("Frame", {
                    BackgroundColor3 = item.Swatch,
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(12, 12),
                    Position = UDim2.new(0, 14, 0.5, -6),
                    ZIndex = 504,
                }, { corner(6), create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.6 }) }).Parent = frame
                textX = 34
            end

            create("TextLabel", {
                Text = item.Name,
                Font = Enum.Font.GothamMedium,
                TextSize = state.touch and 15 or 14,
                TextColor3 = Theme.Text,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -(textX + 78), 1, 0),
                Position = UDim2.new(0, textX, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 503,
            }).Parent = frame

            create("TextLabel", {
                Text = item.Tag or "",
                Font = Enum.Font.Gotham,
                TextSize = state.touch and 13 or 12,
                TextColor3 = item.TagAccent and Theme.Accent or Theme.SubText,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 70, 1, 0),
                Position = UDim2.new(1, -78, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 503,
            }).Parent = frame

            state.rows[i] = { frame = frame, bar = bar }

            frame.Activated:Connect(function()
                state.selected = i
                state.runItem(item)
            end)
            frame.MouseEnter:Connect(function()
                state.selected = i
                paintSelection(state)
            end)
        end

        if n == 0 then
            state.empty = create("TextLabel", {
                Text = "No matching commands",
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextColor3 = Theme.SubText,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                ZIndex = 503,
            })
            state.empty.Parent = state.list
        end

        state.list.CanvasSize = UDim2.fromOffset(0, n * (rh + 2) + 8)
        paintSelection(state)

        local contentH = math.max(n, 1) * (rh + 2) + 12 + state.footerH
        local h = math.min(contentH, state.maxH or 320)
        tween(state.frame, { Size = UDim2.fromOffset(state.width or 280, h) }, 0.1)
    end

    local function refresh(state)
        state.results = computeResults(state, state.query)
        state.selected = (#state.results > 0) and 1 or 0
        state.list.CanvasPosition = Vector2.new(0, 0)
        render(state)
    end

    ------------------------------------------------------------
    -- Per-window controller
    ------------------------------------------------------------
    local function buildState(window, titleBox, windowName)
        local touch = window._touch
        local footerH = touch and 0 or 20

        local frame = create("Frame", {
            Name = "CommandDropdown",
            Size = UDim2.fromOffset(280, 0),
            BackgroundColor3 = Theme.Header,
            BackgroundTransparency = 0.03,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 500,
        }, { corner(12), stroke(Theme.Accent, 1) })
        frame.Parent = window._screenGui

        local list = create("ScrollingFrame", {
            Name = "Results",
            Size = UDim2.new(1, -12, 1, -(footerH + 8)),
            Position = UDim2.new(0, 6, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = touch and 5 or 3,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 501,
        }, {
            create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        list.Parent = frame

        if footerH > 0 then
            create("TextLabel", {
                Text = "↑↓ navigate    Enter run    Esc close",
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Theme.SubText,
                TextTransparency = 0.25,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -16, 0, footerH),
                Position = UDim2.new(0, 8, 1, -footerH),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
            }).Parent = frame
        end

        local state = {
            window = window, titleBox = titleBox, windowName = windowName,
            frame = frame, list = list, touch = touch, footerH = footerH,
            rows = {}, results = {}, items = {}, recents = {},
            selected = 0, query = "", focused = false, open = false,
            navigated = false, hover = false, lastPress = 0, closeToken = 0,
        }
        return state
    end

    local function rememberRecent(state, name)
        for i = #state.recents, 1, -1 do
            if state.recents[i] == name then table.remove(state.recents, i) end
        end
        table.insert(state.recents, 1, name)
        if #state.recents > 5 then table.remove(state.recents) end
    end

    local function hide(state)
        if not state.open then return end
        state.open = false
        state.window._paletteOpen = false
        state.frame.Visible = false
        state.frame.Size = UDim2.fromOffset(state.width or 280, 0)
    end

    local function show(state)
        state.items = collect(state.window, state)
        state.query = ""
        state.navigated = false
        state.open = true
        state.window._paletteOpen = true
        reposition(state)
        state.frame.Visible = true
        refresh(state)
    end

    local function scheduleClose(state, delay)
        state.closeToken += 1
        local token = state.closeToken
        task.delay(delay, function()
            if token ~= state.closeToken or state.focused or not state.open then return end
            if state.hover or os.clock() - state.lastPress < 1.5 then
                scheduleClose(state, 1.5)
            else
                hide(state)
            end
        end)
    end

    local function fillText(state, text)
        local tb = state.titleBox
        task.delay(0.05, function()
            pcall(function() tb:CaptureFocus() end)
            task.wait(0.03)
            tb.Text = text
            tb.CursorPosition = #text + 1
        end)
    end

    local function attach(window, titleBox, windowName)
        local state = buildState(window, titleBox, windowName)
        stateByWindow[window] = state
        window._paletteItems = window._paletteItems or {}

        function state.runItem(item)
            rememberRecent(state, item.Name)
            state.closeToken += 1
            if item.Fill then
                hide(state)
                titleBox.Text = windowName
                fillText(state, item.Fill)
                return
            end
            hide(state)
            pcall(function() titleBox:ReleaseFocus() end)
            titleBox.Text = windowName
            local ok, err = pcall(item.Run)
            if not ok then warn("[CornUi] palette item error: " .. tostring(err)) end
        end

        state.frame.MouseEnter:Connect(function() state.hover = true end)
        state.frame.MouseLeave:Connect(function() state.hover = false end)
        state.frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                state.lastPress = os.clock()
            end
        end)

        titleBox.Focused:Connect(function()
            state.focused = true
            state.closeToken += 1
            show(state)
        end)

        titleBox:GetPropertyChangedSignal("Text"):Connect(function()
            if not state.focused then return end
            state.query = titleBox.Text
            refresh(state)
        end)

        titleBox:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if state.open then reposition(state) end
        end)

        titleBox.InputBegan:Connect(function(input)
            if not state.open then return end
            local key = input.KeyCode
            if key == Enum.KeyCode.Down and #state.results > 0 then
                state.selected = math.min(#state.results, state.selected + 1)
                state.navigated = true
                paintSelection(state)
                scrollIntoView(state)
            elseif key == Enum.KeyCode.Up and #state.results > 0 then
                state.selected = math.max(1, state.selected - 1)
                state.navigated = true
                paintSelection(state)
                scrollIntoView(state)
            elseif key == Enum.KeyCode.Escape then
                hide(state)
                pcall(function() titleBox:ReleaseFocus() end)
            end
        end)

        -- Called by Window's FocusLost handler (seam). Returns true when the
        -- palette handled the event, so the original command parser is skipped.
        function window._paletteConsume(enterPressed, rawText)
            state.focused = false
            if not enterPressed then
                scheduleClose(state, 0.25)
                return true -- a blur is not a command
            end

            local raw = rawText:gsub("^%s+", ""):gsub("%s+$", "")
            local first = raw:match("^(%S+)")
            if raw ~= "" then
                if raw:match("^/cornelius") then hide(state) return false end
                if first and raw:find("%s") and window._commands[first:lower()] then
                    hide(state)
                    return false
                end
                if window._commands[raw:lower()] and not state.navigated then
                    hide(state)
                    return false
                end
            end

            local item = state.results[state.selected]
            if item then
                state.runItem(item)
                return true
            end
            hide(state)
            return false
        end

        function window:RegisterPaletteItem(def)
            if type(def) ~= "table" or type(def.Name) ~= "string" or type(def.Run) ~= "function" then
                warn("[CornUi] RegisterPaletteItem needs { Name = string, Run = function }")
                return
            end
            table.insert(self._paletteItems, def)
        end

        return state
    end

    ------------------------------------------------------------
    -- WindowMethods (same names as before)
    ------------------------------------------------------------
    function WM:OpenCommandPalette(config)
        config = config or {}
        local state = stateByWindow[self]
        if not state then return end
        self._main.Visible = true
        pcall(function() state.titleBox:CaptureFocus() end)
        if type(config.Query) == "string" and config.Query ~= "" then
            fillText(state, config.Query)
        end
        return state
    end

    function WM:ToggleCommandPalette()
        local state = stateByWindow[self]
        if not state then return end
        if state.open then
            hide(state)
            pcall(function() state.titleBox:ReleaseFocus() end)
        else
            self:OpenCommandPalette({})
        end
    end

    function WM:IsCommandPaletteOpen()
        local state = stateByWindow[self]
        return state ~= nil and state.open == true
    end

    return {
        Attach = attach,
        OpenCommandPalette = WM.OpenCommandPalette,
    }
end
