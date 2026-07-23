-- KeySystem.lua
-- Gate access to your hub behind a randomly generated, tiered, time-limited
-- key, validated against your own Cloudflare Worker (see worker.js). Caches
-- a valid key locally so users aren't re-prompted every session.

local HttpService = game:GetService("HttpService")

local KeySystem = {}

local VALIDATE_URL = "https://keysystem.chauhannityam-1512.workers.dev/validate?key="
local SAVE_PATH = "CornUi_Key.txt"

-- Each tier needs its own Linkvertise/LootLabs link, set to require the
-- matching number of checkpoints, both pointing at key.html?tier=<id>.
local TIERS = {
    { id = "1day", label = "1 Day  (1 checkpoint)",  Linkvertise = "https://link-center.net/7571152/xMThd1NH3TJz", LootLabs = "https://loot-link.com/s?CbWWsAC4" },
    { id = "3day", label = "3 Days (3 checkpoints)", Linkvertise = "https://direct-link.net/7571152/TdvvLouv7T2W", LootLabs = "https://loot-link.com/s?QUlCKmPG" },
    { id = "7day", label = "7 Days (5 checkpoints)", Linkvertise = "https://link-hub.net/7571152/hYMDRpzZlS9I", LootLabs = "https://lootdest.org/s?J5g6qRM6" },
}

local function isKeyValid(key)
    if not key or key == "" then return false end
    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(VALIDATE_URL .. key))
    end)
    return ok and result and result.valid == true
end

local function hasCachedKey()
    if not (isfile and readfile) then return false end
    if isfile(SAVE_PATH) then
        local saved = readfile(SAVE_PATH)
        if isKeyValid(saved) then
            return true
        end
    end
    return false
end

-- KeySystem.Prompt(onSuccess) — shows the UI (or skips it if a valid
-- cached key exists), then calls onSuccess() once a valid key is entered.
function KeySystem.Prompt(onSuccess)
    if hasCachedKey() then
        onSuccess()
        return
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "CornKeySystem"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 320, 0, 258)
    Frame.Position = UDim2.new(0.5, -160, 0.5, -129)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 27, 20)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.Text = "Enter Key"
    Title.Size = UDim2.new(1, 0, 0, 36)
    Title.Position = UDim2.new(0, 0, 0, 8)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(237, 230, 211)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Parent = Frame

    local Input = Instance.new("TextBox")
    Input.PlaceholderText = "Paste your key..."
    Input.Size = UDim2.new(1, -30, 0, 36)
    Input.Position = UDim2.new(0, 15, 0, 48)
    Input.BackgroundColor3 = Color3.fromRGB(31, 34, 26)
    Input.TextColor3 = Color3.fromRGB(237, 230, 211)
    Input.ClearTextOnFocus = false
    Input.Parent = Frame

    local Submit = Instance.new("TextButton")
    Submit.Text = "Submit"
    Submit.Size = UDim2.new(1, -30, 0, 36)
    Submit.Position = UDim2.new(0, 15, 0, 93)
    Submit.BackgroundColor3 = Color3.fromRGB(244, 196, 48)
    Submit.TextColor3 = Color3.fromRGB(26, 23, 6)
    Submit.Font = Enum.Font.GothamBold
    Submit.Parent = Frame

    -- Tier selector — tap to cycle between 1/3/7 day options
    local selectedIndex = 1

    local TierButton = Instance.new("TextButton")
    TierButton.Text = "Tier: " .. TIERS[selectedIndex].label .. "  ⟳"
    TierButton.Size = UDim2.new(1, -30, 0, 30)
    TierButton.Position = UDim2.new(0, 15, 0, 138)
    TierButton.BackgroundColor3 = Color3.fromRGB(31, 34, 26)
    TierButton.TextColor3 = Color3.fromRGB(237, 230, 211)
    TierButton.Font = Enum.Font.Code
    TierButton.TextSize = 13
    TierButton.Parent = Frame

    TierButton.MouseButton1Click:Connect(function()
        selectedIndex = (selectedIndex % #TIERS) + 1
        TierButton.Text = "Tier: " .. TIERS[selectedIndex].label .. "  ⟳"
    end)

    local GetLinkvertise = Instance.new("TextButton")
    GetLinkvertise.Text = "Linkvertise"
    GetLinkvertise.Size = UDim2.new(0.5, -18, 0, 28)
    GetLinkvertise.Position = UDim2.new(0, 15, 0, 178)
    GetLinkvertise.BackgroundTransparency = 1
    GetLinkvertise.TextColor3 = Color3.fromRGB(163, 172, 116)
    GetLinkvertise.Parent = Frame

    local GetLootLabs = Instance.new("TextButton")
    GetLootLabs.Text = "LootLabs"
    GetLootLabs.Size = UDim2.new(0.5, -18, 0, 28)
    GetLootLabs.Position = UDim2.new(0.5, 3, 0, 178)
    GetLootLabs.BackgroundTransparency = 1
    GetLootLabs.TextColor3 = Color3.fromRGB(163, 172, 116)
    GetLootLabs.Parent = Frame

    local Hint = Instance.new("TextLabel")
    Hint.Text = "Pick a tier above, then get a key through either link. Hitting Linkvertise's wait? Try LootLabs."
    Hint.Size = UDim2.new(1, -30, 0, 40)
    Hint.Position = UDim2.new(0, 15, 0, 208)
    Hint.BackgroundTransparency = 1
    Hint.TextColor3 = Color3.fromRGB(139, 138, 120)
    Hint.TextSize = 11
    Hint.TextWrapped = true
    Hint.Parent = Frame

    GetLinkvertise.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(TIERS[selectedIndex].Linkvertise)
            Title.Text = TIERS[selectedIndex].label .. " link copied!"
        end
    end)

    GetLootLabs.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(TIERS[selectedIndex].LootLabs)
            Title.Text = TIERS[selectedIndex].label .. " link copied!"
        end
    end)

    Submit.MouseButton1Click:Connect(function()
        local key = Input.Text
        if isKeyValid(key) then
            if writefile then
                writefile(SAVE_PATH, key)
            end
            ScreenGui:Destroy()
            onSuccess()
        else
            Title.Text = "Invalid key"
            Title.TextColor3 = Color3.fromRGB(255, 90, 90)
        end
    end)
end

return KeySystem
