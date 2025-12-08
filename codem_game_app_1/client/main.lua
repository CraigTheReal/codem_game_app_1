local appRegistered = false

RegisterNetEvent('codem-phone:phoneLoaded')
AddEventHandler('codem-phone:phoneLoaded', function()
    Wait(2000)
    LoadPhoneApp()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (resourceName == GetCurrentResourceName()) then
        Wait(2000)
        LoadPhoneApp()
    end
end)

function LoadPhoneApp()
    if appRegistered then
        print('^3[RPS-GAME] App already registered, skipping...^7')
        return
    end

    while GetResourceState('codem-phone') ~= 'started' do
        print('^3[RPS-GAME] Waiting for codem-phone to start...^7')
        Wait(100)
    end

    -- Small delay
    Wait(1000)

    -- Read HTML content
    local htmlContent = LoadResourceFile(GetCurrentResourceName(), 'ui/index.html')

    if not htmlContent then
        print('^1[RPS-GAME] Failed to load HTML content^7')
        return
    end

    print('^3[RPS-GAME] Attempting to register app...^7')

    -- Register the app
    local success, err = exports['codem-phone']:AddCustomApp({
        identifier = 'rps-game',
        name = 'RPS Game',
        icon = 'nui://codem_game_app_1/ui/icon.svg',
        ui = htmlContent,
        description = 'Rock Paper Scissors multiplayer betting game',
        defaultApp = false,
        notification = true,
        job = {
            -- ['police'] = { 3, 4 },
            -- ['ambulance'] = { 2, 3 }
        },
        onOpen = function()
            print('[RPS-GAME] RPS Game app opened')
            SendNUIMessage({
                type = 'appOpened'
            })
        end,
        onClose = function()
            print('[RPS-GAME] RPS Game app closed')
        end
    })

    if success then
        appRegistered = true
        print('^2[RPS-GAME] RPS Game app registered successfully!^7')
    else
        print('^1[RPS-GAME] Failed to register RPS Game app: ' .. tostring(err) .. '^7')
    end
end


RegisterNetEvent('codem-game:updateLobby')
AddEventHandler('codem-game:updateLobby', function(data)
    SendNUIMessage({
        type = 'broadcast',
        payload = data
    })
end)

RegisterNetEvent('codem-game:sendNotification')
AddEventHandler('codem-game:sendNotification', function(data)
end)
