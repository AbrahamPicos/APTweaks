-- APTweaks_Server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Server_Commands")

local modID = aptweaks.modID
local aptweaks_temp = aptweaks.aptweaks_temp

local SetupData = aptweaks.SetupData
local processCommandResult = aptweaks.processCommandResult
local SafezoneCommand = commands.SafezoneCommand
local TeleportCommand = commands.TeleportCommand
local WarpCommand = commands.WarpCommand
local ClearDataCommand = commands.ClearDataCommand

local Events = aptweaks.Events
local SafeHouse = aptweaks.SafeHouse
local getConnectedPlayers = aptweaks.getConnectedPlayers

local client_commands = {
    ClearDataCommand = {
        handler = function (_, _) return ClearDataCommand() end
    },
    WarpComand = {
        handler = function(_, args) return WarpCommand(args) end
    },
    SafezoneCommand = {
        handler = function (player, args) return SafezoneCommand(player, args) end
    },
    TeleportCommand = {
        handler = function (player, args) return TeleportCommand(player, args) end
    }
}
-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod restrea a los jugadores conectados.
local onlinePlayers = {}
-- El mapa de datos de APTweaks. Se referencia aquí para un acceso más rápido en el evento OnTick.
local aptweaks_data

-- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por un cliente.
--- Evita problemas de sincronización.
aptweaks_temp.blocked = {}
-- El submapa de los clientes que se están teletransportando en este momento.
-- También resuelve problemas de sincronización.
aptweaks_temp.inTeleport = {}

-- En el evento OnInitGlobalModData. Crea el mapa de Datos de APTweaks.
---@param isNewGame boolean Si GlobalModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(isNewGame)
    SetupData(false)
end

-- En el evento OnClientCommand.
-- Ejeuta acciones cuando un cliente envió un comando relevante para APTweaks.
---@param module string La ID del módulo que envió el comando.
---@param command string El comando es sí.
---@param player table El IsoPlayer asociado al cliente que envió el comando.
---@param args table Los argumentos del comando.
local function OnClientCommand(module, command, player, args)

    if module ~= modID then return end

    local result = client_commands[command].handler(player, args)

    if result then
        processCommandResult(player, result)
    end
end

-- Ejecuta acciones cuando un jugador se conecta al servidor.
---@param username string
local function AftherPlayerConnected(username)
    -- Notificar de la conexión a todos los clientes
    sendServerCommand(modID, "PlayerConnected", {username = username})
end

-- Ejecuta acciones cuando un jugador se desconectó del servidor.
---@param username string
local function AftherPlayerDisconected(username)
    -- Notificar de la desconexión a todos los clientes.
    sendServerCommand(modID, "PlayerDisconnected", {username = username})

    -- Si el jugador tenía un área bloqueada, desbloquear.
    if aptweaks_temp.blocked[username] then
        aptweaks_temp.blocked[username] = nil
    end
end

-- Actualiza los estados del jugador. Como cuando está en teletransporte.
---@param username string
---@param tick number
local function updatePlayerStatus(username, tick)
    -- Si el jugador está en teletransporación.
    local inTeleportTickStart = aptweaks_temp.inTeleport[username]

    if inTeleportTickStart then

        if inTeleportTickStart == -1 then
            aptweaks_temp.inTeleport[username] = tick

        elseif tick - inTeleportTickStart >= 30 then
            aptweaks_temp.inTeleport[username] = nil
        end
    end
end

-- En el evento OnTick.
---@param tick integer El tick actual.
local function OnTick(tick)
    -- Por cada jugador conectado.
    local currentPlayers = {}

    for i = 0, getConnectedPlayers():size() - 1 do
        local player = getConnectedPlayers():get(i)
        local username = player:getUsername()

        currentPlayers[username] = true

        -- Comprobar si el jugador se acaba de conectar.
        if not onlinePlayers[username] then
            onlinePlayers[username] = player

            AftherPlayerConnected(player)
        end

        updatePlayerStatus(username, tick)
    end

    -- Por cada jugador conectado el tick anterior.
    for username, _ in pairs(onlinePlayers) do

        -- Comprobar si el jugador se desconectó.
        if not currentPlayers[username] then
            onlinePlayers[username] = nil

            AftherPlayerDisconected(username)
        end
    end

    -- Por cada área bloqueada.
    for username, areaID in pairs(aptweaks_temp.blocked) do
        local area = aptweaks_data.areas[areaID]
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
