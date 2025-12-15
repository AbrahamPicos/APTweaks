-- APTweaks_Client_Chat.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo sobrescribe múltiples funciones del juego base. No lo recargue si hay otros mods.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Client_Commands")

-- El módulo APTweaks.lua está en "shared", donde no está disponible ISChat.
aptweaks.ISChat = aptweaks.ISChat or ISChat

local modID = aptweaks.modID
local client_flags = aptweaks.client_flags
local legacy_functions = aptweaks.legacy_functions

local APTweaksCommand = commands.APTweaksCommand
local WarpCommand = commands.WarpCommand
local WarpsCommand = commands.WarpsCommand
local ClaimCommand = commands.ClaimCommand
local ProcessCommandResult = aptweaks.ProcessCommandResult

local getText = aptweaks.getText
local ISChat = aptweaks.ISChat
local isAdmin = aptweaks.isAdmin
local isCoopHost = aptweaks.isCoopHost
local doKeyPress = aptweaks.doKeyPress

legacy_functions.onSwitchStream = legacy_functions.onSwitchStream or ISChat.onSwitchStream
legacy_functions.onCommandEntered = legacy_functions.onCommandEntered or ISChat.onCommandEntered
legacy_functions.addLineInChat = legacy_functions.addLineInChat or ISChat.addLineInChat
legacy_functions.updateChatPrefixSettings = legacy_functions.updateChatPrefixSettings or ISChat.updateChatPrefixSettings

local luautils = aptweaks.luautils
local APTweaksVars = aptweaks.APTweaksVars

-- Las definiciones de los comandos de APTweaks.
local aptweaks_commands = {
    {name = "aptweaks", command = "/aptweaks ", tabID = 1},
    {name = "warp", command = "/warp ", tabID = 1},
    {name = "warps", command = "/warps ", tabID = 1},
    {name = "claim", command = "/claim ", tabID = 1},
    {name = "something", command = "/something ", tabID = 1}}

-- Registrando los comandos de APTweaks en la clase Lua ISChat.
for i = 1, #aptweaks_commands do
    local isNeeded = true

    for _, v in ipairs(ISChat.allChatStreams) do

        if v == aptweaks_commands[i] then
            isNeeded = false
        end
    end

    if isNeeded then
        table.insert(ISChat.allChatStreams, aptweaks_commands[i])
    end
end

-- Procesa los comandos de APTweaks.
---@param command string El comando que se interpretó.
---@param argsString string Una cadena de todos los argumentos que se usaron al ingresar el comando.
---@return boolean handled Si el comando fue menejado completamente por APTweaks.
local function ProcessAPTweaksCommand(player, command, argsString)
    local args = {}
    local result

    for arg in string.gmatch(argsString, "%S+") do
        table.insert(args, arg)
    end

    -- El comando principal de APTweaks (para administradores).
    if command == "aptweaks" and (isCoopHost() or isAdmin()) then
        result = APTweaksCommand(player, args)

    -- El comando warp. 
    elseif command == getText("UI_APTweaks_WarpCommand") and APTweaksVars.TeleportSystemEnabled then
        result = WarpCommand(player, args)

    -- El comando warps.
    elseif command == "warps" and APTweaksVars.TeleportSystemEnabled then
        result = WarpsCommand(args)

    -- El comando claim.
    elseif command == "claim" and APTweaksVars.SafehouseSystemEnabled then
        result = ClaimCommand(player, args)

    -- Un comando de pruebas (se usapara el desarrollo del mod).
    elseif command == "something" then
        result = {command = "something", data = {}}
    end

    return ProcessCommandResult(player, result)
end

-- Interpreta si el texto ingresado en el chat es un comando de APTweaks.
-- Tenga en cuenta que esta función es llamada cada vez que se ingresa texto al chat, independientemente del contenido.
---@param player table El IsoPlayer ligado al cliente.
---@param chat table La instancia de ISChat.
---@param textEntry string El texto que se ingresó al chat.
local function APTweaksOnCommandEntered(player, chat, textEntry)

    -- Si la entrada de texto es válida.
    -- En vanilla los comandos pueden ejecutarse incluso con el jugador muerto. Esto no es deseable para este mod.
    if not textEntry or textEntry == "" or not player or not player:isAlive() then return end

    local commandString
    local commandData

    -- Si el texto coincide con un comando de APTweaks.
    for _, command in ipairs(aptweaks_commands) do -- Value example: {name = "command", command = "/command " shortCommand = "/cmd ", tabID = 1}

        -- La función llamada devuelve true si el primer string coincide con el segundo, pero sólo los compara hasta el tamaño
        --- del segundo. Es decir, que por ejemplo: `stringStarts("holaquehace", "holaq")` será true.
        -- En vanilla se compara `textEntry` con `command.command` directamente, lo que provoca que por ejemplo "/say" devuélva
        --- "unknown command say" en lugar de un mensaje de error indicando que faltan argumentos. Esto no es deseable para este
        --- mod, por lo que se sustituye `textEntry` por `textEntry .. " "`.
        if luautils.stringStarts(textEntry .. " ", command.command) then
            commandString, commandData = command.command, command
            break

        -- Actualmente ningún comando de APTweaks tiene una versión corta, pero dejé esto por si acaso.
        elseif command.shortCommand and luautils.stringStarts(textEntry .. " ", command.shortCommand) then
            commandString, commandData = command.shortCommand, command
            break
        end
    end

    -- Si no se encontró un comando que coincida, o se ejecutó en la pestaña incorrecta.
    -- Vanilla manejará el comando correctamente en estos casos.
    if not commandString or chat.currentTabID ~= commandData.tabID then return end

    -- Procesar el comando.
    local handled = ProcessAPTweaksCommand(player, commandData.name, string.sub(textEntry, #commandString))

    -- No se establece `chat.chatText.lastChatCommand` debido a que, -aunque funcionaría-, es mejor reservarlo sólo a los comandos
    --- de chat, como el /say, /whisper, y /all.
    if not handled then return end

    -- Se limpia el campo de texto para evitar que vanilla lo procese otra vez.
    chat.textEntry:setText("")
    -- Se supone que esto registra la ejecución del comando en el log, pero no lo veo.
    chat:logChatCommand(textEntry)
    -- Evita que el cliente pueda volver a usar la entrada de texto del chat, y retira el foco.
    doKeyPress(false)
    -- El tiempo en ticks que debe pasar hasta que que doKeyPress se restablezca a true.
    chat.timerTextEntry = 20
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

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onCommandEntered de la clase Lua ISChat.
-- Añade a la función la lógica adicional necesaria para interpretar los comandos de APTweaks.
-- Se usa la función auxiliar APTweaksOnCommandEntered para poder retornar mientras se sigue llamando a la función heredada. Esto 
---  mejora la legibilidad sin sacrificar la compatibilidad.
function ISChat:onCommandEntered()
    -- Por alguna razón esto no está en la tabla `self`.
    local chat = ISChat.instance

    APTweaksOnCommandEntered(client_flags.player, chat, chat.textEntry:getText())
    legacy_functions.onCommandEntered(self)
end

---comment
---@param previousStreamIndex any
---@param curTxtPanel any
local function APTweaksOnSwitchStream(previousStreamIndex, curTxtPanel)
    local actualStreamIndex = curTxtPanel.streamID
    local allChatStreams = curTxtPanel.chatStreams

    -- Si el índice actual no es igual al índice anterior +1. Esto significa que la función heredada ignoró uno o más índices. Esto
    --  puede ocurrir porque el cliente no debería verlos, -como cuando no tiene permisos suficientes-, o porque no pueden ser
    --  comprobados por el método `checkPlayerCanUseChat`. Esto último ocurre con todos los comandos de mods.
    -- Si la función heredada proviene de un mod bien programado, significa que ignoró los índices que no le corresponden.
    -- Nuevamente, no hay un return para permitir que otros mods hagan lo suyo.
    if not (actualStreamIndex ~= previousStreamIndex + 1) then return end

    -- Determina la cantidad máxima de índices que se evaluarán. Si la función vanilla regresó al primer índice, -lo que pasa
    --  siempre que ha recorrido ya todos los streams-, se evaluará desde el índice anterior (´previousStreamIndex + 1´) hasta
    --  el índice final (´#allChatStreams´), hasta encontrar el siguiente comando de APTweaks. De lo contrarío, sólo evaluará
    --  los índices desde el índice anterior hasta el actual (´i = previousStreamIndex + 1, actualStreamIndex - 1´).
    local maxIndex = (actualStreamIndex == 1 and #allChatStreams or actualStreamIndex - 1)
    local isAptweaksCommand = false

    for i = previousStreamIndex + 1, maxIndex do

        for j = 1, #aptweaks_commands do

            if allChatStreams[i] and allChatStreams[i].command == aptweaks_commands[j].command then
                curTxtPanel.streamID = i
                ISChat.instance.textEntry:setText(aptweaks_commands[j].command)
                isAptweaksCommand = true
                break
            end
        end

        if isAptweaksCommand then break end
    end
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onSwitchStream de la clase Lua ISChat.
-- La función heredada es llamada temprano para que todos los mods tengan la oportunidad de almacenar la ID del stream anterior.
ISChat.onSwitchStream = function ()
    local curTxtPanel = ISChat.instance.chatText
    -- El índice actual, antes de que la función heredada lo cambie.
    -- Mientras respeten la convención, todos los mods tendrían que tener la oportunidad de almacenarlo.
    local previousStreamIndex = curTxtPanel.streamID

    legacy_functions.onSwitchStream()
    APTweaksOnSwitchStream(previousStreamIndex, curTxtPanel)
end

-- Aún debo hacer que onCommandEntered ignore los comandos que están deshabilitados en la onfiguración, y que tanto los comandos
--- de sistemas deshabilitados, como los que no debería ver por permissos, sean ignorados en onSwitchStream.
-- Debo internacionalizar los comandos, pero aún necesito una biblioteca de internacionalización para las formas plurales si quero
--- soportar más idiomas que el español e inglés.
