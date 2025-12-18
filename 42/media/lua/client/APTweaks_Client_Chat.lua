-- APTweaks_Client_Chat.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo sobrescribe múltiples funciones del juego base. No lo recargue si hay otros mods.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Client_Commands")

aptweaks.ISChat = aptweaks.ISChat or ISChat -- El módulo APTweaks.lua está en "shared", donde no está disponible ISChat.

local modID = aptweaks.modID
local client_flags = aptweaks.client_flags
local legacy_functions = aptweaks.legacy_functions

local APTweaksCommand = commands.APTweaksCommand
local WarpCommand = commands.WarpCommand
local WarpsCommand = commands.WarpsCommand
local ClaimCommand = commands.ClaimCommand
local ProcessCommandResult = aptweaks.ProcessCommandResult

local ISChat = aptweaks.ISChat
local isAdmin = aptweaks.isAdmin
local Capability = aptweaks.Capability
local isCoopHost = aptweaks.isCoopHost
local doKeyPress = aptweaks.doKeyPress
local getTimestampMs = aptweaks.getTimestampMs

legacy_functions.onSwitchStream = legacy_functions.onSwitchStream or ISChat.onSwitchStream
legacy_functions.onCommandEntered = legacy_functions.onCommandEntered or ISChat.onCommandEntered
legacy_functions.addLineInChat = legacy_functions.addLineInChat or ISChat.addLineInChat
legacy_functions.updateChatPrefixSettings = legacy_functions.updateChatPrefixSettings or ISChat.updateChatPrefixSettings

local luautils = aptweaks.luautils
local APTweaksVars = aptweaks.APTweaksVars

local aptweaks_commands = {}
local aptweaks_streams = {}

aptweaks_streams[1] = {
    name = "aptweaks",
    command = "/aptweaks ",
    tabID = 1,
    requires = {admin = true},
    handler = function(player, args) return APTweaksCommand(player, args) end
}
aptweaks_streams[2] = {
    name = "warp",
    command = "/warp ",
    tabID = 1,
    requires = {teleportSystem = true},
    handler = function(player, args) return WarpCommand(player, args) end
}
aptweaks_streams[3] = {
    name = "warps",
    command = "/warps ",
    tabID = 1,
    requires = {teleportSystem = true},
    handler = function(_, args) return WarpsCommand(args) end
}
aptweaks_streams[4] = {
    name = "claim",
    command = "/claim ",
    tabID = 1,
    requires = {safehouseSystem = true},
    handler = function(player, args) return ClaimCommand(player, args) end
}
aptweaks_streams[5] = {
    name = "something",
    command = "/something ",
    tabID = 1,
    requires = {admin = true},
    handler = function(_, _) return {command = "something", data = {}} end
}

-- Registrar los comandos en la clase Lua ISChat.
for _, command in ipairs(aptweaks_streams) do
    local already = false

    for _, value in ipairs(ISChat.allChatStreams) do

        if value.name == command.name then
            already = true
            break
        end
    end

    if not already then
        table.insert(ISChat.allChatStreams, command)
    end

    -- Añadir el comando a un mapa para acceso rápido.
    aptweaks_commands[command.name] = command
end

-- Valida si se cumplen los requerimientos para la ejecución de un comando.
---@param player table El IsoPlayer asociado al cliente.
---@param requires table Los requerimientos del comando.
---@return boolean isValidated Si el comando deberia poder ejecutarse.
local function checkRequires(player, requires)
    return player and player:isAlive()
       and (not requires.admin or isCoopHost() or isAdmin())
       and (not requires.teleportSystem or APTweaksVars.TeleportSystemEnabled)
       and (not requires.safehouseSystem or APTweaksVars.SafehouseSystemEnabled)
end

local function ProcessAPTweaksCommand(player, command, argsString)
    -- Separar argumentos y limpiar espacios.
    local args = {}

    for arg in string.gmatch(argsString, "%S+") do
        table.insert(args, arg)
    end

    -- Comprobar los requerimientos del comando.
    local commandData = aptweaks_commands[command]
    local isValidated = checkRequires(player, commandData.requires)

    -- Ejecutar si validado, si no devolver mensaje genérico.
    local result = (isValidated and commandData.handler(player, args))
                or {text = "Unknown command " .. command}

    ProcessCommandResult(player, result)
end

-- Interpreta si el texto ingresado en el chat es un comando de APTweaks.
-- Tenga en cuenta que esta función es llamada cada vez que se ingresa texto al chat, independientemente del contenido.
---@param player table El IsoPlayer ligado al cliente.
---@param chat table La instancia de ISChat.
---@param textEntry string El texto que se ingresó al chat.
local function APTweaksOnCommandEntered(player, chat, textEntry)

    -- Validar entrada de texto.
    if not textEntry or textEntry == "" then return end

    -- Comprobar enfriamiento por modo lento.
    if not (player:getRole():hasCapability(Capability.IgnoreChatSlowMode) and (chat.timerMessageSlowMode > getTimestampMs())) then
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

    -- Validar coincidencia y pestaña.
    if not commandString or (chat.currentTabID ~= commandData.tabID) then return end

    -- Procesar comando.
    local args = string.sub(textEntry, #commandString)

    ProcessAPTweaksCommand(player, commandData.name, args)

    chat:unfocus()
    chat.textEntry:setText("")
    doKeyPress(false)
    chat.timerTextEntry = 20
end

-- Añade a la pseudo tab complete los comandos de APTweaks.
---@param previousStreamIndex number El índice actual, antes de que la función heredada lo cambie.
---@param curTxtPanel table Idk.
local function APTweaksOnSwitchStream(previousStreamIndex, curTxtPanel)
    local actualStreamIndex = curTxtPanel.streamID
    local allChatStreams = curTxtPanel.chatStreams

    -- Si el índice actual es exactamente el siguiente esperado, no hay nada que hacer.
    if actualStreamIndex == previousStreamIndex + 1 then return end

    -- Determinar el rango máximo de índices a evaluar.
    local maxIndex = (actualStreamIndex == 1) and #allChatStreams or (actualStreamIndex - 1)

    -- Buscar coincidencia en APTweaks.
    for i = previousStreamIndex + 1, maxIndex do
        local aptweaksCommand = aptweaks_commands[allChatStreams[i].name]

        if aptweaksCommand and checkRequires(client_flags.player, aptweaksCommand.requires) then
            curTxtPanel.streamID = i
            ISChat.instance.textEntry:setText(aptweaksCommand.command)
            return
        end
    end
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

-- Debo internacionalizar los comandos, pero aún necesito una biblioteca de internacionalización para las formas plurales si
-- quero soportar más idiomas que el español e inglés.
