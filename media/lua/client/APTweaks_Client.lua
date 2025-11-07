-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local player_flags = aptweaks.player_flags

local SecondsElapsed = aptweaks.SecondsElapsed
local ProcessCommandResult = aptweaks.ProcessCommandResult

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local getText = aptweaks.getText
local getCore = aptweaks.getCore
local isClient = aptweaks.isClient
local getPlayer = aptweaks.getPlayer
local SafeHouse = aptweaks.SafeHouse
local sendClientCommand = aptweaks.sendClientCommand

-- El mapa de datos de APTweaks. Se obtiene desde el servidor.
-- Esto rompe el estilo.
local aptweaks_data = nil
-- Un contador experimental para probar si usar GameTime gettimedelta puede volver consistente el tiempo.
local GenericTimeCounter = 0

-- Rellena labla que almacena el mapa de datos de APTweaks.
-- La tabla en la que se almacena la ModData localmente se encuentra en el módulo común APTweaks.lua. Esto permite que sea
--  accesible desde todos los módulos del mod.
-- La primera vez que se ejecuta rellena una tabla vacía, y cuando se actualiza, simplemente sobrescribe lo que ya hay. Esto es
--  prudente debido a que APTweaks no necesita crear o eliminar subtablas en su mapa de datos en tiempo de ejecución.
---@param data table La tabla con los datos que se rellenarán.
local function syncData(data)

    for k, v in pairs(data) do
        aptweaks.aptweaks_data[k] = v
    end
    aptweaks_data = aptweaks.aptweaks_data
end

-- En el evento OnInitGlobalModData. Obtiene la Global ModData de APTweaks al iniciar la sesión.
---@param newGame boolean Si GlobalModData se inicializa en un nuevo guardado. Esto no es relevante para este mod.
local function OnInitGlobalModData(newGame)
    syncData(ModData.get("aptweaks"))
end

-- En el evento OnReceiveGlobalModData. Obtiene la Global ModData de APTweaks si se actualizó posteriormente.
-- Esto ocurre cuando el servidor vuelve a enviar la tabla a todos los clientes usando `ModData.transmit("aptweaks")`.
---@param key string El nombre de la tabla que se está recibiendo.
---@param data table La tabla que se está recibiendo en sí.
local function OnReceiveGlobalModData(key, data)

    if key == "aptweaks" then
        syncData(data)
    end
end

-- Restaura las banderas del jugador a sus valores por defecto para su posterior reutilización.
---@param allFlags boolean Si debe hacerse un hard restore, lo que borrará todas las banderas.
---@param cooldownFlags boolean Si deberían borrarse las banderas de cooldown, independientemente de todas las demás.
---@param value (table|nil) El valor que la bandera lastLocation tendrá. Puede ignorarse completamente si allFlags es false.
local function RestorePlayerFlags(allFlags, cooldownFlags, value)
    local player = player_flags.player

    -- Restaura las banderas referentes al teleport cooldown.
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

            if player_flags.inTeleport then
                player_flags.inTeleport = false
            end

            if player_flags.warpCommandWarp ~= nil then
                player_flags.warpCommandWarp = nil
            end
            player_flags.inWarpCommand = false
        end
        player_flags.lastX, player_flags.lastY, player_flags.lastZ = value.x, value.y, value.z

    else

        if cooldownFlags then
            RestoreCooldownFlags()
        end
    end
end

-- En el evento OnServerCommand. Procesa los comandos enviados desde el servidor al cliente, los que tienen que ver con APTweaks.
--- Incluye el servicio de mensajería interno y la reclamación de safehouses.
---@param module string Suele usarse la ID del mod. Sirve para diferenciar entre comandos enviados por otros mods.
---@param command string El comando en sí, es como el "asunto" en un correo electrónico.
---@param args table Los argumentos del comando. Es una tabla que puede contener cualquier cosa.
local function OnServerCommand(module, command, args)
    local player = player_flags.player

    if not (player ~= nil and module == modID) then return end

    local result = nil
    local data = nil

    if command == "createSafehouse" then
        local username = player:getUsername()
        local sucess = false
        local text = nil
        local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2
        local safezone = SafeHouse.addSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1, username, false)

        if safezone ~= nil then
            safezone:setTitle(string.format("refugio de %s", username))
            -- Crear safehouses con el método anterior trae un par de problemas, que espero se solucionen usando los métodos
            --  siguientes. Tendrían que hacerlo, ya que son los que usa el código base del juego, y funciona bien ahí.
            safezone:setOwner(username)
            safezone:updateSafehouse(player)
            safezone:syncSafehouse()

            text = "Safehouse creada exitosamente."
            sucess = true
        else
            text = "Ocurrio un error desconocido al crear la safehouse."
        end
        data = {sucess = sucess, areaID = args.areaID, blocked = username}
        result = {text = text, command = "claimCommandSucess", data = data}

    elseif command == "teleportPlayer" then
        local x, y ,z = args.x, args.y, args.z

        -- Hace falta sobreescribir también la última localización, o volverá ahí luego de la teletransportación.
        player:setX(x); player:setY(y); player:setZ(z); player:setLx(x); player:setLy(y); player:setLz(z)
        player:setHaloNote(string.format(getText("UI_APTweaks_TeleportSuccess"), player_flags.warpCommandWarp), 0, 255, 0, 500)
        -- Debido a que el juego hará un ajuste en la localización del jugador al final de cualquier forma, lo
        --  que llamará de nuevo a RestorePlayerFlags, puede ignorarla aquí.
        -- Aún así las banderas deben limpiarse ahora para asegurarse de que el comando esté disponble
        --  inmediatamente al siguente tick. Es una medida de escape.
        RestorePlayerFlags(true, false, nil)

        result = {command = "teleportSuccess", data = {}}

    elseif command == "messageCommand" then
        result = {text = args.text}
    end
    ProcessCommandResult(player, result)
end

-- En el evento OnTick. Verifica constantemente la localización del cliente, -de tenerla-, y redefine las variables en su
--- tabla de banderas según la lógica que procesa.
---@param tick number
local function OnTick(tick)
    local warpSystemEnabled, afkSystemEnabled = APTweaksVars.WarpSystemEnabled, APTweaksVars.AfkSystemEnable

    if not isClient() and (warpSystemEnabled or afkSystemEnabled) then return end

    local player = getPlayer()
    local playerX, playerY, playerZ = player:getX(), player:getY(), player:getZ()

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

        -- Si el sistema de warps está habilitado.
        -- Dentro de este bloque se procesan el teleport delay y el teleport cooldown. También se solicita la teletransportación.
        if warpSystemEnabled then

            if player_flags.warpCommandTickStart ~= nil and player_flags.inTeleport == false then
                local secondsElapsed, isWholeSecond = SecondsElapsed(tick, player_flags.warpCommandTickStart)

                if isWholeSecond then

                    if player_flags.inWarpCommand then
                        player:setHaloNote(string.format(getText("UI_APTweaks_TeleportDelaying"), math.abs(secondsElapsed - APTweaksVars.TeleportDelay)), 0, 255, 0, 500)

                        if secondsElapsed == APTweaksVars.TeleportDelay then
                            player_flags.inTeleport = true
                            sendClientCommand(player, modID, "teleportNeeded", {warp = player_flags.warpCommandWarp})
                        end
                    else
                        player_flags.warpCommandCooldownSecondsLeft = math.abs(secondsElapsed - (APTweaksVars.TeleportDelay + APTweaksVars.TeleportCooldown))

                        if secondsElapsed == APTweaksVars.TeleportDelay + APTweaksVars.TeleportCooldown then
                            RestorePlayerFlags(false, true, nil)
                        end
                    end
                end
            end
        end

        -- Si el jugador se movió.
        if playerX ~= player_flags.lastX or playerY ~= player_flags.lastY or playerZ ~= player_flags.lastZ then
            RestorePlayerFlags(true, true, {x = playerX, y = playerY, z = playerZ})

        -- Si el jugador no se ha movido.
        else
            -- Si el sistema Anti-AFK está habilitado.
            -- Aquí se cuenta el tiempo AFK, y se procesa la desconexión por AFK.
            if afkSystemEnabled then

                if player_flags.iddleTickStart == nil then
                    player_flags.iddleTickStart = tick
                end
                local secondsElapsed, isWholeSecond = SecondsElapsed(tick, player_flags.iddleTickStart)

                if isWholeSecond then

                    if secondsElapsed >= APTweaksVars.AfkStart then

                        if secondsElapsed == APTweaksVars.AfkStart then
                            player_flags.isAfk = true
                        end

                        if player_flags.isAfk then
                            player:setHaloNote(getText("UI_APTweaks_Afk"), 255, 0, 0, 500)

                            if secondsElapsed == APTweaksVars.AfkStart + APTweaksVars.AfkKick then
                                getCore():exitToMenu()
                            end
                        end
                    end
                end
            end
        end
    else
        print("El jugador se acaba de morir o no tiene coordenadas.")
        -- Evita que el teletransporte ocurra si el jugador asociado al cliente muere o el cliente sale del servidor.
        -- Aunque esto nunca se disparó durante las pruebas, está aquí como medida de escape.
        RestorePlayerFlags(true, false, nil)
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnReceiveGlobalModData.Add(OnReceiveGlobalModData)
Events.OnTick.Add(OnTick)
Events.OnServerCommand.Add(OnServerCommand)

print("[APTweaksDebug] APTweaks_Client.lua is loaded.")
