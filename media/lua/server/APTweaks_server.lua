-- APTweaks_server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- La ID del mod.
local modID = "com.github.abrahampicos.aptweaks"

-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod restrea a los jugadores conectados.
local onlinePlayers = {}

-- El mapa de datos de APTweaks.
-- Evidentemente esto no es persistente. Es sólo para la demostración. Está pendiente implementar ModData
--  para que los datos sean persistentes.
local aptweaks = {
    -- La versión de la estructura de datos. Se usará para saber si debe actualizarse cuando se actualiza el mod.
    dataversion = 1,
    -- El submapa de las áreas. Contiene toda la información de las áreas que pueden reclamarse.
    areas = {},
    -- El submapa que indexa las áreas por celda.
    -- APTweaks usa una cuadricula espacial para indexar las áreas, lo que reduce las iteraciones al acceder al mapa de datos.
    cells = {},
    -- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por otro clientes.
    blocked = {}
}

-- Las IDs de administradores Permitidas.
-- Tenga en cuenta que esto no está terminado. En el futuro las IDs se cargarán de un archivo.
local allowedUsers = {
    ["76561198978760030"] = "AbrahamPicos" -- Esta no es la ID real de AbrahamPicos.
}

-- El el evento OnServerStarted. Limpia el submapa de áreas bloqueadas.
-- APTweaks_server bloquea áreas cuando un usuario intenta reclamarlas para evitar que debido lag, puedan crearse varias
--  safehouses en la misma área. Que queden áreas bloqueadas es anormal, pero puede ocurrir luego de que que el servidor
--  se apage incorrectamente.
local function OnServerStarted()

    if aptweaks.blocked ~= {} then
        aptweaks.blocked = {}
    end
end

-- Comprueba si hay una safehouse en el área.
---@param x1 integer Abscisa del vértice superior izquierdo.
---@param y1 integer Ordenada del vértice superior izquierdo.
---@param x2 integer Abscisa del vértice inferior derecho.
---@param y2 integer Ordenada del vértice inferior derecho.
---@return boolean
local function IsSafeHouse(x1, y1, x2, y2)
    return SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) ~= nil
end

-- En el evento on tick. Registra las conexiones y desconexiones de los clientes. Aquí se procesa lógica relacionada con el
--  bloqueo de áreas, y el sistema anticheat de APTweaks.
---@param tick integer El tick actual.
local function OnTick(tick)
    local currentPlayers = {}

    -- Por cada jugador conectado. Aquí se buscan las nuevas conexiones, y está la lógica del anticheat.
    for i = 0, getConnectedPlayers():size() - 1 do
        local player = getConnectedPlayers():get(i)
        local username = player:getUsername()

        currentPlayers[username] = true

        -- Si el jugador se acaba de conectar.
        if not onlinePlayers[username] then
            onlinePlayers[username] = player
            triggerEvent("OnPlayerConnected", player)
        end

        -- Si se debe comprobar el nivel de acceso del jugador. Se restablece a "None" si no están autorizados a tener un
        --  nivel de acceso mayor. Esto intenta parchar los exploits para escalar privilegios.
        if SandboxVars.APTweaks.AnticheatSystemEnabled then
            local accessLevel = player:getAccessLevel()

            if accessLevel ~= "None" then
                local steamID = getSteamIDFromUsername(username)

                -- El juego tarda varios ticks en actualizar el nivel de acceso de un jugador cuando se usa setAccessLevel,
                --  tiempo en el cual, mantendrá el nivel de acceso actual, no podrá obtener su steamID, y no podrá volver
                --  a usar sobre él el método setAccessLevel, lo que probocará errores si no comprueba nil aquí.
                if steamID ~= nil then

                    if not allowedUsers[steamID] then
                        writeLog("APTweaks", "[APTweaksAnticheat] Jugador no autorizado escalando privilegios. Nombre: " .. username .. " ID: " .. steamID .. " Nivel de acceso: " .. accessLevel)
                        player:setAccessLevel("None")
                    end
                end
            end
        end
    end

    -- Por cada área bloqueada.
    --  Desbloquea el área si se confirma que la safehouse ha sido creada.
    for username, areaID in pairs(aptweaks.blocked) do
        local area = aptweaks.areas[areaID]
        local x1, y1, x2, y2 = area.x1, area.y1, area.x2, area.y2

        if IsSafeHouse(x1, y1, x2, y2) then
            aptweaks.blocked[username] = nil
        end
    end

    -- Por cada jugador en onlinePlayers. Aquí se buscan las desconexiones.
    for username, player in pairs(onlinePlayers) do

        -- Si un jugador se desconectó.
        if not currentPlayers[username] then
            onlinePlayers[username] = nil
            triggerEvent("OnPlayerDisconnected", player)

            -- Si el jugador tenía un área bloqueada,lo que significa que perdió la conexión antes de añadir el área.
            if aptweaks.blocked[username] then
                aptweaks.blocked[username] = nil
            end
        end
    end
end

-- En el evento OnCLientCommand.
---comment
---@param module string
---@param command string
---@param player table
---@param args table
local function OnClientCommand(module, command, player, args)

    -- Si el jugador no se desconectó para el momento en que se procesa su comando.
    if player ~= nil then

        if module == modID then
            local result = nil
            local data = nil

            -- Cuando el cliente usó el comando '/safezone claim'. Si se cumplen las condiciones, envia al cliente el comando
            --  "createSafehouse" , bloquea el área en questión, y comienza a restrear la safehouse del lado del servidor.
            if command == "claimCommand" then
                -- args = {cellID = cellID, x = x, y = y}
                local cellID = args.cellID
                local isInsideArea = false

                if aptweaks.cells[cellID] then
                    local x, y = args.x, args.y

                    for i = 1, #aptweaks.cells[cellID] do
                        local area = aptweaks.areas[aptweaks.cells[cellID][i]]
                        local x1, y1, x2, y2 = area.x1, area.y1, area.x2, area.y2

                        if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
                            local areaID = tostring(x1) .. "," .. tostring(y1)
                            local isBlocked = false

                            isInsideArea = true

                            for _, ID in pairs(aptweaks.blocked) do

                                if ID == areaID then
                                    isBlocked = true
                                    break
                                end
                            end

                            if not isBlocked then

                                if not IsSafeHouse(x1, y1, x2, y2) then
                                    aptweaks.blocked[player:getUsername()] = areaID

                                    data = {areaID = areaID, x1 = x1, y1 = y1, x2 = x2, y2 = y2}
                                    result = {command = "createSafehouse", data = data}

                                else
                                    result = {text = "El area ya esta reclamada."}
                                end
                            else
                                result = {text = "Intente mas tarde."}
                            end
                            break
                        end
                    end
                end

                if not isInsideArea then
                    result = {text = "No esta dentro de un area reclamable."}

                end
            -- Cuando el cliente ejecutó el comando /safezone define.
            elseif command == "safehouseDefineCommand" then
                -- args = {areaID = areaID, area = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}, cells = cells}
                local areaID = args.areaID

                if not aptweaks.areas[areaID] then
                    local failed = false
                    local insertionAreas = {}
                    local text = {}

                    for cellID, _ in pairs(args.cells) do
                        local areaNonAddable = false
                        local firstInsert = false

                        if not aptweaks.cells[cellID] then
                            firstInsert = true
                            aptweaks.cells[cellID] = {}
                            table.insert(text, string.format("[%s] Celda: %s. La celda no esta registrada, asi que se creara e indexara el area.", areaID, cellID))

                        else

                            local function IsOverlapping(area1, area2)
                                return not (area1.x2 < area2.x1 or area1.x1 > area2.x2 or area1.y2 < area2.y1 or area1.y1 > area2.y2)
                            end

                            for j = 1, #aptweaks.cells[cellID] do
                                local area2ID = aptweaks.cells[cellID][j]

                                if IsOverlapping(args.area, aptweaks.areas[area2ID]) then
                                    areaNonAddable = true
                                    failed = true
                                    table.insert(text, string.format("[%s] Celda: %s. Error: El area no puede añadirse porque estaria solapando al area %s.", areaID, cellID, area2ID))
                                    break
                                end
                            end
                        end

                        if not areaNonAddable then
                            insertionAreas[cellID] = areaID

                            if not firstInsert then
                            table.insert(text, string.format("[%s] Celda: %s. El area se indexara en el indice de la celda.", areaID, cellID))
                            end
                        end
                    end

                    if not failed then
                        aptweaks.areas[areaID] = args.area

                        for insertionCellID, insertionAreaID in pairs(insertionAreas) do
                            table.insert(aptweaks.cells[insertionCellID], insertionAreaID)
                        end
                        table.insert(text, 1, "La operacion se completo con exito. Detalles:")

                    else
                        table.insert(text, 1, "La operacion fracaso miserablemente. Detalles:")
                    end
                    result = {text = table.concat(text, "[NL]")}

                else
                    result = {text = "Esa area ya existe."}
                end

            -- Cuando el cliente confirma que terminó de procesar el comando "createSafehouse" enviado por el servidor.
            elseif command == "claimCommandSucess" then

                -- Si el cliente dijo que no pudo crear la safehouse, lo que es un fallo, elimina el bloqueo del área y el rastreo
                --  del área. Si es creada exitosamente, no hace nada para siguir rastreando el área.
                if not args.sucess then
                    aptweaks.blocked[args.blocked] = nil
                end

            -- Si el cliente envió el comando teleportPlayer. Teletransporta del lado del servidor al cliente.
            elseif command == "teleportPlayer" then
                local x, y, z = args.x, args.y, args.z

                player:setLocation(x, y, z)
                result = {command = "playerTeleported", data = {x = x, y = y, z = z}}

            -- Usaré esto para experimentación. -AbrahamPicos.
            elseif command == "something" then
                print("something.")
            end

            if result then
                local commandSend = result.command

                data = result.data

                if not commandSend then
                    commandSend = "messageCommand"
                    data = result
                end
                sendServerCommand(player, modID, commandSend, data)
            end
        end
    end
end

Events.OnServerStarted.Add(OnServerStarted)
Events.OnTick.Add(OnTick)
Events.OnClientCommand.Add(OnClientCommand)