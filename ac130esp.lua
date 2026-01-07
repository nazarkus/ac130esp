local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "AC130_ESP" then
        v:Destroy()
    end
end

local AC130ESPfolder = Instance.new("Folder")
AC130ESPfolder.Name = "AC130_ESP"
AC130ESPfolder.Parent = CoreGui

local trackedAC130 = {}
local lastUpdate = 0

local function getGunshipWorkspace()
    local gameSystems = workspace:FindFirstChild("Game Systems")
    if not gameSystems then return nil end
    return gameSystems:FindFirstChild("Gunship Workspace")
end

local function getHealthPercent(model)
    local humanoid = model:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
        return healthPercent
    end
    
    local healthValue, maxHealthValue = 100, 100
    
    for _, child in pairs(model:GetDescendants()) do
        if child:IsA("NumberValue") or child:IsA("IntValue") then
            if child.Name == "Health" or child.Name == "HP" then
                healthValue = child.Value
            elseif child.Name == "MaxHealth" then
                maxHealthValue = child.Value
            end
        end
    end
    
    if maxHealthValue > 0 then
        local healthPercent = math.floor((healthValue / maxHealthValue) * 100)
        return math.clamp(healthPercent, 0, 100)
    end
    
    return 100
end

local function formatDistance(distance)
    if distance >= 1000 then
        return string.format("%.1fkm", distance / 1000)
    else
        return string.format("%dm", math.floor(distance))
    end
end

local function findAllGunships()
    local gunshipWorkspace = getGunshipWorkspace()
    if not gunshipWorkspace then return {} end
    
    local gunships = {}
    
    for _, gunshipModel in pairs(gunshipWorkspace:GetChildren()) do
        if gunshipModel:IsA("Model") then
            local primaryPart = gunshipModel.PrimaryPart or gunshipModel:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                local healthPercent = getHealthPercent(gunshipModel)
                
                table.insert(gunships, {
                    model = gunshipModel,
                    name = gunshipModel.Name,
                    primaryPart = primaryPart,
                    isAC130 = gunshipModel.Name:find("AC-130") or gunshipModel.Name:find("AC130"),
                    healthPercent = healthPercent
                })
            end
        end
    end
    
    return gunships
end

local function createAC130ESP(gunshipData)
    if not gunshipData.model then return nil end
    
    local color = Color3.fromRGB(255, 100, 255)
    local displayName = gunshipData.name
    
    if gunshipData.isAC130 then
        color = Color3.fromRGB(255, 50, 50)
        displayName = "AC-130"
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "AC130_Highlight"
    highlight.Adornee = gunshipData.model
    highlight.FillColor = color
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = gunshipData.model
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AC130_Text"
    billboard.Adornee = gunshipData.primaryPart
    billboard.Size = UDim2.new(0, 200, 0, 75)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Parent = AC130ESPfolder
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = string.format("%s\n%d%%\n0m", displayName, gunshipData.healthPercent)
    textLabel.TextColor3 = color
    textLabel.TextStrokeTransparency = 0.3
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 16
    textLabel.TextWrapped = true
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.Parent = billboard
    
    return {
        highlight = highlight,
        billboard = billboard,
        textLabel = textLabel,
        model = gunshipData.model,
        name = gunshipData.name,
        displayName = displayName,
        isAC130 = gunshipData.isAC130,
        healthPercent = gunshipData.healthPercent,
        primaryPart = gunshipData.primaryPart,
        color = color
    }
end

local function updateAC130ESP(espData)
    if not espData.model or not espData.model.Parent then
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end
        return false
    end
    
    local healthPercent = getHealthPercent(espData.model)
    espData.healthPercent = healthPercent
    
    local distance = math.huge
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and espData.primaryPart then
        distance = (LocalPlayer.Character.PrimaryPart.Position - espData.primaryPart.Position).Magnitude
    end
    
    espData.textLabel.Text = string.format("%s\n%d%%\n%s", 
        espData.displayName, 
        healthPercent, 
        formatDistance(distance))
    
    if espData.isAC130 then
        if healthPercent < 30 then
            espData.textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            espData.highlight.FillColor = Color3.fromRGB(255, 50, 50)
        elseif healthPercent < 60 then
            espData.textLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
            espData.highlight.FillColor = Color3.fromRGB(255, 200, 50)
        else
            espData.textLabel.TextColor3 = espData.color
            espData.highlight.FillColor = espData.color
        end
    end
    
    if distance > 5000 then
        espData.highlight.FillTransparency = 0.6
    elseif distance > 3000 then
        espData.highlight.FillTransparency = 0.4
    else
        espData.highlight.FillTransparency = 0.2
    end
    
    return true
end

local function mainESP()
    if tick() - lastUpdate < 0.3 then return end
    lastUpdate = tick()
    
    for model, espData in pairs(trackedAC130) do
        if not model or not model.Parent then
            if espData.highlight then espData.highlight:Destroy() end
            if espData.billboard then espData.billboard:Destroy() end
            trackedAC130[model] = nil
        else
            updateAC130ESP(espData)
        end
    end
    
    local foundGunships = findAllGunships()
    
    for _, gunshipData in pairs(foundGunships) do
        if not trackedAC130[gunshipData.model] then
            local espData = createAC130ESP(gunshipData)
            if espData then
                trackedAC130[gunshipData.model] = espData
            end
        end
    end
end

local connection
local function startESP()
    if connection then
        connection:Disconnect()
    end
    
    connection = RunService.Heartbeat:Connect(function()
        pcall(mainESP)
    end)
end

wait(1)
startESP()

print("ac130 esp loaded")
