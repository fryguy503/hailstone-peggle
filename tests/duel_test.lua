package.path = "./addon/?.lua;" .. package.path

local Game = require("game")
local Duel = require("duel")

local events, commands = {}, {}
local mq = {
    event = function(name, pattern, handler)
        assert(pattern == "#1# tells you, 'PW#2#'")
        events[name] = handler
    end,
    unevent = function(name) events[name] = nil end,
    cmd = function(command) commands[#commands + 1] = command end,
}

local function finishVerification(duel)
    for _ = 1, 1100 do
        if not duel.verifying then return end
        duel:tick()
    end
    error("verification did not finish")
end

local duel = Duel.new(Game, mq)
local challenge = assert(Duel.challenge("grove", 12345, "standard"))
local legacyChallenge = "PW1C-grove-standard-12345"
local legacyResult = "PW1R-grove-standard-12345-its0009ew4m0a9zgjy2subn671ccxkits0009ew4m0a9z"
assert(challenge == "PW2C-grove-standard-12345")
assert(Duel.challenge("grove", 12345, "standard", 1.22) == legacyChallenge)
assert(not Duel.challenge("grove", 12345, "standard", 1.23))
assert(not Duel.challenge("harbor", 12345, "standard", 1.22))
local offer = assert(duel:import("  " .. challenge:upper() .. "\t"))
assert(offer.kind == "challenge" and offer.code == challenge)
assert(offer.boardId == "grove" and offer.modeId == "standard" and offer.seed == 12345)
assert(offer.version == 2 and offer.maxAngle == Game.maxAngle)
local legacyOffer = assert(duel:import(legacyChallenge))
assert(legacyOffer.version == 1 and legacyOffer.maxAngle == 1.22)
assert(not duel.verifying and not duel.listening and not next(events))
assert(not duel:import("PW3C-grove-standard-12345"))
assert(not duel:import("PW1C-another-standard-12345"))
assert(not duel:import("PW1C-harbor-standard-12345"))
assert(not duel:import("PW1C-grove-standard-2147483647"))
assert(not duel:import(challenge .. "-123"))
assert(not duel:import("PW1R-grove-standard-12345-zzz"))
assert(not duel:import("PW2R-grove-standard-12345-zzz"))
assert(not duel:import("PW1R-grove-standard-12345-0000"))
assert(not duel:import("PW1R-grove-standard-12345-" .. string.rep("000", 49)))

assert(duel:listen(true))
local incoming = assert(events.pegworks_duel_tell)
incoming("Not relevant", "Bad Name", challenge:sub(3))
incoming("Not relevant", "Mira", "bogus")
assert(not duel.inbox)
incoming("Not relevant", "Mira", legacyChallenge:sub(3))
assert(duel.inbox.peer == "Mira" and duel.inbox.code == legacyChallenge)
incoming("Not relevant", "Mira", challenge:sub(3))
assert(duel.inbox.peer == "Mira" and duel.inbox.code == challenge)
assert(duel.inbox.kind == "challenge" and #commands == 0)
assert(not duel:send("Mira /say", challenge))
assert(not duel:send("Mira", challenge .. "\n/ooc spam"))
assert(duel:send("Mira", challenge))
assert(#commands == 1 and commands[1] == "/tell Mira " .. challenge)
assert(duel:listen(false) and not next(events))
incoming("Not relevant", "Mira", challenge:sub(3))
assert(not duel.inbox)

local shots = {Game.maxAngle, -Game.maxAngle, 0, -0.6224, 0.1119, 0.9254, -0.857, 0.289, -0.308, 0.456}
local function play(offer)
    local run = Game.new(offer.boardId, offer.seed, offer.modeId, offer.maxAngle)
    assert(not Duel.result(run))
    for i = 1, Game.maxRounds do
        if Game.isTerminal(run.phase) then break end
        assert(run:launch(shots[(i - 1) % #shots + 1]))
        for _ = 1, 1700 do
            if run.phase ~= "flight" then break end
            run:update(0.01)
        end
        assert(run.phase ~= "flight", "a test shot timed out")
    end
    assert(Game.isTerminal(run.phase))
    return run
end

local run = play(offer)
assert(run.angles[1] == math.floor(Game.maxAngle * Game.angleScale + 0.5))
assert(run.angles[2] == -run.angles[1] and run.angles[1] > 12200)
local result = assert(Duel.result(run))
assert(result:match("^PW2R%-"))
local manual = Duel.new(Game)
assert(not manual:listen(true) and not manual:send("Mira", result))
assert(manual:import(result).kind == "result" and manual.verifying)
finishVerification(manual)
assert(not manual.error and manual.verified.code == result)
assert(manual.verified.maxAngle == Game.maxAngle and manual.verified.version == 2)
local expected = run:result()
for _, key in ipairs({"score", "rounds", "phase", "remaining", "seed", "modeId", "boardId"}) do
    assert(manual.verified[key] == expected[key], "replay differs for " .. key)
end

assert(manual:import(result:sub(1, -4)))
finishVerification(manual)
assert(manual.error and not manual.verified)

assert(#run.angles < Game.maxRounds)
assert(manual:import(result .. "000"))
finishVerification(manual)
assert(manual.error and not manual.verified)

local legacyRun = play(legacyOffer)
assert(legacyRun.angles[1] == 12200 and legacyRun.angles[2] == -12200)
assert(Duel.result(legacyRun) == legacyResult)
assert(manual:import(legacyResult))
finishVerification(manual)
assert(manual.verified.score == 5670 and manual.verified.rounds == 15)
assert(manual.verified.maxAngle == 1.22 and manual.verified.version == 1)

print("Peggle friend challenge, tell, and replay tests passed.")
