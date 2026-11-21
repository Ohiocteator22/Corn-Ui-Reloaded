--[[
    CornUi v2.2 — Systems/Host.lua
    The single integration point with the executor/host environment: HTTP
    (GET + POST), clipboard, teleport queueing, executor identity.

    Every capability is capability-detected (the executor globals these
    features rely on vary by executor) and pcall-guarded — functions return
    (ok, result) and degrade to a warn() instead of throwing, so a hub keeps
    working on hosts that expose fewer globals.
]]

return function(Modules)

    local Host = {}

    local HttpService = game:GetService("HttpService")

    ------------------------------------------------------------
    -- HTTP GET — via game:HttpGet (available on effectively every executor)
    ------------------------------------------------------------

    function Host.HttpGet(url)
        local ok, body = pcall(game.HttpGet, game, url)
        if not ok or type(body) ~= "string" then
            return false, body
        end
        return true, body
    end

    ------------------------------------------------------------
    -- Full request (POST for webhooks etc.). Tries the request-capable
    -- globals in the order executors commonly expose them.
    ------------------------------------------------------------

    local function findRequestImpl()
        if type(request) == "function" then return request end
        if type(http_request) == "function" then return http_request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        return nil
    end

    -- Host.Request({ Url, Method = "POST", Headers = {...}, Body }) ->
    --   (ok, bodyOrError)
    -- Body tables are JSON-encoded automatically.
    function Host.Request(opts)
        opts = opts or {}
        local impl = findRequestImpl()
        if not impl then
            return false, "no request-capable global on this executor"
        end

        local body = opts.Body
        if type(body) == "table" then
            local ok, encoded = pcall(HttpService.JSONEncode, HttpService, body)
            if not ok then
                return false, encoded
            end
            body = encoded
        end

        local payload = {
            Url = opts.Url,
            Method = opts.Method or "GET",
            Headers = opts.Headers,
            Body = body,
        }

        local ok, response = pcall(impl, payload)
        if not ok then
            return false, response
        end
        if type(response) == "table" then
            local success = response.Success ~= false
            if success and response.Body ~= nil then
                return true, response.Body
            end
            return success, response.Body or response.ErrorMessage
        end
        return true, response
    end

    ------------------------------------------------------------
    -- Clipboard — every capability the executors came up with, in order.
    ------------------------------------------------------------

    function Host.SetClipboard(text)
        local impl
        if type(setclipboard) == "function" then impl = setclipboard end
        if not impl and type(toclipboard) == "function" then impl = toclipboard end
        if not impl and type(set_clipboard) == "function" then impl = set_clipboard end
        if not impl then
            warn("[CornUi] Host.SetClipboard: no clipboard global on this executor")
            return false
        end

        local ok, err = pcall(impl, text)
        if not ok then
            warn("[CornUi] Host.SetClipboard failed: " .. tostring(err))
            return false
        end
        return true
    end

    -- Returns (true, text) or (false, reason). Clipboard READ is rarer than
    -- write across executors — callers must handle the false case.
    function Host.GetClipboard()
        local impl
        if type(getclipboard) == "function" then impl = getclipboard end
        if not impl and type(get_clipboard) == "function" then impl = get_clipboard end
        if not impl then
            return false, "no getclipboard global on this executor"
        end

        local ok, value = pcall(impl)
        if not ok then
            return false, value
        end
        return true, value
    end

    ------------------------------------------------------------
    -- Teleport queueing — re-run code after a game teleport (server hop,
    -- rejoin). Named differently per executor; unavailable ones just warn.
    ------------------------------------------------------------

    function Host.QueueOnTeleport(fn)
        assert(type(fn) == "function", "QueueOnTeleport: fn must be a function")

        local impl
        if type(queue_on_teleport) == "function" then impl = queue_on_teleport end
        if not impl and type(teleport_queue) == "table" and type(teleport_queue.on_teleport) == "function" then
            impl = teleport_queue.on_teleport
        end
        if not impl then
            warn("[CornUi] Host.QueueOnTeleport: not supported on this executor")
            return false
        end

        local ok, err = pcall(impl, fn)
        if not ok then
            warn("[CornUi] Host.QueueOnTeleport failed: " .. tostring(err))
            return false
        end
        return true
    end

    ------------------------------------------------------------
    -- Executor identity — purely informational (shown in the statusbar).
    ------------------------------------------------------------

    function Host.Identify()
        if type(identifyexecutor) == "function" then
            local ok, name = pcall(identifyexecutor)
            if ok and type(name) == "string" and #name > 0 then
                return name
            end
        end
        return "Unknown"
    end

    return Host
end
