-- APTweaks_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

local commands, aptweaks = {}, require("APTweaks")

local getText = aptweaks.getText

local player_flags = aptweaks.player_flags
local aptweaks_temp = aptweaks.aptweaks_temp

aptweaks_temp.safezone = {}

-- Devuélve la lista de warps disponibles en forma de string, en un formato compatible con el español e inglés.
---@return string aviableWarps `aviableWarps = warp1, warp2, warp3, and warp4`.
local function ShowWarps()
    local aviableWarps = ""
    local totalElements = 0
    local processedElements = 0

    for _ in pairs(aptweaks.aptweaks_data.warps) do
        totalElements = totalElements + 1
    end

    for existingWarp, _ in pairs(aptweaks.aptweaks_data.warps) do
        processedElements = processedElements + 1

        if aviableWarps == "" then
            aviableWarps = tostring(existingWarp)

        elseif processedElements == totalElements then
            aviableWarps = aviableWarps .. getText("UI_APTweaks_WarpsList_SeparatorFinal") .. tostring(existingWarp)

        else
            aviableWarps = aviableWarps .. getText("UI_APTweaks_WarpsList_Separator") .. tostring(existingWarp)
        end
    end

    return aviableWarps
end

-- El comando `/aptweaks warp add|remove`.
---@param player table
---@param action string
---@param warp boolean
---@return table result
local function APTweaksWarpCommand(player, action, warp)

    if action == "add" then
        local location = {x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ())}

        return {command = "WarpCommand", data = {action = action, name = warp, location = location}}

    elseif action == "remove" then
        return {command = "WarpCommand", data = {action = action, name = warp}}

    else
        return {text = "Uso incorrecto."}
    end
end

-- El comando `/aptweaks safezone add|remove`.
---@param player table
---@param action string
---@return table result
local function APTWeaksSafezoneCommand(player, action)
    local x, y = math.floor(player:getX()), math.floor(player:getY())

    if action == "pos1" or action == "pos2" then
        aptweaks_temp.safezone[action] = {x = x, y = y}

        return {text = string.format("Definida la posicion del vertice de area %s en %d,%d.", action, x, y)}

    elseif action == "add" then
        local pos1, pos2 = aptweaks_temp.safezone.pos1, aptweaks_temp.safezone.pos2

        if pos1 and pos2 then
            return {command = "SafezoneAddCommand", data = {x1 = pos1.x, y1 = pos1.y, x2 = pos2.x, y2 = pos2.y}}

        else
            return {text = "<RGB:1,0,0>Antes debe definir el area con <RGB:0,0,1><SPACE>pos1 <RGB:1,0,0><SPACE>y <RGB:0,0,1><SPACE>pos2."}
        end

    elseif action == "remove" then
        return {command = "SafezoneClaimCommand", data = {action = action, x = x, y = y}}

    elseif action == "prune" then
        return {command = "SafezonePruneCommand", data = {}}

    else
        return {text = "Uso Incorrecto."}
    end
end

-- El comado `/aptweaks`.
---@param player table Un IsoPlayer.
---@param args table La lista de argumentos.
---@return table|nil result Una tabla con la respuesta. Un texto, y un comando con sus argumentos según se requiera.
function commands.APTweaksCommand(player, args)

    if #args > 3 then
        return {text = "Demasiados argumentos"}
    end

    local subcommand = args[1]
    local action = args[2]

    if #args == 1 then

        if subcommand == "cleardata" then
            return {command = "ClearData", data = {}}

        else
            return {text = "Uso incorrecto."}
        end

    elseif #args == 2 then

        if subcommand == "safezone" then
            return APTWeaksSafezoneCommand(player, action)

        else
            return {text = "Uso incorrecto."}
        end

    elseif #args == 3 then

        if subcommand == "warp" then
            return APTweaksWarpCommand(player, action, args[3])

        else
            return {text = "Uso incorrecto."}
        end

    else
        return {text = "Faltan argumentos."}
    end
end

-- el comando `/warp`. 
---@param player table
---@param args table
---@return table result
function commands.WarpCommand(player, args)

    if #args > 1 then
        return {text = string.format(getText("UI_APTweaks_ManyArgs"), getText("UI_APTweaks_WarpCommandUsage"))}
    end

    if #args < 1 then
        return {text = string.format(getText("UI_APTweaks_FewArgs"), getText("UI_APTweaks_WarpCommandUsage"))}
    end

    local warp = args[1] -- El warp que el jugador ingresó, tal cual como lo escribió.
    local location = aptweaks.aptweaks_data.warps[warp]

    if not location then
        return {text = string.format(getText("UI_APTweaks_MissingWarp"), warp, ShowWarps())}
    end

    if player:getVehicle() then
        return {text = getText("UI_APTweaks_RidingExecutionForbidden")}
    end

    if player_flags.isMoving then
        return {text = getText("UI_APTweaks_MovingExecutionForbidden")}
    end

    if player_flags.isTeleporting and player_flags.hasTeleportRequest then
        return {text = getText("UI_APTweaks_AlreadyExecuting")}
    end

    player_flags.isTeleporting = true
    player_flags.teleportLocation = {x= location.x, y = location.y, z = location.z, name = warp}

    return {text = string.format(getText("UI_APTweaks_TeleportBegins"), warp)}
    --return {text = string.format(getText("UI_APTweaks_TeleportCooldown"), player_flags.warpCommandCooldownSecondsLeft)}
end

-- El comando `/warps`.
---@param args table
---@return table result
function commands.WarpsCommand(args)

    if #args > 0 then
        return {text = "Demasiados argumentos. Use /warps"}
    end

    return {text = "Los warps disponibles son " ..ShowWarps() .. "."}
end

-- El comando `/claim`.
---@param player table
---@param args table
---@return table result
function commands.ClaimCommand(player, args)

    if #args > 0 then
        return {text = "Demasiados argumentos. Use /claim"}
    end

    local x, y = math.floor(player:getX()), math.floor(player:getY())

    return {command = "SafezoneClaimCommand", data = {action = "claim", x = x, y = y}}
end

return commands
