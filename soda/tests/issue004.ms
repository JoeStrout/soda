// Test from https://github.com/JoeStrout/soda/issues/4

print "Starting test."

fileInFolder = function(folderName, fileName)
	if not file.exists(folderName) then
		print "Folder """ + folderName + """ not found."
		exit
	end if
	return file.child(folderName, fileName)
end function

window.backColor = "#aaaaaa"
window.width = 640
window.height = 480

makeCardSprite = function(cardImg)
  cardSprite = new Sprite
  cardSprite.image = cardImg

  cardSprite.localBounds = new Bounds
  cardSprite.localBounds.width = cardImg.width
  cardSprite.localBounds.height = cardImg.height

  return cardSprite
end function

cardImg = file.loadImage(fileInFolder("images", "soda-128.png"))

cardA = makeCardSprite(cardImg)
sprites.push cardA
cardA.x = 400
cardA.y = 400

isDown = false
wasDown = false

while true
  if key.pressed("q") or key.pressed("escape") then break

  isDown = mouse.button
  if isDown and not wasDown then
    if cardA.contains(mouse) then
      print "Sprite clicked"
    end if
  end if
  wasDown = isDown
  
  yield
end while

print "Test complete!"
