--[[
    MM2 - iOS 26 Liquid Glass (Усиленный эффект капли – ГОРИЗОНТАЛЬНО)
    Просто изменены размеры панели и капли на горизонтальные
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==================== ОПРЕДЕЛЕНИЕ РОЛИ ====================
local function getPlayerRole(player)
    local character = player.Character
    if not character then return "Innocent" end
    local function hasTool(...)
        for _, kw in ipairs({...}) do
            kw = kw:lower()
            for _, container in ipairs({character, player.Backpack}) do
                for _, child in container:GetChildren() do
                    if child:IsA("Tool") then
                        if child.Name:lower():find(kw) then return true end
                    end
                end
            end
        end
        return false
    end
    if hasTool("knife", "нож", "убийца", "murder") then return "Murderer"
    elseif hasTool("gun", "pistol", "пистолет", "sheriff", "шериф", "revolver", "deagle") then return "Sheriff"
    else return "Innocent" end
end

print("Текущая роль:", getPlayerRole(LocalPlayer))

-- ==================== ПОИСК REMOTEEVENT ДЛЯ ВЫСТРЕЛА ====================
local shootRemote = nil
for _, obj in ReplicatedStorage:GetDescendants() do
    if obj:IsA("RemoteEvent") then
        local name = obj.Name:lower()
        if name:find("shoot") or name:find("gun") or name:find("fire") or name:find("pistol") then
            shootRemote = obj
            break
        end
    end
end
if not shootRemote then
    for _, obj in ReplicatedStorage:GetDescendants() do
        if obj:IsA("RemoteEvent") then
            shootRemote = obj
            break
        end
    end
end
print(shootRemote and "RemoteEvent для выстрела найден: " .. shootRemote.Name or "RemoteEvent не найден, используется телепорт-атака")

-- ==================== ГЛОБАЛЬНЫЙ THROTTLE ТЕЛЕПОРТОВ ====================
local lastTeleportTime = 0
local TELEPORT_COOLDOWN = 0.5

local function canTeleport()
    return tick() - lastTeleportTime >= TELEPORT_COOLDOWN
end

local function safeTeleport(targetCFrame)
    if not canTeleport() then return false end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.CFrame = targetCFrame
            lastTeleportTime = tick()
        end)
        return true
    end
    return false
end

-- ==================== ESP ИГРОКИ ====================
local espPlayers = false
local playerHighlights = {}
local roleColors = {
    Murderer = Color3.fromRGB(255, 59, 48),
    Sheriff  = Color3.fromRGB(0, 122, 255),
    Innocent = Color3.fromRGB(52, 199, 89)
}

local function updatePlayerESP()
    for player, hl in pairs(playerHighlights) do
        if player.Parent == nil then
            hl:Destroy()
            playerHighlights[player] = nil
        else
            hl.FillColor = roleColors[getPlayerRole(player)] or roleColors.Innocent
        end
    end
end

local function addPlayerESP(player)
    if playerHighlights[player] or not player.Character then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = roleColors[getPlayerRole(player)] or roleColors.Innocent
    hl.OutlineColor = Color3.new(1,1,1)
    hl.OutlineTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.3
    hl.Parent = player.Character
    playerHighlights[player] = hl
end

local function removePlayerESP(player)
    if playerHighlights[player] then playerHighlights[player]:Destroy(); playerHighlights[player] = nil end
end

local function clearPlayerESP()
    for _, hl in pairs(playerHighlights) do hl:Destroy() end
    table.clear(playerHighlights)
end

local function onCharacterAdded(char)
    local player = Players:GetPlayerFromCharacter(char)
    if player and espPlayers then removePlayerESP(player); addPlayerESP(player) end
end

Players.PlayerAdded:Connect(function(plr)
    if espPlayers then
        plr.CharacterAdded:Connect(onCharacterAdded)
        if plr.Character then addPlayerESP(plr) end
    end
end)
Players.PlayerRemoving:Connect(removePlayerESP)

-- ==================== ESP ПРЕДМЕТЫ ====================
local espItems = false
local itemHighlights = {}

local function updateItemESP()
    for obj, hl in pairs(itemHighlights) do
        if not obj:IsDescendantOf(workspace) then hl:Destroy(); itemHighlights[obj] = nil end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and not itemHighlights[obj] then
            local name = obj.Name:lower()
            if name:find("knife") or name:find("gun") or name:find("pistol") or name:find("sheriff") then
                local hl = Instance.new("Highlight")
                hl.FillColor = name:find("knife") and Color3.fromRGB(255,100,100) or Color3.fromRGB(100,100,255)
                hl.OutlineColor = Color3.new(1,1,1)
                hl.OutlineTransparency = 0.5
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.FillTransparency = 0.4
                hl.Parent = obj
                itemHighlights[obj] = hl
            end
        end
    end
end

local function clearItemESP()
    for _, hl in pairs(itemHighlights) do hl:Destroy() end
    table.clear(itemHighlights)
end

-- ==================== NOCLIP ====================
local noclipEnabled = false
local function noclipLoop()
    if noclipEnabled and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

-- ==================== SPEED + ПОЛЗУНОК ====================
local speedEnabled = false
local speedValue = 50

local function setSpeed()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speedEnabled and speedValue or 16
    end
end

-- ==================== JUMP + ПОЛЗУНОК ====================
local jumpEnabled = false
local jumpValue = 50

local function setJump()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.UseJumpPower = true
        char.Humanoid.JumpPower = jumpEnabled and jumpValue or 50
    end
end

-- ==================== ПОДОБРАТЬ ПИСТОЛЕТ (одноразовое) ====================
local function pickUpPistol()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("pistol")) then
            local handle = obj:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                pcall(function()
                    if safeTeleport(handle.CFrame * CFrame.new(0, 2, 0)) then
                        task.wait(0.05)
                        firetouchinterest(root, handle, 0)
                        firetouchinterest(root, handle, 1)
                    end
                end)
                if speedEnabled then setSpeed() end
                if jumpEnabled then setJump() end
                return
            end
        end
    end
end

-- ==================== СТАТЬ УБИЙЦЕЙ / ШЕРИФОМ (авто-подбор) ====================
local murderEnabled = false
local sheriffEnabled = false
local lastMurderTry = 0
local lastSheriffTry = 0

local function becomeMurderer()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name:lower():find("knife") then
            local handle = obj:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                pcall(function()
                    if safeTeleport(handle.CFrame * CFrame.new(0, 1.5, 0)) then
                        task.wait(0.05)
                        firetouchinterest(root, handle, 0)
                        firetouchinterest(root, handle, 1)
                        local humanoid = myChar:FindFirstChildOfClass("Humanoid")
                        if humanoid and LocalPlayer.Backpack:FindFirstChild(obj.Name) then
                            humanoid:EquipTool(LocalPlayer.Backpack[obj.Name])
                        end
                    end
                end)
                if speedEnabled then setSpeed() end
                if jumpEnabled then setJump() end
                return
            end
        end
    end
end

local function becomeSheriff()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("pistol")) then
            local handle = obj:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                pcall(function()
                    if safeTeleport(handle.CFrame * CFrame.new(0, 1.5, 0)) then
                        task.wait(0.05)
                        firetouchinterest(root, handle, 0)
                        firetouchinterest(root, handle, 1)
                        local humanoid = myChar:FindFirstChildOfClass("Humanoid")
                        if humanoid and LocalPlayer.Backpack:FindFirstChild(obj.Name) then
                            humanoid:EquipTool(LocalPlayer.Backpack[obj.Name])
                        end
                    end
                end)
                if speedEnabled then setSpeed() end
                if jumpEnabled then setJump() end
                return
            end
        end
    end
end

-- ==================== AIMBOT ====================
local aimbotEnabled = false

local function aimbotLook()
    if not aimbotEnabled then return end
    if getPlayerRole(LocalPlayer) ~= "Sheriff" then return end

    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local nearest = nil
    local minDist = 300
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getPlayerRole(plr) == "Murderer" and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; nearest = root end
            end
        end
    end
    if nearest then
        local camera = workspace.CurrentCamera
        if camera then
            local targetPos = nearest.Position + Vector3.new(0, 2, 0)
            local newLook = CFrame.lookAt(camera.CFrame.Position, targetPos)
            camera.CFrame = camera.CFrame:Lerp(newLook, 0.2)
        end
    end
end

-- ==================== СТРЕЛЬБА СКВОЗЬ СТЕНУ ====================
local shootWallEnabled = false
local lastShotTime = 0

local function shootThroughWalls()
    if getPlayerRole(LocalPlayer) ~= "Sheriff" then return end
    if tick() - lastShotTime < 0.5 then return end
    lastShotTime = tick()

    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local murderer = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getPlayerRole(plr) == "Murderer" and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                murderer = plr
                break
            end
        end
    end
    if not murderer then return end

    local pistol = nil
    for _, tool in ipairs(myChar:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("gun") or tool.Name:lower():find("pistol")) then
            pistol = tool
            break
        end
    end
    if not pistol then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("gun") or tool.Name:lower():find("pistol")) then
                local humanoid = myChar:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:EquipTool(tool) end
                pistol = tool
                break
            end
        end
    end
    if not pistol then return end

    if shootRemote then
        pcall(function()
            shootRemote:FireServer(murderer)
        end)
    else
        local targetRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local savedCFrame = myRoot.CFrame
            if safeTeleport(targetRoot.CFrame * CFrame.new(0, 1, 0)) then
                task.wait(0.05)
                pcall(function() pistol:Activate() end)
                task.wait(0.1)
                pcall(function() myRoot.CFrame = savedCFrame end)
            end
        end
    end
end

-- ==================== ТЕЛЕПОРТЫ ====================
local function teleportToNearestMurderer()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local nearest = nil; local minDist = 9999
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getPlayerRole(plr) == "Murderer" and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; nearest = root end
            end
        end
    end
    if nearest then safeTeleport(nearest.CFrame * CFrame.new(0, 2, 0)) end
end

local function teleportToNearestSheriff()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local nearest = nil; local minDist = 9999
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getPlayerRole(plr) == "Sheriff" and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; nearest = root end
            end
        end
    end
    if nearest then safeTeleport(nearest.CFrame * CFrame.new(0, 2, 0)) end
end

local function teleportToPlayer(player)
    if not player or not player.Character then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
    if myRoot and targetRoot then
        safeTeleport(targetRoot.CFrame * CFrame.new(0, 2, 0))
    end
end

-- ==================== ТЕЛЕПОРТ К ОРУЖИЮ ====================
local function teleportToWeapon()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("pistol")) then
            local handle = obj:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                pcall(function()
                    safeTeleport(handle.CFrame * CFrame.new(0, 2, 0))
                end)
                return
            end
        end
    end
end

-- ==================== СОХРАНЕНИЕ / ЗАГРУЗКА НАСТРОЕК ====================
local function saveSettings()
    local settings = {
        espPlayers = espPlayers,
        espItems = espItems,
        noclip = noclipEnabled,
        speedEnabled = speedEnabled,
        speedValue = speedValue,
        jumpEnabled = jumpEnabled,
        jumpValue = jumpValue,
        murderEnabled = murderEnabled,
        sheriffEnabled = sheriffEnabled,
        aimbotEnabled = aimbotEnabled,
        shootWallEnabled = shootWallEnabled,
    }
    local jsonStr = game:GetService("HttpService"):JSONEncode(settings)
    if writefile then
        writefile("mm2_settings.txt", jsonStr)
        print("Настройки сохранены в mm2_settings.txt")
    else
        print("Ошибка: функция writefile недоступна")
    end
end

local function loadSettings()
    if not readfile then
        print("Ошибка: функция readfile недоступна")
        return
    end
    local success, result = pcall(function() return readfile("mm2_settings.txt") end)
    if not success or not result then
        print("Файл настроек не найден или повреждён")
        return
    end
    local settings = game:GetService("HttpService"):JSONDecode(result)
    if not settings then return end

    espPlayers = settings.espPlayers or false
    espItems = settings.espItems or false
    noclipEnabled = settings.noclip or false
    speedEnabled = settings.speedEnabled or false
    speedValue = settings.speedValue or 50
    jumpEnabled = settings.jumpEnabled or false
    jumpValue = settings.jumpValue or 50
    murderEnabled = settings.murderEnabled or false
    sheriffEnabled = settings.sheriffEnabled or false
    aimbotEnabled = settings.aimbotEnabled or false
    shootWallEnabled = settings.shootWallEnabled or false

    local function updateBtn(btn, state, textOn, textOff)
        btn.Text = state and textOn or textOff
        setActive(btn, state)
    end
    updateBtn(espPlayersBtn, espPlayers, "ESP игроков ВКЛ", "ESP игроков ВЫКЛ")
    updateBtn(espItemsBtn, espItems, "ESP предметов ВКЛ", "ESP предметов ВЫКЛ")
    updateBtn(noclipBtn, noclipEnabled, "Хождение сквозь ВКЛ", "Хождение сквозь ВЫКЛ")
    updateBtn(speedBtn, speedEnabled, "Скорость ВКЛ", "Скорость ВЫКЛ")
    updateBtn(jumpBtn, jumpEnabled, "Прыжок ВКЛ", "Прыжок ВЫКЛ")
    updateBtn(murderBtn, murderEnabled, "Стать убийцей ВКЛ", "Стать убийцей ВЫКЛ")
    updateBtn(sheriffBtn, sheriffEnabled, "Стать шерифом ВКЛ", "Стать шерифом ВЫКЛ")
    updateBtn(aimbotBtn, aimbotEnabled, "Aimbot ВКЛ", "Aimbot ВЫКЛ")
    updateBtn(shootWallBtn, shootWallEnabled, "Стрельба сквозь стену ВКЛ", "Стрельба сквозь стену ВЫКЛ")

    speedSlider.Visible = speedEnabled
    jumpSlider.Visible = jumpEnabled
    updateThumbPosition(speedSlider, speedThumb, speedValue, 16, 100)
    updateThumbPosition(jumpSlider, jumpThumb, jumpValue, 0, 200)

    setSpeed()
    setJump()

    print("Настройки загружены")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "MM2_LiquidGlass"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.BackgroundColor3 = Color3.new(0,0,0)
overlay.BackgroundTransparency = 1
overlay.Size = UDim2.new(1,0,1,0)
overlay.ZIndex = 1
overlay.Visible = false
overlay.Parent = gui

-- Круглая кнопка меню с анимацией
local menuBtn = Instance.new("ImageButton")
menuBtn.Size = UDim2.new(0, 56, 0, 56)
menuBtn.Position = UDim2.new(1, -76, 0.5, -28)
menuBtn.Image = "rbxassetid://6159452397"
menuBtn.BackgroundTransparency = 1
menuBtn.ScaleType = Enum.ScaleType.Stretch
menuBtn.ZIndex = 10
menuBtn.AutoButtonColor = false
menuBtn.ClipsDescendants = true

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(1, 0)
menuCorner.Parent = menuBtn

local menuStroke = Instance.new("UIStroke")
menuStroke.Thickness = 2
menuStroke.Color = Color3.new(1,1,1)
menuStroke.Transparency = 0.5
menuStroke.Parent = menuBtn

-- Анимация кнопки меню
local origMenuSize = menuBtn.Size
local bigMenuSize = UDim2.new(0, 65, 0, 65)
menuBtn.MouseButton1Down:Connect(function()
    TweenService:Create(menuBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = bigMenuSize}):Play()
end)
menuBtn.MouseButton1Up:Connect(function()
    TweenService:Create(menuBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = origMenuSize}):Play()
end)
menuBtn.MouseLeave:Connect(function()
    TweenService:Create(menuBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = origMenuSize}):Play()
end)

menuBtn.Parent = gui

-- Главная панель (изменён размер на горизонтальный)
local mainPanel = Instance.new("Frame")
mainPanel.Size = UDim2.new(0, 480, 0, 340)   -- было 320×600
mainPanel.AnchorPoint = Vector2.new(0.5,0.5)
mainPanel.Position = UDim2.new(0.5,0,0.5,0)
mainPanel.BackgroundColor3 = Color3.new(1,1,1)
mainPanel.BackgroundTransparency = 0.5
mainPanel.ClipsDescendants = true
mainPanel.Visible = false
mainPanel.ZIndex = 5

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(1, 0)
mainCorner.Parent = mainPanel

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 2
mainStroke.Color = Color3.new(1,1,1)
mainStroke.Transparency = 0.4
mainStroke.Parent = mainPanel

-- Заголовок
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1,0,0,40)
title.Position = UDim2.new(0,24,0,16)
title.Text = "Инструменты MM2"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.new(0,0,0)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = mainPanel

local closeBtn = Instance.new("TextButton")
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.new(0,32,0,32)
closeBtn.Position = UDim2.new(1,-44,0,14)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.new(0.4,0.4,0.4)
closeBtn.ZIndex = 3
closeBtn.Parent = mainPanel

-- Скроллинг
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.Size = UDim2.new(1, -20, 1, -70)
scroll.Position = UDim2.new(0, 10, 0, 65)
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.ScrollBarThickness = 4
scroll.ZIndex = 3
scroll.Parent = mainPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = scroll

-- Фабрика кнопок (+30%)
local function makeBtn(name, text)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.BackgroundColor3 = Color3.new(1,1,1)
    btn.BackgroundTransparency = 0.25
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.TextColor3 = Color3.new(0,0,0)
    btn.ZIndex = 3
    btn.AutoButtonColor = false
    btn.ClipsDescendants = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

    local origSize = btn.Size
    local bigSize = UDim2.new(1, 0, 0, 60)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = bigSize}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = origSize}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = origSize}):Play()
    end)
    btn.Parent = scroll
    return btn
end

-- Кнопки (русские названия)
local espPlayersBtn = makeBtn("ESP_P", "ESP игроков ВЫКЛ")
local espItemsBtn = makeBtn("ESP_I", "ESP предметов ВЫКЛ")
local noclipBtn = makeBtn("Noclip", "Хождение сквозь ВЫКЛ")
local speedBtn = makeBtn("Speed", "Скорость ВЫКЛ")
local jumpBtn = makeBtn("Jump", "Прыжок ВЫКЛ")
local pickupBtn = makeBtn("Pickup", "Подобрать пистолет")
local murderBtn = makeBtn("BecomeMurderer", "Стать убийцей ВЫКЛ")
local sheriffBtn = makeBtn("BecomeSheriff", "Стать шерифом ВЫКЛ")
local aimbotBtn = makeBtn("Aimbot", "Aimbot ВЫКЛ")
local shootWallBtn = makeBtn("ShootWall", "Стрельба сквозь стену ВЫКЛ")
local tpWeaponBtn = makeBtn("TPWeapon", "Телепорт к оружию")
local saveBtn = makeBtn("SaveSettings", "Сохранить настройки")
local loadBtn = makeBtn("LoadSettings", "Загрузить настройки")
local tpMurdererBtn = makeBtn("TPMurderer", "Телепорт к убийце")
local tpSheriffBtn = makeBtn("TPSheriff", "Телепорт к шерифу")
local tpPlayerBtn = makeBtn("TPPlayer", "Телепорт к игроку")

-- Панель выбора игрока
local playerList = Instance.new("Frame")
playerList.Name = "PlayerList"
playerList.BackgroundColor3 = Color3.new(1,1,1)
playerList.BackgroundTransparency = 0.3
playerList.Size = UDim2.new(1, -10, 0, 160)
playerList.Visible = false
playerList.ZIndex = 6
Instance.new("UICorner", playerList).CornerRadius = UDim.new(0, 12)
playerList.Parent = scroll

local playerScroll = Instance.new("ScrollingFrame")
playerScroll.BackgroundTransparency = 1
playerScroll.Size = UDim2.new(1,0,1,0)
playerScroll.CanvasSize = UDim2.new(0,0,0,0)
playerScroll.ScrollBarThickness = 3
playerScroll.ZIndex = 6
playerScroll.Parent = playerList

local playerLayout = Instance.new("UIListLayout")
playerLayout.Padding = UDim.new(0, 5)
playerLayout.FillDirection = Enum.FillDirection.Vertical
playerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
playerLayout.SortOrder = Enum.SortOrder.Name
playerLayout.Parent = playerScroll

local function updatePlayerList()
    for _, child in ipairs(playerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local y = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local b = Instance.new("TextButton")
            b.Text = plr.Name
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 15
            b.TextColor3 = Color3.new(1,1,1)
            b.BackgroundColor3 = Color3.fromRGB(100,100,100)
            b.BackgroundTransparency = 0.4
            b.Size = UDim2.new(1, 0, 0, 30)
            b.ZIndex = 6
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
            b.MouseButton1Click:Connect(function()
                teleportToPlayer(plr)
                playerList.Visible = false
                tpPlayerBtn.Visible = true
            end)
            b.Parent = playerScroll
            y = y + 30 + playerLayout.Padding.Offset
        end
    end
    playerScroll.CanvasSize = UDim2.new(0,0,0,y)
end

-- ===== Ползунки =====
local function createSlider(name, parent)
    local slider = Instance.new("Frame")
    slider.Name = name
    slider.BackgroundColor3 = Color3.new(1,1,1)
    slider.BackgroundTransparency = 0.5
    slider.Size = UDim2.new(1, 0, 0, 30)
    slider.ZIndex = 4
    slider.Visible = false
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 8)

    local track = Instance.new("Frame")
    track.BackgroundColor3 = Color3.new(0.8,0.8,0.8)
    track.BackgroundTransparency = 0.4
    track.AnchorPoint = Vector2.new(0.5, 0.5)
    track.Position = UDim2.new(0.5, 0, 0.5, 0)
    track.Size = UDim2.new(1, -20, 0, 6)
    track.BorderSizePixel = 0
    track.ZIndex = 4
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    track.Parent = slider

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 28, 0, 28)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.BackgroundTransparency = 0.2
    thumb.Text = ""
    thumb.AutoButtonColor = false
    thumb.ZIndex = 5
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    thumb.Parent = slider

    slider.Parent = parent
    return slider, thumb
end

local speedSlider, speedThumb = createSlider("SpeedSlider", scroll)
local jumpSlider, jumpThumb = createSlider("JumpSlider", scroll)

-- ===== Общие функции для ползунков =====
local function updateThumbPosition(slider, thumb, value, minVal, maxVal)
    if not slider.Visible then return end
    local range = maxVal - minVal
    local fraction = (value - minVal) / range
    local trackWidth = slider.AbsoluteSize.X - 20
    thumb.Position = UDim2.new(0, 10 + fraction * trackWidth, 0.5, 0)
end

local function updateValueFromThumb(input, slider, thumb, minVal, maxVal, setter)
    if not slider.Visible then return end
    local trackWidth = slider.AbsoluteSize.X - 20
    local relativeX = input.Position.X - slider.AbsolutePosition.X - 10
    local fraction = math.clamp(relativeX / trackWidth, 0, 1)
    local newVal = math.floor(minVal + fraction * (maxVal - minVal))
    setter(newVal)
    updateThumbPosition(slider, thumb, newVal, minVal, maxVal)
end

-- ===== Логика перетаскивания =====
local draggingSlider = nil
local draggingThumb = nil
local dragMin, dragMax, dragSetVal

local function startDrag(slider, thumb, minVal, maxVal, setVal)
    draggingSlider = slider
    draggingThumb = thumb
    dragMin = minVal
    dragMax = maxVal
    dragSetVal = setVal
    TweenService:Create(thumb, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 34, 0, 34)}):Play()
end

local function stopDrag()
    if draggingThumb then
        TweenService:Create(draggingThumb, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 28, 0, 28)}):Play()
    end
    draggingSlider = nil
    draggingThumb = nil
end

speedThumb.MouseButton1Down:Connect(function()
    startDrag(speedSlider, speedThumb, 16, 100, function(v) speedValue = v; setSpeed() end)
end)
jumpThumb.MouseButton1Down:Connect(function()
    startDrag(jumpSlider, jumpThumb, 0, 200, function(v) jumpValue = v; setJump() end)
end)

speedThumb.MouseButton1Up:Connect(stopDrag)
jumpThumb.MouseButton1Up:Connect(stopDrag)
speedThumb.MouseLeave:Connect(stopDrag)
jumpThumb.MouseLeave:Connect(stopDrag)

UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and draggingThumb and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        updateValueFromThumb(input, draggingSlider, draggingThumb, dragMin, dragMax, dragSetVal)
    end
end)

speedSlider.Changed:Connect(function(prop)
    if prop == "AbsoluteSize" then updateThumbPosition(speedSlider, speedThumb, speedValue, 16, 100) end
end)
jumpSlider.Changed:Connect(function(prop)
    if prop == "AbsoluteSize" then updateThumbPosition(jumpSlider, jumpThumb, jumpValue, 0, 200) end
end)

-- ==================== АНИМАЦИЯ КАЧАНИЯ КНОПОК ПРИ СКРОЛЛЕ ====================
local lastCanvasPos = scroll.CanvasPosition

scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    local newPos = scroll.CanvasPosition
    if newPos ~= lastCanvasPos then
        lastCanvasPos = newPos
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then
                local origSize = child.Size
                local shakeSize = UDim2.new(1, 0, 0, origSize.Y.Offset + 4)
                TweenService:Create(child, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = shakeSize}):Play()
                TweenService:Create(child, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    {Size = origSize}):Play()
            end
        end
    end
end)

-- ==================== ОБЩАЯ ФУНКЦИЯ РАЗМЕРА СКРОЛЛА ====================
local function updateCanvasSize()
    local h = 0
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("Frame") then
            h = h + child.AbsoluteSize.Y + listLayout.Padding.Offset
        end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, h)
end

mainPanel.Parent = gui

-- ==================== АНИМАЦИИ ОКНА (эффект капли – горизонтальная) ====================
local isOpen = false
local openInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)

local function getMenuCenter()
    return Vector2.new(
        menuBtn.AbsolutePosition.X + menuBtn.AbsoluteSize.X/2,
        menuBtn.AbsolutePosition.Y + menuBtn.AbsoluteSize.Y/2
    )
end

local function setMini()
    local c = getMenuCenter()
    mainPanel.Position = UDim2.new(0, c.X, 0, c.Y)
    mainPanel.Size = UDim2.new(0,0,0,0)
    mainPanel.BackgroundTransparency = 1
    mainCorner.CornerRadius = UDim.new(1, 0)
end

local function openPanel()
    isOpen = true
    setMini()
    menuBtn.Visible = false
    overlay.Visible = true
    mainPanel.Visible = true
    updateCanvasSize()
    updatePlayerList()
    updateThumbPosition(speedSlider, speedThumb, speedValue, 16, 100)
    updateThumbPosition(jumpSlider, jumpThumb, jumpValue, 0, 200)
    
    -- Фон затемняется
    TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.4}):Play()
    
    -- Этап 1: из кнопки вылетает горизонтальная капля (широкий овал)
    local dropletSize = UDim2.new(0, 260, 0, 80)  -- было 80×260
    local centerPos = UDim2.new(0.5, 0, 0.5, 0)
    local tween1 = TweenService:Create(mainPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = dropletSize,
        Position = centerPos,
        BackgroundTransparency = 0.4
    })
    tween1:Play()
    
    -- Этап 2: капля расширяется в горизонтальное меню
    tween1.Completed:Connect(function()
        TweenService:Create(mainPanel, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 480, 0, 340),   -- было 320×600
            BackgroundTransparency = 0.5
        }):Play()
        TweenService:Create(mainCorner, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            CornerRadius = UDim.new(0, 28)
        }):Play()
    end)
end

local function closePanel()
    isOpen = false
    TweenService:Create(overlay, closeInfo, {BackgroundTransparency = 1}):Play()
    overlay.Visible = false

    -- Сначала возвращаем скругление до круга
    TweenService:Create(mainCorner, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
        {CornerRadius = UDim.new(1, 0)}):Play()

    local c = getMenuCenter()
    -- Схлопываем в исходную точку (кнопку)
    TweenService:Create(mainPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0, c.X, 0, c.Y),
        Size = UDim2.new(0,0,0,0),
        BackgroundTransparency = 1
    }):Play()
    
    task.delay(0.4, function()
        mainPanel.Visible = false
        menuBtn.Visible = true
        playerList.Visible = false
        tpPlayerBtn.Visible = true
    end)
end

menuBtn.MouseButton1Click:Connect(function() if isOpen then closePanel() else openPanel() end end)
closeBtn.MouseButton1Click:Connect(closePanel)
overlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        closePanel()
    end
end)

-- ==================== ОБРАБОТЧИКИ КНОПОК ====================
local function setActive(btn, state)
    btn.TextColor3 = state and Color3.fromRGB(52,199,89) or Color3.new(0,0,0)
end

espPlayersBtn.MouseButton1Click:Connect(function()
    espPlayers = not espPlayers
    if espPlayers then
        espPlayersBtn.Text = "ESP игроков ВКЛ"
        setActive(espPlayersBtn, true)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                plr.CharacterAdded:Connect(onCharacterAdded)
                if plr.Character then addPlayerESP(plr) end
            end
        end
    else
        espPlayersBtn.Text = "ESP игроков ВЫКЛ"
        setActive(espPlayersBtn, false)
        clearPlayerESP()
    end
end)

espItemsBtn.MouseButton1Click:Connect(function()
    espItems = not espItems
    if espItems then
        espItemsBtn.Text = "ESP предметов ВКЛ"
        setActive(espItemsBtn, true)
    else
        espItemsBtn.Text = "ESP предметов ВЫКЛ"
        setActive(espItemsBtn, false)
        clearItemESP()
    end
end)

noclipBtn.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        noclipBtn.Text = "Хождение сквозь ВКЛ"
        setActive(noclipBtn, true)
    else
        noclipBtn.Text = "Хождение сквозь ВЫКЛ"
        setActive(noclipBtn, false)
    end
end)

speedBtn.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    speedSlider.Visible = speedEnabled
    if speedEnabled then
        speedBtn.Text = "Скорость ВКЛ"
        setActive(speedBtn, true)
        updateThumbPosition(speedSlider, speedThumb, speedValue, 16, 100)
    else
        speedBtn.Text = "Скорость ВЫКЛ"
        setActive(speedBtn, false)
    end
    setSpeed()
    updateCanvasSize()
end)

jumpBtn.MouseButton1Click:Connect(function()
    jumpEnabled = not jumpEnabled
    jumpSlider.Visible = jumpEnabled
    if jumpEnabled then
        jumpBtn.Text = "Прыжок ВКЛ"
        setActive(jumpBtn, true)
        updateThumbPosition(jumpSlider, jumpThumb, jumpValue, 0, 200)
    else
        jumpBtn.Text = "Прыжок ВЫКЛ"
        setActive(jumpBtn, false)
    end
    setJump()
    updateCanvasSize()
end)

pickupBtn.MouseButton1Click:Connect(pickUpPistol)

murderBtn.MouseButton1Click:Connect(function()
    murderEnabled = not murderEnabled
    if murderEnabled then
        murderBtn.Text = "Стать убийцей ВКЛ"
        setActive(murderBtn, true)
        if sheriffEnabled then
            sheriffEnabled = false
            sheriffBtn.Text = "Стать шерифом ВЫКЛ"
            setActive(sheriffBtn, false)
        end
    else
        murderBtn.Text = "Стать убийцей ВЫКЛ"
        setActive(murderBtn, false)
    end
end)

sheriffBtn.MouseButton1Click:Connect(function()
    sheriffEnabled = not sheriffEnabled
    if sheriffEnabled then
        sheriffBtn.Text = "Стать шерифом ВКЛ"
        setActive(sheriffBtn, true)
        if murderEnabled then
            murderEnabled = false
            murderBtn.Text = "Стать убийцей ВЫКЛ"
            setActive(murderBtn, false)
        end
    else
        sheriffBtn.Text = "Стать шерифом ВЫКЛ"
        setActive(sheriffBtn, false)
    end
end)

aimbotBtn.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    if aimbotEnabled then
        aimbotBtn.Text = "Aimbot ВКЛ"
        setActive(aimbotBtn, true)
    else
        aimbotBtn.Text = "Aimbot ВЫКЛ"
        setActive(aimbotBtn, false)
    end
end)

shootWallBtn.MouseButton1Click:Connect(function()
    shootWallEnabled = not shootWallEnabled
    if shootWallEnabled then
        shootWallBtn.Text = "Стрельба сквозь стену ВКЛ"
        setActive(shootWallBtn, true)
    else
        shootWallBtn.Text = "Стрельба сквозь стену ВЫКЛ"
        setActive(shootWallBtn, false)
    end
end)

tpWeaponBtn.MouseButton1Click:Connect(teleportToWeapon)

saveBtn.MouseButton1Click:Connect(saveSettings)
loadBtn.MouseButton1Click:Connect(loadSettings)

tpMurdererBtn.MouseButton1Click:Connect(teleportToNearestMurderer)
tpSheriffBtn.MouseButton1Click:Connect(teleportToNearestSheriff)

tpPlayerBtn.MouseButton1Click:Connect(function()
    playerList.Visible = not playerList.Visible
    tpPlayerBtn.Visible = not playerList.Visible
    if playerList.Visible then updatePlayerList() end
    updateCanvasSize()
end)

-- ==================== ЦИКЛЫ ОБНОВЛЕНИЯ ====================
RunService.Heartbeat:Connect(function()
    if espPlayers then updatePlayerESP() end
    if espItems then updateItemESP() end
    if noclipEnabled then noclipLoop() end
    if aimbotEnabled then aimbotLook() end
    if shootWallEnabled then shootThroughWalls() end

    if murderEnabled and tick() - lastMurderTry > 1 then
        becomeMurderer()
        lastMurderTry = tick()
    end
    if sheriffEnabled and tick() - lastSheriffTry > 1 then
        becomeSheriff()
        lastSheriffTry = tick()
    end

    if speedEnabled then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            if char.Humanoid.WalkSpeed ~= speedValue then
                char.Humanoid.WalkSpeed = speedValue
            end
        end
    end
    if jumpEnabled then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.UseJumpPower = true
            if char.Humanoid.JumpPower ~= jumpValue then
                char.Humanoid.JumpPower = jumpValue
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if speedEnabled then setSpeed() end
    if jumpEnabled then setJump() end
    if speedSlider.Visible then updateThumbPosition(speedSlider, speedThumb, speedValue, 16, 100) end
    if jumpSlider.Visible then updateThumbPosition(jumpSlider, jumpThumb, jumpValue, 0, 200) end
end)

setMini()
mainPanel.Visible = false
print("✅ Горизонтальное меню с каплей загружено! Просто поменяны размеры.")
