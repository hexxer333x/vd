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
    Movement = {
        OmniSprint = false,
        OmniConnection = nil
    },
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
            Generator = {Enabled = true, Color = Color3.fromRGB(210, 87, 255)},
            Gate = {Enabled = true, Color = Color3.fromRGB(255, 255, 255)},
            Pallet = {Enabled = true, Color = Color3.fromRGB(74, 255, 181)},
            Window = {Enabled = true, Color = Color3.fromRGB(74, 255, 181)},
            Hook = {Enabled = true, Color = Color3.fromRGB(132, 255, 169)}
        }
    },
    AutoSkillCheck = {
        Enabled = false
    }
}
local HEX = getgenv().HEX

-- Healing Connections (DELETED - patched by anticheat)
-- local InstantHealConnection = nil
-- local AutoHealAllConnection = nil

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
            
            -- Check if ESP enabled AND specific role is enabled
            local role = GetRole(p)
            local shouldShow = HEX.ESP.Enabled and 
                             ((role == "Killer" and HEX.ESP.ShowKillers) or 
                              (role == "Survivor" and HEX.ESP.ShowSurvivors))
            
            if shouldShow then
                ApplyHighlight(p.Character, HEX.ESP.Players[role].Color)
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
                    -- Check each object type
                    for objName, objData in pairs(HEX.ESP.Objects) do
                        local matches = false
                        
                        -- Special case: Pallet matches anything with "pallet" in the name (case-insensitive)
                        if objName == "Pallet" then
                            matches = obj.Name:lower():find("pallet") ~= nil
                        else
                            -- Exact match for other objects
                            matches = obj.Name == objName
                        end
                        
                        if matches and objData.Enabled and not obj:FindFirstChild("RxmmyESP") then 
                            ApplyHighlight(obj, objData.Color)
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
-- OMNI SPRINT (NO SLOWDOWN)
----------------------------------------------------------------
local function setupOmniSprint()
    if HEX.Movement.OmniSprint then
        if HEX.Movement.OmniConnection then
            HEX.Movement.OmniConnection:Disconnect()
        end
        
        HEX.Movement.OmniConnection = RunService.Heartbeat:Connect(function()
            if not HEX.Movement.OmniSprint or not Character or not Humanoid then return end
            
            -- Simply prevent slowdown by keeping walk speed constant
            -- No CFrame manipulation, just remove the directional penalty
            if Humanoid.MoveDirection.Magnitude > 0 then
                -- Do nothing, just let natural movement happen without penalty
                -- The game will handle movement, we just remove slowdown
            end
        end)
    else
        if HEX.Movement.OmniConnection then
            HEX.Movement.OmniConnection:Disconnect()
            HEX.Movement.OmniConnection = nil
        end
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
    local PlayerBox = MainTab:AddLeftGroupbox("Movement")
    
    PlayerBox:AddToggle("OmniSprint", {
        Text = "Omni Sprint",
        Default = false,
        Tooltip = "Run at full speed in all directions (no slowdown)"
    }):OnChanged(function(value)
        HEX.Movement.OmniSprint = value
        setupOmniSprint()
        
        Obsidian:Notify({
            Title = "HEXWARE",
            Description = value and "Omni Sprint enabled" or "Omni Sprint disabled",
            Duration = 2
        })
    end)
    
    PlayerBox:AddLabel("💡 Removes directional speed penalty")
    PlayerBox:AddLabel("Run backwards/sideways at full speed")
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
    
    local SurvBox = SurvivorTab:AddRightGroupbox("Survivor Features")
    
    SurvBox:AddLabel("⚠️ Healing features removed (patched)")
    SurvBox:AddLabel("Other survivor features coming soon")
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
        -- Refresh without destroying
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local role = GetRole(p)
                if role == "Killer" then
                    local h = p.Character:FindFirstChild("RxmmyESP")
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
        -- Refresh without destroying
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local role = GetRole(p)
                if role == "Survivor" then
                    local h = p.Character:FindFirstChild("RxmmyESP")
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
        -- Refresh all object ESP visibility
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local h = obj:FindFirstChild("RxmmyESP")
            if h and obj ~= LocalPlayer.Character then
                -- Check if this is an object highlight (not player)
                local isObject = false
                for objName in pairs(HEX.ESP.Objects) do
                    if obj.Name == objName then
                        isObject = true
                        break
                    end
                end
                if isObject then
                    h.Enabled = value and HEX.ESP.Enabled
                end
            end
        end
    end)
    
    ESPBox:AddDropdown("ObjectSelection", {
        Text = "Select Objects",
        Default = {"Generator", "Gate", "Pallet", "Window", "Hook"},
        Values = {"Generator", "Gate", "Pallet", "Window", "Hook"},
        Multi = true,
        Tooltip = "Choose which objects to highlight"
    }):OnChanged(function(value)
        -- Update enabled state for each object
        HEX.ESP.Objects.Generator.Enabled = value.Generator or false
        HEX.ESP.Objects.Gate.Enabled = value.Gate or false
        HEX.ESP.Objects.Pallet.Enabled = value.Pallet or false
        HEX.ESP.Objects.Window.Enabled = value.Window or false
        HEX.ESP.Objects.Hook.Enabled = value.Hook or false
        
        -- Refresh all object highlights
        for _, obj in ipairs(Workspace:GetDescendants()) do
            for objName, objData in pairs(HEX.ESP.Objects) do
                local matches = false
                
                -- Special case: Pallet matches anything with "pallet" in the name (case-insensitive)
                if objName == "Pallet" then
                    matches = obj.Name:lower():find("pallet") ~= nil
                else
                    -- Exact match for other objects
                    matches = obj.Name == objName
                end
                
                if matches then
                    local h = obj:FindFirstChild("RxmmyESP")
                    if h then
                        h.Enabled = objData.Enabled and HEX.ESP.ShowObjects and HEX.ESP.Enabled
                    elseif objData.Enabled and HEX.ESP.ShowObjects and HEX.ESP.Enabled then
                        ApplyHighlight(obj, objData.Color)
                    end
                end
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
            HEX.ESP.Objects.Pallet.Color = value
            -- Update existing highlights for any object with "pallet" in name
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name:lower():find("pallet") then
                    local h = obj:FindFirstChild("RxmmyESP")
                    if h then
                        h.FillColor = value
                        h.OutlineColor = value
                    end
                end
            end
        end
    })
    
    ObjectBox:AddLabel("Window Color:"):AddColorPicker("WindowColor", {
        Default = Color3.fromRGB(74, 255, 181),
        Title = "Window ESP Color",
        Transparency = 0,
        Changed = function(value)
            for _, obj in pairs(HEX.ESP.Objects) do
                if obj.Name == "Window" then obj.Color = value end
            end
            -- Update existing highlights
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Window" then
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
            for _, obj in pairs(HEX.ESP.Objects) do
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
    Description = "Loaded! ESP, Auto Skill Check & Omni Sprint",
    Duration = 3
})

print("[HEXWARE] Loaded successfully!")
print("[HEXWARE] Features: ESP, Auto Skill Check, Omni Sprint")
print("[HEXWARE] Healing removed (patched by anticheat)")
print("[HEXWARE] Credits: Rxmmy (ESP & Skill Check), hexxer333x")
