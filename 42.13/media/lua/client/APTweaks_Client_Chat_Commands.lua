-- APTweaks_Client_chatCommands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

local chatCommands, aptweaks = {}, require("APTweaks")

local getText = aptweaks.getText

local aptweaks_temp = aptweaks.aptweaks_temp
local client_flags = aptweaks.client_flags

aptweaks_temp.safezone = {}

-- Devuélve la lista de warps disponibles en forma de string.
---@param warps table El mapa con los warps existentes.
---@return string aviableWarps Un string con saltos de línea compatible con el chat de Project Zomboid.
local function showWarps(warps)
    local aviableWarps = "<LINE>"
    local index = 0

    for warp, _ in pairs(warps) do
        index = index + 1
        aviableWarps = aviableWarps .. "* " .. tostring(warp)

        if index < #warps then
            aviableWarps = aviableWarps .. "<LINE>"
        end
    end

    return aviableWarps
end

-- El comando `/aptweaks warp add|remove`.
---@param player table Un IsoPlayer.
---@param action string La acción que el comando realizará.
---@param warp boolean El nombre del warp sobre el que se realizará la acción.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.APTweaksWarpCommand(player, action, warp)
    local data

    if action == "add" then
        local location = {x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ())}

        data = {action = action, name = warp, location = location}

    elseif action == "remove" then
        data = {action = action, name = warp}

    else
        return {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText("IGUI_APTweaks_MainCommandUsage_Warp"))}
    end

    return {command = "WarpCommand", data = data}
end

-- El comando `/aptweaks safezone add|remove`.
---@param player table Un IsoPlayer.
---@param action string La acción que el comando realizará.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.APTweaksSafezoneCommand(player, action)
    local data

    if action == "add" then
        local pos1, pos2 = aptweaks_temp.safezone.pos1, aptweaks_temp.safezone.pos2

        if not (pos1 and pos2) then
            return {text = getText("IGUI_APTweaks_Chat_VertexNeeded")}
        end

        data = {action = action, x1 = pos1.x, y1 = pos1.y, x2 = pos2.x, y2 = pos2.y}

    elseif action == "prune" then
        data = {action = action}
    end

    local x, y = math.floor(player:getX()), math.floor(player:getY())

    if action == "pos1" or action == "pos2" then
        aptweaks_temp.safezone[action] = {x = x, y = y}

        return {text = string.format(getText("IGUI_APTweaks_Chat_VertexDefined"), action, x, y)}

    elseif action == "remove" then
        data = {action = action, x = x, y = y}

    else
        return {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText("IGUI_APTweaks_MainCommandUsage_Safezone"))}
    end

    return {command = "SafezoneCommand", data = data}
end

-- El comando `/warp`. 
---@param player table Un IsoPlayer.
---@param args table La lista de argumentos.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.WarpCommand(player, args)
    local warp = args[1] -- El warp que el jugador ingresó, tal cual como lo escribió.
    local warps = aptweaks.aptweaks_data.warps
    local location = warps[warp]

    if not location then
        return {text = string.format(getText("IGUI_APTweaks_Chat_MissingWarp"), warp, showWarps(warps))}
    end

    if player:getVehicle() then
        return {text = getText("IGUI_APTweaks_Chat_RidingExecutionForbidden")}
    end

    if client_flags.isMoving then
        return {text = getText("IGUI_APTweaks_Chat_MovingExecutionForbidden")}
    end

    if client_flags.isTeleporting or client_flags.TeleportRequest then
        return {text = getText("IGUI_APTweaks_Chat_AlreadyExecuting")}
    end

    client_flags.isTeleporting = true
    client_flags.teleportLocation = {x= location.x, y = location.y, z = location.z, name = warp}

    return {text = string.format(getText("IGUI_APTweaks_Chat_TeleportBegins"), warp)}
    --return {text = string.format(getText("IGUI_APTweaks_TeleportCooldown"), client_flags.warpCommandCooldownSecondsLeft)}
end

-- El comando `/warps`.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.WarpsCommand()
    local warps = aptweaks.aptweaks_data.warps

    return {text = string.format(getText("IGUI_APTweaks_AviableWarps"), showWarps(warps))}
end

-- El comando `/claim`.
---@param player table Un IsoPlayer.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function chatCommands.ClaimCommand(player)
    local x, y = math.floor(player:getX()), math.floor(player:getY())

    return {command = "SafezoneCommand", data = {action = "claim", x = x, y = y}}
end

return chatCommands
