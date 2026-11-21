--[[
    CornUi v2.0 — Core/Theme.lua
    Data-driven Skin System. Themes are plain tables; Render.New calls
    Theme.Apply() on every instance it builds unless opted out.

    A theme maps {Kind -> role} to properties. "role" lets multiple instances
    of the same Kind look different (e.g. Frame/"Window" vs Frame/"Card").
]]

return function(Modules)

    local Theme = {}

    local Themes = {}
    local ActiveName = nil
    local Changed = Instance.new("BindableEvent") -- fires on Theme.Set

    ------------------------------------------------------------
    -- Built-in default themes
    ------------------------------------------------------------

    -- Corn/kernel identity: warm roasted-husk darks and cream lights,
    -- gold kernel accent shared across both. Replaces the generic
    -- gray/green placeholder palette used during initial construction.
    Themes.Dark = {
        Frame = {
            Default = { Color = Color3.fromRGB(26, 20, 16), CornerRadius = 8 },   -- #1A1410
            Window  = { Color = Color3.fromRGB(26, 20, 16), CornerRadius = 10 },  -- #1A1410
            Card    = { Color = Color3.fromRGB(36, 29, 22), CornerRadius = 6 },   -- #241D16
            Enabled = { Color = Color3.fromRGB(232, 163, 61), CornerRadius = 10 }, -- #E8A33D
        },
        Text = {
            Default = { Color = Color3.fromRGB(245, 233, 211) }, -- #F5E9D3
            Muted   = { Color = Color3.fromRGB(184, 168, 136) }, -- #B8A888
        },
        Icon = {
            Default = { Color = Color3.fromRGB(245, 233, 211) }, -- #F5E9D3
        },
    }

    Themes.Light = {
        Frame = {
            Default = { Color = Color3.fromRGB(250, 243, 227), CornerRadius = 8 },  -- #FAF3E3
            Window  = { Color = Color3.fromRGB(250, 243, 227), CornerRadius = 10 }, -- #FAF3E3
            Card    = { Color = Color3.fromRGB(240, 230, 204), CornerRadius = 6 },  -- #F0E6CC
            Enabled = { Color = Color3.fromRGB(214, 144, 31), CornerRadius = 10 },  -- #D6901F
        },
        Text = {
            Default = { Color = Color3.fromRGB(43, 32, 19) },  -- #2B2013
            Muted   = { Color = Color3.fromRGB(138, 123, 92) }, -- #8A7B5C
        },
        Icon = {
            Default = { Color = Color3.fromRGB(43, 32, 19) }, -- #2B2013
        },
    }

    -- Ported from v1.9.3's preset list (Background/Header/Accent/Text/
    -- SubText/Element -> Frame.Window/Card/Enabled, Text.Default/Muted).
    -- Colors carried over verbatim from the original Themes table.
    local function portedTheme(v1)
        return {
            Frame = {
                Default = { Color = v1.Element,     CornerRadius = 8 },
                Window  = { Color = v1.Background,  CornerRadius = 10 },
                Card    = { Color = v1.Header,      CornerRadius = 6 },
                Enabled = { Color = v1.Accent,       CornerRadius = 10 },
            },
            Text = {
                Default = { Color = v1.Text },
                Muted   = { Color = v1.SubText },
            },
            Icon = {
                Default = { Color = v1.Text },
            },
        }
    end

    Themes.Ocean = portedTheme({
        Background = Color3.fromRGB(8, 20, 40),
        Header     = Color3.fromRGB(12, 30, 50),
        Accent     = Color3.fromRGB(64, 224, 208),
        Text       = Color3.fromRGB(220, 240, 255),
        SubText    = Color3.fromRGB(160, 190, 210),
        Element    = Color3.fromRGB(16, 35, 55),
    })

    Themes.Forest = portedTheme({
        Background = Color3.fromRGB(10, 25, 10),
        Header     = Color3.fromRGB(15, 35, 15),
        Accent     = Color3.fromRGB(80, 200, 80),
        Text       = Color3.fromRGB(220, 255, 220),
        SubText    = Color3.fromRGB(160, 200, 160),
        Element    = Color3.fromRGB(15, 35, 15),
    })

    Themes.Sunset = portedTheme({
        Background = Color3.fromRGB(40, 10, 20),
        Header     = Color3.fromRGB(50, 15, 25),
        Accent     = Color3.fromRGB(255, 140, 60),
        Text       = Color3.fromRGB(255, 220, 210),
        SubText    = Color3.fromRGB(210, 160, 150),
        Element    = Color3.fromRGB(50, 15, 25),
    })

    Themes.Amethyst = portedTheme({
        Background = Color3.fromRGB(25, 15, 40),
        Header     = Color3.fromRGB(30, 20, 45),
        Accent     = Color3.fromRGB(180, 120, 255),
        Text       = Color3.fromRGB(240, 225, 255),
        SubText    = Color3.fromRGB(180, 160, 200),
        Element    = Color3.fromRGB(30, 20, 45),
    })

    Themes.Ruby = portedTheme({
        Background = Color3.fromRGB(40, 10, 10),
        Header     = Color3.fromRGB(50, 15, 15),
        Accent     = Color3.fromRGB(255, 60, 60),
        Text       = Color3.fromRGB(255, 220, 220),
        SubText    = Color3.fromRGB(210, 160, 160),
        Element    = Color3.fromRGB(50, 15, 15),
    })

    Themes.Frost = portedTheme({
        Background = Color3.fromRGB(20, 30, 45),
        Header     = Color3.fromRGB(25, 35, 50),
        Accent     = Color3.fromRGB(150, 220, 255),
        Text       = Color3.fromRGB(230, 245, 255),
        SubText    = Color3.fromRGB(170, 190, 210),
        Element    = Color3.fromRGB(25, 35, 50),
    })

    Themes.Candy = portedTheme({
        Background = Color3.fromRGB(45, 20, 35),
        Header     = Color3.fromRGB(55, 25, 42),
        Accent     = Color3.fromRGB(255, 150, 200),
        Text       = Color3.fromRGB(255, 235, 245),
        SubText    = Color3.fromRGB(220, 180, 200),
        Element    = Color3.fromRGB(55, 25, 42),
    })

    Themes.Midnight = portedTheme({
        Background = Color3.fromRGB(5, 5, 8),
        Header     = Color3.fromRGB(8, 8, 12),
        Accent     = Color3.fromRGB(200, 200, 220),
        Text       = Color3.fromRGB(255, 255, 255),
        SubText    = Color3.fromRGB(150, 150, 160),
        Element    = Color3.fromRGB(8, 8, 12),
    })

    Themes.Cyber = portedTheme({
        Background = Color3.fromRGB(10, 5, 20),
        Header     = Color3.fromRGB(15, 8, 28),
        Accent     = Color3.fromRGB(0, 255, 150),
        Text       = Color3.fromRGB(0, 255, 150),
        SubText    = Color3.fromRGB(100, 200, 150),
        Element    = Color3.fromRGB(15, 8, 28),
    })

    ------------------------------------------------------------
    -- Instance -> theme-binding tracking, for live re-skin on Theme.Set
    ------------------------------------------------------------

    -- Weak-keyed so instances that get destroyed don't leak entries.
    local Bindings = setmetatable({}, { __mode = "k" })

    local function resolve(kind, role)
        local themeTable = Themes[ActiveName]
        if not themeTable then return nil end
        local kindTable = themeTable[kind]
        if not kindTable then return nil end
        return kindTable[role] or kindTable.Default
    end

    -- Resolves a Font value from either an Enum.Font or a custom uploaded
    -- font asset id, so themes can point at the user's own font assets
    -- exactly like they point at texture asset ids.
    local function resolveFont(value)
        if typeof(value) == "Font" then
            return value
        elseif typeof(value) == "EnumItem" then
            return nil, value -- caller sets .Font, not .FontFace
        elseif type(value) == "number" then
            return Font.fromId(value)
        elseif type(value) == "string" then
            local id = value:match("rbxassetid://(%d+)") or value:match("^(%d+)$")
            if id then
                return Font.fromId(tonumber(id))
            end
            local ok, enumFont = pcall(function() return Enum.Font[value] end)
            if ok and enumFont then
                return nil, enumFont
            end
            return Font.fromName(value)
        end
        return nil
    end

    local function paint(inst, kind, style)
        if not style then return end

        if style.Color then
            -- The color channel follows the BINDING kind, not the instance
            -- class: a TextButton bound to a Frame role must paint its
            -- background (and keep its label readable), while the same class
            -- bound to a Text role paints text color.
            if kind == "Text" or kind == "Icon" then
                if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                    inst.TextColor3 = style.Color
                elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
                    inst.ImageColor3 = style.Color
                end
            else
                if inst:IsA("GuiObject") then
                    inst.BackgroundColor3 = style.Color
                end
                -- Themed buttons (Render "Button" kind) bind to Frame roles;
                -- their label must follow the theme's Text.Default so it
                -- stays readable (white text on cream Light = gone).
                if inst:IsA("TextButton") then
                    local textStyle = resolve("Text", "Default")
                    if textStyle and textStyle.Color then
                        inst.TextColor3 = textStyle.Color
                    end
                end
            end
        end

        if style.CornerRadius then
            local corner = inst:FindFirstChildOfClass("UICorner")
            if corner then
                corner.CornerRadius = typeof(style.CornerRadius) == "UDim"
                    and style.CornerRadius or UDim.new(0, style.CornerRadius)
            end
        end

        -- Custom texture asset ids (window background, card background,
        -- accent texture, etc). Applies to any Frame-kind instance that
        -- has a BackgroundColor3 — the texture layers on top as a child
        -- ImageLabel, so the color still shows through transparent areas.
        if kind == "Frame" and inst:IsA("GuiObject") then
            local existing = inst:FindFirstChild("ThemeTexture")
            if style.Texture then
                local img = existing
                if not img then
                    img = Instance.new("ImageLabel")
                    img.Name = "ThemeTexture"
                    img.BackgroundTransparency = 1
                    img.BorderSizePixel = 0
                    img.Size = UDim2.fromScale(1, 1)
                    img.Parent = inst
                end
                img.ZIndex = inst.ZIndex + 1
                img.Image = style.Texture
                img.ImageTransparency = style.TextureTransparency or 0
                img.ScaleType = style.TextureScaleType or Enum.ScaleType.Crop
            elseif existing then
                existing:Destroy() -- switched to a theme/role with no texture
            end
        end

        -- Custom font asset ids or Enum.Font names, per Text role.
        if style.Font and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then
            local fontFace, enumFont = resolveFont(style.Font)
            if fontFace then
                inst.FontFace = fontFace
            elseif enumFont then
                inst.Font = enumFont
            end
        end
    end

    ------------------------------------------------------------
    -- Public API
    ------------------------------------------------------------

    -- Called automatically by Render.New(kind, props) unless props.Theme == false.
    -- props.Theme may be a string to pick a role within the kind (e.g. "Window", "Card", "Muted").
    function Theme.Apply(inst, kind, props)
        local role = (type(props.Theme) == "string") and props.Theme or "Default"
        local style = resolve(kind, role)

        Bindings[inst] = { Kind = kind, Role = role }
        paint(inst, kind, style)

        return inst
    end

    -- Switches the active theme and live-repaints every tracked instance.
    function Theme.Set(name)
        assert(Themes[name], ("Theme.Set: unknown theme '%s'"):format(tostring(name)))
        ActiveName = name

        for inst, binding in pairs(Bindings) do
            if inst and inst.Parent then
                paint(inst, binding.Kind, resolve(binding.Kind, binding.Role))
            end
        end

        Changed:Fire(name)
    end

    function Theme.Get()
        return ActiveName
    end

    -- Registers a new theme or overwrites an existing one by name.
    -- Shape: { [Kind] = { [Role] = { Color = ..., CornerRadius = ..., ... }, Default = {...} } }
    function Theme.Register(name, definition)
        assert(type(name) == "string", "Theme.Register: name must be a string")
        assert(type(definition) == "table", "Theme.Register: definition must be a table")
        Themes[name] = definition
    end

    -- Names the library ships with. Patching one of these live would mutate
    -- the built-in definition for the whole session with no way back, so
    -- PatchRole clones built-ins into a "<name> Custom" theme on first edit.
    local BuiltinNames = {}
    for builtinName in pairs(Themes) do
        BuiltinNames[builtinName] = true
    end

    local function copyTheme(t)
        local out = {}
        for k, v in pairs(t) do
            out[k] = (type(v) == "table") and copyTheme(v) or v
        end
        return out
    end

    function Theme.List()
        local out = {}
        for name in pairs(Themes) do
            table.insert(out, name)
        end
        table.sort(out)
        return out
    end

    -- Returns the live style table for a Kind/Role under the active theme
    -- (e.g. Theme.GetStyle("Text", "Default").Color). Read-only usage; do not
    -- mutate the returned table — go through PatchRole for edits.
    function Theme.GetStyle(kind, role)
        return resolve(kind, role or "Default")
    end

    -- Live-edits a single Kind/Role style on a theme (merges `patch` into the
    -- existing style table) and immediately repaints every bound instance
    -- that uses it. Used by the Theme Editor UI for custom color edits.
    --
    -- Patching a built-in theme never mutates it: the first patch clones the
    -- whole theme into "<name> Custom", switches to that clone (repainting
    -- everything), and applies the patch there. Theme.Set(name) with the
    -- original built-in name therefore acts as "reset to default".
    function Theme.PatchRole(themeName, kind, role, patch)
        local customName = themeName .. " Custom"

        if BuiltinNames[themeName] then
            if not Themes[customName] then
                Themes[customName] = copyTheme(Themes[themeName])
            end
            if ActiveName == themeName then
                Theme.Set(customName) -- repaints all instances against the clone
            end
            themeName = customName
        end

        local themeTable = Themes[themeName]
        assert(themeTable, ("PatchRole: unknown theme '%s'"):format(tostring(themeName)))

        themeTable[kind] = themeTable[kind] or {}
        themeTable[kind][role] = themeTable[kind][role] or {}

        for k, v in pairs(patch) do
            themeTable[kind][role][k] = v
        end

        if ActiveName == themeName then
            for inst, binding in pairs(Bindings) do
                if inst and inst.Parent and binding.Kind == kind and binding.Role == role then
                    paint(inst, kind, resolve(kind, role))
                end
            end
        end
    end

    -- Convenience wrappers over PatchRole for the common custom-asset cases —
    -- set a texture (window background, card background, accent texture) or
    -- a font (custom uploaded font asset id, or an Enum.Font name) on a role.
    function Theme.SetTexture(themeName, kind, role, assetId, transparency, scaleType)
        Theme.PatchRole(themeName, kind, role, {
            Texture = assetId,
            TextureTransparency = transparency,
            TextureScaleType = scaleType,
        })
    end

    -- Removes a texture from a role entirely (reverting to plain Color).
    -- Not done via PatchRole since a nil-valued key in a patch table never
    -- actually reaches the merge — Lua drops nil table-constructor entries.
    function Theme.ClearTexture(themeName, kind, role)
        local themeTable = Themes[themeName]
        assert(themeTable, ("ClearTexture: unknown theme '%s'"):format(tostring(themeName)))

        local roleStyle = themeTable[kind] and themeTable[kind][role]
        if not roleStyle then return end
        roleStyle.Texture = nil
        roleStyle.TextureTransparency = nil
        roleStyle.TextureScaleType = nil

        if ActiveName == themeName then
            for inst, binding in pairs(Bindings) do
                if inst and inst.Parent and binding.Kind == kind and binding.Role == role then
                    paint(inst, kind, resolve(kind, role))
                end
            end
        end
    end

    function Theme.SetFont(themeName, role, font)
        Theme.PatchRole(themeName, "Text", role, { Font = font })
    end

    -- Fires with the new theme name whenever Theme.Set runs.
    Theme.OnChanged = Changed.Event

    -- Design tokens — the single source of truth for the shell's sizing, so
    -- Window and Elements stay visually coherent without magic numbers.
    -- Values are pixels; colors deliberately come from theme roles instead.
    Theme.Tokens = {
        TitleHeight = 22,       -- title bar text row height
        AccentLineHeight = 2,   -- gold accent line under the title bar
        TabBarHeight = 30,      -- pill tab strip height
        IndicatorHeight = 3,    -- sliding gold underline under the active tab
        RowHeight = 28,         -- standard single-line element row
        RowWithDescription = 42,
        ChipCorner = 7,         -- kernel chip / small squares
        PanelCorner = 8,        -- dropdown / picker pop panels
    }

    -- Default to Frost for the Christmas release.
    ActiveName = "Frost"

    return Theme
end
