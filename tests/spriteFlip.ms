import "soda"

spr1 = new Sprite
spr1.image = file.loadImage("assets/images/soda-128.png")
spr1.scale = 2
spr1.x = 480; spr1.y = 440

spr2 = new Sprite
spr2.image = file.loadImage("assets/images/soda-128.png")
spr2.scale = [-2, 2]
spr2.x = 480; spr2.y = 200

display(4).sprites.push spr1
display(4).sprites.push spr2
while true; yield; end while
