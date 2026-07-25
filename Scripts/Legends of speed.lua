
if game.PlaceId ~= 3101667897 then
    return
end


local Corn = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"
))()


local Window = Corn:CreateWindow({
    Name = "Corn Hub 🥀",
    Subtitle = "Speed Simulator",
    Theme = "Dark",
    Icon = 80406291512141,
})


--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer


--==================================================
-- STATE
--==================================================

local farming = false
local farmThread = nil



--==================================================
-- NOTIFY HELPER
--==================================================

local function Notify(title, content, type)
    Window:Notify({
        Title = title,
        Content = content,
        Type = type or "info",
    })
end



--==================================================
-- FARM SYSTEM
--==================================================

local function StopFarm()

    farming = false

    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end

    Notify(
        "Autofarm",
        "Farm stopped",
        "warning"
    )

end



local function StartFarm(orbType, area)

    StopFarm()

    farming = true


    Notify(
        "Autofarm",
        "Started farming "..orbType.." in "..area,
        "success"
    )


    farmThread = task.spawn(function()

        while farming do

            local args = {
                "collectOrb",
                orbType,
                area
            }


            pcall(function()

                ReplicatedStorage
                    :WaitForChild("rEvents")
                    :WaitForChild("orbEvent")
                    :FireServer(
                        unpack(args)
                    )

            end)


            task.wait(0.1)

        end

    end)

end



--==================================================
-- RACE SYSTEM
--==================================================

local function RaceWin(x,y,z)

    local character = Player.Character 
        or Player.CharacterAdded:Wait()


    local hrp = character:WaitForChild(
        "HumanoidRootPart"
    )


    hrp.CFrame = CFrame.new(
        x,y,z
    )


    Notify(
        "Race",
        "Teleported to finish line",
        "success"
    )

end



--==================================================
-- TELEPORT SYSTEM
--==================================================

local function TeleportToAreaPart(partName)

    local character = Player.Character
        or Player.CharacterAdded:Wait()


    local hrp = character:
        WaitForChild("HumanoidRootPart")


    local teleportParts =
        workspace:WaitForChild(
            "areaTeleportParts"
        )


    local part =
        teleportParts:FindFirstChild(
            partName
        )


    if not part then

        Notify(
            "Teleport Failed",
            "Missing teleport part",
            "error"
        )

        return

    end


    hrp.CFrame = part.CFrame


    Notify(
        "Teleport",
        "Moved successfully",
        "success"
    )

end

--==================================================
-- AUTOFARM TAB
--==================================================


local FarmTab = Window:CreateTab(
    "🔥 Autofarm",
    {
        Icon = 123456
    }
)


local FarmSection = FarmTab:CreateSection(
    "Speed Simulator Autofarm"
)



FarmSection:CreateButton({

    Name = "Farm Red Orb (City)",

    Description = "Collect City red orbs",

    Callback = function()

        StartFarm(
            "Red Orb",
            "City"
        )

    end

})



FarmSection:CreateButton({

    Name = "Farm Gems (City)",

    Description = "Collect City gems",

    Callback = function()

        StartFarm(
            "Gem",
            "City"
        )

    end

})



FarmSection:CreateButton({

    Name = "Stop All Farms",

    Callback = function()

        StopFarm()

    end

})





--==================================================
-- SNOW CITY TAB
--==================================================


local SnowTab = Window:CreateTab(
    "❄️ Snow City",
    {
        Icon = 123456
    }
)


local SnowSection = SnowTab:CreateSection(
    "Snow City Autofarm"
)



SnowSection:CreateButton({

    Name = "Farm Snow City Orbs",

    Callback = function()

        StartFarm(
            "Red Orb",
            "Snow City"
        )

    end

})



SnowSection:CreateButton({

    Name = "Farm Snow City Gems",

    Callback = function()

        StartFarm(
            "Gem",
            "Snow City"
        )

    end

})





--==================================================
-- MAGMA CITY TAB
--==================================================


local MagmaTab = Window:CreateTab(
    "🌋 Magma City",
    {
        Icon = 123456
    }
)



local MagmaSection =
    MagmaTab:CreateSection(
        "Magma City Autofarm"
    )



MagmaSection:CreateButton({

    Name = "Farm Magma Orbs",

    Callback = function()

        StartFarm(
            "Red Orb",
            "Magma City"
        )

    end

})



MagmaSection:CreateButton({

    Name = "Farm Magma Gems",

    Callback = function()

        StartFarm(
            "Gem",
            "Magma City"
        )

    end

})





--==================================================
-- RACE TAB
--==================================================


local RaceTab = Window:CreateTab(
    "🏁 Races",
    {
        Icon = 123456
    }
)



local RaceSection =
    RaceTab:CreateSection(
        "Instant Race Wins"
    )




RaceSection:CreateButton({

    Name = "Win Grassland Race",

    Callback = function()

        RaceWin(
            1612.379,
            0.841,
            -5961.641
        )

    end

})




RaceSection:CreateButton({

    Name = "Win Desert Race",

    Callback = function()

        RaceWin(
            -10.590,
            0.841,
            -8686.902
        )

    end

})




RaceSection:CreateButton({

    Name = "Win Magma Race",

    Callback = function()

        RaceWin(
            948.594,
            0.841,
            -10987.772
        )

    end

})

--==================================================
-- TELEPORT TAB
--==================================================


local TeleportTab = Window:CreateTab(
    "🗺️ Teleports",
    {
        Icon = 123456
    }
)



local TeleportSection =
    TeleportTab:CreateSection(
        "Area Teleports"
    )



TeleportSection:CreateLabel(
    "Bypasses the parkour sections"
)



TeleportSection:CreateButton({

    Name = "Teleport to Snow City",

    Callback = function()

        TeleportToAreaPart(
            "mysteriousCaveToSnowCity"
        )

    end

})



TeleportSection:CreateButton({

    Name = "Teleport to Magma City",

    Callback = function()

        TeleportToAreaPart(
            "infernoCaveToMagmaCity"
        )

    end

})



TeleportSection:CreateButton({

    Name = "Teleport to Speed Jungle",

    Callback = function()

        TeleportToAreaPart(
            "jungleCaveToSpeedJungle"
        )

    end

})



TeleportSection:CreateButton({

    Name = "Teleport to Legends Highway",

    Callback = function()

        TeleportToAreaPart(
            "electroCaveToLegendsHighway"
        )

    end

})





--==================================================
-- SETTINGS TAB
--==================================================


local SettingsTab = Window:CreateTab(
    "⚙️ Settings",
    {
        Icon = 123456
    }
)



local SettingsSection =
    SettingsTab:CreateSection(
        "Hub Settings"
    )



SettingsSection:CreateToggle({

    Name = "Auto Notify",

    Default = true,

    Flag = "AutoNotify",

    Callback = function(state)

        Corn:SetFlag(
            "AutoNotify",
            state
        )

    end

})



SettingsSection:CreateKeybind({

    Name = "Stop Farming Key",

    Default = Enum.KeyCode.X,

    Flag = "StopFarmKey",

    Callback = function()

        StopFarm()

    end

})





--==================================================
-- GLOBAL COMMAND
--==================================================


Window:RegisterCommand(
    "stopfarm",
    function()

        StopFarm()

    end
)



Window:RegisterCommand(
    "farmcity",
    function()

        StartFarm(
            "Red Orb",
            "City"
        )

    end
)



--==================================================
-- STARTUP
--==================================================


Notify(
    "Corn Hub 🥀",
    "Loaded successfully",
    "success"
)


--==================================================
-- CLEANUP
--==================================================


Player.CharacterAdded:Connect(function()

    if farming then

        Notify(
            "Character Respawned",
            "Farm continues",
            "info"
        )

    end

end)
