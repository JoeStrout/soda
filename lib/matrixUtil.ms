// Matrix Utilities.
//
// `Matrix` itself is an intrinsic class, always available in globals; you do
// not need this module to use it.  What this module adds is the convenience
// layer: methods that are entirely definable in terms of the intrinsic API,
// and so are written here in MiniScript rather than in C++.
//
// Importing it pokes those methods into the intrinsic Matrix class, so they
// are available on every matrix, including ones made before the import.
//
// NOTE: in keeping with standard programming convention, but NOT standard math
// convention, we use 0-based indexing.  So the top-left element is 0,0.
//
// Naming convention, inherited from the intrinsic layer: a verb mutates the
// receiver and returns it (`transpose`, `add`, `normalizeRows`); the matching
// past participle returns a new matrix and leaves the receiver alone
// (`transposed`, `plus`, `normalizedRows`).  The copying forms here are all
// literally `clone` plus the in-place version.

// Read an argument that may be given as either a Matrix or a list of lists.
// A file-scope helper, and so private to this module: the wrapper methods
// below reach it through `outer`, but importers never see it on the class.
_asMatrix = function(x)
	if x isa Matrix then return x
	if x isa list then return Matrix.fromList(x)
	return err("Matrix: expected a Matrix or a list, got " + x)
end function


//----------------------------------------------------------------------
// GEMM wrappers.
//
// Every one of these is a single `gemm` call:
//     alpha * op(A) * op(B) + beta * addend   ->   out
// naming its common specializations.  They allocate nothing beyond their
// result, and the in-place forms allocate nothing at all.
//----------------------------------------------------------------------

// A.times(B): matrix product (or scaling, if B is a number) -> new Matrix.
Matrix.times = function(B)
	if B isa number then return self.gemm(null, null, null, false, false, B)
	B = _asMatrix(B)
	if B isa error then return B
	return self.gemm(B)
end function

// A.multiplyBy(B): matrix product (or scaling) in place -> self.
Matrix.multiplyBy = function(B)
	if B isa number then return self.gemm(null, null, self, false, false, B)
	B = _asMatrix(B)
	if B isa error then return B
	return self.gemm(B, null, self)
end function

// A.timesInto(B, out): matrix product written into an existing matrix -> out.
Matrix.timesInto = function(B, out)
	return self.gemm(B, null, out)
end function

// A.transposedTimes(B): Aᵀ·B, without ever forming Aᵀ -> new Matrix.
Matrix.transposedTimes = function(B)
	return self.gemm(B, null, null, true)
end function

// A.timesTransposed(B): A·Bᵀ, without ever forming Bᵀ -> new Matrix.
Matrix.timesTransposed = function(B)
	return self.gemm(B, null, null, false, true)
end function

// A.timesPlus(B, c): A·B + c, one pass; c broadcasts like any addend -> new.
Matrix.timesPlus = function(B, c)
	return self.gemm(B, c)
end function

// A.timesPlusInto(B, c, out): A·B + c, written into an existing matrix -> out.
Matrix.timesPlusInto = function(B, c, out)
	return self.gemm(B, c, out)
end function

// A.plusScaled(C, beta): A + beta*C -> new Matrix.
Matrix.plusScaled = function(C, beta)
	return self.gemm(null, C, null, false, false, 1, beta)
end function

// A.addScaled(C, beta): A += beta*C, in place -> self.
Matrix.addScaled = function(C, beta)
	return self.gemm(null, C, self, false, false, 1, beta)
end function

// C.addProduct(A, B): C += A·B, in place -> self.
Matrix.addProduct = function(A, B)
	A = _asMatrix(A)
	if A isa error then return A
	B = _asMatrix(B)
	if B isa error then return B
	return A.gemm(B, self, self)
end function

// A.transposed -> a new matrix, the transpose of A.
Matrix.transposed = function
	return self.gemm(null, null, null, true)
end function

// A.transpose: transpose in place (reshaping self) -> self.
Matrix.transpose = function
	return self.gemm(null, null, self, true)
end function

// A.clone -> an independent copy of A.
Matrix.clone = function
	return self.gemm(null)
end function

// A.copyFrom(B): overwrite A's contents with B's, resizing as needed -> self.
Matrix.copyFrom = function(B)
	B = _asMatrix(B)
	if B isa error then return B
	return B.gemm(null, null, self)
end function

// A.plus(x) -> new matrix, A + x.  x may be a number, a Matrix, or a list;
// a 1 x n or n x 1 operand broadcasts, as it does everywhere else.
Matrix.plus = function(x)
	return self.gemm(null, x)
end function

// A.add(x): A += x, in place -> self.
Matrix.add = function(x)
	return self.gemm(null, x, self)
end function

// A.minus(x) -> new matrix, A - x.
Matrix.minus = function(x)
	return self.gemm(null, x, null, false, false, 1, -1)
end function

// A.subtract(x): A -= x, in place -> self.
Matrix.subtract = function(x)
	return self.gemm(null, x, self, false, false, 1, -1)
end function

// A.negated -> new matrix, -A.
Matrix.negated = function
	return self.gemm(null, null, null, false, false, -1)
end function

// A.negate: negate in place -> self.
Matrix.negate = function
	return self.gemm(null, null, self, false, false, -1)
end function


//----------------------------------------------------------------------
// Copying forms of the in-place elementwise operations.
//
// Each is clone-then-mutate: two passes instead of one, which is the right
// trade, since both forms exist precisely so that hot-loop code can use the
// in-place one and everything else can use the convenient one.
//----------------------------------------------------------------------

// Hadamard (elementwise) product -> new matrix.
Matrix.elemTimes = function(x)
	c = self.clone
	if c isa error then return c
	return c.elemMultiplyBy(x)
end function

// Elementwise quotient -> new matrix.
Matrix.elemOver = function(x)
	c = self.clone
	if c isa error then return c
	return c.elemDivideBy(x)
end function

// Each element raised to the k'th power -> new matrix.
Matrix.powed = function(k)
	c = self.clone
	if c isa error then return c
	return c.pow(k)
end function

Matrix.absed = function
	c = self.clone
	if c isa error then return c
	return c.abs
end function

Matrix.sqrted = function
	c = self.clone
	if c isa error then return c
	return c.sqrt
end function

Matrix.rounded = function(places = 0)
	c = self.clone
	if c isa error then return c
	return c.round(places)
end function

// Each element clamped to [lo, hi]; a null bound means unbounded -> new matrix.
Matrix.clamped = function(lo, hi)
	c = self.clone
	if c isa error then return c
	return c.clamp(lo, hi)
end function

// f applied to each element, in row-major order -> new matrix.
Matrix.applied = function(f)
	c = self.clone
	if c isa error then return c
	return c.apply(@f)
end function

// f(element, arg1) applied to each element -> new matrix.
Matrix.applied1 = function(f, arg1)
	c = self.clone
	if c isa error then return c
	return c.apply1(@f, arg1)
end function

Matrix.sigmoided = function
	c = self.clone
	if c isa error then return c
	return c.sigmoid
end function

Matrix.tanhed = function
	c = self.clone
	if c isa error then return c
	return c.tanh
end function

Matrix.softmaxed = function(axis = 1)
	c = self.clone
	if c isa error then return c
	return c.softmax(axis)
end function

Matrix.reshaped = function(rows, columns)
	c = self.clone
	if c isa error then return c
	return c.reshape(rows, columns)
end function


//----------------------------------------------------------------------
// Shape and slicing.
//----------------------------------------------------------------------

// True if m2 has exactly our shape.  (m.size, a list of extents, is intrinsic.)
Matrix.sameSize = function(m2)
	return self.rows == m2.rows and self.columns == m2.columns
end function

// [0, 1, ... rows-1], for iterating.  Not cached: matrices can be resized.
Matrix.rowRange = function
	if self.rows == 0 then return []
	return range(0, self.rows - 1)
end function

Matrix.colRange = function
	if self.columns == 0 then return []
	return range(0, self.columns - 1)
end function

// One row, as a 1 x columns Matrix.  (For a plain list, use getRow.)
Matrix.row = function(r)
	return self.getSub(r, 0, 1)
end function

// One column, as a rows x 1 Matrix.  (For a plain list, use getColumn.)
Matrix.column = function(c)
	return self.getSub(0, c, null, 1)
end function

// One column, as a 1 x rows Matrix.
Matrix.columnAsRow = function(c)
	sub = self.getSub(0, c, null, 1)
	if sub isa error then return sub
	return sub.transpose		// in place: `sub` is ours, freshly made
end function

// The whole matrix as a list of row lists.
Matrix.toList = function
	result = []
	for r in self.rowRange
		result.push self.getRow(r)
	end for
	return result
end function

// Reshape to a single row, in place -> self.
Matrix.flatten = function
	return self.reshape(1, null)
end function

// A new 1 x n matrix holding our elements in row-major order.
Matrix.flattened = function
	c = self.clone
	if c isa error then return c
	return c.flatten
end function

// The sum of the main diagonal.  Defined for non-square matrices too, over
// min(rows, columns) elements, as numpy's trace is.
Matrix.trace = function
	n = self.rows
	if self.columns < n then n = self.columns
	total = 0
	for i in range(0, n-1)
		total = total + self.getElem(i, i)
	end for
	if n == 0 then return 0
	return total
end function


//----------------------------------------------------------------------
// Growing and concatenating.
//
// `addRow`/`addRows`/`appendRows` grow in place, so against reserved capacity
// they allocate nothing; `vcat`/`hcat` always allocate a fresh matrix.
//----------------------------------------------------------------------

// Append one row, given as a list of numbers (or a single number, broadcast
// across the row).  Returns the new row's index -- so a spawn reads
// `i = pos.addRow([x, y])`.
Matrix.addRow = function(values)
	// A matrix with no shape at all adopts the width of its first row.
	if self.rows == 0 and self.columns == 0 and values isa list then
		e = self.resize(0, values.len)
		if e isa error then return e
	end if
	i = self.rows
	e = self.resize(i + 1, null)
	if e isa error then return e
	e = self.setRow(i, values)
	if e isa error then return e
	return i
end function

// Append rows: `n` blank (zero) rows if given a number, or the rows of a
// Matrix or list of lists.  Returns the first new row's index.
Matrix.addRows = function(rowsOrCount)
	i = self.rows
	if rowsOrCount isa number then
		e = self.resize(i + rowsOrCount, null)
		if e isa error then return e
		return i
	end if
	e = self.appendRows(rowsOrCount)
	if e isa error then return e
	return i
end function

// Append all the rows of m2 (a Matrix or list of lists) -> self.
Matrix.appendRows = function(m2)
	m2 = _asMatrix(m2)
	if m2 isa error then return m2
	if self.rows == 0 then
		cols = m2.columns
	else
		cols = self.columns
	end if
	if m2.columns != cols then
		return err("Matrix.appendRows: column counts do not match (" +
		  m2.columns + " vs. " + cols + ")")
	end if
	i = self.rows
	e = self.resize(i + m2.rows, cols)
	if e isa error then return e
	e = self.setSub(i, 0, m2)
	if e isa error then return e
	return self
end function

// Matrix.vcat(matrices): stack a *list* of matrices vertically -> new Matrix.
// A list rather than a pair because pairwise chaining (a.vcat(b).vcat(c))
// recopies the accumulated prefix at every step; this sizes the result once.
Matrix.vcat = function(matrices)
	blocks = []
	rows = 0
	cols = 0
	for m in matrices
		m = _asMatrix(m)
		if m isa error then return m
		if not blocks then
			cols = m.columns
		else if m.columns != cols then
			return err("Matrix.vcat: every matrix must have the same " +
			  "column count (" + m.columns + " vs. " + cols + ")")
		end if
		rows = rows + m.rows
		blocks.push m
	end for
	out = Matrix.ofSize(rows, cols)
	if out isa error then return out
	r = 0
	for m in blocks
		out.setSub r, 0, m
		r = r + m.rows
	end for
	return out
end function

// Matrix.hcat(matrices): the same, side by side.  Note that this is inherently
// a full copy: row-major storage means no column is contiguous.
Matrix.hcat = function(matrices)
	blocks = []
	rows = 0
	cols = 0
	for m in matrices
		m = _asMatrix(m)
		if m isa error then return m
		if not blocks then
			rows = m.rows
		else if m.rows != rows then
			return err("Matrix.hcat: every matrix must have the same " +
			  "row count (" + m.rows + " vs. " + rows + ")")
		end if
		cols = cols + m.columns
		blocks.push m
	end for
	out = Matrix.ofSize(rows, cols)
	if out isa error then return out
	c = 0
	for m in blocks
		out.setSub 0, c, m
		c = c + m.columns
	end for
	return out
end function

// Matrix.fromFlatList(flatList, rows, columns): a flat list of numbers, laid
// out in row-major order.  Exactly one of rows/columns may be null and is
// then inferred; both null gives a 1 x n row vector.
Matrix.fromFlatList = function(flatList, rows, columns)
	m = Matrix.fromList(flatList)
	if m isa error then return m
	if rows == null and columns == null then return m
	return m.reshape(rows, columns)
end function


//----------------------------------------------------------------------
// Reductions and per-row vector math.
//
// axis null -> a number; axis 0 -> 1 x n (down the columns);
// axis 1 -> m x 1 (across the rows).  Same axis meaning as numpy.
//----------------------------------------------------------------------

// The mean, over the whole matrix or along one axis.
Matrix.mean = function(axis)
	s = self.sum(axis)
	if s isa error then return s
	if axis == null then
		n = self.rows * self.columns
		if n == 0 then return 0
		return s / n
	end if
	if axis == 0 then n = self.rows else n = self.columns
	if n == 0 then return s
	return s.elemMultiplyBy(1 / n)
end function

// Add all the rows together -> 1 x columns.
Matrix.sumRows = function
	return self.sum(0)
end function

// Add all the columns together -> rows x 1.
Matrix.sumColumns = function
	return self.sum(1)
end function

// The Euclidean length of each row -> rows x 1.
Matrix.rowLengths = function
	s = self.sumOfSquares(1)
	if s isa error then return s
	return s.sqrt
end function

// Scale each row to unit length, in place -> self.
Matrix.normalizeRows = function
	lengths = self.rowLengths
	if lengths isa error then return lengths
	return self.elemDivideBy(lengths)
end function

Matrix.normalizedRows = function
	c = self.clone
	if c isa error then return c
	return c.normalizeRows
end function

// The dot product of each row with the corresponding row of m2 -> rows x 1.
// m2 may have one row, which is then dotted with every row of self.
Matrix.rowDot = function(m2)
	p = self.elemTimes(m2)
	if p isa error then return p
	return p.sum(1)
end function


//----------------------------------------------------------------------
// Neural network helpers.
//
// The derivatives are expressed in terms of the layer's OUTPUT, not its
// input, so a layer caches only what it already produced.
//----------------------------------------------------------------------

// ReLU, in place -> self.
Matrix.relu = function
	return self.clamp(0, null)
end function

Matrix.relued = function
	c = self.clone
	if c isa error then return c
	return c.relu
end function

// relu'(y) = (y > 0) -> new matrix of 0s and 1s.
Matrix.reluDeriv = function
	c = self.clone
	if c isa error then return c
	return c.greaterThan(0)
end function

// sigmoid'(y) = y * (1 - y), where y is the sigmoid's output.
Matrix.sigmoidDeriv = function
	d = self.negated			// -y
	if d isa error then return d
	d.add 1						// 1 - y
	return d.elemMultiplyBy(self)
end function

// tanh'(y) = 1 - y², where y is the tanh's output.
Matrix.tanhDeriv = function
	d = self.powed(2)			// y²
	if d isa error then return d
	d.negate					// -y²
	return d.add(1)				// 1 - y²
end function

// The gradient of softmaxCrossEntropy with respect to the logits, which is
// exactly yHat - targets.  `self` is the *probabilities* (softmax output),
// i.e. what softmaxCrossEntropy wrote into its outProbs argument.
Matrix.softmaxCrossEntropyGrad = function(targets)
	return self.minus(targets)
end function


//----------------------------------------------------------------------
// Convolution helpers.
//
// The intrinsic m.convolve(kernel, out) writes only where the whole kernel
// fits, and leaves the border -- floor(k/2) rows/columns before the data and
// the rest after it -- alone.  So edge handling is done by keeping that
// border around the data and filling it before each convolve.  That is what
// refreshBorder is for.
//----------------------------------------------------------------------

// Scratch for refreshBorder's row and column copies.  Reused (getSub resizes
// it, keeping capacity) so refreshing a border every frame makes no garbage.
_band = Matrix.ofSize(0, 0)

// Fold an index that has run off either end of 0..n-1 back into range.
_borderIndex = function(t, n, mode)
	if mode == "wrap" then
		t = t % n
		if t < 0 then t += n
		return t
	else if mode == "nearest" then
		if t < 0 then return 0
		if t >= n then return n - 1
		return t
	else if mode == "reflect" then      // d c b a | a b c d | d c b a
		t = t % (2*n)
		if t < 0 then t += 2*n
		if t >= n then t = 2*n - 1 - t
		return t
	else if mode == "mirror" then       // d c b | a b c d | c b a
		if n == 1 then return 0
		t = t % (2*n - 2)
		if t < 0 then t += 2*n - 2
		if t >= n then t = 2*n - 2 - t
		return t
	end if
	return null
end function

// m.refreshBorder(kernel, mode=0): fill the border that m.convolve(kernel)
// leaves unwritten, from the interior, in place -> self.
//
// Only the kernel's size is used (it may be a Matrix or a list), so the
// border matches convolve's exactly, even-sized kernels included.  mode is:
//   a number   every border element is that constant (0 for zero-padding)
//   "wrap"     from the opposite edge -- a torus
//   "nearest"  the nearest edge element, repeated
//   "reflect"  mirrored, repeating the edge element (d c b a | a b c d)
//   "mirror"   mirrored about the edge element     (d c b | a b c d)
// The names are scipy.ndimage's.  Corners come out right for every mode:
// rows are filled first, then whole columns including the new rows.
Matrix.refreshBorder = function(kernel, mode=0)
	if kernel isa Matrix then
		kh = kernel.rows; kw = kernel.columns
	else if kernel isa list and kernel.len > 0 and kernel[0] isa list then
		kh = kernel.len; kw = kernel[0].len
	else if kernel isa list then
		kh = 1; kw = kernel.len
	else
		return err("Matrix.refreshBorder: kernel must be a Matrix or a list")
	end if
	top = floor(kh / 2); left = floor(kw / 2)
	h = self.rows - kh + 1; w = self.columns - kw + 1    // the interior
	if h < 1 or w < 1 then return err("Matrix.refreshBorder: kernel is larger than the matrix")

	if mode isa number then
		i = 0
		while i < top; self.setRow i, mode; i += 1; end while
		i = top + h
		while i < self.rows; self.setRow i, mode; i += 1; end while
		j = 0
		while j < left; self.setColumn j, mode; j += 1; end while
		j = left + w
		while j < self.columns; self.setColumn j, mode; j += 1; end while
		return self
	end if
	if _borderIndex(0, 1, mode) == null then
		return err("Matrix.refreshBorder: unknown mode " + mode)
	end if

	// Border rows, across the interior columns only.
	i = 0
	while i < self.rows
		if i == top then i = top + h    // skip the interior
		if i >= self.rows then break
		src = top + _borderIndex(i - top, h, mode)
		self.getSub src, left, 1, w, _band
		self.setSub i, left, _band
		i += 1
	end while
	// Border columns, full height, so the corners come from the rows above.
	j = 0
	while j < self.columns
		if j == left then j = left + w
		if j >= self.columns then break
		src = left + _borderIndex(j - left, w, mode)
		self.getSub 0, src, self.rows, 1, _band
		self.setSub 0, j, _band
		j += 1
	end while
	return self
end function

// m.flip: reverse the element order in both dimensions (a 180-degree
// rotation), in place -> self.  convolve correlates; flipping the kernel first
// gives true convolution, as scipy.signal.convolve2d or MATLAB conv2 compute.
Matrix.flip = function
	i = 0; j = self.rows - 1
	while i < j; self.swapRows i, j; i += 1; j -= 1; end while
	i = 0; j = self.columns - 1
	while i < j; self.swapColumns i, j; i += 1; j -= 1; end while
	return self
end function

// m.flipped -> new matrix, m reversed in both dimensions.
Matrix.flipped = function
	return self.clone.flip
end function


//----------------------------------------------------------------------
// Display.
//----------------------------------------------------------------------

// How much of a matrix `str` shows before it starts eliding.
Matrix.maxStrRows = 6
Matrix.maxStrColumns = 8

// Print the whole matrix, one row per line.
Matrix.print = function(fieldWidth = 10, precision = null)
	print self.format(fieldWidth, precision)
end function

// A short description: the dimensions, plus a corner of the elements.  It is
// a method rather than an override of the global str(m) because MiniScript
// has no hook for a map to define its own string form.
Matrix.str = function
	desc = self.rows + "x" + self.columns + " Matrix"
	if self.rows == 0 or self.columns == 0 then return desc
	r = self.rows
	c = self.columns
	if r > self.maxStrRows then r = self.maxStrRows
	if c > self.maxStrColumns then c = self.maxStrColumns
	sub = self
	if r < self.rows or c < self.columns then sub = self.getSub(0, 0, r, c)
	if sub isa error then return desc
	lines = sub.format.split(char(10))
	if c < self.columns then
		for i in lines.indexes
			lines[i] = lines[i] + "   ..."
		end for
	end if
	if r < self.rows then lines.push "   ..."
	return desc + ":" + char(10) + lines.join(char(10))
end function


//----------------------------------------------------------------------
// Unit tests.
//----------------------------------------------------------------------

runUnitTests = function
	print "Unit testing: matrixUtil"

	errorCount = 0
	assertEqual = function(actual, expected, note)
		if actual isa Matrix then actual = actual.toList
		if actual != expected then
			print "Unit test failure (" + note + "): expected " + expected +
			  ", got " + actual + " at " + stackTrace[1]
			outer.errorCount = errorCount + 1
		end if
	end function

	assert = function(shouldBeTrue, note)
		if shouldBeTrue then return
		print "Unit test failure (" + note + ") at " + stackTrace[1]
		outer.errorCount = errorCount + 1
	end function

	m = Matrix.fromList([[1,2,3], [4,5,6]])

	// gemm wrappers
	assertEqual m.clone, [[1,2,3], [4,5,6]], "clone"
	assert not refEquals(m.clone, m), "clone is a copy"
	assertEqual m.transposed, [[1,4], [2,5], [3,6]], "transposed"
	assertEqual m, [[1,2,3], [4,5,6]], "transposed leaves self alone"
	assertEqual m.clone.transpose, [[1,4], [2,5], [3,6]], "transpose"
	assertEqual m.times(10), [[10,20,30], [40,50,60]], "times scalar"
	assertEqual m.times(m.transposed), [[14,32], [32,77]], "times matrix"
	assertEqual m.times([[1,0],[0,1],[0,0]]), [[1,2], [4,5]], "times list"
	assertEqual m.transposedTimes(m), [[17,22,27], [22,29,36], [27,36,45]],
	  "transposedTimes"
	assertEqual m.timesTransposed(m), [[14,32], [32,77]], "timesTransposed"
	assertEqual m.timesPlus(m.transposed, 1), [[15,33], [33,78]], "timesPlus"
	assertEqual m.plus(10), [[11,12,13], [14,15,16]], "plus scalar"
	assertEqual m.plus([[10,0,0], [0,0,100]]), [[11,2,3], [4,5,106]], "plus list"
	assertEqual m.plus([[10,20,30]]), [[11,22,33], [14,25,36]], "plus row vector"
	assertEqual m.minus(1), [[0,1,2], [3,4,5]], "minus"
	assertEqual m.negated, [[-1,-2,-3], [-4,-5,-6]], "negated"
	assertEqual m, [[1,2,3], [4,5,6]], "copying forms leave self alone"

	m2 = m.clone
	assertEqual m2.add(1), [[2,3,4], [5,6,7]], "add"
	assertEqual m2.subtract(1), [[1,2,3], [4,5,6]], "subtract"
	assertEqual m2.negate, [[-1,-2,-3], [-4,-5,-6]], "negate"
	assertEqual m2.multiplyBy(-1), [[1,2,3], [4,5,6]], "multiplyBy scalar"
	assertEqual m2.addScaled([[1,1,1],[1,1,1]], 10), [[11,12,13], [14,15,16]],
	  "addScaled"
	assertEqual m2.copyFrom(m), [[1,2,3], [4,5,6]], "copyFrom"
	assert refEquals(m2.copyFrom(m), m2), "copyFrom returns self"

	acc = Matrix.ofSize(2, 2)
	assertEqual acc.addProduct([[1,2],[3,4]], [[1,0],[0,1]]), [[1,2], [3,4]],
	  "addProduct"
	out = Matrix.ofSize(0,0)
	assertEqual m.timesInto(m.transposed, out), [[14,32], [32,77]], "timesInto"
	assert refEquals(m.timesInto(m.transposed, out), out), "timesInto returns out"

	// elementwise copying forms
	assertEqual m.elemTimes(m), [[1,4,9], [16,25,36]], "elemTimes"
	assertEqual m.elemOver(m), [[1,1,1], [1,1,1]], "elemOver"
	assertEqual m.powed(2), [[1,4,9], [16,25,36]], "powed"
	assertEqual m.negated.absed, [[1,2,3], [4,5,6]], "absed"
	assertEqual m.powed(2).sqrted, [[1,2,3], [4,5,6]], "sqrted"
	assertEqual m.times(0.5).rounded, [[1,1,2], [2,3,3]], "rounded"
	assertEqual m.clamped(2, 5), [[2,2,3], [4,5,5]], "clamped"
	assertEqual m.clamped(0, null), [[1,2,3], [4,5,6]], "clamped null hi"
	double = function(x); return x*2; end function
	assertEqual m.applied(@double), [[2,4,6], [8,10,12]], "applied"
	addUp = function(x, k); return x + k; end function
	assertEqual m.applied1(@addUp, 100), [[101,102,103], [104,105,106]], "applied1"
	assertEqual m, [[1,2,3], [4,5,6]], "elementwise copies leave self alone"

	// shape and slicing
	assert m.sameSize(m.clone), "sameSize"
	assert not m.sameSize(m.transposed), "not sameSize"
	assertEqual m.rowRange, [0,1], "rowRange"
	assertEqual m.colRange, [0,1,2], "colRange"
	assertEqual Matrix.ofSize(0,0).rowRange, [], "rowRange when empty"
	assertEqual m.row(1), [[4,5,6]], "row"
	assertEqual m.column(2), [[3], [6]], "column"
	assertEqual m.columnAsRow(2), [[3,6]], "columnAsRow"
	assertEqual m.toList, [[1,2,3], [4,5,6]], "toList"
	assertEqual m.flattened, [[1,2,3,4,5,6]], "flattened"
	assertEqual m.reshaped(3, 2), [[1,2], [3,4], [5,6]], "reshaped"
	assertEqual m.trace, 6, "trace"
	assertEqual Matrix.identity(4).trace, 4, "trace of identity"

	// growing and concatenating
	pool = Matrix.ofSize(0, 2)
	assertEqual pool.addRow([1, 2]), 0, "addRow returns the index"
	assertEqual pool.addRow([3, 4]), 1, "addRow again"
	assertEqual pool, [[1,2], [3,4]], "addRow contents"
	assertEqual pool.addRows(1), 2, "addRows count"
	assertEqual pool, [[1,2], [3,4], [0,0]], "addRows blank contents"
	assertEqual pool.appendRows([[5,6]]), [[1,2], [3,4], [0,0], [5,6]],
	  "appendRows"
	fresh = Matrix.ofSize(0,0)
	assertEqual fresh.addRow([7,8,9]), 0, "addRow adopts the width"
	assertEqual fresh, [[7,8,9]], "addRow adopted contents"
	assertEqual Matrix.vcat([m, m]), [[1,2,3], [4,5,6], [1,2,3], [4,5,6]], "vcat"
	assertEqual Matrix.hcat([m, m]), [[1,2,3,1,2,3], [4,5,6,4,5,6]], "hcat"
	assert Matrix.vcat([m, m.transposed]) isa error, "vcat shape mismatch"
	assert Matrix.hcat([m, m.transposed]) isa error, "hcat shape mismatch"
	assertEqual Matrix.fromFlatList([1,2,3,4,5,6], 2), [[1,2,3], [4,5,6]],
	  "fromFlatList"
	assertEqual Matrix.fromFlatList([1,2,3]), [[1,2,3]], "fromFlatList default"

	// reductions and row math
	assertEqual m.mean, 3.5, "mean"
	assertEqual m.mean(0), [[2.5, 3.5, 4.5]], "mean axis 0"
	assertEqual m.mean(1), [[2], [5]], "mean axis 1"
	assertEqual m.sumRows, [[5,7,9]], "sumRows"
	assertEqual m.sumColumns, [[6], [15]], "sumColumns"
	assertEqual Matrix.fromList([[3,4], [6,8]]).rowLengths, [[5], [10]],
	  "rowLengths"
	assertEqual Matrix.fromList([[3,4], [6,8]]).normalizedRows,
	  [[0.6, 0.8], [0.6, 0.8]], "normalizedRows"
	assertEqual m.rowDot(m), [[14], [77]], "rowDot"
	assertEqual m.rowDot([[1,0,0]]), [[1], [4]], "rowDot broadcast"

	// nn helpers
	assertEqual Matrix.fromList([[-1, 0, 2]]).relued, [[0, 0, 2]], "relued"
	assertEqual Matrix.fromList([[-1, 0, 2]]).reluDeriv, [[0, 0, 1]], "reluDeriv"
	assertEqual Matrix.fromList([[0.5]]).sigmoidDeriv, [[0.25]], "sigmoidDeriv"
	assertEqual Matrix.fromList([[0.5]]).tanhDeriv, [[0.75]], "tanhDeriv"
	assertEqual Matrix.fromList([[1, 0]]).softmaxCrossEntropyGrad([[0.75, 0.25]]),
	  [[0.25, -0.25]], "softmaxCrossEntropyGrad"

	// convolution helpers (the edge modes are checked against numpy.pad and
	// scipy in matrix_numpy_test.ms)
	assertEqual Matrix.fromList([[1,2,3],[4,5,6]]).flipped, [[6,5,4],[3,2,1]], "flipped"
	assertEqual Matrix.fromList([[1,2,3]]).flipped, [[3,2,1]], "flipped row"
	fb = Matrix.fromList([[9,9,9,9],[9,1,2,9],[9,9,9,9]])
	assertEqual fb.refreshBorder([[0,0,0],[0,1,0],[0,0,0]], "wrap"),
	  [[2,1,2,1],[2,1,2,1],[2,1,2,1]], "refreshBorder wrap, list-of-lists kernel"
	fb = Matrix.fromList([[9,1,2,9]])
	assertEqual fb.refreshBorder([0,1,0], "nearest"), [[1,1,2,2]], "refreshBorder, flat-list kernel"
	assertEqual fb.refreshBorder([0,1,0]), [[0,1,2,0]], "refreshBorder defaults to zeros"
	assert fb.refreshBorder([0,1,0], "bogus") isa error, "an unknown mode is an error"
	assert fb.refreshBorder([[1],[1]]) isa error, "a kernel taller than the matrix is an error"
	// convolve correlates; a flipped kernel gives true convolution
	assertEqual Matrix.fromList([[1,2,3]]).convolve([1,0,0]), [[0, 1, 0]], "convolve correlates"
	assertEqual Matrix.fromList([[1,2,3]]).convolve(Matrix.fromList([[1,0,0]]).flipped),
	  [[0, 3, 0]], "convolve with a flipped kernel"

	// display
	assert m.str.indexOf("2x3 Matrix") == 0, "str names the dimensions"
	big = Matrix.ofSize(20, 20)
	assert big.str.indexOf("...") != null, "str elides a big matrix"
	assert Matrix.ofSize(0,0).str == "0x0 Matrix", "str of an empty matrix"

	// errors come back as values, not as crashes
	assert m.times(m) isa error, "incompatible product is an error value"
	assert m.appendRows([[1,2]]) isa error, "appendRows mismatch is an error"

	if errorCount == 0 then
		print "All tests passed.  Matrices rock!"
	else
		print errorCount + " error" + "s" * (errorCount!=1) + " found."
	end if
end function

if globals == locals then runUnitTests
