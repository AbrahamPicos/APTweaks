-- APTweaks.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

-- Este archivo actúa como un contenedor de datos. No lo recargue.

local aptweaks = {
    -- La ID del mod.
    modID = "com.github.abrahampicos.aptweaks",
    -- Las utilidades específicas del cliente o servidor.
    utils = {},
    -- Los comandos de APTweaks. Tanto los del servidor como los del cliente.
    commands = {},
    -- Datos varios que APTweaks necesita en tiempo de ejecución.
    aptweaks_temp = {},
    -- Respaldos de las funciones que fueron sobrescritas por APTweaks.
    legacy_functions = {},

    -- Variables de sandbox de APTweaks.
    APTweaksVars = SandboxVars.APTweaks ---@type APTweaksVars
}

---@class APTResult
---@field text string?
---@field command string?
---@field data table?

---@class APTweaksVars
---@field CoopServerMode boolean
---@field TeleportSystemEnabled boolean
---@field AfkSystemEnabled boolean
---@field SafehouseSystemEnabled boolean
---@field TeleportDelay integer
---@field TeleportCooldown integer
---@field AfkStart integer
---@field AfkKick integer

local isClient = isClient
local isServer = isServer
local sendClientCommand = sendClientCommand
local sendServerCommand = sendServerCommand

local modID = aptweaks.modID
local utils = aptweaks.utils
local commands = aptweaks.commands
local aptweaks_temp = aptweaks.aptweaks_temp
local client_flags = aptweaks_temp.client_flags

-- Verifica si una tabla está vacía (ya que `next` no funciona en Project Zomboid).
---@param t table La tabla que se verificará. Cualquier cosa que no sea una tabla se conciderará vacía.
---@return boolean isEmpty Si la tabla estaba vacía.
function utils.isTableEmpty(t)

    if type(t) ~= "table" then return true end

    for _ in pairs(t) do
        return false
    end

    return true
end

-- Procesa la respuesta de todos los comandos de APTweaks cuando son usados a travez de APTweaks.
-- Envia un comando, y/o añade un mensaje al chat, según sean necesarios.
---@param player IsoPlayer Un IsoPlayer.
---@param result APTResult La tabla con el resultado del comando.
---@param provider string El proovedor de comando. Se usa para enviar comandos.
function utils.processCommandResult(player, result, provider)
    local text = result.text
    local data = result.data or {}
    local commandName = result.command or "MessageCommand"

    if isServer() then

        if commandName ~= "MessageCommand" and text then
            sendServerCommand(player, provider, "MessageCommand", {text = text})
        end

        sendServerCommand(player, provider, commandName, data)
        return
    end
    
    if not isClient() then return end

    if commandName ~= "MessageCommand" and text then
        utils.addMessage(text, provider, false, 1)
    end
    
    sendClientCommand(player, provider, commandName, data)
end

-- Ejecuta acciones cuando el servidor o un cliente envió un comando relevante para APTweaks.
-- Se usa como callback en OnClientCommand y OnServerCommand.
---@param module string La ID del módulo que envió el comando.
---@param command string El comando es sí.
---@param player IsoPlayer? El IsoPlayer asociado al cliente asociado al comando.
---@param args table? Los argumentos del comando. Pueden ser cualquier cosa.
function utils.OnCommand(module, command, player, args)

    -- Si el módulo no coincide con APTweaks, o el comando no existe, no hay nada que hacer.
    if module ~= modID or not commands[command] then return end

    player = player or client_flags.player -- En onClientCommand el argumento player siempre contendrá un IsoPlayer.

    -- Manejar comando.
    local result = commands[command].handler(player, args or {})

    -- Procesar el resultado.
    if result then
        utils.processCommandResult(player, result, modID)
    end
end

return aptweaks
