-- APTweaks_Client_chatCommands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

local chatCommands, aptweaks = {}, require("APTweaks")

local getText = aptweaks.getText

local aptweaks_temp = aptweaks.aptweaks_temp
local client_flags = aptweaks.client_flags

local showWarps = aptweaks.showWarps

aptweaks_temp.safezone = aptweaks_temp.safezone or {}

-- El comando `/aptweaks warp add|remove`.
---@param player table Un IsoPlayer.
---@param action string La acción que el comando realizará.
---@param warp boolean El nombre del warp sobre el que se realizará la acción.
---@return table|nil result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.APTweaksWarpCommand(player, action, warp)

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
function chatCommands.APTweaksSafezoneCommand(player, action)

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
function chatCommands.WarpCommand(player, args)
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

-- El comando `/warps`.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.WarpsCommand()
    local warps = aptweaks.aptweaks_data.warps

    return {text = getText("IGUI_APTweaks_AviableWarps", showWarps(warps))}
end

-- El comando `/claim`.
---@param player table Un IsoPlayer.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.ClaimCommand(player)
    local x, y = math.floor(player:getX()), math.floor(player:getY())

    return {command = "SafezoneCommand", data = {action = "claim", x = x, y = y}}
end

return chatCommands
