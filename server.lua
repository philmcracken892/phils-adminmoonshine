local RSGCore = exports['rsg-core']:GetCoreObject()

local placedStills = {}
local brewingStills = {}
local stillsFile = 'stills.json'

-----------------
-- UTILITIES
-----------------
local function TableCount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function GetFilePath()
    return GetResourcePath(GetCurrentResourceName()) .. '/' .. stillsFile
end

-----------------
-- JSON FUNCTIONS
-----------------
local function LoadStills()
    local path = GetFilePath()
    local file = io.open(path, 'r')
    
    if file then
        local content = file:read('*a')
        file:close()
        
        if content and content ~= '' then
            placedStills = json.decode(content) or {}
            print('^2[Moonshiner]^0 Loaded ' .. TableCount(placedStills) .. ' stills')
        else
            placedStills = {}
        end
    else
        local newFile = io.open(path, 'w+')
        if newFile then
            newFile:write('{}')
            newFile:close()
            print('^2[Moonshiner]^0 Created ' .. stillsFile)
        end
        placedStills = {}
    end
end

local function SaveStills()
    local path = GetFilePath()
    local file = io.open(path, 'w+')
    
    if file then
        file:write(json.encode(placedStills, {indent = true}))
        file:close()
        print('^2[Moonshiner]^0 Saved ' .. TableCount(placedStills) .. ' stills')
        return true
    end
    return false
end

local function GetBrewingElapsed()
    local elapsed = {}
    for stillId, startTime in pairs(brewingStills) do
        if startTime then
            elapsed[stillId] = os.time() - startTime
        end
    end
    return elapsed
end

-----------------
-- AUTO LOAD ON START
-----------------
CreateThread(function()
    Wait(500)
    LoadStills()
end)

-----------------
-- ADMIN COMMAND
-----------------
RegisterCommand(Config.AdminCommand, function(source, args, rawCommand)
    local src = source
    TriggerClientEvent('rsg-moonshiner:client:openMenu', src)
end, false)

-----------------
-- REQUEST STILLS
-----------------
RegisterNetEvent('rsg-moonshiner:server:requestStills')
AddEventHandler('rsg-moonshiner:server:requestStills', function()
    local src = source
    local brewingElapsed = GetBrewingElapsed()
    TriggerClientEvent('rsg-moonshiner:client:loadStills', src, placedStills, brewingElapsed)
end)

-----------------
-- ADD STILL
-----------------
RegisterNetEvent('rsg-moonshiner:server:addStill')
AddEventHandler('rsg-moonshiner:server:addStill', function(id, data)
    placedStills[id] = {
        pos = data.pos,
        heading = data.heading
    }
    TriggerClientEvent('rsg-moonshiner:client:syncAddStill', -1, id, data)
end)

-----------------
-- REMOVE STILL
-----------------
RegisterNetEvent('rsg-moonshiner:server:removeStill')
AddEventHandler('rsg-moonshiner:server:removeStill', function(id)
    placedStills[id] = nil
    brewingStills[id] = nil
    TriggerClientEvent('rsg-moonshiner:client:syncRemoveStill', -1, id)
end)

-----------------
-- SAVE STILLS
-----------------
RegisterNetEvent('rsg-moonshiner:server:saveStills')
AddEventHandler('rsg-moonshiner:server:saveStills', function()
    local src = source
    
    if SaveStills() then
        TriggerClientEvent('RSGCore:Notify', src, 'Stills saved! (' .. TableCount(placedStills) .. ' total)', 'success')
    else
        TriggerClientEvent('RSGCore:Notify', src, 'Failed to save stills!', 'error')
    end
end)

-----------------
-- START BREWING
-----------------
RegisterNetEvent('rsg-moonshiner:server:startBrewing')
AddEventHandler('rsg-moonshiner:server:startBrewing', function(stillId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if brewingStills[stillId] then
        TriggerClientEvent('RSGCore:Notify', src, 'This still is already brewing!', 'error')
        return
    end
    
    local hasAll = true
    local missing = {}
    
    for _, ingredient in ipairs(Config.Recipe) do
        local hasItem = Player.Functions.GetItemByName(ingredient.item)
        if not hasItem or hasItem.amount < ingredient.amount then
            hasAll = false
            table.insert(missing, ingredient.label)
        end
    end
    
    if not hasAll then
        TriggerClientEvent('RSGCore:Notify', src, 'Missing: ' .. table.concat(missing, ", "), 'error')
        return
    end
    
    for _, ingredient in ipairs(Config.Recipe) do
        Player.Functions.RemoveItem(ingredient.item, ingredient.amount)
        TriggerClientEvent("rsg-inventory:client:ItemBox", src, RSGCore.Shared.Items[ingredient.item], "remove")
    end
    
    local startTime = os.time()
    brewingStills[stillId] = startTime
    
    TriggerClientEvent('rsg-moonshiner:client:brewingStarted', src, stillId)
    TriggerClientEvent('rsg-moonshiner:client:syncBrewingState', -1, stillId, 0)
    
    -- Alert lawmen
    TriggerEvent('rsg-lawman:server:lawmanAlert', 'Moonshine is getting brewed!')
    
    print('^2[Moonshiner]^0 Brewing started at still: ' .. stillId .. ' by player: ' .. src)
end)

-----------------
-- COLLECT MOONSHINE
-----------------
RegisterNetEvent('rsg-moonshiner:server:collectMoonshine')
AddEventHandler('rsg-moonshiner:server:collectMoonshine', function(stillId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local startTime = brewingStills[stillId]
    
    if not startTime then
        TriggerClientEvent('RSGCore:Notify', src, 'Nothing to collect!', 'error')
        return
    end
    
    local elapsed = os.time() - startTime
    local requiredTime = Config.BrewTime / 1000
    
    if elapsed < requiredTime then
        TriggerClientEvent('RSGCore:Notify', src, 'Moonshine is not ready yet!', 'error')
        return
    end
    
    Player.Functions.AddItem(Config.Output.item, Config.Output.amount)
    TriggerClientEvent("rsg-inventory:client:ItemBox", src, RSGCore.Shared.Items[Config.Output.item], "add")
    TriggerClientEvent('RSGCore:Notify', src, 'You collected ' .. Config.Output.amount .. 'x Moonshine!', 'success')
    
    brewingStills[stillId] = nil
    TriggerClientEvent('rsg-moonshiner:client:syncBrewingState', -1, stillId, nil)
    
    print('^2[Moonshiner]^0 Moonshine collected from still: ' .. stillId .. ' by player: ' .. src)
end)