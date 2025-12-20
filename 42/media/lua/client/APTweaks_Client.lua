-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, serverCommands = require("APTweaks"), require("APTweaks_Client_Commands")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local client_flags = aptweaks.client_flags

local setTimer = aptweaks.setTimer
local getTimerCycle = aptweaks.getTimerCycle
local getTimerUpdate = aptweaks.getTimerUpdate
local SafezoneCommand = serverCommands.SafezoneCommand
local TeleportCommand = serverCommands.TeleportCommand
local ProcessCommandResult = aptweaks.ProcessCommandResult

local Events = aptweaks.Events
local ModData = aptweaks.ModData
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
    } -- args = {x = x, y = y, z = z, name = name}
}

-- Añadir Timers.
setTimer("afk")
setTimer("teleport")

-- Enelevento OnGameStart.
-- Cachea el IsoPlayer asociado al cliente.
local function OnGameStart()
    client_flags.player = getPlayer()
end

-- En el evento OnInitGlobalModData.
-- Obtiene la Global ModData de APTweaks al iniciar la sesión.
---@param newGame boolean Si GlobalModData se inicializa en un nuevo guardado. Esto no es relevante para este mod.
local function OnInitGlobalModData(newGame)
    aptweaks.aptweaks_data = ModData.get("aptweaks")
end

-- En el evento OnServerCommand.
-- Procesa los comandos enviados por APTweaks desde el servidor al cliente.
---@param module string La ID del módulo que envió el comando. En este caso este mod.
---@param command string El comando.
---@param args table Los argumentos del comando.
local function OnServerCommand(module, command, args)
    local player = client_flags.player

    -- Si el módulo no coincide, no hay nada que hacer.
    if not (module == modID) then return end

    -- Manejar comando.
    local result = server_commands[command].handler(player, args)

    -- Procesar el resultado.
    ProcessCommandResult(player, result)
end

-- Actualiza el estado AFK del cliente.
---@param player table|nil El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que ocurrió desde el último tick.
---@param inMainMenu any Si el cliente aún está en el menú principal.
local function updateAfkStatus(player, deltaTime, inMainMenu)

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then

        if player and (getTimerCycle("afk") >= APTweaksVars.AfkStart) then -- Actualizar notificación sólo si la hubo.
            player:setHaloNote(getText("IGUI_APTweaks_HaloNote_AfkRemoved"), 0, 255, 0, 500)
        end

        setTimer("afk")
        return
    end

    -- Validar que ha pasado suficiente tiempo desde la última actualización.
    local seconds, isWholeSecond = getTimerUpdate("afk", deltaTime)

    if not isWholeSecond and (seconds <= APTweaksVars.AfkStart) then return end

    -- Actualizar noticifación AFK.
    if player then
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_Afk"), 255, 0, 0, 500) -- No hace nada si isAlive es false.
    end

    -- Validar que ha pasado suficiente tiempo para una expulsión.
    if seconds ~= APTweaksVars.AfkStart + APTweaksVars.AfkKick then return end

    -- Expulsar.
    if inMainMenu then
        getCore():quit()
        return
    end

    getCore():exitToMenu()
end

-- Actualiza el estado de teletransporte del cliente.
---@param player table El IsoPlayer asociado al cliente.
---@param deltaTime number La fracción de segundo que ocurrió desde el último tick.
local function updateTeleportStatus(player, deltaTime)

    -- Si no se está en teletransporte o no se ha enviado una solicitud de teletransporte, no hay nada qué hacer.
    if not (client_flags.isTeleporting and client_flags.TeleportRequest) then return end

    -- Si el jugador se movió, reiniciar estado.
    if client_flags.isMoving then

        if client_flags.TeleportRequest ~= "requested" then -- Si una solicitud en espera no puede reiniciarse del todo.

            if client_flags.TeleportRequest ~= "failed" then -- Si ya terminó y no fue fallida no debe verse este mensaje.
                player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportCancelled"), 255, 0, 0, 500)
            end

            client_flags.TeleportRequest = nil
            setTimer("teleport")
        end

        client_flags.isTeleporting = nil
        return
    end

    -- Validar que ha pasado suficiente tiempo desde la última actualización
    local seconds, isWholeSecond = getTimerUpdate("teleport", deltaTime)

    if not isWholeSecond and (seconds <= APTweaksVars.TeleportDelay) then return end

    -- Actualizar notificación de retraso de teletransporte.
    player:setHaloNote(string.format(getText("IGUI_APTweaks_HaloNote_TeleportDelaying"), math.abs(getTimerCycle("teleport") - APTweaksVars.TeleportDelay)), 0, 255, 0, 500)

    -- validar si ha pasado suficiente tiempo para teletransportar.
    if seconds ~= APTweaksVars.TeleportDelay then return end

    -- Enviar solicitud de teletransporte.
    sendClientCommand(player, modID, "TeleportCommand", {location = client_flags.teleportLocation, isRequest = true})
    client_flags.TeleportRequest = "requested"
end

-- En el evento OnTickEvenPaused.
-- Actualiza los estados del cliente nesesarios por algunos sistemas de APTweaks.
---@param tick number El tick actual.
local function OnTickEvenPaused(tick)

    -- Si no se está en multijugador, o no hay un sistema relevante habilitado, no hay nada que hacer.
    if not isClient() and not (APTweaksVars.AfkSystemEnabled or APTweaksVars.TeleportSystemEnabled) then return end

    -- Actualizar estados del cliente.
    local deltaTime = GameTime.getInstance():getTimeDelta() -- Esta instancia puede cambiar entre ticks. ¿Habrá un Evento?
    local player = client_flags.player

    -- Movimiento.
    if player then
        local x, y, z = player:getX(), player:getY(), player:getZ()

        client_flags.isMoving = player:isAlive() and (client_flags.lastX ~= x or client_flags.lastY ~= y or client_flags.lastZ ~= z)

        if client_flags.isMoving then
            client_flags.lastX, client_flags.lastY, client_flags.lastZ = x, y, z
        end
    end

    -- AFK.
    if APTweaksVars.AfkSystemEnabled then
        updateAfkStatus(player, deltaTime, false)
    end

    -- Teletransporte.
    if APTweaksVars.TeleportSystemEnabled then -- `player` nunca será nil si isTeleporting es verdadero.
        updateTeleportStatus(player, deltaTime)
    end
end

-- En el evento OnTickEvenPaused.
-- Actualiza el estado AFK del cliente mientras aún está en el menú principal. Como cuando aún está creando personaje.
-- Lamentablemente no funciona durante la pantalla de carga.
local function OnFETick()

    -- Si no se está en multijugador o el sistema Anti-AFK está deshabilitado, no hay nada que hacer.
    if not isClient() and not APTweaksVars.AfkSystemEnabled then return end

    -- Actualizar estado AFK.
    local deltaTime = GameTime.getInstance():getTimeDelta()

    updateAfkStatus(nil, deltaTime, true)
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnGameStart.Add(OnGameStart)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnFETick.Add(OnFETick)
Events.OnServerCommand.Add(OnServerCommand)

-- Añadir la lógica necesaria del lado del servidor para manejar el teleportCooldown.
-- Revisar si puedo usar algún método como IsoPlayer.getSpeed para comprobar el movimento, en lugar de lo que hago ahora.
--- Hay un evento de movimiento.
-- Que el sistema anti-AFK no expulse si estás leyendo, subiendo sastrería, o escribiste en el chat.
-- Que el sistema anti-AFK pueda expulsar durante la pantalla de carga.
-- Que la teletransportación se cancele si provocas o recibes daño.