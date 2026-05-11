-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo actua como un contenedor de datos. No lo recargue.

local aptweaks = {
    -- La ID del mod.
    modID = "com.github.abrahampicos.aptweaks",
    -- Los comandos de APTweaks. Tanto los del servidor como los del cliente.
    commands = {},
    -- Datos varios que APTweaks necesita en tiempo de ejecución.
    aptweaks_temp = {},
    -- Respaldos de las funciones que fueron sobrescritas por APTweaks.
    legacy_functions = {},

    -- Referencias a clases Java de Project Zomboid.

    Color = Color,
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
    deleteRole = deleteRole,
    isCoopHost = isCoopHost,
    doKeyPress = doKeyPress,
    triggerEvent = triggerEvent,
    getTimestampMs = getTimestampMs,
    getServerOptions = getServerOptions,
    sendClientCommand = sendClientCommand,
    sendServerCommand = sendServerCommand,
    getConnectedPlayers = getConnectedPlayers,
    alreadyHaveSafehouse = alreadyHaveSafehouse,
    getPlayerFromUsername = getPlayerFromUsername,

    -- Referencias a variables globales de Project Zomboid.

    luautils = luautils,
    APTweaksVars = SandboxVars.APTweaks
}

local ModData = aptweaks.ModData
local addRole = aptweaks.addRole
local getText = aptweaks.getText
local isClient = aptweaks.isClient
local isServer = aptweaks.isServer
local getRoles =  aptweaks.getRoles
local sendClientCommand = aptweaks.sendClientCommand
local sendServerCommand = aptweaks.sendServerCommand

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

local commands = aptweaks.commands
local client_flags = aptweaks_temp.client_flags

-- Establece o respablece un timer.
---@param name string El nombre del timer.
local function setTimer(name)
    aptweaks_temp.timers[name] = {justAdded = true, counter = 0, cycles = 0}
end

-- Obtiene el ciclo actual de un timer.
---@param name string El nombre del timer.
---@return number cycle El número de ciclo.
local function getTimerCycle(name)
    return aptweaks_temp.timers[name].cycles
end

-- Instancia un ChatMessge falso para usarlo con la función `ISChat.addLineInChat`.
---@param size string El tamaño del texto. Puede cambiarse luego con setSize(). Puede ser "small", "medium", y "large".
---@param text string El texto del mensaje.
---@param author string El nombre del autor del mensaje.
---@param isShowAuthor boolean Si debe mostrarse el nombre del autor en el mensaje: Ejem: "[AbrahamPicos]: Este es un mensaje.".
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

-- Devuélve la lista de warps disponibles en forma de string.
---@param warps table El mapa con los warps existentes.
---@return string aviableWarps Un string con saltos de línea compatible con el chat de Project Zomboid.
function aptweaks.showWarps(warps)
    local aviableWarps = "<LINE>"
    local index = 0

    for warp, _ in pairs(warps) do
        index = index + 1
        aviableWarps = aviableWarps .. "* " .. tostring(warp)

        if index < #warps then
            aviableWarps = aviableWarps .. "<LINE>"
        end
    end

    return aviableWarps
end

-- Crea el mapa de datos de APTweaks. También lo restablece si es necesario.
---@param reset boolean Si el mapa debe restablecerse, lo que borrará todos los datos.
function aptweaks.SetupData(reset)
    local aptweaks_data = ModData.getOrCreate("aptweaks")

    -- Las claves con las que se nombran a las tablas de ModData no admiten puntos, por lo que no puedo usar modID.
    aptweaks.aptweaks_data = aptweaks_data

    if aptweaks.isTableEmpty(aptweaks_data) or reset then
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
end

-- Procesa la respuesta de todos los comandos de APTweaks cuando son usados a travez de APTweaks.
---@param player table Un IsoPlayer.
---@param result table La tabla con el resultado del comando.
---@param provider string El proovedor de comando. Se usa para enviar comandos.
function aptweaks.processCommandResult(player, result, provider)

    local data = result.data or result
    local commandName = result.command or "MessageCommand"

    if isServer() then
        sendServerCommand(player, provider, commandName, data)

    elseif isClient() then

        if commandName == "MessageCommand" or data.text then
            local ISChat = aptweaks.ISChat

            ISChat.addLineInChat(getFakeChatMessage(ISChat.instance.chatFont, data.text, provider, false), 0)

        else
            sendClientCommand(player, provider, commandName, data)
        end
    end
end

-- Actualiza un timer, y devuelve sus variables.
---@param name string El nombre del timer.
---@param time number El tiempo que se añadirá al timer.
---@return number cycle El número de ciclo.
---@return boolean isCycleUpdate Si esta actualización resultó en un nuevo ciclo.
function aptweaks.getTimerUpdate(name, time)
    local timer = aptweaks_temp.timers[name]
    local isCycleUpdate = timer.justAdded -- Con esto el primer ciclo es el 0.

    timer.counter = timer.counter + time
    timer.justAdded = false

    if timer.counter >= 1 then
        timer.counter = timer.counter - 1
        timer.cycles = timer.cycles + 1
        isCycleUpdate = true
    end

    return timer.cycles, isCycleUpdate
end

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

-- Restablece el estado AFK del cliente.
---@param player table|nil El IsoPlayer asociado al cliente.
function aptweaks.resetAfkStatus(player)

    -- Validar si pasó suficiente tiempo para tener que notificar al usuario.
    if player and (getTimerCycle("afk") >= APTweaksVars.AfkStart) then
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_AfkRemoved"), 0, 255, 0, 500)
    end

    -- Restablecer timer
    setTimer("afk")
end

-- Restablece el estado de teletransporte del cliente.
---@param player table El IsoPlayer asociado al cliente.
---@param teleporting table Una referencia a la tabla de teletransporte del cliente (optimización).
function aptweaks.resetTeleportStatus(player, teleporting)
    -- restablecer timer y notificar al usuario.
    player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportCancelled"), 255, 0, 0, 500)
    setTimer("teleport")

    -- Validar que aún no se haya enviado una solicitud al servidor. Si se hizo, cambiar estado a cancelado y salir.
    if teleporting.status == "requested" then
        teleporting.status = "cancelled"
        return
    end

    -- Limpiar teletransporte.
    client_flags.teleporting = nil
end

-- Devuélve si un rol es el rol por defecto para los nuevos usuarios.
---@param role table
---@return boolean|nil isDefault
function aptweaks.isRoleUsersDefault(role)

    if not role:isReadOnly() then return false end

    local defaults = role:getDefaults()

    for i = 0, defaults:size() - 1 do
        local string = defaults:get(i)

        if string == "user" then
            return true
        end
    end
end

-- Crea y devuélve un nuevo rol.
---@param name string
---@return table|nil role
function aptweaks.getNewRole(name)
    local roles = getRoles()

    addRole(name)

    for i = 0, roles:size() - 1 do
        local role = roles:get(i)

        if role:getName() == name then
            return role
        end
    end
end

-- Extiende una lista de streams con los elementos de otra.
---@param destList table La lista de destino.
---@param list table La lista cuyos elementos se copiarán a otra.
---@param map table|nil Si los elementos deben añadirse también a un mapa vacío.
function aptweaks.extendStreamsList(destList, list, map)

    for _, value in ipairs(list) do
        local exists = false

        for _, destValue in ipairs(destList) do
            local shortCommand = value.shortCommand

            if shortCommand and (shortCommand == destValue.shortCommand) or value.commmand == destValue.command  then
                exists = true
                break
            end
        end

        if exists then
            print ("[ATWeaks (" .. value.provider .. ")] WARN: Stream already exists: "  .. value.name)
            break
        end

        if map then
            map[value.name] = value
        end

        table.insert(destList, value)
    end
end

-- Ejecuta acciones cuando el servidor o un cliente envió un comando relevante para APTweaks.
---@param module string La ID del módulo que envió el comando.
---@param command string El comando es sí.
---@param player table|nil El IsoPlayer asociado al cliente que envió el comando.
---@param args table Los argumentos del comando.
function aptweaks.OnCommand(module, command, player, args)

    -- Si el módulo no coincide con APTweaks, no hay nada que hacer.
    if module ~= modID then return end

    player = player or client_flags.player

    -- Manejar comando.
    local result = commands[command].handler(player, args)

    -- Procesar el resultado.
    if result then
        aptweaks.processCommandResult(player, result, modID)
    end
end

-- Inicializar variables de datos temporales.
if not isServer() then
    -- La tabla de timers.
    aptweaks_temp.timers = {}
    -- El mapa de banderas del cliente. Controla los estados del cliente para los sistemas que el mod añade. 
    aptweaks_temp.client_flags = {}
    -- La tabla de los de los comandos de chat. Debe añadir aquí sus comandos para que este mod los maneje. 
    aptweaks_temp.aptweaks_streams = {}

    -- Inicializar timers.
    setTimer("afk"); setTimer("teleport")

else
    -- El submapa de los jugadores que están en la pantalla de carga.
    aptweaks_temp.afk = {}
    -- El submapa de los jugadres pateados.
    aptweaks_temp.kicked = {}
    -- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por algún cliente.
    aptweaks_temp.blocked = {}
    -- El submapa de los clientes que se están teletransportando en este momento.
    aptweaks_temp.teleport = {}
    -- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod rastrea conexiones y desconexiones.
    aptweaks_temp.onlinePlayers = {}
    -- La tabla con las funciones que se ejecutarán cada vez que un jugador se conecta.
    aptweaks_temp.onPlayerConnected = {}
    -- La tabla con las funciones que se ejecutarán cada vez que un jugador se desconecta.
    aptweaks_temp.onPlayerDisconnected = {}
end

return aptweaks
