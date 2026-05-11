-- APTweaks_Server_Teleport.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Esto tiene un problema serio, pues pese a las medidas de seguridad los jugadores aún podrán usarlo para atravezar paredes.

local aptweaks, aptweaks_teleport = require("APTweaks"), {}

local setupRole = aptweaks.setupRole
local Capability = aptweaks.Capability
local deleteRole = aptweaks.deleteRole
local getTimestampMs = aptweaks.getTimestampMs

local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

-- Crea y devuélve un nuevo rol de teletransporte para un jugador basado en su rol actual.
-- Para evitar inconsistencias con los roles no hace nada si el rol proporcionado no es el rol por defecto.
---@param player table
---@param playerRole table
---@return table|nil role
local function teleportRoleForPlayer(player, playerRole)

    -- Si no es el rol por defecto para los nuevos usaurios, o no es de solo lectura, no hay nada que hacer.
    if not aptweaks.isRoleUsersDefault(playerRole) then return end

    local playerCapabilities = playerRole:getCapabilities()
    local capabilities = {Capability.UseFastMoveCheat}

    -- Obtener las capacidades actuales del jugador.
    for i = 0, playerCapabilities:size() - 1 do
        table.insert(capabilities, playerCapabilities:get(i))
    end

    local newRole = aptweaks.getNewRole("APTweaks_Teleport_" .. player:getUsername())

    -- Configurar y devolver el nuevo rol.
    setupRole(newRole, "A temporary APTweaks Teleport role", playerRole:getColor(), capabilities)
    return newRole
end

-- Ajusta los parámetros iniciales de la teletransportación, y notifica al cliente.
---@param player table
---@param args table
---@return table|nil data (nil si el paquete es malo)
function aptweaks_teleport.teleportRequestCommand(player, args)
    local origin = {x = player:getX(), y = player:getY(), z = player:getZ()}
    local name = args.name or args.username
    local destination

    -- Si el cliente quiere teletransportarse a otro jugador.
    if args.username then
        local requestedPlayer = aptweaks_temp.onlinePlayers[name]

        if not requestedPlayer then
            return {status = "denied", username = name}
        end

        -- Implementación del sistema TP-Ask pendiente.
        -- destination = {x = requestedPlayer:getX(), y = requestedPlayer:getY(), z = requestedPlayer:getZ()}

    -- Si el cliente quiere teletransportarse a un warp.
    elseif args.name then
        local aptweaks_data = aptweaks.aptweaks_data

        destination = aptweaks_data.warps[name]

        if not destination then
            return {status = "denied", name = name, names = aptweaks_data.warps}
        end
    end

    -- Validar y proceder.
    if destination then
        aptweaks_temp.teleport[player:getUsername()] = {origin = origin, destination = destination, time = getTimestampMs(), name = name}
        return {status = "proceed"}
    end
end

-- Autoriza al cliente para teletransportarse, y le notifica que comience.
---@param player table El jugador asociado al cliente.
---@param teleport table
---@return table|nil data
function aptweaks_teleport.teleportStartCommand(player, teleport)

    -- Si el cliente envió el paquete demasiado rápido despùés del paquete begins, negar solicitud.
    if (getTimestampMs() - teleport.time) <= ((APTweaksVars.TeleportDelay * 1000) + 800) then return end

    local x, y, z = player:getX(), player:getY(), player:getZ()
    local origin = teleport.origin

    -- Si el jugador no está en la misma localización en la que estaba cuando se envió el paquete begins, cancelar teletransporte.
    if not (origin.x == x and origin.y == y and origin.z == z) then
        aptweaks_temp.teleport[player:getUsername()] = nil
        return -- ERROR: Recuerda eliminar la lógica sobrante del lado del cliente o el cliente se quedará esperando.
    end

    local playerRole = player:getRole()

    -- Si el rol del jugador no le permite teletransportarse, crear nuevo rol, y cambiarlo a él.
    if not playerRole:hasCapability(Capability.UseFastMoveCheat) then
        local role = teleportRoleForPlayer(player, playerRole)

        -- Si el jugador tenía un rol personalizado, denegar solicitud y notificar problema.
        if not role then
            aptweaks_temp.teleport[player:getUsername()] = nil
            return {status = "denied", dynamicRole = true}
        end

        -- Registrar y aplica rol.
        teleport.tempRole = role

        player:setRole(role)
    end

    return {status = "approved", destination = teleport.location}
end -- WARN: Busca una forma de eliminar el teletransporte aquí, si no procede, sin repetirte.

-- Remueve un teletransporte en curso. ESTA FUNCION ES FEA.
---@param player table|string El jugador asociado al cliente, o su nombre de usaurio.
---@param teleport table
---@param action string
function aptweaks_teleport.teleportEndsCommand(player, teleport, action)
    local expected = teleport.origin
    local username = player

    -- Si el cliente tenía un rol temporal, eliminar rol.
    if teleport.tempRole then
        deleteRole(teleport.tempRole)
    end

    -- Si la teletransportación fue exitosa, comprobar destino en lugar de origen, e iniciar cooldown.
    if action == "succes" then
        teleport.cooldown = getTimestampMs()
        expected = teleport.destination

    -- De lo contrario, remover teletransporte.
    else
        aptweaks_temp.teleport[username] = nil
    end

    local fX, fY, fZ = expected.x, expected.y, expected.z

    -- Si el jugador aún está presente, comprobar localización.
    if type(player) == "table" then
        local x, y, z = player:getX(), player:getY(), player:getZ()

        username = player:getUsername()

        -- Comprobar si el jugador está al menos cerca del lugar en donde debería.
        if math.abs(x - fX) <= 10 and math.abs(y - fY) <= 10 and math.abs(z - fZ) <= 1 then
            player:setRole(aptweaks.getPlayerKickRole(player)) -- ERROR: Esto no está bien hecho.
        end
    end
end

-- En el evento OnTick.
-- Remueve el teletransporte de un usuario si alcanzó el tiempo límite, y maneja el teleport cooldown.
---@param tick integer El tick actual.
local function OnTick(tick)

    -- Por cada usuario en teletransporte.
    for username, teleport in pairs(aptweaks_temp.teleport) do
        local actualTime = getTimestampMs()

        -- Si el teletransporte está el cooldown, y se cumple el pazo, removerlo.
        if teleport.cooldown and actualTime >= teleport.cooldown then
            aptweaks_temp.teleport[username] = nil
            return
        end

        -- Si exedió el tiempo límite de respuesta, remover teletransporte.
        if (actualTime - teleport.time) >= 6000 then
            aptweaks_teleport.teleportEndsCommand(aptweaks.onlinePlayers[username] or username, teleport, "fail")
        end
    end
end

-- Registrar las acciones requeridas en onPlayerDisconnected.
aptweaks_temp.onPlayerDisconnected.APTweaksTeleport = function (username)

    -- Si el jugador estaba en teletransporte, terminar.
    if aptweaks_temp.teleport[username] then
        aptweaks.teleportEndsCommand(username, aptweaks_temp.teleport[username], {status = "failed"})
    end
end

-- Registrar la función OnTick en el evento, y devolver tabla.
Events.OnTick.Add(OnTick)

return aptweaks_teleport

-- Quizá sea más seguro verificar constantemente los movimientos del jugador durante el evento tick,
