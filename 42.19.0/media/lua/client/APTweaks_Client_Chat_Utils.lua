-- APTweaks_Client_Chat_Utils.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

local table = table

local modID = aptweaks.modID
local aptweaks_temp = aptweaks.aptweaks_temp
local utils = aptweaks.utils

local ISChat = ISChat ---@cast ISChat.instance -? Las funciones en ISChat sólo se usan cuando el chat está inicializado.

local pairs = pairs
local print = print
local ipairs = ipairs

-- La tabla de los de los comandos de chat. Debe añadir aquí sus comandos para que este mod los maneje. 
aptweaks_temp.aptweaks_chat = aptweaks_temp.aptweaks_chat or {
    streams = {}, ---@type table<string,(APTStream|APTAdvancedStream)?> 
    index = {} ---@type string[]
}

local aptweaks_chatIndex = aptweaks_temp.aptweaks_chat.index
local aptweaks_chatStreams = aptweaks_temp.aptweaks_chat.streams


-- Instancia un ChatMessge falso para usarlo con la función `ISChat.addLineInChat`.
---@param size string El tamaño del texto. Puede ser "small", "medium", y "large".
---@param text string El texto del mensaje.
---@param author string El autor del mensaje.
---@param isShowAuthor boolean Si debe mostrarse el autor como un prefijo en el texto.
---@return APTChatMessage message Una tabla que simula ser una instancia de ChatMessage, con algunos de sus métodos.
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

-- Añade un nuevo mensaje al chat del juego.
---@param text string El texto del mensaje.
---@param author string El autor del mensaje.
---@param isShowAuthor boolean Si se mostrará el autor en el mensaje.
---@param tabID integer La ID de la pestaña a la que se añadirá el mensaje.
function utils.addMessage(text, author, isShowAuthor, tabID)
    ISChat.addLineInChat(getFakeChatMessage(
        ISChat.instance.chatFont, text, author, isShowAuthor)--[[@cast +ChatMessage, -APTChatMessage]],
        tabID
    ) -- Forzando un APTChatMessage en el lugar de un ChatMessage.
end

-- Añade comandos a la API de comandos de APTweaks.
---@param provider string
---@param commands (APTCommand|APTAdvancedCommand)[]
---@param checker fun(player:IsoPlayer, requires:table<string,boolean?>): boolean
function utils.addCommands(provider, commands, checker)

    for i, command in ipairs(commands) do
        local shortCommandString = command.shortCommand
        local commandString = command.command
        local name = command.name
        local exist ---@type boolean

        -- Buscar si name, command, o shortcommand existen.
        for _, value in pairs(aptweaks_chatStreams) do
            local shortCommand = value.shortCommand
            
            if name == value.name
                or value.command == commandString
                or shortCommand and shortCommand == shortCommandString
            then
                exist = true
                break
            end
        end

        -- Si no existe, convertir en stream, y añadirlo al mapa de streams.
        if not exist then
            table.insert(aptweaks_chatIndex, name) -- Indexando para mantener el órden.
            
            ---@cast command +APTAdvancedStream, +APTStream, -APTAdvancedCommand, -APTCommand
            command.checker = checker
            command.provider = provider
            aptweaks_chatStreams[name] = command

        else
            print("[APTWeaks (" .. provider .. ")] WARN: Command already exist: " .. name)
        end
    end
end

-- Busca coincidencias entre dos tablas de comandos, y llama a un callback por cada elemento que no coincida.
---@param commands table<string,APTCommand?> La tabla de comandos.
---@param iterator function El iterador que se usará para buscar coincidencias.
---@param callback fun(name:string, command:APTCommand) Lo que se hará con cada elemento que no esté en la lista.
function utils.extendStreamsList(commands, iterator, callback)

    for name, command in pairs(commands) do
        local exist ---@type boolean

        -- Buscar si name, command, o shortcommand existen.
        for _, value in iterator do
            local shortCommand = value.shortCommand
            
            if name == value.name or value.command == command.command or shortCommand and shortCommand == command.shortCommand then
                exist = true
                break
            end
        end

        -- Si no existe llamar al callback.
        if not exist then
            callback(name, command)

        else
            print("[APTWeaks (" .. command.provider .. ")] WARN: Command already exist: " .. name)
        end
    end
end

-- Registra comandos para que sean manejados por la API de comandos de APTweaks.
---@param provider string El módulo que provee los comandos.
---@param commands (APTCommand|APTAdvancedCommand)[] La tabla con los comandos.
---@param checker fun(player:IsoPlayer, requires:table<string,boolean?>): boolean La función para verificar los requerimientos del comando.
function utils.addChatCommands(provider, commands, checker)
    extendCommandsList(commands, pairs(aptweaks_streams), addCommand)
end
