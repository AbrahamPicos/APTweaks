-- APTweaks_Server_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")
local aptweaks_safezones, aptweaks_teleport = require("APTweaks_Server_Safezones"), require("APTweaks_Server_Teleport")

local getTimestampMs = aptweaks.getTimestampMs

local SetupData = aptweaks.SetupData
local addSafezoneCommand = aptweaks_safezones.addSafezoneCommand
local claimSafezoneCommand = aptweaks_safezones.claimSafezoneCommand
local removeSafezoneCommand = aptweaks_safezones.removeSafezoneCommand
local teleportEndsCommand = aptweaks_teleport.teleportEndsCommand
local teleportBeginsCommand = aptweaks_teleport.teleportBeginsCommand
local teleportRequestedCommand = aptweaks_teleport.teleportRequestedCommand

local aptweaks_temp = aptweaks.aptweaks_temp
local APTweaksVars = aptweaks.APTweaksVars

-- La parte de la lógica del sistema de teletransporte procesada del lado del servidor.
---@param player table El jugador asociado al cliente.
---@param args table los argumentos del comando.
---@return table|nil result
local function TeleportCommand(player, args) -- args = {name = name, status = status}
    local teleport = aptweaks_temp.teleport[player:getUsername()]
    local aptweaks_data = aptweaks.aptweaks_data
    local status = args.status
    local data

    -- Si es un paquete begins.
    if status == "begins" then
        data = teleportBeginsCommand(player, teleport, aptweaks_data, args)

    -- Si el cliente envió antes un paquete begins.
    elseif not teleport then

        -- si el paquete es requested.
        if status == "requested" then
            data = teleportRequestedCommand(player, teleport)

        -- Si el paquete es succeded o failed.
        elseif status == "succeded" or status == "failed" then
            teleportEndsCommand(player, teleport, args)
            return -- El cliente no espera respuesta en este caso.
        end
    end

    -- Si hubo una inconsistencia grave, responder con un paquete denied vacío.
    if not data then
        data = {status = "denied"}
    end

    -- Terminar.
    return {command = "TeleportCommand", data = data}
end

-- La parte de la lógica del sistema de safehouses sin edificios procesada del lado del servidor.
---@param player table Un IsoPlayer.
---@param args table 
---@return table|nil result
local function SafezoneCommand(player, args)

    -- Si el sistema de safehuses sin edificios no está habilitado no hay nada qué hacer. 
    if not APTweaksVars.SafehouseSystemEnabled then return end

    local requireAdmin = {add = true, remove = true, claim = false}
    local action = args.action

    -- Validar permisos.
    if not APTweaksVars.CoopServerMode and (requireAdmin[action] and player:getAccessLevel() ~= "admin") then
        return {text = "No tienes permitido realizar esa acción."}
    end

    local data = aptweaks.aptweaks_data

    -- Si va a añadirse un área, añadirla.
    if action == "add" then
        return addSafezoneCommand(args, data)
    end

    local x, y = args.x, args.y
    local cellID = math.floor(x / 300) .. math.floor(y / 300)
    local cellAreas = data.cells[cellID]
    local targetArea

    -- De lo contrario, buscar área objetivo para reclamar o remover.
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

-- Añade o remueve un warp del mapa de datos del mod.
-- args = {action = action, name = warp, location = {x = x, y = y, z = z}}
---@param player table El IsoPlayer asociado al cliente.
---@param args table
---@return table|nil result
local function WarpCommand(player, args)
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

-- Notifica al cliente la tabla de warps disponibles.
local function WarpsCommand()
    return {command = "WarpsCommand", data = {names = aptweaks.aptweaks_data.warps}}
end

-- Reinicia el mapa de datos de APTweaks a sus valores predeterminados.
---@return table|nil result
local function ClearDataCommand(player) -- args = {}

    if player:getAccessLevel() ~= "admin" and not APTweaksVars.CoopServerMode then return end

    SetupData(true) -- Esto realmente lo elimina todo.

    return {text = "Todos los datos de APTweaks han sido eliminados."}
end

-- Controla si el jugador debe expulsarse por pasar demasiado tiempo existiendo sin notificar que salió de la pantalla de carga.
---@param player table
---@param args table
local function AfkAsistCommand(player, args)

    if args.start then
        aptweaks_temp.afk[player:getUsername()] = getTimestampMs()

    else
        aptweaks_temp.afk[player:getUsername()] = nil
    end
end

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
    WarpsCommand = {
        handler = function (_, _) return WarpsCommand() end
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

return client_commands
