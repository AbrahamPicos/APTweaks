-- APTweaks_Client_Utils.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

---@class APTClientFlags
---@field afk boolean
---@field teleport table?
---@field isMoving boolean
---@field player IsoPlayer
---@field lastX number
---@field lastY number
---@field lastZ number

local getText = getText

local utils = aptweaks.utils
local aptweaks_temp = aptweaks.aptweaks_temp

-- La tabla de timers.
aptweaks_temp.timers = aptweaks_temp.timers or {}
-- El mapa de banderas del cliente. Controla los estados del cliente para los sistemas que el mod añade. 
aptweaks_temp.client_flags = aptweaks_temp.client_flags or {} ---@type APTClientFlags
-- Las tablas de timers. Se usan para actualizar estados en el evento OnTick.
aptweaks_temp.timers = {}

local timers = aptweaks_temp.timers
local client_flags = aptweaks_temp.client_flags

-- Establece uno de los timers a un nuevo valor de tiempo.
---@param timer "clientAFK"|"clientTeleport"
---@param time integer
local function setTimes(timer, time)
    local times = timers[timer].times

    times.start, times.lastNotify = time, time
end

-- Restablece el estado AFK del cliente.
---@param player IsoPlayer? El IsoPlayer asociado al cliente.
---@param time integer Una marca de tiempo UNIX.
function utils.resetAfkStatus(player, time)
    -- Restablecer timer
    setTimes("clientAFK", time)

    -- Validar si pasó suficiente tiempo para tener que notificar al usuario.
    if player and client_flags.afk then
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_AfkRemoved"), 0, 255, 0, 1000)
    end

    -- Limpiar vandera
    client_flags.afk = nil
end

-- Restablece el estado de teletransporte del cliente.
-- Los estados de la solicitud de teletransporte son nil, "begins", "requested", y "cancelled".
---@param player IsoPlayer El IsoPlayer asociado al cliente.
---@param time integer Una marca de tiempo UNIX.
---@param teleport table Una referencia a la tabla de teletransporte del cliente (optimización).
function utils.resetTeleportStatus(player, time, teleport)
    -- restablecer timer y notificar al usuario.
    player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportCancelled"), 255, 0, 0, 1000)
    setTimes("clientTeleport", time)

    -- Validar que aún no haya terminado el retraso. Si terminó, cambiar estado a cancelado y salir.
    if teleport.status == "waiting" then
        teleport.status = "cancelled"
        return
    end

    -- Limpiar teletransporte.
    client_flags.teleport = nil
end

return utils

-- Teleport no puede ser "table". Hágalo más específico.
