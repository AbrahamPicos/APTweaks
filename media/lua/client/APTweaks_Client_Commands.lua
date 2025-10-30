-- APTweaks_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

local commands, aptweaks = {}, require("APTweaks")

local isClient = aptweaks.isClient
local isAdmin = aptweaks.isAdmin
local getText = aptweaks.getText

local aptweaks_data = aptweaks.aptweaks_data
local APTweaksVars = aptweaks.APTweaksVars
local player_flags = aptweaks.player_flags

local format = aptweaks.format

-- Almacena las definiciones temporales de pos1 y pos2, posiciones que representan los vertices que limitan el área de la
--  safehouse. Se usan para el comando safezone define.
local safehouse = {
    -- El vertice1, debe ser el de la esquina superior izquierda.
    pos1 = nil,
    -- El vertice2, debe ser el de la esquina inferior derecha.
    pos2 = nil
}

-- La lógica del comando warp. Siempre que proporcione argumentos válidos, y la lógica para usar la tabla que
--  responde, puede llamar a esta función desde cualquier otra. 
--- @param player table Un IsoPlayer.
--- @param args table La lista de argumentos.
--- @return table table Una tabla con la respuesta. Un texto, y un mapa de datos según se requiera.
function commands.WarpComamand(player, args)

    if #args >= 1 then

        if #args == 1 then
            -- El warp que el cliente ingresó, tal cual como lo escribió.
            local warp = args[1]

            if aptweaks_data.warps[warp] then

                if player:getVehicle() == nil then

                    if not player:isMoving() then

                        if not player_flags.inWarpCommand then

                            if player_flags.warpCommandTickStart == nil then
                                player_flags.inWarpCommand = true
                                player_flags.warpCommandWarp = warp
                                player_flags.warpCommandCooldownSecondsLeft = APTweaksVars.TeleportCooldown

                                return {text = format(getText("UI_APTweaks_TeleportBegins"), warp)}
                            else
                                return {text = format(getText("UI_APTweaks_TeleportCooldown"), player_flags.warpCommandCooldownSecondsLeft)}
                            end
                        else
                            return {text = getText("UI_APTweaks_AlreadyExecuting")}
                        end
                    else
                        return {text = getText("UI_APTweaks_MovingExecutionForbidden")}
                    end
                else
                    return {text = getText("UI_APTweaks_RidingExecutionForbidden")}
                end
            -- En este bloque, usando como elementos las llaves en la tabla warps, se crea un string con el formato
            --  correcto para ser incluido en una oración que dicta los warps disponibles.
            -- Aunque ahora parece sobreingeniería, los warps serán dinámicos en el futuro.
            else
                local aviableWarps = ""
                local totalElements = 0
                local processedElements = 0

                for _ in pairs(aptweaks_data.warps) do
                    totalElements = totalElements + 1
                end

                for existingWarp, _ in pairs(aptweaks_data.warps) do
                    processedElements = processedElements + 1

                    if aviableWarps == "" then
                        aviableWarps = tostring(existingWarp)
                    elseif processedElements == totalElements then
                        aviableWarps = aviableWarps .. getText("UI_APTweaks_WarpsList_SeparatorFinal") .. tostring(existingWarp)
                    else
                        aviableWarps = aviableWarps .. getText("UI_APTweaks_WarpsList_Separator") .. tostring(existingWarp)
                    end
                end
                return {text = format(getText("UI_APTweaks_MissingWarp"), warp, aviableWarps)}
            end
        else
            return {text = format(getText("UI_APTweaks_ManyArgs"), getText("UI_APTweaks_WarpCommandUsage"))}
        end
    else
        return {text = format(getText("UI_APTweaks_FewArgs"), getText("UI_APTweaks_WarpCommandUsage"))}
    end
end

-- La lógica del comando safehouse. Siempre que proporcione argumentos válidos, y la lógica para usar la tabla que
--  responde, puede llamar a esta función desde cualquier otra. 
--- @param player table Un IsoPlayer.
--- @param args table La lista de argumentos.
--- @return table table Una tabla con la respuesta. Un texto, y un mapa de datos según se requiera.
function commands.SafehouseCommand(player, args)
    local argsLength = #args

    if argsLength >= 1 then
        local data = nil
        local command = args[1]
        local hasPermission = isAdmin()

        if argsLength == 1 then
            local x, y = math.floor(player:getX()), math.floor(player:getY())

            local function removePos()
                safehouse.pos2, safehouse.pos2 = nil, nil
            end

            if command == "claim" or command == "undefine" then

                if not command == "undefine" or hasPermission then
                    local unclaim = false
                    local cell = player:getCell()
                    local cellX, cellY = math.floor(cell:getMinX() / 300), math.floor(cell:getMinY() / 300)
                    local cellID = tostring(cellX) .. "," .. tostring(cellY)

                    data = {cellID = cellID, x = x, y = y}

                    return {text = "Espere un momento...", uncliam = unclaim, command = command .. "Command", data = data}
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            elseif command == "pos1" or command == "pos2" then

                if hasPermission then

                    if x >= 0 and y >= 0 and x <= 19799 and y <= 15899 then
                        safehouse[command] = {x = x, y = y}

                        return {text = format("Definida la posicion del vertice de area %s en %d,%d.", command, x, y)}
                    else
                        return {text = "No puede usar coordenadas fuera del mapa."}
                    end
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            elseif command == "clearposts" then

                if hasPermission then
                    removePos()

                    return {text = "Se han removido las definiciones de pos1 y pos2 de la memoria temporal."}
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            elseif command == "define" then

                if hasPermission then
                    local pos1, pos2 = safehouse.pos1, safehouse.pos2

                    if pos1 and pos2 then
                        local x1, y1, x2, y2 = pos1.x, pos1.y, pos2.x, pos2.y

                        if x2 > x1 and y2 > y1 then

                            if x2 - x1 < 300 and y2 - y1 < 300 then
                                local cells = {} -- cells = {cellID = {areaID}}
                                local cellID = nil
                                local areaID = x1 .. "," .. y1
                                local cx1, cy1, cx2, cy2 = math.floor(x1 / 300), math.floor(y1 / 300), math.floor(x2 / 300), math.floor(y2 / 300)

                                for cx = cx1, cx2 do

                                    for cy = cy1, cy2 do
                                        cellID = tostring(cx) .. "," .. tostring(cy)

                                        if not cells[cellID] then
                                            cells[cellID] = {}
                                            table.insert(cells[cellID], areaID)
                                        end
                                    end
                                end
                                data = {areaID = areaID, area = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}, cells = cells}
                                removePos()

                                return {text = "Espere un momento...", command = "safehouseDefineCommand", data = data}
                            else
                                return {text = "El area no puede ser mayor o igual a 300 tiles."}
                            end
                        else
                            return {text = "Es necesario que pos1 este en la esquina superior izquierda del area."}
                        end
                    else
                        return {text = "<RGB:1,0,0>Antes debe definir el area con <RGB:0,0,1><SPACE>pos1 <RGB:1,0,0><SPACE>y <RGB:0,0,1><SPACE>pos2."}
                    end
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            elseif command == "prune" then

                if hasPermission then
                    return {text = "Espere un momento...", command = "safezonePruneCommand", data = {}}
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            else
                return {text = "Uso incorrecto."}
            end
        else
            return {text = "Demasiados argumentos."}
        end
    else
        return {text = "Faltan argumentos."}
    end
end

return commands