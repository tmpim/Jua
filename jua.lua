local jua = {}

local running = false
local eventRegistry = {}
local suspendedThreads = {}

local function registerEvent(event, func)
  if not eventRegistry[event] then
    eventRegistry[event] = {}
  end

  eventRegistry[event][#eventRegistry + 1] = func
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
  end
end

jua.on = function(event, func)
  registerEvent(event, func)
end

jua.run = function()
  running = true
  mainThread()
end

jua.stop = function()
  running = false
end

return jua
