local Corn = loadstring(game:HttpGet('https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua'))()

local Window = Corn:CreateWindow({
    Name = "Corn Hub 🥀 ",
    Subtitle = "By Lifeless (v.10 stable)",
    Icon = 80406291512141,
    Theme = "Dark"
})


local AutoClick = false
local FarmCoinEnabled = false
local TargetNinjitsu = 0
local hoopFarming = false


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer


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


local function FarmHoops()

    while true do

        if hoopFarming then

            local player = game.Players.LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            local hrp = character:WaitForChild("HumanoidRootPart")

            local hoopsFolder = workspace:FindFirstChild("Hoops")

            if hoopsFolder then

                for _, hoop in ipairs(hoopsFolder:GetChildren()) do

                    if not hoopFarming then
                        break
                    end


                    local target


                    if hoop:IsA("BasePart") then

                        target = hoop.CFrame


                    elseif hoop:IsA("Model") then

                        if hoop.PrimaryPart then
                            target = hoop.PrimaryPart.CFrame
                        else
                            local part = hoop:FindFirstChildWhichIsA("BasePart")

                            if part then
                                target = part.CFrame
                            end
                        end

                    end


                    if target then

                        hrp.CFrame = target + Vector3.new(0,3,0)

                        task.wait(0.2)

                    end

                end

            end

        end

        task.wait(0.2)

    end

end
--functions--
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
--special child btw--
Tab:CreateTextbox({
    Name = "Sell All Ninjitsu threshold",
    Placeholder = "Example: 100000",
    Callback = function(text)
        TargetNinjitsu = tonumber(text) or 0
    end
})
task.spawn(function()

    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local Ninjitsu = LocalPlayer.leaderstats:WaitForChild("Ninjitsu")
    local SellPart = workspace.sellAreaCircles.sellAreaCircle.circleInner

    while true do

        if TargetNinjitsu > 0 and Ninjitsu.Value >= TargetNinjitsu then

            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local root = character:WaitForChild("HumanoidRootPart")

            root.CFrame = SellPart.CFrame + Vector3.new(0, 3, 0)

            task.wait(1)

        end

        task.wait(0.1)

    end

end)


--end of this special child--
Tab:CreateToggle({
    Name = "Farm Hoops",
    Default = false,
    Callback = function(state)
        hoopFarming = state
    end

})


task.spawn(FarmNinjustsu)
task.spawn(FarmCoins)
task.spawn(FarmHoops)
