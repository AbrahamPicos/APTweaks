-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- El sistema Anti-AFK se quedará del lado del cliente para evitar sobrecargar el servidor sin que valga la pena.
--- Incluso si estuviera del lado del servidor, podría burlarse fácilmente con una capturadora de teclas, o simplemente quedándose
---  en la pantalla de creación de personaje para siempre al no tener un IsoPlayer asociado con el cual rastrearlo.
--- Esto será imposible hasta que IndieStone decida permitir manipular conexiones del lado del servidor desde lua.

local aptweaks = require("APTweaks")

local modID = aptweaks.modID
local utils = aptweaks.utils
local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

local Events = Events
local GameTime = GameTime

local getText = getText
local getCore = getCore
local isClient = isClient
local sendClientCommand = sendClientCommand

local client_flags = aptweaks_temp.client_flags

-- Actualiza el estado AFK del cliente.
-- Esto sóĺo funciona antes y después de la pantalla de carga. Aún no encuentro una forma de que funcione durante.
---@param player IsoPlayer? El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que transcurrió desde el último tick.
local function updateAfkStatus(player, deltaTime)

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then
        utils.resetAfkStatus(player)
        return
    end

    local seconds, isWholeSecond = utils.getTimerUpdate("afk", deltaTime)

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
---@param player IsoPlayer El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que transcurrió desde el último tick.
local function updateTeleportStatus(player, deltaTime)
    local teleport = client_flags.teleport

    -- Si no se está en teletransporte, o fue cancelado luego de enviar una solicitud al servidor, no hay nada qué hacer.
    if not teleport or teleport.status == "cancelled" then return end

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then
        utils.resetTeleportStatus(player, teleport)
        return
    end

    local seconds, isWholeSecond = utils.getTimerUpdate("teleport", deltaTime)

    -- Validar que ha pasado suficiente tiempo desde la última actualización, y que el tiempo no es mayor al necesario.
    if not isWholeSecond or (seconds > APTweaksVars.TeleportDelay) then return end

    -- Actualizar notificación de retraso de teletransporte.
    player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportDelaying", math.abs(seconds - APTweaksVars.TeleportDelay)), 0, 255, 0, 500)

    -- Si ya terminó el tiempo, cambiar el estado de teletransporte.
    if seconds == APTweaksVars.TeleportDelay then
        teleport.status = "waiting" -- Aún debe esperar una respuuesta desde el servidor.
    end
end

-- En los eventos OnTickEvenPaused y OnFETick.
-- Actualiza los estados del cliente nesesarios por algunos sistemas de APTweaks.
---@param tick integer El tick actual.
local function OnTickEvenPaused(tick)

    -- Si no se está en multijugador, o no hay sistemas relevantes habilitados, no hay nada que hacer.
    if not (isClient() and (APTweaksVars.AfkSystemEnabled or APTweaksVars.TeleportSystemEnabled)) then return end

    -- Actualizar estados del cliente.
    local deltaTime = GameTime.getInstance():getTimeDelta() -- Esta instancia puede cambiar entre ticks. ¿Habrá un Evento?.
    local player = client_flags.player ---@type IsoPlayer? Es nil antes de la pantalla de carga.

    -- Movimiento.
    if player then
        local x, y, z = player:getX(), player:getY(), player:getZ()

        client_flags.isMoving = player:isAlive() and (client_flags.lastX ~= x or client_flags.lastY ~= y or client_flags.lastZ ~= z)

        if client_flags.isMoving then
            client_flags.lastX, client_flags.lastY, client_flags.lastZ = x, y, z
        end

        -- Teletransporte.
        if APTweaksVars.TeleportSystemEnabled then
            updateTeleportStatus(player, deltaTime)
        end
    end

    -- AFK.
    if APTweaksVars.AfkSystemEnabled then
        updateAfkStatus(player, deltaTime)
    end
end

-- En el evento OnCreatePlayer.
-- Notifica al servidor que debe manejar temporalmente el sistema anti-afk para este cliente.
-- También cachea el IsoPlayer asociado a este cliente para un acceso rápido.
---@param index integer El indice del nuevo jugador. 0 si es el asociado a este cliente.
---@param player IsoPlayer El IsoPlayer que fue instanciado localmente.
local function OnCreatePlayer(index, player)

    -- Si el nuevo jugador no es el asociado al cliente no hay nada que hacer.
    if not index == 0 then return end -- El player 0 se instancia al entrar en la pantalla de carga.

    client_flags.player = player

    sendClientCommand(player, modID, "AfkAsistCommand", {start = true})
end

-- En el evento OnGameStart.
-- Notifica al servidor que debe dejar de manejar el sistema anti-afk para este cliente.
local function OnGameStart()
    sendClientCommand(client_flags.player, modID, "AfkAsistCommand", {start = false})
end

-- Intercepta y traduce los mensajes de muerte antes de que los vean los clientes.
---@param message ChatMessage Un ChatMessage.
---@param tabId integer La ID de la pestaña a la que fue añadido el mensaje.
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
Events.OnFETick.Add(OnTickEvenPaused)
Events.OnAddMessage.Add(OnAddMessage)
Events.OnCreatePlayer.Add(OnCreatePlayer)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnServerCommand.Add(function (module, command, args)
    utils.OnCommand(module, command, _, args)
end)

-- Añadir la lógica necesaria del lado del servidor para manejar el teleportCooldown. *EN TRABAJO -AbrahamPicos*
-- Tal vez sea mejor usar timers con callbacks para la función OnTick.
-- Revisar si puedo usar algún método como IsoPlayer.getSpeed para comprobar el movimento, en lugar de lo que hago ahora.
--- Hay un evento de movimiento.
-- Que el sistema anti-AFK no expulse si estás leyendo o subiendo sastrería.
-- Que el sistema anti-AFK pueda expulsar durante la pantalla de carga (muy complicado). *EN TRABAJO -AbrahamPicos*
-- Que la teletransportación se cancele si provocas o recibes daño.
-- Que la teletransportación no se cancele cuando el jugador intente ver a su alrededor (muy complicado).
-- Probablemente sea mejor usar marcas de tiempo para el evento ontick.
