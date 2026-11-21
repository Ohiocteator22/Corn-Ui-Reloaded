--[[
    Flag manager, keybind registry, notification log, custom-element registry — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 46-51, 57-105, 465-479. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Systems/Flags.lua
return function(Modules)
    local Library = Modules

-- ============ LIBRARY STATE (v1.9.4d lines 46-51) ============

Library._customElements = {}
Library._themeHistory = {}
Library._windowPositions = {}

Library.VERSION = "1.9.3"
Library.BUILD = "2024.08.07"

-- ============ FLAG MANAGER / KEYBINDS / NOTIFICATION LOG (lines 57-105) ============

Library.Flags = {
    UISounds = true,
    Haptics = true,
    UIScale = 1,
    CompactMode = false,
    ShowIntro = true,
    SnapToEdges = false,
    TabReordering = true,
    AutoSaveInterval = 60,
    RememberPosition = true,
    ReducedMotion = false,
    PerformanceMode = false,
}

local flagChangedEvent = Instance.new("BindableEvent")
Library.FlagChanged = flagChangedEvent.Event

function Library:GetFlag(name)
    return Library.Flags[name]
end

function Library:SetFlag(name, value)
    if not name then return end
    Library.Flags[name] = value
    flagChangedEvent:Fire(name, value)
end

Library.FlagElements = {}

-- ============================================================
-- KEYBIND REGISTRY
-- ============================================================

Library.Keybinds = {}
local keybindRegisteredEvent = Instance.new("BindableEvent")
Library.KeybindRegistered = keybindRegisteredEvent.Event
local keybindChangedEvent = Instance.new("BindableEvent")
Library.KeybindChanged = keybindChangedEvent.Event
local keybindUnregisteredEvent = Instance.new("BindableEvent")
Library.KeybindUnregistered = keybindUnregisteredEvent.Event

-- ============================================================
-- NOTIFICATION HISTORY
-- ============================================================

Library.NotificationHistory = {}
Library.MAX_NOTIFICATION_HISTORY = 50
local notificationLoggedEvent = Instance.new("BindableEvent")
Library.NotificationLogged = notificationLoggedEvent.Event

-- ============ CUSTOM ELEMENT REGISTRATION (lines 465-479) ============

function Library:RegisterElement(name, constructor)
    if type(name) ~= "string" or type(constructor) ~= "function" then
        warn("[MobileUILib] RegisterElement requires a name string and a constructor function")
        return
    end
    Library._customElements[name] = constructor
end

function Library:GetRegisteredElements()
    local list = {}
    for name in pairs(Library._customElements) do
        table.insert(list, name)
    end
    return list
end
end
