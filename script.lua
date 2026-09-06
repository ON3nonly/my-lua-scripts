-- ==========================================
-- MOBILE EGG THIEF FOR DELTA
-- ==========================================

-- 1. CONFIGURATION & STATE
local EggThief = {
    Enabled = true,
    KeyBind = Enum.KeyCode.T, -- Toggle UI
    Cooldown = 2.0, -- Seconds between attempts
    Speed = 30, -- Tween speed
    HomePosition = Vector3.new(0, 10, 0), -- Set your safe home base here
    
    -- Rarity Tiers (Higher number = Higher Priority)
    Rarities = {
        ["Common"] = 1,
        ["Uncommon"] = 2,
        ["Rare"] = 3,
        ["Epic"] = 4,
        ["Legendary"] = 5,
        ["Mythic"] = 6,
        ["Cosmic"] = 7,
        ["Secret"] = 8,
        ["Eternal"] = 9,
        ["Divine"] = 10
    },
    
    -- Selection State (Default: All ON)
    SelectedRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythic = true,
        Cosmic = true,
        Secret = true,
        Eternal = true,
        Divine = true
    },
    
    -- Stats
    Stats = {
        TotalSteals = 0,
        StartTime = tick(),
        CurrentTarget = "None",
        LastSteal = ""
    },
    
    -- Internal State
    LockedTarget = nil,
    LastAttemptTime = 0,
    ScanQueue = {}, -- Stores recent spawns
    UIVisible = true
}

-- ==========================================
-- 2. CORE LOGIC: SCANNER & STEALER
-- ==========================================

-- Helper: Check if a specific rarity is enabled for stealing
function EggThief:ShouldSteal(rarityName)
    return EggThief.SelectedRarities[rarityName] or false
end

-- Helper: Identify rarity from object name
function EggThief:GetRarityFromName(objectName)
    local name = string.upper(objectName)
    for rarity, _ in pairs(EggThief.Rarities) do
        if string.find(name, rarity) then
            return rarity
        end
    end
    return "Common" -- Default fallback
end

-- Main Loop: Scans and Steals
spawn(function()
    while EggThief.Enabled do
        -- 1. Get all valid egg-like objects in workspace
        local eggs = {}
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local name = obj.Name or ""
                local rarity = EggThief:GetRarityFromName(name)
                if EggThief.Rarities[rarity] then
                    table.insert(eggs, {
                        Instance = obj,
                        Rarity = rarity,
                        Tier = EggThief.Rarities[rarity]
                    })
                end
            end
        end

        -- 2. Filter eggs based on user selection
        local selectableEggs = {}
        for _, egg in ipairs(eggs) do
            if EggThief:ShouldSteal(egg.Rarity) then
                table.insert(selectableEggs, egg)
            end
        end

        -- 3. Find highest priority target
        local bestTarget = nil
        local maxTier = 0
        
        for _, egg in ipairs(selectableEggs) do
            if egg.Tier > maxTier then
                maxTier = egg.Tier
                bestTarget = egg
            elseif egg.Tier == maxTier then
                -- Tie-breaker: Pick the closest one
                local myPos = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
                local targetPos = egg.Instance.Position
                local distBest = (bestTarget.Instance.Position - myPos).Magnitude
                local distCurrent = (targetPos - myPos).Magnitude
                if distCurrent < distBest then
                    bestTarget = egg
                end
            end
        end

        -- 4. Execute Steal if Target Found and Cooldown Passed
        if bestTarget and tick() - EggThief.LastAttemptTime >= EggThief.Cooldown then
            EggThief.LockedTarget = bestTarget
            EggThief.Stats.CurrentTarget = bestTarget.Rarity
            
            -- Move to target
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                
                -- Simple pathfinding/tweening
                local tweenService = game:GetService("TweenService")
                local info = TweenInfo.new(
                    (root.Position - bestTarget.Instance.Position).Magnitude / EggThief.Speed,
                    Enum.EasingStyle.Linear,
                    Enum.EasingDirection.Out
                )
                local goal = TweenGoal.new({Position = bestTarget.Instance.Position})
                local tween = tweenService:Create(root, info, goal)
                
                tween:Play()
                tween.Completed:Wait()
                
                -- "Steal" logic (Destroy or Capture)
                if bestTarget.Instance and bestTarget.Instance.Parent then
                    bestTarget.Instance:Destroy()
                    EggThief.Stats.TotalSteals += 1
                    EggThief.Stats.LastSteal = bestTarget.Rarity
                    EggThief.LastAttemptTime = tick()
                    
                    -- Visual feedback
                    print("[EGG THIEF] Stole: " .. bestTarget.Rarity)
                end
            end
        else
            EggThief.Stats.CurrentTarget = "Scanning..."
        end
        
        wait(1) -- Scan every second
    end
end)

-- ==========================================
-- 3. UI OVERLAY (Mobile Optimized)
-- ==========================================

spawn(function()
    -- Create ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "EggThiefUI"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Frame
    local Frame = Instance.new("Frame")
    Frame.Name = "MainFrame"
    Frame.Size = UDim2.new(0, 280, 0, 450) -- Taller for list
    Frame.Position = UDim2.new(0.5, -140, 0, 50)
    Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    Frame.BorderSizePixel = 0
    Frame.BackgroundTransparency = 0.1
    Frame.Parent = ScreenGui
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 35)
    TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Frame
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Name = "Title"
    TitleText.Size = UDim2.new(1, -40, 1, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "EGG THIEF"
    TitleText.TextColor3 = Color3.fromRGB(0, 255, 255)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 16
    TitleText.Parent = TitleBar
    
    -- Close Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "Close"
    CloseBtn.Size = UDim2.new(0, 35, 0, 35)
    CloseBtn.Position = UDim2.new(1, -35, 0, 0)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar
    
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = not ScreenGui.Enabled
    end)
    
    -- Dragging Logic
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- ==========================================
    -- RARITY TOGGLE LIST
    -- ==========================================
    
    local ToggleFrame = Instance.new("ScrollingFrame")
    ToggleFrame.Name = "ToggleFrame"
    ToggleFrame.Size = UDim2.new(1, -10, 0, 200) -- Height for list
    ToggleFrame.Position = UDim2.new(0, 5, 0, 45)
    ToggleFrame.BackgroundTransparency = 0.8
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.ScrollBarThickness = 4
    ToggleFrame.Parent = Frame
    
    local Layout = Instance.new("UIListLayout")
    Layout.Parent = ToggleFrame
    Layout.Padding = UDim.new(0, 5)
    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    -- Create Buttons for Each Rarity
    local rarityNames = {"Divine", "Eternal", "Secret", "Cosmic", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"}
    
    for _, rarity in ipairs(rarityNames) do
        local btn = Instance.new("TextButton")
        btn.Name = "Btn_" .. rarity
        btn.Size = UDim2.new(0.9, 0, 0, 25)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        btn.Text = "[" .. rarity .. "] ON"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 12
        btn.Parent = ToggleFrame
        
        btn.MouseButton1Click:Connect(function()
            -- Toggle State
            EggThief.SelectedRarities[rarity] = not EggThief.SelectedRarities[rarity]
            
            -- Update Button Text
            if EggThief.SelectedRarities[rarity] then
                btn.Text = "[" .. rarity .. "] ON"
                btn.BackgroundColor3 = Color3.fromRGB(40, 100, 40) -- Green tint
            else
                btn.Text = "[" .. rarity .. "] OFF"
                btn.BackgroundColor3 = Color3.fromRGB(60, 40, 40) -- Red tint
            end
        end)
        
        -- Touch support
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                btn.MouseButton1Click:Invoke()
            end
        end)
    end
    
    -- ==========================================
    -- STATS & FEED DISPLAY
    -- ==========================================
    
    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -10, 0, 20)
    StatusLabel.Position = UDim2.new(0, 5, 0, 255)
    StatusLabel.BackgroundTransparency = 0.5
    StatusLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    StatusLabel.Text = "Target: None"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 12
    StatusLabel.Parent = Frame
    
    -- Stats Label
    local StatsLabel = Instance.new("TextLabel")
    StatsLabel.Name = "StatsLabel"
    StatsLabel.Size = UDim2.new(1, -10, 0, 20)
    StatsLabel.Position = UDim2.new(0, 5, 0, 280)
    StatsLabel.BackgroundTransparency = 0.5
    StatsLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    StatsLabel.Text = "Steals: 0"
    StatsLabel.TextColor3 = Color3.new(0, 1, 0)
    StatsLabel.Font = Enum.SourceSans
    StatsLabel.TextSize = 12
    StatsLabel.Parent = Frame
    
    -- Log Feed (Last 5)
    local FeedFrame = Instance.new("ScrollingFrame")
    FeedFrame.Name = "FeedFrame"
    FeedFrame.Size = UDim2.new(1, -10, 1, -310)
    FeedFrame.Position = UDim2.new(0, 5, 0, 305)
    FeedFrame.BackgroundTransparency = 0.8
    FeedFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    FeedFrame.BorderSizePixel = 0
    FeedFrame.ScrollBarThickness = 2
    FeedFrame.Parent = Frame
    
    local FeedLayout = Instance.new("UIListLayout")
    FeedLayout.Parent = FeedFrame
    FeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- Update UI Loop
    spawn(function()
        while wait(0.5) do
            if ScreenGui.Enabled then
                StatusLabel.Text = "Target: " .. EggThief.Stats.CurrentTarget
                StatsLabel.Text = "Steals: " .. EggThief.Stats.TotalSteals
                
                -- Update Feed with last stolen item
                local logText = "Last: " .. EggThief.Stats.LastSteal
                if EggThief.Stats.LastSteal ~= "" then
                    -- Clear old feed
                    for _, child in ipairs(FeedFrame:GetChildren()) do
                        if child:IsA("TextLabel") then
                            child:Destroy()
                        end
                    end
                    
                    local newLog = Instance.new("TextLabel")
                    newLog.Size = UDim2.new(1, 0, 0, 20)
                    newLog.BackgroundTransparency = 0.5
                    newLog.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
                    newLog.Text = "[" .. os.date("%H:%M:%S") .. "] Stole: " .. EggThief.Stats.LastSteal
                    newLog.TextColor3 = Color3.new(0, 1, 1)
                    newLog.Font = Enum.Font.SourceMono
                    newLog.TextSize = 10
                    newLog.Parent = FeedFrame
                end
            end
        end
    end)
    
    -- Keybind Toggle
    game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == EggThief.KeyBind then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)
end)
