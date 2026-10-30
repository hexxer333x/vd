--[[
    HEXWARE - Violence District
    Premium Script by hexxer333x
    Full Featured Version
]]

-- Загрузка библиотек
local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/hexxer333x/obsidian/main/ThemeManager.lua"))()

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Локальные переменные
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Проверка мобильной платформы
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Обновление персонажа при респавне
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
end)

-- Сохранение оригинальных значений
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

-- Config
getgenv().HEX = getgenv().HEX or {
    -- Generator / Healing
    AutoSkillcheck = false,
    AutoSkillcheckMode = "Normal",
    InstantHealSelf = false,
    AutoHealAll = false,
    
    -- Movement
    Speed = false,
    SpeedValue = 16,
    Jump = false,
    JumpValue = 50,
    InfiniteJump = false,
    Noclip = false,
    
    -- Visual
    Fullbright = false,
    NoFog = false,
    WeatherTheme = "Default",
    
    -- Combat
    AutoAttack = false,
    AttackRange = 12,
    HitboxEnabled = false,
    HitboxSize = 15,
    
    -- Survivor
    FleeKiller = false,
    FleeDistance = 40,
    AutoParry = false,
    ParryDistance = 8,
    AntiKnock = false,
    
    -- Killer
    AutoHook = false,
    DestroyPallets = false,
    NoPalletStun = false,
    NoSlowdown = false,
    
    -- Camera
    FOVEnabled = false,
    FOV = 90,
    ThirdPerson = false,
    
    -- Misc
    AntiAFK = false,
    AntiFallDamage = false,
}

local HEX = getgenv().HEX

-- Auto Skillcheck система
local AutoSkill = {
    LastGoalRotation = nil,
    HasClickedThisGoal = false,
    LastLineRotation = nil,
    LastTick = nil,
    WasActive = false,
    PerfectLastGoalRotation = nil,
    PerfectHasClickedThisGoal = false,
    PerfectLastLineRotation = nil,
    PerfectLastTick = nil,
    PerfectWasActive = false,
    InstantHasClicked = false,
    InstantRotationConnection = nil,
}

-- =====================================================
-- AUTO SKILLCHECK FUNCTIONS
-- =====================================================

function VD_PressSkill()
    if isMobile then
        local btn = PlayerGui:FindFirstChild("check", true)
        if btn and btn:IsA("GuiObject") then
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local x = pos.X + (size.X / 2) + inset.X
            local y = pos.Y + (size.Y / 2) + inset.Y
            pcall(function() VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.Begin.Value, x, y) end)
            task.wait(0.01)
            pcall(function() VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.End.Value, x, y) end)
        end
    else
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
        task.wait(0.01)
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
    end
end

function VD_GetSkillCheck()
    for _, guiName in ipairs({ "SkillCheckPromptGui", "SkillCheckPromptGui-con" }) do
        local gui = PlayerGui:FindFirstChild(guiName, true)
        if gui then
            local check = gui:FindFirstChild("Check", true)
            if check and check.Visible then
                local line = check:FindFirstChild("Line", true)
                local goal = check:FindFirstChild("Goal", true)
                if line and goal then return line, goal end
            end
        end
    end
end

function VD_AngularDelta(from, to)
    local d = to - from
    if d > 180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

function VD_CrossedZone(prevLr, lr, startPos, endPos)
    local function inZone(r)
        if startPos > endPos then
            return r >= startPos or r <= endPos
        end
        return r >= startPos and r <= endPos
    end
    if inZone(lr) then return true end
    if prevLr == nil then return false end
    local delta = VD_AngularDelta(prevLr, lr)
    local steps = math.abs(math.floor(delta))
    if steps < 2 then return false end
    local stepSize = delta / steps
    for i = 1, steps do
        if inZone((prevLr + stepSize * i) % 360) then return true end
    end
    return false
end

function VD_NormalSkillcheckUpdate()
    local line, goal = VD_GetSkillCheck()
    if not (line and goal) then
        AutoSkill.LastGoalRotation = nil
        AutoSkill.HasClickedThisGoal = false
        AutoSkill.LastLineRotation = nil
        AutoSkill.LastTick = nil
        AutoSkill.WasActive = false
        return
    end

    local lr = line.Rotation % 360
    local gr = goal.Rotation % 360
    local now = os.clock()
    if not AutoSkill.WasActive then
        AutoSkill.WasActive = true
        AutoSkill.HasClickedThisGoal = false
        AutoSkill.LastGoalRotation = gr
        AutoSkill.LastLineRotation = lr
        AutoSkill.LastTick = now
        return
    end
    if AutoSkill.LastGoalRotation and math.abs(VD_AngularDelta(AutoSkill.LastGoalRotation, gr)) > 5 then
        AutoSkill.HasClickedThisGoal = false
        AutoSkill.LastLineRotation = nil
        AutoSkill.LastTick = nil
    end
    AutoSkill.LastGoalRotation = gr
    if AutoSkill.HasClickedThisGoal then
        AutoSkill.LastLineRotation = lr
        AutoSkill.LastTick = now
        return
    end
    if AutoSkill.LastLineRotation and AutoSkill.LastTick then
        local dt = now - AutoSkill.LastTick
        if dt > 0 then
            local lineSpeed = VD_AngularDelta(AutoSkill.LastLineRotation, lr) / dt
            local predicted = (lr + lineSpeed * dt * 0) % 360
            if VD_CrossedZone(AutoSkill.LastLineRotation, predicted, (gr + 104) % 360, (gr + 109) % 360) then
                AutoSkill.HasClickedThisGoal = true
                task.spawn(function()
                    task.wait(0.03)
                    VD_PressSkill()
                end)
            end
        end
    end
    AutoSkill.LastLineRotation = lr
    AutoSkill.LastTick = now
end

function VD_PerfectSkillcheckUpdate()
    local line, goal = VD_GetSkillCheck()
    if not (line and goal) then
        AutoSkill.PerfectLastGoalRotation = nil
        AutoSkill.PerfectHasClickedThisGoal = false
        AutoSkill.PerfectLastLineRotation = nil
        AutoSkill.PerfectLastTick = nil
        AutoSkill.PerfectWasActive = false
        return
    end

    local lr = line.Rotation % 360
    local gr = goal.Rotation % 360
    local now = os.clock()
    if not AutoSkill.PerfectWasActive then
        AutoSkill.PerfectWasActive = true
        AutoSkill.PerfectHasClickedThisGoal = false
        AutoSkill.PerfectLastGoalRotation = gr
        AutoSkill.PerfectLastLineRotation = lr
        AutoSkill.PerfectLastTick = now
        return
    end
    if AutoSkill.PerfectLastGoalRotation and math.abs(VD_AngularDelta(AutoSkill.PerfectLastGoalRotation, gr)) > 5 then
        AutoSkill.PerfectHasClickedThisGoal = false
        AutoSkill.PerfectLastLineRotation = nil
        AutoSkill.PerfectLastTick = nil
    end
    AutoSkill.PerfectLastGoalRotation = gr
    if AutoSkill.PerfectHasClickedThisGoal then
        AutoSkill.PerfectLastLineRotation = lr
        AutoSkill.PerfectLastTick = now
        return
    end
    if AutoSkill.PerfectLastLineRotation and AutoSkill.PerfectLastTick then
        local dt = now - AutoSkill.PerfectLastTick
        if dt > 0 then
            local lineSpeed = VD_AngularDelta(AutoSkill.PerfectLastLineRotation, lr) / dt
            local predicted = (lr + lineSpeed * dt * 0) % 360
            if VD_CrossedZone(AutoSkill.PerfectLastLineRotation, predicted, (gr + 104) % 360, (gr + 108) % 360) then
                AutoSkill.PerfectHasClickedThisGoal = true
                VD_PressSkill()
            end
        end
    end
    AutoSkill.PerfectLastLineRotation = lr
    AutoSkill.PerfectLastTick = now
end

function VD_InstantSkillcheckUpdate()
    if AutoSkill.InstantHasClicked then return end

    local prompt = PlayerGui:FindFirstChild("SkillCheckPromptGui")
    if not prompt then
        prompt = PlayerGui:FindFirstChild("SkillCheckPromptGui-con")
    end
    if not prompt then return end

    local check = prompt:FindFirstChild("Check")
    if not check or not check.Visible then return end

    local line = check:FindFirstChild("Line")
    local goal = check:FindFirstChild("Goal")
    if not line or not goal then return end

    line.Rotation = goal.Rotation + 109

    AutoSkill.InstantHasClicked = true
    task.spawn(function()
        VD_PressSkill()
        task.wait(0.2)
        AutoSkill.InstantHasClicked = false
    end)
end

-- =====================================================
-- HEALING FUNCTIONS
-- =====================================================

local InstantHealConnection = nil
local AutoHealAllConnection = nil

function doSelfHealTrue()
    local char = LocalPlayer.Character
    if not char then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function() healRemote:FireServer(hrp, true) end)
end

function doSelfHealFalse()
    local char = LocalPlayer.Character
    if not char then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function() healRemote:FireServer(hrp, false) end)
end

function doOthersHealTrue(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    pcall(function() healRemote:FireServer(targetHRP, true) end)
end

function doOthersHealFalse(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    pcall(function() healRemote:FireServer(targetHRP, false) end)
end

function setInstantHealSelf(v)
    HEX.InstantHealSelf = v
    if v then
        local healActive = false
        if InstantHealConnection then InstantHealConnection:Disconnect() end
        InstantHealConnection = RunService.Heartbeat:Connect(function()
            if not HEX.InstantHealSelf then return end
            local myChar = LocalPlayer.Character
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if not myHum then return end
            
            if myHum.Health >= myHum.MaxHealth * 0.9 then 
                if healActive then
                    healActive = false
                    doSelfHealFalse()
                end
                return 
            end
            
            if not healActive then
                healActive = true
                doSelfHealTrue()
            end
        end)
    else
        if InstantHealConnection then InstantHealConnection:Disconnect(); InstantHealConnection = nil end
        pcall(doSelfHealFalse)
    end
end

function setAutoHealAll(v)
    HEX.AutoHealAll = v
    if v then
        local activeHeals = {}
        if AutoHealAllConnection then AutoHealAllConnection:Disconnect() end
        AutoHealAllConnection = RunService.Heartbeat:Connect(function()
            if not HEX.AutoHealAll then return end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.9 and hrp then
                        if not activeHeals[player] then
                            activeHeals[player] = true
                            doOthersHealTrue(player)
                        end
                    else
                        if activeHeals[player] then
                            activeHeals[player] = nil
                            doOthersHealFalse(player)
                        end
                    end
                end
            end
        end)
    else
        if AutoHealAllConnection then AutoHealAllConnection:Disconnect(); AutoHealAllConnection = nil end
    end
end

-- =====================================================
-- UI CREATION
-- =====================================================

local Window = Obsidian:Window({
    Name = "HEXWARE",
    Size = Vector2.new(580, 460),
    Keybind = Enum.KeyCode.RightControl,
    Accent = Color3.fromRGB(125, 85, 255),
})

-- ============================================
-- ВКЛАДКА: MAIN
-- ============================================
local MainTab = Window:Tab({
    Name = "Main",
    Icon = "rbxassetid://7733779610"
})

local PlayerSection = MainTab:AddLeftGroupbox("Player")

-- Speed
local SpeedToggle = PlayerSection:AddToggle("Speed", {
    Text = "Speed Hack",
    Default = false,
    Callback = function(value)
        HEX.Speed = value
    end
})

SpeedToggle:AddKeyPicker("SpeedBind", {
    Default = "None",
    Text = "Speed Keybind",
    Mode = "Toggle",
    Callback = function(value)
        HEX.Speed = not HEX.Speed
        SpeedToggle:SetValue(HEX.Speed)
    end
})

PlayerSection:AddSlider("SpeedValue", {
    Text = "Speed Value",
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.SpeedValue = value
    end
})

-- Jump
PlayerSection:AddToggle("Jump", {
    Text = "Jump Hack",
    Default = false,
    Callback = function(value)
        HEX.Jump = value
    end
})

PlayerSection:AddSlider("JumpValue", {
    Text = "Jump Power",
    Default = 50,
    Min = 50,
    Max = 200,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.JumpValue = value
    end
})

-- Infinite Jump
PlayerSection:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(value)
        HEX.InfiniteJump = value
    end
})

-- Noclip
local NoclipToggle = PlayerSection:AddToggle("Noclip", {
    Text = "Noclip",
    Default = false,
    Callback = function(value)
        HEX.Noclip = value
    end
})

NoclipToggle:AddKeyPicker("NoclipBind", {
    Default = "None",
    Text = "Noclip Keybind",
    Mode = "Toggle",
    Callback = function(value)
        HEX.Noclip = not HEX.Noclip
        NoclipToggle:SetValue(HEX.Noclip)
    end
})

-- Anti Fall Damage
PlayerSection:AddToggle("AntiFallDamage", {
    Text = "Anti Fall Damage",
    Default = false,
    Callback = function(value)
        HEX.AntiFallDamage = value
    end
})

-- ============================================
-- COMBAT SECTION
-- ============================================
local CombatSection = MainTab:AddRightGroupbox("Combat")

-- Auto Attack
CombatSection:AddToggle("AutoAttack", {
    Text = "Auto Attack",
    Default = false,
    Callback = function(value)
        HEX.AutoAttack = value
    end
})

CombatSection:AddSlider("AttackRange", {
    Text = "Attack Range",
    Default = 12,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.AttackRange = value
    end
})

-- Hitbox Expander
CombatSection:AddToggle("HitboxEnabled", {
    Text = "Hitbox Expand",
    Default = false,
    Callback = function(value)
        HEX.HitboxEnabled = value
    end
})

CombatSection:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 15,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.HitboxSize = value
    end
})

-- ============================================
-- ВКЛАДКА: SURVIVOR
-- ============================================
local SurvivorTab = Window:Tab({
    Name = "Survivor",
    Icon = "rbxassetid://7733764083"
})

local GenSection = SurvivorTab:AddLeftGroupbox("Generator")

-- Auto Skillcheck
GenSection:AddToggle("AutoSkillcheck", {
    Text = "Auto Skillcheck",
    Default = false,
    Callback = function(value)
        HEX.AutoSkillcheck = value
        if not value then
            if AutoSkill.InstantRotationConnection then
                AutoSkill.InstantRotationConnection:Disconnect()
                AutoSkill.InstantRotationConnection = nil
            end
            AutoSkill.InstantHasClicked = false
            AutoSkill.WasActive = false
            AutoSkill.PerfectWasActive = false
        end
    end
})

GenSection:AddDropdown("AutoSkillcheckMode", {
    Text = "Skillcheck Mode",
    Values = {"Normal", "Perfect", "Instant"},
    Default = 1,
    Callback = function(value)
        HEX.AutoSkillcheckMode = value
        if value ~= "Instant" and AutoSkill.InstantRotationConnection then
            AutoSkill.InstantRotationConnection:Disconnect()
            AutoSkill.InstantRotationConnection = nil
            AutoSkill.InstantHasClicked = false
        end
    end
})

GenSection:AddDivider()

local HealSection = SurvivorTab:AddLeftGroupbox("Healing")

-- Instant Heal Self
HealSection:AddToggle("InstantHealSelf", {
    Text = "Instant Heal Self",
    Default = false,
    Callback = function(value)
        setInstantHealSelf(value)
    end
})

-- Auto Heal All
HealSection:AddToggle("AutoHealAll", {
    Text = "Auto Heal All",
    Default = false,
    Callback = function(value)
        setAutoHealAll(value)
    end
})

HealSection:AddDivider()

local SurvFeatures = SurvivorTab:AddRightGroupbox("Features")

-- Flee Killer
SurvFeatures:AddToggle("FleeKiller", {
    Text = "Flee Killer",
    Default = false,
    Callback = function(value)
        HEX.FleeKiller = value
    end
})

SurvFeatures:AddSlider("FleeDistance", {
    Text = "Flee Distance",
    Default = 40,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.FleeDistance = value
    end
})

SurvFeatures:AddDivider()

-- Auto Parry
SurvFeatures:AddToggle("AutoParry", {
    Text = "Auto Parry",
    Default = false,
    Callback = function(value)
        HEX.AutoParry = value
    end
})

SurvFeatures:AddSlider("ParryDistance", {
    Text = "Parry Distance",
    Default = 8,
    Min = 3,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.ParryDistance = value
    end
})

-- Anti Knock
SurvFeatures:AddToggle("AntiKnock", {
    Text = "Anti Knock",
    Default = false,
    Callback = function(value)
        HEX.AntiKnock = value
    end
})

-- ============================================
-- ВКЛАДКА: KILLER
-- ============================================
local KillerTab = Window:Tab({
    Name = "Killer",
    Icon = "rbxassetid://7743875962"
})

local KillerSection = KillerTab:AddLeftGroupbox("Killer Features")

-- Auto Hook
KillerSection:AddToggle("AutoHook", {
    Text = "Auto Hook",
    Default = false,
    Callback = function(value)
        HEX.AutoHook = value
    end
})

-- Destroy Pallets
KillerSection:AddToggle("DestroyPallets", {
    Text = "Destroy Pallets",
    Default = false,
    Callback = function(value)
        HEX.DestroyPallets = value
    end
})

-- No Pallet Stun
KillerSection:AddToggle("NoPalletStun", {
    Text = "No Pallet Stun",
    Default = false,
    Callback = function(value)
        HEX.NoPalletStun = value
    end
})

-- No Slowdown
KillerSection:AddToggle("NoSlowdown", {
    Text = "No Slowdown",
    Default = false,
    Callback = function(value)
        HEX.NoSlowdown = value
    end
})

-- ============================================
-- ВКЛАДКА: VISUAL
-- ============================================
local VisualTab = Window:Tab({
    Name = "Visual",
    Icon = "rbxassetid://7733955511"
})

local VisualSection = VisualTab:AddLeftGroupbox("Visual")

-- Fullbright
VisualSection:AddToggle("Fullbright", {
    Text = "Fullbright",
    Default = false,
    Callback = function(value)
        HEX.Fullbright = value
        if value then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = originalLighting.Brightness
            Lighting.ClockTime = originalLighting.ClockTime
            Lighting.FogEnd = originalLighting.FogEnd
            Lighting.GlobalShadows = originalLighting.GlobalShadows
        end
    end
})

-- No Fog
VisualSection:AddToggle("NoFog", {
    Text = "No Fog",
    Default = false,
    Callback = function(value)
        HEX.NoFog = value
        if value then
            Lighting.FogEnd = 100000
        else
            Lighting.FogEnd = originalLighting.FogEnd
        end
    end
})

VisualSection:AddDivider()

-- Camera FOV
VisualSection:AddToggle("FOVEnabled", {
    Text = "Enable FOV Override",
    Default = false,
    Callback = function(value)
        HEX.FOVEnabled = value
    end
})

VisualSection:AddSlider("FOV", {
    Text = "Camera FOV",
    Default = 90,
    Min = 70,
    Max = 120,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        HEX.FOV = value
    end
})

-- Third Person
VisualSection:AddToggle("ThirdPerson", {
    Text = "Third Person (Killer)",
    Default = false,
    Callback = function(value)
        HEX.ThirdPerson = value
    end
})

-- ============================================
-- ВКЛАДКА: MISC
-- ============================================
local MiscTab = Window:Tab({
    Name = "Misc",
    Icon = "rbxassetid://7733964370"
})

local MiscSection = MiscTab:AddLeftGroupbox("Miscellaneous")

-- Anti AFK
MiscSection:AddToggle("AntiAFK", {
    Text = "Anti AFK",
    Default = false,
    Callback = function(value)
        HEX.AntiAFK = value
        if value then
            local VirtualUser = game:GetService("VirtualUser")
            LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
})

-- ============================================
-- ВКЛАДКА: SETTINGS
-- ============================================
local SettingsTab = Window:Tab({
    Name = "Settings",
    Icon = "rbxassetid://7733955511"
})

-- Theme Manager
ThemeManager:SetLibrary(Obsidian)
ThemeManager:SetFolder("HexwareSettings")
ThemeManager:ApplyToTab(SettingsTab)

-- Save Manager
SaveManager:SetLibrary(Obsidian)
SaveManager:SetFolder("HexwareSettings")
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(SettingsTab:AddRightGroupbox("Configuration"))

-- ============================================
-- RUNTIME LOOPS
-- ============================================

-- Auto Skillcheck Loop
RunService.RenderStepped:Connect(function()
    if not HEX.AutoSkillcheck then return end
    if HEX.AutoSkillcheckMode == "Perfect" then
        VD_PerfectSkillcheckUpdate()
    elseif HEX.AutoSkillcheckMode == "Instant" then
        VD_InstantSkillcheckUpdate()
    else
        VD_NormalSkillcheckUpdate()
    end
end)

-- Speed & Jump Loop
RunService.Heartbeat:Connect(function()
    if HEX.Speed and Humanoid then
        Humanoid.WalkSpeed = HEX.SpeedValue
    end
    
    if HEX.Jump and Humanoid then
        Humanoid.JumpPower = HEX.JumpValue
    end
    
    if HEX.FOVEnabled and Camera then
        Camera.FieldOfView = HEX.FOV
    end
end)

-- Noclip Loop
RunService.Stepped:Connect(function()
    if HEX.Noclip and Character then
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if HEX.InfiniteJump and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Загрузка конфигурации
SaveManager:LoadAutoloadConfig()

-- Уведомление о загрузке
Obsidian:Notify({
    Title = "HEXWARE",
    Description = "Violence District loaded successfully!",
    Duration = 5
})

print("[HEXWARE] Violence District Script fully loaded!")
