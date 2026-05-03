-- renderer.lua
local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(cave)
    local self = setmetatable({}, Renderer)
    self.cave     = cave
    self.tileSize = 12
    self.camX     = cave.startX
    self.camY     = cave.startY
    self.zoom     = 1.0

    -- Parchment palette
    self.colors = {
        background  = { 0.13, 0.11, 0.08 },       -- deep dark surround
        parchment   = { 0.82, 0.74, 0.57 },        -- revealed floor
        stone       = { 0.18, 0.15, 0.11 },        -- revealed solid
        fog         = { 0.09, 0.08, 0.06, 1.0 },   -- unrevealed
        gridLine    = { 0.60, 0.52, 0.38, 0.18 },  -- subtle grid
        border      = { 0.50, 0.43, 0.30, 0.5 },   -- floor edge shading
    }

    return self
end

function Renderer:tileToScreen(tx, ty, W, H)
    local ts = self.tileSize * self.zoom
    local sx = (tx - self.camX) * ts + W / 2
    local sy = (ty - self.camY) * ts + H / 2
    return sx, sy
end

function Renderer:screenToTile(sx, sy, W, H)
    local ts = self.tileSize * self.zoom
    local tx = (sx - W / 2) / ts + self.camX
    local ty = (sy - H / 2) / ts + self.camY
    return math.floor(tx), math.floor(ty)
end

function Renderer:draw(W, H)
    local ts    = self.tileSize * self.zoom
    local cave  = self.cave

    -- How many tiles fit on screen
    local tilesX = math.ceil(W / ts) + 2
    local tilesY = math.ceil(H / ts) + 2

    local startTX = math.floor(self.camX - tilesX / 2)
    local startTY = math.floor(self.camY - tilesY / 2)

    -- Background
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", 0, 0, W, H)

    for ty = startTY, startTY + tilesY do
        for tx = startTX, startTX + tilesX do
            local sx, sy = self:tileToScreen(tx, ty, W, H)
            local revealed = cave:isRevealed(tx, ty)
            local tile     = cave:get(tx, ty)

            if not revealed then
                -- Fog of war
                love.graphics.setColor(self.colors.fog)
                love.graphics.rectangle("fill", sx, sy, ts, ts)
            else
                if tile == cave.FLOOR then
                    -- Parchment floor
                    love.graphics.setColor(self.colors.parchment)
                    love.graphics.rectangle("fill", sx, sy, ts, ts)

                    -- Subtle grid lines
                    love.graphics.setColor(self.colors.gridLine)
                    love.graphics.rectangle("line", sx, sy, ts, ts)

                    -- Edge darkening where floor meets solid
                    local function isSolid(ox, oy)
                        local t = cave:get(tx+ox, ty+oy)
                        return t == cave.SOLID
                    end

                    love.graphics.setColor(self.colors.border)
                    if isSolid(0, -1) then
                        love.graphics.rectangle("fill", sx, sy, ts, 2)
                    end
                    if isSolid(0, 1) then
                        love.graphics.rectangle("fill", sx, sy + ts - 2, ts, 2)
                    end
                    if isSolid(-1, 0) then
                        love.graphics.rectangle("fill", sx, sy, 2, ts)
                    end
                    if isSolid(1, 0) then
                        love.graphics.rectangle("fill", sx + ts - 2, sy, 2, ts)
                    end

                else
                    -- Revealed solid — darker parchment
                    love.graphics.setColor(self.colors.stone)
                    love.graphics.rectangle("fill", sx, sy, ts, ts)
                end
            end
        end
    end
end

function Renderer:pan(dx, dy)
    self.camX = self.camX + dx
    self.camY = self.camY + dy
end

function Renderer:zoomIn()
    self.zoom = math.min(self.zoom * 1.1, 4.0)
end

function Renderer:zoomOut()
    self.zoom = math.max(self.zoom * 0.9, 0.3)
end

return Renderer