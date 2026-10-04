-- Corn UI + GEF Teleport & Farm Hub

local Corn = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua"
))()

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer

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

Window:Notify({ Title = "Welcome", Content = "GEF Hub loaded!", Type = "success" })

-- helpers

local function getChar()
    local char = player.Character or player.CharacterAdded:Wait()
    return char, char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(part)
    if not part then warn("teleportTo: part is nil") return false end
    local char, hrp = getChar()
    if not hrp then warn("teleportTo: no HumanoidRootPart") return false end
    hrp.CFrame = part.CFrame + Vector3.new(0, 5, 0)
    return true
end

local function findItem(name)
    local pickups = workspace:FindFirstChild("Pickups")
    if not pickups then return nil end
    for _, item in ipairs(pickups:GetDescendants()) do
        if item:IsA("MeshPart") and item.Name == name then return item end
    end
    return nil
end

local function teleportToAll(name, delay, shouldCancel)
    delay = delay or 0.5
    shouldCancel = shouldCancel or function() return false end

    local pickups = workspace:FindFirstChild("Pickups")
    if not pickups then warn("Pickups folder not found") return 0 end

    local matches = {}
    for _, item in ipairs(pickups:GetDescendants()) do
        if item:IsA("MeshPart") and item.Name == name then
            table.insert(matches, item)
        end
    end
    if #matches == 0 then warn(("No items named '%s'"):format(name)) return 0 end

    local count = 0
    for i, part in ipairs(matches) do
        if shouldCancel() then break end
        if part and part.Parent then
            teleportTo(part)
            count = count + 1
        end
        task.wait(delay)
    end
    return count
end

-- gef helpers

local function getBasePart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function getHealthValue(gef)
    if not gef or not gef.Parent then return nil end

    local h = gef:FindFirstChild("Health")
    if h then
        if h:IsA("NumberValue") or h:IsA("IntValue") then
            return h.Value
        elseif h:IsA("Humanoid") then
            return h.Health
        end
    end

    local hum = gef:FindFirstChildWhichIsA("Humanoid", true)
    if hum then return hum.Health end

    return nil
end

local function isGrouped(gef, allGEFs, radius)
    local base = getBasePart(gef)
    if not base then return true end

    for _, other in ipairs(allGEFs) do
        if other ~= gef then
            local otherBase = getBasePart(other)
            if otherBase then
                if (otherBase.Position - base.Position).Magnitude <= radius then
                    return true
                end
            end
        end
    end
    return false
end

local function collectGEFs(targetName, maxRadius, groupRadius)
    maxRadius   = maxRadius   or 1000
    groupRadius = groupRadius or 100

    local gefs = workspace:FindFirstChild("GEFs")
    if not gefs then return {} end

    local _, hrp = getChar()
    local origin = hrp and hrp.Position or Vector3.zero

    local allMatching = {}
    for _, obj in ipairs(gefs:GetChildren()) do
        if obj.Name == targetName then
            table.insert(allMatching, obj)
        end
    end

    local out = {}
    for _, obj in ipairs(allMatching) do
        local base = getBasePart(obj)
        if base then
            local dist = (base.Position - origin).Magnitude
            if dist <= maxRadius then
                if not isGrouped(obj, allMatching, groupRadius) then
                    table.insert(out, { obj = obj, dist = dist })
                end
            end
        end
    end

    table.sort(out, function(a, b) return a.dist < b.dist end)

    local result = {}
    for _, entry in ipairs(out) do
        table.insert(result, entry.obj)
    end
    return result
end

-- Tab: Teleports

local Tab1 = Window:CreateTab("Teleports")

local ITEMS = {
    "Hammer", "sw", "Food", "GPS", "Lantern",
    "Money", "Bullets", "Medkit", "Soda", "Shells",
    "Crowbar", "Bat", "Shotgun", "Handgun",
}

local moneyToggle    = false
local moneyCancel    = false
local moneyDelay     = 0.5
local moneyToggleRef = nil

Tab1:CreateDropdown({
    Name = "Item Teleports",
    Options = ITEMS,
    Default = "Hammer",
    Flag = "SelectOption",
    Callback = function(option)
        if option == "Money" then
            local target = findItem("Money")
            if target then teleportTo(target) end
        else
            local target = findItem(option)
            if not target then
                Window:Notify({ Title = "Teleport", Content = ("No item named '%s'"):format(option), Type = "error" })
                return
            end
            teleportTo(target)
            Window:Notify({ Title = "Teleport", Content = ("Teleported to %s"):format(option), Type = "success" })
        end
    end,
})

Tab1:CreateSlider({
    Name = "Money Hop Delay (sec)",
    Min = 0.1, Max = 3, Default = 0.5, Flag = "MoneyDelay",
    Callback = function(value) moneyDelay = value end,
})

moneyToggleRef = Tab1:CreateToggle({
    Name = "Auto-Teleport to ALL Money",
    Default = false,
    Flag = "MoneyToggle",
    Callback = function(state)
        moneyToggle = state
        if state then
            moneyCancel = false
            Window:Notify({ Title = "Money Farm", Content = "Started", Type = "info" })
            task.spawn(function()
                local n = teleportToAll("Money", moneyDelay, function()
                    return moneyCancel or not moneyToggle
                end)
                moneyToggle = false
                if moneyToggleRef and moneyToggleRef.Set then
                    pcall(function() moneyToggleRef:Set(false) end)
                end
                Window:Notify({ Title = "Money Farm", Content = ("Visited %d Money pickups"):format(n), Type = "success" })
            end)
        else
            moneyCancel = true
            Window:Notify({ Title = "Money Farm", Content = "Stopped", Type = "warn" })
        end
    end,
})

-- Tab: Farms

local Tab2 = Window:CreateTab("Farms")

local GEF_OFFSET       = Vector3.new(5, 0, 0)
local GEF_LOCK_TIMEOUT = 12
local GEF_RADIUS       = 1000
local GEF_GROUP_RADIUS = 100

local farmToken     = 0
local farmToggleRef = nil

local savedCollision = {}

local function disableCollision()
    local char = player.Character
    if not char then return end

    savedCollision = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            savedCollision[part] = part.CanCollide
            part.CanCollide = false
        end
    end
end

local function restoreCollision()
    for part, state in pairs(savedCollision) do
        if part and part.Parent then
            part.CanCollide = state
        end
    end
    savedCollision = {}
end

local function farmGEFs(targetName, offset, myToken)
    offset = offset or GEF_OFFSET

    local function cancelled()
        return farmToken ~= myToken
    end

    local targets = collectGEFs(targetName, GEF_RADIUS, GEF_GROUP_RADIUS)
    if #targets == 0 then
        Window:Notify({ Title = "GEF Farm", Content = ("No isolated %s within %d studs"):format(targetName, GEF_RADIUS), Type = "warn" })
        return
    end

    disableCollision()

    local char, hrp = getChar()
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local savedWalk, savedJumpPower, savedJumpHeight
    if humanoid then
        savedWalk       = humanoid.WalkSpeed
        savedJumpPower  = humanoid.JumpPower
        savedJumpHeight = humanoid.JumpHeight
        humanoid.WalkSpeed  = 0
        humanoid.JumpPower  = 0
        humanoid.JumpHeight = 0
    end

    Window:Notify({ Title = "GEF Farm", Content = ("Farming %d isolated %s"):format(#targets, targetName), Type = "info" })
    print(("Farming %d isolated x %s within %d studs"):format(#targets, targetName, GEF_RADIUS))

    for i, gef in ipairs(targets) do
        if cancelled() then break end
        if not gef.Parent then continue end

        print(("  Locking onto %s (%d/%d)"):format(targetName, i, #targets))

        local lockStart     = os.clock()
        local hitRegistered = false
        local lastHp        = getHealthValue(gef)

        while gef.Parent and not cancelled() do
            local hp = getHealthValue(gef)

            if hp == nil or hp <= 0 then
                print(("  %s (%d/%d) down"):format(targetName, i, #targets))
                break
            end

            if lastHp and hp < lastHp then
                hitRegistered = true
            end
            lastHp = hp

            if not hitRegistered and os.clock() - lockStart > GEF_LOCK_TIMEOUT then
                print(("  %s (%d/%d) skipped (no damage)"):format(targetName, i, #targets))
                break
            end

            local _, root = getChar()
            if not root then
                task.wait(0.1)
                continue
            end

            local base = getBasePart(gef)
            if not base then break end

            local pos = base.Position + offset
            if pos ~= pos then break end

            root.CFrame = CFrame.lookAt(pos, base.Position)

            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end

            RunService.RenderStepped:Wait()
        end
    end

    restoreCollision()

    if humanoid and humanoid.Parent then
        humanoid.WalkSpeed  = savedWalk or 16
        humanoid.JumpPower  = savedJumpPower or 50
        humanoid.JumpHeight = savedJumpHeight or 7.2
    end

    if farmToken == myToken then
        Window:Notify({ Title = "GEF Farm", Content = "Finished", Type = "success" })
    end
    print(("Finished farming %s"):format(targetName))
end

local function startFarm(targetName)
    farmToken = farmToken + 1
    local myToken = farmToken

    task.spawn(function()
        farmGEFs(targetName, GEF_OFFSET, myToken)

        if farmToken == myToken then
            if farmToggleRef and farmToggleRef.Set then
                pcall(function() farmToggleRef:Set(false) end)
            end
        end
    end)
end

local function stopFarm()
    farmToken = farmToken + 1
    restoreCollision()

    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed  = 16
        humanoid.JumpPower  = 50
        humanoid.JumpHeight = 7.2
    end
end

farmToggleRef = Tab2:CreateToggle({
    Name = "Farm Mini GEF",
    Default = false,
    Flag = "GEFFarm",
    Callback = function(state)
        if state then
            Window:Notify({ Title = "GEF Farm", Content = "Started", Type = "info" })
            startFarm("Mini GEF")
        else
            stopFarm()
            Window:Notify({ Title = "GEF Farm", Content = "Stopped", Type = "warn" })
        end
    end,
})

-- Tab: Modifications

local Tab3 = Window:CreateTab("Modifications")

-- money
local MONEY_MIN = 0
local MONEY_MAX = 999999999999999999999999999

local function setMoney(value)
    local moneyObj = player:FindFirstChild("Money")
    if not moneyObj then
        Window:Notify({ Title = "Money", Content = "player.Money not found", Type = "error" })
        return false
    end

    if value < MONEY_MIN then value = MONEY_MIN end
    if value > MONEY_MAX then value = MONEY_MAX end

    moneyObj.Value = value
    return true
end

Tab3:CreateTextbox({
    Name = "Set Money",
    Default = tostring(MONEY_MIN),
    Placeholder = ("%d - %d"):format(MONEY_MIN, MONEY_MAX),
    Flag = "MoneyInput",
    Callback = function(text, enterPressed)
        if not enterPressed then return end

        local num = tonumber(text)
        if not num then
            Window:Notify({ Title = "Money", Content = "Invalid number", Type = "error" })
            return
        end

        num = math.floor(num)
        if setMoney(num) then
            Window:Notify({ Title = "Money", Content = ("Set to %d"):format(num), Type = "success" })
        end
    end,
})

-- upgrades

local function getUpgrades()
    return player:FindFirstChild("Upgrades")
end

local function setUpgrade(name, value)
    local upgrades = getUpgrades()
    if not upgrades then
        Window:Notify({ Title = "Upgrades", Content = "player.Upgrades not found", Type = "error" })
        return false
    end

    local obj = upgrades:FindFirstChild(name)
    if not obj then
        Window:Notify({ Title = "Upgrades", Content = ("Upgrades.%s not found"):format(name), Type = "error" })
        return false
    end

    obj.Value = value
    return true
end

-- MaxStamina
local MAXSTAMINA_MIN = 1
local MAXSTAMINA_MAX = 24334

Tab3:CreateTextbox({
    Name = "Max Stamina",
    Default = tostring(MAXSTAMINA_MIN),
    Placeholder = ("%d - %d"):format(MAXSTAMINA_MIN, MAXSTAMINA_MAX),
    Flag = "MaxStaminaInput",
    Callback = function(text, enterPressed)
        if not enterPressed then return end

        local num = tonumber(text)
        if not num then
            Window:Notify({ Title = "Max Stamina", Content = "Invalid number", Type = "error" })
            return
        end

        num = math.floor(num)
        if num < MAXSTAMINA_MIN then num = MAXSTAMINA_MIN end
        if num > MAXSTAMINA_MAX then num = MAXSTAMINA_MAX end

        if setUpgrade("MaxStamina", num) then
            Window:Notify({ Title = "Max Stamina", Content = ("Set to %d"):format(num), Type = "success" })
        end
    end,
})

-- StaminaRegen
local STAMINAREGEN_MIN = 0
local STAMINAREGEN_MAX = 24334

Tab3:CreateSlider({
    Name = "Stamina Regen",
    Min = STAMINAREGEN_MIN,
    Max = STAMINAREGEN_MAX,
    Default = 1,
    Flag = "StaminaRegenSlider",
    Callback = function(value)
        value = math.floor(value)
        setUpgrade("StaminaRegen", value)
    end,
})

-- Storage
local STORAGE_MIN = 4
local STORAGE_MAX = 10

Tab3:CreateTextbox({
    Name = "Storage",
    Default = tostring(STORAGE_MIN),
    Placeholder = ("%d - %d"):format(STORAGE_MIN, STORAGE_MAX),
    Flag = "StorageInput",
    Callback = function(text, enterPressed)
        if not enterPressed then return end

        local num = tonumber(text)
        if not num then
            Window:Notify({ Title = "Storage", Content = "Invalid number", Type = "error" })
            return
        end

        num = math.floor(num)
        if num < STORAGE_MIN then num = STORAGE_MIN end
        if num > STORAGE_MAX then num = STORAGE_MAX end

        if setUpgrade("Storage", num) then
            Window:Notify({ Title = "Storage", Content = ("Set to %d"):format(num), Type = "success" })
        end
    end,
})

-- Fake Death Screen section
local FakeDeathSection = Tab3:CreateSection("Fake Death Screen")

local GEFSKILLED_MIN = 0
local GEFSKILLED_MAX = 9999

local function setGefsKilled(value)
    local runData = player:FindFirstChild("RunData")
    if not runData then
        Window:Notify({ Title = "Gefs Killed", Content = "player.RunData not found", Type = "error" })
        return false
    end

    local stats = runData:FindFirstChild("Stats")
    if not stats then
        Window:Notify({ Title = "Gefs Killed", Content = "RunData.Stats not found", Type = "error" })
        return false
    end

    local killed = stats:FindFirstChild("GefsKilled")
    if not killed then
        Window:Notify({ Title = "Gefs Killed", Content = "Stats.GefsKilled not found", Type = "error" })
        return false
    end

    killed.Value = value
    return true
end

FakeDeathSection:CreateTextbox({
    Name = "Gefs Killed",
    Default = tostring(GEFSKILLED_MIN),
    Placeholder = ("%d - %d"):format(GEFSKILLED_MIN, GEFSKILLED_MAX),
    Flag = "GefsKilledInput",
    Callback = function(text, enterPressed)
        if not enterPressed then return end

        local num = tonumber(text)
        if not num then
            Window:Notify({ Title = "Gefs Killed", Content = "Invalid number", Type = "error" })
            return
        end

        num = math.floor(num)
        if num < GEFSKILLED_MIN then num = GEFSKILLED_MIN end
        if num > GEFSKILLED_MAX then num = GEFSKILLED_MAX end

        if setGefsKilled(num) then
            Window:Notify({ Title = "Gefs Killed", Content = ("Set to %d"):format(num), Type = "success" })
        end
    end,
})