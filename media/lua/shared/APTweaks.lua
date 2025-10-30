-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = {}
    -- La ID del mod.
    aptweaks.modID = "com.github.abrahampicos.aptweaks"
    -- El Número que identificar la sesión actual. Se usa para diferenciar el sistema de mensajería interno.
    aptweaks.sessionID = nil
    -- El mapa de datos de APTweaks. Se define aquí como una tabla rellenable para ser accesible desde todos los módulos.
    aptweaks.aptweaks_data = {}
    -- Referencias a Funciones incorporadas en Lua.

    aptweaks.format = string.format
    aptweaks.gmatch = string.gmatch
    aptweaks.insert = table.insert
    aptweaks.unpack = unpack

    -- Referencias a Funciones Java de Proyect Zomboid.

    aptweaks.Events = Events
    aptweaks.ModData = ModData
    aptweaks.getCore = getCore
    aptweaks.getText = getText
    aptweaks.writeLog = writeLog
    aptweaks.isClient = isClient
    aptweaks.isServer = isServer
    aptweaks.getPlayer = getPlayer
    aptweaks.SafeHouse = SafeHouse
    aptweaks.triggerEvent = triggerEvent
    aptweaks.getServerOptions = getServerOptions
    aptweaks.ZombRandBetween = ZombRandBetween
    aptweaks.sendClientCommand = sendClientCommand
    aptweaks.sendServerCommand = sendServerCommand
    aptweaks.getConnectedPlayers = getConnectedPlayers
    aptweaks.SendCommandToServer = SendCommandToServer
    aptweaks.alreadyHaveSafehouse = alreadyHaveSafehouse
    aptweaks.getSteamIDFromUsername = getSteamIDFromUsername

    -- Referencias a variables globales de Proyect Zomboid.

    aptweaks.APTweaksVars = SandboxVars.APTweaks

local isClient = aptweaks.isClient
local isServer = aptweaks.isServer
local SafeHouse = aptweaks.SafeHouse
local ZombRandBetween = aptweaks.ZombRandBetween
local sendClientCommand = aptweaks.sendClientCommand
local sendServerCommand = aptweaks.sendServerCommand
local SendCommandToServer = aptweaks.SendCommandToServer

aptweaks.sessionID = ZombRandBetween(100, 1000)

local modID = aptweaks.modID
local sessionID = aptweaks.sessionID

-- Comprueba si hay una safehouse en un área.
---@param x1 integer Abscisa del vértice superior izquierdo.
---@param y1 integer Ordenada del vértice superior izquierdo.
---@param x2 integer Abscisa del vértice inferior derecho.
---@param y2 integer Ordenada del vértice inferior derecho.
---@return boolean
function aptweaks.IsSafeHouse(x1, y1, x2, y2)
    return SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) ~= nil
end

-- Procesa la respuesta de todos los comandos de APTweaks cuando son usados a travez de APTweaks.
--- @param player table Un IsoPlayer.
--- @param result table|nil La tabla con el resultado del comando.
--- @param message table|nil Un ChatMessage. Es el el caso de que la función se llame en el evento OnAddMessage.
function aptweaks.ProcessCommandResult(player, result, message)

    if result then
        local text = result.text
        local data = result.data
        local commandSend = result.command
        local server, client = isServer(), isClient()

        if not commandSend and server then
            commandSend = "messageCommand"
            data = result

        elseif commandSend then

            if client then
                sendClientCommand(player, modID, commandSend, data)

            elseif server then
                sendServerCommand(player, modID, commandSend, data)
            end
        end

        if text and client then

            if message then
                text = text:gsub("%[NL%]", "\n")
                message:setText(text)
            else
                SendCommandToServer("/APTM-" .. sessionID .. " " .. text)
            end
        end
    end
end

-- Usa el tick actual para determinar cuántos segundos han pasado, y si son segundos enteros.
--- @param tick number El tick actual.
--- @param value number El tick que se usará para obtener la diferencia de tiempo.
--- @return number secondsElapsed El segundo obtenido en el tick actual.
--- @return boolean isWoleSecond Si el segundo obtenido es un segundo completo.
function aptweaks.SecondsElapsed(tick, value)
    local ticksElapsed = tick - value
    local secondsElapsed = ticksElapsed / 60
    local isWholeSecond = false

    if ticksElapsed % 60 == 0 then
        isWholeSecond = true
    end
    return secondsElapsed, isWholeSecond
end

return aptweaks
