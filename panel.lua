-- panel.lua
local Panel = {}
Panel.__index = Panel

local ROE_LABELS = {
    passive    = "Passive",
    defensive  = "Defensive",
    aggressive = "Aggressive",
}

local FORMATION_LABELS = {
    spread  = "Spread",
    cluster = "Cluster",
    line    = "Line",
}

local function colorForType(t)
    if t == "explorer" then return { 0.70, 0.85, 0.95 } end
    if t == "mining"   then return { 0.95, 0.78, 0.40 } end
    if t == "defense"  then return { 0.95, 0.45, 0.40 } end
    return { 1, 1, 1 }
end

local function roeNext(roe)
    if roe == "passive"    then return "defensive"  end
    if roe == "defensive"  then return "aggressive" end
    return "passive"
end

local function formationNext(f)
    if f == "spread"  then return "cluster" end
    if f == "cluster" then return "line"    end
    return "spread"
end

function Panel.new(x, y, w, h, font)
    local self = setmetatable({}, Panel)
    self.x    = x
    self.y    = y
    self.w    = w
    self.h    = h
    self.font = font

    self.selected   = {}     -- set of probe ids
    self.formation  = "spread"
    self.awaitingTarget = false  -- true when user clicked "Set Target"

    -- Probe build UI state
    self.buildType   = "explorer"
    self.buildWeapon = "none"

    -- Scroll offset for probe list
    self.scrollY = 0
    self.rowH    = 48

    -- Buttons (populated in layout)
    self.buttons = {}

    self:_buildLayout()
    return self
end

function Panel:_buildLayout()
    local bx = self.x + 10
    local bw = self.w - 20
    local bh = 28

    self.buttons = {
        -- ROE cycle
        roe = { x=bx, y=0, w=bw, h=bh, label=function()
            local roe = self:_commonROE()
            return "ROE: " .. ROE_LABELS[roe or "defensive"]
        end },
        -- Formation cycle
        formation = { x=bx, y=0, w=bw, h=bh, label=function()
            return "Formation: " .. FORMATION_LABELS[self.formation]
        end },
        -- Set target
        setTarget = { x=bx, y=0, w=bw, h=bh, label=function()
            return self.awaitingTarget and "[ Click map... ]" or "Set Target"
        end },
        -- Build type cycle
        buildType = { x=bx, y=0, w=bw/2-2, h=bh, label=function()
            return self.buildType:sub(1,1):upper() .. self.buildType:sub(2)
        end },
        -- Build weapon cycle
        buildWeapon = { x=bx + bw/2+2, y=0, w=bw/2-2, h=bh, label=function()
            return self.buildWeapon:sub(1,1):upper() .. self.buildWeapon:sub(2)
        end },
        -- Queue build
        build = { x=bx, y=0, w=bw, h=bh, label=function() return "Build Probe" end },
    }
end

function Panel:_commonROE()
    -- Returns the ROE if all selected probes share one, else nil
    local roe = nil
    for id, _ in pairs(self.selected) do
        -- id is probe id, will be resolved externally
        roe = roe  -- placeholder, resolved in draw with depot
    end
    return roe or "defensive"
end

function Panel:select(probeId, additive)
    if not additive then self.selected = {} end
    self.selected[probeId] = true
end

function Panel:deselect(probeId)
    self.selected[probeId] = nil
end

function Panel:clearSelection()
    self.selected = {}
end

function Panel:hasSelection()
    return next(self.selected) ~= nil
end

function Panel:selectedCount()
    local n = 0
    for _ in pairs(self.selected) do n = n + 1 end
    return n
end

function Panel:isSelected(probeId)
    return self.selected[probeId] == true
end

function Panel:scroll(dy)
    self.scrollY = math.max(0, self.scrollY + dy * 30)
end

function Panel:_btn(name, x, y)
    local b = self.buttons[name]
    b.x = x
    b.y = y
    return b
end

function Panel:_isHovered(btn)
    local mx, my = love.mouse.getPosition()
    return mx > btn.x and mx < btn.x+btn.w and my > btn.y and my < btn.y+btn.h
end

function Panel:_drawButton(btn, active)
    local hovered = self:_isHovered(btn)
    local bg = active  and {0.88, 0.82, 0.68, 0.20} or
               hovered and {0.88, 0.82, 0.68, 0.08} or
                           {0.0,  0.0,  0.0,  0.0}

    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(hovered and {0.88,0.82,0.68,0.6} or {0.45,0.40,0.32,0.6})
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

    local label = type(btn.label) == "function" and btn.label() or btn.label
    love.graphics.setColor(hovered and {0.95,0.90,0.75} or {0.65,0.60,0.48})
    love.graphics.setFont(self.font)
    local tw = self.font:getWidth(label)
    love.graphics.print(label, btn.x + btn.w/2 - tw/2, btn.y + btn.h/2 - self.font:getHeight()/2)
end

function Panel:draw(depot)
    local x, y, w, h = self.x, self.y, self.w, self.h
    local fh = self.font:getHeight()

    -- Background
    love.graphics.setColor(0.07, 0.06, 0.04, 0.96)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.45, 0.40, 0.32, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)

    -- Left edge accent
    love.graphics.setColor(0.60, 0.52, 0.38, 0.4)
    love.graphics.rectangle("fill", x, y, 2, h)

    local cx = x + 10
    local cy = y + 12

    -- ── Resources ──────────────────────────────────────────
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.70, 0.62, 0.46)
    love.graphics.print("Depot Resources", cx, cy)
    cy = cy + fh + 4

    local res = depot.resources
    local function resLine(label, val, col)
        love.graphics.setColor(col)
        love.graphics.print(string.format("%-8s %d", label, val), cx, cy)
        cy = cy + fh + 2
    end
    resLine("Metal",  res.metal,  {0.75, 0.72, 0.65})
    resLine("Energy", res.energy, {0.55, 0.80, 0.90})
    resLine("Rare",   res.rare,   {0.85, 0.60, 0.90})

    cy = cy + 6
    love.graphics.setColor(0.40, 0.36, 0.28, 0.5)
    love.graphics.line(cx, cy, x+w-10, cy)
    cy = cy + 10

    -- ── Build ───────────────────────────────────────────────
    love.graphics.setColor(0.70, 0.62, 0.46)
    love.graphics.print("Manufacture", cx, cy)
    cy = cy + fh + 6

    -- Type + weapon buttons side by side
    local bbt = self.buttons.buildType
    local bbw = self.buttons.buildWeapon
    bbt.x = cx;           bbt.y = cy
    bbw.x = cx+bbt.w+4;  bbw.y = cy
    self:_drawButton(bbt)
    self:_drawButton(bbw)
    cy = cy + bbt.h + 4

    -- Cost preview
    local cost = depot:getCost(self.buildType, self.buildWeapon)
    local canAfford = depot:canAfford(self.buildType, self.buildWeapon)
    love.graphics.setColor(canAfford and {0.55,0.75,0.55} or {0.80,0.40,0.40})
    love.graphics.print(
        string.format("Cost  M:%d E:%d R:%d", cost.metal, cost.energy, cost.rare),
        cx, cy
    )
    cy = cy + fh + 4

    -- Queue info
    love.graphics.setColor(0.55, 0.50, 0.40)
    if #depot.queue > 0 then
        local pct = depot.buildTimer / depot.buildTime
        love.graphics.print(string.format("Building... %d%%  (+%d queued)",
            math.floor(pct*100), #depot.queue - 1), cx, cy)
    else
        love.graphics.print("Queue empty", cx, cy)
    end
    cy = cy + fh + 4

    local bb = self.buttons.build
    bb.x = cx; bb.y = cy
    self:_drawButton(bb, not canAfford)
    cy = cy + bb.h + 8

    love.graphics.setColor(0.40, 0.36, 0.28, 0.5)
    love.graphics.line(cx, cy, x+w-10, cy)
    cy = cy + 10

    -- ── Selection controls ──────────────────────────────────
    if self:hasSelection() then
        love.graphics.setColor(0.70, 0.62, 0.46)
        love.graphics.print(
            string.format("Selected  (%d)", self:selectedCount()),
            cx, cy
        )
        cy = cy + fh + 6

        -- ROE button
        local brb = self:_btn("roe", cx, cy)
        self:_drawButton(brb)
        cy = cy + brb.h + 4

        -- Formation button
        local bfb = self:_btn("formation", cx, cy)
        self:_drawButton(bfb)
        cy = cy + bfb.h + 4

        -- Set target button
        local stb = self:_btn("setTarget", cx, cy)
        self:_drawButton(stb, self.awaitingTarget)
        cy = cy + stb.h + 8

        love.graphics.setColor(0.40, 0.36, 0.28, 0.5)
        love.graphics.line(cx, cy, x+w-10, cy)
        cy = cy + 10
    end

    -- ── Probe list ──────────────────────────────────────────
    love.graphics.setColor(0.70, 0.62, 0.46)
    love.graphics.print(
        string.format("Probes  %d", depot:aliveProbes()),
        cx, cy
    )
    cy = cy + fh + 6

    -- Scissor to clip probe list
    local listTop = cy
    local listH   = h - (cy - y) - 10
    love.graphics.setScissor(x, listTop, w, listH)

    local ry = cy - self.scrollY
    for _, probe in ipairs(depot.probes) do
        if not probe.alive then goto nextProbe end

        local selected = self:isSelected(probe.id)
        local rowY     = ry
        local col      = colorForType(probe.type)

        -- Row background
        if selected then
            love.graphics.setColor(col[1], col[2], col[3], 0.15)
            love.graphics.rectangle("fill", x+2, rowY, w-4, self.rowH)
        end

        -- Color stripe
        love.graphics.setColor(col)
        love.graphics.rectangle("fill", x+2, rowY+6, 3, self.rowH-12)

        -- Name + status
        love.graphics.setColor(selected and {0.95,0.90,0.75} or {0.65,0.60,0.48})
        love.graphics.print(
            string.format("#%d %s", probe.id, probe.type:sub(1,1):upper()..probe.type:sub(2)),
            cx+6, rowY+4
        )
        love.graphics.setColor(0.50, 0.46, 0.38)
        love.graphics.print(probe.status, cx+6, rowY+4+fh+1)

        -- HP bar
        local barW = w - 30
        love.graphics.setColor(0.25, 0.10, 0.10)
        love.graphics.rectangle("fill", cx+6, rowY+self.rowH-10, barW, 4)
        love.graphics.setColor(col[1]*0.8, col[2]*0.8, col[3]*0.8)
        love.graphics.rectangle("fill", cx+6, rowY+self.rowH-10, barW*(probe.hp/probe.maxHp), 4)

        -- Weapon badge
        if probe.weapon ~= "none" then
            love.graphics.setColor(0.70, 0.50, 0.30)
            love.graphics.print("[" .. probe.weapon .. "]", x+w-52, rowY+4)
        end

        -- Row border
        love.graphics.setColor(0.30, 0.27, 0.20, 0.4)
        love.graphics.line(x+2, rowY+self.rowH, x+w-2, rowY+self.rowH)

        ry = ry + self.rowH
        ::nextProbe::
    end

    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1)
end

-- Returns which probe row was clicked, or nil
function Panel:probeRowAt(my, depot, listTopY)
    local ry = listTopY - self.scrollY
    for _, probe in ipairs(depot.probes) do
        if not probe.alive then goto skip end
        if my >= ry and my < ry + self.rowH then
            return probe.id
        end
        ry = ry + self.rowH
        ::skip::
    end
    return nil
end

return Panel