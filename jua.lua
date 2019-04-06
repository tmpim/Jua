local jua = {}

-- Local state for whether the jua event loop is running
local running = false
-- Local thread group
local threads = {}

-- Counts elements in a table
local function count(object)
  local i = 0
  for k, v in pairs(object) do
    i = i + 1
  end
  return i
end

-- Checks for a table containing an object as a key or value
local function contains(value, object)
  for k, v in pairs(object) do
    if v == value or k == value then
      return k
    end
  end

  return false
end

-- Finds the lowest free pid
local function newPid()
  for i = 1, math.huge do
    if not threads[i] then
      return i
    elseif not threads[-i] then
      return -i
    end
  end
end

-- Returns pid of given coroutine
local function getPid(thread)
  return contains(thread, threads)
end

-- Returns status of a given pid (suspended, running, dead, free)
local function threadStatus(pid)
  if threads[pid] then
    return coroutine.status(threads[pid])
  else
    return "free"
  end
end

-- Removes a thread from the local thread group
local function removeThread(pid)
  threads[pid] = nil
end

-- Runs/"resumes" a thread by pid immediately with optional args
local function resumeThread(pid, ...)
  local success, kill = coroutine.resume(threads[pid], ...)
  if success and kill then
    removeThread(pid)
  elseif not success then
    error(kill)
  end

  return kill
end

-- Spawns a thread and runs it immediately with optional args
local function newThread(func, ...)
  local thread = coroutine.create(func)
  local pid = newPid()
  threads[pid] = thread
  local success, kill = resumeThread(pid, ...)
  return pid, kill
end

-- Spawns a forking event loop based thread (note, it follows a KILL from child processes if told to do so)
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

-- Kills the thread which this function is called from (marked dead)
local function killRunningThread()
  coroutine.yield(true)
end

-- Internal thread managing event loop
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

-- Spawns a forking event thread with an event filter (function predicate, table of strings, string)
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

-- Spawns a forking event thread that kills itself after a single event
jua.once = function(onEvent, func)
  jua.on(onEvent, function(...)
    func(...)
    killRunningThread()
  end)
end

-- Spawns a recurring timer thread
jua.onInterval = function(interval, func)
  local timer = os.startTimer(interval)

  jua.on("timer", function(_, tid)
    if tid == timer then
      func()
      timer = os.startTimer(interval)
    end
  end)
end

-- Alternative to onInterval with reversed args
jua.setInterval = function(func, interval)
  return jua.onInterval(interval, func)
end

-- Spawns a one-time timer thread
jua.onTimeout = function(timeout, func)
  local timer = os.startTimer(timeout)

  jua.on("timer", function(event, tid)
    if tid == timer then
      func()
      killRunningThread()
    end
  end)
end

-- Alternative to onTimeout with reversed args
jua.setTimeout = function(func, timeout)
  return jua.onTimeout(timeout, func)
end

-- Returns a promise with the given executor
jua.promise = function(executor)
  local promise = {}

  promise.status = "pending"
  promise.done_callback = {}
  promise.fail_callback = {}
  promise.finally_callback = {}

  -- Registers callback for after promise has resolved
  promise.done = function(onFulfilled, onRejected)
    if promise.status == "fulfilled" and onFulfilled then
      newThread(onFulfilled, unpack(promise.results))
    elseif promise.status == "rejected" and onRejected then
      newThread(onRejected, unpack(promise.results))
    else
      if onFulfilled then
        table.insert(promise.done_callback, onFulfilled)
      end
  
      if onRejected then
        table.insert(promise.fail_callback, onRejected)
      end
    end

    return promise
  end

  -- Alternative to promise.done
  promise["then"] = promise.done

  -- Registers callback for after promise has rejected
  promise.fail = function(onRejected)
    promise.done(nil, onRejected)

    return promise
  end

  -- Alternative to promise.fail
  promise.catch = promise.fail

  -- Registers callback for after promise has resolved or rejected
  promise.finally = function(onFinally)
    if promise.status ~= "pending" and onFinally then
      newThread(onFinally)
    elseif onFinally then
      table.insert(promise.finally_callback, onFinally)
    end

    return promise
  end

  -- Helper function for resolve/reject
  promise.finish = function(success, ...)
    if promise.status ~= "pending" then
      error("Promise already resolved")
    end

    promise.success = success
    promise.results = {...}

    if success then
      promise.status = "fulfilled"

      if #promise.done_callback > 0 then
        for _, callback in pairs(promise.done_callback) do
          newThread(callback, unpack(promise.results))
        end
      end
    else
      promise.status = "rejected"

      if #promise.fail_callback > 0 then
        for _, callback in pairs(promise.fail_callback) do
          newThread(callback, unpack(promise.results))
        end
      end
    end

    if #promise.finally_callback > 0 then
      for _, callback in pairs(promise.finally_callback) do
        newThread(callback)
      end
    end

    return promise
  end
  
  -- Resolves the promise
  promise.resolve = function(...)
    promise.finish(true, ...)

    return promise
  end

  -- Rejects the promise
  promise.reject = function(...)
    promise.finish(false, ...)

    return promise
  end

  newThread(executor, promise.resolve, promise.reject)

  return promise
end


-- Queues a jua_init event, sets running to true and runs the event loop
jua.run = function()
  os.queueEvent("jua_init")
  running = true
  eventLoop()
end

-- Sets running to false, stopping the event loop ASAP
jua.stop = function()
  running = false
end

-- jua.run with a callback on jua_init
jua.go = function(func)
  if func then
    jua.once("jua_init", function()
      func()
    end)
  end
  jua.run()
end

-- Export jua
return jua