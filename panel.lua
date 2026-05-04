local Panel = {}
Panel.__index = Panel

local ROE_LABELS = { passive="Passive", defensive="Defensive", aggressive="Aggressive" }
local FORMATION_LABELS = { spread="Spread", cluster="Cluster", line="Line" }

local function colorForType(t)
    if t == "explorer" then return {0.70,0.85,0.95} end
    if t == "mining"   then return {0.95,0.78,0.40} end
    if t == "defense"  then return {0.95,0.45,0.40} end
    return {1,1,1}
end

function Panel.new(x, y, w, h, font)
    local self = setmetatable({}, Panel)
    self.x = x; self.y = y; self.w = w; self.h = h; self.font = font
    self.selected       = {}
    self.formation      = "spread"
    self.awaitingTarget = false
    self.buildType      = "explorer"
    self.buildWeapon    = "none"
    self.scrollY        = 0
    self.rowH           = 48
    self._lastROE       = "defensive"
    self.buttons        = {}
    self:_buildLayout()
    return self
end

function Panel:_buildLayout()
    local bx = self.x + 10
    local bw = self.w - 20
    local bh = 28
    self.buttons = {
        roe         = { x=bx, y=0, w=bw,       h=bh, label=function() return "ROE: "..(ROE_LABELS[self._lastROE] or "Mixed") end },
        formation   = { x=bx, y=0, w=bw,       h=bh, label=function() return "Formation: "..FORMATION_LABELS[self.formation] end },
        setTarget   = { x=bx, y=0, w=bw,       h=bh, label=function() return self.awaitingTarget and "[ Click map... ]" or "Set Target" end },
        buildType   = { x=bx, y=0, w=bw/2-2,   h=bh, label=function() return self.buildType:sub(1,1):upper()..self.buildType:sub(2) end },
        buildWeapon = { x=bx+bw/2+2, y=0, w=bw/2-2, h=bh, label=function() return self.buildWeapon:sub(1,1):upper()..self.buildWeapon:sub(2) end },
        build       = { x=bx, y=0, w=bw,       h=bh, label=function() return "Build Probe" end },
    }
end

function Panel:select(probeId, additive)
    if not additive then self.selected = {} end
    self.selected[probeId] = true
end

function Panel:deselect(probeId)    self.selected[probeId] = nil end
function Panel:clearSelection()     self.selected = {}; self.awaitingTarget = false end
function Panel:hasSelection()       return next(self.selected) ~= nil end
function Panel:isSelected(probeId)  return self.selected[probeId] == true end
function Panel:scroll(dy)           self.scrollY = math.max(0, self.scrollY + dy*30) end

function Panel:selectedCount()
    local n = 0; for _ in pairs(self.selected) do n = n+1 end; return n
end

function Panel:_isHovered(btn)
    local mx, my = love.mouse.getPosition()
    return mx > btn.x and mx < btn.x+btn.w and my > btn.y and my < btn.y+btn.h
end

function Panel:_drawButton(btn, dimmed)
    local hovered = self:_isHovered(btn)
    love.graphics.setColor(dimmed and {0.20,0.18,0.14,0.8} or hovered and {0.88,0.82,0.68,0.10} or {0,0,0,0})
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(hovered and {0.88,0.82,0.68,0.6} or {0.40,0.36,0.28,0.5})
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
    local label = type(btn.label)=="function" and btn.label() or btn.label
    love.graphics.setColor(dimmed and {0.35,0.32,0.26} or hovered and {0.95,0.90,0.75} or {0.65,0.60,0.48})
    love.graphics.setFont(self.font)
    local tw = self.font:getWidth(label)
    love.graphics.print(label, btn.x+btn.w/2-tw/2, btn.y+btn.h/2-self.font:getHeight()/2)
end

function Panel:draw(depot)
    local x,y,w,h = self.x,self.y,self.w,self.h
    local fh = self.font:getHeight()
    local cx = x+10

    love.graphics.setColor(0.07,0.06,0.04,0.97)
    love.graphics.rectangle("fill",x,y,w,h)
    love.graphics.setColor(0.45,0.40,0.32,0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line",x,y,w,h)
    love.graphics.setColor(0.60,0.52,0.38,0.4)
    love.graphics.rectangle("fill",x,y,2,h)

    local cy = y+12

    -- Resources
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.70,0.62,0.46)
    love.graphics.print("Depot Resources", cx, cy); cy=cy+fh+4

    local function resLine(lbl,val,col)
        love.graphics.setColor(col)
        love.graphics.print(string.format("%-8s %d",lbl,val),cx,cy); cy=cy+fh+2
    end
    resLine("Metal",  depot.resources.metal,  {0.75,0.72,0.65})
    resLine("Energy", depot.resources.energy, {0.55,0.80,0.90})
    resLine("Rare",   depot.resources.rare,   {0.85,0.60,0.90})

    cy=cy+6
    love.graphics.setColor(0.40,0.36,0.28,0.5)
    love.graphics.line(cx,cy,x+w-10,cy); cy=cy+10

    -- Manufacture
    love.graphics.setColor(0.70,0.62,0.46)
    love.graphics.print("Manufacture",cx,cy); cy=cy+fh+6

    local bbt=self.buttons.buildType
    local bbw=self.buttons.buildWeapon
    bbt.x=cx; bbt.y=cy; bbw.x=cx+bbt.w+4; bbw.y=cy
    self:_drawButton(bbt); self:_drawButton(bbw); cy=cy+bbt.h+4

    local cost=depot:getCost(self.buildType,self.buildWeapon)
    local canAfford=depot:canAfford(self.buildType,self.buildWeapon)
    love.graphics.setFont(self.font)
    love.graphics.setColor(canAfford and {0.55,0.75,0.55} or {0.80,0.40,0.40})
    love.graphics.print(string.format("Cost  M:%d E:%d R:%d",cost.metal,cost.energy,cost.rare),cx,cy); cy=cy+fh+4

    love.graphics.setColor(0.50,0.46,0.36)
    if #depot.queue>0 then
        love.graphics.print(string.format("Building %d%%  (+%d)",math.floor(depot.buildTimer/depot.buildTime*100),#depot.queue-1),cx,cy)
    else
        love.graphics.print("Queue empty",cx,cy)
    end
    cy=cy+fh+4

    local bb=self.buttons.build; bb.x=cx; bb.y=cy
    self:_drawButton(bb, not canAfford); cy=cy+bb.h+8

    love.graphics.setColor(0.40,0.36,0.28,0.5)
    love.graphics.line(cx,cy,x+w-10,cy); cy=cy+10

    -- Selection
    if self:hasSelection() then
        local commonROE=nil
        for id in pairs(self.selected) do
            local probe=depot:getProbe(id)
            if probe then
                if commonROE==nil then commonROE=probe.roe
                elseif commonROE~=probe.roe then commonROE="mixed"; break end
            end
        end
        self._lastROE=commonROE

        love.graphics.setColor(0.70,0.62,0.46)
        love.graphics.print(string.format("Selected  (%d)",self:selectedCount()),cx,cy); cy=cy+fh+6

        local brb=self.buttons.roe; brb.x=cx; brb.y=cy; self:_drawButton(brb); cy=cy+brb.h+4
        local bfb=self.buttons.formation; bfb.x=cx; bfb.y=cy; self:_drawButton(bfb); cy=cy+bfb.h+4
        local stb=self.buttons.setTarget; stb.x=cx; stb.y=cy; self:_drawButton(stb); cy=cy+stb.h+8

        love.graphics.setColor(0.40,0.36,0.28,0.5)
        love.graphics.line(cx,cy,x+w-10,cy); cy=cy+10
    end

    -- Probe list
    love.graphics.setColor(0.70,0.62,0.46)
    love.graphics.print(string.format("Probes  %d",depot:aliveProbes()),cx,cy); cy=cy+fh+6

    local listTop=cy
    local listH=h-(cy-y)-10
    love.graphics.setScissor(x,listTop,w,listH)

    local ry=cy-self.scrollY
    for _,probe in ipairs(depot.probes) do
        if not probe.alive then goto nextProbe end
        if ry+self.rowH>=listTop and ry<=listTop+listH then
            local sel=self:isSelected(probe.id)
            local col=colorForType(probe.type)

            if sel then
                love.graphics.setColor(col[1],col[2],col[3],0.15)
                love.graphics.rectangle("fill",x+2,ry,w-4,self.rowH)
            end
            love.graphics.setColor(col)
            love.graphics.rectangle("fill",x+2,ry+6,3,self.rowH-12)

            love.graphics.setFont(self.font)
            love.graphics.setColor(sel and {0.95,0.90,0.75} or {0.65,0.60,0.48})
            love.graphics.print(string.format("#%d %s",probe.id,probe.type:sub(1,1):upper()..probe.type:sub(2)),cx+6,ry+4)
            love.graphics.setColor(0.45,0.42,0.34)
            love.graphics.print(probe.status,cx+6,ry+4+fh+1)

            local barW=w-30
            love.graphics.setColor(0.25,0.10,0.10)
            love.graphics.rectangle("fill",cx+6,ry+self.rowH-10,barW,4)
            love.graphics.setColor(col[1]*0.8,col[2]*0.8,col[3]*0.8)
            love.graphics.rectangle("fill",cx+6,ry+self.rowH-10,barW*(probe.hp/probe.maxHp),4)

            if probe.weapon~="none" then
                love.graphics.setColor(0.70,0.50,0.30)
                love.graphics.print("["..probe.weapon.."]",x+w-55,ry+4)
            end

            love.graphics.setColor(0.28,0.25,0.19,0.4)
            love.graphics.line(x+2,ry+self.rowH,x+w-2,ry+self.rowH)
        end
        ry=ry+self.rowH
        ::nextProbe::
    end

    love.graphics.setScissor()
    love.graphics.setColor(1,1,1)
end

return Panel