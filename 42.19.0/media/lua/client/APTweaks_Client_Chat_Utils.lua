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

local addCommandsTasks = {
    APTChat = {
        iterator = function (commands)
            return ipairs(commands)
        end,
        iteratorExternal = pairs(aptweaks_chatStreams), 
        callback = function (name, command, checker, provider)
            table.insert(aptweaks_chatIndex, name) -- Indexando para mantener el órden.

            ---@cast command +APTAdvancedStream, +APTStream, -APTAdvancedCommand, -APTCommand
            command.checker = checker
            command.provider = provider
            aptweaks_chatStreams[name] = command
        end
    },
    ISChat = {
        iterator = function (commands)
            return pairs(commands)
        end,
        itetatorExternal = ipairs(ISChat.allChatStreams),
        callback = function (name, command, checker, provider)
            -- FALTA EL CALLBACK.
        end
    }
}

-- Busca coincidencias entre dos tablas de comandos, y llama a un callback por cada elemento que no coincida.
---@param commands (APTCommand|APTAdvancedCommand)[]|table<string,(APTStream|APTAdvancedStream)?> La tabla de comandos.
---@param task table
---@param data {provider:string,checker:fun(player:IsoPlayer,requires:table<string,boolean?>):boolean}
local function extendCommandsList(commands, task, data)
    local provi = task.provider
    local check = task.checker

    for i, command in task.iterator do
        local shortCommandString = command.shortCommand
        local commandString = command.command
        local name = command.name
        local exist ---@type boolean

        -- Buscar si name, command, o shortcommand existen.
        for _, value in task.iteratorExternal do
            local shortCommand = value.shortCommand

            if name == value.name
                or value.command == commandString
                or shortCommand and shortCommand == shortCommandString
            then
                exist = true
                break
            end
        end

        provi = provi or command.provider

        -- Si no existe llamar al callback.
        if not exist then
            task.callback(name, command, check or command.checker, provi)

        else
            print("[APTWeaks (" .. provi .. ")] WARN: Command already exist: " .. name)
        end
    end
end

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
---@param provider string El mod que provee los comandos.
---@param checker fun(player:IsoPlayer,requires:table<string,boolean?>):boolean La función que verifica los requerimientos de los comandos.s
---@param commands (APTCommand|APTAdvancedCommand)[] La lista de los comandos que se añadirán.
function utils.addChatCommands(provider, commands, checker)
    extendCommandsList(commands, addCommandsTasks.APTChat, {provider = provider, checker = checker})
end
