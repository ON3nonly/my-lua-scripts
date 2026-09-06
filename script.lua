--[[
	Egg Thief v1.0 - Unified Module for Delta Environment
	Author: NoTrack
	Date: 2026-09-06
	Description: Monitors egg spawns, prioritizes by rarity, tweens to collect, returns to base, and displays live status.
]]

local EggThief = {}

-- --- CONFIGURATION ---
EggThief.Config = {
    HomeCoordinate = Vector3.new(0, 10, 0), -- Base coordinate to return to
    MoveSpeed = 20.0, -- Speed of tweening (studs/sec)
    Cooldown = 5.0, -- Seconds between attempts
    Keybind = Enum.KeyCode.T, -- Toggle UI keybind
    RarityTiers = {
        ["Secret"] = 1,
        ["Eternal"] = 2,
        ["Divine"] = 3,
        ["Common"] = 4
    }
}

-- --- MODULE 1: EGG SCANNER ---
local EggScanner = {}
EggScanner.log = {}

function EggScanner:ScanForEggs()
    local eggs = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = tostring(obj.Name)
            for tier, priority in pairs(EggThief.Config.RarityTiers) do
                if string.find(string.upper(name), tier) then
                    table.insert(eggs, {
                        object = obj,
                        name = name,
                        tier = tier,
                        priority = priority,
                        position = obj:GetPrimaryPartCFrame().Position
                    })
                end
            end
        end
    end
    -- Sort by priority (lowest number = highest priority)
    table.sort(eggs, function(a, b) return a.priority < b.priority end)
    return eggs
end

function EggScanner:LogSpawn(egg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = {
        timestamp = timestamp,
        objectName = egg.name,
        rarity = egg.tier,
        entityID = egg.object,
        coordinates = egg.position
    }
    table.insert(self.log, logEntry)
    print("[SCANNER] New " .. egg.tier .. " Egg: " .. egg.name)
    return logEntry
end

-- --- MODULE 2: TWEEN PATHFINDER ---
local TweenPathfinder = {}

function TweenPathfinder:SetHomeCoordinate(coord)
    EggThief.Config.HomeCoordinate = coord
end

function TweenPathfinder:TweenToTarget(targetEntity)
    local player = game.Players.LocalPlayer
    if not player then return false end
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end

    local startPos = character:GetPrimaryPartCFrame().Position
    local endPos = targetEntity.position

    -- Obstacle Check via Raycast
    local direction = (endPos - startPos).Unit * (endPos - startPos).Magnitude
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    local result = workspace:Raycast(startPos, direction, rayParams)
    if result then
        print("[PATHFINDER] Obstacle detected. Skipping target.")
        return false
    end

    -- Tween to target
    local tweenInfo = TweenInfo.new((endPos - startPos).Magnitude / EggThief.Config.MoveSpeed, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(character, tweenInfo, {Position = endPos})
    tween:Play()
    tween.Completed:Wait()

    -- Return to home after success
    self:TweenToHome()
    return true
end

function TweenPathfinder:TweenToHome()
    local player = game.Players.LocalPlayer
    if not player then return false end
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end

    local startPos = character:GetPrimaryPartCFrame().Position
    local endPos = EggThief.Config.HomeCoordinate

    local tweenInfo = TweenInfo.new((endPos - startPos).Magnitude / EggThief.Config.MoveSpeed, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(character, tweenInfo, {Position = endPos})
    tween:Play()
    tween.Completed:Wait()
    return true
end

-- --- MODULE 3: PRIORITY STEALER ---
local PriorityStealer = {}
PriorityStealer.lastAttemptTime = 0
PriorityStealer.lockedTarget = nil

function PriorityStealer:StartStealLoop()
    while true do
        if os.time() - self.lastAttemptTime >= EggThief.Config.Cooldown then
            local eggs = EggScanner:ScanForEggs()
            if #eggs > 0 then
                local target = eggs[1] -- Highest priority
                self.lockedTarget = target
                print("[STEALER] Targeting: " .. target.name .. " [" .. target.tier .. "]")
                local success = TweenPathfinder:TweenToTarget(target)
                if success then
                    print("[STEALER] Success! Collected: " .. target.name)
                    EggThief.stats.totalSteals += 1
                    EggThief.stats[target.tier .. "Count"] += 1
                else
                    print("[STEALER] Failed to collect: " .. target.name)
                end
            end
        end
        wait(1.0) -- Check every second
    end
end

-- --- MODULE 4: UI OVERLAY ---
local UIOverlay = {}
UIOverlay.visible = true

function UIOverlay:CreatePanel()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggThiefUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    -- Labels
    local label = Instance.new("TextLabel")
    label.Name = "StatusLabel"
    label.Text = "Egg Thief v1.0"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 18
    label.Position = UDim2.new(0, 10, 0, 10)
    label.Size = UDim2.new(0, 200, 0, 30)
    label.Parent = screenGui

    local feedLabel = Instance.new("TextLabel")
    feedLabel.Name = "ScanFeed"
    feedLabel.Text = "Scanning..."
    feedLabel.TextColor3 = Color3.new(0, 1, 1)
    feedLabel.TextSize = 14
    feedLabel.Position = UDim2.new(0, 10, 0, 50)
    feedLabel.Size = UDim2.new(0, 200, 0, 150)
    feedLabel.Parent = screenGui

    local targetLabel = Instance.new("TextLabel")
    targetLabel.Name = "TargetLabel"
    targetLabel.Text = "Target: None"
    targetLabel.TextColor3 = Color3.new(1, 0.5, 0)
    targetLabel.TextSize = 14
    targetLabel.Position = UDim2.new(0, 10, 0, 210)
    targetLabel.Size = UDim2.new(0, 200, 0, 30)
    targetLabel.Parent = screenGui

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "StatsLabel"
    statsLabel.Text = "Stats: 0 Steals"
    statsLabel.TextColor3 = Color3.new(0.5, 1, 0.5)
    statsLabel.TextSize = 12
    statsLabel.Position = UDim2.new(0, 10, 0, 250)
    statsLabel.Size = UDim2.new(0, 200, 0, 50)
    statsLabel.Parent = screenGui

    -- Keybind Listener
    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.KeyCode == EggThief.Config.Keybind then
            UIOverlay.visible = not UIOverlay.visible
            screenGui.Visible = UIOverlay.visible
        end
    end)

    -- Update Loop
    spawn(function()
        while true do
            if UIOverlay.visible then
                -- Update Feed
                local eggs = EggScanner:ScanForEggs()
                local feedText = "Latest Spawns:\n"
                for i = 1, math.min(5, #eggs) do
                    feedText = feedText .. "[" .. eggs[i].tier .. "] " .. eggs[i].name .. "\n"
                end
                feedLabel.Text = feedText

                -- Update Target
                if PriorityStealer.lockedTarget then
                    targetLabel.Text = "Target: " .. PriorityStealer.lockedTarget.name
                else
                    targetLabel.Text = "Target: None"
                end

                -- Update Stats
                statsLabel.Text = string.format("Steals: %d | S:%d E:%d D:%d | Runtime: %ds", 
                    EggThief.stats.totalSteals, 
                    EggThief.stats.secretCount, 
                    EggThief.stats.eternalCount, 
                    EggThief.stats.divineCount, 
                    os.time() - EggThief.stats.startTime)
            end
            wait(1.0)
        end
    end)
end

-- --- INITIALIZATION ---
EggThief.stats = {
    totalSteals = 0,
    secretCount = 0,
    eternalCount = 0,
    divineCount = 0,
    startTime = os.time()
}

function EggThief:Initialize()
    TweenPathfinder:SetHomeCoordinate(EggThief.Config.HomeCoordinate)
    UIOverlay:CreatePanel()
    spawn(function()
        PriorityStealer:StartStealLoop()
    end)
    print("[EGG THIEF] Initialized. Press " .. EggThief.Config.Keybind.Name .. " to toggle UI.")
end

-- Run Initialization
EggThief:Initialize()
