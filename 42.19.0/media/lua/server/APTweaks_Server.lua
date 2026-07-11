-- APTweaks_Server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

require "APTweaks_Server_Utils"

local modID = aptweaks.modID
local utils = aptweaks.utils
local aptweaks_temp = aptweaks.aptweaks_temp
local APTweaksVars = aptweaks.APTweaksVars

local Events = Events

local pairs = pairs

local getRoles = getRoles
local deleteRole = deleteRole
local getTimestampMs = getTimestampMs
local sendServerCommand = sendServerCommand
local getConnectedPlayers = getConnectedPlayers

local onlinePlayers = aptweaks_temp.onlinePlayers

local luautils = luautils

-- Devuelve un rol de kick para un jugador.
---@param player IsoPlayer
---@return Role role
local function getPlayerKickRole(player)
    return utils.getNewRole("APTweaks_Kick_" .. player:getUsername(), {})
end

-- En el evento OnInitGlobalModData. Crea el mapa de Datos de APTweaks.
-- Este también es un buen punto para purgar datos.
---@param isNewGame boolean Si GlobalModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(isNewGame)
    local roles = getRoles()

    utils.SetupData(false)

    -- Eliminar los roles de APTweaks rezagados. Esto puede pasar si el servidor se apaga incorrectamente.
    for i = 0, roles:size() - 1 do
        local role = roles:get(i)
        local roleName = role:getName()

        if luautils.stringStarts(roleName, "APTweaks_") then
            deleteRole(roleName) -- Esto también quita el rol a cualquier jugador desconectado que lo tenga.
        end
    end
end

-- En el evento OnTick.
-- Rastrea conexiones y desconexiones de jugadores, y controla rutinas secundarias.
---@param tick integer El tick actual.
local function OnTick(tick)
    local players = getConnectedPlayers()
    local currentPlayers = {} ---@type table<string,boolean?>

    -- Por cada jugador conectado.
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local username = player:getUsername()

        currentPlayers[username] = true

        -- Comprobar si el jugador se acaba de conectar.
        if not onlinePlayers[username] then
            onlinePlayers[username] = player

            -- Notificar de la conexión a todos los clientes
            sendServerCommand(modID, "PlayerConnected", {username = player:getUsername()})
        end
    end

    -- Por cada jugador conectado el tick anterior.
    for username, _ in pairs(onlinePlayers) do

        -- Comprobar si el jugador se desconectó.
        if not currentPlayers[username] then
            onlinePlayers[username] = nil

            for _, task in pairs(aptweaks_temp.onPlayerDisconnected) do
                task(username)
            end

            -- Si el jugador estaba en la pantalla de carga, remover.
            if aptweaks_temp.afk[username] then
                aptweaks_temp.afk[username] = nil
            end

            -- Si el jugador fue expulsado, eliminar rol de kick.
            if aptweaks_temp.kicked[username] then
                deleteRole(aptweaks_temp.kicked[username])

                aptweaks_temp.kicked[username] = nil
            end

            -- Notificar de la desconexión a todos los clientes.
            sendServerCommand(modID, "PlayerDisconnected", {username = username})
        end
    end

    -- Lanzar tareas de los módulos,
    for _, task in pairs(aptweaks_temp.onTick) do
        task(tick)
    end

    -- Por cada jugador en la pantalla de carga.
    for username, time in pairs(aptweaks_temp.afk) do

        -- Si excedió el tiempo límite, expulsar.
        if (getTimestampMs() - time) >= ((APTweaksVars.AfkStart + APTweaksVars.AfkKick) * 1000) then
            local player = onlinePlayers[username]

            if player then
                local kickRole = getPlayerKickRole(player)

                player:setRole(kickRole); aptweaks_temp.kicked[username] = kickRole:getName()
            end

            aptweaks_temp.afk[username] = nil
        end
    end
end

Events.OnTick.Add(OnTick)
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnClientCommand.Add(function (module, command, player, args)
    utils.OnCommand(module, command, player, args)
end)
