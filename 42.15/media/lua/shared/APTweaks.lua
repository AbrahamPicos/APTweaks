-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo actua como un contenedor de datos. No lo recargue.

local aptweaks = {
    -- La ID del mod.
    modID = "com.github.abrahampicos.aptweaks",
    -- Variables para el jugador controladas por el evento tick. Son útiles para el comando warp y el sistema AFK.
    client_flags = {},
    -- Datos que APTweaks necesita en tiempo de ejecución, pero que no hace falta que persistan.
    aptweaks_temp = {},
    -- Respaldos de las funciones que fueron sobrescritas por APTweaks.
    legacy_functions = {},

    -- Referencias a clases Java de Project Zomboid.

    Events = Events,
    ModData = ModData,
    GameTime = GameTime,
    SafeHouse = SafeHouse,
    Capability = Capability,

    -- Referencias a métodos Java de Project Zomboid.

    getCore = getCore,
    getText = getText,
    isAdmin = isAdmin,
    addRole = addRole,
    getRoles = getRoles,
    writeLog = writeLog,
    isClient = isClient,
    isServer = isServer,
    getPlayer = getPlayer,
    setupRole = setupRole,
    isCoopHost = isCoopHost,
    doKeyPress = doKeyPress,
    triggerEvent = triggerEvent,
    getTimestampMs = getTimestampMs,
    getServerOptions = getServerOptions,
    sendClientCommand = sendClientCommand,
    sendServerCommand = sendServerCommand,
    getConnectedPlayers = getConnectedPlayers,
    alreadyHaveSafehouse = alreadyHaveSafehouse,

    -- Referencias a variables globales de Project Zomboid.

    luautils = luautils,
    APTweaksVars = SandboxVars.APTweaks
}

local isClient = aptweaks.isClient
local isServer = aptweaks.isServer
local sendClientCommand = aptweaks.sendClientCommand
local sendServerCommand = aptweaks.sendServerCommand

local modID = aptweaks.modID
local aptweaks_temp = aptweaks.aptweaks_temp

-- Inicializar timers.
aptweaks_temp.timers = {}

-- Verifica si una tabla está vacía (ya que `next` no funciona en Project Zomboid).
---@param t table La tabla que se verificará. Cualquier cosa que no sea una tabla se conciderará vacía.
---@return boolean isEmpty Si la tabla estaba vacía.
function aptweaks.isTableEmpty(t)

    if type(t) ~= "table" then return true end

    for _ in pairs(t) do
        return false
    end

    return true
end

-- Crea el mapa de datos de APTweaks. También lo restablece si es necesario.
---@param reset boolean Si el mapa debe restablecerse, lo que borrará todos los datos.
function aptweaks.SetupData(reset)
    -- Las claves con las que se nombran a las tablas de ModData no admiten puntos, por lo que no puedo usar modID.
    local aptweaks_data = ModData.getOrCreate("aptweaks")

    aptweaks.aptweaks_data = aptweaks_data

    if not aptweaks.isTableEmpty(aptweaks_data) and not reset then return end

    -- La versión de la estructura de datos. Se usará para saber si debe actualizarse cuando se actualiza el mod.
    aptweaks_data.dataversion = 1
    -- El submapa de las áreas. Contiene toda la información de las áreas que pueden reclamarse como non-building safehouses.
    aptweaks_data.areas = {}
    -- El submapa que indexa las áreas por celda.
    -- APTweaks usa una cuadricula espacial para indexar las áreas, lo que reduce las iteraciones al acceder al mapa de datos.
    aptweaks_data.cells = {}
    -- El submapa que contiene los warps.
    aptweaks_data.warps = {}
end

-- Instancia un ChatMessge falso para usarlo con la función `ISChat.addLineInChat`.
---@param size string El tamaño del texto. Puede cambiarse luego con setSize(). Puede ser "small", "medium", y "large".
---@param text string El texto del mensaje.
---@param author string El nombre del autor del mensaje.
---@param isShowAuthor any Si debe mostrarse el nombre del autor en el mensaje: Ejem: "[AbrahamPicos]: Este es un mensaje.".
---@return table ChatMessage Una tabla que simula ser una instancia de zombie.chat.ChatMessage, con algunos de sus métodos.
local function getFakeChatMessage(size, text, author, isShowAuthor)
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
---@param provider string El proovedor de comando. Se usa para enviar comandos.
function aptweaks.processCommandResult(player, result, provider)

    local data = result.data or result
    local commandName = result.command or "MessageCommand"

    if isServer() then
        sendServerCommand(player, provider, commandName, data)

    elseif isClient() then

        if commandName == "MessageCommand" then
            local ISChat = aptweaks.ISChat

            ISChat.addLineInChat(getFakeChatMessage(ISChat.instance.chatFont, data.text, provider, false), 0)

        else
            sendClientCommand(player, provider, commandName, data)
        end
    end
end

-- Establece o respablece un timer.
---@param name string El nombre del timer.
function aptweaks.setTimer(name)
    aptweaks_temp.timers[name] = {justAdded = true, counter = 0, cycles = 0}
end

-- Obtiene el ciclo actual de un timer.
---@param name string El nombre del timer.
---@return number cycle El número de ciclo.
function aptweaks.getTimerCycle(name)
    return aptweaks_temp.timers[name].cycles
end

-- Actualiza un timer, y devuelve sus variables.
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
