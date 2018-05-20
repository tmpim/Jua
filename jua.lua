local juaVersion = "0.0"

juaRunning = false
eventRegistry = {}
timedRegistry = {}

local function registerEvent(event, callback)
  if eventRegistry[event] == nil then
    eventRegistry[event] = {}
  end

  table.insert(eventRegistry[event], callback)
end

local function unregisterEvent(event, callback)
  if eventRegistry[event] == nil then
    return false
  end

  if not callback then
    -- Clear all callbacks
    eventRegistry[event] = {}
    return true
  end

  local callbackList = eventRegistry[event]

  for i = 1, #callbackList do
    if callbackList[i] == callback then
      table.remove(callbackList, i)
      return true
    end
  end

  return false
end

local function registerTimed(time, repeating, callback)
  if repeating then
    callback(true)
  end

  table.insert(timedRegistry, {
    time = time,
    repeating = repeating,
    callback = callback,
    timer = os.startTimer(time)
  })
end

local function unregisterTimed(callback)
  local callbackList = timedRegistry

  if not callback then
    -- Clear all timed callbacks
    timedRegistry = {}
    return true
  end

  for i = 1, #callbackList do
    if callbackList[i] == callback then
      table.remove(callbackList, i)
      return true
    end
  end

  return false
end

local function discoverEvents(event)
    local evs = {}
    for k,v in pairs(eventRegistry) do
        if k == event or string.match(k, event) or event == "*" then
            for i,v2 in ipairs(v) do
                table.insert(evs, v2)
            end
        end
    end

    return evs
end

function on(event, callback)
  registerEvent(event, callback)
end

function off(event, callback)
  unregisterEvent(event, callback)
end

function once(event, callback)
  local callbackWrapper
  
  callbackWrapper = function(...)
    callback(...)
    unregisterEvent(event, callbackWrapper)
  end

  registerEvent(event, callbackWrapper)
end

function setInterval(callback, time)
  registerTimed(time, true, callback)
end

function setTimeout(callback, time)
  registerTimed(time, false, callback)
end

function clearInterval(callback)
  unregisterTimed(callback)
end

clearTimeout = clearInterval

function tick()
  local eargs = {os.pullEventRaw()}
  local event = eargs[1]

  if eventRegistry[event] == nil then
    eventRegistry[event] = {}
  else
    local evs = discoverEvents(event)
    for i, v in ipairs(evs) do
      v(unpack(eargs))
    end
  end

  if event == "timer" then
    local timer = eargs[2]

    for i, v in ipairs(timedRegistry) do
      if v.timer == timer then
        v.callback(not v.repeating or nil)

        if v.repeating then
          v.timer = os.startTimer(v.time)
        else
          table.remove(timedRegistry, i)
        end
      end
    end
  end
end

function run()
  os.queueEvent("init")
  juaRunning = true
  while juaRunning do
    tick()
  end
end

function go(func)
  on("init", func)
  run()
end

function stop()
  juaRunning = false
end

function await(func, ...)
  local args = {...}
  local out
  local finished
  func(function(...)
    out = {...}
    finished = true
  end, unpack(args))
  while not finished do tick() end
  return unpack(out)
end

return {
  on = on,
  off = off,
  once = once,
  setInterval = setInterval,
  setTimeout = setTimeout,
  clearInterval = clearInterval,
  clearTimeout = clearTimeout,
  tick = tick,
  run = run,
  go = go,
  stop = stop,
  await = await
}
