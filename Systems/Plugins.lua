--[[
    CornUi v2.0 — Systems/Plugins.lua
    Plugin lifecycle manager. A plugin is a module that returns a table with
    at minimum an Init(ctx) function, and optionally Unload(ctx).

    ctx passed to plugins = { Window, Render, Theme, Flags, Config, Modules }
    so plugins get the same surface the core library builds with.
]]

return function(Modules)

    local Plugins = {}

    local Registry = {}   -- [name] = { Source = fn/url, Instance = table|nil, Enabled = bool }
    local LoadOrder = {}

    local function buildContext()
        return {
            Window  = Modules.Window,
            Render  = Modules.Render,
            Theme   = Modules.Theme,
            Flags   = Modules.Flags,
            Config  = Modules.Config,
            Modules = Modules,
        }
    end

    -- source may be a function(ctx) -> pluginTable, or a URL string to HttpGet + loadstring.
    function Plugins.Register(name, source)
        assert(type(name) == "string", "Plugins.Register: name must be a string")
        assert(not Registry[name], ("Plugins.Register: '%s' already registered"):format(name))

        Registry[name] = { Source = source, Instance = nil, Enabled = false }
        table.insert(LoadOrder, name)
    end

    local function resolveFactory(entry)
        if type(entry.Source) == "function" then
            return entry.Source
        elseif type(entry.Source) == "string" then
            local src = game:HttpGet(entry.Source)
            local chunk = loadstring(src)
            assert(chunk, "Plugins: loadstring failed for plugin source")
            return chunk
        end
        error("Plugins: unsupported source type for plugin")
    end

    function Plugins.EnablePlugin(name)
        local entry = Registry[name]
        assert(entry, ("EnablePlugin: unknown plugin '%s'"):format(name))
        if entry.Enabled then return true end

        local factory = resolveFactory(entry)
        local ctx = buildContext()

        local ok, pluginOrErr = pcall(factory, ctx)
        if not ok then
            warn(("Plugins: '%s' failed to load: %s"):format(name, tostring(pluginOrErr)))
            return false, pluginOrErr
        end

        entry.Instance = pluginOrErr
        entry.Enabled = true

        if entry.Instance and entry.Instance.Init then
            local okInit, err = pcall(entry.Instance.Init, ctx)
            if not okInit then
                warn(("Plugins: '%s' Init() errored: %s"):format(name, tostring(err)))
            end
        end

        return true
    end

    function Plugins.DisablePlugin(name)
        local entry = Registry[name]
        assert(entry, ("DisablePlugin: unknown plugin '%s'"):format(name))
        if not entry.Enabled then return true end

        if entry.Instance and entry.Instance.Unload then
            local ctx = buildContext()
            local ok, err = pcall(entry.Instance.Unload, ctx)
            if not ok then
                warn(("Plugins: '%s' Unload() errored: %s"):format(name, tostring(err)))
            end
        end

        entry.Enabled = false
        entry.Instance = nil
        return true
    end

    function Plugins.ReloadPlugin(name)
        Plugins.DisablePlugin(name)
        return Plugins.EnablePlugin(name)
    end

    function Plugins.UnloadPlugin(name)
        Plugins.DisablePlugin(name)
        Registry[name] = nil
        for i, n in ipairs(LoadOrder) do
            if n == name then
                table.remove(LoadOrder, i)
                break
            end
        end
    end

    function Plugins.ListPlugins()
        local out = {}
        for _, name in ipairs(LoadOrder) do
            local entry = Registry[name]
            table.insert(out, { Name = name, Enabled = entry.Enabled })
        end
        return out
    end

    -- Returns the live registry entry for a plugin:
    -- { Source = fn|url, Instance = table|nil, Enabled = bool }, or nil.
    -- Treat it as read-only; mutations go through Enable/Disable/Unload.
    function Plugins.GetPlugin(name)
        return Registry[name]
    end

    return Plugins
end
