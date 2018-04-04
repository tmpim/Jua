local jua = {}

local running = false
local eventRegistry = {}
local timedRegistry = {}
local intervalLookup = {}
local intervalRegistry = {}
local suspendedThreads = {}

local function registerEvent(event, func)
  if not eventRegistry[event] then
    eventRegistry[event] = {}
  end

  eventRegistry[event][#eventRegistry + 1] = func
end

local function registerTimeout(func, timeout)
  local timer = os.startTimer(timeout)
  timedRegistry[timer] = func
end

local function registerInterval(func, interval)
  local index = #intervalRegistry + 1
  intervalRegistry[index] = {
    interval = interval,
    func = func
  }

  local timer = os.startTimer(interval)
  intervalLookup[timer] = index
end

local function mainThread()
  while running do
    local event = {coroutine.yield()}
    local eventName = event[1]

    if eventRegistry[eventName] and #eventRegistry[eventName] > 0 then
      for k, v in pairs(eventRegistry[eventName]) do
        local co = coroutine.create(v)

        coroutine.resume(co, unpack(event))

        if coroutine.status(co) == "suspended" then
          suspendedThreads[#suspendedThreads + 1] = co
        end
      end
    end

    if eventName == "timer" then
      if timedRegistry[event[2]] then
        local co = coroutine.create(timedRegistry[event[2]])

        coroutine.resume(co, unpack(event))

        if coroutine.status(co) == "suspended" then
          suspendedThreads[#suspendedThreads + 1] = co
        end
      elseif intervalLookup[event[2]] then
        local index = intervalLookup[event[2]]

        local co = coroutine.create(intervalRegistry[index].func)

        coroutine.resume(co, unpack(event))
        
        if coroutine.status(co) == "suspended" then
          suspendedThreads[#suspendedThreads + 1] = co
        end

        intervalLookup[event[2]] = nil
        local timer = os.startTimer(intervalRegistry[index].interval)
        intervalLookup[timer] = index
      end
    end
  end
end

jua.on = registerEvent

jua.setTimeout = registerTimeout

jua.setInterval = registerInterval

jua.run = function()
  running = true
  mainThread()
end

jua.stop = function()
  running = false
end

return jua
