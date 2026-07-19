local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURATION
-- ==========================================
local FOV_RADIUS = 120
local localCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- Automatically update our character reference whenever we respawn
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    localCharacter = newCharacter
end)

-- ==========================================
-- TARGETING LOGIC (FFA / No Teams)
-- ==========================================
local function getClosestValidPlayer()
    local targetCharacter = nil
    local shortestWorldDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        -- Exclude yourself
        if player ~= LocalPlayer then
            local character = player.Character
            
            -- Alive Check & Essential Parts Check
            if character and character:FindFirstChild("Head") and character:FindFirstChild("HumanoidRootPart") then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                if humanoid and humanoid.Health > 0 then
                    local head = character.Head
                    local targetRoot = character.HumanoidRootPart
                    
                    -- 1. Screen Check: Convert 3D position to 2D screen position
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    
                    if onScreen then
                        -- Calculate 2D distance from center of the screen
                        local distanceFromCenter = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
                        
                        if distanceFromCenter <= FOV_RADIUS then
                            -- 2. Distance Priority Check: Calculate 3D distance between players
                            local worldDistance = (targetRoot.Position - localRoot.Position).Magnitude
                            
                            -- Prioritize whoever is physically closest to us in 3D space
                            if worldDistance < shortestWorldDistance then
                                
                                -- 3. Raycast (Wall Check)
                                local rayParams = RaycastParams.new()
                                rayParams.FilterDescendantsInstances = {localCharacter}
                                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                
                                local direction = (head.Position - Camera.CFrame.Position)
                                local rayResult = Workspace:Raycast(Camera.CFrame.Position, direction, rayParams)
                                
                                -- If ray hits nothing (clear sky) or hits the target character directly, it's valid
                                if not rayResult or (rayResult and rayResult.Instance:IsDescendantOf(character)) then
                                    shortestWorldDistance = worldDistance
                                    targetCharacter = character
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return targetCharacter
end

-- ==========================================
-- CAMERA MANIPULATION
-- ==========================================
RunService.RenderStepped:Connect(function()
    if localCharacter and localCharacter:FindFirstChildOfClass("Humanoid") and localCharacter:FindFirstChildOfClass("Humanoid").Health > 0 then
        local target = getClosestValidPlayer()
        
        if target and target:FindFirstChild("Head") then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Head.Position)
        end
    end
end)
