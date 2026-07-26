if game.PlaceId == 100588763114828 or game.PlaceId == 129279692364812 then

    local Corn = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"
    ))()


    local Window = Corn:CreateWindow({
        Name = "Corn Hub 🥀",
        Subtitle = "Nullscape",
        Theme = "Dark",
    })


    --------------------------------------------------------------------
    -- Variables
    --------------------------------------------------------------------

    local AntiVoidEnabled = false
    local Baseplate = nil


    --------------------------------------------------------------------
    -- Functions
    --------------------------------------------------------------------

    local function FarmGiftsN()

        local Success, GiftHandler = pcall(function()
            return require(
                game.ReplicatedFirst.ClientModules.GiftClient.GiftClientHandler
            )
        end)

        if not Success then
            Window:Notify({
                Title = "Gift Farm",
                Content = "Failed loading Gift Handler",
                Type = "error"
            })
            return
        end


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
                    Content = "Teleporting to gift "..tostring(ID),
                    Duration = 2,
                    Type = "info"
                })


                TeleportTo(Gift.Position)

                task.wait(0.2)

            end

        end


        Window:Notify({
            Title = "Gift Farm",
            Content = "Finished collecting gifts.",
            Duration = 3,
            Type = "success"
        })

    end



    local function EnableAntiVoid()

        if AntiVoidEnabled then
            return
        end


        AntiVoidEnabled = true


        local Player = game.Players.LocalPlayer
        local Character = Player.Character or Player.CharacterAdded:Wait()
        local HRP = Character:WaitForChild("HumanoidRootPart")


        Baseplate = Instance.new("Part")

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
            Type = "success"
        })

    end



    local function DisableAntiVoid()

        AntiVoidEnabled = false


        if Baseplate then

            Baseplate:Destroy()
            Baseplate = nil

        end


        Window:Notify({
            Title = "Anti Void",
            Content = "Disabled",
            Type = "warning"
        })

    end



    --------------------------------------------------------------------
    -- Farming Tab
    --------------------------------------------------------------------

    local FarmTab = Window:CreateTab("Farming 🔥")


    local FarmSection = FarmTab:CreateSection("Farms 🔥")


    FarmSection:CreateButton({

        Name = "Farm Normal Gifts",

        Callback = function()

            task.spawn(FarmGiftsN)

        end

    })



    --------------------------------------------------------------------
    -- Misc Tab
    --------------------------------------------------------------------

    local MiscTab = Window:CreateTab("Misc")


    local MiscSection = MiscTab:CreateSection("Miscellaneous")


    MiscSection:CreateToggle({

        Name = "Anti Void",

        Default = false,

        Flag = "AntiVoid",

        Callback = function(State)

            if State then

                EnableAntiVoid()

            else

                DisableAntiVoid()

            end

        end

    })



    --------------------------------------------------------------------
    -- Command Palette
    --------------------------------------------------------------------

    Window:RegisterCommand("farmgifts", function(window)

        task.spawn(FarmGiftsN)

    end)



    Window:RegisterCommand("antivoid", function(window)

        local Current = Corn:GetFlag("AntiVoid")

        Corn:SetFlag(
            "AntiVoid",
            not Current
        )

    end)



end
