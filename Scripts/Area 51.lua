if game.PlaceId == 2092166489 then
    local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
    local Window = OrionLib:MakeWindow({Name = "Corn Hub 🥀", HidePremium = true, SaveConfig = true, ConfigFolder = "Corn3yConfig"})
    --done making window--
    local player = game.Players.LocalPlayer   
    --done adding variables--
    local Weapons = {
    ["AK-47"] = workspace.Weapons["AK-47"],
    ["AN-94"] = workspace.Weapons["AN-94"],
    ["Colt Anaconda"] = workspace.Weapons["Colt Anaconda"],
    ["AWP"] = workspace.Weapons.AWP,
    ["DB Shotgun"] = workspace.Weapons["DB Shotgun"],
    ["Desert Eagle"] = workspace.Weapons["Desert Eagle"],
    ["Flamethrower"] = workspace.Weapons.Flamethrower,
    ["G36C"] = workspace.Weapons.G36C,
    ["M1014"] = workspace.Weapons.M1014,
    ["M14"] = workspace.Weapons.M14,
    ["M16A2/M203"] = workspace.Weapons["M16A2/M203"],
    ["M4A1"] = workspace.Weapons.M4A1,
    ["MP5K"] = workspace.Weapons.MP5k,
    ["P90"] = workspace.Weapons.P90,
    ["R870"] = workspace.Weapons.R870,
    ["RayGun"] = workspace.Weapons.RayGun,
    ["SVD"] = workspace.Weapons.SVD
    }
    --weapon table done--
    function TeleportToWeapon(name)
        local character = player.Character or player.CharacterAdded:Wait()
        local weapon = Weapons[name]
        if weapon then
            character:PivotTo(weapon:GetPivot())
        end
    end

    function TeleportToSpawn()
        
    end

    --functions only--
    --making Auto get weapon tab--
    local WeaponTab = Window:MakeTab({
    Name = "Get Guns 💥",
    Icon = "nil",
    PremiumOnly = false
    })
    
    local Section = WeaponTab:AddSection({
    Name = "Get all Guns"
    })
    
    WeaponTab:AddButton({
    Name = "Get Ak-47",
    Callback = function()
        TeleportToWeapon("AK-47")
    end
    })
    WeaponTab:AddButton({
    Name = "Get An-94",
    Callback = function()
        TeleportToWeapon("AN-94")
    end
    })

    WeaponTab:AddButton({
    Name = "Get Colt Anaconda",
    Callback = function()
        TeleportToWeapon("Colt Anaconda")
    end
    })

    WeaponTab:AddButton({
    Name = "Get AWP",
    Callback = function()
        TeleportToWeapon("AWP")
    end
    })

    WeaponTab:AddButton({
    Name = "Get DB shotgun",
    Callback = function()
        TeleportToWeapon("DB Shotgun")
    end
    })

    WeaponTab:AddButton({
    Name = "Get Desert Eagle",
    Callback = function()
        TeleportToWeapon("Desert Eagle")
    end
    })

    WeaponTab:AddButton({
    Name = "Get Flamethrower",
    Callback = function()
        TeleportToWeapon("Flamethrower")
    end
    })

    WeaponTab:AddButton({
    Name = "Get G36C",
    Callback = function()
        TeleportToWeapon("G36C")
    end
    })

    WeaponTab:AddButton({
    Name = "Get M1014",
    Callback = function()
        TeleportToWeapon("M1014")
    end
    })

    WeaponTab:AddButton({
    Name = "Get M14",
    Callback = function()
        TeleportToWeapon("M14")
    end
    })

    WeaponTab:AddButton({
    Name = "Get M16A2/M203",
    Callback = function()
        TeleportToWeapon("M16A2/M203")
    end
    })

    WeaponTab:AddButton({
    Name = "Get M4A1",
    Callback = function()
        TeleportToWeapon("M4A1")
    end
    })

    WeaponTab:AddButton({
    Name = "Get MP5k",
    Callback = function()
        TeleportToWeapon("MP5K")
    end
    })

    WeaponTab:AddButton({
    Name = "Get P90",
    Callback = function()
        TeleportToWeapon("P90")
    end
    })

    WeaponTab:AddButton({
    Name = "Get R870",
    Callback = function()
        TeleportToWeapon("R870")
    end
    })

    WeaponTab:AddButton({
    Name = "Get RayGun",
    Callback = function()
        TeleportToWeapon("RayGun")
    end
    })

    WeaponTab:AddButton({
    Name = "Get SVD",
    Callback = function()
        TeleportToWeapon("SVD")
    end
    })

    --WeaponTab:AddButton({
    --Name = "Back to spawn",
    --Callback = function()
        
    --end
    --})
end




























