local Duel = {}
Duel.__index = Duel

-- PW1/PW2 use three base-36 digits for each offset shot angle. PW3 uses four base-64
-- digits for the shot angle and the catcher's position within its cycle at launch.
local maxSeed, maxRounds, angleScale = 2147483646, 48, 10000
local legacyVersion, fixedCatcherVersion, timedCatcherVersion = 1, 2, 3
local angleLimits = {12200, 18300, 18300}
local catcherCycleTicks = 432
local legacyBoards = {grove = true, foundry = true, basin = true, crown = true, tide = true, vault = true}
local legacyModes = {standard = true, precision = true, practice = true}
local maxCodeLength = 256
local base36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local base64Values = {}
for i = 1, #base64 do base64Values[base64:sub(i, i)] = i - 1 end
local eventName = "pegworks_duel_tell"
local eventPattern = "#1# tells you, 'PW#2#'"

local function integer(value, minimum, maximum)
    return type(value) == "number" and value >= minimum and value <= maximum and value == math.floor(value)
end

local function validId(value)
    return type(value) == "string" and #value <= 12 and value:match("^[a-z]+$") ~= nil
end

local function validPeer(name)
    return type(name) == "string" and #name <= 63 and name:match("^[A-Za-z]+$") ~= nil
end

local function versionForRules(maxAngle, timedCatcher)
    if maxAngle == angleLimits[legacyVersion] / angleScale then
        if not timedCatcher then return legacyVersion end
    elseif maxAngle == nil or maxAngle == angleLimits[timedCatcherVersion] / angleScale then
        if timedCatcher == false then return fixedCatcherVersion end
        return timedCatcherVersion
    end
end

local function encodeDigits(value, digits, width)
    local chars = {}
    for i = width, 1, -1 do
        local index = value % #digits + 1
        chars[i] = digits:sub(index, index)
        value = math.floor(value / #digits)
    end
    return table.concat(chars)
end

local function decodeBase64(chars)
    local value = 0
    for i = 1, #chars do
        local digit = base64Values[chars:sub(i, i)]
        if digit == nil then return nil end
        value = value * 64 + digit
    end
    return value
end

local function encodeHeader(version, kind, boardId, seed, modeId)
    if not angleLimits[version] then return nil, "This combination of aim and catcher rules cannot be shared." end
    if not validId(boardId) or not validId(modeId) or not integer(seed, 1, maxSeed) then
        return nil, "This board, mode, or seed cannot be shared."
    end
    if version == legacyVersion and not (legacyBoards[boardId] and legacyModes[modeId]) then
        return nil, "This board or mode is unavailable with legacy rules."
    end
    return string.format("PW%d%s-%s-%s-%.0f", version, kind, boardId, modeId, seed)
end

function Duel.challenge(boardId, seed, modeId, maxAngle, timedCatcher)
    return encodeHeader(versionForRules(maxAngle, timedCatcher), "C", boardId, seed, modeId)
end

function Duel.result(run)
    local result = run:result()
    if result.phase ~= "won" and result.phase ~= "lost" then
        return nil, "Finish the round to share a replay."
    end
    local version = versionForRules(run.maxAngle, run.timedCatcher)
    local header, err = encodeHeader(version, "R", result.boardId, result.seed, result.modeId)
    if not header then return nil, err end

    local angleLimit = angleLimits[version]
    local angles = run.angles
    if #angles < 1 or #angles > maxRounds then return nil, "This round cannot be shared." end
    local shots = {}
    local timedCatcher = version == timedCatcherVersion
    local angleCount = angleLimit * 2 + 1
    local launchTicks = run.launchCatcherTicks
    for i, angle in ipairs(angles) do
        if not integer(angle, -angleLimit, angleLimit) then return nil, "This shot cannot be shared." end
        local offsetAngle = angle + angleLimit
        if timedCatcher then
            local catcherTick = launchTicks and launchTicks[i]
            if not integer(catcherTick, 0, catcherCycleTicks - 1) then return nil, "This shot has invalid timing." end
            shots[i] = encodeDigits(offsetAngle + angleCount * catcherTick, base64, 4)
        else
            shots[i] = encodeDigits(offsetAngle, base36, 3)
        end
    end
    return header .. "-" .. table.concat(shots)
end

local function hasId(options, id)
    for _, option in ipairs(options) do
        if option.id == id then return true end
    end
    return false
end

local function decode(game, code)
    if type(code) ~= "string" or #code > maxCodeLength then return nil, "Enter a valid Peggle code." end
    code = code:match("^%s*(.-)%s*$")
    local versionText, kind, boardId, modeId, seedText, tail =
        code:match("^[Pp][Ww](%d)([CcRr])%-([A-Za-z]+)%-([A-Za-z]+)%-(%d+)(.*)$")
    local version = tonumber(versionText)
    local angleLimit = angleLimits[version]
    if not angleLimit then return nil, "Enter a supported Peggle challenge or replay code." end

    kind, boardId, modeId = kind:upper(), boardId:lower(), modeId:lower()
    local seed = tonumber(seedText)
    local header, err = encodeHeader(version, kind, boardId, seed, modeId)
    if not header then return nil, err end
    if not hasId(game.boards, boardId) or not hasId(game.modes, modeId) then
        return nil, "This board, mode, or seed is unavailable."
    end
    local timedCatcher = version == timedCatcherVersion
    local entry = {
        kind = "challenge", boardId = boardId, seed = seed, modeId = modeId, code = header,
        version = version, maxAngle = angleLimit / angleScale, timedCatcher = timedCatcher,
    }
    if kind == "C" then
        if tail == "" then return entry end
        return nil, "This challenge code has extra text."
    end

    local payload = tail:match("^%-(.+)$")
    local width = timedCatcher and 4 or 3
    if not payload or #payload % width ~= 0 or #payload > maxRounds * width then
        return nil, "This replay code has an invalid shot list."
    end
    if not timedCatcher then
        payload = payload:lower()
        if not payload:match("^[0-9a-z]+$") then return nil, "This replay code has an invalid shot angle." end
    end
    local angles, catcherTicks = {}, {}
    local angleCount = angleLimit * 2 + 1
    for i = 1, #payload, width do
        local shot = payload:sub(i, i + width - 1)
        if timedCatcher then
            local value = decodeBase64(shot)
            if not value or value >= angleCount * catcherCycleTicks then
                return nil, "This replay code has an invalid timed shot."
            end
            angles[#angles + 1] = value % angleCount - angleLimit
            catcherTicks[#catcherTicks + 1] = math.floor(value / angleCount)
        else
            local angle = tonumber(shot, 36) - angleLimit
            if angle > angleLimit then return nil, "This replay code has an invalid shot angle." end
            angles[#angles + 1] = angle
        end
    end
    entry.kind = "result"
    entry.code = header .. "-" .. payload
    entry.angles = angles
    entry.catcherTicks = catcherTicks
    return entry
end

function Duel.new(game, mq)
    return setmetatable({game = game, mq = mq, listening = false, verifying = false}, Duel)
end

function Duel:import(code)
    local entry, err = decode(self.game, code)
    if not entry then return nil, err end
    if entry.kind == "result" then
        self.replayRun = self.game.new(entry.boardId, entry.seed, entry.modeId, entry.maxAngle, entry.timedCatcher)
        self.replay = entry
        self.shotIndex = 1
        self.shotSteps = 0
        self.verified = nil
        self.error = nil
        self.verifying = true
    end
    return entry
end

function Duel:tick()
    if not self.verifying then return end
    local run, entry = self.replayRun, self.replay

    -- A replay shares the script's time slice with the player's own round.
    for _ = 1, 4 do
        if self.game.isTerminal(run.phase) then
            if self.shotIndex == #entry.angles + 1 then
                self.verified = run:result()
                self.verified.code = entry.code
                self.verified.maxAngle = entry.maxAngle
                self.verified.version = entry.version
                self.verified.timedCatcher = entry.timedCatcher
            else
                self.error = "This replay lists shots after the round ended."
            end
            break
        end

        if run.phase == "flight" then
            self.shotSteps = self.shotSteps + 1
            if self.shotSteps > 80 then
                self.error = "This replay could not finish a shot."
                break
            end
            run:update(0.25)
        else
            local angle = entry.angles[self.shotIndex]
            local catcherTick = entry.catcherTicks[self.shotIndex]
            if angle == nil or not run:launch(angle / angleScale, catcherTick) then
                self.error = "This replay stopped before the round ended."
                break
            end
            self.shotIndex = self.shotIndex + 1
            self.shotSteps = 0
        end
    end

    if self.verified or self.error then
        self.verifying = false
        self.replay, self.replayRun = nil, nil
    end
end

function Duel:listen(enabled)
    if enabled == self.listening then return true end
    if not self.mq then return nil, "Tells are unavailable. You can still exchange codes." end
    if not enabled then
        self.mq.unevent(eventName)
        self.listening = false
        self.inbox = nil
        return true
    end

    local ok = pcall(self.mq.event, eventName, eventPattern, function(_, peer, suffix)
        if not self.listening or not validPeer(peer) then return end
        local incoming = decode(self.game, "PW" .. suffix)
        if incoming then self.inbox = {peer = peer, code = incoming.code, kind = incoming.kind} end
    end)
    if not ok then return nil, "Listening for tells is unavailable. You can still paste a code." end
    self.listening = true
    return true
end

function Duel:send(peer, code)
    if not self.mq then return nil, "Tells are unavailable. You can still exchange codes." end
    if not validPeer(peer) then return nil, "Enter your friend's character name." end
    local entry, err = decode(self.game, code)
    if not entry then return nil, err end
    if not pcall(self.mq.cmd, "/tell " .. peer .. " " .. entry.code) then
        return nil, "Could not submit this tell. You can still share the code."
    end
    return true
end

return Duel
