// Base64 support.

// Build the base64 lookup table once
idxToChar = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
charToIdx = {}
for i in range(0, idxToChar.len-1)
	charToIdx[idxToChar[i]] = i
end for
//charToIdx["="] = 0  // Safe padding

// Encode a RawData as Base64
toBase64 = function(raw)
	if raw isa string then
		rd = new RawData
		rd.resize string.len*3
		rd.resize rd.setUtf8(0, raw)
		raw = rd
	end if
	rlen = raw.len
	result = ["="] * ceil(rlen/3) * 4
	// Work in 3-byte chunks
	j = 0
	for i in range(0, rlen - 1, 3)
		if i < rlen - 2 then
			d = raw.byte(i) * 65536 + raw.byte(i+1) * 256 + raw.byte(i+2)
			pad = 0
		else if i < rlen - 1 then
			d = raw.byte(i) * 65536 + raw.byte(i+1) * 256
			pad = 1
		else
			d = raw.byte(i) * 65536
			pad = 2
		end if
		if pad == 0 then result[j+3] = idxToChar[d % 64]
		d = floor(d / 64)
		if pad <= 1 then result[j+2] = idxToChar[d % 64]
		d = floor(d / 64)
		if pad <= 2 then result[j+1] = idxToChar[d % 64]
		d = floor(d / 64)
		result[j] = idxToChar[d % 64]
		j += 4
	end for
	return result.join("")	
end function

toRaw = function(b64)
	blen = b64.len
	raw = new RawData
	raw.resize ceil(blen * 3/4)
	j = 0
	i = 0
	trim = 0
	while i < blen
		// Grab next 4 characters, as a 3-byte value
		d = 0
		m = 262144
		while true
			if i >= blen then
				while m >= 1
					trim += 1
					m /= 64
				end while
				break
			end if
			c = b64[i]
			i += 1
			if not charToIdx.hasIndex(c) then continue
			d += charToIdx[c] * m
			if m == 1 then break else m /= 64
		end while
		// Now, store that as 3 bytes
		raw.setByte j+2, d % 256
		d = floor(d / 256)
		raw.setByte j+1, d % 256
		d = floor(d / 256)
		raw.setByte j, d
		j += 3
	end while
	raw.resize raw.len - trim
	return raw
end function

toString = function(b64)
	globals.raw = toRaw(b64)
	return raw.utf8
end function

runUnitTests = function
	print "Unit testing: base64"
	
	errorCount = 0
	assertEqual = function(actual, expected, note)
		if actual != expected then
			print "Unit test failure (" + testing + "): expected " + expected + ", got " + actual
			outer.errorCount = errorCount + 1
		end if
	end function
	
	testing = "toBase64"
	assertEqual toBase64("M"), "TQ=="
	assertEqual toBase64("Ma"), "TWE="
	assertEqual toBase64("Many hands make light work."),
	  "TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu"  
	
	testing = "toString"
	assertEqual toString("TQ=="), "M"
	assertEqual toString("TWE="), "Ma"
	assertEqual toString("TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu"),
	  "Many hands make light work."
	
	if errorCount == 0 then
		print "All tests passed.  Yay!"
	else
		print errorCount + " error" + "s" * (errorCount!=1) + " found."
	end if
	
end function

if globals == locals then runUnitTests
