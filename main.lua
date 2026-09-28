--[[
    ========================================================================
    VOXEL COASTER | ADVANCED AUTO BUILDER & AUTOMATION ENGINE
    ========================================================================
    Game: Build Your Voxel Coaster
    Optimized for: Delta, Fluxus, Arceus X, Codex, Solara, Wave, Synapse, PC
    Theme: Pure Midnight Black & Clean Crisp White (Monochrome Pro UI)
    
    CORE FEATURES:
    1. Auto Build Coasters: Closed Circuit Loop, Sky Spiral, Mega Drop, Runway
    2. Live Rail Follow: Automatically lays rails in front of you as you walk/fly
    3. Auto Build Structures: Flat Platforms (10x10 to 50x50), Towers, Pillars
    4. Preset Spawner: Loop Rail, Monster Loop, Giant Drop, Corkscrew, Airtime Hills
    5. Auto Cart Manager: Spawn Cart, Auto Mount/Ride, Cart Speed Boost
    6. Auto Rewards: Daily Claim, Free Cash, Playtime Rewards
    7. Movement: Smooth Fly, Noclip, WalkSpeed, Infinite Jump, 24/7 Anti-AFK
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

-- Available Blocks List
local AvailableBlocks = {
    "Oak Wood Plank",
    "Rail",
    "Powered Rail - Active",
    "Chainlift Rail",
    "Launch Rail",
    "Cobblestone",
    "Stone Bricks",
    "Glass",
    "Block of Diamond",
    "Block of Gold",
    "Block of Iron",
    "Obsidian",
    "White Wool",
    "Black Wool",
    "Red Wool",
    "TNT"
}

if BlocksFolder then
    local collected = {}
    for _, b in ipairs(BlocksFolder:GetChildren()) do
        if b:IsA("BasePart") or b:IsA("Model") then
            table.insert(collected, b.Name)
        end
    end
    if #collected > 0 then
        table.sort(collected)
        AvailableBlocks = collected
    end
end

-- ========================================================================
-- RUNTIME STATE
-- ========================================================================
local State = {
    Running = true,
    
    -- Auto Build
    AutoRailPath = false,
    SelectedRailType = "Rail",
    SelectedBlockType = "Oak Wood Plank",
    BuildSpeed = 0.05, -- Delay between blocks
    PlatformSize = 10,
    TowerHeight = 20,
    IsBuilding = false,
    
    -- Cart & Ride
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
    
    -- Status
    Status = "Ready"
}

-- ========================================================================
-- MONOCHROME BLACK & WHITE THEME
-- ========================================================================
local Theme = {
    BgDark     = Color3.fromRGB(12, 12, 12),      -- Main Window Background
    BgCard     = Color3.fromRGB(20, 20, 20),      -- Component Container Background
    BgInput    = Color3.fromRGB(28, 28, 28),      -- Buttons / Fields Background
    BgHover    = Color3.fromRGB(38, 38, 38),      -- Button Hover
    Border     = Color3.fromRGB(48, 48, 48),      -- Outlines & Dividers
    BorderLight= Color3.fromRGB(75, 75, 75),      -- Highlight Outlines
    White      = Color3.fromRGB(255, 255, 255),  -- Active Text & Highlights
    Muted      = Color3.fromRGB(170, 170, 170),  -- Subtitles & Labels
    DarkMuted  = Color3.fromRGB(110, 110, 110),  -- Inactive Text
    Accent     = Color3.fromRGB(255, 255, 255),  -- Monochrome Accent (White)
    AccentDark = Color3.fromRGB(14, 14, 14)       -- Text on Accent
}

-- ========================================================================
-- UTILITY FUNCTIONS
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

-- Convert Grid Cell to World Position
local function cellToWorld(cell, isRail)
    local yOffset = isRail and 0.1 or 2
    return Vector3.new(
        cell.X * 4 + 2,
        cell.Y * 4 + yOffset,
        cell.Z * 4 + 2
    )
end

-- Safe Tool Equipper
local function equipTool(toolName)
    local char = getCharacter()
    if not char then return nil end
    local equipped = char:FindFirstChild(toolName)
    if equipped then return equipped end
    
    local inBackpack = LocalPlayer.Backpack:FindFirstChild(toolName)
    if inBackpack then
        inBackpack.Parent = char
        task.wait(0.08)
        return inBackpack
    end
    return nil
end

-- Universal Block Placement Dispatcher
local function placeVoxelBlock(cell, blockName, rot)
    rot = rot or 0
    if not PlaceBlockRemote then return false end
    
    -- Ensure appropriate tool is equipped if possible
    equipTool(blockName)
    
    -- Fire with safety checks for various server implementations
    local success = pcall(function()
        PlaceBlockRemote:FireServer(cell, blockName, rot)
    end)
    
    if not success then
        pcall(function()
            PlaceBlockRemote:FireServer(cell, rot, blockName)
        end)
    end
    return true
end

-- Break Block Dispatcher
local function breakVoxelBlock(cell)
    if not BreakBlockRemote then return false end
    equipTool("Pickaxe")
    local success = pcall(function()
        BreakBlockRemote:FireServer(cell)
    end)
    return success
end

-- ========================================================================
-- AUTO BUILD ENGINE PRESETS
-- ========================================================================

-- 1. Complete Oval Coaster Circuit (Closed Loop with Power Boosters)
local function buildCoasterCircuit(radiusX, radiusZ)
    if State.IsBuilding then return end
    State.IsBuilding = true
    State.Status = "Building Coaster Circuit..."
    
    task.spawn(function()
        local root = getRootPart()
        if not root then State.IsBuilding = false return end
        
        local centerCell = worldToCell(root.Position + Vector3.new(0, 0, 0))
        local rX = radiusX or 8
        local rZ = radiusZ or 8
        local y = centerCell.Y
        
        local trackCells = {}
        
        -- Generate outer rounded rectangle circuit
        for x = -rX, rX do
            table.insert(trackCells, {cell = Vector3.new(centerCell.X + x, y, centerCell.Z - rZ), rot = 0, isPower = (math.abs(x) % 3 == 0)})
            table.insert(trackCells, {cell = Vector3.new(centerCell.X + x, y, centerCell.Z + rZ), rot = 2, isPower = (math.abs(x) % 3 == 0)})
        end
        for z = -rZ + 1, rZ - 1 do
            table.insert(trackCells, {cell = Vector3.new(centerCell.X + rX, y, centerCell.Z + z), rot = 1, isPower = (math.abs(z) % 3 == 0)})
            table.insert(trackCells, {cell = Vector3.new(centerCell.X - rX, y, centerCell.Z + z), rot = 3, isPower = (math.abs(z) % 3 == 0)})
        end
        
        -- Build foundational support under the tracks first
        for _, point in ipairs(trackCells) do
            local baseCell = Vector3.new(point.cell.X, point.cell.Y - 1, point.cell.Z)
            placeVoxelBlock(baseCell, "Oak Wood Plank", 0)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
        end
        
        -- Place rails over foundation
        for _, point in ipairs(trackCells) do
            local railName = point.isPower and "Powered Rail - Active" or "Rail"
            placeVoxelBlock(point.cell, railName, point.rot)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
        end
        
        State.IsBuilding = false
        State.Status = "Coaster Circuit Built!"
    end)
end

-- 2. Sky Spiral Tower Coaster
local function buildSpiralCoaster(heightLevels, radius)
    if State.IsBuilding then return end
    State.IsBuilding = true
    State.Status = "Building Spiral Coaster..."
    
    task.spawn(function()
        local root = getRootPart()
        if not root then State.IsBuilding = false return end
        
        local centerCell = worldToCell(root.Position)
        local rad = radius or 4
        local levels = heightLevels or 10
        
        local angle = 0
        local stepAngle = math.pi / 4 -- 8 steps per circle
        local currentY = centerCell.Y
        
        for i = 1, levels * 8 do
            local cx = centerCell.X + math.round(math.cos(angle) * rad)
            local cz = centerCell.Z + math.round(math.sin(angle) * rad)
            currentY = centerCell.Y + math.floor(i / 2)
            
            local cPos = Vector3.new(cx, currentY, cz)
            local pillarBase = Vector3.new(cx, currentY - 1, cz)
            
            -- Place pillar support
            placeVoxelBlock(pillarBase, "Oak Wood Plank", 0)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
            
            -- Place chainlift rail going up
            placeVoxelBlock(cPos, "Chainlift Rail", 0)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
            
            angle = angle + stepAngle
        end
        
        State.IsBuilding = false
        State.Status = "Spiral Coaster Built!"
    end)
end

-- 3. High-Speed Straight Runway
local function buildRunway(length)
    if State.IsBuilding then return end
    State.IsBuilding = true
    State.Status = "Building Speed Runway..."
    
    task.spawn(function()
        local root = getRootPart()
        if not root then State.IsBuilding = false return end
        
        local startCell = worldToCell(root.Position)
        local lookDir = root.CFrame.LookVector
        local dirX = math.abs(lookDir.X) > math.abs(lookDir.Z) and (lookDir.X > 0 and 1 or -1) or 0
        local dirZ = dirX == 0 and (lookDir.Z > 0 and 1 or -1) or 0
        
        local len = length or 25
        
        for i = 1, len do
            local curCell = Vector3.new(startCell.X + (dirX * i), startCell.Y, startCell.Z + (dirZ * i))
            local underCell = Vector3.new(curCell.X, curCell.Y - 1, curCell.Z)
            
            -- Base block
            placeVoxelBlock(underCell, "Stone Bricks", 0)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
            
            -- Launch / Powered rail
            local railName = (i % 2 == 0) and "Launch Rail" or "Powered Rail - Active"
            placeVoxelBlock(curCell, railName, 0)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
        end
        
        State.IsBuilding = false
        State.Status = "Runway Built!"
    end)
end

-- 4. Flat Floor / Platform Builder
local function buildPlatform(size, blockType)
    if State.IsBuilding then return end
    State.IsBuilding = true
    State.Status = "Building Platform (" .. tostring(size) .. "x" .. tostring(size) .. ")..."
    
    task.spawn(function()
        local root = getRootPart()
        if not root then State.IsBuilding = false return end
        
        local centerCell = worldToCell(root.Position)
        local half = math.floor(size / 2)
        local y = centerCell.Y - 1
        
        for x = -half, half do
            for z = -half, half do
                local targetCell = Vector3.new(centerCell.X + x, y, centerCell.Z + z)
                placeVoxelBlock(targetCell, blockType or State.SelectedBlockType, 0)
                if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
            end
        end
        
        State.IsBuilding = false
        State.Status = "Platform Complete!"
    end)
end

-- 5. Sky Pillar / High Altitude Tower
local function buildPillar(height, blockType)
    if State.IsBuilding then return end
    State.IsBuilding = true
    State.Status = "Building Sky Pillar..."
    
    task.spawn(function()
        local root = getRootPart()
        if not root then State.IsBuilding = false return end
        
        local centerCell = worldToCell(root.Position)
        local h = height or 25
        
        for y = 0, h do
            local targetCell = Vector3.new(centerCell.X, centerCell.Y + y, centerCell.Z)
            placeVoxelBlock(targetCell, blockType or State.SelectedBlockType, 0)
            if State.BuildSpeed > 0 then task.wait(State.BuildSpeed) end
        end
        
        State.IsBuilding = false
        State.Status = "Sky Pillar Complete!"
    end)
end

-- 6. Live Path Follower (Lays rails or blocks in front of player while walking/flying)
task.spawn(function()
    while State.Running do
        if State.AutoRailPath and not State.IsBuilding then
            local root = getRootPart()
            if root then
                local currentCell = worldToCell(root.Position)
                local floorCell = Vector3.new(currentCell.X, currentCell.Y - 1, currentCell.Z)
                local trackCell = Vector3.new(currentCell.X, currentCell.Y, currentCell.Z)
                
                -- Put support block under if empty
                placeVoxelBlock(floorCell, State.SelectedBlockType, 0)
                -- Put rail on feet level
                placeVoxelBlock(trackCell, State.SelectedRailType, 0)
            end
        end
        task.wait(0.2)
    end
end)

-- ========================================================================
-- CART & RIDE AUTOMATION
-- ========================================================================
local function spawnCartOnNearestRail()
    if not PlaceCartRemote then return end
    local root = getRootPart()
    if not root then return end
    
    local char = getCharacter()
    equipTool("Minecart")
    
    local myCell = worldToCell(root.Position)
    pcall(function()
        PlaceCartRemote:FireServer(myCell)
    end)
    State.Status = "Spawned Minecart"
end

local function autoMountNearestCart()
    local root = getRootPart()
    if not root then return end
    
    local nearestCart = nil
    local minDist = 50
    
    local cartsFolder = Workspace:FindFirstChild("Minecarts") or Workspace
    for _, item in ipairs(cartsFolder:GetDescendants()) do
        if item:IsA("VehicleSeat") or (item:IsA("Seat") and item.Name:lower():find("cart")) then
            local dist = (item.Position - root.Position).Magnitude
            if dist < minDist and not item.Occupant then
                minDist = dist
                nearestCart = item
            end
        end
    end
    
    if nearestCart then
        local hum = getHumanoid()
        if hum then
            nearestCart:Sit(hum)
            State.Status = "Mounted Cart"
        end
    end
end

-- Cart Speed Booster Loop
task.spawn(function()
    while State.Running do
        if State.BoostCartSpeed then
            local hum = getHumanoid()
            if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
                local seat = hum.SeatPart
                seat.MaxSpeed = 100 * State.CartSpeedMultiplier
                seat.Torque = 500000
                local model = seat:FindFirstAncestorOfClass("Model")
                if model and model.PrimaryPart then
                    model.PrimaryPart.AssemblyLinearVelocity = model.PrimaryPart.CFrame.LookVector * (60 * State.CartSpeedMultiplier)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Auto Rewards & Daily Claim Loop
task.spawn(function()
    while State.Running do
        if State.AutoClaimDaily and DailyRemotes then
            local claimDaily = DailyRemotes:FindFirstChild("ClaimDaily")
            if claimDaily then
                pcall(function() claimDaily:FireServer() end)
            end
        end
        if State.AutoClaimRewards and RewardRemotes then
            local claimReward = RewardRemotes:FindFirstChild("ClaimReward")
            if claimReward then
                for i = 1, 12 do
                    pcall(function() claimReward:FireServer(i) end)
                    task.wait(0.1)
                end
            end
        end
        task.wait(15)
    end
end)

-- ========================================================================
-- PLAYER MOVEMENT HACKS (SPEED, NOCLIP, FLY, INF JUMP)
-- ========================================================================
local function applyPlayerStats()
    local hum = getHumanoid()
    if hum then
        if State.SpeedHack then
            hum.WalkSpeed = State.WalkSpeed
        end
        if State.JumpHack then
            hum.UseJumpPower = true
            hum.JumpPower = State.JumpPower
        end
    end
end

-- Continuous Speed & Jump Enforcement
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

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Noclip Loop
RunService.Stepped:Connect(function()
    if State.Noclip then
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
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
        flyBV.Name = "VCFlyBV"
        flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
        
        flyBG = Instance.new("BodyGyro")
        flyBG.Name = "VCFlyBG"
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
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end
        
        if moveDir.Magnitude > 0 then
            flyBV.Velocity = moveDir.Unit * State.FlySpeed
        else
            flyBV.Velocity = Vector3.zero
        end
        flyBG.CFrame = camCF
    end
end)

-- 24/7 Anti-AFK
LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

-- ========================================================================
-- MONOCHROME USER INTERFACE (PURE BLACK BOXES, CRISP WHITE TEXT)
-- ========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- Main Window Card
local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = UDim2.new(0, 500, 0, 390)
MainCard.Position = UDim2.new(0.5, -250, 0.5, -195)
MainCard.BackgroundColor3 = Theme.BgDark
MainCard.BorderSizePixel = 0
MainCard.ClipsDescendants = true
MainCard.Active = true
MainCard.Draggable = true
MainCard.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 10)
CardCorner.Parent = MainCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Theme.Border
CardStroke.Thickness = 1.5
CardStroke.Parent = MainCard

-- Header Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Theme.BgCard
Header.BorderSizePixel = 0
Header.Parent = MainCard

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderDivider = Instance.new("Frame")
HeaderDivider.Size = UDim2.new(1, 0, 0, 1)
HeaderDivider.Position = UDim2.new(0, 0, 1, -1)
HeaderDivider.BackgroundColor3 = Theme.Border
HeaderDivider.BorderSizePixel = 0
HeaderDivider.Parent = Header

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Name = "Title"
TitleLbl.Size = UDim2.new(1, -90, 1, 0)
TitleLbl.Position = UDim2.new(0, 15, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.Text = "VOXEL COASTER  |  AUTO BUILD"
TitleLbl.TextColor3 = Theme.White
TitleLbl.TextSize = 14
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0, 8)
CloseBtn.BackgroundColor3 = Theme.BgInput
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.White
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

local CloseStroke = Instance.new("UIStroke")
CloseStroke.Color = Theme.Border
CloseStroke.Thickness = 1
CloseStroke.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = not ScreenGui.Enabled
end)

-- Mobile Floating Re-Open Button
local OpenGui = Instance.new("ScreenGui")
OpenGui.Name = TOGGLE_NAME
OpenGui.ResetOnSpawn = false
OpenGui.Parent = parentGui

local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "OpenButton"
FloatBtn.Size = UDim2.new(0, 105, 0, 34)
FloatBtn.Position = UDim2.new(0, 15, 0.5, -17)
FloatBtn.BackgroundColor3 = Theme.BgDark
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.Text = "AUTO BUILD"
FloatBtn.TextColor3 = Theme.White
FloatBtn.TextSize = 12
FloatBtn.Active = true
FloatBtn.Draggable = true
FloatBtn.Parent = OpenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 8)
FloatCorner.Parent = FloatBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Theme.White
FloatStroke.Thickness = 1.2
FloatStroke.Parent = FloatBtn

FloatBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = not ScreenGui.Enabled
end)

-- Sidebar Tabs
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 130, 1, -46)
Sidebar.Position = UDim2.new(0, 0, 0, 46)
Sidebar.BackgroundColor3 = Theme.BgCard
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainCard

local SidebarDivider = Instance.new("Frame")
SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
SidebarDivider.Position = UDim2.new(1, -1, 0, 0)
SidebarDivider.BackgroundColor3 = Theme.Border
SidebarDivider.BorderSizePixel = 0
SidebarDivider.Parent = Sidebar

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 10)
SidebarPad.PaddingLeft = UDim.new(0, 8)
SidebarPad.PaddingRight = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

-- Content Container
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "Content"
ContentContainer.Size = UDim2.new(1, -140, 1, -54)
ContentContainer.Position = UDim2.new(0, 135, 0, 50)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainCard

local Tabs = {}
local TabButtons = {}

local function createTab(tabName, layoutOrder)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = tabName .. "Btn"
    tabBtn.Size = UDim2.new(1, 0, 0, 32)
    tabBtn.BackgroundColor3 = layoutOrder == 1 and Theme.BgInput or Theme.BgCard
    tabBtn.BorderSizePixel = 0
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.Text = tabName
    tabBtn.TextColor3 = layoutOrder == 1 and Theme.White or Theme.DarkMuted
    tabBtn.TextSize = 12
    tabBtn.LayoutOrder = layoutOrder
    tabBtn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = tabBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = layoutOrder == 1 and Theme.BorderLight or Theme.Border
    btnStroke.Thickness = 1
    btnStroke.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.White
    page.Visible = layoutOrder == 1
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = ContentContainer

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingTop = UDim.new(0, 4)
    pagePad.PaddingRight = UDim.new(0, 8)
    pagePad.PaddingBottom = UDim.new(0, 10)
    pagePad.Parent = page

    Tabs[tabName] = page
    TabButtons[tabName] = {btn = tabBtn, stroke = btnStroke}

    tabBtn.MouseButton1Click:Connect(function()
        for name, p in pairs(Tabs) do
            p.Visible = (name == tabName)
        end
        for name, item in pairs(TabButtons) do
            local active = (name == tabName)
            item.btn.BackgroundColor3 = active and Theme.BgInput or Theme.BgCard
            item.btn.TextColor3 = active and Theme.White or Theme.DarkMuted
            item.stroke.Color = active and Theme.BorderLight or Theme.Border
        end
    end)

    return page
end

-- Create Pages
local CoasterTab   = createTab("Coasters", 1)
local StructureTab = createTab("Structures", 2)
local PresetsTab   = createTab("Loops & Packs", 3)
local CartTab      = createTab("Minecart", 4)
local EconomyTab   = createTab("Rewards", 5)
local PlayerTab    = createTab("Player/Misc", 6)

-- ========================================================================
-- UI BUILDER HELPERS (BLACK & WHITE THEME)
-- ========================================================================

-- Helper: Section Header
local function createSection(parent, title)
    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 24)
    sec.BackgroundTransparency = 1
    sec.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = string.upper(title)
    lbl.TextColor3 = Theme.White
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = sec

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = Theme.Border
    line.BorderSizePixel = 0
    line.Parent = sec
end

-- Helper: Toggle
local function createToggle(parent, title, desc, defaultState, callback)
    local card = Instance.new("Frame")
    card.Name = title .. "Card"
    card.Size = UDim2.new(1, 0, 0, 46)
    card.BackgroundColor3 = Theme.BgCard
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Theme.Border
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -60, 0, 20)
    tLabel.Position = UDim2.new(0, 10, 0, 4)
    tLabel.BackgroundTransparency = 1
    tLabel.Font = Enum.Font.GothamBold
    tLabel.Text = title
    tLabel.TextColor3 = Theme.White
    tLabel.TextSize = 12
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = card

    local dLabel = Instance.new("TextLabel")
    dLabel.Size = UDim2.new(1, -60, 0, 16)
    dLabel.Position = UDim2.new(0, 10, 0, 24)
    dLabel.BackgroundTransparency = 1
    dLabel.Font = Enum.Font.Gotham
    dLabel.Text = desc
    dLabel.TextColor3 = Theme.Muted
    dLabel.TextSize = 10
    dLabel.TextXAlignment = Enum.TextXAlignment.Left
    dLabel.Parent = card

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "Toggle"
    toggleBtn.Size = UDim2.new(0, 40, 0, 22)
    toggleBtn.Position = UDim2.new(1, -48, 0.5, -11)
    toggleBtn.BackgroundColor3 = defaultState and Theme.White or Theme.BgInput
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = card

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Theme.BorderLight
    toggleStroke.Thickness = 1
    toggleStroke.Parent = toggleBtn

    local circle = Instance.new("Frame")
    circle.Name = "Circle"
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = defaultState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = defaultState and Theme.BgDark or Theme.White
    circle.BorderSizePixel = 0
    circle.Parent = toggleBtn

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle

    local active = defaultState

    local function updateState()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = active and Theme.White or Theme.BgInput
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {
            Position = active and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = active and Theme.BgDark or Theme.White
        }):Play()
    end

    toggleBtn.MouseButton1Click:Connect(function()
        active = not active
        updateState()
        callback(active)
    end)

    return {
        Set = function(val)
            active = val
            updateState()
            callback(active)
        end
    }
end

-- Helper: Action Button
local function createButton(parent, title, desc, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 46)
    card.BackgroundColor3 = Theme.BgCard
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Theme.Border
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -110, 0, 20)
    tLabel.Position = UDim2.new(0, 10, 0, 4)
    tLabel.BackgroundTransparency = 1
    tLabel.Font = Enum.Font.GothamBold
    tLabel.Text = title
    tLabel.TextColor3 = Theme.White
    tLabel.TextSize = 12
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = card

    local dLabel = Instance.new("TextLabel")
    dLabel.Size = UDim2.new(1, -110, 0, 16)
    dLabel.Position = UDim2.new(0, 10, 0, 24)
    dLabel.BackgroundTransparency = 1
    dLabel.Font = Enum.Font.Gotham
    dLabel.Text = desc
    dLabel.TextColor3 = Theme.Muted
    dLabel.TextSize = 10
    dLabel.TextXAlignment = Enum.TextXAlignment.Left
    dLabel.Parent = card

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 85, 0, 28)
    btn.Position = UDim2.new(1, -95, 0.5, -14)
    btn.BackgroundColor3 = Theme.BgInput
    btn.Font = Enum.Font.GothamBold
    btn.Text = "EXECUTE"
    btn.TextColor3 = Theme.White
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Theme.BorderLight
    btnStroke.Thickness = 1
    btnStroke.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgInput}):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        callback()
    end)
end

-- Helper: Slider
local function createSlider(parent, title, minVal, maxVal, defaultVal, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 52)
    card.BackgroundColor3 = Theme.BgCard
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Theme.Border
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -60, 0, 20)
    tLabel.Position = UDim2.new(0, 10, 0, 4)
    tLabel.BackgroundTransparency = 1
    tLabel.Font = Enum.Font.GothamBold
    tLabel.Text = title
    tLabel.TextColor3 = Theme.White
    tLabel.TextSize = 12
    tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = card

    local vLabel = Instance.new("TextLabel")
    vLabel.Size = UDim2.new(0, 45, 0, 20)
    vLabel.Position = UDim2.new(1, -55, 0, 4)
    vLabel.BackgroundTransparency = 1
    vLabel.Font = Enum.Font.GothamBold
    vLabel.Text = tostring(defaultVal)
    vLabel.TextColor3 = Theme.White
    vLabel.TextSize = 12
    vLabel.TextXAlignment = Enum.TextXAlignment.Right
    vLabel.Parent = card

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 34)
    bar.BackgroundColor3 = Theme.BgInput
    bar.BorderSizePixel = 0
    bar.Parent = card

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.White
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local sliding = false

    local function updateSlider(input)
        local posX = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.round(minVal + (maxVal - minVal) * posX)
        fill.Size = UDim2.new(posX, 0, 1, 0)
        vLabel.Text = tostring(val)
        callback(val)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
end

-- ========================================================================
-- POPULATE PAGES WITH FUNCTIONALITY
-- ========================================================================

-- 1. COASTERS TAB
createSection(CoasterTab, "Automatic Coaster Circuits")

createButton(CoasterTab, "Build Closed Coaster Circuit", "Builds a full loop with powered boost rails", function()
    buildCoasterCircuit(8, 8)
end)

createButton(CoasterTab, "Build Large Oval Circuit", "Extended 16x10 circuit with continuous speed", function()
    buildCoasterCircuit(16, 10)
end)

createButton(CoasterTab, "Build Sky Spiral Tower", "8-point spiraling coaster with chainlift climb", function()
    buildSpiralCoaster(10, 5)
end)

createButton(CoasterTab, "Build High-Speed Runway", "Straight track boosted with active launch rails", function()
    buildRunway(30)
end)

createSection(CoasterTab, "Continuous Live Path")

createToggle(CoasterTab, "Auto Rail Walk/Fly Follower", "Lays rails directly in front as you move", State.AutoRailPath, function(v)
    State.AutoRailPath = v
end)

createSlider(CoasterTab, "Block Placement Delay (ms)", 10, 200, 50, function(v)
    State.BuildSpeed = v / 1000
end)

-- 2. STRUCTURES TAB
createSection(StructureTab, "Voxel Foundations & Towers")

createButton(StructureTab, "Build Flat Platform (10x10)", "Generates a clean voxel floor under your feet", function()
    buildPlatform(10)
end)

createButton(StructureTab, "Build Mega Platform (20x20)", "Spacious building base for large coasters", function()
    buildPlatform(20)
end)

createButton(StructureTab, "Build Giant Platform (30x30)", "Massive foundation covering 900 voxel blocks", function()
    buildPlatform(30)
end)

createButton(StructureTab, "Build Sky Pillar (Height 25)", "Pillar reaching up into the high build limit", function()
    buildPillar(25)
end)

createButton(StructureTab, "Clear / Demolish All Blocks", "Fires server demolition on placed blocks", function()
    if ClearAllRemote then
        pcall(function() ClearAllRemote:FireServer() end)
        State.Status = "Cleared Blocks"
    end
end)

-- 3. PRESETS & LOOPS TAB
createSection(PresetsTab, "Instant Loop & Track Stunts")

local presetList = {
    {name = "Loop Rail", kind = "loop", r = 6},
    {name = "Monster Loop", kind = "loop", r = 16},
    {name = "Mega Drop", kind = "megadrop", r = 6},
    {name = "Corkscrew", kind = "corkscrew", r = 6},
    {name = "Giant Drop", kind = "giantdrop", r = 6},
    {name = "Cobra Roll", kind = "cobra", r = 6},
    {name = "Zero-G Roll", kind = "zerog", r = 6},
    {name = "Airtime Hills", kind = "airtime", r = 6},
    {name = "Double Loop", kind = "doubleloop", r = 6}
}

for _, p in ipairs(presetList) do
    createButton(PresetsTab, p.name, "Places stunt at current cell position", function()
        local root = getRootPart()
        if root and PlaceLoopRemote then
            local cell = worldToCell(root.Position + root.CFrame.LookVector * 12)
            pcall(function()
                PlaceLoopRemote:FireServer(cell, p.kind, 0, p.r, Vector3.new(0, 0, 1))
            end)
            State.Status = "Placed " .. p.name
        end
    end)
end

-- 4. MINECART TAB
createSection(CartTab, "Minecart Automation")

createButton(CartTab, "Spawn Minecart", "Places a new cart on the nearest track", function()
    spawnCartOnNearestRail()
end)

createButton(CartTab, "Auto Mount / Sit in Cart", "Teleports avatar directly into closest cart seat", function()
    autoMountNearestCart()
end)

createToggle(CartTab, "Cart Velocity Booster", "Enforces maximum torque and forward velocity", State.BoostCartSpeed, function(v)
    State.BoostCartSpeed = v
end)

createSlider(CartTab, "Cart Speed Multiplier", 1, 5, 2, function(v)
    State.CartSpeedMultiplier = v
end)

createButton(CartTab, "Remove / Despawn Carts", "Clears cart instances from the workspace", function()
    if RemoveCartRemote then
        pcall(function() RemoveCartRemote:FireServer() end)
        State.Status = "Removed Carts"
    end
end)

-- 5. REWARDS TAB
createSection(EconomyTab, "Automated Rewards")

createToggle(EconomyTab, "Auto Claim Playtime Rewards", "Periodically redeems free gifts & cash", State.AutoClaimRewards, function(v)
    State.AutoClaimRewards = v
end)

createToggle(EconomyTab, "Auto Claim Daily Reward", "Collects daily login rewards every 15s", State.AutoClaimDaily, function(v)
    State.AutoClaimDaily = v
end)

createButton(EconomyTab, "Claim All Now", "Triggers immediate claim cycle for all rewards", function()
    if RewardRemotes and RewardRemotes:FindFirstChild("ClaimReward") then
        for i = 1, 12 do
            pcall(function() RewardRemotes.ClaimReward:FireServer(i) end)
        end
    end
    if DailyRemotes and DailyRemotes:FindFirstChild("ClaimDaily") then
        pcall(function() DailyRemotes.ClaimDaily:FireServer() end)
    end
    State.Status = "Claimed All Rewards"
end)

-- 6. PLAYER / MISC TAB
createSection(PlayerTab, "Movement & Flight")

createToggle(PlayerTab, "Speed Hack", "Overrides humanoid walk speed", State.SpeedHack, function(v)
    State.SpeedHack = v
    applyPlayerStats()
end)

createSlider(PlayerTab, "WalkSpeed", 16, 200, State.WalkSpeed, function(v)
    State.WalkSpeed = v
    applyPlayerStats()
end)

createToggle(PlayerTab, "Jump Power Hack", "Enables higher jumps", State.JumpHack, function(v)
    State.JumpHack = v
    applyPlayerStats()
end)

createSlider(PlayerTab, "JumpPower", 50, 300, State.JumpPower, function(v)
    State.JumpPower = v
    applyPlayerStats()
end)

createToggle(PlayerTab, "Infinite Jump", "Jump repeatedly mid-air", State.InfiniteJump, function(v)
    State.InfiniteJump = v
end)

createToggle(PlayerTab, "Noclip", "Walk through all blocks and structures", State.Noclip, function(v)
    State.Noclip = v
end)

createToggle(PlayerTab, "Smooth Fly", "Fly using WASD + Space/Shift keys", State.Fly, function(v)
    State.Fly = v
    toggleFly(v)
end)

createSlider(PlayerTab, "Fly Speed", 20, 200, State.FlySpeed, function(v)
    State.FlySpeed = v
end)

createToggle(PlayerTab, "24/7 Anti-AFK", "Prevents 20-minute idle disconnects", State.AntiAFK, function(v)
    State.AntiAFK = v
end)

-- Status Bar
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(1, -140, 0, 24)
StatusBar.Position = UDim2.new(0, 135, 1, -26)
StatusBar.BackgroundColor3 = Theme.BgCard
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MainCard

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusBar

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Color = Theme.Border
StatusStroke.Thickness = 1
StatusStroke.Parent = StatusBar

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -10, 1, 0)
StatusText.Position = UDim2.new(0, 8, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.GothamMedium
StatusText.Text = "Status: Ready"
StatusText.TextColor3 = Theme.White
StatusText.TextSize = 11
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusBar

-- Live Status updater
task.spawn(function()
    while State.Running do
        StatusText.Text = "Status: " .. tostring(State.Status)
        task.wait(0.2)
    end
end)

print("[AUTO BUILD] Voxel Coaster Automation Engine Loaded Successfully!")
