--[[
    CreateThemeEditor — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 3907-3936. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Elements/ThemeEditor.lua
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
-- THEME EDITOR
-- ============================================================

function TM:CreateThemeEditor(config)
    config = config or {}
    local window = self._window

    self:CreateLabel(config.Title or "Theme Editor")

    self:CreateColorPicker({
        Name = config.UIColorName or "UI Color",
        Default = Theme.Background,
        Keywords = { "theme", "background" },
        Description = "Recolors the hub's main background",
        Callback = function(color)
            if window then window:SetThemeColor("Background", color) end
        end,
    })

    self:CreateColorPicker({
        Name = config.ToggleColorName or "Toggle Button Color",
        Default = Theme.ToggleButton,
        Keywords = { "theme", "float button", "toggle" },
        Description = "Recolors the floating show/hide button",
        Callback = function(color)
            if window then window:SetThemeColor("ToggleButton", color) end
        end,
    })
end
end
