local _M = {}

local function pr(...)
	-- uncomment the following line to see the emited code while compiling
	-- print(...)
	tex.print(...)
end

-- array part -> collected header fields
-- max: max set bit
_M.coll = {max=0}

-- set -> which rows should be skipped
-- map -> mapping of row to row in table because some might be skipped
_M.sk = {set={}, map={}}

-- sadly these settings must be known during collection.
-- These also must be the same for drawTab and drawTikz => set globally not as function argument of the draw functions
-- amount of columns in the table
_M.cols = 32*2
-- column scale
_M.scale = 1
assert(_M.cols/_M.scale == _M.cols//_M.scale, "invalid scale/cols used. cols must be a multiple of scale")

-- reset all currently collected state and defaults:
-- scale: scaling (default: 1)
-- cols: amount of columns (default: 32), must be multiple of scale
function _M.reset(cols, scale)
	_M.coll = {max=0}
	_M.sk = {set={}, map={}}
	_M.scale = scale or 1
	_M.cols = cols or 32
	assert(_M.cols/_M.scale == _M.cols//_M.scale, "invalid scale/cols used. cols must be a multiple of scale")
	pr([[\ignorespaces]])
end

-- add header field. Arguments:
-- - from: byte where to start this field
-- - to: byte where to end this field
-- - node: name of the node created by tikz (for further referencing)
-- - c1: node content code to typeset in the field
-- - c2: node content code for field if it spans multiple rows
-- - c3: node content code for field if it spans multiple rows
function _M.collect(from, to, node, c1,c2,c3)
	-- "sort" from and to arguments
	if from > to then
		local tmp = from
		from      = to
		to        = tmp
	end
	table.insert(_M.coll, {
		from = from,
		to   = to,
		node = node,
		c1   = c1,
		c2   = c2,
		c3   = c3,
		line = tex.inputlineno
	})
	if to > _M.coll.max then _M.coll.max = to end
	pr([[\ignorespaces]])
end

-- skip rows between from and to
function _M.skip(from, to)
	from = (from) // _M.cols +1
	to = (to) // _M.cols +1
	for i=from,to do
		_M.sk.set[i] = true
	end
	pr([[\ignorespaces]])
end

local function tab(rows, skipped_rows, mapping, hide_lengths)
	pr([[\setlength{\tabcolsep}{\packetcolsep}]])
	pr(string.format([[\begin{NiceTabular}{*{%d}{c}}[]], _M.cols//_M.scale))
	pr([[code-before = {]])
	pr([[\tikz{]])
	if not hide_lengths then
		-- draw the alternating color pattern
		for c=1,_M.cols//_M.scale do
			-- number of the end-row
			local e = rows-skipped_rows+1
			-- if c > _M.coll.max % _M.cols+1 then e = e-1 end
			if c % 2 == 1 then
				pr(string.format([[\fill[black!05] (row-%d -| col-%d) -- (row-%d -| col-%d) -- (row-%d -| col-%d) -- (row-%d -| col-%d) -- cycle;]], 1,c, e,c, e,c+1, 1,c+1))
			else
				pr(string.format([[\fill[black!10] (row-%d -| col-%d) -- (row-%d -| col-%d) -- (row-%d -| col-%d) -- (row-%d -| col-%d) -- cycle;]], 1,c, e,c, e,c+1, 1,c+1))
			end
		end
	end
	pr("}},")
	pr([[first-col,first-row]])
	pr("]")

	-- print the bit numbers in the header
	for c=0,_M.cols-1,_M.scale do
		if not hide_lengths then
			pr(string.format([[& \parbox{1em}{\centering \scriptsize %d }]], c))
		else
			pr(string.format([[& \parbox{1em}{\phantom{\centering \scriptsize %d }}]], c))
		end
	end
	pr([[\\]])
	-- print the byte offsets at the left side
	for r=1,rows+1 do
		-- check if row shall actually be shown (or is collapsed)
		if mapping[r] then
			if not hide_lengths then
				pr(string.format(
					-- TODO maybe use siunitx for this?
					[[\footnotesize %dB\\]],
					(r-1)*(_M.cols/8) -- -1 for lua index and -1 to skip the header with the indices
				))
			else
				pr([[\phantom{\footnotesize 0B}\\]])
			end
		end
	end

	pr([[\end{NiceTabular}]])
end

-- draw the actual header -- the nicematrix part
function _M.drawTab(hide_lengths)
	-- create a mapping row -> row in table to implement the skipping of specific rows
	local offset = 0
	for c=1,_M.coll.max // _M.cols + 1 do
		if _M.sk.set[c] then
			offset = offset - 1
		else
			_M.sk.map[c] = c + offset
		end
	end

	-- calculate the amount of rows present and the amount os skipped rows
	local rows = _M.coll.max // _M.cols + 1
	local skipped_rows = 0
	for _,_ in pairs(_M.sk.set) do
		skipped_rows = skipped_rows + 1
	end
	tab(rows, skipped_rows, _M.sk.map, hide_lengths)
end

local function draw(e)
	-- calculate the mapped start/end row/col
	local st = {row = _M.sk.map[e.from // _M.cols+1], col = (e.from % _M.cols) // _M.scale + 1}
	local en = {row = _M.sk.map[e.to   // _M.cols+1], col = (e.to   % _M.cols) // _M.scale + 1}
	if not st.row or not en.row then
		-- start and/or end is not mapped -> skip this field and issue a warning
		pr(([[\PackageWarning{packetprinting}{start and/or end of field collected from line %d is collapsed -> cannot draw that field -> skip that field}]]):format(e.line))
		return
	end
	-- draw the fitting node
	if st.row ~= en.row then
		-- spans only part of a row
		pr(string.format(
			[[\node[inner sep=0pt,fit=(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)] (%s) {};]],
			st.row,1,
			en.row+1,(_M.cols//_M.scale)+1,
			e.node
		))
	else
		-- spans multiple rows -> fit node until last column
		pr(string.format(
			[[\node[inner sep=0pt,fit=(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)] (%s) {};]],
			st.row,st.col,
			en.row+1,en.col+1,
			e.node
		))
	end

	-- different cases for drawing the fields
	if st.row == en.row then
		-- field only spans (part of) a row
		pr(string.format(
			[[\draw (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- cycle;]],
			st.row,st.col,
			en.row,en.col+1,
			en.row+1,en.col+1,
			st.row+1,st.col
		))
		if e.c1 and e.c1 ~= "" then
			pr(string.format(
				[[\draw let \p1 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$), \p2 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$) in ($(\p1)!0.5!(\p2)$) node {%s};]],
				st.row,st.col,
				st.row+1,st.col,
				en.row,en.col+1,
				en.row+1,en.col+1,
				e.c1
			))
		end
	elseif st.row == en.row -1 and st.col > en.col then
		-- field spans two rows
		pr(string.format(
			[[\draw (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- cycle;]],
			st.row+1,(_M.cols//_M.scale)+1,
			st.row+1,st.col,
			st.row,st.col,
			st.row,(_M.cols//_M.scale)+1
		))
		pr(string.format(
			[[\draw (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- cycle;]],
			en.row+1,1,
			en.row+1,en.col+1,
			en.row,en.col+1,
			en.row,1
		))
		if e.c1 and e.c1 ~= "" then
			pr(string.format(
				[[\draw let \p1 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$), \p2 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$) in ($(\p1)!0.5!(\p2)$) node {%s};]],
				st.row,st.col,
				st.row+1,st.col,
				st.row,(_M.cols//_M.scale)+1,
				st.row+1,(_M.cols//_M.scale)+1,
				e.c1
			))
		end
		if e.c2 and e.c2 ~= "" then
			pr(string.format(
				[[\draw let \p1 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$), \p2 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$) in ($(\p1)!0.5!(\p2)$) node {%s};]],
				en.row,en.col,
				en.row+1,en.col,
				en.row,1,
				en.row+1,1,
				e.c2
			))
		end
	else
		-- field spans multiple rows
		pr(string.format(
			[[\draw (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)  -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) -- cycle;]],
			st.row+1,1,
			st.row+1,st.col,
			st.row,st.col,
			st.row,(_M.cols//_M.scale)+1,

			en.row,(_M.cols//_M.scale)+1,
			en.row,en.col+1,
			en.row+1,en.col+1,
			en.row+1,1
		))

		if e.c1 and e.c1 ~= "" then
			pr(string.format(
				[[\draw let \p1 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$), \p2 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$) in ($(\p1)!0.5!(\p2)$) node {%s};]],
				st.row,st.col,
				st.row+1,st.col,
				st.row,(_M.cols//_M.scale)+1,
				st.row+1,(_M.cols//_M.scale)+1,
				e.c1
			))
		end
		if e.c2 and e.c2 ~= "" then
			pr(string.format(
				[[\draw let \p1 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$), \p2 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$) in ($(\p1)!0.5!(\p2)$) node[] {%s};]],
				en.row,en.col+1,
				en.row+1,en.col+1,
				en.row,1,
				en.row+1,1,
				e.c2
			))
		end
		if e.c3 and e.c3 ~= "" and st.row < en.row -1 then
			pr(string.format(
				[[\draw let \p1 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$), \p2 = ($(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)!0.5!(nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d)$) in ($(\p1)!0.5!(\p2)$) node[] {%s};]],
				en.row,(_M.cols//_M.scale)+1,
				st.row+1,(_M.cols//_M.scale)+1,
				en.row,1,
				st.row+1,1,
				e.c3
			))
		end
	end
end

-- draw the actual header -- the tikz part for borders
-- place this inside
-- \begin{tikzpicture}[remember picture, overlay, name prefix=nm-\NiceMatrixLastEnv-]
-- and put any other tikz code referencing the nodes from nicematrix here too
function _M.drawTikz()
	-- draw field by field
	for _,e in ipairs(_M.coll) do
		draw(e)
	end
	-- draw the \approx signs at rows before the collapsing
	for c=1,(_M.coll.max*_M.scale) // _M.cols +1 do
		if not _M.sk.set[c-1] and _M.sk.set[c] then
			pr(string.format(
				[[\node[anchor=south] at (nm-\NiceMatrixLastEnv-row-%d -| nm-\NiceMatrixLastEnv-col-%d) {$\approx$};]],
				_M.sk.map[c-1]+1,(_M.cols//_M.scale)+1
			))
		end
	end
end

return _M
