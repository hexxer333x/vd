--[[
    HEXWARE - Violence District
    Base Version - Clean UI Framework
]]

local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/Library.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
end)

-- Config
getgenv().HEX = getgenv().HEX or {
    ESP = {
        Enabled = false,
        Players = {
            Killer = {Color = Color3.fromRGB(255, 93, 108)},
            Survivor = {Color = Color3.fromRGB(64, 224, 255)}
        },
        Objects = {
            {Name = "Generator", Color = Color3.fromRGB(210, 87, 255)},
            {Name = "Gate", Color = Color3.fromRGB(255, 255, 255)},
            {Name = "Palletwrong", Color = Color3.fromRGB(74, 255, 181)},
            {Name = "Window", Color = Color3.fromRGB(74, 255, 181)},
            {Name = "Hook", Color = Color3.fromRGB(132, 255, 169)}
        }
    },
    AutoSkillCheck = {
        Enabled = false
    }
}
local HEX = getgenv().HEX

----------------------------------------------------------------
-- ESP SYSTEM
----------------------------------------------------------------
local function ApplyHighlight(obj, color)
    if not obj or obj == LocalPlayer.Character or obj:FindFirstChild("RxmmyESP") then return end
    
    local h = Instance.new("Highlight")
    h.Name = "RxmmyESP"
    h.Adornee = obj
    h.FillColor = color
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = 0.7
    h.OutlineTransparency = 0.2
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Enabled = HEX.ESP.Enabled
    h.Parent = obj
end

local function GetRole(p)
    if p.Team and LocalPlayer.Team then
        local teamName = p.Team.Name:lower()
        local myTeam = LocalPlayer.Team.Name:lower()

        if teamName:find("killer") or teamName:find("murderer") or teamName:find("hunter") or teamName:find("slasher") or teamName:find("beast") then 
            return "Killer" 
        end

        if myTeam:find("survivor") and teamName ~= myTeam then
            return "Killer"
        end
    end
    return "Survivor"
end

local function SetupPlayerESP(p)
    if p == LocalPlayer then return end
    
    local function Refresh()
        if p.Character then
            local existing = p.Character:FindFirstChild("RxmmyESP")
            if existing then existing:Destroy() end
            task.wait(0.1)
            if HEX.ESP.Enabled then
                ApplyHighlight(p.Character, HEX.ESP.Players[GetRole(p)].Color)
            end
        end
    end

    p.CharacterAdded:Connect(Refresh)
    p:GetPropertyChangedSignal("Team"):Connect(Refresh)
    Refresh()
end

local function SetupObjectESP()
    task.spawn(function()
        while true do
            if HEX.ESP.Enabled then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    for _, data in ipairs(HEX.ESP.Objects) do
                        if obj.Name == data.Name and not obj:FindFirstChild("RxmmyESP") then 
                            ApplyHighlight(obj, data.Color)
                        end
                    end
                end
            end
            task.wait(5)
        end
    end)
end

local function ToggleESP(enabled)
    HEX.ESP.Enabled = enabled
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local h = obj:FindFirstChild("RxmmyESP")
        if h then h.Enabled = enabled end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local h = p.Character:FindFirstChild("RxmmyESP")
            if h then h.Enabled = enabled end
        end
    end
end

----------------------------------------------------------------
-- AUTO SKILL CHECK
----------------------------------------------------------------
local SkillCheckConnection = nil

local function StartSkillCheckLogic()
    local function ConnectUI()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        local CheckGui = PlayerGui:WaitForChild("SkillCheckPromptGui", 10)
        if not CheckGui then return end
        
        local Check = CheckGui:WaitForChild("Check")
        local Line = Check:WaitForChild("Line")
        local Goal = Check:WaitForChild("Goal")
        local HeartbeatConn = nil

        Check:GetPropertyChangedSignal("Visible"):Connect(function()
            if Check.Visible and HEX.AutoSkillCheck.Enabled and LocalPlayer.Team and LocalPlayer.Team.Name:lower():find("survivor") then
                if HeartbeatConn then HeartbeatConn:Disconnect() end
                
                HeartbeatConn = RunService.Stepped:Connect(function()
                    if not Check.Visible then 
                        if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
                        return 
                    end

                    if not Line or not Goal or not Line.Parent or not Goal.Parent then return end

                    local lr, gr = Line.Rotation % 360, Goal.Rotation % 360
                    local gs, ge = (gr + 104) % 360, (gr + 114) % 360
                    local isInside = (gs > ge) and (lr >= gs or lr <= ge) or (lr >= gs and lr <= ge)

                    if isInside then
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
                    end
                end)
            elseif HeartbeatConn then
                HeartbeatConn:Disconnect(); HeartbeatConn = nil
            end
        end)
    end

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if HEX.AutoSkillCheck.Enabled then
            ConnectUI()
        end
    end)
    
    if HEX.AutoSkillCheck.Enabled then
        ConnectUI()
    end
end

-- Initialize ESP
for _, p in ipairs(Players:GetPlayers()) do 
    SetupPlayerESP(p) 
end
Players.PlayerAdded:Connect(SetupPlayerESP)
SetupObjectESP()

-- Create Window
local Window = Obsidian:CreateWindow({
    Title = "HEXWARE",
    SubTitle = "Violence District",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Create Tabs
local MainTab = Window:AddTab({ Name = "Main", Icon = "lucide:cpu" })
local SurvivorTab = Window:AddTab({ Name = "Survivor", Icon = "lucide:user" })
local KillerTab = Window:AddTab({ Name = "Killer", Icon = "lucide:skull" })
local VisualTab = Window:AddTab({ Name = "Visual", Icon = "lucide:eye" })
local MiscTab = Window:AddTab({ Name = "Misc", Icon = "lucide:settings" })

-- Main Tab
do
    local PlayerBox = MainTab:AddLeftGroupbox("Player")
    
    PlayerBox:AddLabel("Movement features will be added here")
end

-- Survivor Tab
do
    local GenBox = SurvivorTab:AddLeftGroupbox("Generator")
    
    GenBox:AddToggle("AutoSkillCheck", {
        Text = "Auto Skill Check",
        Default = false,
        Tooltip = "Automatically hit skill checks perfectly"
    }):OnChanged(function(value)
        HEX.AutoSkillCheck.Enabled = value
        if value then
            StartSkillCheckLogic()
            Obsidian:Notify({
                Title = "HEXWARE",
                Description = "Auto Skill Check enabled",
                Duration = 2
            })
        else
            Obsidian:Notify({
                Title = "HEXWARE",
                Description = "Auto Skill Check disabled",
                Duration = 2
            })
        end
    end)
    
    GenBox:AddLabel("Generator features will be added here")
    
    local HealBox = SurvivorTab:AddLeftGroupbox("Healing")
    
    HealBox:AddLabel("Healing features will be added here")
    
    local SurvBox = SurvivorTab:AddRightGroupbox("Survivor Features")
    
    SurvBox:AddLabel("Survivor features will be added here")
end

-- Killer Tab
do
    local KillerBox = KillerTab:AddLeftGroupbox("Killer Features")
    
    KillerBox:AddLabel("Killer features will be added here")
end

-- Visual Tab
do
    local ESPBox = VisualTab:AddLeftGroupbox("ESP")
    
    ESPBox:AddToggle("ESPMaster", {
        Text = "Enable ESP",
        Default = false,
        Tooltip = "Toggle ESP highlights for players and objects"
    }):OnChanged(function(value)
        ToggleESP(value)
        Obsidian:Notify({
            Title = "HEXWARE",
            Description = value and "ESP enabled" or "ESP disabled",
            Duration = 2
        })
    end)
    
    ESPBox:AddDivider()
    ESPBox:AddLabel("Player ESP")
    
    ESPBox:AddLabel("Killer Color:"):AddColorPicker("KillerColor", {
        Default = HEX.ESP.Players.Killer.Color,
        Title = "Killer ESP Color"
    }):OnChanged(function(value)
        HEX.ESP.Players.Killer.Color = value
    end)
    
    ESPBox:AddLabel("Survivor Color:"):AddColorPicker("SurvivorColor", {
        Default = HEX.ESP.Players.Survivor.Color,
        Title = "Survivor ESP Color"
    }):OnChanged(function(value)
        HEX.ESP.Players.Survivor.Color = value
    end)
    
    local ObjectBox = VisualTab:AddRightGroupbox("Object ESP")
    
    ObjectBox:AddLabel("Generator Color:"):AddColorPicker("GeneratorColor", {
        Default = Color3.fromRGB(210, 87, 255),
        Title = "Generator ESP Color"
    }):OnChanged(function(value)
        for _, obj in ipairs(HEX.ESP.Objects) do
            if obj.Name == "Generator" then obj.Color = value end
        end
    end)
    
    ObjectBox:AddLabel("Gate Color:"):AddColorPicker("GateColor", {
        Default = Color3.fromRGB(255, 255, 255),
        Title = "Gate ESP Color"
    }):OnChanged(function(value)
        for _, obj in ipairs(HEX.ESP.Objects) do
            if obj.Name == "Gate" then obj.Color = value end
        end
    end)
    
    ObjectBox:AddLabel("Pallet Color:"):AddColorPicker("PalletColor", {
        Default = Color3.fromRGB(74, 255, 181),
        Title = "Pallet ESP Color"
    }):OnChanged(function(value)
        for _, obj in ipairs(HEX.ESP.Objects) do
            if obj.Name == "Palletwrong" then obj.Color = value end
        end
    end)
    
    ObjectBox:AddLabel("Hook Color:"):AddColorPicker("HookColor", {
        Default = Color3.fromRGB(132, 255, 169),
        Title = "Hook ESP Color"
    }):OnChanged(function(value)
        for _, obj in ipairs(HEX.ESP.Objects) do
            if obj.Name == "Hook" then obj.Color = value end
        end
    end)
end

-- Misc Tab
do
    local MiscBox = MiscTab:AddLeftGroupbox("Miscellaneous")
    
    MiscBox:AddLabel("Misc features will be added here")
end

Obsidian:Notify({
    Title = "HEXWARE",
    Description = "Loaded with ESP & Auto Skill Check!",
    Duration = 3
})

print("[HEXWARE] Loaded successfully!")
print("[HEXWARE] Features: ESP, Auto Skill Check")
print("[HEXWARE] Credits: Rxmmy (ESP & Skill Check)")
