local jua = {}

-- local state for whether the jua event loop is running
local running = false
-- local thread group
local threads = {}

-- counts elements in a table
local function count(object)
  local i = 0
  for k, v in pairs(object) do
    i = i + 1
  end
  return i
end

-- checks for a table containing an object as a key or value
local function contains(value, object)
  for k, v in pairs(object) do
    if v == value or k == value then
      return true
    end
  end

  return false
end

-- finds the lowest free pid
local function newPid()
  for i = 1, math.huge do
    if not threads[i] then
      return i
    elseif not threads[-i] then
      return -i
    end
  end
end

-- returns status of a given pid (suspended, running, dead, free)
local function threadStatus(pid)
  if threads[pid] then
    return coroutine.status(threads[pid])
  else
    return "free"
  end
end

-- removes a thread from the local thread group
local function removeThread(pid)
  threads[pid] = nil
end

-- runs/"resumes" a thread by pid immediately with optional args
local function resumeThread(pid, ...)
  local success, kill = coroutine.resume(threads[pid], ...)
  if success and kill then
    removeThread(pid)
  elseif not success then
    error(kill)
  end

  return kill
end

-- spawns a thread and runs it immediately with optional args
local function newThread(func, ...)
  local thread = coroutine.create(func)
  local pid = newPid()
  threads[pid] = thread
  local success, kill = resumeThread(pid, ...)
  return pid, kill
end

-- spawns a forking event loop based thread (note, it follows a KILL from child processes if told to do so)
local function newEventThread(func)
  newThread(function()
    while true do
      local event = {coroutine.yield()}
      if #event > 0 then
        local pid, kill = newThread(func, unpack(event))
        
        if kill then
          break
        end
      end
    end
  end)
end

-- kills the thread which this function is called from (marked dead)
local function killRunningThread()
  coroutine.yield(true)
end

-- internal thread managing event loop
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

-- spawns a forking event thread with an event filter (function predicate, table of strings, string)
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

-- spawns a recurring timer thread
jua.onInterval = function(interval, func)
  local timer = os.startTimer(interval)

  jua.on("timer", function(_, tid)
    if tid == timer then
      func()
      timer = os.startTimer(interval)
    end
  end)
end

-- alternative to onInterval with reversed args
jua.setInterval = function(func, interval)
  return jua.onInterval(interval, func)
end

-- spawns a one-time timer thread
jua.onTimeout = function(timeout, func)
  local timer = os.startTimer(timeout)

  jua.on("timer", function(event, tid)
    if tid == timer then
      func()
      killRunningThread()
    end
  end)
end

-- alternative to onTimeout with reversed args
jua.setTimeout = function(func, timeout)
  return jua.onTimeout(timeout, func)
end

-- queues a jua_init event, sets running to true and runs the event loop
jua.run = function()
  os.queueEvent("jua_init")
  running = true
  eventLoop()
end

-- sets running to false, stopping the event loop ASAP
jua.stop = function()
  running = false
end

-- jua.run with a callback on jua_init
jua.go = function(func)
  jua.on("jua_init", function()
    func()
    killRunningThread()
  end)
  jua.run()
end

-- export jua
return jua