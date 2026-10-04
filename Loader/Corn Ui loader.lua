-- CORN LOADER

local Corn = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"
))()

local Window = Corn:CreateWindow({
    Name = "Corn Hub",
    Subtitle = "By Lifeless (Allure)",
    Icon = 80406291512141,
    Theme = "Dark",
    Intro = {
        Image = 80406291512141,
        Text = "By Lifeless",
        Duration = 1.4,
        Funny = true,
    },
})

Window:Notify({ Title = "Loader", Content = "Corn Loader ready", Type = "success" })

local Tab1 = Window:CreateTab("LOADER")
local Section1 = Tab1:CreateSection("LOAD GAMES")

-- map: game name -> single URL string OR array of URL strings
local SCRIPTS = {
    ["GEF"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/GEF.lua",

    ["Tower of Hell"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/TowerOfHell.lua",

    ["Survive and Kill in Area 51"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Area%2051.lua",

    ["Ninja Legends"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Ninja%20Legends.lua",

    ["Legends of Speed"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Legends%20of%20speed.lua",

    ["Nullscape"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Nullscape.lua",

    ["Rivals"] = "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Rivals.lua",

    ["Flick"] = {
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Universal%20Aimlock.lua",
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/universal%20ESP.lua",
    },

    ["OneTap"] = {
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Universal%20Aimlock.lua",
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/universal%20ESP.lua",
    },

    ["Sniper Arena"] = {
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Universal%20Aimlock.lua",
        "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/universal%20ESP.lua",
    },
}

local function loadGame(name)
    local entry = SCRIPTS[name]
    if not entry then
        Window:Notify({ Title = "Loader", Content = ("No entry for '%s'"):format(name), Type = "error" })
        return
    end

    local urls = typeof(entry) == "table" and entry or { entry }

    local allOk = true
    for _, url in ipairs(urls) do
        local ok, err = pcall(function()
            local src = game:HttpGet(url)
            loadstring(src)()
        end)
        if not ok then
            allOk = false
            Window:Notify({ Title = "Loader", Content = ("Failed %s: %s"):format(name, tostring(err)), Type = "error" })
        end
    end

    if allOk then
        Window:Notify({ Title = "Loader", Content = ("Loaded %s"):format(name), Type = "success" })
    end
end

local currentSelection = "Rivals"

Section1:CreateDropdown({
    Name = "Select Game",
    Options = {
        "GEF", "Tower of Hell", "Survive and Kill in Area 51",
        "Ninja Legends", "Legends of Speed", "Nullscape",
        "Rivals", "Flick", "OneTap", "Sniper Arena",
    },
    Default = "Rivals",
    Flag = "SelectOption",
    Callback = function(option)
        currentSelection = option
        loadGame(option)
    end,
})

Section1:CreateButton({
    Name = "Load Selected",
    Callback = function()
        loadGame(currentSelection)
    end,
})