if game.PlaceId == 100588763114828 or game.PlaceId == 129279692364812 then

    local Corn = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"
    ))()

    local Window = Corn:CreateWindow({
        Title = "Corn Hub 🥀",
        SaveConfig = true,
        ConfigFolder = "Corn2yConfig"
    })

    --------------------------------------------------------------------
    -- Variables
    --------------------------------------------------------------------

    local AntiVoidEnabled = false
    local Baseplate = Instance.new("Part")

    --------------------------------------------------------------------
    -- Functions
    --------------------------------------------------------------------

    local function FarmGiftsN()

        local GiftHandler = require(
            game.ReplicatedFirst.ClientModules.GiftClient.GiftClientHandler
        )

        local Player = game.Players.LocalPlayer

        local function TeleportTo(Position)
            local Character = Player.Character or Player.CharacterAdded:Wait()
            local HRP = Character:WaitForChild("HumanoidRootPart")

            HRP.CFrame = CFrame.new(Position)
        end

        for ID, Gift in pairs(GiftHandler.Gifts) do
            if not Gift.Collected then

                Window:Notify({
                    Title = "Gift Farm",
                    Content = "Teleporting to Gift "..tostring(ID),
                    Duration = 2
                })

                TeleportTo(Gift.Position)

                task.wait(0.2)
            end
        end

        Window:Notify({
            Title = "Gift Farm",
            Content = "Finished collecting gifts.",
            Duration = 3
        })

    end

    --------------------------------------------------------------------

    local function EnableAntiVoid()

        if AntiVoidEnabled then
            return
        end

        AntiVoidEnabled = true

        local Player = game.Players.LocalPlayer
        local Character = Player.Character or Player.CharacterAdded:Wait()
        local HRP = Character:WaitForChild("HumanoidRootPart")

        Baseplate.Size = Vector3.new(600,6,600)
        Baseplate.Position = HRP.Position - Vector3.new(0,20,0)
        Baseplate.Anchored = true
        Baseplate.CanCollide = true
        Baseplate.Transparency = 1
        Baseplate.Name = "CornAntiVoid"
        Baseplate.Parent = workspace

        Window:Notify({
            Title = "Anti Void",
            Content = "Enabled",
            Duration = 2
        })

    end

    --------------------------------------------------------------------

    local function DisableAntiVoid()

        AntiVoidEnabled = false

        if Baseplate and Baseplate.Parent then
            Baseplate:Destroy()
            Baseplate = Instance.new("Part")
        end

        Window:Notify({
            Title = "Anti Void",
            Content = "Disabled",
            Duration = 2
        })

    end

    --------------------------------------------------------------------
    -- Farming Tab
    --------------------------------------------------------------------

    local FarmTab = Window:CreateTab({
        Title = "Farming 🔥"
    })

    local FarmSection = FarmTab:CreateSection({
        Title = "Farms 🔥"
    })

    FarmSection:CreateButton({
        Title = "Farm Normal Gifts",

        Callback = function()
            FarmGiftsN()
        end
    })

    --------------------------------------------------------------------
    -- Misc Tab
    --------------------------------------------------------------------

    local MiscTab = Window:CreateTab({
        Title = "Misc"
    })

    local MiscSection = MiscTab:CreateSection({
        Title = "Miscellaneous"
    })

    MiscSection:CreateToggle({

        Title = "Anti Void",

        Default = false,

        Flag = "AntiVoid",

        Callback = function(Value)

            if Value then
                EnableAntiVoid()
            else
                DisableAntiVoid()
            end

        end
    })

    --------------------------------------------------------------------
    -- Command Palette
    --------------------------------------------------------------------

    Window:RegisterCommand({
        Name = "farmgifts",
        Description = "Collect all available gifts",

        Callback = function()
            FarmGiftsN()
        end
    })

    Window:RegisterCommand({
        Name = "antivoid",
        Description = "Toggle Anti Void",

        Callback = function()

            local State = not Corn:GetFlag("AntiVoid")
            Corn:SetFlag("AntiVoid", State)

        end
    })

end
