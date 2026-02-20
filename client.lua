local RSGCore = exports['rsg-core']:GetCoreObject()
local placedStills = {}
local stillBlips = {}
local smokeEffects = {}
local brewingStills = {}
local isMenuOpen = false
local currentMenuStillId = nil

-----------------
-- HELPER FUNCTIONS
-----------------
local function FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

local function GetProgressBar(percent)
    local filled = math.floor(percent / 5)
    local empty = 20 - filled
    return '[' .. string.rep('|', filled) .. string.rep('.', empty) .. '] ' .. math.floor(percent) .. '%'
end

local function GetBrewingStatus(percent)
    if percent <= 20 then
        return 'Starting', 'red'
    elseif percent <= 40 then
        return 'Warming Up', 'orange'
    elseif percent <= 60 then
        return 'Fermenting', 'yellow'
    elseif percent <= 80 then
        return 'Distilling', 'blue'
    else
        return 'Nearly Done', 'green'
    end
end

local function GetBrewingIcon(percent)
    if percent <= 20 then
        return 'fas fa-fire-alt'
    elseif percent <= 40 then
        return 'fas fa-temperature-high'
    elseif percent <= 60 then
        return 'fas fa-hourglass-half'
    elseif percent <= 80 then
        return 'fas fa-flask'
    else
        return 'fas fa-check-circle'
    end
end

-----------------
-- OX TARGET
-----------------
CreateThread(function()
    exports.ox_target:addModel(Config.Prop, {
        {
            label = 'Check Still',
            icon = 'fas fa-flask',
            onSelect = function(data)
                local stillId = GetNearestStillId()
                if stillId then
                    OpenStillMenu(stillId)
                end
            end
        }
    })
end)

-----------------
-- PLAYER LOAD
-----------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded')
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    Wait(3000)
    TriggerServerEvent('rsg-moonshiner:server:requestStills')
end)

-----------------
-- RESOURCE START
-----------------
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(3000)
        TriggerServerEvent('rsg-moonshiner:server:requestStills')
    end
end)

-----------------
-- GET NEAREST STILL
-----------------
function GetNearestStillId()
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearestId = nil
    local nearestDist = 5.0
    
    for id, data in pairs(placedStills) do
        local dist = #(playerPos - vector3(data.pos.x, data.pos.y, data.pos.z))
        if dist < nearestDist then
            nearestDist = dist
            nearestId = id
        end
    end
    
    return nearestId
end

-----------------
-- CHECK INGREDIENTS
-----------------
local function HasIngredients()
    for _, ingredient in ipairs(Config.Recipe) do
        if not RSGCore.Functions.HasItem(ingredient.item) then
            return false
        end
    end
    return true
end

local function GetIngredientStatus()
    local status = ""
    for i, ingredient in ipairs(Config.Recipe) do
        local has = RSGCore.Functions.HasItem(ingredient.item)
        status = status .. ingredient.label .. ': ' .. (has and '[Y]' or '[N]')
        if i < #Config.Recipe then
            status = status .. ' | '
        end
    end
    return status
end

-----------------
-- STILL MENU
-----------------
function OpenStillMenu(stillId, skipThread)
    local brewing = brewingStills[stillId]
    local options = {}
    
    isMenuOpen = true
    currentMenuStillId = stillId
    
    if brewing then
        local now = GetGameTimer()
        local elapsed = now - brewing.startTime
        local remaining = Config.BrewTime - elapsed
        local percent = math.min((elapsed / Config.BrewTime) * 100, 100)
        
        if remaining <= 0 then
            isMenuOpen = false
            currentMenuStillId = nil
            
            options[#options + 1] = {
                title = 'Collect Moonshine',
                description = 'Your moonshine is ready!',
                icon = 'fas fa-wine-bottle',
                iconColor = '#FFD700',
                onSelect = function()
                    TriggerServerEvent('rsg-moonshiner:server:collectMoonshine', stillId)
                    brewingStills[stillId] = nil
                end
            }
        else
            local remainingSecs = math.ceil(remaining / 1000)
            local statusText, statusColor = GetBrewingStatus(percent)
            local statusIcon = GetBrewingIcon(percent)
            
            options[#options + 1] = {
                title = 'Brewing In Progress',
                description = GetProgressBar(percent) .. '\nTime Remaining: ' .. FormatTime(remainingSecs) .. '\nStatus: ' .. statusText,
                icon = statusIcon,
                progress = percent,
                colorScheme = statusColor,
                disabled = false
            }
            
            options[#options + 1] = {
                title = 'Close Menu',
                description = 'Close this menu',
                icon = 'fas fa-times',
                iconColor = '#e74c3c',
                onSelect = function()
                    isMenuOpen = false
                    currentMenuStillId = nil
                end
            }
            
            if not skipThread then
                StartLiveUpdateThread(stillId)
            end
        end
    else
        isMenuOpen = false
        currentMenuStillId = nil
        
        local hasItems = HasIngredients()
        
        options[#options + 1] = {
            title = 'Start Brewing',
            description = GetIngredientStatus(),
            icon = 'fas fa-play-circle',
            iconColor = hasItems and '#2ecc71' or '#e74c3c',
            disabled = not hasItems,
            onSelect = function()
                if hasItems then
                    StartBrewing(stillId)
                else
                    RSGCore.Functions.Notify('Missing ingredients!', 'error')
                end
            end
        }
        
        local recipeText = ''
        for i, ingredient in ipairs(Config.Recipe) do
            recipeText = recipeText .. ingredient.amount .. 'x ' .. ingredient.label
            if i < #Config.Recipe then
                recipeText = recipeText .. ' + '
            end
        end
        recipeText = recipeText .. ' = ' .. Config.Output.amount .. 'x Moonshine'
        
        options[#options + 1] = {
            title = 'Recipe Info',
            description = recipeText .. '\nBrew Time: ' .. FormatTime(Config.BrewTime / 1000),
            icon = 'fas fa-book-open',
            iconColor = '#9b59b6',
            disabled = true
        }
    end
    
    lib.registerContext({
        id = 'moonshine_still_menu',
        title = 'Moonshine Still',
        options = options,
        onExit = function()
            isMenuOpen = false
            currentMenuStillId = nil
        end
    })
    
    lib.showContext('moonshine_still_menu')
end

-----------------
-- LIVE UPDATE THREAD
-----------------
function StartLiveUpdateThread(stillId)
    CreateThread(function()
        while isMenuOpen and currentMenuStillId == stillId do
            Wait(1000)
            
            if not isMenuOpen or currentMenuStillId ~= stillId then
                break
            end
            
            local brewing = brewingStills[stillId]
            if brewing then
                local now = GetGameTimer()
                local elapsed = now - brewing.startTime
                local remaining = Config.BrewTime - elapsed
                
                if remaining <= 0 then
                    isMenuOpen = false
                    currentMenuStillId = nil
                    OpenStillMenu(stillId)
                    break
                else
                    OpenStillMenu(stillId, true)
                end
            else
                break
            end
        end
    end)
end

-----------------
-- START BREWING
-----------------
function StartBrewing(stillId)
    TriggerServerEvent('rsg-moonshiner:server:startBrewing', stillId)
end

-----------------
-- BREWING STARTED
-----------------
RegisterNetEvent('rsg-moonshiner:client:brewingStarted')
AddEventHandler('rsg-moonshiner:client:brewingStarted', function(stillId)
    brewingStills[stillId] = {
        startTime = GetGameTimer()
    }
    
    RSGCore.Functions.Notify('Brewing started! Come back in ' .. FormatTime(Config.BrewTime / 1000), 'success')
    
    Wait(500)
    OpenStillMenu(stillId)
end)

-----------------
-- SYNC BREWING STATE
-----------------
RegisterNetEvent('rsg-moonshiner:client:syncBrewingState')
AddEventHandler('rsg-moonshiner:client:syncBrewingState', function(stillId, elapsedSeconds)
    if elapsedSeconds then
        local clientStart = GetGameTimer() - (elapsedSeconds * 1000)
        brewingStills[stillId] = {
            startTime = clientStart
        }
    else
        brewingStills[stillId] = nil
    end
end)

-----------------
-- REMOVE STILL
-----------------
local function RemoveStill(id)
    if placedStills[id] then
        local data = placedStills[id]
        
        if data.entity and DoesEntityExist(data.entity) then
            SetEntityAsMissionEntity(data.entity)
            DeleteObject(data.entity)
        end
        
        if stillBlips[id] then
            RemoveBlip(stillBlips[id])
            stillBlips[id] = nil
        end
        
        if smokeEffects[id] then
            Citizen.InvokeNative(0x22970F3A088B133B, smokeEffects[id], false)
            smokeEffects[id] = nil
        end
        
        placedStills[id] = nil
        brewingStills[id] = nil
    end
end

-----------------
-- CREATE STILL
-----------------
local function CreateStill(id, data)
    -- Skip if already exists
    if placedStills[id] and placedStills[id].entity and DoesEntityExist(placedStills[id].entity) then
        return
    end
    
    local pos = data.pos
    local heading = data.heading
    
    local modelHash = GetHashKey(Config.Prop)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(1)
        end
    end
    
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    Wait(500)
    
    local prop = CreateObject(modelHash, pos.x, pos.y, pos.z + 0.5, false, false, false)
    SetEntityHeading(prop, heading)
    
    Wait(100)
    
    if DoesEntityExist(prop) then
        PlaceObjectOnGroundProperly(prop)
        Wait(100)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)
        
        local finalPos = GetEntityCoords(prop)
        
        placedStills[id] = {
            entity = prop,
            pos = finalPos,
            heading = heading
        }
        
        if Config.Blip.Enabled then
            local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, -1230993421, prop)
            SetBlipSprite(blip, Config.Blip.Sprite, 1)
            SetBlipScale(blip, Config.Blip.Scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blip.Name)
            stillBlips[id] = blip
        end
        
        if Config.Smoke.Enabled then
            Citizen.InvokeNative(0xA10DB07FC234DD12, Config.Smoke.Group)
            local smoke = Citizen.InvokeNative(0xBA32867E86125D3A, Config.Smoke.Name, finalPos.x, finalPos.y, finalPos.z + Config.Smoke.OffsetZ, 0, 0.0, 0.0, Config.Smoke.Scale, false, false, false, true)
            Citizen.InvokeNative(0x239879FC61C610CC, smoke, 1.0, 1.0, 1.0, false)
            smokeEffects[id] = smoke
        end
    end
end

-----------------
-- LOAD ALL STILLS
-----------------
RegisterNetEvent('rsg-moonshiner:client:loadStills')
AddEventHandler('rsg-moonshiner:client:loadStills', function(stills, brewingData)
    -- Clear existing
    for id, _ in pairs(placedStills) do
        RemoveStill(id)
    end
    
    placedStills = {}
    stillBlips = {}
    smokeEffects = {}
    brewingStills = {}
    
    Wait(1500)
    
    -- Create stills
    if stills then
        for id, data in pairs(stills) do
            CreateStill(id, data)
            Wait(200)
        end
    end
    
    -- Load brewing states
    if brewingData then
        for stillId, elapsedSeconds in pairs(brewingData) do
            if elapsedSeconds then
                local clientStart = GetGameTimer() - (elapsedSeconds * 1000)
                brewingStills[stillId] = {
                    startTime = clientStart
                }
            end
        end
    end
end)

-----------------
-- SYNC ADD STILL
-----------------
RegisterNetEvent('rsg-moonshiner:client:syncAddStill')
AddEventHandler('rsg-moonshiner:client:syncAddStill', function(id, data)
    if not placedStills[id] then
        CreateStill(id, data)
    end
end)

-----------------
-- SYNC REMOVE STILL
-----------------
RegisterNetEvent('rsg-moonshiner:client:syncRemoveStill')
AddEventHandler('rsg-moonshiner:client:syncRemoveStill', function(id)
    RemoveStill(id)
end)

-----------------
-- COUNT STILLS
-----------------
local function GetStillCount()
    local count = 0
    for _ in pairs(placedStills) do count = count + 1 end
    return count
end

-----------------
-- PLACE STILL
-----------------
local function PlaceStillHere()
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    RSGCore.Functions.Notify('Placing still...', 'primary')
    
    local id = tostring(GetGameTimer()) .. tostring(math.random(1000, 9999))
    local stillData = {
        pos = vector3(pos.x, pos.y, pos.z),
        heading = heading
    }
    
    CreateStill(id, stillData)
    TriggerServerEvent('rsg-moonshiner:server:addStill', id, stillData)
    
    PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)
    RSGCore.Functions.Notify('Still placed! Use /stills to save', 'success')
end

-----------------
-- REMOVE NEAREST
-----------------
local function RemoveNearestStill()
    local nearestId = GetNearestStillId()
    
    if nearestId then
        RSGCore.Functions.Notify('Removing still...', 'primary')
        
        RemoveStill(nearestId)
        TriggerServerEvent('rsg-moonshiner:server:removeStill', nearestId)
        
        PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)
        RSGCore.Functions.Notify('Still removed! Use /stills to save', 'success')
    else
        RSGCore.Functions.Notify('No still found within 5 meters!', 'error')
    end
end

-----------------
-- ADMIN MENU
-----------------
RegisterNetEvent('rsg-moonshiner:client:openMenu')
AddEventHandler('rsg-moonshiner:client:openMenu', function()
    local stillCount = GetStillCount()
    
    lib.registerContext({
        id = 'moonshine_admin_menu',
        title = 'Moonshine Stills Management',
        options = {
            {
                title = 'Place Still Here',
                description = 'Place a moonshine still at your location',
                icon = 'fas fa-plus-circle',
                iconColor = '#2ecc71',
                onSelect = function()
                    PlaceStillHere()
                end
            },
            {
                title = 'Remove Nearest Still',
                description = 'Remove the closest still within 5 meters',
                icon = 'fas fa-trash-alt',
                iconColor = '#e74c3c',
                onSelect = function()
                    RemoveNearestStill()
                end
            },
            {
                title = 'Save All Stills',
                description = 'Save all stills to JSON file',
                icon = 'fas fa-save',
                iconColor = '#3498db',
                onSelect = function()
                    TriggerServerEvent('rsg-moonshiner:server:saveStills')
                end
            },
            {
                title = 'Total Stills: ' .. stillCount,
                description = 'Currently placed stills on the map',
                icon = 'fas fa-list-ol',
                iconColor = '#9b59b6',
                disabled = true
            }
        }
    })
    
    lib.showContext('moonshine_admin_menu')
end)