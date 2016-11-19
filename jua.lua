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

local function registerTimed(time, repeating, callback)
  table.insert(timedRegistry, {
    time = time,
    repeating = repeating,
    callback = callback,
    timer = os.startTimer(time)
  })
end

function on(event, callback)
  registerEvent(event, callback)
end

function setInterval(callback, time)
  registerTimed(time, true, callback)
end

function setTimeout(callback, time)
  registerTimed(time, false, callback)
end

local function tick()
  local eargs = {os.pullEventRaw()}
  local event = eargs[1]

  if eventRegistry[event] == nil then
    eventRegistry[event] = {}
  elseif #eventRegistry[event] > 0 then
    for i, v in ipairs(eventRegistry[event]) do
      v(unpack(eargs))
    end
  end

  if event == "timer" then
    local timer = eargs[2]

    for i, v in ipairs(timedRegistry) do
      if v.timer == timer then
        v.callback()

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
  juaRunning = true
  while true do
    if not juaRunning then
      break
    end
    tick()
  end
end

function stop()
  juaRunning = false
end