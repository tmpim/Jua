local jua = {}

local running = false
local eventRegistry = {}
local timedRegistry = {}
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
  --TODO: interval registry
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
        timedRegistry[event[2]](unpack(event))
      else
        -- TODO: handle intervals
      end
    end
  end
end

jua.on = registerEvent

jua.setTimeout = registerTimeout

jua.run = function()
  running = true
  mainThread()
end

jua.stop = function()
  running = false
end

return jua
