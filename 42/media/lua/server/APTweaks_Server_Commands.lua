-- APTweaks_Server_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), {}

local aptweaks_temp = aptweaks.aptweaks_temp

local isTableEmpty = aptweaks.isTableEmpty

local ModData = aptweaks.ModData
local SafeHouse = aptweaks.SafeHouse
local getServerOptions = aptweaks.getServerOptions

-- La instancia de la clase ServerOptions de la sesión actual.
-- Se usa para alterar la configuración del servidor en tiempo de ejecución.
local serverOptions = getServerOptions()

-- Función auxiliar de commands.SafezoneCommand: Obtiener las celdas que comprenden un area.
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

-- Función auxiliar de commands.SafezoneCommand: buscar área.
---@param x number
---@param y number
---@param data table
---@return table|nil area
local function findTargetArea(x, y, data)
    local cellID = math.floor(x / 300) .. math.floor(y / 300)
    local cellAreas = data.cells[cellID]

    if cellAreas then

        for i = 1, #cellAreas do
            local area = data.areas[cellAreas[i]]

            if area and x >= area.x1 and x <= area.x2 and y >= area.y1 and y <= area.y2 then
                return area
            end
        end
    end

    return nil
end

-- Función auxiliar de commands.SafezoneCommand: añadir área.
---@param args table
---@param data table
---@return table result
local function handleAdd(args, data) -- args = {x1 = pos1.x, y1 = pos1.y, x2 = pos2.x, y2 = pos2.y}
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

-- Función auxiliar de commands.SafezoneCommand: remover área.
---comment
---@param targetArea table
---@param data table
---@return table result
local function handleRemove(targetArea, data)
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
    ModData.transmit("aptweaks")

    return {text = string.format("El área %s fue removida exitosamente.", areaID)}
end

-- Función auxiliar de commands.SafezoneCommand: reclamar área.
local function handleClaim(player, targetArea)
    local areaID = targetArea.x1 .. "," .. targetArea.y1

    -- Verificar bloqueo
    for _, blockedID in pairs(aptweaks_temp.blocked) do

        if blockedID == areaID then
            return {text = "Alguien más está intentando reclamar esa área. Intente más tarde."}
        end
    end

    -- Verificar safehouse existente
    local x1, y1, x2, y2 = targetArea.x1, targetArea.y1, targetArea.x2, targetArea.y2

    if SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) then
        return {text = "El área ya está reclamada."}
    end

    -- Bloquear y proceder
    aptweaks_temp.blocked[player:getUsername()] = areaID
    return {command = "CreateSafehouseCommand", data = {areaID = areaID, x1 = x1, y1 = y1, x2 = x2, y2 = y2}}
end

-- La parte de la lógica del sistema de safehouses sin edificios procesada del lado del servidor.
---@param player table Un IsoPlayer.
---@param args table 
---@return table result
function commands.SafezoneCommand(player, args)
    local action = args.action

    -- Validar permisos
    local requireAdmin = {add = true, remove = true, claim = false}

    if requireAdmin[action] and player:getAccessLevel() ~= "admin" then
        return {text = "No tienes permitido realizar esa acción."}
    end

    local data = aptweaks.aptweaks_data

    -- Si va a añadirse un área, añadirla.
    if action == "add" then
        return handleAdd(args, data)
    end

    -- De lo contrario, buscar área objetivo.
    local targetArea = findTargetArea(args.x, args.y, aptweaks.aptweaks_data)

    if not targetArea then
        return {text = "Debe estar en un área reclamable."}
    end

    -- Reclamar o remover área.
    if action == "claim" then
        return handleClaim(player, targetArea)

    elseif action == "remove" then
        return handleRemove(targetArea, data)

    else
        return {text = "Debe proporcionar una acción válida."}
    end
end

-- Esto tiene problemas, pues si otro mod, -o el administrador-, cambia la configuración del anticheat en producción será
--- gravemente inconsistente.
function commands.TeleportCommand(player, args)

    -- Si es una solicitud desactiva el anticheat, de lo contrario verifica si su nombre estaba en la lista y lo elimina.
    if args.isRequest then
        local addPlayer = false

        if serverOptions:getBoolean("AntiCheatProtectionType2") then
            serverOptions:changeOption("AntiCheatProtectionType2", "false")
            addPlayer = true
        end

        -- Si `addPlayer` es true significa que es el primer jugador en intentar teletransportarse.
        -- Si `aptweaks_data.inTeleport` está vacía y addPlayer es false, significa que el anticheat ya estaba desactivado.
        -- Si `aptweaks_data.inTeleport` no está vacía y addPlayer es false, significa que el mod desactivó el anticheat.
        if addPlayer or isTableEmpty(aptweaks_temp.inTeleport) then
            aptweaks_temp.inTeleport[player:getUsername()] = -1
        end

        return {command = "TeleportPlayerCommand", data = args}

    else

        if aptweaks_temp.inTeleport[player:getUsername()] then
            aptweaks_temp.inTeleport[player:getUsername()] = nil
        end
    end
end

function commands.WarpCommand(args) -- data = {action = action, name = warp, location = location}
    local aptweaks_data = aptweaks.aptweaks_data
    local warp = args.warp

    if args.action == "add" then

        if not aptweaks_data.warps[warp] then
            aptweaks_data.warps[warp] = args.location
            ModData.transmit("aptweaks")

            return {text = string.format("warp %s añadido.", warp)}

        else
            return {text = "Ese warp ya existe."}
        end

    else

        if aptweaks_data.warps[warp] then
            aptweaks_data.warps[warp] = nil
            ModData.transmit("aptweaks")

            return {text = string.format("warp %s eliminado.", warp)}

        else
            return {text = string.format("El warp %s no existe.", warp)}
        end
    end
end

return commands