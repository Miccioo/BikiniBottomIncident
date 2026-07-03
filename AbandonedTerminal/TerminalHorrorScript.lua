-- Server Script: Abandoned Bus Terminal Horror & Quest Script (Silent & Pre-Placed NPC/Coin Version)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local terminal = script.Parent
local layout = terminal:WaitForChild("Layout")

-- Remote Event for replication
local remoteEvent = ReplicatedStorage:FindFirstChild("TerminalEvent")
if not remoteEvent then
    remoteEvent = Instance.new("RemoteEvent")
    remoteEvent.Name = "TerminalEvent"
    remoteEvent.Parent = ReplicatedStorage
end

-- References
local counter = layout:WaitForChild("TicketCounterModel")
local exitGate = terminal:WaitForChild("ExitLockChain")
local maintDoorModel = layout:WaitForChild("MaintenanceDoorModel")
local benches = layout:WaitForChild("Benches")

local ticketMachine = counter:WaitForChild("TicketMachine")
local serviceBell = counter:WaitForChild("ServiceBell")

local shadowSilhouette = counter:WaitForChild("ShadowSilhouette")
local bench3 = benches:WaitForChild("Bench3")

-- State handlers
local ticketPrompt = ticketMachine:WaitForChild("ProximityPrompt")
local bellPrompt = serviceBell:WaitForChild("ProximityPrompt")

-- Entrance Door / Wall Exit Button
local exitBtnModel = terminal:WaitForChild("ExitButtonModel")
local exitBtnPrompt = exitBtnModel.ButtonPart.Prompt

exitBtnPrompt.Triggered:Connect(function(player)
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Teleport player outside near BuildingTicket entrance
            hrp.CFrame = CFrame.new(-180, 2.5, 75)
            print("Player clicked exit button and teleported outside")
        end
    end
end)

-- Maintenance Door Button
local maintBtnModel = terminal:WaitForChild("MaintButtonModel")
local maintBtnPart = maintBtnModel.ButtonPart
local maintBtnPrompt = maintBtnPart.Prompt

-- Service Bell Trigger Dialog on Client
bellPrompt.Triggered:Connect(function(player)
    -- Fire to this specific client to start the dialog
    remoteEvent:FireClient(player, "StartDialog")
end)

-- Main Gameplay Event: Ticket Retrieved
ticketPrompt.Triggered:Connect(function(player)
    ticketPrompt.Enabled = false
    terminal:SetAttribute("State", 1)
    
    print("Ticket retrieved by player " .. player.Name)
    
    -- Make the Shadow visible
    shadowSilhouette.Transparency = 0.2
    
    -- Notify all clients to start client-side horror effects
    remoteEvent:FireAllClients("TicketRetrieved")
    
    -- Schedule Maintenance Door opening after 50 seconds
    task.spawn(function()
        task.wait(50)
        
        -- Open Maintenance Door
        terminal:SetAttribute("State", 2)
        
        -- Swing door open
        local hinge = maintDoorModel.Hinge
        local door = maintDoorModel.Door
        local startCF = hinge.CFrame
        for angle = 0, 90, 2 do
            hinge.CFrame = startCF * CFrame.Angles(0, math.rad(-angle), 0)
            door.CFrame = hinge.CFrame * CFrame.new(0, 0, 3)
            task.wait(0.02)
        end
        
        -- Unlock maintenance button next to door
        maintBtnPart.Color = Color3.fromRGB(50, 200, 50) -- Turn Green
        maintBtnPrompt.Enabled = true -- Enable it!
        
        -- Change prompt script to teleport player to a spawn point or next area
        maintBtnPrompt.Triggered:Connect(function(p)
            local character = p.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = hinge.CFrame * CFrame.new(-10, 0, 0)
                end
            end
        end)
        
        -- Notify all clients
        remoteEvent:FireAllClients("EscapePathOpen")
    end)
end)

-- Initialize SpongebobBaru and Coins to be hidden at server startup
local spongebob = workspace:WaitForChild("SpongebobBaru", 10)
if spongebob then
    spongebob:SetAttribute("QuestState", 0)
    spongebob:SetAttribute("CoinCount", 0)
    
    for _, part in ipairs(spongebob:GetDescendants()) do
        if part:IsA("BasePart") then
            if not part:GetAttribute("OriginalTransparency") then
                part:SetAttribute("OriginalTransparency", part.Transparency)
            end
            part.Transparency = 1
            part.CanCollide = false
        end
    end
    
    -- Find TalkPrompt in model descendants
    local talkPrompt = nil
    for _, desc in ipairs(spongebob:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Name == "TalkPrompt" then
            talkPrompt = desc
            break
        end
    end
    if talkPrompt then
        talkPrompt.Enabled = false
    end
end

-- Receive Client messages & Quest Actions
remoteEvent.OnServerEvent:Connect(function(player, action, ...)
    if action == "ShadowSpotted" then
        shadowSilhouette.Transparency = 1
        print("Shadow silhouette spotted and vanished!")
    elseif action == "BenchSpawned" then
        for _, part in ipairs(bench3:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.CanCollide = true
            end
        end
        print("Bench3 materialized behind player!")
    elseif action == "FredDialogFinished" then
        -- Reveal SpongebobBaru in outside world!
        if spongebob then
            for _, part in ipairs(spongebob:GetDescendants()) do
                if part:IsA("BasePart") then
                    local origTrans = part:GetAttribute("OriginalTransparency") or 0
                    part.Transparency = origTrans
                    part.CanCollide = false -- Keep non-collidable so player doesn't get stuck
                end
            end
            
            -- Find TalkPrompt in model descendants
            local talkPrompt = nil
            for _, desc in ipairs(spongebob:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Name == "TalkPrompt" then
                    talkPrompt = desc
                    break
                end
            end
            if talkPrompt then
                talkPrompt.Enabled = true -- Enable dialogue prompt!
                
                -- Setup TalkPrompt listener
                talkPrompt.Triggered:Connect(function(p)
                    local qState = spongebob:GetAttribute("QuestState") or 0
                    local cCount = spongebob:GetAttribute("CoinCount") or 0
                    remoteEvent:FireClient(p, "StartSpongebobDialog", qState, cCount)
                end)
            end
            print("SpongebobBaru NPC revealed outside!")
        end
    elseif action == "ResetGame" then
        -- Reset all quest states so the game can be played again
        if spongebob then
            spongebob:SetAttribute("QuestState", 0)
            spongebob:SetAttribute("CoinCount", 0)
            
            -- Re-hide SpongebobBaru
            for _, part in ipairs(spongebob:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 1
                    part.CanCollide = false
                end
            end
            
            -- Re-disable TalkPrompt
            local talkPrompt = nil
            for _, desc in ipairs(spongebob:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Name == "TalkPrompt" then
                    talkPrompt = desc
                    break
                end
            end
            if talkPrompt then
                talkPrompt.Enabled = false
            end
        end
        
        -- Re-hide all coins
        for i = 1, 6 do
            local coin = workspace:FindFirstChild("QuestCoin_" .. i)
            if coin then
                coin.Transparency = 1
                local light = coin:FindFirstChildOfClass("PointLight")
                if light then light.Enabled = false end
                local prompt = coin:FindFirstChild("Prompt")
                if prompt then prompt.Enabled = false end
            end
        end
        
        -- Reset AbandonedTerminal state
        terminal:SetAttribute("State", 0)
        
        -- Re-hide shadow silhouette
        shadowSilhouette.Transparency = 1
        
        -- Re-enable ticket machine prompt
        ticketPrompt.Enabled = true
        
        -- Reset maintenance button (disable and turn red)
        maintBtnPrompt.Enabled = false
        maintBtnPart.Color = Color3.fromRGB(200, 50, 50)
        
        -- Close maintenance door
        local hinge = maintDoorModel:FindFirstChild("Hinge")
        local door = maintDoorModel:FindFirstChild("Door")
        if hinge and door then
            hinge.CFrame = hinge.CFrame * CFrame.Angles(0, math.rad(90), 0) -- approximate reset
            door.CFrame = hinge.CFrame * CFrame.new(0, 0, 3)
        end
        
        -- Notify client to reset horror state
        remoteEvent:FireClient(player, "ResetClient")
        
        print("Game reset! Player will respawn at SpawnLocation.")
    elseif action == "StartCoinQuest" then
        if spongebob and spongebob:GetAttribute("QuestState") == 0 then
            spongebob:SetAttribute("QuestState", 1)
            
            -- Pick exactly 3 random indices from 1 to 6
            local indices = {1, 2, 3, 4, 5, 6}
            for i = #indices, 2, -1 do
                local j = math.random(1, i)
                indices[i], indices[j] = indices[j], indices[i]
            end
            
            -- Reveal the 3 selected coins
            for i = 1, 3 do
                local idx = indices[i]
                local coin = workspace:FindFirstChild("QuestCoin_" .. idx)
                if coin then
                    coin.Transparency = 0 -- Make visible
                    local light = coin:FindFirstChildOfClass("PointLight")
                    if light then light.Enabled = true end
                    local prompt = coin:FindFirstChild("Prompt")
                    if prompt then
                        prompt.Enabled = true
                        
                        -- Coin pickup trigger
                        prompt.Triggered:Connect(function(p)
                            -- Hide coin again
                            coin.Transparency = 1
                            if light then light.Enabled = false end
                            prompt.Enabled = false
                            
                            local count = (spongebob:GetAttribute("CoinCount") or 0) + 1
                            spongebob:SetAttribute("CoinCount", count)
                            
                            -- Notify player UI
                            remoteEvent:FireClient(p, "CoinCollected", count)
                            
                            if count >= 3 then
                                spongebob:SetAttribute("QuestState", 2)
                                print("Spongebob Quest: All 3 coins collected!")
                            end
                        end)
                    end
                end
            end
            print("3 Quest coins revealed randomly near buildings!")
        end
    end
end)
