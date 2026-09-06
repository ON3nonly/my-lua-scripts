local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Save initial position as base destination
local SAVED_BASE_CFRAME = HumanoidRootPart.CFrame

-- Target Remotes identified from the dump
local Networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local AskFieldEggCarry = Networking:WaitForChild("RF/EggWorld/AskFieldEggCarry")

local function stealEggAndTeleport()
    local guardAreas = Workspace:FindFirstChild("__OBJECTS")
        and Workspace.__OBJECTS:FindFirstChild("Areas")
        and Workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")

    if not guardAreas then
        warn("GuardAreas folder not found.")
        return
    end

    -- Iterate through game areas (Forest, Cosmic, Titan Temple, Cherry Blossom, Volcano, Lake, Jungle, Prehistoric, Snow, Desert)
    for _, area in ipairs(guardAreas:GetChildren()) do
        local nests = area:FindFirstChild("Nests")
        if nests then
            for _, nestModel in ipairs(nests:GetChildren()) do
                local eggSpot = nestModel:FindFirstChild("EggSpotBottom") or nestModel:FindFirstChild("EggFitBounds")
                if eggSpot then
                    -- Execute pickup remote via RemoteFunction
                    pcall(function()
                        AskFieldEggCarry:InvokeServer(eggSpot)
                    end)

                    -- Instant return teleportation to base location
                    task.wait(0.05)
                    if HumanoidRootPart then
                        HumanoidRootPart.CFrame = SAVED_BASE_CFRAME
                    end
                    return
                end
            end
        end
    end
end

-- Execute Script
stealEggAndTeleport()
