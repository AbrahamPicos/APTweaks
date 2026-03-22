-- APTweaks_Client_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local serverCommands, aptweaks = {}, require("APTweaks")

local client_flags = aptweaks.client_flags

local getText = aptweaks.getText
local SafeHouse = aptweaks.SafeHouse
local alreadyHaveSafehouse = aptweaks.alreadyHaveSafehouse

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

---comment
--- Valdría la pena probar si ahora esto se puede hacer del lado del servidor.
---@param player table
---@param args table
---@return table result
function serverCommands.TeleportCommand(player, args)

    if not client_flags.isTeleporting then
        client_flags.TeleportRequest = "failed"

    else
        local x, y, z = args.x, args.y, args.z

        player:setX(x); player:setY(y); player:setZ(z); player:setLx(x); player:setLy(y); player:setLz(z)
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportSuccess", args.name), 0, 255, 0, 500)
        client_flags.isTeleporting = false
        client_flags.TeleportRequest = "succeded"
    end

    return {command = "TeleportCommand", data = {isRequest = false}}
end

return serverCommands
