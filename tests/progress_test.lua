package.path = "./addon/?.lua;" .. package.path

local Game = require("game")
local Progress = require("progress")

local clean = Progress.load(Game)
assert(clean.runs == 0 and clean.bestCombo == 0 and not next(clean.records))
assert(#Progress.launchers == 2 and clean.launcher == "ricochet")
assert(not next(Progress.modifiers(clean)))
assert(Progress.medal(Progress.record(clean, "grove", "standard")) == nil)
local cost, reason = Progress.canBuy(clean, "aimLattice")
assert(cost == 1 and reason == "Need 1 more point.")
assert(not Progress.buy(clean, "aimLattice"))
assert(not Progress.buy(clean, "unknown"))

local migrated = Progress.load(Game, {
    runs = 7, bestCombo = 11,
    records = {
        ["grove/standard"] = {score = 4500, cleared = true},
        ["grove/precision"] = {score = 4000, cleared = true},
        ["foundry/standard"] = {score = 800, cleared = false},
        ["basin/standard"] = {score = 8300, fullCleared = true, bestClearedPercent = 92},
        ["unknown/standard"] = {score = 999, cleared = true},
    },
})
assert(migrated.runs == 7 and migrated.bestCombo == 11)
local original = Progress.record(migrated, "grove", "standard")
assert(original.score == 4500 and original.cleared and not original.fullCleared and original.bestClearedPercent == nil)
assert(Progress.medal(original) == "cleared")
local played = Progress.record(migrated, "foundry", "standard")
assert(Progress.medal(played) == "played")
local mastery = Progress.record(migrated, "basin", "standard")
assert(Progress.medal(mastery) == "mastery" and mastery.cleared and mastery.bestClearedPercent == 100)
assert(not next(Progress.record(migrated, "unknown", "standard")))
assert(Progress.budget(migrated).earned == 3)

local function terminal(boardId, modeId, phase, completionPercent, score, combo)
    return {
        boardId = boardId, modeId = modeId, phase = phase, score = score, bestCombo = combo,
        beaten = phase == "won", fullCleared = completionPercent == 100, completionPercent = completionPercent,
    }
end

local update = assert(Progress.applyResult(migrated, terminal("grove", "standard", "lost", 96, 5100, 14)))
assert(update.newBest and not update.newBeat and not update.newMastery and update.pointsEarned == 0)
assert(update.record.score == 5100 and update.record.cleared and not update.record.fullCleared)
assert(update.record.bestClearedPercent == 96 and migrated.runs == 8 and migrated.bestCombo == 14)
update = assert(Progress.applyResult(migrated, terminal("grove", "standard", "won", 100, 4400, 8)))
assert(not update.newBest and not update.newBeat and update.newMastery and update.pointsEarned == 1)
assert(update.record.score == 5100 and update.record.fullCleared and update.record.bestClearedPercent == 100)
update = assert(Progress.applyResult(migrated, terminal("grove", "practice", "won", 100, 100, 3)))
assert(update.newBest and update.pointsEarned == 0 and Progress.medal(update.record) == "mastery")
local grove = Progress.boardProgress(migrated, "grove")
assert(grove.cleared and grove.fullCleared and grove.bestClearedPercent == 100)
assert(Progress.budget(migrated).earned == 4)

update = assert(Progress.applyResult(clean, terminal("foundry", "standard", "won", 55, 3100, 7)))
assert(update.newBeat and not update.newMastery and update.pointsEarned == 1)
assert(Progress.medal(update.record) == "cleared" and update.record.bestClearedPercent == 55)
update = assert(Progress.applyResult(clean, terminal("foundry", "precision", "won", 78, 1700, 6)))
assert(not update.newBeat and not update.newMastery and update.pointsEarned == 0)
assert(Progress.boardProgress(clean, "foundry").bestClearedPercent == 78)
assert(not Progress.applyResult(clean, terminal("absent", "standard", "won", 100, 900, 11)))
assert(not Progress.applyResult(clean, terminal("foundry", "standard", "flight", 100, 900, 11)))
assert(not Progress.applyResult(clean, terminal("foundry", "absent", "won", 100, 900, 11)))
assert(clean.runs == 2 and Progress.budget(clean).available == 1)

cost, reason = Progress.canBuy(clean, "springCoil")
assert(cost == 1 and reason == "Requires Aim Lattice rank 1.")
assert(Progress.buy(clean, "aimLattice") and Progress.rank(clean, "aimLattice") == 1)
assert(Progress.modifiers(clean).guideSteps == 12)
assert(Progress.budget(clean).spent == 1 and Progress.budget(clean).available == 0)
assert(not Progress.buy(clean, "springCoil"))

local repaired = Progress.load(Game, {
    records = {["foundry/standard"] = {score = -1, cleared = true}, ["basin/standard"] = 77},
    talents = {echoRelay = 2, spareCharge = 3, blueAlloy = 9000, unexpectedTalent = 1},
    runs = 0/0, bestCombo = math.huge,
})
assert(repaired.runs == 0 and repaired.bestCombo == 0)
assert(Progress.record(repaired, "foundry", "standard").score == 0)
assert(not next(Progress.record(repaired, "basin", "standard")))
assert(Progress.rank(repaired, "spareCharge") == 1 and Progress.rank(repaired, "echoRelay") == 0)
assert(Progress.rank(repaired, "blueAlloy") == 0 and Progress.rank(repaired, "unexpectedTalent") == 0)
assert(Progress.budget(repaired).available == 0)

local completed = Progress.load(Game)
local totalPoints = 2 * #Game.boards
for _, board in ipairs(Game.boards) do
    update = assert(Progress.applyResult(completed, terminal(board.id, "standard", "won", 100, 5000, 11)))
    assert(update.newBeat and update.newMastery and update.pointsEarned == 2)
end
assert(totalPoints == 26 and Progress.budget(completed).earned == totalPoints)

local maxEffects = {
    guideSteps = 42, greenBoost = 55, resonanceHits = 3, comboPoints = 45, targetBonus = 85,
    extraShots = 3, catcherWidth = 36, catchPoints = 225, bankBonus = 240, blueBonus = 20, fullClearBonus = 2600,
}
local talentCount = 0
for _, discipline in ipairs(Progress.catalog) do
    assert(Progress.reset(completed))
    assert(Progress.budget(completed).available == totalPoints)
    for _, talent in ipairs(discipline.talents) do
        talentCount = talentCount + 1
        for _ = 1, #talent.costs do assert(Progress.buy(completed, talent.id)) end
        assert(Progress.modifiers(completed)[talent.effect] == maxEffects[talent.effect])
        cost, reason = Progress.canBuy(completed, talent.id)
        assert(cost == nil and reason == "Maximum rank.")
    end
    local reloaded = Progress.load(Game, completed)
    assert(Progress.budget(reloaded).spent == Progress.budget(completed).spent)
    for _, talent in ipairs(discipline.talents) do
        assert(Progress.rank(reloaded, talent.id) == #talent.costs)
    end
end
assert(talentCount == 11)
assert(Progress.reset(completed) and Progress.budget(completed).available == totalPoints)
assert(Progress.buy(completed, "spareCharge") and Progress.buy(completed, "aimLattice"))
local mixed = Progress.modifiers(completed)
assert(mixed.extraShots == 1 and mixed.guideSteps == 12 and Progress.budget(completed).available == totalPoints - 2)

assert(not Progress.selectLauncher(completed, "unknown"))
assert(completed.launcher == "ricochet" and Progress.modifiers(completed).launcher == nil)
assert(Progress.selectLauncher(completed, "catchfield"))
assert(Progress.modifiers(completed).launcher == "catchfield")
local reloaded = Progress.load(Game, completed)
assert(reloaded.launcher == "catchfield" and Progress.modifiers(reloaded).launcher == "catchfield")
assert(Progress.reset(reloaded) and Progress.modifiers(reloaded).launcher == "catchfield")
assert(Progress.selectLauncher(reloaded, "ricochet") and not next(Progress.modifiers(reloaded)))
assert(Progress.load(Game, {launcher = "unknown"}).launcher == "ricochet")

print("Peggle talent budget, profile migration, and mastery records tests passed.")
