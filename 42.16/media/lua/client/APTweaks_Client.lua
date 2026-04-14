-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, serverCommands = require("APTweaks"), require("APTweaks_Client_Commands")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local client_flags = aptweaks.client_flags

local getTimerUpdate = aptweaks.getTimerUpdate
local resetAfkStatus = aptweaks.resetAfkStatus
local resetTeleportStatus = aptweaks.resetTeleportStatus
local SafezoneCommand = serverCommands.SafezoneCommand
local TeleportCommand = serverCommands.TeleportCommand
local PlayerConnectedCommand = serverCommands.PlayerConnectedCommand
local PlayerDisconnectedCommand = serverCommands.PlayerDisconnectedCommand
local processCommandResult = aptweaks.processCommandResult

local Events = aptweaks.Events
local getText = aptweaks.getText
local getCore = aptweaks.getCore
local isClient = aptweaks.isClient
local GameTime = aptweaks.GameTime
local getPlayer = aptweaks.getPlayer
local sendClientCommand = aptweaks.sendClientCommand

local server_commands = {

    MessageCommand = {
        handler = function(_, args) return {text = args.text} end
    }, -- args = {text = text}
    SafezoneCommand = {
        handler = function (player, args) return SafezoneCommand(player, args) end
    }, -- args = {x = x, y = y, z = z}
    TeleportCommand = {
        handler = function (player, args) return TeleportCommand(player, args) end
    }, -- args = {x = x, y = y, z = z, name = name} *DESACTUALIZADO*
    PlayerConnected = {
        handler = function (_, args) return PlayerConnectedCommand(args) end
    }, -- args = {username = username}
    playerDisconnected = {
        handler = function (_, args) return PlayerDisconnectedCommand(args) end
    } -- args = {username = username}
}

-- En el evento OnGameStart.
-- Cachea el IsoPlayer asociado al cliente.
local function OnGameStart()
    client_flags.player = getPlayer()
end

-- En el evento OnServerCommand.
-- Procesa los comandos enviados por APTweaks desde el servidor al cliente.
---@param module string La ID del módulo que envió el comando. En este caso este mod.
---@param command string El comando.
---@param args table Los argumentos del comando.
local function OnServerCommand(module, command, args)
    local player = client_flags.player

    -- Si el módulo no coincide con APTweaks, no hay nada que hacer.
    if module ~= modID then return end

    -- Manejar comando.
    local result = server_commands[command].handler(player, args)

    -- Procesar el resultado.
    if result then
        processCommandResult(player, result, modID)
    end
end

-- Actualiza el estado AFK del cliente.
-- Esto sóĺo funciona antes y después de la pantalla de carga. Aún no encuentro una forma de que funcione durante.
---@param player table|nil El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que transcurrió desde el último tick.
local function updateAfkStatus(player, deltaTime)

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then
        resetAfkStatus(player)
        return
    end

    local seconds, isWholeSecond = getTimerUpdate("afk", deltaTime)

    -- Validar que ha pasado suficiente tiempo desde la última actualización.
    if not isWholeSecond or (seconds < APTweaksVars.AfkStart) then return end

    -- Si hay un jugador asociado al cliente, actualizar notificación AFK.
    if player then
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_Afk"), 255, 0, 0, 500) -- No hace nada si isAlive es false.
    end

    -- Validar que ha pasado suficiente tiempo para una expulsión, y que el tiempo no es mayor al necesario.
    if seconds ~= (APTweaksVars.AfkStart + APTweaksVars.AfkKick) then return end

    -- Expulsar.
    if not player then -- Si aún está en el menú principal.
        getCore():quit()
        return
    end

    getCore():exitToMenu()
end

-- Actualiza el estado de teletransporte del cliente.
-- Los estados de la solicitud de teletransporte son nil, "begins", "requested", y "cancelled".
---@param player table El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que transcurrió desde el último tick.
local function updateTeleportStatus(player, deltaTime)
    local teleporting = client_flags.teleporting

    -- Si no se está en teletransporte, o fue cancelado luego de enviar una solicitud al servidor, no hay nada qué hacer.
    if not teleporting or teleporting.status == "cancelled" then return end

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then
        resetTeleportStatus(player, teleporting)
        return
    end

    local seconds, isWholeSecond = getTimerUpdate("teleport", deltaTime)

    -- Validar que ha pasado suficiente tiempo desde la última actualización, y que el tiempo no es mayor al necesario.
    if not isWholeSecond or (seconds > APTweaksVars.TeleportDelay) then return end

    -- Actualizar notificación de retraso de teletransporte.
    player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportDelaying", math.abs(seconds - APTweaksVars.TeleportDelay)), 0, 255, 0, 500)

    -- si ya terminó el tiempo, notificar al usuario, y enviar solicitud de teletransporte al servidor.
    if seconds == APTweaksVars.TeleportDelay then
        sendClientCommand(player, modID "TeleportCommand", {status = "requested"})
        teleporting.status = "requested"
    end
end

-- En los eventos OnTickEvenPaused y OnFETick.
-- Actualiza los estados del cliente nesesarios por algunos sistemas de APTweaks.
---@param tick number El tick actual.
local function OnTickEvenPaused(tick)

    -- Si no se está en multijugador, o no hay sistemas relevantes habilitados, no hay nada que hacer.
    if not (isClient() and (APTweaksVars.AfkSystemEnabled or APTweaksVars.TeleportSystemEnabled)) then return end

    -- Actualizar estados del cliente.
    local deltaTime = GameTime.getInstance():getTimeDelta() -- Esta instancia puede cambiar entre ticks. ¿Habrá un Evento?.
    local player = client_flags.player

    -- Movimiento.
    if player then -- Esto sólo puede ser nil antes de la pantalla de carga.
        local x, y, z = player:getX(), player:getY(), player:getZ()

        client_flags.isMoving = player:isAlive() and (client_flags.lastX ~= x or client_flags.lastY ~= y or client_flags.lastZ ~= z)

        if client_flags.isMoving then
            client_flags.lastX, client_flags.lastY, client_flags.lastZ = x, y, z
        end
    end

    -- AFK.
    if APTweaksVars.AfkSystemEnabled then
        updateAfkStatus(player, deltaTime)
    end

    -- Teletransporte.
    if APTweaksVars.TeleportSystemEnabled then
        updateTeleportStatus(player, deltaTime)
    end
end

-- Intercepta y traduce los mensajes de muerte antes de que los vean los clientes.
---@param message table Un ChatMessage.
---@param tabId number La ID de la pestaña a la que fue añadido el mensaje.
local function OnAddMessage(message, tabId)

    if not message:isServerAuthor() then return end

    local words = {}

    for word in string.gmatch(message:getText(), "%S+") do
        table.insert(words, word)
    end

    if #words ~= 3 then return end

    if words[2] == "is" and words[3] == "dead." then
        message:setText(getText("IGUI_APTweaks_Chat_DeathMessage", words[1]))
    end
end

Events.OnGameStart.Add(OnGameStart)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnFETick.Add(OnTickEvenPaused)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnAddMessage.Add(OnAddMessage)

-- Añadir la lógica necesaria del lado del servidor para manejar el teleportCooldown.
-- Tal vez sea mejor usar timers con callbacks para la función OnTick.
-- Revisar si puedo usar algún método como IsoPlayer.getSpeed para comprobar el movimento, en lugar de lo que hago ahora.
--- Hay un evento de movimiento.
-- Que el sistema anti-AFK no expulse si estás leyendo o subiendo sastrería.
-- Que el sistema anti-AFK pueda expulsar durante la pantalla de carga (muy complicado).
--- Quizá pueda hacerse del lado del servidor, ya que el jugador aparece del lado del servidor poco antes.
--- No puedo trasladar todo el sistema al servidor, porque no funcionaría durante la pantalla de creación de personaje.
-- Que la teletransportación se cancele si provocas o recibes daño.
-- Que la teletransportación no se cancele cuando el jugador intente ver a su alrededor (muy complicado).
