-- APTweaks_Server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")
local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars

local ProcessCommandResult = aptweaks.ProcessCommandResult
local IsSafeHouse = aptweaks.IsSafeHouse

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local writeLog = aptweaks.writeLog
local triggerEvent = aptweaks.triggerEvent
local getServerOptions = aptweaks.getServerOptions
local alreadyHaveSafehouse = aptweaks.alreadyHaveSafehouse
local getConnectedPlayers = aptweaks.getConnectedPlayers
local getSteamIDFromUsername = aptweaks.getSteamIDFromUsername

-- La instancia de la clase ServerOptions de la sesión actual.
-- Se usa para alterar la configuración del servidor en tiempo de ejecución.
local serverOptions = getServerOptions()
-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod restrea a los jugadores conectados.
local onlinePlayers = {}
-- El mapa de datos de APTweaks. Se crea en el evento OnInitGlobalModData.
local aptweaks_data

-- Datos que APTweaks necesita en tiempo de ejecución, pero que no hace falta que persistan.
local aptweaks_temp = {
    -- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por otro clientes.
    blocked = {},
    -- El submapa de los clientes que se están teletransportando en este momento.
    -- APTweaks deshabilita el anticheat "type2" del juego base para evitar que expulse a los clientes al intentar
    --- teletransportarse. Si este submapa está vacío, vuelve a habilitarse.
    inTeleport = {}
}

-- Crea el mapa de datos de APTweaks. También lo restablece si necesita limpiarlo.
---@param reset boolean Si el mapa debe restablecerse, lo que borrará todos los datos.
local function SetupData(reset)
    -- Las claves con las que se nombran a las tablas de ModData no admiten puntos, por lo que no puedo usar modID.
    aptweaks_data = ModData.getOrCreate("aptweaks")

    if aptweaks_data == {} or reset then
        -- La versión de la estructura de datos. Se usará para saber si debe actualizarse cuando se actualiza el mod.
        aptweaks_data.dataversion = 1
        -- Las IDs de administradores Permitidas. El sistema anticheat de APTweaks no se habilitará hasta que haya almenos una.
        aptweaks_data.allowedUsers = {}
        -- El submapa de las áreas. Contiene toda la información de las áreas que pueden reclamarse como non-building safehouses.
        aptweaks_data.areas = {}
        -- El submapa que indexa las áreas por celda.
        -- APTweaks usa una cuadricula espacial para indexar las áreas, lo que reduce las iteraciones al acceder al mapa de datos.
        aptweaks_data.cells = {}
        -- El submapa que contiene los warps.
        -- Ahora mismo no son personalizables, pero se añadirá un comando `/setwarp` en el futuro.
        aptweaks_data.warps = {
            westpoint = {x = 11889, y = 6862, z = 0},
            rosewood = {x = 8078, y = 11419, z = 0},
            riverside = {x = 6448, y = 5313, z = 0},
            louisville = {x = 12650, y = 2020, z =0}
        }
    end

    if reset then
        ModData.transmit("aptweaks")
    end
end

-- En el evento OnInitGlobalModData. Crea el mapa de Datos de APTweaks.
---@param isNewGame boolean Si GlobalModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(isNewGame)
    SetupData(false)
end

-- El el evento OnServerStarted. Limpia el submapa de áreas bloqueadas.
-- APTweaks_server bloquea áreas cuando un usuario intenta reclamarlas para evitar que debido lag, puedan crearse varias
--- safehouses en la misma área. Que queden áreas bloqueadas es anormal, pero puede ocurrir luego de que que el servidor
--- se apage incorrectamente.
local function OnServerStarted()

    if aptweaks_temp.blocked ~= {} then
        aptweaks_temp.blocked = {}
    end
end

-- La parte de la lógica del comando `/safezone claim` procesada del lado del servidor.
---@param player any
---@param args any
---@return table|nil
local function SafezoneClaimCommand(player, args) -- args = {cellID = cellID, x = x, y = y}
    local data = nil
    local result = nil
    local cellID = args.cellID
    local isInsideArea = false

    if aptweaks_data.cells[cellID] then
        local x, y = args.x, args.y

        for i = 1, #aptweaks_data.cells[cellID] do
            local area = aptweaks_data.areas[aptweaks_data.cells[cellID][i]]
            local x1, y1, x2, y2 = area.x1, area.y1, area.x2, area.y2

            if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
                local areaID = tostring(x1) .. "," .. tostring(y1)
                local isBlocked = false

                isInsideArea = true

                for _, ID in pairs(aptweaks_temp.blocked) do

                    if ID == areaID then
                        isBlocked = true
                        break
                    end
                end

                if not isBlocked then

                    if not IsSafeHouse(x1, y1, x2, y2) then
                        aptweaks_temp.blocked[player:getUsername()] = areaID

                        data = {areaID = areaID, x1 = x1, y1 = y1, x2 = x2, y2 = y2}
                        result = {command = "createSafehouse", data = data}
                    else
                        result = {text = "El area ya esta reclamada."}
                    end
                else
                    result = {text = "Alguien más está intentando reclamar esa área. Intente mas tarde."}
                end
                break
            end
        end
    end

    if not isInsideArea then
        result = {text = "No esta dentro de un area reclamable."}
    end
    return result
end

-- La parte de la lógica del comando `/safezone define` procesada lado del servidor.
---@param args table Los argumentos del comando.
---@return table|nil result Una tabla con el resultado del comando.
local function SafezoneDefineCommand(args) -- args = {areaID = areaID, area = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}, cells = cells}
    local result = nil
    local areaID = args.areaID

    if not aptweaks_data.areas[areaID] then
        local failed = false
        local insertionAreas = {}
        local text = {}

        for cellID, _ in pairs(args.cells) do
            local areaNonAddable = false
            local firstInsert = false

            if not aptweaks_data.cells[cellID] then
                firstInsert = true
                aptweaks_data.cells[cellID] = {}
                table.insert(text, string.format("[%s] Celda: %s. La celda no esta registrada, asi que se creara e indexara el area.", areaID, cellID))

            else

                local function IsOverlapping(area1, area2)
                    return not (area1.x2 < area2.x1 or area1.x1 > area2.x2 or area1.y2 < area2.y1 or area1.y1 > area2.y2)
                end

                for j = 1, #aptweaks_data.cells[cellID] do
                    local area2ID = aptweaks_data.cells[cellID][j]

                    if IsOverlapping(args.area, aptweaks_data.areas[area2ID]) then
                        areaNonAddable = true
                        failed = true
                        table.insert(text, string.format("[%s] Celda: %s. Error: El area no puede anadirse porque estaria solapando al area %s.", areaID, cellID, area2ID))
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
            aptweaks_data.areas[areaID] = args.area

            for insertionCellID, insertionAreaID in pairs(insertionAreas) do
                table.insert(aptweaks_data.cells[insertionCellID], insertionAreaID)
            end
            table.insert(text, 1, "La operacion se completo con exito. Detalles:")

        else
            table.insert(text, 1, "La operacion fracaso miserablemente. Detalles:")
        end
        result = {text = table.concat(text, "[NL]")}

    else
        result = {text = "Esa area ya existe."}
    end
    return result
end

-- En el evento on tick. Registra las conexiones y desconexiones de los clientes. Aquí se procesa lógica relacionada con el
--- bloqueo de áreas, y el sistema anticheat de APTweaks.
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
        --- nivel de acceso mayor. Esto intenta parchar los exploits para escalar privilegios.
        if aptweaks_data ~= nil and APTweaksVars.AnticheatSystemEnabled and aptweaks_data.allowedUsers ~= {} then
            local accessLevel = player:getAccessLevel()

            if accessLevel ~= "None" then
                local steamID = getSteamIDFromUsername(username)

                -- El juego tarda varios ticks en actualizar el nivel de acceso de un jugador cuando se usa setAccessLevel,
                --- tiempo en el cual, mantendrá el nivel de acceso actual, no podrá obtener su steamID, y no podrá volver
                --- a usar sobre él el método setAccessLevel, lo que probocará errores si no comprueba nil aquí.
                if steamID ~= nil then

                    if not aptweaks_data.allowedUsers[steamID] then
                        writeLog("APTweaks", "[APTweaksAnticheat] Jugador no autorizado escalando privilegios. Nombre: " .. username .. " ID: " .. steamID .. " Nivel de acceso: " .. accessLevel)
                        player:setAccessLevel("None")
                    end
                end
            end
        end
    end

    -- Por cada área bloqueada.
    -- Desbloquea el área si se confirma que la safehouse ha sido creada.
    for username, areaID in pairs(aptweaks_temp.blocked) do
        local area = aptweaks_data.areas[areaID]
        local x1, y1, x2, y2 = area.x1, area.y1, area.x2, area.y2

        if IsSafeHouse(x1, y1, x2, y2) then
            aptweaks_temp.blocked[username] = nil
        end
    end

    -- Por cada jugador en onlinePlayers. Aquí se buscan las desconexiones.
    -- Esta lista contiene a los jugadores que estaban conectados el tick anterior, por lo que podrían no estarlo ahora.
    for username, _ in pairs(onlinePlayers) do
        local inTeleportTickStart = aptweaks_data.inTeleport[username]

        -- Si el jugador se desconectó.
        if not currentPlayers[username] then
            onlinePlayers[username] = nil
            triggerEvent("OnPlayerDisconnected", username)

            -- Si el jugador tenía un área bloqueada,lo que significa que perdió la conexión antes de añadir el área.
            if aptweaks_temp.blocked[username] then
                aptweaks_temp.blocked[username] = nil
            end
        end

        -- Si el jugador está en teletransporación.
        if inTeleportTickStart then

            if inTeleportTickStart == -1 then
                aptweaks_data.inTeleport[username] = tick

            elseif tick - inTeleportTickStart >= 30 then
                aptweaks_data.inTeleport[username] = nil
            end
        end
    end

    -- Si debe volverse a habilitar el anticheat type2.
    if serverOptions:getBoolean("AntiCheatProtectionType2") == false and aptweaks_data.inTeleport == {} then
        serverOptions:changeOption("AntiCheatProtectionType2", "true")
    end
end

-- En el evento OnCLientCommand.
---@param module string
---@param command string
---@param player table
---@param args table
local function OnClientCommand(module, command, player, args)

    -- Si el comando es uno de APTweaks, que que significa que contiene su ModID.
    if module == modID then
        local result = nil
        local data = nil

        -- Si el jugador no se ha desconectado para el momento en que se recibió su comando.
        if player ~= nil then

            -- Cuando el cliente usó el comando '/safezone claim'. Si se cumplen las condiciones, envia al cliente el comando
            --- "createSafehouse" , bloquea el área en questión, y comienza a restrear la safehouse del lado del servidor.
            if command == "claimCommand" then
                result = SafezoneClaimCommand(player, args)

            -- Cuando el cliente ejecutó el comando /safezone define.
            elseif command == "safehouseDefineCommand" then
                result = SafezoneDefineCommand(args)

            -- Cuando el cliente ejecutó el comando `/aptweaks cleardata`.
            elseif command == "clearData" then
                SetupData(true)

            -- Cuando el cliente indicó que necesita teletransportarse.
            elseif command == "teleportNeeded" then -- args = {x = x, y = y, z = z, name = name}
                local addPlayer = false

                if serverOptions:getBoolean("AntiCheatProtectionType2") then
                    serverOptions:changeOption("AntiCheatProtectionType2", "false")
                    addPlayer = true
                end

                if addPlayer or aptweaks_data.inTeleport ~= {} then
                    aptweaks_data.inTeleport[player:getUsername()] = -1
                end

                result = {command = "teleportPlayer", data = args}

            elseif command == "teleportSuccess" then -- args = {}

                if serverOptions:getBoolean("AntiCheatProtectionType2") == false and aptweaks_data.inTeleport ~= {} then

                    if aptweaks_data.inTeleport[player:getUsername()] ~= nil then
                        aptweaks_data.inTeleport[player:getUsername()] = nil
                    end
                end

                -- Usaré esto para experimentación. -AbrahamPicos.
            elseif command == "something" then
                print("something")
            end
        end

        if result and player ~= nil then
            ProcessCommandResult(player, result)
        end
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnServerStarted.Add(OnServerStarted)
Events.OnTick.Add(OnTick)
Events.OnClientCommand.Add(OnClientCommand)

print("[APTweaksDebug] APTweaks_Server.lua is loaded.")
