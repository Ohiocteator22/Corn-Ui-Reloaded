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



task.spawn(FarmNinjustsu)
task.spawn(FarmCoins)
