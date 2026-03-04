local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local Parried = false
local Enabled = true
local SpamEnabled = false

-- Camera-relative directions
local Directions = {"Forward", "Left", "Right", "Back", "Up"}
local CurrentIndex = 1
local CurrentDirection = Directions[CurrentIndex]

local Indicator
local DirectionIndicator
local SpamIndicator

local Connections = {}

local function Track(conn)
    table.insert(Connections, conn)
    return conn
end

-- UI Indicator (SMALLER + SPAM UI)
local function CreateIndicator()
    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "ParryIndicator"
    Billboard.Size = UDim2.new(0, 110, 0, 85)
    Billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    Billboard.AlwaysOnTop = true
    Billboard.Parent = Character:WaitForChild("Head")

    local ParryText = Instance.new("TextLabel")
    ParryText.Name = "State"
    ParryText.Size = UDim2.new(1, 0, 0.33, 0)
    ParryText.BackgroundTransparency = 1
    ParryText.TextScaled = true
    ParryText.Font = Enum.Font.GothamBold
    ParryText.TextColor3 = Color3.fromRGB(0, 255, 0)
    ParryText.TextTransparency = 0.35
    ParryText.Text = "PARRY: ON"
    ParryText.Parent = Billboard

    local DirectionText = Instance.new("TextLabel")
    DirectionText.Name = "Direction"
    DirectionText.Size = UDim2.new(1, 0, 0.33, 0)
    DirectionText.Position = UDim2.new(0, 0, 0.33, 0)
    DirectionText.BackgroundTransparency = 1
    DirectionText.TextScaled = true
    DirectionText.Font = Enum.Font.GothamBold
    DirectionText.TextColor3 = Color3.fromRGB(255, 255, 0)
    DirectionText.TextTransparency = 0.35
    DirectionText.Text = "DIR: " .. CurrentDirection
    DirectionText.Parent = Billboard

    local SpamText = Instance.new("TextLabel")
    SpamText.Name = "SpamStatus"
    SpamText.Size = UDim2.new(1, 0, 0.33, 0)
    SpamText.Position = UDim2.new(0, 0, 0.66, 0)
    SpamText.BackgroundTransparency = 1
    SpamText.TextScaled = true
    SpamText.Font = Enum.Font.GothamBold
    SpamText.TextColor3 = Color3.fromRGB(255, 0, 0)
    SpamText.TextTransparency = 0.35
    SpamText.Text = "CLICK SPAM: OFF"
    SpamText.Parent = Billboard

    return ParryText, DirectionText, SpamText
end

Indicator, DirectionIndicator, SpamIndicator = CreateIndicator()

Track(Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    task.wait(0.1)
    Indicator, DirectionIndicator, SpamIndicator = CreateIndicator()
    Indicator.Text = Enabled and "PARRY: ON" or "PARRY: OFF"
    DirectionIndicator.Text = "DIR: " .. CurrentDirection
    SpamIndicator.Text = SpamEnabled and "CLICK SPAM: ON" or "CLICK SPAM: OFF"
end))

local function UpdateIndicator()
    Indicator.Text = Enabled and "PARRY: ON" or "PARRY: OFF"
    Indicator.TextColor3 = Enabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
end

local function UpdateDirectionIndicator()
    DirectionIndicator.Text = "DIR: " .. CurrentDirection
end

local function UpdateSpamIndicator()
    if SpamEnabled then
        SpamIndicator.Text = "CLICK SPAM: ON"
        SpamIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        SpamIndicator.Text = "CLICK SPAM: OFF"
        SpamIndicator.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end

-- Toggle + Direction Cycle
Track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    -- PARRY ON/OFF TOGGLE (V KEY)
    if input.KeyCode == Enum.KeyCode.V then
        Enabled = not Enabled
        UpdateIndicator()
    end

    -- Direction cycle
    if input.KeyCode == Enum.KeyCode.C then
        CurrentIndex += 1
        if CurrentIndex > #Directions then CurrentIndex = 1 end
        CurrentDirection = Directions[CurrentIndex]
        UpdateDirectionIndicator()
    end

    -- CLICK SPAM TOGGLE (X KEY)
    if input.KeyCode == Enum.KeyCode.X then
        SpamEnabled = not SpamEnabled
        UpdateSpamIndicator()
    end
end))

-- CLICK SPAM LOOP (50 CLICKS PER FRAME — NO LAG)
Track(RunService.Heartbeat:Connect(function()
    if SpamEnabled then
        for i = 1, 50 do
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end
end))

-- Camera override
local Camera = workspace.CurrentCamera

local function AimCameraForParry()
    local original = Camera.CFrame
    local pos = original.Position

    local forward = original.LookVector
    local right = original.RightVector
    local up = original.UpVector

    local dir

    if CurrentDirection == "Forward" then dir = forward end
    if CurrentDirection == "Back" then dir = -forward end
    if CurrentDirection == "Left" then dir = -right end
    if CurrentDirection == "Right" then dir = right end
    if CurrentDirection == "Up" then dir = up end

    if not dir then return original end

    Camera.CFrame = CFrame.lookAt(pos, pos + dir * 1000)

    return original
end

-- Get Ball
local function GetBall()
    for _, Ball in ipairs(workspace.Balls:GetChildren()) do
        if Ball:GetAttribute("realBall") then
            return Ball
        end
    end
end

-- Prediction Parry
Track(RunService.PreSimulation:Connect(function()
    if not Enabled then return end

    local Ball = GetBall()
    if not Ball then return end

    local Character = Player.Character
    if not Character then return end

    local HRP = Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return end

    local velocity = Ball.zoomies.VectorVelocity
    local speed = velocity.Magnitude
    if speed < 1 then return end

    local distance = (Ball.Position - HRP.Position).Magnitude
    local directionToPlayer = (HRP.Position - Ball.Position).Unit
    local movingToward = velocity.Unit:Dot(directionToPlayer) > 0.7
    if not movingToward then return end

    local damp = 1 - math.exp(-distance / 20)
    local speedBoost = math.clamp(speed / 180, 0, 0.45)

    local predictionTime = math.clamp((distance / speed) * (damp + speedBoost), 0.01, 0.24)
    local predictedPosition = Ball.Position + (velocity * predictionTime)
    local predictedDistance = (predictedPosition - HRP.Position).Magnitude

    local hitboxRadius = math.clamp(6 + (speed / 55), 7, 16)

    if Ball:GetAttribute("target") == Player.Name and not Parried and predictedDistance <= hitboxRadius then
        
        local originalCam = AimCameraForParry()

        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)

        RunService.RenderStepped:Wait()
        Camera.CFrame = originalCam

        local cooldown = math.clamp(0.1 * (distance / speed), 0.015, 0.12)
        Parried = true
        task.delay(cooldown, function() Parried = false end)
    end
end))

--------------------------------------------------------------------
-- HARD UNLOAD (SAFE)
--------------------------------------------------------------------

local function HardUnload()
    Enabled = false
    Parried = true

    for _, conn in ipairs(Connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end

    table.clear(Connections)

    if Indicator and Indicator.Parent then
        Indicator.Parent:Destroy()
    end

    task.defer(function()
        Indicator = nil
        DirectionIndicator = nil
        SpamIndicator = nil
        Directions = nil
        CurrentDirection = nil
        Camera = nil
    end)

    print("Parry Script HARD UNLOADED.")
end

Track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.KeypadOne then
        HardUnload()
    end
end))
