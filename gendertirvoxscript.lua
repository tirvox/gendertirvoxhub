-- tirvoxhub – v22 (Tween Zones & Fixes)
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

local gravityNormal = workspace.Gravity

-- ==================== ФЛАГИ ====================
local antiAfkEnabled = false
local flyEnabled = false
local infinityJumpEnabled = false
local noclipEnabled = false
local autoStopEnabled = false
local clickTpEnabled = false
local fullbrightEnabled = false
local fpsBoostEnabled = false
local playerEspEnabled = false
local zoomEnabled = false
local isClicking = false
local autoBuyPotionEnabled = false
local autoUpgradeEnabled = false
local autoPotion2x = false
local autoPotion5x = false
local autoTp2x = false
local autoTp5x = false
local autoPotionLoopRunning = false
local potionAmountLabel = nil

-- ==================== FLY ====================
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyKeys = {W=false, A=false, S=false, D=false, Space=false, Q=false}
local flySpeed = 50

-- ==================== INFINITY JUMP ====================
local jumpHeld = false
local jumpTimer = 0
local JUMP_INTERVAL = 0.1

-- ==================== CLICK TP ====================
local clickTpHeld = false
local mouse = player:GetMouse()

-- ==================== ESP ====================
local espObjects = {}

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ====================
local function getChar()
    local c = player.Character
    if not c then return nil, nil, nil end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChild("Humanoid")
    return c, h, r
end

local function setGodMode()
    local c, h, r = getChar()
    if not h then return end
    h.MaxHealth = math.huge
    h.Health = math.huge
    h.BreakJointsOnDeath = false
    h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
    h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
    h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    h:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
end

local function clickUIBtn(btn)
    if not btn then return end
    
    if btn:IsA("GuiButton") then
        if firesignal then
            pcall(firesignal, btn.Activated)
            pcall(firesignal, btn.MouseButton1Click)
            return
        end
        if getconnections then
            local fired = false
            pcall(function()
                for _, c in pairs(getconnections(btn.Activated)) do c:Fire(); fired = true end
                for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire(); fired = true end
            end)
            if fired then return end
        end
    else
        if getconnections then
            local fired = false
            pcall(function()
                for _, c in pairs(getconnections(btn.InputBegan)) do 
                    local fakeInput = {UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown}
                    c:Fire(fakeInput) 
                    fired = true
                end
            end)
            if fired then return end
        end
    end
    
    local pos = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local x = math.floor(pos.X + size.X/2)
    local y = math.floor(pos.Y + size.Y/2)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
end

local function parseNum(str)
    if not str then return 0 end
    str = tostring(str):lower()
    local mult = 1
    if str:find("k") then mult = 1e3 end
    if str:find("m") then mult = 1e6 end
    if str:find("b") then mult = 1e9 end
    if str:find("t") then mult = 1e12 end
    
    local numStr = str:gsub("[^0-9%.]", "")
    if numStr == "" then return 0 end
    local num = tonumber(numStr)
    return num and num * mult or 0
end

local function findUpgrade(mainFrame, name)
    local target = string.lower(name):gsub(" ", "")
    for _, desc in ipairs(mainFrame:GetDescendants()) do
        if string.lower(desc.Name):gsub(" ", "") == target then
            return desc
        end
    end
    return nil
end

local function findPrice(item)
    for _, desc in ipairs(item:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local n = string.lower(desc.Name)
            if n == "price" or n:find("cost") then
                return desc
            end
        end
    end
    for _, desc in ipairs(item:GetDescendants()) do
        if desc:IsA("TextLabel") and string.find(desc.Text, "%d") then
            return desc
        end
    end
    return nil
end

local function getZoneTouch(zoneName)
    local zone = workspace:FindFirstChild(zoneName)
    if zone then
        local touch = zone:FindFirstChild("Touch", true)
        if touch and touch:IsA("BasePart") then
            return touch
        end
    end
    return nil
end

-- ==================== NOCLIP ====================
RunService.Stepped:Connect(function()
    if noclipEnabled then
        local c = player.Character
        if c then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

local function disableNoclip()
    local c = player.Character
    if c then
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCollide = true end
        end
    end
end

-- ==================== ПОЛЁТ ====================
local function setupFly()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = root
    if flyBodyGyro then flyBodyGyro:Destroy() end
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyBodyGyro.P = 100000
    flyBodyGyro.CFrame = root.CFrame
    flyBodyGyro.Parent = root
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end
    workspace.Gravity = 0
end

local function teardownFly()
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    workspace.Gravity = gravityNormal
end

local function toggleFly()
    flyEnabled = not flyEnabled
    if flyEnabled then setupFly() else teardownFly() end
end

-- ==================== FULLBRIGHT ====================
local originalLighting = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function applyFullbright()
    Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(178, 178, 178)
    Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end

local function removeFullbright()
    Lighting.Brightness = originalLighting.Brightness
    Lighting.ClockTime = originalLighting.ClockTime
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.Ambient = originalLighting.Ambient
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
end

-- ==================== FPS BOOST ====================
local function applyFpsBoost()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic; obj.Reflectance = 0
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            obj.Enabled = false
        end
    end
    Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
    if workspace:FindFirstChildOfClass("Terrain") then
        workspace.Terrain.WaterWaveSize = 0; workspace.Terrain.WaterWaveSpeed = 0
        workspace.Terrain.WaterReflectance = 0; workspace.Terrain.Decoration = false
    end
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end
end

-- ==================== PLAYER ESP ====================
local function createEsp(p)
    if p == player then return end
    local function setup(char)
        if not char then return end
        local hl = Instance.new("Highlight")
        hl.Name = "tirvox_esp"
        hl.FillColor = Color3.fromRGB(255, 0, 0)
        hl.FillTransparency = 0.5
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0
        hl.Parent = char
        espObjects[p] = hl
    end
    if p.Character then setup(p.Character) end
    p.CharacterAdded:Connect(function(c) setup(c) end)
end

local function enableEsp()
    for _, p in ipairs(Players:GetPlayers()) do createEsp(p) end
    Players.PlayerAdded:Connect(createEsp)
end

local function disableEsp()
    for p, hl in pairs(espObjects) do hl:Destroy() end
    espObjects = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("tirvox_esp")
            if hl then hl:Destroy() end
        end
    end
end

-- ==================== ZOOM UNLOCK ====================
local function enableZoom()
    player.CameraMaxZoomDistance = 999999
    player.CameraMinZoomDistance = 0.5
end

local function disableZoom()
    player.CameraMaxZoomDistance = 128
    player.CameraMinZoomDistance = 0.5
end

-- ==================== АВТОКЛИКЕР ROLL ====================
local function getRollButton()
    local ok, btn = pcall(function()
        return player.PlayerGui.UI.MainButtons.Roll
    end)
    if ok and btn then return btn end
    return nil
end

local function autoClickLoop()
    local btn = getRollButton()
    if not btn then
        Library:Notify("Auto Clicker", "Roll button not found in PlayerGui!")
        Toggles.AutoClicker:SetValue(false)
        return
    end
    while isClicking do
        clickUIBtn(btn)
        local speed = 0.1
        if Options.ClickSpeed then speed = Options.ClickSpeed.Value end
        wait(speed)
    end
end

-- ==================== AUTOBUY POTIONS ====================
local function autoBuyPotionLoop()
    while autoBuyPotionEnabled do
        local ok, mainFrame = pcall(function()
            return player.PlayerGui.UI.Frames.Potions.MainFrame
        end)
        if ok and mainFrame then
            for _, potionName in ipairs({"1", "2", "3"}) do
                local imgLabel = mainFrame:FindFirstChild(potionName)
                if imgLabel then
                    local buyBtn = imgLabel:FindFirstChild("BuyButtonCash", true)
                    if buyBtn then
                        clickUIBtn(buyBtn)
                    end
                end
            end
        end
        wait(0.5)
    end
end

-- ==================== AUTO UPGRADE ====================
local upgLabels = {}

local function autoUpgradeLoop()
    while autoUpgradeEnabled do
        local cashTxt = player.PlayerGui.UI.CashFrame.CashAmount.Text
        local cash = parseNum(cashTxt)
        
        local ok, mainFrame = pcall(function()
            return player.PlayerGui.UI.Frames.Upgrades.MainFrame
        end)
        
        if ok and mainFrame then
            local affordable = {}
            
            local upgrades = {
                {name = "Cash Income", tog = "UpgradeCashIncome", label = upgLabels[1]},
                {name = "Luck", tog = "UpgradeLuck", label = upgLabels[2]},
                {name = "Potion Duration", tog = "UpgradePotionDuration", label = upgLabels[3]},
                {name = "Roll Speed", tog = "UpgradeRollSpeed", label = upgLabels[4]}
            }
            
            for _, upg in ipairs(upgrades) do
                if Toggles[upg.tog] and Toggles[upg.tog].Value then
                    local item = findUpgrade(mainFrame, upg.name)
                    if item then
                        local priceLabel = findPrice(item)
                        local price = 0
                        if priceLabel then
                            price = parseNum(priceLabel.Text)
                            if upg.label then
                                upg.label:SetText(upg.name .. ": " .. priceLabel.Text)
                            end
                        else
                            if upg.label then
                                upg.label:SetText(upg.name .. ": Price N/A")
                            end
                        end
                        
                        if cash >= price then
                            table.insert(affordable, {frame = item, price = price})
                        end
                    else
                        if upg.label then
                            upg.label:SetText(upg.name .. ": Not Found")
                        end
                    end
                end
            end
            
            table.sort(affordable, function(a, b) return a.price < b.price end)
            
            if #affordable > 0 then
                local toBuy = affordable[1].frame
                local buyBtn = toBuy:FindFirstChild("BuyButtonCash", true)
                if not buyBtn then
                    buyBtn = toBuy:FindFirstChildWhichIsA("TextButton") or toBuy:FindFirstChildWhichIsA("ImageButton")
                end
                if buyBtn then
                    clickUIBtn(buyBtn)
                else
                    clickUIBtn(toBuy)
                end
                wait(0.2)
            else
                wait(0.5)
            end
        else
            wait(1)
        end
    end
end

-- ==================== AUTO POTIONS (Использование) & ZONES ====================
local function getPotionsUseFrame()
    local ok, res = pcall(function()
        local ui = player.PlayerGui:FindFirstChild("UI")
        if not ui then return nil end
        local frames = ui:FindFirstChild("Frames")
        if not frames then return nil end
        
        local mainFrame = frames:FindFirstChild("MainFrame")
        if mainFrame then
            local potions = mainFrame:FindFirstChild("Potions")
            if potions then return potions end
        end
        
        local potions = frames:FindFirstChild("Potions")
        if potions then
            local mf = potions:FindFirstChild("MainFrame")
            if mf then return mf end
            return potions
        end
        
        return nil
    end)
    return ok and res or nil
end

local function startAutoPotionLoopIfNeeded()
    if not autoPotionLoopRunning and (autoTp2x or autoTp5x or autoPotion2x or autoPotion5x) then
        autoPotionLoopRunning = true
        spawn(function()
            while autoTp2x or autoTp5x or autoPotion2x or autoPotion5x do
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                
                local touch2 = getZoneTouch("2")
                local touch5 = getZoneTouch("5")
                
                -- Логика полёта (Tween)
                if root then
                    local target = nil
                    if autoTp5x and touch5 then
                        target = touch5
                    elseif autoTp2x and touch2 then
                        target = touch2
                    end
                    
                    if target then
                        local goal = target.CFrame + Vector3.new(0, 3, 0)
                        local distance = (root.Position - goal.Position).Magnitude
                        
                        -- Если далеко, летим твином. Если близко - просто стоим.
                        if distance > 5 then
                            local timeNeeded = math.max(0.1, distance / 100) -- 100 studs/s
                            local info = TweenInfo.new(timeNeeded, Enum.EasingStyle.Linear)
                            local tween = TweenService:Create(root, info, {CFrame = CFrame.new(goal.Position)})
                            tween:Play()
                            tween.Completed:Wait()
                        end
                    end
                end
                
                -- Логика использования зелий
                local in2x = false
                local in5x = false
                if root and touch2 then
                    if (root.Position - touch2.Position).Magnitude < 30 then in2x = true end
                end
                if root and touch5 then
                    if (root.Position - touch5.Position).Magnitude < 30 then in5x = true end
                end
                
                local shouldUse = (autoPotion2x and in2x) or (autoPotion5x and in5x)
                
                local potionsFrame = getPotionsUseFrame()
                
                if potionsFrame then
                    local amounts = {}
                    for _, potion in ipairs(potionsFrame:GetChildren()) do
                        if potion:IsA("GuiObject") then
                            local amountLabel = potion:FindFirstChild("Amount", true)
                            local useBtn = potion:FindFirstChild("UseButton", true)
                            
                            local amount = 0
                            if amountLabel then
                                local amountStr = string.match(amountLabel.Text, "%((%d+)%)") or string.match(amountLabel.Text, "%d+") or "0"
                                amount = tonumber(amountStr) or 0
                                table.insert(amounts, potion.Name .. ": " .. amount)
                            else
                                table.insert(amounts, potion.Name .. ": N/A")
                            end
                            
                            if shouldUse and useBtn then
                                clickUIBtn(useBtn)
                            end
                        end
                    end
                    
                    if potionAmountLabel then
                        potionAmountLabel:SetText("Potion amounts:\n" .. table.concat(amounts, "\n"))
                    end
                else
                    if potionAmountLabel then
                        potionAmountLabel:SetText("Potions frame not found")
                    end
                end
                
                wait(0.5)
            end
            autoPotionLoopRunning = false
        end)
    end
end

-- ==================== ВВОД ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if clickTpEnabled and clickTpHeld then
            local c, h, r = getChar()
            if r and mouse.Hit then
                r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end

    if gameProcessed then return end
    local key = input.KeyCode
    
    if Options.FlyKeybind and key == Options.FlyKeybind.Value then
        Toggles.FlyToggle:SetValue(not Toggles.FlyToggle.Value); return
    end
    if Options.InfJumpKeybind and key == Options.InfJumpKeybind.Value then
        Toggles.InfinityJumpToggle:SetValue(not Toggles.InfinityJumpToggle.Value); return
    end
    if Options.NoclipKeybind and key == Options.NoclipKeybind.Value then
        Toggles.NoclipToggle:SetValue(not Toggles.NoclipToggle.Value); return
    end
    if Options.ClickTpKeybind and key == Options.ClickTpKeybind.Value then
        clickTpHeld = true; return
    end

    if key == Enum.KeyCode.W then flyKeys.W = true
    elseif key == Enum.KeyCode.A then flyKeys.A = true
    elseif key == Enum.KeyCode.S then flyKeys.S = true
    elseif key == Enum.KeyCode.D then flyKeys.D = true
    elseif key == Enum.KeyCode.Space then
        flyKeys.Space = true; jumpHeld = true
        if infinityJumpEnabled and not flyEnabled then
            local c, h, r = getChar()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    elseif key == Enum.KeyCode.Q then flyKeys.Q = true end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    local key = input.KeyCode
    if key == Enum.KeyCode.W then flyKeys.W = false
    elseif key == Enum.KeyCode.A then flyKeys.A = false
    elseif key == Enum.KeyCode.S then flyKeys.S = false
    elseif key == Enum.KeyCode.D then flyKeys.D = false
    elseif key == Enum.KeyCode.Space then flyKeys.Space = false; jumpHeld = false
    elseif key == Enum.KeyCode.Q then flyKeys.Q = false end

    if Options.ClickTpKeybind and key == Options.ClickTpKeybind.Value then
        clickTpHeld = false
    end
end)

-- ==================== HEARTBEAT ====================
RunService.Heartbeat:Connect(function(dt)
    setGodMode()
    if infinityJumpEnabled and not flyEnabled and jumpHeld then
        jumpTimer = jumpTimer + dt
        if jumpTimer >= JUMP_INTERVAL then
            jumpTimer = 0
            local c, h, r = getChar()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    else
        jumpTimer = 0
    end
    if flyEnabled then
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and flyBodyVelocity then
                local move = Vector3.new(0, 0, 0)
                local cam = workspace.CurrentCamera
                local camCF = cam and cam.CFrame or root.CFrame
                if flyKeys.W then move = move + camCF.LookVector end
                if flyKeys.S then move = move - camCF.LookVector end
                if flyKeys.A then move = move - camCF.RightVector end
                if flyKeys.D then move = move + camCF.RightVector end
                if flyKeys.Space then move = move + Vector3.new(0, 1, 0) end
                if flyKeys.Q then move = move - Vector3.new(0, 1, 0) end
                if move.Magnitude > 0 then
                    move = move.Unit * flySpeed
                    if flyBodyGyro then
                        flyBodyGyro.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
                    end
                else
                    if autoStopEnabled then root.AssemblyLinearVelocity = Vector3.zero end
                end
                flyBodyVelocity.Velocity = move
            end
        end
    end
end)

-- ==================== АНТИ-AFK ====================
spawn(function()
    while true do
        wait(10)
        if antiAfkEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
        end
    end
end)

-- ==================== ОБРАБОТКА РЕСПАВНА ====================
player.CharacterAdded:Connect(function(newChar)
    local humanoid = newChar:WaitForChild("Humanoid")
    setGodMode()
    if flyEnabled then flyBodyVelocity = nil; flyBodyGyro = nil; setupFly() end
    if isClicking then spawn(autoClickLoop) end
    if autoBuyPotionEnabled then spawn(autoBuyPotionLoop) end
    if autoUpgradeEnabled then spawn(autoUpgradeLoop) end
    startAutoPotionLoopIfNeeded()
    humanoid.WalkSpeed = Options.Speed and Options.Speed.Value or 16
    humanoid.JumpPower = Options.Jump and Options.Jump.Value or 50
end)

-- ==================== ИНТЕРФЕЙС ====================
local Window = Library:CreateWindow({
    Title = 'tirvoxhub', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2
})

local Tabs = {
    Farm = Window:AddTab('Farm'),
    Player = Window:AddTab('Player'),
    Autobuy = Window:AddTab('Autobuy'),
    Misc = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ==================== FARM ====================
local farmGroup = Tabs.Farm:AddLeftGroupbox('Farm Controls')

farmGroup:AddToggle('AutoClicker', {
    Text = 'Auto Roll (GUI Clicker)', Default = false,
    Tooltip = 'Clicks the Roll button in PlayerGui',
    Callback = function(val)
        isClicking = val
        if isClicking then spawn(autoClickLoop) end
    end
})

farmGroup:AddSlider('ClickSpeed', {
    Text = 'Click Delay', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2, Suffix = 's',
})

farmGroup:AddButton({ Text = 'Close Script', Func = function() Library:Unload() end })

farmGroup:AddToggle('AntiAfkToggle', {
    Text = 'Anti AFK', Default = false, Tooltip = 'Simulates K key press every 10s',
    Callback = function(val) antiAfkEnabled = val end
})

-- ==================== PLAYER ====================
local moveGroup = Tabs.Player:AddLeftGroupbox('Movement')

moveGroup:AddSlider('Speed', { Text = 'Walk Speed', Default = 16, Min = 0, Max = 1000, Rounding = 1, Callback = function(val) local c, h, r = getChar(); if h then h.WalkSpeed = val end end })
moveGroup:AddSlider('Jump', { Text = 'Jump Power', Default = 50, Min = 0, Max = 500, Rounding = 1, Callback = function(val) local c, h, r = getChar(); if h then h.JumpPower = val end end })
moveGroup:AddSlider('Gravity', { Text = 'Gravity', Default = 196.2, Min = -100, Max = 500, Rounding = 1, Callback = function(val) workspace.Gravity = val; gravityNormal = val end })
moveGroup:AddSlider('FlySpeed', { Text = 'Fly Speed', Default = 50, Min = 10, Max = 1000, Rounding = 1, Suffix = ' s/s', Callback = function(val) flySpeed = val end })
moveGroup:AddToggle('AutoStopToggle', { Text = 'Auto Stop', Default = false, Callback = function(val) autoStopEnabled = val end })

local flyToggle = moveGroup:AddToggle('FlyToggle', { Text = 'Fly Mode', Default = false, Callback = function(val) if val ~= flyEnabled then toggleFly() end end })
flyToggle:AddKeyPicker('FlyKeybind', { Default = 'F', Text = 'Fly', SyncToggleState = true, Mode = 'Toggle' })

local infJumpToggle = moveGroup:AddToggle('InfinityJumpToggle', { Text = 'Infinity Jump', Default = false, Callback = function(val) infinityJumpEnabled = val end })
infJumpToggle:AddKeyPicker('InfJumpKeybind', { Default = 'G', Text = 'Inf Jump', SyncToggleState = true, Mode = 'Toggle' })

local noclipToggle = moveGroup:AddToggle('NoclipToggle', { Text = 'Noclip', Default = false, Callback = function(val) noclipEnabled = val; if not val then disableNoclip() end end })
noclipToggle:AddKeyPicker('NoclipKeybind', { Default = 'H', Text = 'Noclip', SyncToggleState = true, Mode = 'Toggle' })

local clickTpToggle = moveGroup:AddToggle('ClickTpToggle', { Text = 'Click TP', Default = false, Callback = function(val) clickTpEnabled = val end })
clickTpToggle:AddKeyPicker('ClickTpKeybind', { Default = 'V', Text = 'Click TP', SyncToggleState = false, Mode = 'Hold' })

local visGroup = Tabs.Player:AddRightGroupbox('Visuals')
visGroup:AddToggle('FullbrightToggle', { Text = 'Fullbright', Default = false, Callback = function(val) fullbrightEnabled = val; if val then applyFullbright() else removeFullbright() end end })
visGroup:AddToggle('FpsBoostToggle', { Text = 'FPS Boost', Default = false, Callback = function(val) fpsBoostEnabled = val; if val then applyFpsBoost() end end })
visGroup:AddToggle('PlayerEspToggle', { Text = 'Player ESP', Default = false, Callback = function(val) playerEspEnabled = val; if val then enableEsp() else disableEsp() end end })
visGroup:AddToggle('ZoomToggle', { Text = 'Zoom Unlock', Default = false, Callback = function(val) zoomEnabled = val; if val then enableZoom() else disableZoom() end end })

-- ==================== AUTOBUY ====================
local potionGroup = Tabs.Autobuy:AddLeftGroupbox('Potion Buyer')

potionGroup:AddToggle('AutoBuyPotion', {
    Text = 'Auto Buy All Potions (1, 2, 3)',
    Default = false,
    Callback = function(val)
        autoBuyPotionEnabled = val
        if val then spawn(autoBuyPotionLoop) end
    end
})

local upgradeGroup = Tabs.Autobuy:AddRightGroupbox('Auto Upgrades')

upgradeGroup:AddToggle('AutoUpgrade', {
    Text = 'Enable Auto Upgrade',
    Default = false,
    Callback = function(val)
        autoUpgradeEnabled = val
        if val then spawn(autoUpgradeLoop) end
    end
})

upgradeGroup:AddToggle('UpgradeCashIncome', { Text = 'Cash Income', Default = true })
upgradeGroup:AddToggle('UpgradeLuck', { Text = 'Luck', Default = true })
upgradeGroup:AddToggle('UpgradePotionDuration', { Text = 'Potion Duration', Default = true })
upgradeGroup:AddToggle('UpgradeRollSpeed', { Text = 'Roll Speed', Default = true })

upgLabels[1] = upgradeGroup:AddLabel('Cash Income: $0', true)
upgLabels[2] = upgradeGroup:AddLabel('Luck: $0', true)
upgLabels[3] = upgradeGroup:AddLabel('Potion Duration: $0', true)
upgLabels[4] = upgradeGroup:AddLabel('Roll Speed: $0', true)

local autoPotionGroup = Tabs.Autobuy:AddLeftGroupbox('Auto Potions & Zones')

autoPotionGroup:AddToggle('AutoTp2x', { 
    Text = 'Auto TP to 2x Zone', Default = false, 
    Callback = function(val) autoTp2x = val; startAutoPotionLoopIfNeeded() end 
})
autoPotionGroup:AddToggle('AutoTp5x', { 
    Text = 'Auto TP to 5x Zone', Default = false, 
    Callback = function(val) autoTp5x = val; startAutoPotionLoopIfNeeded() end 
})
autoPotionGroup:AddToggle('UsePotion2x', { 
    Text = 'Use Potions in 2x Zone', Default = false, 
    Callback = function(val) autoPotion2x = val; startAutoPotionLoopIfNeeded() end 
})
autoPotionGroup:AddToggle('UsePotion5x', { 
    Text = 'Use Potions in 5x Zone', Default = false, 
    Callback = function(val) autoPotion5x = val; startAutoPotionLoopIfNeeded() end 
})

potionAmountLabel = autoPotionGroup:AddLabel('Potion amounts:\nLoading...', true)

-- ==================== MISC ====================
local creditsGroup = Tabs.Misc:AddLeftGroupbox('Credits')
creditsGroup:AddLabel('Credits: kiten, tirvox', true)
local gamesGroup = Tabs.Misc:AddRightGroupbox('Games')
gamesGroup:AddLabel('Works in this games:', true)
gamesGroup:AddLabel('• Dingus', true)
gamesGroup:AddLabel('• Build a Boat for Treasure', true)

-- ==================== UI SETTINGS ====================
local menuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
menuGroup:AddButton({ Text = 'Unload (reset)', Func = function() Library:Unload() end })
local menuKeyLabel = menuGroup:AddLabel('Menu key')
menuKeyLabel:AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind', 'FlyKeybind', 'InfJumpKeybind', 'NoclipKeybind', 'ClickTpKeybind' })
ThemeManager:SetFolder('tirvoxhub')
SaveManager:SetFolder('tirvoxhub/configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

-- ==================== СБРОС ====================
local function resetSettings()
    antiAfkEnabled = false; flyEnabled = false
    infinityJumpEnabled = false; noclipEnabled = false; autoStopEnabled = false
    clickTpEnabled = false; fullbrightEnabled = false; fpsBoostEnabled = false
    playerEspEnabled = false; zoomEnabled = false; autoBuyPotionEnabled = false
    autoUpgradeEnabled = false; isClicking = false
    autoPotion2x = false; autoPotion5x = false; autoTp2x = false; autoTp5x = false

    teardownFly(); disableNoclip(); removeFullbright(); disableEsp(); disableZoom()

    workspace.Gravity = gravityNormal
    local c = player.Character
    if c then
        local h = c:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = 16; h.JumpPower = 50; h.PlatformStand = false end
    end
end

Library:OnUnload(function() resetSettings() end)
