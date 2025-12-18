-- APTweaks_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

local commands, aptweaks = {}, require("APTweaks")

local getText = aptweaks.getText

local aptweaks_temp = aptweaks.aptweaks_temp
local client_flags = aptweaks.client_flags

aptweaks_temp.safezone = {}

-- Devuélve la lista de warps disponibles en forma de string, en un formato compatible con el español e inglés.
-- Probablemente deba remover esto para evitar tener que hacer una biblioteca de internacionalización.
---@return string aviableWarps `aviableWarps = warp1, warp2, warp3, and warp4`.
local function ShowWarps()
    local aptweaks_data = aptweaks.aptweaks_data
    local aviableWarps = ""
    local totalElements = 0
    local processedElements = 0

    for _ in pairs(aptweaks_data.warps) do
        totalElements = totalElements + 1
    end

    for warp, _ in pairs(aptweaks_data.warps) do
        processedElements = processedElements + 1

        if aviableWarps == "" then
            aviableWarps = tostring(warp)

        elseif processedElements == totalElements then
            aviableWarps = aviableWarps .. getText("IGUI_APTweaks_ListSeparator_Final") .. tostring(warp)

        else
            aviableWarps = aviableWarps .. getText("IGUI_APTweaks_ListSeparator") .. tostring(warp)
        end
    end

    return aviableWarps
end

-- El comando `/aptweaks warp add|remove`.
---@param player table Un IsoPlayer.
---@param action string La acción que el comando realizará.
---@param warp boolean El nombre del warp sobre el que se realizará la acción.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
local function APTweaksWarpCommand(player, action, warp)
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
local function APTweaksSafezoneCommand(player, action)
    local x, y = math.floor(player:getX()), math.floor(player:getY())
    local data

    if action == "pos1" or action == "pos2" then
        aptweaks_temp.safezone[action] = {x = x, y = y}

        return {text = string.format(getText("IGUI_APTweaks_Chat_VertexDefined"), action, x, y)}

    elseif action == "add" then
        local pos1, pos2 = aptweaks_temp.safezone.pos1, aptweaks_temp.safezone.pos2

        if not (pos1 and pos2) then
            return {text = getText("IGUI_APTweaks_Chat_VertexNeeded")}
        end

        data = {action = action, x1 = pos1.x, y1 = pos1.y, x2 = pos2.x, y2 = pos2.y}

    elseif action == "remove" then
        data = {action = action, x = x, y = y}

    elseif action == "prune" then
        data = {action = action}

    else
        return {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText("IGUI_APTweaks_MainCommandUsage_Safezone"))}
    end

    return {command = "SafezoneCommand", data = data}
end

-- El comado `/aptweaks`.
---@param player table Un IsoPlayer.
---@param args table La lista de argumentos.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function commands.APTweaksCommand(player, args)
    local argc = #args

    if argc > 3 then
        return {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText("IGUI_APTweaks_MainCommandUsage"))}

    elseif argc < 1 then
        return {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText("IGUI_APTweaks_MainCommandUsage"))}
    end

    local subcommand = args[1]

    if subcommand == "cleardata" and argc == 1 then
        return {command = "ClearData", data = {}}

    elseif subcommand == "safezone" then

        if argc == 2 then
            return APTweaksSafezoneCommand(player, args[2])

        else
            return {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText("IGUI_APTweaks_MainCommandUsage_Safezone"))}
        end

    elseif subcommand == "warp" then

        if argc == 3 then
            return APTweaksWarpCommand(player, args[2], args[3])

        else
            return {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText("IGUI_APTweaks_MainCommandUsage_Warp"))}
        end
    else
        return {text = string.format(getText("IGUI_APTweaks_Chat_IncorrectUse"), getText("IGUI_APTweaks_MainCommandUsage"))}
    end
end

-- El comando `/warp`. 
---@param player table Un IsoPlayer.
---@param args table La lista de argumentos.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function commands.WarpCommand(player, args)
    local argc = #args

    if argc > 1 then
        return {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText("IGUI_APTweaks_WarpCommandUsage"))}

    elseif argc < 1 then
        return {text = string.format(getText("IGUI_APTweaks_Chat_FewArgs"), getText("IGUI_APTweaks_WarpCommandUsage"))}
    end

    local warp = args[1] -- El warp que el jugador ingresó, tal cual como lo escribió.
    local location = aptweaks.aptweaks_data.warps[warp]

    if not location then
        return {text = string.format(getText("IGUI_APTweaks_Chat_MissingWarp"), warp, string.format(getText("IGUI_APTweaks_AviableWarps"), ShowWarps()))}
    end

    if player:getVehicle() then
        return {text = getText("IGUI_APTweaks_Chat_RidingExecutionForbidden")}
    end

    if client_flags.isMoving then
        return {text = getText("IGUI_APTweaks_Chat_MovingExecutionForbidden")}
    end

    if client_flags.isTeleporting or client_flags.hasTeleportRequest then
        return {text = getText("IGUI_APTweaks_Chat_AlreadyExecuting")}
    end

    client_flags.isTeleporting = true
    client_flags.teleportLocation = {x= location.x, y = location.y, z = location.z, name = warp}

    return {text = string.format(getText("IGUI_APTweaks_Chat_TeleportBegins"), warp)}
    --return {text = string.format(getText("IGUI_APTweaks_TeleportCooldown"), client_flags.warpCommandCooldownSecondsLeft)}
end

-- El comando `/warps`.
---@param args table La lista de argumentos.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function commands.WarpsCommand(args)

    if #args > 0 then
        return {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText("IGUI_APTweaks_WarpsCommandUsage"))}
    end

    return {text = string.format(getText("IGUI_APTweaks_AviableWarps") .. ".", ShowWarps())} -- WARN: Esto no es internacionalizable.
end

-- El comando `/claim`.
---@param player table Un IsoPlayer.
---@param args table La lista de argumentos.
---@return table result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function commands.ClaimCommand(player, args)

    if #args > 0 then
        return {text = string.format(getText("IGUI_APTweaks_Chat_ManyArgs"), getText("IGUI_APTweaks_ClaimCommandUsage"))}
    end

    local x, y = math.floor(player:getX()), math.floor(player:getY())

    return {command = "SafezoneCommand", data = {action = "claim", x = x, y = y}}
end

return commands
