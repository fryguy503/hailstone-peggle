local Game = {
    width = 760,
    height = 550,
    launcherX = 380,
    launcherY = 24,
    pegRadius = 8.5,
    ballRadius = 6,
    catcherWidth = 116,
    catcherY = 516,
    maxSeed = 2147483646,
    maxAngle = 1.22,
    angleScale = 10000,
    maxRounds = 48,
}

Game.boards = {
    { id = "grove", name = "Lantern Grove", description = "Seven curved branches shelter the lower targets.", targets = 21 },
    { id = "foundry", name = "Prism Foundry", description = "Follow the chevrons through gaps in the forge.", targets = 21 },
    { id = "basin", name = "Starfall Basin", description = "Nested orbits open up as you clear their outer rings.", targets = 23 },
    { id = "crown", name = "Copper Crown", description = "Three raised points give way to a broad base.", targets = 20 },
    { id = "tide", name = "Tideglass Reach", description = "Five offset waves offer long routes across the field.", targets = 22 },
    { id = "vault", name = "Quartz Vault", description = "Five diamond clusters leave open lanes along the walls.", targets = 20 },
}

Game.modes = {
    { id = "standard", name = "Standard", description = "Twelve shots with a standard aim guide.", shots = 12, guideSteps = 72 },
    { id = "precision", name = "Precision", description = "Eight shots with a shorter aim guide.", shots = 8, guideSteps = 30 },
    { id = "practice", name = "Practice", description = "Eighteen shots with an extended aim guide.", shots = 18, guideSteps = 138 },
}

local Run = {}
Run.__index = Run

local ticksPerSecond = 120
local step = 1 / ticksPerSecond
local gravity = 525
local shotSpeed = 515
local maxBallSpeed = 820
local contactRadius = Game.ballRadius + Game.pegRadius
local pegValues = { blue = 20, orange = 150, green = 80, purple = 240 }

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function descriptor(list, id)
    if id == nil then
        return list[1]
    end
    for _, value in ipairs(list) do
        if value.id == id then
            return value
        end
    end
end

local function addPeg(pegs, x, y)
    pegs[#pegs + 1] = { x = x, y = y, kind = "blue", hit = false, removed = false }
end

local function grove(pegs)
    local widths = { 237, 279, 318, 302, 310, 274, 216 }
    for row, extent in ipairs(widths) do
        local count = 10 + row % 2
        for column = 0, count - 1 do
            local u = column * 2 / (count - 1) - 1
            local bend = 19 * math.cos(u * math.pi) + 12 * math.sin(u * math.pi + row * 0.66)
            addPeg(pegs, Game.launcherX + extent * u, 87 + (row - 1) * 55 + bend)
        end
    end
end

local function foundry(pegs)
    for row = 0, 6 do
        local count = 12 + row % 2
        for column = 0, count - 1 do
            local u = column * 2 / (count - 1) - 1
            local centralGap = (row == 2 or row == 3) and math.abs(u) < 0.17
            local edgeGap = (row == 0 or row == 6) and math.abs(u) > 0.85
            if not centralGap and not edgeGap then
                local bend = math.abs(u) * 30
                addPeg(pegs, Game.launcherX + u * 323, 98 + row * 50 + bend)
            end
        end
    end
end

local function basin(pegs)
    local rings = {
        { 315, 192, 27 },
        { 266, 150, 22 },
        { 207, 108, 17 },
        { 137, 68, 12 },
        { 63, 34, 6 },
    }
    for index, ring in ipairs(rings) do
        local xRadius, yRadius, count = ring[1], ring[2], ring[3]
        for point = 0, count - 1 do
            local angle = (point + (index % 2) * 0.5) * 2 * math.pi / count
            addPeg(pegs, Game.launcherX + xRadius * math.cos(angle), 268 + yRadius * math.sin(angle))
        end
    end
    addPeg(pegs, Game.launcherX, 268)
end

local function crown(pegs)
    local rows = {
        "#.....#.....#",
        "##...###...##",
        "#.#..#.#..#.#",
        "##.##...##.##",
        ".##.#####.##.",
        ".#.#.#.#.#.#.",
        "..##..#..##..",
        "..#########..",
        "....#####....",
    }
    for row, pattern in ipairs(rows) do
        for column = 1, #pattern do
            if pattern:sub(column, column) == "#" then
                addPeg(pegs, Game.launcherX + (column - 7) * 51 + (row % 2 - 0.5) * 14,
                    88 + (row - 1) * 45)
            end
        end
    end
end

local function tide(pegs)
    for current = 0, 4 do
        local count = 15 + (current % 2) * 2
        for index = 0, count - 1 do
            local u = index * 2 / (count - 1) - 1
            local curl = 36 * math.sin(u * math.pi * 1.35 + current * 0.84)
            addPeg(pegs, Game.launcherX + u * 324, 106 + current * 77 + curl)
        end
    end
end

local function vault(pegs)
    local centers = {
        { 192, 151 }, { 568, 151 }, { 380, 265 }, { 192, 379 }, { 568, 379 },
    }
    for index, center in ipairs(centers) do
        local xGap = index == 3 and 44 or 53
        for row = -2, 2 do
            local extent = 2 - math.abs(row)
            for column = -extent, extent do
                addPeg(pegs, center[1] + column * xGap, center[2] + row * 38)
            end
        end
    end
end

local layouts = { grove = grove, foundry = foundry, basin = basin, crown = crown, tide = tide, vault = vault }

local function colorPegs(pegs, targetCount, seed)
    local order = {}
    for index = 1, #pegs do
        order[index] = index
    end
    -- The products fit within the exact integer range of both Lua numbers and Luau numbers.
    for index = #order, 2, -1 do
        seed = seed * 48271 % 2147483647
        local other = seed % index + 1
        order[index], order[other] = order[other], order[index]
    end
    for index = 1, targetCount do
        pegs[order[index]].kind = "orange"
    end
    pegs[order[targetCount + 1]].kind = "purple"
    pegs[order[targetCount + 2]].kind = "green"
    pegs[order[targetCount + 3]].kind = "green"
end

function Game.isTerminal(phase)
    return phase == "won" or phase == "lost"
end

function Game.new(boardId, seed, modeId)
    local board = descriptor(Game.boards, boardId)
    local mode = descriptor(Game.modes, modeId)
    assert(board, "Unknown peg board")
    assert(mode, "Unknown peg board mode")
    if not finite(seed) then
        seed = 1
    end
    seed = (math.floor(math.abs(seed)) - 1) % Game.maxSeed + 1

    local pegs = {}
    layouts[board.id](pegs)
    colorPegs(pegs, board.targets, seed)

    return setmetatable({
        width = Game.width,
        height = Game.height,
        launcherX = Game.launcherX,
        launcherY = Game.launcherY,
        pegRadius = Game.pegRadius,
        ballRadius = Game.ballRadius,
        catcherY = Game.catcherY,
        catcherWidth = Game.catcherWidth,
        boardId = board.id,
        modeId = mode.id,
        guideSteps = mode.guideSteps,
        seed = seed,
        pegs = pegs,
        initialTargets = board.targets,
        remaining = board.targets,
        shots = mode.shots,
        rounds = 0,
        catches = 0,
        score = 0,
        shotScore = 0,
        lastShot = 0,
        combo = 0,
        bestCombo = 0,
        charge = 0,
        angle = 0,
        angles = {},
        phase = "ready",
        events = {},
        ticks = 0,
        accumulator = 0,
    }, Run)
end

local function encodeAngle(angle)
    local units = clamp(angle, -Game.maxAngle, Game.maxAngle) * Game.angleScale
    if units < 0 then
        return math.ceil(units - 0.5)
    end
    return math.floor(units + 0.5)
end

function Run:aim(x, y)
    if self.phase ~= "ready" or not finite(x) or not finite(y) then
        return self.angle
    end
    local horizontal = x - self.launcherX
    local vertical = math.max(y - self.launcherY, 0.001)
    self.angle = encodeAngle(math.atan(horizontal / vertical)) / Game.angleScale
    return self.angle
end

local function newBall(angle)
    return {
        x = Game.launcherX,
        y = Game.launcherY,
        vx = math.sin(angle) * shotSpeed,
        vy = math.cos(angle) * shotSpeed,
    }
end

function Run:launch(angle)
    if self.phase ~= "ready" or self.shots <= 0 then
        return false
    end
    if angle == nil then
        angle = self.angle
    elseif not finite(angle) then
        return false
    end
    local encoded = encodeAngle(angle)
    self.angle = encoded / Game.angleScale
    self.ball = newBall(self.angle)
    self.rounds = self.rounds + 1
    self.angles[self.rounds] = encoded
    self.shots = self.shots - 1
    self.ticks = 0
    self.accumulator = 0
    self.shotScore = 0
    self.combo = 0
    self.charge = 0
    self.power = nil
    self.phase = "flight"
    self.events[#self.events + 1] = { type = "launch", x = self.ball.x, y = self.ball.y }
    return true
end

local function catcherX(run, round, time)
    local amplitude = (run.width - run.catcherWidth) / 2 - 13
    local phase = (run.seed % 1109) * 0.011 + round * 1.97
    return run.width / 2 + amplitude * math.sin(phase + time * 1.74)
end

function Run:catcher()
    if self.phase == "flight" then
        return catcherX(self, self.rounds, self.ticks * step)
    end
    return catcherX(self, self.rounds + 1, 0)
end

local function advanceBall(ball)
    ball.vy = math.min(ball.vy + gravity * step, maxBallSpeed)
    ball.x = ball.x + ball.vx * step
    ball.y = ball.y + ball.vy * step

    if ball.x < Game.ballRadius then
        ball.x = 2 * Game.ballRadius - ball.x
        ball.vx = math.abs(ball.vx) * 0.96
    elseif ball.x > Game.width - Game.ballRadius then
        ball.x = 2 * (Game.width - Game.ballRadius) - ball.x
        ball.vx = -math.abs(ball.vx) * 0.96
    end
    if ball.y < Game.ballRadius then
        ball.y = 2 * Game.ballRadius - ball.y
        ball.vy = math.abs(ball.vy) * 0.91
    end
end

local function pegContact(pegs, ball)
    local closest
    local bestSquared = contactRadius * contactRadius
    for _, peg in ipairs(pegs) do
        if not peg.removed then
            local dx = ball.x - peg.x
            local dy = ball.y - peg.y
            local distanceSquared = dx * dx + dy * dy
            if distanceSquared < bestSquared then
                closest = peg
                bestSquared = distanceSquared
            end
        end
    end
    return closest, bestSquared
end

function Run:preview(angle)
    local points = {}
    if self.phase ~= "ready" then
        return points
    end
    angle = finite(angle) and encodeAngle(angle) / Game.angleScale or self.angle
    local ball = newBall(angle)
    for tick = 1, self.guideSteps do
        advanceBall(ball)
        local impact = pegContact(self.pegs, ball)
        if impact or tick % 5 == 0 then
            points[#points + 1] = { x = ball.x, y = ball.y }
        end
        if impact or ball.y >= self.catcherY then
            break
        end
    end
    return points
end

local function registerHit(run, peg)
    peg.hit = true
    run.combo = run.combo + 1
    run.bestCombo = math.max(run.combo, run.bestCombo)
    local multiplier = math.min(5, 1 + math.floor((run.combo - 1) / 3))
    if run.charge > 0 then
        multiplier = multiplier * 2
        run.charge = run.charge - 1
    end
    if peg.kind == "purple" then
        run.charge = 3
    elseif peg.kind == "orange" then
        run.remaining = run.remaining - 1
    end
    run.power = run.charge > 0 and "resonance" or nil

    local points = pegValues[peg.kind] * multiplier
    run.score = run.score + points
    run.shotScore = run.shotScore + points
    run.events[#run.events + 1] = {
        type = "hit", kind = peg.kind, x = peg.x, y = peg.y, points = points, combo = run.combo,
    }
end

local function bounce(run, peg, squared)
    local ball = run.ball
    local distance = math.sqrt(squared)
    local nx, ny = 0, -1
    if distance > 0 then
        nx = (ball.x - peg.x) / distance
        ny = (ball.y - peg.y) / distance
    end
    ball.x = peg.x + nx * (contactRadius + 0.02)
    ball.y = peg.y + ny * (contactRadius + 0.02)

    local normalSpeed = ball.vx * nx + ball.vy * ny
    if normalSpeed >= 0 then
        return
    end
    local impulse = math.max(-normalSpeed * 1.76, -normalSpeed + 115)
    ball.vx = ball.vx + impulse * nx
    ball.vy = ball.vy + impulse * ny

    if not peg.hit then
        registerHit(run, peg)
        if peg.kind == "green" then
            local side = ball.vx >= 0 and 1 or -1
            ball.vx = clamp(ball.vx + 105 * side, -530, 530)
            ball.vy = math.min(ball.vy, -210)
        end
    elseif math.abs(ball.vx) < 18 then
        -- A nearly vertical rebound eventually slips off a peg it has already scored.
        ball.vx = nx < 0 and -55 or 55
    end
end

local function settle(run)
    for _, peg in ipairs(run.pegs) do
        if peg.hit then
            peg.removed = true
        end
    end
    run.ball = nil
    run.accumulator = 0
    run.charge = 0
    run.power = nil
    run.lastShot = run.shotScore

    if run.remaining == 0 then
        run.phase = "won"
        local bonus = run.shots * 500
        if bonus > 0 then
            run.score = run.score + bonus
            run.events[#run.events + 1] = { type = "bonus", points = bonus }
        end
    elseif run.shots == 0 or run.rounds >= Game.maxRounds then
        run.phase = "lost"
    else
        run.phase = "ready"
    end
    if Game.isTerminal(run.phase) then
        run.events[#run.events + 1] = { type = "finish", phase = run.phase }
    else
        run.events[#run.events + 1] = { type = "settle" }
    end
end

local function simulate(run)
    local ball = run.ball
    local previousX, previousY = ball.x, ball.y
    run.ticks = run.ticks + 1
    advanceBall(ball)
    local peg, distanceSquared = pegContact(run.pegs, ball)
    if peg then
        bounce(run, peg, distanceSquared)
    end

    local rim = run.catcherY - run.ballRadius
    if previousY < rim and ball.y >= rim then
        local crossing = (rim - previousY) / (ball.y - previousY)
        local x = previousX + (ball.x - previousX) * crossing
        local center = catcherX(run, run.rounds, (run.ticks - 1 + crossing) * step)
        if math.abs(x - center) <= run.catcherWidth / 2 then
            run.shots = run.shots + 1
            run.catches = run.catches + 1
            run.events[#run.events + 1] = { type = "catch", x = x, y = run.catcherY }
            settle(run)
            return
        end
    end
    if ball.y > run.height + run.ballRadius or run.ticks >= ticksPerSecond * 16 then
        settle(run)
    end
end

function Run:update(dt)
    if self.phase == "flight" and finite(dt) and dt > 0 then
        self.accumulator = self.accumulator + math.min(dt, 0.25)
        while self.phase == "flight" and self.accumulator + 1e-10 >= step do
            self.accumulator = self.accumulator - step
            simulate(self)
        end
    end
    local events = self.events
    self.events = {}
    return events
end

function Run:result()
    return {
        boardId = self.boardId,
        modeId = self.modeId,
        seed = self.seed,
        phase = self.phase,
        score = self.score,
        rounds = self.rounds,
        shots = self.shots,
        catches = self.catches,
        remaining = self.remaining,
        initialTargets = self.initialTargets,
        bestCombo = self.bestCombo,
    }
end

return Game
