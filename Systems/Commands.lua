--[[
    CornUi v2.0 — Systems/Commands.lua
    Central command registry backing Cornelius (the command palette).
    Anything user-reachable — toggles, sliders, tab switches, config
    actions — can register itself here, and the palette UI (Elements/
    CommandPalette.lua) searches and runs entries.

    Registration is cheap (one table insert); the palette UI is built
    lazily and only when the hub opts into it, so hubs that never open
    Cornelius pay nothing beyond the registry itself.

    API:
        Commands.Register({ Id, Title, Keywords, Hint, Owner, Run })
        Commands.Unregister(id)
        Commands.Release(owner) -- unregister everything owned by `owner`
        Commands.Search(query)  -> ranked array of entries
        Commands.Run(id)        -> bool (found)
        Commands.Count()
]]

return function(Modules)

    local Commands = {}

    local Registry = {}   -- array of entries, registration order
    local ById = {}       -- [id] = entry

    -- props = {
    --     Id       = "CornUi.Toggle.MyFlag",  -- unique; re-registering replaces
    --     Title    = "Toggle: Aimbot",        -- what the palette shows
    --     Keywords = "aimbot esp combat",     -- extra search words (lowercase ok)
    --     Hint     = "On" | function() return "On" end,  -- optional right-aligned
    --                                                 -- status; a function is
    --                                                 -- evaluated at render time
    --     Owner    = windowTable,             -- optional; all entries sharing an
    --                                             Owner are released together when
    --                                             that window is destroyed
    --     Run      = function() end,
    -- }
    function Commands.Register(props)
        assert(type(props.Id) == "string", "Commands.Register: props.Id must be a string")
        assert(type(props.Title) == "string", "Commands.Register: props.Title must be a string")
        assert(type(props.Run) == "function", "Commands.Register: props.Run must be a function")

        -- Re-registering an existing Id (e.g. an element was rebuilt) replaces
        -- the old entry instead of duplicating it.
        if ById[props.Id] then
            Commands.Unregister(props.Id)
        end

        local entry = {
            Id = props.Id,
            Title = props.Title,
            Keywords = string.lower(props.Keywords or ""),
            Hint = props.Hint,
            Owner = props.Owner,
            Run = props.Run,
        }
        ById[props.Id] = entry
        table.insert(Registry, entry)
        return props.Id
    end

    -- Releases every entry owned by `owner` (a window). Multi-window CornUi:
    -- a destroyed sub-UI must not leave its commands behind — running one
    -- would poke at instances that no longer exist.
    function Commands.Release(owner)
        local removed = 0
        for i = #Registry, 1, -1 do
            if Registry[i].Owner == owner then
                ById[Registry[i].Id] = nil
                table.remove(Registry, i)
                removed += 1
            end
        end
        return removed
    end

    function Commands.Unregister(id)
        local entry = ById[id]
        if not entry then return false end
        ById[id] = nil
        for i, cmd in ipairs(Registry) do
            if cmd == entry then
                table.remove(Registry, i)
                break
            end
        end
        return true
    end

    -- Bounded edit distance (optimal-string-alignment: insert, delete,
    -- substitute and adjacent-transpose), bailing out as soon as a whole
    -- DP row exceeds `maxDist` — per-keystroke cost stays negligible even
    -- with a few hundred registered commands. Returns the distance or nil.
    local function FuzzyDistance(word, target, maxDist)
        local m, n = #word, #target
        if m - n > maxDist or n - m > maxDist then return nil end

        local prev2, prev = nil, {}
        for j = 0, n do prev[j] = j end

        for i = 1, m do
            local cur = { [0] = i }
            local rowMin = i
            local wi = string.byte(word, i)
            for j = 1, n do
                local cost = (wi == string.byte(target, j)) and 0 or 1
                local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                if i > 1 and j > 1
                    and wi == string.byte(target, j - 1)
                    and string.byte(word, i - 1) == string.byte(target, j)
                then
                    local t = prev2[j - 2] + 1
                    if t < v then v = t end
                end
                cur[j] = v
                if v < rowMin then rowMin = v end
            end
            if rowMin > maxDist then return nil end
            prev2, prev = prev, cur
        end

        local d = prev[n]
        return d <= maxDist and d or nil
    end

    -- Fuzzy tier: does `word` land within tolerance of any punctuation-
    -- trimmed token of `text`? Words shorter than 4 letters never go
    -- fuzzy — they match too much noise to be useful.
    local function FuzzyMatch(word, text)
        if #word < 4 then return false end
        local maxDist = (#word <= 6) and 1 or 2
        for raw in text:gmatch("%S+") do
            -- trimmed local (not the loop var, which is const under strict Lua)
            local token = raw:gsub("^%W+", ""):gsub("%W+$", "")
            if #token >= #word - maxDist and #token <= #word + maxDist
                and FuzzyDistance(word, token, maxDist) then
                return true
            end
        end
        return false
    end

    -- Ranked search. The query is tokenized: every word must match the
    -- title or keywords (AND). Word scoring — title prefix beats title
    -- substring beats keyword hit, with a fuzzy tier (bounded edit
    -- distance, so "togle" still reaches "Toggle aimlock") as the last
    -- resort. An entry's score is its WORST-matching word, so entries
    -- that matched every word exactly always outrank partly-fuzzy ones.
    -- Empty query returns the registry in registration order (capped).
    function Commands.Search(query, maxResults)
        maxResults = maxResults or 30
        query = string.lower(query or "")

        local words = {}
        for word in query:gmatch("%S+") do
            table.insert(words, word)
        end

        if #words == 0 then
            local results = {}
            for i, entry in ipairs(Registry) do
                if i > maxResults then break end
                table.insert(results, entry)
            end
            return results
        end

        local scored = {}
        for _, entry in ipairs(Registry) do
            local title = string.lower(entry.Title)
            local worst = 0
            local matchedAll = true

            for _, word in ipairs(words) do
                local score
                if title:sub(1, #word) == word then
                    score = 0
                elseif title:find(word, 1, true) then
                    score = 1
                elseif entry.Keywords:find(word, 1, true) then
                    score = 2
                elseif FuzzyMatch(word, title) then
                    score = 3
                elseif FuzzyMatch(word, entry.Keywords) then
                    score = 4
                else
                    matchedAll = false
                    break
                end
                if score > worst then worst = score end
            end

            if matchedAll then
                table.insert(scored, { Score = worst, Entry = entry })
            end
        end

        table.sort(scored, function(a, b)
            if a.Score ~= b.Score then return a.Score < b.Score end
            return a.Entry.Title < b.Entry.Title
        end)

        local results = {}
        for i, item in ipairs(scored) do
            if i > maxResults then break end
            table.insert(results, item.Entry)
        end
        return results
    end

    function Commands.Run(id)
        local entry = ById[id]
        if not entry then return false end
        task.spawn(entry.Run)
        return true
    end

    function Commands.Get(id)
        return ById[id]
    end

    function Commands.Count()
        return #Registry
    end

    return Commands
end
