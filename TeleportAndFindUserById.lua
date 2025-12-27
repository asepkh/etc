-- Sequential server hopper that checks by players (local Player list) + persistent visited file
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Api = "https://games.roblox.com/v1/games/"
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId
local SERVERS_URL = Api .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"

local VISITED_FILE = "visited_servers.json"
local time_to_wait = 10 -- seconds to wait on each server before moving on
local targetUserId = 9102903420 -- << set the UserId you want to find

-- visited table (keys = serverId -> true)
local visited = {}

-- safe JSON decode
local function safeDecode(s)
    local ok, res = pcall(function() return Http:JSONDecode(s) end)
    if ok then return res end
    return nil
end

-- Load visited from file (if available)
local function LoadVisited()
    if isfile and isfile(VISITED_FILE) then
        local ok, content = pcall(readfile, VISITED_FILE)
        if ok and content and #content > 0 then
            local decoded = safeDecode(content)
            if type(decoded) == "table" then
                for k,v in pairs(decoded) do visited[k] = v end
                print("[Visited] Loaded", #decoded, "entries")
            end
        end
    end
end

-- Save visited to file
local function SaveVisited()
    if writefile then
        local t = {}
        for k,v in pairs(visited) do t[k] = v end
        pcall(writefile, VISITED_FILE, Http:JSONEncode(t))
    end
end

-- Show centered UI text on the player's screen for `dur` seconds
local function ShowStatus(text, color3, dur)
    dur = dur or 5
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ServerFinderStatus"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,0.15,0)
    label.Position = UDim2.new(0.2,0,0.425,0)
    label.AnchorPoint = Vector2.new(0,0)
    label.BackgroundTransparency = 0.4
    label.BackgroundColor3 = Color3.fromRGB(20,20,20)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.TextColor3 = color3
    label.Text = text
    label.Parent = screenGui

    delay(dur, function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end

-- Fetch list of servers (returns decoded JSON)
local function ListServers(cursor)
    local url = SERVERS_URL .. ((cursor and "&cursor=" .. cursor) or "")
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or not raw then return nil end
    return safeDecode(raw)
end

-- Find the next unvisited server id from server pages
-- local function GetNextServerId()
--     local cursor = nil
--     while true do
--         local page = ListServers(cursor)
--         if not page or not page.data then return nil end

--         for _, server in ipairs(page.data) do
--             local sid = server.id
--             if sid ~= JOB_ID and not visited[sid] then
--                 return sid, page.nextPageCursor
--             end
--         end

--         if page.nextPageCursor then
--             cursor = page.nextPageCursor
--         else
--             return nil
--         end
--     end
-- end

-- Main flow: when this script is running in a server instance:
LoadVisited()

-- Mark current server as visited (so we don't re-check if script restarts here)
if JOB_ID and JOB_ID ~= "" then
    visited[JOB_ID] = true
    SaveVisited()
end

-- Wait for local player to fully load into the server (character and players list)
local function WaitForFullyLoaded(timeout)
    timeout = timeout or 15
    local t0 = tick()
    while tick() - t0 < timeout do
        if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            return true
        end
        wait(0.5)
    end
    return false
end

WaitForFullyLoaded(20)

-- Check players in the current server for targetUserId
local function CheckLocalPlayersForTarget()
    local found = false
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.UserId == targetUserId then
            found = true
            break
        end
    end
    if found then
        ShowStatus("FOUND!", Color3.fromRGB(0,255,0), 5)
        print("[Finder] Target present in this server!")
    else
        ShowStatus("Not Found", Color3.fromRGB(255,0,0), 5)
        print("[Finder] Target not found in this server.")
    end
end

-- Run the local-player check now (this meets "check by players, not API")
CheckLocalPlayersForTarget()

-- Wait the configured time before moving on
local waited = 0
while waited < time_to_wait do
    local to = math.min(1, time_to_wait - waited)
    wait(to)
    waited = waited + to
end

-- Find next unvisited server and teleport there (if any)
-- [DELETE] The entire GetNextServerId function (Lines 86-105)

-- [MODIFY] TeleportToNext to use a loop instead of recursion
local function TeleportToNext()
    while true do
        -- Re-load visited (in case file changed externally)
        LoadVisited()

        local nextId = nil
        local cursor = nil
        
        -- Scan for next server
        repeat
            local page = ListServers(cursor)
            if not page or not page.data then break end
            for _, server in ipairs(page.data) do
                -- Check if server is full? (Optional: server.playing < server.maxPlayers)
                if server.id ~= JOB_ID and not visited[server.id] then
                    nextId = server.id
                    break
                end
            end
            if nextId then break end
            cursor = page.nextPageCursor
        until not cursor

        if nextId then
            -- Found a server
            visited[nextId] = true
            SaveVisited()
            print("[Teleport] Going to server:", nextId)
            TPS:TeleportToPlaceInstance(PLACE_ID, nextId, LocalPlayer)
            break -- Break the loop to stop searching
        else
            -- No server found
            print("[Teleport] No unvisited servers. Clearing list and retrying...")
            table.clear(visited)
            SaveVisited()
            wait(5)
            -- Loop sends us back to start
        end
    end
end

-- Trigger teleport to next server (this will end the current session)
TeleportToNext()