-- APTweaks_Server_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), {}

local aptweaks_temp = aptweaks.aptweaks_temp

local SetupData = aptweaks.SetupData

local ModData = aptweaks.ModData
local addRole = aptweaks.addRole
local getRoles =  aptweaks.getRoles
local setupRole = aptweaks.setupRole
local SafeHouse = aptweaks.SafeHouse
local deleteRole = aptweaks.deleteRole

local APTweaksVars = aptweaks.APTweaksVars

-- La instancia de la clase ServerOptions de la sesión actual.
-- Se usa para alterar la configuración del servidor en tiempo de ejecución.
--local serverOptions = getServerOptions()

-- Obtiene las celdas que comprenden un area.
-- Basándose en las mediadas de la cuadrícula espacial de Project Zomboid.
---@param x1 number
---@param x2 number
---@param y1 number
---@param y2 number
---@return table areaCells
local function getAreaCells(x1, x2, y1, y2)
    local cx1, cy1 = math.floor(x1 / 300), math.floor(y1 / 300)
    local cx2, cy2 = math.floor(x2 / 300), math.floor(y2 / 300)
    local areaCells = {}

    for cx = cx1, cx2 do

        for cy = cy1, cy2 do
            local cellID = cx .. "," .. cy

            areaCells[cellID] = true
        end
    end

    return areaCells
end

-- Indeaxa un área en una cuadricula espacial en un mapa en con el formato de APTweaks.
---@param args table Los argumentos del comando.
---@param data table El mapa de datos en el que se indexará el área.
---@return table result
local function addSafezoneCommand(args, data) -- args = {x1 = pos1.x, y1 = pos1.y, x2 = pos2.x, y2 = pos2.y}
    local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2

    -- Validación de coordenadas
    if x1 < 0 or y1 < 0 or x2 > 19799 or y2 > 15899 then
        return {text = "No puede usar coordenadas fuera del mapa."}

    elseif x2 <= x1 or y2 <= y1 then
        return {text = "Es necesario que pos1 este en la esquina superior izquierda del area."}

    elseif (x2 - x1) >= 300 or (y2 - y1) >= 300 then
        return {text = "El area no puede ser mayor o igual a 300 tiles."}
    end

    -- Verificar si ya existe el área
    local areaID = x1 .. "," .. y1

    if data.areas[areaID] then
        return {text = "Esa area ya existe."}
    end

    -- Obtener las celdas que comprenden el área
    local areaCells = getAreaCells(x1, x2, y1, y2)

    -- Verificar solapamientos
    for cellID in pairs(areaCells) do
        local cellAreas = data.cells[cellID]

        if cellAreas then

            for i = 1, #cellAreas do
                local area2 = data.areas[cellAreas[i]]

                if area2 and not (x2 < area2.x1 or x1 > area2.x2 or y2 < area2.y1 or y1 > area2.y2) then
                    return {text = string.format("Ocurrio un error al indexar el area %s", areaID)}
                end
            end
        end
    end

    -- Proceder con la indexación del área
    data.areas[areaID] = args

    for cellID in pairs(areaCells) do

        if not data.cells[cellID] then
            data.cells[cellID] = {}
        end

        table.insert(data.cells[cellID], areaID)
        ModData.transmit("aptweaks")
    end

    return {text = string.format("El area %s fue indexada correctamente", areaID)}
end

-- Reclama un área como una safehouse para un cliente.
---@param player table El IsoPlayer asociado al cliente que hizó la solicitud. 
---@param targetArea table El área que está intentando reclamar.
---@return table result
local function claimSafezoneCommand(player, targetArea)
    -- Verificar safehouse existente
    local x1, y1, x2, y2 = targetArea.x1, targetArea.y1, targetArea.x2, targetArea.y2

    if SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) then
        return {text = "El área ya está reclamada."}
    end

    -- Verificar bloqueo
    local areaID = targetArea.x1 .. "," .. targetArea.y1

    for _, blockedID in pairs(aptweaks_temp.blocked) do

        if blockedID == areaID then
            return {text = "Alguien más está intentando reclamar esa área. Intente más tarde."}
        end
    end

    -- Bloquear y proceder
    aptweaks_temp.blocked[player:getUsername()] = areaID

    return {command = "CreateSafehouseCommand", data = {areaID = areaID, x1 = x1, y1 = y1, x2 = x2, y2 = y2}}
end

-- Remueve un área del mapa de datos de APTweaks,
---@param targetArea table El área que se eliminará.
---@param data table El mapa de datos del que se eliminará el área.
---@return table result
local function removeSafezoneCommand(targetArea, data)
    local areaID = targetArea.x1 .. "," .. targetArea.y1
    local areaCells = getAreaCells(targetArea.x1, targetArea.x2, targetArea.y1, targetArea.y2)

    for ID, _ in pairs(areaCells) do

        for i = #data.cells[ID], 1, -1 do

            if data.cells[ID][i] == areaID then
                table.remove(data.cells[ID], i)
                break
            end
        end

        if #data.cells[ID] == 0 then
            data.cells[ID] = nil
        end
    end

    data.areas[areaID] = nil

    return {text = string.format("El área %s fue removida exitosamente.", areaID)}
end

-- La parte de la lógica del sistema de safehouses sin edificios procesada del lado del servidor.
---@param player table Un IsoPlayer.
---@param args table 
---@return table|nil result
function commands.SafezoneCommand(player, args)

    -- Validar permisos.
    local requireAdmin = {add = true, remove = true, claim = false}
    local action = args.action

    if not APTweaksVars.CoopServerMode and (requireAdmin[action] and player:getAccessLevel() ~= "admin") then
        return {text = "No tienes permitido realizar esa acción."}
    end

    -- Si va a añadirse un área, añadirla.
    local data = aptweaks.aptweaks_data

    if action == "add" then
        return addSafezoneCommand(args, data)
    end

    -- De lo contrario, buscar área objetivo para reclamar o remover.
    local x, y = args.x, args.y
    local cellID = math.floor(x / 300) .. math.floor(y / 300)
    local cellAreas = data.cells[cellID]
    local targetArea

    if cellAreas then

        for i = 1, #cellAreas do
            local area = data.areas[cellAreas[i]]

            if area and x >= area.x1 and x <= area.x2 and y >= area.y1 and y <= area.y2 then
                targetArea = area
                break
            end
        end
    end

    if not targetArea then
        return {text = "Debe estar en un área reclamable."}
    end

    if action == "claim" then
        return claimSafezoneCommand(player, targetArea)

    elseif action == "remove" then
        return removeSafezoneCommand(targetArea, data)
    end
end

-- Ajusta los parámetros iniciales de la teletransportación, y notifica al cliente.
---@param player table
---@param aptweaks_data table
---@param args table
---@return table|nil data
local function TeleportBeginsCommand(player, teleport, aptweaks_data, args)

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
local function TeleportEndsCommand(player, teleport, args)

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
local function TeleportRequestedCommand(player, teleport, aptweaks_data, args)

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

-- i.
---@param player table El jugador asociado al cliente.
---@param args table los argumentos del comando.
---@return table|nil result 
function commands.TeleportCommand(player, args) -- args = name = name, status = status}
    local teleport = aptweaks_temp.teleport[player:getUsername()]
    local aptweaks_data = aptweaks.aptweaks_data
    local data

    if args.status == "begins" then
        data = TeleportBeginsCommand(player, teleport, aptweaks_data, args)

    elseif args.status == "requested" then
        data = TeleportRequestedCommand(player, teleport, aptweaks_data, args)

    elseif args.status == "succeded" or args.status == "failed" then
        TeleportEndsCommand(player, teleport, args)
        return
    end

    if not data then
        data = {status = "denied"}
    end

    return {command = "TeleportCommand", data = data}
end

-- Añade o remueve un warp del mapa de datos del mod.
-- args = {action = action, name = warp, location = {x = x, y = y, z = z}}
---@param player table El IsoPlayer asociado al cliente.
---@param args table
---@return table|nil result
function commands.WarpCommand(player, args)
    local aptweaks_data = aptweaks.aptweaks_data
    local warp = args.name

    if player:getRole():getName() ~= "admin" and not APTweaksVars.CoopServerMode then return end

    if args.action == "add" then
        local location = args.location
        local x, y, z = location.x, location.y, location.z

        if x < 0 or y < 0 or x > 19799 or y > 15899 then
            -- Aún hay que encontrar una forma de comprobar si `z` es segura.
            return {text = "No puede usar coordenadas fuera del mapa."}
        end

        if not aptweaks_data.warps[warp] then
            aptweaks_data.warps[warp] = location

            return {text = string.format("warp %s añadido.", warp)}

        else
            return {text = "Ese warp ya existe."}
        end

    elseif args.action == "remove" then

        if aptweaks_data.warps[warp] then
            aptweaks_data.warps[warp] = nil

            return {text = string.format("Warp %s eliminado.", warp)}

        else
            return {text = string.format("El warp %s no existe.", warp)}
        end
    end
end

-- Reinicia el mapa de datos de APTweaks a sus valores predeterminados.
---@return table|nil result
function commands.ClearDataCommand(player) -- args = {}

    if player:getAccessLevel() ~= "admin" and not APTweaksVars.CoopServerMode then return end

    SetupData(true)

    return {text = "Todos los datos de APTweaks han sido eliminados."}
end

return commands