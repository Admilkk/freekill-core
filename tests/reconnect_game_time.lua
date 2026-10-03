-- SPDX-License-Identifier: GPL-3.0-or-later
-- 在 core 仓库根目录运行：lua5.4 tests/reconnect_game_time.lua
fk = { os = os, io = io }
class = dofile "lua/lib/middleclass.lua"
Util = dofile "lua/core/util.lua"

local function assertEquals(actual, expected)
  assert(actual == expected, ("expected %s, got %s"):format(tostring(expected), tostring(actual)))
end
local ClientBase = dofile "lua/client/clientbase.lua"
local ServerRoomBase = dofile "lua/server/roombase.lua"

local tests = {}
local now

local function serverSummary(start_time)
  return ServerRoomBase.serialize({
    start_time = start_time,
    class = { super = { serialize = function()
      return {
        circle = {}, players = { [1] = { setup_data = { 1, "test", "guojia", nil, 0 } } },
        observers = {}, settings = {}, timeout = 15, you = 1,
      }
    end } },
  })
end

local function fakeClient()
  local client = setmetatable({
    replaying = true, capacity = 0, players = {}, observers = {},
    observer_setup_data = { 1, "test", "guojia", 0 },
  }, { __index = ClientBase })
  client.client = { notifyUI = function(_, command)
    if command == "StartGame" then
      client.timeShownAtStart = os.time() - client.gameStartTime
    end
  end }
  client.enterRoom = function() ClientInstance = fakeClient() end
  for _, name in ipairs {
    "addPlayer", "addObserver", "arrangeSeats", "deserialize", "sendDataToUI",
    "stopRecording", "setup", "addTotalGameTime", "getPlayerById", "ensureObserverIdentity",
  } do client[name] = Util.DummyFunc end
  return client
end

function tests.testServerIncludesElapsedDuration()
  assertEquals(serverSummary(now - 300).played_time, 300)
end

function tests.testServerBeforeGameStarts()
  assertEquals(serverSummary(nil).played_time, 0)
end

function tests.testServerClockMovedBackwards()
  assertEquals(serverSummary(now + 10).played_time, 0)
end

function tests.testReconnectRestoresDurationWithDifferentClock()
  local summary = serverSummary(now - 300)
  now = now + 7200
  local client = fakeClient()
  client:reconnect(summary)
  assert(ClientInstance ~= client, "reconnect must rebuild the client")
  assertEquals(ClientInstance.timeShownAtStart, 300)
  now = now + 25
  assertEquals(os.time() - ClientInstance.gameStartTime, 325)
end

function tests.testObserveRestoresDuration()
  fakeClient():observe(serverSummary(now - 450))
  assertEquals(ClientInstance.timeShownAtStart, 450)
end

function tests.testLegacySummaryStartsFromZero()
  local summary = serverSummary(now - 300)
  summary.played_time = nil
  fakeClient():loadRoomSummary(summary)
  assertEquals(ClientInstance.timeShownAtStart, 0)
end

function tests.testNormalStartAndNextGameStartFromZero()
  local client = fakeClient()
  client:startGame()
  assertEquals(client.timeShownAtStart, 0)
  now = now + 300
  client.gameStarted = false
  client:startGame()
  assertEquals(client.timeShownAtStart, 0)
end

local names = {}
for name in pairs(tests) do table.insert(names, name) end
table.sort(names)
local failures = 0
for _, name in ipairs(names) do
  local oldTime, oldClient = os.time, ClientInstance
  now = 10000
  os.time = function() return now end
  local success, message = xpcall(tests[name], debug.traceback)
  os.time, ClientInstance = oldTime, oldClient
  failures = failures + (success and 0 or 1)
  print(success and "PASS " .. name or "FAIL " .. name .. ": " .. message)
end
print(("%d tests, %d failures"):format(#names, failures))
os.exit(failures == 0 and 0 or 1)
