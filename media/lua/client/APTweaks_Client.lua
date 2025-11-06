-- APTweaks_Client.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks, commands = require("APTweaks"), require("APTweaks_Client_Commands")

local modID = aptweaks.modID
local APTweaksVars = aptweaks.APTweaksVars
local player_flags = aptweaks.player_flags

local format = aptweaks.format
local SecondsElapsed = aptweaks.SecondsElapsed
local ProcessCommandResult = aptweaks.ProcessCommandResult
local WarpComamand = commands.WarpComamand
local SafehouseCommand = commands.SafehouseCommand

local Events = aptweaks.Events
local ModData = aptweaks.ModData
local getText = aptweaks.getText
local getCore = aptweaks.getCore
local SafeHouse = aptweaks.SafeHouse
local sendClientCommand = aptweaks.sendClientCommand

local ISChat = ISChat
local isClient = isClient
local getPlayer = getPlayer
local doKeyPress = doKeyPress
local stringStarts = luautils.stringStarts

local old_onSwitchStream = ISChat.onSwitchStream
local old_onCommandEntered = ISChat.onCommandEntered
local old_addLineInChat = ISChat.addLineInChat
local old_UpdateChatPrefixSettings = ISChat.updateChatPrefixSettings

-- El mapa de datos de APTweaks. Se obtiene desde el servidor.
local aptweaks_data
-- Almacena los mensajes personalizados del mod.
local customMessages = {}
-- Un contador experimental para probar si usar GameTime gettimedelta puede volver consistente el tiempo.
local GenericTimeCounter = 0

-- Las definiciones de los comandos de APTweaks.
local aptweaks_commands = {
    {name = "aptweaks", command = "/aptweaks ", tabID = 1},
    {name = "warp", command = "/warp ", tabID = 1},
    {name = "safezone", command = "/safezone ", tabID = 1}}

-- Registrando los comandos de APTweaks en la clase ISChat.
-- Verifica si ya están para poder recargar el archivo.
for i = 1, #aptweaks_commands do
    local needed = false

    for _, v in ipairs(ISChat.allChatStreams) do
        if v == aptweaks_commands[i] then
            needed = true
        end
    end

    if needed then
        table.insert(ISChat.allChatStreams, aptweaks_commands[i])
    end
end

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

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: AddLineInChat de la clase Lua ISChat.
-- Corrige el bug de líneas infinitas que hay en el código vanilla.
---@param message table Un objeto ChatMessage, o uno que simule serlo.
---@param tabID number La ID de la pestaña en la que se mostrará el mensaje. Tenga encuenta que la ID de la pestaña 1 es 0.
ISChat.addLineInChat = function(message, tabID)

    old_addLineInChat(message, tabID)

    local chatText

    for _, tab in ipairs(ISChat.instance.tabs) do
        if tab and tab.tabID == tabID then
            chatText = tab
            break
        end
    end

    if #chatText.chatMessages > ISChat.maxLine + 1 then
        local newMessages = {}
        for i, msg in ipairs(chatText.chatMessages) do
            if i ~= 1 then
                table.insert(newMessages, msg)
            end
        end
        chatText.chatMessages = newMessages
    end
end

-- SOBRESCRIBIENDO UNA FUNCION VANILLA: updateChatPrefixSettings de la clase Lua ISChat.
function ISChat:updateChatPrefixSettings()

    -- Actualizar el tamaño de letra en nuestros mensajes falsos.
    for _, tab in ipairs(self.tabs) do
        for _, msg in ipairs(tab.chatMessages) do
            if msg.modID == modID then
                    msg:setSize(self.chatFont)
            end
        end
    end
    old_UpdateChatPrefixSettings(self)
end

-- Procesa los comandos de APTweaks,
---@param command string El comando que se ejecutó.
---@param args string Una cadena de todos los argumentos que se usaron al ingresar el comando.
local function ProcessAptweaksCommand(command, args)
    local player = player_flags.player

    if not player then return end

    -- La tabla que almacena cada palabra incluida en la cadena args.
    local words = {}

    for arg in string.gmatch(args, "%S+") do
        table.insert(words, arg)
    end
    local result = nil

    -- El comando principal de aptweaks (experimental).
    if command == "aptweaks" then

        if #words <= 1 then

            if #words == 1 then
                local subcommand = words[1]

                if subcommand == "cleardata" then
                    result = {text = "Espere un momento", command = "clearData", data = {}}
                end
            else
                result = {text = "Faltan argumentos. Use /aptweaks cleardata"}
            end
        else
            result = {text = "Demasiados argumentos"}
        end

    -- El comando warp. 
    elseif command == getText("UI_APTweaks_WarpCommand") and APTweaksVars.WarpSystemEnabled then
        result = WarpComamand(player, words)

    -- El comando safezone.
    elseif command == "safezone" and APTweaksVars.SafehouseSystemEnabled then
        result = SafehouseCommand(player, words)

    -- El comando de pruebas.
    elseif command == "something" then
        result = {text = "Espere un momento...", command = "something", data = {}}
    end
    ProcessCommandResult(player, result)
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

    if old_onSwitchStream then
        local success, err = pcall(old_onSwitchStream)
        if not success then
            print("APTweaks: Error al ejecutar función heredada de onSwitchStream: " .. tostring(err))
        end
    end

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
    local player = player_flags.player

    if not (player and module == modID) then return end

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
    ProcessCommandResult(player, result)
end

-- En el evento OnTick. Verifica constantemente la localización del cliente, de tenerla, y redefine las variables en su
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
