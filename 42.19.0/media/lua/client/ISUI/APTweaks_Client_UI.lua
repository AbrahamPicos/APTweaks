-- Este es un experimento para entender la UI del juego. No tengo pensado añadir una UI al mod realmente.

local aptweaks = require("APTweaks_Client")

local aptweaks_temp = aptweaks.aptweaks_temp

---@class APTweaksUI : ISPanel 
local APTweaksUI = ISPanel:derive("APTweaksUI")

--- initialize the UI, notably used to add child elements
function APTweaksUI:initialise()
    ISPanel.initialise(self)
end

--- called before the render function, notably used to precalculate data and cache
function APTweaksUI:prerender()
    ISPanel.prerender(self)
    self:drawText("Hello world",0,0,1,1,1,1, UIFont.Small) -- Escribe una línea de texto.
end

-- Se usa para renderizar elementos en cada tick. Aparentemente es llamada constantemente por el UIManager.
function APTweaksUI:render()
end

-- Crea una nueva instancia de la ventana.
function APTweaksUI:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)

    o.moveWithMouse = true
    return o
end

-- Abrir y cerrar ventana.
Events.OnKeyPressed.Add(function(key)

    if key ~= Keyboard.KEY_X then return end

    local window = aptweaks_temp.instanceUI -- No estoy seguro de que esta sea la mejor forma de almacenar la instancia.

    if not window then
        window = APTweaksUI:new(100, 100, 200, 200)
        
        window:initialise()
        window:addToUIManager()
    
    else
        window:setVisible(false)
        window:removeFromUIManager()
    
        aptweaks_temp.instanceUI = nil
    end

    aptweaks_temp.instanceUI = window
end)

return APTweaksUI
