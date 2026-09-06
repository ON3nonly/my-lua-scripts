--[[
    EGG THIEF v1.0 - Delta Compatible
    Combines: Scanner, Pathfinder, Priority Logic, UI Overlay
]]

local EggThief = {
    Name = "Egg Thief",
    Version = "1.0",
    Author = "Delta Tools"
}

-- ============================================================
-- PART 1: EGG SCANNER
-- ============================================================
local Scanner = {
    ScanInterval = 0.5,
    MaxDistance = 1000,
    Eggs = {},
    Log = {},
    RarityTiers = {
        SECRET = { priority = 1, color = {1, 0.2, 0.8}, label = "[SECRET]" },
        ETERNAL = { priority = 2, color = {1, 0.8, 0}, label = "[ETERNAL]" },
        DIVINE = { priority = 3, color = {0.2, 0.8, 1}, label = "[DIVINE]" },
        LEGENDARY = { priority = 4, color = {1, 0.5, 0}, label = "[LEGENDARY]" },
        EPIC = { priority = 5, color = {0.5, 0.2, 1}, label = "[EPIC]" },
        RARE = { priority = 6, color = {0.2, 0.5, 1}, label = "[RARE]" },
        COMMON = { priority = 7, color = {0.5, 0.5, 0.5}, label = "[COMMON]" }
    }
}

function Scanner:DetectRarity(objectName)
    local name = string.upper(objectName or "")
    for tier, data in pairs(self.RarityTiers) do
        if string.find(name, tier) or string.find(name, data.label) then
            return tier, data
        end
    end
    -- Fallback: try to parse from name patterns
    if string.find(name, "SECRET") then return "SECRET", self.RarityTiers.SECRET end
    if string.find(name, "ETERNAL") then return "ETERNAL", self.RarityTiers.ETERNAL end
    if string.find(name, "DIVINE") then return "DIVINE", self.RarityTiers.DIVINE end
    return "COMMON", self.RarityTiers.COMMON
end

function Scanner:ScanEggs()
    local eggs = {}
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    
    if not root then return eggs end
    
    local pos = root.Position
    
    -- Scan all parts in workspace for egg-like objects
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name and string.find(string.upper(obj.Name), "EGG") then
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
    
    -- Sort by priority (higher priority = lower number)
    table.sort(eggs, function(a, b)
        if a.Priority ~= b.Priority then
            return a.Priority < b.Priority
        end
        return a.Distance < b.Distance
    end)
    
    self.Eggs = eggs
    return eggs
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
    if #self.Log > 1000 then
        table.remove(self.Log, 1)
    end
end

-- ============================================================
-- PART 2: AUTO TWEEN PATHFINDER
-- ============================================================
local Pathfinder = {
    TweenSpeed = 16,
    ReturnSpeed = 25,
    HomePosition = nil,
    CurrentTarget = nil,
    IsTweening = false,
    ObstacleCheckRadius = 3,
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
end

function Pathfinder:GetCharacterRoot()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

function Pathfinder:CheckPathClear(startPos, endPos)
    -- Simple raycast check for obstacles
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
    
    -- Check if path is clear
    local clear, obstacle = self:CheckPathClear(root.Position, targetPos)
    if not clear then
        if callback then callback(false, "Path blocked by " .. tostring(obstacle.Name)) end
        return
    end
    
    self.IsTweening = true
    speed = speed or self.TweenSpeed
    
    -- Create tween using Delta's tweening
    local tweenInfo = TweenInfo.new(
        (root.Position - targetPos).Magnitude / speed,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )
    
    local goal = {Position = targetPos}
    local tween = game:GetService("TweenService"):Create(root, tweenInfo, goal)
    
    tween:Play()
    
    tween.Completed:Connect(function()
        self.IsTweening = false
        if callback then callback(true, "Arrived at target") end
    end)
    
    -- Safety timeout
    game:GetService("Debris"):AddItem(tween, 30)
end

function Pathfinder:TweenToEgg(eggInfo, callback)
    if not eggInfo or not eggInfo.Object or not eggInfo.Object.Parent then
        if callback then callback(false, "Egg no longer exists") end
        return
    end
    
    self.CurrentTarget = eggInfo
    local targetPos = eggInfo.Position + Vector3.new(0, 2, 0) -- Offset to stand near egg
    
    self:TweenToPosition(targetPos, self.TweenSpeed, function(success, message)
        if success then
            -- Arrived at egg
            if callback then callback(true, "Reached egg") end
        else
            if callback then callback(false, message) end
        end
    end)
end

function Pathfinder:ReturnHome(callback)
    if not self.HomePosition then
        if not self:SetHomePosition() then
            if callback then callback(false, "No home position set") end
            return
        end
    end
    
    self:TweenToPosition(self.HomePosition, self.ReturnSpeed, function(success, message)
        if callback then callback(success, message) end
    end)
end

-- ============================================================
-- PART 3: PRIORITY STEAL LOGIC
-- ============================================================
local Stealer = {
    IsRunning = false,
    Cooldown = 2.0,
    LastAttempt = 0,
    CurrentTarget = nil,
    RetryCount = 0,
    MaxRetries = 3,
    CollectionHistory = {},
    Stats = {
        TotalSteals = 0,
        ByRarity = {
            SECRET = 0,
            ETERNAL = 0,
            DIVINE = 0,
            LEGENDARY = 0,
            EPIC = 0,
            RARE = 0,
            COMMON = 0
        }
    }
}

function Stealer:GetPriorityTarget(scannedEggs)
    if not scannedEggs or #scannedEggs == 0 then return nil end
    
    -- Return the highest priority (first in sorted list)
    return scannedEggs[1]
end

function Stealer:StealEgg(eggInfo)
    if not eggInfo or not eggInfo.Object or not eggInfo.Object.Parent then
        return false, "Egg no longer exists"
    end
    
    -- Attempt to click/interact with the egg
    local player = game:GetService("Players").LocalPlayer
    local mouse = player:GetMouse()
    
    -- Simulate interaction (Delta-specific)
    -- This would be replaced with actual interaction logic
    local success = pcall(function()
        -- Click on egg
        local clickPosition = eggInfo.Position + Vector3.new(0, 1, 0)
        -- Simulate click at screen position
        -- In Delta, you'd use something like: mouse.Click()
    end)
    
    if success then
        -- Record collection
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
        
        return true, "Successfully collected " .. eggInfo.Name
    else
        return false, "Failed to collect egg"
    end
end

function Stealer:DecisionLoop()
    if self.IsRunning then return end
    self.IsRunning = true
    
    game:GetService("RunService").Heartbeat:Connect(function()
        if not self.IsRunning then return end
        
        -- Check cooldown
        if tick() - self.LastAttempt < self.Cooldown then return end
        
        -- Scan for eggs
        local eggs = Scanner:ScanEggs()
        
        -- Get priority target
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
                        -- Return home
                        Pathfinder:ReturnHome(function(returnSuccess, returnMsg)
                            if returnSuccess then
                                UI:UpdateStatus("IDLE")
                            else
                                UI:UpdateStatus("ERROR: " .. returnMsg)
                            end
                        end)
                    else
                        UI:UpdateStatus("FAILED: " .. stealMsg)
                        self.RetryCount = self.RetryCount + 1
                        if self.RetryCount >= self.MaxRetries then
                            self.RetryCount = 0
                            Pathfinder:ReturnHome()
                        end
                    end
                else
                    UI:UpdateStatus("PATH ERROR: " .. message)
                    Pathfinder:ReturnHome()
                end
            end)
        else
            UI:UpdateStatus("SCANNING...")
        end
    end)
end

-- ============================================================
-- PART 4: UI OVERLAY
-- ============================================================
local UI = {
    Visible = true,
    Keybind = Enum.KeyCode.F,
    Status = "INITIALIZING...",
    Frame = nil,
    Elements = {},
    Drawing = nil
}

function UI:Initialize()
    -- Create drawing objects (Delta-specific)
    -- Using simple text labels since Delta's drawing library is limited
    self.Frame = Drawing.new("Frame")
    self.Frame.Visible = true
    self.Frame.Position = Vector2.new(10, 10)
    self.Frame.Size = Vector2.new(350, 250)
    self.Frame.Color = Color3.fromRGB(0, 0, 0)
    self.Frame.BackgroundTransparency = 0.8
    self.Frame.Active = true
    self.Frame.Draggable = true
    
    -- Title
    self.Title = Drawing.new("Text")
    self.Title.Size = 16
    self.Title.Color = Color3.fromRGB(100, 255, 100)
    self.Title.Position = Vector2.new(20, 15)
    self.Title.Text = "EGG THIEF v1.0"
    
    -- Status
    self.StatusText = Drawing.new("Text")
    self.StatusText.Size = 14
    self.StatusText.Color = Color3.fromRGB(255, 255, 255)
    self.StatusText.Position = Vector2.new(20, 40)
    self.StatusText.Text = "Status: INITIALIZING..."
    
    -- Target
    self.TargetText = Drawing.new("Text")
    self.TargetText.Size = 13
    self.TargetText.Color = Color3.fromRGB(200, 200, 200)
    self.TargetText.Position = Vector2.new(20, 65)
    self.TargetText.Text = "Target: None"
    
    -- Stats
    self.StatsText = Drawing.new("Text")
    self.StatsText.Size = 12
    self.StatsText.Color = Color3.fromRGB(180, 180, 180)
    self.StatsText.Position = Vector2.new(20, 95)
    self.StatsText.Text = "Stats: 0 steals"
    
    -- Scan Feed
    self.ScanFeed = Drawing.new("Text")
    self.ScanFeed.Size = 11
    self.ScanFeed.Color = Color3.fromRGB(150, 150, 150)
    self.ScanFeed.Position = Vector2.new(20, 140)
    self.ScanFeed.Text = "Scan Feed:\nNone"
    self.ScanFeed.TextXAlignment = "Left"
    self.ScanFeed.TextYAlignment = "Top"
    
    -- Keybind hint
    self.HintText = Drawing.new("Text")
    self.HintText.Size = 10
    self.HintText.Color = Color3.fromRGB(100, 100, 100)
    self.HintText.Position = Vector2.new(20, 235)
    self.HintText.Text = "Press " .. tostring(self.Keybind) .. " to toggle"
    
    self:UpdateStatus("READY")
end

function UI:UpdateStatus(status)
    self.Status = status
    if self.StatusText then
        self.StatusText.Text = "Status: " .. status
        -- Color status based on state
        local colors = {
            IDLE = Color3.fromRGB(100, 255, 100),
            SCANNING = Color3.fromRGB(255, 255, 100),
            MOVING = Color3.fromRGB(100, 200, 255),
            COLLECTING = Color3.fromRGB(255, 150, 0),
            ERROR = Color3.fromRGB(255, 50, 50),
            READY = Color3.fromRGB(100, 255, 100)
        }
        self.StatusText.Color = colors[status] or Color3.fromRGB(255, 255, 255)
    end
end

function UI:UpdateTarget(eggInfo)
    if not self.TargetText then return end
    if eggInfo then
        self.TargetText.Text = "Target: " .. eggInfo.Label .. " " .. eggInfo.Name
        self.TargetText.Color = Color3.fromRGB(unpack(eggInfo.Color or {200, 200, 200}))
    else
        self.TargetText.Text = "Target: None"
        self.TargetText.Color = Color3.fromRGB(200, 200, 200)
    end
end

function UI:UpdateStats()
    if not self.StatsText then return end
    local stats = Stealer.Stats
    local text = string.format("Stats: %d steals | S:%d E:%d D:%d",
        stats.TotalSteals,
        stats.ByRarity.SECRET or 0,
        stats.ByRarity.ETERNAL or 0,
        stats.ByRarity.DIVINE or 0
    )
    self.StatsText.Text = text
end

function UI:UpdateScanFeed()
    if not self.ScanFeed then return end
    local log = Scanner.Log
    local recent = {}
    local count = 0
    for i = #log, math.max(1, #log - 5), -1 do
        count = count + 1
        local entry = log[i]
        local color = Scanner.RarityTiers[entry.Rarity] and Scanner.RarityTiers[entry.Rarity].color or {0.5, 0.5, 0.5}
        local colorStr = string.format("%.0f,%.0f,%.0f", color[1]*255, color[2]*255, color[3]*255)
        table.insert(recent, string.format("  [%s] %s %s", entry.TimeString, entry.Rarity, entry.Name))
    end
    self.ScanFeed.Text = "Scan Feed:\n" .. table.concat(recent, "\n")
end

function UI:Toggle()
    self.Visible = not self.Visible
    self.Frame.Visible = self.Visible
    self.Title.Visible = self.Visible
    self.StatusText.Visible = self.Visible
    self.TargetText.Visible = self.Visible
    self.StatsText.Visible = self.Visible
    self.ScanFeed.Visible = self.Visible
    self.HintText.Visible = self.Visible
end

function UI:Render()
    -- Update all UI elements
    self:UpdateStats()
    self:UpdateScanFeed()
    self:UpdateTarget(Stealer.CurrentTarget)
end

-- ============================================================
-- PART 5: MERGE BLOCK - MAIN CONTROLLER
-- ============================================================
local Main = {
    IsRunning = false
}

function Main:Initialize()
    -- Initialize all subsystems
    print("[Egg Thief] Initializing...")
    
    -- Setup UI
    UI:Initialize()
    
    -- Set home position
    Pathfinder:SetHomePosition()
    
    -- Setup keybind
    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.KeyCode == UI.Keybind and input.UserInputType == Enum.UserInputType.Keyboard then
            UI:Toggle()
        end
    end)
    
    -- Start the decision loop
    Stealer:DecisionLoop()
    
    -- Start UI render loop
    game:GetService("RunService").Heartbeat:Connect(function()
        if UI.Visible then
            UI:Render()
        end
    end)
    
    self.IsRunning = true
    UI:UpdateStatus("IDLE")
    print("[Egg Thief] Ready!")
end

function Main:Stop()
    self.IsRunning = false
    Stealer.IsRunning = false
    UI:UpdateStatus("STOPPED")
    print("[Egg Thief] Stopped")
end

-- ============================================================
-- COMMAND INTERFACE
-- ============================================================
_G.EggThief = Main

-- Auto-start
Main:Initialize()

-- ============================================================
-- HELPER FUNCTIONS (for manual control)
-- ============================================================
function StartEggThief()
    if not Main.IsRunning then
        Main:Initialize()
    end
    Stealer.IsRunning = true
    UI:UpdateStatus("IDLE")
    print("[Egg Thief] Started")
end

function StopEggThief()
    Main:Stop()
end

function ToggleUI()
    UI:Toggle()
end

function SetHomePosition()
    Pathfinder:SetHomePosition()
    print("[Egg Thief] Home position set")
end

-- ============================================================
-- EXAMPLE USAGE
-- ============================================================
--[[
    -- Start the thief
    StartEggThief()
    
    -- Stop the thief
    StopEggThief()
    
    -- Toggle UI visibility (default: F key)
    ToggleUI()
    
    -- Set current position as home
    SetHomePosition()
]]

print("[Egg Thief] Loaded successfully!")
print("[Egg Thief] Press F to toggle UI")
