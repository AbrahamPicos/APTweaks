-- APTweaks_Client_Chat.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo sobrescribe múltiples funciones del juego base. No lo recargue si hay otros mods.

local aptweaks, chatCommands = require("APTweaks"), require("APTweaks_Client_Chat_Commands")

aptweaks.ISChat = aptweaks.ISChat or ISChat -- El módulo APTweaks.lua está en "shared", donde no está disponible ISChat.

local modID = aptweaks.modID
local client_flags = aptweaks.client_flags
local legacy_functions = aptweaks.legacy_functions

local WarpCommand = chatCommands.WarpCommand
local WarpsCommand = chatCommands.WarpsCommand
local ClaimCommand = chatCommands.ClaimCommand
local APTweaksSafezoneCommand = chatCommands.APTweaksSafezoneCommand
local APTweaksWarpCommand = chatCommands.APTweaksWarpCommand
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

-- Valida si se cumplen los requerimientos para la ejecución de un comando de APTweaks.
-- Se usa un mensaje genéroco para simular que el comandono existe.
---@param player table El IsoPlayer asociado al cliente.
---@param commandData table
---@return table|nil result Devuelve un mensaje si no pasó la validación, de lo contrario no devuelve nada.
local function checkCommandFromAPTwekas(player, commandData)
    local requires = commandData.requires or {}

    -- Validar personaje, permisos, y disponibilidad de sistemas.
    return (not player:isAlive()
        or (requires.admin and not (isCoopHost() or isAdmin()))
        or (requires.teleportSystem and not APTweaksVars.TeleportSystemEnabled)
        or (requires.safehouseSystem and not APTweaksVars.SafehouseSystemEnabled))
        and ("Unknown command " .. commandData.name) or nil
end

local aptweaks_commands = {}
local aptweaks_streams = {

    {
        name = "aptweaks",
        command = "/aptweaks ",
        tabID = 1,
        argc = {min = 1, max = 3},
        usage = "IGUI_APTweaks_MainCommandUsage",
        requires = {admin = true},
        subcommands = {
            cleardata = {
                argc = {max = 1},
                usage = "IGUI_APTweaks_MainCommandUsage",
                handler = function(_, _) return {command = "ClearData", data = {}} end
            },
            safezone = {
                argc = {max = 2},
                usage = "IGUI_APTweaks_MainCommandUsage_Safezone",
                handler = function(player, args) return APTweaksSafezoneCommand(player, args[2]) end
            },
            warp = {
                argc = {max = 3},
                usage = "IGUI_APTweaks_MainCommandUsage_Warp",
                handler = function(player, args) return APTweaksWarpCommand(player, args[2], args[3]) end
            }}
    }, {
        name = "warp",
        command = "/warp ",
        tabID = 1,
        argc = {min = 1, max =1},
        usage = "IGUI_APTweaks_WarpCommandUsage",
        requires = {
            teleportSystem = true,
            checker = function (player, commandData) checkCommandFromAPTwekas(player, commandData) end
        },
        handler = function(player, args) return WarpCommand(player, args) end
    }, {
        name = "warps",
        command = "/warps ",
        tabID = 1,
        usage = "IGUI_APTweaks_WarpsCommandUsage",
        requires = {
            teleportSystem = true,
            checker = function (player, commandData) checkCommandFromAPTwekas(player, commandData) end
        },
        handler = function(_, _) return WarpsCommand() end
    }, {
        name = "claim",
        command = "/claim ",
        tabID = 1,
        usage = "IGUI_APTweaks_ClaimCommandUsage",
        requires = {
            safehouseSystem = true,
            checker = function (player, commandData) checkCommandFromAPTwekas(player, commandData) end
        },
        handler = function(player, _) return ClaimCommand(player) end
    }, {
        name = "something",
        command = "/something ",
        tabID = 1,
        usage = "IGUI_APTweaks_SomethingCommandUsage",
        requires = {admin = true},
        handler = function(_, _) return {command = "something", data = {}} end
    }
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

-- Valida si se cumplen los requerimientos para la ejecución de un comando de APTweaks.
-- Se usa un mensaje genéroco para simular que el comandono existe.
---@param player table El IsoPlayer asociado al cliente.
---@param commandData table
---@return table|nil result Devuelve un mensaje si no pasó la validación, de lo contrario no devuelve nada.
local function  checkAPTweaksCommand(player, commandData)
    local requires = commandData.requires or {}

    -- Validar personaje, permisos, y disponibilidad de sistemas.
    return (not player:isAlive()
        or (requires.admin and not (isCoopHost() or isAdmin()))
        or (requires.teleportSystem and not APTweaksVars.TeleportSystemEnabled)
        or (requires.safehouseSystem and not APTweaksVars.SafehouseSystemEnabled))
        and ("Unknown command " .. commandData.name) or nil
end

local function checkCommandRequires(player, command, args)
    -- Comprobar los requerimientos específicos del comando.
    local commandData = aptweaks_commands[command] -- Esto nunca es nil.
    local failMessage = getFailMessage(player, commandData)

    if failMessage then return failMessage end

    -- Validar si cumple con el número mínimo de argumentos.
    local argsRange = commandData.argc or {min = 0, max = 0}
    local argc = #args

    if argc < argsRange.min then
        return {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText(commandData.usage))}
    end

    -- Comprobar si debe haber un subcomando.
    local subcommands = commandData.subcommands

    if subcommands then
        local subcommandData = commandData.subcommands[args[1]]

        -- Si el subcomando no es válido, terminar.
        if not subcommandData then
            return {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText(commandData.usage))}
        end

        commandData = subcommandData
    end

    if argc > argsRange.max then
        return {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText(commandData.usage))}
    end

    -- Obtener handler
    local handler = commandData.handler
end

local function ProcessAPTweaksCommand(player, command, argsString)
    -- Separar argumentos y limpiar espacios.
    local args = {}

    for arg in string.gmatch(argsString, "%S+") do
        table.insert(args, arg)
    end

    checkCommandRequires(player, command, args)

    -- Comprobar los requerimientos específicos del comando.
    local commandData = aptweaks_commands[command] -- Esto nunca es nil.
    local result = getFailMessage(player, commandData)

    if not result then
        -- Validar si cumple con el número mínimo de argumentos.
        local argsRange = commandData.argc or {min = 0, max = 0}
        local argc = #args

        if argc < argsRange.min then
            result = {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText(commandData.usage))}
        end

        -- Comprobar si debe haber un subcomando.
        local subcommands = commandData.subcommands

        if subcommands then
            local subcommandData = commandData.subcommands[args[1]]

            -- Si el subcomando no es válido, terminar.
            if not subcommandData then
                result = {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText(commandData.usage))}
            end

            commandData = subcommandData
        end

        elseif argc > argsRange.max then
            result = {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText(commandData.usage))}
        end

        -- Obtener handler
        local handler = commandData.handler
    end
end
    -- Validar argumentos.
    local argsRange = commandData.argc or {min = 0, max = 0}
    local argc = #args

    -- Validar argumentos.
    if argc < argsRange.min then
        result = {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText(commandData.usage))}

    elseif argc > argsRange.max then
        result = {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText(commandData.usage))}
    end

    -- Comprobar si hay un subcomando y obtener handler.
    local subcommandData = commandData.subcommands[args[1]]
    local handler = commandData.handler

    if not handler then

        if not subcommandData then
            result = {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText(subcommandData.usage))}
        end

        handler = subcommandData.handler
    end



    if not handler then
        local subcommandData = commandData.subcommands[args[1]]

        -- Si el subcomando no es válido, terminar.
        if not subcommandData then
            result = {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText(subcommandData.usage))}
        end

        -- Comprobar si hay suficientes argumentos para el subcomando.
        if argc ~= subcommandData.argc then
            result = {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText(subcommandData.usage))}
        end

        handler = subcommandData.handler
    end

    -- Validar requerimientos específicos del proveedor y manejar.
    if not result then
        result = getFailMessage(player, commandData) or handler(player, args)
        or {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText(subcommandData.usage))}
    end

    -- Procesar resultado
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

        if aptweaksCommand and not getFailMessage(client_flags.player, aptweaksCommand) then
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
