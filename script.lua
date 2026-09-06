--[[
    EGG THIEF v1.0 - Delta Mobile Compatible
    Optimized for Android/iOS Delta Executor
]]

local EggThief = {
    Name = "Egg Thief Mobile",
    Version = "1.0",
    Author = "Delta Tools"
}

-- ============================================================
-- PART 1: EGG SCANNER (Mobile Optimized)
-- ============================================================
local Scanner = {
    ScanInterval = 0.3, -- Faster on mobile
    MaxDistance = 500, -- Reduced for performance
    Eggs = {},
    Log = {},
    RarityTiers = {
        SECRET = { priority = 1, color = {1, 0.2, 0.8}, label = "⭐ SECRET" },
        ETERNAL = { priority = 2, color = {1, 0.8, 0}, label = "♾️ ETERNAL" },
        DIVINE = { priority = 3, color = {0.2, 0.8, 1}, label = "👼 DIVINE" },
        LEGENDARY = { priority = 4, color = {1, 0.5, 0}, label = "🔥 LEGENDARY" },
        EPIC = { priority = 5, color = {0.5, 0.2, 1}, label = "💜 EPIC" },
        RARE = { priority = 6, color = {0.2, 0.5, 1}, label = "💙 RARE" },
        COMMON = { priority = 7, color = {0.5, 0.5, 0.5}, label = "⬜ COMMON" }
    }
}

-- Mobile-friendly object scanning
function Scanner:ScanEggs()
    local eggs = {}
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    
    if not root then return eggs end
    
    local pos = root.Position
    
    -- Optimized scanning - only check parts nearby
    local parts = workspace:GetDescendants()
    for i = 1, #parts do
        local obj = parts[i]
        if obj:IsA("BasePart") and obj.Name then
            local nameUpper = string.upper(obj.Name)
            if string.find(nameUpper, "EGG") or string.find(nameUpper, "SECRET") or 
               string.find(nameUpper, "ETERNAL") or string.find(nameUpper, "DIVINE") then
                
                local distance = (obj.Position - pos).Magnitude
                if distance <= self.MaxDistance then
                    local rarity, data = self:DetectRarity(obj.Name)
                    local eggInfo = {
                        Object = obj,
                        Name = obj.Name,
                        Position = obj.Position,
                        Distance = distance,
                        Rarity = rarity,
                        Priority = data.priority,
                        Color = data.color,
                        Label = data.label,
                        Timestamp = os.time(),
                        Size = obj.Size,
                        Exists = true
                    }
                    table.insert(eggs, eggInfo)
                end
            end
        end
    end
    
    -- Sort by priority
    table.sort(eggs, function(a, b)
        if a.Priority ~= b.Priority then
            return a.Priority < b.Priority
        end
        return a.Distance < b.Distance
    end)
    
    self.Eggs = eggs
    return eggs
end

function Scanner:DetectRarity(objectName)
    local name = string.upper(objectName or "")
    for tier, data in pairs(self.RarityTiers) do
        if string.find(name, tier) then
            return tier, data
        end
    end
    return "COMMON", self.RarityTiers.COMMON
end

function Scanner:LogSpawn(eggInfo)
    local entry = {
        Timestamp = os.time(),
        TimeString = os.date("%H:%M:%S"),
        Name = eggInfo.Name,
        Rarity = eggInfo.Rarity,
        Position = eggInfo.Position,
        Action = "SPAWNED"
    }
    table.insert(self.Log, entry)
    if #self.Log > 500 then
        table.remove(self.Log, 1)
    end
end

-- ============================================================
-- PART 2: AUTO TWEEN PATHFINDER (Mobile)
-- ============================================================
local Pathfinder = {
    TweenSpeed = 12, -- Slightly slower for mobile stability
    ReturnSpeed = 20,
    HomePosition = nil,
    CurrentTarget = nil,
    IsTweening = false,
    ObstacleCheckRadius = 2,
    RetryCount = 0,
    MaxRetries = 3
}

function Pathfinder:SetHomePosition()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        self.HomePosition = root.Position
        return true
    end
    return false
}

function Pathfinder:GetCharacterRoot()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

function Pathfinder:CheckPathClear(startPos, endPos)
    -- Simple obstacle check
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {game:GetService("Players").LocalPlayer.Character}
    
    local result = workspace:Raycast(startPos, direction * distance, raycastParams)
    if result then
        return false, result.Instance
    end
    return true, nil
end

function Pathfinder:TweenToPosition(targetPos, speed, callback)
    local root = self:GetCharacterRoot()
    if not root or self.IsTweening then
        if callback then callback(false, "Cannot start tween") end
        return
    end
    
    -- Check path
    local clear, obstacle = self:CheckPathClear(root.Position, targetPos)
    if not clear then
        if callback then callback(false, "Path blocked") end
        return
    end
    
    self.IsTweening = true
    speed = speed or self.TweenSpeed
    
    -- Mobile-friendly tween with better performance
    local tweenInfo = TweenInfo.new(
        (root.Position - targetPos).Magnitude / speed,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out,
        0, -- No delay
        false, -- Not reversed
        0 -- No repeats
    )
    
    local goal = {Position = targetPos}
    local tween = game:GetService("TweenService"):Create(root, tweenInfo, goal)
    
    tween:Play()
    
    tween.Completed:Connect(function()
        self.IsTweening = false
        if callback then callback(true, "Arrived") end
    end)
    
    -- Safety timeout
    task.wait(30)
    if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
        tween:Cancel()
        self.IsTweening = false
        if callback then callback(false, "Tween timeout") end
    end
end

function Pathfinder:TweenToEgg(eggInfo, callback)
    if not eggInfo or not eggInfo.Object or not eggInfo.Object.Parent then
        if callback then callback(false, "Egg gone") end
        return
    end
    
    self.CurrentTarget = eggInfo
    local targetPos = eggInfo.Position + Vector3.new(0, 2, 0)
    
    self:TweenToPosition(targetPos, self.TweenSpeed, function(success, message)
        if callback then callback(success, message) end
    end)
end

function Pathfinder:ReturnHome(callback)
    if not self.HomePosition then
        if not self:SetHomePosition() then
            if callback then callback(false, "No home position") end
            return
        end
    end
    
    self:TweenToPosition(self.HomePosition, self.ReturnSpeed, function(success, message)
        if callback then callback(success, message) end
    end)
end

-- ============================================================
-- PART 3: PRIORITY STEAL LOGIC (Mobile)
-- ============================================================
local Stealer = {
    IsRunning = false,
    Cooldown = 2.5, -- Slightly longer on mobile
    LastAttempt = 0,
    CurrentTarget = nil,
    RetryCount = 0,
    MaxRetries = 3,
    CollectionHistory = {},
    Stats = {
        TotalSteals = 0,
        ByRarity = {
            SECRET = 0, ETERNAL = 0, DIVINE = 0,
            LEGENDARY = 0, EPIC = 0, RARE = 0, COMMON = 0
        }
    }
}

function Stealer:GetPriorityTarget(scannedEggs)
    if not scannedEggs or #scannedEggs == 0 then return nil end
    return scannedEggs[1]
end

function Stealer:StealEgg(eggInfo)
    if not eggInfo or not eggInfo.Object or not eggInfo.Object.Parent then
        return false, "Egg gone"
    end
    
    -- Mobile-friendly interaction
    local success = pcall(function()
        -- Simulate clicking/tapping on egg
        -- In Delta mobile, use touch events
        local player = game:GetService("Players").LocalPlayer
        
        -- Try to fire touch event
        local touch = {
            Position = eggInfo.Position + Vector3.new(0, 1, 0),
            UserInputType = Enum.UserInputType.Touch
        }
        
        -- Alternative: use mouse click simulation
        local mouse = player:GetMouse()
        if mouse and mouse.Click then
            -- Move mouse to position and click
            mouse.Move(eggInfo.Position + Vector3.new(0, 1, 0))
            mouse.Click()
        end
    end)
    
    if success then
        self.CollectionHistory[#self.CollectionHistory + 1] = {
            Timestamp = os.time(),
            TimeString = os.date("%H:%M:%S"),
            Rarity = eggInfo.Rarity,
            Name = eggInfo.Name
        }
        
        self.Stats.TotalSteals = self.Stats.TotalSteals + 1
        if self.Stats.ByRarity[eggInfo.Rarity] then
            self.Stats.ByRarity[eggInfo.Rarity] = self.Stats.ByRarity[eggInfo.Rarity] + 1
        end
        
        return true, "Collected " .. eggInfo.Name
    else
        return false, "Failed to collect"
    end
end

function Stealer:DecisionLoop()
    if self.IsRunning then return end
    self.IsRunning = true
    
    -- Use task.wait for better mobile performance
    task.spawn(function()
        while self.IsRunning do
            task.wait(self.Cooldown)
            
            -- Scan for eggs
            local eggs = Scanner:ScanEggs()
            local target = self:GetPriorityTarget(eggs)
            
            if target then
                self.CurrentTarget = target
                self.LastAttempt = tick()
                
                -- Log spawn
                Scanner:LogSpawn(target)
                
                -- Tween to target
                Pathfinder:TweenToEgg(target, function(success, message)
                    if success then
                        -- Attempt steal
                        local stealSuccess, stealMsg = self:StealEgg(target)
                        
                        if stealSuccess then
                            Pathfinder:ReturnHome()
                            UI:UpdateStatus("✅ COLLECTED: " .. target.Label)
                        else
                            UI:UpdateStatus("❌ FAILED: " .. stealMsg)
                        end
                    else
                        UI:UpdateStatus("⚠️ PATH ERROR")
                        Pathfinder:ReturnHome()
                    end
                end)
            else
                UI:UpdateStatus("🔍 SCANNING...")
            end
        end
    end)
end

-- ============================================================
-- PART 4: UI OVERLAY (Mobile Delta)
-- ============================================================
local UI = {
    Visible = true,
    Keybind = Enum.KeyCode.F, -- Also works with touch
    Status = "INITIALIZING...",
    Elements = {}
}

-- Mobile-friendly drawing using Delta's GUI library
function UI:Initialize()
    -- Use Delta's built-in GUI for mobile
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggThiefUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    
    -- Main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 250)
    frame.Position = UDim2.new(0, 10, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(100, 255, 100)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 5, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "🥚 EGG THIEF v1.0"
    title.TextColor3 = Color3.fromRGB(100, 255, 100)
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.Bold
    title.Parent = frame
    
    -- Status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 5, 0, 30)
    status.BackgroundTransparency = 1
    status.Text = "🔴 Status: INITIALIZING..."
    status.TextColor3 = Color3.fromRGB(255, 255, 255)
    status.TextSize = 14
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame
    
    -- Target
    local target = Instance.new("TextLabel")
    target.Size = UDim2.new(1, 0, 0, 20)
    target.Position = UDim2.new(0, 5, 0, 55)
    target.BackgroundTransparency = 1
    target.Text = "🎯 Target: None"
    target.TextColor3 = Color3.fromRGB(200, 200, 200)
    target.TextSize = 13
    target.TextXAlignment = Enum.TextXAlignment.Left
    target.Parent = frame
    
    -- Stats
    local stats = Instance.new("TextLabel")
    stats.Size = UDim2.new(1, 0, 0, 50)
    stats.Position = UDim2.new(0, 5, 0, 80)
    stats.BackgroundTransparency = 1
    stats.Text = "📊 Stats:\nTotal: 0 | S:0 E:0 D:0"
    stats.TextColor3 = Color3.fromRGB(180, 180, 180)
    stats.TextSize = 12
    stats.TextXAlignment = Enum.TextXAlignment.Left
    stats.TextYAlignment = Enum.TextYAlignment.Top
    stats.Parent = frame
    
    -- Scan feed
    local feed = Instance.new("TextLabel")
    feed.Size = UDim2.new(1, 0, 0, 80)
    feed.Position = UDim2.new(0, 5, 0, 140)
    feed.BackgroundTransparency = 1
    feed.Text = "📋 Recent:\nNone"
    feed.TextColor3 = Color3.fromRGB(150, 150, 150)
    feed.TextSize = 11
    feed.TextXAlignment = Enum.TextXAlignment.Left
    feed.TextYAlignment = Enum.TextYAlignment.Top
    feed.Parent = frame
    
    -- Control buttons (mobile friendly)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 80, 0, 25)
    toggleBtn.Position = UDim2.new(0, 5, 0, 222)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    toggleBtn.Text = "⏹ STOP"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 12
    toggleBtn.Parent = frame
    
    toggleBtn.MouseButton1Click:Connect(function()
        if Stealer.IsRunning then
            Main:Stop()
            toggleBtn.Text = "▶ START"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        else
            Main:Start()
            toggleBtn.Text = "⏹ STOP"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end)
    
    -- Store references
    self.Frame = frame
    self.Title = title
    self.Status = status
    self.Target = target
    self.Stats = stats
    self.Feed = feed
    self.ToggleBtn = toggleBtn
    self.Gui = screenGui
    
    -- Add to player GUI
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    UI:UpdateStatus("✅ READY")
end

function UI:UpdateStatus(status)
    if self.Status then
        self.Status.Text = "🔄 " .. status
    end
end

function UI:UpdateTarget(eggInfo)
    if not self.Target then return end
    if eggInfo then
        self.Target.Text = "🎯 " .. eggInfo.Label .. " " .. eggInfo.Name
        -- Color the text based on rarity
        local color = eggInfo.Color or {200, 200, 200}
        self.Target.TextColor3 = Color3.fromRGB(color[1]*255, color[2]*255, color[3]*255)
    else
        self.Target.Text = "🎯 Target: None"
        self.Target.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end

function UI:UpdateStats()
    if not self.Stats then return end
    local stats = Stealer.Stats
    self.Stats.Text = string.format(
        "📊 Stats:\nTotal: %d | ⭐%d ♾️%d 👼%d",
        stats.TotalSteals,
        stats.ByRarity.SECRET or 0,
        stats.ByRarity.ETERNAL or 0,
        stats.ByRarity.DIVINE or 0
    )
end

function UI:UpdateFeed()
    if not self.Feed then return end
    local log = Scanner.Log
    local lines = {}
    local count = 0
    for i = #log, math.max(1, #log - 4), -1 do
        count = count + 1
        local entry = log[i]
        table.insert(lines, string.format("  %s %s %s", entry.TimeString, entry.Rarity, entry.Name))
    end
    if #lines == 0 then
        self.Feed.Text = "📋 Recent:\nNone"
    else
        self.Feed.Text = "📋 Recent:\n" .. table.concat(lines, "\n")
    end
end

function UI:Toggle()
    if self.Gui then
        self.Gui.Enabled = not self.Gui.Enabled
    end
end

-- ============================================================
-- PART 5: MAIN CONTROLLER
-- ============================================================
local Main = {
    IsRunning = false
}

function Main:Initialize()
    print("🥚 Egg Thief Mobile Starting...")
    
    -- Setup UI
    UI:Initialize()
    
    -- Set home position
    task.wait(1) -- Wait for character to load
    Pathfinder:SetHomePosition()
    
    -- Setup keybind (works with keyboard if connected)
    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F and input.UserInputType == Enum.UserInputType.Keyboard then
            UI:Toggle()
        end
    end)
    
    -- Start the loop
    Stealer:DecisionLoop()
    
    -- Start UI update loop
    task.spawn(function()
        while true do
            task.wait(0.5)
            if Stealer.IsRunning then
                UI:UpdateStats()
                UI:UpdateFeed()
                UI:UpdateTarget(Stealer.CurrentTarget)
            end
        end
    end)
    
    self.IsRunning = true
    print("✅ Egg Thief Ready! Press F to toggle UI")
end

function Main:Start()
    if not self.IsRunning then
        self:Initialize()
    end
    Stealer.IsRunning = true
    UI:UpdateStatus("🟢 RUNNING")
    print("▶ Egg Thief Started")
end

function Main:Stop()
    Stealer.IsRunning = false
    UI:UpdateStatus("🔴 STOPPED")
    print("⏹ Egg Thief Stopped")
end

-- ============================================================
-- COMMANDS (Type in console)
-- ============================================================
_G.EggThief = Main

-- Auto-start on load
task.wait(2)
Main:Initialize()

-- Mobile-friendly console commands
print("═══════════════════════════════════")
print("🥚 EGG THIEF MOBILE LOADED")
print("═══════════════════════════════════")
print("📱 Commands:")
print("  StartEggThief()  - Start collecting")
print("  StopEggThief()   - Stop collecting")
print("  ToggleUI()       - Show/Hide UI")
print("  SetHomePosition()- Set return point")
print("═══════════════════════════════════")

-- ============================================================
-- MOBILE OPTIMIZATIONS
-- ============================================================

-- Reduce memory usage
task.spawn(function()
    while true do
        task.wait(60) -- Clean up every minute
        collectgarbage()
    end
end)

-- Touch controls (for mobile)
local touchService = game:GetService("UserInputService")
touchService.TouchStarted:Connect(function(touch)
    -- Double tap to toggle UI (optional)
    -- Could add more touch gestures here
end)

print("📱 Mobile optimization enabled")
