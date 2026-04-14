-- APTweaks_Server_Teleport.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, aptweaks_teleport = require("APTweaks"), {}

local aptweaks_temp = aptweaks.aptweaks_temp
local APTweaksVars = aptweaks.APTweaksVars

local addRole = aptweaks.addRole
local getRoles =  aptweaks.getRoles
local setupRole = aptweaks.setupRole
local deleteRole = aptweaks.deleteRole

-- Ajusta los parámetros iniciales de la teletransportación, y notifica al cliente.
---@param player table
---@param aptweaks_data table
---@param args table
---@return table|nil data
function aptweaks_teleport.teleportBeginsCommand(player, teleport, aptweaks_data, args)

    -- Si el cliente ya tiene un teletransporte en curso, o el sistema está deshabilitado, no hay nada qué hacer.
    if teleport or not APTweaksVars.TeleportSystemEnabled then return end

    local origin = {x = player:getX(), y = player:getY(), z = player:getZ()}
    local name = args.name
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
        destination = aptweaks_data.warps[name]

        if not destination then
            return {status = "denied", name = name, names = aptweaks_data.warps}
        end
    end

    -- Si se obtuvo un destino válido, proceder.
    if destination then
        aptweaks_data.teleport[player:getUsername()] = {origin = origin, destination = destination, time = getTimestampMs()}
        return {status = "proceed"}
    end
end

---comment
---@param player any El jugador asociado al cliente.
---@param teleport any
---@param args any
function aptweaks_teleport.teleportEndsCommand(player, teleport, args)

    if not teleport then return end

    if teleport.tempRole then
        deleteRole(teleport.tempRole)
    end

    local final = teleport.origin

    if args.status == "succeded" then
        final = teleport.destination
    end

    local x, y, z = player:getX(), player:getY(), player:getZ()
    local fX, fY, fZ = final.x, final.y, final.z

    -- Comprobar si el jugador está al menos cerca del lugar en donde debería.
    if math.abs(x - fX) <= 10 and math.abs(y - fY) <= 10 and math.abs(z - fZ) <= 1 then
        print("a") -- Esto tendría que ser un log o algo así.
    end

    aptweaks_temp.teleport[player:getUsername()] = nil
end

-- e.
---@param player table El jugador asociado al cliente.
---@param teleport table
---@param aptweaks_data table
---@param args table
---@return table|nil data
function aptweaks_teleport.teleportRequestedCommand(player, teleport, aptweaks_data, args)

    -- Si el cliente no envió antes un paquete begins, no hay nada qué hacer.
    if not teleport then return end

    -- Si el cliente envió el paquete demasiado rápido despùés del paquete begins, negar solicitud.
    if (getTimestampMs() - teleport.time) <= ((APTweaksVars.teleportDelay * 1000) + 800) then return end

    local x, y, z = player:getX(), player:getY(), player:getZ()
    local origin = teleport.origin

    -- Si el jugador no está en la misma localización en la que estaba cuando se envió el paquete begins, no hay nada qué hacer.
    if not (origin.x == x and origin.y == y and origin.z == z) then return end

    local playerRole = player:getRole()

    -- Si el rol del jugador no le permite teletransportarse, crear nuevo rol, y cambiarlo a él.
    if not playerRole:hasCapability(Capability.UseFastMoveCheat) then
        local defaults = playerRole:getDefaults()
        local default = false

        for i = 0, defaults:size() - 1 do
            local string = defaults:get(i)

            if string == "user" then
                default = true
                break
            end
        end

        -- Si el jugador no está asignado al grupo por defecto para los nuevos usaurios, denegar solicitud.
        if not default then
            return {status = "denied", customRole = true}
        end

        local newRoleName = "APTweaks_Teleport" .. "_" .. player:getUsername()
        local playerCapabilities = playerRole:getCapabilities()
        local capabilities = {}
        local newRole

        for i = 0, playerCapabilities:size() - 1 do
            table.insert(capabilities, playerCapabilities:get(i))
        end

        table.insert(capabilities, Capability.UseFastMoveCheat)
        addRole(newRoleName)

        local roles = getRoles()

        for i = 0, roles:size() - 1 do
            local role = roles:get(i)

            if role:getName() == newRoleName then
                newRole = role
                break
            end
        end

        aptweaks_temp.teleport.tempRole = newRole

        setupRole(newRole, "A temporary APTweaks Teleport role for a user", playerRole:getColor(), capabilities)
        player:setRole(newRole)
    end

    return {status = "approved", destination = teleport.location}
end


return aptweaks_teleport
