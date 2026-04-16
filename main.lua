local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

local ToggleRefs = {}
local ToggleGameRequirements = {}
local guiCreated = false
local pendingNotifications = {}

local Keybinds = {
    Menu = Enum.KeyCode.Z,
    Flight = Enum.KeyCode.F,
    Noclip = Enum.KeyCode.X,
    Desync = Enum.KeyCode.U,
    FaceTarget = Enum.KeyCode.R,
    PlayerAttach = Enum.KeyCode.V,
    TeleportNearest = Enum.KeyCode.G
}


local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function GetRootPart(c) return c and c:FindFirstChild("HumanoidRootPart") end

local function IsUnsupportedExecutor()
    if identifyexecutor and type(identifyexecutor) == "function" then
        local executor = identifyexecutor():lower()
        local unsupported = {"ronix", "codex", "fluxus", "solara"}
        for _, u in ipairs(unsupported) do
            if executor:find(u) then return true end
        end
    end
    return false
end

local function Notify(title, text, duration)
    if guiCreated then
        Library:Notify({Title = title, Description = text, Duration = duration or 3})
    else
        table.insert(pendingNotifications, {title = title, text = text, duration = duration or 3})
    end
end

local function PlayBell()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://6518811702"
    s.Volume = 1
    s.Parent = SoundService
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
end

local function IsXenoExecutor()
    if identifyexecutor and type(identifyexecutor) == "function" then
        local executor = identifyexecutor():lower()
        if executor:find("xeno") or executor:find("x3no") then return true end
    end
    return false
end

local function IsMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function IsGameActive(gameName)
    local values = Workspace:FindFirstChild("Values")
    if not values then return false end
    local currentGame = values:FindFirstChild("CurrentGame")
    return currentGame and currentGame.Value == gameName
end

local function DisableToggle(toggleName)
    if ToggleRefs[toggleName] and ToggleRefs[toggleName].SetValue then
        pcall(function() ToggleRefs[toggleName]:SetValue(false) end)
    end
end

local function CanEnableToggle(gameName, toggleName)
    if not IsGameActive(gameName) then
        Notify(toggleName, "Wait for " .. gameName .. "!", 2)
        PlayBell()
        return false
    end
    return true
end

local function SafeTeleport(pos)
    local c = GetCharacter()
    if c then
        local rp = GetRootPart(c)
        if rp then rp.CFrame = CFrame.new(pos); return true end
    end
    return false
end

local function IsHider(p) return p and p:GetAttribute("IsHider") == true end
local function IsSeeker(p) return p and p:GetAttribute("IsHunter") == true end

PlayBell()
Library:Notify({Title = "HollyScriptX", Description = "Loading...", Duration = 3})
task.wait(3)

local FaceTargetModule = {
    Enabled = false,
    Connection = nil
}

function ToggleFaceTarget(enabled)
    if type(enabled) ~= "boolean" then
        enabled = not FaceTargetModule.Enabled
    end

    if FaceTargetModule.Connection then
        FaceTargetModule.Connection:Disconnect()
        FaceTargetModule.Connection = nil
    end
    
    FaceTargetModule.Enabled = enabled
    
    if enabled then
        FaceTargetModule.Connection = RunService.Heartbeat:Connect(function()
            if not FaceTargetModule.Enabled then return end
            
            local character = LocalPlayer.Character
            if not character then return end
            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            
            local closestPlayer = nil
            local shortestDistance = math.huge
            local myPos = root.Position
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        local dist = (targetRoot.Position - myPos).Magnitude
                        if dist < shortestDistance then
                            shortestDistance = dist
                            closestPlayer = player
                        end
                    end
                end
            end
            
            if closestPlayer and closestPlayer.Character then
                local targetRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local lookAt = CFrame.lookAt(root.Position, targetRoot.Position)
                    root.CFrame = CFrame.new(root.Position) * (lookAt - lookAt.Position)
                end
            end
        end)
        Notify("Face Target", "Enabled", 3)
    else
        Notify("Face Target", "Disabled", 3)
    end
    PlayBell()
end

local AutoDodge = {
    Enabled = false,
    AnimationIds = {
        "rbxassetid://88451099342711",
        "rbxassetid://79649041083405", 
        "rbxassetid://73242877658272",
        "rbxassetid://114928327045353",
        "rbxassetid://135690448001690", 
        "rbxassetid://103355259844069",
        "rbxassetid://125906547773381",
        "rbxassetid://121147456137931",
        "rbxassetid://96924216250322",
        "rbxassetid://116839849594540"
    },
    Connections = {},
    LastDodgeTime = 0,
    DodgeCooldown = 0.9,
    Range = 3.8,
    RangeSquared = 3.8 * 3.8,
    AnimationIdsSet = {},
    ActiveAnimations = {},
    CapturedCall = nil,
    OriginalFireServer = nil,
    Remote = nil,
    HeartbeatConnection = nil
}

for _, id in ipairs(AutoDodge.AnimationIds) do
    AutoDodge.AnimationIdsSet[id] = true
end

local function setupRemoteHook()
    local remote = nil
    local rs = ReplicatedStorage
    
    if rs:FindFirstChild("Remotes") then
        for _, child in pairs(rs.Remotes:GetChildren()) do
            if child:IsA("RemoteEvent") and child.Name == "UsedTool" then
                remote = child
                break
            end
        end
    end
    
    if not remote and rs:FindFirstChild("Events") then
        for _, child in pairs(rs.Events:GetChildren()) do
            if child:IsA("RemoteEvent") and child.Name == "UsedTool" then
                remote = child
                break
            end
        end
    end
    
    if not remote then return false end
    
    AutoDodge.Remote = remote
    
    if hookfunction then
        AutoDodge.OriginalFireServer = hookfunction(remote.FireServer, function(self, ...)
            local args = {...}
            
            for i, arg in ipairs(args) do
                if typeof(arg) == "Instance" and arg:IsA("Tool") and arg.Name == "DODGE!" then
                    AutoDodge.CapturedCall = {
                        args = {unpack(args)},
                        timestamp = tick(),
                        tool = arg
                    }
                    break
                end
            end
            
            return AutoDodge.OriginalFireServer(self, ...)
        end)
    end
    
    return true
end

local function executeDodge()
    if not AutoDodge.Enabled then return false end
    
    local currentTime = tick()
    if currentTime - AutoDodge.LastDodgeTime < AutoDodge.DodgeCooldown then return false end
    if not AutoDodge.CapturedCall then return false end
    
    local player = Players.LocalPlayer
    if not player then return false end
    
    local dodgeTool
    local character = player.Character
    if character then
        dodgeTool = character:FindFirstChild("DODGE!")
        if not dodgeTool and player.Backpack then
            dodgeTool = player.Backpack:FindFirstChild("DODGE!")
        end
    end
    
    if not dodgeTool then return false end
    
    local modifiedArgs = {}
    for i, arg in ipairs(AutoDodge.CapturedCall.args) do
        if typeof(arg) == "Instance" and arg:IsA("Tool") and arg.Name == "DODGE!" then
            modifiedArgs[i] = dodgeTool
        else
            modifiedArgs[i] = arg
        end
    end
    
    AutoDodge.LastDodgeTime = currentTime
    
    pcall(function()
        AutoDodge.Remote:FireServer(unpack(modifiedArgs))
    end)
    
    return true
end

local function isLookingAtPlayer(targetPlayer, localPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    if not localPlayer or not localPlayer.Character then return false end
    
    local targetHead = targetPlayer.Character:FindFirstChild("Head")
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not (targetHead and localRoot) then return false end
    
    local directionToLocal = (localRoot.Position - targetHead.Position).Unit
    local lookVector = targetHead.CFrame.LookVector
    
    local dotProduct = directionToLocal:Dot(lookVector)
    
    return dotProduct > 0.1
end

local function setupHeartbeatProcessing()
    local function instantHeartbeatCheck()
        if not AutoDodge.Enabled then return end
        if not LocalPlayer or not LocalPlayer.Character then return end
        
        local currentTime = tick()
        if currentTime - AutoDodge.LastDodgeTime < AutoDodge.DodgeCooldown then return end
        
        local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not localRoot then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if not player.Character then continue end
            
            local character = player.Character
            local targetRoot = character:FindFirstChild("HumanoidRootPart")
            if not targetRoot then continue end
            
            local distanceVector = targetRoot.Position - localRoot.Position
            local distanceSquared = distanceVector.Magnitude
            
            if distanceSquared > AutoDodge.RangeSquared then
                AutoDodge.ActiveAnimations[player.Name] = nil
                continue
            end
            
            if not isLookingAtPlayer(player, LocalPlayer) then continue end
            
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid then continue end
            
            local playingTracks = humanoid:GetPlayingAnimationTracks()
            
            for _, track in pairs(playingTracks) do
                if track and track.Animation and track.IsPlaying then
                    local animId = track.Animation.AnimationId
                    
                    if AutoDodge.AnimationIdsSet[animId] then
                        if not AutoDodge.ActiveAnimations[player.Name] then
                            AutoDodge.ActiveAnimations[player.Name] = {}
                        end
                        
                        local animationKey = animId
                        
                        if not AutoDodge.ActiveAnimations[player.Name][animationKey] then
                            AutoDodge.ActiveAnimations[player.Name][animationKey] = true
                            
                            if executeDodge() then
                                if track.Stopped then
                                    track.Stopped:Once(function()
                                        if AutoDodge.ActiveAnimations[player.Name] then
                                            AutoDodge.ActiveAnimations[player.Name][animationKey] = nil
                                        end
                                    end)
                                else
                                    task.delay(2, function()
                                        if AutoDodge.ActiveAnimations[player.Name] then
                                            AutoDodge.ActiveAnimations[player.Name][animationKey] = nil
                                        end
                                    end)
                                end
                                return
                            else
                                AutoDodge.ActiveAnimations[player.Name][animationKey] = nil
                            end
                        end
                    end
                end
            end
        end
    end
    
    AutoDodge.HeartbeatConnection = RunService.Heartbeat:Connect(instantHeartbeatCheck)
    table.insert(AutoDodge.Connections, AutoDodge.HeartbeatConnection)
end

function ToggleAutoDodge(enabled)
    if enabled then
        if IsXenoExecutor() then
            Notify("HollyScriptX [BETA]", "This Feature cannot be enabled in your executor :c", 5)
            return false
        end
        if not CanEnableToggle("HideAndSeek", "Auto Dodge") then
            return false
        end
    end
    
    for _, conn in pairs(AutoDodge.Connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    
    AutoDodge.Enabled = false
    AutoDodge.Connections = {}
    AutoDodge.ActiveAnimations = {}
    AutoDodge.LastDodgeTime = 0
    AutoDodge.HeartbeatConnection = nil
    
    if enabled then
        AutoDodge.Enabled = true
        
        if not AutoDodge.Remote then
            setupRemoteHook()
        end
        
        setupHeartbeatProcessing()
        Notify("Auto Dodge", "Enabled", 3)
    else
        Notify("Auto Dodge", "Disabled", 3)
    end
    PlayBell()
    return true
end

local Rebel = {
    Enabled = false,
    Connection = nil,
    LastCheckTime = 0,
    LastKillTime = 0,
    CheckCooldown = 0.1,
    KillCooldown = 0.05
}

function ToggleRebel(enabled)
    Rebel.Enabled = enabled
    if Rebel.Connection then
        Rebel.Connection:Disconnect()
        Rebel.Connection = nil
    end
    if enabled then
        Rebel.Connection = RunService.Heartbeat:Connect(function()
            if not Rebel.Enabled then return end
            local currentTime = tick()
            if currentTime - Rebel.LastCheckTime < Rebel.CheckCooldown then return end
            Rebel.LastCheckTime = currentTime
            
            local enemyNames = {}
            if workspace:FindFirstChild("Live") then
                for _, enemy in pairs(workspace.Live:GetChildren()) do
                    if enemy:IsA("Model") and enemy:FindFirstChild("Enemy") and not enemy:FindFirstChild("Dead") then
                        local isPlayer = false
                        for _, player in pairs(game:GetService("Players"):GetPlayers()) do
                            if player.Name == enemy.Name then
                                isPlayer = true
                                break
                            end
                        end
                        if not isPlayer then
                            table.insert(enemyNames, enemy.Name)
                        end
                    end
                end
            end
            
            if #enemyNames == 0 then return end
            
            for _, enemyName in pairs(enemyNames) do
                if currentTime - Rebel.LastKillTime < Rebel.KillCooldown then
                    task.wait(Rebel.KillCooldown - (currentTime - Rebel.LastKillTime))
                end
                
                local character = game:GetService("Players").LocalPlayer.Character
                local backpack = game:GetService("Players").LocalPlayer.Backpack
                local gun = nil
                
                if character then
                    for _, tool in pairs(character:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("Gun") then
                            gun = tool
                            break
                        end
                    end
                end
                
                if not gun and backpack then
                    for _, tool in pairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("Gun") then
                            gun = tool
                            break
                        end
                    end
                end
                
                if gun then
                    local args = {
                        gun,
                        {
                            ClientRayNormal = Vector3.new(-1.1920928955078125e-7, 1.0000001192092896, 0),
                            FiredGun = true,
                            SecondaryHitTargets = {},
                            ClientRayInstance = workspace:WaitForChild("StairWalkWay"):WaitForChild("Part"),
                            ClientRayPosition = Vector3.new(-220.17489624023438, 183.2957763671875, 301.07257080078125),
                            bulletCF = CFrame.new(-220.5039825439453, 185.22506713867188, 302.133544921875, 0.9551116228103638, 0.2567310333251953, -0.14782091975212097, 7.450581485102248e-9, 0.4989798665046692, 0.8666135668754578, 0.2962462604045868, -0.8277127146720886, 0.4765814542770386),
                            HitTargets = {
                                [enemyName] = "Head"
                            },
                            bulletSizeC = Vector3.new(0.009999999776482582, 0.009999999776482582, 4.452499866485596),
                            NoMuzzleFX = false,
                            FirePosition = Vector3.new(-72.88850402832031, -679.4803466796875, -173.31005859375)
                        }
                    }
                    
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("FiredGunClient"):FireServer(unpack(args))
                    end)
                    
                    Rebel.LastKillTime = tick()
                    task.wait(0.05)
                end
            end
        end)
        Notify("Rebel", "Instant Rebel Enabled", 2)
    else
        Rebel.LastKillTime = 0
        Rebel.LastCheckTime = 0
        Notify("Rebel", "Instant Rebel Disabled", 2)
    end
end

local FreeGuardSettings = {
    Enabled = false,
    MaxCycles = 5,
    ButtonWaitTime = 0.6
}

function ToggleFreeGuard(enabled)
    if enabled and IsXenoExecutor() then
        Notify("HollyScriptX [BETA]", "This Feature cannot be enabled in your executor :c", 5)
        return false
    end
    
    FreeGuardSettings.Enabled = enabled
    
    if enabled then
        Notify("Free Guard", "Enabled", 2)
        
        LocalPlayer:SetAttribute("__OwnsPermGuard", true)
        
        local function shouldIgnoreButton(button)
            if not button then return true end
            
            local buttonName = button.Name:lower()
            local buttonText = ""
            if button:IsA("TextButton") and button.Text then
                buttonText = button.Text:lower()
            end
            
            local fullText = buttonName .. " " .. buttonText
            
            local forbiddenWords = {
                "buy", "playable", "one.time", "onetime", "temporary", 
                "onetim", "time.playable", "time.guard", "playable.guard",
                "one.time.guard", "temporary.guard", "playable.one.time"
            }
            
            for _, word in ipairs(forbiddenWords) do
                if string.find(fullText, word) then
                    return true
                end
            end
            
            return false
        end
        
        local function findButtonByCriteria(criteria)
            local playerGui = LocalPlayer.PlayerGui
            
            local function searchInGui(guiObject)
                local foundButtons = {}
                
                for _, child in pairs(guiObject:GetChildren()) do
                    if child:IsA("TextButton") or child:IsA("ImageButton") then
                        local matches = true
                        
                        if criteria.skipBuy then
                            local btnName = child.Name:lower()
                            local hasBuy = string.find(btnName, "buy")
                            
                            if child:IsA("TextButton") and child.Text then
                                local btnText = child.Text:lower()
                                hasBuy = hasBuy or string.find(btnText, "buy")
                            end
                            
                            if hasBuy then
                                matches = false
                            end
                        end
                        
                        if criteria.name and child.Name ~= criteria.name then
                            matches = false
                        end
                        
                        if criteria.text and child:IsA("TextButton") and child.Text then
                            local btnText = child.Text:lower()
                            if not string.find(btnText, criteria.text:lower()) then
                                matches = false
                            end
                        end
                        
                        if criteria.color and child.BackgroundColor3 ~= criteria.color then
                            matches = false
                        end
                        
                        if matches then
                            table.insert(foundButtons, child)
                        end
                    end
                    
                    if #child:GetChildren() > 0 then
                        local nestedResults = searchInGui(child)
                        for _, btn in ipairs(nestedResults) do
                            table.insert(foundButtons, btn)
                        end
                    end
                end
                
                return foundButtons
            end
            
            return searchInGui(playerGui)
        end
        
        local function findButtonByPartialPath(pathParts, skipBuy)
            local playerGui = LocalPlayer.PlayerGui
            
            local function deepSearch(parent, depth)
                if depth > #pathParts then
                    return nil
                end
                
                local targetName = pathParts[depth]
                
                for _, child in pairs(parent:GetChildren()) do
                    if skipBuy and string.find(child.Name:lower(), "buy") then
                        continue
                    end
                    
                    if string.find(child.Name:lower(), targetName:lower()) then
                        if depth == #pathParts then
                            return child
                        else
                            local found = deepSearch(child, depth + 1)
                            if found then
                                return found
                            end
                        end
                    elseif #child:GetChildren() > 0 then
                        local found = deepSearch(child, depth)
                        if found then
                            return found
                        end
                    end
                end
                
                return nil
            end
            
            return deepSearch(playerGui, 1)
        end
        
        local function clickButton(button)
            if not button then return false end
            
            local buttonName = button.Name:lower()
            local buttonText = ""
            if button:IsA("TextButton") and button.Text then
                buttonText = button.Text:lower()
            end
            
            local fullText = buttonName .. " " .. buttonText
            
            if string.find(fullText, "buy") or
               string.find(fullText, "playable") or
               string.find(fullText, "one.time") or
               string.find(fullText, "onetime") or
               string.find(fullText, "temporary") or
               string.find(fullText, "onetim") or
               string.find(fullText, "time.playable") or
               string.find(fullText, "time.guard") or
               string.find(fullText, "playable.guard") then
                return false
            end
            
            if button:IsA("ImageLabel") or button:IsA("Frame") then
                local childButton = button:FindFirstChildWhichIsA("TextButton") or 
                                    button:FindFirstChildWhichIsA("ImageButton")
                if childButton then
                    button = childButton
                else
                    local parent = button.Parent
                    if parent and (parent:IsA("TextButton") or parent:IsA("ImageButton")) then
                        button = parent
                    else
                        return false
                    end
                end
            end
            
            if not (button:IsA("TextButton") or button:IsA("ImageButton")) then
                return false
            end
            
            local success = false
            
            if getconnections then
                local connections = getconnections(button.MouseButton1Click)
                if #connections > 0 then
                    for _, conn in pairs(connections) do
                        pcall(function()
                            conn:Fire()
                            success = true
                        end)
                    end
                end
            end
            
            if not success then
                pcall(function()
                    button.MouseButton1Click:Fire()
                    success = true
                end)
            end
            
            if not success and button:IsA("GuiButton") then
                pcall(function()
                    button:Activate()
                    success = true
                end)
            end
            
            return success
        end
        
        local function executeGuardCycle()
            local successCount = 0
            
            local greenButtons = findButtonByCriteria({
                color = Color3.fromRGB(0, 255, 0),
                skipBuy = true
            })
            
            local filteredGreenButtons = {}
            for _, btn in ipairs(greenButtons) do
                if not shouldIgnoreButton(btn) then
                    table.insert(filteredGreenButtons, btn)
                end
            end
            
            if #filteredGreenButtons == 0 then
                local acceptButtons = findButtonByCriteria({
                    text = "accept",
                    skipBuy = true
                })
                
                for _, btn in ipairs(acceptButtons) do
                    if not shouldIgnoreButton(btn) then
                        table.insert(filteredGreenButtons, btn)
                    end
                end
            end
            
            if #filteredGreenButtons == 0 then
                local nameGreenButtons = findButtonByCriteria({
                    name = "Green",
                    skipBuy = true
                })
                
                for _, btn in ipairs(nameGreenButtons) do
                    if not shouldIgnoreButton(btn) then
                        table.insert(filteredGreenButtons, btn)
                    end
                end
            end
            
            local button1 = findButtonByPartialPath({"HeaderPrompt", "Green"}, true)
            if button1 and not shouldIgnoreButton(button1) then
                table.insert(filteredGreenButtons, button1) 
            end
            
            if #filteredGreenButtons > 0 then
                for _, btn in ipairs(filteredGreenButtons) do
                    if clickButton(btn) then
                        successCount = successCount + 1
                        break
                    end
                end
            end
            
            if successCount == 0 then
                return false
            end
            
            task.wait(FreeGuardSettings.ButtonWaitTime)
            
            local tierButtons = findButtonByCriteria({
                name = "EquipTier1",
                skipBuy = true
            })
            
            local filteredTierButtons = {}
            for _, btn in ipairs(tierButtons) do
                if not shouldIgnoreButton(btn) then
                    table.insert(filteredTierButtons, btn)
                end
            end
            
            if #filteredTierButtons == 0 then
                local button2 = findButtonByPartialPath({"RankSelection", "EquipTier1"}, true)
                if button2 and not shouldIgnoreButton(button2) then
                    table.insert(filteredTierButtons, button2) 
                end
            end
            
            if #filteredTierButtons == 0 then
                local tier1Buttons = findButtonByCriteria({
                    text = "tier1",
                    skipBuy = true
                })
                
                for _, btn in ipairs(tier1Buttons) do
                    if not shouldIgnoreButton(btn) then
                        table.insert(filteredTierButtons, btn)
                    end
                end
            end
            
            if #filteredTierButtons == 0 then
                local allButtons = findButtonByCriteria({skipBuy = true})
                for _, btn in ipairs(allButtons) do
                    local btnName = btn.Name:lower()
                    local btnText = ""
                    if btn:IsA("TextButton") and btn.Text then
                        btnText = btn.Text:lower()
                    end
                    
                    local hasTier1 = string.find(btnName, "tier1") or 
                                    string.find(btnText, "tier1")
                    
                    if hasTier1 and not shouldIgnoreButton(btn) then
                        table.insert(filteredTierButtons, btn)
                    end
                end
            end
            
            if #filteredTierButtons > 0 then
                for _, tierBtn in ipairs(filteredTierButtons) do
                    if clickButton(tierBtn) then
                        successCount = successCount + 1
                        break
                    end
                end
            end
            
            if successCount < 2 then
                return false
            end
            
            task.wait(FreeGuardSettings.ButtonWaitTime)
            
            local confirmButtons = findButtonByCriteria({
                color = Color3.fromRGB(0, 255, 0),
                skipBuy = true
            })
            
            local filteredConfirmButtons = {}
            for _, btn in ipairs(confirmButtons) do
                if not shouldIgnoreButton(btn) then
                    table.insert(filteredConfirmButtons, btn)
                end
            end
            
            local playerGui = LocalPlayer.PlayerGui
            local function findGreenImageLabel(parent)
                for _, child in pairs(parent:GetChildren()) do
                    local childName = child.Name:lower()
                    if child:IsA("ImageLabel") and 
                       (string.find(childName, "green") or child.Name == "Green") and
                       not shouldIgnoreButton(child) then
                        return child
                    end
                    if #child:GetChildren() > 0 then
                        local found = findGreenImageLabel(child)
                        if found then return found end
                    end
                end
                return nil
            end
            
            local greenImageLabel = findGreenImageLabel(playerGui)
            if greenImageLabel and clickButton(greenImageLabel) then
                successCount = successCount + 1
                return true
            end
            
            local confirmButton3 = findButtonByPartialPath({"RankConfirmation", "Green"}, true)
            if confirmButton3 and not shouldIgnoreButton(confirmButton3) and clickButton(confirmButton3) then
                successCount = successCount + 1
                return true
            end
            
            local confirmTextButtons = findButtonByCriteria({
                text = "confirm",
                skipBuy = true
            })
            
            for _, cbtn in ipairs(confirmTextButtons) do
                if not shouldIgnoreButton(cbtn) and clickButton(cbtn) then
                    successCount = successCount + 1
                    return true
                end
            end
            
            return successCount > 2
        end
        
        local function executeAllCyclesInstantly()
            local cyclesCompleted = 0
            local totalCycles = FreeGuardSettings.MaxCycles
            
            for i = 1, totalCycles do
                if FreeGuardSettings.Enabled then
                    if executeGuardCycle() then
                        cyclesCompleted = cyclesCompleted + 1
                    end
                else
                    break
                end
            end
            
            Notify("Free Guard", "Completed", 2)
            
            task.wait(2)
            
            FreeGuardSettings.Enabled = false
        end
        
        spawn(executeAllCyclesInstantly)
        
    else
        Notify("Free Guard", "Disabled", 2)
        FreeGuardSettings.Enabled = false
    end
    PlayBell()
    return true
end

local Fly = {Enabled = false, Speed = 45, Connection = nil, BodyVelocity = nil}
function ToggleFly(enabled, silent)
    if enabled then
        if Fly.Enabled then return end
        Fly.Enabled = true
        local c = GetCharacter()
        if not c then return end
        local h = GetHumanoid(c)
        local rp = GetRootPart(c)
        if not (h and rp) then return end
        if Fly.BodyVelocity then Fly.BodyVelocity:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "FlyBodyVelocity"
        bv.MaxForce = Vector3.new(40000, 40000, 40000)
        bv.Parent = rp
        Fly.BodyVelocity = bv
        Fly.Connection = RunService.Heartbeat:Connect(function()
            if not Fly.Enabled or not c or not c.Parent then ToggleFly(false, true); return end
            rp = GetRootPart(c)
            if not rp or not bv then ToggleFly(false, true); return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local md = Vector3.new(0,0,0)
            local lv = cam.CFrame.LookVector
            local rv = cam.CFrame.RightVector
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then md = md + lv end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then md = md - lv end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then md = md - rv end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then md = md + rv end
            bv.Velocity = md.Magnitude > 0 and md.Unit * Fly.Speed or Vector3.new(0,0,0)
        end)
        if not silent then Notify("Flight", "Enabled", 3) end
    else
        if not Fly.Enabled then return end
        Fly.Enabled = false
        if Fly.Connection then Fly.Connection:Disconnect(); Fly.Connection = nil end
        if Fly.BodyVelocity then Fly.BodyVelocity:Destroy(); Fly.BodyVelocity = nil end
        local c = GetCharacter()
        if c then
            local rp = GetRootPart(c)
            if rp then rp.AssemblyLinearVelocity = Vector3.new(0,0,0) end
        end
        if not silent then Notify("Flight", "Disabled", 3) end
    end
    if not silent then PlayBell() end
end

local harmfulEffectsList = {"RagdollStun","Stun","Stunned","StunEffect","StunHit","Knockback","Knockdown","Knockout","Dazed","Paralyzed","Freeze","Frozen","Sleep","Slow","Slowed","Root","Rooted"}
local RemoveStunEnabled = false
function ToggleRemoveStun(enabled)
    RemoveStunEnabled = enabled
    if enabled then
        local function remove()
            local c = GetCharacter()
            if not c then return end
            for _, e in ipairs(harmfulEffectsList) do
                local eff = c:FindFirstChild(e)
                if eff then pcall(function() eff:Destroy() end) end
            end
            local h = GetHumanoid(c)
            if h and h:GetAttribute("Stunned") then h:SetAttribute("Stunned", false) end
        end
        remove()
        RunService.Heartbeat:Connect(function() if RemoveStunEnabled then remove() end end)
        Notify("Remove Stun", "Enabled", 3)
    else
        Notify("Remove Stun", "Disabled", 3)
    end
    PlayBell()
end

local AutoQTEEnabled = false
function ToggleAutoQTE(enabled)
    if enabled and IsXenoExecutor() then
        Notify("HollyScriptX [BETA]", "This Feature cannot be enabled in your executor :c", 5)
        return false
    end
    AutoQTEEnabled = enabled
    if enabled then
        local ImpactFrames = LocalPlayer.PlayerGui:FindFirstChild("ImpactFrames")
        if ImpactFrames then
            local processed = {}
            ImpactFrames.ChildAdded:Connect(function(outer)
                if outer.Name ~= "OuterRingTemplate" or processed[outer] then return end
                processed[outer] = true
                task.defer(function()
                    local inner = nil
                    for _, g in pairs(ImpactFrames:GetChildren()) do
                        if g.Name == "InnerTemplate" and g.Position == outer.Position and not g:GetAttribute("Failed") then
                            inner = g; break
                        end
                    end
                    if not inner or inner:GetAttribute("Tweening") or inner:GetAttribute("Failed") then return end
                    local HBGQTE = require(ReplicatedStorage.Modules.HBGQTE)
                    pcall(function() HBGQTE.Pressed(false, {Inner=inner, Outer=outer, Duration=2, StartedAt=tick(), Data={}}) end)
                end)
            end)
        end
        Notify("Auto QTE", "Enabled", 3)
    else
        Notify("Auto QTE", "Disabled", 3)
    end
    PlayBell()
    return true
end

function TeleportUp()
    local c = GetCharacter()
    if c then
        local rp = GetRootPart(c)
        if rp then rp.CFrame = rp.CFrame + Vector3.new(0,100,0); Notify("Teleport","Up 100",2) end
    end
    PlayBell()
end

function TeleportDown()
    local c = GetCharacter()
    if c then
        local rp = GetRootPart(c)
        if rp then rp.CFrame = rp.CFrame + Vector3.new(0,-40,0); Notify("Teleport","Down 40",2) end
    end
    PlayBell()
end

local GamePassStates = {
    PermanentGuard = false,
    GlassVision = false,
    EmotePages = false,
    CustomPlayerTag = false,
    PrivateServerPlus = false,
    FreeVIP = false
}

function TogglePermanentGuard(enabled)
    GamePassStates.PermanentGuard = enabled
    LocalPlayer:SetAttribute("__OwnsPermGuard", enabled)
    Notify("GamePass", "Permanent Guard " .. (enabled and "Enabled" or "Disabled"), 3)
    PlayBell()
end

function ToggleGlassVision(enabled)
    GamePassStates.GlassVision = enabled
    LocalPlayer:SetAttribute("__OwnsGlassManufacturerVision", enabled)
    Notify("GamePass", "Glass Vision " .. (enabled and "Enabled" or "Disabled"), 3)
    PlayBell()
end

function ToggleEmotePages(enabled)
    GamePassStates.EmotePages = enabled
    LocalPlayer:SetAttribute("__OwnsEmotePages", enabled)
    Notify("GamePass", "Emote Pages " .. (enabled and "Enabled" or "Disabled"), 3)
    PlayBell()
end

function ToggleCustomPlayerTag(enabled)
    GamePassStates.CustomPlayerTag = enabled
    LocalPlayer:SetAttribute("__OwnsCustomPlayerTag", enabled)
    Notify("GamePass", "Custom Player Tag " .. (enabled and "Enabled" or "Disabled"), 3)
    PlayBell()
end

function TogglePrivateServerPlus(enabled)
    GamePassStates.PrivateServerPlus = enabled
    LocalPlayer:SetAttribute("__OwnsPSPlus", enabled)
    Notify("GamePass", "Private Server Plus " .. (enabled and "Enabled" or "Disabled"), 3)
    PlayBell()
end

function ToggleFreeVIP(enabled)
    GamePassStates.FreeVIP = enabled
    LocalPlayer:SetAttribute("__OwnsVIPGamepass", enabled)
    LocalPlayer:SetAttribute("VIPChatTag", enabled)
    LocalPlayer:SetAttribute("VIPJoinAlert", enabled)
    Notify("GamePass", "Free VIP " .. (enabled and "Enabled" or "Disabled"), 3)
    PlayBell()
end

local HitboxEnabled = false; local HitboxSize = 50; local ModifiedParts = {}
function ToggleHitboxExpander(enabled)
    HitboxEnabled = enabled
    if enabled then
        RunService.Heartbeat:Connect(function()
            if not HitboxEnabled then return end
            pcall(function()
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local r = p.Character:FindFirstChild("HumanoidRootPart")
                        if r and not ModifiedParts[r] then
                            ModifiedParts[r] = {Size = r.Size, CanCollide = r.CanCollide, Transparency = r.Transparency}
                            r.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                            r.CanCollide = false
                            r.Transparency = 1
                        end
                    end
                end
            end)
        end)
        Notify("Hitbox","Enabled - "..HitboxSize,3)
    else
        for p, props in pairs(ModifiedParts) do
            if p and p.Parent then p.Size = props.Size; p.CanCollide = props.CanCollide; p.Transparency = props.Transparency end
        end
        ModifiedParts = {}
        Notify("Hitbox","Disabled",3)
    end
    PlayBell()
end
function SetHitboxSize(s) HitboxSize = s; if HitboxEnabled then for p,_ in pairs(ModifiedParts) do if p and p.Parent then p.Size = Vector3.new(s,s,s) end end end end

local RapidFireEnabled = false; local OriginalFireRates = {}
function ToggleRapidFire(enabled)
    RapidFireEnabled = enabled
    if enabled then
        RunService.Heartbeat:Connect(function()
            if not RapidFireEnabled then return end
            pcall(function()
                local w = ReplicatedStorage:FindFirstChild("Weapons")
                if w and w:FindFirstChild("Guns") then
                    for _, o in pairs(w.Guns:GetDescendants()) do
                        if o.Name == "FireRateCD" and (o:IsA("NumberValue") or o:IsA("IntValue")) then
                            if not OriginalFireRates[o] then OriginalFireRates[o] = o.Value end
                            o.Value = 0
                        end
                    end
                end
                local c = GetCharacter()
                if c then for _, t in pairs(c:GetChildren()) do if t:IsA("Tool") then for _, o in pairs(t:GetDescendants()) do if o.Name == "FireRateCD" and (o:IsA("NumberValue") or o:IsA("IntValue")) then if not OriginalFireRates[o] then OriginalFireRates[o] = o.Value end; o.Value = 0 end end end end end
            end)
        end)
        Notify("Rapid Fire","Enabled",3)
    else
        for o,v in pairs(OriginalFireRates) do if o and o.Parent then o.Value = v end end
        OriginalFireRates = {}
        Notify("Rapid Fire","Disabled",3)
    end
    PlayBell()
end

local InfiniteAmmoEnabled = false; local OriginalAmmo = {}
function ToggleInfiniteAmmo(enabled)
    InfiniteAmmoEnabled = enabled
    if enabled then
        RunService.Heartbeat:Connect(function()
            if not InfiniteAmmoEnabled then return end
            pcall(function()
                local c = GetCharacter()
                if c then for _, t in pairs(c:GetChildren()) do if t:IsA("Tool") then for _, o in pairs(t:GetDescendants()) do if (o:IsA("NumberValue") or o:IsA("IntValue")) and (o.Name:lower():find("ammo") or o.Name:lower():find("bullet")) then if not OriginalAmmo[o] then OriginalAmmo[o] = o.Value end; o.Value = math.huge end end end end end
                local bp = LocalPlayer:FindFirstChild("Backpack")
                if bp then for _, t in pairs(bp:GetChildren()) do if t:IsA("Tool") then for _, o in pairs(t:GetDescendants()) do if (o:IsA("NumberValue") or o:IsA("IntValue")) and (o.Name:lower():find("ammo") or o.Name:lower():find("bullet")) then if not OriginalAmmo[o] then OriginalAmmo[o] = o.Value end; o.Value = math.huge end end end end end
            end)
        end)
        Notify("Infinite Ammo","Enabled",3)
    else
        for o,v in pairs(OriginalAmmo) do if o and o.Parent then o.Value = v end end
        OriginalAmmo = {}
        Notify("Infinite Ammo","Disabled",3)
    end
    PlayBell()
end

local AutoNextEnabled = false; local AutoNextConn = nil; local TargetPos = Vector3.new(-214.30,186.86,242.64); local Radius = 80
function ToggleAutoNextGame(enabled)
    AutoNextEnabled = enabled
    if AutoNextConn then AutoNextConn:Disconnect(); AutoNextConn = nil end
    if enabled then
        local t = 0
        AutoNextConn = RunService.Heartbeat:Connect(function(dt)
            if not AutoNextEnabled then return end
            local c = LocalPlayer.Character
            local pp = c and c.PrimaryPart and c.PrimaryPart.Position
            if pp and (pp - TargetPos).Magnitude <= Radius then
                t = t + dt
                if t >= 3.4 then t = 0; pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("TemporaryReachedBindable"):FireServer() end) end
            else t = 0 end
        end)
        Notify("Auto Next Game","Enabled",3)
    else Notify("Auto Next Game","Disabled",3) end
    PlayBell()
end

local FreeDashEnabled = false
function ToggleFreeDash(enabled)
    if enabled and IsXenoExecutor() then
        Notify("HollyScriptX [BETA]", "This Feature cannot be enabled in your executor :c", 5)
        return false
    end
    FreeDashEnabled = enabled
    if enabled then
        pcall(function()
            local r = ReplicatedStorage:FindFirstChild("Remotes")
            if r then r = r:FindFirstChild("DashRequest")
                if r and setrawmetatable then setrawmetatable(r, {__index=function() return function() end end}) end
            end
            local b = LocalPlayer:FindFirstChild("Boosts")
            if b and b:FindFirstChild("Faster Sprint") then b["Faster Sprint"].Value = 5 end
        end)
        Notify("Free Dash","Enabled",3)
    else
        pcall(function()
            local b = LocalPlayer:FindFirstChild("Boosts")
            if b and b:FindFirstChild("Faster Sprint") then b["Faster Sprint"].Value = 1 end
        end)
        Notify("Free Dash","Disabled",3)
    end
    PlayBell()
    return true
end

local ESPEnabled = false; local ESPFolder = nil; local ESPPlayers = {}
function ToggleESP(enabled)
    ESPEnabled = enabled
    if ESPFolder then ESPFolder:Destroy() end
    if enabled then
        ESPFolder = Instance.new("Folder", CoreGui)
        ESPFolder.Name = "HollyScriptX_ESP"
        local function update()
            if not ESPEnabled then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local c = p.Character
                    local h = c:FindFirstChildOfClass("Humanoid")
                    local rp = c:FindFirstChild("HumanoidRootPart")
                    if h and rp and h.Health > 0 then
                        if not ESPPlayers[p] then
                            local hl = Instance.new("Highlight", ESPFolder)
                            hl.Name = p.Name.."_ESP"
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            local bb = Instance.new("BillboardGui", ESPFolder)
                            bb.Name = p.Name.."_Text"
                            bb.AlwaysOnTop = true
                            bb.Size = UDim2.new(0,200,0,50)
                            bb.StudsOffset = Vector3.new(0,3,0)
                            local lbl = Instance.new("TextLabel", bb)
                            lbl.Size = UDim2.new(1,0,1,0)
                            lbl.BackgroundTransparency = 1
                            lbl.TextColor3 = Color3.new(1,1,1)
                            lbl.TextSize = 18
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextStrokeColor3 = Color3.new(0,0,0)
                            lbl.TextStrokeTransparency = 0.5
                            ESPPlayers[p] = {highlight = hl, billboard = bb, label = lbl}
                        end
                        local d = ESPPlayers[p]
                        d.highlight.Adornee = c
                        d.billboard.Adornee = rp
                        if IsHider(p) then
                            d.highlight.FillColor = Color3.fromRGB(0,255,0)
                            d.highlight.OutlineColor = Color3.fromRGB(0,200,0)
                        elseif IsSeeker(p) then
                            d.highlight.FillColor = Color3.fromRGB(255,0,0)
                            d.highlight.OutlineColor = Color3.fromRGB(200,0,0)
                        else
                            d.highlight.FillColor = Color3.fromRGB(255,255,255)
                            d.highlight.OutlineColor = Color3.fromRGB(255,255,255)
                        end
                        d.label.Text = p.DisplayName or p.Name
                        d.billboard.Enabled = true
                        d.highlight.Enabled = true
                    elseif ESPPlayers[p] then
                        ESPPlayers[p].highlight.Enabled = false
                        ESPPlayers[p].billboard.Enabled = false
                    end
                end
            end
        end
        RunService.RenderStepped:Connect(update)
        Notify("ESP", "Enabled", 3)
    else
        for _, d in pairs(ESPPlayers) do
            if d.highlight then d.highlight:Destroy() end
            if d.billboard then d.billboard:Destroy() end
        end
        ESPPlayers = {}
        Notify("ESP", "Disabled", 3)
    end
    PlayBell()
end

local AutoSafeEnabled = false; local AutoSafeConn = nil; local AutoSafeTriggered = false
function ToggleAutoSafe(enabled)
    if AutoSafeConn then AutoSafeConn:Disconnect(); AutoSafeConn = nil end
    AutoSafeEnabled = enabled
    AutoSafeTriggered = false
    if enabled then
        AutoSafeConn = RunService.Heartbeat:Connect(function()
            if not AutoSafeEnabled then return end
            if AutoSafeTriggered then return end
            local c = GetCharacter()
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 and h.Health <= 30 then
                    AutoSafeTriggered = true
                    local rp = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
                    if rp then rp.CFrame = CFrame.new(rp.Position.X, rp.Position.Y+100, rp.Position.Z); Notify("AutoSafe","Saved!",2) end
                end
            end
        end)
        Notify("AutoSafe","Enabled",3)
    else Notify("AutoSafe","Disabled",3) end
    PlayBell()
end

function Dalgona_Lighter()
    if IsGameActive("Dalgona") then
        LocalPlayer:SetAttribute("HasLighter", true)
        Notify("Dalgona","Lighter Unlocked",2)
    else
        Notify("Dalgona","Wait for Dalgona!",2)
    end
    PlayBell()
end

function JR_TP_Start()
    if IsGameActive("JumpRope") then
        SafeTeleport(Vector3.new(615.284424,192.274277,920.952515))
        Notify("JumpRope","Teleported to Start",2)
    else
        Notify("JumpRope","Wait for JumpRope!",2)
    end
    PlayBell()
end

function JR_TP_End()
    if IsGameActive("JumpRope") then
        SafeTeleport(Vector3.new(720.896057,198.628311,921.170654))
        Notify("JumpRope","Teleported to End",2)
    else
        Notify("JumpRope","Wait for JumpRope!",2)
    end
    PlayBell()
end

function JR_DeleteRope()
    if IsGameActive("JumpRope") then
        for _,o in pairs(workspace:GetDescendants()) do
            if o.Name == "Rope" and (o:IsA("Model") or o:IsA("Part")) then
                o:Destroy()
                Notify("JumpRope","Rope deleted",2)
                PlayBell()
                return
            end
        end
        Notify("JumpRope","Rope not found",2)
    else
        Notify("JumpRope","Wait for JumpRope!",2)
    end
    PlayBell()
end

local JumpRopeAntiFall = {Enabled=false, Platform=nil, Conn=nil}
function ToggleJumpRopeAntiFall(enabled)
    if enabled then
        if not CanEnableToggle("JumpRope", "Anti Fall") then
            return false
        end
    end
    if JumpRopeAntiFall.Conn then JumpRopeAntiFall.Conn:Disconnect() end
    if JumpRopeAntiFall.Platform then JumpRopeAntiFall.Platform:Destroy() end
    JumpRopeAntiFall.Enabled = enabled
    if enabled then
        local function create()
            local c = GetCharacter()
            if not c then return nil end
            local rp = GetRootPart(c)
            if not rp then return nil end
            local p = Instance.new("Part")
            p.Name = "JumpRopeAntiFall"
            p.Size = Vector3.new(10000,1,10000)
            p.Position = Vector3.new(rp.Position.X, rp.Position.Y-5, rp.Position.Z)
            p.Anchored = true
            p.CanCollide = true
            p.Transparency = 1
            p.Parent = workspace
            return p
        end
        JumpRopeAntiFall.Platform = create()
        JumpRopeAntiFall.Conn = RunService.Heartbeat:Connect(function()
            if not JumpRopeAntiFall.Enabled then return end
            if not IsGameActive("JumpRope") then
                DisableToggle("JumpRopeAntiFall")
                return
            end
            if not (JumpRopeAntiFall.Platform and JumpRopeAntiFall.Platform.Parent) then
                JumpRopeAntiFall.Platform = create()
            end
        end)
        Notify("AntiFall","Enabled",3)
    else
        Notify("AntiFall","Disabled",2)
    end
    PlayBell()
    return true
end

function GB_TP_End()
    if IsGameActive("GlassBridge") then
        SafeTeleport(Vector3.new(-196.372467,522.192139,-1534.20984))
        Notify("GlassBridge","Teleported to End",2)
    else
        Notify("GlassBridge","Wait for GlassBridge!",2)
    end
    PlayBell()
end

local GlassESPEnabled = false
function ToggleGlassESP(enabled)
    if enabled then
        if not CanEnableToggle("GlassBridge", "Glass ESP") then
            return false
        end
    end
    GlassESPEnabled = enabled
    if enabled then
        local function update()
            local gh = Workspace:FindFirstChild("GlassBridge") and Workspace.GlassBridge:FindFirstChild("GlassHolder")
            if not gh then return end
            for _,l in pairs(gh:GetChildren()) do
                for _,gm in pairs(l:GetChildren()) do
                    if gm:IsA("Model") then
                        for _,p in pairs(gm:GetDescendants()) do
                            if p:IsA("BasePart") and p:GetAttribute("GlassPart") then
                                p.Color = p:GetAttribute("ActuallyKilling") == nil and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
                                p.Material = Enum.Material.Neon
                            end
                        end
                    end
                end
            end
        end
        update()
        RunService.Heartbeat:Connect(function() if GlassESPEnabled then update() end end)
        Notify("GlassESP","Enabled",3)
    else
        local gh = Workspace:FindFirstChild("GlassBridge") and Workspace.GlassBridge:FindFirstChild("GlassHolder")
        if gh then
            for _,l in pairs(gh:GetChildren()) do
                for _,gm in pairs(l:GetChildren()) do
                    if gm:IsA("Model") then
                        for _,p in pairs(gm:GetDescendants()) do
                            if p:IsA("BasePart") and p:GetAttribute("GlassPart") then
                                p.Color = Color3.fromRGB(163,162,165)
                                p.Material = Enum.Material.Glass
                            end
                        end
                    end
                end
            end
        end
        Notify("GlassESP","Disabled",3)
    end
    PlayBell()
    return true
end

local AntiBreakEnabled = false; local AntiBreakConn = nil; local SafetyPlatforms = {}
function ToggleAntiBreak(enabled)
    if enabled then
        if not CanEnableToggle("GlassBridge", "Anti Break") then
            return false
        end
    end
    if AntiBreakConn then AntiBreakConn:Disconnect(); AntiBreakConn = nil end
    for _,p in pairs(SafetyPlatforms) do if p then p:Destroy() end end
    SafetyPlatforms = {}
    AntiBreakEnabled = enabled
    if enabled then
        AntiBreakConn = RunService.Heartbeat:Connect(function()
            if not AntiBreakEnabled then return end
            if not IsGameActive("GlassBridge") then
                DisableToggle("AntiBreak")
                return
            end
            local gh = Workspace:FindFirstChild("GlassBridge") and Workspace.GlassBridge:FindFirstChild("GlassHolder")
            if not gh then return end
            for _,l in pairs(gh:GetChildren()) do
                for _,gm in pairs(l:GetChildren()) do
                    if gm:IsA("Model") and gm.PrimaryPart then
                        if gm.PrimaryPart:GetAttribute("exploitingisevil") then
                            gm.PrimaryPart:SetAttribute("exploitingisevil", nil)
                        end
                        if not SafetyPlatforms[gm] then
                            local p = Instance.new("Part")
                            p.Name = "GlassSafetyPlatform"
                            p.Size = Vector3.new(20,1,20)
                            p.Position = gm.PrimaryPart.Position + Vector3.new(0,-2,0)
                            p.Anchored = true
                            p.CanCollide = true
                            p.Transparency = 1
                            p.Parent = workspace
                            SafetyPlatforms[gm] = p
                        end
                    end
                end
            end
        end)
        Notify("AntiBreak","Enabled",2)
    else
        Notify("AntiBreak","Disabled",2)
    end
    PlayBell()
    return true
end

function TeleportToHider()
    if not IsGameActive("HideAndSeek") then
        Notify("HNS","Wait for HideAndSeek!",2)
        PlayBell()
        return
    end
    local c = GetCharacter()
    if not c then return end
    for _,p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsHider(p) and p.Character then
            local hr = p.Character:FindFirstChild("HumanoidRootPart")
            if hr then
                local rp = GetRootPart(c)
                if rp then
                    rp.CFrame = CFrame.new(hr.Position.X, hr.Position.Y+3, hr.Position.Z)
                    Notify("HNS","Teleported to hider: "..p.Name,2)
                    PlayBell()
                    return
                end
            end
        end
    end
    Notify("HNS","No hider found",2)
    PlayBell()
end

local InfStaminaActive = false; local StaminaConns = {}
function ToggleInfiniteStamina(enabled)
    if enabled then
        if not CanEnableToggle("HideAndSeek", "Infinite Stamina") then
            return false
        end
    end
    if enabled then
        if InfStaminaActive then return end
        InfStaminaActive = true
        local function freezeUI()
            local ui = ReplicatedStorage:FindFirstChild("UI")
            if ui then
                local sb = ui:FindFirstChild("StaminaBar")
                local nsb = ui:FindFirstChild("NoRegenStaminaBar")
                if sb then
                    sb.Size = UDim2.new(1,0,1,0)
                    table.insert(StaminaConns, sb:GetPropertyChangedSignal("Size"):Connect(function() if sb.Size.X.Scale < 1 then sb.Size = UDim2.new(1,0,1,0) end end))
                end
                if nsb then
                    nsb.Size = UDim2.new(1,0,1,0)
                    table.insert(StaminaConns, nsb:GetPropertyChangedSignal("Size"):Connect(function() if nsb.Size.X.Scale < 1 then nsb.Size = UDim2.new(1,0,1,0) end end))
                end
            end
        end
        local function freezeChar()
            local c = LocalPlayer.Character
            if not c then return end
            local h = c:FindFirstChild("Humanoid")
            if not h then return end
            for _,ch in pairs(h:GetChildren()) do
                if ch:IsA("NumberValue") and (ch.Name:lower():find("stamina") or ch.Name:lower():find("energy")) then
                    ch.Value = 100
                    table.insert(StaminaConns, ch:GetPropertyChangedSignal("Value"):Connect(function() ch.Value = 100 end))
                end
            end
            for _,ch in pairs(c:GetChildren()) do
                if ch:IsA("NumberValue") and (ch.Name:lower():find("stamina") or ch.Name:lower():find("energy")) then
                    ch.Value = 100
                    table.insert(StaminaConns, ch:GetPropertyChangedSignal("Value"):Connect(function() ch.Value = 100 end))
                end
            end
        end
        freezeUI(); freezeChar()
        table.insert(StaminaConns, LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); if InfStaminaActive then freezeChar() end end))
        table.insert(StaminaConns, RunService.Heartbeat:Connect(function()
            if InfStaminaActive then
                local c = LocalPlayer.Character
                if c then
                    local h = c:FindFirstChild("Humanoid")
                    if h then
                        for _,ch in pairs(h:GetChildren()) do
                            if ch:IsA("NumberValue") and (ch.Name:lower():find("stamina") or ch.Name:lower():find("energy")) and ch.Value < 100 then
                                ch.Value = 100
                            end
                        end
                    end
                end
                local ui = ReplicatedStorage:FindFirstChild("UI")
                if ui then
                    local sb = ui:FindFirstChild("StaminaBar")
                    local nsb = ui:FindFirstChild("NoRegenStaminaBar")
                    if sb and sb.Size.X.Scale < 1 then sb.Size = UDim2.new(1,0,1,0) end
                    if nsb and nsb.Size.X.Scale < 1 then nsb.Size = UDim2.new(1,0,1,0) end
                end
            end
        end))
        Notify("Infinite Stamina","Enabled",3)
    else
        InfStaminaActive = false
        for _,c in pairs(StaminaConns) do pcall(function() c:Disconnect() end) end
        StaminaConns = {}
        Notify("Infinite Stamina","Disabled",3)
    end
    PlayBell()
    return true
end

local SpikesKill = {Enabled=false, SpikesPos=nil, Platform=nil, Conn=nil, CharConn=nil}
local SpikeAnimIds = {"rbxassetid://105341857343164","rbxassetid://95623680038308","rbxassetid://106191977814264","rbxassetid://118039465583394"}
function ToggleSpikesKill(enabled)
    if enabled then
        if not CanEnableToggle("HideAndSeek", "Spikes Kill") then
            return false
        end
    end
    if SpikesKill.Conn then SpikesKill.Conn:Disconnect() end
    if SpikesKill.CharConn then SpikesKill.CharConn:Disconnect() end
    if SpikesKill.Platform then SpikesKill.Platform:Destroy() end
    SpikesKill.Enabled = enabled
    if enabled then
        pcall(function()
            local hsm = workspace:FindFirstChild("HideAndSeekMap")
            local kp = hsm and hsm:FindFirstChild("KillingParts")
            if kp then
                for _,s in pairs(kp:GetChildren()) do
                    if s:IsA("BasePart") then
                        if not SpikesKill.SpikesPos then SpikesKill.SpikesPos = s.Position end
                        s:Destroy()
                    end
                end
            end
        end)
        local function createPlatform()
            if not SpikesKill.SpikesPos then return end
            if SpikesKill.Platform then SpikesKill.Platform:Destroy() end
            local p = Instance.new("Part")
            p.Name = "SafetyPlatform"
            p.Size = Vector3.new(20,1,20)
            p.Position = SpikesKill.SpikesPos + Vector3.new(0,10,0)
            p.Anchored = true
            p.CanCollide = true
            p.Transparency = 1
            p.Parent = workspace
            SpikesKill.Platform = p
        end
        local function setupChar(char)
            local h = char:WaitForChild("Humanoid")
            SpikesKill.Conn = h.AnimationPlayed:Connect(function(track)
                if not SpikesKill.Enabled then return end
                if track.Animation and table.find(SpikeAnimIds, track.Animation.AnimationId) then
                    local rp = char:FindFirstChild("HumanoidRootPart")
                    if rp and SpikesKill.Platform then
                        local orig = char:GetPrimaryPartCFrame()
                        char:SetPrimaryPartCFrame(CFrame.new(SpikesKill.Platform.Position + Vector3.new(0,3,0)))
                        track.Stopped:Connect(function()
                            task.wait(0.6)
                            if orig then char:SetPrimaryPartCFrame(orig) end
                        end)
                    end
                end
            end)
        end
        createPlatform()
        if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
        SpikesKill.CharConn = LocalPlayer.CharacterAdded:Connect(function(char) task.wait(1); setupChar(char) end)
        Notify("Spikes Kill","Enabled",2)
    else
        Notify("Spikes Kill","Disabled",2)
    end
    PlayBell()
    return true
end

local AutoGonggiEnabled = false
function ToggleAutoGonggi(enabled)
    if enabled then
        if not CanEnableToggle("Pentathlon", "Auto Gonggi") then
            return false
        end
    end
    AutoGonggiEnabled = enabled
    if enabled then
        task.spawn(function()
            while AutoGonggiEnabled do
                if not IsGameActive("Pentathlon") then
                    DisableToggle("AutoGonggi")
                    break
                end
                pcall(function()
                    local ui = LocalPlayer.PlayerGui:FindFirstChild("Gonggi")
                    if ui then
                        local qte = ui:FindFirstChild("QTEScreen")
                        if qte and qte.Visible then
                            local cont = qte:FindFirstChild("MainBar")
                            cont = cont and cont:FindFirstChild("ButtonContents")
                            cont = cont and cont:FindFirstChild("Inner")
                            local btns = ui:FindFirstChild("MobileButtons")
                            if cont and btns then
                                for _,img in pairs(cont:GetChildren()) do
                                    if img:IsA("ImageLabel") and img.ImageTransparency < 0.1 then
                                        local it = img:GetAttribute("InputType")
                                        if it then
                                            local btn = btns:FindFirstChild(tostring(it))
                                            if btn and getconnections then
                                                for _,c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                            end
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                    local pm = workspace:FindFirstChild("PentathlonMap")
                    if pm then
                        for _,s in pairs(pm:GetDescendants()) do
                            if s:IsA("BasePart") and (s.Name:find("Stone") or s.Name:find("GonggiStone")) then
                                s.Anchored = true
                                s.CanCollide = false
                            end
                        end
                    end
                end)
                task.wait(0.05)
            end
        end)
        Notify("AutoGonggi","Enabled",3)
    else
        Notify("AutoGonggi","Disabled",3)
    end
    PlayBell()
    return true
end

local SpeedHackEnabled = false; local SpeedValue = 39; local SpeedHackLoop = nil
function ToggleSpeedHack(enabled)
    SpeedHackEnabled = enabled
    if enabled then
        if SpeedHackLoop then task.cancel(SpeedHackLoop) end
        SpeedHackLoop = task.spawn(function()
            while SpeedHackEnabled do
                local c = GetCharacter()
                if c then
                    local h = GetHumanoid(c)
                    if h and h.Health > 0 then
                        h.WalkSpeed = SpeedValue
                    end
                end
                task.wait(0.1)
            end
        end)
        Notify("SpeedHack","Enabled - "..SpeedValue,3)
    else
        if SpeedHackLoop then task.cancel(SpeedHackLoop); SpeedHackLoop = nil end
        local c = GetCharacter()
        if c then
            local h = GetHumanoid(c)
            if h then
                h.WalkSpeed = 16
            end
        end
        Notify("SpeedHack","Disabled",3)
    end
    PlayBell()
end
function SetSpeedValue(v)
    SpeedValue = math.min(v, 40)
    if SpeedHackEnabled then
        local c = GetCharacter()
        if c then
            local h = GetHumanoid(c)
            if h and h.Health > 0 then
                h.WalkSpeed = SpeedValue
            end
        end
    end
end

local FOVEnabled = false; local FOVValue = 120; local FOVConnection = nil
function ToggleFOV(enabled)
    if type(enabled) ~= "boolean" then
        enabled = not FOVEnabled
    end
    FOVEnabled = enabled
    local cam = workspace.CurrentCamera
    if enabled then
        cam.FieldOfView = FOVValue
        if not FOVConnection then
            FOVConnection = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
                if FOVEnabled then
                    cam.FieldOfView = FOVValue
                end
            end)
        end
        Notify("FOV","Enabled - "..FOVValue,3)
    else
        if FOVConnection then
            FOVConnection:Disconnect()
            FOVConnection = nil
        end
        cam.FieldOfView = 70
        Notify("FOV","Disabled",3)
    end
    PlayBell()
end
function SetFOV(v)
    FOVValue = math.min(v, 120)
    if FOVEnabled then
        workspace.CurrentCamera.FieldOfView = FOVValue
    end
end

local InstInteractEnabled = false; local InstInteractConn = nil
function ToggleInstantInteract(enabled)
    InstInteractEnabled = enabled
    if enabled then
        for _,o in pairs(Workspace:GetDescendants()) do
            if o:IsA("ProximityPrompt") then
                o.HoldDuration = 0
            end
        end
        InstInteractConn = Workspace.DescendantAdded:Connect(function(o)
            if o:IsA("ProximityPrompt") then
                o.HoldDuration = 0
            end
        end)
        Notify("Instant Interact","Enabled",3)
    else
        if InstInteractConn then
            InstInteractConn:Disconnect()
            InstInteractConn = nil
        end
        Notify("Instant Interact","Disabled",3)
    end
    PlayBell()
end

local ZoneKillEnabled = false; local ZoneKillConn = nil; local ZoneKillCharConn = nil
local ZoneAnimId = "rbxassetid://105341857343164"
local ZonePos = Vector3.new(197.7,54.6,-96.3)
function ToggleZoneKill(enabled)
    if enabled then
        if not CanEnableToggle("LastDinner", "Zone Kill") then
            return false
        end
    end
    if ZoneKillConn then ZoneKillConn:Disconnect() end
    if ZoneKillCharConn then ZoneKillCharConn:Disconnect() end
    ZoneKillEnabled = enabled
    if enabled then
        local function setup(char)
            local h = char:WaitForChild("Humanoid")
            ZoneKillConn = h.AnimationPlayed:Connect(function(track)
                if track.Animation and track.Animation.AnimationId == ZoneAnimId then
                    local orig = char:GetPrimaryPartCFrame()
                    char:SetPrimaryPartCFrame(CFrame.new(ZonePos))
                    track.Stopped:Connect(function()
                        task.wait(0.6)
                        if orig then char:SetPrimaryPartCFrame(orig) end
                    end)
                end
            end)
        end
        if LocalPlayer.Character then setup(LocalPlayer.Character) end
        ZoneKillCharConn = LocalPlayer.CharacterAdded:Connect(function(char) task.wait(1); setup(char) end)
        Notify("Zone Kill","Enabled",2)
    else
        Notify("Zone Kill","Disabled",2)
    end
    PlayBell()
    return true
end

local VoidKillEnabled = false; local VoidKillConn = nil; local VoidKillCharConn = nil
local VoidAnimIds = {"rbxassetid://107989020363293","rbxassetid://71619354165195"}
local VoidZonePos = Vector3.new(-95.1,964.6,67.6)
function ToggleVoidKill(enabled)
    if enabled then
        if not CanEnableToggle("SkySquidGame", "Void Kill") then
            return false
        end
    end
    if VoidKillConn then VoidKillConn:Disconnect() end
    if VoidKillCharConn then VoidKillCharConn:Disconnect() end
    VoidKillEnabled = enabled
    if enabled then
        local function setup(char)
            local h = char:WaitForChild("Humanoid")
            VoidKillConn = h.AnimationPlayed:Connect(function(track)
                if track.Animation and table.find(VoidAnimIds, track.Animation.AnimationId) then
                    local orig = char:GetPrimaryPartCFrame()
                    local platform = Instance.new("Part")
                    platform.Name = "VoidKillAntiFall"
                    platform.Size = Vector3.new(10,1,10)
                    platform.Position = VoidZonePos + Vector3.new(0,-4,0)
                    platform.Anchored = true
                    platform.CanCollide = true
                    platform.Transparency = 1
                    platform.Parent = workspace
                    char:SetPrimaryPartCFrame(CFrame.new(VoidZonePos.X, VoidZonePos.Y, VoidZonePos.Z))
                    track.Stopped:Connect(function()
                        task.wait(1)
                        if orig then char:SetPrimaryPartCFrame(orig) end
                        platform:Destroy()
                    end)
                end
            end)
        end
        if LocalPlayer.Character then setup(LocalPlayer.Character) end
        VoidKillCharConn = LocalPlayer.CharacterAdded:Connect(function(char) task.wait(1); setup(char) end)
        Notify("Void Kill","Enabled",2)
    else
        Notify("Void Kill","Disabled",2)
    end
    PlayBell()
    return true
end

local MingleVoidKillEnabled = false; local MingleConns = {}
local MingleAnimId = "rbxassetid://71318091779666"
function ToggleMingleVoidKill(enabled)
    if enabled then
        if not CanEnableToggle("Mingle", "Void Kill") then
            return false
        end
    end
    for _,c in pairs(MingleConns) do pcall(function() c:Disconnect() end) end
    MingleConns = {}
    MingleVoidKillEnabled = enabled
    if enabled then
        local platform = nil
        local origPos = nil
        local function setup(char)
            local h = char:WaitForChild("Humanoid")
            local conn = h.AnimationPlayed:Connect(function(track)
                if track.Animation and track.Animation.AnimationId == MingleAnimId then
                    local rp = char:FindFirstChild("HumanoidRootPart")
                    if rp then
                        origPos = rp.Position
                        if platform then platform:Destroy() end
                        platform = Instance.new("Part")
                        platform.Name = "MingleSafetyPlatform"
                        platform.Size = Vector3.new(100,10,100)
                        platform.Position = Vector3.new(origPos.X, origPos.Y-30, origPos.Z)
                        platform.Anchored = true
                        platform.CanCollide = true
                        platform.Transparency = 0.8
                        platform.Color = Color3.fromRGB(0,170,255)
                        platform.Material = Enum.Material.Neon
                        platform.Parent = workspace
                        rp.CFrame = CFrame.new(platform.Position.X, platform.Position.Y+3, platform.Position.Z)
                        track.Stopped:Connect(function()
                            task.wait(0.6)
                            if origPos then rp.CFrame = CFrame.new(origPos) end
                            if platform then platform:Destroy(); platform=nil end
                        end)
                    end
                end
            end)
            table.insert(MingleConns, conn)
        end
        if LocalPlayer.Character then setup(LocalPlayer.Character) end
        table.insert(MingleConns, LocalPlayer.CharacterAdded:Connect(function(char) task.wait(1); setup(char) end))
        Notify("Void Kill","Enabled",2)
    else
        Notify("Void Kill","Disabled",2)
    end
    PlayBell()
    return true
end

local SkySquidAntiFall = {Enabled=false, Platform=nil, Conn=nil}
function ToggleSkySquidAntiFall(enabled)
    if enabled then
        if not CanEnableToggle("SkySquidGame", "Anti Fall") then
            return false
        end
    end
    if SkySquidAntiFall.Conn then SkySquidAntiFall.Conn:Disconnect() end
    if SkySquidAntiFall.Platform then SkySquidAntiFall.Platform:Destroy() end
    SkySquidAntiFall.Enabled = enabled
    if enabled then
        local function create()
            local c = GetCharacter()
            if not c then return nil end
            local rp = GetRootPart(c)
            if not rp then return nil end
            local p = Instance.new("Part")
            p.Name = "SkySquidAntiFall"
            p.Size = Vector3.new(10000,1,10000)
            p.Position = Vector3.new(rp.Position.X, rp.Position.Y-5, rp.Position.Z)
            p.Anchored = true
            p.CanCollide = true
            p.Transparency = 1
            p.Parent = workspace
            return p
        end
        SkySquidAntiFall.Platform = create()
        SkySquidAntiFall.Conn = RunService.Heartbeat:Connect(function()
            if not SkySquidAntiFall.Enabled then return end
            if not IsGameActive("SkySquidGame") then
                DisableToggle("SkySquidAntiFall")
                return
            end
            if not (SkySquidAntiFall.Platform and SkySquidAntiFall.Platform.Parent) then
                SkySquidAntiFall.Platform = create()
            end
        end)
        Notify("AntiFall","Enabled",3)
    else
        Notify("AntiFall","Disabled",2)
    end
    PlayBell()
    return true
end

local FullbrightEnabled = false
function ToggleFullbright(enabled)
    FullbrightEnabled = enabled
    local Lighting = game:GetService("Lighting")
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Notify("Fullbright", "Enabled", 3)
    else
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Notify("Fullbright", "Disabled", 3)
    end
    PlayBell()
end

local currentAnim = nil; local currentSound = nil
local function stopEmote()
    if currentAnim then currentAnim:Stop(); currentAnim = nil end
    if currentSound then currentSound:Stop(); currentSound:Destroy(); currentSound = nil end
end
function PlayDreamJournal()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://117325441970867"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://88476306353688"
        s.Volume = 10
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","Dream Journal",2)
        PlayBell()
    end
end
function PlayOtsukareSummer()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://134888005420629"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://127332409398776"
        s.Volume = 3
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","Otsukare Summer",2)
        PlayBell()
    end
end

function PlaySpite()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://100382123964355"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://90513005423910"
        s.Volume = 5
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","Spite",2)
        PlayBell()
    end
end

function PlayShuffle()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://113121578988536"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        
        local soundIds = {
            "rbxassetid://18278587259",
            "rbxassetid://104805805321503",
            "rbxassetid://127426881747595"
        }
        local randomSoundId = soundIds[math.random(1, #soundIds)]
        
        local s = Instance.new("Sound")
        s.SoundId = randomSoundId
        s.Volume = 5
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","Shuffle",2)
        PlayBell()
    end
end

function PlayYareYare()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://86642655479570"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://128193072645447"
        s.Volume = 5
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","Yare Yare",2)
        PlayBell()
    end
end

function PlayPerfectVictory()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://110501561372722"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://104280886491008"
        s.Volume = 5
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","My Perfect Victory",2)
        PlayBell()
    end
end

function PlayPosingTime()
    stopEmote()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://89240795237958"
    local h = GetHumanoid(GetCharacter())
    if h then
        currentAnim = h:LoadAnimation(anim)
        currentAnim:Play()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://113259086406604"
        s.Volume = 1
        s.Looped = true
        s.Parent = SoundService
        s:Play()
        currentSound = s
        Notify("Emote","Posing Time",2)
        PlayBell()
    end
end
function StopAllEmotes()
    stopEmote()
    Notify("Emote","All emotes stopped",2)
    PlayBell()
end

function RLGL_TP_End()
    if IsGameActive("RedLightGreenLight") then
        SafeTeleport(Vector3.new(-214.4,1023.1,146.7))
        Notify("RLGL","Teleported to End",2)
    else
        Notify("RLGL","Wait for RedLightGreenLight!",2)
    end
    PlayBell()
end

local GodModeEnabled = false; local GodModeConn = nil; local GodModeOrigY = nil
function ToggleGodMode(enabled)
    if enabled then
        if not CanEnableToggle("RedLightGreenLight", "God Mode") then
            return false
        end
    end
    if enabled then
        if GodModeConn then GodModeConn:Disconnect(); GodModeConn = nil end
        GodModeEnabled = true
        local c = GetCharacter()
        if not c then Notify("GodMode","Character not found",2); GodModeEnabled=false; PlayBell(); return false end
        local rp = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
        if rp then
            GodModeOrigY = rp.Position.Y
            SafeTeleport(Vector3.new(rp.Position.X, rp.Position.Y+170, rp.Position.Z))
            Notify("GodMode","Enabled",2)
        end
        GodModeConn = RunService.Heartbeat:Connect(function()
            if GodModeEnabled and not IsGameActive("RedLightGreenLight") then
                DisableToggle("GodMode")
            end
        end)
    else
        GodModeEnabled = false
        if GodModeConn then GodModeConn:Disconnect(); GodModeConn = nil end
        if GodModeOrigY then
            local c = GetCharacter()
            if c then
                local rp = c:FindFirstChild("HumanoidRootPart")
                if rp then SafeTeleport(Vector3.new(rp.Position.X, GodModeOrigY, rp.Position.Z)) end
            end
        end
        GodModeOrigY = nil
        Notify("GodMode","Disabled",2)
    end
    PlayBell()
    return true
end

local noclipEnabled = false
local noclipButton = nil
local TELEPORT_DISTANCE = 13
local RAY_LENGTH = 6

local function createNoclipButton()
    if noclipButton then noclipButton:Destroy() end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NoclipButton"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 0, 80)
    button.Position = UDim2.new(1, -100, 0, 100)
    button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    button.BackgroundTransparency = 0.5
    button.Text = "TP"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 20
    button.Font = Enum.Font.GothamBold
    button.Parent = screenGui
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Parent = button
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
        end
    end)
    
    button.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        teleportThroughWall()
    end)
    
    noclipButton = screenGui
    return screenGui
end

local function teleportThroughWall()
    if not noclipEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local direction = cam.CFrame.LookVector
    local origin = root.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {char}
    rayParams.IgnoreWater = true
    local rayResult = workspace:Raycast(origin, direction * RAY_LENGTH, rayParams)
    local targetPos = origin + (direction * TELEPORT_DISTANCE)
    if rayResult then
        local hitPos = rayResult.Position
        local normal = rayResult.Normal
        targetPos = hitPos + (direction * 3) + (normal * 2)
    end
    root.CanCollide = false
    root.CFrame = CFrame.new(targetPos)
    task.wait()
    root.CanCollide = true
end

local desyncHooked = false
local desyncAvailable = pcall(function() return raknet and raknet.add_send_hook end)

local function rakhook(packet)
    if packet.PacketId == 0x1B then
        local buf = packet.AsBuffer
        if buffer and buffer.writeu32 then
            buffer.writeu32(buf, 1, 0xFFFFFFFF)
            packet:SetData(buf)
        end
    end
end

local function ToggleDesync(enabled)
    if enabled and IsXenoExecutor() then
        Notify("HollyScriptX [BETA]", "This Feature cannot be enabled in your executor :c", 5)
        return false
    end
    if not desyncAvailable then
        Notify("Desync", "Unsupported Executor :c", 3)
        return false
    end
    if enabled then
        if not desyncHooked then 
            pcall(function()
                raknet.add_send_hook(rakhook)
                desyncHooked = true
                Notify("Desync","Enabled",3)
            end)
        end
    else
        if desyncHooked then 
            pcall(function()
                raknet.remove_send_hook(rakhook)
                desyncHooked = false
                Notify("Desync","Disabled",3)
            end)
        end
    end
    return true
end

local PlayerAttachEnabled = false
local attachedTarget = nil
local attachConnection = nil
local bodyPosition = nil
local bodyVelocity = nil

local function createBodyPosition(rootPart)
    if bodyPosition then bodyPosition:Destroy() end
    if bodyVelocity then bodyVelocity:Destroy() end
    bodyPosition = Instance.new("BodyPosition")
    bodyPosition.MaxForce = Vector3.new(40000, 40000, 40000)
    bodyPosition.P = 20000
    bodyPosition.D = 1000
    bodyPosition.Parent = rootPart
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
    bodyVelocity.P = 20000
    bodyVelocity.Parent = rootPart
    return bodyPosition
end

local function attachToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    if attachedTarget then detach() end
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    if not myHRP or not myHum then return false end
    myHum.PlatformStand = true
    myHum.AutoRotate = false
    createBodyPosition(myHRP)
    attachedTarget = targetPlayer
    attachConnection = RunService.Heartbeat:Connect(function()
        if not attachedTarget or not attachedTarget.Character then detach(); return end
        local targetChar = attachedTarget.Character
        local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetHRP and myHRP and bodyPosition then
            local behindPos = targetHRP.CFrame * CFrame.new(0,0,-3.5)
            bodyPosition.Position = behindPos.Position
            bodyVelocity.Velocity = targetHRP.AssemblyLinearVelocity
        end
    end)
    return true
end

local function detach()
    if attachConnection then attachConnection:Disconnect(); attachConnection = nil end
    if bodyPosition then bodyPosition:Destroy(); bodyPosition = nil end
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    local myChar = LocalPlayer.Character
    if myChar then
        local myHum = myChar:FindFirstChildOfClass("Humanoid")
        if myHum then
            myHum.PlatformStand = false
            myHum.AutoRotate = true
        end
    end
    attachedTarget = nil
end

local function getNearestPlayer()
    local nearest = nil
    local nearestDist = 30
    local myChar = LocalPlayer.Character
    local myPos = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myPos then return nil end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local plrRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            if plrRoot then
                local dist = (myPos.Position - plrRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = plr
                end
            end
        end
    end
    return nearest
end

local function getNearestPlayerAnywhere()
    local nearest = nil
    local nearestDist = math.huge
    local myChar = LocalPlayer.Character
    local myPos = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myPos then return nil end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local plrRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            if plrRoot then
                local dist = (myPos.Position - plrRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = plr
                end
            end
        end
    end
    return nearest
end

function TogglePlayerAttach(enabled)
    PlayerAttachEnabled = enabled
    if enabled then
        local nearest = getNearestPlayer()
        if nearest then 
            attachToPlayer(nearest)
            Notify("Player Attach","Attached to: "..nearest.Name,2)
            PlayBell()
        else 
            Notify("Player Attach","No players near",2)
            PlayBell()
            PlayerAttachEnabled = false
        end
    else
        detach()
        Notify("Player Attach","Disabled",2)
        PlayBell()
    end
end

local function teleportToNearest()
    local nearest = getNearestPlayerAnywhere()
    if nearest and nearest.Character then
        local root = nearest.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local myChar = LocalPlayer.Character
            if myChar then
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    myRoot.CFrame = CFrame.new(root.Position + Vector3.new(0, 3, 0))
                    Notify("Teleport", "Teleported to: " .. nearest.Name, 2)
                    PlayBell()
                end
            end
        end
    else
        Notify("Teleport", "No players near", 2)
        PlayBell()
    end
end

local function loadCursor()
    local player = LocalPlayer
    local mouse = player:GetMouse()
    local screenGui, aimContainer, topLine, bottomLine, leftLine, rightLine, textLabel
    local time = 0
    local rotationProgress = 0
    local currentRotationSpeed = 0.8
    local smoothedRotation = 5
    local lineThickness = 3
    local baseRotationSpeed = 0.8
    local pulseSpeed = 2.5
    local minLength = -10
    local maxLength = -30
    local function createLine(parent, size, position, color)
        local frame = Instance.new("Frame")
        frame.Size = size
        frame.Position = position
        frame.BackgroundColor3 = color
        frame.BorderSizePixel = 0
        frame.ZIndex = 5
        frame.Parent = parent
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.new(0,0,0)
        stroke.Thickness = 1
        stroke.Parent = frame
        return frame
    end
    local function createTextLabel(parent, text, position, color, font, scaled)
        local label = Instance.new("TextLabel")
        label.Text = text
        label.Position = position
        label.TextColor3 = color
        label.Font = font
        label.TextScaled = scaled
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0, 150, 0, 23)
        label.ZIndex = 10
        label.Parent = parent
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        stroke.Color = Color3.new(0,0,0)
        stroke.Thickness = 1
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = label
        return label
    end
    local function clearGui()
        if screenGui then screenGui:Destroy() end
    end
    local function createGui()
        clearGui()
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "HollyScriptX_Cursor"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = player:WaitForChild("PlayerGui")
        aimContainer = Instance.new("Frame")
        aimContainer.BackgroundTransparency = 1
        aimContainer.Size = UDim2.new(0, 25, 0, 25)
        aimContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        aimContainer.Parent = screenGui
        topLine = createLine(aimContainer, UDim2.new(0, lineThickness, 0, 25), UDim2.new(0.5, -lineThickness/2, 0, 0), Color3.new(1,1,1))
        bottomLine = createLine(aimContainer, UDim2.new(0, lineThickness, 0, 25), UDim2.new(0.5, -lineThickness/2, 1, -25), Color3.new(1,1,1))
        leftLine = createLine(aimContainer, UDim2.new(0, 25, 0, lineThickness), UDim2.new(0, 0, 0.5, -lineThickness/2), Color3.new(1,1,1))
        rightLine = createLine(aimContainer, UDim2.new(0, 25, 0, lineThickness), UDim2.new(1, -25, 0.5, -lineThickness/2), Color3.new(1,1,1))
        textLabel = createTextLabel(screenGui, "HollyScriptX", UDim2.new(0, 0, 0, 0), Color3.new(1,1,1), Enum.Font.Arcade, true)
    end
    local function getRainbowColor(t)
        local r = math.sin(t * 0.6) * 0.5 + 0.5
        local g = math.sin(t * 0.6 + 2) * 0.5 + 0.5
        local b = math.sin(t * 0.6 + 4) * 0.5 + 0.5
        return Color3.new(r, g, b)
    end
    local function calculateRotationSpeed(progress)
        local slowdownStart = 0.6
        local slowdownDuration = 0.35
        local minSlowdownSpeed = 0.3
        if progress >= slowdownStart then
            local slowdownProgress = (progress - slowdownStart) / slowdownDuration
            local easedProgress = slowdownProgress * slowdownProgress
            local slowdownFactor = 1 - (easedProgress * (1 - minSlowdownSpeed))
            return baseRotationSpeed * math.max(slowdownFactor, minSlowdownSpeed)
        else
            return baseRotationSpeed
        end
    end
    local function smoothRotation(currentRot, targetRot, smoothing)
        return currentRot + (targetRot - currentRot) * smoothing
    end
    local function smoothPulse(t, speed)
        local rawPulse = math.sin(t * speed) * 0.5 + 0.5
        return rawPulse * rawPulse
    end
    local function onCharacterAdded()
        createGui()
    end
    if player.Character then
        onCharacterAdded()
    else
        player.CharacterAdded:Connect(onCharacterAdded)
    end
    RunService.RenderStepped:Connect(function(deltaTime)
        if not aimContainer then return end
        time = time + deltaTime
        aimContainer.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
        textLabel.Position = UDim2.new(0, mouse.X - 70, 0, mouse.Y + 50)
        rotationProgress = (rotationProgress + currentRotationSpeed * deltaTime) % 1
        currentRotationSpeed = calculateRotationSpeed(rotationProgress)
        local targetRotation = rotationProgress * 360
        smoothedRotation = smoothRotation(smoothedRotation, targetRotation, 1)
        aimContainer.Rotation = smoothedRotation
        local pulse = smoothPulse(time, pulseSpeed)
        local currentLength = minLength + (maxLength - minLength) * pulse
        topLine.Size = UDim2.new(0, lineThickness, 0, currentLength)
        bottomLine.Size = UDim2.new(0, lineThickness, 0, currentLength)
        leftLine.Size = UDim2.new(0, currentLength, 0, lineThickness)
        rightLine.Size = UDim2.new(0, currentLength, 0, lineThickness)
        topLine.Position = UDim2.new(0.5, -lineThickness/2, 0, 0)
        bottomLine.Position = UDim2.new(0.5, -lineThickness/2, 1, -currentLength)
        leftLine.Position = UDim2.new(0, 0, 0.5, -lineThickness/2)
        rightLine.Position = UDim2.new(1, -currentLength, 0.5, -lineThickness/2)
        local rainbowColor = getRainbowColor(time)
        topLine.BackgroundColor3 = rainbowColor
        bottomLine.BackgroundColor3 = rainbowColor
        leftLine.BackgroundColor3 = rainbowColor
        rightLine.BackgroundColor3 = rainbowColor
        textLabel.TextColor3 = rainbowColor
    end)
end

local GameStateMonitor = {
    Connection = nil,
    LastGame = nil
}

function GameStateMonitor:Start()
    if self.Connection then self.Connection:Disconnect() end
    
    self.Connection = RunService.Heartbeat:Connect(function()
        local values = Workspace:FindFirstChild("Values")
        if not values then return end
        local currentGame = values:FindFirstChild("CurrentGame")
        local gameName = currentGame and currentGame.Value
        
        if gameName ~= self.LastGame then
            if self.LastGame then
                self:DisableGameToggles(self.LastGame)
            end
            self.LastGame = gameName
        end
    end)
end

function GameStateMonitor:DisableGameToggles(gameName)
    local toggles = {
        HideAndSeek = {"AutoDodge", "InfiniteStamina", "SpikesKill"},
        JumpRope = {"JumpRopeAntiFall"},
        GlassBridge = {"GlassESP", "AntiBreak"},
        Pentathlon = {"AutoGonggi"},
        LastDinner = {"ZoneKill"},
        SkySquidGame = {"VoidKill", "SkySquidAntiFall"},
        Mingle = {"MingleVoidKill"},
        RedLightGreenLight = {"GodMode"},
        Rebel = {"AutoKillGuards"}
    }
    
    local gameToggles = toggles[gameName]
    if gameToggles then
        for _, toggleName in ipairs(gameToggles) do
            DisableToggle(toggleName)
        end
    end
end

GameStateMonitor:Start()

local Window = Library:CreateWindow({
    Title = "HollyScriptX",
    Icon = "diamond-percent",
    Footer = "Ink Game | HollyScriptX.lua",
    Center = true,
    AutoShow = true,
    ShowCustomCursor = false,
    ShowToggleButton = true,
    ToggleKeybind = nil
})

guiCreated = true

for _, notif in ipairs(pendingNotifications) do
    Library:Notify({Title = notif.title, Description = notif.text, Duration = notif.duration})
end
pendingNotifications = {}

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("HollyScriptX")
end

if IsMobile() then
    Library:SetDPIScale(0.7)
end

if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:SetFolder("HollyScriptX")
    SaveManager:IgnoreThemeSettings()
end

local MainTab = Window:AddTab("Main", "warehouse")
local MainPlayer = MainTab:AddLeftGroupbox("Player", "user")
local MainCombat = MainTab:AddLeftGroupbox("Combat Features", "sword")
local MainExtras = MainTab:AddLeftGroupbox("Extra Features", "sparkles")
local MainTeleports = MainTab:AddRightGroupbox("Teleports", "rocket")
local MainEmotes = MainTab:AddRightGroupbox("Emotes", "music")

local GuardsTab = Window:AddTab("Guards", "shield")
local GuardsLeft = GuardsTab:AddLeftGroupbox("Hitbox & Fire")
local GuardsRight = GuardsTab:AddRightGroupbox("Ammo & Guard")

local GamepassTab = Window:AddTab("GamePass", "crown")
local GPGroup = GamepassTab:AddLeftGroupbox("Unlockers")

local GamesTab = Window:AddTab("Games", "gamepad")
local RLGLGroup = GamesTab:AddLeftGroupbox("Red Light Green Light", "lightbulb")
local DalgonaGroup = GamesTab:AddRightGroupbox("Dalgona", "cookie")
local PentathlonGroup = GamesTab:AddLeftGroupbox("Pentathlon", "gamepad")
local HNSLeft = GamesTab:AddLeftGroupbox("Hide And Seek", "eye")
local JumpLeft = GamesTab:AddLeftGroupbox("Jump Rope", "arrow-up")
local GlassLeft = GamesTab:AddLeftGroupbox("Glass Bridge", "circuit-board")
local MingleGroup = GamesTab:AddLeftGroupbox("Mingle", "users")
local DinnerGroup = GamesTab:AddRightGroupbox("Last Dinner", "utensils")
local SquidLeft = GamesTab:AddLeftGroupbox("Sky Squid", "cloud")
local RebelGroup = GamesTab:AddRightGroupbox("Rebel", "flag")

local SettingsTab = Window:AddTab("Settings", "paintbrush")
local SettingsLeft = SettingsTab:AddLeftGroupbox("Theme & UI")
local KeybindsGroup = SettingsTab:AddRightGroupbox("Keybinds", "keyboard")

ToggleRefs.SpeedHack = MainPlayer:AddToggle("SpeedHack", {Text="Speed Hack", Default=false, Callback=ToggleSpeedHack})
MainPlayer:AddSlider("SpeedValue", {Text="Speed Value", Default=39, Min=16, Max=40, Callback=SetSpeedValue})
ToggleRefs.FOVChanger = MainPlayer:AddToggle("FOVChanger", {Text="FOV Changer", Default=false, Callback=ToggleFOV})
MainPlayer:AddSlider("FOVValue", {Text="FOV Value", Default=120, Min=70, Max=120, Callback=SetFOV})
ToggleRefs.Fullbright = MainPlayer:AddToggle("Fullbright", {Text="Fullbright", Default=false, Callback=ToggleFullbright})
ToggleRefs.RemoveStun = MainPlayer:AddToggle("RemoveStun", {Text="Remove Stun", Default=false, Callback=ToggleRemoveStun})
ToggleRefs.InstantInteract = MainPlayer:AddToggle("InstantInteract", {Text="Instant Interact", Default=false, Callback=ToggleInstantInteract})
ToggleRefs.Flight = MainPlayer:AddToggle("Flight", {Text="Flight", Default=false, Callback=ToggleFly})

ToggleRefs.PlayerAttach = MainCombat:AddToggle("PlayerAttach", {Text="Player Attach", Default=false, Callback=TogglePlayerAttach})
ToggleRefs.FaceTarget = MainCombat:AddToggle("FaceTarget", {Text="Face Target", Default=false, Callback=ToggleFaceTarget})
ToggleRefs.Desync = MainCombat:AddToggle("Desync", {Text="Desync", Default=false, Callback=ToggleDesync})

ToggleRefs.AutoQTE = MainExtras:AddToggle("AutoQTE", {Text="Auto QTE", Default=false, Callback=ToggleAutoQTE})
ToggleRefs.FreeDash = MainExtras:AddToggle("FreeDash", {Text="Free Dash", Default=false, Callback=ToggleFreeDash})
ToggleRefs.Noclip = MainExtras:AddToggle("Noclip", {Text="TP Through Walls", Default=false, Callback=function(state) 
    noclipEnabled = state
    if state then
        if IsMobile() then createNoclipButton() end
    else
        if noclipButton then noclipButton:Destroy() end
    end
end})
ToggleRefs.AutoSafe = MainExtras:AddToggle("AutoSafe", {Text="Auto Safe (30 HP)", Default=false, Callback=ToggleAutoSafe})
ToggleRefs.AutoNextGame = MainExtras:AddToggle("AutoNextGame", {Text="Auto Next Game", Default=false, Callback=ToggleAutoNextGame})
ToggleRefs.PlayerESP = MainExtras:AddToggle("PlayerESP", {Text="Players ESP", Default=false, Callback=ToggleESP})

MainTeleports:AddButton("Teleport Up 100", TeleportUp)
MainTeleports:AddButton("Teleport Down 40", TeleportDown)
MainTeleports:AddButton("Teleport to Nearest", teleportToNearest)
MainTeleports:AddButton("Spectate Nearest", function()
    local nearest = getNearestPlayerAnywhere()
    if nearest and nearest.Character then
        workspace.CurrentCamera.CameraSubject = nearest.Character:FindFirstChildOfClass("Humanoid")
        Notify("Spectate", "Spectating: " .. nearest.Name, 2)
    else
        Notify("Spectate", "No players near", 2)
    end
    PlayBell()
end)
MainTeleports:AddButton("Stop Spectating", function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            workspace.CurrentCamera.CameraSubject = hum
            Notify("Spectate", "Stopped", 2)
        end
    end
    PlayBell()
end)

MainEmotes:AddButton("Play Dream Journal", PlayDreamJournal)
MainEmotes:AddButton("Play Otsukare Summer", PlayOtsukareSummer)
MainEmotes:AddButton("Play Spite", PlaySpite)
MainEmotes:AddButton("Play Posing Time", PlayPosingTime)
MainEmotes:AddButton("Play Shuffle", PlayShuffle)
MainEmotes:AddButton("Play Yare Yare", PlayYareYare)
MainEmotes:AddButton("My Perfect Victory", PlayPerfectVictory)
MainEmotes:AddButton("Stop All Emotes", StopAllEmotes)

ToggleRefs.HitboxExpander = GuardsLeft:AddToggle("HitboxExpander", {Text="Hitbox Expander", Default=false, Callback=ToggleHitboxExpander})
GuardsLeft:AddSlider("HitboxSize", {Text="Hitbox Size", Default=50, Min=10, Max=999, Callback=SetHitboxSize})
ToggleRefs.RapidFire = GuardsLeft:AddToggle("RapidFire", {Text="Rapid Fire", Default=false, Callback=ToggleRapidFire})
ToggleRefs.InfiniteAmmo = GuardsRight:AddToggle("InfiniteAmmo", {Text="Infinite Ammo", Default=false, Callback=ToggleInfiniteAmmo})
ToggleRefs.FreeGuard = GuardsRight:AddToggle("FreeGuard", {Text="Free Guard", Default=false, Callback=ToggleFreeGuard})

ToggleRefs.PermanentGuard = GPGroup:AddToggle("PermanentGuard", {Text="Permanent Guard", Default=false, Callback=TogglePermanentGuard})
ToggleRefs.GlassVision = GPGroup:AddToggle("GlassVision", {Text="Glass Vision", Default=false, Callback=ToggleGlassVision})
ToggleRefs.EmotePages = GPGroup:AddToggle("EmotePages", {Text="Emote Pages", Default=false, Callback=ToggleEmotePages})
ToggleRefs.CustomPlayerTag = GPGroup:AddToggle("CustomPlayerTag", {Text="Custom Player Tag", Default=false, Callback=ToggleCustomPlayerTag})
ToggleRefs.PrivateServerPlus = GPGroup:AddToggle("PrivateServerPlus", {Text="Private Server Plus", Default=false, Callback=TogglePrivateServerPlus})
ToggleRefs.FreeVIP = GPGroup:AddToggle("FreeVIP", {Text="Free VIP", Default=false, Callback=ToggleFreeVIP})

RLGLGroup:AddButton("Teleport to End", RLGL_TP_End)
ToggleRefs.GodMode = RLGLGroup:AddToggle("GodMode", {Text="God Mode", Default=false, Callback=ToggleGodMode})

DalgonaGroup:AddButton("Get Lighter", Dalgona_Lighter)

ToggleRefs.AutoGonggi = PentathlonGroup:AddToggle("AutoGonggi", {Text="Auto Gonggi", Default=false, Callback=ToggleAutoGonggi})

ToggleRefs.InfiniteStamina = HNSLeft:AddToggle("InfiniteStamina", {Text="Infinite Stamina", Default=false, Callback=ToggleInfiniteStamina})
ToggleRefs.SpikesKill = HNSLeft:AddToggle("SpikesKill", {Text="Spikes Kill", Default=false, Callback=ToggleSpikesKill})
HNSLeft:AddButton("Teleport to Hider", TeleportToHider)
ToggleRefs.AutoDodge = HNSLeft:AddToggle("AutoDodge", {Text="Auto Dodge", Default=false, Callback=ToggleAutoDodge})

ToggleRefs.JumpRopeAntiFall = JumpLeft:AddToggle("AntiFall", {Text="Anti Fall", Default=false, Callback=ToggleJumpRopeAntiFall})
JumpLeft:AddButton("Remove Rope", JR_DeleteRope)
JumpLeft:AddButton("Teleport to Start", JR_TP_Start)
JumpLeft:AddButton("Teleport to End", JR_TP_End)

ToggleRefs.AntiBreak = GlassLeft:AddToggle("AntiBreak", {Text="Anti Break", Default=false, Callback=ToggleAntiBreak})
GlassLeft:AddButton("Teleport to End", GB_TP_End)
ToggleRefs.GlassESP = GlassLeft:AddToggle("GlassESP", {Text="Glass ESP", Default=false, Callback=ToggleGlassESP})

ToggleRefs.MingleVoidKill = MingleGroup:AddToggle("VoidKill", {Text="Void Kill", Default=false, Callback=ToggleMingleVoidKill})

ToggleRefs.ZoneKill = DinnerGroup:AddToggle("ZoneKill", {Text="Zone Kill", Default=false, Callback=ToggleZoneKill})

ToggleRefs.SkySquidAntiFall = SquidLeft:AddToggle("AntiFall", {Text="Anti Fall", Default=false, Callback=ToggleSkySquidAntiFall})
ToggleRefs.VoidKill = SquidLeft:AddToggle("VoidKill", {Text="Void Kill", Default=false, Callback=ToggleVoidKill})

ToggleRefs.AutoKillGuards = RebelGroup:AddToggle("AutoKillGuards", {Text="Auto Kill Guards", Default=false, Callback=ToggleRebel})

SettingsLeft:AddDropdown("DPIDropdown", {
    Callback = function(Value)
        local Scale = tonumber(Value:gsub("%%", ""))
        Library:SetDPIScale(Scale / 100)
    end,
    Text = "DPI Scale",
    Default = "100%",
    Values = {"50%", "75%", "100%", "125%", "150%", "175%", "200%"}
})

SettingsLeft:AddLabel("Menu Keybind"):AddKeyPicker("MenuBind", {
    Default = "Z",
    NoUI = true,
    Text = "Menu Keybind",
    Callback = function(k) Window:SetToggleKeybind(k) end
})

KeybindsGroup:AddLabel("Flight"):AddKeyPicker("FlightBind", {
    Default = "F",
    Text = "Flight",
    Mode = "Toggle",
    Callback = function(Value)
        ToggleFly(Value)
        if ToggleRefs.Flight then ToggleRefs.Flight:SetValue(Value) end
    end
})

KeybindsGroup:AddLabel("Face Target"):AddKeyPicker("FaceTargetBind", {
    Default = "R",
    Text = "Face Target",
    Mode = "Toggle",
    Callback = function(Value)
        ToggleFaceTarget(Value)
        if ToggleRefs.FaceTarget then ToggleRefs.FaceTarget:SetValue(Value) end
    end
})

KeybindsGroup:AddLabel("Desync"):AddKeyPicker("DesyncBind", {
    Default = "U",
    Text = "Desync",
    Mode = "Toggle",
    Callback = function(Value)
        ToggleDesync(Value)
        if ToggleRefs.Desync then ToggleRefs.Desync:SetValue(Value) end
    end
})

KeybindsGroup:AddLabel("Player Attach"):AddKeyPicker("AttachBind", {
    Default = "V",
    Text = "Player Attach",
    Mode = "Toggle",
    Callback = function(Value)
        TogglePlayerAttach(Value)
        if ToggleRefs.PlayerAttach then ToggleRefs.PlayerAttach:SetValue(Value) end
    end
})

KeybindsGroup:AddLabel("Teleport Nearest"):AddKeyPicker("TPNearestBind", {
    Default = "G",
    Text = "TP To Nearest",
    Mode = "Press",
    Callback = function()
        teleportToNearest()
    end
})

SettingsLeft:AddButton("Unload Script", function()
    for name, toggle in pairs(ToggleRefs) do
        if toggle and toggle.SetValue then
            pcall(function() toggle:SetValue(false) end)
        end
    end
    
    ToggleFly(false)
    ToggleFaceTarget(false)
    ToggleDesync(false)
    TogglePlayerAttach(false)
    ToggleESP(false)
    ToggleSpeedHack(false)
    ToggleFOV(false)
    ToggleFullbright(false)
    ToggleRemoveStun(false)
    ToggleAutoQTE(false)
    ToggleFreeDash(false)
    ToggleAutoSafe(false)
    ToggleAutoNextGame(false)
    ToggleHitboxExpander(false)
    ToggleRapidFire(false)
    ToggleInfiniteAmmo(false)
    ToggleFreeGuard(false)
    TogglePermanentGuard(false)
    ToggleGlassVision(false)
    ToggleEmotePages(false)
    ToggleCustomPlayerTag(false)
    TogglePrivateServerPlus(false)
    ToggleFreeVIP(false)
    ToggleGodMode(false)
    ToggleAutoGonggi(false)
    ToggleInfiniteStamina(false)
    ToggleSpikesKill(false)
    ToggleAutoDodge(false)
    ToggleJumpRopeAntiFall(false)
    ToggleAntiBreak(false)
    ToggleGlassESP(false)
    ToggleMingleVoidKill(false)
    ToggleZoneKill(false)
    ToggleSkySquidAntiFall(false)
    ToggleVoidKill(false)
    ToggleRebel(false)
    ToggleInstantInteract(false)
    
    stopEmote()
    detach()
    
    if noclipButton then
        noclipButton:Destroy()
        noclipButton = nil
    end
    
    if ESPFolder then
        ESPFolder:Destroy()
        ESPFolder = nil
    end
    
    for _, obj in pairs(CoreGui:GetChildren()) do
        if obj:IsA("ScreenGui") or obj:IsA("Folder") then
            local name = obj.Name
            if name:find("HollyScriptX") or name:find("Obsidian") or name:find("NoclipButton") then
                pcall(function() obj:Destroy() end)
            end
        end
    end
    
    if Window and Window.Destroy then
        pcall(function() Window:Destroy() end)
    end
    
    Library:Unload()
end)

if ThemeManager then
    ThemeManager:ApplyToTab(SettingsTab)
end

if SaveManager then
    SaveManager:BuildConfigSection(SettingsTab)
end

task.defer(function()
    task.wait(0.5)
    pcall(function()
        Library.Scheme.BackgroundColor = Color3.fromRGB(0, 0, 0)
        Library.Scheme.MainColor = Color3.fromRGB(0, 0, 0)
        Library.Scheme.AccentColor = Color3.fromRGB(255, 255, 255)
        Library.Scheme.OutlineColor = Color3.fromRGB(40, 40, 40)
        Library.Scheme.FontColor = Color3.new(1, 1, 1)
        Library.Scheme.Font = Font.fromEnum(Enum.Font.Gotham)
        if Library.UpdateColorsUsingRegistry then
            Library:UpdateColorsUsingRegistry()
        end
    end)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Keybinds.Flight then
        ToggleFly(not Fly.Enabled)
        if ToggleRefs.Flight then ToggleRefs.Flight:SetValue(Fly.Enabled) end
    elseif key == Keybinds.Noclip then
        if noclipEnabled then teleportThroughWall() end
    elseif key == Keybinds.Desync then
        ToggleDesync(not desyncHooked)
        if ToggleRefs.Desync then ToggleRefs.Desync:SetValue(desyncHooked) end
    elseif key == Keybinds.FaceTarget then
        ToggleFaceTarget()
        if ToggleRefs.FaceTarget then ToggleRefs.FaceTarget:SetValue(FaceTargetModule.Enabled) end
    elseif key == Keybinds.PlayerAttach then
        TogglePlayerAttach(not PlayerAttachEnabled)
        if ToggleRefs.PlayerAttach then ToggleRefs.PlayerAttach:SetValue(PlayerAttachEnabled) end
    elseif key == Keybinds.TeleportNearest then
        teleportToNearest()
    end
end)

loadCursor()
PlayBell()


if IsXenoExecutor() then
    Notify("HollyScriptX [BETA]", "Your Executor can be broken. Use with risk!", 5)
else
    Notify("HollyScriptX [BETA]", "Success Loaded!", 11)
end
