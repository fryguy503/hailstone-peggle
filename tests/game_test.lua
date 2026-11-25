local Game = dofile("addon/game.lua")

local function finishShot(run, dt)
    local events, calls = {}, 0
    while run.phase == "flight" do
        calls = calls + 1
        assert(calls * dt <= 16 + dt, "Shot took longer than the physics time limit")
        for _, event in ipairs(run:update(dt)) do
            events[#events + 1] = event
        end
    end
    return events
end

local function hasEvent(events, eventType)
    for _, event in ipairs(events) do
        if event.type == eventType then
            return event
        end
    end
end

local function distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

local function aimAt(run, x, y, peg, shouldHit)
    local angle = run:aim(x, y)
    local points = run:preview()
    if shouldHit then
        assert(distance(points[#points], peg) < run.pegRadius + run.ballRadius, "Aim guide missed the peg")
    end
    assert(run:launch())
    local hit = hasEvent(finishShot(run, 0.25), "hit")
    if shouldHit then
        assert(hit and hit.x == peg.x and hit.y == peg.y, "The actual shot missed the guided peg")
    else
        assert(not hit, "A shot aimed outside the collision radius hit the peg")
    end
    return angle
end

assert(#Game.boards == 12)
for _, board in ipairs(Game.boards) do
    for _, mode in ipairs(Game.modes) do
        local run = Game.new(board.id, 827107, mode.id)
        assert(run.shots == mode.shots)
        assert(run.phase == "ready")
        assert(run:aim(0, 0) == -Game.maxAngle)
        assert(run:aim(run.width, 0) == Game.maxAngle)
        assert(run:aim(run.launcherX, run.height) == 0)
        assert(#run:preview() > 0)

        local sameSeed = Game.new(board.id, run.seed, mode.id)
        local differentSeed = Game.new(board.id, run.seed + 1, mode.id)
        local changed = false
        local colors = { orange = 0, green = 0, purple = 0, blue = 0 }
        for index, peg in ipairs(run.pegs) do
            local matching = sameSeed.pegs[index]
            assert(peg.x == matching.x and peg.y == matching.y and peg.kind == matching.kind)
            assert(peg.x >= run.pegRadius and peg.x <= run.width - run.pegRadius)
            assert(peg.y >= run.launcherY + 2 * run.pegRadius and peg.y <= run.catcherY - 2 * run.pegRadius)
            colors[peg.kind] = colors[peg.kind] + 1
            changed = changed or peg.kind ~= differentSeed.pegs[index].kind

            for earlier = 1, index - 1 do
                local other = run.pegs[earlier]
                local square = (peg.x - other.x) ^ 2 + (peg.y - other.y) ^ 2
                assert(square > (2 * (run.ballRadius + run.pegRadius)) ^ 2, "Peg positions trap the ball")
            end
        end
        assert(changed, "The seed does not change the board")
        assert(colors.orange == run.remaining and colors.green == 2 and colors.purple == 1)
    end
end

for _, x in ipairs({ 60, Game.width - 60 }) do
    for _, offset in ipairs({ 0, -13, 13, -26, 26 }) do
        local run = Game.new("grove", 100, "standard")
        local peg = { x = x, y = 167, kind = "orange" }
        run.pegs = { peg }
        local angle = aimAt(run, peg.x, peg.y + offset, peg, math.abs(offset) < 20)
        if offset == 0 then
            assert(math.abs(angle) > 1.22 and math.abs(angle) < Game.maxAngle, "The edge peg remains out of range")
        end
    end
end

for _, board in ipairs(Game.boards) do
    local pegs = Game.new(board.id, 827107, "standard").pegs
    for _, peg in ipairs(pegs) do
        local run = Game.new(board.id, 827107, "standard")
        local onlyPeg = { x = peg.x, y = peg.y, kind = peg.kind }
        run.pegs = { onlyPeg }
        aimAt(run, peg.x, peg.y, onlyPeg, true)
    end
end

for _, index in ipairs({ 1, 3 }) do
    local run = Game.new("crown", 827107, "standard")
    local peg = run.pegs[index]
    assert(peg.y == 88 and math.abs(peg.x - run.launcherX) > 290)
    assert(math.abs(aimAt(run, peg.x, peg.y, peg, true)) > math.pi / 2,
        "The outermost upper peg must be reached by an upward launch")
end

local legacy = Game.new("grove", 1, "standard", Game.legacyMaxAngle)
local legacyAim = -math.floor(math.atan(320 / 143) * Game.angleScale + 0.5) / Game.angleScale
assert(legacy:aim(60, 167) == legacyAim and legacy.guideSteps == 72)
assert(legacy:setAngle(-2) == -1.22)
assert(legacy:setAngle(2) == 1.22)
assert(legacy:launch(1.83) and legacy.angles[1] == 12200)
assert(legacy:setAngle(0) == 1.22, "The launcher rotated during flight")

local function play(dt)
    local run = Game.new("basin", 827107, "standard")
    local sequence = { 0.3, -0.9, 1.1, -0.6448, 0.11157, 0.22, -0.944, 0.835, 1.2, -1.2, 0.91, -0.03 }
    local notes = {}
    for index, angle in ipairs(sequence) do
        if Game.isTerminal(run.phase) then
            break
        end
        run:update(dt * 2)
        assert(run:launch(angle, index * 29))
        assert(not run:launch(angle), "A second ball launched before the previous shot finished")
        for _, event in ipairs(finishShot(run, dt)) do
            notes[#notes + 1] = event.type .. "/" .. tostring(event.kind) .. "/" .. tostring(event.points)
        end
    end
    assert(run.score > 0 and run.bestCombo > 1)
    return run, table.concat(notes, ",")
end

local quick, quickNotes = play(0.25)
local slow, slowNotes = play(1 / 144)
assert(quickNotes == slowNotes, "Frame timing changed the shot events")
for field, result in pairs(quick:result()) do
    assert(result == slow:result()[field], "Frame timing changed " .. field)
end
assert(#quick.angles == quick.rounds and quick.angles[5] == 1116)
assert(#quick.launchCatcherTicks == quick.rounds and quick.launchCatcherTicks[5] == 145)

local catchRun = Game.new("grove", 1, "precision", Game.maxAngle, false)
catchRun.pegs = {}
catchRun.shots = 1
local legacyReady = catchRun:catcher()
catchRun:update(0.27)
assert(catchRun:catcher() == legacyReady and not catchRun:launch(0, 20))
assert(catchRun:launch(0))
assert(catchRun:catcher() == legacyReady and #catchRun.launchCatcherTicks == 0)
catchRun:update(0.25)
local legacyInFlight = catchRun.width / 2
    + ((catchRun.width - catchRun.catcherWidth) / 2 - 13) * math.sin(0.011 + 1.97 + 0.25 * 1.74)
assert(math.abs(catchRun:catcher() - legacyInFlight) < 1e-8)
assert(hasEvent(finishShot(catchRun, 0.25), "catch"))
assert(catchRun.phase == "ready" and catchRun.catches == 1 and catchRun.shots == 1)

local miss = Game.new("grove", 100, "precision", Game.maxAngle, false)
miss.pegs = {}
miss.shots = 1
assert(miss:launch(0))
assert(hasEvent(finishShot(miss, 0.25), "finish").phase == "lost")
assert(Game.isTerminal(miss.phase) and not miss:launch(0))

local function catcherPosition(run, tick)
    local amplitude = (run.width - run.catcherWidth) / 2 - 13
    return run.width / 2 + amplitude * math.sin(tick * 2 * math.pi / Game.catcherCycleTicks)
end

local motion = Game.new("grove", Game.catcherCycleTicks, "standard")
motion.pegs = {}
assert(motion.timedCatcher and not legacy.timedCatcher)
assert(not motion:launch(0, -1) and not motion:launch(0, 432) and not motion:launch(0, 1.5))
assert(motion.phase == "ready" and motion.rounds == 0)
assert(math.abs(motion:catcher() - catcherPosition(motion, 0)) < 1e-8)
motion:update(0.103)
local beforeLaunch = motion:catcher()
assert(math.abs(beforeLaunch - catcherPosition(motion, 12.36)) < 1e-8)
motion:update(3.6)
assert(math.abs(motion:catcher() - beforeLaunch) < 1e-8, "The catch tray did not complete one full sweep")
assert(motion:launch(0))
assert(motion.launchCatcherTicks[1] == 12)
assert(math.abs(motion:catcher() - beforeLaunch) < 1e-8, "The catch tray jumped at launch")
motion:update(0.071)
local elapsed = 12 + 8.52
while motion.phase == "flight" do
    assert(math.abs(motion:catcher() - catcherPosition(motion, elapsed)) < 1e-8)
    motion:update(1 / 120)
    elapsed = elapsed + 1
end
assert(motion.phase == "ready")
assert(math.abs(motion:catcher() - catcherPosition(motion, elapsed)) < 1e-8, "The catch tray jumped at settle")
motion:update(0.01)
assert(math.abs(motion:catcher() - catcherPosition(motion, elapsed + 1.2)) < 1e-8)

local lag = Game.new("grove", 1, "standard")
assert(lag:launch(0, 0))
lag:update(2)
assert(lag.phase == "flight" and lag.ticks == 30, "The game simulated a long frame at once")
assert(math.abs(lag:catcher() - catcherPosition(lag, 30)) < 1e-8, "The catch tray advanced ahead of the ball")

local function timedCatch(tick, idle, dt)
    local run = Game.new("grove", 1, "precision")
    run.pegs = {}
    run.shots = 1
    run:update(idle)
    assert(run:launch(0, tick) and run.launchCatcherTicks[1] == tick)
    return run, hasEvent(finishShot(run, dt), "catch")
end

local caught, catchEvent = timedCatch(348, 0.17, 0.25)
assert(catchEvent and caught.catches == 1 and caught.shots == 1)
local replay, replayEvent = timedCatch(348, 1.23, 1 / 144)
assert(replayEvent and replayEvent.x == catchEvent.x and replay.ticks == caught.ticks)
local lost, noCatch = timedCatch(24, 1.23, 0.25)
assert(not noCatch and lost.catches == 0 and lost.phase == "lost", "Changing the launch phase did not change the catch")

local win = Game.new("grove", 100, "precision")
win.pegs = { { x = win.launcherX, y = 100, kind = "orange" } }
win.remaining = 1
assert(win:launch(0))
local winEvents = finishShot(win, 0.25)
assert(hasEvent(winEvents, "hit").points == 150)
assert(hasEvent(winEvents, "bonus").points == win.shots * 500)
assert(hasEvent(winEvents, "finish").phase == "won")
assert(win.score == 150 + win.shots * 500 and win.pegs[1].removed)

local function firstHit(kind)
    local run = Game.new("grove", 1, "precision")
    run.pegs = { { x = run.launcherX, y = 100, kind = kind } }
    assert(run:launch(0))
    for _ = 1, 60 do
        if hasEvent(run:update(1 / 120), "hit") then
            return run
        end
    end
    error("Ball passed through the " .. kind .. " peg")
end

local green = firstHit("green")
assert(green.ball.vy <= -210 and math.abs(green.ball.vx) >= 105)
local purple = firstHit("purple")
assert(purple.power == "resonance" and purple.charge == 3)
finishShot(purple, 0.25)
assert(purple.phase == "ready" and purple.charge == 0 and purple.power == nil)

local function strike(run, peg)
    assert(run.phase == "flight")
    run.ball = { x = peg.x - 16, y = peg.y, vx = 360, vy = -525 / 120 }
    return hasEvent(run:update(1 / 120), "hit")
end

local greenPeg = { x = 150, y = 120, kind = "green" }
local kickoff = Game.new("grove", 1, "standard")
kickoff.pegs = { greenPeg }
assert(kickoff:launch())
assert(strike(kickoff, greenPeg).points == 80)
assert(math.abs(kickoff.ball.vx - (-378.6)) < 1e-8 and kickoff.ball.vy == -210)
assert(not strike(kickoff, greenPeg))
assert(math.abs(kickoff.ball.vx - (-273.6)) < 1e-8 and kickoff.ball.vy == 0, "The green boost applied twice")

local chargingPeg = { x = 150, y = 160, kind = "purple" }
local resonant = Game.new("grove", 1, "standard")
resonant.pegs = { chargingPeg }
assert(resonant:launch())
assert(strike(resonant, chargingPeg).points == 240)
assert(not strike(resonant, chargingPeg) and resonant.charge == 3, "A repeat hit consumed resonance")
for index, expected in ipairs({ 40, 40, 80, 40 }) do
    local bluePeg = { x = 150 + index * 50, y = 160, kind = "blue" }
    resonant.pegs[#resonant.pegs + 1] = bluePeg
    assert(strike(resonant, bluePeg).points == expected)
    assert(resonant.charge == math.max(0, 3 - index))
end
assert(resonant.power == nil)

print("Peg-board gameplay tests passed")
