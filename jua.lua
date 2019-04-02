local jua = {}

local running = false
local threads = {}

local function count(object)
  local i = 0
  for k, v in pairs(object) do
    i = i + 1
  end
  return i
end

local function contains(value, object)
  for k, v in pairs(object) do
    if v == value or k == value then
      return true
    end
  end

  return false
end

local function newPid()
  for i = 1, math.huge do
    if not threads[i] then
      return i
    elseif not threads[-i] then
      return -i
    end
  end
end

local function threadStatus(pid)
  if threads[pid] then
    return coroutine.status(threads[pid])
  else
    return "free"
  end
end

local function removeThread(pid)
  threads[pid] = nil
end

local function resumeThread(pid, ...)
  local success, kill = coroutine.resume(threads[pid], ...)
  if success and kill then
    removeThread(pid)
  elseif not success then
    error(kill)
  end

  return success
end

local function newThread(func, ...)
  local thread = coroutine.create(func)
  local pid = newPid()
  threads[pid] = thread
  resumeThread(pid, ...)
  return pid
end

local function newEventThread(func)
  newThread(function()
    while true do
      local event = {coroutine.yield()}
      if #event > 0 then
        newThread(func, unpack(event))
      end
    end
  end)
end

local function killRunningThread()
  coroutine.yield(true)
end

local function eventLoop()
  while running do
    local event = {coroutine.yield()}

    for pid, _ in pairs(threads) do
      local status = threadStatus(pid)

      if status == "suspended" then
        resumeThread(pid, unpack(event))
      end
      
      if status == "dead" then
        removeThread(pid)
      end
    end
  end
end

jua.on = function(onEvent, func)
  newEventThread(function(...)
    local eargs = {...}
    local event = eargs[1]
    
    if   (type(onEvent) == "string"   and event == onEvent)
      or (type(onEvent) == "function" and onEvent(event))
      or (type(onEvent) == "table"    and contains(event, onEvent))
      or (onEvent == "*") then
        func(...)
    end
  end)
end

jua.onInterval = function(interval, func)
  local timer = os.startTimer(interval)

  jua.on("timer", function(_, tid)
    if tid == timer then
      func()
      timer = os.startTimer(interval)
    end
  end)
end

jua.setInterval = function(func, interval)
  return jua.onInterval(interval, func)
end

jua.onTimeout = function(timeout, func)
  local timer = os.startTimer(timeout)

  newThread(function()
    while true do
      local eargs = {coroutine.yield()}
      local event = eargs[1]
      local tid = eargs[2]

      if event == "timer" and tid == timer then
        func()
        killRunningThread()
      end
    end
  end)
end

jua.setTimeout = function(func, timeout)
  return jua.onTimeout(timeout, func)
end

jua.run = function()
  os.queueEvent("jua_init")
  running = true
  eventLoop()
end

jua.stop = function()
  running = false
end

jua.go = function(func)
  newThread(function()
    print("go")
    coroutine.yield()
    func()
  end)
  jua.run()
end

return jua