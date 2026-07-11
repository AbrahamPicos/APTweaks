-- APTweaks_Server_Teleport.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Esto tiene un problema serio, pues pese a las medidas de seguridad los jugadores aún podrán usarlo para atravezar paredes.

local aptweaks, aptweaks_teleport = require("APTweaks"), {}

---@class APTTeleport
---@field origin {x:number,y:number,z:number}
---@field destination {x:number,y:number,z:number}
---@field time integer
---@field name string
---@field tempRole string?
---@field sended boolean?
---@field cooldown integer?

local Capability = Capability

local deleteRole = deleteRole
local getTimestampMs = getTimestampMs
local sendServerCommand = sendServerCommand

local modID = aptweaks.modID
local utils = aptweaks.utils
local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

-- El submapa de los clientes que se están teletransportando en este momento.
aptweaks_temp.teleport = aptweaks_temp.teleport or {} ---@type table<string,APTTeleport?>

-- Obtiene la distancia al cuadrado entre dos puntos.
---@param p1 {x:number,y:number,z:number}
---@param p2 {x:number,y:number,z:number}
---@return number DistanceSquared
local function getDistanceSquared(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return dx*dx + dy*dy + dz*dz -- $dist^2 = \Delta x^2 + \Delta y^2 + \Delta z^2$
end

-- Remueve un teletransporte en curso.
---@param username string
---@param tempRole string?
---@param cooldown boolean
local function removeTeleport(username, tempRole, cooldown)

    if not cooldown then
        aptweaks_temp.teleport[username] = nil
    end

    if tempRole then
        deleteRole(tempRole)
    end
end

-- Autoriza al cliente para teletransportarse, y le notifica que comience.
---@param player IsoPlayer El jugador asociado al cliente.
---@param teleport APTTeleport
local function sendTeleport(player, teleport)
    local playerRole = player:getRole()

    -- Si el rol del jugador no le permite teletransportarse, crear nuevo rol, y cambiarlo a él.
    if not playerRole:hasCapability(Capability.UseFastMoveCheat) then

        -- Si el jugador tenía un rol personalizado, denegar solicitud y notificar problema.
        if not utils.isRoleUsersDefault(playerRole) then
            sendServerCommand(player, modID, "TeleportCommand", {status = "unauthorized"})
            removeTeleport(player:getUsername(), nil, false)
            return
        end

        local playerCapabilities = playerRole:getCapabilities():toArray()
        local capabilities = {Capability.UseFastMoveCheat}

        -- Obtener las capacidades actuales del jugador.
        for i = 0, playerCapabilities.length - 1 do
            table.insert(capabilities, playerCapabilities[i])    
        end

        local newRoleName = "APTweaks_Teleport_" .. player:getUsername()
        local newRole = utils.getNewRole(newRoleName, capabilities)

        -- Configurar, registrar, y aplicar el nuevo rol.
        player:setRole(newRole); teleport.tempRole = newRoleName
    end

    sendServerCommand(player, modID, "TeleportCommand", {status = "proceed"}); teleport.sended = true
end

-- Ajusta los parámetros iniciales de la teletransportación, y notifica al cliente.
---@param player IsoPlayer
---@param args table
---@return APTResult? data (nil si el paquete es malo)
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
        local aptweaks_data = aptweaks_temp.aptweaks_data

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

-- Registrar las acciones requeridas en el evento OnTick.
-- Necesita ejecutarse luego de onPlayerDisconected, por lo que no puede registrarse como función independiente en OnTick.
aptweaks_temp.onTick.APTweaksTeleport = function (tick)

    -- Por cada usuario en teletransporte.
    for username, teleport in pairs(aptweaks_temp.teleport) do
        local actualTime = getTimestampMs()

        -- Si el teletransporte está en cooldown, comprobar plazo y retornar.
        if teleport.cooldown then

            -- Si se cumplió el plazo, removerlo.
            if actualTime >= teleport.cooldown then
                aptweaks_temp.teleport[username] = nil
            end

            return
        end

        local player = aptweaks_temp.onlinePlayers[username] ---@cast player -? Garantizado por el orden de ejecución.
        local p = {x = player:getX(), y = player:getY(), z = player:getZ()}
        local o = teleport.origin

        -- Si el jugador no está donde se espera, actualizar teletransporte y retornar.
        if not (o.x == p.x and o.y == p.y and o.z == p.z) then
            local suceeded = false -- Si el cambio de coordenadas fue porque el teletransporte ocurrrió.

            -- Si el teletransporte ya fue enviado al cliente, comprobar distancias al origen y destino.
            if teleport.sended then
                local d = teleport.destination
                local distA, distB = getDistanceSquared(p, o), getDistanceSquared(p, d)
                local f = o

                -- Si el jugador está más cerca del destino, actualizar su localización esperada a esa, y aplicar cooldown.
                if distB < distA then
                    teleport.cooldown = getTimestampMs()
                    suceeded = true
                    f = d
                end

                -- Si el jugador no está razonablemente cerca de donde se espera, registrar en el log.
                if math.abs(p.x - f.x) <= 1 and math.abs(p.y - f.y) <= 1 and math.abs(p.z - f.z) <= 1 then
                    print("[APTweaks] WARN: Jugador " .. username .. " haciendo trampa, supongo.")
                end
            end

            -- Si el teletransporte no ocurrió, remover, y notificar al cliente.
            if not suceeded then
                sendServerCommand(player, modID, "TeleportCommand", {status = "failed"})
                removeTeleport(username, teleport.tempRole, false)
            end

            return
        end

        -- Si ya ha transcurrido el tiempo de retraso, preparar teletransporte y notificar al cliente.
        if not teleport.sended and (actualTime - teleport.time >= APTweaksVars.TeleportDelay * 1000) then
            sendTeleport(player, teleport)
        end
    end
end

-- Registrar las acciones requeridas en onPlayerDisconnected.
aptweaks_temp.onPlayerDisconnected.APTweaksTeleport = function (username)
    local teleport = aptweaks_temp.teleport[username]

    -- Si el jugador estaba en teletransporte, terminar.
    if teleport then
        removeTeleport(username, teleport.tempRole, teleport.cooldown)
    end
end

return aptweaks_teleport

-- Comprobar si el anticheat aplica instaantáneamente después de remover el permiso.
-- Buscar una forma de evitar que esto se use para atravezar paredes en PVP.
-- Implementar sistema TP-Ask.
-- El teleportCooldown debería ser persistente entre reinicios.