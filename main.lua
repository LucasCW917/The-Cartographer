local Cave     = require("cave")
local Renderer = require("renderer")
local Depot = require("depot")
local Panel = require("panel")

-- Globals
local W, H
local bg, vignette
local titleFont, buttonFont, smallFont
local scene = "menu"
local currentDepot = nil
local currentPanel = nil
local SIDEBAR_W = 220

-- Menu
local buttons = {}

-- Setup
local activeInput  = nil
local difficultyButtons = {}
local beginButton  = { text="", x=0, y=0, w=0, h=0, onClick=function() end }
local setup = {
    name = { x=0, y=0, w=320, h=38, value="", active=false, placeholder="Your name..." },
    seed = { x=0, y=0, w=320, h=38, value="", active=false, placeholder="Leave blank for random" },
    difficulty = nil,
}
local difficulties = {
    { id="apprentice",   label="Apprentice",   desc="For those new to the dark." },
    { id="cartographer", label="Cartographer", desc="The true path. No shortcuts." },
    { id="pioneer",      label="Pioneer",      desc="The map ends where you do." },
    { id="lost",         label="The Lost",     desc="No one is coming for you." },
}
local difficultySizes = {
    apprentice   = { w=200,  h=200  },
    cartographer = { w=500,  h=500  },
    pioneer      = { w=1000, h=1000 },
    lost         = nil,
}

-- Game
local currentCave     = nil
local currentRenderer = nil

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

function newButton(text, x, y, w, h, onClick)
    return { text=text, x=x, y=y, w=w, h=h, onClick=onClick }
end

function isHovered(btn)
    local mx, my = love.mouse.getPosition()
    return mx > btn.x and mx < btn.x+btn.w and my > btn.y and my < btn.y+btn.h
end

-- -------------------------------------------------------------------------
-- Love callbacks
-- -------------------------------------------------------------------------

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    love.window.setFullscreen(true)
    W, H = love.graphics.getDimensions()

    titleFont  = love.graphics.newFont("assets/fonts/IMFellEnglish-Regular.ttf", 48)
    buttonFont = love.graphics.newFont("assets/fonts/IMFellEnglish-Italic.ttf", 18)
    smallFont  = love.graphics.newFont("assets/fonts/IMFellEnglish-Italic.ttf", 12)

    bg = love.graphics.newImage("assets/images/map.jpg", { mipmaps=true })
    bg:setFilter("linear", "linear")

    vignette = love.graphics.newMesh({
        { 0, 0,  0, 0,  0, 0, 0, 0.85 },
        { W, 0,  0, 0,  0, 0, 0, 0.85 },
        { W, H,  0, 0,  0, 0, 0, 0.85 },
        { 0, H,  0, 0,  0, 0, 0, 0.85 },
    }, "fan")

    -- Menu buttons
    local bw, bh = 220, 38
    local bx = W/2 - bw/2
    local by = H/2 + 20
    buttons = {
        newButton("New Expedition", bx, by,       bw, bh, function() scene = "setup" end),
        newButton("Continue",       bx, by+52,    bw, bh, function() continueGame() end),
        newButton("Quit",           bx, by+104,   bw, bh, function() love.event.quit() end),
    }

    -- Setup screen layout
    local cx = W/2
    setup.name.x = cx - 160
    setup.name.y = H/2 - 160
    setup.seed.x = cx - 160
    setup.seed.y = H/2 - 80

    local dw, dh = 148, 48
    local dy = H/2 + 20
    difficultyButtons = {
        { d=difficulties[1], x=cx-152, y=dy,     w=dw, h=dh },
        { d=difficulties[2], x=cx+4,   y=dy,     w=dw, h=dh },
        { d=difficulties[3], x=cx-152, y=dy+58,  w=dw, h=dh },
        { d=difficulties[4], x=cx+4,   y=dy+58,  w=dw, h=dh },
    }
    beginButton = newButton("Begin Expedition", cx-110, H/2+200, 220, 38, function()
        if setup.difficulty and #setup.name.value > 0 then
            startGame()
        end
    end)
end

function love.update(dt)
    if scene == "game" then
        updateGame(dt)
    end
end

function love.draw()
    if     scene == "menu"  then drawMenu()
    elseif scene == "setup" then drawSetup()
    elseif scene == "game"  then drawGame()
    end
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end

    if scene == "menu" then
        for _, btn in ipairs(buttons) do
            if isHovered(btn) then btn.onClick() end
        end

    elseif scene == "setup" then
        activeInput = nil
        for _, inp in ipairs({ setup.name, setup.seed }) do
            inp.active = mx > inp.x and mx < inp.x+inp.w and my > inp.y and my < inp.y+inp.h
            if inp.active then activeInput = inp end
        end
        for _, db in ipairs(difficultyButtons) do
            if mx > db.x and mx < db.x+db.w and my > db.y and my < db.y+db.h then
                setup.difficulty = db.d.id
            end
        end
        if isHovered(beginButton) then beginButton.onClick() end
    end
end

function love.textinput(t)
    if activeInput then
        activeInput.value = activeInput.value .. t
    end
end

function love.keypressed(key)
    if activeInput and key == "backspace" then
        activeInput.value = activeInput.value:sub(1, -2)
    end
    if key == "tab" then
        local fields = { setup.name, setup.seed }
        for i, inp in ipairs(fields) do
            if inp.active then
                inp.active = false
                activeInput = fields[i % #fields + 1]
                activeInput.active = true
                break
            end
        end
    end
    if key == "escape" then
        if scene == "setup" then scene = "menu" end
    end
end

function love.wheelmoved(x, y)
    if scene == "game" and currentRenderer then
        if y > 0 then currentRenderer:zoomIn()
        else           currentRenderer:zoomOut()
        end
    end
end

-- -------------------------------------------------------------------------
-- Game logic
-- -------------------------------------------------------------------------

function startGame()
    local seed = tonumber(setup.seed.value) or math.random(99999)
    local size = difficultySizes[setup.difficulty]

    if size then
        currentCave = Cave.new(seed, size.w, size.h)
    else
        currentCave = Cave.newInfinite(seed)
    end

    currentCave:reveal(currentCave.startX, currentCave.startY, 5)
    currentRenderer = Renderer.new(currentCave)
    currentRenderer.viewW = W - SIDEBAR_W  -- map only occupies left portion
    currentDepot = Depot.new(currentCave.startX, currentCave.startY)
    currentPanel = Panel.new(W - SIDEBAR_W, 0, SIDEBAR_W, H, buttonFont)
    scene = "game"

    print("Name:", setup.name.value, "Seed:", seed, "Difficulty:", setup.difficulty)
end

function continueGame()
    print("Continuing expedition...")
end

function updateGame(dt)
    local speed = 20 * dt
    if love.keyboard.isDown("w") then currentRenderer:pan(0, -speed) end
    if love.keyboard.isDown("s") then currentRenderer:pan(0,  speed) end
    if love.keyboard.isDown("a") then currentRenderer:pan(-speed, 0) end
    if love.keyboard.isDown("d") then currentRenderer:pan( speed, 0) end
    if love.keyboard.isDown("p") and scene == "game" then
        currentDepot:queueProbe("explorer", "none", currentCave)
    end

    if currentDepot then
        currentDepot:update(dt, currentCave, {})
    end
end

-- -------------------------------------------------------------------------
-- Draw functions
-- -------------------------------------------------------------------------

function drawBackground(alpha)
    local scaleX = W / bg:getWidth()
    local scaleY = H / bg:getHeight()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(bg, 0, 0, 0, scaleX, scaleY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(vignette)
end

function drawButtonStyled(btn)
    local hovered = isHovered(btn)
    if hovered then
        love.graphics.setColor(0.88, 0.82, 0.68, 0.08)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(0.88, 0.82, 0.68, 0.7)
        love.graphics.rectangle("fill", btn.x-6, btn.y+10, 2, btn.h-20)
    end
    love.graphics.setColor(hovered and {0.95, 0.90, 0.75} or {0.55, 0.50, 0.40})
    local tw = buttonFont:getWidth(btn.text)
    love.graphics.print(btn.text, btn.x+btn.w/2-tw/2, btn.y+btn.h/2-buttonFont:getHeight()/2)
end

function drawMenu()
    love.graphics.clear(0.05, 0.04, 0.03)
    drawBackground(0.15)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.88, 0.82, 0.68)
    local tw = titleFont:getWidth("The Cartographer")
    love.graphics.print("The Cartographer", W/2-tw/2, H/2-120)

    love.graphics.setColor(0.5, 0.45, 0.35, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(W/2-120, H/2-60, W/2+120, H/2-60)

    love.graphics.setFont(buttonFont)
    for _, btn in ipairs(buttons) do
        drawButtonStyled(btn)
    end

    love.graphics.setColor(1, 1, 1)
end

function drawSetup()
    love.graphics.clear(0.05, 0.04, 0.03)
    drawBackground(0.08)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.88, 0.82, 0.68)
    local tw = titleFont:getWidth("New Expedition")
    love.graphics.print("New Expedition", W/2-tw/2, H/2-240)

    love.graphics.setColor(0.5, 0.45, 0.35, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(W/2-120, H/2-190, W/2+120, H/2-190)

    -- Text inputs
    love.graphics.setFont(buttonFont)
    for _, inp in ipairs({ setup.name, setup.seed }) do
        love.graphics.setColor(0.55, 0.50, 0.40)
        love.graphics.print(inp == setup.name and "Name" or "Seed", inp.x, inp.y-22)

        love.graphics.setColor(0.05, 0.04, 0.03, 0.8)
        love.graphics.rectangle("fill", inp.x, inp.y, inp.w, inp.h)

        love.graphics.setColor(inp.active and {0.88, 0.82, 0.68, 0.6} or {0.55, 0.50, 0.40, 0.4})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", inp.x, inp.y, inp.w, inp.h)

        local display = #inp.value > 0 and inp.value or inp.placeholder
        love.graphics.setColor(#inp.value > 0 and {0.88, 0.82, 0.68} or {0.35, 0.32, 0.26})
        love.graphics.print(display, inp.x+10, inp.y+inp.h/2-buttonFont:getHeight()/2)

        if inp.active and (love.timer.getTime() % 1) < 0.5 then
            local cx = inp.x + 10 + buttonFont:getWidth(inp.value)
            love.graphics.setColor(0.88, 0.82, 0.68, 0.8)
            love.graphics.line(cx, inp.y+8, cx, inp.y+inp.h-8)
        end
    end

    -- Difficulty buttons
    love.graphics.setFont(buttonFont)
    for _, db in ipairs(difficultyButtons) do
        local mx, my = love.mouse.getPosition()
        local hovered  = mx > db.x and mx < db.x+db.w and my > db.y and my < db.y+db.h
        local selected = setup.difficulty == db.d.id

        love.graphics.setColor(selected and {0.88,0.82,0.68,0.12} or hovered and {0.88,0.82,0.68,0.06} or {0,0,0,0})
        love.graphics.rectangle("fill", db.x, db.y, db.w, db.h)

        love.graphics.setColor(selected and {0.88,0.82,0.68,0.8} or {0.55,0.50,0.40,0.4})
        love.graphics.rectangle("line", db.x, db.y, db.w, db.h)

        love.graphics.setColor(selected and {0.95,0.90,0.75} or hovered and {0.75,0.70,0.58} or {0.55,0.50,0.40})
        local lw = buttonFont:getWidth(db.d.label)
        love.graphics.print(db.d.label, db.x+db.w/2-lw/2, db.y+8)

        love.graphics.setFont(smallFont)
        love.graphics.setColor(selected and {0.70,0.65,0.52} or {0.35,0.32,0.26})
        local dw = smallFont:getWidth(db.d.desc)
        love.graphics.print(db.d.desc, db.x+db.w/2-dw/2, db.y+26)
        love.graphics.setFont(buttonFont)
    end

    -- Begin button
    local canBegin = setup.difficulty ~= nil and #setup.name.value > 0
    local hovered  = isHovered(beginButton)

    if hovered and canBegin then
        love.graphics.setColor(0.88, 0.82, 0.68, 0.08)
        love.graphics.rectangle("fill", beginButton.x, beginButton.y, beginButton.w, beginButton.h)
        love.graphics.setColor(0.88, 0.82, 0.68, 0.7)
        love.graphics.rectangle("fill", beginButton.x-6, beginButton.y+10, 2, beginButton.h-20)
    end

    love.graphics.setColor(not canBegin and {0.30,0.28,0.22} or hovered and {0.95,0.90,0.75} or {0.55,0.50,0.40})
    local btw = buttonFont:getWidth(beginButton.text)
    love.graphics.print(beginButton.text, beginButton.x+beginButton.w/2-btw/2, beginButton.y+beginButton.h/2-buttonFont:getHeight()/2)

    if not canBegin then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.35, 0.32, 0.26)
        local hint = "Enter your name and choose a difficulty to begin."
        local hw = smallFont:getWidth(hint)
        love.graphics.print(hint, W/2-hw/2, beginButton.y+50)
    end

    love.graphics.setColor(1, 1, 1)
end
function drawGame()
    love.graphics.clear(0.05, 0.04, 0.03)
    if currentRenderer then
        currentRenderer:draw(W, H)
    end
    if currentDepot then
        drawDepotOverlay()
    end
    love.graphics.setColor(1, 1, 1)
end

function drawDepotOverlay()
    local ts = currentRenderer.tileSize * currentRenderer.zoom

    -- Draw depot
    local dx, dy = currentRenderer:tileToScreen(currentDepot.x, currentDepot.y, W, H)
    love.graphics.setColor(0.95, 0.85, 0.50)
    love.graphics.rectangle("fill", dx, dy, ts, ts)

    -- Draw probes
    for _, probe in ipairs(currentDepot.probes) do
        if probe.alive then
            local sx, sy = currentRenderer:tileToScreen(probe.x, probe.y, W, H)
            local col = probe:getColor()
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.circle("fill", sx + ts/2, sy + ts/2, math.max(3, ts/3))

            -- HP bar
            if probe.hp < probe.maxHp then
                love.graphics.setColor(0.8, 0.2, 0.2)
                love.graphics.rectangle("fill", sx, sy - 4, ts, 3)
                love.graphics.setColor(0.2, 0.8, 0.2)
                love.graphics.rectangle("fill", sx, sy - 4, ts * (probe.hp/probe.maxHp), 3)
            end
        end
    end

    -- HUD: resources
    love.graphics.setFont(buttonFont)
    love.graphics.setColor(0.88, 0.82, 0.68, 0.9)
    love.graphics.print(
        string.format("Metal: %d   Energy: %d   Rare: %d   Probes: %d / queued: %d",
            currentDepot.resources.metal,
            currentDepot.resources.energy,
            currentDepot.resources.rare,
            currentDepot.aliveProbes and currentDepot:aliveProbes() or 0,
            #currentDepot.queue
        ),
        16, 16
    )
end