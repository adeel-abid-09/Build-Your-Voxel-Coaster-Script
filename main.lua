--[[
    ========================================================================
    VOXEL COASTER | AUTO BUILDER & AUTOMATION ENGINE
    ========================================================================
    Game: Build Your Voxel Coaster
    Optimized for: Delta, Fluxus, Arceus X, Codex, Solara, Wave, PC
    Theme: Pure Midnight Black & Clean Crisp White (Monochrome Pro UI)
    Layout: Portrait with Dynamic Scale, Minimize and Corner Resize Grip
    Strict Rule: Zero Emojis, No Hub Branding, 100% Toggle-Driven Automation
    ========================================================================
--]]

-- ========================================================================
-- SERVICES & CORE REFERENCES
-- ========================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

-- Safe GUI Parent Detection
local function getSafeParent()
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    local okCore, core = pcall(function() return CoreGui end)
    if okCore and core then
        local testOk = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = core
            test:Destroy()
        end)
        if testOk then return core end
    end
    return PlayerGui
end

local parentGui = getSafeParent()
local GUI_NAME = "VCAutoBuildMainGui"
local TOGGLE_NAME = "VCAutoBuildOpenToggle"

pcall(function()
    for _, child in ipairs(parentGui:GetChildren()) do
        if child.Name == GUI_NAME or child.Name == TOGGLE_NAME then
            child:Destroy()
        end
    end
end)

-- Game Remotes & References
local BuildRemotes = ReplicatedStorage:WaitForChild("BuildRemotes", 5)
local BuildToolRemotes = ReplicatedStorage:FindFirstChild("BuildToolRemotes")
local RewardRemotes = ReplicatedStorage:FindFirstChild("RewardRemotes")
local DailyRemotes = ReplicatedStorage:FindFirstChild("DailyRemotes")
local BlocksFolder = ReplicatedStorage:FindFirstChild("Blocks")
local PlacedBlocks = Workspace:FindFirstChild("PlacedBlocks")

local PlaceBlockRemote = BuildRemotes and BuildRemotes:FindFirstChild("PlaceBlock")
local BreakBlockRemote = BuildRemotes and BuildRemotes:FindFirstChild("BreakBlock")
local PlaceCartRemote = BuildRemotes and BuildRemotes:FindFirstChild("PlaceCart")
local RemoveCartRemote = BuildRemotes and BuildRemotes:FindFirstChild("RemoveCart")
local PlaceLoopRemote = BuildRemotes and BuildRemotes:FindFirstChild("PlaceLoop")
local PlaceTemplateRemote = BuildRemotes and BuildRemotes:FindFirstChild("PlaceTemplate")
local ClearAllRemote = BuildRemotes and BuildRemotes:FindFirstChild("ClearAll")

-- ========================================================================
-- RUNTIME STATE
-- ========================================================================
local State = {
    Running = true,
    UiScale = 1.0,
    
    -- Auto Build Toggles
    BuildCircuit = false,
    BuildOval = false,
    BuildSpiral = false,
    BuildRunway = false,
    BuildPlatform = false,
    BuildMegaPlatform = false,
    BuildSkyPillar = false,
    AutoRailPath = false,
    AutoClearBlocks = false,
    
    -- Stunt Loops Toggles
    LoopRail = false,
    MonsterLoop = false,
    MegaDrop = false,
    Corkscrew = false,
    GiantDrop = false,
    CobraRoll = false,
    ZeroGRoll = false,
    AirtimeHills = false,
    DoubleLoop = false,
    
    -- Cart & Ride Toggles
    AutoSpawnCart = false,
    AutoRideCart = false,
    BoostCartSpeed = false,
    CartSpeedMultiplier = 2,
    
    -- Automation & Rewards
    AutoClaimRewards = false,
    AutoClaimDaily = false,
    
    -- Movement & Utility
    SpeedHack = false,
    WalkSpeed = 32,
    JumpHack = false,
    JumpPower = 80,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
    AntiAFK = true,
    
    -- Settings
    BuildSpeed = 0.05,
    SelectedBlockType = "Oak Wood Plank",
    SelectedRailType = "Rail",
    Status = "Ready"
}

-- ========================================================================
-- MONOCHROME THEME (PURE BLACK & CRISP WHITE)
-- ========================================================================
local Theme = {
    BG        = Color3.fromRGB(12, 12, 12),
    Header    = Color3.fromRGB(18, 18, 18),
    ItemBg    = Color3.fromRGB(22, 22, 22),
    ItemHover = Color3.fromRGB(30, 30, 30),
    Border    = Color3.fromRGB(44, 44, 44),
    BorderLight = Color3.fromRGB(70, 70, 70),
    White     = Color3.fromRGB(255, 255, 255),
    Muted     = Color3.fromRGB(160, 160, 160),
    DarkMuted = Color3.fromRGB(100, 100, 100),
    ToggleOFF = Color3.fromRGB(28, 28, 28),
    ToggleON  = Color3.fromRGB(255, 255, 255),
    Red       = Color3.fromRGB(230, 60, 60),
    FontB     = Enum.Font.GothamBold,
    FontR     = Enum.Font.GothamMedium,
}

-- ========================================================================
-- UTILITY & TOOL HELPERS
-- ========================================================================
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Convert World Position to 4x4 Grid Cell
local function worldToCell(pos)
    return Vector3.new(
        math.floor((pos.X) / 4),
        math.floor((pos.Y) / 4),
        math.floor((pos.Z) / 4)
    )
end

-- Proper Tool Equipper with Humanoid Support
local function equipTool(toolName)
    local char = getCharacter()
    if not char then return nil end
    local hum = getHumanoid()
    
    local tool = char:FindFirstChild(toolName)
    if tool and tool:IsA("Tool") then return tool end
    
    local inBackpack = LocalPlayer.Backpack:FindFirstChild(toolName)
    if inBackpack then
        if hum then
            hum:EquipTool(inBackpack)
        else
            inBackpack.Parent = char
        end
        return inBackpack
    end
    
    return char:FindFirstChildOfClass("Tool")
end

-- Universal Block Placement Dispatcher (Robust multi-signature)
local function placeVoxelBlock(cell, blockName, rot)
    rot = rot or 0
    if not PlaceBlockRemote then return false end
    
    -- Equip tool if available
    local tool = equipTool(blockName)
    
    -- Safe multi-signature fire
    pcall(function()
        PlaceBlockRemote:FireServer(cell, rot)
    end)
    pcall(function()
        PlaceBlockRemote:FireServer(cell, blockName, rot)
    end)
    pcall(function()
        PlaceBlockRemote:FireServer(cell, rot, blockName)
    end)
    pcall(function()
        PlaceBlockRemote:FireServer(cell, rot, Vector3.new(0, 0, 1))
    end)
    
    if tool and tool:FindFirstChild("Handle") then
        pcall(function() tool:Activate() end)
    end
    
    return true
end

-- ========================================================================
-- CORE AUTO BUILD RUNNERS (TOGGLE DRIVEN)
-- ========================================================================

-- 1. Closed Coaster Loop
task.spawn(function()
    while State.Running do
        if State.BuildCircuit then
            State.Status = "Building Coaster Loop..."
            local root = getRootPart()
            if root then
                local centerCell = worldToCell(root.Position)
                local rX, rZ = 8, 8
                local y = math.max(1, centerCell.Y + 1)
                
                local trackCells = {}
                for x = -rX, rX do
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X + x, y, centerCell.Z - rZ), rot = 0, isPower = (math.abs(x) % 3 == 0)})
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X + x, y, centerCell.Z + rZ), rot = 2, isPower = (math.abs(x) % 3 == 0)})
                end
                for z = -rZ + 1, rZ - 1 do
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X + rX, y, centerCell.Z + z), rot = 1, isPower = (math.abs(z) % 3 == 0)})
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X - rX, y, centerCell.Z + z), rot = 3, isPower = (math.abs(z) % 3 == 0)})
                end
                
                -- Place support foundation under track
                for _, pt in ipairs(trackCells) do
                    if not State.BuildCircuit then break end
                    local baseCell = Vector3.new(pt.cell.X, pt.cell.Y - 1, pt.cell.Z)
                    placeVoxelBlock(baseCell, "Oak Wood Plank", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
                
                -- Place rails
                for _, pt in ipairs(trackCells) do
                    if not State.BuildCircuit then break end
                    local rail = pt.isPower and "Powered Rail - Active" or "Rail"
                    placeVoxelBlock(pt.cell, rail, pt.rot)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildCircuit = false
            State.Status = "Coaster Loop Complete!"
        end
        task.wait(0.3)
    end
end)

-- 2. Large Oval Circuit
task.spawn(function()
    while State.Running do
        if State.BuildOval then
            State.Status = "Building Oval Circuit..."
            local root = getRootPart()
            if root then
                local centerCell = worldToCell(root.Position)
                local rX, rZ = 14, 8
                local y = math.max(1, centerCell.Y + 1)
                
                local trackCells = {}
                for x = -rX, rX do
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X + x, y, centerCell.Z - rZ), rot = 0, isPower = (math.abs(x) % 3 == 0)})
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X + x, y, centerCell.Z + rZ), rot = 2, isPower = (math.abs(x) % 3 == 0)})
                end
                for z = -rZ + 1, rZ - 1 do
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X + rX, y, centerCell.Z + z), rot = 1, isPower = (math.abs(z) % 3 == 0)})
                    table.insert(trackCells, {cell = Vector3.new(centerCell.X - rX, y, centerCell.Z + z), rot = 3, isPower = (math.abs(z) % 3 == 0)})
                end
                
                for _, pt in ipairs(trackCells) do
                    if not State.BuildOval then break end
                    local baseCell = Vector3.new(pt.cell.X, pt.cell.Y - 1, pt.cell.Z)
                    placeVoxelBlock(baseCell, "Stone Bricks", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
                
                for _, pt in ipairs(trackCells) do
                    if not State.BuildOval then break end
                    local rail = pt.isPower and "Powered Rail - Active" or "Rail"
                    placeVoxelBlock(pt.cell, rail, pt.rot)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildOval = false
            State.Status = "Oval Circuit Complete!"
        end
        task.wait(0.3)
    end
end)

-- 3. Sky Spiral Coaster
task.spawn(function()
    while State.Running do
        if State.BuildSpiral then
            State.Status = "Building Sky Spiral..."
            local root = getRootPart()
            if root then
                local centerCell = worldToCell(root.Position)
                local rad = 5
                local levels = 8
                local angle = 0
                local stepAngle = math.pi / 4
                
                for i = 1, levels * 8 do
                    if not State.BuildSpiral then break end
                    local cx = centerCell.X + math.round(math.cos(angle) * rad)
                    local cz = centerCell.Z + math.round(math.sin(angle) * rad)
                    local curY = math.max(1, centerCell.Y + math.floor(i / 2))
                    
                    local cPos = Vector3.new(cx, curY, cz)
                    local pillarBase = Vector3.new(cx, curY - 1, cz)
                    
                    placeVoxelBlock(pillarBase, "Oak Wood Plank", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    
                    placeVoxelBlock(cPos, "Chainlift Rail", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    
                    angle = angle + stepAngle
                end
            end
            State.BuildSpiral = false
            State.Status = "Sky Spiral Complete!"
        end
        task.wait(0.3)
    end
end)

-- 4. High-Speed Straight Runway
task.spawn(function()
    while State.Running do
        if State.BuildRunway then
            State.Status = "Building Speed Runway..."
            local root = getRootPart()
            if root then
                local startCell = worldToCell(root.Position)
                local lookDir = root.CFrame.LookVector
                local dirX = math.abs(lookDir.X) > math.abs(lookDir.Z) and (lookDir.X > 0 and 1 or -1) or 0
                local dirZ = dirX == 0 and (lookDir.Z > 0 and 1 or -1) or 0
                local len = 25
                local curY = math.max(1, startCell.Y)
                
                for i = 1, len do
                    if not State.BuildRunway then break end
                    local curCell = Vector3.new(startCell.X + (dirX * i), curY, startCell.Z + (dirZ * i))
                    local underCell = Vector3.new(curCell.X, curCell.Y - 1, curCell.Z)
                    
                    placeVoxelBlock(underCell, "Stone Bricks", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    
                    local rail = (i % 2 == 0) and "Launch Rail" or "Powered Rail - Active"
                    placeVoxelBlock(curCell, rail, 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildRunway = false
            State.Status = "Runway Complete!"
        end
        task.wait(0.3)
    end
end)

-- 5. Flat Platform (10x10)
task.spawn(function()
    while State.Running do
        if State.BuildPlatform then
            State.Status = "Building Platform (10x10)..."
            local root = getRootPart()
            if root then
                local centerCell = worldToCell(root.Position)
                local half = 5
                local y = math.max(0, centerCell.Y - 1)
                
                for x = -half, half do
                    for z = -half, half do
                        if not State.BuildPlatform then break end
                        local targetCell = Vector3.new(centerCell.X + x, y, centerCell.Z + z)
                        placeVoxelBlock(targetCell, State.SelectedBlockType, 0)
                        if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    end
                end
            end
            State.BuildPlatform = false
            State.Status = "Platform (10x10) Complete!"
        end
        task.wait(0.3)
    end
end)

-- 6. Mega Platform (20x20)
task.spawn(function()
    while State.Running do
        if State.BuildMegaPlatform then
            State.Status = "Building Platform (20x20)..."
            local root = getRootPart()
            if root then
                local centerCell = worldToCell(root.Position)
                local half = 10
                local y = math.max(0, centerCell.Y - 1)
                
                for x = -half, half do
                    for z = -half, half do
                        if not State.BuildMegaPlatform then break end
                        local targetCell = Vector3.new(centerCell.X + x, y, centerCell.Z + z)
                        placeVoxelBlock(targetCell, State.SelectedBlockType, 0)
                        if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    end
                end
            end
            State.BuildMegaPlatform = false
            State.Status = "Platform (20x20) Complete!"
        end
        task.wait(0.3)
    end
end)

-- 7. Sky Pillar (Height 25)
task.spawn(function()
    while State.Running do
        if State.BuildSkyPillar then
            State.Status = "Building Sky Pillar..."
            local root = getRootPart()
            if root then
                local centerCell = worldToCell(root.Position)
                for y = 0, 25 do
                    if not State.BuildSkyPillar then break end
                    local targetCell = Vector3.new(centerCell.X, centerCell.Y + y, centerCell.Z)
                    placeVoxelBlock(targetCell, State.SelectedBlockType, 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildSkyPillar = false
            State.Status = "Sky Pillar Complete!"
        end
        task.wait(0.3)
    end
end)

-- 8. Live Rail Path Follower (Lays rails as you move)
task.spawn(function()
    while State.Running do
        if State.AutoRailPath then
            local root = getRootPart()
            if root then
                local currentCell = worldToCell(root.Position)
                local floorCell = Vector3.new(currentCell.X, currentCell.Y - 1, currentCell.Z)
                local trackCell = Vector3.new(currentCell.X, currentCell.Y, currentCell.Z)
                
                placeVoxelBlock(floorCell, State.SelectedBlockType, 0)
                placeVoxelBlock(trackCell, State.SelectedRailType, 0)
            end
        end
        task.wait(0.18)
    end
end)

-- 9. Auto Demolish / Clear Blocks
task.spawn(function()
    while State.Running do
        if State.AutoClearBlocks then
            if ClearAllRemote then
                pcall(function() ClearAllRemote:FireServer() end)
                State.Status = "Cleared Placed Blocks"
            end
            State.AutoClearBlocks = false
        end
        task.wait(0.5)
    end
end)

-- 10. Stunt Loops & Presets Runners
local function runStuntPreset(kind, r)
    local root = getRootPart()
    if root and PlaceLoopRemote then
        local cell = worldToCell(root.Position + root.CFrame.LookVector * 10)
        pcall(function()
            PlaceLoopRemote:FireServer(cell, kind, 0, r, Vector3.new(0, 0, 1))
        end)
        State.Status = "Placed " .. kind
    end
end

task.spawn(function()
    while State.Running do
        if State.LoopRail then runStuntPreset("loop", 6); State.LoopRail = false end
        if State.MonsterLoop then runStuntPreset("loop", 16); State.MonsterLoop = false end
        if State.MegaDrop then runStuntPreset("megadrop", 6); State.MegaDrop = false end
        if State.Corkscrew then runStuntPreset("corkscrew", 6); State.Corkscrew = false end
        if State.GiantDrop then runStuntPreset("giantdrop", 6); State.GiantDrop = false end
        if State.CobraRoll then runStuntPreset("cobra", 6); State.CobraRoll = false end
        if State.ZeroGRoll then runStuntPreset("zerog", 6); State.ZeroGRoll = false end
        if State.AirtimeHills then runStuntPreset("airtime", 6); State.AirtimeHills = false end
        if State.DoubleLoop then runStuntPreset("doubleloop", 6); State.DoubleLoop = false end
        task.wait(0.3)
    end
end)

-- ========================================================================
-- MINECART & REWARDS AUTOMATION
-- ========================================================================
task.spawn(function()
    while State.Running do
        if State.AutoSpawnCart and PlaceCartRemote then
            local root = getRootPart()
            if root then
                equipTool("Minecart")
                local myCell = worldToCell(root.Position)
                pcall(function() PlaceCartRemote:FireServer(myCell) end)
                State.Status = "Spawned Cart"
            end
            State.AutoSpawnCart = false
        end
        
        if State.AutoRideCart then
            local root = getRootPart()
            if root then
                local nearest = nil
                local minDist = 40
                local cartsFolder = Workspace:FindFirstChild("Minecarts") or Workspace
                for _, item in ipairs(cartsFolder:GetDescendants()) do
                    if item:IsA("VehicleSeat") or (item:IsA("Seat") and item.Name:lower():find("cart")) then
                        local d = (item.Position - root.Position).Magnitude
                        if d < minDist and not item.Occupant then
                            minDist = d
                            nearest = item
                        end
                    end
                end
                if nearest then
                    local hum = getHumanoid()
                    if hum then nearest:Sit(hum); State.Status = "Mounted Cart" end
                end
            end
        end
        
        if State.BoostCartSpeed then
            local hum = getHumanoid()
            if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
                local seat = hum.SeatPart
                seat.MaxSpeed = 120 * State.CartSpeedMultiplier
                seat.Torque = 600000
                local mdl = seat:FindFirstAncestorOfClass("Model")
                if mdl and mdl.PrimaryPart then
                    mdl.PrimaryPart.AssemblyLinearVelocity = mdl.PrimaryPart.CFrame.LookVector * (65 * State.CartSpeedMultiplier)
                end
            end
        end
        
        if State.AutoClaimDaily and DailyRemotes then
            local cd = DailyRemotes:FindFirstChild("ClaimDaily")
            if cd then pcall(function() cd:FireServer() end) end
        end
        if State.AutoClaimRewards and RewardRemotes then
            local cr = RewardRemotes:FindFirstChild("ClaimReward")
            if cr then
                for i = 1, 12 do pcall(function() cr:FireServer(i) end) end
            end
        end
        
        task.wait(1.5)
    end
end)

-- Movement & Noclip
RunService.RenderStepped:Connect(function()
    local hum = getHumanoid()
    if hum then
        if State.SpeedHack and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
        end
        if State.JumpHack and hum.JumpPower ~= State.JumpPower then
            hum.UseJumpPower = true
            hum.JumpPower = State.JumpPower
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Stepped:Connect(function()
    if State.Noclip then
        local char = getCharacter()
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end)

-- Fly System
local flyBV, flyBG
local function toggleFly(enable)
    local root = getRootPart()
    if not root then return end
    if enable then
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
        
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
        
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBG.P = 15000
        flyBG.CFrame = root.CFrame
        flyBG.Parent = root
        
        local hum = getHumanoid()
        if hum then hum.PlatformStand = true end
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        local hum = getHumanoid()
        if hum then hum.PlatformStand = false end
    end
end

RunService.RenderStepped:Connect(function()
    if State.Fly and flyBV and flyBG then
        local root = getRootPart()
        if not root then return end
        local moveDir = Vector3.zero
        local camCF = Camera.CFrame
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        if moveDir.Magnitude > 0 then
            flyBV.Velocity = moveDir.Unit * State.FlySpeed
        else
            flyBV.Velocity = Vector3.zero
        end
        flyBG.CFrame = camCF
    end
end)

LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

-- ========================================================================
-- PORTRAIT USER INTERFACE (PURE BLACK BOXES, CRISP WHITE TEXT)
-- ========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = parentGui

local function makeDraggable(frame, handle)
    handle = handle or frame
    local drag, dInp, dSt, dP0
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; dSt = i.Position; dP0 = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then dInp = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == dInp and drag then
            local d = i.Position - dSt
            frame.Position = UDim2.new(dP0.X.Scale, dP0.X.Offset + d.X, dP0.Y.Scale, dP0.Y.Offset + d.Y)
        end
    end)
end

-- Mobile Floating Re-Open Button
local OpenGui = Instance.new("ScreenGui")
OpenGui.Name = TOGGLE_NAME
OpenGui.ResetOnSpawn = false
OpenGui.DisplayOrder = 999998
OpenGui.IgnoreGuiInset = true
OpenGui.Parent = parentGui

local FloatBtn = Instance.new("TextButton", OpenGui)
FloatBtn.Name = "FloatToggle"
FloatBtn.Size = UDim2.new(0, 92, 0, 32)
FloatBtn.Position = UDim2.new(0, 15, 0.45, 0)
FloatBtn.BackgroundColor3 = Theme.BG
FloatBtn.BorderSizePixel = 0
FloatBtn.Font = Theme.FontB
FloatBtn.Text = "AUTO BUILD"
FloatBtn.TextColor3 = Theme.White
FloatBtn.TextSize = 11
FloatBtn.Active = true
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 6)
local fS = Instance.new("UIStroke", FloatBtn)
fS.Color = Theme.White; fS.Thickness = 1.2
makeDraggable(FloatBtn)

-- Main Portrait Panel
local curW = 270
local curH = 380
local isMin = false

local Main = Instance.new("Frame", ScreenGui)
Main.Name = "MainPanel"
Main.Size = UDim2.new(0, curW, 0, curH)
Main.Position = UDim2.new(0.5, -135, 0.5, -190)
Main.BackgroundColor3 = Theme.BG
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
local mS = Instance.new("UIStroke", Main)
mS.Color = Theme.Border; mS.Thickness = 1.2

-- Global Scale Controller
local GlobalScale = Instance.new("UIScale", Main)
GlobalScale.Scale = State.UiScale

local function setScale(val)
    val = math.clamp(val, 0.5, 1.6)
    State.UiScale = val
    GlobalScale.Scale = val
end

-- Header
local Hdr = Instance.new("Frame", Main)
Hdr.Name = "Header"
Hdr.Size = UDim2.new(1, 0, 0, 32)
Hdr.BackgroundColor3 = Theme.Header
Hdr.BorderSizePixel = 0
Hdr.ZIndex = 10
Instance.new("UICorner", Hdr).CornerRadius = UDim.new(0, 8)

local Ttl = Instance.new("TextLabel", Hdr)
Ttl.Size = UDim2.new(1, -110, 1, 0)
Ttl.Position = UDim2.new(0, 10, 0, 0)
Ttl.BackgroundTransparency = 1
Ttl.Font = Theme.FontB
Ttl.Text = "AUTO BUILDER"
Ttl.TextColor3 = Theme.White
Ttl.TextSize = 11.5
Ttl.TextXAlignment = Enum.TextXAlignment.Left
Ttl.ZIndex = 11

-- Scale Down Button (-)
local ScaleMinus = Instance.new("TextButton", Hdr)
ScaleMinus.Size = UDim2.new(0, 20, 0, 20)
ScaleMinus.Position = UDim2.new(1, -100, 0.5, -10)
ScaleMinus.BackgroundColor3 = Theme.ItemBg
ScaleMinus.Text = "-"
ScaleMinus.Font = Theme.FontB
ScaleMinus.TextColor3 = Theme.White
ScaleMinus.TextSize = 13
ScaleMinus.AutoButtonColor = false
ScaleMinus.ZIndex = 12
Instance.new("UICorner", ScaleMinus).CornerRadius = UDim.new(0, 4)

-- Scale Up Button (+)
local ScalePlus = Instance.new("TextButton", Hdr)
ScalePlus.Size = UDim2.new(0, 20, 0, 20)
ScalePlus.Position = UDim2.new(1, -76, 0.5, -10)
ScalePlus.BackgroundColor3 = Theme.ItemBg
ScalePlus.Text = "+"
ScalePlus.Font = Theme.FontB
ScalePlus.TextColor3 = Theme.White
ScalePlus.TextSize = 13
ScalePlus.AutoButtonColor = false
ScalePlus.ZIndex = 12
Instance.new("UICorner", ScalePlus).CornerRadius = UDim.new(0, 4)

-- Minimize Button (_)
local MinB = Instance.new("TextButton", Hdr)
MinB.Size = UDim2.new(0, 20, 0, 20)
MinB.Position = UDim2.new(1, -52, 0.5, -10)
MinB.BackgroundColor3 = Theme.ItemBg
MinB.Text = "_"
MinB.Font = Theme.FontB
MinB.TextColor3 = Theme.Muted
MinB.TextSize = 10
MinB.AutoButtonColor = false
MinB.ZIndex = 12
Instance.new("UICorner", MinB).CornerRadius = UDim.new(0, 4)

-- Close Button (X)
local XBtn = Instance.new("TextButton", Hdr)
XBtn.Size = UDim2.new(0, 20, 0, 20)
XBtn.Position = UDim2.new(1, -28, 0.5, -10)
XBtn.BackgroundColor3 = Color3.fromRGB(35, 18, 18)
XBtn.Text = "X"
XBtn.Font = Theme.FontB
XBtn.TextColor3 = Theme.Red
XBtn.TextSize = 10.5
XBtn.AutoButtonColor = false
XBtn.ZIndex = 12
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 4)

-- Category Navigation Bar
local CatBar = Instance.new("Frame", Main)
CatBar.Name = "CategoryBar"
CatBar.Size = UDim2.new(1, -10, 0, 26)
CatBar.Position = UDim2.new(0, 5, 0, 36)
CatBar.BackgroundTransparency = 1
CatBar.ZIndex = 5

local CatLayout = Instance.new("UIListLayout", CatBar)
CatLayout.FillDirection = Enum.FillDirection.Horizontal
CatLayout.Padding = UDim.new(0, 4)
CatLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Scrolling Body
local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -10, 1, -88)
Scroll.Position = UDim2.new(0, 5, 0, 66)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 2.5
Scroll.ScrollBarImageColor3 = Theme.White
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ZIndex = 2

local SL = Instance.new("UIListLayout", Scroll)
SL.Padding = UDim.new(0, 5)
SL.SortOrder = Enum.SortOrder.LayoutOrder

-- Footer (Status & Resize Grip)
local Ftr = Instance.new("Frame", Main)
Ftr.Size = UDim2.new(1, 0, 0, 22)
Ftr.Position = UDim2.new(0, 0, 1, -22)
Ftr.BackgroundColor3 = Theme.Header
Ftr.BorderSizePixel = 0
Ftr.ZIndex = 3

local FtrL = Instance.new("TextLabel", Ftr)
FtrL.Name = "Status"
FtrL.Size = UDim2.new(1, -80, 1, 0)
FtrL.Position = UDim2.new(0, 8, 0, 0)
FtrL.BackgroundTransparency = 1
FtrL.Font = Theme.FontR
FtrL.Text = "Status: Ready"
FtrL.TextColor3 = Theme.White
FtrL.TextSize = 10
FtrL.TextXAlignment = Enum.TextXAlignment.Left
FtrL.ZIndex = 4

-- Dynamic Corner Resize Grip
local ResizeHandle = Instance.new("TextButton", Main)
ResizeHandle.Name = "ResizeGrip"
ResizeHandle.Size = UDim2.new(0, 64, 0, 18)
ResizeHandle.Position = UDim2.new(1, -66, 1, -20)
ResizeHandle.BackgroundColor3 = Theme.ItemBg
ResizeHandle.Text = "RESIZE ///"
ResizeHandle.Font = Theme.FontB
ResizeHandle.TextColor3 = Theme.Muted
ResizeHandle.TextSize = 9
ResizeHandle.AutoButtonColor = false
ResizeHandle.BorderSizePixel = 0
ResizeHandle.ZIndex = 5
Instance.new("UICorner", ResizeHandle).CornerRadius = UDim.new(0, 4)

-- Minimize / Restore Function
local function toggleMinimize(target)
    if target ~= nil then isMin = target else isMin = not isMin end
    if isMin then
        CatBar.Visible = false
        Scroll.Visible = false
        Ftr.Visible = false
        ResizeHandle.Visible = false
        MinB.Text = "+"
        Ttl.Text = "AUTO BUILDER [CLICK +]"
        TweenService:Create(Main, TweenInfo.new(0.2), {Size = UDim2.new(0, curW, 0, 32)}):Play()
    else
        MinB.Text = "_"
        Ttl.Text = "AUTO BUILDER"
        CatBar.Visible = true
        Scroll.Visible = true
        Ftr.Visible = true
        ResizeHandle.Visible = true
        TweenService:Create(Main, TweenInfo.new(0.2), {Size = UDim2.new(0, curW, 0, curH)}):Play()
    end
end

makeDraggable(Main, Hdr)
FloatBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
    if Main.Visible and isMin then toggleMinimize(false) end
end)

XBtn.MouseButton1Click:Connect(function() Main.Visible = false end)
MinB.MouseButton1Click:Connect(function() toggleMinimize() end)
ScaleMinus.MouseButton1Click:Connect(function() setScale(State.UiScale - 0.1) end)
ScalePlus.MouseButton1Click:Connect(function() setScale(State.UiScale + 0.1) end)

-- Dynamic Drag Resize Handler
local resizing = false
local rStartPos, rStartSize
ResizeHandle.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        rStartPos = i.Position
        rStartSize = Vector2.new(Main.AbsoluteSize.X, Main.AbsoluteSize.Y)
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then resizing = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local delta = (i.Position - rStartPos) / (GlobalScale.Scale or 1)
        local newW = math.clamp(rStartSize.X + delta.X, 220, 480)
        local newH = math.clamp(rStartSize.Y + delta.Y, 260, 650)
        curW = newW
        curH = newH
        if not isMin then Main.Size = UDim2.new(0, newW, 0, newH) end
    end
end)

-- ========================================================================
-- CATEGORY SYSTEM & UI HELPERS (STRICT TOGGLES ONLY)
-- ========================================================================
local CategoryPages = {}
local CategoryButtons = {}
local activeCategory = "TRACKS"

local function AddCategory(name)
    local btn = Instance.new("TextButton", CatBar)
    btn.Size = UDim2.new(0.24, -2, 1, 0)
    btn.BackgroundColor3 = Theme.ItemBg
    btn.Text = name
    btn.Font = Theme.FontB
    btn.TextColor3 = Theme.DarkMuted
    btn.TextSize = 9.5
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local st = Instance.new("UIStroke", btn)
    st.Color = Theme.Border; st.Thickness = 1
    
    local container = Instance.new("Frame", Scroll)
    container.Size = UDim2.new(1, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.Visible = false
    
    local layout = Instance.new("UIListLayout", container)
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    CategoryPages[name] = container
    CategoryButtons[name] = {btn = btn, stroke = st}
    
    btn.MouseButton1Click:Connect(function()
        for cat, page in pairs(CategoryPages) do
            page.Visible = (cat == name)
        end
        for cat, item in pairs(CategoryButtons) do
            local isAct = (cat == name)
            item.btn.TextColor3 = isAct and Theme.White or Theme.DarkMuted
            item.stroke.Color = isAct and Theme.White or Theme.Border
        end
        activeCategory = name
    end)
    
    return container
end

local PageTracks     = AddCategory("TRACKS")
local PageStructures = AddCategory("BUILDS")
local PageStunts     = AddCategory("LOOPS")
local PagePlayer     = AddCategory("PLAYER")

-- Set Default Category Active
CategoryPages["TRACKS"].Visible = true
CategoryButtons["TRACKS"].btn.TextColor3 = Theme.White
CategoryButtons["TRACKS"].stroke.Color = Theme.White

-- Helper: Section Divider
local function AddSection(parent, title)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 18)
    f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Font = Theme.FontB
    l.Text = "  " .. title:upper()
    l.TextColor3 = Theme.White
    l.TextSize = 9.5
    l.TextXAlignment = Enum.TextXAlignment.Left
    local ln = Instance.new("Frame", f)
    ln.Size = UDim2.new(1, -6, 0, 1)
    ln.Position = UDim2.new(0, 3, 1, -1)
    ln.BackgroundColor3 = Theme.Border
    ln.BorderSizePixel = 0
end

-- Helper: Pure ON/OFF Toggle Card (No Execute Button!)
local function AddToggle(parent, title, desc, defaultVal, callback)
    local state = defaultVal or false
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Theme.ItemBg
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local sk = Instance.new("UIStroke", row)
    sk.Color = Theme.Border; sk.Thickness = 1

    local tLbl = Instance.new("TextLabel", row)
    tLbl.Size = UDim2.new(1, -52, 0, 16)
    tLbl.Position = UDim2.new(0, 8, 0, 2)
    tLbl.BackgroundTransparency = 1
    tLbl.Font = Theme.FontB
    tLbl.Text = title
    tLbl.TextColor3 = Theme.White
    tLbl.TextSize = 10.5
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local dLbl = Instance.new("TextLabel", row)
    dLbl.Size = UDim2.new(1, -52, 0, 14)
    dLbl.Position = UDim2.new(0, 8, 0, 18)
    dLbl.BackgroundTransparency = 1
    dLbl.Font = Theme.FontR
    dLbl.Text = desc
    dLbl.TextColor3 = Theme.Muted
    dLbl.TextSize = 8.5
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local box = Instance.new("TextButton", row)
    box.Size = UDim2.new(0, 38, 0, 18)
    box.Position = UDim2.new(1, -44, 0.5, -9)
    box.BackgroundColor3 = state and Theme.ToggleON or Theme.ToggleOFF
    box.Text = state and "ON" or "OFF"
    box.Font = Theme.FontB
    box.TextColor3 = state and Theme.BG or Theme.Muted
    box.TextSize = 9.5
    box.AutoButtonColor = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    local bStroke = Instance.new("UIStroke", box)
    bStroke.Color = state and Theme.White or Theme.BorderLight
    bStroke.Thickness = 1

    local function flip(v)
        state = v
        box.BackgroundColor3 = state and Theme.ToggleON or Theme.ToggleOFF
        box.Text = state and "ON" or "OFF"
        box.TextColor3 = state and Theme.BG or Theme.Muted
        bStroke.Color = state and Theme.White or Theme.BorderLight
        pcall(callback, state)
    end

    box.MouseButton1Click:Connect(function() flip(not state) end)
    
    local clickArea = Instance.new("TextButton", row)
    clickArea.Size = UDim2.new(1, -48, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.MouseButton1Click:Connect(function() flip(not state) end)

    return {
        Set = function(v) flip(v) end
    }
end

-- Helper: Slider
local function AddSlider(parent, title, minVal, maxVal, defaultVal, callback)
    local val = defaultVal or minVal
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = Theme.ItemBg
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", row).Color = Theme.Border

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -45, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, 3)
    lbl.BackgroundTransparency = 1
    lbl.Font = Theme.FontB
    lbl.Text = title
    lbl.TextColor3 = Theme.White
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local vL = Instance.new("TextLabel", row)
    vL.Size = UDim2.new(0, 40, 0, 18)
    vL.Position = UDim2.new(1, -45, 0, 3)
    vL.BackgroundTransparency = 1
    vL.Font = Theme.FontB
    vL.Text = tostring(val)
    vL.TextColor3 = Theme.White
    vL.TextSize = 10
    vL.TextXAlignment = Enum.TextXAlignment.Right

    local bar = Instance.new("TextButton", row)
    bar.Size = UDim2.new(1, -16, 0, 6)
    bar.Position = UDim2.new(0, 8, 0, 26)
    bar.BackgroundColor3 = Theme.Border
    bar.Text = ""
    bar.AutoButtonColor = false
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(math.clamp((val - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.White
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local drag = false
    local function upd(i)
        local rx = math.clamp(i.Position.X - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
        local r = rx / bar.AbsoluteSize.X
        val = math.floor(minVal + (maxVal - minVal) * r)
        fill.Size = UDim2.new(r, 0, 1, 0)
        vL.Text = tostring(val)
        pcall(callback, val)
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; upd(i)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            upd(i)
        end
    end)
end

-- ========================================================================
-- POPULATE CATEGORIES (STRICT ZERO EXECUTE BUTTONS - ALL TOGGLES)
-- ========================================================================

-- TAB 1: TRACKS
AddSection(PageTracks, "Continuous Rail Builders")
AddToggle(PageTracks, "Auto Rail Walk/Fly Follower", "Lays rails directly in front as you move", State.AutoRailPath, function(v)
    State.AutoRailPath = v
end)

AddToggle(PageTracks, "Auto Build Coaster Loop", "Constructs a full closed loop circuit", State.BuildCircuit, function(v)
    State.BuildCircuit = v
end)

AddToggle(PageTracks, "Auto Build Large Oval Track", "Extended high-speed oval circuit", State.BuildOval, function(v)
    State.BuildOval = v
end)

AddToggle(PageTracks, "Auto Build Sky Spiral Tower", "8-point spiraling coaster with chainlift", State.BuildSpiral, function(v)
    State.BuildSpiral = v
end)

AddToggle(PageTracks, "Auto Build Speed Runway", "Straight boosted launch track", State.BuildRunway, function(v)
    State.BuildRunway = v
end)

AddSection(PageTracks, "Build Settings")
AddSlider(PageTracks, "Block Placement Speed (ms)", 10, 150, 50, function(v)
    State.BuildSpeed = v / 1000
end)

-- TAB 2: BUILDS (STRUCTURES & FOUNDATIONS)
AddSection(PageStructures, "Voxel Platforms and Towers")
AddToggle(PageStructures, "Auto Build Platform (10x10)", "Generates a clean voxel floor under feet", State.BuildPlatform, function(v)
    State.BuildPlatform = v
end)

AddToggle(PageStructures, "Auto Build Platform (20x20)", "Large foundation for big coaster designs", State.BuildMegaPlatform, function(v)
    State.BuildMegaPlatform = v
end)

AddToggle(PageStructures, "Auto Build Sky Pillar", "Pillar straight up to the build height", State.BuildSkyPillar, function(v)
    State.BuildSkyPillar = v
end)

AddToggle(PageStructures, "Clear All Placed Blocks", "Demolishes all user-placed blocks on plot", State.AutoClearBlocks, function(v)
    State.AutoClearBlocks = v
end)

-- TAB 3: LOOPS (STUNT TRACK PRESETS)
AddSection(PageStunts, "Instant Stunt Tracks")
AddToggle(PageStunts, "Place Loop Rail", "Vertical loop at front cell", State.LoopRail, function(v) State.LoopRail = v end)
AddToggle(PageStunts, "Place Monster Loop", "Gigantic 16-stud radius stunt loop", State.MonsterLoop, function(v) State.MonsterLoop = v end)
AddToggle(PageStunts, "Place Mega Drop", "Steep high vertical drop track", State.MegaDrop, function(v) State.MegaDrop = v end)
AddToggle(PageStunts, "Place Corkscrew", "360-degree corkscrew roll element", State.Corkscrew, function(v) State.Corkscrew = v end)
AddToggle(PageStunts, "Place Giant Drop", "Huge thrill tower drop track", State.GiantDrop, function(v) State.GiantDrop = v end)
AddToggle(PageStunts, "Place Cobra Roll", "Double inversion cobra roll stunt", State.CobraRoll, function(v) State.CobraRoll = v end)
AddToggle(PageStunts, "Place Zero-G Roll", "Weightless zero gravity roll", State.ZeroGRoll, function(v) State.ZeroGRoll = v end)
AddToggle(PageStunts, "Place Airtime Hills", "Triple airtime camelback hills", State.AirtimeHills, function(v) State.AirtimeHills = v end)
AddToggle(PageStunts, "Place Double Loop", "Twin continuous vertical loops", State.DoubleLoop, function(v) State.DoubleLoop = v end)

-- TAB 4: PLAYER, CART & AUTOMATION
AddSection(PagePlayer, "Minecart Automation")
AddToggle(PagePlayer, "Auto Spawn Minecart", "Places new cart on the nearest rail", State.AutoSpawnCart, function(v) State.AutoSpawnCart = v end)
AddToggle(PagePlayer, "Auto Mount / Ride Cart", "Continuously sits in nearest cart seat", State.AutoRideCart, function(v) State.AutoRideCart = v end)
AddToggle(PagePlayer, "Cart Velocity Booster", "Enforces maximum speed and forward torque", State.BoostCartSpeed, function(v) State.BoostCartSpeed = v end)
AddSlider(PagePlayer, "Cart Speed Multiplier", 1, 5, 2, function(v) State.CartSpeedMultiplier = v end)

AddSection(PagePlayer, "Automated Rewards")
AddToggle(PagePlayer, "Auto Claim Daily Login", "Redeems daily rewards every 15s", State.AutoClaimDaily, function(v) State.AutoClaimDaily = v end)
AddToggle(PagePlayer, "Auto Claim Playtime Cash", "Collects free gift box money automatically", State.AutoClaimRewards, function(v) State.AutoClaimRewards = v end)

AddSection(PagePlayer, "Movement & Hacks")
AddToggle(PagePlayer, "Speed Hack", "Overrides humanoid walk speed", State.SpeedHack, function(v) State.SpeedHack = v end)
AddSlider(PagePlayer, "WalkSpeed", 16, 200, 32, function(v) State.WalkSpeed = v end)

AddToggle(PagePlayer, "Infinite Jump", "Jump repeatedly mid-air", State.InfiniteJump, function(v) State.InfiniteJump = v end)
AddToggle(PagePlayer, "Noclip", "Walk through all blocks and structures", State.Noclip, function(v) State.Noclip = v end)
AddToggle(PagePlayer, "Smooth Fly", "Fly using WASD + Space/Shift keys", State.Fly, function(v) State.Fly = v; toggleFly(v) end)
AddSlider(PagePlayer, "Fly Speed", 20, 200, 50, function(v) State.FlySpeed = v end)
AddToggle(PagePlayer, "24/7 Anti-AFK", "Prevents 20-minute idle disconnects", State.AntiAFK, function(v) State.AntiAFK = v end)

-- Live Status updater
task.spawn(function()
    while State.Running do
        FtrL.Text = "Status: " .. tostring(State.Status)
        task.wait(0.25)
    end
end)

print("[AUTO BUILD] Voxel Coaster Automation Engine Loaded Successfully!")
