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

local ROOT = ".../"
local CONFIG_PATH = ROOT .. "configs/config.json"
local JSON_ROOT = ROOT .. "json/"

local function notify(title, text, dur)
    if gui and gui.Notification then
        pcall(function() gui:Notification{Title = title, Text = text, Duration = dur or 3} end)
    end
end

if _G.Combat and _G.Combat._Active then
    notify("Combat", "Stopping previous instance...", 3)
    print("[Combat] Stopping previous instance...")
    if _G.Combat._Connections then
        for _, conn in pairs(_G.Combat._Connections) do pcall(function() conn:Disconnect() end) end
        _G.Combat._Connections = {}
    end
    if _G.Combat._Loops then
        for _, flag in pairs(_G.Combat._Loops) do flag.Stopped = true end
        _G.Combat._Loops = {}
    end
    if _G.Combat._GUI then pcall(function() _G.Combat._GUI:Destroy() end) end
    _G.Combat._Active = false
    task.wait(0.3)
end

notify("Combat", "Loading config...", 2)
print("[Combat] Loading config...")
task.wait(0.2)

local DEFAULT_CONFIG = {
    KillAll       = {Enabled=false, Distance=500, Speed=0.1, Delay=0.05, MaxPerTick=5, HitParts={"Head","HumanoidRootPart"}},
    KillAura      = {Enabled=false, Distance=25, Speed=0.1, Delay=0.05, MaxPerTick=3, HitParts={"Head","HumanoidRootPart"}},
    AutoTowel     = {Enabled=false, Range=50, Distance=10},
    ShieldBypass  = {Enabled=false, Speed=0.1},
    FreezeRay     = {Enabled=false, Distance=500, Speed=0.1, Charged=true},
    AutoFreezeRay = {Enabled=false, Distance=500, Speed=0.1},
    SuperBall     = {Enabled=false, Speed=0.1},
    AutoUmbrella  = {Enabled=false, MinFallTime=0.3, Cooldown=0.5},
    Slingshot     = {Enabled=false, Distance=500, Speed=0.1},
    AutoSlingshot = {Enabled=false, Distance=500, Speed=0.1},
    AutoFreefall  = {Enabled=false, Speed=0.1},
    ZombieStaff   = {Enabled=false, Distance=500, Speed=0.1},
    DamageEvent   = {Enabled=false, Distance=500, Speed=0.1},
    Firebrand     = {Enabled=false, Distance=500, Speed=0.1},
    Speed         = {Enabled=false, Value=16},
    JumpPower     = {Enabled=false, Value=50},
    Noclip        = {Enabled=false},
    InfiniteJump  = {Enabled=false},
    Fly           = {Enabled=false, Speed=50},
    AntiAFK       = {Enabled=false, Interval=60},
    ModDetect     = {Enabled=true, KickMethod="kick"},
    EnemyTracker  = {Enabled=true, Debug=true},
    AutoConfig    = {Enabled=true},
    Blink         = {Enabled=true, Key="LeftShift", Distance=25, Speed=0.15, Cooldown=0.5, HoldMode=true},
}

local function loadConfig()
    local ok, raw = pcall(readfile, CONFIG_PATH)
    if not ok or not raw or raw == "" then
        print("[Config] No config found, writing defaults")
        local ok2, encoded = pcall(function() return HttpService:JSONEncode(DEFAULT_CONFIG) end)
        if ok2 then pcall(writefile, CONFIG_PATH, encoded) end
        return DEFAULT_CONFIG
    end
    local ok3, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok3 or not decoded then
        print("[Config] Failed to parse, using defaults")
        return DEFAULT_CONFIG
    end
    for k, v in pairs(DEFAULT_CONFIG) do
        if decoded[k] == nil then decoded[k] = v end
    end
    print("[Config] Loaded from config.json")
    return decoded
end

_G.Combat = loadConfig()
_G.Combat._Active = true
_G.Combat._Connections = {}
_G.Combat._Cleanup = {}
_G.Combat._Loops = {}
_G.Combat._GUI = gui

if type(_G.Combat.Blink.Key) == "string" then
    local kc = Enum.KeyCode[_G.Combat.Blink.Key]
    if kc then _G.Combat.Blink.Key = kc end
end

local function saveConfig()
    local out = {}
    for k, v in pairs(_G.Combat) do
        if k:sub(1,1) ~= "_" and type(v) == "table" then
            local copy = {}
            for kk, vv in pairs(v) do
                if typeof(vv) == "EnumItem" then copy[kk] = vv.Name
                else copy[kk] = vv end
            end
            out[k] = copy
        end
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(out) end)
    if ok then pcall(writefile, CONFIG_PATH, encoded) end
end

_G.SaveCombatConfig = saveConfig

notify("Combat", "Applying your config...", 2)
print("[Combat] Applying config...")
task.wait(0.2)

local Combat = _G.Combat

local KillAll       = Combat.KillAll
local KillAura      = Combat.KillAura
local AutoTowel     = Combat.AutoTowel
local ShieldBypass  = Combat.ShieldBypass
local FreezeRay     = Combat.FreezeRay
local AutoFreezeRay = Combat.AutoFreezeRay
local SuperBall     = Combat.SuperBall
local AutoUmbrella  = Combat.AutoUmbrella
local Slingshot     = Combat.Slingshot
local AutoSlingshot = Combat.AutoSlingshot
local AutoFreefall  = Combat.AutoFreefall
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

local function getChar() return LocalPlayer.Character end
local function getHrp()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function trackConn(conn) table.insert(Combat._Connections, conn) return conn end
local function newLoop() local f = {Stopped = false} table.insert(Combat._Loops, f) return f end

--

local BlinkLastTick = 0
local BlinkHeld = false
local BlinkTween = nil

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
    local startCf = hrp.CFrame
    local endCf = CFrame.new(hrp.Position + dir * Blink.Distance) * (startCf - startCf.Position)
    if BlinkTween then BlinkTween:Cancel() end
    BlinkTween = TweenService:Create(hrp, TweenInfo.new(Blink.Speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = endCf})
    BlinkTween:Play()
end

trackConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not Blink.Enabled then return end
    if input.KeyCode == Blink.Key then
        BlinkHeld = true
        if not Blink.HoldMode then doBlink() end
    end
end))

trackConn(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Blink.Key then BlinkHeld = false end
end))

trackConn(RunService.Heartbeat:Connect(function()
    if not Blink.Enabled then return end
    if not Blink.HoldMode then return end
    if not BlinkHeld then return end
    doBlink()
end))

--

local Config = {EnemiesFolder=nil, ProjectilesFolder=nil, MapsFolder=nil, RemotesFolder=nil, DetectedTools={}, DetectedLimbNames={}}

local function verifyGame()
    if not AutoConfig.Enabled then return end
    print("================================")
    print("[AutoConfig] Verifying structure...")
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        Config.EnemiesFolder = enemies
        print("  [OK] workspace.Enemies (" .. #enemies:GetChildren() .. ")")
    else print("  [MISSING] workspace.Enemies") end
    local proj = workspace:FindFirstChild("Projectiles")
    if proj then Config.ProjectilesFolder = proj print("  [OK] workspace.Projectiles")
    else print("  [MISSING] workspace.Projectiles") end
    local maps = workspace:FindFirstChild("Maps")
    if maps then
        Config.MapsFolder = maps
        local map = maps:FindFirstChild("Map")
        local room = map and map:FindFirstChild("Room")
        print("  [OK] workspace.Maps.Map.Room (" .. (room and #room:GetChildren() or 0) .. ")")
    else print("  [MISSING] workspace.Maps") end
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        Config.RemotesFolder = events
        local re = events:FindFirstChild("RemoteEvents")
        print("  [OK] ReplicatedStorage.Events.RemoteEvents (" .. (re and #re:GetChildren() or 0) .. ")")
    else print("  [MISSING] ReplicatedStorage.Events") end
    print("================================")
end
verifyGame()

local function scanLimbs()
    if not Config.EnemiesFolder then return end
    local first = Config.EnemiesFolder:GetChildren()[1]
    if not first then return end
    local limbs = {}
    for _, c in ipairs(first:GetChildren()) do
        if c:IsA("BasePart") then table.insert(limbs, c.Name) end
    end
    Config.DetectedLimbNames = limbs
    if AutoConfig.Enabled then print("[AutoConfig] Limbs: " .. table.concat(limbs, ", ")) end
end
scanLimbs()

local function applyAutoConfig()
    if not AutoConfig.Enabled then return end
    if Config.DetectedLimbNames then
        local hasCenter, hasHead = false, false
        for _, n in ipairs(Config.DetectedLimbNames) do
            if n == "Center" then hasCenter = true end
            if n == "Head" then hasHead = true end
        end
        if hasCenter then
            KillAll.HitParts = {"Center","HumanoidRootPart"}
            KillAura.HitParts = {"Center","HumanoidRootPart"}
            print("[AutoConfig] HitParts: Center")
        elseif hasHead then
            KillAll.HitParts = {"Head","HumanoidRootPart"}
            KillAura.HitParts = {"Head","HumanoidRootPart"}
            print("[AutoConfig] HitParts: Head")
        end
    end
end
applyAutoConfig()

print("================================")
print("[AutoConfig] Ready.")
print("================================")

--

local Enemies = {}
local EnemiesFolder = nil

local function trackEnemy(model)
    if not model:IsA("Model") then return end
    if Enemies[model] then return end
    Enemies[model] = true
    if EnemyTracker.Debug then print("[EnemyTracker] + " .. model.Name) end
end

local function untrackEnemy(model)
    if not Enemies[model] then return end
    Enemies[model] = nil
    if EnemyTracker.Debug then print("[EnemyTracker] - " .. model.Name) end
end

local function bindEnemyFolder(folder)
    EnemiesFolder = folder
    local n = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") then trackEnemy(c) n = n + 1 end
    end
    print("[EnemyTracker] Bound (" .. n .. ")")
    trackConn(folder.ChildAdded:Connect(function(c) if c:IsA("Model") then trackEnemy(c) end end))
    trackConn(folder.ChildRemoved:Connect(untrackEnemy))
end

if Config.EnemiesFolder then bindEnemyFolder(Config.EnemiesFolder)
else trackConn(workspace.ChildAdded:Connect(function(c)
    if c.Name == "Enemies" and not EnemiesFolder then bindEnemyFolder(c) end
end)) end

local function getEnemies()
    if not EnemiesFolder then return {} end
    local list = {}
    for _, c in ipairs(EnemiesFolder:GetChildren()) do
        if c:IsA("Model") then table.insert(list, c) end
    end
    return list
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
    for _, roleName in ipairs(ROLE_FILES) do
        local ok, raw = pcall(readfile, JSON_ROOT .. roleName .. ".json")
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
        else LocalPlayer:Kick("Windforce staff: " .. plr.Name) end
    end
end
for _, p in ipairs(Players:GetPlayers()) do checkStaff(p) end
trackConn(Players.PlayerAdded:Connect(checkStaff))

--

local function pickHitPart(m, parts)
    for _, n in ipairs(parts) do
        local p = m:FindFirstChild(n)
        if p then return p end
    end
    return m:FindFirstChild("HumanoidRootPart")
end

local function firePaintball(m, parts)
    local char = getChar()
    if not char then return end
    local gun = char:FindFirstChild("Paintball Gun") or LocalPlayer.Backpack:FindFirstChild("Paintball Gun")
    if not gun then return end
    local ev = gun:FindFirstChild("VerifyHit")
    if not ev then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hrp = m:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local hp = pickHitPart(m, parts)
    if not hp then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    ev:FireServer(hum, hp.Position, myHrp and myHrp.Position or hp.Position, hp, {Color=BrickColor.new("Light blue"), Quickdraw=false, ObjectBreak=false})
end

local function fireRocket(m, parts)
    local char = getChar()
    if not char then return end
    local r = char:FindFirstChild("Rocket Launcher") or LocalPlayer.Backpack:FindFirstChild("Rocket Launcher")
    if not r then return end
    local ev = r:FindFirstChild("CreateExplosion")
    if not ev then return end
    local hp = pickHitPart(m, parts)
    if not hp then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    ev:FireServer(hp.Position, myHrp and myHrp.Position or hp.Position, hp, {})
end

local function fireSlingshot(m)
    local char = getChar()
    if not char then return end
    local s = char:FindFirstChild("Slingshot") or LocalPlayer.Backpack:FindFirstChild("Slingshot")
    if not s then return end
    local ev = s:FindFirstChild("VerifyHit")
    if not ev then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hrp = m:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local leftArm = m:FindFirstChild("Left Arm") or hrp
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    ev:FireServer(hum, hrp.Position, myHrp and myHrp.Position or hrp.Position, leftArm)
end

local function fireFreezeRay(m)
    local char = getChar()
    if not char then return end
    local g = char:FindFirstChild("Freeze Ray") or LocalPlayer.Backpack:FindFirstChild("Freeze Ray")
    if not g then return end
    local ev = g:FindFirstChild("VerifyHit")
    if not ev then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hrp = m:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local center = m:FindFirstChild("Center") or hrp
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    local aimVec = myHrp and (myHrp.Position + Vector3.new(0,5,0)) or hrp.Position + Vector3.new(0,5,0)
    ev:FireServer(hum, center.Position, aimVec, center, {Charged=FreezeRay.Charged, Quickdraw=false, ObjectBreak=false})
end

local function fireZombieStaff(m)
    local char = getChar()
    if not char then return end
    local s = char:FindFirstChild("Zombie Staff") or LocalPlayer.Backpack:FindFirstChild("Zombie Staff")
    if not s then return end
    local dmg = s:FindFirstChild("DamageEvent")
    if not dmg or not dmg:IsA("RemoteEvent") then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local hrp = m:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    local center = m:FindFirstChild("Center") or hrp
    dmg:FireServer(center, hum)
end

local function fireFirebrand(m)
    local char = getChar()
    if not char then return end
    local b = char:FindFirstChild("Firebrand") or LocalPlayer.Backpack:FindFirstChild("Firebrand")
    if not b then return end
    local oh = b:FindFirstChild("VerifyOffhand")
    if oh then pcall(function() oh:FireServer("Swing") end) end
    local h = b:FindFirstChild("VerifyHit")
    if h then
        local hum = m:FindFirstChildOfClass("Humanoid")
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            local rl = m:FindFirstChild("Right Leg") or hrp
            local myHrp = char:FindFirstChild("HumanoidRootPart")
            local dir = myHrp and (hrp.Position - myHrp.Position).Unit or Vector3.new(0,0,-1)
            pcall(function() h:FireServer("Slash", hum, dir, rl, true, nil, {AttackDash=false, Overhead=false, Backstab=false}) end)
        end
    end
end

local function fireUmbrella()
    local char = getChar()
    if not char then return end
    local g = char:FindFirstChild("UmbrellaGear") or LocalPlayer.Backpack:FindFirstChild("UmbrellaGear")
    if not g then return end
    local ev = g:FindFirstChild("RemoteEvent")
    if not ev then return end
    pcall(function() ev:FireServer(true) end)
end

local function fireSuperBall()
    local char = getChar()
    if not char then return end
    local b = LocalPlayer.Backpack:FindFirstChild("Superball") or char:FindFirstChild("Superball")
    if not b then return end
    local ev = b:FindFirstChild("ThrowBall")
    if not ev then return end
    local myHrp = getHrp()
    if not myHrp then return end
    pcall(function()
        ev:InvokeServer(
            myHrp.Position + Vector3.new(0,5,0),
            Vector3.new(-6.577060007728619e-10, 7.8036966442596167e-05, 5.7456515101250716e-09),
            0,
            nil
        )
    end)
end

local function fireFreefall()
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    if not r then return end
    local rep = r:FindFirstChild("Replication")
    if not rep then return end
    local ff = rep:FindFirstChild("ReplicateFreefall")
    if not ff or not ff:IsA("RemoteEvent") then return end
    pcall(function() ff:FireServer(true) end)
end

--

local killLoop = newLoop()
task.spawn(function()
    while not killLoop.Stopped do
        task.wait(KillAll.Speed)
        if killLoop.Stopped then break end
        if not KillAll.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        local fired = 0
        for _, m in ipairs(getEnemies()) do
            if fired >= KillAll.MaxPerTick then break end
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= KillAll.Distance then
                pcall(firePaintball, m, KillAll.HitParts)
                pcall(fireRocket, m, KillAll.HitParts)
                fired = fired + 1
                task.wait(KillAll.Delay)
            end
        end
    end
end)

local auraLoop = newLoop()
task.spawn(function()
    while not auraLoop.Stopped do
        task.wait(KillAura.Speed)
        if auraLoop.Stopped then break end
        if not KillAura.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        local fired = 0
        for _, m in ipairs(getEnemies()) do
            if fired >= KillAura.MaxPerTick then break end
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= KillAura.Distance then
                pcall(firePaintball, m, KillAura.HitParts)
                pcall(fireRocket, m, KillAura.HitParts)
                fired = fired + 1
                task.wait(KillAura.Delay)
            end
        end
    end
end)

local freezeLoop = newLoop()
task.spawn(function()
    while not freezeLoop.Stopped do
        task.wait(FreezeRay.Speed)
        if freezeLoop.Stopped then break end
        if not FreezeRay.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= FreezeRay.Distance then
                pcall(fireFreezeRay, m)
            end
        end
    end
end)

local autoFreezeLoop = newLoop()
task.spawn(function()
    while not autoFreezeLoop.Stopped do
        task.wait(AutoFreezeRay.Speed)
        if autoFreezeLoop.Stopped then break end
        if not AutoFreezeRay.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= AutoFreezeRay.Distance then
                pcall(fireFreezeRay, m)
            end
        end
    end
end)

local slingLoop = newLoop()
task.spawn(function()
    while not slingLoop.Stopped do
        task.wait(Slingshot.Speed)
        if slingLoop.Stopped then break end
        if not Slingshot.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= Slingshot.Distance then
                pcall(fireSlingshot, m)
                break
            end
        end
    end
end)

local autoSlingLoop = newLoop()
task.spawn(function()
    while not autoSlingLoop.Stopped do
        task.wait(AutoSlingshot.Speed)
        if autoSlingLoop.Stopped then break end
        if not AutoSlingshot.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= AutoSlingshot.Distance then
                pcall(fireSlingshot, m)
            end
        end
    end
end)

local freefallLoop = newLoop()
task.spawn(function()
    while not freefallLoop.Stopped do
        task.wait(AutoFreefall.Speed)
        if freefallLoop.Stopped then break end
        if not AutoFreefall.Enabled then continue end
        pcall(fireFreefall)
    end
end)

local ballLoop = newLoop()
task.spawn(function()
    while not ballLoop.Stopped do
        task.wait(SuperBall.Speed)
        if ballLoop.Stopped then break end
        if not SuperBall.Enabled then continue end
        pcall(fireSuperBall)
    end
end)

local staffLoop = newLoop()
task.spawn(function()
    while not staffLoop.Stopped do
        task.wait(ZombieStaff.Speed)
        if staffLoop.Stopped then break end
        if not ZombieStaff.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= ZombieStaff.Distance then
                pcall(fireZombieStaff, m)
            end
        end
    end
end)

local brandLoop = newLoop()
task.spawn(function()
    while not brandLoop.Stopped do
        task.wait(Firebrand.Speed)
        if brandLoop.Stopped then break end
        if not Firebrand.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= Firebrand.Distance then
                pcall(fireFirebrand, m)
                break
            end
        end
    end
end)

local damageLoop = newLoop()
task.spawn(function()
    while not damageLoop.Stopped do
        task.wait(DamageEvent.Speed)
        if damageLoop.Stopped then break end
        if not DamageEvent.Enabled then continue end
        local myHrp = getHrp()
        if not myHrp then continue end
        for _, m in ipairs(getEnemies()) do
            if not isAlive(m) then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if (myHrp.Position - hrp.Position).Magnitude <= DamageEvent.Distance then
                pcall(fireZombieStaff, m)
            end
        end
    end
end)

local UmbrellaLastFire = 0
local UmbrellaFallStart = 0
local UmbrellaWasFalling = false

trackConn(RunService.Heartbeat:Connect(function()
    if not AutoUmbrella.Enabled then
        UmbrellaWasFalling = false
        UmbrellaFallStart = 0
        return
    end
    local hum = getHum()
    if not hum then return end
    local state = hum:GetState()
    local falling = state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.PlatformStanding
    if falling and not UmbrellaWasFalling then
        UmbrellaWasFalling = true
        UmbrellaFallStart = tick()
    elseif not falling then
        UmbrellaWasFalling = false
        UmbrellaFallStart = 0
    end
    if falling and UmbrellaWasFalling then
        local fallDuration = tick() - UmbrellaFallStart
        if fallDuration >= AutoUmbrella.MinFallTime then
            if tick() - UmbrellaLastFire >= AutoUmbrella.Cooldown then
                UmbrellaLastFire = tick()
                pcall(fireUmbrella)
            end
        end
    end
end))

--

local towelLoop = newLoop()
task.spawn(function()
    while not towelLoop.Stopped do
        task.wait(0.05)
        if towelLoop.Stopped then break end
        if not AutoTowel.Enabled then continue end
        local char = getChar()
        if not char then continue end
        local trowel = char:FindFirstChild("Trowel") or LocalPlayer.Backpack:FindFirstChild("Trowel")
        if not trowel then continue end
        local ev = trowel:FindFirstChild("PlaceReplicate")
        if not ev then continue end
        local myHrp = char:FindFirstChild("HumanoidRootPart")
        if not myHrp then continue end
        local projectiles = Config.ProjectilesFolder or workspace:FindFirstChild("Projectiles")
        if not projectiles then continue end
        for _, proj in ipairs(projectiles:GetChildren()) do
            local pp = proj:IsA("BasePart") and proj or proj:FindFirstChildWhichIsA("BasePart")
            if not pp then continue end
            local dir = (myHrp.Position - pp.Position)
            if dir.Magnitude > AutoTowel.Range then continue end
            local vel = pp.AssemblyLinearVelocity
            if vel.Magnitude < 1 then continue end
            local toMe = dir.Unit
            local toVel = vel.Unit
            if toMe:Dot(toVel) < 0.5 then continue end
            local placePos = myHrp.Position + toMe * AutoTowel.Distance
            pcall(function() ev:FireServer(projectiles:GetChildren()[21], CFrame.new(placePos, myHrp.Position), {}) end)
            break
        end
    end
end)

local shieldLoop = newLoop()
task.spawn(function()
    while not shieldLoop.Stopped do
        task.wait(ShieldBypass.Speed)
        if shieldLoop.Stopped then break end
        if not ShieldBypass.Enabled then continue end
        for _, npc in ipairs(getEnemies()) do
            local shield = npc:FindFirstChild("Shield")
            if shield and shield:IsA("UnionOperation") then
                pcall(function()
                    shield.CanCollide = false
                    shield.Transparency = 1
                    local d = shield:FindFirstChildOfClass("Decal")
                    if d then d:Destroy() end
                end)
            end
        end
    end
end)

--

trackConn(RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if Speed.Enabled then hum.WalkSpeed = Speed.Value
    elseif hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
end))

trackConn(RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if JumpPower.Enabled then
        hum.UseJumpPower = true
        hum.JumpPower = JumpPower.Value
    elseif hum.UseJumpPower and hum.JumpPower ~= 50 then
        hum.JumpPower = 50
    end
end))

trackConn(RunService.Stepped:Connect(function()
    local char = getChar()
    if not char then return end
    if Noclip.Enabled then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end))

trackConn(UserInputService.JumpRequest:Connect(function()
    if not InfiniteJump.Enabled then return end
    local hum = getHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

local flyBV, flyBG
trackConn(RunService.Heartbeat:Connect(function()
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
end))

local afkLoop = newLoop()
task.spawn(function()
    while not afkLoop.Stopped do
        task.wait(AntiAFK.Interval)
        if afkLoop.Stopped then break end
        if AntiAFK.Enabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end
end)

--

local Main  = gui:tab{Icon = "rbxassetid://6034996695", Name = "Main"}
local Misc  = gui:tab{Icon = "rbxassetid://6031075931", Name = "Misc"}
local Tools = gui:tab{Icon = "rbxassetid://6031075931", Name = "Tools"}

Main:toggle({Name="Kill All",Default=KillAll.Enabled,Callback=function(s) KillAll.Enabled = s saveConfig() end})
Main:slider({Name="Kill All Distance",Min=10,Max=2000,Default=KillAll.Distance,Callback=function(v) KillAll.Distance = v saveConfig() end})
Main:slider({Name="Kill All Speed",Min=0.01,Max=2,Default=KillAll.Speed,Decimals=2,Callback=function(v) KillAll.Speed = v saveConfig() end})
Main:slider({Name="Kill All Delay",Min=0,Max=0.5,Default=KillAll.Delay,Decimals=2,Callback=function(v) KillAll.Delay = v saveConfig() end})
Main:slider({Name="Kill All Max Per Tick",Min=1,Max=50,Default=KillAll.MaxPerTick,Callback=function(v) KillAll.MaxPerTick = v saveConfig() end})
Main:dropdown({Name="Kill All Hit Part",StartingText="Head",Items={"Head","HumanoidRootPart","Center","Torso","Left Arm","Right Arm","Left Leg","Right Leg"},Callback=function(v) KillAll.HitParts = {v} saveConfig() end})

Main:toggle({Name="Kill Aura",Default=KillAura.Enabled,Callback=function(s) KillAura.Enabled = s saveConfig() end})
Main:slider({Name="Kill Aura Distance",Min=5,Max=100,Default=KillAura.Distance,Callback=function(v) KillAura.Distance = v saveConfig() end})
Main:slider({Name="Kill Aura Speed",Min=0.01,Max=2,Default=KillAura.Speed,Decimals=2,Callback=function(v) KillAura.Speed = v saveConfig() end})
Main:slider({Name="Kill Aura Delay",Min=0,Max=0.5,Default=KillAura.Delay,Decimals=2,Callback=function(v) KillAura.Delay = v saveConfig() end})
Main:slider({Name="Kill Aura Max Per Tick",Min=1,Max=50,Default=KillAura.MaxPerTick,Callback=function(v) KillAura.MaxPerTick = v saveConfig() end})
Main:dropdown({Name="Kill Aura Hit Part",StartingText="Head",Items={"Head","HumanoidRootPart","Center","Torso","Left Arm","Right Arm","Left Leg","Right Leg"},Callback=function(v) KillAura.HitParts = {v} saveConfig() end})

Main:toggle({Name="Auto Towel",Default=AutoTowel.Enabled,Callback=function(s) AutoTowel.Enabled = s saveConfig() end})
Main:slider({Name="Towel Range",Min=5,Max=200,Default=AutoTowel.Range,Callback=function(v) AutoTowel.Range = v saveConfig() end})
Main:slider({Name="Towel Distance",Min=1,Max=30,Default=AutoTowel.Distance,Callback=function(v) AutoTowel.Distance = v saveConfig() end})

Main:toggle({Name="Shield Bypass",Default=ShieldBypass.Enabled,Callback=function(s) ShieldBypass.Enabled = s saveConfig() end})
Main:slider({Name="Shield Bypass Speed",Min=0.01,Max=1,Default=ShieldBypass.Speed,Decimals=2,Callback=function(v) ShieldBypass.Speed = v saveConfig() end})

Main:toggle({Name="Enemy Tracker",Default=EnemyTracker.Enabled,Callback=function(s) EnemyTracker.Enabled = s saveConfig() end})
Main:toggle({Name="Enemy Tracker Debug",Default=EnemyTracker.Debug,Callback=function(s) EnemyTracker.Debug = s saveConfig() end})

Tools:toggle({Name="Freeze Ray",Default=FreezeRay.Enabled,Callback=function(s) FreezeRay.Enabled = s saveConfig() end})
Tools:slider({Name="Freeze Ray Distance",Min=10,Max=2000,Default=FreezeRay.Distance,Callback=function(v) FreezeRay.Distance = v saveConfig() end})
Tools:slider({Name="Freeze Ray Speed",Min=0.01,Max=2,Default=FreezeRay.Speed,Decimals=2,Callback=function(v) FreezeRay.Speed = v saveConfig() end})
Tools:toggle({Name="Charged",Default=FreezeRay.Charged,Callback=function(s) FreezeRay.Charged = s saveConfig() end})

Tools:toggle({Name="Auto Freeze Ray",Default=AutoFreezeRay.Enabled,Callback=function(s) AutoFreezeRay.Enabled = s saveConfig() end})
Tools:slider({Name="Auto Freeze Ray Distance",Min=10,Max=2000,Default=AutoFreezeRay.Distance,Callback=function(v) AutoFreezeRay.Distance = v saveConfig() end})
Tools:slider({Name="Auto Freeze Ray Speed",Min=0.01,Max=2,Default=AutoFreezeRay.Speed,Decimals=2,Callback=function(v) AutoFreezeRay.Speed = v saveConfig() end})

Tools:toggle({Name="Slingshot",Default=Slingshot.Enabled,Callback=function(s) Slingshot.Enabled = s saveConfig() end})
Tools:slider({Name="Slingshot Distance",Min=10,Max=2000,Default=Slingshot.Distance,Callback=function(v) Slingshot.Distance = v saveConfig() end})
Tools:slider({Name="Slingshot Speed",Min=0.01,Max=2,Default=Slingshot.Speed,Decimals=2,Callback=function(v) Slingshot.Speed = v saveConfig() end})

Tools:toggle({Name="Auto Slingshot",Default=AutoSlingshot.Enabled,Callback=function(s) AutoSlingshot.Enabled = s saveConfig() end})
Tools:slider({Name="Auto Slingshot Distance",Min=10,Max=2000,Default=AutoSlingshot.Distance,Callback=function(v) AutoSlingshot.Distance = v saveConfig() end})
Tools:slider({Name="Auto Slingshot Speed",Min=0.01,Max=2,Default=AutoSlingshot.Speed,Decimals=2,Callback=function(v) AutoSlingshot.Speed = v saveConfig() end})

Tools:toggle({Name="Auto Freefall",Description="spams ReplicateFreefall",Default=AutoFreefall.Enabled,Callback=function(s) AutoFreefall.Enabled = s saveConfig() end})
Tools:slider({Name="Auto Freefall Speed",Min=0.01,Max=2,Default=AutoFreefall.Speed,Decimals=2,Callback=function(v) AutoFreefall.Speed = v saveConfig() end})

Tools:toggle({Name="Super Ball",Default=SuperBall.Enabled,Callback=function(s) SuperBall.Enabled = s saveConfig() end})
Tools:slider({Name="Super Ball Speed",Min=0.01,Max=2,Default=SuperBall.Speed,Decimals=2,Callback=function(v) SuperBall.Speed = v saveConfig() end})

Tools:toggle({Name="Auto Umbrella",Description="fires on falling state",Default=AutoUmbrella.Enabled,Callback=function(s) AutoUmbrella.Enabled = s saveConfig() end})
Tools:slider({Name="Umbrella Min Fall Time",Min=0,Max=2,Default=AutoUmbrella.MinFallTime,Decimals=2,Callback=function(v) AutoUmbrella.MinFallTime = v saveConfig() end})
Tools:slider({Name="Umbrella Cooldown",Min=0.1,Max=3,Default=AutoUmbrella.Cooldown,Decimals=2,Callback=function(v) AutoUmbrella.Cooldown = v saveConfig() end})

Tools:toggle({Name="Zombie Staff",Default=ZombieStaff.Enabled,Callback=function(s) ZombieStaff.Enabled = s saveConfig() end})
Tools:slider({Name="Zombie Staff Distance",Min=10,Max=2000,Default=ZombieStaff.Distance,Callback=function(v) ZombieStaff.Distance = v saveConfig() end})
Tools:slider({Name="Zombie Staff Speed",Min=0.01,Max=2,Default=ZombieStaff.Speed,Decimals=2,Callback=function(v) ZombieStaff.Speed = v saveConfig() end})

Tools:toggle({Name="Firebrand",Default=Firebrand.Enabled,Callback=function(s) Firebrand.Enabled = s saveConfig() end})
Tools:slider({Name="Firebrand Distance",Min=10,Max=2000,Default=Firebrand.Distance,Callback=function(v) Firebrand.Distance = v saveConfig() end})
Tools:slider({Name="Firebrand Speed",Min=0.01,Max=2,Default=Firebrand.Speed,Decimals=2,Callback=function(v) Firebrand.Speed = v saveConfig() end})

Tools:toggle({Name="Damage Event",Default=DamageEvent.Enabled,Callback=function(s) DamageEvent.Enabled = s saveConfig() end})
Tools:slider({Name="Damage Event Distance",Min=10,Max=2000,Default=DamageEvent.Distance,Callback=function(v) DamageEvent.Distance = v saveConfig() end})
Tools:slider({Name="Damage Event Speed",Min=0.01,Max=2,Default=DamageEvent.Speed,Decimals=2,Callback=function(v) DamageEvent.Speed = v saveConfig() end})

Misc:toggle({Name="Speed",Default=Speed.Enabled,Callback=function(s) Speed.Enabled = s saveConfig() end})
Misc:slider({Name="Speed Value",Min=16,Max=500,Default=Speed.Value,Callback=function(v) Speed.Value = v saveConfig() end})
Misc:toggle({Name="JumpPower",Default=JumpPower.Enabled,Callback=function(s) JumpPower.Enabled = s saveConfig() end})
Misc:slider({Name="JumpPower Value",Min=50,Max=500,Default=JumpPower.Value,Callback=function(v) JumpPower.Value = v saveConfig() end})
Misc:toggle({Name="Noclip",Default=Noclip.Enabled,Callback=function(s) Noclip.Enabled = s saveConfig() end})
Misc:toggle({Name="Infinite Jump",Default=InfiniteJump.Enabled,Callback=function(s) InfiniteJump.Enabled = s saveConfig() end})
Misc:toggle({Name="Fly",Default=Fly.Enabled,Callback=function(s) Fly.Enabled = s saveConfig() end})
Misc:slider({Name="Fly Speed",Min=10,Max=500,Default=Fly.Speed,Callback=function(v) Fly.Speed = v saveConfig() end})
Misc:toggle({Name="Blink",Default=Blink.Enabled,Callback=function(s) Blink.Enabled = s saveConfig() end})
Misc:toggle({Name="Blink Hold Mode",Default=Blink.HoldMode,Callback=function(s) Blink.HoldMode = s saveConfig() end})
Misc:slider({Name="Blink Distance",Min=5,Max=100,Default=Blink.Distance,Callback=function(v) Blink.Distance = v saveConfig() end})
Misc:slider({Name="Blink Speed",Min=0.05,Max=1,Default=Blink.Speed,Decimals=2,Callback=function(v) Blink.Speed = v saveConfig() end})
Misc:slider({Name="Blink Cooldown",Min=0.1,Max=3,Default=Blink.Cooldown,Decimals=2,Callback=function(v) Blink.Cooldown = v saveConfig() end})
Misc:toggle({Name="Anti AFK",Default=AntiAFK.Enabled,Callback=function(s) AntiAFK.Enabled = s saveConfig() end})
Misc:slider({Name="Anti AFK Interval",Min=10,Max=300,Default=AntiAFK.Interval,Callback=function(v) AntiAFK.Interval = v saveConfig() end})
Misc:button({Name="Reset",Callback=function()
    local hum = getHum()
    if hum then hum.Health = 0 end
end})
Misc:button({Name="Rejoin",Callback=function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end})
Misc:button({Name="Save Config",Callback=function()
    saveConfig()
    notify("Config", "saved", 2)
end})

notify("Combat Initiation", "loaded", 3)