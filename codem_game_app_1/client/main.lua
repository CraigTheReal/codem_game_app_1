

local appRegistered = false


CreateThread(function()

    while GetResourceState('codem-phone') ~= 'started' do
        Wait(100)
    end

    Wait(1000)

    local htmlContent = LoadResourceFile(GetCurrentResourceName(), 'ui/index.html')

    if not htmlContent then
        return
    end

  
    local success, err = exports['codem-phone']:AddCustomApp({
        identifier = 'rps-game',
        name = 'RPS Game',
        icon = 'nui://codem_game_app_1/ui/icon.svg',
        ui = htmlContent,
        description = 'Rock Paper Scissors multiplayer betting game',
        defaultApp = false,
        notification = true,
        onOpen = function()
            SendNUIMessage({
                type = 'appOpened'
            })
        end,
        onClose = function()
        end
    })

    if success then
        appRegistered = true
    end
end)


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
