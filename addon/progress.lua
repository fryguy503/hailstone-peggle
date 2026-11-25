-- Copyright 2026 fryguy503. All rights reserved. See LICENSE.
local Progress = {}

Progress.launchers = {
    {id = "ricochet", name = "Ricochet", description = "Green pegs add lift and side kick to the ball."},
    {id = "catchfield", name = "Catchfield", description = "Green pegs widen the catcher for the rest of the shot."},
}

Progress.catalog = {
    {
        id = "trajectory", name = "Trajectory",
        talents = {
            {
                id = "aimLattice", name = "Aim Lattice", description = "Lengthens the dotted aim guide.",
                costs = {1, 1, 2}, effect = "guideSteps", effects = {12, 24, 42}, unit = "guide steps",
            },
            {
                id = "springCoil", name = "Spring Coil", description = "Strengthens the launcher's green peg power.",
                costs = {1, 2}, effect = "greenBoost", effects = {26, 55}, unit = "power strength",
                requires = {id = "aimLattice", rank = 1},
            },
            {
                id = "echoRelay", name = "Echo Relay", description = "Extends violet resonance to more hits.",
                costs = {2, 3}, effect = "resonanceHits", effects = {1, 3}, unit = "resonant hits",
                requires = {id = "springCoil", rank = 2},
            },
            {
                id = "rallyChain", name = "Rally Chain", description = "Adds points per peg hit from combo 5 onward.",
                costs = {1, 2, 2}, effect = "comboPoints", effects = {15, 30, 45}, unit = "points per combo hit",
                requires = {id = "aimLattice", rank = 1},
            },
            {
                id = "amberEtching", name = "Amber Etching", description = "Adds points for each amber peg hit.",
                costs = {2, 3}, effect = "targetBonus", effects = {40, 85}, unit = "points per amber peg",
                requires = {id = "rallyChain", rank = 2},
            },
        },
    },
    {
        id = "fortune", name = "Fortune",
        talents = {
            {
                id = "spareCharge", name = "Spare Charge", description = "Starts each board with more shots.",
                costs = {1, 2, 2}, effect = "extraShots", effects = {1, 2, 3}, unit = "starting shots",
            },
            {
                id = "wideCradle", name = "Wide Cradle", description = "Widens the moving catcher.",
                costs = {1, 2}, effect = "catcherWidth", effects = {18, 36}, unit = "catcher width",
                requires = {id = "spareCharge", rank = 1},
            },
            {
                id = "catchPurse", name = "Catch Purse", description = "Pays extra points for a bucket catch.",
                costs = {1, 2}, effect = "catchPoints", effects = {100, 225}, unit = "points per catch",
                requires = {id = "wideCradle", rank = 1},
            },
            {
                id = "reserveInterest", name = "Reserve Interest", description = "Pays more for unused shots after a win.",
                costs = {1, 2}, effect = "bankBonus", effects = {100, 240}, unit = "points per unused shot",
                requires = {id = "spareCharge", rank = 1},
            },
            {
                id = "blueAlloy", name = "Blue Alloy", description = "Adds points for each blue peg hit.",
                costs = {1, 2}, effect = "blueBonus", effects = {10, 20}, unit = "points per blue peg",
                requires = {id = "reserveInterest", rank = 1},
            },
            {
                id = "finishingSeal", name = "Finishing Seal", description = "Adds to the bonus for clearing every peg.",
                costs = {2, 2, 3}, effect = "fullClearBonus", effects = {700, 1500, 2600}, unit = "points on full clear",
                requires = {id = "blueAlloy", rank = 2},
            },
        },
    },
}

local maxCounter = 1000000000
local defaultLauncher = Progress.launchers[1].id
local launchersById = {}
for _, launcher in ipairs(Progress.launchers) do launchersById[launcher.id] = launcher end
local talentsById = {}
for _, discipline in ipairs(Progress.catalog) do
    for _, talent in ipairs(discipline.talents) do talentsById[talent.id] = talent end
end

-- The set of valid record keys comes from the engine and stays outside the saved profile.
local recordKeys = setmetatable({}, {__mode = "k"})

local function count(value, maximum)
    if type(value) == "number" and value >= 0 and value <= maximum then return math.floor(value) end
end

local function normalizeRecord(entry)
    if type(entry) ~= "table" then return nil end
    local percent = count(entry.bestClearedPercent, 100)
    local full = entry.fullCleared == true or percent == 100
    return {
        score = count(entry.score, maxCounter) or 0,
        cleared = entry.cleared == true or full,
        fullCleared = full,
        bestClearedPercent = full and 100 or percent,
    }
end

function Progress.record(profile, boardId, modeId)
    return profile.records[boardId .. "/" .. modeId] or {}
end

function Progress.medal(record)
    if record.fullCleared then return "mastery" end
    if record.cleared then return "cleared" end
    if record.score ~= nil then return "played" end
end

function Progress.boardProgress(profile, boardId)
    local summary = {cleared = false, fullCleared = false}
    local prefix = boardId .. "/"
    for key, record in pairs(profile.records) do
        if key:sub(1, #prefix) == prefix then
            summary.cleared = summary.cleared or record.cleared
            summary.fullCleared = summary.fullCleared or record.fullCleared
            if record.bestClearedPercent ~= nil then
                summary.bestClearedPercent = math.max(summary.bestClearedPercent or 0, record.bestClearedPercent)
            end
        end
    end
    return summary
end

function Progress.rank(profile, id)
    return profile.talents[id] or 0
end

function Progress.budget(profile)
    local earned, spent = 0, 0
    local boardPoints = {}
    for key, record in pairs(profile.records) do
        local boardId = key:match("^([^/]+)/")
        local points = record.fullCleared and 2 or (record.cleared and 1 or 0)
        local previous = boardPoints[boardId] or 0
        if points > previous then
            earned = earned + points - previous
            boardPoints[boardId] = points
        end
    end
    for id, rank in pairs(profile.talents) do
        local costs = talentsById[id].costs
        for i = 1, rank do spent = spent + costs[i] end
    end
    return {earned = earned, spent = spent, available = earned - spent}
end

function Progress.canBuy(profile, id)
    local talent = talentsById[id]
    if not talent then return nil, "Unknown talent." end
    local cost = talent.costs[Progress.rank(profile, id) + 1]
    if not cost then return nil, "Maximum rank." end
    local requires = talent.requires
    if requires and Progress.rank(profile, requires.id) < requires.rank then
        return cost, string.format("Requires %s rank %d.", talentsById[requires.id].name, requires.rank)
    end
    local shortage = cost - Progress.budget(profile).available
    if shortage > 0 then
        return cost, string.format("Need %d more %s.", shortage, shortage == 1 and "point" or "points")
    end
    return cost
end

function Progress.buy(profile, id)
    local _, reason = Progress.canBuy(profile, id)
    if reason then return nil, reason end
    profile.talents[id] = Progress.rank(profile, id) + 1
    return true
end

function Progress.reset(profile)
    profile.talents = {}
    return true
end

function Progress.selectLauncher(profile, id)
    if not launchersById[id] then return nil, "Unknown launcher." end
    profile.launcher = id
    return true
end

function Progress.modifiers(profile)
    local modifiers = {}
    if profile.launcher ~= defaultLauncher then modifiers.launcher = profile.launcher end
    for id, rank in pairs(profile.talents) do
        local talent = talentsById[id]
        modifiers[talent.effect] = talent.effects[rank]
    end
    return modifiers
end

function Progress.load(Game, saved)
    if type(saved) ~= "table" then saved = {} end
    local profile = {
        version = 2, records = {}, talents = {},
        runs = count(saved.runs, maxCounter) or 0, bestCombo = count(saved.bestCombo, maxCounter) or 0,
        launcher = launchersById[saved.launcher] and saved.launcher or defaultLauncher,
    }
    local known = {}
    recordKeys[profile] = known
    local savedRecords = type(saved.records) == "table" and saved.records or {}
    for _, board in ipairs(Game.boards) do
        for _, mode in ipairs(Game.modes) do
            local key = board.id .. "/" .. mode.id
            known[key] = true
            profile.records[key] = normalizeRecord(savedRecords[key])
        end
    end
    if type(saved.talents) == "table" then
        for _, discipline in ipairs(Progress.catalog) do
            for _, talent in ipairs(discipline.talents) do
                local wanted = count(saved.talents[talent.id], #talent.costs) or 0
                for _ = 1, wanted do
                    if not Progress.buy(profile, talent.id) then break end
                end
            end
        end
    end
    return profile
end

function Progress.applyResult(profile, result)
    if type(result) ~= "table" or (result.phase ~= "won" and result.phase ~= "lost") then
        return nil, "Finish the run to record progress."
    end
    if type(result.boardId) ~= "string" or type(result.modeId) ~= "string" then
        return nil, "Unknown board or mode."
    end
    local key = result.boardId .. "/" .. result.modeId
    if not recordKeys[profile] or not recordKeys[profile][key] then return nil, "Unknown board or mode." end
    local score = count(result.score, maxCounter)
    if score == nil then return nil, "Invalid run score." end

    local previous = Progress.boardProgress(profile, result.boardId)
    local record = Progress.record(profile, result.boardId, result.modeId)
    local percent = count(result.completionPercent, 100)
    local full = result.fullCleared == true or percent == 100
    local beaten = result.beaten == true or result.phase == "won" or full
    local newBest = record.score == nil or score > record.score
    local newBeat, newMastery = beaten and not previous.cleared, full and not previous.fullCleared
    if full then percent = 100 end
    if percent ~= nil then record.bestClearedPercent = math.max(record.bestClearedPercent or 0, percent) end
    if newBest then record.score = score end
    record.cleared = record.cleared == true or beaten
    record.fullCleared = record.fullCleared == true or full

    profile.records[key] = record
    profile.runs = math.min(maxCounter, profile.runs + 1)
    profile.bestCombo = math.max(profile.bestCombo, count(result.bestCombo, maxCounter) or 0)
    return {
        record = record, newBest = newBest, newBeat = newBeat, newMastery = newMastery,
        pointsEarned = (newBeat and 1 or 0) + (newMastery and 1 or 0),
    }
end

return Progress
