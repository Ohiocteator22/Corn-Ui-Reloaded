if game.PlaceId == 3101667897 then 
    local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
    local Window = OrionLib:MakeWindow({Name = "Corn Hub 🥀", HidePremium = true, SaveConfig = true, ConfigFolder = "CornyConfig"})
    --making Window--
    --EXTRA IMPORTANR--
    local farming = false
    --functions--
    function AutoFarm(OrbType, Area)
      farming = true
        while farming do
            wait(0.1)
            local args = {
            "collectOrb",
            OrbType,
            Area
            }
            game:GetService("ReplicatedStorage"):WaitForChild("rEvents"):WaitForChild("orbEvent"):FireServer(unpack(args))
        end    
    end 
   --end--
    function RaceWin(x, y, z)
        local player = game:GetService("Players").LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
        local finishpart = Instance.new("Part")
        finishpart.Name = "Part"
        finishpart.Position = Vector3.new(x, y, z)
        finishpart.Size = Vector3.new(5, 1, 5)
        finishpart.Anchored = true
        finishpart.CanCollide = false
        finishpart.Parent = workspace
        task.wait(0.1)
        hrp.CFrame = finishpart.CFrame

    end
    --end--
    function TeleportToAreaPart(partName)
        local player = game:GetService("Players").LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
    
        local teleportParts = workspace:WaitForChild("areaTeleportParts")
        local part = teleportParts:WaitForChild(partName)
    
        if not part:IsA("BasePart") then
            warn(partName .. " is not a valid teleport part")
            return
        end
    
        hrp.CFrame = part.CFrame
    end

            
    --main tab--
    local MainTab = Window:MakeTab({
	Name = "🔥 Autofarm ",
	Icon = "nil",
	PremiumOnly = false
    })
    --section--
    local Section = MainTab:AddSection({
	Name = "W autofarm"
    })
    MainTab:AddButton({
	Name = "Farm Red ORb (City)",
	Callback = function()
      		print("Farm started")
        AutoFarm("Red Orb", "City")
  	end    
        })
    MainTab:AddButton({
	Name = "Farm Gems (City) ",
	Callback = function()
      		print("farming satrted")
        AutoFarm("Gem", "City")
  	end    
        })
    MainTab:AddButton({
    Name = "Stop all Farms",
    Callback = function()
        
        farming = false
        print("farming stopped")
        
    end
        })

 

    
    --Snow city--
    local SnowTab = Window:MakeTab({
    Name = "❄️ Snow City farm",
    Icon = "nil",
    PremiumOnly = false
    })

    --section--
    local Section = SnowTab:AddSection({
    Name = "Snow City Autofarm (works only in Snow city island)"    
    })


    SnowTab:AddButton({
    Name = "Farm Orbs(Snow City)",
    Callback = function()
            print("farming started")
        AutoFarm("Red Orb", "Snow City")    
    end
        })
    SnowTab:AddButton({
    Name = "Farm Gems (snow city)",
    Callback = function()
            print("Farming Started")
        AutoFarm("Gem", "Snow City")
    end 
         })
    
    --Magma City--    
    local MagmaTab = Window:MakeTab({
    Name = "🌋 Magma Tab",
    Icon = "nil",
    PremiumOnly = false
    })

    local section = MagmaTab:AddSection({
    Name = "Magma city autofarm (works onyl in Magma city)"
    })

    MagmaTab:AddButton({
    Name = "Autofarm  (Magma city)",
    Callback = function()
        print("farm started")
        AutoFarm("Red Orb","Magma City")
    end 
    })

    MagmaTab:AddButton({
    Name = "Autofarm Gems (Magma City)",
    Callback = function()
            print("farm Started")
        AutoFarm("Gem", "Magma City")
    end
    })
    --Race Tab--
    local RaceTab = Window:MakeTab({
    Name = "🏁 Race Tab",
    Icon = "nil",
    PremiumOnly = false
    })

    local Section = RaceTab:AddSection({
    Name = "Auto win Race Lol"    
    })

    RaceTab:AddButton({
    Name = "WinRace Grassland",
    Callback = function()
        RaceWin(1612.379, 0.841, -5961.641)
    end
        })
    RaceTab:AddButton({
    Name = "WinRace Desert",
    Callback = function()
        RaceWin(-10.590, 0.8415, -8686.9023)
        
    end
        })
    RaceTab:AddButton({
    Name = "WinRace Magma",
    Callback = function()
        RaceWin(948.594, 0.841, -10987.772)
        
    end
        })
    --Teleports Tabs--
    local TeleportsTab = Window:MakeTab({
    Name = "🗺️ Teleports Tab",
    Icon = "nil",
    PremiumOnly = false 
    })

    local Section = TeleportsTab:AddSection({
    Name = "Teleport to Areas (ONLY BYPASSES PARKOUR)"
    })

    local Section = TeleportsTab:AddSection({
    Name = "You need to go back into cave/teleporter and into the city to make orbs work"
    })

    TeleportsTab:AddButton({
    Name = "TP to Snow City",
    Callback = function()
        TeleportToAreaPart("mysteriousCaveToSnowCity")
    end
    })

    TeleportsTab:AddButton({
    Name = "TP to Magma City",
    Callback = function()
        TeleportToAreaPart("infernoCaveToMagmaCity")
    end
    })

    TeleportsTab:AddButton({
    Name = "TP to Speed Jungle (Cannot bypass rebirth)",
    Callback = function()
        TeleportToAreaPart("jungleCaveToSpeedJungle")
    end
    })

    TeleportsTab:AddButton({
    Name = "TP to Legends Highway",
    Callback = function()
        TeleportToAreaPart("electroCaveToLegendsHighway")
    end
    })



end


-- 1612.3790283203125, 0.8415580987930298, -5961.64111328125 grassland--
--12:18:53 -10.590089797973633, 0.8415583372116089,-8686.90234375 desert--
--12:23:04 948.5941772460938, 0.8415580987930298, -10987.7724609375 magma--




 
