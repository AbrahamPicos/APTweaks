
local aptweaks, aptweaks_safezones = require("APTweaks"), {}

local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

local ModData = ModData
local SafeHouse = SafeHouse

-- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por algún cliente.
aptweaks_temp.blocked = aptweaks_temp.blocked or {} ---@type table<string,string?>

-- Obtiene las celdas que comprenden un area.
-- Basándose en las mediadas de la cuadrícula espacial de Project Zomboid.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return table<string,boolean?> areaCells
local function getAreaCells(x1, y1, x2, y2)
    local minX, maxX = math.floor(x1 / 256), math.floor(x2 / 256)
    local minY, maxY = math.floor(y1 / 256), math.floor(y2 / 256) 
    local areaCells = {} ---@type table<string,boolean?>

    for x = minX, maxX do
        
        for y = minY, maxY do
            local cellID = x .. ","  .. y

            areaCells[cellID] = true
        end
    end

    return areaCells
end

-- Indeaxa un área en una cuadricula espacial en un mapa en con el formato de APTweaks.
---@param args {x1:integer,y1:integer,x2:integer,y2:integer} Los argumentos del comando.
---@param data table El mapa de datos en el que se indexará el área.
---@return APTResult result
function aptweaks_safezones.addSafezoneCommand(args, data)
    local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2

    -- Validación de coordenadas
    if x1 < 0 or y1 < 0 or x2 > 19799 or y2 > 15899 then
        return {text = "No puede usar coordenadas fuera del mapa."}

    elseif x2 <= x1 or y2 <= y1 then
        return {text = "Es necesario que pos1 este en la esquina superior izquierda del area."}

    elseif (x2 - x1) >= 256 or (y2 - y1) >= 256 then
        return {text = "El area no puede ser mayor o igual a 256 tiles."}
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
                    --return {text = "IGUI_APTweaks_Chat_IndexingError", subs = {areaID}}
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
---@param player IsoPlayer El IsoPlayer asociado al cliente que hizó la solicitud. 
---@param targetArea table El área que está intentando reclamar.
---@return APTResult result
function aptweaks_safezones.claimSafezoneCommand(player, targetArea)
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
---@return APTResult result
function aptweaks_safezones.removeSafezoneCommand(targetArea, data)
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

-- En el evento OnTick.
-- Remueve el área bloqueada si se confirma que la safehouse apareció (obsoleto).
---@param tick integer El tick actual.
local function OnTick(tick)

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

-- Registrar las acciones reueridas en onPlayerDisconnected.
aptweaks_temp.onPlayerDisconnected.APTweaksSafezones = function (username)

    -- Si el jugador tenía un área bloqueada, desbloquear.
    if aptweaks_temp.blocked[username] then
        aptweaks_temp.blocked[username] = nil
    end
end

-- Registrar la función OnTick en el evento, y devolver tabla.
Events.OnTick.Add(OnTick)

return aptweaks_safezones
