-- APTweaks_Server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Server_Commands")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

local isTableEmpty = aptweaks.isTableEmpty
local ProcessCommandResult = aptweaks.ProcessCommandResult
local SafezoneClaimCommand = commands.SafezoneClaimCommand
local SafezoneAddCommand = commands.SafezoneAddCommand
local TeleportCommand = commands.TeleportCommand
local WarpCommand = commands.WarpCommand

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local writeLog = aptweaks.writeLog
local SafeHouse = aptweaks.SafeHouse
local getServerOptions = aptweaks.getServerOptions
local getConnectedPlayers = aptweaks.getConnectedPlayers
local getSteamIDFromUsername = aptweaks.getSteamIDFromUsername

local serverOptions = getServerOptions()
-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod restrea a los jugadores conectados.
local onlinePlayers = {}
-- El mapa de datos de APTweaks. Se referencia aquí para un acceso más rápido en el evento OnTick.
local aptweaks_data

-- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por un cliente.
--- Evita problemas de sincronización.
aptweaks_temp.blocked = {}
-- El submapa de los clientes que se están teletransportando en este momento.
-- APTweaks deshabilita el anticheat "type2" del juego base para evitar que expulse a los clientes al intentar
--- teletransportarse. Si este submapa está vacío, vuelve a habilitarse.
-- también resuelve problemas de sincronización.
aptweaks_temp.inTeleport = {}

-- Crea el mapa de datos de APTweaks. También lo restablece si necesita limpiarlo.
---@param reset boolean Si el mapa debe restablecerse, lo que borrará todos los datos.
---@return table|nil result Devuelve un texto cuando reset es verdadero.
local function SetupData(reset)
    -- Las claves con las que se nombran a las tablas de ModData no admiten puntos, por lo que no puedo usar modID.
    aptweaks_data = ModData.getOrCreate("aptweaks")
    aptweaks.aptweaks_data = aptweaks_data

    if isTableEmpty(aptweaks_data) or reset then
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
        aptweaks_data.warps = {}
    end

    ModData.transmit("aptweaks")

    if reset then
        return {text = "Todos los datos de APTweaks han sido eliminados."}
    end
end

-- En el evento OnInitGlobalModData. Crea el mapa de Datos de APTweaks.
---@param isNewGame boolean Si GlobalModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(isNewGame)
    SetupData(false)
end

-- En el evento OnClientCommand.
---@param module string
---@param command string
---@param player table
---@param args table
local function OnClientCommand(module, command, player, args)

    if module ~= modID then return end

    local result

    -- Cuando el cliente usó el comando '/claim' o `/aptweaks safezone remove`.
    if command == "SafezoneClaimCommand" then -- args = {action = action, x = x, y = y, area = area}
        result = SafezoneClaimCommand(player, args)

    -- Cuando el cliente ejecutó el comando `/aptweaks safezone add`.
    elseif command == "SafezoneAddCommand" then -- args = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}
        result = SafezoneAddCommand(player, args)

    -- Cuando el cliente ejecutó el comando `/aptweaks cleardata`.
    elseif command == "ClearDataCommand" then -- args = {}
        result = SetupData(true)

    -- Cuando el cliente indicó que necesita teletransportarse.
    elseif command == "TeleportCommand" then -- args = {x = x, y = y, z = z, name = name}
        result = TeleportCommand(args)

    -- Cuando el cliente usó el comando `/aptweaks warp add|remove`.
    elseif command == "WarpCommand" then -- data = {action = action, name = warp, location = location}
        result = WarpCommand(args)

    -- Usaré esto para experimentación. -AbrahamPicos.
    elseif command == "something" then
        result = {text = ":" .. ""}
    end

    if result then
        ProcessCommandResult(player, result)
    end
end

-- En el evento OnTick.
-- Registra las conexiones y desconexiones de los clientes. Aquí se procesa lógica relacionada con el bloqueo de áreas, y el
--- sistema anticheat de APTweaks.
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
        end

        -- Si se debe comprobar el nivel de acceso del jugador. Se restablece a "None" si no están autorizados a tener un
        --- nivel de acceso mayor. Esto intenta parchar los exploits para escalar privilegios.
        if APTweaksVars.AnticheatSystemEnabled and isTableEmpty(aptweaks_data.allowedUsers) then
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

    -- Por cada jugador en onlinePlayers. Aquí se buscan las desconexiones.
    -- Esta lista contiene a los jugadores que estaban conectados el tick anterior, por lo que podrían no estarlo ahora.
    for username, _ in pairs(onlinePlayers) do
        local inTeleportTickStart = aptweaks_temp.inTeleport[username]

        -- Si el jugador se desconectó.
        if not currentPlayers[username] then
            onlinePlayers[username] = nil

            -- Si el jugador tenía un área bloqueada,lo que significa que perdió la conexión antes de añadir el área.
            if aptweaks_temp.blocked[username] then
                aptweaks_temp.blocked[username] = nil
            end
        end

        -- Si el jugador está en teletransporación.
        if inTeleportTickStart then

            if inTeleportTickStart == -1 then
                aptweaks_temp.inTeleport[username] = tick

            elseif tick - inTeleportTickStart >= 30 then
                aptweaks_temp.inTeleport[username] = nil
            end
        end
    end

    -- Por cada área bloqueada.
    -- Desbloquea el área si se confirma que la safehouse ha sido creada.
    for username, areaID in pairs(aptweaks_temp.blocked) do
        local area = aptweaks_data.areas[areaID]
        local x1, y1, x2, y2 = area.x1, area.y1, area.x2, area.y2

        if SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) then
            aptweaks_temp.blocked[username] = nil
        end
    end

    -- Si debe volverse a habilitar el anticheat type2.
    if serverOptions:getBoolean("AntiCheatProtectionType2") == false and isTableEmpty(aptweaks_data.inTeleport) then
        serverOptions:changeOption("AntiCheatProtectionType2", "true")
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnTick.Add(OnTick)
Events.OnClientCommand.Add(OnClientCommand)
