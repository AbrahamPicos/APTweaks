-- APTweaks_Server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Server_Commands")
local aptweaks_teleport = require("APTweaks_Server_Teleport")

local modID = aptweaks.modID
local aptweaks_temp = aptweaks.aptweaks_temp
local APTweaksVars = aptweaks.APTweaksVars

local SetupData = aptweaks.SetupData
local processCommandResult = aptweaks.processCommandResult
local WarpCommand = commands.WarpCommand
local AfkAsistCommand = commands.AfkAsistCommand
local SafezoneCommand = commands.SafezoneCommand
local TeleportCommand = commands.TeleportCommand
local ClearDataCommand = commands.ClearDataCommand
local teleportEndsCommand = aptweaks_teleport.teleportEndsCommand

local Color = aptweaks.Color
local Events = aptweaks.Events
local SafeHouse = aptweaks.SafeHouse
local getConnectedPlayers = aptweaks.getConnectedPlayers

-- El submapa de los jugadores que están en la pantalla de carga.
aptweaks_temp.afk = aptweaks_temp.afk or {}
-- El submapa de los jugadres pateados.
aptweaks_temp.kicked = aptweaks_temp.kicked or {}
-- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por algún cliente.
aptweaks_temp.blocked = aptweaks_temp.blocked or {}
-- El submapa de los clientes que se están teletransportando en este momento.
aptweaks_temp.teleport = aptweaks_temp.teleport or {}
-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod rastrea conexiones y desconexiones.
aptweaks_temp.onlinePlayers = aptweaks_temp.onlinePlayers or {}

local onlinePlayers = aptweaks_temp.onlinePlayers
local client_commands = {

    AfkAsistCommand = {
        handler = function (player, args) return AfkAsistCommand(player, args) end
    },
    ClearDataCommand = {
        handler = function (player, _) return ClearDataCommand(player) end
    },
    WarpCommand = {
        handler = function(player, args) return WarpCommand(player, args) end
    },
    SafezoneCommand = {
        handler = function (player, args) return SafezoneCommand(player, args) end
    },
    TeleportCommand = {
        handler = function (player, args) return TeleportCommand(player, args) end
    },
    Something = {
        handler = function (_, _) return nil end
    }
}

-- Devuelve un rol de kick para un jugador.
---@param player table
---@return table|nil role
local function getPlayerKickRole(player)
    local name = "APTweaks_Kick_" .. player:getUsername()
    local newRole = aptweaks.getNewRole(name)

    setupRole(newRole, "A temporary APTweaks Kick role", Color.red, {})
    return newRole
end

-- En el evento OnInitGlobalModData. Crea el mapa de Datos de APTweaks.
-- Este también es un buen punto para purgar datos.
---@param isNewGame boolean Si GlobalModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(isNewGame)
    local roles = getRoles()

    SetupData(false)

    -- Eliminar los roles de APTweaks rezagados. Esto puede pasar si el servidor se apaga incorrectamente.
    for i = 0, roles:size() - 1 do
        local role = roles:get(i)

        if luautils.stringStarts(role:getName(), "APTweaks_") then
            deleteRole(role) -- Esto también quita el rol a cualquier jugador desconectado que lo tenga.
        end
    end
end

-- En el evento OnClientCommand.
-- Ejeuta acciones cuando un cliente envió un comando relevante para APTweaks.
---@param module string La ID del módulo que envió el comando.
---@param command string El comando es sí.
---@param player table El IsoPlayer asociado al cliente que envió el comando.
---@param args table Los argumentos del comando.
local function OnClientCommand(module, command, player, args)

    -- Si el módulo no coincide con APTweaks, no hay nada que hacer.
    if module ~= modID then return end

    -- Manejar comando.
    local result = client_commands[command].handler(player, args)

    -- Procesar el resultado.
    if result then
        processCommandResult(player, result, modID)
    end
end

-- En el evento OnTick.
-- Rastrea conexiones y desconexiones de jugadores, y controla rutinas secundarias.
---@param tick integer El tick actual.
local function OnTick(tick)
    local players = getConnectedPlayers()
    local currentPlayers = {}

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

            -- Si el jugador tenía un área bloqueada, desbloquear.
            if aptweaks_temp.blocked[username] then
                aptweaks_temp.blocked[username] = nil
            end

            -- Si el jugador estaba en teletransporte, terminar.
            if aptweaks_temp.teleport[username] then
                teleportEndsCommand(username, aptweaks_temp.teleport[username], {status = "failed"})
            end

            -- Si el jugador estaba en la pantalla de carga, remover.
            if aptweaks_temp.afk[username] then
                aptweaks_temp.afk[username] = nil
            end

            local kick = aptweaks_temp.kicked[username]

            -- Si el jugador fue expulsado, eiminar rol de kick.
            if kick then
                deleteRole(kick)

                aptweaks_temp.kicked[username] = nil
            end

            -- Notificar de la desconexión a todos los clientes.
            sendServerCommand(modID, "PlayerDisconnected", {username = username})
        end
    end

    -- Por cada usuario en teletransporte.
    for username, teleport in pairs(aptweaks_temp.teleport) do

        -- Si exedió el tiempo límite, terminar.
        if (getTimestampMs() - teleport.time) >= 6000 then
            teleportEndsCommand(onlinePlayers[username] or username, teleport, {status = "failed"})
        end
    end

    -- Por cada jugador en la pantalla de carga.
    for username, time in pairs(aptweaks_temp.afk) do

        -- Si exedió el tiempo límite, expulsar.
        if (getTimestampMs() - time) >= ((APTweaksVars.AfkStart + APTweaksVars.AfkKick) * 1000) then
            local player = onlinePlayers[username]

            if onlinePlayers[username] then
                local kickRole = getPlayerKickRole(player)

                if kickRole then
                    player:setRole(kickRole)

                    aptweaks_temp.kicked[username] = kickRole
                end
            end

            aptweaks_temp.afk[username] = nil
        end
    end

    -- Por cada área bloqueada.
    for username, areaID in pairs(aptweaks_temp.blocked) do
        local area = aptweaks.aptweaks_data.areas[areaID]
        local x1, y1, x2, y2 = area.x1, area.y1, area.x2, area.y2

        -- Si la safehouse fue creada, desbloquear.
        if SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) then
            aptweaks_temp.blocked[username] = nil
        end
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnTick.Add(OnTick)
Events.OnClientCommand.Add(OnClientCommand)
