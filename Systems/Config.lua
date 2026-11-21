--[[
    CornUi v2.0 — Systems/Config.lua
    Save/load Flag state to JSON, with Color3/Enum/Vector2/array-safe
    serialization so round-tripping doesn't lose type information.
]]

return function(Modules)

    local Flags = Modules.Flags
    local Host = Modules.Host
    local HttpService = game:GetService("HttpService")

    local Config = {}

    local FOLDER_NAME = "CornUi/Configs"
    local AUTOSAVE_FLAG = "__CornUi_LastConfig"

    local function ensureFolder()
        if not isfolder then return end -- executor without filesystem support
        if not isfolder(FOLDER_NAME) then
            makefolder(FOLDER_NAME)
        end
    end

    ------------------------------------------------------------
    -- Type-safe encode/decode
    -- Wraps non-primitive types as {__type = "...", ...} so decode can
    -- reconstruct the exact Roblox type instead of guessing from shape.
    ------------------------------------------------------------

    local function encodeValue(value)
        local t = typeof(value)

        if t == "Color3" then
            return { __type = "Color3", R = value.R, G = value.G, B = value.B }
        elseif t == "Vector2" then
            return { __type = "Vector2", X = value.X, Y = value.Y }
        elseif t == "Vector3" then
            return { __type = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
        elseif t == "UDim2" then
            return {
                __type = "UDim2",
                XS = value.X.Scale, XO = value.X.Offset,
                YS = value.Y.Scale, YO = value.Y.Offset,
            }
        elseif t == "EnumItem" then
            -- Encode the enum TYPE's plain name ("KeyCode"), not its
            -- tostring form ("Enum.KeyCode") — Enum["Enum.KeyCode"] is not a
            -- valid lookup on real Roblox and decoding used to yield nil.
            return { __type = "Enum", EnumType = value.EnumType.Name, Name = value.Name }
        elseif t == "table" then
            local out = {}
            local isArray = (#value > 0)
            for k, v in pairs(value) do
                out[k] = encodeValue(v)
            end
            if isArray then out.__isArray = true end
            return out
        end

        return value -- string, number, boolean pass through as-is
    end

    local function decodeValue(value)
        if type(value) ~= "table" then
            return value
        end

        if value.__type == "Color3" then
            return Color3.new(value.R, value.G, value.B)
        elseif value.__type == "Vector2" then
            return Vector2.new(value.X, value.Y)
        elseif value.__type == "Vector3" then
            return Vector3.new(value.X, value.Y, value.Z)
        elseif value.__type == "UDim2" then
            return UDim2.new(value.XS, value.XO, value.YS, value.YO)
        elseif value.__type == "Enum" then
            local ok, enumType = pcall(function() return Enum[value.EnumType] end)
            return ok and enumType and enumType[value.Name] or nil
        end

        local out = {}
        for k, v in pairs(value) do
            if k ~= "__isArray" then
                out[k] = decodeValue(v)
            end
        end
        return out
    end

    ------------------------------------------------------------
    -- Public API
    ------------------------------------------------------------

    local function serializeAllFlags()
        local raw = Flags.GetAllFlags()
        local encoded = {}
        for k, v in pairs(raw) do
            if not k:match("^__CornUi") then -- don't persist internal bookkeeping flags
                encoded[k] = encodeValue(v)
            end
        end

        local ok, json = pcall(HttpService.JSONEncode, HttpService, encoded)
        if not ok then
            return nil, "Encode failed: " .. tostring(json)
        end
        return json
    end

    -- Applies a decoded config table to the live Flags store. UI sync happens
    -- automatically via SetFlag -> element.Set.
    local function applyConfigTable(data)
        for k, v in pairs(data) do
            Flags.SetFlag(k, decodeValue(v))
        end
    end

    function Config.SaveConfig(name)
        assert(type(name) == "string" and #name > 0, "SaveConfig: name must be a non-empty string")

        if not writefile then
            return false, "Executor does not support file writes"
        end
        ensureFolder()

        local json, encodeErr = serializeAllFlags()
        if not json then
            return false, encodeErr
        end

        local ok, err = pcall(writefile, FOLDER_NAME .. "/" .. name .. ".json", json)
        if not ok then
            return false, "Write failed: " .. tostring(err)
        end

        Flags.SetFlag(AUTOSAVE_FLAG, name, true)
        return true
    end

    -- Returns the JSON string for the current flag state without touching the
    -- filesystem — for hubs that keep configs in a DataStore / webhook.
    function Config.ExportConfig()
        local json, encodeErr = serializeAllFlags()
        if not json then
            return nil, encodeErr
        end
        return json
    end

    function Config.LoadConfig(name)
        assert(type(name) == "string" and #name > 0, "LoadConfig: name must be a non-empty string")

        if not readfile then
            return false, "Executor does not support file reads"
        end

        local path = FOLDER_NAME .. "/" .. name .. ".json"
        if not (isfile and isfile(path)) then
            return false, "Config '" .. name .. "' does not exist"
        end

        local ok, json = pcall(readfile, path)
        if not ok then
            return false, "Read failed: " .. tostring(json)
        end

        local okDecode, data = pcall(HttpService.JSONDecode, HttpService, json)
        if not okDecode then
            return false, "Decode failed: " .. tostring(data)
        end

        applyConfigTable(data)
        Flags.SetFlag(AUTOSAVE_FLAG, name, true)
        return true
    end

    -- Applies an exported JSON string to the live Flags store (inverse of
    -- ExportConfig). Returns true, or false + reason.
    function Config.ImportConfig(jsonText)
        assert(type(jsonText) == "string" and #jsonText > 0, "ImportConfig: jsonText must be a non-empty string")

        local okDecode, data = pcall(HttpService.JSONDecode, HttpService, jsonText)
        if not okDecode then
            return false, "Decode failed: " .. tostring(data)
        end
        if type(data) ~= "table" then
            return false, "Config JSON must decode to an object"
        end

        applyConfigTable(data)
        return true
    end

    function Config.ListConfigs()
        ensureFolder()
        if not listfiles then return {} end

        local out = {}
        for _, path in ipairs(listfiles(FOLDER_NAME)) do
            local fileName = path:match("([^/\\]+)%.json$")
            if fileName then
                table.insert(out, fileName)
            end
        end
        table.sort(out)
        return out
    end

    function Config.DeleteConfig(name)
        local path = FOLDER_NAME .. "/" .. name .. ".json"
        if isfile and isfile(path) and delfile then
            delfile(path)
            return true
        end
        return false, "Config not found or executor lacks delfile"
    end

    ------------------------------------------------------------
    -- Share / cloud: configs as portable strings (clipboard) and URLs.
    -- The string form is base64-wrapped with a "CornUiC1:" prefix so a
    -- pasted blob is recognisable and never decodes by accident.
    ------------------------------------------------------------

    local EXPORT_PREFIX = "CornUiC1:"

    function Config.ExportToString()
        local json, encodeErr = serializeAllFlags()
        if not json then
            return nil, encodeErr
        end
        local ok, b64 = pcall(HttpService.Base64Encode, HttpService, json)
        if not ok then
            return nil, "Base64 failed: " .. tostring(b64)
        end
        return EXPORT_PREFIX .. b64
    end

    function Config.ImportFromString(str)
        assert(type(str) == "string" and #str > 0, "ImportFromString: str must be a non-empty string")
        if str:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
            return false, "Not a CornUi config string (missing '" .. EXPORT_PREFIX .. "' prefix)"
        end

        local ok, json = pcall(HttpService.Base64Decode, HttpService, str:sub(#EXPORT_PREFIX + 1))
        if not ok then
            return false, "Base64 failed: " .. tostring(json)
        end
        return Config.ImportConfig(json)
    end

    -- Copies the current config to the clipboard as a portable string.
    -- Returns (true, shareString) or (false, reason) when clipboard is
    -- unavailable — the caller can still fall back to ExportToString().
    function Config.CopyToString()
        if not Host then
            return false, "Host module not loaded"
        end
        local str, encodeErr = Config.ExportToString()
        if not str then
            return false, encodeErr
        end
        if not Host.SetClipboard(str) then
            return false, "clipboard write unavailable on this executor"
        end
        return true, str
    end

    -- Reads a config string from the clipboard (needs a getclipboard global;
    -- not every executor has one).
    function Config.PasteFromString()
        if not Host then
            return false, "Host module not loaded"
        end
        local ok, text = Host.GetClipboard()
        if not ok then
            return false, text
        end
        return Config.ImportFromString(text)
    end

    -- Fetches a config JSON from any URL (gist, repo raw file, personal
    -- host) and applies it to the live Flags store.
    function Config.LoadFromUrl(url)
        assert(type(url) == "string" and #url > 0, "LoadFromUrl: url must be a non-empty string")
        if not Host then
            return false, "Host module not loaded"
        end

        local ok, body = Host.HttpGet(url)
        if not ok then
            return false, "Fetch failed: " .. tostring(body)
        end
        return Config.ImportConfig(body)
    end

    -- Debounced autosave: flags are written `intervalSeconds` after the LAST
    -- change (not on every change), so flag-spamming gameplay doesn't hit the
    -- disk repeatedly. Returns a stop() function — Window:EnableAutoSave wires
    -- that into its cleanup registry for you.
    function Config.EnableAutoSave(name, intervalSeconds)
        assert(type(name) == "string" and #name > 0, "EnableAutoSave: name must be a non-empty string")
        local interval = intervalSeconds or 5

        local pendingToken = 0
        local conn = Flags.FlagChanged:Connect(function()
            pendingToken += 1
            local myToken = pendingToken
            task.delay(interval, function()
                if myToken == pendingToken then
                    -- SaveConfig sets __CornUi_LastConfig, whose FlagChanged
                    -- event fires once (old ~= value) and then goes quiet —
                    -- no resave loop.
                    Config.SaveConfig(name)
                end
            end)
        end)

        return function()
            conn:Disconnect()
        end
    end

    return Config
end
