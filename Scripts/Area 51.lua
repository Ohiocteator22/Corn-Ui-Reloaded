if game.PlaceId == 2092166489 then
    local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"))()
    local Window = Library:CreateWindow({
    Name = "Corn Hub",
    Subtitle = "By Lifeless",
    Icon = 80406291512141, -- or nil if this one also gets flagged
    Theme = "Dark",
    Intro = {
        Image = 80406291512141,
        Text = "By Lifeless",
        Duration = 1.4,
    },
})
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
    Window:Notify({
    Title = "Success",
    Content = "CornUI Loaded!",
    Duration = 4,
    Type = "success"
    })
    --making Auto get weapon tab--
    local Main = Window:CreateTab("Get Guns 💥", {
    Icon = 98667413760537
    })
    
    local Section = Main:CreateSection("Get Guns")
    Section:CreateDropdown({
    Name = "Weapon",
    Options = {
        "AK47",
        "M4A1",
        "AWP",
        "Colt Anaconda",
        "SVD",
        "RayGun",
        "R870",
        "P90",
        "MP5K",
        "Flamethrower",
        "Desert Eagle",
        "DB Shotgun",
        "M16A2/M203",
        "M14",
        "M1014",
        "G36C"
    },
    Default = "AK47",
    Callback = function(name)
        TeleportToWeapon(name)
    end
    })
    
    Main:CreateButton({
    Name = "goto ak47",
    Callback = function()
        TeleportToWeapon("AK-47")
    end
    })
end




























