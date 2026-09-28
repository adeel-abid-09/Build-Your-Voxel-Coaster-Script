--[[
    ========================================================================
    VOXEL COASTER | AUTO BUILDER & AUTOMATION ENGINE
    ========================================================================
    Game: Build Your Voxel Coaster
    Optimized for: Delta, Fluxus, Arceus X, Codex, Solara, Wave, PC
    Theme: Pure Midnight Black & Clean Crisp White (Monochrome Pro UI)
    Layout: Portrait with Dynamic Scale and Corner Resize Grip
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
    
    -- Main Coaster Farm Toggles
    MasterCoasterFarm = false,     -- Builds Hill + 2 Loops, Spawns Cart, Auto Rides & Farms Infinite Cash
    BuildStuntTrack = false,       -- Hill Ramp, Drop and 2 Loops
    AutoRideCart = false,          -- Sits in cart and drives continuously
    BoostCartSpeed = true,         -- High speed booster on cart
    CartSpeedMultiplier = 3,
    
    -- Other Builders (Toggles)
    BuildCircuit = false,          -- Oval Circuit
    BuildSpiral = false,           -- Sky Spiral
    BuildRunway = false,           -- Straight Launch Runway
    AutoRailPath = false,          -- Live path follower as you move
    BuildPlatform = false,         -- 10x10 Platform
    BuildMegaPlatform = false,     -- 20x20 Platform
    BuildSkyPillar = false,        -- Pillar to sky
    AutoClearBlocks = false,       -- Demolish all placed blocks
    
    -- Stunts
    LoopRail = false,
    MonsterLoop = false,
    MegaDrop = false,
    DoubleLoop = false,
    
    -- Economy
    AutoClaimRewards = true,       -- Free playtime cash gifts (top right box)
    AutoClaimDaily = true,         -- Daily login reward
    
    -- Movement
    SpeedHack = false,
    WalkSpeed = 32,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
    AntiAFK = true,
    
    -- Configuration
    BuildSpeed = 0.04,
    SelectedBlockType = "Oak Wood Plank",
    SelectedRailType = "Rail",
    Status = "Ready"
}

-- ========================================================================
-- MONOCHROME THEME (PURE BLACK & CRISP WHITE)
-- ========================================================================
local Theme = {
    BG          = Color3.fromRGB(12, 12, 12),
    Header      = Color3.fromRGB(18, 18, 18),
    ItemBg      = Color3.fromRGB(22, 22, 22),
    ItemHover   = Color3.fromRGB(30, 30, 30),
    Border      = Color3.fromRGB(44, 44, 44),
    BorderLight = Color3.fromRGB(70, 70, 70),
    White       = Color3.fromRGB(255, 255, 255),
    Muted       = Color3.fromRGB(160, 160, 160),
    DarkMuted   = Color3.fromRGB(100, 100, 100),
    ToggleOFF   = Color3.fromRGB(28, 28, 28),
    ToggleON    = Color3.fromRGB(255, 255, 255),
    Red         = Color3.fromRGB(230, 60, 60),
    FontB       = Enum.Font.GothamBold,
    FontR       = Enum.Font.GothamMedium,
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

-- Universal Block Placement Dispatcher
local function placeVoxelBlock(cell, blockName, rot)
    rot = rot or 0
    if not PlaceBlockRemote then return false end
    
    local tool = equipTool(blockName)
    
    pcall(function() PlaceBlockRemote:FireServer(cell, rot) end)
    pcall(function() PlaceBlockRemote:FireServer(cell, blockName, rot) end)
    pcall(function() PlaceBlockRemote:FireServer(cell, rot, blockName) end)
    pcall(function() PlaceBlockRemote:FireServer(cell, rot, Vector3.new(0, 0, 1)) end)
    
    if tool and tool:FindFirstChild("Handle") then
        pcall(function() tool:Activate() end)
    end
    return true
end

-- Stunt Placement Dispatcher
local function placeStunt(cell, kind, r, dir)
    if not PlaceLoopRemote then return false end
    r = r or 6
    dir = dir or Vector3.new(0, 0, 1)
    pcall(function() PlaceLoopRemote:FireServer(cell, kind, 0, r, dir) end)
    pcall(function()
        if PlaceTemplateRemote then
            PlaceTemplateRemote:FireServer(kind, cell, 0)
        end
    end)
    return true
end

-- Spawn & Mount Cart
local function spawnCart(cell)
    if not PlaceCartRemote then return end
    equipTool("Minecart")
    pcall(function() PlaceCartRemote:FireServer(cell) end)
end

local function mountNearestCart()
    local root = getRootPart()
    if not root then return end
    local nearest = nil
    local minDist = 60
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
        if hum then nearest:Sit(hum) end
    end
end

-- ========================================================================
-- EXACT STUNT COASTER ENGINE (HILL RAMP + DROP + 2 LOOPS + RETURN CIRCUIT)
-- ========================================================================
local function buildStuntHillAndLoops()
    local root = getRootPart()
    if not root then return nil end
    
    local startCell = worldToCell(root.Position)
    local curY = math.max(1, startCell.Y)
    local lookDir = root.CFrame.LookVector
    local dirX = math.abs(lookDir.X) > math.abs(lookDir.Z) and (lookDir.X > 0 and 1 or -1) or 0
    local dirZ = dirX == 0 and (lookDir.Z > 0 and 1 or -1) or 0
    
    State.Status = "Laying Launch Runway..."
    -- 1. Start Launch Platform & Powered Rails
    for i = 1, 4 do
        local c = Vector3.new(startCell.X + (dirX * i), curY, startCell.Z + (dirZ * i))
        placeVoxelBlock(Vector3.new(c.X, c.Y - 1, c.Z), "Oak Wood Plank", 0)
        placeVoxelBlock(c, "Powered Rail - Active", 0)
        task.wait(State.BuildSpeed)
    end
    
    State.Status = "Building Hill Incline (Chainlift)..."
    -- 2. Ascending Hill Ramp with Chainlift Rails (4 Blocks High)
    local hillStart = 4
    for h = 1, 4 do
        local c = Vector3.new(startCell.X + (dirX * (hillStart + h)), curY + h, startCell.Z + (dirZ * (hillStart + h)))
        for sy = 0, h do
            placeVoxelBlock(Vector3.new(c.X, curY - 1 + sy, c.Z), "Oak Wood Plank", 0)
        end
        placeVoxelBlock(c, "Chainlift Rail", 0)
        task.wait(State.BuildSpeed)
    end
    
    State.Status = "Building Steep Drop..."
    -- 3. Hill Peak & Drop Back Down
    local dropStart = hillStart + 4
    for h = 1, 4 do
        local c = Vector3.new(startCell.X + (dirX * (dropStart + h)), curY + (4 - h), startCell.Z + (dirZ * (dropStart + h)))
        for sy = 0, (4 - h) do
            placeVoxelBlock(Vector3.new(c.X, curY - 1 + sy, c.Z), "Oak Wood Plank", 0)
        end
        placeVoxelBlock(c, "Powered Rail - Active", 0)
        task.wait(State.BuildSpeed)
    end
    
    State.Status = "Placing Stunt Loops..."
    -- 4. Transition Flat Track
    local loopStart = dropStart + 5
    for i = 0, 2 do
        local c = Vector3.new(startCell.X + (dirX * (loopStart + i)), curY, startCell.Z + (dirZ * (loopStart + i)))
        placeVoxelBlock(Vector3.new(c.X, c.Y - 1, c.Z), "Stone Bricks", 0)
        placeVoxelBlock(c, "Powered Rail - Active", 0)
        task.wait(State.BuildSpeed)
    end
    
    -- 5. Stunt Element 1: Vertical Loop
    local loop1Cell = Vector3.new(startCell.X + (dirX * (loopStart + 3)), curY, startCell.Z + (dirZ * (loopStart + 3)))
    placeStunt(loop1Cell, "loop", 6, Vector3.new(dirX, 0, dirZ))
    task.wait(0.25)
    
    -- 6. Stunt Element 2: Second Vertical Loop
    local loop2Cell = Vector3.new(startCell.X + (dirX * (loopStart + 7)), curY, startCell.Z + (dirZ * (loopStart + 7)))
    placeStunt(loop2Cell, "loop", 6, Vector3.new(dirX, 0, dirZ))
    task.wait(0.25)
    
    State.Status = "Connecting Return Circuit..."
    -- 7. Return Loop back to start so cart runs indefinitely
    local returnStart = loopStart + 11
    local width = 8
    local sideX = -dirZ
    local sideZ = dirX
    
    -- Curve Turn
    for w = 0, width do
        local c = Vector3.new(startCell.X + (dirX * returnStart) + (sideX * w), curY, startCell.Z + (dirZ * returnStart) + (sideZ * w))
        placeVoxelBlock(Vector3.new(c.X, c.Y - 1, c.Z), "Oak Wood Plank", 0)
        placeVoxelBlock(c, "Powered Rail - Active", 0)
        task.wait(State.BuildSpeed)
    end
    
    -- Return Straight Run
    for i = returnStart, 1, -1 do
        local c = Vector3.new(startCell.X + (dirX * i) + (sideX * width), curY, startCell.Z + (dirZ * i) + (sideZ * width))
        placeVoxelBlock(Vector3.new(c.X, c.Y - 1, c.Z), "Oak Wood Plank", 0)
        placeVoxelBlock(c, (i % 3 == 0) and "Powered Rail - Active" or "Rail", 0)
        task.wait(State.BuildSpeed)
    end
    
    -- Connect back to launch pad
    for w = width, 0, -1 do
        local c = Vector3.new(startCell.X + (sideX * w), curY, startCell.Z + (sideZ * w))
        placeVoxelBlock(Vector3.new(c.X, c.Y - 1, c.Z), "Oak Wood Plank", 0)
        placeVoxelBlock(c, "Powered Rail - Active", 0)
        task.wait(State.BuildSpeed)
    end
    
    return Vector3.new(startCell.X + (dirX * 2), curY, startCell.Z + (dirZ * 2))
end

-- ========================================================================
-- MASTER COASTER FARM RUNNER (BUILD + RIDE + INFINITE CASH)
-- ========================================================================
task.spawn(function()
    while State.Running do
        if State.MasterCoasterFarm then
            local cartSpawnCell = buildStuntHillAndLoops()
            task.wait(0.5)
            
            State.Status = "Spawning Minecart..."
            if cartSpawnCell then
                spawnCart(cartSpawnCell)
            else
                local root = getRootPart()
                if root then spawnCart(worldToCell(root.Position)) end
            end
            task.wait(0.8)
            
            State.Status = "Mounting Cart..."
            mountNearestCart()
            
            while State.MasterCoasterFarm and State.Running do
                local hum = getHumanoid()
                if hum and not hum.SeatPart then
                    mountNearestCart()
                end
                State.Status = "Farming Thrill Cash & Loops!"
                task.wait(2)
            end
        end
        task.wait(0.5)
    end
end)

-- Dedicated Stunt Coaster Builder
task.spawn(function()
    while State.Running do
        if State.BuildStuntTrack then
            buildStuntHillAndLoops()
            State.Status = "Stunt Coaster Ready!"
            State.BuildStuntTrack = false
        end
        task.wait(0.3)
    end
end)

-- Other Track Builders
task.spawn(function()
    while State.Running do
        if State.BuildCircuit then
            State.Status = "Building Oval Circuit..."
            local root = getRootPart()
            if root then
                local center = worldToCell(root.Position)
                local rX, rZ = 12, 7
                local y = math.max(1, center.Y + 1)
                
                local cells = {}
                for x = -rX, rX do
                    table.insert(cells, {c = Vector3.new(center.X + x, y, center.Z - rZ), rot = 0, p = (math.abs(x) % 3 == 0)})
                    table.insert(cells, {c = Vector3.new(center.X + x, y, center.Z + rZ), rot = 2, p = (math.abs(x) % 3 == 0)})
                end
                for z = -rZ + 1, rZ - 1 do
                    table.insert(cells, {c = Vector3.new(center.X + rX, y, center.Z + z), rot = 1, p = (math.abs(z) % 3 == 0)})
                    table.insert(cells, {c = Vector3.new(center.X - rX, y, center.Z + z), rot = 3, p = (math.abs(z) % 3 == 0)})
                end
                for _, pt in ipairs(cells) do
                    if not State.BuildCircuit then break end
                    placeVoxelBlock(Vector3.new(pt.c.X, pt.c.Y - 1, pt.c.Z), "Oak Wood Plank", 0)
                    placeVoxelBlock(pt.c, pt.p and "Powered Rail - Active" or "Rail", pt.rot)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildCircuit = false
            State.Status = "Circuit Complete!"
        end
        
        if State.BuildSpiral then
            State.Status = "Building Sky Spiral..."
            local root = getRootPart()
            if root then
                local center = worldToCell(root.Position)
                local rad, levels = 5, 8
                local angle = 0
                for i = 1, levels * 8 do
                    if not State.BuildSpiral then break end
                    local cx = center.X + math.round(math.cos(angle) * rad)
                    local cz = center.Z + math.round(math.sin(angle) * rad)
                    local curY = math.max(1, center.Y + math.floor(i / 2))
                    placeVoxelBlock(Vector3.new(cx, curY - 1, cz), "Oak Wood Plank", 0)
                    placeVoxelBlock(Vector3.new(cx, curY, cz), "Chainlift Rail", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    angle = angle + (math.pi / 4)
                end
            end
            State.BuildSpiral = false
            State.Status = "Sky Spiral Complete!"
        end
        
        if State.BuildRunway then
            State.Status = "Building Speed Runway..."
            local root = getRootPart()
            if root then
                local start = worldToCell(root.Position)
                local look = root.CFrame.LookVector
                local dx = math.abs(look.X) > math.abs(look.Z) and (look.X > 0 and 1 or -1) or 0
                local dz = dx == 0 and (look.Z > 0 and 1 or -1) or 0
                local curY = math.max(1, start.Y)
                for i = 1, 25 do
                    if not State.BuildRunway then break end
                    local c = Vector3.new(start.X + (dx * i), curY, start.Z + (dz * i))
                    placeVoxelBlock(Vector3.new(c.X, c.Y - 1, c.Z), "Stone Bricks", 0)
                    placeVoxelBlock(c, (i % 2 == 0) and "Launch Rail" or "Powered Rail - Active", 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildRunway = false
            State.Status = "Runway Complete!"
        end
        
        if State.AutoRailPath then
            local root = getRootPart()
            if root then
                local cur = worldToCell(root.Position)
                placeVoxelBlock(Vector3.new(cur.X, cur.Y - 1, cur.Z), State.SelectedBlockType, 0)
                placeVoxelBlock(Vector3.new(cur.X, cur.Y, cur.Z), State.SelectedRailType, 0)
            end
            task.wait(0.18)
        else
            task.wait(0.3)
        end
    end
end)

-- Platforms and Pillars
task.spawn(function()
    while State.Running do
        if State.BuildPlatform then
            local root = getRootPart()
            if root then
                local center = worldToCell(root.Position)
                local y = math.max(0, center.Y - 1)
                for x = -5, 5 do
                    for z = -5, 5 do
                        if not State.BuildPlatform then break end
                        placeVoxelBlock(Vector3.new(center.X + x, y, center.Z + z), State.SelectedBlockType, 0)
                        if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    end
                end
            end
            State.BuildPlatform = false
            State.Status = "Platform (10x10) Built!"
        end
        if State.BuildMegaPlatform then
            local root = getRootPart()
            if root then
                local center = worldToCell(root.Position)
                local y = math.max(0, center.Y - 1)
                for x = -10, 10 do
                    for z = -10, 10 do
                        if not State.BuildMegaPlatform then break end
                        placeVoxelBlock(Vector3.new(center.X + x, y, center.Z + z), State.SelectedBlockType, 0)
                        if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                    end
                end
            end
            State.BuildMegaPlatform = false
            State.Status = "Platform (20x20) Built!"
        end
        if State.BuildSkyPillar then
            local root = getRootPart()
            if root then
                local center = worldToCell(root.Position)
                for y = 0, 25 do
                    if not State.BuildSkyPillar then break end
                    placeVoxelBlock(Vector3.new(center.X, center.Y + y, center.Z), State.SelectedBlockType, 0)
                    if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
                end
            end
            State.BuildSkyPillar = false
            State.Status = "Sky Pillar Built!"
        end
        if State.AutoClearBlocks then
            if ClearAllRemote then
                pcall(function() ClearAllRemote:FireServer() end)
                State.Status = "Cleared Placed Blocks"
            end
            State.AutoClearBlocks = false
        end
        task.wait(0.3)
    end
end)

-- Stunt Presets
task.spawn(function()
    while State.Running do
        local root = getRootPart()
        if root then
            local frontCell = worldToCell(root.Position + root.CFrame.LookVector * 10)
            if State.LoopRail then placeStunt(frontCell, "loop", 6); State.LoopRail = false end
            if State.MonsterLoop then placeStunt(frontCell, "loop", 16); State.MonsterLoop = false end
            if State.MegaDrop then placeStunt(frontCell, "megadrop", 6); State.MegaDrop = false end
            if State.DoubleLoop then placeStunt(frontCell, "loop", 6); task.wait(0.2); placeStunt(worldToCell(root.Position + root.CFrame.LookVector * 16), "loop", 6); State.DoubleLoop = false end
        end
        task.wait(0.3)
    end
end)

-- Minecart & Cash Booster
task.spawn(function()
    while State.Running do
        if State.AutoRideCart then
            mountNearestCart()
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

-- Player Movement Hacks
RunService.RenderStepped:Connect(function()
    local hum = getHumanoid()
    if hum then
        if State.SpeedHack and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
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

-- Smooth Fly
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
        flyBV.Velocity = moveDir.Magnitude > 0 and (moveDir.Unit * State.FlySpeed) or Vector3.zero
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
-- CLEAN PORTRAIT USER INTERFACE (NO CONFUSING MINIMIZE - ALWAYS VISIBLE)
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

local Main = Instance.new("Frame", ScreenGui)
Main.Name = "MainPanel"
Main.Size = UDim2.new(0, curW, 0, curH)
Main.Position = UDim2.new(0.5, -135, 0.35, 0)
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
Ttl.Size = UDim2.new(1, -90, 1, 0)
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
ScaleMinus.Position = UDim2.new(1, -76, 0.5, -10)
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
ScalePlus.Position = UDim2.new(1, -52, 0.5, -10)
ScalePlus.BackgroundColor3 = Theme.ItemBg
ScalePlus.Text = "+"
ScalePlus.Font = Theme.FontB
ScalePlus.TextColor3 = Theme.White
ScalePlus.TextSize = 13
ScalePlus.AutoButtonColor = false
ScalePlus.ZIndex = 12
Instance.new("UICorner", ScalePlus).CornerRadius = UDim.new(0, 4)

-- Close Button (X)
local XBtn = Instance.new("TextButton", Hdr)
XBtn.Size = UDim2.new(0, 20, 0, 20)
XBtn.Position = UDim2.new(1, -26, 0.5, -10)
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

makeDraggable(Main, Hdr)
FloatBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

XBtn.MouseButton1Click:Connect(function() Main.Visible = false end)
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
        curW = math.clamp(rStartSize.X + delta.X, 220, 480)
        curH = math.clamp(rStartSize.Y + delta.Y, 260, 650)
        Main.Size = UDim2.new(0, curW, 0, curH)
    end
end)

-- ========================================================================
-- CATEGORY SYSTEM & UI HELPERS (STRICT TOGGLES ONLY)
-- ========================================================================
local CategoryPages = {}
local CategoryButtons = {}

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

-- Helper: Pure ON/OFF Toggle Card
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

-- ========================================================================
-- POPULATE CATEGORIES (STRICT ZERO EXECUTE BUTTONS - ALL TOGGLES)
-- ========================================================================

-- TAB 1: TRACKS (FEATURED COASTERS & STUNT CIRCUITS)
AddSection(PageTracks, "Master Automation")
AddToggle(PageTracks, "Auto Farm Coaster (All-in-One)", "Builds Hill+Loops, rides cart & farms cash", State.MasterCoasterFarm, function(v)
    State.MasterCoasterFarm = v
end)

AddSection(PageTracks, "Stunt Coasters")
AddToggle(PageTracks, "Build Stunt Track (Hill + 2 Loops)", "Constructs exact hill ramp & double loop", State.BuildStuntTrack, function(v)
    State.BuildStuntTrack = v
end)

AddToggle(PageTracks, "Build Closed Coaster Loop", "Constructs a full high-speed loop circuit", State.BuildCircuit, function(v)
    State.BuildCircuit = v
end)

AddToggle(PageTracks, "Build Sky Spiral Tower", "8-point spiraling coaster with chainlift", State.BuildSpiral, function(v)
    State.BuildSpiral = v
end)

AddToggle(PageTracks, "Build Speed Runway", "Straight boosted launch track", State.BuildRunway, function(v)
    State.BuildRunway = v
end)

AddToggle(PageTracks, "Auto Rail Walk/Fly Follower", "Lays rails directly in front as you move", State.AutoRailPath, function(v)
    State.AutoRailPath = v
end)

-- TAB 2: BUILDS (STRUCTURES & FOUNDATIONS)
AddSection(PageStructures, "Voxel Platforms and Towers")
AddToggle(PageStructures, "Build Platform (10x10)", "Generates a clean voxel floor under feet", State.BuildPlatform, function(v)
    State.BuildPlatform = v
end)

AddToggle(PageStructures, "Build Platform (20x20)", "Large foundation for big coaster designs", State.BuildMegaPlatform, function(v)
    State.BuildMegaPlatform = v
end)

AddToggle(PageStructures, "Build Sky Pillar", "Pillar straight up to the build height", State.BuildSkyPillar, function(v)
    State.BuildSkyPillar = v
end)

AddToggle(PageStructures, "Clear All Placed Blocks", "Demolishes all user-placed blocks on plot", State.AutoClearBlocks, function(v)
    State.AutoClearBlocks = v
end)

-- TAB 3: LOOPS (STUNT TRACK PRESETS)
AddSection(PageStunts, "Instant Stunt Elements")
AddToggle(PageStunts, "Place Double Loop", "Twin continuous vertical loops (as in pic)", State.DoubleLoop, function(v) State.DoubleLoop = v end)
AddToggle(PageStunts, "Place Loop Rail", "Vertical loop at front cell", State.LoopRail, function(v) State.LoopRail = v end)
AddToggle(PageStunts, "Place Monster Loop", "Gigantic 16-stud radius stunt loop", State.MonsterLoop, function(v) State.MonsterLoop = v end)
AddToggle(PageStunts, "Place Mega Drop", "Steep high vertical drop track", State.MegaDrop, function(v) State.MegaDrop = v end)

-- TAB 4: PLAYER, CART & AUTOMATION
AddSection(PagePlayer, "Minecart Automation")
AddToggle(PagePlayer, "Auto Ride & Farm Cash", "Mounts cart and drives infinite loops", State.AutoRideCart, function(v) State.AutoRideCart = v end)
AddToggle(PagePlayer, "Cart Speed Booster", "Enforces maximum speed and torque", State.BoostCartSpeed, function(v) State.BoostCartSpeed = v end)

AddSection(PagePlayer, "Automated Rewards")
AddToggle(PagePlayer, "Auto Claim Time Gifts ($130k+)", "Redeems all 12 playtime gifts automatically", State.AutoClaimRewards, function(v) State.AutoClaimRewards = v end)
AddToggle(PagePlayer, "Auto Claim Daily Login", "Redeems daily rewards every 15s", State.AutoClaimDaily, function(v) State.AutoClaimDaily = v end)

AddSection(PagePlayer, "Movement & Hacks")
AddToggle(PagePlayer, "Speed Hack", "Fast walkspeed boost", State.SpeedHack, function(v) State.SpeedHack = v end)
AddToggle(PagePlayer, "Infinite Jump", "Jump repeatedly mid-air", State.InfiniteJump, function(v) State.InfiniteJump = v end)
AddToggle(PagePlayer, "Noclip", "Walk through all blocks and structures", State.Noclip, function(v) State.Noclip = v end)
AddToggle(PagePlayer, "Smooth Fly", "Fly using WASD + Space/Shift keys", State.Fly, function(v) State.Fly = v; toggleFly(v) end)
AddToggle(PagePlayer, "24/7 Anti-AFK", "Prevents 20-minute idle disconnects", State.AntiAFK, function(v) State.AntiAFK = v end)

-- Live Status updater
task.spawn(function()
    while State.Running do
        FtrL.Text = "Status: " .. tostring(State.Status)
        task.wait(0.25)
    end
end)

print("[AUTO BUILD] Voxel Coaster Automation Engine Loaded Successfully!")
