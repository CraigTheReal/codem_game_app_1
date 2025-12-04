

ESX = exports['es_extended']:getSharedObject()


local GameLobbies = {}
local PlayerInLobby = {}


local function GenerateLobbyId()
    local lobbyId
    repeat
        lobbyId = math.random(1000, 9999)
    until not GameLobbies[lobbyId]
    return lobbyId
end

local function DetermineWinner(choice1, choice2)
    if choice1 == choice2 then
        return 'draw'
    end

    if (choice1 == 'rock' and choice2 == 'scissors') or
       (choice1 == 'paper' and choice2 == 'rock') or
       (choice1 == 'scissors' and choice2 == 'paper') then
        return 'player1'
    else
        return 'player2'
    end
end


local function BroadcastToLobby(lobbyId, eventType, data, excludePlayer)
    local lobby = GameLobbies[lobbyId]
    if not lobby then return end

    for _, playerId in ipairs(lobby.players) do
        if playerId ~= excludePlayer then
            TriggerClientEvent('codem-game:updateLobby', playerId, {
                type = eventType,
                data = data
            })
        end
    end
end


local function GetPlayerName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        return xPlayer.getName()
    end
    return "Unknown"
end


AddEventHandler('codem-phone:customApp:rps-game:getPlayerInfo', function(source, payload, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({ success = false, error = 'Player not found' })
        return
    end

    local currentLobby = PlayerInLobby[source]
    local lobbyData = nil

    if currentLobby and GameLobbies[currentLobby] then
        local lobby = GameLobbies[currentLobby]
        lobbyData = {
            id = lobby.id,
            bet = lobby.bet,
            status = lobby.status,
            players = {}
        }

        for _, pid in ipairs(lobby.players) do
            table.insert(lobbyData.players, {
                id = pid,
                name = GetPlayerName(pid),
                ready = lobby.ready[pid] or false
            })
        end

        -- If game is finished, include game results
        if lobby.status == 'finished' and #lobby.players == 2 then
            local player1 = lobby.players[1]
            local player2 = lobby.players[2]

            -- Determine result from current player's perspective
            local myResult = 'unknown'
            if lobby.winner == 'draw' then
                myResult = 'draw'
            elseif lobby.winner == 'player1' and source == player1 then
                myResult = 'win'
            elseif lobby.winner == 'player2' and source == player2 then
                myResult = 'win'
            else
                myResult = 'lose'
            end

            lobbyData.gameResult = {
                player1 = {
                    id = player1,
                    name = GetPlayerName(player1),
                    choice = lobby.choices[player1] or 'none'
                },
                player2 = {
                    id = player2,
                    name = GetPlayerName(player2),
                    choice = lobby.choices[player2] or 'none'
                },
                winner = lobby.winner or 'unknown',
                myResult = myResult,
                bet = lobby.bet
            }
        end
    end

    cb({
        success = true,
        money = xPlayer.getAccount('bank').money,
        playerName = xPlayer.getName(),
        currentLobby = lobbyData
    })
end)


AddEventHandler('codem-phone:customApp:rps-game:createLobby', function(source, payload, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({ success = false, error = 'Player not found' })
        return
    end

   
    if PlayerInLobby[source] then
        cb({ success = false, error = 'You are already in a lobby!' })
        return
    end

    local betAmount = tonumber(payload.bet) or 0

   
    if betAmount < 0 then
        cb({ success = false, error = 'Invalid bet amount' })
        return
    end

    if betAmount > 0 then
        local bankMoney = xPlayer.getAccount('bank').money
        if bankMoney < betAmount then
            cb({ success = false, error = 'Insufficient funds in bank' })
            return
        end
    end


    local lobbyId = GenerateLobbyId()
    GameLobbies[lobbyId] = {
        id = lobbyId,
        host = source,
        players = {source},
        bet = betAmount,
        status = 'waiting', 
        ready = {},
        choices = {},
        createdAt = os.time()
    }

    PlayerInLobby[source] = lobbyId

    cb({
        success = true,
        lobbyId = lobbyId,
        lobby = {
            id = lobbyId,
            bet = betAmount,
            status = 'waiting',
            players = {{
                id = source,
                name = GetPlayerName(source),
                ready = false
            }}
        }
    })
end)


AddEventHandler('codem-phone:customApp:rps-game:joinLobby', function(source, payload, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({ success = false, error = 'Player not found' })
        return
    end

    
    if PlayerInLobby[source] then
        cb({ success = false, error = 'You are already in a lobby!' })
        return
    end

    local lobbyId = tonumber(payload.lobbyId)
    local lobby = GameLobbies[lobbyId]

    if not lobby then
        cb({ success = false, error = 'Lobby not found' })
        return
    end

    if lobby.status ~= 'waiting' then
        cb({ success = false, error = 'Game already in progress' })
        return
    end

    if #lobby.players >= 2 then
        cb({ success = false, error = 'Lobby is full' })
        return
    end

    
    if lobby.bet > 0 then
        local bankMoney = xPlayer.getAccount('bank').money
        if bankMoney < lobby.bet then
            cb({ success = false, error = 'Insufficient funds in bank' })
            return
        end
    end


    table.insert(lobby.players, source)
    PlayerInLobby[source] = lobbyId

    
    local lobbyData = {
        id = lobby.id,
        bet = lobby.bet,
        status = lobby.status,
        players = {}
    }

    for _, pid in ipairs(lobby.players) do
        table.insert(lobbyData.players, {
            id = pid,
            name = GetPlayerName(pid),
            ready = lobby.ready[pid] or false
        })
    end

    -- Send notification to other players
    for _, pid in ipairs(lobby.players) do
        if pid ~= source then
            TriggerClientEvent('codem-game:sendNotification', pid, {
                header = 'RPS Game',
                message = GetPlayerName(source) .. ' joined your lobby!'
            })
        end
    end

    BroadcastToLobby(lobbyId, 'playerJoined', {
        playerId = source,
        playerName = GetPlayerName(source),
        lobby = lobbyData
    }, source)

    cb({
        success = true,
        lobby = lobbyData
    })
end)


AddEventHandler('codem-phone:customApp:rps-game:leaveLobby', function(source, payload, cb)
    local lobbyId = PlayerInLobby[source]
    if not lobbyId then
        cb({ success = false, error = 'Not in a lobby' })
        return
    end

    local lobby = GameLobbies[lobbyId]
    if not lobby then
        cb({ success = false })
        return
    end

    
    for i, pid in ipairs(lobby.players) do
        if pid == source then
            table.remove(lobby.players, i)
            break
        end
    end

    lobby.ready[source] = nil
    lobby.choices[source] = nil
    PlayerInLobby[source] = nil


    if #lobby.players == 0 then
        GameLobbies[lobbyId] = nil
    else
        
        BroadcastToLobby(lobbyId, 'playerLeft', {
            playerId = source,
            playerName = GetPlayerName(source)
        })

        
        if lobby.host == source then
            lobby.host = lobby.players[1]
        end
    end

    cb({ success = true })
end)


AddEventHandler('codem-phone:customApp:rps-game:setReady', function(source, payload, cb)
    local lobbyId = PlayerInLobby[source]
    if not lobbyId then
        cb({ success = false, error = 'Not in a lobby' })
        return
    end

    local lobby = GameLobbies[lobbyId]
    if not lobby then
        cb({ success = false })
        return
    end

    lobby.ready[source] = true

    
    local allReady = true
    for _, pid in ipairs(lobby.players) do
        if not lobby.ready[pid] then
            allReady = false
            break
        end
    end

    
    BroadcastToLobby(lobbyId, 'playerReady', {
        playerId = source,
        allReady = allReady
    })

    cb({ success = true, allReady = allReady })
end)

AddEventHandler('codem-phone:customApp:rps-game:makeChoice', function(source, payload, cb)
    local lobbyId = PlayerInLobby[source]
    if not lobbyId then
        cb({ success = false, error = 'Not in a lobby' })
        return
    end

    local lobby = GameLobbies[lobbyId]
    if not lobby then
        cb({ success = false })
        return
    end

    local choice = payload.choice
    if choice ~= 'rock' and choice ~= 'paper' and choice ~= 'scissors' then
        cb({ success = false, error = 'Invalid choice' })
        return
    end

    lobby.choices[source] = choice
    lobby.status = 'playing'


    if #lobby.players == 2 and lobby.choices[lobby.players[1]] and lobby.choices[lobby.players[2]] then
       
        local player1 = lobby.players[1]
        local player2 = lobby.players[2]
        local choice1 = lobby.choices[player1]
        local choice2 = lobby.choices[player2]

        local winner = DetermineWinner(choice1, choice2)

        local xPlayer1 = ESX.GetPlayerFromId(player1)
        local xPlayer2 = ESX.GetPlayerFromId(player2)


        if lobby.bet > 0 and xPlayer1 and xPlayer2 then
            if winner == 'player1' then

                xPlayer2.removeAccountMoney('bank', lobby.bet)
                xPlayer1.addAccountMoney('bank', lobby.bet)
            elseif winner == 'player2' then

                xPlayer1.removeAccountMoney('bank', lobby.bet)
                xPlayer2.addAccountMoney('bank', lobby.bet)
            end

        end

        lobby.status = 'finished'
        lobby.winner = winner

        -- Send personalized results to each player
        local baseResult = {
            player1 = {
                id = player1,
                name = GetPlayerName(player1),
                choice = choice1
            },
            player2 = {
                id = player2,
                name = GetPlayerName(player2),
                choice = choice2
            },
            winner = winner,
            bet = lobby.bet
        }

        -- Send to player1
        local result1 = baseResult
        if winner == 'draw' then
            result1.myResult = 'draw'
        elseif winner == 'player1' then
            result1.myResult = 'win'
        else
            result1.myResult = 'lose'
        end
        TriggerClientEvent('codem-game:updateLobby', player1, {
            type = 'gameFinished',
            data = result1
        })

        -- Send to player2
        local result2 = baseResult
        if winner == 'draw' then
            result2.myResult = 'draw'
        elseif winner == 'player2' then
            result2.myResult = 'win'
        else
            result2.myResult = 'lose'
        end
        TriggerClientEvent('codem-game:updateLobby', player2, {
            type = 'gameFinished',
            data = result2
        })
    else
        
        BroadcastToLobby(lobbyId, 'choiceMade', {
            playerId = source
        })
    end

    cb({ success = true })
end)


AddEventHandler('codem-phone:customApp:rps-game:resetGame', function(source, payload, cb)
    local lobbyId = PlayerInLobby[source]
    if not lobbyId then
        cb({ success = false, error = 'Not in a lobby' })
        return
    end

    local lobby = GameLobbies[lobbyId]
    if not lobby then
        cb({ success = false })
        return
    end

 
    lobby.status = 'waiting'
    lobby.ready = {}
    lobby.choices = {}

    BroadcastToLobby(lobbyId, 'gameReset', {})

    cb({ success = true })
end)


AddEventHandler('playerDropped', function(reason)
    local source = source
    local lobbyId = PlayerInLobby[source]

    if lobbyId then
        local lobby = GameLobbies[lobbyId]
        if lobby then
            
            for i, pid in ipairs(lobby.players) do
                if pid == source then
                    table.remove(lobby.players, i)
                    break
                end
            end

            lobby.ready[source] = nil
            lobby.choices[source] = nil



            if #lobby.players == 0 then
                GameLobbies[lobbyId] = nil
            else
                
                BroadcastToLobby(lobbyId, 'playerLeft', {
                    playerId = source,
                    playerName = 'Player'
                })

                
                if lobby.host == source then
                    lobby.host = lobby.players[1]
                end
            end
        end

        PlayerInLobby[source] = nil
    end
end)
