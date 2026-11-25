-- Copyright 2026 fryguy503. All rights reserved. See LICENSE.
local mq = require('mq')
local ui = require('ImGui')
local Game = require('game')
local Duel = require('duel')
local Cabinet = require('cabinet')
local ScoreChat = require('score_chat')
local Progress = require('progress')

local profilePath = mq.configDir..'/pegworks.lua'

local function loadProfile()
    local saved
    local chunk = loadfile(profilePath)
    if chunk then
        local ok, value = pcall(chunk)
        if ok then saved = value end
    end
    return Progress.load(Game, saved)
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
    Game=Game, Progress=Progress, ScoreChat=ScoreChat, duel=Duel.new(Game, mq), profile=loadProfile(), page='play',
    open=(...) == 'open', peer='', inCode='', outCode='', effects={}, trail={},
    now=0, dt=0, noticeUntil=0, trailTime=0, shareChannel=ScoreChat.channels[1].id, boardPreviews={},
}

for index, board in ipairs(Game.boards) do
    state.boardPreviews[board.id] = Game.new(board.id, 41753*index).pegs
end

function state:recordRun(run)
    if self.recordedRun == run or not Game.isTerminal(run.phase) then return end
    local result = Progress.applyResult(self.profile, run:result())
    self.recordedRun, self.profileDirty = run, true
    self.earnedPoints = result and result.pointsEarned or 0
    self.finishedAt = self.now
end

function state:start(boardId, seed, modeId, challenge, maxAngle, timedCatcher)
    local previous = self.run
    if previous then
        if previous.solo and previous.beaten and previous.phase == 'ready' then previous:bank() end
        self:recordRun(previous)
    end
    local soloOptions = not challenge and Progress.modifiers(self.profile) or nil
    self.run = Game.new(boardId, seed, modeId, maxAngle, timedCatcher, soloOptions)
    self.challenge = challenge
    self.trail, self.effects = {}, {}
    self.notice, self.beatAt, self.finishedAt, self.guideAngle = nil, nil, nil, nil
    self.mouseX, self.mouseY = nil, nil
    self.trailTime, self.earnedPoints = 0, 0
end

function state:record(boardId, modeId)
    return Progress.record(self.profile, boardId or self.run.boardId, modeId or self.run.modeId)
end

function state:selectScore(board, mode, score)
    local record = {boardName=board.name, modeName=mode.name, score=score}
    local message = ScoreChat.format(record)
    if not message then return end
    self.shareRecord, self.shareMessage = record, message
    self.shareBoardId, self.shareModeId = board.id, mode.id
    self.shareStatus = nil
end

function state:sendScore()
    self.pendingScore = {channel=self.shareChannel, record=self.shareRecord}
end

function state:restart()
    local run = self.run
    self:start(run.boardId, run.seed, run.modeId, self.challenge, run.maxAngle, run.timedCatcher)
end

function state:pickBoard(delta)
    local boards = Game.boards
    local index = indexOf(boards, self.run.boardId)
    local board = boards[(index-1+delta) % #boards+1]
    self:start(board.id, freshSeed(), self.run.modeId, false)
end

function state:chooseBoard(boardId)
    self:start(boardId, freshSeed(), self.run.modeId, false)
    self.page = 'play'
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

function state:bank()
    if self.run:bank() then self:recordRun(self.run) end
end

local function talentEdit(self, ok, issue)
    self.talentIssue = not ok
    if not ok then
        self.talentStatus = issue
        return
    end

    self.profileDirty = true
    local run = self.run
    if run.solo and run.rounds == 0 then
        self:restart()
        self.talentStatus = 'Applied to your current board.'
    else
        self.talentStatus = 'Applies to your next solo run.'
    end
end

function state:buyTalent(id)
    talentEdit(self, Progress.buy(self.profile, id))
end

function state:resetTalents()
    talentEdit(self, Progress.reset(self.profile))
end

function state:selectLauncher(id)
    if self.profile.launcher ~= id then talentEdit(self, Progress.selectLauncher(self.profile, id)) end
end

function state:status(message, issue)
    self.duelStatus, self.duelIssue = message, issue
end

function state:beginChallenge(boardId, seed, modeId, maxAngle, timedCatcher, stay)
    self:start(boardId, seed, modeId, true, maxAngle, timedCatcher)
    if not stay then self.page = 'play' end
end

function state:createChallenge()
    local run, seed = self.run, freshSeed()
    local code, errorText = Duel.challenge(run.boardId, seed, run.modeId)
    if not code then return self:status(errorText, true) end
    self:beginChallenge(run.boardId, seed, run.modeId, Game.maxAngle, true, true)
    self.outCode = code
    self:status('Challenge ready. Share the code, then open Play.')
end

function state:shareResult()
    if self.run.solo then return self:status('Play a friend challenge to share a replay.', true) end
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
    self:beginChallenge(offer.boardId, offer.seed, offer.modeId, offer.maxAngle, offer.timedCatcher)
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

local function serviceScoreChat()
    local pending = state.pendingScore
    if not pending then return end
    state.pendingScore = nil
    local ok = ScoreChat.send(mq, pending.channel, pending.record)
    if pending.record == state.shareRecord then
        state.shareStatus = ok and 'Submitted to chat' or 'Copy text to share'
        state.shareIssue = not ok
    end
end

local function saveProfile(now)
    if not state.profileDirty or now < (state.saveAfter or 0) then return end
    local ok, result = pcall(mq.pickle, profilePath, state.profile)
    if not ok or result == false then
        state.notice, state.noticeUntil = 'Progress could not be saved', now+4
        state.noticeTone = 'red'
        state.talentStatus, state.talentIssue = 'Progress could not be saved. Retrying.', true
        state.saveAfter = now+2
    else
        state.profileDirty, state.saveAfter = false, nil
    end
end

local function updateRun(dt, now)
    local run = state.run
    local events = run:update(dt)
    for _, event in ipairs(events) do
        if event.type == 'hit' or event.type == 'catch' then
            local label
            if event.kind == 'green' then label = run.launcherStyle == 'catchfield' and 'CATCHFIELD' or 'BOOST' end
            state.effects[#state.effects+1] = {
                x=event.x, y=event.y, kind=event.kind, points=event.points, time=now, label=label,
            }
            if event.type == 'catch' then
                state.notice, state.noticeUntil = 'Catch!  +1 shot', now+1.85
                if event.points then state.notice = state.notice..'  + '..event.points..' pts' end
                state.noticeTone = 'gold'
            elseif event.kind == 'green' then
                local power = run.launcherStyle == 'catchfield' and 'Catchfield' or 'Ricochet boost'
                state.notice, state.noticeUntil = power, now+2.1
                state.noticeTone = 'green'
            end
        elseif event.type == 'beat' then
            state.beatAt = now
        elseif event.type == 'finish' then
            state:recordRun(run)
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
    saveProfile(now)
    serviceDuels()
    serviceScoreChat()
    mq.delay(10)
end
