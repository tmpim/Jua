local jua = require("jua")

-- Local state to store seconds passed
local timePassed = 0

-- Register an event for termination, and don't terminate
jua.on("terminate", function()
  print("Recieved terminate event. Ignoring...")
end)

-- Register an event for mouse_click events and print them to the screen
jua.on("mouse_click", function(event, button, x, y)
  print("Mouse clicked at X: "..x.." Y: "..y)
end)

-- After 15 seconds have passed, print to the screen and stop jua
jua.onTimeout(15, function()
  print("The program ran for 15 seconds. Exiting...")
  jua.stop()
end)

-- After 5 seconds have passed, print to the screen
jua.onTimeout(5, function()
  print("The program will exit in 10 seconds.")
end)

-- Every 1 second, print the time passed to the screen
jua.onInterval(1, function()
  timePassed = timePassed + 1
  print(timePassed.." seconds have passed.")
end)

-- Create a promise that resolves after 1 second
jua.promise(function(resolve, reject)
  jua.onTimeout(1, function()
    resolve("Promise resolved after 1 second!")
  end)
end)
  .done(function(s) print(s) end)

-- Create a promise that rejects after 2 seconds
jua.promise(function(resolve, reject)
  jua.onTimeout(2, function()
    reject("Promise rejected after 2 seconds!")
  end)
end)
  .fail(function(s) print(s) end)

-- Start jua with a callback (jua.run without callback)
jua.go(function()
  print("Hello from Jua! Click on the screen or press Ctrl+T to test events...")
end)