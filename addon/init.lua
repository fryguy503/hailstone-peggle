-- Copyright 2026 fryguy503. All rights reserved. See LICENSE.
local mq = require('mq')
local ui = require('ImGui')
local Game = require('game')
local Duel = require('duel')
local Cabinet = require('cabinet')

local profilePath = mq.configDir..'/pegworks.lua'

local function count(value)
    return type(value) == 'number' and value >= 0 and value <= 1000000000 and math.floor(value) or 0
end

local function loadProfile()
    local profile = {records={}, runs=0, bestCombo=0}
    local chunk = loadfile(profilePath)
    if not chunk then return profile end

    local ok, saved = pcall(chunk)
    if not ok or type(saved) ~= 'table' then return profile end
    profile.runs, profile.bestCombo = count(saved.runs), count(saved.bestCombo)
    if type(saved.records) == 'table' then
        for _, board in ipairs(Game.boards) do
            for _, mode in ipairs(Game.modes) do
                local key = board.id..'/'..mode.id
                local entry = saved.records[key]
                if type(entry) == 'table' then
                    profile.records[key] = {score=count(entry.score), cleared=entry.cleared == true}
                end
            end
        end
    end
    return profile
end

local function indexOf(list, id)
    for index, entry in ipairs(list) do
        if entry.id == id then return index end
    end
    return 1
end

local seedNonce = 0
local function freshSeed()
    seedNonce = seedNonce + 1
    return (os.time()*65537 + math.floor(mq.gettime())*101 + seedNonce*293) % 2147483646 + 1
end

local state = {
    Game=Game, duel=Duel.new(Game, mq), profile=loadProfile(), page='play',
    open=(...) == 'open', peer='', inCode='', outCode='', effects={}, trail={},
    now=0, dt=0, noticeUntil=0, trailTime=0,
}

function state:start(boardId, seed, modeId, challenge)
    self.run = assert(Game.new(boardId, seed, modeId))
    self.challenge = challenge
    self.trail, self.effects = {}, {}
    self.notice, self.guideAngle, self.mouseX, self.mouseY = nil, nil, nil, nil
    self.trailTime = 0
end

function state:record(boardId, modeId)
    local key = (boardId or self.run.boardId)..'/'..(modeId or self.run.modeId)
    return self.profile.records[key] or {}
end

function state:restart()
    local run = self.run
    self:start(run.boardId, run.seed, run.modeId, self.challenge)
end

function state:pickBoard(delta)
    local boards = Game.boards
    local index = indexOf(boards, self.run.boardId)
    local board = boards[(index-1+delta) % #boards+1]
    self:start(board.id, freshSeed(), self.run.modeId, false)
end

function state:pickMode()
    local index = indexOf(Game.modes, self.run.modeId)
    local mode = Game.modes[index % #Game.modes+1]
    self:start(self.run.boardId, self.run.seed, mode.id, false)
end

function state:launch()
    if self.run:launch() then
        self.trail, self.effects = {}, {}
        self.notice, self.guideAngle = nil, nil
        self.trailTime = 0
    end
end

function state:status(message, issue)
    self.duelStatus, self.duelIssue = message, issue
end

function state:beginChallenge(boardId, seed, modeId, stay)
    self:start(boardId, seed, modeId, true)
    if not stay then self.page = 'play' end
end

function state:createChallenge()
    local run, seed = self.run, freshSeed()
    local code, errorText = Duel.challenge(run.boardId, seed, run.modeId)
    if not code then return self:status(errorText, true) end
    self:beginChallenge(run.boardId, seed, run.modeId, true)
    self.outCode = code
    self:status('Challenge ready. Share the code, then open Play.')
end

function state:shareResult()
    local code, errorText = Duel.result(self.run)
    if not code then return self:status(errorText, true) end
    self.outCode = code
    self:status('Result ready to share.')
end

function state:importCode()
    local entry, errorText = self.duel:import(self.inCode)
    if not entry then
        self.offer = nil
        return self:status(errorText, true)
    end
    if entry.kind == 'challenge' then
        self.offer = entry
        self:status('Challenge ready to play.')
    else
        self:status('Result received.')
    end
end

function state:acceptChallenge()
    local offer = self.offer
    if not offer then return end
    self:beginChallenge(offer.boardId, offer.seed, offer.modeId)
    self.offer = nil
end

function state:sendCode()
    self.pendingTell = {peer=self.peer, code=self.outCode}
end

function state:setListening(enabled)
    self.pendingListening = enabled
end

local function serviceDuels()
    local duel = state.duel
    if state.pendingListening ~= nil then
        local enabled = state.pendingListening
        state.pendingListening = nil
        local ok, errorText = duel:listen(enabled)
        state:status(ok and (enabled and 'Listening for Peggle tells.' or 'Tell listening is off.') or errorText, not ok)
    end
    local tell = state.pendingTell
    if tell then
        state.pendingTell = nil
        local ok, errorText = duel:send(tell.peer, tell.code)
        state:status(ok and 'Tell submitted. Check chat for delivery.' or errorText, not ok)
    end
    if duel.listening then mq.doevents() end
    duel:tick()
end

local function rememberResult(run)
    local profile = state.profile
    local record = state:record()
    profile.records[run.boardId..'/'..run.modeId] = {
        score=math.max(record.score or 0, run.score), cleared=record.cleared or run.phase == 'won',
    }
    profile.bestCombo = math.max(profile.bestCombo, run.bestCombo)
    profile.runs = profile.runs + 1
    local ok, result = pcall(mq.pickle, profilePath, profile)
    if not ok or result == false then
        state.notice, state.noticeUntil = 'Records could not be saved', state.now+4
    end
end

local function updateRun(dt, now)
    local run = state.run
    local events = run:update(dt)
    for _, event in ipairs(events) do
        if event.type == 'hit' or event.type == 'catch' then
            state.effects[#state.effects+1] = {x=event.x, y=event.y, kind=event.kind, points=event.points, time=now}
            if event.type == 'catch' then
                state.notice, state.noticeUntil = 'Catch!  +1 shot', now+1.85
            elseif event.kind == 'purple' then
                state.notice, state.noticeUntil = 'Resonance  /  x2 points', now+2.1
            elseif event.kind == 'green' then
                state.notice, state.noticeUntil = 'Boosted rebound', now+1.6
            end
        elseif event.type == 'finish' then
            rememberResult(run)
        end
    end
    while state.effects[1] and (now-state.effects[1].time >= 0.62 or #state.effects > 20) do
        table.remove(state.effects, 1)
    end
    if run.ball and now >= state.trailTime then
        local trail = state.trail
        trail[#trail+1] = {x=run.ball.x, y=run.ball.y}
        if #trail > 12 then table.remove(trail, 1) end
        state.trailTime = now+0.026
    end
end

state:start(Game.boards[1].id, freshSeed(), Game.modes[1].id, false)

local function toggleCabinet(args)
    if args == 'open' then state.open = true
    elseif args == 'close' then state.open = false
    else state.open = not state.open end
end

local primaryBound, bindError = pcall(mq.bind, '/peggle', toggleCabinet)
local aliasBound = pcall(mq.bind, '/pegworks', toggleCabinet)
if not primaryBound then
    if not aliasBound then error(bindError, 0) end
    print('[Peggle] /peggle is unavailable. Use /pegworks to open the cabinet.')
end

mq.imgui.init('pegworks', function()
    if state.open then Cabinet.draw(ui, state, state.now) end
end)

local last = mq.gettime()/1000
while true do
    local now = mq.gettime()/1000
    state.now, state.dt = now, math.max(0, math.min(0.10, now-last))
    last = now
    updateRun(state.dt, now)
    serviceDuels()
    mq.delay(10)
end
