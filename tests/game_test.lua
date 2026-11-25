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

assert(#Game.boards == 6)
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

local function play(dt)
    local run = Game.new("basin", 827107, "standard")
    local sequence = { 0.3, -0.9, 1.1, -0.6448, 0.11157, 0.22, -0.944, 0.835, 1.2, -1.2, 0.91, -0.03 }
    local notes = {}
    for _, angle in ipairs(sequence) do
        if Game.isTerminal(run.phase) then
            break
        end
        assert(run:launch(angle))
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

local catchRun = Game.new("grove", 1, "precision")
catchRun.pegs = {}
catchRun.shots = 1
assert(catchRun:launch(0))
assert(hasEvent(finishShot(catchRun, 0.25), "catch"))
assert(catchRun.phase == "ready" and catchRun.catches == 1 and catchRun.shots == 1)

local miss = Game.new("grove", 100, "precision")
miss.pegs = {}
miss.shots = 1
assert(miss:launch(0))
assert(hasEvent(finishShot(miss, 0.25), "finish").phase == "lost")
assert(Game.isTerminal(miss.phase) and not miss:launch(0))

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

print("Peg-board gameplay tests passed")
