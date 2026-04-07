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

-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod rastrea conexiones y desconexiones.
aptweaks_temp.onlinePlayers = aptweaks_temp.onlinePlayers or {}
-- El submapa de los clientes que se están teletransportando en este momento.
aptweaks_temp.teleport = aptweaks_temp.teleport or {}
-- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por algún cliente.
aptweaks_temp.blocked = aptweaks_temp.blocked or {}

local onlinePlayers = aptweaks_temp.onlinePlayers
local client_commands = {

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

-- En el evento OnInitGlobalModData. Crea el mapa de Datos de APTweaks.
-- Este también es un buen punto para purgar datos.
---@param isNewGame boolean Si GlobalModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(isNewGame)
    local roles = getRoles()

    SetupData(false)

    -- Eliminar los roles de APTwekas rezagados. Esto puede pasar si el servidor se apaga incorrectamente.
    for i = 0, roles:size() - 1 do
        local role = roles:get(i)

        if luautils.stringStarts(role:getName(), "APTweaks_Teleport") then
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

-- Ejecuta acciones cuando un jugador se conecta al servidor.
---@param player table
local function AftherPlayerConnected(player)
    -- Notificar de la conexión a todos los clientes
    sendServerCommand(modID, "PlayerConnected", {username = player:getUsername()})
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

-- En el evento OnTick.
---@param tick integer El tick actual.
local function OnTick(tick)
    local currentPlayers = {}
    local players = getConnectedPlayers()

    -- Por cada jugador conectado.
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local username = player:getUsername()

        currentPlayers[username] = true

        -- Comprobar si el jugador se acaba de conectar.
        if not onlinePlayers[username] then
            onlinePlayers[username] = player

            AftherPlayerConnected(player)
        end

        --updatePlayerStatus(username, tick)
    end

    -- Por cada jugador conectado el tick anterior.
    for username, _ in pairs(onlinePlayers) do

        -- Comprobar si el jugador se desconectó.
        if not currentPlayers[username] then
            onlinePlayers[username] = nil

            AftherPlayerDisconected(username)
        end
    end

    -- Por cada cliente en teletransporte.
    for _, teleport in pairs(aptweaks_temp.teleport) do

        if teleport.time > 6000 then
            TeleportEndsCommand()
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
