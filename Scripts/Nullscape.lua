if game.PlaceId == 100588763114828 or game.PlaceId == 129279692364812 then
    local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
    local Window = OrionLib:MakeWindow({Name = "Corn Hub 🥀", HidePremium = true, SaveConfig = true, ConfigFolder = "Corn2yConfig"})
    --done making window--
    local Void = false
    local baseplate = Instance.new("Part")
    --functions--
    function FarmGiftsN()
        local GiftHandler = require(
        game.ReplicatedFirst.ClientModules.GiftClient.GiftClientHandler
        )

        local player = game.Players.LocalPlayer

        local function TeleportTo(pos)
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")

        hrp.CFrame = CFrame.new(pos)
        end


        for id, gift in pairs(GiftHandler.Gifts) do
            if not gift.Collected then
                print("Going to gift:", id, gift.Position)

                TeleportTo(gift.Position)

                task.wait(0.2)
            end
        end
    end

    --function end--

    function AntiVoid()
        Void = true
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")
        wait(0.1)
        if Void == true then           
            baseplate.Size = Vector3.new(600,6,600)
            baseplate.Position = Vector3.new(hrp.Position.X, hrp.Position.Y -20, hrp.Position.Z)
            baseplate.Parent = workspace
            baseplate.CanCollide = true
            baseplate.Anchored = true
            baseplate.Transparency = 1
        end         
    end

    function DisableAntiVoid()
        Void = false
        baseplate:Destroy()
    end 
    --making Farm Tab--
    local FarmTab = Window:MakeTab({
    Name = "Farming 🔥",
    Icon = "nil",
    PremiumOnly = false
    })
    --section--
    local Section = FarmTab:AddSection({
    Name = "Farms 🔥"
    })
    --buttons--
    FarmTab:AddButton({
    Name = "Farm Normal Gifts",
    Callback = function()
        FarmGiftsN()
    end
    })
        
        
    





    --Mic Tab--
    local MiscTab = Window:MakeTab({
    Name = "Misc",
    Icon = "nil",
    PremiumOnly = false
    })
    --section--
    local Section = MiscTab:AddSection({
    Name = "Micalleniousuuss (idk spelling)"
    })
    --buttons--
    MiscTab:AddButton({
    Name = "Turn On Antivoid",
    Callback = function()
        AntiVoid()
    end
    })
    MiscTab:AddButton({
    Name = "Turn off Antivoid",
    Callback = function()
        DisableAntiVoid()
    end
    })
























end 
