--[[
    CornUi v1.9.4d (modular) — Elements/CommandPalette.lua

    ADDITION over the v1.9.4d window — the shell itself is untouched; this
    only registers three WindowMethods entries and builds its UI from the
    verbatim helpers (create/corner/stroke) inside the window's own ScreenGui,
    styled straight from the live Theme table so SetTheme recolors an open
    palette along with everything else.

        window:OpenCommandPalette(config)
        window:ToggleCommandPalette()
        window:IsCommandPaletteOpen()

    Sources, merged and scored:
      - the window's own commands (window._commands: theme, save, load,
        list, minimize, export, screenshot, help, reset, t-notif, cornelius
        and anything added later via window:RegisterCommand)
      - Cornelius commands, exposed as "/cornelius <name>"
      - boolean flag handles (Library.FlagElements) as "Toggle: <flag>"

    Interaction model (what "better" means here):
      - fuzzy subsequence scoring: exact substring > prefix > consecutive
        runs > gapped matches, so "thm" still finds "theme"
      - Up/Down move, Enter runs, Esc closes, mouse/tap click runs,
        hover previews the selection
      - recents per window (max 5), pinned to the top of an empty query
      - fixed-height rows in a ScrollingFrame — no AutomaticSize anywhere,
        so it cannot collapse or overlap the way the old floating palette did
]]

return function(Modules)

    local Library = Modules
    local Render = Modules.Render
    local Theme = Modules.Theme.Theme
    local WM = Modules.WindowMethods
    local UserInputService = Render.UserInputService
    local create = Render.create
    local corner = Render.corner
    local stroke = Render.stroke

    local stateByWindow = setmetatable({}, { __mode = "k" })

    ------------------------------------------------------------
    -- Fuzzy scoring: nil = no match, higher = better.
    ------------------------------------------------------------
    local function score(query, text)
        query = query:lower()
        text = text:lower()
        if #query == 0 then return 1 end

        local at = text:find(query, 1, true)
        if at then
            return 1000 - at -- exact substring, earlier is better
        end

        local s = 0
        local i = 1
        local streak = 0
        for ci = 1, #query do
            local char = query:sub(ci, ci)
            local found = nil
            for j = i, #text do
                if text:sub(j, j) == char then found = j break end
            end
            if not found then return nil end
            if ci == 1 and found == 1 then
                s = s + 30 -- prefix bonus
            end
            if found == i and ci > 1 then
                streak = streak + 1
                s = s + 15 + streak * 5 -- consecutive-run bonus
            else
                streak = 0
                s = s - (found - i) * 2 -- gap penalty
            end
            i = found + 1
        end
        return s
    end

    ------------------------------------------------------------
    -- Command collection (window commands + Cornelius + flag toggles).
    ------------------------------------------------------------
    local function collectCommands(window)
        local items = {}

        for kw, fn in pairs(window._commands or {}) do
            items[#items + 1] = {
                Name = tostring(kw),
                Kind = "command",
                Run = function()
                    local ok, err = pcall(fn, window, "")
                    if not ok then warn("[CornUi] palette command error: " .. tostring(err)) end
                end,
            }
        end

        if type(Cornelius) == "table" and type(Cornelius.Commands) == "table" then
            for name in pairs(Cornelius.Commands) do
                items[#items + 1] = {
                    Name = "/cornelius " .. tostring(name),
                    Kind = "cornelius",
                    Run = function()
                        Cornelius:HandleCommand(window, "/cornelius " .. tostring(name))
                    end,
                }
            end
        end

        for flag, handle in pairs(Library.FlagElements or {}) do
            if type(handle) == "table" and type(handle.Set) == "function" and type(handle.Get) == "function" then
                local ok, current = pcall(handle.Get, handle)
                if ok and (current == true or current == false) then
                    items[#items + 1] = {
                        Name = "Toggle: " .. tostring(flag),
                        Kind = "flag",
                        Run = function()
                            local okGet, cur = pcall(handle.Get, handle)
                            if okGet then pcall(handle.Set, handle, not cur) end
                        end,
                    }
                end
            end
        end

        table.sort(items, function(a, b) return a.Name < b.Name end)
        return items
    end

    ------------------------------------------------------------
    -- UI construction + per-window state.
    ------------------------------------------------------------
    local MAX_ROWS = 60
    local ROW_HEIGHT = 28

    local function build(window, config)
        config = config or {}
        local old = stateByWindow[window]
        if old and old.frame and old.frame.Parent then
            if old.inputConn then old.inputConn:Disconnect() end
            if old.textConn then old.textConn:Disconnect() end
            old.frame:Destroy()
        end

        local touch = window._touch
        local main = window._main
        local header = main:FindFirstChild("Header")
        local headerH = (header and header.Size and header.Size.Y.Offset) or 40

        local height = math.clamp(config.Height or (touch and 250 or 310), 160, 420)

        local frame = create("Frame", {
            Name = "CommandPalette",
            Size = UDim2.new(1, -20, 0, height),
            Position = UDim2.new(0, 10, 0, headerH + 8),
            BackgroundColor3 = Theme.Header,
            ZIndex = 400,
            BorderSizePixel = 0,
        }, { corner(12), stroke(Theme.Accent, 1) })
        frame.Parent = main

        local box = create("TextBox", {
            Name = "Query",
            PlaceholderText = config.Placeholder or "Type a command...",
            Text = "",
            Font = Enum.Font.GothamMedium,
            TextSize = touch and 15 or 14,
            TextColor3 = Theme.Text,
            PlaceholderColor3 = Theme.SubText,
            BackgroundColor3 = Theme.Element,
            Size = UDim2.new(1, -16, 0, 32),
            Position = UDim2.new(0, 8, 0, 8),
            ClearTextOnFocus = false,
            ZIndex = 401,
        }, { corner(8) })
        box.Parent = frame

        local list = create("ScrollingFrame", {
            Name = "Results",
            Size = UDim2.new(1, -16, 1, -48),
            Position = UDim2.new(0, 8, 0, 44),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = touch and 6 or 4,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 401,
        }, {
            create("UIListLayout", {
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })
        list.Parent = frame

        local state = {
            frame = frame,
            box = box,
            list = list,
            open = true,
            selected = 1,
            rows = {},
            results = {},
            items = collectCommands(window),
            recents = (old and old.recents) or {},
            inputConn = nil,
            textConn = nil,
            run = nil,
        }
        stateByWindow[window] = state
        return state
    end

    ------------------------------------------------------------
    -- Result computation: recents pinned on empty query, else scored.
    ------------------------------------------------------------
    local function computeResults(state, query)
        local results = {}
        if query == "" then
            local byName = {}
            for _, item in ipairs(state.items) do byName[item.Name] = item end
            for _, name in ipairs(state.recents) do
                local item = byName[name]
                if item then results[#results + 1] = item end
            end
            for _, item in ipairs(state.items) do
                results[#results + 1] = item
            end
            return results
        end

        local scored = {}
        for _, item in ipairs(state.items) do
            local s = score(query, item.Name)
            if s then scored[#scored + 1] = { item = item, s = s } end
        end
        table.sort(scored, function(a, b)
            if a.s == b.s then return a.item.Name < b.item.Name end
            return a.s > b.s
        end)
        for i, entry in ipairs(scored) do
            if i > MAX_ROWS then break end
            results[#results + 1] = entry.item
        end
        return results
    end

    ------------------------------------------------------------
    -- Row rendering + selection paint.
    ------------------------------------------------------------
    local function paintSelection(state)
        for i, row in ipairs(state.rows) do
            local isSel = (i == state.selected)
            row.frame.BackgroundColor3 = isSel and Theme.Accent or Theme.Element
            row.title.TextColor3 = isSel and Theme.TextOnAccent or Theme.Text
            row.hint.TextColor3 = isSel and Theme.TextOnAccent or Theme.SubText
        end
    end

    local function renderResults(state)
        for _, row in ipairs(state.rows) do
            row.frame:Destroy()
        end
        state.rows = {}

        for i, item in ipairs(state.results) do
            local rowFrame = create("TextButton", {
                Name = "Row_" .. tostring(i),
                Text = "",
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 402,
            }, { corner(6) })
            rowFrame.Parent = state.list

            local title = create("TextLabel", {
                Text = item.Name,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = Theme.Text,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -90, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 403,
            })
            title.Parent = rowFrame

            local hint = create("TextLabel", {
                Text = item.Kind,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Theme.SubText,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 80, 1, 0),
                Position = UDim2.new(1, -86, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 403,
            })
            hint.Parent = rowFrame

            local row = { frame = rowFrame, title = title, hint = hint, index = i }
            state.rows[#state.rows + 1] = row

            rowFrame.MouseButton1Click:Connect(function()
                state.selected = i
                state.run(rowFrame, item)
            end)
            rowFrame.MouseEnter:Connect(function()
                state.selected = i
                paintSelection(state)
            end)
        end

        paintSelection(state)
    end

    local function updateResults(state)
        state.results = computeResults(state, state.box.Text)
        if #state.results == 0 then
            state.selected = 0
        elseif state.selected > #state.results then
            state.selected = #state.results
        elseif state.selected < 1 then
            state.selected = 1
        end
        renderResults(state)
    end

    ------------------------------------------------------------
    -- Open / close / keyboard wiring.
    ------------------------------------------------------------
    local function rememberRecent(state, name)
        for i = #state.recents, 1, -1 do
            if state.recents[i] == name then table.remove(state.recents, i) end
        end
        table.insert(state.recents, 1, name)
        if #state.recents > 5 then table.remove(state.recents) end
    end

    local function close(window)
        local state = stateByWindow[window]
        if not state then return end
        if state.inputConn then state.inputConn:Disconnect() end
        if state.textConn then state.textConn:Disconnect() end
        if state.frame and state.frame.Parent then state.frame:Destroy() end
        stateByWindow[window] = nil
    end

    local function openPalette(window, config)
        local state = build(window, config)

        function state.run(_, item)
            rememberRecent(state, item.Name)
            close(window)
            item.Run()
        end

        state.textConn = state.box:GetPropertyChangedSignal("Text"):Connect(function()
            updateResults(state)
        end)

        state.inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.KeyCode == Enum.KeyCode.Escape then
                close(window)
            elseif input.KeyCode == Enum.KeyCode.Up then
                if #state.results > 0 then
                    state.selected = math.max(1, state.selected - 1)
                    paintSelection(state)
                end
            elseif input.KeyCode == Enum.KeyCode.Down then
                if #state.results > 0 then
                    state.selected = math.min(#state.results, state.selected + 1)
                    paintSelection(state)
                end
            elseif input.KeyCode == Enum.KeyCode.Return then
                local item = state.results[state.selected]
                if item then state.run(state.frame, item) end
            end
        end)

        updateResults(state)
        pcall(function() state.box:CaptureFocus() end)
        return state
    end

    ------------------------------------------------------------
    -- WindowMethods additions.
    ------------------------------------------------------------
    function WM:OpenCommandPalette(config)
        return openPalette(self, config)
    end

    function WM:ToggleCommandPalette()
        if stateByWindow[self] then
            close(self)
        else
            openPalette(self, {})
        end
    end

    function WM:IsCommandPaletteOpen()
        local state = stateByWindow[self]
        return state ~= nil and state.open == true
    end

    return { OpenCommandPalette = WM.OpenCommandPalette }
end
