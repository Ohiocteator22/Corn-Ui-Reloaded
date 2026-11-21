--[[
    CornUi v2.0 — Core/Render.lua
    Single-entry-point rendering primitive layer.
    Loaded via Loader.lua as: Modules.Render = Import("Render")

    Usage:
        local frame = Render.New("Frame", { Size = UDim2.fromOffset(200, 50), Theme = "Window" })
        local label = Render.New("Text",  { Text = "Hello", Font = Enum.Font.GothamBold })

    All builders return the primary Instance they create. Where a builder needs
    to attach auxiliary instances (e.g. a stroke on a wrapper), those are parented
    under the returned instance so callers never have to juggle more than one handle.
    The one exception is Stroke wrapping: the returned instance is a transparent
    wrapper frame and Theme styling targets the inner frame internally.
]]

return function(Modules)

    local Render = {}
    local Builders = {}

    ------------------------------------------------------------
    -- Quality levels (mobile-first perf switch)
    -- "High": all motion + polish on (default).
    -- "Low":  tweens, pop animations, stroke wrappers and the intro are
    --         skipped; property writes become instant. Intended for weak
    --         phones — CornUi's whole point is not lagging there.
    -- Elements read Render.Quality ~= "Low" before paying for motion.
    ------------------------------------------------------------

    Render.Quality = "High"

    function Render.SetQuality(level)
        assert(level == "High" or level == "Low", "Render.SetQuality: level must be 'High' or 'Low'")
        Render.Quality = level
    end

    -- True when decorative motion may run. Callers pass the TweenInfo they
    -- would use so Low quality doesn't even allocate the tween info.
    function Render.Motion()
        return Render.Quality ~= "Low"
    end

    ------------------------------------------------------------
    -- Internal helpers
    ------------------------------------------------------------

    local function applyCommon(inst, props)
        if props.Name then inst.Name = props.Name end
        if props.Size then inst.Size = props.Size end
        if props.Position then inst.Position = props.Position end
        if props.AnchorPoint then inst.AnchorPoint = props.AnchorPoint end
        if props.ZIndex then inst.ZIndex = props.ZIndex end
        if props.Visible ~= nil and inst:IsA("GuiObject") then
            inst.Visible = props.Visible
        end
        if props.Parent then inst.Parent = props.Parent end
        return inst
    end

    local function addCorner(inst, radius)
        if not radius then return end
        local corner = Instance.new("UICorner")
        corner.CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius)
        corner.Parent = inst
        return corner
    end

    -- Stroke is deliberately placed on a wrapper Frame rather than directly on
    -- the styled instance. CornUi v1.x had an orange text-fringe bug in Light
    -- mode caused by UIStroke rendering against the parent's fill color on
    -- certain instance types — wrapping avoids that class of bug entirely.
    -- Returns (wrapper, inner) so callers can keep two handles:
    -- the wrapper goes into the UI tree, the inner stays the theme target
    -- (binding the wrapper would paint its transparent background and never
    -- repaint the visible frame on Theme.Set).
    local function wrapWithStroke(inst, props)
        if not props.Stroke then return inst, inst end

        local outerParent = inst.Parent -- applyCommon already parented the inst

        local wrapper = Instance.new("Frame")
        wrapper.Name = (props.Name or inst.ClassName) .. "_StrokeWrapper"
        wrapper.BackgroundTransparency = 1
        wrapper.Size = inst.Size
        wrapper.Position = inst.Position
        wrapper.AnchorPoint = inst.AnchorPoint
        wrapper.ClipsDescendants = false

        local stroke = Instance.new("UIStroke")
        stroke.Color = props.Stroke.Color or Color3.new(0, 0, 0)
        stroke.Thickness = props.Stroke.Thickness or 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = wrapper

        inst.Position = UDim2.new(0, 0, 0, 0)
        inst.AnchorPoint = Vector2.new(0, 0)
        inst.Parent = wrapper
        wrapper.Parent = outerParent

        return wrapper, inst
    end

    ------------------------------------------------------------
    -- Builders
    ------------------------------------------------------------

    Builders.Frame = function(props)
        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = props.Color or Color3.fromRGB(30, 30, 30)
        frame.BackgroundTransparency = props.Transparency or 0
        frame.BorderSizePixel = 0
        -- Clipping is opt-IN. Every ClipsDescendants frame is a GPU scissor
        -- group, and combined with AutomaticSize it forces extra layout
        -- passes — on low-end mobiles that combination is measurably costly.
        -- Panels that used to need clipping are Scroll containers now.
        frame.ClipsDescendants = props.Clip == true

        applyCommon(frame, props)
        addCorner(frame, props.CornerRadius)

        -- Skin System texture support — resolved once here, not per-caller.
        if props.Texture then
            local image = Instance.new("ImageLabel")
            image.BackgroundTransparency = 1
            image.Size = UDim2.fromScale(1, 1)
            image.Image = props.Texture
            image.ImageTransparency = props.TextureTransparency or 0
            image.ScaleType = props.TextureScaleType or Enum.ScaleType.Crop
            image.ZIndex = frame.ZIndex + 1
            image.Parent = frame
        end

        return wrapWithStroke(frame, props)
    end

    Builders.Text = function(props)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Text = props.Text or ""
        label.TextColor3 = props.Color or Color3.fromRGB(255, 255, 255)
        label.TextTransparency = props.Transparency or 0
        label.TextScaled = props.TextScaled or false
        label.TextWrapped = props.TextWrapped ~= false
        label.TextXAlignment = props.XAlignment or Enum.TextXAlignment.Left
        label.TextYAlignment = props.YAlignment or Enum.TextYAlignment.Center

        -- Custom font support, solved once at the primitive level.
        -- Accepts either an Enum.Font or a Font.new(...) FontFace (custom asset).
        if props.Font then
            if typeof(props.Font) == "Font" then
                label.FontFace = props.Font
            else
                label.Font = props.Font
            end
        end
        if not props.TextScaled then
            label.TextSize = props.TextSize or 16
        end

        -- Auto-grow support for wrapped text (paragraphs, toast bodies).
        if props.AutomaticSize then
            label.AutomaticSize = props.AutomaticSize
        end

        applyCommon(label, props)
        return label
    end

    Builders.Icon = function(props)
        assert(props.Image, "Render.New('Icon', props): props.Image is required")

        -- Resolve the source through Assets (rbxassetid number/string, URL,
        -- local file or embedded pack name). nil resolution = source not
        -- available in this environment: hide the icon instead of erroring.
        local resolved = props.Image
        if Modules.Assets then
            resolved = Modules.Assets.Resolve(props.Image)
        end

        local icon = Instance.new("ImageLabel")
        icon.BackgroundTransparency = 1
        icon.Image = resolved or ""
        icon.Visible = resolved ~= nil
        icon.ImageColor3 = props.Color or Color3.fromRGB(255, 255, 255)
        icon.ImageTransparency = props.Transparency or 0
        icon.ScaleType = props.ScaleType or Enum.ScaleType.Fit

        applyCommon(icon, props)
        return icon
    end

    Builders.Gradient = function(props)
        local gradient = Instance.new("UIGradient")
        gradient.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
        if props.Transparency then gradient.Transparency = props.Transparency end
        if props.Rotation then gradient.Rotation = props.Rotation end
        if props.Parent then gradient.Parent = props.Parent end
        return gradient
    end

    -- Clickable text button styled through the Frame theme roles (Default /
    -- Card / Enabled / Window). Text color follows the active theme's
    -- Text.Default on build AND on every Theme.Set repaint (see paint()'s
    -- TextButton special case in Core/Theme.lua).
    Builders.Button = function(props)
        local btn = Instance.new("TextButton")
        btn.AutoButtonColor = true
        btn.BackgroundColor3 = props.Color or Color3.fromRGB(60, 60, 60)
        btn.BackgroundTransparency = props.Transparency or 0
        btn.BorderSizePixel = 0
        btn.Text = props.Text or ""
        btn.TextSize = props.TextSize or 14
        btn.TextScaled = props.TextScaled or false
        btn.TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center
        btn.TextYAlignment = Enum.TextYAlignment.Center

        if props.Font then
            if typeof(props.Font) == "Font" then
                btn.FontFace = props.Font
            else
                btn.Font = props.Font
            end
        end

        applyCommon(btn, props)
        addCorner(btn, props.CornerRadius or 6)
        return wrapWithStroke(btn, props)
    end

    -- Scrolling container for pages that can overflow (mobile-first default).
    -- ClipsDescendants is forced off — setting it true on a ScrollingFrame
    -- breaks scrolling input. Theme is opt-in (usually a passthrough).
    Builders.Scroll = function(props)
        local sf = Instance.new("ScrollingFrame")
        sf.BackgroundColor3 = props.Color or Color3.fromRGB(30, 30, 30)
        sf.BackgroundTransparency = (props.Transparency ~= nil) and props.Transparency or 1
        sf.BorderSizePixel = 0
        sf.ScrollBarThickness = props.ScrollBarThickness or 3
        sf.ScrollBarImageTransparency = 0.4
        sf.ScrollingDirection = Enum.ScrollingDirection.Y
        sf.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        sf.CanvasSize = props.CanvasSize or UDim2.new()
        sf.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
        sf.ClipsDescendants = false

        applyCommon(sf, props)
        addCorner(sf, props.CornerRadius)
        return sf
    end

    ------------------------------------------------------------
    -- Public entry point
    ------------------------------------------------------------

    -- kind:  string key into Builders ("Frame", "Text", "Icon", "Gradient", ...)
    -- props: table of properties consumed by the builder + shared keys
    --        (Name, Size, Position, AnchorPoint, ZIndex, Visible, Parent, Theme)
    function Render.New(kind, props)
        props = props or {}

        local builder = Builders[kind]
        assert(builder, ("Render.New: unknown kind '%s'"):format(tostring(kind)))

        -- builder returns (instance, themeTarget). For plain builders both are
        -- the same instance; the stroke wrapper returns (wrapper, inner) so
        -- the theme binds to the visible frame, not the transparent wrapper.
        local instance, themeTarget = builder(props)

        -- Theme auto-application, opt out with Theme = false.
        -- Buttons style through the Frame roles (Default/Card/Enabled) since
        -- themes don't carry a separate "Button" kind.
        if props.Theme ~= false and Modules.Theme then
            local themeKind = (kind == "Button") and "Frame" or kind
            Modules.Theme.Apply(themeTarget or instance, themeKind, props)
        end

        return instance
    end

    -- Allows Theme.lua / Elements to register additional primitive kinds
    -- (e.g. "ColorGradient", "ProgressBar" base shapes) without editing this file.
    function Render.RegisterBuilder(kind, builderFn)
        assert(type(kind) == "string", "RegisterBuilder: kind must be a string")
        assert(not Builders[kind], ("RegisterBuilder: '%s' already registered"):format(kind))
        Builders[kind] = builderFn
    end

    return Render
end
