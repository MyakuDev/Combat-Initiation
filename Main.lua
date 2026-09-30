-- ============================================================
-- Combat Initiation - Main
-- ============================================================

local function log(tag, ...)
    print(string.format("[%s] %s", tag, table.concat({...}, " ")))
end

log("Boot", "Starting Combat Initiation script...")

-- ------------------------------------------------------------
-- 1. stop previous instance
-- ------------------------------------------------------------
if _G.Combat and _G.Combat._Active then
    log("Boot", "Previous instance detected - stopping...")

    if _G.Combat._Connections then
        local n = 0
        for _, c in pairs(_G.Combat._Connections) do
            pcall(function() c:Disconnect() end)
            n = n + 1
        end
        log("Boot", "Disconnected " .. n .. " connections")
        _G.Combat._Connections = {}
    end

    if _G.Combat._Loops then
        local n = 0
        for _, f in pairs(_G.Combat._Loops) do
            f.Stopped = true
            n = n + 1
        end
        log("Boot", "Stopped " .. n .. " loops")
        _G.Combat._Loops = {}
    end

    if _G.Combat._GUI then
        pcall(function() _G.Combat._GUI:Destroy() end)
        log("Boot", "Destroyed previous GUI")
    end

    _G.Combat._Active = false
    task.wait(0.4)
end

-- ------------------------------------------------------------
-- 2. fetch Mercury library
-- ------------------------------------------------------------
log("Fetch", "Requesting Mercury library from GitHub...")
local fetchStart = tick()

local fetchOk, librarySource = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua")
end)

if not fetchOk or not librarySource or librarySource == "" then
    warn("[Fetch] Failed to fetch Mercury library")
    return
end

local fetchTime = tick() - fetchStart
log("Fetch", string.format("Mercury fetched in %.2fs (%d bytes)", fetchTime, #librarySource))

local compileOk, Library = pcall(function()
    return loadstring(librarySource)()
end)

if not compileOk or not Library then
    warn("[Fetch] Failed to compile Mercury library")
    return
end

log("Fetch", "Mercury library loaded successfully")

local gui = Library:create{Theme = Library.Themes.Serika}
log("UI", "GUI created")

-- ------------------------------------------------------------
-- 3. services
-- ------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local LocalPlayer       = Players.LocalPlayer

log("Boot", "Services loaded")
log("Boot", "LocalPlayer: " .. LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")")

-- ------------------------------------------------------------
-- 4. paths
-- ------------------------------------------------------------
local ROOT = ".../"
local CONFIG_PATH = ROOT .. "configs/config.json"
local JSON_ROOT = ROOT .. "json/"
local WHITELIST_URL = "https://raw.githubusercontent.com/MyakuDev/Combat-Initiation/refs/heads/main/json/whitelist.json"

log("Config", "Root path: " .. ROOT)
log("Config", "Whitelist URL: " .. WHITELIST_URL)

-- ------------------------------------------------------------
-- 5. whitelist groups (hardcoded)
-- ------------------------------------------------------------
local whitelistedGroups = {
    {groupId = 890266119, name = "STURMVERN"},
    {groupId = 13281488, name = "HALL OF FAME TS PLAYERS"},
    {groupId = 15949457, name = "1911"},
    {groupId = 485032, name = "stop sopa from hacking the internet and cersonin"},
    {groupId = 11865514, name = "RR"},
    {groupId = 9674449, name = "CGD"},
    {groupId = 7270724, name = "Adversity"},
    {groupId = 8751009, name = "Axlze"},
    {groupId = 9753174, name = "Chug man fan group"},
    {groupId = 12087716, name = "DekHex"},
    {groupId = 7020914, name = "E L E V E N S"},
    {groupId = 16853340, name = "ESSENCEOF"},
    {groupId = 3143604, name = "Enders pack"},
    {groupId = 9342172, name = "Exnia"},
    {groupId = 3234585, name = "Federal Military Of The U S"},
    {groupId = 15060052, name = "K9WARE"},
    {groupId = 14097548, name = "M O L O T O V"},
    {groupId = 8016146, name = "L-eaT"},
    {groupId = 10564376, name = "Spill Blood Private Operation Union"},
    {groupId = 9447681, name = "ThugHunters Incorporated"},
    {groupId = 7371469, name = "W O K E"},
    {groupId = 14733325, name = "Zuki"},
    {groupId = 11852052, name = "blxty"},
    {groupId = 10479603, name = "culprit gang"},
    {groupId = 4179593, name = "i hate anime"},
    {groupId = 11911765, name = "tenspacedgod"},
    {groupId = 11648242, name = "your abd"},
    {groupId = 2526694, name = "unnamed"},
    {groupId = 2712820, name = "unnamed"},
    {groupId = 14488612, name = "Aura"},
}

log("Whitelist", "Loaded " .. #whitelistedGroups .. " whitelisted groups")

-- ------------------------------------------------------------
-- 6. fetch whitelist users from GitHub
-- ------------------------------------------------------------
log("Whitelist", "Fetching whitelist users from GitHub...")
local wlStart = tick()

local wlOk, wlRaw = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local whitelistUsers = {}

if not wlOk or not wlRaw or wlRaw == "" then
    warn("[Whitelist] Failed to fetch whitelist - continuing without user whitelist")
else
    local wlTime = tick() - wlStart
    log("Whitelist", string.format("Fetched in %.2fs (%d bytes)", wlTime, #wlRaw))

    local parseOk, parsed = pcall(function()
        return HttpService:JSONDecode(wlRaw)
    end)

    if not parseOk or not parsed then
        warn("[Whitelist] Failed to parse whitelist JSON")
    else
        local userCount = 0
        for _, entry in ipairs(parsed) do
            if entry.userId then
                whitelistUsers[entry.userId] = {
                    name = entry.name or "unknown",
                    displayName = entry.displayName or entry.name or "unknown",
                }
                userCount = userCount + 1
            end
        end
        log("Whitelist", "Parsed " .. userCount .. " whitelisted users")
    end
end

-- ------------------------------------------------------------
-- 7. whitelist check functions
-- ------------------------------------------------------------
local function isWhitelistedUser(userId)
    return whitelistUsers[userId] ~= nil
end

local function isWhitelistedGroup(plr)
    for _, g in ipairs(whitelistedGroups) do
        local ok, inGroup = pcall(function()
            return plr:IsInGroup(g.groupId)
        end)
        if ok and inGroup then
            return g.name
        end
    end
    return nil
end

local function checkWhitelist(plr, announce)
    if not plr then return end

    local userEntry = whitelistUsers[plr.UserId]
    if userEntry then
        local tag = (plr == LocalPlayer) and "YOU" or plr.Name
        log("Whitelist", tag .. " is whitelisted (user: " .. userEntry.name .. ")")
        if announce then
            gui:Notification{
                Title = "Whitelisted",
                Text = tag .. " is whitelisted (user: " .. userEntry.name .. ")",
                Duration = 5
            }
        end
    end

    local groupName = isWhitelistedGroup(plr)
    if groupName then
        local tag = (plr == LocalPlayer) and "YOU" or plr.Name
        log("Whitelist", tag .. " is whitelisted (group: " .. groupName .. ")")
        if announce then
            gui:Notification{
                Title = "Whitelisted",
                Text = tag .. " is whitelisted (group: " .. groupName .. ")",
                Duration = 5
            }
        end
    end
end

-- check yourself
log("Whitelist", "Checking if you are whitelisted...")
checkWhitelist(LocalPlayer, false)

-- ------------------------------------------------------------
-- 8. config load
-- ------------------------------------------------------------
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
    log("Config", "Loading from " .. CONFIG_PATH)

    local ok, raw = pcall(readfile, CONFIG_PATH)
    if not ok or not raw or raw == "" then
        log("Config", "No config found - writing defaults")
        local ok2, encoded = pcall(function() return HttpService:JSONEncode(DEFAULT_CONFIG) end)
        if ok2 then
            pcall(writefile, CONFIG_PATH, encoded)
            log("Config", "Default config written")
        end
        return DEFAULT_CONFIG
    end

    local ok3, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok3 or not decoded then
        warn("[Config] Failed to parse - using defaults")
        return DEFAULT_CONFIG
    end

    local merged = 0
    for k, v in pairs(DEFAULT_CONFIG) do
        if decoded[k] == nil then
            decoded[k] = v
            merged = merged + 1
        end
    end
    if merged > 0 then
        log("Config", "Merged " .. merged .. " missing keys from defaults")
    end

    log("Config", "Config loaded successfully")
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
    if kc then
        _G.Combat.Blink.Key = kc
        log("Config", "Blink key restored: " .. kc.Name)
    end
end

local function saveConfig()
    local out = {}
    for k, v in pairs(_G.Combat) do
        if k:sub(1,1) ~= "_" and type(v) == "table" then
            local copy = {}
            for kk, vv in pairs(v) do
                if typeof(vv) == "EnumItem" then
                    copy[kk] = vv.Name
                else
                    copy[kk] = vv
                end
            end
            out[k] = copy
        end
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(out) end)
    if ok then
        pcall(writefile, CONFIG_PATH, encoded)
    else
        warn("[Config] Failed to encode for save")
    end
end

_G.SaveCombatConfig = saveConfig

log("Boot", "Applying config to UI...")
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

-- ------------------------------------------------------------
-- 9. safe getters
-- ------------------------------------------------------------
local function getChar()
    local c = LocalPlayer.Character
    if not c or not c.Parent then return nil end
    return c
end

local function getHrp()
    local c = getChar()
    if not c then return nil end
    local h = c:FindFirstChild("HumanoidRootPart")
    if not h or not h.Parent then return nil end
    return h
end

local function getHum()
    local c = getChar()
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or not h.Parent then return nil end
    return h
end

local function trackConn(conn)
    table.insert(Combat._Connections, conn)
    return conn
end

local function newLoop()
    local f = {Stopped = false}
    table.insert(Combat._Loops, f)
    return f
end

log("Boot", "Safe getters registered")

-- ------------------------------------------------------------
-- 10. whitelist monitoring
-- ------------------------------------------------------------
log("Whitelist", "Scanning current server...")
for _, plr in ipairs(Players:GetPlayers()) do
    checkWhitelist(plr, true)
end

trackConn(Players.PlayerAdded:Connect(function(plr)
    task.wait(1)
    checkWhitelist(plr, true)
end))

log("Whitelist", "Monitoring active")

-- ------------------------------------------------------------
-- 11. blink
-- ------------------------------------------------------------
local BlinkLastTick = 0
local BlinkHeld = false
local BlinkTween = nil

local function getMoveDirection()
    local hum = getHum()
    if not hum then return nil end
    local moveVec = hum.MoveDirection
    if moveVec.Magnitude > 0 then return moveVec.Unit end
    local cam = workspace.CurrentCamera
    if not cam then return nil end
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

    if BlinkTween then
        pcall(function() BlinkTween:Cancel() end)
    end

    BlinkTween = TweenService:Create(
        hrp,
        TweenInfo.new(Blink.Speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {CFrame = endCf}
    )
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
    if input.KeyCode == Blink.Key then
        BlinkHeld = false
    end
end))

trackConn(RunService.Heartbeat:Connect(function()
    if not Blink.Enabled then return end
    if not Blink.HoldMode then return end
    if not BlinkHeld then return end
    doBlink()
end))

log("Blink", "Initialized")

-- ------------------------------------------------------------
-- 12. game verification
-- ------------------------------------------------------------
local Config = {
    EnemiesFolder = nil,
    ProjectilesFolder = nil,
    MapsFolder = nil,
    RemotesFolder = nil,
    DetectedTools = {},
    DetectedLimbNames = {},
}

local function verifyGame()
    if not AutoConfig.Enabled then return end
    log("Verify", "Scanning game structure...")

    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        Config.EnemiesFolder = enemies
        log("Verify", "workspace.Enemies OK (" .. #enemies:GetChildren() .. " children)")
    else
        log("Verify", "workspace.Enemies MISSING")
    end

    local proj = workspace:FindFirstChild("Projectiles")
    if proj then
        Config.ProjectilesFolder = proj
        log("Verify", "workspace.Projectiles OK")
    else
        log("Verify", "workspace.Projectiles MISSING")
    end

    local maps = workspace:FindFirstChild("Maps")
    if maps then
        Config.MapsFolder = maps
        local map = maps:FindFirstChild("Map")
        local room = map and map:FindFirstChild("Room")
        log("Verify", "workspace.Maps.Map.Room OK (" .. (room and #room:GetChildren() or 0) .. " children)")
    else
        log("Verify", "workspace.Maps MISSING")
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        Config.RemotesFolder = events
        local re = events:FindFirstChild("RemoteEvents")
        log("Verify", "ReplicatedStorage.Events.RemoteEvents OK (" .. (re and #re:GetChildren() or 0) .. ")")
    else
        log("Verify", "ReplicatedStorage.Events MISSING")
    end
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
    log("AutoConfig", "Limbs: " .. table.concat(limbs, ", "))
end
scanLimbs()

local function applyAutoConfig()
    if not AutoConfig.Enabled then return end
    if not Config.DetectedLimbNames then return end
    local hasCenter, hasHead = false, false
    for _, n in ipairs(Config.DetectedLimbNames) do
        if n == "Center" then hasCenter = true end
        if n == "Head" then hasHead = true end
    end
    if hasCenter then
        KillAll.HitParts = {"Center","HumanoidRootPart"}
        KillAura.HitParts = {"Center","HumanoidRootPart"}
        log("AutoConfig", "HitParts set to Center")
    elseif hasHead then
        KillAll.HitParts = {"Head","HumanoidRootPart"}
        KillAura.HitParts = {"Head","HumanoidRootPart"}
        log("AutoConfig", "HitParts set to Head")
    end
end
applyAutoConfig()

log("Verify", "Initialization complete")

-- ------------------------------------------------------------
-- 13. enemy tracker
-- ------------------------------------------------------------
local Enemies = {}
local EnemiesFolder = nil

local function trackEnemy(model)
    if not model or not model.Parent then return end
    if not model:IsA("Model") then return end
    if Enemies[model] then return end
    Enemies[model] = true
    if EnemyTracker.Debug then
        log("EnemyTracker", "+ " .. model.Name)
    end
end

local function untrackEnemy(model)
    if not Enemies[model] then return end
    Enemies[model] = nil
    if EnemyTracker.Debug then
        log("EnemyTracker", "- " .. model.Name)
    end
end

local function bindEnemyFolder(folder)
    EnemiesFolder = folder
    local n = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") then
            trackEnemy(c)
            n = n + 1
        end
    end
    log("EnemyTracker", "Bound to " .. folder:GetFullName() .. " (" .. n .. " tracked)")
    trackConn(folder.ChildAdded:Connect(function(c)
        if c:IsA("Model") then trackEnemy(c) end
    end))
    trackConn(folder.ChildRemoved:Connect(untrackEnemy))
end

if Config.EnemiesFolder then
    bindEnemyFolder(Config.EnemiesFolder)
else
    trackConn(workspace.ChildAdded:Connect(function(c)
        if c.Name == "Enemies" and not EnemiesFolder then
            bindEnemyFolder(c)
        end
    end))
end

local function getEnemies()
    if not EnemiesFolder or not EnemiesFolder.Parent then return {} end
    local list = {}
    for _, c in ipairs(EnemiesFolder:GetChildren()) do
        if c:IsA("Model") then table.insert(list, c) end
    end
    return list
end

local function isAlive(model)
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

-- ------------------------------------------------------------
-- 14. moderator detection
-- ------------------------------------------------------------
local ROLE_FILES = {"Trusted","Developers","AssistantDevelopers","RetiredDevelopers","Consultants","HeadOfStaff","SeniorModerators","Moderators","JuniorModerators","Contributors"}
local RoleCache = {}

local function loadRoles()
    log("Roles", "Loading role files from " .. JSON_ROOT)
    local n = 0
    for _, roleName in ipairs(ROLE_FILES) do
        local ok, raw = pcall(readfile, JSON_ROOT .. roleName .. ".json")
        if ok and raw and raw ~= "" then
            local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and decoded and decoded.users then
                RoleCache[roleName] = decoded.users
                n = n + 1
                log("Roles", roleName .. ": " .. #decoded.users .. " entries")
            end
        end
    end
    log("Roles", "Loaded " .. n .. " role files")
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
    if not plr or plr == LocalPlayer then return end
    if not ModDetect.Enabled then return end
    local role = isStaff(plr.UserId, plr.Name)
    if role then
        log("ModDetect", "Detected: " .. plr.Name .. " (" .. role .. ")")
        task.wait(0.5)
        if ModDetect.KickMethod == "shutdown" then
            game:Shutdown()
        else
            LocalPlayer:Kick("Windforce staff: " .. plr.Name)
        end
    end
end
for _, p in ipairs(Players:GetPlayers()) do checkStaff(p) end
trackConn(Players.PlayerAdded:Connect(checkStaff))

log("ModDetect", "Initialized (kick method: " .. ModDetect.KickMethod .. ")")

-- ------------------------------------------------------------
-- 15. tool firing helpers
-- ------------------------------------------------------------
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
    if not myHrp then return end
    pcall(function()
        ev:FireServer(hum, hp.Position, myHrp.Position, hp, {
            Color = BrickColor.new("Light blue"),
            Quickdraw = false,
            ObjectBreak = false
        })
    end)
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
    if not myHrp then return end
    pcall(function() ev:FireServer(hp.Position, myHrp.Position, hp, {}) end)
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
    if not myHrp then return end
    pcall(function() ev:FireServer(hum, hrp.Position, myHrp.Position, leftArm) end)
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
    if not myHrp then return end
    local aimVec = myHrp.Position + Vector3.new(0,5,0)
    pcall(function()
        ev:FireServer(hum, center.Position, aimVec, center, {
            Charged = FreezeRay.Charged,
            Quickdraw = false,
            ObjectBreak = false
        })
    end)
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
    pcall(function() dmg:FireServer(center, hum) end)
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
            if myHrp then
                local dir = (hrp.Position - myHrp.Position).Unit
                pcall(function()
                    h:FireServer("Slash", hum, dir, rl, true, nil, {
                        AttackDash = false, Overhead = false, Backstab = false
                    })
                end)
            end
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

log("Tools", "Firing helpers registered")

-- ------------------------------------------------------------
-- 16. main loops
-- ------------------------------------------------------------
local killLoop = newLoop()
task.spawn(function()
    log("Loop", "KillAll loop started")
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
                firePaintball(m, KillAll.HitParts)
                fireRocket(m, KillAll.HitParts)
                fired = fired + 1
                task.wait(KillAll.Delay)
            end
        end
    end
    log("Loop", "KillAll loop stopped")
end)

local auraLoop = newLoop()
task.spawn(function()
    log("Loop", "KillAura loop started")
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
                firePaintball(m, KillAura.HitParts)
                fireRocket(m, KillAura.HitParts)
                fired = fired + 1
                task.wait(KillAura.Delay)
            end
        end
    end
    log("Loop", "KillAura loop stopped")
end)

local freezeLoop = newLoop()
task.spawn(function()
    log("Loop", "FreezeRay loop started")
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
                fireFreezeRay(m)
            end
        end
    end
    log("Loop", "FreezeRay loop stopped")
end)

local autoFreezeLoop = newLoop()
task.spawn(function()
    log("Loop", "AutoFreezeRay loop started")
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
                fireFreezeRay(m)
            end
        end
    end
    log("Loop", "AutoFreezeRay loop stopped")
end)

local slingLoop = newLoop()
task.spawn(function()
    log("Loop", "Slingshot loop started")
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
                fireSlingshot(m)
                break
            end
        end
    end
    log("Loop", "Slingshot loop stopped")
end)

local autoSlingLoop = newLoop()
task.spawn(function()
    log("Loop", "AutoSlingshot loop started")
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
                fireSlingshot(m)
            end
        end
    end
    log("Loop", "AutoSlingshot loop stopped")
end)

local freefallLoop = newLoop()
task.spawn(function()
    log("Loop", "AutoFreefall loop started")
    while not freefallLoop.Stopped do
        task.wait(AutoFreefall.Speed)
        if freefallLoop.Stopped then break end
        if not AutoFreefall.Enabled then continue end
        fireFreefall()
    end
    log("Loop", "AutoFreefall loop stopped")
end)

local ballLoop = newLoop()
task.spawn(function()
    log("Loop", "SuperBall loop started")
    while not ballLoop.Stopped do
        task.wait(SuperBall.Speed)
        if ballLoop.Stopped then break end
        if not SuperBall.Enabled then continue end
        fireSuperBall()
    end
    log("Loop", "SuperBall loop stopped")
end)

local staffLoop = newLoop()
task.spawn(function()
    log("Loop", "ZombieStaff loop started")
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
                fireZombieStaff(m)
            end
        end
    end
    log("Loop", "ZombieStaff loop stopped")
end)

local brandLoop = newLoop()
task.spawn(function()
    log("Loop", "Firebrand loop started")
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
                fireFirebrand(m)
                break
            end
        end
    end
    log("Loop", "Firebrand loop stopped")
end)

local damageLoop = newLoop()
task.spawn(function()
    log("Loop", "DamageEvent loop started")
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
                fireZombieStaff(m)
            end
        end
    end
    log("Loop", "DamageEvent loop stopped")
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
                fireUmbrella()
            end
        end
    end
end))

local towelLoop = newLoop()
task.spawn(function()
    log("Loop", "AutoTowel loop started")
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
            local anchor = projectiles:GetChildren()[21]
            if anchor then
                pcall(function() ev:FireServer(anchor, CFrame.new(placePos, myHrp.Position), {}) end)
            end
            break
        end
    end
    log("Loop", "AutoTowel loop stopped")
end)

local shieldLoop = newLoop()
task.spawn(function()
    log("Loop", "ShieldBypass loop started")
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
    log("Loop", "ShieldBypass loop stopped")
end)

trackConn(RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if Speed.Enabled then
        hum.WalkSpeed = Speed.Value
    elseif hum.WalkSpeed ~= 16 then
        hum.WalkSpeed = 16
    end
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
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
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
    if not hrp then
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        return
    end
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
        if cam then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then md += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then md -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then md -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then md += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.new(0,1,0) end
            if md.Magnitude > 0 then
                flyBV.Velocity = md.Unit * Fly.Speed
            else
                flyBV.Velocity = Vector3.zero
            end
            flyBG.CFrame = cam.CFrame
        end
    else
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
    end
end))

local afkLoop = newLoop()
task.spawn(function()
    log("Loop", "AntiAFK loop started")
    while not afkLoop.Stopped do
        task.wait(AntiAFK.Interval)
        if afkLoop.Stopped then break end
        if AntiAFK.Enabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end
    log("Loop", "AntiAFK loop stopped")
end)

log("Loop", "All loops started")

-- ------------------------------------------------------------
-- 17. tabs and UI
-- ------------------------------------------------------------
log("UI", "Building tabs...")

local Main  = gui:tab{Icon = "rbxassetid://6034996695", Name = "Main"}
local Misc  = gui:tab{Icon = "rbxassetid://6031075931", Name = "Misc"}
local Tools = gui:tab{Icon = "rbxassetid://6031075931", Name = "Tools"}
local WhitelistTab = gui:tab{Icon = "rbxassetid://6031075931", Name = "Whitelist"}

-- main tab
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

-- tools tab
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

Tools:toggle({Name="Auto Freefall",Default=AutoFreefall.Enabled,Callback=function(s) AutoFreefall.Enabled = s saveConfig() end})
Tools:slider({Name="Auto Freefall Speed",Min=0.01,Max=2,Default=AutoFreefall.Speed,Decimals=2,Callback=function(v) AutoFreefall.Speed = v saveConfig() end})

Tools:toggle({Name="Super Ball",Default=SuperBall.Enabled,Callback=function(s) SuperBall.Enabled = s saveConfig() end})
Tools:slider({Name="Super Ball Speed",Min=0.01,Max=2,Default=SuperBall.Speed,Decimals=2,Callback=function(v) SuperBall.Speed = v saveConfig() end})

Tools:toggle({Name="Auto Umbrella",Default=AutoUmbrella.Enabled,Callback=function(s) AutoUmbrella.Enabled = s saveConfig() end})
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

-- misc tab
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
    log("Config", "Manual save triggered")
end})

-- whitelist tab
WhitelistTab:button({Name="Scan Server for Whitelisted",Callback=function()
    log("Whitelist", "Manual scan triggered")
    for _, plr in ipairs(Players:GetPlayers()) do
        checkWhitelist(plr, true)
    end
end})

WhitelistTab:button({Name="Dump Whitelisted Users",Callback=function()
    local out = {}
    for id, data in pairs(whitelistUsers) do
        table.insert(out, data.name .. " (" .. id .. ")")
    end
    if #out == 0 then
        log("Whitelist", "No whitelisted users loaded")
    else
        log("Whitelist", #out .. " users: " .. table.concat(out, ", "))
    end
end})

WhitelistTab:button({Name="Dump Whitelisted Groups",Callback=function()
    local out = {}
    for _, g in ipairs(whitelistedGroups) do
        table.insert(out, g.name .. " (" .. g.groupId .. ")")
    end
    log("Whitelist", #out .. " groups: " .. table.concat(out, ", "))
end})

WhitelistTab:toggle({Name="Am I Whitelisted?",Default=false,Callback=function(s)
    if not s then return end
    local userEntry = whitelistUsers[LocalPlayer.UserId]
    if userEntry then
        log("Whitelist", "YES - you are whitelisted as user: " .. userEntry.name)
    else
        log("Whitelist", "NO - you are not a whitelisted user")
    end
    local groupName = isWhitelistedGroup(LocalPlayer)
    if groupName then
        log("Whitelist", "YES - you are in group: " .. groupName)
    else
        log("Whitelist", "NO - you are not in any whitelisted group")
    end
end})

log("UI", "All tabs and controls created")

-- ------------------------------------------------------------
-- 18. character tracking
-- ------------------------------------------------------------
trackConn(LocalPlayer.CharacterAdded:Connect(function(char)
    log("Character", "Character added: " .. char.Name)
    task.wait(2)
    scanLimbs()
    applyAutoConfig()
end))

trackConn(LocalPlayer.CharacterRemoving:Connect(function()
    log("Character", "Character removing")
end))

-- ------------------------------------------------------------
-- 19. tool tracking
-- ------------------------------------------------------------
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

local function hookBackpack()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        trackConn(bp.ChildAdded:Connect(function(t)
            if t:IsA("Tool") then
                task.wait(0.3)
                scanToolsCache()
                log("Tools", "Tool added: " .. t.Name)
            end
        end))
    end
    trackConn(LocalPlayer.ChildAdded:Connect(function(c)
        if c.Name == "Backpack" then
            trackConn(c.ChildAdded:Connect(function(t)
                if t:IsA("Tool") then
                    task.wait(0.3)
                    scanToolsCache()
                    log("Tools", "Tool added: " .. t.Name)
                end
            end))
        end
    end))
end

hookBackpack()
scanToolsCache()
log("Tools", "Tool tracking initialized")

-- ------------------------------------------------------------
-- 20. final boot message
-- ------------------------------------------------------------
log("Boot", "Combat Initiation loaded successfully")
log("Boot", "Active loops: " .. #Combat._Loops)
log("Boot", "Active connections: " .. #Combat._Connections)
log("Boot", "Whitelisted users loaded: " .. (function()
    local n = 0
    for _ in pairs(whitelistUsers) do n = n + 1 end
    return n
end)())
log("Boot", "Whitelisted groups loaded: " .. #whitelistedGroups)
log("Boot", "Ready.")

