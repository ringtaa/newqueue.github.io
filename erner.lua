-- Wait for game to load
repeat wait() until game:IsLoaded()

local lobbyPlaceId = 116495829188952 -- Specify the lobby PlaceId
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Define positions for back-and-forth movement
local pointA = Vector3.new(45, 8, 91)
local pointB = Vector3.new(45, 8, 154)
local moveSpeed = 21 -- Normal walking speed

-- Function to disable collisions (noclip effect)
local function enableNoClip()
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

-- Function to move smoothly between points using TweenService
local function tweenToPosition(targetPosition)
    local distance = (rootPart.Position - targetPosition).Magnitude
    local timeToMove = distance / moveSpeed -- Time based on speed

    local tweenInfo = TweenInfo.new(timeToMove, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    
    tween:Play()
    return tween
end

-- Function to fire the create party remote endlessly (Updated path & args, now with isPrivate=true)
local function fireCreatePartyRemote()
    while true do
        local args = {
            {
                isPrivate = true,      -- Now required for private/solo parties
                maxMembers = 1,        -- Ensures solo party creation
                trainId = "default",   -- Required by the new game system
                gameMode = "Normal"    -- Keeps the correct mode
            }
        }
        print("Firing CreateParty remote with args:", args) -- Debugging statement
        ReplicatedStorage:WaitForChild("Shared")
            :WaitForChild("Network")
            :WaitForChild("RemoteEvent")
            :WaitForChild("CreateParty")
            :FireServer(unpack(args))
        wait(0.1) -- Small delay to prevent crashes
    end
end

-- Function to check if the player has been teleported
local function hasBeenTeleported()
    return game.PlaceId ~= lobbyPlaceId -- Only consider teleported if we've left the lobby
end

-- Function to get a low-player server
local function getLowPlayerServer(cursor)
    local apiUrl = "https://games.roblox.com/v1/games/" .. lobbyPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local url = apiUrl .. ((cursor and "&cursor=" .. cursor) or "")
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if success then
        local data = HttpService:JSONDecode(response)
        for _, server in pairs(data.data) do
            if server.playing < 3 and server.id ~= game.JobId then -- Adjust maxPlayersAllowed if needed
                return server.id
            end
        end
        return data.nextPageCursor
    end

    warn("Failed to fetch server list.")
    return nil
end

-- Main teleportation loop
local function startTeleportationLoop()
    enableNoClip() -- Enable noclip to prevent movement issues

    while not hasBeenTeleported() do
        local tweenA = tweenToPosition(pointA)
        tweenA.Completed:Wait() -- Wait for movement to finish
        if hasBeenTeleported() then break end

        local tweenB = tweenToPosition(pointB)
        tweenB.Completed:Wait() -- Wait for movement to finish
        if hasBeenTeleported() then break end
    end

    print("Successfully Teleported. Stopping teleportation & remote firing.")
end

-- Only execute if the current PlaceId matches the lobbyPlaceId
if game.PlaceId == lobbyPlaceId then
    -- Start the remote firing loop
    task.spawn(fireCreatePartyRemote)

    -- Start the teleportation loop
    task.spawn(startTeleportationLoop)

    -- Start the delayed teleportation check in parallel
    task.spawn(function()
        wait(35) -- Wait for 35 seconds

        if game.PlaceId == lobbyPlaceId then
            local serverId, cursor = nil, nil
            repeat
                cursor = getLowPlayerServer(cursor)
                if cursor and not serverId then
                    serverId = cursor
                end
            until serverId or not cursor

            if serverId then
                print("Teleporting to a low-player server...")
                TeleportService:TeleportToPlaceInstance(lobbyPlaceId, serverId, player)
            else
                warn("No suitable server found.")
            end
        else
            print("Not in the lobby, skipping server hop.")
        end
    end)
else
    print("Not in the local lobby. Script will not run.")
end
