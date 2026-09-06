-- 🎨 UI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaRarityUI"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Background Panel
local Frame = Instance.new("Frame")
Frame.Name = "Panel"
Frame.Size = UDim2.new(0, 300, 0, 150)
Frame.Position = UDim2.new(0.5, -150, 0.5, -75)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.Text = "🎯 Secret/Eternal/Divine Stealer"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Gothen
Title.TextSize = 14
Title.Parent = Frame

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.Position = UDim2.new(0, 10, 0, 40)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Scanning..."
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 12
StatusLabel.Parent = Frame

-- Last Stolen Label
local LastStolenLabel = Instance.new("TextLabel")
LastStolenLabel.Name = "LastStolen"
LastStolenLabel.Size = UDim2.new(1, -20, 0, 20)
LastStolenLabel.Position = UDim2.new(0, 10, 0, 65)
LastStolenLabel.BackgroundTransparency = 1
LastStolenLabel.Text = "Last Stolen: None"
LastStolenLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
LastStolenLabel.Font = Enum.Font.Code
LastStolenLabel.TextSize = 12
LastStolenLabel.Parent = Frame

-- Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "Toggle"
ToggleBtn.Size = UDim2.new(0, 100, 0, 30)
ToggleBtn.Position = UDim2.new(0.5, -50, 1, -30)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ToggleBtn.Text = "PAUSE"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.Bold
ToggleBtn.TextSize = 12
ToggleBtn.Parent = Frame

-- UI State
local isPaused = false
ToggleBtn.MouseButton1Click:Connect(function()
    isPaused = not isPaused
    ToggleBtn.Text = isPaused and "RESUME" or "PAUSE"
    StatusLabel.Text = isPaused and "Status: Paused" or "Status: Scanning..."
    StatusLabel.TextColor3 = isPaused and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
end)

-- Helper function to update UI
local function updateUI(status, msg)
    if isPaused and status ~= "Paused" then return end
    StatusLabel.Text = "Status: " .. status
    if msg then
        LastStolenLabel.Text = "Last Stolen: " .. msg
        LastStolenLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
        wait(1)
        LastStolenLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    end
end

-- 1. Get LocalPlayer
local LocalPlayer = game:GetService("Players").LocalPlayer
local TweenService = game:GetService("TweenService")

-- 2. Get Remote Event
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GiveItemRemote = ReplicatedStorage:WaitForChild("GiveItem")

-- 3. Define Target RARITIES ONLY (Secret, Eternal, Divine)
local TargetRarities = {
    "Secret", 
    "Eternal", 
    "Divine"
}

local function isTargetRarity(item)
    if not item or not item:IsA("Tool") then return false end
    local rarity = item:GetAttribute("Rarity") or item.Name
    for _, target in pairs(TargetRarities) do
        if rarity:lower():find(target:lower(), 1, true) then
            return true
        end
    end
    return false
end

-- 4. Tween Animation Function
local function animateSteal(item, targetPlayer)
    local char = targetPlayer.Character
    if not char then return end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local handle = item:FindFirstChild("Handle") or item:FindFirstChild("MeshPart") or item
    
    local myChar = LocalPlayer.Character
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    -- Fast tween to your position
    local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
    local goal = {Position = myRoot.Position + Vector3.new(0, 2, 0)}
    
    local tween = TweenService:create(handle, tweenInfo, goal)
    tween:Play()
    tween:Complete() 
    
    item.Parent = LocalPlayer.Backpack
end

-- 5. Main Steal Logic
local function trySteal(item, sourcePlayer)
    if not GiveItemRemote then return end
    if not item:IsA("Tool") then return end
    
    if not isTargetRarity(item) then return end
    
    updateUI("Target Found", item.Name)
    print("🎯 Target Rarity Found: " .. item.Name)
    
    -- Play Tween Animation
    animateSteal(item, sourcePlayer)
    
    -- Fire Remote
    GiveItemRemote:FireServer(item, LocalPlayer)
    
    -- Ensure it's in backpack
    item.Parent = LocalPlayer.Backpack
    
    -- Trigger Safe Return
    safeReturnToBase(item)
    
    return true
end

-- 6. Safe Return Logic
local function safeReturnToBase(item)
    local Base = LocalPlayer.Character:FindFirstChild("Base") 
    if not Base then
        Base = LocalPlayer.Backpack:FindFirstChild("Base") or LocalPlayer.Character:FindFirstChild("Base")
    end
    
    if Base and Base:IsA("Tool") then
        print("🔄 Returning " .. item.Name .. " to base...")
        
        -- Equip Base
        LocalPlayer.Character.Humanoid:EquipTool(Base)
        wait(0.5)
        
        -- Right Click to Deposit
        LocalPlayer.Character.Humanoid:UnequipTools()
        if Base.Handle and Base.Handle:FindFirstChild("ProximityPrompt") then
            Base.Handle.ProximityPrompt:Fire()
        elseif Base.Handle and Base.Handle:FindFirstChild("ClickDetector") then
            Base.Handle.ClickDetector.MouseClick:Fire(LocalPlayer)
        else
            -- Fallback: Just parent it to base if prompt fails
            item.Parent = Base.Parent
        end
        
        wait(1) 
        
        -- Unequip Base
        LocalPlayer.Character.Humanoid:UnequipTools()
    else
        print("⚠️ Base tool not found for return!")
    end
end

-- 7. Scan Backpacks
game:GetService("RunService").Heartbeat:Connect(function()
    if isPaused then return end
    
    -- Update Status
    updateUI("Scanning...")
    
    -- Scan Backpacks
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            for _, item in pairs(player.Backpack:GetChildren()) do
                if item:IsA("Tool") and isTargetRarity(item) then
                    trySteal(item, player)
                    break 
                end
            end
        end
    end
end)

print("✅ Secret/Eternal/Divine Stealer Active")
