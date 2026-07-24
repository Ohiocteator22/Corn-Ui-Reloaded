local Corn = loadstring(game:HttpGet('https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua'))()

local Window = Corn:CreateWindow({
    Name = "Corn Hub 🥀 ",
    Subtitle = "By Lifeless (v.10 stable)",
    Icon = 80406291512141,
    Theme = "Dark"
})


local AutoClick = false
local FarmCoinEnabled = false
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RobotLoop = false
--variables--
local function FarmNinjustsu()

    while true do

        if AutoClick then

            local event = LocalPlayer:FindFirstChild("ninjaEvent")

            if event then
                event:FireServer("swingKatana")
            end

        end

        task.wait(0.2)

    end
end




-- Shop Area
local function TeleportShop()
    local character = LocalPlayer.Character
    if not character then return end

    character:PivotTo(
        workspace.shopAreaCircles.shopAreaCircle.circleInner.CFrame
    )
end

-- Skills Area
local function TeleportSkills()
    local character = LocalPlayer.Character
    if not character then return end

    character:PivotTo(
        workspace.skillAreaCircles.skillsAreaCircle.circleInner.CFrame
    )
end

-- Safezone 13
local function TeleportSafezone13()
    local character = LocalPlayer.Character
    if not character then return end

    character:PivotTo(
        workspace.safezoneParts:GetChildren()[13].CFrame
    )
end

-- Safezone 12
local function TeleportSafezone12()
    local character = LocalPlayer.Character
    if not character then return end

    character:PivotTo(
        workspace.safezoneParts:GetChildren()[12].CFrame
    )
end

-- Robot Boss Loop
local function StartRobotBossLoop()
    RobotLoop = true

    task.spawn(function()
        while RobotLoop do
            local character = LocalPlayer.Character
            local boss = workspace.bossFolder:FindFirstChild("RobotBoss")

            if character and boss and boss:FindFirstChild("Head") then
                character:PivotTo(boss.Head.CFrame)
            end

            task.wait()
        end
    end)
end

local function StopRobotBossLoop()
    RobotLoop = false
end

local function FarmCoins()

    while true do

        if FarmCoinEnabled then

            local character = LocalPlayer.Character

            if character then

                local root = character:FindFirstChild("HumanoidRootPart")

                local spawnedCoins = workspace:FindFirstChild("spawnedCoins")
                local valley = spawnedCoins and spawnedCoins:FindFirstChild("Valley")

                if root and valley then

                    for _, coin in ipairs(valley:GetChildren()) do

                        if not FarmCoinEnabled then
                            break
                        end


                        local target


                        if coin:IsA("BasePart") then

                            target = coin.CFrame


                        elseif coin:IsA("Model") and coin.PrimaryPart then

                            target = coin.PrimaryPart.CFrame

                        end


                        if target then

                            root.CFrame = target + Vector3.new(0,3,0)

                        end


                        task.wait(0.3)

                    end
                end
            end
        end


        task.wait(0.2)

    end
end



local Tab = Window:CreateTab("Main", {Icon = nil})

local Section = Tab:CreateSection("Farms")

Section:CreateLabel("Have Fun!")


Tab:CreateToggle({
    Name = "Farm Ninjutsu (equip sword)",
    Default = false,

    Callback = function(state)

        AutoClick = state

    end
})


Tab:CreateToggle({
    Name = "Farm Coins",
    Default = false,

    Callback = function(state)

        FarmCoinEnabled = state

    end
})

local Tab2 = Window:CreateTab("Teleports", {Icon = nil})

Tab2:CreateLabel("Teleports to Locations!")

local Section2 = Tab2:CreateSection("Teleports")
Tab2:CreateButton({
    Name = "Teleport to Shop",
    Callback = function()
        TeleportShop()
    end
})

Tab2:CreateButton({
    Name = "Teleport to Skills",
    Callback = function()
        TeleportSkills()
    end
})

Tab2:CreateButton({
    Name = "Teleport To Purple Crystal",
    Callback = function()
        TeleportSafezone13()
    end
})

Tab2:CreateButton({
    Name = "Teleport To Blue Crystal",
    Callback = function()
        TeleportSafezone12()
    end
})

Tab2:CreateToggle({
    Name = "Robot Boss Farm Loop",
    Default = false,
    Callback = function(state)
        if state then
            StartRobotBossLoop()
        else
            StopRobotBossLoop()
        end
    end
})


task.spawn(FarmNinjustsu)
task.spawn(FarmCoins)
