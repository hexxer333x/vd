--[[
    HEXWARE - Violence District
    Base Version - Clean UI Framework
]]

local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/ThemeManager.lua"))()

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
        ShowObjects = false,
        ShowKillers = false,
        ShowSurvivors = false,
        Players = {
            Killer = {Color = Color3.fromRGB(255, 93, 108)},
            Survivor = {Color = Color3.fromRGB(64, 224, 255)}
        },
        Objects = {
            {Name = "Generator", Color = Color3.fromRGB(210, 87, 255)},
            {Name = "Gate", Color = Color3.fromRGB(255, 255, 255)},
            {Name = "Palletwrong", Color = Color3.fromRGB(74, 255, 181)},
            {Name = "Pallet", Color = Color3.fromRGB(74, 255, 181)},
            {Name = "Window", Color = Color3.fromRGB(74, 255, 181)},
            {Name = "Hook", Color = Color3.fromRGB(132, 255, 169)}
        }
    },
    AutoSkillCheck = {
        Enabled = false
    },
    Healing = {
        InstantHealSelf = false,
        AutoHealAll = false
    }
}
local HEX = getgenv().HEX

-- Healing Connections
local InstantHealConnection = nil
local AutoHealAllConnection = nil

----------------------------------------------------------------
-- ESP SYSTEM
----------------------------------------------------------------
local function ApplyHighlight(obj, color)
    if not obj or obj == LocalPlayer.Character or obj:FindFirstChild("RxmmyESP") then return end
    
    local h = Instance.new("Highlight")
    h.Name = "RxmmyESP"
    h.Adornee = obj
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Enabled = HEX.ESP.Enabled
    h.Parent = obj
end

local function GetRole(p)
    if p.Team then
        local teamName = p.Team.Name:lower()
        
        if teamName:find("killer") then 
            return "Killer" 
        elseif teamName:find("survivor") then
            return "Survivor"
        end
    end
    return nil
end

local function SetupPlayerESP(p)
    if p == LocalPlayer then return end
    
    local function Refresh()
        if p.Character then
            local existing = p.Character:FindFirstChild("RxmmyESP")
            if existing then existing:Destroy() end
            task.wait(0.1)
            
            if HEX.ESP.Enabled then
                local role = GetRole(p)
                if role == "Killer" and HEX.ESP.ShowKillers then
                    ApplyHighlight(p.Character, HEX.ESP.Players.Killer.Color)
                elseif role == "Survivor" and HEX.ESP.ShowSurvivors then
                    ApplyHighlight(p.Character, HEX.ESP.Players.Survivor.Color)
                end
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
            if HEX.ESP.Enabled and HEX.ESP.ShowObjects then
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

----------------------------------------------------------------
-- HEALING SYSTEM
----------------------------------------------------------------
local function doSelfHealTrue()
    local char = LocalPlayer.Character
    if not char then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function() healRemote:FireServer(hrp, true) end)
end

local function doSelfHealFalse()
    local char = LocalPlayer.Character
    if not char then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function() healRemote:FireServer(hrp, false) end)
end

local function doOthersHealTrue(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    pcall(function() healRemote:FireServer(targetHRP, true) end)
end

local function doOthersHealFalse(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    pcall(function() healRemote:FireServer(targetHRP, false) end)
end

local function setInstantHealSelf(v)
    HEX.Healing.InstantHealSelf = v
    
    if v then
        local healActive = false
        if InstantHealConnection then InstantHealConnection:Disconnect() end
        InstantHealConnection = RunService.Heartbeat:Connect(function()
            if not HEX.Healing.InstantHealSelf then return end
            
            local myChar = LocalPlayer.Character
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if not myHum then return end
            
            if myHum.Health >= myHum.MaxHealth * 0.9 then 
                -- Auto stop heal when HP is full
                if healActive then
                    healActive = false
                    doSelfHealFalse()
                end
                return 
            end
            
            -- Check if game cancelled our heal (e.g. player moved)
            if healActive then
                local checkScript = myChar:FindFirstChild("CheckInterractable")
                if checkScript and not checkScript:GetAttribute("isHealing") then
                    -- Game cancelled our heal, reset so we can restart
                    healActive = false
                end
            end
            
            -- Start heal (or restart after being cancelled)
            if not healActive then
                healActive = true
                doSelfHealTrue()
            end
        end)
    else
        if InstantHealConnection then InstantHealConnection:Disconnect(); InstantHealConnection = nil end
        -- Send stop heal just in case
        pcall(doSelfHealFalse)
    end
end

local function setAutoHealAll(v)
    HEX.Healing.AutoHealAll = v
    
    if v then
        local activeHeals = {} -- [player] = true if we're currently healing them
        if AutoHealAllConnection then AutoHealAllConnection:Disconnect() end
        AutoHealAllConnection = RunService.Heartbeat:Connect(function()
            if not HEX.Healing.AutoHealAll then return end
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.9 and hrp then
                        -- Check if game cancelled our heal on this player (e.g. we or they moved)
                        if activeHeals[player] then
                            local myChar = LocalPlayer.Character
                            local checkScript = myChar and myChar:FindFirstChild("CheckInterractable")
                            if checkScript and not checkScript:GetAttribute("isHealing") then
                                activeHeals[player] = nil
                            end
                        end
                        -- Start healing this player if not already
                        if not activeHeals[player] then
                            activeHeals[player] = true
                            doOthersHealTrue(player)
                        end
                    else
                        -- Stop healing if HP is full or dead
                        if activeHeals[player] then
                            activeHeals[player] = nil
                            doOthersHealFalse(player)
                        end
                    end
                else
                    -- Player left or no character
                    if activeHeals[player] then
                        activeHeals[player] = nil
                        pcall(function() doOthersHealFalse(player) end)
                    end
                end
            end
        end)
    else
        if AutoHealAllConnection then AutoHealAllConnection:Disconnect(); AutoHealAllConnection = nil end
    end
end

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
    
    HealBox:AddToggle("InstantHealSelf", {
        Text = "Instant Heal Self",
        Default = false,
        Tooltip = "Automatically heal yourself instantly when injured"
    }):OnChanged(function(value)
        setInstantHealSelf(value)
        Obsidian:Notify({
            Title = "HEXWARE",
            Description = value and "Instant Heal Self enabled" or "Instant Heal Self disabled",
            Duration = 2
        })
    end)
    
    HealBox:AddToggle("AutoHealAll", {
        Text = "Auto Heal All",
        Default = false,
        Tooltip = "Automatically heal all nearby injured players"
    }):OnChanged(function(value)
        setAutoHealAll(value)
        Obsidian:Notify({
            Title = "HEXWARE",
            Description = value and "Auto Heal All enabled" or "Auto Heal All disabled",
            Duration = 2
        })
    end)
    
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
        Tooltip = "Master toggle - enables all ESP types"
    }):OnChanged(function(value)
        ToggleESP(value)
        Obsidian:Notify({
            Title = "HEXWARE",
            Description = value and "ESP enabled" or "ESP disabled",
            Duration = 2
        })
    end)
    
    ESPBox:AddDivider()
    
    ESPBox:AddToggle("ShowKillers", {
        Text = "Killer ESP",
        Default = false,
        Tooltip = "Highlight killer players"
    }):OnChanged(function(value)
        HEX.ESP.ShowKillers = value
        -- Just update visibility, no destroy/recreate
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("RxmmyESP")
                local role = GetRole(p)
                if role == "Killer" then
                    if h then
                        h.Enabled = value and HEX.ESP.Enabled
                    elseif value and HEX.ESP.Enabled then
                        ApplyHighlight(p.Character, HEX.ESP.Players.Killer.Color)
                    end
                end
            end
        end
    end)
    
    ESPBox:AddLabel("Killer Color:"):AddColorPicker("KillerColor", {
        Default = HEX.ESP.Players.Killer.Color,
        Title = "Killer ESP Color",
        Transparency = nil,
        Changed = function(value)
            HEX.ESP.Players.Killer.Color = value
            -- Update all killer highlights in real-time
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local role = GetRole(p)
                    if role == "Killer" then
                        local h = p.Character:FindFirstChild("RxmmyESP")
                        if h then
                            h.FillColor = value
                            h.OutlineColor = value
                        end
                    end
                end
            end
        end
    })
    
    ESPBox:AddToggle("ShowSurvivors", {
        Text = "Survivor ESP",
        Default = false,
        Tooltip = "Highlight survivor players"
    }):OnChanged(function(value)
        HEX.ESP.ShowSurvivors = value
        -- Just update visibility, no destroy/recreate
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("RxmmyESP")
                local role = GetRole(p)
                if role == "Survivor" then
                    if h then
                        h.Enabled = value and HEX.ESP.Enabled
                    elseif value and HEX.ESP.Enabled then
                        ApplyHighlight(p.Character, HEX.ESP.Players.Survivor.Color)
                    end
                end
            end
        end
    end)
    
    ESPBox:AddLabel("Survivor Color:"):AddColorPicker("SurvivorColor", {
        Default = HEX.ESP.Players.Survivor.Color,
        Title = "Survivor ESP Color",
        Transparency = 0,
        Changed = function(value)
            HEX.ESP.Players.Survivor.Color = value
            -- Update all survivor highlights in real-time
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local role = GetRole(p)
                    if role == "Survivor" then
                        local h = p.Character:FindFirstChild("RxmmyESP")
                        if h then
                            h.FillColor = value
                            h.OutlineColor = value
                        end
                    end
                end
            end
        end
    })
    
    ESPBox:AddToggle("ShowObjects", {
        Text = "Object ESP",
        Default = false,
        Tooltip = "Highlight objects (generators, gates, etc)"
    }):OnChanged(function(value)
        HEX.ESP.ShowObjects = value
        -- Refresh all object ESP
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local h = obj:FindFirstChild("RxmmyESP")
            if h and obj ~= LocalPlayer.Character and not obj:IsA("Model") then
                h.Enabled = value and HEX.ESP.Enabled
            end
        end
    end)
    
    local ObjectBox = VisualTab:AddRightGroupbox("Object Colors")
    
    ObjectBox:AddLabel("Generator Color:"):AddColorPicker("GeneratorColor", {
        Default = Color3.fromRGB(210, 87, 255),
        Title = "Generator ESP Color",
        Transparency = 0,
        Changed = function(value)
            for _, obj in ipairs(HEX.ESP.Objects) do
                if obj.Name == "Generator" then obj.Color = value end
            end
            -- Update existing highlights
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Generator" then
                    local h = obj:FindFirstChild("RxmmyESP")
                    if h then
                        h.FillColor = value
                        h.OutlineColor = value
                    end
                end
            end
        end
    })
    
    ObjectBox:AddLabel("Gate Color:"):AddColorPicker("GateColor", {
        Default = Color3.fromRGB(255, 255, 255),
        Title = "Gate ESP Color",
        Transparency = 0,
        Changed = function(value)
            for _, obj in ipairs(HEX.ESP.Objects) do
                if obj.Name == "Gate" then obj.Color = value end
            end
            -- Update existing highlights
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Gate" then
                    local h = obj:FindFirstChild("RxmmyESP")
                    if h then
                        h.FillColor = value
                        h.OutlineColor = value
                    end
                end
            end
        end
    })
    
    ObjectBox:AddLabel("Pallet Color:"):AddColorPicker("PalletColor", {
        Default = Color3.fromRGB(74, 255, 181),
        Title = "Pallet ESP Color",
        Transparency = nil,
        Changed = function(value)
            for _, obj in ipairs(HEX.ESP.Objects) do
                if obj.Name == "Palletwrong" or obj.Name == "Pallet" then 
                    obj.Color = value 
                end
            end
            -- Update existing highlights
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Palletwrong" or obj.Name == "Pallet" then
                    local h = obj:FindFirstChild("RxmmyESP")
                    if h then
                        h.FillColor = value
                        h.OutlineColor = value
                    end
                end
            end
        end
    })
    
    ObjectBox:AddLabel("Hook Color:"):AddColorPicker("HookColor", {
        Default = Color3.fromRGB(132, 255, 169),
        Title = "Hook ESP Color",
        Transparency = 0,
        Changed = function(value)
            for _, obj in ipairs(HEX.ESP.Objects) do
                if obj.Name == "Hook" then obj.Color = value end
            end
            -- Update existing highlights
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Hook" then
                    local h = obj:FindFirstChild("RxmmyESP")
                    if h then
                        h.FillColor = value
                        h.OutlineColor = value
                    end
                end
            end
        end
    })
end

-- Misc Tab  
do
    local MiscBox = MiscTab:AddLeftGroupbox("UI Settings")
    
    MiscBox:AddButton({
        Text = "Unload UI",
        Func = function()
            Obsidian:Unload()
        end,
        DoubleClick = true,
        Tooltip = "Double-click to unload the UI"
    })
    
    MiscBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
        Default = "RightControl",
        NoUI = true,
        Text = "Menu keybind"
    })
end

-- Initialize SaveManager and ThemeManager
pcall(function()
    ThemeManager:SetLibrary(Obsidian)
    SaveManager:SetLibrary(Obsidian)
    SaveManager:SetFolder("hexware/violence-district")
    
    -- Add Configuration section
    SaveManager:BuildConfigSection(MiscTab)
    
    -- Add Theme Manager section
    ThemeManager:ApplyToTab(MiscTab)
    
    -- Load autoload config
    task.spawn(function()
        task.wait(1)
        pcall(function()
            SaveManager:LoadAutoloadConfig()
        end)
    end)
end)

Obsidian:Notify({
    Title = "HEXWARE",
    Description = "Loaded with ESP, Auto Skill Check & Healing!",
    Duration = 3
})

print("[HEXWARE] Loaded successfully!")
print("[HEXWARE] Features: ESP, Auto Skill Check, Instant Heal, Auto Heal All")
print("[HEXWARE] Credits: Rxmmy (ESP & Skill Check)")
