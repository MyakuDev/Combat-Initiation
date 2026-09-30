local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()
local gui = Library:create{Theme = Library.Themes.Serika}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

_G.Combat = _G.Combat or {
    KillAll      = {Enabled = false, Distance = 500, Speed = 0.1, Delay = 0.05, MaxPerTick = 5, HitParts = {"Head", "HumanoidRootPart"}},
    KillAura     = {Enabled = false, Distance = 25, Speed = 0.1, Delay = 0.05, MaxPerTick = 3, HitParts = {"Head", "HumanoidRootPart"}},
    AutoTowel    = {Enabled = false, Range = 50, Distance = 10},
    ShieldBypass = {Enabled = false, Speed = 0.1},
    Speed        = {Enabled = false, Value = 16},
    JumpPower    = {Enabled = false, Value = 50},
    Noclip       = {Enabled = false},
    InfiniteJump = {Enabled = false},
    Fly          = {Enabled = false, Speed = 50},
    AntiAFK      = {Enabled = false, Interval = 60},
    ModDetect    = {Enabled = true, KickMethod = "kick"},
}
local Combat = _G.Combat

local KillAll      = Combat.KillAll
local KillAura     = Combat.KillAura
local AutoTowel    = Combat.AutoTowel
local ShieldBypass = Combat.ShieldBypass
local Speed        = Combat.Speed
local JumpPower    = Combat.JumpPower
local Noclip       = Combat.Noclip
local InfiniteJump = Combat.InfiniteJump
local Fly          = Combat.Fly
local AntiAFK      = Combat.AntiAFK
local ModDetect    = Combat.ModDetect

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

local ROLE_FILES = {
    "Trusted", "Developers", "AssistantDevelopers", "RetiredDevelopers",
    "Consultants", "HeadOfStaff", "SeniorModerators", "Moderators",
    "JuniorModerators", "Contributors"
}

local RoleCache = {}

local function loadRoles()
    local root = (_G.Vigil and _G.Vigil.JsonRoot) or "C:/Users/kirok/OneDrive/Desktop/Yunrine/Lua/Mortem Metallum/Vigil/json"
    for _, roleName in ipairs(ROLE_FILES) do
        local ok, raw = pcall(readfile, root .. "/" .. roleName .. ".json")
        if ok and raw and raw ~= "" then
            local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and decoded and decoded.users then
                RoleCache[roleName] = decoded.users
            end
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
        if ModDetect.KickMethod == "shutdown" then
            game:Shutdown()
        else
            LocalPlayer:Kick("Windforce staff: " .. plr.Name .. " (" .. role .. ")")
        end
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

--

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
    ev:FireServer(
        hum,
        hitPart.Position,
        myHrp and myHrp.Position or hitPart.Position,
        hitPart,
        {
            Color = BrickColor.new("Light blue"),
            Quickdraw = false,
            ObjectBreak = false
        }
    )
end

--

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
    ev:FireServer(
        hitPart.Position,
        myHrp and myHrp.Position or hitPart.Position,
        hitPart,
        {}
    )
end

--

local function getEnemies()
    local folder = workspace:FindFirstChild("Enemies")
    if not folder then return {} end
    return folder:GetChildren()
end

local function isAlive(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

--

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

--

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

local function fireTowel(cframe)
    local char = getChar()
    if not char then return end
    local trowel = char:FindFirstChild("Trowel") or LocalPlayer.Backpack:FindFirstChild("Trowel")
    if not trowel then return end
    local ev = trowel:FindFirstChild("PlaceReplicate")
    if not ev then return end
    local maps = workspace:FindFirstChild("Maps")
    local map = maps and maps:FindFirstChild("Map")
    local room = map and map:FindFirstChild("Room")
    if not room then return end
    local anchor = room:GetChildren()[21]
    if not anchor then return end
    ev:FireServer(anchor, cframe, {})
end

--

local function getProjectiles()
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

--

task.spawn(function()
    while true do
        task.wait(ShieldBypass.Speed)
        if not ShieldBypass.Enabled then continue end
        local enemies = workspace:FindFirstChild("Enemies")
        if not enemies then continue end
        for _, npc in ipairs(enemies:GetChildren()) do
            local shield = npc:FindFirstChild("Shield")
            if shield and shield:IsA("UnionOperation") then
                pcall(function()
                    shield.CanCollide = false
                    shield.Transparency = 1
                    if shield:FindFirstChildOfClass("Decal") then
                        shield:FindFirstChildOfClass("Decal"):Destroy()
                    end
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
    end
end)

--

RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if JumpPower.Enabled then
        hum.UseJumpPower = true
        hum.JumpPower = JumpPower.Value
    end
end)

--

RunService.Stepped:Connect(function()
    if not Noclip.Enabled then return end
    local char = getChar()
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            p.CanCollide = false
        end
    end
end)

--

UserInputService.JumpRequest:Connect(function()
    if not InfiniteJump.Enabled then return end
    local hum = getHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

--

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

--

task.spawn(function()
    while true do
        task.wait(AntiAFK.Interval)
        if AntiAFK.Enabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end
end)

--

local Main = gui:tab{Icon = "rbxassetid://6034996695", Name = "Main"}
local Misc = gui:tab{Icon = "rbxassetid://6031075931", Name = "Misc"}

--

Main:toggle({Name="Kill All",Description="hits every enemy in range",Default=false,Callback=function(s) KillAll.Enabled = s end})
Main:slider({Name="Kill All Distance",Min=10,Max=2000,Default=500,Callback=function(v) KillAll.Distance = v end})
Main:slider({Name="Kill All Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) KillAll.Speed = v end})
Main:slider({Name="Kill All Delay",Min=0,Max=0.5,Default=0.05,Decimals=2,Callback=function(v) KillAll.Delay = v end})
Main:slider({Name="Kill All Max Per Tick",Min=1,Max=50,Default=5,Callback=function(v) KillAll.MaxPerTick = v end})
Main:dropdown({Name="Kill All Hit Part",StartingText="Head",Items={"Head","HumanoidRootPart","Torso","Left Arm","Right Arm","Left Leg","Right Leg"},Callback=function(v)
    KillAll.HitParts = {v}
end})

--

Main:toggle({Name="Kill Aura",Description="hits nearby enemies",Default=false,Callback=function(s) KillAura.Enabled = s end})
Main:slider({Name="Kill Aura Distance",Min=5,Max=100,Default=25,Callback=function(v) KillAura.Distance = v end})
Main:slider({Name="Kill Aura Speed",Min=0.01,Max=2,Default=0.1,Decimals=2,Callback=function(v) KillAura.Speed = v end})
Main:slider({Name="Kill Aura Delay",Min=0,Max=0.5,Default=0.05,Decimals=2,Callback=function(v) KillAura.Delay = v end})
Main:slider({Name="Kill Aura Max Per Tick",Min=1,Max=50,Default=3,Callback=function(v) KillAura.MaxPerTick = v end})
Main:dropdown({Name="Kill Aura Hit Part",StartingText="Head",Items={"Head","HumanoidRootPart","Torso","Left Arm","Right Arm","Left Leg","Right Leg"},Callback=function(v)
    KillAura.HitParts = {v}
end})

--

Main:toggle({Name="Auto Towel",Description="places Trowel in front of incoming projectiles",Default=false,Callback=function(s) AutoTowel.Enabled = s end})
Main:slider({Name="Towel Range",Min=5,Max=200,Default=50,Callback=function(v) AutoTowel.Range = v end})
Main:slider({Name="Towel Distance",Min=1,Max=30,Default=10,Callback=function(v) AutoTowel.Distance = v end})

--

Main:toggle({Name="Shield Bypass",Description="removes enemy shields (UnionOperation)",Default=false,Callback=function(s) ShieldBypass.Enabled = s end})
Main:slider({Name="Shield Bypass Speed",Min=0.01,Max=1,Default=0.1,Decimals=2,Callback=function(v) ShieldBypass.Speed = v end})

--

Misc:toggle({Name="Speed",Description="custom walkspeed",Default=false,Callback=function(s) Speed.Enabled = s end})
Misc:slider({Name="Speed Value",Min=16,Max=500,Default=16,Callback=function(v) Speed.Value = v end})

--

Misc:toggle({Name="JumpPower",Description="custom jumppower",Default=false,Callback=function(s) JumpPower.Enabled = s end})
Misc:slider({Name="JumpPower Value",Min=50,Max=500,Default=50,Callback=function(v) JumpPower.Value = v end})

--

Misc:toggle({Name="Noclip",Description="walk through walls",Default=false,Callback=function(s) Noclip.Enabled = s end})
Misc:toggle({Name="Infinite Jump",Description="jump in midair",Default=false,Callback=function(s) InfiniteJump.Enabled = s end})

--

Misc:toggle({Name="Fly",Description="WASD fly, space up, ctrl down",Default=false,Callback=function(s) Fly.Enabled = s end})
Misc:slider({Name="Fly Speed",Min=10,Max=500,Default=50,Callback=function(v) Fly.Speed = v end})

--

Misc:toggle({Name="Anti AFK",Description="prevents idle kick",Default=false,Callback=function(s) AntiAFK.Enabled = s end})
Misc:slider({Name="Anti AFK Interval",Min=10,Max=300,Default=60,Callback=function(v) AntiAFK.Interval = v end})

--

Misc:button({Name="Reset",Description="reset your character",Callback=function()
    local hum = getHum()
    if hum then hum.Health = 0 end
end})

Misc:button({Name="Rejoin",Description="rejoin current server",Callback=function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end})

--

notify("Combat Initiation", "loaded", 3)
