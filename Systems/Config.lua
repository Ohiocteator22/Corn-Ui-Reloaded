--[[
    Config save/load/list/delete/export/import — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 115-320. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Systems/Config.lua
return function(Modules)
    local Library = Modules
    local Render = Modules.Render
    local HttpService = Render.HttpService

-- ============ CONFIG SYSTEM (v1.9.4d lines 115-320) ============
-- ============================================================
-- CONFIG SYSTEM
-- ============================================================

local CONFIG_PREFIX = "CornUi_Config_"
local CONFIG_SUFFIX = ".lc"

local function configPath(name)
    local safeName = tostring(name or "default"):gsub("[^%w_%-]", "_")
    if safeName == "" then safeName = "default" end
    return CONFIG_PREFIX .. safeName .. CONFIG_SUFFIX
end

local function serializeFlagValue(value)
    local kind = typeof(value)
    if kind == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    elseif kind == "EnumItem" then
        local enumName = tostring(value.EnumType):gsub("^Enum%.", "")
        return { __type = "Enum", enum = enumName, name = value.Name }
    elseif kind == "number" or kind == "string" or kind == "boolean" then
        return value
    elseif kind == "table" then
        local out = {}
        for i, v in ipairs(value) do
            out[i] = serializeFlagValue(v)
        end
        return { __type = "Array", items = out }
    else
        return tostring(value)
    end
end

local function deserializeFlagValue(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.r, value.g, value.b)
    elseif type(value) == "table" and value.__type == "Enum" then
        local ok, enumType = pcall(function() return Enum[value.enum] end)
        if not ok or not enumType then return nil end
        local ok2, item = pcall(function() return enumType[value.name] end)
        if ok2 then return item end
        return nil
    elseif type(value) == "table" and value.__type == "Array" then
        local out = {}
        for i, v in ipairs(value.items or {}) do
            out[i] = deserializeFlagValue(v)
        end
        return out
    else
        return value
    end
end

function Library:SaveConfig(name)
    if type(writefile) ~= "function" then
        warn("[MobileUILib] SaveConfig: writefile not available")
        return false
    end

    local data = {
        Flags = {},
        Theme = Library._currentThemeName or "Frost",
        Skin = Library._currentSkinName,
        Version = Library.VERSION,
        Timestamp = os.time()
    }
    for flagName, value in pairs(Library.Flags) do
        data.Flags[flagName] = serializeFlagValue(value)
    end

    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then
        warn("[MobileUILib] SaveConfig: JSONEncode failed — " .. tostring(json))
        return false
    end

    local wok, werr = pcall(writefile, configPath(name), json)
    if not wok then
        warn("[MobileUILib] SaveConfig: writefile failed — " .. tostring(werr))
        return false
    end
    return true
end

function Library:LoadConfig(name, window)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        warn("[MobileUILib] LoadConfig: isfile/readfile not available")
        return false
    end

    local path = configPath(name)
    local existsOk, exists = pcall(isfile, path)
    if not existsOk or not exists then
        return false
    end

    local readOk, raw = pcall(readfile, path)
    if not readOk then
        warn("[MobileUILib] LoadConfig: readfile failed — " .. tostring(raw))
        return false
    end

    local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decodeOk or type(data) ~= "table" then
        warn("[MobileUILib] LoadConfig: malformed config file")
        return false
    end

    if data.Skin and window and Library.Skins[data.Skin] then
        pcall(function() window:SetSkin(data.Skin) end)
    elseif data.Theme and window then
        pcall(function() window:SetTheme(data.Theme) end)
    end

    if type(data.Flags) == "table" then
        for flagName, rawValue in pairs(data.Flags) do
            local value = deserializeFlagValue(rawValue)
            local elem = Library.FlagElements[flagName]
            if elem and elem.Set then
                pcall(function() elem:Set(value) end)
            else
                Library:SetFlag(flagName, value)
            end
        end
    end

    return true
end

function Library:ListConfigs()
    if type(listfiles) ~= "function" then return {} end
    local ok, files = pcall(listfiles, "")
    if not ok or type(files) ~= "table" then return {} end

    local names = {}
    for _, path in ipairs(files) do
        local fileName = path:match("[^/\\]+$") or path
        local name = fileName:match("^" .. CONFIG_PREFIX .. "(.+)" .. CONFIG_SUFFIX .. "$")
        if name then table.insert(names, name) end
    end
    return names
end

function Library:DeleteConfig(name)
    if type(delfile) ~= "function" or type(isfile) ~= "function" then
        warn("[MobileUILib] DeleteConfig: delfile/isfile not available")
        return false
    end
    local path = configPath(name)
    local existsOk, exists = pcall(isfile, path)
    if not existsOk or not exists then return false end
    local ok, err = pcall(delfile, path)
    if not ok then
        warn("[MobileUILib] DeleteConfig: delfile failed — " .. tostring(err))
        return false
    end
    return true
end

function Library:ExportConfig(name)
    local data = {
        Flags = {},
        Theme = Library._currentThemeName or "Frost",
        Skin = Library._currentSkinName,
        Version = Library.VERSION,
        Timestamp = os.time()
    }
    for flagName, value in pairs(Library.Flags) do
        data.Flags[flagName] = serializeFlagValue(value)
    end

    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then
        warn("[MobileUILib] ExportConfig: JSONEncode failed — " .. tostring(json))
        return nil
    end
    return json
end

function Library:ImportConfig(jsonText, window)
    local decodeOk, data = pcall(function() return HttpService:JSONDecode(jsonText) end)
    if not decodeOk or type(data) ~= "table" then
        warn("[MobileUILib] ImportConfig: malformed config data")
        return false
    end

    if data.Skin and window and Library.Skins[data.Skin] then
        pcall(function() window:SetSkin(data.Skin) end)
    elseif data.Theme and window then
        pcall(function() window:SetTheme(data.Theme) end)
    end

    if type(data.Flags) == "table" then
        for flagName, rawValue in pairs(data.Flags) do
            local value = deserializeFlagValue(rawValue)
            local elem = Library.FlagElements[flagName]
            if elem and elem.Set then
                pcall(function() elem:Set(value) end)
            else
                Library:SetFlag(flagName, value)
            end
        end
    end

    return true
end
end
