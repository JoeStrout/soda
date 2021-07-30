// Soda test!

sp = {"x":0, "y":200}
sprites.push sp
while true
	sp.x = sp.x + 3
	if sp.x > 960 then sp.x = 0
	wait 0.01
end while
