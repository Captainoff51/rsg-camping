local RSGCore = exports['rsg-core']:GetCoreObject()
local SpawnedProps = {}
local isBusy = false
local showingtext = false
local showingprompt = false

---------------------------------------------
-- spawn props
---------------------------------------------
Citizen.CreateThread(function()
    while true do
        Wait(150)

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local InRange = false

        for i = 1, #Config.PlayerProps do
            local prop = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
            local dist = #(pos - prop)
            if dist >= 50.0 then goto continue end

            local hasSpawned = false
            InRange = true

            for z = 1, #SpawnedProps do
                local p = SpawnedProps[z]

                if p.id == Config.PlayerProps[i].id then
                    hasSpawned = true
                end
            end

            if hasSpawned then goto continue end

            local modelHash = Config.PlayerProps[i].hash
            local data = {}
            
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Wait(1)
                end
            end
            
            data.id = Config.PlayerProps[i].id
            data.obj = CreateObject(modelHash, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z -1.2, false, false, false)
            SetEntityHeading(data.obj, Config.PlayerProps[i].h)
            SetEntityAsMissionEntity(data.obj, true)
            PlaceObjectOnGroundProperly(data.obj)
            Wait(1000)
            FreezeEntityPosition(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)

            -- veg modifiy
            local veg_modifier_sphere = 0
            
            if veg_modifier_sphere == nil or veg_modifier_sphere == 0 then
                local veg_radius = 3.0
                local veg_Flags =  1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256
                local veg_ModType = 1
                
                veg_modifier_sphere = Citizen.InvokeNative(0xFA50F79257745E74, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, veg_radius, veg_ModType, veg_Flags, 0)
                
            else
                Citizen.InvokeNative(0x9CF1836C03FB67A2, Citizen.PointerValueIntInitialized(veg_modifier_sphere), 0)
                veg_modifier_sphere = 0
            end

            SpawnedProps[#SpawnedProps + 1] = data
            hasSpawned = false

            ::continue::
        end

        if not InRange then
            Wait(5000)
        end
    end
end)

---------------------------------------------
-- trigger promps
---------------------------------------------
Citizen.CreateThread(function()
    while true do
        local sleep = 0
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for k, v in pairs(Config.PlayerProps) do
            if v.proptype == 'camptent' then
                local campprop = vector3(v.x, v.y, v.z)
                local dist = #(pos - campprop)
                if dist < 3 and not IsPedInAnyVehicle(PlayerPedId(), false) and not showingprompt then
                    exports['rsg-core']:createPrompt(k..'-'..v.id, campprop, RSGCore.Shared.Keybinds['ENTER'], 'Open Menu', {
                        type = 'client',
                        event = 'rsg-camping:client:mainmenu',
                        args = { v.builder },
                    })
                    showingprompt = true
                end
                if dist > 3 and showingprompt then
                    exports['rsg-core']:deletePrompt(k..'-'..v.id)
                    showingprompt = false
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------
-- camp menu
---------------------------------------------
RegisterNetEvent('rsg-camping:client:mainmenu', function(builder)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playercid = PlayerData.citizenid
    if playercid == builder then
        lib.registerContext({
            id = 'camp_mainmenu',
            title = 'Camp Menu',
            options = {
                {
                    title = 'Camp Items',
                    description = 'camp items',
                    icon = 'fa-solid fa-campground',
                    event = 'rsg-camping:client:campitemsmenu',
                    args = { cid = playercid },
                    arrow = true
                },
                {
                    title = 'Camp Storage',
                    description = 'camp storage',
                    icon = 'fa-solid fa-box',
                    event = 'rsg-camping:client:campstorage',
                    arrow = true
                },
                {
                    title = 'Buy Equipment',
                    description = 'buy equipment to add to your camp',
                    icon = 'fa-solid fa-basket-shopping',
                    event = 'rsg-camping:client:campingequipment',
                    arrow = true
                },
            }
        })
        lib.showContext("camp_mainmenu")
    else
        lib.registerContext({
            id = 'camp_robmenu',
            title = 'Rob Camp Menu',
            options = {
                {
                    title = 'Rob Camp',
                    description = 'rob this camp',
                    icon = 'fa-solid fa-mask',
                    event = 'rsg-camping:client:robcamp',
                    args = { cid = playercid },
                    arrow = true
                },
            }
        })
        lib.showContext("camp_robmenu")
    end
end)

---------------------------------------------
-- camp deployed
---------------------------------------------
RegisterNetEvent('rsg-camping:client:campitemsmenu')
AddEventHandler('rsg-camping:client:campitemsmenu', function(data)
    local options = {}
    for k, v in pairs(Config.PlayerProps) do
        if v.builder == data.cid then
            options[#options + 1] = {
                title = RSGCore.Shared.Items[v.proptype].label,
                icon = 'fa-solid fa-box',
                event = 'rsg-camping:client:propmenu',
                args = { propid = v.id },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'camp_deployed',
            title = 'Deployed Items',
            menu = 'camp_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('camp_deployed')        
    end
end)

---------------------------------------------
-- prop menu
---------------------------------------------
RegisterNetEvent('rsg-camping:client:propmenu', function(data)
    RSGCore.Functions.TriggerCallback('rsg-camping:server:getallpropdata', function(result)
        lib.registerContext({
            id = 'camp_propmenu',
            title = RSGCore.Shared.Items[result[1].proptype].label,
            menu = 'camp_deployed',
            onBack = function() end,
            options = {
                {
                    title = 'Credit : $'..result[1].credit,
                    description = 'current maintenance credit',
                    icon = 'fa-solid fa-coins',
                },
                {
                    title = 'Add Credit',
                    description = 'add maintenance credit',
                    icon = 'fa-solid fa-plus',
                    iconColor = 'green',
                    event = 'rsg-camping:client:addcredit',
                    args = { 
                        propid = result[1].propid,
                        credit = result[1].credit
                    },
                    arrow = true
                },
                {
                    title = 'Remove Credit',
                    description = 'remove maintenance credit',
                    icon = 'fa-solid fa-minus',
                    iconColor = 'red',
                    event = 'rsg-camping:client:removecredit',
                    args = { 
                        propid = result[1].propid,
                        credit = result[1].credit
                    },
                    arrow = true
                },
                {
                    title = 'Packup',
                    description = 'packup camp equiment',
                    icon = 'fa-solid fa-box',
                    iconColor = 'red',
                    serverEvent = 'rsg-camping:server:destroyProp',
                    args = { 
                        propid = result[1].propid,
                        item = result[1].proptype
                    },
                    arrow = true
                },
            }
        })
        lib.showContext("camp_propmenu")
    end, data.propid)
end)

---------------------------------------------
-- add credit
---------------------------------------------
RegisterNetEvent('rsg-camping:client:addcredit', function(data)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local cash = tonumber(PlayerData.money['cash'])
    local input = lib.inputDialog('Add Credit', {
        { 
            label = 'Amount',
            type = 'input',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    
    if not input then
        return
    end
    
    if tonumber(input[1]) == nil then
        return
    end

    if cash >= tonumber(input[1]) then
        local creditadjust = data.credit + tonumber(input[1])
        TriggerServerEvent('rsg-camping:server:addcredit', creditadjust, tonumber(input[1]), data.propid )
    else
        lib.notify({ title = 'Not Enough Cash', description = 'you don\'t enough cash to do this!', type = 'error', duration = 5000 })
    end
end)

---------------------------------------------
-- remove credit
---------------------------------------------
RegisterNetEvent('rsg-camping:client:removecredit', function(data)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local cash = tonumber(PlayerData.money['cash'])
    local input = lib.inputDialog('Remove Credit', {
        { 
            label = 'Amount',
            type = 'input',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    
    if not input then
        return
    end
    
    if tonumber(input[1]) == nil then
        return
    end
    if tonumber(input[1]) < tonumber(data.credit)  then
        local creditadjust = tonumber(data.credit) - tonumber(input[1])
        TriggerServerEvent('rsg-camping:server:removecredit', creditadjust, tonumber(input[1]), data.propid )
    else
        lib.notify({ title = 'Not Enough Credit', description = 'you don\'t have that much credit!', type = 'error', duration = 5000 })
    end
end)

---------------------------------------------
-- remove prop object
---------------------------------------------
RegisterNetEvent('rsg-camping:client:removePropObject')
AddEventHandler('rsg-camping:client:removePropObject', function(prop)
    for i = 1, #SpawnedProps do
        local o = SpawnedProps[i]

        if o.id == prop then
            SetEntityAsMissionEntity(o.obj, false)
            FreezeEntityPosition(o.obj, false)
            DeleteObject(o.obj)
        end
    end
    Wait(1000)
    if lib.isTextUIOpen() then
        Wait(500)
        lib.hideTextUI()
    end
end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterNetEvent('rsg-camping:client:updatePropData')
AddEventHandler('rsg-camping:client:updatePropData', function(data)
    Config.PlayerProps = data
end)

---------------------------------------------
-- place prop
---------------------------------------------
RegisterNetEvent('rsg-camping:client:placeNewProp')
AddEventHandler('rsg-camping:client:placeNewProp', function(proptype, pHash, item)
    RSGCore.Functions.TriggerCallback('rsg-camping:server:countprop', function(result)
        if proptype == 'camptent' and result > 0 then
            lib.notify({ title = 'Campsite Already Setup', description = 'you can only have one tent deployed', type = 'error', duration = 7000 })
            return
        end
        local pos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 3.0, 0.0)
        local heading = GetEntityHeading(PlayerPedId())
        local ped = PlayerPedId()

        if CanPlacePropHere(pos) and not IsPedInAnyVehicle(PlayerPedId(), false) and not isBusy then
            isBusy = true
            local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
            FreezeEntityPosition(ped, true)
            TaskStartScenarioInPlace(ped, anim1, 0, true)
            Wait(10000)
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            TriggerServerEvent('rsg-camping:server:newProp', proptype, pos, heading, pHash)
            isBusy = false

            return
        end

        lib.notify({ title = 'Restricted Area', description = 'can\'t place it here!', type = 'error', duration = 7000 })

        Wait(3000)
    end, proptype)
end)

---------------------------------------------
-- check to see if prop can be place here
---------------------------------------------
function CanPlacePropHere(pos)
    local canPlace = true

    local ZoneTypeId = 1
    local x,y,z =  table.unpack(GetEntityCoords(PlayerPedId()))
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, x,y,z, ZoneTypeId)
    if town ~= false then
        canPlace = false
    end

    for i = 1, #Config.PlayerProps do
        local checkprops = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
        local dist = #(pos - checkprops)
        if dist < 1.3 then
            canPlace = false
        end
    end
    
    return canPlace
end

---------------------------------------------
-- rob camp
---------------------------------------------
RegisterNetEvent('rsg-camping:client:robcamp')
AddEventHandler('rsg-camping:client:robcamp', function(data)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playercid = PlayerData.citizenid
    if playercid ~= data.cid then
        local hasItem = RSGCore.Functions.HasItem('lockpick', 1)
        if hasItem == true then
            TriggerServerEvent('rsg-camping:server:removeitem', 'lockpick', 1)
            local success = lib.skillCheck({'easy', 'easy', {areaSize = 60, speedMultiplier = 2}, 'hard'}, {'w', 'a', 's', 'd'})
            if success == true then
                TriggerServerEvent("inventory:server:OpenInventory", "stash", "camp_" .. data.playercid)
            else
                lib.notify({ title = 'Failed', description = 'try again!', type = 'error', duration = 7000 })
            end
        else
            lib.notify({ title = 'Lockpick Needed', description = 'you need a lockpick to access that!', type = 'error', duration = 7000 })
        end
    else
        lib.notify({ title = 'Warning', description = 'you can\'t rob your own camp!', type = 'error', duration = 7000 })
    end
end)

---------------------------------------------
-- camp storage
---------------------------------------------
RegisterNetEvent('rsg-camping:client:campstorage', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playercid = PlayerData.citizenid
    TriggerServerEvent("inventory:server:OpenInventory", "stash", 'camp_'..playercid, { maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots })
    TriggerEvent("inventory:client:SetCurrentStash", 'camp_'..playercid)
end)

---------------------------------------------
-- buy camp equipment
---------------------------------------------
RegisterNetEvent('rsg-camping:client:campingequipment')
AddEventHandler('rsg-camping:client:campingequipment', function()
    local CampingItems = {}
    CampingItems.label = "Camping Equipment"
    CampingItems.items = Config.CampingEquipment
    CampingItems.slots = #Config.CampingEquipment
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "CampingEquipment_"..math.random(1, 99), CampingItems)
end)

---------------------------------------------
-- clean up
---------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #SpawnedProps do
        local props = SpawnedProps[i].obj

        SetEntityAsMissionEntity(props, false)
        FreezeEntityPosition(props, false)
        DeleteObject(props)
    end
end)
