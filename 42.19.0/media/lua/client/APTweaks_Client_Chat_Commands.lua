-- APTweaks_Client_Chat_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

-- Puede usar este archivo como un ejemplo de cómo usar la API de comandos de chat de APTweaks.

local aptweaks = require("APTweaks")

local math = math

local modID = aptweaks.modID
local utils = aptweaks.utils
local APTweaksVars = aptweaks.APTweaksVars
local aptweaks_temp = aptweaks.aptweaks_temp

local getText = getText

local safezone = {} ---@type {pos1:{x:number,y:number}?,pos2:{x:number,y:number}?}
local client_flags = aptweaks_temp.client_flags

-- Solicita al servidor que elimine todos los datos del mod.
---@return APTResult result
local function APTweaksCleardataCommand()
    return {command = "ClearDataCommand", data = {}}
end

-- El comando `/aptweaks warp add|remove`.
---@param player IsoPlayer Un IsoPlayer.
---@param action "add"|"remove" La acción que el comando realizará.
---@param warp string El nombre del warp sobre el que se realizará la acción.
---@return APTResult result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function APTweaksWarpCommand(player, action, warp)
    local data = {name = warp, action = action}

    if action == "add" then
        data.location = {x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ())}
    end

    return {command = "WarpCommand", data = data}
end

-- El comando `/aptweaks safezone add|remove`.
---@param player IsoPlayer El jugador asociado a este cliente.
---@param action "add"|"remove"|"pos1"|"pos2" La acción que el comando realizará.
---@return APTResult result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function APTweaksSafezoneCommand(player, action)
    local data = {action = action}

    if action == "add" then
        local pos1, pos2 = safezone.pos1, safezone.pos2

        if not pos1 or not pos2 then
            return {text = getText("IGUI_APTweaks_Chat_VertexNeeded")}
        end

        data.x1, data.y1, data.x2, data.y2 = pos1.x, pos1.y, pos2.x, pos2.y

    else
        local x, y = math.floor(player:getX()), math.floor(player:getY())

        if action == "pos1" or action == "pos2" then
            safezone[action] = {x = x, y = y}

            return {text = getText("IGUI_APTweaks_Chat_VertexDefined", action, x, y)}

        else
            data.x, data.y = x, y
        end
    end

    return {command = "SafezoneCommand", data = data}
end

-- El comando `/warp`. 
---@param player IsoPlayer Un IsoPlayer.
---@param warp string El warp que el jugador ingresó, tal cual como lo escribió.
---@return APTResult result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function WarpCommand(player, warp)

    if player:isSeatedInVehicle() then
        return {text = getText("IGUI_APTweaks_Chat_RidingExecutionForbidden")}
    end

    if client_flags.isMoving then
        return {text = getText("IGUI_APTweaks_Chat_MovingExecutionForbidden")}
    end

    if client_flags.teleport then
        return {text = getText("IGUI_APTweaks_Chat_AlreadyExecuting")}
    end

    return {command = "TeleportCommand", data = {action = "request", name = warp}}
end

-- Solicita al servidor la lista de warps.
---@return APTResult result
local function WarpsCommand()
    return {command = "WarpsCommand", data = {}}
end

-- El comando `/claim`.
---@param player IsoPlayer Un IsoPlayer.
---@return APTResult result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function ClaimCommand(player)
    local x, y = math.floor(player:getX()), math.floor(player:getY())

    return {command = "SafezoneCommand", data = {action = "claim", x = x, y = y}}
end

-- Valida si se cumplen los requerimientos para la ejecución de un comando de chat de APTweaks.
---@param player IsoPlayer El IsoPlayer asociado al cliente.
---@param requires table<string,boolean?> La tabla con los requerimientos del comando.
---@return boolean canExec Si el comando pasó la validación.
local function customChecker(player, requires)

    if requires.teleportSystem and not APTweaksVars.TeleportSystemEnabled then return false end

    if requires.safehouseSystem and not APTweaksVars.SafehouseSystemEnabled then return false end

    return true
end

-- Registrar los comandos de chat propios de APTweaks, en la tabla de streams de la API de comandos de chat de APTweaks.
-- Siempre que estén debidamente registrados en la tabla, los argumentos de un comando no pueden ser nil.
utils.addChatCommands(modID, {
    {
        name = "aptweaks",
        command = "/aptweaks ",
        argc = {min = 1, max = 3},
        usage = "IGUI_APTweaks_MainCommandUsage",
        requires = {
            tabID = 1,
            admin = true,
            playerAlive = true
        },
        subcommands = {
            cleardata = {
                argc = {max = 1},
                usage = "IGUI_APTweaks_MainCommandUsage",
                handler = function(_, _) 
                    return APTweaksCleardataCommand()
                end
            },
            safezone = {
                argc = {max = 2},
                usage = "IGUI_APTweaks_MainCommandUsage_Safezone",
                actions = {"pos1", "pos2", "add", "remove", "prune"},
                handler = function(player, args)
                    return APTweaksSafezoneCommand(player, args[2]--[[@cast "add"|"remove"|"pos1"|"pos2"]])
                end
            },
            warp = {
                argc = {max = 3},
                usage = "IGUI_APTweaks_MainCommandUsage_Warp",
                actions = {"add", "remove"},
                handler = function(player, args)
                    return APTweaksWarpCommand(player, args[2]--[[@cast "add"|"remove"]], args[3]--[[@cast -?]])
                end
            }
        }
    }, {
        name = "warp",
        command = "/warp ",
        argc = {min = 1, max =1},
        usage = "IGUI_APTweaks_WarpCommandUsage",
        requires = {
            tabID = 1,
            playerAlive = true
        },
        customRequires = {
            teleportSystem = true
        },
        handler = function(player, args)
            return WarpCommand(player, args[1]--[[@cast -?]])
        end
    }, {
        name = "warps",
        command = "/warps ",
        tabID = 1,
        usage = "IGUI_APTweaks_WarpsCommandUsage",
        customRequires = {
            tabID = 1,
            teleportSystem = true
        },
        handler = function(_, _)
            return WarpsCommand()
        end
    }, {
        name = "claim",
        command = "/claim ",
        usage = "IGUI_APTweaks_ClaimCommandUsage",
        requires = {
            tabID = 1,
            playerAlive = true
        },
        customRequires = {
            safehouseSystem = true,
        },
        handler = function(player, _)
            return ClaimCommand(player)
        end
    }, {
        name= "something",
        command = "/something ",
        usage = "IGUI_APTweaks_SomethingCommandUsage",
        requires = {
            tabID = 1,
            admin = true
        },
        handler = function(_, _)
            return {command = "Something", data = {}}
        end
    }
}, customChecker)
