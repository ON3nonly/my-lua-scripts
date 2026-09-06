-- ULTRA SIMPLE EGG THIEF - Delta Mobile
print("🥚 Loading...")

local running = false
local homePos = nil

-- Set home
local function setHome()
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        homePos = char.HumanoidRootPart.Position
        print("🏠 Home set!")
    end
end

-- Simple scan
local function scanEggs()
    local eggs = {}
    local char = game.Players.LocalPlayer.Character
    if not char then return eggs end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return eggs end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name and string.find(string.upper(obj.Name), "EGG") then
            local dist = (obj.Position - root.Position).Magnitude
            if dist < 500 then
                table.insert(eggs, obj)
            end
        end
    end
    return eggs
end

-- Start
function StartEggThief()
    running = true
    setHome()
    print("✅ Started!")
    
    task.spawn(function()
        while running do
            local eggs = scanEggs()
            if #eggs > 0 then
                local target = eggs[1]
                print("🎯 Found egg: " .. target.Name)
                
                -- Move to egg
                local root = game.Players.LocalPlayer.Character.HumanoidRootPart
                local tween = game:GetService("TweenService"):Create(root, 
                    TweenInfo.new(2, Enum.EasingStyle.Linear), 
                    {Position = target.Position + Vector3.new(0, 2, 0)}
                )
                tween:Play()
                task.wait(3)
                
                -- Try to click
                pcall(function()
                    local mouse = game.Players.LocalPlayer:GetMouse()
                    if mouse and mouse.Click then
                        mouse.Move(target.Position)
                        mouse.Click()
                        print("✅ Clicked!")
                    end
                end)
                
                -- Return home
                if homePos then
                    local tween2 = game:GetService("TweenService"):Create(root,
                        TweenInfo.new(2, Enum.EasingStyle.Linear),
                        {Position = homePos}
                    )
                    tween2:Play()
                    task.wait(2)
                end
            end
            task.wait(2)
        end
    end)
end

function StopEggThief()
    running = false
    print("⏹ Stopped!")
end

print("✅ Loaded! Type StartEggThief() to begin")
