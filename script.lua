local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BASE_POSITION = Vector3.new(0, 50, 0)

-- Create ScreenGui Container
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

-- Main Interface Window
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 220, 0, 160)
mainFrame.Position = UDim2.new(0.5, -110, 0.4, -80)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Steal An Egg GUI"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

-- Button 1: Steal & Teleport
local stealButton = Instance.new("TextButton")
stealButton.Name = "StealButton"
stealButton.Size = UDim2.new(0.85, 0, 0, 35)
stealButton.Position = UDim2.new(0.075, 0, 0.28, 0)
stealButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
stealButton.Text = "Instant Steal & TP"
stealButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stealButton.TextSize = 14
stealButton.Font = Enum.Font.SourceSans
stealButton.Parent = mainFrame

local stealCorner = Instance.new("UICorner")
stealCorner.CornerRadius = UDim.new(0, 6)
stealCorner.Parent = stealButton

-- Button 2: Teleport Base Only
local tpButton = Instance.new("TextButton")
tpButton.Name = "TPButton"
tpButton.Size = UDim2.new(0.85, 0, 0, 35)
tpButton.Position = UDim2.new(0.075, 0, 0.60, 0)
tpButton.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
tpButton.Text = "Teleport To Base"
tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpButton.TextSize = 14
tpButton.Font = Enum.Font.SourceSans
tpButton.Parent = mainFrame

local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 6)
tpCorner.Parent = tpButton

-- Mechanics Functions
local function teleportToBase()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(BASE_POSITION)
    end
end

local function stealHighestRarityEgg()
    local targetEgg = nil
    local highestRarityValue = -1

    local eggsFolder = Workspace:FindFirstChild("Eggs") or Workspace:FindFirstChild("EggSpawns")
    if eggsFolder then
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            local rarityAttr = egg:GetAttribute("Rarity") or (egg:FindFirstChild("Rarity") and egg.Rarity.Value)
            if rarityAttr and type(rarityAttr) == "number" and rarityAttr > highestRarityValue then
                highestRarityValue = rarityAttr
                targetEgg = egg
            end
        end
    end

    local stealRemote = ReplicatedStorage:FindFirstChild("StealEgg", true) or ReplicatedStorage:FindFirstChild("InteractRemote", true)
    if stealRemote and stealRemote:IsA("RemoteEvent") then
        if targetEgg then
            stealRemote:FireServer(targetEgg)
        else
            stealRemote:FireServer()
        end
        task.wait(0.05)
        teleportToBase()
    end
end

-- Event Listeners
stealButton.MouseButton1Click:Connect(stealHighestRarityEgg)
tpButton.MouseButton1Click:Connect(teleportToBase)
