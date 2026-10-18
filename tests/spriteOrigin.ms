import "soda"

// defualt origin: center
spr1 = new Sprite
spr1.image = file.loadImage("assets/images/soda-128.png")
spr1.x = 480; spr1.y = 440

// custom origin: bottom
spr2 = new Sprite
spr2.image = file.loadImage("assets/images/soda-128.png")
spr2.origin = [64, 120]
spr2.x = 480; spr2.y = 200

display(4).sprites.push spr1
display(4).sprites.push spr2

while true
    spr1.rotation -= 4
    spr2.rotation -= 4

    yield
end while