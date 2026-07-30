// Draw a scaled-up sprite.  This is supposed to use no interpolation,
// resulting in big chunky pixels, rather than a blurry mess.

import "soda"

sp = new Sprite
sp.image = file.loadImage("assets/images/soda-128.png")
display(4).sprites.push sp
sp.scale = 20
sp.scale = 10

while not key.pressed("escape"); yield; end while
