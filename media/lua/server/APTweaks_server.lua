-- APTweaks_server.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

require("APTweaks.lua")

-- El mapa de datos de APTweaks.
-- Evidentemente esto no es persistente. Es sólo para la demostración. Está pendiente implementar ModData
--  para que los datos sean persistentes.
local aptweaks = {
    -- La versión de la estructura de datos. Se usará para saber si debe actualizarse cuando se actualiza el mod.
    dataversion = 1,
    -- El submapa de las áreas. Contiene toda la información de las áreas que pueden reclamarse.
    areas = {},
    -- Un índice que registra las áreas que contiene cada celda para un acceso más rápido con iteraciones.
    cells = {},
    -- El submapa de las áreas bloqueadas. Registra como "bloqueadas" las áreas que están siendo accedidas por otro ciente.
    --  Está aquí para evitar problemas de sincronización.
    blocked = {}
}

-- Las IDs de administradores Permitidas.
local allowedUsers = {
    ["76561198978760030"] = "AbrahamPicos"
}

local function OnTick(tick)

    for i = 0, getOnlinePlayers():size() - 1 do
        local player = getOnlinePlayers():get(i)

        if player:getAccessLevel() ~= "None" then
            local username = player:getUsername()
            local steamID = getSteamIDFromUsername(username)

            if not allowedUsers[steamID] then
                player:setAccessLevel("None")
                print("[APTweaksDebug] Jugador no autorizado detectado. Nombre: " .. username .. " ID: " .. steamID)
            end
        end
    end
end

local function OnClientCommand(module, command, player, args)

    if module == "com.github.abrahampicos.aptweaks" then

        if command == "claimCommand" then
            local cellID = args.cellID

            if aptweaks.cells[cellID] then

                for _, area in ipairs(aptweaks.cells[cellID].areas) do
                    local x, y = args.x, args.y
                    local data = aptweaks.areas[area]
                    local x1, y1, x2, y2, owner = data.x1, data.y1, data.x2, data.y2, data.owner

                    if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
                        local areaID = x1 .. "," .. y2
                        local isBlocked = false

                        for _, ID in pairs(aptweaks.blocked) do

                            if ID == areaID then
                                isBlocked = true
                                break
                            end
                        end

                        if not isBlocked then

                            if owner ~= nil then
                                aptweaks.blocked[areaID] = player:getUsername()
                                sendServerCommand(player, "com.github.abrahampicos.aptweaks", "createSafehouse", {areaID = areaID, x1 = x1, y1= y1, w = x2 - x1, h = y2 - y1})
                            else
                                sendServerCommand(player, "com.github.abrahampicos.aptweaks", "messageCommand", {text = "El area ya esta reclamada."})
                            end
                        else
                            sendServerCommand(player, "com.github.abrahampicos.aptweaks", "messageCommand", {text = "Intente mas tarde."})
                        end
                        break
                    end
                end
            else
                sendServerCommand(player, "com.github.abrahampicos.aptweaks", "messageCommand", {text = "No estas en un area reclamable."})
            end
        elseif command == "defineCommand" then
            local areaID = args.areaID
            local area = args.area
            local cells = args.cells

            if not aptweaks.areas[areaID] then
                aptweaks.areas[areaID] = area
            end
            -- {areaID = {x1= x1, y1= y1, x2= x2, y2 = y2, owner = nil}, cells = cells}
            --local table = args.areaID
            --local x1, y1, x2, y2, owner = table.x1, table.y2, table.x2, table.y2, table.owner

        elseif command == "claimCommandSucess" then

            if args.owner then
                aptweaks.areas[args.areaID].owner = args.owner
            end
            aptweaks.blocked[args.blocked] = nil

        elseif command == "something" then
            print("Esto es para experimentos futuros.")
        end
    end
end

-- Verifica si uno de los usuarios con un área bloqueada salió del servidor.
-- Aunque es poco probable que dos o más jugadores intenten reclamar un área practicamente al mismo tiempo
--   esto está aquí para asegurarse de que no queden áreas bloqueadas hasta el siguiente reinicio.
local function OnDisconnect()

    for username, _ in pairs(aptweaks.blocked) do
        local online = false

        for i = 0, getOnlinePlayers():size() - 1 do

            if getOnlinePlayers():get(i):getUsername() == username then
                online = true
                break
            end
        end

        if not online then
            aptweaks.blocked[username] = nil
        end
    end
end

Events.OnTick.Add(OnTick)
Events.OnDisconnect.Add(OnDisconnect)
Events.OnClientCommand.Add(OnClientCommand)