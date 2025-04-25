-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Almacena las definiciones temporales de pos1 y pos2, posiciones que representan los vertices que limitan el área de la
--  safehouse. Se usan para el comando safehouse define.
local safehouse = {
    -- El vertice1, debe ser el de la esquina superior izquierda.
    pos1 = nil,
    -- El vertice2, debe ser el de la esquina inferior derecha.
    pos2 = nil
}

-- El Número que identificar la sesión actual. Se usa para diferenciar el sistema de mensajería interno.
local sesionID = nil

local function OnGameStart()
    -- Por alguna razón esto puede dar 100, pero no 1000, así que el número siempre será de 3 dígitos.
    sesionID = ZombRandBetween(100, 1000)
end

-- La lógica del comando safehouse. Estoy experimentando con mover cosas de OnAddMessage afuera. Voy a cargar mucho ese
--  evento.
--- @param player table
--- @param message table
--- @param args table
local function SafehouseCommand(player, message, args)

    if #args >= 4 then

        if #args == 4 then
            local command = args[4]
            local x, y = math.floor(player:getX()), math.floor(player:getY())

            if command == "claim" then
                local cell = player:getCell()
                local cellX, cellY = math.floor(cell:getMinX() / 300), math.floor(cell:getMinY() / 300)
                local cellID = tostring(cellX) .. "," .. tostring(cellY)

                message:setText("Espere un momento...")
                sendClientCommand(player, "com.github.abrahampicos.aptweaks", "claimCommand", {cellID = cellID, x = x, y = y})

            elseif command == "pos1" or command == "pos2" then

                if x >= 0 and y >= 0 then

                    if command == "pos1" then
                        safehouse.pos1 = {x = x, y = y}
                    else
                        safehouse.pos2 = {x = x, y = y}
                    end
                    message:setText(string.format("definida la posicion del vertice de area %s en %d,%d.", command, x, y))
                else
                    message:setText("No puede usar coordenadas negativas.")
                end
            elseif command == "clearposts" then
                safehouse.pos1 = nil
                safehouse.pos2 = nil
                message:setText("Se han removido las definiciones de pos1 y pos2 de la memoria temporal.")

            elseif command == "define" then
                local pos1, pos2 = safehouse.pos1, safehouse.pos2

                if pos1 ~= nil and pos2 ~= nil then
                    local x1, y1, x2, y2 = pos1.x, pos1.y, pos2.x, pos2.y

                    if x2 > x1 and y2 > y1 then
                        local cellID = nil

                        if x2 - x1 < 300 and y2 - y1 < 300 then
                            local areaID = x1 .. "," .. y2
                            local cx1 = math.floor(x1 / 300)
                            local cx2 = math.floor(x2 / 300)
                            local cy1 = math.floor(y1 / 300)
                            local cy2 = math.floor(x2 / 300)
                            local cells = {}

                            for cx = cx1, cx2 do

                                for cy = cy1, cy2 do
                                    cellID = cx .. "," .. cy

                                    if not cells[cellID] then
                                        cells[cellID] = {x = cx, y = cy, areas = {areaID}}
                                    end
                                end
                            end
                            sendClientCommand(player, "com.github.abrahampicos.aptweaks", "safehouseDefineCommand", {areaID = areaID, cellID = cellID, area = {x1= x1, y1= y1, x2= x2, y2 = y2, owner = nil}, cells = cells})
                        else
                            message:setText("El area no puede ser mayor o igual a 300 tiles.")
                        end
                    else
                        message:setText("Es necesario que pos1 este en la esquina superior izquierda del area.")
                    end
                else
                    message:setText("Antes debe definir el area con pos1 y pos2.")
                end
            else
                message:setText("Uso incorrecto.")
            end
        else
            message:setText("Demasiados argumentos.")
        end
    else
        message:setText("Faltan argumentos.")
    end
end

-- En el evento OnAddMessage. Intercepta los mensajes, y convierte su cadana de texto a una tabla cuyos elementos usa
--  para determinar si cliente está intentando ejecutar el comando claim.
--- @param message table
--- @param tabId number
local function OnAddMessage(message, tabId)
    local player = getPlayer()

    if player ~= nil then
        -- La tabla que almacena cada palabra incluida en la cadena message.
        -- Tenga en cuenta que esta tabla contiene todo el mensaje, incluidas las palabras "Unknown command", por lo que no
        --   no son argumentos realmente.
        local args = {}

        for word in string.gmatch(message:getText(), "%S+") do
            table.insert(args, word)
        end

        if #args >= 3 then

            if args[1] == "Unknown" and args[2] == "command" then

                if args[3] == "APTWeaksMessage" then

                    if args[4] == sesionID then
                        message:setText(table.concat(args, " ", 5))
                    end

                elseif args[3] == "safe" then
                    SafehouseCommand(player, message, args)
                end
            end
        end
    end
end

-- Recibe la respuesta del servidor al sendClientCommand enviado en el evento OnAddMessage.
local function OnServerCommand(module, command, args)
    if module == "com.github.abrahampicos.aptweaks" then

        if command == "claimCommand" then
            -- addSafeHouse(Int X, Int Y, Int W, Int H, String username, boolean remote)
			-- X y Y, representa el vértice desde el que se extenderá la safehouse, y debe estar en la esquina superior izquierda.
			-- W es el largo que se expandirá el área a partir de dicho vértice en dirección a la esquina superior derecha.
			-- H es el largo que se expandirá el área a partir de dicho vértice en dirección a la esquina interior izquieda. 
            -- No tengo ni la más nínima idea de qué es remote.
            local safehouse = SafeHouse.addSafeHouse(8079, 11420, 10, 10, getPlayer():getUsername(), false)
            safehouse:syncSafehouse()
            print("[APTweaksDebug] Se supone que debiste haber obtenido aqui tu mugre safehouse.")
        end
    end
end

Events.OnGameStart.Add(OnGameStart)
Events.OnServerCommand.Add(OnServerCommand)
Events.OnAddMessage.Add(OnAddMessage)
