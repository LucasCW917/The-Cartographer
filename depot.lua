-- depot.lua
local Probe = require("probe")

local Depot = {}
Depot.__index = Depot

local BASE_COST = {
    explorer = { metal=8,  energy=4, rare=0 },
    mining   = { metal=12, energy=6, rare=2 },
    defense  = { metal=10, energy=8, rare=3 },
}
local WEAPON_COST = {
    none   = { metal=0, energy=0, rare=0 },
    rocket = { metal=6, energy=4, rare=3 },
    gun    = { metal=4, energy=2, rare=1 },
    laser  = { metal=3, energy=6, rare=2 },
}

function Depot.new(x, y)
    local self = setmetatable({}, Depot)

    self.x = x
    self.y = y

    self.resources = {
        metal  = 40,
        energy = 20,
        rare   = 5,
    }

    self.probes     = {}
    self.nextId     = 1
    self.queue      = {}
    self.buildTimer = 0
    self.buildTime  = 5.0

    return self
end

function Depot:canAfford(probeType, weapon)
    local bc = BASE_COST[probeType]
    local wc = WEAPON_COST[weapon or "none"]
    if not bc or not wc then return false end
    return
        self.resources.metal  >= bc.metal  + wc.metal  and
        self.resources.energy >= bc.energy + wc.energy and
        self.resources.rare   >= bc.rare   + wc.rare
end

function Depot:getCost(probeType, weapon)
    local bc = BASE_COST[probeType]   or { metal=0, energy=0, rare=0 }
    local wc = WEAPON_COST[weapon or "none"] or { metal=0, energy=0, rare=0 }
    return {
        metal  = bc.metal  + wc.metal,
        energy = bc.energy + wc.energy,
        rare   = bc.rare   + wc.rare,
    }
end

function Depot:queueProbe(probeType, weapon, cave)
    if not self:canAfford(probeType, weapon) then
        return false, "Insufficient resources."
    end
    local cost = self:getCost(probeType, weapon)
    self.resources.metal  = self.resources.metal  - cost.metal
    self.resources.energy = self.resources.energy - cost.energy
    self.resources.rare   = self.resources.rare   - cost.rare
    table.insert(self.queue, { probeType=probeType, weapon=weapon, cave=cave })
    return true
end

function Depot:update(dt, cave, threats)
    -- Advance build queue
    if #self.queue > 0 then
        self.buildTimer = self.buildTimer + dt
        if self.buildTimer >= self.buildTime then
            self.buildTimer = 0
            local order = table.remove(self.queue, 1)
            local probe = Probe.new(
                self.nextId,
                order.probeType,
                order.weapon,
                self.x, self.y,
                order.cave
            )
            self.nextId = self.nextId + 1
            table.insert(self.probes, probe)
        end
    end

    -- Update probes
    for _, probe in ipairs(self.probes) do
        probe:update(dt, threats, self)

        if probe.status == "returning" then
            local dist = math.abs(probe.x - self.x) + math.abs(probe.y - self.y)
            if dist <= 1 then
                probe:depositCargo(self)
            end
        end
    end

    -- Cull dead probes
    for i = #self.probes, 1, -1 do
        if not self.probes[i].alive then
            table.remove(self.probes, i)
        end
    end
end

function Depot:getProbe(id)
    for _, p in ipairs(self.probes) do
        if p.id == id then return p end
    end
    return nil
end

function Depot:aliveProbes()
    local count = 0
    for _, p in ipairs(self.probes) do
        if p.alive then count = count + 1 end
    end
    return count
end

return Depot