local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = `rbxassetid://{ReGui.PrefabsId}`

if _G.StopESPScript then
    _G.StopESPScript()
end

local scriptRunning = true
_G.StopESPScript = function()
    scriptRunning = false
    if _G.ESPFolder then
        _G.ESPFolder.Settings.AimEnabled = false
        _G.ESPFolder.Settings.Enabled = false
    end
    print("[DEBUG] Stopping previous script instance")
end

ReGui:Init({
    Prefabs = game:GetService("InsertService"):LoadLocalAsset(PrefabsId)
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 1
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Transparency = 0.7
fovCircle.NumSides = 100

local lastFovUpdate = 0
local function updateFovCircle()
    if not scriptRunning then return end
    local now = tick()
    if now - lastFovUpdate < 0.1 then return end
    
    lastFovUpdate = now
    if not _G.ESPFolder.Settings.AimEnabled then
        fovCircle.Visible = false
        return
    end
    
    fovCircle.Visible = true
    fovCircle.Radius = _G.ESPFolder.Settings.AimFov
    local camera = workspace.CurrentCamera
    fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

_G.ESPFolder = {
    fovCircle = fovCircle,
    Connections = {},
    Drawings = {},
    Settings = {
        Enabled = true,
        BoxColor = Color3.new(1, 0, 0),
        HostageColor = Color3.new(0, 1, 0),
        SuspectColor = Color3.new(1, 0, 0),
        TextColor = Color3.new(1, 1, 1),
        HealthColor = Color3.new(0, 1, 0),
        TracerColor = Color3.new(1, 1, 1),
        SkeletonColor = Color3.new(1, 1, 1),
        BoxThickness = 1,
        TextSize = 16,
        ShowDistance = true,
        ShowNames = true,
        ShowHostages = true,
        ShowSuspects = true,
        ShowHealth = true,
        ShowTracers = false,
        ShowSkeleton = true,
        FilledBoxes = false,
        BoxTransparency = 0.5,
        TracerOrigin = "Bottom",
        FullBright = false,
        Brightness = 1,
        GlobalShadows = true,
        MaxDistance = 1000,
        DisablePostEffects = true,
        SavedPostEffects = {},
        AimEnabled = false,
        AimFov = 100,
        AimSmoothness = 9,
        AimKey = Enum.KeyCode.X,
        AimPriority = "Distance",
        AimMinHealth = 0,
        AimMaxHealth = 100,
        AimMinDistance = 0,
        AimMaxDistance = 1000,
        AimAtHostages = false,
        AimPart = "Head",
        AimPrediction = false,
        AimPredictionAmount = 0.165,
        AimWallCheck = true,
        AimTeamCheck = true,
        AimVisibilityCheck = true
    }
}

local function updatePostEffects()
    if _G.ESPFolder.Settings.DisablePostEffects then
        for _, obj in pairs(Lighting:GetChildren()) do
            if obj:IsA("PostEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or 
               obj:IsA("SunRaysEffect") or obj:IsA("BloomEffect") or obj:IsA("DepthOfFieldEffect") then
                _G.ESPFolder.Settings.SavedPostEffects[obj] = obj.Enabled
                obj.Enabled = false
            end
        end
    else
        for obj, enabled in pairs(_G.ESPFolder.Settings.SavedPostEffects) do
            if obj and obj.Parent then
                obj.Enabled = enabled
            end
        end
    end
end

local function updateFullBright()
    if _G.ESPFolder.Settings.FullBright then
        _G.ESPFolder.Settings.OldBrightness = Lighting.Brightness
        _G.ESPFolder.Settings.OldGlobalShadows = Lighting.GlobalShadows
        Lighting.Brightness = _G.ESPFolder.Settings.Brightness
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = _G.ESPFolder.Settings.OldBrightness
        Lighting.GlobalShadows = _G.ESPFolder.Settings.OldGlobalShadows
    end
end

local Window = ReGui:TabsWindow({
    Title = "BodyCam by internet.monster",
    Size = UDim2.fromOffset(550, 400),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5)
})

local isWindowVisible = true
local isAiming = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not scriptRunning then return end
    if input.KeyCode == Enum.KeyCode.F then
        isAiming = true
    end
end)

local function isNPCAlive(model)
    local humanoid = model:FindFirstChild("Humanoid")
    if humanoid then
        return humanoid.Health > 0
    end
    return true
end

local function getNPCType(model)
    local name = model.Name:lower()
    if name:match("civilian") or name:match("hostage") then
        return "hostage"
    else
        return "suspect"
    end
end

local function clearESP()
    for _, connection in pairs(_G.ESPFolder.Connections) do
        connection:Disconnect()
    end
    for _, drawings in pairs(_G.ESPFolder.Drawings) do
        for _, drawing in pairs(drawings) do
            if drawing.Remove then
                drawing:Remove()
            end
        end
    end
    table.clear(_G.ESPFolder.Connections)
    table.clear(_G.ESPFolder.Drawings)
end

local CombatTab = Window:CreateTab({
    Name = "Combat"
})

local VisualTab = Window:CreateTab({
    Name = "Visual"
})

local MiscTab = Window:CreateTab({
    Name = "Misc"
})

MiscTab:Keybind({
    Label = "Show / Hide GUI",
    Value = Enum.KeyCode.RightShift,
    Callback = function(_, NewKeybind)
        if Window then
            isWindowVisible = not isWindowVisible
            Window:SetVisible(isWindowVisible)
        end
    end
})

MiscTab:Label({
    Text = "Hotkeys"
})

MiscTab:Label({
    Text = "RightShift - Show / Hide GUI"
})

local ESPTab = Window:CreateTab({
    Name = "ESP"
})

-- ESP Tab
ESPTab:Label({
    Text = "ESP Settings"
})

ESPTab:Checkbox({
    Label = "ESP Enabled",
    Value = _G.ESPFolder.Settings.Enabled,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.Enabled = Value
    end
})

ESPTab:Checkbox({
    Label = "Show Health",
    Value = _G.ESPFolder.Settings.ShowHealth,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.ShowHealth = Value
    end
})

ESPTab:Checkbox({
    Label = "Show Names",
    Value = _G.ESPFolder.Settings.ShowNames,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.ShowNames = Value
    end
})

ESPTab:Checkbox({
    Label = "Show Distance",
    Value = _G.ESPFolder.Settings.ShowDistance,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.ShowDistance = Value
    end
})

ESPTab:SliderFloat({
    Label = "Box Thickness",
    Minimum = 1,
    Maximum = 5,
    Value = _G.ESPFolder.Settings.BoxThickness,
    Format = "Thickness: %.1f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.BoxThickness = Value
    end
})

ESPTab:SliderFloat({
    Label = "Text Size",
    Minimum = 12,
    Maximum = 24,
    Value = _G.ESPFolder.Settings.TextSize,
    Format = "Size: %.0f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.TextSize = Value
    end
})

ESPTab:Checkbox({
    Label = "Filled Boxes",
    Value = _G.ESPFolder.Settings.FilledBoxes,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.FilledBoxes = Value
    end
})

ESPTab:SliderFloat({
    Label = "Box Transparency",
    Minimum = 0,
    Maximum = 1,
    Value = _G.ESPFolder.Settings.BoxTransparency,
    Format = "Transparency: %.2f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.BoxTransparency = Value
    end
})

ESPTab:Checkbox({
    Label = "Show Skeleton",
    Value = _G.ESPFolder.Settings.ShowSkeleton,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.ShowSkeleton = Value
    end
})

ESPTab:InputColor3({
    Label = "Skeleton Color",
    Value = _G.ESPFolder.Settings.SkeletonColor,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.SkeletonColor = Value
        for _, drawings in pairs(_G.ESPFolder.Drawings) do
            if drawings.skeleton then
                for _, line in pairs(drawings.skeleton) do
                    line.Color = Value
                end
            end
        end
    end
})

ESPTab:SliderFloat({
    Label = "ESP Distance",
    Minimum = 0,
    Maximum = 5000,
    Value = _G.ESPFolder.Settings.MaxDistance,
    Format = "Distance: %.0f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.MaxDistance = Value
    end
})

-- Visual Tab
VisualTab:Label({
    Text = "Visual Settings"
})

VisualTab:Checkbox({
    Label = "Full Bright",
    Value = _G.ESPFolder.Settings.FullBright,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.FullBright = Value
        updateFullBright()
    end
})

VisualTab:SliderFloat({
    Label = "Brightness",
    Minimum = 1,
    Maximum = 10,
    Value = _G.ESPFolder.Settings.Brightness,
    Format = "Brightness: %.1f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.Brightness = Value
        if _G.ESPFolder.Settings.FullBright then
            Lighting.Brightness = Value
        end
    end
})

VisualTab:Checkbox({
    Label = "Disable Post Effects",
    Value = _G.ESPFolder.Settings.DisablePostEffects,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.DisablePostEffects = Value
        updatePostEffects()
    end
})

-- Combat Tab
CombatTab:Label({
    Text = "Aimbot Settings"
})

CombatTab:Checkbox({
    Label = "Vector Aim",
    Value = _G.ESPFolder.Settings.AimEnabled,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimEnabled = Value
        fovCircle.Visible = Value
    end
})

CombatTab:Dropdown({
    Label = "Aim Part",
    Items = {"Head", "UpperTorso", "HumanoidRootPart"},
    Value = _G.ESPFolder.Settings.AimPart,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimPart = Value
    end
})

CombatTab:Checkbox({
    Label = "Target Hostages",
    Value = _G.ESPFolder.Settings.AimAtHostages,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimAtHostages = Value
    end
})

CombatTab:Checkbox({
    Label = "Wall Check",
    Value = _G.ESPFolder.Settings.AimWallCheck,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimWallCheck = Value
    end
})

CombatTab:Checkbox({
    Label = "FOV Check",
    Value = _G.ESPFolder.Settings.AimVisibilityCheck,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimVisibilityCheck = Value
    end
})

CombatTab:Checkbox({
    Label = "Prediction",
    Value = _G.ESPFolder.Settings.AimPrediction,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimPrediction = Value
    end
})

CombatTab:SliderFloat({
    Label = "Prediction Amount",
    Minimum = 0.1,
    Maximum = 1.0,
    Value = _G.ESPFolder.Settings.AimPredictionAmount,
    Format = "Prediction: %.3f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimPredictionAmount = Value
    end
})

CombatTab:Dropdown({
    Label = "Aim Priority",
    Items = {"Distance", "Health", "Random"},
    Value = _G.ESPFolder.Settings.AimPriority,
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimPriority = Value
    end
})

CombatTab:SliderFloat({
    Label = "FOV",
    Minimum = 10,
    Maximum = 500,
    Value = _G.ESPFolder.Settings.AimFov,
    Format = "FOV: %.0f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimFov = Value
        fovCircle.Radius = Value
    end
})

CombatTab:SliderFloat({
    Label = "Smoothness",
    Minimum = 1,
    Maximum = 20,
    Value = _G.ESPFolder.Settings.AimSmoothness,
    Format = "Smoothness: %.1f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimSmoothness = Value
    end
})

CombatTab:SliderFloat({
    Label = "Min Distance",
    Minimum = 0,
    Maximum = 1000,
    Value = _G.ESPFolder.Settings.AimMinDistance,
    Format = "Min Distance: %.0f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimMinDistance = Value
    end
})

CombatTab:SliderFloat({
    Label = "Max Distance",
    Minimum = 0,
    Maximum = 1000,
    Value = _G.ESPFolder.Settings.AimMaxDistance,
    Format = "Max Distance: %.0f",
    Callback = function(self, Value)
        _G.ESPFolder.Settings.AimMaxDistance = Value
    end
})

CombatTab:Label({
    Text = "Aim Key: F"
})

local function createESP(suspect)
    local esp = Drawing.new("Square")
    local name = Drawing.new("Text")
    local distance = Drawing.new("Text")
    local healthBar = Drawing.new("Square")
    local healthText = Drawing.new("Text")
    local tracer = Drawing.new("Line")
    local npcType = getNPCType(suspect)
    
    local skeletonLines = {
        Head_Torso = Drawing.new("Line"),
        Torso_LeftArm = Drawing.new("Line"),
        Torso_RightArm = Drawing.new("Line"),
        Torso_LeftLeg = Drawing.new("Line"),
        Torso_RightLeg = Drawing.new("Line")
    }
    
    for _, line in pairs(skeletonLines) do
        line.Visible = false
        line.Color = _G.ESPFolder.Settings.SkeletonColor
        line.Thickness = 1
        line.Transparency = 1
    end
    
    esp.Visible = false
    esp.Color = npcType == "hostage" and _G.ESPFolder.Settings.HostageColor or _G.ESPFolder.Settings.SuspectColor
    esp.Thickness = _G.ESPFolder.Settings.BoxThickness
    esp.Transparency = 1
    esp.Filled = _G.ESPFolder.Settings.FilledBoxes
    
    name.Visible = false
    name.Color = _G.ESPFolder.Settings.TextColor
    name.Size = _G.ESPFolder.Settings.TextSize
    name.Center = true
    name.Outline = true
    
    distance.Visible = false
    distance.Color = _G.ESPFolder.Settings.TextColor
    distance.Size = _G.ESPFolder.Settings.TextSize - 2
    distance.Center = true
    distance.Outline = true
    
    healthBar.Visible = false
    healthBar.Color = _G.ESPFolder.Settings.HealthColor
    healthBar.Thickness = 1
    healthBar.Filled = true
    
    healthText.Visible = false
    healthText.Color = _G.ESPFolder.Settings.TextColor
    healthText.Size = _G.ESPFolder.Settings.TextSize - 2
    healthText.Center = true
    healthText.Outline = true
    
    tracer.Visible = false
    tracer.Color = _G.ESPFolder.Settings.TracerColor
    tracer.Thickness = 1
    
    _G.ESPFolder.Drawings[suspect] = {
        esp = esp,
        name = name,
        distance = distance,
        healthBar = healthBar,
        healthText = healthText,
        tracer = tracer,
        skeleton = skeletonLines,
        type = npcType
    }
    
    local lastUpdate = 0
    local updateInterval = 0.008  -- ~120 FPS update rate
    local lastDistance = 0
    
    local function updateESP()
        if not scriptRunning then return end
        
        local now = tick()
        if now - lastUpdate < updateInterval then return end
        lastUpdate = now
        
        if not _G.ESPFolder.Settings.Enabled or not suspect or not suspect:FindFirstChild("HumanoidRootPart") or not isNPCAlive(suspect) then
            esp.Visible = false
            name.Visible = false
            distance.Visible = false
            healthBar.Visible = false
            healthText.Visible = false
            tracer.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            return
        end
        
        local camera = workspace.CurrentCamera
        local player = Players.LocalPlayer
        local character = player.Character
        
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            esp.Visible = false
            name.Visible = false
            distance.Visible = false
            healthBar.Visible = false
            healthText.Visible = false
            tracer.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            return
        end
        
        -- Quick distance check before doing viewport calculations
        local dist = (character.HumanoidRootPart.Position - suspect.HumanoidRootPart.Position).Magnitude
        lastDistance = dist
        
        if dist > _G.ESPFolder.Settings.MaxDistance then
            esp.Visible = false
            name.Visible = false
            distance.Visible = false
            healthBar.Visible = false
            healthText.Visible = false
            tracer.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            return
        end
        
        local vector, onScreen = camera:WorldToViewportPoint(suspect.HumanoidRootPart.Position)
        local targetPosition = Vector2.new(vector.X, vector.Y)
        
        if not onScreen then
            esp.Visible = false
            name.Visible = false
            distance.Visible = false
            healthBar.Visible = false
            healthText.Visible = false
            tracer.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            return
        end
        
        if (npcType == "hostage" and not _G.ESPFolder.Settings.ShowHostages) or
           (npcType == "suspect" and not _G.ESPFolder.Settings.ShowSuspects) then
            esp.Visible = false
            name.Visible = false
            distance.Visible = false
            healthBar.Visible = false
            healthText.Visible = false
            tracer.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            return
        end
        
        local size = Vector3.new()
        local hrp = suspect:FindFirstChild("HumanoidRootPart")
        if hrp then
            local parts = {}
            for _, part in pairs(suspect:GetDescendants()) do
                if part:IsA("BasePart") then
                    table.insert(parts, part)
                end
            end
            
            local minX, minY, minZ = math.huge, math.huge, math.huge
            local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
            
            for _, part in pairs(parts) do
                local pos = part.Position
                local size = part.Size
                minX = math.min(minX, pos.X - size.X/2)
                minY = math.min(minY, pos.Y - size.Y/2)
                minZ = math.min(minZ, pos.Z - size.Z/2)
                maxX = math.max(maxX, pos.X + size.X/2)
                maxY = math.max(maxY, pos.Y + size.Y/2)
                maxZ = math.max(maxZ, pos.Z + size.Z/2)
            end
            
            size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
        end

        esp.Visible = true
        local boxSize = Vector2.new(
            math.clamp(math.max(size.X, size.Z) * 500 / vector.Z, 2, camera.ViewportSize.X / 4),
            math.clamp(size.Y * 500 / vector.Z, 2, camera.ViewportSize.Y / 3)
        )
        
        esp.Size = boxSize
        esp.Position = Vector2.new(
            math.clamp(targetPosition.X - boxSize.X/2, 0, camera.ViewportSize.X - boxSize.X),
            math.clamp(targetPosition.Y - boxSize.Y/2, 0, camera.ViewportSize.Y - boxSize.Y)
        )
        esp.Color = npcType == "hostage" and _G.ESPFolder.Settings.HostageColor or _G.ESPFolder.Settings.SuspectColor
        esp.Thickness = _G.ESPFolder.Settings.BoxThickness
        esp.Filled = _G.ESPFolder.Settings.FilledBoxes
        esp.Transparency = _G.ESPFolder.Settings.FilledBoxes and _G.ESPFolder.Settings.BoxTransparency or 1
        
        if _G.ESPFolder.Settings.ShowHealth then
            local humanoid = suspect:FindFirstChild("Humanoid")
            if humanoid then
                local health = humanoid.Health
                local maxHealth = humanoid.MaxHealth
                local healthPercentage = health / maxHealth
                
                healthText.Visible = true
                healthText.Text = string.format("%d/%d", health, maxHealth)
                healthText.Position = Vector2.new(
                    targetPosition.X,
                    esp.Position.Y - 20
                )
                
                healthBar.Visible = true
                healthBar.Size = Vector2.new(boxSize.X, 3)
                healthBar.Position = Vector2.new(
                    esp.Position.X,
                    esp.Position.Y - 10
                )
                healthBar.Color = Color3.new(1 - healthPercentage, healthPercentage, 0)
            else
                healthBar.Visible = false
                healthText.Visible = false
            end
        else
            healthBar.Visible = false
            healthText.Visible = false
        end
        
        if _G.ESPFolder.Settings.ShowNames then
            name.Visible = true
            name.Text = string.format("[%s] %s", npcType:upper(), suspect.Name)
            name.Position = Vector2.new(
                targetPosition.X,
                esp.Position.Y - 35
            )
            name.Size = _G.ESPFolder.Settings.TextSize
        else
            name.Visible = false
        end
        
        distance.Visible = _G.ESPFolder.Settings.ShowDistance
        distance.Text = string.format("%.1f m", dist)
        distance.Position = Vector2.new(targetPosition.X, targetPosition.Y + boxSize.Y / 2 + 5)
        distance.Color = _G.ESPFolder.Settings.TextColor
        distance.Size = _G.ESPFolder.Settings.TextSize - 2
        
        if _G.ESPFolder.Settings.ShowTracers then
            tracer.Visible = true
            tracer.From = 
                _G.ESPFolder.Settings.TracerOrigin == "Bottom" and Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y) or
                _G.ESPFolder.Settings.TracerOrigin == "Top" and Vector2.new(camera.ViewportSize.X / 2, 0) or
                _G.ESPFolder.Settings.TracerOrigin == "Mouse" and Vector2.new(game:GetService("UserInputService"):GetMouseLocation().X, game:GetService("UserInputService"):GetMouseLocation().Y)
            tracer.To = targetPosition
        else
            tracer.Visible = false
        end
        
        if _G.ESPFolder.Settings.ShowSkeleton then
            local function worldToScreen(position)
                local screenPos, onScreen = camera:WorldToViewportPoint(position)
                return Vector2.new(screenPos.X, screenPos.Y), onScreen
            end
            
            local function updateSkeletonLine(line, part1Name, part2Name)
                local part1 = suspect:FindFirstChild(part1Name)
                local part2 = suspect:FindFirstChild(part2Name)
                
                if part1 and part2 then
                    local pos1, onScreen1 = worldToScreen(part1.Position)
                    local pos2, onScreen2 = worldToScreen(part2.Position)
                    
                    if onScreen1 and onScreen2 then
                        line.Visible = true
                        line.From = pos1
                        line.To = pos2
                        line.Color = _G.ESPFolder.Settings.SkeletonColor
                        line.Thickness = 1.5
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end

            updateSkeletonLine(skeletonLines.Head_Torso, "Head", "Torso")
            updateSkeletonLine(skeletonLines.Torso_LeftArm, "Torso", "Left Arm")
            updateSkeletonLine(skeletonLines.Torso_RightArm, "Torso", "Right Arm")
            updateSkeletonLine(skeletonLines.Torso_LeftLeg, "Torso", "Left Leg")
            updateSkeletonLine(skeletonLines.Torso_RightLeg, "Torso", "Right Leg")
        else
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
        end
    end
    
    local connection = RunService.RenderStepped:Connect(updateESP)
    _G.ESPFolder.Connections[suspect] = connection
end

local function setupESP()
    clearESP()
    

    if not workspace:FindFirstChild("GAME") then
        print("Waiting for GAME folder...")
        workspace:WaitForChild("GAME", 10) 
    end
    
    if not workspace.GAME:FindFirstChild("Suspects") then
        print("Waiting for Suspects folder...")
        workspace.GAME:WaitForChild("Suspects", 10)
    end
    
    if not workspace:FindFirstChild("GAME") or not workspace.GAME:FindFirstChild("Suspects") then
        print("Required folders not found!")
        return
    end
    
    local suspects = workspace.GAME.Suspects:GetChildren()
    for _, suspect in ipairs(suspects) do
        if suspect:IsA("Model") then
            task.spawn(function()
                createESP(suspect)
            end)
        end
    end
end

local function autoReconnect()

    if not workspace:FindFirstChild("GAME") then
        workspace:WaitForChild("GAME", 10)
    end
    
    if workspace:FindFirstChild("GAME") then
        if not workspace.GAME:FindFirstChild("Suspects") then
            workspace.GAME:WaitForChild("Suspects", 10)
        end
        
        local gameConnection = workspace.GAME.DescendantAdded:Connect(function(descendant)
            if descendant.Parent and descendant.Parent.Name == "Suspects" then
                task.wait(1)
                setupESP()
            end
        end)
        table.insert(_G.ESPFolder.Connections, gameConnection)
    end
    
    local workspaceConnection = workspace.ChildAdded:Connect(function(child)
        if child.Name == "GAME" then
            if not child:FindFirstChild("Suspects") then
                child:WaitForChild("Suspects", 10)
            end
            task.wait(1)
            setupESP()
        end
    end)
    table.insert(_G.ESPFolder.Connections, workspaceConnection)
end

local function getClosestSuspect()
    if not _G.ESPFolder.Settings.AimEnabled then return nil end

    local closest = nil
    local shortestDistance = math.huge
    local camera = workspace.CurrentCamera
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local player = Players.LocalPlayer
    local character = player.Character
    
    if not character or not character:FindFirstChild("Head") then return nil end
    
    if not workspace:FindFirstChild("GAME") or not workspace.GAME:FindFirstChild("Suspects") then return nil end
    
    for _, suspect in pairs(workspace.GAME.Suspects:GetChildren()) do
        if suspect:IsA("Model") and suspect:FindFirstChild(_G.ESPFolder.Settings.AimPart) and suspect:FindFirstChild("Humanoid") and suspect.Humanoid.Health > 0 then
            local npcType = getNPCType(suspect)
            if npcType == "hostage" and not _G.ESPFolder.Settings.AimAtHostages then
                continue
            end
            
            local targetPart = suspect:FindFirstChild(_G.ESPFolder.Settings.AimPart)
            local pos = targetPart.Position
            
            if _G.ESPFolder.Settings.AimPrediction then
                local velocity = targetPart.Velocity
                pos = pos + (velocity * _G.ESPFolder.Settings.AimPredictionAmount)
            end
            
            local screenPos, onScreen = camera:WorldToViewportPoint(pos)
            
            if _G.ESPFolder.Settings.AimWallCheck then
                local rayOrigin = camera.CFrame.Position
                local rayDirection = (pos - rayOrigin).Unit
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {character, suspect}
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                
                local rayResult = workspace:Raycast(rayOrigin, rayDirection * (pos - rayOrigin).Magnitude, rayParams)
                if rayResult then
                    continue
                end
            end
            
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                local realDistance = (character.HumanoidRootPart.Position - suspect.HumanoidRootPart.Position).Magnitude
                
                if realDistance < _G.ESPFolder.Settings.AimMinDistance or realDistance > _G.ESPFolder.Settings.AimMaxDistance then
                    continue
                end
                
                if _G.ESPFolder.Settings.AimVisibilityCheck and distance > _G.ESPFolder.Settings.AimFov then
                    continue
                end
                
                if _G.ESPFolder.Settings.AimPriority == "Distance" then
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closest = suspect
                    end
                elseif _G.ESPFolder.Settings.AimPriority == "Health" then
                    local health = suspect.Humanoid.Health
                    if health > shortestDistance then
                        shortestDistance = health
                        closest = suspect
                    end
                elseif _G.ESPFolder.Settings.AimPriority == "Random" then
                    if math.random() > 0.5 then
                        closest = suspect
                        break
                    end
                end
            end
        end
    end
    
    return closest
end

local function moveMouseToTarget()
    if not scriptRunning or not _G.ESPFolder.Settings.AimEnabled then return end
    
    local target = getClosestSuspect()
    if not target then return end
    
    local camera = workspace.CurrentCamera
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local targetPart = target:FindFirstChild(_G.ESPFolder.Settings.AimPart)
    if not targetPart then return end
    
    local targetPos = targetPart.Position
    if _G.ESPFolder.Settings.AimPrediction then
        targetPos = targetPos + (targetPart.Velocity * _G.ESPFolder.Settings.AimPredictionAmount)
    end
    
    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    
    if onScreen then
        local targetPoint = Vector2.new(screenPos.X, screenPos.Y)
        local mouseDelta = (targetPoint - screenCenter) / _G.ESPFolder.Settings.AimSmoothness
        
        if mousemoverel then
            mousemoverel(mouseDelta.X, mouseDelta.Y)
        end
    end
end

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if not scriptRunning then return end
    if input.KeyCode == Enum.KeyCode.F then
        isAiming = false
    end
end)

RunService.RenderStepped:Connect(function()
    if not scriptRunning then return end
    if isAiming and _G.ESPFolder.Settings.AimEnabled then
        moveMouseToTarget()
    end
    updateFovCircle()
end)

task.spawn(function()
    updatePostEffects()
    autoReconnect()
    setupESP()
    updateFullBright()
end)

RunService.RenderStepped:Connect(function()
    if not scriptRunning then return end
    updateFovCircle()
end) 