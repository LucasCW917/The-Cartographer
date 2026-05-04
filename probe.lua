-- probe.lua
local Pathfinder = require("pathfinder")

local Probe = {}
Probe.__index = Probe

Probe.TYPE_EXPLORER = "explorer"
Probe.TYPE_MINING   = "mining"
Probe.TYPE_DEFENSE  = "defense"

Probe.WEAPON_NONE   = "none"
Probe.WEAPON_ROCKET = "rocket"
Probe.WEAPON_GUN    = "gun"
Probe.WEAPON_LASER  = "laser"

Probe.ROE_PASSIVE    = "passive"
Probe.ROE_DEFENSIVE  = "defensive"
Probe.ROE_AGGRESSIVE = "aggressive"

local WEAPON_STATS = {
    none   = { damage=0,  range=0,  cooldown=0.0,  energyCost=0 },
    rocket = { damage=50, range=8,  cooldown=3.0,  energyCost=5 },
    gun    = { damage=15, range=5,  cooldown=0.4,  energyCost=1 },
    laser  = { damage=8,  range=10, cooldown=0.05, energyCost=2 },
}

local TYPE_SPEED = {
    explorer = 3.0,
    mining   = 1.5,
    defense  = 2.0,
}

local PROBE_COLORS = {
    explorer = { 0.70, 0.85, 0.95 },
    mining   = { 0.95, 0.78, 0.40 },
    defense  = { 0.95, 0.45, 0.40 },
}

function Probe.new(id, probeType, weapon, x, y, cave)
    local self = setmetatable({}, Probe)

    self.id          = id
    self.type        = probeType
    self.weapon      = weapon or Probe.WEAPON_NONE
    self.weaponStats = WEAPON_STATS[weapon or "none"]
    self.roe         = Probe.ROE_DEFENSIVE
    self.cave        = cave

    self.x           = x
    self.y           = y
    self.targetX     = x
    self.targetY     = y
    self.path        = nil
    self.pathIndex   = 1
    self.speed       = TYPE_SPEED[probeType]
    self.moveTimer   = 0

    self.hp          = 100
    self.maxHp       = 100
    self.alive       = true

    self.weaponCooldown = 0
    self.lastFiredAt    = nil

    self.mineTimer   = 0
    self.mineTarget  = nil

    self.status      = "idle"
    self.log         = {}

    self.cargo       = { metal=0, energy=0, rare=0 }
    self.cargoMax    = 20

    return self
end

function Probe:setTarget(tx, ty)
    -- Snap to nearest floor tile if target is solid
    if self.cave:get(tx, ty) ~= self.cave.FLOOR then
        local best, bestDist = nil, math.huge
        for r = 1, 8 do
            for dy = -r, r do
                for dx = -r, r do
                    local nx, ny = tx+dx, ty+dy
                    if self.cave:get(nx, ny) == self.cave.FLOOR then
                        local dist = dx*dx + dy*dy
                        if dist < bestDist then
                            best     = { x=nx, y=ny }
                            bestDist = dist
                        end
                    end
                end
            end
            if best then break end
        end
        if not best then
            self:addLog("No reachable floor near target.")
            self.status = "idle"
            return
        end
        tx, ty = best.x, best.y
    end

    self.targetX   = tx
    self.targetY   = ty
    self.path      = Pathfinder.find(self.cave, math.floor(self.x), math.floor(self.y), tx, ty)
    self.pathIndex = 1
    if self.path then
        self.status = "moving"
    else
        self:addLog("Could not find path to target.")
        self.status = "idle"
    end
end

function Probe:addLog(msg)
    table.insert(self.log, { time=love.timer.getTime(), msg=msg })
    if #self.log > 20 then table.remove(self.log, 1) end
end

function Probe:update(dt, threats, depot)
    if not self.alive then return end

    self.weaponCooldown = math.max(0, self.weaponCooldown - dt)

    if self.weapon ~= Probe.WEAPON_NONE and self.roe ~= Probe.ROE_PASSIVE then
        self:checkCombat(dt, threats)
    end

    if self.type == Probe.TYPE_MINING and self.mineTarget then
        self:updateMining(dt, depot)
        return
    end

    if self.path and self.pathIndex <= #self.path then
        self.moveTimer = self.moveTimer + dt
        local stepTime = 1 / self.speed

        while self.moveTimer >= stepTime and self.pathIndex <= #self.path do
            self.moveTimer = self.moveTimer - stepTime
            local step = self.path[self.pathIndex]
            self.x = step.x
            self.y = step.y
            self.pathIndex = self.pathIndex + 1

            self.cave:reveal(math.floor(self.x), math.floor(self.y), 4)

            if self.type == Probe.TYPE_MINING then
                self:checkDeposit()
            end
        end

        if self.pathIndex > #self.path then
            self.status = "idle"
            self.path   = nil
            self:addLog("Reached destination.")
        end
    end
end

function Probe:checkDeposit()
    for dy = -2, 2 do
        for dx = -2, 2 do
            local tx   = math.floor(self.x) + dx
            local ty   = math.floor(self.y) + dy
            local tile = self.cave:get(tx, ty)
            if tile == self.cave.DEPOSIT and not self.mineTarget then
                self.mineTarget = { x=tx, y=ty }
                self.status = "mining"
                self:addLog("Deposit found. Mining...")
            end
        end
    end
end

function Probe:updateMining(dt, depot)
    self.mineTimer = self.mineTimer + dt
    if self.mineTimer >= 1.0 then
        self.mineTimer = 0
        local total = self.cargo.metal + self.cargo.energy + self.cargo.rare
        if total < self.cargoMax then
            local roll = math.random(3)
            if roll == 1 then
                self.cargo.metal  = self.cargo.metal  + math.random(1, 3)
            elseif roll == 2 then
                self.cargo.energy = self.cargo.energy + math.random(1, 2)
            else
                self.cargo.rare   = self.cargo.rare   + 1
            end
            self:addLog("Mined resources.")
        else
            self.mineTarget = nil
            self.status     = "returning"
            self:addLog("Cargo full. Returning to depot.")
            self:setTarget(depot.x, depot.y)
        end
    end
end

function Probe:checkCombat(dt, threats)
    if #threats == 0 then return end
    local ws = self.weaponStats
    for _, threat in ipairs(threats) do
        local dist = math.sqrt((threat.x - self.x)^2 + (threat.y - self.y)^2)
        local shouldFire = false

        if self.roe == Probe.ROE_AGGRESSIVE and dist <= ws.range then
            shouldFire = true
        elseif self.roe == Probe.ROE_DEFENSIVE and dist <= ws.range and threat.targeting == self.id then
            shouldFire = true
        end

        if shouldFire and self.weaponCooldown <= 0 then
            self:fire(threat)
        end
    end
end

function Probe:fire(target)
    local ws = self.weaponStats
    self.weaponCooldown = ws.cooldown
    self.lastFiredAt    = { x=target.x, y=target.y, time=love.timer.getTime() }
    target.hp = (target.hp or 100) - ws.damage
    self:addLog("Fired " .. self.weapon .. " at target.")
    if target.hp <= 0 then
        target.alive = false
        self:addLog("Target destroyed.")
    end
end

function Probe:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self.alive = false
        self:addLog("Probe destroyed.")
    end
end

function Probe:depositCargo(depot)
    depot.resources.metal  = depot.resources.metal  + self.cargo.metal
    depot.resources.energy = depot.resources.energy + self.cargo.energy
    depot.resources.rare   = depot.resources.rare   + self.cargo.rare
    self.cargo  = { metal=0, energy=0, rare=0 }
    self.status = "idle"
    self:addLog("Cargo deposited.")
end

function Probe:getColor()
    return PROBE_COLORS[self.type]
end

return Probe