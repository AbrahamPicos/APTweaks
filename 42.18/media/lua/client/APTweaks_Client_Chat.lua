-- APTweaks_Client_Chat.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo sobrescribe múltiples funciones del juego base. No lo recargue si hay otros mods.

local aptweaks = require("APTweaks")

aptweaks.ISChat = aptweaks.ISChat or ISChat -- El módulo APTweaks.lua está en "shared", donde no está disponible ISChat.

local modID = aptweaks.modID
local aptweaks_temp = aptweaks.aptweaks_temp
local legacy_functions = aptweaks.legacy_functions

local resetAfkStatus = aptweaks.resetAfkStatus
local extendStreamsList = aptweaks.extendStreamsList
local processCommandResult = aptweaks.processCommandResult

local Events = aptweaks.Events
local ISChat = aptweaks.ISChat
local getText = aptweaks.getText
local Capability = aptweaks.Capability
local doKeyPress = aptweaks.doKeyPress
local getTimestampMs = aptweaks.getTimestampMs

legacy_functions.addLineInChat = legacy_functions.addLineInChat or ISChat.addLineInChat
legacy_functions.onSwitchStream = legacy_functions.onSwitchStream or ISChat.onSwitchStream
legacy_functions.onCommandEntered = legacy_functions.onCommandEntered or ISChat.onCommandEntered
legacy_functions.updateChatPrefixSettings = legacy_functions.updateChatPrefixSettings or ISChat.updateChatPrefixSettings

aptweaks_temp.aptweaks_commands = aptweaks_temp.aptweaks_commands or {}

local luautils = aptweaks.luautils

local aptweaks_streams = aptweaks_temp.aptweaks_streams
local client_flags = aptweaks_temp.client_flags
local aptweaks_commands = aptweaks_temp.aptweaks_commands

-- Despacha un comando de Chat de APTweaks.
---@param player table El IsoPlayer asociado al cliente.
---@param commandData table La tabla que define al comando.
---@param args table Una tabla con los argumentos que acompañaron al comando.
---@return table resul El resultado del comando. Una tabla con un texto y un comando según se requiera.
local function handleAPTweaksChatCommand(player, commandData, args)
    -- Comprobar los requerimientos específicos del comando.
    local requires = commandData.requires

    if not requires.checker(player, requires) then
        return {text = "Unknown command " .. commandData.name}
    end

    -- Validar si cumple con el número mínimo de argumentos.
    local argsRange = commandData.argc or {min = 0, max = 0}
    local usage = commandData.usage
    local argc = #args

    -- Comprobar si debería haber un subcomando.
    local subcommands = commandData.subcommands

    if subcommands then
        local subcommandData = commandData.subcommands[args[1]]

        if subcommandData then
            argsRange.min, argsRange.max = subcommandData.argc.max, subcommandData.argc.max
            usage = subcommandData.usage
        end

        commandData = subcommandData
    end

    -- Comprobar el rango de argumentos.
    if argc < argsRange.min then
        return {text = getText("IGUI_APTweaks_Chat_FewArgs", getText(usage))}
    end

    if commandData and argc > argsRange.max then
        return {text = getText("IGUI_APTweaks_Chat_ManyArgs", getText(usage))}
    end

    -- Obtener resultado. 
    return commandData and commandData.handler(player, args)
        or {text = getText("IGUI_APTweaks_Chat_IncorrectUse", getText(usage))}
end

-- Interpreta si el texto ingresado en el chat es un comando de APTweaks.
-- Tenga en cuenta que esta función es llamada cada vez que se ingresa texto al chat, independientemente del contenido.
---@param player table El IsoPlayer ligado al cliente.
---@param chat table La instancia de ISChat.
---@param textEntry string El texto que se ingresó al chat.
local function APTweaksOnCommandEntered(player, chat, textEntry)

    -- Limpiar líneas vacías si el jugador no las tiene permitidas.
    if not player:getRole():hasCapability(Capability.EmptyLinesInChat) then
        textEntry = textEntry:gsub("[\n\r]", " ")
    end

    -- Validar entrada de texto.
    if not textEntry or textEntry == "" or textEntry == " " then return end

    -- Comprobar enfriamiento por modo lento.
    if not player:getRole():hasCapability(Capability.IgnoreChatSlowMode) and chat.timerMessageSlowMode > getTimestampMs() then
        return -- Debe haber una manera de evitar que el usuario vea este mensaje.
    end

    -- Buscar coincidencia en APTweaks.
    local entryWithSpace = textEntry .. " "
    local commandString, commandData

    for _, command in ipairs(aptweaks_streams) do

        if luautils.stringStarts(entryWithSpace, command.command) then
            commandString, commandData = command.command, command
            break

        elseif command.shortCommand and luautils.stringStarts(entryWithSpace, command.shortCommand) then
            commandString, commandData = command.shortCommand, command
            break
        end
    end

    -- Reiniciar estado AFK del jugador.
    resetAfkStatus(player)

    -- Validar coincidencia y pestaña.
    if not commandString or (chat.currentTabID ~= commandData.tabID) then return end

    -- Separar argumentos y limpiar espacios.
    local args = {}

    for arg in string.gmatch(string.sub(textEntry, #commandString), "%S+") do
        table.insert(args, arg)
    end

    -- Manejar comando.
    local result = handleAPTweaksChatCommand(player, commandData, args)

    processCommandResult(player, result, commandData.provider)

    -- Terminar.
    chat:unfocus()
    doKeyPress(false)
    chat.textEntry:setText("")

    chat.timerTextEntry = 20
end

-- Añade a la pseudo tab complete los comandos de APTweaks.
---@param previousStreamIndex number El índice actual, antes de que la función heredada lo cambie.
---@param curTxtPanel table Idk.
local function APTweaksOnSwitchStream(previousStreamIndex, curTxtPanel)
    local actualStreamIndex = curTxtPanel.streamID
    local chatStreams = curTxtPanel.chatStreams

    -- Si el índice actual es exactamente el siguiente esperado, no hay nada que hacer.
    if actualStreamIndex == previousStreamIndex + 1 then return end

    -- Determinar el rango máximo de índices a evaluar.
    local maxIndex = (actualStreamIndex == 1) and #chatStreams or (actualStreamIndex - 1)

    -- Buscar coincidencia en APTweaks.
    for i = previousStreamIndex + 1, maxIndex do
        local aptweaksCommand = aptweaks_commands[chatStreams[i].name]

        if aptweaksCommand then
            local requires = aptweaksCommand.requires

            -- Cambiar al comando si se cumple con los requerimientos.
            if requires.checker(client_flags.player, requires) then
                ISChat.instance.textEntry:setText(aptweaksCommand.command)
                curTxtPanel.streamID = i
                return
            end
        end
    end
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: updateChatPrefixSettings de la clase Lua ISChat.
-- Actualiza el tamaño de letra en nuestros mensajes falsos.
function ISChat:updateChatPrefixSettings()

    for _, tab in ipairs(self.tabs) do

        for _, msg in ipairs(tab.chatMessages) do

            if msg.modID == modID then
                msg:setSize(self.chatFont)
            end
        end
    end

    legacy_functions.updateChatPrefixSettings(self)
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: AddLineInChat de la clase Lua ISChat.
-- De ser necesario, corrige el bug de líneas infinitas que hay en el código vanilla.
---@param message table Un objeto ChatMessage, o uno que simule serlo.
---@param tabID number La ID de la pestaña en la que se mostrará el mensaje. Tenga en cuenta que la ID de la pestaña 1 es 0.
ISChat.addLineInChat = function(message, tabID)
    legacy_functions.addLineInChat(message, tabID)

    local chatText

    for _, tab in ipairs(ISChat.instance.tabs) do

        if tab ~= nil and tab.tabID == tabID then
            chatText = tab
            break
        end
    end

    if #chatText.chatMessages > ISChat.maxLine + 1 then
        local newMessages = {}

        for i, msg in ipairs(chatText.chatMessages) do

            if i ~= 1 then
                table.insert(newMessages, msg)
            end
        end

        chatText.chatMessages = newMessages
    end
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onCommandEntered de la clase Lua ISChat.
function ISChat:onCommandEntered()
    -- Por alguna razón esto no está en la tabla `self`.
    local chat = ISChat.instance

    APTweaksOnCommandEntered(client_flags.player, chat, chat.textEntry:getText())
    legacy_functions.onCommandEntered(self)
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onSwitchStream de la clase Lua ISChat.
-- La función heredada es llamada temprano para que todos los mods tengan la oportunidad de almacenar la ID del stream anterior.
ISChat.onSwitchStream = function ()
    local curTxtPanel = ISChat.instance.chatText
    local previousStreamIndex = curTxtPanel.streamID

    legacy_functions.onSwitchStream()
    APTweaksOnSwitchStream(previousStreamIndex, curTxtPanel)
end

-- Registra los comandos en la clase Lua ISChat.
Events.OnGameStart.Add(function() extendStreamsList(ISChat.allChatStreams, aptweaks_streams, aptweaks_commands) end)
