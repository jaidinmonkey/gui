--==============================================================
-- Services
--==============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

--==============================================================
-- Settings
--==============================================================
local AIM_ENABLED = true
local AIM_SMOOTHNESS = 0.25       -- Base smoothness (0 = instant)
local IGNORE_TEAM = true           -- Ignore teammates
local AIM_FOV = 80                 -- Field of view around crosshair
local AIM_OFFSET = {
    Head = Vector3.new(0, 0.2, 0),
    Torso = Vector3.new(0, 0, 0),
    RightHand = Vector3.new(0, 0, 0),
    HumanoidRootPart = Vector3.new(0, 0, 0)
}
local TARGET_PRIORITY = {"Head", "Torso", "RightHand", "HumanoidRootPart"} -- Priority order
local TARGET_LOCK_TIME = 0.15     -- Seconds before switching target to avoid jitter

--==============================================================
-- Variables
--==============================================================
local currentTarget = nil
local currentPart = nil
local lastSwitchTime = 0

--==============================================================
-- Helper Functions
--==============================================================

-- Check if a player is an enemy
local function isEnemy(player)
    if not player.Team or not LocalPlayer.Team then
        return true
    end
    return player.Team ~= LocalPlayer.Team
end

-- Check if part is visible (raycast)
local function isVisible(part)
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin).Unit * (part.Position - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, direction, params)
    return not result or result.Instance:IsDescendantOf(part.Parent)
end

-- Check if part is inside FOV
local function inFOV(part, offset)
    offset = offset or Vector3.new(0,0,0)
    local viewportPos, onScreen = Camera:WorldToViewportPoint(part.Position + offset)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local distance = (Vector2.new(viewportPos.X, viewportPos.Y) - center).Magnitude
    local maxDistance = (AIM_FOV / 180) * Camera.ViewportSize.X
    return distance <= maxDistance
end

-- Predictive aim based on target velocity
local function predictPosition(part)
    if part.Parent:FindFirstChild("HumanoidRootPart") then
        local velocity = part.Parent:FindFirstChild("HumanoidRootPart").Velocity
        return part.Position + velocity * 0.1 -- Adjust multiplier for speed
    end
    return part.Position
end

-- Find the closest valid target based on priority
local function getClosestTarget()
    local closestPlayer = nil
    local closestPart = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not IGNORE_TEAM or isEnemy(player) then
                for _, partName in ipairs(TARGET_PRIORITY) do
                    local part = player.Character:FindFirstChild(partName)
                    if part and isVisible(part) and inFOV(part, AIM_OFFSET[partName]) then
                        local predictedPos = predictPosition(part) + AIM_OFFSET[partName]
                        local viewportPos = Camera:WorldToViewportPoint(predictedPos)
                        local distance = (Vector2.new(viewportPos.X, viewportPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestPlayer = player
                            closestPart = partName
                        end
                    end
                end
            end
        end
    end

    return closestPlayer, closestPart
end

-- Aim at a specific part
local function aimAt(player, partName)
    if not player or not player.Character then return end
    local part = player.Character:FindFirstChild(partName) or player.Character:FindFirstChild("HumanoidRootPart")
    if not part then return end

    local predictedPos = predictPosition(part) + (AIM_OFFSET[partName] or Vector3.new(0,0,0))
    local direction = (predictedPos - Camera.CFrame.Position).Unit
    local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)

    -- Dynamic smoothing based on distance
    local distance = (predictedPos - Camera.CFrame.Position).Magnitude
    local smooth = math.clamp(AIM_SMOOTHNESS * (distance/50), 0, 1)
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, smooth)
end

--==============================================================
-- Main Loop
--==============================================================
RunService.RenderStepped:Connect(function(dt)
    if AIM_ENABLED then
        local time = tick()
        local target, part = getClosestTarget()
        if target then
            -- Only switch target if enough time has passed
            if target ~= currentTarget or part ~= currentPart or time - lastSwitchTime > TARGET_LOCK_TIME then
                currentTarget = target
                currentPart = part
                lastSwitchTime = time
            end
            aimAt(currentTarget, currentPart)
        else
            currentTarget = nil
            currentPart = nil
        end
    end
end)
