-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local GameTimeInstance = aptweaks.GameTimeInstance
local player_flags = aptweaks.player_flags

local ProcessCommandResult = aptweaks.ProcessCommandResult

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local getText = aptweaks.getText
local getCore = aptweaks.getCore
local isClient = aptweaks.isClient
local getPlayer = aptweaks.getPlayer
local SafeHouse = aptweaks.SafeHouse
local sendClientCommand = aptweaks.sendClientCommand
local alreadyHaveSafehouse = aptweaks.alreadyHaveSafehouse

-- El mapa de datos de APTweaks. Se obtiene desde el servidor.
-- Esto rompe el estilo.
local aptweaks_data
-- Suma el tiemp que se ha pasado AFK hasta alcanzar un segundo.
local afkTimer = 0
-- El número de segundos que que se ha estado AFK.
local afkSeconds = 0
-- Suma el tiempo desde que se solicitó una teletransportación hasta alcanzar un segundo.
local teleportTimer = 0
-- El número de segundos que han pasado desde que se solicitó una teletransportación.
local teleportSeconds = 0

local function OnGameStart()
    player_flags.player = getPlayer()
end

-- Rellena labla que almacena el mapa de datos de APTweaks.
-- La tabla en la que se almacena la ModData localmente se encuentra en el módulo común APTweaks.lua. Esto permite que sea
--  accesible desde todos los módulos del mod.
-- La primera vez que se ejecuta rellena una tabla vacía, y cuando se actualiza, simplemente sobrescribe lo que ya hay. Esto es
--  prudente debido a que APTweaks no necesita crear o eliminar subtablas en su mapa de datos en tiempo de ejecución.
---@param data table La tabla con los datos que se rellenarán.
local function syncData(data)

    for k, v in pairs(data) do
        aptweaks.aptweaks_data[k] = v
    end
    aptweaks_data = aptweaks.aptweaks_data
end

-- En el evento OnInitGlobalModData. Obtiene la Global ModData de APTweaks al iniciar la sesión.
---@param newGame boolean Si GlobalModData se inicializa en un nuevo guardado. Esto no es relevante para este mod.
local function OnInitGlobalModData(newGame)
    syncData(ModData.get("aptweaks"))
end

-- En el evento OnReceiveGlobalModData. Obtiene la Global ModData de APTweaks si se actualizó posteriormente.
-- Esto ocurre cuando el servidor vuelve a enviar la tabla a todos los clientes usando `ModData.transmit("aptweaks")`.
---@param key string El nombre de la tabla que se está recibiendo.
---@param data table La tabla que se está recibiendo en sí.
local function OnReceiveGlobalModData(key, data)

    if key == "aptweaks" then
        syncData(data)
    end
end

-- En el evento OnServerCommand. Procesa los comandos enviados desde el servidor al cliente, los que tienen que ver con APTweaks.
--- Incluye la teletransportación, y la reclamación de safehouses.
---@param module string Suele usarse la ID del mod. Sirve para diferenciar entre comandos enviados por otros mods.
---@param command string El comando en sí, es como el "asunto" en un correo electrónico.
---@param args table Los argumentos del comando. Es una tabla que puede contener cualquier cosa.
local function OnServerCommand(module, command, args)
    local player = player_flags.player

    if not (player and module == modID) then return end

    local result

    if command == "createSafehouse" then
        local username = player:getUsername()
        local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2

        if not alreadyHaveSafehouse(player) then
            local safezone = SafeHouse.addSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1, username, false)

            -- No estoy seguro del porqué deben usarse estos métodos.
            safezone:setTitle(string.format("refugio de %s", username))
            safezone:setOwner(username)
            safezone:updateSafehouse(player)
            safezone:syncSafehouse()

            result = {text = "Safehouse creada exitosamente."}
            -- Por seguridad, el desbloqueo de areas se maneja completamente del lado del servidor.
        else
            result = {text = "Ya tienes o eres miembro de un refugio."}
        end

    elseif command == "teleportPlayer" then
        local x, y, z = args.x, args.y, args.z

        player:setX(x); player:setY(y); player:setZ(z); player:setLx(x); player:setLy(y); player:setLz(z)
        player:setHaloNote(string.format(getText("UI_APTweaks_TeleportSuccess"), args.name), 0, 255, 0, 500)
        player_flags.isTeleporting = nil

        result = {command = "teleportSuccess", data = {}}

    elseif command == "messageCommand" then
        result = {text = args.text}
    end
    ProcessCommandResult(player, result)
end

local function updateAfkStatus(player, deltaTime)

    if not APTweaksVars.AfkSystemEnable then return end

    if not player_flags.isMoving then
        afkTimer = afkTimer + deltaTime

        if afkTimer >= 1 or (afkTimer == deltaTime and afkSeconds == 0) then
            if afkTimer >= 1 then
                afkTimer = afkTimer - 1
                afkSeconds = afkSeconds + 1
            end

            if afkSeconds >= APTweaksVars.AfkStart then
                if player then
                    player:setHaloNote(getText("UI_APTweaks_Afk"), 255, 0, 0, 500)
                end

                if afkSeconds == APTweaksVars.AfkStart + APTweaksVars.AfkKick then
                    getCore():exitToMenu()
                end
            end
        end
    else
        if player and afkSeconds >= APTweaksVars.AfkStart then
            player:setHaloNote(getText("UI_APTweaks_AfkRemoved"), 0, 255, 0, 500)
        end
        afkTimer, afkSeconds = 0, 0
    end
end

local function updateTeleportStatus(player, deltaTime)

    if not APTweaksVars.WarpSystemEnabled then return end

    if not player_flags.isMoving and player_flags.isTeleporting then
        teleportTimer = teleportTimer + deltaTime

        if teleportTimer >= 1 or (teleportTimer == deltaTime and teleportSeconds == 0) then
            if teleportTimer >= 1 then
                teleportTimer = teleportTimer - 1
                teleportSeconds = teleportSeconds + 1
            end

            if teleportSeconds <= APTweaksVars.TeleportDelay then
                player:setHaloNote(
                    string.format(getText("UI_APTweaks_TeleportDelaying"), math.abs(teleportSeconds - APTweaksVars.TeleportDelay)),
                    0, 255, 0, 500)

                if teleportSeconds == APTweaksVars.TeleportDelay then
                    sendClientCommand(player, modID, "teleportNeeded", player_flags.teleportLocation)
                    -- El teleportDelay se maneja del lado del servidor.
                end
            end
        end
    else
        if player and (teleportTimer ~= 0 or teleportSeconds ~= 0) then
            player:setHaloNote(getText("UI_APTweaks_TeleportCancelled"), 255, 0, 0, 500)
        end
        player_flags.isTeleporting = nil
        teleportTimer, teleportSeconds = 0, 0
    end
end

-- En el evento OnTickEvenPaused.
-- Nota: En este juego la tasa de ticks es igual a los FPS.
---@param tick number
local function OnTickEvenPaused(tick)
    local deltaTime = GameTimeInstance:getTimeDelta()
    local player = player_flags.player

    if not isClient() then return end

    -- Es false si entra al servidor sin haber creado un personaje en la sesión previa.
    -- Los personajes muertos pueden seguir moviéndose, pero ya no son controlados por el jugador.
    if player and player:isAlive() then
        local x, y, z =  player:getX(), player:getY(), player:getZ()

        -- Hago esto porque IsoPlayer.isMoving es inconsistente.
        player_flags.isMoving = player_flags.lastX ~= x or player_flags.lastY ~= y or player_flags.lastZ ~= z

        if player_flags.isMoving then
            player_flags.lastX, player_flags.lastY, player_flags.lastZ = x, y, z
        end
    else
        player_flags.isMoving = nil
    end

    updateAfkStatus(player, deltaTime)
    updateTeleportStatus(player, deltaTime)
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnReceiveGlobalModData.Add(OnReceiveGlobalModData)
Events.OnGameStart.Add(OnGameStart)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnServerCommand.Add(OnServerCommand)
