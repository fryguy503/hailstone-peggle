local Duel = {}
Duel.__index = Duel

-- Version 1 encodes a board, mode and seed, followed by three base-36 digits per shot.
-- A shot records its signed angle in ten-thousandths of a radian, offset to be nonnegative.
local maxSeed, maxRounds, angleLimit, angleScale = 2147483646, 48, 12200, 10000
local maxCodeLength = 192
local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
local eventName = "pegworks_duel_tell"
local eventPattern = "#1# tells you, 'PW1#2#'"

local function integer(value, minimum, maximum)
    return type(value) == "number" and value >= minimum and value <= maximum and value == math.floor(value)
end

local function validId(value)
    return type(value) == "string" and #value <= 12 and value:match("^[a-z]+$") ~= nil
end

local function validPeer(name)
    return type(name) == "string" and #name <= 63 and name:match("^[A-Za-z]+$") ~= nil
end

local function encodeAngle(angle)
    local value = angle + angleLimit
    local high = math.floor(value / 1296) + 1
    local middle = math.floor(value / 36) % 36 + 1
    local low = value % 36 + 1
    return digits:sub(high, high) .. digits:sub(middle, middle) .. digits:sub(low, low)
end

local function encodeHeader(kind, boardId, seed, modeId)
    if not validId(boardId) or not validId(modeId) or not integer(seed, 1, maxSeed) then
        return nil, "This board, mode, or seed cannot be shared."
    end
    return string.format("PW1%s-%s-%s-%.0f", kind, boardId, modeId, seed)
end

function Duel.challenge(boardId, seed, modeId)
    return encodeHeader("C", boardId, seed, modeId)
end

function Duel.result(run)
    local result = run:result()
    if result.phase ~= "won" and result.phase ~= "lost" then
        return nil, "Finish the round to share a replay."
    end
    local header, err = encodeHeader("R", result.boardId, result.seed, result.modeId)
    if not header then return nil, err end

    local angles = run.angles
    if #angles < 1 or #angles > maxRounds then return nil, "This round cannot be shared." end
    local shots = {}
    for i, angle in ipairs(angles) do
        if not integer(angle, -angleLimit, angleLimit) then return nil, "This shot cannot be shared." end
        shots[i] = encodeAngle(angle)
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
    if type(code) ~= "string" or #code > maxCodeLength then return nil, "Enter a valid Pegworks code." end
    code = code:lower():match("^%s*(.-)%s*$")
    local kind, boardId, modeId, seedText, tail = code:match("^pw1([cr])%-([a-z]+)%-([a-z]+)%-(%d+)(.*)$")
    if not kind then return nil, "Enter a Pegworks v1 challenge or replay code." end

    local seed = tonumber(seedText)
    local header = encodeHeader(kind:upper(), boardId, seed, modeId)
    if not header or not hasId(game.boards, boardId) or not hasId(game.modes, modeId) then
        return nil, "This board, mode, or seed is unavailable."
    end
    local entry = {kind = "challenge", boardId = boardId, seed = seed, modeId = modeId, code = header}
    if kind == "c" then
        if tail == "" then return entry end
        return nil, "This challenge code has extra text."
    end

    local payload = tail:match("^%-([0-9a-z]+)$")
    if not payload or #payload % 3 ~= 0 or #payload > maxRounds * 3 then
        return nil, "This replay code has an invalid shot list."
    end
    local angles = {}
    for i = 1, #payload, 3 do
        local angle = tonumber(payload:sub(i, i + 2), 36) - angleLimit
        if angle > angleLimit then return nil, "This replay code has an invalid shot angle." end
        angles[#angles + 1] = angle
    end
    entry.kind = "result"
    entry.code = header .. "-" .. payload
    entry.angles = angles
    return entry
end

function Duel.new(game, mq)
    return setmetatable({game = game, mq = mq, listening = false, verifying = false}, Duel)
end

function Duel:import(code)
    local entry, err = decode(self.game, code)
    if not entry then return nil, err end
    if entry.kind == "result" then
        self.replayRun = self.game.new(entry.boardId, entry.seed, entry.modeId)
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
            if angle == nil or not run:launch(angle / angleScale) then
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
        local incoming = decode(self.game, "PW1" .. suffix)
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
