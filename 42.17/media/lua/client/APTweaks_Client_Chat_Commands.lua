-- APTweaks_Client_chatCommands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

-- Puede usar este archivo como un ejemplo de cómo usar la API de comandos de chat de APTweaks.

local aptweaks = require("APTweaks")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local client_flags = aptweaks.client_flags
local aptweaks_temp = aptweaks.aptweaks_temp

local isAdmin = aptweaks.isAdmin
local getText = aptweaks.getText
local isCoopHost = aptweaks.isCoopHost

local extendStreamsList = aptweaks.extendStreamsList

aptweaks_temp.safezone = aptweaks_temp.safezone or {}

local aptweaks_streams = aptweaks_temp.aptweaks_streams

-- Solicita al servidor que elimine todos los datos del mod.
local function APTweaksCleardataCommand()
    return {command = "ClearDataCommand", data = {}}
end

-- El comando `/aptweaks warp add|remove`.
---@param player table Un IsoPlayer.
---@param action string La acción que el comando realizará.
---@param warp boolean El nombre del warp sobre el que se realizará la acción.
---@return table|nil result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function APTweaksWarpCommand(player, action, warp)

    if action ~= "add" and action ~= "remove" then return nil end

    local data = {action = action, name = warp}

    if action == "add" then
        data.location = {x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ())}
    end

    return {command = "WarpCommand", data = data}
end

-- El comando `/aptweaks safezone add|remove`.
---@param player table Un IsoPlayer.
---@param action string La acción que el comando realizará.
---@return table|nil result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function APTweaksSafezoneCommand(player, action)

    if action ~= "pos1" and action ~= "pos2" and action ~= "add" and action ~= "remove" and action ~= "prune" then return nil end

    local data = {action = action}

    if action == "add" then
        local pos1, pos2 = aptweaks_temp.safezone.pos1, aptweaks_temp.safezone.pos2

        if not (pos1 and pos2) then
            return {text = getText("IGUI_APTweaks_Chat_VertexNeeded")}
        end

        data.x1, data.y1, data.x2, data.y2 = pos1.x, pos1.y, pos2.x, pos2.y

    else
        local x, y = math.floor(player:getX()), math.floor(player:getY())

        if action == "pos1" or action == "pos2" then
            aptweaks_temp.safezone[action] = {x = x, y = y}

            return {text = getText("IGUI_APTweaks_Chat_VertexDefined", action, x, y)}

        elseif action == "remove" then
            data.x, data.y = x, y
        end
    end

    return {command = "SafezoneCommand", data = data}
end

-- El comando `/warp`. 
---@param player table Un IsoPlayer.
---@param args table La lista de argumentos.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function WarpCommand(player, args)
    local warp = args[1] -- El warp que el jugador ingresó, tal cual como lo escribió.

    if player:getVehicle() then
        return {text = getText("IGUI_APTweaks_Chat_RidingExecutionForbidden")}
    end

    if client_flags.isMoving then
        return {text = getText("IGUI_APTweaks_Chat_MovingExecutionForbidden")}
    end

    if client_flags.teleporting then
        return {text = getText("IGUI_APTweaks_Chat_AlreadyExecuting")}
    end

    return {command = "TeleportCommand", data = {status = "begins", name = warp}}
end

-- Solicita al servidr la lista de warps.
local function WarpsCommand()
    return {command = "WarpsCommand", data = {}}
end

-- El comando `/claim`.
---@param player table Un IsoPlayer.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function ClaimCommand(player)
    local x, y = math.floor(player:getX()), math.floor(player:getY())

    return {command = "SafezoneCommand", data = {action = "claim", x = x, y = y}}
end

-- Valida si se cumplen los requerimientos para la ejecución de un comando de chat de APTweaks.
---@param player table El IsoPlayer asociado al cliente.
---@param requires table La tabla con los requerimientos del comando.
---@return boolean canExecute Si el comando pasó la validacioń.
local function canExecute(player, requires)

    -- Validar personaje, permisos, y disponibilidad de sistemas.
    if not player:isAlive() then return false end

    if requires.admin and not (isCoopHost() or isAdmin()) then return false end

    if requires.teleportSystem and not APTweaksVars.TeleportSystemEnabled then return false end

    if requires.safehouseSystem and not APTweaksVars.SafehouseSystemEnabled then return false end

    return true
end

-- Los comandos de chat propios de APTweaks.
local aptweaks_self_streams = {
    {
        name = "aptweaks",
        provider = modID,
        command = "/aptweaks ",
        tabID = 1,
        argc = {min = 1, max = 3},
        usage = "IGUI_APTweaks_MainCommandUsage",
        requires = {
            admin = true,
            checker = canExecute
        },
        subcommands = {
            cleardata = {
                argc = {max = 1},
                usage = "IGUI_APTweaks_MainCommandUsage",
                handler = function(_, _) return APTweaksCleardataCommand() end
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
        provider = modID,
        command = "/warp ",
        tabID = 1,
        argc = {min = 1, max =1},
        usage = "IGUI_APTweaks_WarpCommandUsage",
        requires = {
            teleportSystem = true,
            checker = canExecute
        },
        handler = function(player, args) return WarpCommand(player, args) end
    }, {
        name = "warps",
        provider = modID,
        command = "/warps ",
        tabID = 1,
        usage = "IGUI_APTweaks_WarpsCommandUsage",
        requires = {
            teleportSystem = true,
            checker = canExecute
        },
        handler = function(_, _) return WarpsCommand() end
    }, {
        name = "claim",
        provider = modID,
        command = "/claim ",
        tabID = 1,
        usage = "IGUI_APTweaks_ClaimCommandUsage",
        requires = {
            safehouseSystem = true,
            checker = canExecute
        },
        handler = function(player, _) return ClaimCommand(player) end
    }, {
        name = "something",
        provider = modID,
        command = "/something ",
        tabID = 1,
        usage = "IGUI_APTweaks_SomethingCommandUsage",
        requires = {
            admin = true,
            checker = canExecute
        },
        handler = function(_, _) return {command = "Something", data = {}} end
    }
}

-- Registrar los comandos de chat propios de APTweaks en la tabla de streams de la API de comandos de chat de APTweaks.
extendStreamsList(aptweaks_streams, aptweaks_self_streams, nil)
