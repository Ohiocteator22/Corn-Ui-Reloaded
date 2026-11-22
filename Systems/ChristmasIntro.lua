--[[
    CornUi - Systems/ChristmasIntro.lua  (Draft 1)

    Seasonal intro:  night sky + falling snow + light garland
        -> "Merry Christmas" pops in letter by letter
        -> frostbite creeps in from the screen edges and freezes the text
        -> ice cracks from the centre
        -> everything shatters and falls away, revealing the window.

    Everything is drawn with plain Frames (no assets, no Drawing library), so it
    works on any executor. One Heartbeat connection drives all motion; it is
    disconnected the moment the intro finishes or is skipped.

    Config (all optional) - passed as CreateWindow({ Intro = { ... } }):
        Style    = "Christmas" | "Classic"   -- "Classic" = the original wipe intro
        Title    = "Merry Christmas"
        Text     = "-By Lifeless"            -- small line under the title
        Duration = 1.1                       -- seconds the title is held before freezing
        Snow     = true
        Skip     = true                      -- show the Skip button
    CreateWindow({ Intro = false }) skips it entirely.
]]

return function(Modules)
    local Render = Modules.Render
    local TweenService = Render.TweenService
    local RunService = Render.RunService
    local create = Render.create

    local TextService = game:GetService("TextService")

    local Intro = {}

    local ICE = Color3.fromRGB(205, 236, 255)
    local WHITE = Color3.fromRGB(245, 252, 255)
    local RED = Color3.fromRGB(232, 62, 66)
    local GREEN = Color3.fromRGB(72, 190, 108)
    local GOLD = Color3.fromRGB(255, 205, 80)
    local BLUE = Color3.fromRGB(120, 190, 255)
    local BULB_COLORS = { RED, GOLD, GREEN, BLUE }

    local function tw(inst, props, t, style, dir)
        local tween = TweenService:Create(
            inst,
            TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
            props
        )
        tween:Play()
        return tween
    end

    local function rand(a, b)
        return a + math.random() * (b - a)
    end

    local function round(n)
        return math.floor(n + 0.5)
    end

    -- six-armed snow crystal built from three crossed bars
    local function makeFlake(size, color, z)
        local holder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size, size),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = z,
        })
        local thick = math.max(2, round(size / 14))
        for i = 0, 2 do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, 0, 0, thick),
                Rotation = i * 60,
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                ZIndex = z,
            }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) }).Parent = holder
        end
        return holder
    end

    -- the wire sags between three pegs
    local SWAGS = 3
    local function wireY(x)
        local u = (x * SWAGS) % 1
        return 0.012 + 0.05 * (4 * u * (1 - u))
    end

    function Intro.Play(screenGui, cfg)
        cfg = cfg or {}
        local title = cfg.Title or "Merry Christmas"
        local subText = cfg.Text or "-By Lifeless"
        local hold = cfg.Duration or 1.1
        local useSnow = cfg.Snow ~= false

        local abs = screenGui.AbsoluteSize
        if abs.X < 2 or abs.Y < 2 then
            abs = Vector2.new(800, 450)
        end

        local dead = false
        local hb

        local overlay = create("Frame", {
            Name = "IntroOverlay",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 300,
            Active = true,
        })
        overlay.Parent = screenGui

        local function finish()
            if dead then return end
            dead = true
            if hb then hb:Disconnect() end
            if overlay then overlay:Destroy() end
        end

        -- ===== stage: everything that is NOT ice lives in one CanvasGroup =====
        local stage = create("CanvasGroup", {
            Name = "Stage",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            GroupTransparency = 1,
            ZIndex = 300,
        })
        stage.Parent = overlay

        local backdrop = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 1,
        }, {
            create("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new(Color3.fromRGB(7, 14, 34), Color3.fromRGB(24, 48, 90)),
            }),
        })
        backdrop.Parent = stage

        -- ===== snow =====
        local snow = {}
        if useSnow then
            for i = 1, 36 do
                local size = ({ 3, 4, 5, 6 })[math.random(1, 4)]
                local f = create("Frame", {
                    Size = UDim2.fromOffset(size, size),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = WHITE,
                    BackgroundTransparency = rand(0.15, 0.5),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
                f.Parent = stage
                snow[i] = {
                    f = f,
                    x0 = math.random(),
                    y = math.random(),
                    vy = rand(0.05, 0.14) + size * 0.012,
                    amp = rand(0.01, 0.03),
                    freq = rand(0.8, 1.8),
                    phase = rand(0, 6.28),
                }
            end
        end

        -- ===== light garland =====
        local bulbs = {}
        for i = 0, 71 do
            local x = i / 71
            create("Frame", {
                Size = UDim2.fromOffset(2, 2),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(x, wireY(x)),
                BackgroundColor3 = Color3.fromRGB(46, 120, 82),
                BorderSizePixel = 0,
                ZIndex = 3,
            }).Parent = stage
        end
        local BULB_COUNT = 14
        for i = 1, BULB_COUNT do
            local x = (i - 0.5) / BULB_COUNT
            local color = BULB_COLORS[(i - 1) % #BULB_COLORS + 1]
            local cap = create("Frame", {
                Size = UDim2.fromOffset(4, 5),
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(x, 0, wireY(x), 0),
                BackgroundColor3 = Color3.fromRGB(40, 44, 52),
                BorderSizePixel = 0,
                ZIndex = 3,
            })
            cap.Parent = stage
            local bulb = create("Frame", {
                Size = UDim2.fromOffset(10, 13),
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(x, 0, wireY(x), 5),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                ZIndex = 4,
            }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
            bulb.Parent = stage
            bulbs[i] = bulb
        end

        -- ===== title, letter by letter =====
        local fontSize = math.clamp(math.floor(math.min(abs.X / 11, abs.Y / 6)), 26, 72)
        local baseY = abs.Y * 0.46
        local widths, total = {}, 0
        for i = 1, #title do
            local ch = title:sub(i, i)
            local w
            if ch == " " then
                w = fontSize * 0.34
            else
                local ok, size = pcall(function()
                    return TextService:GetTextSize(ch, fontSize, Enum.Font.GothamBold, Vector2.new(1000, 1000))
                end)
                w = ok and size.X or fontSize * 0.6
            end
            widths[i] = w
            total = total + w + 2
        end
        total = total - 2

        local letters = {}
        local wordIndex, acc = 1, 0
        local startX = abs.X / 2 - total / 2
        for i = 1, #title do
            local ch = title:sub(i, i)
            if ch == " " then
                wordIndex += 1
            else
                local color
                if wordIndex == 1 then
                    color = WHITE
                else
                    color = (i % 2 == 0) and RED or GREEN
                end
                local label = create("TextLabel", {
                    Text = ch,
                    Font = Enum.Font.GothamBold,
                    TextSize = fontSize,
                    TextColor3 = color,
                    TextTransparency = 1,
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.fromOffset(startX + acc, baseY + 26),
                    Size = UDim2.fromOffset(widths[i], fontSize * 1.2),
                    ZIndex = 5,
                }, {
                    create("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.55 }),
                })
                label.Parent = stage
                table.insert(letters, { label = label, x = startX + acc, color = color })
            end
            acc = acc + widths[i] + 2
        end

        local sub = create("TextLabel", {
            Text = subText,
            Font = Enum.Font.GothamMedium,
            TextSize = math.max(13, round(fontSize * 0.3)),
            TextColor3 = GOLD,
            TextTransparency = 1,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(abs.X / 2, baseY + fontSize * 0.95),
            Size = UDim2.fromOffset(abs.X * 0.8, 22),
            ZIndex = 5,
        })
        sub.Parent = stage

        -- gold star above the title: two squares, 45 degrees apart
        local star = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(abs.X / 2, baseY - fontSize * 1.05),
            Size = UDim2.fromOffset(0, 0),
            ZIndex = 5,
        })
        for _, rot in ipairs({ 0, 45 }) do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.7, 0.7),
                Rotation = rot,
                BackgroundColor3 = GOLD,
                BorderSizePixel = 0,
                ZIndex = 5,
            }).Parent = star
        end
        star.Parent = stage

        -- ===== skip =====
        if cfg.Skip ~= false then
            local skipBtn = create("TextButton", {
                Text = "Skip",
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Color3.fromRGB(170, 190, 210),
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 60, 0, 30),
                Position = UDim2.new(1, -80, 1, -50),
                ZIndex = 330,
            })
            skipBtn.Parent = overlay
            skipBtn.MouseButton1Click:Connect(finish)
        end

        -- ===== frost layer (a grid of ice cells; also the shatter pieces) =====
        local frost = create("Folder", { Name = "Frost" })
        frost.Parent = overlay

        local ar = abs.X / abs.Y
        local cols, rows
        if ar >= 1 then
            cols = 10
            rows = math.max(5, round(10 / ar))
        else
            rows = 10
            cols = math.max(5, round(10 * ar))
        end

        local cells = {}
        for r = 1, rows do
            for c = 1, cols do
                local cx, cy = (c - 0.5) / cols, (r - 0.5) / rows
                local tint = ICE:Lerp(WHITE, math.random())
                local stroke = create("UIStroke", {
                    Color = WHITE,
                    Thickness = 1,
                    Transparency = 1,
                })
                local cell = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(cx, cy),
                    Size = UDim2.new(1 / cols, 2, 1 / rows, 2),
                    BackgroundColor3 = tint,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ZIndex = 306,
                }, {
                    stroke,
                    create("UIGradient", {
                        Rotation = math.random(0, 180),
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(1, 0.45),
                        }),
                    }),
                })
                cell.Parent = frost
                cells[#cells + 1] = { f = cell, stroke = stroke, cx = cx, cy = cy }
            end
        end

        local crystals = {}
        local parts = {}
        local clock = 0
        local bobOn = false
        local bobAmp = 0
        local frozen = false

        hb = RunService.Heartbeat:Connect(function(dt)
            if dead then return end
            if not overlay.Parent then
                finish()
                return
            end
            dt = math.min(dt, 0.05)
            clock += dt

            for _, s in ipairs(snow) do
                s.y += s.vy * dt
                if s.y > 1.04 then
                    s.y = -0.04
                    s.x0 = math.random()
                end
                s.f.Position = UDim2.new(s.x0 + math.sin(clock * s.freq + s.phase) * s.amp, 0, s.y, 0)
            end

            for i, b in ipairs(bulbs) do
                b.BackgroundTransparency = 0.05 + 0.45 * (0.5 + 0.5 * math.sin(clock * 3 + i * 1.7))
            end

            star.Rotation = clock * 35

            if not frozen then
                local target = bobOn and 1 or 0
                bobAmp += (target - bobAmp) * math.min(1, dt * 6)
                if bobAmp > 0.01 then
                    for i, l in ipairs(letters) do
                        local off = math.sin(clock * 2.4 + i * 0.5) * 3 * bobAmp
                        l.label.Position = UDim2.fromOffset(l.x, baseY + off)
                    end
                end
            end

            for _, c in ipairs(crystals) do
                c.f.Rotation += c.spin * dt
            end

            for i = #parts, 1, -1 do
                local p = parts[i]
                p.age += dt
                if p.age >= p.life then
                    p.f:Destroy()
                    table.remove(parts, i)
                elseif p.age > 0 then
                    p.vy += p.g * dt
                    p.x += p.vx * dt
                    p.y += p.vy * dt
                    p.rot += p.vr * dt
                    p.f.Position = UDim2.fromScale(p.x, p.y)
                    p.f.Rotation = p.rot
                    local k = (p.age - p.fadeAt) / (p.life - p.fadeAt)
                    if k > 0 then
                        local a = p.t0 + (1 - p.t0) * math.min(1, k)
                        p.f.BackgroundTransparency = a
                        if p.stroke then p.stroke.Transparency = a end
                    end
                end
            end
        end)

        -- wait that aborts if the intro was skipped/destroyed
        local function w(t)
            task.wait(t)
            return not dead and overlay.Parent ~= nil
        end

        task.spawn(function()
            -- 1. fade the night in
            tw(stage, { GroupTransparency = 0 }, 0.5)
            if not w(0.35) then return end

            -- 2. letters pop in
            for i, l in ipairs(letters) do
                task.delay((i - 1) * 0.055, function()
                    if dead then return end
                    tw(l.label, {
                        Position = UDim2.fromOffset(l.x, baseY),
                        TextTransparency = 0,
                    }, 0.45, Enum.EasingStyle.Back)
                end)
            end
            if not w(#letters * 0.055 + 0.45) then return end
            bobOn = true
            tw(star, { Size = UDim2.fromOffset(round(fontSize * 0.5), round(fontSize * 0.5)) }, 0.5, Enum.EasingStyle.Back)
            tw(sub, { TextTransparency = 0.1 }, 0.5)

            -- 3. hold
            if not w(hold) then return end
            bobOn = false

            -- 4. frostbite creeps in from the edges and freezes the lettering
            local growT = 1.1
            for _, l in ipairs(letters) do
                tw(l.label, { TextColor3 = ICE }, growT)
                local st = l.label:FindFirstChildOfClass("UIStroke")
                if st then tw(st, { Color = WHITE, Transparency = 0.2 }, growT) end
            end
            tw(sub, { TextColor3 = ICE }, growT)

            for _, c in ipairs(cells) do
                local edge = math.min(c.cx, 1 - c.cx, c.cy, 1 - c.cy) / 0.5 -- 0 edge .. 1 centre
                local delay = edge * growT + math.random() * 0.15
                task.delay(delay, function()
                    if dead then return end
                    tw(c.f, { BackgroundTransparency = rand(0.12, 0.3) }, 0.45, Enum.EasingStyle.Sine)
                    tw(c.stroke, { Transparency = 0.45 }, 0.45, Enum.EasingStyle.Sine)
                end)
            end

            local spots = {
                { 0.07, 0.12 }, { 0.93, 0.14 }, { 0.06, 0.88 }, { 0.94, 0.86 },
                { 0.5, 0.05 }, { 0.5, 0.95 }, { 0.2, 0.5 }, { 0.8, 0.5 },
            }
            for i, spot in ipairs(spots) do
                local size = round(rand(46, 78))
                local f = makeFlake(size, WHITE, 307)
                f.Size = UDim2.fromOffset(0, 0)
                f.Position = UDim2.fromScale(spot[1], spot[2])
                f.Parent = overlay
                crystals[#crystals + 1] = { f = f, spin = rand(-18, 18) }
                task.delay(i * 0.09 + math.random() * 0.2, function()
                    if dead then return end
                    tw(f, { Size = UDim2.fromOffset(size, size) }, 0.5, Enum.EasingStyle.Back)
                end)
            end

            if not w(growT + 0.45) then return end
            frozen = true

            -- 5. cracks race out of the centre
            local cx, cy = abs.X / 2, abs.Y / 2
            local reach = math.max(abs.X, abs.Y) * 0.55
            for i = 1, 8 do
                local ang = (i - 1) * 45 + rand(-14, 14)
                local rad = math.rad(ang)
                local dx, dy = math.cos(rad), math.sin(rad)
                local len = reach * rand(0.6, 1)
                local line = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromOffset(cx, cy),
                    Size = UDim2.fromOffset(0, 2),
                    Rotation = ang,
                    BackgroundColor3 = WHITE,
                    BorderSizePixel = 0,
                    ZIndex = 309,
                })
                line.Parent = overlay
                tw(line, {
                    Size = UDim2.fromOffset(len, 2),
                    Position = UDim2.fromOffset(cx + dx * len / 2, cy + dy * len / 2),
                }, 0.28, Enum.EasingStyle.Quad)

                -- one short branch per crack
                local bAng = ang + (math.random() < 0.5 and -32 or 32)
                local bRad = math.rad(bAng)
                local bLen = len * 0.32
                local sx, sy = cx + dx * len * 0.55, cy + dy * len * 0.55
                local branch = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromOffset(sx, sy),
                    Size = UDim2.fromOffset(0, 1),
                    Rotation = bAng,
                    BackgroundColor3 = WHITE,
                    BorderSizePixel = 0,
                    ZIndex = 309,
                })
                branch.Parent = overlay
                task.delay(0.14, function()
                    if dead then return end
                    tw(branch, {
                        Size = UDim2.fromOffset(bLen, 1),
                        Position = UDim2.fromOffset(sx + math.cos(bRad) * bLen / 2, sy + math.sin(bRad) * bLen / 2),
                    }, 0.2)
                end)
            end
            if not w(0.38) then return end

            -- 6. shatter
            local flash = create("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = WHITE,
                BackgroundTransparency = 0.55,
                BorderSizePixel = 0,
                ZIndex = 315,
            })
            flash.Parent = overlay
            tw(flash, { BackgroundTransparency = 1 }, 0.25)
            tw(stage, { GroupTransparency = 1 }, 0.3)

            for _, c in ipairs(cells) do
                local dx, dy = c.cx - 0.5, c.cy - 0.5
                local dist = math.sqrt(dx * dx + dy * dy)
                parts[#parts + 1] = {
                    f = c.f,
                    stroke = c.stroke,
                    x = c.cx,
                    y = c.cy,
                    vx = dx * 0.9 + rand(-0.08, 0.08),
                    vy = dy * 0.5 - rand(0.05, 0.35),
                    g = 1.9,
                    rot = 0,
                    vr = rand(-240, 240),
                    age = -dist * 0.25,
                    life = 1.15,
                    fadeAt = 0.45,
                    t0 = c.f.BackgroundTransparency,
                }
            end
            for _, c in ipairs(crystals) do
                c.spin = rand(-240, 240)
                task.delay(0.05, function()
                    if dead then return end
                    tw(c.f, { Size = UDim2.fromOffset(0, 0) }, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                end)
            end
            for _ = 1, 34 do
                local s = round(rand(3, 8))
                local f = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.fromOffset(s, s),
                    Position = UDim2.fromScale(0.5, 0.5),
                    BackgroundColor3 = math.random() < 0.5 and WHITE or ICE,
                    BackgroundTransparency = 0.1,
                    BorderSizePixel = 0,
                    ZIndex = 310,
                })
                f.Parent = overlay
                local ang = rand(0, 6.28)
                local speed = rand(0.25, 0.9)
                parts[#parts + 1] = {
                    f = f,
                    x = 0.5 + math.cos(ang) * rand(0, 0.15),
                    y = 0.5 + math.sin(ang) * rand(0, 0.15),
                    vx = math.cos(ang) * speed,
                    vy = math.sin(ang) * speed - 0.2,
                    g = 0.7,
                    rot = rand(0, 90),
                    vr = rand(-300, 300),
                    age = 0,
                    life = rand(0.7, 1.2),
                    fadeAt = 0.2,
                    t0 = 0.1,
                }
            end

            w(1.3)
            finish()
        end)

        return { Skip = finish }
    end

    return Intro
end
