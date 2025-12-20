-- APTweaks_Client_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local serverCommands, aptweaks = {}, require("APTweaks")

local client_flags = aptweaks.client_flags

local getText = aptweaks.getText
local SafeHouse = aptweaks.SafeHouse
local alreadyHaveSafehouse = aptweaks.alreadyHaveSafehouse

---comment
---@param player table
---@param args table
---@return table result
function serverCommands.SafezoneCommand(player, args)
    local username = player:getUsername()
    local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2

    -- Esto evitará que se cree más de una safehouse si el usuario envia varias solicitudes en muy poco tiempo para reclamar
    --- áreas diferentes. Sin embargo, no hay garantía de que la primer solicitud que se hizo sea la primera en llagar hasta
    --- este punto, lo que produciría una inconsistencia.
    -- Como esto último es una inconsistencia menor, -y muy infrecuente-, decidí no hacer nada.
    if not alreadyHaveSafehouse(player) then
        local safezone = SafeHouse.addSafeHouse(x1, y1, x2 - x1 + 1, y2 - y1 + 1, username, false)

        -- No estoy seguro del porqué deben usarse estos métodos, pero así lo hace Indie Stone.
        safezone:setTitle(string.format("refugio de %s", username))
        safezone:setOwner(username)
        safezone:updateSafehouse(player)
        safezone:syncSafehouse()

        return {text = "Safehouse creada exitosamente."}
        -- Por seguridad, el desbloqueo de areas se maneja completamente del lado del servidor.
    else
        return {text = "Ya tienes o eres miembro de un refugio."}
    end
end

---comment
---@param player table
---@param args table
---@return table result
function serverCommands.TeleportCommand(player, args)

    if not client_flags.isTeleporting then
        client_flags.TeleportRequest = "failed"

    else
        local x, y, z = args.x, args.y, args.z

        player:setX(x); player:setY(y); player:setZ(z); player:setLx(x); player:setLy(y); player:setLz(z)
        player:setHaloNote(string.format(getText("IGUI_APTweaks_HaloNote_TeleportSuccess"), args.name), 0, 255, 0, 500)
        client_flags.isTeleporting = false
        client_flags.TeleportRequest = "succeded"
    end

    return {command = "TeleportCommand", data = {isRequest = false}}
end

return serverCommands
