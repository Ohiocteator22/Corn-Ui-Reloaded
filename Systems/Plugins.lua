--[[
    Plugin system: load/enable/disable/reload/unload + context factory — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 5627-5898. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Systems/Plugins.lua
return function(Modules)
    local Library = Modules
    local Render = Modules.Render
    local LocalPlayer = Render.LocalPlayer

-- ============ PLUGIN SYSTEM (v1.9.4d lines 5627-5898) ============
-- ============================================================
-- PLUGIN SYSTEM
-- ============================================================

Library.Plugins = {}
Library.PluginRegistry = {}
local pluginRegistryChangedEvent = Instance.new("BindableEvent")
Library.PluginRegistryChanged = pluginRegistryChangedEvent.Event

local function findPluginRecord(name)
    for _, record in ipairs(Library.PluginRegistry) do
        if record.Name == name then return record end
    end
    return nil
end

function Library:_makePluginContext(window)
    local self_ = self
    return {
        Library = self_,
        Window = window,
        Player = LocalPlayer,

        GetFlag = function(_, name) return self_:GetFlag(name) end,
        SetFlag = function(_, name, value) self_:SetFlag(name, value) end,
        FlagChanged = self_.FlagChanged,

        SaveConfig = function(_, name) return self_:SaveConfig(name) end,
        LoadConfig = function(_, name) return self_:LoadConfig(name, window) end,
        ListConfigs = function(_) return self_:ListConfigs() end,
        DeleteConfig = function(_, name) return self_:DeleteConfig(name) end,
        ExportConfig = function(_, name) return self_:ExportConfig(name) end,
        ImportConfig = function(_, jsonText) return self_:ImportConfig(jsonText, window) end,

        ListPlugins = function(_) return self_:ListPlugins() end,
        DisablePlugin = function(_, name) return self_:DisablePlugin(name) end,
        EnablePlugin = function(_, name) return self_:EnablePlugin(name) end,
        ReloadPlugin = function(_, name) return self_:ReloadPlugin(name) end,
        UnloadPlugin = function(_, name) return self_:UnloadPlugin(name) end,

        RegisterTheme = function(_, name, themeTable)
            self_:RegisterTheme(name, themeTable)
        end,
        RegisterSkin = function(_, name, skinDef)
            self_:RegisterSkin(name, skinDef)
        end,
        SetSkin = function(_, name)
            if not window then
                warn("[MobileUILib] SetSkin needs a Window — pass one to LoadPlugin/LoadPlugins")
                return
            end
            window:SetSkin(name)
        end,
        RegisterElement = function(_, name, constructor)
            self_:RegisterElement(name, constructor)
        end,

        RegisterCommand = function(_, keyword, fn)
            if not window then
                warn("[MobileUILib] RegisterCommand needs a Window — pass one to LoadPlugin/LoadPlugins")
                return
            end
            window:RegisterCommand(keyword, fn)
        end,

        SetBackground = function(_, config)
            if not window then
                warn("[MobileUILib] SetBackground needs a Window — pass one to LoadPlugin/LoadPlugins")
                return
            end
            return window:SetBackground(config)
        end,
        ClearBackground = function(_)
            if window then window:ClearBackground() end
        end,

        CreateTab = function(_, name, tabConfig)
            if not window then return nil end
            return window:CreateTab(name, tabConfig)
        end,

        Notify = function(_, notifConfig)
            if window then window:Notify(notifConfig) end
        end,

        PlaySound = function(_, soundId, volume)
            self_:PlaySound(soundId, volume)
        end,

        PlayHaptic = function(_, variant)
            self_:PlayHaptic(variant)
        end,

        SetAnimationSpeed = function(_, factor)
            if window then window:SetAnimationSpeed(factor) end
        end,
    }
end

function Library:LoadPlugin(url, window)
    local fetchOk, source = pcall(game.HttpGet, game, url)
    if not fetchOk then
        warn("[MobileUILib] Plugin fetch failed (" .. tostring(url) .. "): " .. tostring(source))
        return nil
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        warn("[MobileUILib] Plugin failed to compile (" .. tostring(url) .. "): " .. tostring(compileErr))
        return nil
    end

    local context = self:_makePluginContext(window)
    local runOk, result = pcall(chunk, context)
    if not runOk then
        warn("[MobileUILib] Plugin errored while loading (" .. tostring(url) .. "): " .. tostring(result))
        return nil
    end

    if type(result) == "table" then
        local name = result.Name or url
        self.Plugins[name] = result

        local record = findPluginRecord(name)
        if not record then
            record = { Name = name }
            table.insert(self.PluginRegistry, record)
        end
        record.Url = url
        record.Version = result.Version
        record.Result = result
        record.Context = context
        record.Window = window
        record.Enabled = true
        record.LoadTime = os.time()

        if type(result.Init) == "function" then
            local initOk, initErr = pcall(result.Init, context)
            if not initOk then
                warn("[MobileUILib] Plugin Init error (" .. tostring(name) .. "): " .. tostring(initErr))
            end
        end

        pluginRegistryChangedEvent:Fire()
    end

    return result
end

function Library:LoadPlugins(urls, window)
    local loaded = {}
    for _, url in ipairs(urls or {}) do
        loaded[#loaded + 1] = self:LoadPlugin(url, window)
    end
    return loaded
end

function Library:ListPlugins()
    local list = {}
    for _, record in ipairs(self.PluginRegistry) do
        table.insert(list, {
            Name = record.Name,
            Version = record.Version,
            Url = record.Url,
            Enabled = record.Enabled,
            LoadTime = record.LoadTime,
        })
    end
    return list
end

function Library:DisablePlugin(name)
    local record = findPluginRecord(name)
    if not record or not record.Enabled then return false end

    if record.Result and type(record.Result.Unload) == "function" then
        local ok, err = pcall(record.Result.Unload, record.Context)
        if not ok then
            warn("[MobileUILib] Plugin Unload error (" .. tostring(name) .. "): " .. tostring(err))
        end
    end

    record.Enabled = false
    pluginRegistryChangedEvent:Fire()
    return true
end

function Library:EnablePlugin(name)
    local record = findPluginRecord(name)
    if not record or record.Enabled then return false end

    if record.Result and type(record.Result.Init) == "function" then
        local ok, err = pcall(record.Result.Init, record.Context)
        if not ok then
            warn("[MobileUILib] Plugin Init error on re-enable (" .. tostring(name) .. "): " .. tostring(err))
        end
    end

    record.Enabled = true
    pluginRegistryChangedEvent:Fire()
    return true
end

function Library:ReloadPlugin(name)
    local record = findPluginRecord(name)
    if not record or not record.Url then return false end

    if record.Result and type(record.Result.Unload) == "function" then
        pcall(record.Result.Unload, record.Context)
    end

    local fetchOk, source = pcall(game.HttpGet, game, record.Url)
    if not fetchOk then
        warn("[MobileUILib] Plugin reload fetch failed (" .. tostring(name) .. "): " .. tostring(source))
        return false
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        warn("[MobileUILib] Plugin reload compile failed (" .. tostring(name) .. "): " .. tostring(compileErr))
        return false
    end

    local context = self:_makePluginContext(record.Window)
    local runOk, result = pcall(chunk, context)
    if not runOk then
        warn("[MobileUILib] Plugin reload run error (" .. tostring(name) .. "): " .. tostring(result))
        return false
    end

    if type(result) == "table" then
        self.Plugins[name] = result
        record.Result = result
        record.Context = context
        record.Version = result.Version
        record.Enabled = true
        record.LoadTime = os.time()

        if type(result.Init) == "function" then
            local initOk, initErr = pcall(result.Init, context)
            if not initOk then
                warn("[MobileUILib] Plugin Init error on reload (" .. tostring(name) .. "): " .. tostring(initErr))
            end
        end
    end

    pluginRegistryChangedEvent:Fire()
    return true
end

function Library:UnloadPlugin(name)
    local record = findPluginRecord(name)
    if not record then return false end

    if record.Result and type(record.Result.Unload) == "function" then
        local ok, err = pcall(record.Result.Unload, record.Context)
        if not ok then
            warn("[MobileUILib] Plugin Unload error (" .. tostring(name) .. "): " .. tostring(err))
        end
    end

    self.Plugins[name] = nil
    for i, r in ipairs(self.PluginRegistry) do
        if r.Name == name then
            table.remove(self.PluginRegistry, i)
            break
        end
    end

    pluginRegistryChangedEvent:Fire()
    return true
end
end
