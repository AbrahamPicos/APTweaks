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

-- Obtiene las celdas que comprenden un area.
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

-- La parte de la lógica del comando `/claim` procesada del lado del servidor.
---@param player any
---@param args any
---@return table result
function commands.SafezoneClaimCommand(player, args) -- args = {action = action, x = x, y = y}
    local aptweaks_data = aptweaks.aptweaks_data
    local x, y = args.x, args.y
    local cellID = math.floor(x / 300) .. math.floor(y / 300)

    -- 1. Verificar si la celda existe y tiene áreas.
    local cellAreas = aptweaks_data.cells[cellID]

    if not cellAreas then
        return {text = "No estas dentro de un area reclamable."}
    end

    -- 2. Buscar el área que contiene las coordenadas.
    local targetArea = nil

    for i = 1, #cellAreas do
        local area = aptweaks_data.areas[cellAreas[i]]

        if area and x >= area.x1 and x <= area.x2 and y >= area.y1 and y <= area.y2 then
            targetArea = area
            break
        end
    end

    if not targetArea then
        return {text = "No estas dentro de un area reclamable."}
    end

    -- 3. Verificar si el área está siendo reclamada por otro jugador.
    local areaID = targetArea.x1 .. "," .. targetArea.y1

    for _, blockedID in pairs(aptweaks_temp.blocked) do

        if blockedID == areaID then
            return {text = "Alguien mas esta intentando reclamar esa area. Intente mas tarde."}
        end
    end

    -- 4. Vefiricar si el area debe ser removida en lugar de reclamada.
    if args.action == "remove" then

        if player:getAccessLevel() ~= "admin" then
            return {text = "¿Como puedes siquiera ejeutar esto?"}
        end

        local areaCells = getAreaCells(targetArea.x1, targetArea.x2, targetArea.y1, targetArea.y2)

        for ID, _ in pairs(areaCells) do

            -- Buscar y remover el areaID de la lista de áreas de la celda.
            for i = #aptweaks_data.cells[cellID], 1, -1 do

                if aptweaks_data.cells[cellID][i] == areaID then
                    table.remove(aptweaks_data.cells[cellID], i)
                    break
                end
            end

            -- Limpiar celdas vacías
            if #aptweaks_data.cells[cellID] == 0 then
                aptweaks_data.cells[cellID] = nil
            end
        end
        aptweaks_data.areas[areaID] = nil
        ModData.transmit("aptweaks")

        return {text = string.format("El area %s fue removida exitosamente.", areaID)}
    end

    -- 5. Verificar si ya existe una safehouse en el área.
    local x1, y1, x2, y2 = targetArea.x1, targetArea.y1, targetArea.x2, targetArea.y2

    if SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) then
        return {text = "El area ya esta reclamada."}
    end

    -- 6. Bloquear el área y proceder con la creación.
    aptweaks_temp.blocked[player:getUsername()] = areaID

    return {command = "CreateSafehouseCommand", data = {areaID = areaID, x1 = x1, y1 = y1, x2 = x2, y2 = y2}}
end

-- La parte de la lógica del comando `/aptweaks safezone add` procesada lado del servidor.
---@param args table
---@return table result
function commands.SafezoneAddCommand(player, args) -- args = {x1 = pos1.x, y1 = pos1.y, x2 = pos2.x, y2 = pos2.y}

    if player:getAccessLevel() ~= "admin" then
        return {text = "¿Como puedes siquiera ejeutar esto?"}
    end

    local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2

    -- 1. Validación de coordenadas.
    if x1 < 0 or y1 < 0 or x2 > 19799 or y2 > 15899 then
        return {text = "No puede usar coordenadas fuera del mapa."}
    end

    if x2 <= x1 or y2 <= y1 then
        return {text = "Es necesario que pos1 este en la esquina superior izquierda del area."}
    end

    if (x2 - x1) >= 300 or (y2 - y1) >= 300 then
        return {text = "El area no puede ser mayor o igual a 300 tiles."}
    end

    local areaID = x1 .. "," .. y1
    local aptweaks_data = aptweaks.aptweaks_data

    if aptweaks_data.areas[areaID] then
        return {text = "Esa area ya existe."}
    end

    -- 2. Obtención de las celdas que comprenden el área.
    local areaCells = getAreaCells(x1, x2, y1, y2)

    -- 3. Verificación de solapamiento.
    for cellID in pairs(areaCells) do
        local cellAreas = aptweaks_data.cells[cellID]

        if cellAreas then

            for i = 1, #cellAreas do
                local area2 = aptweaks_data.areas[cellAreas[i]]

                if area2 and not (x2 < area2.x1 or x1 > area2.x2 or y2 < area2.y1 or y1 > area2.y2) then
                    return {text = string.format("Ocurrio un error al indexar el area %s", areaID)}
                end
            end
        end
    end

    -- 4. Indexación del área.
    aptweaks_data.areas[areaID] = args

    for cellID in pairs(areaCells) do

        if not aptweaks_data.cells[cellID] then
            aptweaks_data.cells[cellID] = {}
        end
        table.insert(aptweaks_data.cells[cellID], areaID)
        ModData.transmit("aptweaks")
    end

    return {text = string.format("El area %s fue indexada correctamente", areaID)}
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