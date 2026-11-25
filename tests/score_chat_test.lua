package.path = "./addon/?.lua;" .. package.path

local ScoreChat = require("score_chat")
local Game = require("game")

local record = {boardName = "Lantern Grove", modeName = "Standard", score = 12345}
local expected = "[Peggle] Personal best of 12,345 on Lantern Grove (Standard)."
assert(ScoreChat.format(record) == expected)
assert(ScoreChat.format({boardName = "Lantern Grove", modeName = "Standard", score = 0}):find("best of 0", 1, true))
for _, board in ipairs(Game.boards) do
    for _, mode in ipairs(Game.modes) do
        assert(ScoreChat.format({boardName = board.name, modeName = mode.name, score = 1000}))
    end
end

local sent = {}
local mq = {cmd = setmetatable({}, {__call = function(_, line) sent[#sent + 1] = line end})}
local channels = {group = "/gsay", guild = "/guildsay", raid = "/rsay", say = "/say"}
for index, channel in ipairs(ScoreChat.channels) do
    assert(ScoreChat.send(mq, channel.id, record))
    assert(sent[index] == channels[channel.id] .. " " .. expected)
end
assert(#sent == 4)

assert(not ScoreChat.send(mq, "/ooc", record))
assert(not ScoreChat.send(mq, "say\n/rsay", record))
for _, name in ipairs({"", "Fake\n/rsay test", "${Me.Name}", "Hello %T", "Piece\x12link"}) do
    assert(not ScoreChat.send(mq, "say", {boardName = name, modeName = "Standard", score = 1}))
end
for _, score in ipairs({-1, 1.5, math.huge, 0/0, 1000000001, "10"}) do
    assert(not ScoreChat.send(mq, "say", {boardName = "Lantern Grove", modeName = "Standard", score = score}))
end
assert(#sent == 4)
assert(not ScoreChat.send({cmd = function() error("mock permission failure") end}, "say", record))

print("Peggle score formatting and chat submission tests passed.")
