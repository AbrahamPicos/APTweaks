-- APTweaks_Client_Utils.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

---@class APTClientFlags
---@field teleport table?
---@field isMoving boolean
---@field player IsoPlayer
---@field lastX number
---@field lastY number
---@field lastZ number

local pairs = pairs

local getText = getText

local utils = aptweaks.utils
local aptweaks_temp = aptweaks.aptweaks_temp
local APTweaksVars = aptweaks.APTweaksVars

-- La tabla de timers.
aptweaks_temp.timers = aptweaks_temp.timers or {} ---@type table<string,{justAdded:boolean,counter:number,cycles:integer}>
-- El mapa de banderas del cliente. Controla los estados del cliente para los sistemas que el mod añade. 
aptweaks_temp.client_flags = aptweaks_temp.client_flags or {} ---@type APTClientFlags

local client_flags = aptweaks_temp.client_flags

-- Establece o restablece un timer.
---@param name string El nombre del timer.
local function setTimer(name)
    aptweaks_temp.timers[name] = {justAdded = true, counter = 0, cycles = 0}
end

-- Obtiene el ciclo actual de un timer.
---@param name string El nombre del timer.
---@return number cycle El número de ciclo.
local function getTimerCycle(name)
    return aptweaks_temp.timers[name].cycles
end

-- Devuélve la lista de warps disponibles en forma de string.
---@param warps table El mapa con los warps existentes.
---@return string aviableWarps Un string con saltos de línea compatible con el chat de Project Zomboid.
function utils.showWarps(warps)
    local aviableWarps = "<LINE>"
    local index = 0

    for warp, _ in pairs(warps) do
        index = index + 1
        aviableWarps = aviableWarps .. "* " .. warp

        if index < #warps then
            aviableWarps = aviableWarps .. "<LINE>"
        end
    end

    return aviableWarps
end

-- Actualiza un timer, y devuelve sus variables.
---@param name string El nombre del timer.
---@param time number El tiempo que se añadirá al timer.
---@return number cycle El número de ciclo.
---@return boolean isCycleUpdate Si esta actualización resultó en un nuevo ciclo.
function utils.getTimerUpdate(name, time)
    local timer = aptweaks_temp.timers[name]
    local isCycleUpdate = timer.justAdded -- Con esto el primer ciclo es el 0.

    timer.counter = timer.counter + time
    timer.justAdded = false

    if timer.counter >= 1 then
        timer.counter = timer.counter - 1
        timer.cycles = timer.cycles + 1
        isCycleUpdate = true
    end

    return timer.cycles, isCycleUpdate
end

-- Restablece el estado AFK del cliente.
---@param player IsoPlayer? El IsoPlayer asociado al cliente.
function utils.resetAfkStatus(player)

    -- Validar si pasó suficiente tiempo para tener que notificar al usuario.
    if player and (getTimerCycle("afk") >= APTweaksVars.AfkStart) then
        player:setHaloNote(getText("IGUI_APTweaks_HaloNote_AfkRemoved"), 0, 255, 0, 500)
    end

    -- Restablecer timer
    setTimer("afk")
end

-- Restablece el estado de teletransporte del cliente.
---@param player IsoPlayer El IsoPlayer asociado al cliente.
---@param teleport table Una referencia a la tabla de teletransporte del cliente (optimización).
function utils.resetTeleportStatus(player, teleport)
    -- restablecer timer y notificar al usuario.
    player:setHaloNote(getText("IGUI_APTweaks_HaloNote_TeleportCancelled"), 255, 0, 0, 500)
    setTimer("teleport")

    -- Validar que aún no haya terminado el retraso. Si terminó, cambiar estado a cancelado y salir.
    if teleport.status == "waiting" then
        teleport.status = "cancelled"
        return
    end

    -- Limpiar teletransporte.
    client_flags.teleport = nil
end

-- Inicializar timers.
setTimer("afk"); setTimer("teleport")

return utils

-- Teleporting no puede ser table.
