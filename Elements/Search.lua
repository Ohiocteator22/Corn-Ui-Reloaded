--[[
    CornUi v2.0 — Elements/Search.lua
    Registers Section:CreateSearch(props).

    props = {
        Placeholder = "Search...",
        OnChanged = function(query) end,   -- fires on every keystroke
        Targets = { instance1, instance2 }, -- optional: GuiObjects to auto filter
        MatchKey = function(inst) return inst.Name end, -- how to read a target's searchable text
    }

    If props.Targets is provided, Search auto-hides targets whose MatchKey
    result doesn't contain the query (case-insensitive substring match).
]]

return function(Modules)

    local Render = Modules.Render
    local Section = Modules.Window.Section

    local Search = {}
    Search.__index = Search

    function Search.New(section, props)
        props = props or {}

        local self = setmetatable({}, Search)

        self.Box = Render.New("Frame", {
            Name = "Search",
            Size = UDim2.new(1, 0, 0, 28),
            CornerRadius = 6,
            Theme = "Default",
            Parent = section.Frame,
        })

        local textBox = Instance.new("TextBox")
        textBox.BackgroundTransparency = 1
        textBox.Size = UDim2.new(1, -16, 1, 0)
        textBox.Position = UDim2.fromOffset(8, 0)
        textBox.PlaceholderText = props.Placeholder or "Search..."
        textBox.Text = ""
        textBox.TextSize = 13
        textBox.ClearTextOnFocus = false
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.Parent = self.Box
        self.Input = textBox

        Modules.Theme.Apply(textBox, "Text", { Theme = "Default" })

        local function defaultMatchKey(inst)
            return inst.Name
        end
        local matchKey = props.MatchKey or defaultMatchKey

        local function applyFilter(query)
            query = query:lower()
            if not props.Targets then return end

            for _, inst in ipairs(props.Targets) do
                local ok, text = pcall(matchKey, inst)
                local haystack = ok and tostring(text):lower() or ""
                inst.Visible = (query == "") or haystack:find(query, 1, true) ~= nil
            end
        end

        textBox:GetPropertyChangedSignal("Text"):Connect(function()
            local query = textBox.Text
            applyFilter(query)
            if props.OnChanged then
                task.spawn(props.OnChanged, query)
            end
        end)

        function self:Clear()
            textBox.Text = ""
        end

        function self:GetQuery()
            return textBox.Text
        end

        return self
    end

    Section.CreateSearch = function(section, props)
        return Search.New(section, props)
    end

    return Search
end
