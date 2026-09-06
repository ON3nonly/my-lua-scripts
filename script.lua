-- 🎨 UI SETUP (FIXED FOR DELTA)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaRarityUI"
ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") -- Fixed: Parent to PlayerGui
ScreenGui.ResetOnSpawn = false -- Fixed: Keeps UI after death
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
        task.wait(1) -- Use task.wait instead of wait
        LastStolenLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    end
end

-- 1. Get Services
local LocalPlayer = game:GetService("Players").LocalPlayer
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. Define Target RARITIES ONLY (Secret, Eternal, Divine)
local TargetRarities = {
    "Secret", 
    "Eternal", 
    "Divine"
}

-- 3. Check if Item is Target Rarity
local function isTargetRarity(item)
    if not item or not item:IsA("Tool") then return false end
    
    -- Check Attribute first (modern games)
    local rarity = item:GetAttribute("Rarity") or ""
    
    -- Fallback to Name if Attribute is missing
    if rarity == "" then
        rarity = item.Name
    end
    
    -- Check if any target rarity is in the string
    for _, target in pairs(TargetRarities) do
        if rarity:lower():find(target:lower(), 1, true) then
            return true
        end
    end
    return false
end

-- 4. Tween Animation Function (Fixed)
local function animateSteal(item, targetPlayer)
    local char = targetPlayer.Character
    if not char then return end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local handle = item:FindFirstChild("Handle") or item:FindFirstChild("MeshPart") or item
    
    local myChar = LocalPlayer.Character
    -- ✅ FIXED: Added check for myRoot to prevent error
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end 
    
    -- Tween the item to your character's head or root
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tweenGoal = {
        Position = myRoot.Position + Vector3.new(0, 2, 0) -- Move to above your head
    }
    
    local tween = TweenService:Create(handle, tweenInfo, tweenGoal)
    tween:Play()
    
    print("✅ Animated " .. item.Name .. " to your character")
end

-- 5. Main Loop: Steal Items
while true do
    task.wait(0.5) -- Check every half second
    
    if not isPaused then
        -- Get Character
        local char = LocalPlayer.Character
        if not char then task.wait() continue end
        
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if not myRoot then task.wait() continue end
        
        -- Scan Backpack
        local backpack = LocalPlayer:WaitForChild("Backpack")
        for _, tool in pairs(backpack:GetChildren()) do
            if isTargetRarity(tool) then
                updateUI("Found", tool.Name)
                animateSteal(tool, LocalPlayer)
                -- Optional: You can add logic here to "steal" it from others if needed
            end
        end
        
        -- Scan Character Inventory (Equipped items)
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") and isTargetRarity(tool) then
                -- Avoid double counting if it's also in backpack
                if not backpack:FindFirstChild(tool.Name) then
                    updateUI("Equipped", tool.Name)
                    animateSteal(tool, LocalPlayer)
                end
            end
        end
    end
end
