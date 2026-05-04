-- main.lua
local Cave     = require("cave")
local Renderer = require("renderer")
local Depot    = require("depot")
local Panel    = require("panel")
local Pause    = require("pause")
local Saves    = require("saves")

-- ── Globals ───────────────────────────────────────────────────────────────
local W, H
local bg, vignette
local titleFont, buttonFont, smallFont
local scene     = "menu"
local SIDEBAR_W = 220

-- Menu
local buttons = {}

-- Setup
local activeInput       = nil
local difficultyButtons = {}
local beginButton       = { text="", x=0, y=0, w=0, h=0, onClick=function() end }
local setup = {
    name = { x=0, y=0, w=320, h=38, value="", active=false, placeholder="Your name..." },
    seed = { x=0, y=0, w=320, h=38, value="", active=false, placeholder="Leave blank for random" },
    difficulty = nil,
}
local difficulties = {
    { id="apprentice",   label="Apprentice",   desc="For those new to the dark."  },
    { id="cartographer", label="Cartographer", desc="The true path. No shortcuts." },
    { id="pioneer",      label="Pioneer",      desc="The map ends where you do."   },
    { id="lost",         label="The Lost",     desc="No one is coming for you."    },
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
local currentDepot    = nil
local currentPanel    = nil
local currentPause    = nil
local autosaveTimer   = 0
local AUTOSAVE_INTERVAL = 180  -- seconds

-- Tooltip system
local tooltip = {
    text    = nil,
    timer   = 0,
    fadeIn  = 0,
}
local TOOLTIPS = {
    firstProbe  = { text="Probe built! Select it in the panel, then right-click the map to send it exploring.", shown=false },
    firstSelect = { text="Probe selected. Right-click anywhere on the bright cave floor to dispatch it.", shown=false },
    firstMove   = { text="Probe is moving! Use WASD to pan the camera and scroll to zoom.", shown=false },
    noPath      = { text="Can't reach that tile. Try a different spot, or use a Mining probe to dig through rock.", shown=false },
    lowResources= { text="Running low on resources. Send a Mining probe to find deposits.", shown=false },
}

-- ── Helpers ───────────────────────────────────────────────────────────────

function newButton(text, x, y, w, h, onClick)
    return { text=text, x=x, y=y, w=w, h=h, onClick=onClick }
end

function isHovered(btn)
    local mx, my = love.mouse.getPosition()
    return mx > btn.x and mx < btn.x+btn.w and my > btn.y and my < btn.y+btn.h
end

function roeNext(roe)
    if roe == "passive"   then return "defensive"  end
    if roe == "defensive" then return "aggressive" end
    return "passive"
end

function formationNext(f)
    if f == "spread"  then return "cluster" end
    if f == "cluster" then return "line"    end
    return "spread"
end

function formationOffsets(formation, count)
    local offsets = {}
    if count == 0 then return offsets end
    if formation == "cluster" then
        local ring = {{0,0},{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}
        for i = 1, count do
            offsets[i] = ring[((i-1) % #ring) + 1]
        end
    elseif formation == "line" then
        for i = 1, count do
            offsets[i] = { i - math.ceil(count/2), 0 }
        end
    else
        if count == 1 then
            offsets[1] = { 0, 0 }
        else
            for i = 1, count do
                local angle = (i-1) * (2 * math.pi / count)
                offsets[i] = {
                    math.floor(math.cos(angle) * 2),
                    math.floor(math.sin(angle) * 2),
                }
            end
        end
    end
    return offsets
end

function showTooltip(key)
    local t = TOOLTIPS[key]
    if t and not t.shown then
        tooltip.text   = t.text
        tooltip.timer  = 5.0
        tooltip.fadeIn = 0
        t.shown        = true
    end
end

-- ── Love callbacks ────────────────────────────────────────────────────────

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

    local bw, bh = 220, 38
    local bx = W/2 - bw/2
    local by = H/2 + 20
    buttons = {
        newButton("New Expedition", bx, by,      bw, bh, function() scene = "setup" end),
        newButton("Continue",       bx, by+52,   bw, bh, function() tryLoadSaves()  end),
        newButton("Quit",           bx, by+104,  bw, bh, function() love.event.quit() end),
    }

    local cx = W/2
    setup.name.x = cx - 160
    setup.name.y = H/2 - 160
    setup.seed.x = cx - 160
    setup.seed.y = H/2 - 80

    local dw, dh = 148, 48
    local dy = H/2 + 20
    difficultyButtons = {
        { d=difficulties[1], x=cx-152, y=dy,    w=dw, h=dh },
        { d=difficulties[2], x=cx+4,   y=dy,    w=dw, h=dh },
        { d=difficulties[3], x=cx-152, y=dy+58, w=dw, h=dh },
        { d=difficulties[4], x=cx+4,   y=dy+58, w=dw, h=dh },
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
        if currentPause then currentPause:update(dt) end
    end
    -- Tooltip fade
    if tooltip.timer > 0 then
        tooltip.timer  = tooltip.timer - dt
        tooltip.fadeIn = math.min(1, tooltip.fadeIn + dt * 3)
    end
end

function love.draw()
    if     scene == "menu"  then drawMenu()
    elseif scene == "setup" then drawSetup()
    elseif scene == "game"  then drawGame()
    end
end

function love.mousepressed(mx, my, button)
    -- Let pause menu swallow input when open
    if currentPause and currentPause.visible then
        currentPause:mousepressed(mx, my, button,
            function(data) loadGame(data) end,
            function() abandonGame()      end,
            function() end,
            setup, currentDepot, currentCave
        )
        return
    end

    if button ~= 1 and not (scene == "game" and button == 2) then return end

    if scene == "menu" then
        if button == 1 then
            for _, btn in ipairs(buttons) do
                if isHovered(btn) then btn.onClick() end
            end
        end

    elseif scene == "setup" then
        if button == 1 then
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

    elseif scene == "game" then
        local onMap = mx < W - SIDEBAR_W

        if button == 2 and onMap then
            if currentPanel:hasSelection() then
                local tx, ty = currentRenderer:screenToTile(mx, my, W - SIDEBAR_W, H)
                dispatchSelected(tx, ty)
            end

        elseif button == 1 and onMap then
            local shift   = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
            local clicked = probeAtScreen(mx, my)
            if clicked then
                currentPanel:select(clicked, shift)
                showTooltip("firstSelect")
            elseif currentPanel.awaitingTarget then
                local tx, ty = currentRenderer:screenToTile(mx, my, W - SIDEBAR_W, H)
                dispatchSelected(tx, ty)
            elseif not shift then
                currentPanel:clearSelection()
            end

        elseif button == 1 and not onMap then
            handlePanelClick(mx, my)
        end
    end
end

function love.textinput(t)
    if currentPause and currentPause.visible then
        currentPause:textinput(t)
        return
    end
    if activeInput then
        activeInput.value = activeInput.value .. t
    end
end

function love.keypressed(key)
    if currentPause and currentPause.visible then
        currentPause:keypressed(key)
        return
    end

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
        if scene == "setup" then
            scene = "menu"
        elseif scene == "game" then
            if currentPanel then
                currentPanel.awaitingTarget = false
                currentPanel:clearSelection()
            end
            if currentPause then currentPause:open() end
        end
    end
end

function love.wheelmoved(x, y)
    if currentPause and currentPause.visible then
        currentPause:wheelmoved(y)
        return
    end
    if scene ~= "game" then return end
    local mx = love.mouse.getX()
    if mx < W - SIDEBAR_W then
        if y > 0 then currentRenderer:zoomIn()
        else           currentRenderer:zoomOut()
        end
    else
        currentPanel:scroll(-y)
    end
end

-- ── Game logic ────────────────────────────────────────────────────────────

function startGame()
    local seed = tonumber(setup.seed.value) or math.random(99999)
    local size = difficultySizes[setup.difficulty]

    if size then
        currentCave = Cave.new(seed, size.w, size.h)
    else
        currentCave = Cave.newInfinite(seed)
    end

    local sx, sy = currentCave:nearestFloor(currentCave.startX, currentCave.startY)
    currentCave:reveal(sx, sy, 5)

    currentRenderer       = Renderer.new(currentCave)
    currentRenderer.viewW = W - SIDEBAR_W
    currentRenderer.camX  = sx
    currentRenderer.camY  = sy

    currentDepot = Depot.new(sx, sy)
    currentPanel = Panel.new(W - SIDEBAR_W, 0, SIDEBAR_W, H, buttonFont)
    currentPause = Pause.new(W, H, buttonFont, smallFont)

    autosaveTimer = AUTOSAVE_INTERVAL
    scene = "game"

    -- Reset tooltips for new run
    for _, t in pairs(TOOLTIPS) do t.shown = false end

    print("Name:", setup.name.value, "Seed:", seed, "Difficulty:", setup.difficulty)
end

function loadGame(data)
    local Cave2 = require("cave")
    if data.infinite then
        currentCave = Cave2.newInfinite(data.seed)
    else
        currentCave = Cave2.new(data.seed, data.caveW, data.caveH)
    end

    local sx, sy = data.depotX, data.depotY
    currentCave:reveal(sx, sy, 5)

    currentRenderer       = Renderer.new(currentCave)
    currentRenderer.viewW = W - SIDEBAR_W
    currentRenderer.camX  = sx
    currentRenderer.camY  = sy

    currentDepot = Depot.new(sx, sy)
    currentDepot.resources = {
        metal  = data.resources.metal,
        energy = data.resources.energy,
        rare   = data.resources.rare,
    }
    currentDepot.nextId = data.nextId or 1

    -- Restore probes
    local Probe2 = require("probe")
    for _, pd in ipairs(data.probes or {}) do
        local p = Probe2.new(pd.id, pd.type, pd.weapon, pd.x, pd.y, currentCave)
        p.roe    = pd.roe    or "defensive"
        p.hp     = pd.hp     or 100
        p.status = pd.status or "idle"
        p.cargo  = pd.cargo  or { metal=0, energy=0, rare=0 }
        currentCave:reveal(pd.x, pd.y, 4)
        table.insert(currentDepot.probes, p)
    end

    currentPanel = Panel.new(W - SIDEBAR_W, 0, SIDEBAR_W, H, buttonFont)
    currentPause = Pause.new(W, H, buttonFont, smallFont)

    -- Restore setup info for save display
    setup.name.value  = data.playerName or ""
    setup.difficulty  = data.difficulty or "apprentice"

    autosaveTimer = AUTOSAVE_INTERVAL
    scene = "game"
end

function abandonGame()
    currentCave     = nil
    currentRenderer = nil
    currentDepot    = nil
    currentPanel    = nil
    currentPause    = nil
    scene = "menu"
end

function tryLoadSaves()
    -- Open pause menu on load tab if saves exist
    if not currentPause then
        currentPause = Pause.new(W, H, buttonFont, smallFont)
    end
    currentPause:open()
    currentPause.tab = "load"
    -- Temporarily show pause over menu — reuse game scene trick
    scene = "game"
    -- Minimal stubs so drawGame doesn't crash
    if not currentRenderer then
        currentDepot = nil
        currentPanel = nil
    end
end

function continueGame()
    tryLoadSaves()
end

function updateGame(dt)
    if currentPause and currentPause.visible then return end

    local speed = 20 * dt
    if love.keyboard.isDown("w") then currentRenderer:pan(0, -speed) end
    if love.keyboard.isDown("s") then currentRenderer:pan(0,  speed) end
    if love.keyboard.isDown("a") then currentRenderer:pan(-speed, 0) end
    if love.keyboard.isDown("d") then currentRenderer:pan( speed, 0) end

    if currentDepot then
        local prevCount = currentDepot:aliveProbes()
        currentDepot:update(dt, currentCave, {})
        local newCount = currentDepot:aliveProbes()

        -- Tooltip triggers
        if newCount > prevCount then
            showTooltip("firstProbe")
        end

        -- Low resources hint
        local r = currentDepot.resources
        if r.metal < 10 and r.energy < 10 then
            showTooltip("lowResources")
        end

        -- Check if any probe started moving
        for _, p in ipairs(currentDepot.probes) do
            if p.status == "moving" then
                showTooltip("firstMove")
                break
            end
        end
    end

    -- Autosave
    if currentDepot and currentCave then
        autosaveTimer = autosaveTimer - dt
        if autosaveTimer <= 0 then
            autosaveTimer = AUTOSAVE_INTERVAL
            local data = Saves.serialise(setup, currentDepot, currentCave)
            Saves.write("autosave", data)
            print("Autosaved.")
        end
    end
end

-- ── Probe helpers ─────────────────────────────────────────────────────────

function probeAtScreen(sx, sy)
    if not currentDepot then return nil end
    local ts = currentRenderer.tileSize * currentRenderer.zoom
    local vW = W - SIDEBAR_W
    for _, probe in ipairs(currentDepot.probes) do
        if probe.alive then
            local px, py = currentRenderer:tileToScreen(probe.x, probe.y, vW, H)
            local dist = math.sqrt((sx-(px+ts/2))^2 + (sy-(py+ts/2))^2)
            if dist <= math.max(6, ts/2) then
                return probe.id
            end
        end
    end
    return nil
end

function dispatchSelected(tx, ty)
    if not currentDepot or not currentPanel then return end
    local probes = {}
    for id in pairs(currentPanel.selected) do
        local probe = currentDepot:getProbe(id)
        if probe then table.insert(probes, probe) end
    end
    local offsets = formationOffsets(currentPanel.formation, #probes)
    for i, probe in ipairs(probes) do
        probe:setTarget(tx + offsets[i][1], ty + offsets[i][2])
    end
    currentPanel.awaitingTarget = false
end

function handlePanelClick(mx, my)
    local p   = currentPanel
    local dep = currentDepot
    if not p or not dep then return end

    if p.listTopY and p.listTopY > 0 and my >= p.listTopY then
        local id = p:probeRowAt(my, dep)
        if id then
            local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
            p:select(id, shift)
            showTooltip("firstSelect")
            return
        end
    end

    local bbt = p.buttons.buildType
    if bbt.w > 0 and mx > bbt.x and mx < bbt.x+bbt.w and my > bbt.y and my < bbt.y+bbt.h then
        local types = {"explorer","mining","defense"}
        for i, t in ipairs(types) do
            if t == p.buildType then p.buildType = types[i % #types + 1]; break end
        end
    end

    local bbw = p.buttons.buildWeapon
    if bbw.w > 0 and mx > bbw.x and mx < bbw.x+bbw.w and my > bbw.y and my < bbw.y+bbw.h then
        local weapons = {"none","gun","rocket","laser"}
        for i, ww in ipairs(weapons) do
            if ww == p.buildWeapon then p.buildWeapon = weapons[i % #weapons + 1]; break end
        end
    end

    local bb = p.buttons.build
    if bb.w > 0 and mx > bb.x and mx < bb.x+bb.w and my > bb.y and my < bb.y+bb.h then
        dep:queueProbe(p.buildType, p.buildWeapon, currentCave)
    end

    if p:hasSelection() then
        local brb = p.buttons.roe
        if brb.w > 0 and mx > brb.x and mx < brb.x+brb.w and my > brb.y and my < brb.y+brb.h then
            for id in pairs(p.selected) do
                local probe = dep:getProbe(id)
                if probe then probe.roe = roeNext(probe.roe) end
            end
        end

        local bfb = p.buttons.formation
        if bfb.w > 0 and mx > bfb.x and mx < bfb.x+bfb.w and my > bfb.y and my < bfb.y+bfb.h then
            p.formation = formationNext(p.formation)
        end

        local stb = p.buttons.setTarget
        if stb.w > 0 and mx > stb.x and mx < stb.x+stb.w and my > stb.y and my < stb.y+stb.h then
            p.awaitingTarget = not p.awaitingTarget
        end
    end
end

-- ── Draw functions ────────────────────────────────────────────────────────

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
    love.graphics.setColor(hovered and {0.95,0.90,0.75} or {0.55,0.50,0.40})
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

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.88, 0.82, 0.68)
    local tw = titleFont:getWidth("New Expedition")
    love.graphics.print("New Expedition", W/2-tw/2, H/2-240)

    love.graphics.setColor(0.5, 0.45, 0.35, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(W/2-120, H/2-190, W/2+120, H/2-190)

    love.graphics.setFont(buttonFont)
    for _, inp in ipairs({ setup.name, setup.seed }) do
        love.graphics.setColor(0.55, 0.50, 0.40)
        love.graphics.print(inp == setup.name and "Name" or "Seed", inp.x, inp.y-22)

        love.graphics.setColor(0.05, 0.04, 0.03, 0.8)
        love.graphics.rectangle("fill", inp.x, inp.y, inp.w, inp.h)

        love.graphics.setColor(inp.active and {0.88,0.82,0.68,0.6} or {0.55,0.50,0.40,0.4})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", inp.x, inp.y, inp.w, inp.h)

        local display = #inp.value > 0 and inp.value or inp.placeholder
        love.graphics.setColor(#inp.value > 0 and {0.88,0.82,0.68} or {0.35,0.32,0.26})
        love.graphics.print(display, inp.x+10, inp.y+inp.h/2-buttonFont:getHeight()/2)

        if inp.active and (love.timer.getTime() % 1) < 0.5 then
            local cursorX = inp.x + 10 + buttonFont:getWidth(inp.value)
            love.graphics.setColor(0.88, 0.82, 0.68, 0.8)
            love.graphics.line(cursorX, inp.y+8, cursorX, inp.y+inp.h-8)
        end
    end

    love.graphics.setFont(buttonFont)
    for _, db in ipairs(difficultyButtons) do
        local dmx, dmy = love.mouse.getPosition()
        local hovered  = dmx > db.x and dmx < db.x+db.w and dmy > db.y and dmy < db.y+db.h
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

    local canBegin = setup.difficulty ~= nil and #setup.name.value > 0
    local bHovered = isHovered(beginButton)

    if bHovered and canBegin then
        love.graphics.setColor(0.88, 0.82, 0.68, 0.08)
        love.graphics.rectangle("fill", beginButton.x, beginButton.y, beginButton.w, beginButton.h)
        love.graphics.setColor(0.88, 0.82, 0.68, 0.7)
        love.graphics.rectangle("fill", beginButton.x-6, beginButton.y+10, 2, beginButton.h-20)
    end

    love.graphics.setFont(buttonFont)
    love.graphics.setColor(not canBegin and {0.30,0.28,0.22} or bHovered and {0.95,0.90,0.75} or {0.55,0.50,0.40})
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
        currentRenderer:draw(W - SIDEBAR_W, H)
    end

    if currentDepot and currentPanel then
        drawDepotOverlay()
        currentPanel:draw(currentDepot)
    end

    -- Tooltip
    if tooltip.text and tooltip.timer > 0 then
        local alpha = math.min(tooltip.fadeIn, math.min(1, tooltip.timer))
        love.graphics.setFont(smallFont)
        local tw = smallFont:getWidth(tooltip.text)
        local tx = (W - SIDEBAR_W)/2 - tw/2
        local ty = H - 52
        love.graphics.setColor(0, 0, 0, 0.6 * alpha)
        love.graphics.rectangle("fill", tx-10, ty-6, tw+20, smallFont:getHeight()+12, 4, 4)
        love.graphics.setColor(0.88, 0.82, 0.68, alpha)
        love.graphics.print(tooltip.text, tx, ty)
    end

    -- Await target hint
    if currentPanel and currentPanel.awaitingTarget then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.88, 0.82, 0.68, 0.7)
        local hint = "Right-click or left-click on map to set target"
        local hw = smallFont:getWidth(hint)
        love.graphics.print(hint, (W - SIDEBAR_W)/2 - hw/2, H - 30)
    end

    -- Pause menu on top
    if currentPause then
        currentPause:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

function drawDepotOverlay()
    local ts = currentRenderer.tileSize * currentRenderer.zoom
    local vW = W - SIDEBAR_W

    -- Depot
    local dx, dy = currentRenderer:tileToScreen(currentDepot.x, currentDepot.y, vW, H)
    love.graphics.setColor(0.95, 0.85, 0.50)
    love.graphics.rectangle("fill", dx, dy, ts, ts)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("line", dx, dy, ts, ts)

    -- Probes
    for _, probe in ipairs(currentDepot.probes) do
        if probe.alive then
            local sx, sy = currentRenderer:tileToScreen(probe.x, probe.y, vW, H)
            local col    = probe:getColor()
            local r      = math.max(3, ts/3)

            if currentPanel:isSelected(probe.id) then
                love.graphics.setColor(1, 1, 1, 0.6)
                love.graphics.circle("line", sx+ts/2, sy+ts/2, r+3)
            end

            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.circle("fill", sx+ts/2, sy+ts/2, r)

            -- Dig progress ring
            local digPct = probe:digProgress()
            if digPct then
                love.graphics.setColor(0.95, 0.70, 0.20, 0.8)
                love.graphics.arc("line", sx+ts/2, sy+ts/2, r+5, 0, digPct * math.pi * 2)
            end

            if probe.hp < probe.maxHp then
                love.graphics.setColor(0.6, 0.1, 0.1)
                love.graphics.rectangle("fill", sx, sy-5, ts, 3)
                love.graphics.setColor(0.2, 0.8, 0.2)
                love.graphics.rectangle("fill", sx, sy-5, ts*(probe.hp/probe.maxHp), 3)
            end

            if probe.lastFiredAt and (love.timer.getTime() - probe.lastFiredAt.time) < 0.1 then
                local fx, fy = currentRenderer:tileToScreen(probe.lastFiredAt.x, probe.lastFiredAt.y, vW, H)
                love.graphics.setColor(1, 0.9, 0.3, 0.7)
                love.graphics.line(sx+ts/2, sy+ts/2, fx+ts/2, fy+ts/2)
            end
        end
    end

    -- HUD strip
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, vW, 28)
    love.graphics.setFont(buttonFont)
    love.graphics.setColor(0.88, 0.82, 0.68, 0.9)
    love.graphics.print(
        string.format("Metal: %d   Energy: %d   Rare: %d   Probes: %d   Queue: %d   [ESC] Pause",
            currentDepot.resources.metal,
            currentDepot.resources.energy,
            currentDepot.resources.rare,
            currentDepot:aliveProbes(),
            #currentDepot.queue
        ),
        10, 6
    )
end