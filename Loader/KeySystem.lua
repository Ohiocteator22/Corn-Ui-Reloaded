-- KeySystem.lua
-- Gate access to your hub behind a randomly generated, time-limited key,
-- validated against your own Cloudflare Worker (see worker.js). Caches
-- a valid key locally so users aren't re-prompted every session.

local HttpService = game:GetService("HttpService")

local KeySystem = {}

local VALIDATE_URL = "https://keysystem.chauhannityam-1512.workers.dev/validate?key="
local GET_KEY_URL  = "https://link-target.net/7571152/6d0D7vORtyHm" -- the Linkvertise link that leads to key.html
local SAVE_PATH    = "CornUi_Key.txt"

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
    Frame.Size = UDim2.new(0, 320, 0, 190)
    Frame.Position = UDim2.new(0.5, -160, 0.5, -95)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 27, 20)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.Text = "Enter Key"
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(237, 230, 211)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Parent = Frame

    local Input = Instance.new("TextBox")
    Input.PlaceholderText = "Paste your key..."
    Input.Size = UDim2.new(1, -30, 0, 36)
    Input.Position = UDim2.new(0, 15, 0, 55)
    Input.BackgroundColor3 = Color3.fromRGB(31, 34, 26)
    Input.TextColor3 = Color3.fromRGB(237, 230, 211)
    Input.ClearTextOnFocus = false
    Input.Parent = Frame

    local Submit = Instance.new("TextButton")
    Submit.Text = "Submit"
    Submit.Size = UDim2.new(1, -30, 0, 36)
    Submit.Position = UDim2.new(0, 15, 0, 100)
    Submit.BackgroundColor3 = Color3.fromRGB(244, 196, 48)
    Submit.TextColor3 = Color3.fromRGB(26, 23, 6)
    Submit.Font = Enum.Font.GothamBold
    Submit.Parent = Frame

    local GetKey = Instance.new("TextButton")
    GetKey.Text = "Get Key"
    GetKey.Size = UDim2.new(1, -30, 0, 28)
    GetKey.Position = UDim2.new(0, 15, 0, 148)
    GetKey.BackgroundTransparency = 1
    GetKey.TextColor3 = Color3.fromRGB(163, 172, 116)
    GetKey.Parent = Frame

    GetKey.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(GET_KEY_URL)
            Title.Text = "Link copied!"
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
