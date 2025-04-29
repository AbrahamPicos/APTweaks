-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

require("APTweaks_server.lua")

-- La ID del mod.
local modID = "com.github.abrahampicos.aptweaks"
-- El Número que identificar la sesión actual. Se usa para diferenciar el sistema de mensajería interno.
local sesionID = nil
--- Un contador experimental para probar si usar GameTime gettimedelta puede volver consistente el tiempo.
local GenericTimeCounter = 0
-- Almacena la función orignial onReleaseSafehouse de la clase ISSafehouseUI para usarla aquí,
local old_onReleaseSafehouse = ISSafehouseUI.onReleaseSafehouse

-- Constantes que controlan algunos aspectos configurables del mod:
local config = {
    --- Si se usará el sistema de warps(Incompleto pero estable).
    warpSystemEnabled = true,
    --- Si se usará el sistema anti-AFK(Incompleto pero estable).
    afkSystemEnabled = true,
    --- Si se usará el sistema de non-buildig safehouses(incompleto e inestable).
    safehouseSystemEnabled = false,
    --- El retraso de la teletransportación. Dentro de este tiempo se cancelará si el jugador se mueve.
    teleportDelay = 5,
    --- El tiempo de enfriamiento de la teletransportación. El jugador no podrá volver a teletransportarse dentro de este tiempo.
    teleportCooldown = 30,
    --- El tiempo que el jugador debe estar quieto para considerarse AFK.
    afkStart = 60,
    --- El tiempo que el jugador debe continuar quieto luego de considerarse AFK para forzarlo a salir al menú principal.
    afkKick =  60
}

-- Las localizaciones de cada warp. El punto al que el jugador será teletransportado.
local warps = {
    westpoint = {x = 11889, y = 6862, z = 0},
    rosewood = {x = 8078, y = 11419, z = 0},
    riverside = {x = 6448, y = 5313, z = 0},
    louisville = {x = 12650, y = 2020, z =0}
}

-- Almacena las definiciones temporales de pos1 y pos2, posiciones que representan los vertices que limitan el área de la
--  safehouse. Se usan para el comando safezone define.
local safehouse = {
    -- El vertice1, debe ser el de la esquina superior izquierda.
    pos1 = nil,
    -- El vertice2, debe ser el de la esquina inferior derecha.
    pos2 = nil
}

-- Variables para el jugador controladas por el evento tick; Son útiles para el comando warp y el sistema AFK.
local player_flags = {
    --- El jugador asociado al cliente. Se establece a un IsoPlayer si existe en el evento OnTick. Se reestablece a nil si
    ---  deja de existir.
    player = nil;
    --- La última localización del jugador. Se reajusta en cada tick si su localización ha cambiado.
    lastLocation = {x = nil, y = nil, z = nil};
    --- Es el tick a partir del cual el jugador ha estado quieto. Se reestablece a nil si el jugador se mueve.
    iddleTickStart = nil;
    --- Si el jugador está AFK. Se establece en true si iddleTickStart ha sido diferente de nil durante afkStart segundos.
    ---  Se reestablece a false si el jugador se mueve.
    isAfk = false;
    --- Si el jugador está ejecutando el comando warp. Se establece en true cuando el jugador usó el comando warp. Se
    ---  reestablece a false si el jugador se movió o fue teletransportado.
    inWarpCommand = false;
    --- El warp al que el jugador se teletransportará al finalizar teleportDelay si inWarpCommand es true. Se establece como
    ---  args[4] cuando este puede usarse como indice para obtener coordenadas en la tabla warps. Se reestablece a false si
    ---  el jugador se movió o fue teletransportado.
    warpCommandWarp = nil;
    --- El tick cuando inició el comando warp. Se establece como el número de tick en el que inWarpCommand se estableció como
    ---  true. Se reestablece a nil si el jugador se movió o fue teletransportado.
    warpCommandTickStart = nil;
    --- La cantidad de segundos que faltan para que el jugador pueda teletransportarse otra vez. Sólo se usa para el mensaje de
    ---  error que el jugador ve cuando intenta teletrasportarse en cooldown. Se reestablece a nil cuando ha pasado el tiempo en
    ---  teleportDelay.
    warpCommandCooldownSecondsLeft = nil
}

-- En el evento OnGameStart. Define cómo será la ID de esta sesión.
local function OnGameStart()
    print("[APTweaksDebug] APTweaks.lua is loaded.")
    -- Por alguna razón esto puede dar 100, pero no 1000, así que el número siempre será de 3 dígitos.
    sesionID = ZombRandBetween(100, 1000)
end

-- Añade lógica adicional a la función vanilla onReleaseSafehouse para que ordene la modificación
--  del mapa de datos de APTweaks.
function ISSafehouseUI:onReleaseSafehouse(button, player)
    old_onReleaseSafehouse(self, button, player)

    if config.safehouseSystemEnabled then
        -- Si necesitara inspacccionar self para conocer los atributos disponibles.
        --for k, v in pairs(self) do
        --    print(k, v)
        --end
        local safezone = button.parent.ui.safehouse

        if safezone then
            local areaID = tostring(safezone:getX()) .. " " .. tostring(safezone:getY())

            sendClientCommand(player, modID, "safehouseUnclaim", {areaID = areaID, owener = player:getUsername()})
        end
    end
end

-- La lógica del comando warp. Siempre que proporcione argumentos válidos, y la lógica para usar la tabla que
--  responde, puede llamar a esta función desde cualquier otra. 
--- @param player table Un IsoPlayer.
--- @param args table La lista de argumentos.
--- @return table table Una tabla con la respuesta. Un texto, y un mapa de datos según se requiera.
local function WarpComamand(player, args)
    if #args >= 1 then

        if #args == 1 then
            -- El warp que el cliente ingresó, tal cual como lo escribió.
            local warp = args[1]

            if warps[warp] then

                if player:getVehicle() == nil then

                    if player_flags.iddleTickStart ~= nil then

                        if not player_flags.inWarpCommand then

                            if player_flags.warpCommandTickStart == nil then
                                player_flags.inWarpCommand = true
                                player_flags.warpCommandWarp = warp
                                player_flags.warpCommandCooldownSecondsLeft = config.teleportCooldown

                                return {text = string.format(getText("UI_APTweaks_TeleportBegins"), warp)}
                            else
                                return {text = string.format(getText("UI_APTweaks_TeleportCooldown"), player_flags.warpCommandCooldownSecondsLeft)}
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

                for _ in pairs(warps) do
                    totalElements = totalElements + 1
                end

                for existingWarp, _ in pairs(warps) do
                    processedElements = processedElements + 1

                    if aviableWarps == "" then
                        aviableWarps = tostring(existingWarp)
                    elseif processedElements == totalElements then
                        aviableWarps = aviableWarps .. getText("UI_APTweaks_WarpsList_SeparatorFinal") .. tostring(existingWarp)
                    else
                        aviableWarps = aviableWarps .. getText("UI_APTweaks_WarpsList_Separator") .. tostring(existingWarp)
                    end
                end
                return {text = string.format(getText("UI_APTweaks_MissingWarp"), warp, aviableWarps)}
            end
        else
            return {text = string.format(getText("UI_APTweaks_ManyArgs"), getText("UI_APTweaks_WarpCommandUsage"))}
        end
    else
        return {text = string.format(getText("UI_APTweaks_FewArgs"), getText("UI_APTweaks_WarpCommandUsage"))}
    end
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

            local function removePos()
                safehouse.pos2 = nil
                safehouse.pos2 = nil
            end

            if command == "claim" then
                local cell = player:getCell()
                local cellX, cellY = math.floor(cell:getMinX() / 300), math.floor(cell:getMinY() / 300)
                local cellID = tostring(cellX) .. "," .. tostring(cellY)

                local data = {cellID = cellID, x = x, y = y}

                return {text = "Espere un momento...", commandSend = {command = "claimCommand", data = data}}

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
                    removePos()

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

                            if x2 - x1 < 300 and y2 - y1 < 300 then
                                local areaID = x1 .. "," .. y2
                                local cx1, cy1, cx2, cy2 = math.floor(x1 / 300), math.floor(y1 / 300), math.floor(x2 / 300), math.floor(y2 / 300)
                                local cellID = nil
                                local cells = {}

                                for cx = cx1, cx2 do

                                    for cy = cy1, cy2 do
                                        cellID = cx .. "," .. cy

                                        if not cells[cellID] then
                                            cells[cellID] = {x = cx, y = cy, areas = {areaID}}
                                        end
                                    end
                                end
                                local data = {areaID = areaID, cellID = cellID, area = {x1= x1, y1= y1, x2= x2, y2 = y2, owner = nil}, cells = cells}
                                removePos()

                                return {text = "Espere un momento...", commandSend = {command = "safehouseDefineCommand", data = data}}
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
    local player = player_flags.player

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

                -- El comando del sistema de mensajería interno.
                if command == "APTM-" .. sesionID then
                    text = table.concat(args, " ")

                -- El comando warp. 
                elseif command == getText("UI_APTweaks_WarpCommand") and config.warpSystemEnabled then
                    result = WarpComamand(player, args)

                -- El comando safezone.
                elseif command == "safezone" and config.safehouseSystemEnabled then
                    result = SafehouseCommand(player, args)
                end

                if result then
                    text = result.text
                    local commandSend = result.commandSend

                    if commandSend then
                        sendClientCommand(player, modID, commandSend.command, commandSend.data)
                    end
                end

                if text then
                message:setText(text)
                end
            end
        end
    end
end

-- En el evento OnServerCommand. Procesa los comandos enviados desde el servidor al cliente que tienen que ver con APTweaks.
--  Incluye el servicio de mensajería interno y la reclamación de safehouses.
---@param module string Suele usarse la ID del mod. Sirve para diferenciar entre comandos enviados por otros mods.
---@param command string El comandos en sí, es como el "asunto" en un correo electronico.
---@param args table Los argumentos del comando. Es una tabla que puede contener cualquier cosa.
local function OnServerCommand(module, command, args)

    if module == "com.github.abrahampicos.aptweaks" then
        local text = nil
        local commandSend = nil
        local player = nil

        if command == "createSafehouse" then
            player = getPlayer()

            local username = player:getUsername()
            local owner = nil
            -- addSafeHouse(Int X, Int Y, Int W, Int H, String username, boolean remote)
            -- X y Y, representa el vértice desde el que se extenderá la safehouse, y debe estar en la esquina superior izquierda.
            -- W(width) es el largo que se expandirá el área a partir de dicho vértice en dirección a la esquina superior derecha.
            -- H(height) es el largo que se expandirá el área a partir de dicho vértice en dirección a la esquina inferior izquieda. 
            -- No tengo ni la más mínima idea de qué es remote. Podría afectar al cómo se reporta al servidor la existencia del área.
            local safezone = SafeHouse.addSafeHouse(args.x1, args.y1, args.w, args.h, username, false)

            if safezone then
                owner = username
                text = "Safehouse creada exitosamente."
            else
                text = "Ocurrio un error desconocido al crear la safehouse."
            end
            local data = {areaID = args.areaID, owner = owner, blocked = username}

            commandSend = {command = "claimCommandSucess", data = data}

        elseif command == "messageCommand" then
            text = args.text
        end

        if text then
            SendCommandToServer("APTM-" .. sesionID .. " " .. text)
        end

        if commandSend then
            sendClientCommand(player, modID, commandSend.command, commandSend.data)
        end
    end
end

-- Restaura las vanderas del jugador a sus valores por defecto para su posterior reutilización.
--- @param allFlags boolean Si debe hacerse un hard restore, lo que borrará todas las vanderas.
--- @param cooldownFlags boolean Si deberían borrarse las vanderas de cooldown, independientemente de todas las demás.
--- @param value (table|nil) El valor que la vandera lastLocation tendrá. Puede ignorarse completamente si allFlags es false.
local function RestorePlayerFlags(allFlags, cooldownFlags, value)
    local player = player_flags.player

    -- Restaura las vanderas referentes al teleport cooldown.
    local function RestoreCooldownFlags()
        player_flags.warpCommandTickStart = nil
        player_flags.warpCommandCooldownSecondsLeft = nil
    end

    if allFlags then
        value = value or {x = nil, y = nil, z = nil}

        if player_flags.iddleTickStart ~= nil then

            if player_flags.isAfk == true then
                player_flags.isAfk = false

                if player ~= nil then
                    player:setHaloNote(getText("UI_APTweaks_AfkRemoved"), 0, 255, 0, 500)
                end
            end
            player_flags.iddleTickStart = nil
        end

        if player_flags.inWarpCommand then

            if cooldownFlags then
                RestoreCooldownFlags()

                if player ~= nil then
                    player:setHaloNote(getText("UI_APTweaks_TeleportCancelled"), 255, 0, 0, 500)
                end
            end
            if player_flags.warpCommandWarp ~= nil then
                player_flags.warpCommandWarp = nil
            end

            player_flags.inWarpCommand = false
        end

        player_flags.lastLocation = value
    else
        if cooldownFlags then
            RestoreCooldownFlags()
        end
    end
end

-- Usa el tick actual para determinar cuántos segundos han pasado, y si son segundos enteros.
--- @param tick number El tick actual.
--- @param value number El tick que se usará para obtener la diferencia de tiempo.
--- @return number secondsElapsed El segundo obtenido en el tick actual.
--- @return boolean isWoleSecond Si el segundo obtenido es un segundo completo.
local function SecondsElapsed(tick, value)
    local ticksElapsed = tick - value
    local secondsElapsed = ticksElapsed / 60
    local isWholeSecond = false

    if ticksElapsed % 60 == 0 then
        isWholeSecond = true
    end
    return secondsElapsed, isWholeSecond
end

-- En el evento OnTickEvenPaused. Verifica constantemente la localización del cliente, de tenerla, y redefine las variables en su
--  tabla de vanderas según la lógica que procesa.
--- @param tick number
local function OnTickEvenPaused(tick)

    if isClient() then

        if config.warpSystemEnabled or config.afkSystemEnabled then
            local player = getPlayer()
            local playerX = player:getX()
            local playerY = player:getY()
            local playerZ = player:getZ()

            player_flags.player = player

            -- Si el jugador existe y tiene coordenadas.
            if player ~= nil and playerX ~= nil and playerY ~= nil and playerZ ~= nil then

                -- El evento OnAddMessage no puede saber cuál es el tick actual, ya que no hay un método para eso en la clase GameTime.
                --  En cambio, usa usa esta variable para indicar a este evento que tiene que registrarlo.
                if player_flags.inWarpCommand then

                    if player_flags.warpCommandTickStart == nil then
                        player_flags.warpCommandTickStart = tick
                    end
                end

                -- Dentro de este bloque se procesan el teleport delay, y el teleport cooldown. También ocurre la teletransportación.
                if config.warpSystemEnabled then

                    if player_flags.warpCommandTickStart ~= nil then
                        local secondsElapsed, isWholeSecond = SecondsElapsed(tick, player_flags.warpCommandTickStart)

                        if isWholeSecond then

                            if player_flags.inWarpCommand then
                                player:setHaloNote(string.format(getText("UI_APTweaks_TeleportDelaying"), math.abs(secondsElapsed - config.teleportDelay)), 0, 255, 0, 500)

                                if secondsElapsed == config.teleportDelay then
                                local location = warps[player_flags.warpCommandWarp]

                                    -- Es necesario sobreescribir primero la última localización, o volverá ahí luego de la teletransportación.
                                    player:setLx(location.x)
                                    player:setLy(location.y)
                                    player:setLz(location.z)
                                    player:setX(location.x)
                                    player:setY(location.y)
                                    player:setZ(location.z)
                                    player:setHaloNote(string.format(getText("UI_APTweaks_TeleportSuccess"), player_flags.warpCommandWarp), 0, 255, 0, 500)
                                    -- Debido a que el juego hará un ajuste en la localización del jugador al final de cualquier forma, lo
                                    --  que llamará de nuevo a RestorePlayerFlags, puede ignorarla aquí.
                                    -- Aún así las vanderas deben limpiarse ahora para asegurarse de que el comando esté disponble
                                    --  inmediatamente al siguente tick. Es una medida de escape.
                                    RestorePlayerFlags(true, false, nil)
                                end
                            else
                                player_flags.warpCommandCooldownSecondsLeft = math.abs(secondsElapsed - (config.teleportDelay + config.teleportCooldown))

                                if secondsElapsed == config.teleportDelay + config.teleportCooldown then
                                    RestorePlayerFlags(false, true, nil)
                                end
                            end
                        end
                    end
                end
                -- Si el jugador se movió.
                if playerX ~= player_flags.lastLocation.x or playerY ~= player_flags.lastLocation.y or playerZ ~= player_flags.lastLocation.z then
                    RestorePlayerFlags(true, true, {x = playerX, y = playerY, z = playerZ})

                -- Si el jugador no se ha movido. En este bloque se procesa el tiempo AFK.
                else
                    if config.afkSystemEnabled then

                        if player_flags.iddleTickStart == nil then
                            player_flags.iddleTickStart = tick
                        end
                        local secondsElapsed, isWholeSecond = SecondsElapsed(tick, player_flags.iddleTickStart)

                        if isWholeSecond then

                            if secondsElapsed >= config.afkStart then

                                if secondsElapsed == config.afkStart then
                                    player_flags.isAfk = true
                                end
                                if player_flags.isAfk then
                                    player:setHaloNote(getText("UI_APTweaks_Afk"), 255, 0, 0, 500)

                                    if secondsElapsed == config.afkStart + config.afkKick then
                                        getCore():exitToMenu()
                                    end
                                end
                            end
                        end
                    end
                end
            else
                -- Evita que el teletransporte ocurra si el jugador asociado al cliente muere o el cliente sale del servidor.
                -- Aunque esto nunca se disparó durante las pruebas, está aquí como medida de escape.
                RestorePlayerFlags(true, false, nil)
            end
        end
    end
end

Events.OnGameStart.Add(OnGameStart)
Events.OnAddMessage.Add(OnAddMessage)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnServerCommand.Add(OnServerCommand)