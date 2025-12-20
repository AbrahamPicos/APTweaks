-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo actua como un contenedor de datos. No lo recargue.

local aptweaks = {}
    -- La ID del mod.
    aptweaks.modID = "com.github.abrahampicos.aptweaks"
    -- Variables para el jugador controladas por el evento tick. Son útiles para el comando warp y el sistema AFK.
    aptweaks.client_flags = {}
    -- Datos que APTweaks necesita en tiempo de ejecución, pero que no hace falta que persistan.
    aptweaks.aptweaks_temp = {}
    -- Respaldos de las funciones que fueron sobrescritas por APTweaks.
    aptweaks.legacy_functions = {}

    -- Referencias a clases y métodos Java de Project Zomboid.

    aptweaks.Events = Events
    aptweaks.ModData = ModData
    aptweaks.getCore = getCore
    aptweaks.getText = getText
    aptweaks.isAdmin = isAdmin
    aptweaks.writeLog = writeLog
    aptweaks.isClient = isClient
    aptweaks.isServer = isServer
    aptweaks.GameTime = GameTime
    aptweaks.getPlayer = getPlayer
    aptweaks.SafeHouse = SafeHouse
    aptweaks.Capability = Capability
    aptweaks.isCoopHost = isCoopHost
    aptweaks.doKeyPress = doKeyPress
    aptweaks.triggerEvent = triggerEvent
    aptweaks.getTimestampMs = getTimestampMs
    aptweaks.getServerOptions = getServerOptions
    aptweaks.sendClientCommand = sendClientCommand
    aptweaks.sendServerCommand = sendServerCommand
    aptweaks.getConnectedPlayers = getConnectedPlayers
    aptweaks.alreadyHaveSafehouse = alreadyHaveSafehouse
    aptweaks.getSteamIDFromUsername = getSteamIDFromUsername

    -- Referencias a variables globales de Project Zomboid.

    aptweaks.luautils = luautils
    aptweaks.APTweaksVars = SandboxVars.APTweaks

local isClient = aptweaks.isClient
local isServer = aptweaks.isServer
local sendClientCommand = aptweaks.sendClientCommand
local sendServerCommand = aptweaks.sendServerCommand

local modID = aptweaks.modID
local aptweaks_temp = aptweaks.aptweaks_temp

-- Estableciendo Timers.
aptweaks_temp.timers = {}

-- Crea un ChatMessge falso para usarlo con la función `ISChat.addLineInChat`.
---@param size string El tamaño del texto. Puede cambiarse luego con setSize(). Puede ser "small", "medium", y "large".
---@param text string El texto del mensaje.
---@param author string El nombre del autor del mensaje.
---@param isShowAuthor any Si debe mostrarse el nombre del autor en el mensaje: Ejem: "[AbrahamPicos]: Este es el mensaje.".
---@return table ChatMessage Una tabla que simula ser un objeto ChatMessage, con algunos de sus métodos.
function aptweaks.CreateFakeChatMessage(size, text, author, isShowAuthor)
    return {
        modID = modID,
        getTextWithPrefix = function(self)
            local prefix = "<RGB:0.0,0.5,1.0> " .. "<SIZE:" .. size .. "> "

            if isShowAuthor then
                prefix = prefix .. "[" .. author .. "]: "
            end

            return prefix .. text
        end,
        isShowAuthor = function(self) return isShowAuthor end,
        getAuthor = function(self) return author end,
        getText = function(self) return text end,
        setSize = function (self, newSize) size = newSize end,
        setText = function (self, newText) text = newText end
    }
end

-- Procesa la respuesta de todos los comandos de APTweaks cuando son usados a travez de APTweaks.
---@param player table Un objeto IsoPlayer.
---@param result table La tabla con el resultado del comando.
function aptweaks.ProcessCommandResult(player, result)

    local data = result.data or result
    local commandName = result.command or "MessageCommand"

    if isServer() then
        sendServerCommand(player, modID, commandName, data)

    elseif isClient() then

        if commandName == "MessageCommand" then
            local ISChat = aptweaks.ISChat

            ISChat.addLineInChat(aptweaks.CreateFakeChatMessage(ISChat.instance.chatFont, result.text, "APTweaks", false), 0)

        else
            sendClientCommand(player, modID, commandName, data)
        end
    end
end

-- Verifica si una tabla está vacía (ya que `next` no funciona en Project Zomboid).
---@param t table La tabla que se verificará. Cualquier cosa que no sea una tabla se conciderará vacía, tal como lo hace next.
---@return boolean isEmpty Si la tabla estaba vacía.
function aptweaks.isTableEmpty(t)

    if type(t) ~= "table" then return true end

    for _ in pairs(t) do
        return false
    end

    return true
end

-- Establece o respablece un tiemer.
---@param name string El nombre del timer.
function aptweaks.setTimer(name)
    aptweaks_temp.timers[name] = {justAdded = true, counter = 0, cycles = 0}
end

-- Obtiene el ciclo actual de un timer.
---@param name string El nombre del timer.
---@return number cycle El número de ciclo.
function aptweaks.getTimerCycle(name)
    return aptweaks_temp.timers[name].cycle
end

-- Actualiza un Timer, y devuelve sus variables.
---@param name string El nombre del timer.
---@param time number El tiempo que se añadirá al timer.
---@return number|nil cycle El número de ciclo.
---@return boolean isCycleUpdate Si esta actualización resultó en un nuevo ciclo.
function aptweaks.getTimerUpdate(name, time)
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

return aptweaks
