-- ============================================================================
-- EGG THIEF DELTA - UNIFIED SCRIPT
-- Features: Rarity Scanner, Auto-Tween, Priority Steal, UI with Selector
-- Keybind: T (Toggle UI)
-- ============================================================================

local GameService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- --------------------------------------------------------------------------
-- CONFIGURATION
-- --------------------------------------------------------------------------
local Config = {
    HomeCoordinate = Vector3.new(0, 10, 0), -- Change this to your safe zone/home
    TweenSpeed = 25, -- Higher is faster
    Cooldown = 2, -- Seconds between attempts if target not found
    ToggleKey = Enum.KeyCode.T,
    DefaultRarity = "Secret"
}

-- --------------------------------------------------------------------------
-- MODULE 1: EGG SCANNER
-- --------------------------------------------------------------------------
local EggScanner = {
    log = {},
    rarityTiers = {
        ["Secret"] = 1,
        ["Eternal"] = 2,
        ["Divine"] = 3,
        ["Legendary"] = 4,
        ["Rare"] = 5,
        ["Uncommon"] = 6,
        ["Common"] = 7
    },
    selectedRarity = Config.DefaultRarity,
    startTime = os.time()
}

-- Session Stats
local Stats = {
    totalSteals = 0,
    secretCount = 0,
    eternalCount = 0,
    divineCount = 0,
    otherCount = 0
}

function EggScanner:SetTargetRarity(rarity)
    if self.rarityTiers[rarity] then
        self.selectedRarity = rarity
        print("[SCANNER] Target Rarity set to: " .. rarity)
        return true
    end
    return false
end

function EggScanner:IdentifyRarity(objectName)
    local name = string.upper(objectName)
    if string.find(name, "SECRET") then return "Secret" end
    if string.find(name, "ETERNAL") then return "Eternal" end
    if string.find(name, "DIVINE") then return "Divine" end
    if string.find(name, "LEGENDARY") then return "Legendary" end
    if string.find(name, "RARE") then return "Rare" end
    if string.find(name, "UNCOMMON") then return "Uncommon" end
    return "Common"
end

function EggScanner:ScanForNewEggs()
    local newEggs = {}
    local targetTier = self.rarityTiers[self.selectedRarity] or 7

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = tostring(obj.Name)
            local rarity = self:IdentifyRarity(name)
            local objectTier = self.rarityTiers[rarity] or 7

            -- Only process if it meets or exceeds our target rarity
            if objectTier <= targetTier then
                -- Check if already logged
                local isKnown = false
                for _, logEntry in ipairs(self.log) do
                    if logEntry.objectID == obj:GetUniqueId() then
                        isKnown = true
                        break
                    end
                end

                if not isKnown then
                    local logEntry = {
                        objectName = name,
                        rarity = rarity,
                        objectID = obj:GetUniqueId(),
                        object = obj,
                        position = obj.Position
                    }
                    table.insert(self.log, logEntry)
                    table.insert(newEggs, logEntry)
                    print("[SCANNER] New Egg: " .. name .. " [" .. rarity .. "]")
                end
            end
        end
    end
    return newEggs
end

function EggScanner:GetHighestRarityEgg()
    if #self.log == 0 then return nil end

    -- Sort by rarity (lower number = higher priority)
    table.sort(self.log, function(a, b)
        return self.rarityTiers[a.rarity] < self.rarityTiers[b.rarity]
    end)

    return self.log[1]
end

function EggScanner:RemoveEggFromLog(objectID)
    for i, entry in ipairs(self.log) do
        if entry.objectID == objectID then
            table.remove(self.log, i)
            break
        end
    end
end

-- --------------------------------------------------------------------------
-- MODULE 2: TWEEN PATHFINDER
-- --------------------------------------------------------------------------
local TweenPathfinder = {
    currentSpeed = Config.TweenSpeed
}

function TweenPathfinder:GetCharacter()
    local player = GameService.LocalPlayer
    if player and player.Character then
        return player.Character
    end
    return nil
end

function TweenPathfinder:TweenToTarget(targetEntity)
    local character = self:GetCharacter()
    if not character or not targetEntity then return false end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if not rootPart then return false end

    local startPos = rootPart.Position
    local endPos = targetEntity.Position + Vector3.new(0, 2, 0) -- Offset to pick up item

    -- Basic Obstacle Check
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local direction = (endPos - startPos).Unit * (endPos - startPos).Magnitude
    local raycastResult = Workspace:Raycast(startPos, direction, raycastParams)

    if raycastResult and raycastResult.Instance ~= targetEntity then
        print("[PATHFINDER] Path blocked by: " .. tostring(raycastResult.Instance.Name))
        return false
    end

    local duration = startPos:Distance(endPos) / self.currentSpeed
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(rootPart, tweenInfo, {Position = endPos})
    
    tween:Play()
    tween.Completed:Wait()
    
    -- Return to home after successful retrieval
    self:TweenToHome()
    return true
end

function TweenPathfinder:TweenToHome()
    local character = self:GetCharacter()
    if not character then return false end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if not rootPart then return false end

    local startPos = rootPart.Position
    local endPos = Config.HomeCoordinate
    local duration = startPos:Distance(endPos) / self.currentSpeed

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(rootPart, tweenInfo, {Position = endPos})
    tween:Play()
    tween.Completed:Wait()
    return true
end

-- --------------------------------------------------------------------------
-- MODULE 3: PRIORITY STEALER
-- --------------------------------------------------------------------------
local PriorityStealer = {}

function PriorityStealer:StartLoop()
    print("[STEALER] Loop started.")
    while true do
        local bestEgg = EggScanner:GetHighestRarityEgg()
        
        if bestEgg then
            print("[STEALER] Targeting: " .. bestEgg.objectName .. " [" .. bestEgg.rarity .. "]")
            local success = TweenPathfinder:TweenToTarget(bestEgg.object)
            
            if success then
                -- Log Stats
                Stats.totalSteals = Stats.totalSteals + 1
                if bestEgg.rarity == "Secret" then Stats.secretCount = Stats.secretCount + 1
                elseif bestEgg.rarity == "Eternal" then Stats.eternalCount = Stats.eternalCount + 1
                elseif bestEgg.rarity == "Divine" then Stats.divineCount = Stats.divineCount + 1
                else Stats.otherCount = Stats.otherCount + 1
                end
                
                print("[STEALER] Successfully stole: " .. bestEgg.objectName)
                EggScanner:RemoveEggFromLog(bestEgg.objectID)
            else
                print("[STEALER] Failed to reach target: " .. bestEgg.objectName)
            end
        else
            task.wait(1) -- Wait if no eggs found
        end
        
        task.wait(Config.Cooldown)
    end
end

-- --------------------------------------------------------------------------
-- MODULE 4: UI OVERLAY
-- --------------------------------------------------------------------------
local UIOverlay = {
    visible = true
}

function UIOverlay:CreatePanel()
    local player = GameService.LocalPlayer
    if not player then return end
    
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Main Container
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggThiefUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 250, 0, 480)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.Text = "Egg Thief v2.0"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    -- Target Label
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Name = "TargetLabel"
    targetLabel.Size = UDim2.new(1, -10, 0, 25)
    targetLabel.Position = UDim2.new(0, 5, 0, 35)
    targetLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    targetLabel.Text = "Target: Secret"
    targetLabel.TextColor3 = Color3.new(1, 0.8, 0) -- Orange
    targetLabel.TextSize = 14
    targetLabel.Font = Enum.Font.GothamBold
    targetLabel.Parent = frame
    
    -- Rarity Buttons Container
    local buttonContainer = Instance.new("ScrollingFrame")
    buttonContainer.Name = "RarityButtons"
    buttonContainer.Size = UDim2.new(1, -10, 0, 220)
    buttonContainer.Position = UDim2.new(0, 5, 0, 65)
    buttonContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    buttonContainer.BorderSizePixel = 0
    buttonContainer.ScrollBarThickness = 5
    buttonContainer.Parent = frame
    
    local listLayout = Instance.new("UIGridLayout")
    listLayout.Name = "ListLayout"
    listLayout.CellSize = UDim2.new(0, 110, 0, 30)
    listLayout.Padding = UDim2.new(0, 0, 0, 5)
    listLayout.Parent = buttonContainer
    
    -- Create Buttons
    local rarities = {"Secret", "Eternal", "Divine", "Legendary", "Rare", "Uncommon", "Common"}
    
    for _, rarity in ipairs(rarities) do
        local btn = Instance.new("TextButton")
        btn.Name = rarity .. "Button"
        btn.Size = UDim2.new(0, 100, 0, 25)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.Text = rarity
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.Parent = buttonContainer
        
        btn.MouseButton1Click:Connect(function()
            -- Update Scanner
            EggScanner:SetTargetRarity(rarity)
            
            -- Update UI Label
            targetLabel.Text = "Target: " .. rarity
            
            -- Reset all buttons
            for _, child in ipairs(buttonContainer:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                    child.TextColor3 = Color3.new(1, 1, 1)
                end
            end
            -- Highlight selected
            btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            btn.TextColor3 = Color3.new(1, 1, 1)
        end)
    end
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -10, 0, 30)
    statusLabel.Position = UDim2.new(0, 5, 0, 290)
    statusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    statusLabel.Text = "Scanning..."
    statusLabel.TextColor3 = Color3.new(0, 1, 1) -- Cyan
    statusLabel.TextSize = 14
    statusLabel.Parent = frame
    
    -- Stats Label
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "StatsLabel"
    statsLabel.Size = UDim2.new(1, -10, 0, 70)
    statsLabel.Position = UDim2.new(0, 5, 0, 325)
    statsLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    statsLabel.Text = "Steals: 0"
    statsLabel.TextColor3 = Color3.new(0.5, 1, 0.5) -- Green
    statsLabel.TextSize = 12
    statsLabel.Parent = frame
    
    -- Keybind Toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Config.ToggleKey then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)
    
    -- Update Loop
    spawn(function()
        while true do
            if screenGui.Enabled then
                -- Update Status
                local currentTarget = EggScanner:GetHighestRarityEgg()
                if currentTarget then
                    statusLabel.Text = "Target: " .. currentTarget.objectName .. " [" .. currentTarget.rarity .. "]"
                else
                    statusLabel.Text = "Searching for " .. EggScanner.selectedRarity .. " eggs..."
                end
                
                -- Update Stats
                local runtime = os.time() - EggScanner.startTime
                statsLabel.Text = string.format(
                    "Steals: %d\nS:%d E:%d D:%d\nRuntime: %ds",
                    Stats.totalSteals,
                    Stats.secretCount,
                    Stats.eternalCount,
                    Stats.divineCount,
                    runtime
                )
            end
            task.wait(1)
        end
    end)
end

-- --------------------------------------------------------------------------
-- MAIN INITIALIZATION
-- --------------------------------------------------------------------------

-- Initialize UI
UIOverlay:CreatePanel()

-- Initialize Pathfinder
TweenPathfinder.currentSpeed = Config.TweenSpeed

-- Start Stealer Loop
spawn(function()
    PriorityStealer:StartLoop()
end)

-- Start Scanner Loop
spawn(function()
    while true do
        EggScanner:ScanForNewEggs()
        task.wait(5) -- Scan every 5 seconds
    end
end)

print("[EGG THIEF] Initialized. Press " .. Config.ToggleKey.Name .. " to toggle UI.")
