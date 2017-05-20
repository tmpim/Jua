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
  while juaRunning do
    tick()
  end
end

function stop()
  juaRunning = false
end

return {
  on = on,
  setInterval = setInterval,
  setTimeout = setTimeout,
  run = run,
  stop = stop
}
