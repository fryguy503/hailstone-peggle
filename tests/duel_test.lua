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
local fixedChallenge = "PW2C-grove-standard-12345"
local fixedResult = "PW2R-grove-standard-12345-s8o000e4c9bgezfl9e7iagcmbqshn0s8o000e4c9bgezfl9e7iagcm"
assert(challenge == "PW3C-grove-standard-12345")
assert(Duel.challenge("grove", 12345, "standard", 1.22) == legacyChallenge)
assert(Duel.challenge("grove", 12345, "standard", Game.maxAngle, false) == fixedChallenge)
assert(not Duel.challenge("grove", 12345, "standard", 1.22, true))
assert(not Duel.challenge("grove", 12345, "standard", 1.23))
assert(not Duel.challenge("harbor", 12345, "standard", 1.22))
local offer = assert(duel:import("  " .. challenge:upper() .. "\t"))
assert(offer.kind == "challenge" and offer.code == challenge)
assert(offer.boardId == "grove" and offer.modeId == "standard" and offer.seed == 12345)
assert(offer.version == 3 and offer.maxAngle == Game.maxAngle and offer.timedCatcher == true)
local legacyOffer = assert(duel:import(legacyChallenge))
assert(legacyOffer.version == 1 and legacyOffer.maxAngle == 1.22 and legacyOffer.timedCatcher == false)
local fixedOffer = assert(duel:import(fixedChallenge))
assert(fixedOffer.version == 2 and fixedOffer.maxAngle == Game.maxAngle and fixedOffer.timedCatcher == false)
assert(not duel.verifying and not duel.listening and not next(events))
assert(not duel:import("PW4C-grove-standard-12345"))
assert(not duel:import("PW1C-another-standard-12345"))
assert(not duel:import("PW1C-harbor-standard-12345"))
assert(not duel:import("PW1C-grove-standard-2147483647"))
assert(not duel:import(challenge .. "-123"))
assert(not duel:import("PW1R-grove-standard-12345-zzz"))
assert(not duel:import("PW2R-grove-standard-12345-zzz"))
assert(not duel:import("PW3R-grove-standard-12345-____"))
assert(not duel:import("PW3R-grove-standard-12345-$AAA"))
assert(not duel:import("PW3R-grove-standard-12345-AAA"))
assert(not duel:import("PW3R-grove-standard-12345-" .. string.rep("AAAA", 49)))
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
    local run = Game.new(offer.boardId, offer.seed, offer.modeId, offer.maxAngle, offer.timedCatcher)
    assert(not Duel.result(run))
    for i = 1, Game.maxRounds do
        if Game.isTerminal(run.phase) then break end
        local catcherTick
        if offer.timedCatcher then catcherTick = ((i - 1) * 431) % Game.catcherCycleTicks end
        assert(run:launch(shots[(i - 1) % #shots + 1], catcherTick))
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
assert(run.launchCatcherTicks[1] == 0 and run.launchCatcherTicks[2] == Game.catcherCycleTicks - 1)
local result = assert(Duel.result(run))
local payload = assert(result:match("^PW3R%-grove%-standard%-12345%-(.+)$"))
assert(payload:find("[A-Z]") and payload:find("[a-z]"))
local manual = Duel.new(Game)
assert(not manual:listen(true) and not manual:send("Mira", result))
local decoded = assert(manual:import("pw3r-GROVE-Standard-12345-" .. payload))
assert(decoded.kind == "result" and manual.verifying)
for i, angle in ipairs(run.angles) do
    assert(decoded.angles[i] == angle and decoded.catcherTicks[i] == run.launchCatcherTicks[i])
end
finishVerification(manual)
assert(not manual.error and manual.verified.code == result)
assert(manual.verified.maxAngle == Game.maxAngle and manual.verified.version == 3 and manual.verified.timedCatcher == true)
local expected = run:result()
for _, key in ipairs({"score", "rounds", "phase", "remaining", "catches", "seed", "modeId", "boardId"}) do
    assert(manual.verified[key] == expected[key], "replay differs for " .. key)
end

assert(manual:import(result:sub(1, -5)))
finishVerification(manual)
assert(manual.error and not manual.verified)

assert(#run.angles < Game.maxRounds)
assert(manual:import(result .. "AAAA"))
finishVerification(manual)
assert(manual.error and not manual.verified)

local legacyRun = play(legacyOffer)
assert(legacyRun.angles[1] == 12200 and legacyRun.angles[2] == -12200)
assert(Duel.result(legacyRun) == legacyResult)
assert(manual:import(legacyResult))
finishVerification(manual)
assert(manual.verified.score == 5670 and manual.verified.rounds == 15)
assert(manual.verified.maxAngle == 1.22 and manual.verified.version == 1 and manual.verified.timedCatcher == false)

local fixedRun = play(fixedOffer)
assert(Duel.result(fixedRun) == fixedResult)
assert(manual:import(fixedResult:upper()))
finishVerification(manual)
assert(manual.verified.score == 7210 and manual.verified.rounds == 18)
assert(manual.verified.code == fixedResult and manual.verified.version == 2 and manual.verified.timedCatcher == false)

local longestRun = {
    maxAngle = Game.maxAngle,
    timedCatcher = true,
    angles = {},
    launchCatcherTicks = {},
    result = function()
        return {phase = "lost", boardId = "switchback", modeId = "precision", seed = Game.maxSeed}
    end,
}
local angleLimit = math.floor(Game.maxAngle * Game.angleScale + 0.5)
for i = 1, Game.maxRounds do
    longestRun.angles[i] = i % 2 == 0 and angleLimit or -angleLimit
    longestRun.launchCatcherTicks[i] = i % 2 == 0 and Game.catcherCycleTicks - 1 or 0
end
local longestCode = assert(Duel.result(longestRun))
assert(#longestCode == 229)
assert(duel:send("Mira", longestCode) and commands[#commands] == "/tell Mira " .. longestCode)
assert(duel:listen(true))
events.pegworks_duel_tell("Not relevant", "Mira", longestCode:sub(3))
assert(duel.inbox.code == longestCode and duel.inbox.kind == "result")
local longestEntry = assert(duel:import(duel.inbox.code))
assert(#longestEntry.angles == Game.maxRounds and #longestEntry.catcherTicks == Game.maxRounds)
for i, angle in ipairs(longestRun.angles) do
    assert(longestEntry.angles[i] == angle and longestEntry.catcherTicks[i] == longestRun.launchCatcherTicks[i])
end

print("Peggle friend challenge, tell, and replay tests passed.")
