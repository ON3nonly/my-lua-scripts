local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI Container Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggUI_Fixed"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 230, 0, 160)
mainFrame.Position = UDim2.new(0.5, -115, 0.4, -80)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Steal An Egg GUI (Fixed)"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

local stealButton = Instance.new("TextButton")
stealButton.Size = UDim2.new(0.85, 0, 0, 35)
stealButton.Position = UDim2.new(0.075, 0, 0.28, 0)
stealButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
stealButton.Text = "Instant Steal & TP"
stealButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stealButton.Font = Enum.Font.SourceSans
stealButton.TextSize = 14
stealButton.Parent = mainFrame

local stealCorner = Instance.new("UICorner")
stealCorner.CornerRadius = UDim.new(0, 6)
stealCorner.Parent = stealButton

local tpButton = Instance.new("TextButton")
tpButton.Size = UDim2.new(0.85, 0, 0, 35)
tpButton.Position = UDim2.new(0.075, 0, 0.60, 0)
tpButton.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
tpButton.Text = "Set / Teleport Base"
tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpButton.Font = Enum.Font.SourceSans
tpButton.TextSize = 14
tpButton.Parent = mainFrame

local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 6)
tpCorner.Parent = tpButton

-- Execution Mechanics
local savedBaseCFrame = nil

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function handleTeleport()
    local root = getRoot()
    if root then
        if not savedBaseCFrame then
            savedBaseCFrame = root.CFrame
        else
            root.CFrame = savedBaseCFrame
        end
    end
end

local function executeSteal()
    local root = getRoot()
    if not root then return end

    -- Save base position on first run
    if not savedBaseCFrame then
        savedBaseCFrame = root.CFrame
    end

    -- Trigger Proximity Prompts in workspace
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            if fireproximityprompt then
                fireproximityprompt(prompt)
            else
                prompt:InputHoldBegin()
                task.wait(prompt.HoldDuration)
                prompt:InputHoldEnd()
            end
        end
    end

    -- Fire direct Network Remotes
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            local name = remote.Name:lower()
            if name:find("steal") or name:find("egg") or name:find("claim") or name:find("grab") or name:find("interact") then
                remote:FireServer()
            end
        end
    end

    -- Return to saved base location
    task.wait(0.05)
    handleTeleport()
end

stealButton.MouseButton1Click:Connect(executeSteal)
tpButton.MouseButton1Click:Connect(handleTeleport)
