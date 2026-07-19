local KeySystem = loadstring(game:HttpGet('https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Loader/KeySystem.lua'))()
KeySystem.Prompt(function()
    local Corn = loadstring(game:HttpGet('https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua'))()
    local Window = Corn:CreateWindow({
        Name = "Corn Hub 🥀 ",
        Subtitle = "By Lifeless (v.10 stable)",
        Icon = 80406291512141,
        Theme = "Dark"
    })
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

    local FinishPart = workspace.tower.sections.finish.exit.ParticleBrick


    Window:Notify({Title = "Load Check", Content = "The hub has Loaded!", Type = "success" })

    --window defined--
    function Introduction_Complete()
        character:PivotTo(FinishPart.CFrame)
    end

   

    --functions--
    --making hub--
    local Tab = Window:CreateTab("Main", { Icon = nil })
    local Section = Tab:CreateSection("Instants")
    Section:CreateLabel("Kindly dont die, or else you have to re load the hub")
    
    Section:CreateButton({
        Name = "Auto Tower",
        Callback = function()
            Introduction_Complete()
        end        
    })
end)
