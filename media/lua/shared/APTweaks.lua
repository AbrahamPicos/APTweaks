-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = {}
    -- La ID del mod.
    aptweaks.modID = "com.github.abrahampicos.aptweaks"
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
-- Variables para el jugador controladas por el evento tick; Son útiles para el comando warp y el sistema AFK.
aptweaks.player_flags = {
    -- El jugador asociado al cliente. Se establece a un IsoPlayer si existe en el evento OnTick. Se reestablece a nil si
    --- deja de existir.
    player = nil,
    -- Si el jugador ha enviado al servidor una solicitud de teletransporte.
    InTeleport = false,
    -- La última localización del jugador. Se reajusta en cada tick si su localización ha cambiado.
    lastLocation = {x = nil, y = nil, z = nil},
    -- Es el tick a partir del cual el jugador ha estado quieto. Se reestablece a nil si el jugador se mueve.
    iddleTickStart = nil,
    -- Si el jugador está AFK. Se establece en true si iddleTickStart ha sido diferente de nil durante AfkStart segundos.
    --- Se reestablece a false si el jugador se mueve.
    isAfk = false,
    -- Si el jugador está ejecutando el comando warp. Se establece en true cuando el jugador usó el comando warp. Se
    --- reestablece a false si el jugador se movió o fue teletransportado.
    inWarpCommand = false,
    -- El warp al que el jugador se teletransportará al finalizar TeleportDelay si inWarpCommand es true. Se establece como
    --- args[1] cuando este puede usarse como indice para obtener coordenadas en la tabla warps. Se reestablece a false si
    --- el jugador se movió o fue teletransportado.
    warpCommandWarp = nil,
    -- El tick cuando inició el comando warp. Se establece como el número de tick en el que inWarpCommand se estableció como
    --- true. Se reestablece a nil si el jugador se movió o fue teletransportado.
    warpCommandTickStart = nil,
    -- La cantidad de segundos que faltan para que el jugador pueda teletransportarse otra vez. Sólo se usa para el mensaje de
    --- error que el jugador ve cuando intenta teletrasportarse en cooldown. Se reestablece a nil cuando ha pasado el tiempo en
    --- TeleportDelay.
    warpCommandCooldownSecondsLeft = nil}

local modID = aptweaks.modID

-- Comprueba si hay una safehouse en un área.
---@param x1 integer Abscisa del vértice superior izquierdo.
---@param y1 integer Ordenada del vértice superior izquierdo.
---@param x2 integer Abscisa del vértice inferior derecho.
---@param y2 integer Ordenada del vértice inferior derecho.
---@return boolean
function aptweaks.IsSafeHouse(x1, y1, x2, y2)
    return SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) ~= nil
end

-- Crea un ChatMessge falso para usarlo con la función `ISChat.addLineInChat`.
---@param size string El tamaño del texto. Puede cambiarse luego con setSize(). Puede ser "small", "medium", y "large".
---@param text string El texto del mensaje.
---@param author string El nombre del autor del mensaje.
---@param isShowAuthor any Si debe mostrarse el nombre del autor en el mensaje: Ejem: "[AbrahamPicos]: Este es el mensaje.".
---@return table table Una tabla que simula ser un objeto ChatMessage.
function aptweaks.createFakeChatMessage(size, text, author, isShowAuthor)
    return {
        modID = modID,
        getTextWithPrefix = function(self)
            local prefix = "<RGB:0.0,0.5,1.0> " .. "<SIZE:" .. size .. "> "
            if isShowAuthor then
                prefix = prefix .. "[" .. author .. "]: "
            end
            return prefix .. text
        end,
        isServerAlert = function(self) return false end,
        getAuthor = function(self) return author end,
        isShowAuthor = function(self) return isShowAuthor end,
        getText = function(self) return text end,
        setSize = function (self, newSize)
            size = newSize
        end
    }
end

-- Procesa la respuesta de todos los comandos de APTweaks cuando son usados a travez de APTweaks.
--- @param player table Un IsoPlayer.
--- @param result table|nil La tabla con el resultado del comando.
function aptweaks.ProcessCommandResult(player, result)

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
            ISChat.addLineInChat(aptweaks.createFakeChatMessage(ISChat.instance.chatFont, text, "APTweaks", false), 0)
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
