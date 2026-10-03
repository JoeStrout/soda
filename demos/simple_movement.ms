import "soda"
clear

obj = {}
obj.x = 480
obj.y = 320
obj.update = function
  self.x += key.axis("Horizontal") * 6
  self.y += key.axis("Vertical") * 6
end function
obj.draw = function
  gfx.fillRect self.x-32, self.y-32, 64, 64, "#55f5f5"
end function

while not key.pressed("escape")
  gfx.clear
  obj.update
  obj.draw
  yield
end while

