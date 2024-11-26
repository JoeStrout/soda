// Sierpinski Triangle

average = function(ptA, ptB)
	return [round((ptA[0] + ptB[0])/2), round((ptA[1] + ptB[1])/2)]
end function

drawTriangle = function(ptA, ptB, ptC)
	if abs(ptA[0] - ptB[0]) + abs(ptA[1] - ptB[1]) < 10 then
		gfx.fillPoly [ptA, ptB, ptC], "#FFFF00"
	else
		newA = average(ptA, ptB)
		newB = average(ptB, ptC)
		newC = average(ptC, ptA)
		gfx.fillPoly [newA, newB, newC], "#000088"
		drawTriangle ptA, newA, newC
		drawTriangle newA, ptB, newB
		drawTriangle newC, newB, ptC
	end if
end function

drawTriangle [0,0], [window.width/2, window.height], [window.width, 0]

while not key.pressed("escape") and not key.pressed("space")
	yield
end while
