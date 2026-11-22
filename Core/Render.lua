--[[
    Rendering & executor primitives — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 24-38, 504-561, 656-662, 717-768, 774-880. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Core/Render.lua
return function(Modules)
    local Library = Modules
    -- stroke()'s verbatim body defaults to Theme.Stroke; the live theme
    -- table lives in the Theme module, which loads after this one. Bound
    -- via BindLiveTheme (below) the moment Theme finishes loading — the
    -- extracted body stays byte-identical.
    local Theme

-- ============ SERVICES (v1.9.4d lines 24-38) ============

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============ HELPERS (lines 504-561) ============

local function isTouchDevice()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function corner(radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function setSearchMeta(inst, config, defaultName)
    config = config or {}
    local name = config.Name or defaultName or ""
    inst:SetAttribute("MUI_Name", name)

    local parts = { name }
    if config.Keywords then
        if type(config.Keywords) == "table" then
            for _, kw in ipairs(config.Keywords) do
                table.insert(parts, tostring(kw))
            end
        else
            table.insert(parts, tostring(config.Keywords))
        end
    end
    if config.Description then
        table.insert(parts, tostring(config.Description))
    end
    inst:SetAttribute("MUI_Search", table.concat(parts, " "):lower())
end

local function stroke(color, thickness)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
    })
end

local animationSpeed = 1.0
local function tween(inst, props, duration)
    if Library.Flags.ReducedMotion or Library.Flags.PerformanceMode then
        for prop, value in pairs(props) do
            inst[prop] = value
        end
        return
    end
    local adjustedDuration = (duration or 0.15) / animationSpeed
    TweenService:Create(inst, TweenInfo.new(adjustedDuration, Enum.EasingStyle.Quad), props):Play()
end

-- ============ LAYOUT GUARD (lines 656-662) ============

local LAYOUT_CLASSES = { "UIListLayout", "UIGridLayout", "UITableLayout", "UIPageLayout" }
local function hasChildLayout(inst)
    for _, className in ipairs(LAYOUT_CLASSES) do
        if inst:FindFirstChildOfClass(className) then return true end
    end
    return false
end

-- ============ SOUND & HAPTICS (lines 717-768) ============

local soundMap = {
    click = "rbxassetid://9120396650",
    toggle = "rbxassetid://9120398374",
    slider = "rbxassetid://9120400890",
    dropdown = "rbxassetid://9120404583",
    success = "rbxassetid://9120411087",
    error = "rbxassetid://9120413090",
    warning = "rbxassetid://9120411087",
    info = "rbxassetid://9120404583",
}

function Library:PlaySound(soundId, volume)
    if not Library.Flags.UISounds then return end
    if not soundId then return end
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume or 0.3
    sound.Parent = LocalPlayer.PlayerGui
    sound:Play()
    task.delay(sound.TimeLength + 0.1, function()
        sound:Destroy()
    end)
end

function Library:PlayHaptic(variant)
    if not Library.Flags.Haptics then return end
    if not UserInputService.Vibrate then return end
    local vibrateType = Enum.VibrateType.Short
    if variant == "long" then
        vibrateType = Enum.VibrateType.Long
    elseif variant == "double" then
        pcall(function()
            UserInputService:Vibrate(Enum.VibrateType.Short)
            task.wait(0.1)
            UserInputService:Vibrate(Enum.VibrateType.Short)
        end)
        return
    end
    pcall(function()
        UserInputService:Vibrate(vibrateType)
    end)
end

local function playInteractionSound(style)
    local id = soundMap[style] or soundMap.click
    Library:PlaySound(id)
end

local function playNotificationSound(style)
    local id = soundMap[style] or soundMap.info
    Library:PlaySound(id, 0.2)
end

-- ============ UI HELPERS (lines 774-880) ============

local function startBreathingGlow(guiObject, color)
    local glow = create("UIStroke", { Color = color, Thickness = 2, Transparency = 0.3 })
    glow.Parent = guiObject
    local glowTween = TweenService:Create(
        glow,
        TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.85 }
    )
    glowTween:Play()
    return glow, glowTween
end

local function stopBreathingGlow(glow, glowTween)
    if glowTween then glowTween:Cancel() end
    if glow then glow:Destroy() end
end

local function classicRipple(button, color)
    button.ClipsDescendants = true
    local circle = create("Frame", {
        BackgroundColor3 = color,
        BackgroundTransparency = 0.55,
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        ZIndex = button.ZIndex + 5,
    }, { corner(999) })
    circle.Parent = button
    local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.8
    tween(circle, { Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1 }, 0.5)
    task.delay(0.5, function()
        circle:Destroy()
    end)
end

-- SEAM (draft 3): ripple now delegates to Systems/Motion.lua ("Bloom");
-- the original centered ripple above is kept as classicRipple.
local function ripple(button, color)
    local M = Library.Motion
    if M and M.ripple then
        return M.ripple(button, color)
    end
    return classicRipple(button, color)
end

local function shiftZIndex(root, offset)
    if root:IsA("GuiObject") then
        root.ZIndex += offset
    end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiObject") then
            d.ZIndex += offset
        end
    end
end

local function makeDraggable(dragHandle, target, snap)
    local dragging = false
    local dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        target.Position = newPos

        if snap and Library.Flags.SnapToEdges then
            local absPos = target.AbsolutePosition
            local absSize = target.AbsoluteSize
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local snapThreshold = 50

            if absPos.X < snapThreshold then
                target.Position = UDim2.new(0, 0, newPos.Y.Scale, newPos.Y.Offset)
            elseif absPos.X + absSize.X > viewport.X - snapThreshold then
                target.Position = UDim2.new(1, -absSize.X, newPos.Y.Scale, newPos.Y.Offset)
            end

            if absPos.Y < snapThreshold then
                target.Position = UDim2.new(target.Position.X.Scale, target.Position.X.Offset, 0, 0)
            elseif absPos.Y + absSize.Y > viewport.Y - snapThreshold then
                target.Position = UDim2.new(target.Position.X.Scale, target.Position.X.Offset, 1, -absSize.Y)
            end
        end
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            update(input)
        end
    end)
end

    ------------------------------------------------------------
    -- Module export (ours, not v1.9.4d): services + helpers for the
    -- other modules' preludes. SetAnimationSpeed owns the monolith's
    -- `animationSpeed` local; WM:SetAnimationSpeed forwards here.
    ------------------------------------------------------------
    local Render = {
        UserInputService = UserInputService,
        TweenService = TweenService,
        Players = Players,
        RunService = RunService,
        HttpService = HttpService,
        GuiService = GuiService,
        LocalPlayer = LocalPlayer,
        PlayerGui = PlayerGui,
        isTouchDevice = isTouchDevice,
        create = create,
        corner = corner,
        setSearchMeta = setSearchMeta,
        stroke = stroke,
        tween = tween,
        hasChildLayout = hasChildLayout,
        soundMap = soundMap,
        playInteractionSound = playInteractionSound,
        playNotificationSound = playNotificationSound,
        startBreathingGlow = startBreathingGlow,
        stopBreathingGlow = stopBreathingGlow,
        ripple = ripple,
        classicRipple = classicRipple,
        GetAnimationSpeed = function() return animationSpeed end,
        shiftZIndex = shiftZIndex,
        makeDraggable = makeDraggable,
        SetAnimationSpeed = function(factor)
            animationSpeed = math.clamp(factor, 0.1, 3.0)
        end,
        BindLiveTheme = function(t) Theme = t end,
    }
    return Render

end
