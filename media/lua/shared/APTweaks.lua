-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo actua como un contenedor de datos. No lo recargue.

local aptweaks = {}
    -- La ID del mod.
    aptweaks.modID = "com.github.abrahampicos.aptweaks"
    -- El mapa de datos de APTweaks.
    aptweaks.aptweaks_data = {}
    -- Variables para el jugador controladas por el evento tick; Son útiles para el comando warp y el sistema AFK. 
    aptweaks.player_flags = {}
    -- Referencias a Funciones incorporadas en Lua.
    aptweaks.aptweaks_commands = {}
    -- Funciones heredadas.
    aptweaks.legacy_functions = {}

    -- Referencias a Funciones Java de Proyect Zomboid.

    aptweaks.Events = Events
    aptweaks.ModData = ModData
    aptweaks.getCore = getCore
    aptweaks.getText = getText
    aptweaks.writeLog = writeLog
    aptweaks.isClient = isClient
    aptweaks.isServer = isServer
    aptweaks.getPlayer = getPlayer
    aptweaks.SafeHouse = SafeHouse
    aptweaks.doKeyPress = doKeyPress
    aptweaks.triggerEvent = triggerEvent
    aptweaks.getServerOptions = getServerOptions
    aptweaks.ZombRandBetween = ZombRandBetween
    aptweaks.sendClientCommand = sendClientCommand
    aptweaks.sendServerCommand = sendServerCommand
    aptweaks.getConnectedPlayers = getConnectedPlayers
    aptweaks.SendCommandToServer = SendCommandToServer
    aptweaks.alreadyHaveSafehouse = alreadyHaveSafehouse
    aptweaks.getSteamIDFromUsername = getSteamIDFromUsername

    -- Referencias a variables globales de Proyect Zomboid.

    aptweaks.luautils = luautils
    aptweaks.APTweaksVars = SandboxVars.APTweaks
    aptweaks.GameTimeInstance = GameTime.getInstance()

local isClient = aptweaks.isClient
local isServer = aptweaks.isServer
local SafeHouse = aptweaks.SafeHouse
local sendClientCommand = aptweaks.sendClientCommand
local sendServerCommand = aptweaks.sendServerCommand

local modID = aptweaks.modID

-- Crea un ChatMessge falso para usarlo con la función `ISChat.addLineInChat`.
---@param size string El tamaño del texto. Puede cambiarse luego con setSize(). Puede ser "small", "medium", y "large".
---@param text string El texto del mensaje.
---@param author string El nombre del autor del mensaje.
---@param isShowAuthor any Si debe mostrarse el nombre del autor en el mensaje: Ejem: "[AbrahamPicos]: Este es el mensaje.".
---@return table table Una tabla que simula ser un objeto ChatMessage.
function aptweaks.CreateFakeChatMessage(size, text, author, isShowAuthor)
    return {
        modID = modID,
        getTextWithPrefix = function(self)
            local prefix = "<RGB:0.0,0.5,1.0> " .. "<SIZE:" .. size .. "> "
            if isShowAuthor then
                prefix = prefix .. "[" .. author .. "]: "
            end
            return prefix .. text
        end,
        isServerAlert = function(self) return false end,
        getAuthor = function(self) return author end,
        isShowAuthor = function(self) return isShowAuthor end,
        getText = function(self) return text end,
        setSize = function (self, newSize)
            size = newSize
        end
    }
end

-- Comprueba si hay una safehouse en un área.
---@param x1 integer Abscisa del vértice superior izquierdo.
---@param y1 integer Ordenada del vértice superior izquierdo.
---@param x2 integer Abscisa del vértice inferior derecho.
---@param y2 integer Ordenada del vértice inferior derecho.
---@return boolean
function aptweaks.IsSafeHouse(x1, y1, x2, y2)
    return SafeHouse.getSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1) ~= nil
end

-- Procesa la respuesta de todos los comandos de APTweaks cuando son usados a travez de APTweaks.
--- @param player table Un IsoPlayer.
--- @param result table|nil La tabla con el resultado del comando.
function aptweaks.ProcessCommandResult(player, result)

    if result then
        local text = result.text
        local data = result.data
        local commandSend = result.command
        local server, client = isServer(), isClient()

        if not commandSend and server then
            commandSend = "messageCommand"
            data = result

        elseif commandSend then

            if client then
                sendClientCommand(player, modID, commandSend, data)

            elseif server then
                sendServerCommand(player, modID, commandSend, data)
            end
        end

        if text and client then
            aptweaks.ISChat.addLineInChat(aptweaks.CreateFakeChatMessage(aptweaks.ISChat.instance.chatFont, text, "APTweaks", false), 0)
        end
    end
end
