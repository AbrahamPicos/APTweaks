-- APTweaks_Client_Chat.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Documentar el tipo de los streams vanilla.
---@alias ISStream {name:string,command:string,shortCommand:string,tabID:integer}

-- Documentar los campos faltantes para ISRichTextPanel en Umbrella.
---@class ISRichTextPanel
---@field tabID integer
---@field chatMessages ChatMessage[]
---@field streamID integer
---@field chatStreams ISStream[]

--------------------------------------------------------------

local aptweaks = require("APTweaks")

require "APTweaks_Client_Chat_Utils"

---@class APTProtoCommand
---@field name string
---@field command string
---@field shortCommand string?
---@field argc {min:integer,max:integer}?
---@field usage string
---@field requires {tabID:integer?,admin:boolean?,playerAlive:boolean?}?
---@field customRequires table<string,boolean?>?

---@class APTSubcommand
---@field argc {max:integer}
---@field usage string
---@field actions string[]?
---@field handler fun(player:IsoPlayer,args:string[]):APTResult

---@class APTCommand: APTProtoCommand
---@field handler fun(player:IsoPlayer,args:string[]):APTResult

---@class APTAdvancedCommand: APTProtoCommand
---@field subcommands table<string,APTSubcommand?>?

---@class APTProtoStream: APTProtoCommand
---@field provider string
---@field checker fun(player:IsoPlayer,requires:table<string,boolean?>):boolean

---@class APTStream: APTProtoStream,APTCommand

---@class APTAdvancedStream: APTProtoStream,APTAdvancedCommand

---@class APTChatMessage
---@field modID string
---@field getTextWithPrefix fun(self):string
---@field isShowAuthor fun(self):boolean
---@field getAuthor fun(self):string
---@field getText fun(self):string
---@field setSize fun(self,newSize:string)
---@field setText fun(self,newText:string)

local table = table
local string = string

local pairs = pairs
local ipairs = ipairs

local modID = aptweaks.modID
local utils = aptweaks.utils
local aptweaks_temp = aptweaks.aptweaks_temp
local legacy_functions = aptweaks.legacy_functions

local resetAfkStatus = utils.resetAfkStatus
local processCommandResult = utils.processCommandResult
local extendStreamsList = utils.extendStreamsList

local ISChat = ISChat ---@cast ISChat.instance -? Las funciones en ISChat sólo se usan cuando el chat está inicializado.
local Events = Events

local getText = getText
local doKeyPress = doKeyPress
local isCoopHost = isCoopHost
local getTimestampMs = getTimestampMs

legacy_functions.addLineInChat = legacy_functions.addLineInChat or ISChat.addLineInChat
legacy_functions.onSwitchStream = legacy_functions.onSwitchStream or ISChat.onSwitchStream
legacy_functions.onCommandEntered = legacy_functions.onCommandEntered or ISChat.onCommandEntered
legacy_functions.updateChatPrefixSettings = legacy_functions.updateChatPrefixSettings or ISChat.updateChatPrefixSettings

local luautils = luautils

local client_flags = aptweaks_temp.client_flags
local aptweaks_chatStreams = aptweaks_temp.aptweaks_chat.streams

-- Funciones Auxiliares.
----------------------------------------

-- Comprueba si se cumplen los requerimientos para ejecutar un comando de chat de APTweaks.
---@param chat ISChat La única instancia del chat.
---@param player IsoPlayer El jugador asociado al cliente.
---@param commandData APTStream|APTAdvancedStream El comando que está intentando ejecutar.
---@return boolean canExec Si el comando debería ejecutarse.
---@return APTResult? result El resultado del comando, si la comprobación fue terminante.
local function checkRequires(chat, player, commandData)
    local requires = commandData.requires or {}

    -- Comprobar los permisos requeridos.
    if requires.admin and not (isCoopHost() or isAdmin()) then
        return false, nil
    end

    -- Comprobar si el jugador debe estar vivo.
    if requires.playerAlive and not player:isAlive() then
        return false, nil
    end

    local customRequires = commandData.customRequires

    -- Comprobar los requerimientos específicos del comando según el proovedor.
    if customRequires and not commandData.checker(player, customRequires) then
        return false, nil
    end

    local tabID = requires.tabID

    -- Comprobar la coincidencia de pestaña.
    if tabID and chat.currentTabID ~= tabID then
        return false, {text = "No puede ejecutar este comando en esta pestaña."}
    end

    return true, nil
end

-- Despacha un comando de Chat de APTweaks.
---@param chat ISChat La instancia del chat.
---@param player IsoPlayer El IsoPlayer asociado al cliente.
---@param commandData APTStream|APTAdvancedStream La tabla que define al comando.
---@param argsString string Una tabla con los argumentos que acompañaron al comando.
---@return APTResult result El resultado del comando. Una tabla con un texto y un comando según se requiera.
local function handleAPTweaksChatCommand(chat, player, commandData, argsString)
    local canExec, result = checkRequires(chat, player, commandData)

    -- Comprobar los requerimientos para ejecutar el comando.
    if not canExec then
        return result or {text = "Unknown command " .. commandData.name} -- Fingiendo que el comando no existe, como en Minecraft.
    end

    local args = {} ---@type string[]

    -- Separar argumentos del resto del texto, y limpiar los espacios.
    for arg in string.gmatch(argsString, "%S+") do
        table.insert(args, arg)
    end

    local argsRange = commandData.argc or {min = 0, max = 0}
    local usage = commandData.usage
    local argc = #args

    -- Comprobar el mínimo de argumentos.
    if argc < argsRange.min then
        return {text = getText("IGUI_APTweaks_Chat_FewArgs", getText(usage))}
    end

    local subcommands = commandData.subcommands

    -- Comprobar si debería haber un subcomando.
    if subcommands then
        local subcommandData = subcommands[args[1]--[[@cast -?]]] -- Garantizado por el mínimo de argumentos.

        if subcommandData then
            argsRange.max = subcommandData.argc.max
            usage = subcommandData.usage
        end

        ---@cast commandData +APTSubcommand? Forzando un nuevo tipo en el parámetro.
        commandData = subcommandData
    end

    -- Si para este punto hay commandData, manejar. De lo contrario, devolver error.
    ---@cast commandData -APTAdvancedStream Los APTAdvancedStream siempre tienen un APTSubcommand.
    if commandData then

        if argc > argsRange.max then
            return {text = getText("IGUI_APTweaks_Chat_ManyArgs", getText(usage))}
        end

        -- Validar acciones y obtener resultado.
        for i, action in pairs(commandData.actions or {proceed = true}) do

            if i == "proceed" or action == args[3] then
                return commandData.handler(player, args)
            end
        end
    end

    return {text = getText("IGUI_APTweaks_Chat_IncorrectUse", getText(usage))}
end

-- Funciones que extienden a otras en ISChat.
----------------------------------------

-- De ser necesario, corrige el bug de líneas infinitas que hay en el código vanilla.
---@param message ChatMessage Un objeto ChatMessage, o uno que simule serlo.
---@param tabID integer La ID de la pestaña en la que se mostrará el mensaje. Tenga en cuenta que la ID de la pestaña 1 es 0.
local function addLineInChatExtension(message, tabID)
    local chatText ---@type ISRichTextPanel?

    -- Buscar el panel de texto correspondiente a la pestaña.
    for _, tab in ipairs(ISChat.instance.tabs) do

        if tab and tab.tabID == tabID then -- Comprobar si tab existe me parece redundante, pero así lo hace vanilla.
            chatText = tab
            break
        end
    end

    if not chatText then return end

    local chatMessages = chatText.chatMessages

    -- Si el número de mensajes excede el máximo, limpiar mensajes sobrantes.
    if #chatMessages > ISChat.maxLine + 1 then
        local newMessages = {} ---@type ChatMessage[]

        for i, msg in ipairs(chatMessages) do

            if i ~= 1 then
                table.insert(newMessages, msg)
            end
        end

        chatText.chatMessages = newMessages
    end
end

-- Cambia el tamaño de texto de los mensajes de APTweaks cuando cambia la configuación del chat.
---@param chat ISChat La instancia del chat.
local function updateChatPrefixSettingsExtension(chat)

    for _, tab in ipairs(chat.tabs) do

        ---@cast tab.chatMessages (APTChatMessage|ChatMessage)[] Este mod añade mensajes falsos a esta tabla.
        for _, msg in ipairs(tab.chatMessages) do

            if msg.modID == modID then
                msg:setSize--[[@cast -?]](chat.chatFont) -- Garantizado por modID.
            end
        end
    end
end

-- Interpreta si el texto ingresado en el chat es un comando de APTweaks.
-- Tenga en cuenta que esta función es llamada cada vez que se ingresa texto al chat, independientemente del contenido.
---@param player IsoPlayer El IsoPlayer ligado al cliente.
---@param chat ISChat La instancia de ISChat.
local function OnCommandEnteredExtension(player, chat)
    local textEntry = chat.textEntry:getText()

    -- Reiniciar estado AFK.
    resetAfkStatus(player, getTimestampMs())

    -- Validar que el texto de entrada no esté vacío.
    if not textEntry:match("%S") then return end

    local entryWithSpace = textEntry .. " "
    local commandData ---@type (APTStream|APTAdvancedStream)?

    -- Buscar si el texto coincide con un comando de APTweaks.
    for _, command in pairs(aptweaks_chatStreams) do

        if luautils.stringStarts(entryWithSpace, command.command) then
            commandData = command
            break

        elseif command.shortCommand and luautils.stringStarts(entryWithSpace, command.shortCommand) then
            commandData = command
            break
        end
    end

    -- Si no hubo coincidencia, no hay nada que hacer.
    if not commandData then return end

    -- Terminar, y procesar resultado.
    chat:unfocus()
    doKeyPress(false)
    chat.textEntry:setText("")
    processCommandResult(player, handleAPTweaksChatCommand(
        chat, player, commandData, string.sub(textEntry, #commandData.command)
    ), commandData.provider)

    chat.timerTextEntry = 20
end

-- Añade a la tab complete del juego los comandos de APTweaks.
-- Si la función heredada se salta índices al cambiar de stream, busca si alguno correspondía con un comando de APTweaks.
---@param chat ISChat La única instancia del chat.
---@param previousStreamIndex integer El índice actual, antes de que la función heredada lo cambie.
---@param curTxtPanel ISRichTextPanel Idk. --XD
local function OnSwitchStreamExtension(chat, previousStreamIndex, curTxtPanel)
    local expectedIntex = previousStreamIndex + 1 -- El indice esperado si no hubiera un salto de índices.
    local actualIndex = curTxtPanel.streamID

    -- Si no hubo un salto de indices, no hay nada que hacer.
    if actualIndex == expectedIntex then return end

    local chatStreams = curTxtPanel.chatStreams
    local maxIndex ---@type integer -- El indice máximo que se evaluará.

    -- Si el indice actual es el primero, el índice máximo será el total de índices.
    if actualIndex == 1 then
        maxIndex =  #chatStreams

    -- De lo contrario, será el índice inmediatamente anterior al actual.
    else
        maxIndex = actualIndex - 1
    end

    -- Buscar si alguno de los indices saltados coincide con un comando de APTweaks.
    for i = expectedIntex, maxIndex do
        local commandData = aptweaks_chatStreams[chatStreams[i]--[[@cast -?]].name] -- El rango de índices lo garantiza.

        -- Si hay conincidencia, y si se cumple con los requerimientos del comando, establecerlo.
        if commandData and checkRequires(chat, client_flags.player, commandData) then
            ISChat.instance.textEntry:setText(commandData.command)

            curTxtPanel.streamID = i
            return
        end
    end
end

-- Sobreescrituras.
----------------------------------------

-- Registrar comandos, y aplicar parches en la clase lua ISChat.
Events.OnGameStart.Add(function()
    extendStreamsList(aptweaks_chatStreams, pairs(ISChat.allChatStreams), function(_, command)
        table.insert(ISChat.allChatStreams, {
            name = command.name,
            command = command.command,
            shortCommand = command.shortCommand,
            tabID = command.tabID
        })
    end)

    function ISChat.onSwitchStream()
        local chat = ISChat.instance
        local curTxtPanel = chat.chatText ---@cast curTxtPanel -? Siempre existe cuando se llama a la función.
        local previousStreamIndex = curTxtPanel.streamID

        legacy_functions.onSwitchStream()
        OnSwitchStreamExtension(chat, previousStreamIndex, curTxtPanel)
    end

    ---@param message ChatMessage
    ---@param tabID integer
    function ISChat.addLineInChat(message, tabID)
        legacy_functions.addLineInChat(message, tabID)
        addLineInChatExtension(message, tabID)
    end

    function ISChat:updateChatPrefixSettings()
        updateChatPrefixSettingsExtension(self)
        legacy_functions.updateChatPrefixSettings(self)
    end

    function ISChat:onCommandEntered() -- `self` no se pasa correctamente aquí. Probablemente por culpa de Kahlua.
        OnCommandEnteredExtension(client_flags.player, ISChat.instance)
        legacy_functions.onCommandEntered(self)
    end
end)

-- Permitir que se usen [/r/n] como argumentos o parte de ellos.
-- Hacer a los comandos internacionalizables.
-- Añadir comprobaciones comunes para isAlive y cababilities como requerimientos de comandos. -- En trabajo
--- Esto debe sustituir también las comprobaciones de isAdmin.
