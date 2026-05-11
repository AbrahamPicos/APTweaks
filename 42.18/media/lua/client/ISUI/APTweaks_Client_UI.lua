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

-- Se usa para renderizar elementos en cada tick. Aparentemente es llamada por el UIManager.
function APTweaksUI:render()
end

-- Crea una nueva instancia de la ventana.
function APTweaksUI:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)

    o.moveWithMouse = true
    return o
end

local window

Events.OnKeyPressed.Add(function(key)
    -- verify the key X is pressed
    if key ~= Keyboard.KEY_X then return end

    -- if the UI exists, we close it
    if window then
        window:setVisible(false)
        window:removeFromUIManager()
        window = nil

    -- else we create a new instance of that UI
    else
        window = APTweaksUI:new(100, 100, 200, 200)
        window:initialise()
        window:addToUIManager()
    end
end)

return APTweaksUI