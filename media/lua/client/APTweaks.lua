-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

require("APTweaks_server.lua")

-- Almacena las definiciones temporales de pos1 y pos2, posiciones que representan los vertices que limitan el área de la
--  safehouse. Se usan para el comando safezone define.
local safehouse = {
    -- El vertice1, debe ser el de la esquina superior izquierda.
    pos1 = nil,
    -- El vertice2, debe ser el de la esquina inferior derecha.
    pos2 = nil
}

-- La ID del mod.
local modID = "com.github.abrahampicos.aptweaks"
-- El Número que identificar la sesión actual. Se usa para diferenciar el sistema de mensajería interno.
local sesionID = nil

-- En el evento OnGameStart. Define cómo será la ID de esta sesión.
local function OnGameStart()
    -- Por alguna razón esto puede dar 100, pero no 1000, así que el número siempre será de 3 dígitos.
    sesionID = ZombRandBetween(100, 1000)
end

-- La lógica del comando safehouse. Siempre que proporcione argumentos válidos, y la lógica para usar la tabla que
--  responde, puede llamar a esta función desde cualquier otra. 
--- @param player table Un IsoPlayer.
--- @param args table La lista de argumentos.
--- @return table table Una tabla con la respuesta. Un texto, y un mapa de datos según se requiera.
local function SafehouseCommand(player, args)

    if #args >= 1 then

        if #args == 1 then
            local command = args[1]
            local x, y = math.floor(player:getX()), math.floor(player:getY())

            if command == "claim" then
                local cell = player:getCell()
                local cellX, cellY = math.floor(cell:getMinX() / 300), math.floor(cell:getMinY() / 300)
                local cellID = tostring(cellX) .. "," .. tostring(cellY)

                return {text = "Espere un momento...", commandSend = {command = "claimCommand", data = {cellID = cellID, x = x, y = y}}}

            elseif command == "pos1" or command == "pos2" then

                if isAdmin() then

                    if x >= 0 and y >= 0 then
                        safehouse[command] = {x = x, y = y}
                        return {text = string.format("Definida la posicion del vertice de area %s en %d,%d.", command, x, y)}
                    else
                        return {text = "No puede usar coordenadas negativas."}
                    end
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            elseif command == "clearposts" then

                if isAdmin() then
                    safehouse.pos1 = nil
                    safehouse.pos2 = nil
                    return {text = "Se han removido las definiciones de pos1 y pos2 de la memoria temporal."}
                else
                    return {text = "No tiene permitido usar ese comando."}
                end
            elseif command == "define" then

                if isAdmin() then
                    local pos1, pos2 = safehouse.pos1, safehouse.pos2

                    if pos1 and pos2 then
                        local x1, y1, x2, y2 = pos1.x, pos1.y, pos2.x, pos2.y

                        if x2 > x1 and y2 > y1 then
                            local cellID = nil

                            if x2 - x1 < 300 and y2 - y1 < 300 then
                                local areaID = x1 .. "," .. y2
                                local cx1, cy1, cx2, cy2 = math.floor(x1 / 300), math.floor(y1 / 300), math.floor(x2 / 300), math.floor(y2 / 300)
                                local cells = {}

                                for cx = cx1, cx2 do

                                    for cy = cy1, cy2 do
                                        cellID = cx .. "," .. cy

                                        if not cells[cellID] then
                                            cells[cellID] = {x = cx, y = cy, areas = {areaID}}
                                        end
                                    end
                                end
                                return {text = "Espere un momento...", commandSend = {command = "safehouseDefineCommand", data = {areaID = areaID, cellID = cellID, area = {x1= x1, y1= y1, x2= x2, y2 = y2, owner = nil}, cells = cells}}}
                            else
                                return {text = "El area no puede ser mayor o igual a 300 tiles."}
                            end
                        else
                            return {text = "Es necesario que pos1 este en la esquina superior izquierda del area."}
                        end
                    else
                        return {text = "Antes debe definir el area con pos1 y pos2."}
                    end
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

-- En el evento OnAddMessage. Intercepta los mensajes, y convierte su cadana de texto a una tabla cuyos elementos usa
--  para determinar si cliente está intentando ejecutar algún comando de APTweaks.
--- @param message table
--- @param tabId number
local function OnAddMessage(message, tabId)
    local player = getPlayer()

    if player ~= nil then
        -- La tabla que almacena cada palabra incluida en la cadena message.
        -- Tenga en cuenta que esta tabla contiene todo el mensaje, incluidas las palabras "Unknown command".
        local words = {}

        for word in string.gmatch(message:getText(), "%S+") do
            table.insert(words, word)
        end

        if #words >= 3 then

            if words[1] == "Unknown" and words[2] == "command" then
                local command = words[3]
                local args  = {unpack(words, 4)}
                local text = nil
                local result = nil

                if command == sesionID then
                    result = {text = table.concat(args, " ", 2)}

                elseif command == "safezone" then
                    result = SafehouseCommand(player, args)
                else
                    text = "uso incorrecto."
                end
                if result then
                    text = result.text
                    local commandSend = result.commandSend

                    if commandSend then
                        sendClientCommand(player, modID, commandSend.command, commandSend.data)
                    end
                end
                message:setText(text)
            end
        end
    end
end

-- Recibe la respuesta del servidor al sendClientCommand enviado en el evento OnAddMessage.
local function OnServerCommand(module, command, args)
    if module == "com.github.abrahampicos.aptweaks" then

        if command == "createSafehouse" then
            local player = getPlayer()
            local status = "fail"
            -- addSafeHouse(Int X, Int Y, Int W, Int H, String username, boolean remote)
			-- X y Y, representa el vértice desde el que se extenderá la safehouse, y debe estar en la esquina superior izquierda.
			-- W(width) es el largo que se expandirá el área a partir de dicho vértice en dirección a la esquina superior derecha.
			-- H(height) es el largo que se expandirá el área a partir de dicho vértice en dirección a la esquina inferior izquieda. 
            -- No tengo ni la más mínima idea de qué es remote. Podría afectar al cómo se reporta al servidor la existencia del área.
            local safezone = SafeHouse.addSafeHouse(args.x1, args.y1, args.w, args.h, player:getUsername(), false)
            if safezone then
                SendCommandToServer(sesionID .. " " .. "Safehouse creada exitosamente.")
            else
                SendCommandToServer(sesionID .. " " .. "Ocurrio un error desconocido al crear la safehouse.")
            end
            sendClientCommand(player, modID, "claimCommandSucess", {status = status, blocked = player:getUsername()})
        elseif command == "messageCommand" then
            SendCommandToServer(sesionID .. " " .. args.text)
        end
    end
end

Events.OnGameStart.Add(OnGameStart)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnAddMessage.Add(OnAddMessage)