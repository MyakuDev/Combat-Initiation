local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()
local gui = Library:create{Theme = Library.Themes.Serika}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

_G.Combat = {
    KillAll       = {Enabled = false, Distance = 500, Speed = 0.1, Delay = 0.05, MaxPerTick = 5, HitParts = {"Head", "HumanoidRootPart"}},
    KillAura      = {Enabled = false, Distance = 25, Speed = 0.1, Delay = 0.05, MaxPerTick = 3, HitParts = {"Head", "HumanoidRootPart"}},
    AutoTowel     = {Enabled = false, Range = 50, Distance = 10},
    ShieldBypass  = {Enabled = false, Speed = 0.1},
    FreezeRay     = {Enabled = false, Distance = 500, Speed = 0.1, Charged = true},
    AutoFreezeRay = {Enabled = false, Distance = 500, Speed = 0.1},
    SuperBall     = {Enabled = false, Speed = 0.1},
    Umbrella      = {Enabled = false, Speed = 0.1},
    ZombieStaff   = {Enabled = false, Distance = 500, Speed = 0.1},
    DamageEvent   = {Enabled = false, Distance = 500, Speed = 0.1},
    Firebrand     = {Enabled = false, Distance = 500, Speed = 0.1},
    Speed         = {Enabled = false, Value = 16},
    JumpPower     = {Enabled = false, Value = 50},
    Noclip        = {Enabled = false},
    InfiniteJump  = {Enabled = false},
    Fly           = {Enabled = false, Speed = 50},
    AntiAFK       = {Enabled = false, Interval = 60},
    ModDetect     = {Enabled = true, KickMethod = "kick"},
    EnemyTracker  = {Enabled = true, Debug = true},
    AutoConfig    = {Enabled = true},
    Blink         = {Enabled = true, Key = Enum.KeyCode.LeftShift, Distance = 25, Speed = 0.15, Cooldown = 0.5},
}
local Combat = _G.Combat

local KillAll       = Combat.KillAll
local KillAura      = Combat.KillAura
local AutoTowel     = Combat.AutoTowel
local ShieldBypass  = Combat.ShieldBypass
local FreezeRay     = Combat.FreezeRay
local AutoFreezeRay = Combat.AutoFreezeRay
local SuperBall     = Combat.SuperBall
local Umbrella      = Combat.Umbrella
local ZombieStaff   = Combat.ZombieStaff
local DamageEvent   = Combat.DamageEvent
local Firebrand     = Combat.Firebrand
local Speed         = Combat.Speed
local JumpPower     = Combat.JumpPower
local Noclip        = Combat.Noclip
local InfiniteJump  = Combat.InfiniteJump
local Fly           = Combat.Fly
local AntiAFK       = Combat.AntiAFK
local ModDetect     = Combat.ModDetect
local EnemyTracker  = Combat.EnemyTracker
local AutoConfig    = Combat.AutoConfig
local Blink         = Combat.Blink

local function notify(title, text, dur)
    if gui and gui.Notification then
        pcall(function() gui:Notification{Title = title, Text = text, Duration = dur or 3} end)
    end
end

local function getChar() return LocalPlayer.Character end
local function getHrp()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

--

local BlinkRunning = false
local BlinkLastTick = 0

local function getMoveDirection()
    local hum = getHum()
    if not hum then return nil end
    local moveVec = hum.MoveDirection
    if moveVec.Magnitude > 0 then return moveVec.Unit end
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
    if dir.Magnitude > 0 then return dir.Unit end
    return nil
end

local function doBlink()
    local hrp = getHrp()
    if not hrp then return end
    if tick() - BlinkLastTick < Blink.Cooldown then return end
    local dir = getMoveDirection()
    if not dir then return end
    BlinkLastTick = tick()
    BlinkRunning = true
    local startCf = hrp.CFrame
    local endCf = CFrame.new(hrp.Position + dir * Blink.Distance) * (startCf - startCf.Position)
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(Blink.Speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {CFrame = endCf}
    )
    tween:Play()
    tween.Completed:Connect(function() BlinkRunning = false end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not Blink.Enabled then return end
    if input.KeyCode == Blink.Key then doBlink() end
end)

--

local Config = {
    EnemiesFolder = nil,
    ProjectilesFolder = nil,
    MapsFolder = nil,
    RemotesFolder = nil,
    DetectedTools = {},
    DetectedLimbNames = {},
    DetectedEnemyData = {},
}

local function verifyGame()
    if not AutoConfig.Enabled then return end
    print("================================")
    print("[AutoConfig] Verifying Combat Initiation structure...")

    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        Config.EnemiesFolder = enemies
        print("  [OK] workspace.Enemies (" .. #enemies:GetChildren() .. " children)")
    else
        print("  [MISSING] workspace.Enemies")
    end

    local projectiles = workspace:FindFirstChild("Projectiles")
    if projectiles then
        Config.ProjectilesFolder = projectiles
        print("  [OK] workspace.Projectiles")
    else
        print("  [MISSING] workspace.Projectiles")
    end

    local maps = workspace:FindFirstChild("Maps")
    if maps then
        Config.MapsFolder = maps
        local map = maps:FindFirstChild("Map")
        local room = map and map:FindFirstChild("Room")
        print("  [OK] workspace.Maps.Map.Room (" .. (room and #room:GetChildren() or 0) .. " children)")
    else
        print("  [MISSING] workspace.Maps")
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        Config.RemotesFolder = events
        local re = events:FindFirstChild("RemoteEvents")
        local count = re and #re:GetChildren() or 0
        print("  [OK] ReplicatedStorage.Events.RemoteEvents (" .. count .. " remotes)")
    else
        print("  [MISSING] ReplicatedStorage.Events")
    end

    print("================================")
end

verifyGame()

local function scanLimbs()
    if not Config.EnemiesFolder then return end
    local first = Config.EnemiesFolder:GetChildren()[1]
    if not first then return end
    local limbs = {}
    for _, child in ipairs(first:GetChildren()) do
        if child:IsA("BasePart") then table.insert(limbs, child.Name) end
    end
    Config.DetectedLimbNames = limbs
    if AutoConfig.Enabled then print("[AutoConfig] Enemy limbs detected: " .. table.concat(limbs, ", ")) end
end
scanLimbs()

local function scanEnemies()
    if not Config.EnemiesFolder then return end
    Config.DetectedEnemyData = {}
    for _, model in ipairs(Config.EnemiesFolder:GetChildren()) do
        if model:IsA("Model") then
            Config.DetectedEnemyData[model.Name] = {
                HasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil,
                HasHRP = model:FindFirstChild("HumanoidRootPart") ~= nil,
                HasCenter = model:FindFirstChild("Center") ~= nil,
                HasShield = model:FindFirstChild("Shield") ~= nil,
            }
        end
    end
    if AutoConfig.Enabled then
        local n = 0
        for _ in pairs(Config.DetectedEnemyData) do n = n + 1 end
        print("[AutoConfig] Enemies scanned: " .. n)
    end
end
scanEnemies()

local function scanTools()
    Config.DetectedTools = {}
    local function check(tool)
        if not tool:IsA("Tool") then return end
        local info = {Name = tool.Name, Remotes = {}}
        for _, child in ipairs(tool:GetDescendants()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                table.insert(info.Remotes, child.Name)
            end
        end
        Config.DetectedTools[tool.Name] = info
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do check(t) end end
    local char = getChar()
    if char then for _, t in ipairs(char:GetChildren()) do check(t) end end
    if AutoConfig.Enabled then
        print("[AutoConfig] Tools scanned:")
        for name, info in pairs(Config.DetectedTools) do
            print("  - " .. name .. " (" .. #info.Remotes .. " remotes: " .. table.concat(info.Remotes, ", ") .. ")")
        end
    end
end
scanTools()

local function applyAutoConfig()
    if not AutoConfig.Enabled then return end
    if Config.DetectedLimbNames then
        local hasCenter, hasHead = false, false
        for _, name in ipairs(Config.DetectedLimbNames) do
            if name == "Center" then hasCenter = true end
            if name == "Head" then hasHead = true end
        end
        if hasCenter then
            KillAll.HitParts  = {"Center", "HumanoidRootPart"}
            KillAura.HitParts = {"Center", "HumanoidRootPart"}
            print("[AutoConfig] Hit parts set to: Center, HumanoidRootPart")
        elseif hasHead then
            KillAll.HitParts  = {"Head", "HumanoidRootPart"}
            KillAura.HitParts = {"Head", "HumanoidRootPart"}
            print("[AutoConfig] Hit parts set to: Head, HumanoidRootPart")
        end
    end
    print("[AutoConfig] Configuration applied.")
end
applyAutoConfig()

print("================================")
print("[AutoConfig] Initialization complete.")
print("================================")

--

local Enemies = {}
local EnemiesFolder = nil

local function trackEnemy(model)
    if not model:IsA("Model") then return end
    if Enemies[model] then return end
    Enemies[model] = true
    if EnemyTracker.Debug then
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local center = model:FindFirstChild("Center")
        print("[EnemyTracker] + " .. model.Name ..
            " (hum=" .. tostring(hum ~= nil) ..
            " hrp=" .. tostring(hrp ~= nil) ..
            " center=" .. tostring(center ~= nil) .. ")")
    end
end

local function untrackEnemy(model)
    if not Enemies[model] then return end
    Enemies[model] = nil
    if EnemyTracker.Debug then print("[EnemyTracker] - " .. model.Name) end
end

local function bindEnemyFolder(folder)
    EnemiesFolder = folder
    local tracked = 0
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            trackEnemy(child)
            tracked = tracked + 1
        end
    end
    print("[EnemyTracker] Bound: " .. folder:GetFullName() .. " (" .. tracked .. " tracked)")
    folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then trackEnemy(child) end
    end)
    folder.ChildRemoved:Connect(function(child)
        untrackEnemy(child)
    end)
end

if Config.EnemiesFolder then
    bindEnemyFolder(Config.EnemiesFolder)
else
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Enemies" and not EnemiesFolder then bindEnemyFolder(child) end
    end)
end

local function getEnemies()
    if EnemiesFolder then
        local list = {}
        for _, child in ipairs(EnemiesFolder:GetChildren()) do
            if child:IsA("Model") then table.insert(list, child) end
        end
        return list
    end
    return {}
end

local function isAlive(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

--

local ROLE_FILES = {"Trusted","Developers","AssistantDevelopers","RetiredDevelopers","Consultants","HeadOfStaff","SeniorModerators","Moderators","JuniorModerators","Contributors"}
local RoleCache = {}

local function loadRoles()
    local root = (_G.Combat and _G.Combat.JsonRoot) or "C:/Users/kirok/OneDrive/Desktop/Yunrine/Lua/Combat Initiation/json"
    for _, roleName in ipairs(ROLE_FILES) do
        local ok, raw = pcall(readfile, root .. "/" .. roleName .. ".json")
        if ok and raw and raw ~= "" then
            local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and decoded and decoded.users then RoleCache[roleName] = decoded.users end
        end
    end
end
loadRoles()

local function isStaff(userId, name)
    for roleName, users in pairs(RoleCache) do
        for _, entry in ipairs(users) do
            if entry.userId and entry.userId == userId then return roleName end
            if entry.name and name and entry.name:lower() == name:lower() then return roleName end
        end
    end
    return nil
end

local function checkStaff(plr)
    if plr == LocalPlayer then return end
    if not ModDetect.Enabled then return end
    local role = isStaff(plr.UserId, plr.Name)
    if role then
        notify("MOD DETECTED", plr.Name .. " (" .. role .. ")", 5)
        task.wait(0.5)
        if ModDetect.KickMethod == "shutdown" then game:Shutdown()
        else LocalPlayer:Kick("Windforce staff: " .. plr.Name .. " (" .. role .. ")") end
    end
end
for _, p in ipairs(Players:GetPlayers()) do checkStaff(p) end
Players.PlayerAdded:Connect(checkStaff)

--

local function pickHitPart(targetModel, hitParts)
    for _, partName in ipairs(hitParts) do
        local part = targetModel:FindFirstChild(partName)
        if part then return part end
    end
    return targetModel:FindFirstChild("HumanoidRootPart")
end

local function firePaintball(targetModel, hitParts)
    local char = getChar()
    if not char then return end
    local gun = char:FindFirstChild("Paintball Gun") or LocalPlayer.Backpack:FindFirstChild("Paintball Gun")
    if not gun then return end
    local ev = gun:FindFirstChild("VerifyHit")
    if not ev then return end
    local hum = targetModel:FindFirstChildOfClass("Humanoid")
    local hrp = targetModel:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local hitPart = pickHitPart(targetModel, hitParts)
    if not hitPart then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    ev:FireServer(hum, hitPart.Position, myHrp and myHrp.Position or hitPart.Position, hitPart, {Color = BrickColor.new("Light blue"), Quickdraw = false, ObjectBreak = false})
end

local function fireRocket(targetModel, hitParts)
    local char = getChar()
    if not char then return end
    local rocket = char:FindFirstChild("Rocket Launcher") or LocalPlayer.Backpack:FindFirstChild("Rocket Launcher")
    if not rocket then return end
    local ev = rocket:FindFirstChild("CreateExplosion")
    if not ev then return end
    local hitPart = pickHitPart(targetModel, hitParts)
    if not hitPart then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    ev:FireServer(hitPart.Position, myHrp and myHrp.Position or hitPart.Position, hitPart, {})
end

task.spawn(function()
    while true do
        task.wait(KillAll.Speed)
        if not KillAll.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        local fired = 0
        for _, model in ipairs(getEnemies()) do
            if fired >= KillAll.MaxPerTick then break end
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= KillAll.Distance then
                pcall(firePaintball, model, KillAll.HitParts)
                pcall(fireRocket, model, KillAll.HitParts)
                fired = fired + 1
                task.wait(KillAll.Delay)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(KillAura.Speed)
        if not KillAura.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        local fired = 0
        for _, model in ipairs(getEnemies()) do
            if fired >= KillAura.MaxPerTick then break end
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= KillAura.Distance then
                pcall(firePaintball, model, KillAura.HitParts)
                pcall(fireRocket, model, KillAura.HitParts)
                fired = fired + 1
                task.wait(KillAura.Delay)
            end
        end
    end
end)

--

local function fireFreezeRay(targetModel)
    local char = getChar()
    if not char then return end
    local gun = char:FindFirstChild("Freeze Ray") or LocalPlayer.Backpack:FindFirstChild("Freeze Ray")
    if not gun then return end
    local ev = gun:FindFirstChild("VerifyHit")
    if not ev then return end
    local hum = targetModel:FindFirstChildOfClass("Humanoid")
    local hrp = targetModel:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local center = targetModel:FindFirstChild("Center") or hrp
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    local aimVec = myHrp and (myHrp.Position + Vector3.new(0, 5, 0)) or hrp.Position + Vector3.new(0, 5, 0)
    ev:FireServer(hum, center.Position, aimVec, center, {Charged = FreezeRay.Charged, Quickdraw = false, ObjectBreak = false})
end

task.spawn(function()
    while true do
        task.wait(FreezeRay.Speed)
        if not FreezeRay.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, model in ipairs(getEnemies()) do
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= FreezeRay.Distance then
                pcall(fireFreezeRay, model)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(AutoFreezeRay.Speed)
        if not AutoFreezeRay.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, model in ipairs(getEnemies()) do
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= AutoFreezeRay.Distance then
                pcall(fireFreezeRay, model)
            end
        end
    end
end)

--

local function fireUmbrella()
    local char = getChar()
    if not char then return end
    local gear = char:FindFirstChild("UmbrellaGear") or LocalPlayer.Backpack:FindFirstChild("UmbrellaGear")
    if not gear then return end
    local ev = gear:FindFirstChild("RemoteEvent")
    if not ev then return end
    pcall(function() ev:FireServer(true) end)
end

task.spawn(function()
    while true do
        task.wait(Umbrella.Speed)
        if not Umbrella.Enabled then continue end
        pcall(fireUmbrella)
    end
end)

--

local function fireSuperBall()
    local char = getChar()
    if not char then return end
    local ball = LocalPlayer.Backpack:FindFirstChild("Superball") or char:FindFirstChild("Superball")
    if not ball then return end
    local ev = ball:FindFirstChild("ThrowBall")
    if not ev then return end
    local myHrp = getHrp()
    if not myHrp then return end
    pcall(function()
        ev:InvokeServer(
            myHrp.Position + Vector3.new(0, 5, 0),
            Vector3.new(-6.577060007728619e-10, 7.8036966442596167e-05, 5.7456515101250716e-09),
            0,
            nil
        )
    end)
end

task.spawn(function()
    while true do
        task.wait(SuperBall.Speed)
        if not SuperBall.Enabled then continue end
        pcall(fireSuperBall)
    end
end)

--

local function fireZombieStaff(targetModel)
    local char = getChar()
    if not char then return end
    local staff = char:FindFirstChild("Zombie Staff") or LocalPlayer.Backpack:FindFirstChild("Zombie Staff")
    if not staff then return end
    local dmg = staff:FindFirstChild("DamageEvent")
    if not dmg or not dmg:IsA("RemoteEvent") then return end
    local hum = targetModel:FindFirstChildOfClass("Humanoid")
    local hrp = targetModel:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local center = targetModel:FindFirstChild("Center") or hrp
    dmg:FireServer(center, hum)
end

task.spawn(function()
    while true do
        task.wait(ZombieStaff.Speed)
        if not ZombieStaff.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, model in ipairs(getEnemies()) do
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= ZombieStaff.Distance then
                pcall(fireZombieStaff, model)
            end
        end
    end
end)

--

local function fireFirebrand(targetModel)
    local char = getChar()
    if not char then return end
    local brand = char:FindFirstChild("Firebrand") or LocalPlayer.Backpack:FindFirstChild("Firebrand")
    if not brand then return end
    local offhand = brand:FindFirstChild("VerifyOffhand")
    if offhand then pcall(function() offhand:FireServer("Swing") end) end
    local hit = brand:FindFirstChild("VerifyHit")
    if hit then
        local hum = targetModel:FindFirstChildOfClass("Humanoid")
        local hrp = targetModel:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            local rightLeg = targetModel:FindFirstChild("Right Leg") or hrp
            local myHrp = char:FindFirstChild("HumanoidRootPart")
            local dir = myHrp and (hrp.Position - myHrp.Position).Unit or Vector3.new(0, 0, -1)
            pcall(function()
                hit:FireServer("Slash", hum, dir, rightLeg, true, nil, {AttackDash = false, Overhead = false, Backstab = false})
            end)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(Firebrand.Speed)
        if not Firebrand.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, model in ipairs(getEnemies()) do
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= Firebrand.Distance then
                pcall(fireFirebrand, model)
                break
            end
        end
    end
end)

--

local ToolCache = {}
local function scanToolsCache()
    ToolCache = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then ToolCache[t.Name] = t end
        end
    end
    local char = getChar()
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then ToolCache[t.Name] = t end
        end
    end
end

local function fireDamageEvents(targetModel)
    scanToolsCache()
    local char = getChar()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for name, tool in pairs(ToolCache) do
        local dmg = tool:FindFirstChild("DamageEvent")
        if dmg and dmg:IsA("RemoteEvent") then
            local targetHum = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
            local targetCenter = targetModel and (targetModel:FindFirstChild("Center") or targetModel:FindFirstChild("HumanoidRootPart"))
            if targetHum and targetCenter then
                pcall(function() dmg:FireServer(targetCenter, targetHum) end)
            else
                pcall(function() dmg:FireServer(tool, hum) end)
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(DamageEvent.Speed)
        if not DamageEvent.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, model in ipairs(getEnemies()) do
            if not isAlive(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= DamageEvent.Distance then
                pcall(fireDamageEvents, model)
            end
        end
    end
end)

--

local function fireTowel(cframe)
    local char = getChar()
    if not char then return end
    local trowel = char:FindFirstChild("Trowel") or LocalPlayer.Backpack:FindFirstChild("Trowel")
    if not trowel then return end
    local ev = trowel:FindFirstChild("PlaceReplicate")
    if not ev then return end
    local maps = Config.MapsFolder or workspace:FindFirstChild("Maps")
    local map = maps and maps:FindFirstChild("Map")
    local room = map and map:FindFirstChild("Room")
    if not room then return end
    local anchor = room:GetChildren()[21]
    if not anchor then return end
    ev:FireServer(anchor, cframe, {})
end

local function getProjectiles()
    if Config.ProjectilesFolder then return Config.ProjectilesFolder:GetChildren() end
    local folder = workspace:FindFirstChild("Projectiles")
    if not folder then return {} end
    return folder:GetChildren()
end

task.spawn(function()
    while true do
        task.wait(0.05)
        if not AutoTowel.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, proj in ipairs(getProjectiles()) do
            local projPart = proj:IsA("BasePart") and proj or proj:FindFirstChildWhichIsA("BasePart")
            if not projPart then continue end
            local dir = (myHrp.Position - projPart.Position)
            if dir.Magnitude > AutoTowel.Range then continue end
            local velocity = projPart.AssemblyLinearVelocity
            if velocity.Magnitude < 1 then continue end
            local toMe = dir.Unit
            local toVel = velocity.Unit
            if toMe:Dot(toVel) < 0.5 then continue end
            local placePos = myHrp.Position + toMe * AutoTowel.Distance
            local placeCf = CFrame.new(placePos, myHrp.Position)
            pcall(fireTowel, placeCf)
            break
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(ShieldBypass.Speed)
        if not ShieldBypass.Enabled then continue end
        for _, npc in ipairs(getEnemies()) do
            local shield = npc:FindFirstChild("Shield")
            if shield and shield:IsA("UnionOperation") then
                pcall(function()
                    shield.CanCollide = false
                    shield.Transparency = 1
                    if shield:FindFirstChildOfClass("Decal") then shield:FindFirstChildOfClass("Decal"):Destroy() end
                end)
            end
        end
    end
end)

--

RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if Speed.Enabled then
        hum.WalkSpeed = Speed.Value
    elseif hum.WalkSpeed ~= 16 then
        hum.WalkSpeed = 16
    end
end)

RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if JumpPower.Enabled then
        hum.UseJumpPower = true
        hum.JumpPower = JumpPower.Value
    elseif hum.UseJumpPower and hum.JumpPower ~= 50 then
        hum.JumpPower = 50
    end
end)

RunService.Stepped:Connect(function()
    local char = getChar()
    if not char then return end
    if Noclip.Enabled then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not InfiniteJump.Enabled then return end
    local hum = getHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local flyBV, flyBG
RunService.Heartbeat:Connect(function()
    local hrp = getHrp()
    if not hrp then return end
    if Fly.Enabled then
        if not flyBV or flyBV.Parent ~= hrp then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBV.Parent = hrp
        end
        if not flyBG or flyBG.Parent ~= hrp then
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBG.P = 1000
            flyBG.D = 50
            flyBG.Parent = hrp
        end
        local md = Vector3.zero
        local cam = workspace.CurrentCamera
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.new(0,1,0) end
        flyBV.Velocity = md.Magnitude > 0 and (md.Unit * Fly.Speed) or Vector3.zero
        flyBG.CFrame = cam.CFrame
    else
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
    end
end)

task.spawn(function()
    while true do
        task.wait(AntiAFK.Interval)
        if AntiAFK.Enabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end
end)

local function hookBackpack()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        bp.ChildAdded:Connect(function(t)
            if t:IsA("Tool") then
                task.wait(0.3)
                scanTools()
                scanToolsCache()
            end
        end)
    end
    LocalPlayer.ChildAdded:Connect(function(c)
        if c.Name == "Backpack" then
            c.ChildAdded:Connect(function(t)
                if t:IsA("Tool") then
                    task.wait(0.3)
                    scanTools()
                    scanToolsCache()
                end
            end)
        end
    end)
end

hookBackpack()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    scanTools()
    scanToolsCache()
end)

--

local Main  = gui:tab{Icon = "rbxassetid://6034996695", Name = "Main"}
local Misc  = gui:tab{Icon = "rbxassetid://6031075931", Name = "Misc"}
local Tools = gui:tab{Icon = "rbxassetid://6031075931", Name = "Tools"}

Main:toggle({Name="Kill All",Default=false,Callback=function(s) KillAll.Enabled = s end})
Main:slider({Name="Kill All Distance",Min=10,Max=2000,Default=500,Callback=function(v) KillAll.Distance = v end})
Main:slider({Name="Kill All Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) KillAll.Speed = v end})
Main:slider({Name="Kill All Delay",Min=0,Max=0.5,Default=0.05,Decimals=2,Callback=function(v) KillAll.Delay = v end})
Main:slider({Name="Kill All Max Per Tick",Min=1,Max=50,Default=5,Callback=function(v) KillAll.MaxPerTick = v end})
Main:dropdown({Name="Kill All Hit Part",StartingText="Head",Items={"Head","HumanoidRootPart","Torso","Left Arm","Right Arm","Left Leg","Right Leg"},Callback=function(v) KillAll.HitParts = {v} end})

Main:toggle({Name="Kill Aura",Default=false,Callback=function(s) KillAura.Enabled = s end})
Main:slider({Name="Kill Aura Distance",Min=5,Max=100,Default=25,Callback=function(v) KillAura.Distance = v end})
Main:slider({Name="Kill Aura Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) KillAura.Speed = v end})
Main:slider({Name="Kill Aura Delay",Min=0,Max=0.5,Default=0.05,Decimals=2,Callback=function(v) KillAura.Delay = v end})
Main:slider({Name="Kill Aura Max Per Tick",Min=1,Max=50,Default=3,Callback=function(v) KillAura.MaxPerTick = v end})
Main:dropdown({Name="Kill Aura Hit Part",StartingText="Head",Items={"Head","HumanoidRootPart","Torso","Left Arm","Right Arm","Left Leg","Right Leg"},Callback=function(v) KillAura.HitParts = {v} end})

Main:toggle({Name="Auto Towel",Default=false,Callback=function(s) AutoTowel.Enabled = s end})
Main:slider({Name="Towel Range",Min=5,Max=200,Default=50,Callback=function(v) AutoTowel.Range = v end})
Main:slider({Name="Towel Distance",Min=1,Max=30,Default=10,Callback=function(v) AutoTowel.Distance = v end})

Main:toggle({Name="Shield Bypass",Default=false,Callback=function(s) ShieldBypass.Enabled = s end})
Main:slider({Name="Shield Bypass Speed",Min=0.01,Max=1,Default=0.1,Decimals=2,Callback=function(v) ShieldBypass.Speed = v end})

Main:toggle({Name="Enemy Tracker",Default=true,Callback=function(s) EnemyTracker.Enabled = s end})
Main:toggle({Name="Enemy Tracker Debug",Default=true,Callback=function(s) EnemyTracker.Debug = s end})

--

Tools:toggle({Name="Freeze Ray",Default=false,Callback=function(s) FreezeRay.Enabled = s end})
Tools:slider({Name="Freeze Ray Distance",Min=10,Max=2000,Default=500,Callback=function(v) FreezeRay.Distance = v end})
Tools:slider({Name="Freeze Ray Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) FreezeRay.Speed = v end})
Tools:toggle({Name="Charged",Default=true,Callback=function(s) FreezeRay.Charged = s end})

Tools:toggle({Name="Auto Freeze Ray",Default=false,Callback=function(s) AutoFreezeRay.Enabled = s end})
Tools:slider({Name="Auto Freeze Ray Distance",Min=10,Max=2000,Default=500,Callback=function(v) AutoFreezeRay.Distance = v end})
Tools:slider({Name="Auto Freeze Ray Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) AutoFreezeRay.Speed = v end})

Tools:toggle({Name="Super Ball",Default=false,Callback=function(s) SuperBall.Enabled = s end})
Tools:slider({Name="Super Ball Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) SuperBall.Speed = v end})

Tools:toggle({Name="Umbrella",Default=false,Callback=function(s) Umbrella.Enabled = s end})
Tools:slider({Name="Umbrella Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) Umbrella.Speed = v end})

Tools:toggle({Name="Zombie Staff",Default=false,Callback=function(s) ZombieStaff.Enabled = s end})
Tools:slider({Name="Zombie Staff Distance",Min=10,Max=2000,Default=500,Callback=function(v) ZombieStaff.Distance = v end})
Tools:slider({Name="Zombie Staff Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) ZombieStaff.Speed = v end})

Tools:toggle({Name="Firebrand",Default=false,Callback=function(s) Firebrand.Enabled = s end})
Tools:slider({Name="Firebrand Distance",Min=10,Max=2000,Default=500,Callback=function(v) Firebrand.Distance = v end})
Tools:slider({Name="Firebrand Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) Firebrand.Speed = v end})

Tools:toggle({Name="Damage Event",Default=false,Callback=function(s) DamageEvent.Enabled = s end})
Tools:slider({Name="Damage Event Distance",Min=10,Max=2000,Default=500,Callback=function(v) DamageEvent.Distance = v end})
Tools:slider({Name="Damage Event Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) DamageEvent.Speed = v end})
Tools:button({Name="Rescan Tools",Callback=function()
    scanTools()
    scanToolsCache()
    notify("Tools", "rescanned", 2)
end})

--

Misc:toggle({Name="Speed",Default=false,Callback=function(s) Speed.Enabled = s end})
Misc:slider({Name="Speed Value",Min=16,Max=500,Default=16,Callback=function(v) Speed.Value = v end})

Misc:toggle({Name="JumpPower",Default=false,Callback=function(s) JumpPower.Enabled = s end})
Misc:slider({Name="JumpPower Value",Min=50,Max=500,Default=50,Callback=function(v) JumpPower.Value = v end})

Misc:toggle({Name="Noclip",Default=false,Callback=function(s) Noclip.Enabled = s end})
Misc:toggle({Name="Infinite Jump",Default=false,Callback=function(s) InfiniteJump.Enabled = s end})

Misc:toggle({Name="Fly",Default=false,Callback=function(s) Fly.Enabled = s end})
Misc:slider({Name="Fly Speed",Min=10,Max=500,Default=50,Callback=function(v) Fly.Speed = v end})

Misc:toggle({Name="Blink",Default=true,Callback=function(s) Blink.Enabled = s end})
Misc:slider({Name="Blink Distance",Min=5,Max=100,Default=25,Callback=function(v) Blink.Distance = v end})
Misc:slider({Name="Blink Speed",Min=0.05,Max=1,Default=0.15,Decimals=2,Callback=function(v) Blink.Speed = v end})
Misc:slider({Name="Blink Cooldown",Min=0.1,Max=3,Default=0.5,Decimals=2,Callback=function(v) Blink.Cooldown = v end})
Misc:keybind({Name="Blink Key",Default=Enum.KeyCode.LeftShift,Callback=function(k) Blink.Key = k.KeyCode or k end})

Misc:toggle({Name="Anti AFK",Default=false,Callback=function(s) AntiAFK.Enabled = s end})
Misc:slider({Name="Anti AFK Interval",Min=10,Max=300,Default=60,Callback=function(v) AntiAFK.Interval = v end})

Misc:button({Name="Reset",Callback=function()
    local hum = getHum()
    if hum then hum.Health = 0 end
end})

Misc:button({Name="Rejoin",Callback=function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end})

notify("Combat Initiation", "loaded", 3)
