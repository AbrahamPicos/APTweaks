-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Client_Commands")

local modID = aptweaks.modID
local sessionID = aptweaks.sessionID
local APTweaksVars = aptweaks.APTweaksVars

local format = aptweaks.format
local unpack = aptweaks.unpack
local SecondsElapsed = aptweaks.SecondsElapsed
local ProcessCommandResult = aptweaks.ProcessCommandResult
local WarpComamand = commands.WarpComamand
local SafehouseCommand = commands.SafehouseCommand

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local getText = aptweaks.getText
local getCore = aptweaks.getCore
local isClient = aptweaks.isClient
local getPlayer = aptweaks.getPlayer
local SafeHouse = aptweaks.SafeHouse
local sendClientCommand = aptweaks.sendClientCommand

local ISChat = ISChat
local doKeyPress = doKeyPress
local stringStarts = luautils.stringStarts
-- El mapa de datos de APTweaks. Se obtiene desde el servidor.
local aptweaks_data
-- Un contador experimental para probar si usar GameTime gettimedelta puede volver consistente el tiempo.
local GenericTimeCounter = 0
-- Almacena el chatStream resultante de la última ejecución de la función OnShitchStream.
-- Esto se usa para determinar si OnShitchStream se ha saltado índices.
--local previousStreamIndex = 1


-- Variables para el jugador controladas por el evento tick; Son útiles para el comando warp y el sistema AFK.
local player_flags = {
    -- El jugador asociado al cliente. Se establece a un IsoPlayer si existe en el evento OnTick. Se reestablece a nil si
    --- deja de existir.
    player = nil,
    -- Si el jugador ha enviado al servidor una solicitud de teletransporte.
    InTeleport = false,
    -- La última localización del jugador. Se reajusta en cada tick si su localización ha cambiado.
    lastLocation = {x = nil, y = nil, z = nil},
    -- Es el tick a partir del cual el jugador ha estado quieto. Se reestablece a nil si el jugador se mueve.
    iddleTickStart = nil,
    -- Si el jugador está AFK. Se establece en true si iddleTickStart ha sido diferente de nil durante AfkStart segundos.
    --- Se reestablece a false si el jugador se mueve.
    isAfk = false,
    -- Si el jugador está ejecutando el comando warp. Se establece en true cuando el jugador usó el comando warp. Se
    --- reestablece a false si el jugador se movió o fue teletransportado.
    inWarpCommand = false,
    -- El warp al que el jugador se teletransportará al finalizar TeleportDelay si inWarpCommand es true. Se establece como
    --- args[1] cuando este puede usarse como indice para obtener coordenadas en la tabla warps. Se reestablece a false si
    --- el jugador se movió o fue teletransportado.
    warpCommandWarp = nil,
    -- El tick cuando inició el comando warp. Se establece como el número de tick en el que inWarpCommand se estableció como
    --- true. Se reestablece a nil si el jugador se movió o fue teletransportado.
    warpCommandTickStart = nil,
    -- La cantidad de segundos que faltan para que el jugador pueda teletransportarse otra vez. Sólo se usa para el mensaje de
    --- error que el jugador ve cuando intenta teletrasportarse en cooldown. Se reestablece a nil cuando ha pasado el tiempo en
    --- TeleportDelay.
    warpCommandCooldownSecondsLeft = nil}

-- Las definiciones de los comandos de APTweaks.
local aptweaks_commands = {
    {name = "aptweaks", command = "/aptweaks ", tabID = 1},
    {name = "warp", command = "/warp ", tabID = 1},
    {name = "safezone", command = "/safezone ", tabID = 1}}

-- Registrando los comandos de APTweaks en la clase ISChat.
-- Hay que verificar si ya están para poder recargar los scripts.
for i = 1, #aptweaks_commands do
    table.insert(ISChat.allChatStreams, aptweaks_commands[i])
end

local old_onSwitchStream = ISChat.onSwitchStream
local old_onCommandEntered = ISChat.onCommandEntered

-- Una función provisional para probar si esto está funcionando.
local function ProcessAptweaksCommand(command, args)
    print("Ejecutaste el comando de APTweaks: " .. command)
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onCommandEntered de la clase Lua IsChat.
-- Añade la lógica adicional necesaria para ejecutar los comandos de APTweaks.
-- NOTA: No retornamos después de procesar el comando APTweaks para permitir que otros mods también lo manejen.
function ISChat:onCommandEntered()

    -- Por alguna razón las cosas que necesito aquí no están en self.
    local chat = ISChat.instance
    -- Este es el texto que había en el cuadro de entrada de texto del chat al momento en el que se llamó a la función, tal cual 
    --  como el usuario lo escribió. Tenga en cuenta que incluso el texto que se ingresó sin un "/" al inicio se interpreta como
    --  un comando.
    local textEntry = chat.textEntry:getText()

    if textEntry and textEntry ~= "" then
        local aptweaksCommand

        for _, command in ipairs(aptweaks_commands) do

            if chat.currentTabID == command.tabID then

                -- stringStarts devuelve true si el primer string coincide con el segundo, pero sólo los compara hasta el tamaño
                --   del segundo string. Es decir que por ejemplo: `stringStarts("holaquehace", "holaq")` será true.
                if stringStarts(textEntry, command.command) then
                    aptweaksCommand = command.command

                -- Actualmente ningún comando de APTweaks tiene una versión corta, pero dejé esto por si acaso.
                elseif command.shortCommand and stringStarts(textEntry, command.shortCommand) then
                    aptweaksCommand = command.shortCommand
                end

                -- No se establece chat.chatText.lastChatCommand debido a que, -aunque funcionaría-, es mejor reservarlo sólo a
                --  los comandos de chat, como el /say, /whisper, y /all.
                -- No estoy seguro de qué hacen muchas cosas aquí, pero alguna previene que el chat recupere el foco al ejecutar
                --  el comando.
                if aptweaksCommand then
                    -- Se limpia el campo de texto para evitar que vanilla lo procese otra vez.
                    chat.textEntry:setText("")
                    -- Se supone que esto registra la ejecución del comando en el log, pero no lo veo.
                    chat:logChatCommand(textEntry)
                    ProcessAptweaksCommand(command.name, string.sub(textEntry, #aptweaksCommand))
                    -- Evita que el cliente pueda volver a usar la entrada de texto del chat.
                    doKeyPress(false)
                    -- El tiempo en ticks que debe pasar hasta que que doKeyPress se restablezca a true.
                    chat.timerTextEntry = 20
                    break
                end
            end
        end
    end

    -- Evita errores potencialmente castatróficos causados por otros mods.
    if old_onCommandEntered then
        local success, err = pcall(old_onCommandEntered, self)
        if not success then
            print("APTweaks: Error al ejecutar función heredada de onCommandEntered: " .. tostring(err))
        end
    end
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: onSwitchStream de la clase Lua ISChat.
-- Añade a la primitiva tabcomplete del juego los comandos de APTweaks, al mismo tiempo que mantiene la compatibilidad con otros
--  mods.
ISChat.onSwitchStream = function ()
    local curTxtPanel = ISChat.instance.chatText
    -- Si los otros mods respetan el órden de ejecución, todos tendrían que tener la oportunidad de almacenar el streamID anterior.
    local previousStreamIndex = curTxtPanel.streamID

    old_onSwitchStream()

    local allChatStreams = curTxtPanel.chatStreams
    -- Este es ahora el índice actual en lugar del anterior, porque la función heredada acaba de cambiarlo.
    local actualStreamIndex = curTxtPanel.streamID

    -- Si el índice actual no es igual al índice anterior +1. Esto significa que la función heredada ignoró uno o más índices. Esto
    --  puede ocurrir porque el cliente no debería verlos, -como cuando no tiene permisos suficientes-, o porque no pueden ser
    --  comprobados por el método checkPlayerCanUseChat. Esto último ocurre con todos los comandos de mods.
    -- Si la función heredada es de un mod bien programado, ignoró lo índices porque no eran suyos.
    if actualStreamIndex ~= previousStreamIndex + 1 then
        -- La función vanilla regresa al índice 1 cuando ha recorrido todos los streams.
        -- Esta variable determina la cantidad máxima de índices que se evaluarán. Si la función vanilla regresó al primer índice,
        --  se evaluará desde el índice actual (previousStreamIndex + 1) hasta el índice final (#allChatStreams), hasta encontrar
        --  el siguiente comando de APTweaks. De lo contrarío, sólo evaluará los índices desde el índice anterior, hasta el actual.
        --- (i = previousStreamIndex + 1, actualStreamIndex - 1).
        local maxIndex = (actualStreamIndex == 1 and #allChatStreams or actualStreamIndex - 1)
        local isAptweaksCommand = false

        for i = previousStreamIndex + 1, maxIndex do

            -- Es posible optimizar esto si convierto aptweaks_commands en un mapa.
            for j = 1, #aptweaks_commands do

                if allChatStreams[i] and allChatStreams[i].command == aptweaks_commands[j].command then
                    isAptweaksCommand = true
                    ISChat.instance.textEntry:setText(aptweaks_commands[j].command)
                    curTxtPanel.streamID = i
                    break
                end
            end
            if isAptweaksCommand then break end
        end
    end
    previousStreamIndex = curTxtPanel.streamID
end

-- Rellena labla que almacena el mapa de datos de APTweaks.
-- APTweaks no necesita crear o eliminar subtablas en tiempo de ejecución en en su mapa de datos, así que sólo las sobrescribe.
---@param data table La tabla con los datos que se rellenarán.
local function syncData(data)

    for k, v in pairs(data) do
        aptweaks.aptweaks_data[k] = v
    end
    aptweaks_data = aptweaks.aptweaks_data
end

-- En el evento OnReceiveGlobalModData. Obtiene la Global ModData de APTweaks al iniciar la sesión.
---@param newGame boolean Si Global ModData se inicializa en un nuevo guardado.
local function OnInitGlobalModData(newGame)
    -- ModData.get() no admite puntos, por lo que no puedo usar modID.
    syncData(ModData.get("aptweaks"))
end

-- En el evento OnReceiveGlobalModData. Obtiene la Global ModData de APTweaks si se actualizó posteriormente.
-- Se rellena una tabla vacía en lugar se asignarla directamente para que sea accesible por todos los módulos.
---@param key string El nombre de la tabla que se está recibiendo.
---@param data table La tabla que se está recibiendo en sí.
local function OnReceiveGlobalModData(key, data)

    if key == "aptweaks" then
        syncData(data)
    end
end

-- En el evento OnAddMessage. Intercepta los mensajes, y convierte su cadana de texto a una tabla cuyos elementos usa
--- para determinar si cliente está intentando ejecutar algún comando de APTweaks.
---@param message table
---@param tabId number
local function OnAddMessage(message, tabId)
    local player = player_flags.player
    print(aptweaks_data.warps.rosewood.x)

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
                local args  = {unpack(words, 4)} -- Los argumentos del comando. El juego usa Lua 3.4(unpack warn).
                local result = nil

                -- El comando principal de aptweaks
                if command == "aptweaks" then

                    if #args <= 1 then

                        if #args == 1 then
                            local subcommand = args[1]

                            if subcommand == "cleardata" then
                                result = {text = "Espere un momento", command = "clearData", data = {}}
                            end
                        else
                            result = {text = "Faltan argumentos. Use /aptweaks cleardata"}
                        end
                    else
                        result = {text = "Demasiados argumentos"}
                    end

                -- El comando del sistema de mensajería interno.
                elseif command == "APTM-" .. sessionID then
                    result = {text = table.concat(args, " ")}

                -- El comando warp. 
                elseif command == getText("UI_APTweaks_WarpCommand") and APTweaksVars.WarpSystemEnabled then
                    result = WarpComamand(player, args)

                -- El comando safezone.
                elseif command == "safezone" and APTweaksVars.SafehouseSystemEnabled then
                    result = SafehouseCommand(player, args)

                -- El comando de pruebas.
                elseif command == "something" then
                    result = {text = "Espere un momento...", command = "something", data = {}}
                end
                ProcessCommandResult(player, result, message)
            end
        end
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

            if player_flags.InTeleport then
                player_flags.InTeleport = false
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

-- En el evento OnServerCommand. Procesa los comandos enviados desde el servidor al cliente, los que tienen que ver con APTweaks.
--- Incluye el servicio de mensajería interno y la reclamación de safehouses.
---@param module string Suele usarse la ID del mod. Sirve para diferenciar entre comandos enviados por otros mods.
---@param command string El comando en sí, es como el "asunto" en un correo electrónico.
---@param args table Los argumentos del comando. Es una tabla que puede contener cualquier cosa.
local function OnServerCommand(module, command, args)

    if module == modID then
        local player = player_flags.player

        if player ~= nil then
            local result = nil
            local data = nil

            if command == "createSafehouse" then
                local username = player:getUsername()
                local sucess = false
                local text = nil
                local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2
                local safezone = SafeHouse.addSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1, username, false)

                if safezone ~= nil then
                    safezone:setTitle(format("refugio de %s", username))
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

                -- Hace falta sobreescribir también la última localización, o voverá ahí luego de la teletransportación.
                player:setX(x); player:setY(y); player:setZ(z); player:setLx(x); player:setLy(y); player:setLz(z)
                player:setHaloNote(format(getText("UI_APTweaks_TeleportSuccess"), player_flags.warpCommandWarp), 0, 255, 0, 500)
                -- Debido a que el juego hará un ajuste en la localización del jugador al final de cualquier forma, lo
                --  que llamará de nuevo a RestorePlayerFlags, puede ignorarla aquí.
                -- Aún así las banderas deben limpiarse ahora para asegurarse de que el comando esté disponble
                --  inmediatamente al siguente tick. Es una medida de escape.
                RestorePlayerFlags(true, false, nil)

                result = {command = "teleportSuccess", data = {}}

            elseif command == "messageCommand" then
                result = {text = args.text}
            end
            ProcessCommandResult(player, result, nil)
        end
    end
end

-- En el evento OnTick. Verifica constantemente la localización del cliente, de tenerla, y redefine las variables en su
--- tabla de banderas según la lógica que procesa.
---@param tick number
local function OnTick(tick)

    if isClient() then
        local warpSystemEnabled, afkSystemEnabled = APTweaksVars.WarpSystemEnabled, APTweaksVars.AfkSystemEnabled

        if warpSystemEnabled or afkSystemEnabled then
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

                -- Dentro de este bloque se procesan el teleport delay, y el teleport cooldown. También se solicita la teletransportación.
                if warpSystemEnabled then

                    if player_flags.warpCommandTickStart ~= nil and player_flags.InTeleport == false then
                        local secondsElapsed, isWholeSecond = SecondsElapsed(tick, player_flags.warpCommandTickStart)

                        if isWholeSecond then

                            if player_flags.inWarpCommand then
                                player:setHaloNote(format(getText("UI_APTweaks_TeleportDelaying"), math.abs(secondsElapsed - APTweaksVars.TeleportDelay)), 0, 255, 0, 500)

                                if secondsElapsed == APTweaksVars.TeleportDelay then
                                    player_flags.InTeleport = true
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
                if playerX ~= player_flags.lastLocation.x or playerY ~= player_flags.lastLocation.y or playerZ ~= player_flags.lastLocation.z then
                    RestorePlayerFlags(true, true, {x = playerX, y = playerY, z = playerZ})

                -- Si el jugador no se ha movido. En este bloque se procesa el tiempo AFK.
                else
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
                -- Evita que el teletransporte ocurra si el jugador asociado al cliente muere o el cliente sale del servidor.
                -- Aunque esto nunca se disparó durante las pruebas, está aquí como medida de escape.
                RestorePlayerFlags(true, false, nil)
            end
        end
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.OnReceiveGlobalModData.Add(OnReceiveGlobalModData)
Events.OnAddMessage.Add(OnAddMessage)
Events.OnTick.Add(OnTick)
Events.OnServerCommand.Add(OnServerCommand)

print("[APTweaksDebug] APTweaks_Client.lua is loaded.")