-- APTweaks_Client_Chat.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo sobrescribe múltipes funciones del juego base. No lo recargue si hay otros mods.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Client_Commands")

-- El módulo APTweaks.lua está en "shared", donde no está disponible ISChat.
aptweaks.ISChat = aptweaks.ISChat or ISChat

local modID = aptweaks.modID
local player_flags = aptweaks.player_flags

local WarpComamand = commands.WarpComamand
local SafehouseCommand = commands.SafehouseCommand
local ProcessCommandResult = aptweaks.ProcessCommandResult

local getText = aptweaks.getText
local ISChat = aptweaks.ISChat
local doKeyPress = aptweaks.doKeyPress

aptweaks.old_onSwitchStream = aptweaks.old_onSwitchStream or ISChat.onSwitchStream
aptweaks.old_onCommandEntered = aptweaks.old_onCommandEntered or ISChat.onCommandEntered
aptweaks.old_addLineInChat = aptweaks.old_addLineInChat or ISChat.addLineInChat
aptweaks.old_updateChatPrefixSettings = aptweaks.old_updateChatPrefixSettings or ISChat.updateChatPrefixSettings

local old_onSwitchStream = aptweaks.old_onSwitchStream
local old_onCommandEntered = aptweaks.old_onCommandEntered
local old_addLineInChat = aptweaks.old_addLineInChat
local old_updateChatPrefixSettings = aptweaks.old_updateChatPrefixSettings

local luautils = aptweaks.luautils
local APTweaksVars = aptweaks.APTweaksVars

-- Las definiciones de los comandos de APTweaks.
local aptweaks_commands = {
    {name = "aptweaks", command = "/aptweaks ", tabID = 1},
    {name = "warp", command = "/warp ", tabID = 1},
    {name = "safezone", command = "/safezone ", tabID = 1}}

-- Registrando los comandos de APTweaks en la clase Lua ISChat.
for i = 1, #aptweaks_commands do
    local needed = false

    for _, v in ipairs(ISChat.allChatStreams) do

        if v == aptweaks_commands[i] then
            needed = true
        end
    end

    if needed then
        table.insert(ISChat.allChatStreams, aptweaks_commands[i])
    end
end

-- Procesa los comandos de APTweaks.
---@param command string El comando que se ejecutó.
---@param args string Una cadena de todos los argumentos que se usaron al ingresar el comando.
local function ProcessAPTweaksCommand(command, args)
    local player = player_flags.player

    if not player then return end

    -- La tabla que almacena cada palabra incluida en la cadena args.
    local words = {}

    for arg in string.gmatch(args, "%S+") do
        table.insert(words, arg)
    end
    local result = nil

    -- El comando principal de aptweaks (experimental).
    if command == "aptweaks" then

        if #words <= 1 then

            if #words == 1 then
                local subcommand = words[1]

                if subcommand == "cleardata" then
                    result = {text = "Espere un momento", command = "clearData", data = {}}
                end
            else
                result = {text = "Faltan argumentos. Use /aptweaks cleardata"}
            end
        else
            result = {text = "Demasiados argumentos"}
        end

    -- El comando warp. 
    elseif command == getText("UI_APTweaks_WarpCommand") and APTweaksVars.WarpSystemEnabled then
        result = WarpComamand(player, words)

    -- El comando safezone.
    elseif command == "safezone" and APTweaksVars.SafehouseSystemEnabled then
        result = SafehouseCommand(player, words)

    -- El comando de pruebas.
    elseif command == "something" then
        result = {text = "Espere un momento...", command = "something", data = {}}
    end
    ProcessCommandResult(player, result)
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: AddLineInChat de la clase Lua ISChat.
-- De ser necesario, corrige el bug de líneas infinitas que hay en el código vanilla.
---@param message table Un objeto ChatMessage, o uno que simule serlo.
---@param tabID number La ID de la pestaña en la que se mostrará el mensaje. Tenga encuenta que la ID de la pestaña 1 es 0.
ISChat.addLineInChat = function(message, tabID)

    old_addLineInChat(message, tabID)

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
    old_updateChatPrefixSettings(self)
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onCommandEntered de la clase Lua ISChat.
-- Añade la lógica adicional necesaria para ejecutar los comandos de APTweaks.
function ISChat:onCommandEntered()

    -- Por alguna razón las cosas que necesito aquí no están en `self`.
    local chat = ISChat.instance
    -- Este es el texto que había en el cuadro de entrada de texto del chat al momento en el que se llamó a la función.
    -- Tenga en cuenta que incluso el texto sin un "/" al inicio se interpreta como un comando.
    local textEntry = chat.textEntry:getText()

    -- No hay un return para permitir que otros mods hagan lo suyo.
    if textEntry and textEntry ~= "" then
        local aptweaksCommand = nil

        for _, command in ipairs(aptweaks_commands) do

            if chat.currentTabID == command.tabID then

                -- `stringStarts` devuelve true si el primer string coincide con el segundo, pero sólo los compara hasta el tamaño
                --   del segundo string. Es decir que por ejemplo: `stringStarts("holaquehace", "holaq")` será true.
                if luautils.stringStarts(textEntry, command.command) then
                    aptweaksCommand = command.command

                -- Actualmente ningún comando de APTweaks tiene una versión corta, pero dejé esto por si acaso.
                elseif command.shortCommand and luautils.stringStarts(textEntry, command.shortCommand) then
                    aptweaksCommand = command.shortCommand
                end

                -- No se establece chat.chatText.lastChatCommand debido a que, -aunque funcionaría-, es mejor reservarlo sólo a
                --  los comandos de chat, como el /say, /whisper, y /all.
                if aptweaksCommand ~= nil then
                    ProcessAPTweaksCommand(command.name, string.sub(textEntry, #aptweaksCommand))
                    -- Se limpia el campo de texto para evitar que vanilla lo procese otra vez.
                    chat.textEntry:setText("")
                    -- Se supone que esto registra la ejecución del comando en el log, pero no lo veo.
                    chat:logChatCommand(textEntry)
                    -- Evita que el cliente pueda volver a usar la entrada de texto del chat, y retira el foco.
                    doKeyPress(false)
                    -- El tiempo en ticks que debe pasar hasta que que doKeyPress se restablezca a true.
                    chat.timerTextEntry = 20
                    break
                end
            end
        end
    end
    old_onCommandEntered(self)
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onSwitchStream de la clase Lua ISChat.
-- Añade a la pseudo tab complete del juego los comandos de APTweaks.
ISChat.onSwitchStream = function ()
    local curTxtPanel = ISChat.instance.chatText
    -- El índice actual, antes de que onSwitchStream lo cambie. 
    -- Mientras respeten la convención, todos los mods tendrían que tener la oportunidad de almacenarlo.
    local previousStreamIndex = curTxtPanel.streamID

    old_onSwitchStream()

    local actualStreamIndex = curTxtPanel.streamID
    local allChatStreams = curTxtPanel.chatStreams

    -- Si el índice actual no es igual al índice anterior +1. Esto significa que la función heredada ignoró uno o más índices. Esto
    --  puede ocurrir porque el cliente no debería verlos, -como cuando no tiene permisos suficientes-, o porque no pueden ser
    --  comprobados por el método `checkPlayerCanUseChat`. Esto último ocurre con todos los comandos de mods.
    -- Si la función heredada proviene de un mod bien programado, significa que ignoró lo índices que no le corresponden.
    -- Nuevamente, no hay un return para permitir que otros mods hagan lo suyo.
    if actualStreamIndex ~= previousStreamIndex + 1 then
        -- Determina la cantidad máxima de índices que se evaluarán. Si la función vanilla regresó al primer índice, -lo que pasa
        --  siempre que ha recorrido ya todos los streams-, se evaluará desde el índice anterior (´previousStreamIndex + 1´) hasta
        --  el índice final (´#allChatStreams´), hasta encontrar el siguiente comando de APTweaks. De lo contrarío, sólo evaluará
        --  los índices desde el índice anterior hasta el actual (´i = previousStreamIndex + 1, actualStreamIndex - 1´).
        local maxIndex = (actualStreamIndex == 1 and #allChatStreams or actualStreamIndex - 1)
        local isAptweaksCommand = false

        for i = previousStreamIndex + 1, maxIndex do

            -- Es posible optimizar esto si combierto ´aptweaks_commands´ en un mapa.
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
end

-- Aún debo hacer que onCommandEntered ignore los comandos que están deshabilitados en la onfiguración, y que tanto los comandos
--- de sistemas deshabilitados, como los que no debería ver por permissos, sean ignorados en onSwitchStream.
