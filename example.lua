local jua = require("jua")

local timePassed = 0

jua.on("terminate", function()
  print("Recieved terminate event. Ignoring...")
end)

jua.on("mouse_click", function(event, button, x, y)
  print("Mouse clicked at X: "..x.." Y: "..y)
end)

jua.onTimeout(5, function()
  print("The program ran for 5 seconds. Exiting...")
  jua.stop()
end)

jua.onInterval(1, function()
  timePassed = timePassed + 1
  print(timePassed.." seconds have passed.")
end)

jua.run()