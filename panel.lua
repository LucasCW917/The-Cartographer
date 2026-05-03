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

function Panel.new(x, y, w, h, font)
    local self  = setmetatable({}, Panel)
    self.x      = x
    self.y      = y
    self.w      = w
    self.h      = h
    self.font   = font

    self.selected          = {}
    self.formation         = "spread"
    self.awaitingTarget    = false

    self.buildType         = "explorer"
    self.buildWeapon       = "none"

    self.scrollY           = 0
    self.rowH              = 52

    -- button rects are set dynamically each draw, stored here for click testing
    self.buttons = {
        buildType   = { x=0, y=0, w=0, h=28 },
        buildWeapon = { x=0, y=0, w=0, h=28 },
        build       = { x=0, y=0, w=0, h=28 },
        roe         = { x=0, y=0, w=0, h=28 },
        formation   = { x=0, y=0, w=0, h=28 },
        setTarget   = { x=0, y=0, w=0, h=28 },
    }

    self.listTopY = 0   -- updated each draw, used for click testing

    return self
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

-- ── Internal draw helpers ────────────────────────────────────────────────

function Panel:_isHovered(btn)
    local mx, my = love.mouse.getPosition()
    return mx > btn.x and mx < btn.x+btn.w and my > btn.y and my < btn.y+btn.h
end

function Panel:_drawBtn(btn, label, active)
    local hovered = self:_isHovered(btn)
    love.graphics.setColor(
        active  and {0.88,0.82,0.68,0.22} or
        hovered and {0.88,0.82,0.68,0.09} or
                    {0.0, 0.0, 0.0, 0.0}
    )
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(hovered and {0.88,0.82,0.68,0.6} or {0.45,0.40,0.32,0.5})
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(hovered and {0.95,0.90,0.75} or {0.65,0.60,0.48})
    love.graphics.setFont(self.font)
    local tw = self.font:getWidth(label)
    local fh = self.font:getHeight()
    love.graphics.print(label, btn.x + btn.w/2 - tw/2, btn.y + btn.h/2 - fh/2)
end

function Panel:_section(label, cx, cy)
    love.graphics.setColor(0.70, 0.62, 0.46)
    love.graphics.setFont(self.font)
    love.graphics.print(label, cx, cy)
    return cy + self.font:getHeight() + 6
end

function Panel:_divider(cx, cy, w)
    love.graphics.setColor(0.40, 0.36, 0.28, 0.5)
    love.graphics.line(cx, cy, cx + w, cy)
    return cy + 10
end

-- ── Main draw ────────────────────────────────────────────────────────────

function Panel:draw(depot)
    local x, y, w, h = self.x, self.y, self.w, self.h
    local fh  = self.font:getHeight()
    local cx  = x + 10
    local bw  = w - 20

    -- Panel background
    love.graphics.setColor(0.07, 0.06, 0.04, 0.97)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.45, 0.40, 0.32, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(0.60, 0.52, 0.38, 0.4)
    love.graphics.rectangle("fill", x, y, 2, h)

    local cy = y + 12

    -- ── Resources ──────────────────────────────────────────────────────
    cy = self:_section("Depot Resources", cx, cy)

    local res = depot.resources
    local function resRow(label, val, col)
        love.graphics.setColor(col)
        love.graphics.setFont(self.font)
        love.graphics.print(string.format("%-8s %d", label, val), cx, cy)
        cy = cy + fh + 2
    end
    resRow("Metal",  res.metal,  {0.75, 0.72, 0.65})
    resRow("Energy", res.energy, {0.55, 0.80, 0.90})
    resRow("Rare",   res.rare,   {0.85, 0.60, 0.90})

    cy = cy + 4
    cy = self:_divider(cx, cy, bw)

    -- ── Manufacture ────────────────────────────────────────────────────
    cy = self:_section("Manufacture", cx, cy)

    local halfW = bw/2 - 2
    local bbt   = self.buttons.buildType
    local bbw   = self.buttons.buildWeapon
    bbt.x = cx;           bbt.y = cy; bbt.w = halfW
    bbw.x = cx+halfW+4;   bbw.y = cy; bbw.w = halfW
    self:_drawBtn(bbt, self.buildType:sub(1,1):upper() .. self.buildType:sub(2))
    self:_drawBtn(bbw, self.buildWeapon:sub(1,1):upper() .. self.buildWeapon:sub(2))
    cy = cy + bbt.h + 4

    local cost      = depot:getCost(self.buildType, self.buildWeapon)
    local canAfford = depot:canAfford(self.buildType, self.buildWeapon)
    love.graphics.setFont(self.font)
    love.graphics.setColor(canAfford and {0.55,0.80,0.55} or {0.85,0.40,0.40})
    love.graphics.print(string.format("M:%d  E:%d  R:%d", cost.metal, cost.energy, cost.rare), cx, cy)
    cy = cy + fh + 2

    love.graphics.setColor(0.50, 0.46, 0.38)
    if #depot.queue > 0 then
        local pct = math.floor((depot.buildTimer / depot.buildTime) * 100)
        love.graphics.print(string.format("Building %d%%  +%d queued", pct, #depot.queue-1), cx, cy)
    else
        love.graphics.print("Queue empty", cx, cy)
    end
    cy = cy + fh + 4

    local bb = self.buttons.build
    bb.x = cx; bb.y = cy; bb.w = bw
    self:_drawBtn(bb, "Build Probe", not canAfford)
    cy = cy + bb.h + 8

    cy = self:_divider(cx, cy, bw)

    -- ── Selection controls ─────────────────────────────────────────────
    if self:hasSelection() then
        cy = self:_section(string.format("Selected  (%d)", self:selectedCount()), cx, cy)

        -- Determine shared ROE for display
        local sharedROE = nil
        for id in pairs(self.selected) do
            local p = depot:getProbe(id)
            if p then
                if sharedROE == nil then
                    sharedROE = p.roe
                elseif sharedROE ~= p.roe then
                    sharedROE = "mixed"
                end
            end
        end

        local roeLabel = "ROE: " .. (ROE_LABELS[sharedROE] or "Mixed")
        local brb = self.buttons.roe
        brb.x = cx; brb.y = cy; brb.w = bw
        self:_drawBtn(brb, roeLabel)
        cy = cy + brb.h + 4

        local bfb = self.buttons.formation
        bfb.x = cx; bfb.y = cy; bfb.w = bw
        self:_drawBtn(bfb, "Formation: " .. FORMATION_LABELS[self.formation])
        cy = cy + bfb.h + 4

        local stb = self.buttons.setTarget
        stb.x = cx; stb.y = cy; stb.w = bw
        self:_drawBtn(stb, self.awaitingTarget and "[ Click map... ]" or "Set Target", self.awaitingTarget)
        cy = cy + stb.h + 8

        cy = self:_divider(cx, cy, bw)
    end

    -- ── Probe list ─────────────────────────────────────────────────────
    cy = self:_section(string.format("Probes  %d", depot:aliveProbes()), cx, cy)
    self.listTopY = cy

    local listH = h - (cy - y) - 8
    love.graphics.setScissor(x, cy, w, listH)

    local ry = cy - self.scrollY
    for _, probe in ipairs(depot.probes) do
        if not probe.alive then goto skip end

        -- Only draw rows visible in the list
        if ry + self.rowH > cy and ry < cy + listH then
            local col      = colorForType(probe.type)
            local selected = self:isSelected(probe.id)

            if selected then
                love.graphics.setColor(col[1], col[2], col[3], 0.14)
                love.graphics.rectangle("fill", x+2, ry, w-4, self.rowH)
            end

            -- Type color stripe
            love.graphics.setColor(col)
            love.graphics.rectangle("fill", x+4, ry+8, 3, self.rowH-16)

            -- Name line
            love.graphics.setFont(self.font)
            love.graphics.setColor(selected and {0.95,0.90,0.75} or {0.70,0.65,0.52})
            love.graphics.print(
                string.format("#%d  %s", probe.id,
                    probe.type:sub(1,1):upper() .. probe.type:sub(2)),
                cx+8, ry+6
            )

            -- Status line
            love.graphics.setColor(0.48, 0.44, 0.36)
            love.graphics.print(probe.status, cx+8, ry+6+fh+1)

            -- Weapon badge
            if probe.weapon ~= "none" then
                love.graphics.setColor(0.70, 0.52, 0.32)
                local ww = self.font:getWidth("[" .. probe.weapon .. "]")
                love.graphics.print("[" .. probe.weapon .. "]", x+w-ww-8, ry+6)
            end

            -- HP bar
            local barW = w - 28
            love.graphics.setColor(0.22, 0.08, 0.08)
            love.graphics.rectangle("fill", cx+8, ry+self.rowH-10, barW, 4)
            love.graphics.setColor(col[1]*0.85, col[2]*0.85, col[3]*0.85)
            love.graphics.rectangle("fill", cx+8, ry+self.rowH-10, barW*(probe.hp/probe.maxHp), 4)

            -- Row divider
            love.graphics.setColor(0.28, 0.25, 0.19, 0.4)
            love.graphics.line(x+4, ry+self.rowH, x+w-4, ry+self.rowH)
        end

        ry = ry + self.rowH
        ::skip::
    end

    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1)
end

-- Returns probe id clicked in the list, or nil
function Panel:probeRowAt(my, depot)
    local ry = self.listTopY - self.scrollY
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