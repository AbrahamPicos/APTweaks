-- Licence: CCO-1.0
-- Author: AbrahamPicos

local modID = "SafeTogether"

local SafeHouse = SafeHouse
local ISModalDialog = ISModalDialog
local ISSafehouseUI = ISSafehouseUI
local ISSafehouseAddPlayerUI = ISSafehouseAddPlayerUI

local Legacy_onClick = ISSafehouseAddPlayerUI.onClick
local Legacy_ReceiveSafehouseInvite = ISSafehouseUI.ReceiveSafehouseInvite
local Legacy_onAnswerSafehouseInvite = ISSafehouseUI.onAnswerSafehouseInvite

-- SendSafehouseInvite --> ReceiveSafehouseInvite
-- AcceptSafehouseInvite --> AcceptedSafehouseInvite

-- El código vanilla funciona:
-- 1. El cliente envía SendSafehouseInvite cuando quiere invitar a un jugador a su safehouse.
-- 2. SendSafehouseInvite añade la invitación a la instancia de la safehouse del lado del servidor.
---    Esto sirve para asegurarse de que el cliente que fue invitado realmente (medida contra paquetes falsos).
-- 3. El servidor envía ReceiveSafehouseInvite al destinatario de SendSafehouseInvite.
---    En este punto el cliente remitente ya no interviene más.
-- 4. ReceiveSafehouseInvite añade el diálogo para que el cliente acepte o rechaze la invitación.
-- 5. Si el cliente destinatario acepta o rechaza la invitación, envía AcceptSafehouseInvite al servidor.
-- 6. AcceptSafehouseInvite añade al usaurio a lasafehouse del lado del servidor, y elimina la invitación de la instancia.
-- 6. El servidor envía AcceptedSafehouseInvite a todos los clientes.
-- 7. AcceptedSafehouseInvite añade el cambio a la instancia de la safehouse en los clientes para sincronizar con el servidor.

------------------------------------------------------------------------------------
---Cuando el cliente hace click en el botón para añadir a un jugador a su safehouse.
------------------------------------------------------------------------------------

local function CustomOnClick(self, button)

    -- Manejar sólo si es necesario.
    if button.internal == "ADDPLAYER" or self.changeOwnership then
        return false
    end

    -- Peparar y enviar la invitación al servidor, e inicializar diálogo modal.
    local safehouse = self.safehouse
    local safehouseDef = {x = safehouse.getX(), y = safehouse.getY(), w = safehouse.getW(), h = safehouse.getH()}
    local modal = ISModalDialog:new(0,0, 350, 150, getText("IGUI_FactionUI_InvitationSent",self.selectedPlayer), false, nil, nil)

    modal:initialise()
    modal:addToUIManager()

    sendClientCommand(modID, "SendSafehouseInvite", {invited = self.selectedPlayer, safehouse = safehouseDef})

    -- Ocultar AddPlayerUI y destruir esta instancia.
    self:setVisible(false)
    self:removeFromUIManager()

    ISSafehouseAddPlayerUI.instance = nil

    return true
end

function ISSafehouseAddPlayerUI:onClick(button)
    local isHandled = CustomOnClick(self, button)

    if not isHandled then
        Legacy_onClick(self, button)
    end
end

------------------------------------------------------------------------------------
---Cuando el cliente al que le enviaron la invitación la recibe.
------------------------------------------------------------------------------------

local function CustomReceiveSafehouseInvite(safehouse, host)

    if not SafeHouse.hasSafehouse(getPlayer()) then return end

    --- Inicializar diálogo modal.
    local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 175,getCore():getScreenHeight() / 2 - 75, 350, 150, getText("IGUI_SafehouseUI_Invitation", host), true, nil, ISSafehouseUI.onAnswerSafehouseInvite)

    modal:initialise()
    modal:addToUIManager()

    modal.safehouse = safehouse
    modal.host = host
    modal.moveWithMouse = true

    ISSafehouseUI.inviteDialogs[host] = modal
end

function ISSafehouseUI.ReceiveSafehouseInvite(safehouse, host)
    Legacy_ReceiveSafehouseInvite(safehouse, host)
    CustomReceiveSafehouseInvite(safehouse, host)
end

local function CustomOnAnswerSafehouseInvite(self, button)

    if button.internal ~= "YES" then
        return false
    end

    ISSafehouseUI.inviteDialogs[button.parent.host] = nil

    -- Preparar y enviar la solicitud de aceptar la invitación al servidor.
    local safehouse = button.parent.safehouse
    local safehouseDef = {x = safehouse.getX(), y = safehouse.getY(), w = safehouse.getW(), h = safehouse.getH()}

    sendClientCommand(modID, "AcceptSafehouseInvite", {host = button.parent.host, safehouse = safehouseDef})

    return true
end

function ISSafehouseUI:onAnswerSafehouseInvite(button)
    local isHandled = CustomOnAnswerSafehouseInvite(self, button)

    if not isHandled then
        Legacy_onAnswerSafehouseInvite(self, button)
    end
end

------------------------------------------------------------------
local function getSafehouseFromDef(safehouseDef)
    return SafeHouse.getSafehouse(safehouseDef.x, safehouseDef.y, safehouseDef.w, safehouseDef.h)
end


local server_commands = {
    ReceiveSafehouseInvite = {
        handler = function (safehouse, username)
                triggerEvent("ReceiveSafehouseInvite", safehouse, username)
            end
    },
    AcceptedSafehouseInvite = {
        handler = function (safehouse, username)
                safehouse.addPlayer(username)

                triggerEvent("AcceptedSafehouseInvite", safehouse.getTitle(), owner)
            end
    }
}

local function OnServerCommand(module, command, args)

    if module ~= modID then return end

    -- Validar comando.
    local commandData = server_commands[command]

    if not commandData then return end

    -- Preparar y disparar el evento solicitado.
    local safehouseDef = args.safehouseDef
    local safehouse = SafeHouse.getSafehouse(safehouseDef.x, safehouseDef.y, safehouseDef.w, safehouseDef.h)
    local username = args.invited or getPlayer():getUsername()

    if safehouse then
        commandData.handler(safehouse, username)
    end
end

Events.OnServerCommand.Add(OnServerCommand)
-------------------------------------------------------------------