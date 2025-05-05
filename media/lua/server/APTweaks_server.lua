-- APTweaks_server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

require("APTweaks.lua")

local modID = "com.github.abrahampicos.aptweaks"

-- El mapa de datos de APTweaks.
-- Evidentemente esto no es persistente. Es sólo para la demostración. Está pendiente implementar ModData
--  para que los datos sean persistentes.
local aptweaks = {
    -- La versión de la estructura de datos. Se usará para saber si debe actualizarse cuando se actualiza el mod.
    dataversion = 1,
    -- El submapa de las áreas. Contiene toda la información de las áreas que pueden reclamarse.
    areas = {},
    -- Un índice que registra las áreas que contiene cada celda para un acceso más rápido con iteraciones.
    cells = {},
    -- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por otro ciente.
    --  Está aquí para evitar problemas de sincronización.
    blocked = {},
    -- El submapa de las áreas en espera. Aquellas que se crearon y están esperando confirmación de haber sido creadas.
    tracking = {}
}

-- Las IDs de administradores Permitidas.
local allowedUsers = {
    ["76561198978760030"] = "AbrahamPicos"
}

-- El el evento OnServerStarted. Verifica si hay áreas bloqueadas cuando se inicia el servidor, y limpia la tabla.
--  Que queden áreas bloqueadas es anormal, pero puede ocurrir luego de que que el servidor se apage incorrectamente.
--  El servidor bloquea áreas cuando un usuario intenta reclamarlas para evitar que debido lag, puedan crearse varias
--  safehouses en la misma área.
local function OnServerStarted()

    if aptweaks.blocked ~= {} then
        aptweaks.blocked = {}
    end
end

-- En el evento on tick. Procesa el anticheat y la eliminación del bloqueo de áreas cuando la creación de la safehouse es
--  exitosa.
local function OnTick(tick)
    local trackingLenght = #aptweaks.tracking

    -- Espera a que las safehouses creadas por los clientes figuren en el servidor, lo que significa que la creación fue exitosa,
    --  y luego elimina el bloqueo de esas áreas.
    -- El servidor rastrea las áreas que debieron crearse del lado del cliente para asegurarse de que existan antes de remover
    --  el bloqueo del área. Esto es importante, ya que se comprueba del lado del servidor si existe una safehouse en el lugar
    --  cuando un cliente intenta reclamar una.
    if trackingLenght >= 1 then

        for i = 1, trackingLenght do
            local areaID = aptweaks.tracking[i]
            local area = aptweaks.areas[areaID]
            local safehouse = SafeHouse.getSafeHouse(area.x1, area.y1, area.x2 - area.x1, area.y2 - area.y1)

            if safehouse ~= nil then

                for username, ID in pairs(aptweaks.blocked) do

                    if ID == areaID then
                        aptweaks.blocked[username] = nil
                        table.remove(aptweaks.tracking, areaID)
                        break
                    end
                end
            end
        end
    end

    -- Verifica constantemente el nivel de acceso de los jugadores y lo restablece a "None" si no están autorizados a tener un
    --  nivel de acceso mayor. Esto intenta parchar los exploits para escalar privilegios.
    if SandboxVars.APTweaks.AnticheatSystemEnabled then

        for i = 0, getOnlinePlayers():size() - 1 do
            local player = getOnlinePlayers():get(i)
            local accessLevel = player:getAccessLevel()

            if accessLevel ~= "None" then
                local username = player:getUsername()
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
end

-- En el evento OnCLientCommand.
local function OnClientCommand(module, command, player, args)

    if module == modID then
        local commandSend = {command = "messageCommand"}
        local data = nil

        -- Cuando el cliente usó el comando '/safezone claim'. Envia al cliente el comando "createSafehouse" si se cumplen
        --  las condiciones, bloquea el área en questión, y comienza a restrear la safehouse del lado del servidor.
        if command == "claimCommand" then
            local cellID = args.cellID
            local isInsideArea = false

            if aptweaks.cells[cellID] then
                local x, y = args.x, args.y

                for i = 1, #aptweaks.cells[cellID] do
                    local coords = aptweaks.areas[aptweaks.cells[cellID][i]]
                    local x1, y1, x2, y2 = coords.x1, coords.y1, coords.x2, coords.y2

                    if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
                        local areaID = x1 .. "," .. y1
                        local isBlocked = false

                        isInsideArea = true

                        for _, ID in pairs(aptweaks.blocked) do

                            if ID == areaID then
                                isBlocked = true
                                break
                            end
                        end

                        if not isBlocked then
                            local w, h = (x2 - x1) + 1, (y2 - y1) + 1
                            local safehouse = SafeHouse.getSafeHouse(x1, y1, w, h)

                            if not safehouse then
                                aptweaks.blocked[player:getUsername()] = areaID
                                table.insert(aptweaks.tracking, args.areaID)

                                data = {areaID = areaID, x1 = x1, y1 = y1, w = w, h = h}
                                commandSend = {command = "createSafehouse"}
                            else
                                data = {text = "El area ya esta reclamada."}
                            end
                        else
                            data = {text = "Intente mas tarde."}
                        end
                        break
                    end
                end
            end

            if not isInsideArea then
                data = {text = " No esta dentro de un area reclamable."}

            end
        elseif command == "safehouseDefineCommand" then
            local areaID = args.areaID
            local area = args.area
            local cells = args.cells
            local messages = {}

            if not aptweaks.areas[areaID] then
                aptweaks.areas[areaID] = area
                table.insert(messages, "Area añadida exitosamente. Detalles:")

                for cellID, areas in pairs(cells) do

                    if not aptweaks.cells[cellID] then
                        aptweaks.cells[cellID] = areas
                        table.insert(messages, "La celda no estaba registrada, asi que se creo e indexo el area. " .. areaID .. " " .. cellID)

                    else
                        for i = 1, #areas do
                            local exists = false

                            for j = 1, #aptweaks.cells[cellID] do

                                if aptweaks.cells[cellID][j] == areaID then
                                    exists = true
                                    table.insert(messages, "El area ya existia en el indice de la celda. " .. areaID .. " " .. cellID)
                                    break
                                end
                            end

                            if not exists then
                                table.insert(aptweaks.cells[cellID], areas[i])
                                 table.insert(messages, "El area se indexo en el indice de la celda. " .. areaID .. " " .. cellID)
                            end
                        end
                    end
                end

                for i = 1, #messages do
                    local message = {text = messages[i]}
                    sendServerCommand(player, modID, commandSend.command, message)
                end
            else
                data = {text = "Esa area ya existe."}
            end

        -- Cuando el cliente confirma que terminó de procesar el comando "createSafehouse" enviado por el servidor.
        elseif command == "claimCommandSucess" then

            -- Si el cliente dijo que no pudo crear la safehouse, lo que es un fallo, elimina el bloqueo del área y el rastreo
            --  del área. Si es creada exitosamente, no hace nada para siguir rastreando el área.
            if not args.success then
                aptweaks.blocked[args.blocked] = nil
                table.remove(aptweaks.tracking, args.areaID)
            end

        -- Usaré esto para experimentación. -AbrahamPicos.
        elseif command == "something" then
            print("something.")
        end

        if data ~= nil then
            sendServerCommand(player, modID, commandSend.command, data)
        end
    end
end

-- Verifica si uno de los usuarios con un área bloqueada salió del servidor.
-- Aunque es poco probable que dos o más jugadores intenten reclamar un área practicamente al mismo tiempo
--   esto está aquí para asegurarse de que no queden áreas bloqueadas hasta el siguiente reinicio
-- Si el cliente se desconectó, y el área no puede encontrarse aún, sinifica que nunca lo hará, así que también se elimina
--  el rastreo del área.
local function OnDisconnect()

    for username, areaID in pairs(aptweaks.blocked) do
        local online = false

        for i = 0, getOnlinePlayers():size() - 1 do

            if getOnlinePlayers():get(i):getUsername() == username then
                online = true
                break
            end
        end

        if not online then
            table.remove(aptweaks.tracking, areaID)
            aptweaks.blocked[username] = nil
        end
    end
end

Events.OnServerStarted.Add(OnServerStarted)
Events.OnTick.Add(OnTick)
Events.OnDisconnect.Add(OnDisconnect)
Events.OnClientCommand.Add(OnClientCommand)