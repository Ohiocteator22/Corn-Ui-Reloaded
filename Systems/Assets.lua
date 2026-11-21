--[[
    Systems/Assets.lua
    Universal image-source resolution for CornUi.

    Turns every source script authors actually use into paintable Image
    content, so any prop that feeds Render's Icon (window icon, tab icon,
    button Icon, CreateImage, DiscordButton) accepts them all:

      * 12345                    -> "rbxassetid://12345"
      * "rbxassetid://12345"     -> passthrough
      * "https://host/icon.png"  -> game:HttpGet -> writefile -> getcustomasset
      * "SomeFolder/icon.png"    -> getcustomasset on an existing local file
      * "logo"                   -> embedded pack (Systems/AssetsEmbed.lua)

    URL sources are cached on disk under CacheDir, validated by PNG magic
    bytes (so an HTML error page never gets cached as an icon), and hit the
    network only once per unique URL. Every step degrades gracefully: on
    executors without writefile/getcustomasset, or in Studio, URL/embedded
    sources resolve to nil, the element simply hides the icon, and the rest
    of the UI keeps building.
]]

local PNG_MAGIC = "\137PNG\r\n\026\n"
local CACHE_DIR = "CornUiAssets"

return function(Modules)
    local Assets = {}

    Assets.CacheDir = CACHE_DIR

    -- Capabilities are checked at call time (not load time) so Studio and
    -- restricted executors take the graceful path instead of erroring.
    local function caps()
        local okHttp = false
        pcall(function() okHttp = type(game.HttpGet) == "function" end)
        return {
            http = okHttp,
            write = type(writefile) == "function",
            custom = type(getcustomasset) == "function",
        }
    end

    -- Pure-Lua base64 decoder: the embedded pack must work even on executors
    -- without crypt.base64decode. Handles padding and ignores whitespace.
    local B64 = {}
    do
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        for i = 1, #chars do B64[chars:sub(i, i)] = i - 1 end
    end

    local function base64Decode(data)
        data = data:gsub("[^%w%+%/=]", "")
        local out = {}
        local buf, bits = 0, 0
        for i = 1, #data do
            local c = data:sub(i, i)
            if c == "=" then break end
            local v = B64[c]
            if not v then return nil end
            buf = buf * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                out[#out + 1] = string.char(math.floor(buf / 2 ^ bits) % 256)
                buf = buf % (2 ^ bits)
            end
        end
        return table.concat(out)
    end

    local function hash(s)
        local h = 5381
        for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
        return ("%.8x"):format(h)
    end

    local function cacheName(url, name)
        if name then return tostring(name) end
        local path = url:match("^%a[%w%+%-%.]*://(.+)$") or url -- strip protocol ("https:" would otherwise leak into the name)
        local base = path:match("([^/%?]+)/?$") or "asset" -- trailing path segment, not the host
        base = base:gsub("[^%w%._%-]", "_"):sub(1, 40)
        if not base:match("%.%a+$") then base = base .. ".png" end
        return hash(url) .. "_" .. base
    end

    local function ensureFolder()
        if isfolder and not isfolder(CACHE_DIR) and makefolder then
            local ok = pcall(makefolder, CACHE_DIR)
            if not ok then return false end
        end
        return true
    end

    -- Fetch a PNG over HTTP, cache it on disk, return getcustomasset content.
    -- Second call for the same URL serves from disk without touching the net.
    function Assets.FromUrl(url, name)
        assert(type(url) == "string" and url ~= "", "Assets.FromUrl: url must be a non-empty string")
        local c = caps()
        if not (c.http and c.write and c.custom) then
            local missing = not c.http and "HttpGet" or (not c.write and "writefile" or "getcustomasset")
            warn(("[CornUi] Assets: URL images need HttpGet + writefile + getcustomasset; %s is unavailable here, skipping %s")
                :format(missing, url))
            return nil
        end
        if not ensureFolder() then return nil end

        local path = CACHE_DIR .. "/" .. cacheName(url, name)

        if isfile and isfile(path) then
            local ok, content = pcall(getcustomasset, path)
            if ok and type(content) == "string" then return content end
        end

        local okBytes, bytes = pcall(function() return game:HttpGet(url) end)
        if not okBytes or type(bytes) ~= "string" or #bytes == 0 then
            warn("[CornUi] Assets: download failed for " .. url)
            return nil
        end
        if bytes:sub(1, #PNG_MAGIC) ~= PNG_MAGIC then
            warn("[CornUi] Assets: " .. url .. " did not return PNG data (wrong content or an error page?)")
            return nil
        end
        if not pcall(writefile, path, bytes) then
            warn("[CornUi] Assets: writefile failed for " .. path)
            return nil
        end

        local ok, content = pcall(getcustomasset, path)
        if not ok or type(content) ~= "string" then
            warn("[CornUi] Assets: getcustomasset failed for " .. path)
            return nil
        end
        return content
    end

    -- Load an image from a local file already on disk (executor workspace).
    function Assets.FromFile(path)
        if type(getcustomasset) ~= "function" then
            warn("[CornUi] Assets: getcustomasset is not available in this environment")
            return nil
        end
        if isfile and not isfile(path) then
            warn("[CornUi] Assets: file not found: " .. tostring(path))
            return nil
        end
        local ok, content = pcall(getcustomasset, path)
        if ok and type(content) == "string" then return content end
        warn("[CornUi] Assets: could not load custom asset: " .. tostring(path))
        return nil
    end

    -- Raw bytes of an embedded pack icon ("logo", "gear", "sword", ...).
    function Assets.Embedded(name)
        local pack = Modules.AssetsEmbed
        local b64 = pack and pack[name]
        if not b64 then
            local known = {}
            if pack then for k in pairs(pack) do known[#known + 1] = k end end
            warn("[CornUi] Assets: no embedded icon named '"
                .. tostring(name) .. "' (available: " .. table.concat(known, ", ") .. ")")
            return nil
        end
        return base64Decode(b64)
    end

    -- Embedded icon -> cache file -> getcustomasset, mirroring FromUrl.
    function Assets.FromEmbedded(name)
        local bytes = Assets.Embedded(name)
        if not bytes then return nil end
        local c = caps()
        if not (c.write and c.custom) then
            warn("[CornUi] Assets: embedded icons need writefile + getcustomasset; unavailable here, skipping '" .. tostring(name) .. "'")
            return nil
        end
        if not ensureFolder() then return nil end
        local path = CACHE_DIR .. "/" .. tostring(name) .. ".png"
        if isfile and not isfile(path) then
            if not pcall(writefile, path, bytes) then
                warn("[CornUi] Assets: writefile failed for " .. path)
                return nil
            end
        end
        local ok, content = pcall(getcustomasset, path)
        if ok and type(content) == "string" then return content end
        warn("[CornUi] Assets: getcustomasset failed for " .. path)
        return nil
    end

    -- The one entry point every consumer uses (aliased as Resolve).
    function Assets.Get(source, name)
        local t = type(source)
        if t == "number" then
            return "rbxassetid://" .. tostring(source)
        elseif t == "string" then
            if source == "" then return nil end
            if source:match("^rbxasset") or source:match("^rbxthumb") then return source end
            if source:match("^https?://") then return Assets.FromUrl(source, name) end
            if source:match("^%d+$") then return "rbxassetid://" .. source end
            if source:match("[/\\]") or source:match("%.%w+$") then
                return Assets.FromFile(source)
            end
            if Modules.AssetsEmbed and Modules.AssetsEmbed[source] then
                return Assets.FromEmbedded(source)
            end
            warn("[CornUi] Assets: unknown image source '" .. source .. "'")
            return nil
        end
        return nil
    end

    Assets.Resolve = Assets.Get

    -- Warm the cache before building the UI: Assets.Preload{ url1, { Url = u2, Name = "banner" } }
    function Assets.Preload(list)
        local out = {}
        for i, item in ipairs(list) do
            if type(item) == "string" then
                out[i] = Assets.Get(item)
            elseif type(item) == "table" and type(item.Url) == "string" then
                out[i] = Assets.Get(item.Url, item.Name)
            end
        end
        return out
    end

    -- Wipe the on-disk cache (delfolder is required; a no-op without it).
    function Assets.Flush()
        if type(delfolder) == "function" then
            pcall(delfolder, CACHE_DIR)
            return true
        end
        warn("[CornUi] Assets: delfolder not available; cache kept on disk")
        return false
    end

    return Assets
end
