-- ============================================================
-- ROLL SCRIPT - Fully Fixed Version
-- Plays animation + velocity boost + UI
-- ============================================================

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local Debris = game:GetService('Debris')

local LocalPlayer = Players.LocalPlayer

-- Target parent for UI (Fallback to PlayerGui if CoreGui is restricted)
local function GetUIParent()
    local success, _ = pcall(function()
        return game:GetService("CoreGui").Name
    end)
    if success and gethui then
        return gethui()
    elseif success then
        return game:GetService("CoreGui")
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local UIParent = GetUIParent()

-- ============================================================
-- ANIMATION ID
-- ============================================================

local ROLL_ANIMATION_ID = 'rbxassetid://16299510063'

-- ============================================================
-- CREATE COOLDOWN UI
-- ============================================================

local function CreateCooldownUI()
    if UIParent:FindFirstChild('Cooldown Script') then
        return
    end
    
    local cooldownGui = Instance.new('ScreenGui')
    cooldownGui.Name = 'Cooldown Script'
    cooldownGui.IgnoreGuiInset = true
    cooldownGui.ResetOnSpawn = false
    cooldownGui.Parent = UIParent
    
    local imageLabel = Instance.new('ImageLabel')
    imageLabel.Size = UDim2.new(0.215, 0, 0.059, 0)
    imageLabel.Position = UDim2.new(1.01, 0, 0.305, -50)
    imageLabel.BackgroundTransparency = 1
    imageLabel.AnchorPoint = Vector2.new(1, 0)
    imageLabel.Image = 'rbxassetid://17253889398'
    imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
    imageLabel.Visible = false
    imageLabel.ClipsDescendants = true
    imageLabel.Parent = cooldownGui
    
    local aspectRatio = Instance.new('UIAspectRatioConstraint')
    aspectRatio.AspectRatio = 6.438
    aspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
    aspectRatio.Parent = imageLabel
    
    local frame = Instance.new('Frame')
    frame.Size = UDim2.new(1, 0, 0.98, 0)
    frame.Position = UDim2.new(0, 0, 0.5, 0)
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(0, 0.5)
    frame.ClipsDescendants = true
    frame.Parent = imageLabel
    
    local progressImage = Instance.new('ImageLabel')
    progressImage.Size = UDim2.new(1, 0, 1, 0)
    progressImage.Position = UDim2.new(0, 0, 0, 0)
    progressImage.BackgroundTransparency = 1
    progressImage.Image = 'rbxassetid://17253892073'
    progressImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
    progressImage.Parent = frame
    
    local textLabel = Instance.new('TextLabel')
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.TextScaled = true
    textLabel.Text = ''
    textLabel.Rotation = 15
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.FredokaOne
    textLabel.ZIndex = 2
    textLabel.Parent = imageLabel
    
    local padding = Instance.new('UIPadding')
    padding.PaddingBottom = UDim.new(0.15, 0)
    padding.PaddingLeft = UDim.new(0.05, 0)
    padding.PaddingRight = UDim.new(0.05, 0)
    padding.PaddingTop = UDim.new(0.15, 0)
    padding.Parent = textLabel
    
    local stroke = Instance.new('UIStroke')
    stroke.Thickness = 0.84
    stroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = textLabel
end

CreateCooldownUI()

-- ============================================================
-- SPRING TEXT EFFECT
-- ============================================================

local function SpringText(textLabel, strength)
    strength = strength or 10
    local position = 0
    local velocity = 0
    local mass = 169
    local damping = 8
    
    local connection
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        velocity = velocity + (position - strength) * mass * deltaTime
        velocity = velocity * math.exp(-damping * deltaTime)
        position = position + velocity * deltaTime
        textLabel.Rotation = position
        
        if math.abs(position) < 0.01 and math.abs(velocity) < 0.01 then
            textLabel.Rotation = 0
            connection:Disconnect()
        end
    end)
end

-- ============================================================
-- COOLDOWN FUNCTION
-- ============================================================

local function Cooldown(duration, text)
    local cooldownScript = UIParent:FindFirstChild('Cooldown Script')
    if not cooldownScript then return end
    
    local imageLabel = cooldownScript:FindFirstChild('ImageLabel')
    if not imageLabel or imageLabel.Visible then return end
    
    local frame = imageLabel:FindFirstChild('Frame')
    local textLabel = imageLabel:FindFirstChild('TextLabel')
    
    if not frame or not textLabel then return end
    
    -- Play the cooldown frame animation
    task.spawn(function()
        frame.Size = UDim2.new(1, 0, 0.98, 0)
        local tween = TweenService:Create(
            frame,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            { Size = UDim2.new(0.001, 0, 0.98, 0) }
        )
        tween:Play()
        tween.Completed:Wait()
        
        imageLabel.Visible = false
        frame.Size = UDim2.new(1, 0, 0.98, 0)
        textLabel.Rotation = 15
        
        TweenService:Create(
            imageLabel,
            TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            { Position = UDim2.new(1.01, 0, 0.305, -50) }
        ):Play()
    end)
    
    -- Show the cooldown UI
    task.spawn(function()
        textLabel.Text = text
        imageLabel.Visible = true
        
        TweenService:Create(
            imageLabel,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.98, 0, 0.3, -50) }
        ):Play()
        
        SpringText(textLabel, 20)
    end)
end

-- ============================================================
-- CHECK COOLDOWN
-- ============================================================

local function CheckCooldown()
    local cooldownScript = UIParent:FindFirstChild('Cooldown Script')
    if not cooldownScript then return false end
    
    local imageLabel = cooldownScript:FindFirstChild('ImageLabel')
    return imageLabel and imageLabel.Visible
end

-- ============================================================
-- CREATE FREEZE BV
-- ============================================================

local function CreateFreezeBV()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local rootPart = character:FindFirstChild('HumanoidRootPart')
    if not rootPart then return nil end
    
    local existing = rootPart:FindFirstChild('FreezeBV')
    if existing then existing:Destroy() end
    
    local bv = Instance.new('BodyVelocity')
    bv.Name = 'FreezeBV'
    bv.P = 10000
    bv.MaxForce = Vector3.new(1e6, 0, 1e6)
    bv.Velocity = Vector3.zero
    bv.Parent = rootPart
    
    return bv
end

-- ============================================================
-- PLAY ROLL
-- ============================================================

local rollAnimation = Instance.new('Animation')
rollAnimation.AnimationId = ROLL_ANIMATION_ID

local function PlayRoll()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    if not humanoid or humanoid.Health <= 0 then return end
    
    local rootPart = character:FindFirstChild('HumanoidRootPart')
    if not rootPart then return end
    
    if rootPart:FindFirstChild('FreezeBV') or CheckCooldown() then
        return
    end
    
    -- Start cooldown
    Cooldown(2, 'Roll Script')
    
    -- Play animation
    local animator = humanoid:FindFirstChildOfClass('Animator') or humanoid:WaitForChild('Animator', 1)
    if animator then
        pcall(function()
            local track = animator:LoadAnimation(rollAnimation)
            track:Play()
        end)
    end
    
    -- Apply velocity boost
    local freezeBV = CreateFreezeBV()
    if freezeBV then
        freezeBV.Velocity = rootPart.CFrame.LookVector * 100
    end
    
    -- Make character parts massless temporarily
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA('BasePart') then
            part.Massless = true
        end
    end
    
    -- Remove velocity boost
    task.delay(0.17, function()
        if rootPart then
            local bv = rootPart:FindFirstChild('FreezeBV')
            if bv then bv:Destroy() end
        end
    end)
    
    -- Restore mass standard
    task.delay(0.6, function()
        if LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA('BasePart') then
                    part.Massless = false
                end
            end
        end
    end)
end

-- ============================================================
-- CREATE MOBILE BUTTON
-- ============================================================

local function CreateMobileButton()
    if UIParent:FindFirstChild('Gui Button Script') then return end
    
    local guiButtonScript = Instance.new('ScreenGui')
    guiButtonScript.Name = 'Gui Button Script'
    guiButtonScript.Enabled = true
    guiButtonScript.ResetOnSpawn = false
    guiButtonScript.Parent = UIParent
    
    local abilityFrame = Instance.new('Frame')
    abilityFrame.Name = 'RollAbilityFrame'
    abilityFrame.Size = UDim2.new(0.3, 0, 0.5, 0)
    abilityFrame.Position = UDim2.new(0.65, 0, 0.5, 0)
    abilityFrame.BackgroundTransparency = 1
    abilityFrame.Parent = guiButtonScript
    
    local button = Instance.new('ImageButton')
    button.Name = 'ButtonRoll'
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Size = UDim2.new(0.45, 0, 0.45, 0)
    button.Position = UDim2.new(0.7, -25, -0.25, -25)
    button.BackgroundTransparency = 1
    button.Parent = abilityFrame
    
    local aspectRatio = Instance.new('UIAspectRatioConstraint')
    aspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
    aspectRatio.AspectRatio = 1
    aspectRatio.DominantAxis = Enum.DominantAxis.Width
    aspectRatio.Parent = button
    
    local imageLabel = Instance.new('ImageLabel')
    imageLabel.Name = 'RollButton'
    imageLabel.Position = UDim2.new(0.175, 0, 0.175, 0)
    imageLabel.Size = UDim2.new(0.65, 0, 0.65, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.Image = 'rbxassetid://82648533253503'
    imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
    imageLabel.Parent = button
    
    local function PlayHoverSound(soundId)
        local sound = Instance.new('Sound')
        sound.SoundId = 'rbxassetid://' .. soundId
        sound.Volume = 2
        sound.PlaybackSpeed = 1
        sound.Parent = workspace
        sound:Play()
        Debris:AddItem(sound, 2)
    end
    
    button.MouseEnter:Connect(function()
        PlayHoverSound(10066942189)
        TweenService:Create(imageLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            ImageColor3 = Color3.fromRGB(115, 115, 115)
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(imageLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            ImageColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    end)
    
    button.MouseButton1Click:Connect(function()
        PlayHoverSound(10066936758)
        imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
        PlayRoll()
    end)
end

-- ============================================================
-- CREATE DESKTOP KEYBIND
-- ============================================================

local function CreateKeybind()
    if UIParent:FindFirstChild('Keybind Script') then return end
    
    local keybindScript = Instance.new('ScreenGui')
    keybindScript.Name = 'Keybind Script'
    keybindScript.Enabled = true
    keybindScript.IgnoreGuiInset = true
    keybindScript.ResetOnSpawn = false
    keybindScript.Parent = UIParent
    
    local mainFrame = Instance.new('Frame')
    mainFrame.Size = UDim2.new(0.198, 0, 0.094, 0)
    mainFrame.Position = UDim2.new(0.98, 0, 0.6, -50)
    mainFrame.BackgroundTransparency = 1
    mainFrame.AnchorPoint = Vector2.new(1, 0)
    mainFrame.Parent = keybindScript
    
    local aspectRatio = Instance.new('UIAspectRatioConstraint')
    aspectRatio.AspectRatio = 6.07
    aspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
    aspectRatio.Parent = mainFrame
    
    local layout = Instance.new('UIListLayout')
    layout.Padding = UDim.new(0.25, 0)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Parent = mainFrame
    
    local container = Instance.new('Frame')
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Position = UDim2.new(0, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.AnchorPoint = Vector2.new(1, 0)
    container.Parent = mainFrame
    
    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(0.167, 0, 0.759, 0)
    nameLabel.Position = UDim2.new(0.051, 0, 0.001, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.Text = 'R'
    nameLabel.TextScaled = true
    nameLabel.ZIndex = 2
    nameLabel.Parent = container
    
    local nameStroke = Instance.new('UIStroke')
    nameStroke.Thickness = 1.296
    nameStroke.Parent = nameLabel
    
    local keyLabel = Instance.new('ImageLabel')
    keyLabel.Size = UDim2.new(0.17, 0, 1, 0)
    keyLabel.Position = UDim2.new(0.049, 0, -0.054, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Image = 'rbxassetid://132237752209803'
    keyLabel.ImageColor3 = Color3.fromRGB(47, 47, 47)
    keyLabel.Parent = container
    
    local keyImage = Instance.new('ImageLabel')
    keyImage.Size = UDim2.new(0.9, 0, 0.9, 0)
    keyImage.Position = UDim2.new(0.5, 0, 0, 0)
    keyImage.BackgroundTransparency = 1
    keyImage.AnchorPoint = Vector2.new(0.5, 0)
    keyImage.Image = 'rbxassetid://94740529495833'
    keyImage.ImageColor3 = Color3.fromRGB(84, 84, 84)
    keyImage.Parent = keyLabel
    
    local textLabel = Instance.new('TextLabel')
    textLabel.Size = UDim2.new(0.703, 0, 0.619, 0)
    textLabel.Position = UDim2.new(0.288, 0, 0.055, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Font = Enum.Font.FredokaOne
    textLabel.Text = 'Roll Script'
    textLabel.TextScaled = true
    textLabel.Parent = container
    
    local textStroke = Instance.new('UIStroke')
    textStroke.Thickness = 1.232
    textStroke.Parent = textLabel
    
    local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.R then
            TweenService:Create(keyImage, tweenInfo, {
                Position = UDim2.new(0.5, 0, 0, 0),
                ImageColor3 = Color3.fromRGB(84, 84, 84)
            }):Play()
        end
    end)
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.R then
            if CheckCooldown() then return end
            
            TweenService:Create(keyImage, tweenInfo, {
                Position = UDim2.new(0.5, 0, 0, 4),
                ImageColor3 = Color3.fromRGB(122, 122, 122)
            }):Play()
            
            PlayRoll()
        end
    end)
end

-- ============================================================
-- INITIALIZE
-- ============================================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if isMobile then
    CreateMobileButton()
else
    CreateKeybind()
end
