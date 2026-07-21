-- APTweaks_Server_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")
local aptweaks_safezones, aptweaks_teleport = require("APTweaks_Server_Safezones"), require("APTweaks_Server_Teleport")

local getTimestampMs = getTimestampMs

local utils = aptweaks.utils
local commands = aptweaks.commands
local aptweaks_temp = aptweaks.aptweaks_temp
local APTweaksVars = aptweaks.APTweaksVars

local SetupData = utils.SetupData
local addSafezoneCommand = aptweaks_safezones.addSafezoneCommand
local claimSafezoneCommand = aptweaks_safezones.claimSafezoneCommand
local removeSafezoneCommand = aptweaks_safezones.removeSafezoneCommand
local teleportRequestCommand = aptweaks_teleport.teleportRequestCommand

-- La parte de la lógica del sistema de teletransporte procesada del lado del servidor.
---@param player IsoPlayer El jugador asociado al cliente.
---@param args table<string, string?> los argumentos del comando.
---@return APTResult? result
local function TeleportCommand(player, args) -- args = {name = name, action = action}

    -- Si el sistema está deshabilitado, no hay nada qué hacer.
    if not APTweaksVars.TeleportSystemEnabled then return end

    local action = args.action

    -- validar acciones.
    if not (action == "request") then return end

    local teleport = aptweaks_temp.teleport[player:getUsername()]
    local data

    -- Si el cliente tiene un teletransporte en curso.
    if teleport then

        -- Si está el cooldown, notificar tiempo restante.
        if teleport.cooldown then
            data = {status = "cooldown", time = math.abs(((getTimestampMs() - teleport.cooldown) / 1000) - APTweaksVars.TeleportCooldown)}

        else
            data = {status = "throttled"}
        end

    -- Si el cliente envió una nueva solicitud.
    elseif action == "request" then
        data = teleportRequestCommand(player, args)
    end

    -- Si hubo una inconsistencia grave, responder con un paquete denied vacío.
    if not data then
        data = {status = "denied"}
    end

    return {command = "TeleportCommand", data = data}
end

-- La parte de la lógica del sistema de safehouses sin edificios procesada del lado del servidor.
---@param player IsoPlayer Un IsoPlayer.
---@param args {action:string,x:number,y:number}
---@return APTResult? result
local function SafezoneCommand(player, args)

    -- Si el sistema de safehuses sin edificios no está habilitado, no hay nada qué hacer. 
    if not APTweaksVars.SafehouseSystemEnabled then return end

    local action = args.action
    local requireAdmin = {add = true, remove = true, claim = false}

    -- Validar permisos.
    if not APTweaksVars.CoopServerMode and (requireAdmin[action] and player:getRole():getName() ~= "admin") then
        return {text = "No tienes permitido realizar esa acción."}
    end

    local data = aptweaks_temp.aptweaks_data

    -- Si va a añadirse un área, añadirla y salir.
    if action == "add" then
        return addSafezoneCommand(args, data)
    end

    local x, y = args.x, args.y
    local cellID = math.floor(x / 256) .. "," .. math.floor(y / 256)
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
---@param player IsoPlayer El IsoPlayer asociado al cliente.
---@param args {action:string,name:string,location:location}
---@return APTResult? result
local function WarpCommand(player, args)
    local aptweaks_data = aptweaks_temp.aptweaks_data
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

            return {text = string.format("Warp %s añadido.", warp)}

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
    local warps = {} ---@type string[]

    for warp, _ in pairs(aptweaks_temp.aptweaks_data.warps) do
        table.insert(warps, warp)
    end

    return {command = "WarpsCommand", data = {names = warps}}
end

-- Reinicia el mapa de datos de APTweaks a sus valores predeterminados.
---@param player IsoPlayer El jugador asociado al cliente.
---@return APTResult? result
local function ClearDataCommand(player)

    if player:getRole():getName() ~= "admin" and not APTweaksVars.CoopServerMode then return end

    SetupData(true) -- Esto realmente lo elimina todo.

    return {text = "Todos los datos de APTweaks han sido eliminados."}
end

-- Alterna si el servidor debe manejar el sistema anti-AFK para un cliente.
-- Esto permite expulsar jugadores durante la pantalla de carga, pero el cliente debe notificar cuando entra y sale.
---@param player IsoPlayer El jugador asociado al cliente.
---@param args {start:boolean} Los argumentos del comando.
local function AfkAsistCommand(player, args)

    -- Si el jugador entró en la pantalla de carga, comenzar manejo.
    if args.start then
        aptweaks_temp.afk[player:getUsername()] = getTimestampMs()

    -- De lo contrario, dejar de manejar.
    else
        aptweaks_temp.afk[player:getUsername()] = nil
    end
end

-- Regitrar los comandos de cliente de APTweaks.
commands.AfkAsistCommand = {
    handler = function (player, args) return AfkAsistCommand(player, args) end
}
commands.ClearDataCommand = {
    handler = function (player, _) return ClearDataCommand(player) end
}
commands.WarpCommand = {
    handler = function(player, args) return WarpCommand(player, args) end
}
commands.WarpsCommand = {
    handler = function (_, _) return WarpsCommand() end
}
commands.SafezoneCommand = {
    handler = function (player, args) return SafezoneCommand(player, args) end
}
commands.TeleportCommand = {
    handler = function (player, args) return TeleportCommand(player, args) end
}
commands.Something = {
    handler = function (_, _) return nil end
}
