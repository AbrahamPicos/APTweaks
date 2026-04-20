-- APTweaks_Client_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local serverCommands, aptweaks = {}, require("APTweaks")

local showWarps = aptweaks.showWarps
local client_flags = aptweaks.client_flags

local getText = aptweaks.getText

-- Muestra un mensaje cuando un jugador se conectó al servidor.
function serverCommands.PlayerConnectedCommand(args)
    return {text = getText("IGUI_APTweaks_Chat_WellcomeMessage", args.username)}
end

-- Muestra un mensaje cuando un jugador se desconectó del servidor.
function serverCommands.PlayerDisconnectedCommand(args)
    return {text = getText("IGUI_APTweaks_Chat_FarewellMessage", args.username)}
end

-- Esto ahora tiene que hacerse con SendSafehouseClaim, o del lado del servidor.
-- Tiene que añadirse un rol para cada usuario, y añadirle momentaneamente el rol
-- de crear safehouses. Podría ser prosible añadir safehoses del lado del servidor, pero no
-- se sincronizarían al momento con los cliente.
-- Quizá haya un truco. Como crearla y ajustar algo más aquí.
---@param player table
---@param args table
---@return table result
function serverCommands.SafezoneCommand(player, args) --ESTO ESTA ROTO: Cambió en la B42.
    return {text = "Safehouse creada exitosamente."}
end

-- Teletransporta al jugador asociado al cliente.
---@param player table El jugador asociado al cliente.
---@param args table Los argumentos del comando.
---@return table|nil result El resultado del comando. Un mensaje, y un comando con sus argumentos según se requiera.
function serverCommands.TeleportCommand(player, args)
    local status = args.status

    -- Si el servidor indicó que debe continuar con el cooldown, no hay nada qué hacer.
    if status == "proceed" then return end

    local result = {}

    -- Si el servidor denegó la solicitud, notificar al usuario.
    if status == "denied" then

        if args.name then
            result.text = getText("IGUI_APTweaks_Chat_MissingWarp", args.name, showWarps(args.names))

        elseif args.username then
            result.text = "Jugador " .. args.username .. " no encontrado."

        elseif args.dynamicRole then
            result.text = "APTweaks no es compatible con roles personalizados. Informe a un administrador sobre este error."

        else
            result.text = "Ocurrio un error."
        end

    elseif status == "approved" then
        result.command = "TeleportCommand"
        result.data = {status = "succeded"}

        -- Validar si el trletransporte aún debe ocurrir.
        if client_flags.teleporting.status == "cancelled" then
            result.data.stauts = "failed"
        end

        local location = args.location

        -- Teletransportar y notificar al usaurio.
        player:teleportTo(location.x, location.y, location.z)
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportSuccess", location.name), 0, 255, 0, 500)
    end

    -- Limpiar teletransporte
    client_flags.teleporting = nil

    -- Notificar al servidor.
    return result
end

return serverCommands
