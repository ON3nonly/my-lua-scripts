-- ==========================================
-- PART 5: MERGE BLOCK — EGG THIEF DELTA EDITION
-- ==========================================

local EggThief = {}

-- ==========================================
-- PART 1: EGG SCANNER
-- Monitors spawns, identifies rarity, logs data
-- ==========================================
EggScanner = {
    Log = {},
    MaxLogs = 50,
    RarityMap = {
        ["Secret"] = 1,
        ["Eternal"] = 2,
        ["Divine"] = 3,
        ["Common"] = 4
    },
    -- Event listener for new entities (Delta specific: adjust event name if needed)
    SpawnEvent = nil,
    
    Initialize = function(self)
        -- Assuming Delta provides a global event or we hook into game:GetService("Players").ChildAdded
        -- This is a placeholder for the actual Delta event hook
        self.SpawnEvent = game:GetService("Players").ChildAdded -- Example hook
        print("[SCANNER] Initialized. Monitoring spawns...")
    end,

    IdentifyRarity = function(self, objectName)
        local name = string.upper(tostring(objectName))
        if string.find(name, "SECRET") then return "Secret" end
        if string.find(name, "ETERNAL") then return "Eternal" end
        if string.find(name, "DIVINE") then return "Divine" end
        return "Common"
    end,

    LogSpawn = function(self, entity)
        local rarity = self:IdentifyRarity(entity.Name)
        local timestamp = os.date("%H:%M:%S")
        
        local entry = {
            Timestamp = timestamp,
            Name = entity.Name,
            Rarity = rarity,
            Position = entity.Position,
            Entity = entity
        }
        
        table.insert(self.Log, entry)
        
        -- Keep log size manageable
        if #self.Log > self.MaxLogs then
            table.remove(self.Log, 1)
        end
        
        -- Notify UI
        if EggUI then
            EggUI:UpdateFeed(entry)
        end
        
        -- Notify Stealer
        if EggStealer then
            EggStealer:OnNewSpawn(entry)
        end
        
        return entry
    end
}

-- ==========================================
-- PART 2: AUTO TWEEN PATHFINDER
-- Calculates path, tweens, avoids obstacles, returns home
-- ==========================================
EggPathfinder = {
    HomePosition = Vector3.new(0, 10, 0), -- Default home
    Speed = 10,
    Character = nil,
    Humanoid = nil,
    
    Initialize = function(self)
        local player = game.Players.LocalPlayer
        self.Character = player.Character or player.CharacterAdded:Wait()
        self.Humanoid = self.Character:WaitForChild("Humanoid")
        print("[PATHFINDER] Initialized. Home set to: " .. tostring(self.HomePosition))
    end,

    SetHomePosition = function(self, pos)
        self.HomePosition = pos
    end,

    IsPathClear = function(self, start, finish)
        local direction = (finish - start).Unit * (finish - start).Magnitude
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {self.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local result = workspace:Raycast(start, direction, rayParams)
        return result == nil
    end,

    TweenToPosition = function(self, targetPos)
        if not self.Character then return false end
        
        local currentPos = self.Character.PrimaryPart.Position
        
        -- Simple obstacle check before tweening
        if not self:IsPathClear(currentPos, targetPos) then
            print("[PATHFINDER] Obstacle detected. Pathing manually...")
            -- Fallback: Move humanoid directly
            self.Humanoid:MoveTo(targetPos)
            self.Humanoid.MoveToFinished:Wait()
            return true
        end
        
        -- Create Tween
        local tweenInfo = TweenInfo.new(
            (currentPos - targetPos).Magnitude / self.Speed,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out,
            0,
            false
        )
        
        local tween = TweenService:Create(self.Character.PrimaryPart, tweenInfo, {Position = targetPos})
        tween:Play()
        tween.Completed:Wait()
        return true
    end,

    ReturnHome = function(self)
        if not self.Character then return false end
        
        local currentPos = self.Character.PrimaryPart.Position
        local dist = (currentPos - self.HomePosition).Magnitude
        
        if dist < 2 then return true end -- Already close
        
        print("[PATHFINDER] Returning to base...")
        return self:TweenToPosition(self.HomePosition)
    end
}

-- ==========================================
-- PART 3: PRIORITY STEAL LOGIC
-- Sorts by rarity, locks target, triggers pathfinder, logs steal
-- ==========================================
EggStealer = {
    Queue = {},
    Cooldown = 5.0,
    LastStealTime = 0,
    LockedTarget = nil,
    IsStealing = false,
    
    Initialize = function(self)
        print("[STEALER] Priority Logic Initialized.")
        self:StartLoop()
    end,

    OnNewSpawn = function(self, entry)
        table.insert(self.Queue, entry)
        -- Sort queue by rarity priority (1=Secret, 2=Eternal, etc.)
        table.sort(self.Queue, function(a, b)
            return EggScanner.RarityMap[a.Rarity] < EggScanner.RarityMap[b.Rarity]
        end)
        
        -- If nothing is locked and we are not stealing, try to lock
        if not self.LockedTarget and not self.IsStealing then
            self:TryLockTarget()
        end
    end,

    TryLockTarget = function(self)
        if #self.Queue == 0 then return end
        
        local target = self.Queue[1]
        
        -- Check if target still exists
        if target.Entity and target.Entity.Parent then
            self.LockedTarget = target
            print("[STEALER] Locked Target: " .. target.Name .. " (" .. target.Rarity .. ")")
            
            -- Update UI
            if EggUI then
                EggUI:SetTarget(target)
            end
        else
            -- Target is gone, remove from queue
            table.remove(self.Queue, 1)
            self:TryLockTarget() -- Retry
        end
    end,

    ExecuteSteal = function(self)
        if not self.LockedTarget then return end
        
        self.IsStealing = true
        print("[STEALER] Executing steal on: " .. self.LockedTarget.Name)
        
        -- Trigger Pathfinder
        local success = EggPathfinder:TweenToPosition(self.LockedTarget.Position)
        
        if success then
            -- Simulate collection (in real game, you might click or use a tool)
            task.wait(0.5) -- Small delay for effect
            
            -- Log Steal
            local timestamp = os.date("%H:%M:%S")
            print("[STEALER] Success! Stole: " .. self.LockedTarget.Name .. " at " .. timestamp)
            
            -- Update UI Stats
            if EggUI then
                EggUI:IncrementStats(self.LockedTarget.Rarity)
            end
            
            -- Remove from queue
            for i, entry in ipairs(self.Queue) do
                if entry == self.LockedTarget then
                    table.remove(self.Queue, i)
                    break
                end
            end
            
            -- Return to home
            EggPathfinder:ReturnHome()
            
            -- Update Cooldown
            self.LastStealTime = os.time()
        else
            print("[STEALER] Failed to reach target.")
        end
        
        self.LockedTarget = nil
        self.IsStealing = false
    end,

    StartLoop = function(self)
        while true do
            if not self.IsStealing and not self.LockedTarget then
                self:TryLockTarget()
            end
            
            if self.LockedTarget and not self.IsStealing then
                -- Check cooldown if we just finished a steal (optional logic)
                -- For now, we steal as soon as we lock if no cooldown active
                local now = os.time()
                if (now - self.LastStealTime) >= self.Cooldown then
                    self:ExecuteSteal()
                end
            end
            
            task.wait(1) -- Check every second
        end
    end
}

-- ==========================================
-- PART 4: UI OVERLAY
-- Lightweight, draggable, scrollable, toggleable
-- ==========================================
EggUI = {
    ScreenGui = nil,
    Frame = nil,
    FeedFrame = nil,
    StatsLabel = nil,
    TargetLabel = nil,
    StatusLabel = nil,
    
    Stats = {
        Total = 0,
        Secret = 0,
        Eternal = 0,
        Divine = 0,
        StartTime = os.time()
    },
    
    Initialize = function(self)
        -- Create ScreenGui
        self.ScreenGui = Instance.new("ScreenGui")
        self.ScreenGui.Name = "EggThiefUI"
        self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        self.ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
        
        -- Main Frame
        self.Frame = Instance.new("Frame")
        self.Frame.Name = "MainFrame"
        self.Frame.Size = UDim2.new(0, 300, 0, 400)
        self.Frame.Position = UDim2.new(0.5, -150, 0, 50)
        self.Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        self.Frame.BorderSizePixel = 0
        self.Frame.BackgroundTransparency = 0.1
        self.Frame.Parent = self.ScreenGui
        
        -- Title Bar (for dragging)
        local TitleBar = Instance.new("Frame")
        TitleBar.Name = "TitleBar"
        TitleBar.Size = UDim2.new(1, 0, 0, 30)
        TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        TitleBar.BorderSizePixel = 0
        TitleBar.Parent = self.Frame
        
        local TitleText = Instance.new("TextLabel")
        TitleText.Name = "Title"
        TitleText.Size = UDim2.new(1, -50, 1, 0)
        TitleText.BackgroundTransparency = 1
        TitleText.Text = "EGG THIEF"
        TitleText.TextColor3 = Color3.fromRGB(0, 255, 255)
        TitleText.Font = Enum.Font.GothamBold
        TitleText.TextSize = 16
        TitleText.Parent = TitleBar
        
        -- Close Button
        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Name = "Close"
        CloseBtn.Size = UDim2.new(0, 30, 0, 30)
        CloseBtn.Position = UDim2.new(1, -30, 0, 0)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.new(1, 1, 1)
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Parent = TitleBar
        
        CloseBtn.MouseButton1Click:Connect(function()
            self.ScreenGui.Enabled = not self.ScreenGui.Enabled
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
                startPos = self.Frame.Position
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
                self.Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        
        -- UI Content
        
        -- Status Label
        self.StatusLabel = Instance.new("TextLabel")
        self.StatusLabel.Name = "Status"
        self.StatusLabel.Size = UDim2.new(1, 0, 0, 20)
        self.StatusLabel.Position = UDim2.new(0, 0, 0, 35)
        self.StatusLabel.BackgroundTransparency = 0.5
        self.StatusLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
        self.StatusLabel.Text = "Status: Scanning..."
        self.StatusLabel.TextColor3 = Color3.new(1, 1, 1)
        self.StatusLabel.Font = Enum.Font.SourceSans
        self.StatusLabel.TextSize = 12
        self.StatusLabel.Parent = self.Frame
        
        -- Target Label
        self.TargetLabel = Instance.new("TextLabel")
        self.TargetLabel.Name = "TargetLabel"
        self.TargetLabel.Size = UDim2.new(1, 0, 0, 25)
        self.TargetLabel.Position = UDim2.new(0, 0, 0, 60)
        self.TargetLabel.BackgroundTransparency = 0.5
        self.TargetLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        self.TargetLabel.Text = "Target: None"
        self.TargetLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
        self.TargetLabel.Font = Enum.Font.GothamBold
        self.TargetLabel.TextSize = 14
        self.TargetLabel.Parent = self.Frame
        
        -- Stats Label
        self.StatsLabel = Instance.new("TextLabel")
        self.StatsLabel.Name = "StatsLabel"
        self.StatsLabel.Size = UDim2.new(1, 0, 0, 25)
        self.StatsLabel.Position = UDim2.new(0, 0, 0, 90)
        self.StatsLabel.BackgroundTransparency = 0.5
        self.StatsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        self.StatsLabel.Text = "Total: 0"
        self.StatsLabel.TextColor3 = Color3.new(0, 1, 0)
        self.StatsLabel.Font = Enum.Font.SourceSans
        self.StatsLabel.TextSize = 12
        self.StatsLabel.Parent = self.Frame
        
        -- Scrollable Feed
        self.FeedFrame = Instance.new("ScrollingFrame")
        self.FeedFrame.Name = "Feed"
        self.FeedFrame.Size = UDim2.new(1, -10, 1, -130)
        self.FeedFrame.Position = UDim2.new(0, 5, 0, 120)
        self.FeedFrame.BackgroundTransparency = 0.8
        self.FeedFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
        self.FeedFrame.BorderSizePixel = 0
        self.FeedFrame.ScrollBarThickness = 4
        self.FeedFrame.Parent = self.Frame
        
        local UIListLayout = Instance.new("UIListLayout")
        UIListLayout.Parent = self.FeedFrame
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
        print("[UI] Initialized and Loaded.")
    end,

    UpdateFeed = function(self, entry)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = string.format("[%s] %s: %s", entry.Timestamp, entry.Rarity, entry.Name)
        
        -- Color based on rarity
        if entry.Rarity == "Secret" then label.TextColor3 = Color3.fromRGB(255, 0, 255)
        elseif entry.Rarity == "Eternal" then label.TextColor3 = Color3.fromRGB(255, 165, 0)
        elseif entry.Rarity == "Divine" then label.TextColor3 = Color3.fromRGB(255, 215, 0)
        else label.TextColor3 = Color3.new(1, 1, 1) end
        
        label.Font = Enum.Font.SourceMono
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = self.FeedFrame
        
        -- Auto scroll to bottom
        self.FeedFrame.CanvasSize = UDim2.new(0, 0, 0, #self.FeedFrame:GetChildren() * 20)
    end,

    SetTarget = function(self, target)
        self.TargetLabel.Text = "Target: " .. target.Name .. " (" .. target.Rarity .. ")"
        self.StatusLabel.Text = "Status: Acquiring..."
    end,

    IncrementStats = function(self, rarity)
        self.Stats.Total = self.Stats.Total + 1
        
        if rarity == "Secret" then self.Stats.Secret = self.Stats.Secret + 1
        elseif rarity == "Eternal" then self.Stats.Eternal = self.Stats.Eternal + 1
        elseif rarity == "Divine" then self.Stats.Divine = self.Stats.Divine + 1 end
        
        local elapsed = os.time() - self.Stats.StartTime
        self.StatsLabel.Text = string.format("Total: %d | S: %d | E: %d | D: %d | Time: %ds", 
            self.Stats.Total, self.Stats.Secret, self.Stats.Eternal, self.Stats.Divine, elapsed)
        
        self.StatusLabel.Text = "Status: Scanning..."
    end
}

-- ==========================================
-- PART 5: INITIALIZATION & MERGE
-- ==========================================
function EggThief:Start()
    -- 1. Initialize UI
    EggUI:Initialize()
    
    -- 2. Initialize Pathfinder
    EggPathfinder:Initialize()
    
    -- 3. Initialize Scanner (Hook into spawn event)
    -- This is a generic hook; adjust to Delta's specific event if different
    game:GetService("Workspace").ChildAdded:Connect(function(child)
        if child:IsA("Model") and child:FindFirstChild("Humanoid") or child.Name:lower():find("egg") then
            -- Check if it's a relevant egg object
            local name = child.Name
            if name:lower():find("egg") or name:lower():find("secret") or name:lower():find("eternal") or name:lower():find("divine") then
                EggScanner:LogSpawn(child)
            end
        end
    end)
    
    EggScanner:Initialize()
    
    -- 4. Initialize Stealer Logic
    EggStealer:Initialize()
    
    print("[EGG THIEF] All modules loaded and running.")
end

-- Start the script
EggThief:Start()
