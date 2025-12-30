-- APTweaks_Client_Commands.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local serverCommands, aptweaks = {}, require("APTweaks")

local client_flags = aptweaks.client_flags

local getText = aptweaks.getText
local SafeHouse = aptweaks.SafeHouse
local alreadyHaveSafehouse = aptweaks.alreadyHaveSafehouse

-- Esto ahora tiene que hacerse con SendSafehouseClaim, o del lado del servidor.
-- Tiene que añadirse un rol para cada usuario, y añadirle momentaneamente el rol
-- de crear safehouses. Podría ser prosible añadir safehoses del lado del servidor, pero no
-- se sincronizarían al momento con los cliente.
-- Quizá haya un truco. Como crearla y ajustar algo más aquí.
---@param player table
---@param args table
---@return table result
function serverCommands.SafezoneCommand(player, args) --ESTO ESTA ROTO: Cambió en la B42.

    if alreadyHaveSafehouse(player) then
        return {text = "Ya tienes o eres miembro de un refugio."}
    end

    local owner = player:getUsername()
    local x1, y1, x2, y2 = args.x1, args.y1, args.x2, args.y2
    local w, h = (x2 - x1 + 1), (y2 - y1 + 1)
    local title = string.format("Refugio de %s", owner)

    if not safezone then
        return {text = "Ocurrió un error. Problamente los refugios están deshabilitados en la configuración del servidor."}
    end

    -- No estoy seguro del porqué deben usarse estos métodos, pero así lo hace Indie Stone.
    safezone:setTitle(string.format("Refugio de %s", username))
    safezone:setOwner(username)
    safezone:updateSafehouse(player)
    safezone:syncSafehouse()

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
        player:setHaloNote(string.format(getText("IGUI_APTweaks_HaloNote_TeleportSuccess"), args.name), 0, 255, 0, 500)
        client_flags.isTeleporting = false
        client_flags.TeleportRequest = "succeded"
    end

    return {command = "TeleportCommand", data = {isRequest = false}}
end

return serverCommands
