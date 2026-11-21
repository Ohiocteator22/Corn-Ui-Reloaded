--[[
    CornUi v2.0 — Systems/Flags.lua
    Central value store for every element's state. Elements read/write through
    this instead of holding their own state, so Config can serialize everything
    generically and multiple UI pieces can stay in sync via FlagChanged.
]]

return function(Modules)

    local Flags = {}

    local Store = {}            -- [flagName] = value
    local ChangedEvent = Instance.new("BindableEvent")
    local PerFlagEvents = {}    -- [flagName] = BindableEvent, for targeted listeners

    -- UI sync registry: elements register themselves here so Config/Theme or
    -- external SetFlag calls can push a value back into the live UI control.
    local FlagElements = {}     -- [flagName] = { Set = function(value) ... end, ... }
    Flags.FlagElements = FlagElements

    function Flags.SetFlag(name, value, suppressUI)
        assert(type(name) == "string", "SetFlag: flag name must be a string")

        local old = Store[name]
        Store[name] = value

        if old ~= value then
            ChangedEvent:Fire(name, value, old)
            local perFlag = PerFlagEvents[name]
            if perFlag then
                perFlag:Fire(value, old)
            end
        end

        if not suppressUI then
            local element = FlagElements[name]
            if element and element.Set then
                element.Set(value)
            end
        end
    end

    function Flags.GetFlag(name, default)
        local value = Store[name]
        if value == nil then
            return default
        end
        return value
    end

    function Flags.GetAllFlags()
        local copy = {}
        for k, v in pairs(Store) do
            copy[k] = v
        end
        return copy
    end

    -- Fires (name, newValue, oldValue) for any flag change.
    Flags.FlagChanged = ChangedEvent.Event

    -- Scoped listener for a single flag, avoids filtering the global event.
    function Flags.OnFlagChanged(name, callback)
        if not PerFlagEvents[name] then
            PerFlagEvents[name] = Instance.new("BindableEvent")
        end
        return PerFlagEvents[name].Event:Connect(callback)
    end

    -- Called by element constructors (Toggle, Slider, etc.) to register the
    -- function that updates their visual state when SetFlag is called externally.
    function Flags.RegisterElement(name, controller)
        assert(type(controller) == "table" and controller.Set,
            "RegisterElement: controller must provide a Set(value) function")
        FlagElements[name] = controller
    end

    function Flags.UnregisterElement(name)
        FlagElements[name] = nil
    end

    -- Elements without a Flag call this so callback-only scripts (v1 style)
    -- still get a unique backing key for the store — required for config
    -- save/load and SetFlag→UI sync, invisible to the script author.
    local AutoFlagSeq = 0
    function Flags.NextAutoFlag()
        AutoFlagSeq += 1
        return "_CornUi_Auto_" .. tostring(AutoFlagSeq)
    end

    return Flags
end
