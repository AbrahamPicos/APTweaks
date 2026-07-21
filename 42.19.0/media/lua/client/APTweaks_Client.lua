-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- El sistema Anti-AFK se quedará del lado del cliente para evitar sobrecargar el servidor sin que valga la pena.
--- Incluso si estuviera del lado del servidor, podría burlarse fácilmente con una capturadora de teclas, o simplemente quedándose
---  en la pantalla de creación de personaje para siempre, al no tener un IsoPlayer asociado con el cual rastrearlo.
--- Esto será imposible hasta que IndieStone decida permitir manipular conexiones del lado del servidor desde Lua.

local aptweaks = require("APTweaks")

require "APTweaks_Client_Utils"

local modID = aptweaks.modID
local utils = aptweaks.utils
local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

local math = math
local table = table
local string = string

local Events = Events

local getText = getText
local getCore = getCore
local isClient = isClient
local getTimestampMs = getTimestampMs
local sendClientCommand = sendClientCommand

local timers = aptweaks_temp.timers
local client_flags = aptweaks_temp.client_flags

timers.clientAFK = {
    times = {}, ---@type {start:integer?,lastNotify:integer?}
    canUpdate = function(data)
        return APTweaksVars.AfkSystemEnabled
    end,
    cancel = function (player, time, data)
        utils.resetAfkStatus(player, time)
    end,
    canAction = function (timeElapsed, data) 
        return timeElapsed > APTweaksVars.AfkStart * 1000
    end,
    notify = function (player, timeElapsed)
        client_flags.afk = true

        if player then
            player:setHaloNote(getText("IGUI_APTweaks_HaloNote_Afk"), 255, 0, 0, 1000)
        end
    end,
    timeOut = (APTweaksVars.AfkStart + APTweaksVars.AfkKick) * 1000,
    callback = function(player, data) -- Expulsar al cliente.

        if not player then -- Si aún está en el menú principal.
            getCore():quit()
            return
        end

        getCore():exitToMenu()
    end
}
timers.clientTeleport = {
    times = {},
    canUpdate = function(data)
        return APTweaksVars.TeleportSystemEnabled and data and data.status ~= "cancelled"
    end,
    cancel = function (player, time, data)
        utils.resetTeleportStatus(player, time, data)
    end,
    canAction = function (timeElapsed, data)
        return data.status == "waiting"
    end,
    notify = function (player, timeElapsed)
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportDelaying", math.abs(timeElapsed - APTweaksVars.TeleportDelay)), 0, 255, 0, 1000)
    end,
    timeout = APTweaksVars.TeleportDelay * 1000,
    callback = function (player, data)
        data.status = "waiting" -- Aún debe esperar una respuuesta desde el servidor.
    end
}

-- Actualiza el estado de uno de los sistemas de APTweaks que necesitan actualizaciones constantes.
---@param player IsoPlayer?
---@param system "clientAFK"|"clientTeleport"
---@param time integer
---@param data table?
local function updateStatus(player, system, time, data)
    local reference = timers[system] 

    -- Validar si se puede actualizar el estado.
    if not reference.canUpdate(data) then return end

    -- Si el jugador se movió, reiniciar estado y retornar.
    if client_flags.isMoving then
        reference.cancel(player, time, data)
        return
    end

    local times = reference.times

    -- De ser necesario, actualizar tiempos.
    if not times.start then
        times.start, times.lastNotify = time, time
    end

    local timeElapsed = time - times.start

    -- Validar que se pueda iniciar con las acciones.
    if not reference.canAction(timeElapsed, data) then return end

    local lastNotify = times.lastNotify ---@cast lastNotify -? Garantizado junto a times.start.

    -- Validar que ha pasado al menos un segundo desde la ultima vez.
    if lastNotify ~= time or (time - lastNotify) < 1000 then return end

    -- Actualizar notificación.
    reference.notify(player, timeElapsed); times.lastNotify = time

    -- Si ha pasado tiempo suficiente, llamar al callback.
    if timeElapsed >= reference.timeOut then
        reference.callback(player, data)
    end
end

-- En los eventos OnTickEvenPaused y OnFETick.
-- Actualiza los estados del cliente nesesarios por algunos sistemas de APTweaks.
---@param tick integer El tick actual.
local function OnTickEvenPaused(tick)

    -- Si no se está en multijugador, o no hay sistemas relevantes habilitados, no hay nada que hacer.
    if not (isClient() and (APTweaksVars.AfkSystemEnabled or APTweaksVars.TeleportSystemEnabled)) then return end

    local time = getTimestampMs()
    local player = client_flags.player ---@type IsoPlayer? Es nil antes de la pantalla de carga.

    if player then
        local x, y, z = player:getX(), player:getY(), player:getZ()

        client_flags.isMoving = player:isAlive() and (client_flags.lastX ~= x or client_flags.lastY ~= y or client_flags.lastZ ~= z)

        -- Movimiento.
        if client_flags.isMoving then
            client_flags.lastX, client_flags.lastY, client_flags.lastZ = x, y, z
        end

        -- Teletransporte.
        updateStatus(player, "clientTeleport", time, client_flags.teleport)
    end

    -- AFK.
    updateStatus(player, "clientAFK", time, nil)
end

-- En el evento OnCreatePlayer.
-- Notifica al servidor que debe manejar temporalmente el sistema anti-afk para este cliente.
-- También cachea el IsoPlayer asociado a este cliente para un acceso rápido.
---@param index integer El indice del nuevo jugador. 0 si es el asociado a este cliente.
---@param player IsoPlayer El IsoPlayer que fue instanciado localmente.
local function OnCreatePlayer(index, player)

    -- Si el nuevo jugador no es el asociado al cliente, no hay nada que hacer.
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
-- Esto parace sobreingenieria, pero servirá para otras cosas en el futuro.
---@param message ChatMessage Un ChatMessage.
---@param tabId integer La ID de la pestaña a la que fue añadido el mensaje.
local function OnAddMessage(message, tabId)

    if not message:isServerAuthor() then return end

    local words = {} ---@type string[]

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
Events.OnTickEvenPaused.Add(OnTickEvenPaused--[[@cast (fun(tick:number)) Anotado para Lua 5.1]])
Events.OnServerCommand.Add(function (module, command, args)
    utils.OnCommand(module, command, _, args)
end)

-- Añadir la lógica necesaria del lado del servidor para manejar el teleportCooldown. *EN TRABAJO -AbrahamPicos*
-- Revisar si puedo usar algún método como IsoPlayer.getSpeed para comprobar el movimento, en lugar de lo que hago ahora.
--- Hay un evento de movimiento.
-- Que el sistema anti-AFK no expulse si estás leyendo o subiendo sastrería.
-- Que el sistema anti-AFK pueda expulsar durante la pantalla de carga (muy complicado). *EN TRABAJO -AbrahamPicos*
-- Que la teletransportación se cancele si provocas o recibes daño.
-- Que la teletransportación no se cancele cuando el jugador intente ver a su alrededor (muy complicado).
