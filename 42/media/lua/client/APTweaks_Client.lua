-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local client_flags = aptweaks.client_flags

local ProcessCommandResult = aptweaks.ProcessCommandResult

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local getText = aptweaks.getText
local getCore = aptweaks.getCore
local isClient = aptweaks.isClient
local GameTime = aptweaks.GameTime
local getPlayer = aptweaks.getPlayer
local SafeHouse = aptweaks.SafeHouse
local sendClientCommand = aptweaks.sendClientCommand
local alreadyHaveSafehouse = aptweaks.alreadyHaveSafehouse

local aptweaks_temp = aptweaks.aptweaks_temp

aptweaks_temp.timers = {}

local function OnGameStart()
    client_flags.player = getPlayer()
end

-- En el evento OnInitGlobalModData.
-- Obtiene la Global ModData de APTweaks al iniciar la sesión.
---@param newGame boolean Si GlobalModData se inicializa en un nuevo guardado. Esto no es relevante para este mod.
local function OnInitGlobalModData(newGame)
    aptweaks.aptweaks_data = ModData.get("aptweaks")
end

-- En el evento OnReceiveGlobalModData.
-- Obtiene la Global ModData de APTweaks si se actualizó posteriormente. Esto ocurre cuando el servidor vuelve a enviar la tabla
--  a todos los clientes usando `ModData.transmit("aptweaks")`.
-- APTweaks no necesita crear o eliminar subtablas de su mapa de datos en tiempo de ejecución, por eso simplemente lo sobrescribe.
---@param key string El nombre de la tabla que se está recibiendo.
---@param data table La tabla que se está recibiendo en sí.
local function OnReceiveGlobalModData(key, data)

    if key == "aptweaks" then
        aptweaks.aptweaks_data = data -- Probablemente hacer esto está mal, ya que dejaría de ser un objeto ModData.
    end
end

-- En el evento OnServerCommand.
-- Procesa los comandos enviados por APTweaks desde el servidor al cliente. Incluye la teletransportación, y la reclamación de
--  safehouses.
---@param module string Suele usarse la ID del mod. Sirve para diferenciar entre comandos enviados por otros mods.
---@param command string El comando en sí, es como el "asunto" en un correo electrónico.
---@param args table Los argumentos del comando. Es una tabla que puede contener cualquier cosa.
local function OnServerCommand(module, command, args)
    local player = client_flags.player

    -- Si no hay un jugador o el módulo no coincide, no hay nada que hacer.
    if not (player and module == modID) then return end

    local result

    if command == "MessageCommand" then -- args = {text = text}
        result = {text = args.text}

    elseif command == "CreateSafehouseCommand" then -- args = {x = x, y = y, z = z}
        local username = player:getUsername()
        local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2

        -- Esto evitará que se cree más de una safehouse si el usuario envia varias solicitudes en muy poco tiempo para reclamar
        --- áreas diferentes. Sin embargo, no hay garantía de que la primer solicitud que se hizo sea la primera en llagar hasta
        --- este punto, lo que produciría una inconsistencia.
        -- Como esto último es una inconsistencia menor, -y muy infrecuente-, decidí no hacer nada.
        if not alreadyHaveSafehouse(player) then
            local safezone = SafeHouse.addSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1, username, false)

            -- No estoy seguro del porqué deben usarse estos métodos, pero así lo hace Indie Stone.
            safezone:setTitle(string.format("refugio de %s", username))
            safezone:setOwner(username)
            safezone:updateSafehouse(player)
            safezone:syncSafehouse()

            result = {text = "Safehouse creada exitosamente."}
            -- Por seguridad, el desbloqueo de areas se maneja completamente del lado del servidor.
        else
            result = {text = "Ya tienes o eres miembro de un refugio."}
        end

    elseif command == "TeleportPlayerCommand" then -- args = {x = x, y = y, z = z, name = name}

        if client_flags.isTeleporting then

            local x, y, z = args.x, args.y, args.z

            player:setX(x); player:setY(y); player:setZ(z); player:setLx(x); player:setLy(y); player:setLz(z)
            player:setHaloNote(string.format(getText("IGUI_APTWeaks_HaloNote_TeleportSuccess"), args.name), 0, 255, 0, 500)
            client_flags.isTeleporting = nil
        end
        result = {command = "TeleportCommand", data = {isRequest = false}}
    end
    ProcessCommandResult(player, result)
end

-- Establece o respablece un tiemer.
---@param name string El nombre del timer.
local function setTimer(name)
    aptweaks_temp.timers[name] = {justAdded = true, counter = 0, cycles = 0}
end

-- Obtiene el ciclo actual de un timer.
---@param name string El nombre del timer.
---@return number cycle El número de ciclo.
local function getTimerCycle(name)
    return aptweaks_temp.timers[name].cycle
end

-- Actualiza un Timer, y devuelve sus variables.
---@param name string El nombre del timer.
---@param time number El tiempo que se añadirá al timer.
---@return number|nil cycle El número de ciclo.
---@return boolean isCycleUpdate Si esta actualización resultó en un nuevo ciclo.
local function getTimerUpdate(name, time)
    local timer = aptweaks_temp.timers[name]
    local isCycleUpdate = timer.justAdded

    timer.counter = timer.counter + time
    timer.justAdded = false

    if timer.counter >= 1 then
        timer.counter = timer.counter - 1
        timer.cycles = timer.cycles + 1
        isCycleUpdate = true
    end

    return timer.cycles, isCycleUpdate
end

-- Añadir Timers.
setTimer("afk")
setTimer("teleport")

-- Actualiza el estado AFK del jugador.
---@param player table El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que ocurrió desde el último tick.
---@param inMainMenu any Si el cliente aún está en el menú principal.
local function updateAfkStatus(player, deltaTime, inMainMenu)

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then

        if player and (getTimerCycle("afk") >= APTweaksVars.AfkStart) then
            player:setHaloNote(getText("IGUI_APTWeaks_HaloNote_AfkRemoved"), 0, 255, 0, 500)
        end

        setTimer("afk")
        return
    end

    -- Ejecutar acciones según el tiempo que ha pasado.
    local seconds, isWholeSecond = getTimerUpdate("afk", deltaTime)

    if not isWholeSecond then return end
    if seconds <= APTweaksVars.AfkStart then return end

    if player then
        player:setHaloNote(getText("IGUI_APTWeaks_HaloNote_Afk"), 255, 0, 0, 500) -- No hace nada si isAlive es false.
    end

    if seconds ~= APTweaksVars.AfkStart + APTweaksVars.AfkKick then return end

    if inMainMenu then
        getCore():quit()
        return
    end

    getCore():exitToMenu()
end

local function updateTeleportStatus(player, deltaTime)

    -- Si no se está en teletransporte o no se ha enviado una solicitud de teletransporte, no hay nada qué hacer.
    if not (client_flags.isTeleporting and client_flags.hasTeleportRequest) then return end

    if client_flags.isMoving then

        if not client_flags.hasTeleportRequest then
            player:setHaloNote(getText("IGUI_APTWeaks_HaloNote_TeleportCancelled"), 255, 0, 0, 500)
            setTimer("teleport")
        end

        client_flags.isTeleporting = nil
        return
    end

    local seconds, isWholeSecond = TimerManager:getUpdate("teleport", deltaTime)

        if not isWholeSecond then return end

        if seconds <= APTweaksVars.TeleportDelay then
            player:setHaloNote(string.format(getText("IGUI_APTWeaks_HaloNote_TeleportDelaying"), math.abs(teleportSeconds - APTweaksVars.TeleportDelay)), 0, 255, 0, 500)

            if seconds == APTweaksVars.TeleportDelay then
                sendClientCommand(player, modID, "TeleportCommand", {location = client_flags.teleportLocation, isRequest = true})
                client_flags.hasTeleportRequest = true
            end
        end
end

-- En el evento OnTickEvenPaused.
---@param tick number
local function OnTickEvenPaused(tick)

    if not isClient() and (APTweaksVars.AfkSystemEnabled or APTweaksVars.TeleportSystemEnabled) then return end

    local deltaTime = GameTime.getInstance():getTimeDelta() -- Esta instancia puede cambiar.
    local player = client_flags.player

    -- `IsoPlayer player` sólo puede ser false si el cliente entra al servidor por primera vez, o sin haber creado un nuevo
    -- personaje luego de haber muerto en la sesión previa.
    -- Una vez creado el personaje, `player` se instancia, y se mantiene durante toda la sesión, incluso luego de que el personaje
    -- muere. Esto es así, porque al crear un nuevo personaje en la misma sesión, la instancia de IsoPlayer se reutiliza para él.
    -- Los personajes pueden seguirse moviendo después de muertos, así que sus coordenadas seguirán cambiando sin que esto sea
    -- obra del jugador. Esto será así hasta que la instancia se reutilice para un nuevo personaje.
    if player then
        local x, y, z = player:getX(), player:getY(), player:getZ()

        -- Hago esto porque `player:isMoving()` es inconsistente (probablemente pueda usar el evento OnPlayerMoved).
        client_flags.isMoving = player:isAlive() and (client_flags.lastX ~= x or client_flags.lastY ~= y or client_flags.lastZ ~= z)

        if client_flags.isMoving then
            client_flags.lastX, client_flags.lastY, client_flags.lastZ = x, y, z
        end
    end

    if APTweaksVars.AfkSystemEnabled then
        updateAfkStatus(player, deltaTime, false)
    end

    -- Al menos en condiciones normales, es imposible que las variables relacionadas al teletransporte cambien si `player == nil`.
    if player and APTweaksVars.TeleportSystemEnabled then
        updateTeleportStatus(player, deltaTime)
    end
end

-- En el evento OnFETick.
-- Permite expulsar al cliente AFK antes de la pantalla de carga, cuando aún está en las pantallas de selección de zona de spawn y
--- creación de personaje.
-- Lamentablemente, -debido a que el juego entra en un (sub)bucle durante la pantalla de carga-, no es posible expulsarlo en ella.
local function OnFETick()

    if isClient() and APTweaksVars.AfkSystemEnabled then
        local deltaTime = GameTime.getInstance():getTimeDelta()

        updateAfkStatus(nil, deltaTime, true)
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnReceiveGlobalModData.Add(OnReceiveGlobalModData)
Events.OnGameStart.Add(OnGameStart)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnFETick.Add(OnFETick)
Events.OnServerCommand.Add(OnServerCommand)

-- Añadir la lógica necesaria del lado del servidor para manejar el teleportCooldown.
-- Revisar si puedo usar algún método como IsoPlayer.getSpeed para comprobar el movimento, en lugar de lo que hago ahora.
--- Hay un evento de movimiento.
-- Que el sistema anti-AFK no expulse si estás leyendo, subiendo sastrería, o escribiste en el chat.
-- Que la teletransportación se cancele si recibes daño.