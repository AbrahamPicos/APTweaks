-- APTweaks_Server_Utils.lua
-- Licence: CC0-1.0(Visit https://creativecommons.org/publicdomain/zero/1.0/ to view details).
-- Maintainer: AbrahamPicos.

local aptweaks = require("APTweaks")

local utils = aptweaks.utils
local aptweaks_temp = aptweaks.aptweaks_temp
local aptweaks_data = aptweaks_temp.aptweaks_data

local ModData = ModData

local addRole = addRole
local getRoles =  getRoles
local setupRole = setupRole

-- El submapa de los jugadores que están en la pantalla de carga.
aptweaks_temp.afk = {} ---@type table<string,integer?>
-- La tabla con las funciones que se ejecutarán en el evento onTick.
aptweaks_temp.onTick = {} ---@type table<string,(fun(tick:integer))?>
-- El submapa de los jugadres pateados.
aptweaks_temp.kicked = {} ---@type table<string,string?>
-- La tabla de jugadores conectados. Ya que el juego no tiene nada para eso, este mod rastrea conexiones y desconexiones.
aptweaks_temp.onlinePlayers = {} ---@type table<string,IsoPlayer?>
-- La tabla con las funciones que se ejecutarán cada vez que un jugador se conecta.
aptweaks_temp.onPlayerConnected = {} ---@type table<string,(fun(username:string))?>
-- La tabla con las funciones que se ejecutarán cada vez que un jugador se desconecta.
aptweaks_temp.onPlayerDisconnected = {} ---@type table<string,(fun(username:string))?>

-- Crea el mapa de datos de APTweaks. También lo restablece si es necesario.
---@param reset boolean Si el mapa debe restablecerse, lo que borrará todos los datos.
function utils.SetupData(reset)
    -- Las claves con las que se nombran a las tablas de ModData no admiten puntos, por lo que no puedo usar modID.
    aptweaks_temp.aptweaks_data = ModData.getOrCreate("aptweaks")

    if utils.isTableEmpty(aptweaks_data) or reset then
        -- La versión de la estructura de datos. Se usará para saber si debe actualizarse cuando se actualiza el mod.
        aptweaks_data.dataversion = 1
        -- El submapa de las áreas. Contiene toda la información de las áreas que pueden reclamarse como non-building safehouses.
        aptweaks_data.areas = {}
        -- El submapa que indexa las áreas por celda.
        -- APTweaks usa una cuadricula espacial para indexar las áreas, lo que reduce las iteraciones al acceder al mapa de datos.
        aptweaks_data.cells = {} ---@type table<string, table<string>?>
        -- El submapa que contiene los warps.
        aptweaks_data.warps = {}
    end
end

-- Devuélve si un rol es el rol por defecto para los nuevos usuarios.
---@param role table El rol que se verificará.
---@return boolean isDefault Si es el rol por defecto.
function utils.isRoleUsersDefault(role)

    if not role:isReadOnly() then return false end

    local defaults = role:getDefaults()

    for i = 0, defaults:size() - 1 do
        local string = defaults:get(i)

        if string == "user" then
            return true
        end
    end

    return false
end

-- Crea y devuélve un nuevo rol.
---@param name string El nombre del nuevo rol.
---@param capabilities Capability[] Los permisos que tendrá el nuevo rol.
---@return Role role Un nuevo rol.
function utils.getNewRole(name, capabilities)
    local roles = getRoles()

    addRole(name)

    for i = 0, roles:size() - 1 do
        local role = roles:get(i)

        if role:getName() == name then
            setupRole(role, "A temporary role from APTweaks.", Color.gray, capabilities)
            role:setReadOnly()
            return role
        end
    end

    error("NO_NEW_ROLES")
end

return utils
