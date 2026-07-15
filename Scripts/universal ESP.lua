local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- Create GUI once
local Gui = Instance.new("ScreenGui")
Gui.IgnoreGuiInset = true
Gui.Parent = LocalGui
Gui.ResetOnSpawn = false

LocalPlayer.CharacterAdded:Connect(function()
    local NewGui = LocalPlayer:WaitForChild("PlayerGui")

    if Gui.Parent ~= NewGui then
        Gui.Parent = NewGui
    end
end)
-- Table storing one Frame per player
local Boxes = {}

-- Create a Frame for a player
local function CreateBox(player)
    if player == LocalPlayer then
        return
    end

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.fromOffset(20,20)
    Frame.AnchorPoint = Vector2.new(0.5,0)
    Frame.Visible = false
    Frame.Parent = Gui
    Frame.BackgroundTransparency = 1
    Frame.BorderSizePixel = 2
    Frame.BorderColor3 = Color3.fromRGB(255,0,0)
    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness = 2
    Stroke.Color = Color3.fromRGB(255,0,0)
    Stroke.Parent = Frame
    Boxes[player] = Frame
end

-- Remove a player's Frame
local function RemoveBox(player)
    if Boxes[player] then
        Boxes[player]:Destroy()
        Boxes[player] = nil
    end
end


-- Existing players
for _, player in ipairs(Players:GetPlayers()) do
    CreateBox(player)
end

-- Future players
Players.PlayerAdded:Connect(CreateBox)
Players.PlayerRemoving:Connect(RemoveBox)

-- Update every frame
RunService.RenderStepped:Connect(function()

    for player, box in pairs(Boxes) do

        local character = player.Character
        local head = character and character:FindFirstChild("Head")

        if head then
            local screenPos, visible =
                Camera:WorldToViewportPoint(head.Position)

            box.Visible = visible

            if visible then
                box.Position =
                    UDim2.fromOffset(screenPos.X, screenPos.Y)
            end
        else
            box.Visible = false
        end

    end

end)
