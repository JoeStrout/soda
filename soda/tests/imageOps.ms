// Testing the Image class and various operations you can do with it.

print "Hello imageOps!"

img = file.loadImage("images/soda-512.png")

print "Pixel at 100,100: " + img.pixel(100,100)
img.setPixel 100,100, "#FFFF00"

sp1 = new Sprite
sp1.image = img
sp1.x = 300; sp1.y = 320
sprites.push sp1

sp2 = new Sprite
sp2.image = img.getImage(0, 256, 256, 256)
sp2.x = 700; sp2.y = 320
sprites.push sp2

sp3 = new sp2
sp3.tint = "#FFFF00FF"
sp3.x = 800
sp3.y = 400
sprites.push sp3

sp4 = new sp2
sp4.tint = "#FFFF0044"
sp4.x = 800
sp4.y = 200
sprites.push sp4


while not key.pressed("escape")
	yield
end while