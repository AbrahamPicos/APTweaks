-- HolaMundo.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.
-- Contributors: Stevej.

-- Constantes que controlan algunos aspectos configurables del script:
local config = {
    --- El retraso de la teletransportación. Dentro de este tiempo se cancelará si el jugador se mueve.
    teleportDelay = 5;
    --- El tiempo de enfriamiento de la teletransportación. El jugador no podrá volver a teletransportarse dentro de este tiempo.
    teleportCooldown = 30;
    --- El tiempo que el jugador debe estar quieto para considerarse AFK.
    afkStart = 60;
    --- El tiempo que el jugador debe continuar quieto luego de considerarse AFK para forzarlo a salir al menú principal.
    afkKick =  60
}

-- Variables para el jugador controladas por el evento tick; Son útiles para el comando warp y el sistema AFK.
local player_flags = {
    --- El jugador asociado al cliente. Se establece a un IsoPlayer si existe en el evento OnTick. Se reestablece a nil si
    ---  seja de existir.
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
    --- La cantidad de segundos que falta para que el jugador pueda teletransportarse otra vez. Sólo se usa para el mensaje de
    ---  error que el jugador ve cuando intenta teletrasportarse en cooldown. Se reestablece a nil cuando ha pasado el tiempo en
    ---  releportDelay.
    warpCommandCooldownSecondsLeft = nil
}

--- Un contador experimental para probar si usar gametime gettimedelta puede volver consistente el tiempo.
local GenericTimeCounter = 0

-- Las localizaciones de cada warp. El punto al que el jugador será teletransportado. Actualmente cell no tiene uso.
local warps = {
    westpoint = {x = 11889, y = 6862, z = 0, cell = {x = 39, y = 22}},
    rosewood = {x = 8078, y = 11419, z = 0, cell = {x = 26, y = 38}},
    riverside = {x = 6448, y = 5313, z = 0, cell = {x = 21, y = 17}},
    louisville = {x = 12650, y = 2020, z = 0, cell = {x = 42, y = 6}}
}

-- En el evento OnAddMessage. Intercepta los mensajes, y convierte su cadana de texto a una tabla cuyos elementos usa
--  para determinar si cliente está intentando ejecutar el comando warp.
--- @param message table
--- @param tabId number
local function OnAddMessage(message, tabId)
    local player = player_flags.player

    if player ~= nil then
        -- La tabla que almacena cada palabra incuida en la cádena message.
        -- Tenga en cuenta que esta tabla contiene todo el mensaje, incluidas las palabras "Unknown command".
        local args = {}

        for word in string.gmatch(message:getText(), "%S+") do
            table.insert(args, word)
        end

        if #args >= 3 then

            if args[1] == "Unknown" and args[2] == "command" and args[3] == "warp" then

                if #args <= 4 then

                    if #args == 4 then
                        -- El warp que el cliente ingresó, tal cual como lo escribió.
                        local warp = args[4]

                        if warps[warp] ~= nil then

                            if player:getVehicle() == nil then

                                if player_flags.iddleTickStart ~= nil then

                                    if not player_flags.inWarpCommand then

                                        if player_flags.warpCommandTickStart == nil then
                                            player_flags.inWarpCommand = true
                                            player_flags.warpCommandWarp = warp
                                            player_flags.warpCommandCooldownSecondsLeft = config.teleportCooldown

                                            message:setText(string.format("<RGB:0,1,0>Teletransportadando a %s...", warp))
                                        else
                                            message:setText(string.format("<RGB:1,0,0>Debe esperar %s segundos antes de volver a ejecutar ese comando.", player_flags.warpCommandCooldownSecondsLeft))
                                        end
                                    else
                                        message:setText("<RGB:1,0,0>Ya se esta ejecutando ese comando.")
                                    end
                                else
                                    message:setText("<RGB:1,0,0>No puede ejecutar ese comando mientras se mueve.")
                                end
                            else
                                message:setText("<RGB:1,0,0>No puede ejecutar ese comando dentro de un vehiculo.")
                            end
                        -- En este bloque, usando como elementos las llaves en la tabla warps, crea un string con el formato
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
                                    aviableWarps = aviableWarps .. ", y " .. tostring(existingWarp)
                                else
                                    aviableWarps = aviableWarps .. ", " .. tostring(existingWarp)
                                end
                            end
                            message:setText(string.format("<RGB:1,0,0>Warp %s no encontrado. Los warps disponibles son %s.", warp, aviableWarps))
                        end
                    else
                        message:setText("<RGB:1,0,0>Debe especificar un warp. Use /warp [warp].")
                    end
                else
                    message:setText("<RGB:1,0,0>Demasiados argumentos. Use /warp [warp].")
                end
            end
        end
    end
end

-- Restaura las vanderas referentes al teleport cooldown.
local function RestoreCooldownFlags()
    player_flags.warpCommandTickStart = nil
    player_flags.warpCommandCooldownSecondsLeft = nil
end

-- Restaura las las variables del jugador a sus valores por defecto para su posterior reutilización.
--- @param allFlags boolean Si debe hacerse un hard restore, lo que borrará todas las banderas.
--- @param cooldownFlags boolean Si deberían borrarse las banderas de cooldown, independientemente de todas las demás.
--- @param value (table|nil) El valor que la bandera lastLocation tendrá. Puede ignorarse completamente si allFlags es falso.
local function RestorePlayerFlags(allFlags, cooldownFlags, value)
    local player = player_flags.player

    if allFlags then
        value = value or {x = nil, y = nil, z = nil}

        if player_flags.iddleTickStart ~= nil then

            if player_flags.isAfk == true then
                player_flags.isAfk = false

                if player ~= nil then
                    player:setHaloNote("Ya no estas AFK.", 0, 255, 0, 500)
                end
            end
            player_flags.iddleTickStart = nil
        end

        if player_flags.inWarpCommand then

            if cooldownFlags then
                RestoreCooldownFlags()

                if player ~= nil then
                    player:setHaloNote("Teletransportacion cancelada.", 255, 0, 0, 500)
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

-- En el evento OnTick. Verifica constantemente la localización del cliente, de tenerla, y redefine las variables en su
--  tabla de banderas según la lógica que procesa.
--- @param tick number
local function OnTickEvenPaused(tick)

    if isClient() then
        local player = getPlayer()
        local playerX = player:getX()
        local playerY = player:getY()
        local playerZ = player:getZ()

        player_flags.player = player

        -- Si el jugador existe y tinen coordenadas.
        if player ~= nil and playerX ~= nil and playerY ~= nil and playerZ ~= nil then

            -- El evento OnAddMessage no puede saber cuál es el tick actual, ya que no hay un método para eso en la clase GameTime.
            --  En cambio, usa usa esta variable para indicar a este evento que tiene que registrarlo.
            if player_flags.inWarpCommand then

                if player_flags.warpCommandTickStart == nil then
                    player_flags.warpCommandTickStart = tick
                end
            end

            -- Dentro de este bloque se procesan el teleport delay, y el teleport cooldown. También ocurre la teletransportación.
            if player_flags.warpCommandTickStart ~= nil then
                local secondsElapsed, isWholeSecond = SecondsElapsed(tick, player_flags.warpCommandTickStart)

                if isWholeSecond then

                    if player_flags.inWarpCommand then
                        player:setHaloNote(string.format("Teletransportando. %s...", math.abs(secondsElapsed - config.teleportDelay)), 0, 255, 0, 500)

                        if secondsElapsed == config.teleportDelay then
                        local location = warps[player_flags.warpCommandWarp]

                            -- Es necesario sobreescribir primero la última localización, o volverá ahí luego de la teletransportación.
                            player:setLx(location.x)
                            player:setLy(location.y)
                            player:setLz(location.z)
                            player:setX(location.x)
                            player:setY(location.y)
                            player:setZ(location.z)
                            player:setHaloNote(string.format("Teletransportado a %s.", player_flags.warpCommandWarp), 0, 255, 0, 500)
                            -- Debido a que el juego hará un ajuste en la localización del jugador al final de cualquier forma, lo
                            --  que llamará de nuevo a RestorePlayerFlags, puede ignorarla aquí.
                            -- Aún así las banderas deben limpiarse ahora para asegurarse de que el comando esté disponble
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
            -- Si el jugador se movió.
            if playerX ~= player_flags.lastLocation.x or playerY ~= player_flags.lastLocation.y or playerZ ~= player_flags.lastLocation.z then
                RestorePlayerFlags(true, true, {x = playerX, y = playerY, z = playerZ})

            -- Si el jugador no se ha movido. En este bloque se procesa el tiempo AFK.
            else
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
                            player:setHaloNote("Ahora estas AFK.", 255, 0, 0, 500)

                            if secondsElapsed == config.afkStart + config.afkKick then
                                getCore():exitToMenu()
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

local function OnGameStart()
    print("[APTweaksDebug] HolaMundo.lua is loaded.")
end

Events.OnAddMessage.Add(OnAddMessage)
Events.OnTickEvenPaused.Add(OnTickEvenPaused)
Events.OnGameStart.Add(OnGameStart)

-- OPTIMIZACIONES PENDIENTES: 
-- Elimitar los tostrings donde no son necesarios.
--   Creo que ya los eliminé todos, creía que era como en java.
-- Usar la concatenación directa en lugar de string.format.
--   Creo que vale la pena dejar todos para volver el código más legible.
-- No usar tablas a no ser que requiera poder iterar las variables.
--   Diría que es mejor ordenar las variables en tablas para volver el código más legible.

-- OTROS CAMBIOS PENDIENTES:
-- Tal vez sea mejor usar la simulación de clases, como el resto del código Lua del juego. Aunque no encuentro suficientes
--  motivos. Empeora el rendimiento y la legibilidad.
-- Corregir la inconsistencia del tiempo.
-- Probar si es posible usar el método isMoving() o algo así, en lugar de almacenar coordenadas.
-- Mejorar la autodocumentación.
-- Experimentar con técnicas de almacenamiento de datos del lado del servidor para añadir el comando setwarp, y volver útil
--  el teleport cooldown(actualmente el cooldown se reinicia si el jugador sale del servidor, lo que es un exploit importante
--  si el cooldown se configura muy largo).
-- Pulir el funcionamiento de la cancelación de la teletrasportación, para hacer que no se cancele cuando el jugador gira 
--  usando el cursor isométrico, y se cancele cuando es atacado o ataca a alguien.
-- Es probable que cambie por completo el sistema anti-AFK, para que únicamente detecte las pulsaciones de teclas en lugar de
--  lo que se se hace ahora.