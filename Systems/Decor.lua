--[[
    CornUi - Systems/Decor.lua  (Draft 4: Christmas decorations)

    Pure-Frame decorations (no assets, no Drawing library):
      - Lights    a draped string of twinkling bulbs along the top of the window
      - Snow      a snow-covered top edge plus a light flurry drifting inside
      - Icicles   short icicles hanging from the header's lower edge
      - Holly     a leaf-and-berry sprig in the bottom-left corner
      - Hat       a Santa hat on the floating open/close button

    Config - CreateWindow({ Decor = ... }):
        Decor = false                         -- none at all
        Decor = { Lights = true, Snow = true, Icicles = true, Holly = true, Hat = true }
        (omitted = everything on; set a key to false to drop just that part)

    Runtime:
        window:SetDecor(false)   -- hide / show everything
        window:IsDecorOn()

    Colors are deliberately off-round so Window:SetTheme's color re-mapper never
    mistakes a decoration for a themed surface. Under PerformanceMode or
    ReducedMotion the decorations are drawn static (no twinkle, sway or flurry).
]]

return function(Modules)
    local Library = Modules
    local Render = Modules.Render
    local create = Render.create
    local corner = Render.corner
    local RunService = Render.RunService
    local WM = Modules.WindowMethods

    local Decor = {}

    local SNOW = Color3.fromRGB(244, 251, 254)
    local ICICLE = Color3.fromRGB(186, 226, 249)
    local RED = Color3.fromRGB(214, 52, 61)
    local DEEP_RED = Color3.fromRGB(176, 36, 48)
    local GREEN = Color3.fromRGB(46, 139, 88)
    local DEEP_GREEN = Color3.fromRGB(31, 104, 66)
    local GOLD = Color3.fromRGB(253, 203, 82)
    local BLUE = Color3.fromRGB(118, 188, 252)
    local WIRE = Color3.fromRGB(41, 108, 76)
    local BULB_COLORS = { RED, GOLD, GREEN, BLUE }

    local Z = 12 -- above the header (2) and body content, below notifications

    local function round(n) return math.floor(n + 0.5) end

    local SWAGS = 4
    local function wireOffset(x)
        local u = (x * SWAGS) % 1
        return 2 + 5 * (4 * u * (1 - u))
    end

    ------------------------------------------------------------
    -- window decorations
    ------------------------------------------------------------
    local function buildLights(root, animated, bulbs)
        for i = 0, 63 do
            local x = i / 63
            create("Frame", {
                Size = UDim2.fromOffset(2, 2),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(x, 0, 0, wireOffset(x)),
                BackgroundColor3 = WIRE,
                BorderSizePixel = 0,
                ZIndex = Z + 1,
            }).Parent = root
        end
        local count = 18
        for i = 1, count do
            local x = (i - 0.5) / count
            local y = wireOffset(x)
            local color = BULB_COLORS[(i - 1) % #BULB_COLORS + 1]
            create("Frame", {
                Size = UDim2.fromOffset(3, 3),
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(x, 0, 0, y),
                BackgroundColor3 = Color3.fromRGB(44, 48, 56),
                BorderSizePixel = 0,
                ZIndex = Z + 1,
            }).Parent = root
            local bulb = create("Frame", {
                Size = UDim2.fromOffset(6, 8),
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(x, 0, 0, y + 2),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                ZIndex = Z + 2,
            }, { corner(999) })
            bulb.Parent = root
            bulbs[i] = bulb
        end
    end

    local function buildSnowCap(root)
        local blobs = 16
        for i = 1, blobs do
            local h = math.random(5, 9)
            local w = 1 / blobs * (1.5 + math.random() * 0.6)
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new((i - 0.5) / blobs + (math.random() - 0.5) * 0.015, 0, 0, -round(h * 0.45)),
                Size = UDim2.new(w, 0, 0, h),
                BackgroundColor3 = SNOW,
                BackgroundTransparency = 0.04,
                BorderSizePixel = 0,
                ZIndex = Z,
            }, { corner(999) }).Parent = root
        end
    end

    local function buildIcicles(root, headerH)
        local count = 14
        for i = 1, count do
            local len = math.random(5, 10)
            local w = math.random(3, 5)
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new((i - 0.5) / count + (math.random() - 0.5) * 0.03, 0, 0, headerH - 1),
                Size = UDim2.fromOffset(w, len),
                BackgroundColor3 = ICICLE,
                BackgroundTransparency = 0.22,
                BorderSizePixel = 0,
                ZIndex = Z,
            }, { corner(999) }).Parent = root
        end
    end

    local function leaf(parent, x, y, rot)
        create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(18, 8),
            Rotation = rot,
            BackgroundColor3 = (rot % 2 == 0) and GREEN or DEEP_GREEN,
            BorderSizePixel = 0,
            ZIndex = Z + 1,
        }, { corner(999) }).Parent = parent
    end

    local function buildHolly(root)
        local holly = create("Frame", {
            Name = "Holly",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 6, 1, -4),
            Size = UDim2.fromOffset(40, 28),
            ZIndex = Z + 1,
        })
        holly.Parent = root
        leaf(holly, 12, 18, -30)
        leaf(holly, 24, 18, 30)
        leaf(holly, 18, 11, -88)
        leaf(holly, 10, 10, -62)
        leaf(holly, 27, 10, 62)
        for _, b in ipairs({ { 16, 17 }, { 22, 18 }, { 19, 13 } }) do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(b[1], b[2]),
                Size = UDim2.fromOffset(7, 7),
                BackgroundColor3 = RED,
                BorderSizePixel = 0,
                ZIndex = Z + 2,
            }, { corner(999) }).Parent = holly
        end
        -- berry highlights
        for _, b in ipairs({ { 15, 16 }, { 21, 17 }, { 18, 12 } }) do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(b[1], b[2]),
                Size = UDim2.fromOffset(2, 2),
                BackgroundColor3 = SNOW,
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                ZIndex = Z + 3,
            }, { corner(999) }).Parent = holly
        end
    end

    ------------------------------------------------------------
    -- santa hat for the floating button
    ------------------------------------------------------------
    local function buildHat(floatBtn)
        local S = floatBtn.Size.X.Offset
        if S <= 0 then S = 44 end

        local holder = create("Frame", {
            Name = "SantaHat",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(S, S),
            Position = UDim2.fromOffset(0, 0),
            Rotation = -10,
            ZIndex = 56,
        })
        holder.Parent = floatBtn

        local function piece(cx, cy, w, h, rot, color, z, radius)
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(round(cx * S), round(cy * S)),
                Size = UDim2.fromOffset(round(w * S), round(h * S)),
                Rotation = rot,
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                ZIndex = z,
            }, { corner(radius or 999) }).Parent = holder
        end

        piece(0.46, -0.03, 0.62, 0.36, -8, RED, 56, round(S * 0.14))
        piece(0.42, -0.27, 0.42, 0.32, -22, DEEP_RED, 56, round(S * 0.12))
        piece(0.53, -0.45, 0.28, 0.24, 28, RED, 56, round(S * 0.1))
        piece(0.5, 0.13, 0.84, 0.2, 0, SNOW, 57) -- brim
        piece(0.68, -0.36, 0.22, 0.22, 0, SNOW, 58) -- pompom
        return holder
    end

    ------------------------------------------------------------
    -- attach
    ------------------------------------------------------------
    function Decor.Attach(window, parts)
        local main, header, floatBtn = parts.main, parts.header, parts.floatBtn
        local cfg = parts.config
        if cfg == false then return end
        if type(cfg) ~= "table" then cfg = {} end

        local static = Library.Flags.ReducedMotion or Library.Flags.PerformanceMode
        local headerH = header.Size.Y.Offset

        local root = create("Frame", {
            Name = "Decor",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            ZIndex = Z,
        })
        root.Parent = main

        local bulbs, flakes = {}, {}

        if cfg.Snow ~= false then buildSnowCap(root) end
        if cfg.Lights ~= false then buildLights(root, not static, bulbs) end
        if cfg.Icicles ~= false then buildIcicles(root, headerH) end
        if cfg.Holly ~= false then buildHolly(root) end

        if cfg.Snow ~= false and not static then
            for i = 1, 12 do
                local size = math.random(2, 4)
                local f = create("Frame", {
                    Size = UDim2.fromOffset(size, size),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = SNOW,
                    BackgroundTransparency = 0.45 + math.random() * 0.3,
                    BorderSizePixel = 0,
                    ZIndex = Z - 1,
                }, { corner(999) })
                f.Parent = root
                flakes[i] = {
                    f = f,
                    x0 = math.random(),
                    y = math.random(),
                    vy = 0.05 + math.random() * 0.1,
                    amp = 0.008 + math.random() * 0.02,
                    freq = 0.8 + math.random() * 1.2,
                    phase = math.random() * 6.28,
                }
            end
        end

        local hat
        if cfg.Hat ~= false and floatBtn then
            hat = buildHat(floatBtn)
        end

        local handle = { root = root, hat = hat, on = true }
        window._decor = handle

        if not static then
            local clock = 0
            local conn
            conn = RunService.Heartbeat:Connect(function(dt)
                if not main.Parent then
                    conn:Disconnect()
                    return
                end
                if not handle.on then return end
                clock += math.min(dt, 0.05)

                if main.Visible then
                    for i, b in ipairs(bulbs) do
                        b.BackgroundTransparency = 0.02 + 0.5 * (0.5 + 0.5 * math.sin(clock * 2.6 - i * 0.85))
                    end
                    for _, s in ipairs(flakes) do
                        s.y += s.vy * dt
                        if s.y > 1.03 then
                            s.y = -0.03
                            s.x0 = math.random()
                        end
                        s.f.Position = UDim2.new(s.x0 + math.sin(clock * s.freq + s.phase) * s.amp, 0, s.y, 0)
                    end
                end
                if hat then
                    hat.Rotation = -10 + math.sin(clock * 1.5) * 3
                end
            end)
        end
    end

    function WM:SetDecor(enabled)
        local d = self._decor
        if not d then return end
        d.on = enabled and true or false
        d.root.Visible = d.on
        if d.hat then d.hat.Visible = d.on end
    end

    function WM:IsDecorOn()
        return self._decor ~= nil and self._decor.on == true
    end

    return Decor
end
