--[[
    CreateSearch — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 4312-4376. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/Search.lua
return function(Modules)
    -- Verbatim-body prelude (the only non-v1.9.4d code in this file): binds
    -- the monolith's file-local upvalues to the module system. The loader's
    -- shared table IS the facade, so `Library.X` below reads exactly like
    -- the v1.9.4d source; every extracted body is byte-identical to it.
    local Library = Modules
    local Render = Modules.Render
    local Theme = Modules.Theme.Theme
    local TM = Modules.TabMethods
    local UserInputService = Render.UserInputService
    local TweenService = Render.TweenService
    local RunService = Render.RunService
    local create = Render.create
    local corner = Render.corner
    local setSearchMeta = Render.setSearchMeta
    local stroke = Render.stroke
    local tween = Render.tween
    local playInteractionSound = Render.playInteractionSound
    local ripple = Render.ripple
    local shiftZIndex = Render.shiftZIndex

-- ============================================================
-- SEARCH
-- ============================================================

function TM:CreateSearch(config)
    config = config or {}
    local touch = self._touch
    local compact = Library.Flags.CompactMode
    local page = self._page

    local box = create("TextBox", {
        PlaceholderText = config.Placeholder or "Search...",
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 13 or 15) or (compact and 11 or 13),
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.SubText,
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(1, 0, 0, touch and (compact and 34 or 42) or (compact and 26 or 32)),
        ClearTextOnFocus = false,
    }, {
        corner(10), stroke(),
        create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
    })
    box.Parent = page

    local noResults = create("TextLabel", {
        Text = "The searched feature is not available or removed",
        Font = Enum.Font.Gotham,
        TextSize = touch and (compact and 12 or 14) or (compact and 10 or 12),
        TextColor3 = Theme.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        TextWrapped = true,
        Visible = false,
    })
    noResults.Parent = page

    box:GetPropertyChangedSignal("Text"):Connect(function()
        local query = box.Text:lower()
        local anyVisible = false
        local matchCount = 0
        for _, child in ipairs(page:GetChildren()) do
            if child:IsA("GuiObject") and child ~= box and child ~= noResults then
                local haystack = child:GetAttribute("MUI_Search") or child:GetAttribute("MUI_Name")
                if haystack then
                    local match = query == "" or haystack:lower():find(query, 1, true) ~= nil
                    child.Visible = match
                    if match then
                        anyVisible = true
                        matchCount = matchCount + 1
                    end
                end
            end
        end
        noResults.Visible = (query ~= "" and not anyVisible)
        if query ~= "" and anyVisible then
            box.PlaceholderText = matchCount .. " results"
        else
            box.PlaceholderText = config.Placeholder or "Search..."
        end
    end)

    return box
end
end
