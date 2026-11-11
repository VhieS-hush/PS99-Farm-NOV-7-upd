-- VhieS SC | Pet Simulator 99 Auto Farm
-- Updated for Update 101 (Masquerade Games) - Nov 7, 2026
-- Key System + String Encoding enabled

-- =====================
-- STRING DECODE UTILITY
-- =====================
local function d(t)
    local r = {}
    for _, v in ipairs(t) do
        r[#r+1] = string.char(v)
    end
    return table.concat(r)
end

-- Encoded strings
local S = {
    title     = d({86,104,105,101,83,32,83,67}),                          -- "VhieS SC"
    subtitle  = d({80,101,116,32,83,105,109,117,108,97,116,111,114,32,57,57,32,124,32,85,112,100,97,116,101,32,49,48,49}), -- "Pet Simulator 99 | Update 101"
    guard     = d({86,104,105,101,83,95,80,83,57,57}),                    -- "VhieS_PS99"
    keyguard  = d({86,104,105,101,83,95,75,101,121}),                     -- "VhieS_Key"
    waveurl   = d({104,116,116,112,115,58,47,47,99,100,110,46,112,114,111,106,101,99,116,45,114,101,118,101,114,115,101,46,111,114,103,47,119,97,118,101,45,117,105,46,108,117,97,117}), -- wave-ui url
    invalid   = d({91,86,104,105,101,83,32,83,67,93,32,73,110,118,97,108,105,100,32,107,101,121,46,32,71,101,116,32,97,32,107,101,121,32,102,114,111,109,32,116,104,101,32,86,104,105,101,83,32,83,67,32,68,105,115,99,111,114,100,46}), -- "[VhieS SC] Invalid key. Get a key from the VhieS SC Discord."
    nokey     = d({91,86,104,105,101,83,32,83,67,93,32,78,111,32,107,101,121,32,102,111,117,110,100,46,32,83,101,116,32,103,101,116,103,101,110,118,40,41,46,86,104,105,101,83,95,75,101,121,32,98,101,102,111,114,101,32,114,117,110,110,105,110,103,46}), -- no key message
    loaded    = d({91,86,104,105,101,83,32,83,67,93,32,80,83,57,57,32,72,117,98,32,108,111,97,100,101,100,32,226,128,148,32,85,112,100,97,116,101,32,49,48,49}), -- loaded message
    wavefail  = d({91,86,104,105,101,83,32,83,67,93,32,119,97,118,101,45,117,105,32,102,97,105,108,101,100,32,116,111,32,108,111,97,100}), -- wave-ui failed
}

-- =====================
-- ONLINE KEY SYSTEM
-- =====================
-- https://pastebin.com/zV33EvV3 (replace after you create it)
-- Format of your Pastebin content:
--   VHIES-PS99-ALPHA-0001|2026-12-30
--   VHIES-PS99-ALPHA-0002|2026-11-30
--   VHIES-PS99-BETA-0001|2026-12-15
-- Each line: KEY|YYYY-MM-DD (expiry date)

local KEY_URL = "https://pastebin.com/zV33EvV3" -- <-- replace with your Pastebin raw URL

local genv = getgenv and getgenv() or _G

if genv[S.guard] then return end
genv[S.guard] = true

local userKey = genv[S.keyguard]

if type(userKey) ~= "string" then
    warn(S.nokey)
    genv[S.guard] = nil
    return
end

-- Fetch key list from Pastebin
local keyData = nil
local fetchOk, fetchErr = pcall(function()
    keyData = game:HttpGet(KEY_URL, true)
end)

if not fetchOk or type(keyData) ~= "string" or #keyData < 5 then
    warn("[VhieS SC] Could not reach key server. Check your connection.")
    genv[S.guard] = nil
    return
end

-- Parse keys and expiry dates
local VALID_KEYS = {}
for line in keyData:gmatch("[^\n]+") do
    line = line:gsub("%s+", "") -- trim whitespace
    local key, expiry = line:match("^([^|]+)|(%d%d%d%d%-%d%d%-%d%d)$")
    if key and expiry then
        VALID_KEYS[key] = expiry
    end
end

-- Check if key exists
local expiry = VALID_KEYS[userKey]
if not expiry then
    warn(S.invalid)
    genv[S.guard] = nil
    return
end

-- Check expiry date
local function parseDate(dateStr)
    local y, m, d2 = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
    if not y then return nil end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d2), hour = 23, min = 59, sec = 59 })
end

local expiryTime = parseDate(expiry)
if expiryTime and os.time() > expiryTime then
    warn("[VhieS SC] Your key has expired. Get a new key from the VhieS SC Discord.")
    genv[S.guard] = nil
    return
end

-- Key valid — show days remaining
local daysLeft = expiryTime and math.ceil((expiryTime - os.time()) / 86400) or 999
warn("[VhieS SC] Key valid! " .. daysLeft .. " day(s) remaining — " .. userKey)

-- =====================
-- MAIN SCRIPT
-- =====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Load wave-ui
local waveUI
local ok, err = pcall(function()
    waveUI = loadstring(game:HttpGet(S.waveurl))()
end)
if not ok then
    warn(S.wavefail .. ": " .. tostring(err))
    genv[S.guard] = nil
    return
end

-- =====================
-- CONFIG
-- =====================
local Config = {
    AutoBreak = false,
    AutoCollect = true,
    AutoRebirth = false,
    AutoCombine = false,
    CombineTarget = "Huge",
    AutoMasqueradeGames = false,
    AntiAFK = true,
    TeleportToBreakables = true,
    FarmArea = "Witch Village",
    BreakDelay = 0.05,
    CollectRadius = 50,
}

-- =====================
-- HELPERS
-- =====================
local function getRemote(name)
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        or game:GetService("ReplicatedStorage"):FindFirstChild("RE")
    if remotes then return remotes:FindFirstChild(name) end
    return nil
end

local function teleportTo(pos)
    if HumanoidRootPart then
        HumanoidRootPart.CFrame = CFrame.new(pos)
    end
end

-- =====================
-- AUTO BREAK
-- =====================
local function getBreakables()
    local results = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (
            obj.Name:find("Breakable") or obj.Name:find("Coin") or
            obj.Name:find("Gem") or obj.Name:find("Chest") or obj.Name:find("Egg")
        ) then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primary then results[#results+1] = { model = obj, part = primary } end
        end
    end
    return results
end

local function farmBreakables()
    local breakRemote = getRemote("BreakObject") or getRemote("BreakBubble") or getRemote("BreakObstacle")
    local collectRemote = getRemote("CollectCoins") or getRemote("CollectDrop")
    for _, item in ipairs(getBreakables()) do
        if not Config.AutoBreak then break end
        if item.part and item.part.Parent then
            if Config.TeleportToBreakables then
                teleportTo(item.part.Position + Vector3.new(0, 3, 0))
            end
            if breakRemote then
                pcall(function() breakRemote:FireServer(item.model) end)
            else
                pcall(function()
                    local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if HRP then HRP.CFrame = CFrame.new(item.part.Position + Vector3.new(0, 2, 0)) end
                end)
            end
            task.wait(Config.BreakDelay)
        end
    end
    if Config.AutoCollect then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "Drop" or obj.Name == "Coin" or obj.Name == "Gem") then
                if collectRemote then
                    pcall(function() collectRemote:FireServer(obj) end)
                else
                    local dist = (HumanoidRootPart.Position - obj.Position).Magnitude
                    if dist <= Config.CollectRadius then teleportTo(obj.Position) end
                end
            end
        end
    end
end

-- =====================
-- COMBINE-O-MATIC
-- =====================
local function autoCombine()
    local r = getRemote("CombinePets") or getRemote("CombineOMatic")
    if not r then return end
    pcall(function() r:FireServer({ target = Config.CombineTarget }) end)
end

-- =====================
-- MASQUERADE GAMES
-- =====================
local function joinMasqueradeGame()
    local r = getRemote("JoinMasquerade") or getRemote("JoinMinigame")
    if not r then return end
    pcall(function() r:FireServer() end)
end

-- =====================
-- AUTO REBIRTH
-- =====================
local function autoRebirth()
    local r = getRemote("Rebirth") or getRemote("DoRebirth")
    if not r then return end
    pcall(function() r:FireServer() end)
end

-- =====================
-- ANTI-AFK
-- =====================
local function startAntiAFK()
    task.spawn(function()
        while Config.AntiAFK do
            pcall(function()
                local VU = game:GetService("VirtualUser")
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end)
            task.wait(60)
        end
    end)
end

-- =====================
-- FARM LOOP
-- =====================
local farmActive = false
local function startFarm()
    if farmActive then return end
    farmActive = true
    task.spawn(function()
        while farmActive do
            pcall(function()
                if Config.AutoBreak then farmBreakables() end
                if Config.AutoCombine then autoCombine() end
                if Config.AutoMasqueradeGames then joinMasqueradeGame() end
                if Config.AutoRebirth then autoRebirth() end
            end)
            task.wait(0.1)
        end
    end)
end
local function stopFarm()
    farmActive = false
end

-- =====================
-- UI
-- =====================
local Window = waveUI:CreateWindow({
    Title = S.title,
    SubTitle = S.subtitle,
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
})

-- Overview
local OTab = Window:AddTab({ Title = "Overview", Icon = "rbxassetid://7733715400" })
local OSec = OTab:AddSection("VhieS SC — Pet Simulator 99")
OSec:AddParagraph({ Title = "Update 101 — Masquerade Games", Content = "Nov 7, 2026 · Witch Village, Masquerade Ball, Thorn Spire · Combine-o-Matic · 8 New Pets" })
OSec:AddParagraph({ Title = "Key", Content = "✓ Valid — " .. userKey .. " · " .. daysLeft .. " day(s) left · Expires " .. expiry })

-- Auto Farm
local FTab = Window:AddTab({ Title = "Auto Farm", Icon = "rbxassetid://7733715400" })
local FSec = FTab:AddSection("Breakable Farm")
FSec:AddToggle("AutoBreak", { Title = "Auto Break", Default = false, Callback = function(v)
    Config.AutoBreak = v
    if v then startFarm() else stopFarm() end
end })
FSec:AddToggle("AutoCollect", { Title = "Auto Collect Drops", Default = true, Callback = function(v) Config.AutoCollect = v end })
FSec:AddToggle("TeleportToBreakables", { Title = "Teleport to Breakables", Default = true, Callback = function(v) Config.TeleportToBreakables = v end })
FSec:AddSlider("BreakDelay", { Title = "Break Delay (s)", Default = 0.05, Min = 0.01, Max = 1, Rounding = 2, Callback = function(v) Config.BreakDelay = v end })

local ASec = FTab:AddSection("Area — Update 101")
ASec:AddDropdown("FarmArea", {
    Title = "Farm Area",
    Values = { "Witch Village", "Masquerade Ball", "Thorn Spire", "Manor Entrance", "Spawn" },
    Default = "Witch Village",
    Callback = function(v)
        Config.FarmArea = v
        pcall(function()
            for _, area in ipairs(workspace:GetDescendants()) do
                if area.Name == v then
                    local part = area:FindFirstChildWhichIsA("BasePart")
                    if part then teleportTo(part.Position + Vector3.new(0, 5, 0)) end
                    break
                end
            end
        end)
    end
})

-- Combine-o-Matic
local CTab = Window:AddTab({ Title = "Combine-o-Matic", Icon = "rbxassetid://7733715400" })
local CSec = CTab:AddSection("Combine-o-Matic — Update 101")
CSec:AddParagraph({ Title = "About", Content = "Combine pets into Huge → Titanic → Gargantuan. Chance for Golden, Rainbow, or Shiny." })
CSec:AddToggle("AutoCombine", { Title = "Auto Combine", Default = false, Callback = function(v) Config.AutoCombine = v end })
CSec:AddDropdown("CombineTarget", { Title = "Target", Values = { "Huge", "Titanic", "Gargantuan" }, Default = "Huge", Callback = function(v) Config.CombineTarget = v end })
CSec:AddButton({ Title = "Combine Now", Callback = function() autoCombine() end })

-- Masquerade
local MTab = Window:AddTab({ Title = "Masquerade", Icon = "rbxassetid://7733715400" })
local MSec = MTab:AddSection("Masquerade Games — Update 101")
MSec:AddParagraph({ Title = "Minigames", Content = "Broom Sweep · Bumper Pumpkins · Hide from Gloomkin · Earn Treats, Midnight Gifts, Spirit Shards" })
MSec:AddToggle("AutoMasquerade", { Title = "Auto Join Games", Default = false, Callback = function(v) Config.AutoMasqueradeGames = v end })
MSec:AddButton({ Title = "Join Now", Callback = function() joinMasqueradeGame() end })

-- Misc
local XTab = Window:AddTab({ Title = "Misc", Icon = "rbxassetid://7733715400" })
local XSec = XTab:AddSection("Miscellaneous")
XSec:AddToggle("AutoRebirth", { Title = "Auto Rebirth", Default = false, Callback = function(v) Config.AutoRebirth = v end })
XSec:AddToggle("AntiAFK", { Title = "Anti-AFK", Default = true, Callback = function(v)
    Config.AntiAFK = v
    if v then startAntiAFK() end
end })
XSec:AddButton({ Title = "Rejoin Server", Callback = function()
    pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
end })

startAntiAFK()
warn(S.loaded)
