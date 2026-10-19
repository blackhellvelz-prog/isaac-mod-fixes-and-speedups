-- Быстрый json.decode для общего модуля require("json") (JSON4Lua 0.9.20 из resources/scripts/json.lua игры и
-- REPENTOGON) — 17.10, задача «моды быстрее загружались».
--
-- Почему: в оригинале проверки написаны как assert(условие, "сообщение … " .. s) — Lua склеивает сообщение при
-- КАЖДОМ вызове, даже без ошибки, а s — весь документ. json.decode, decode_scanArray и decode_scanObject копируют
-- его на каждое значение, массив и объект: дерево Passive Skill Trees (220 КБ) — 434 МБ мусора при загрузке. И
-- каждое число читается через load("return " .. число) — компиляция куска Lua на число.
--
-- Что изменено (только скорость, результат тот же): сообщения об ошибках склеиваются только при ошибке (те же
-- тексты, с позицией места проверки — как assert); число — tonumber (не прочиталось — как раньше, через load:
-- оригинал понимает и «1+2»; единственное отличие — «+5» читается, оригинал падал); пробелы — одним поиском по
-- шаблону; константы — без таблиц на каждый вызов; строки — без поиска кавычки и «\» по всему документу на каждом
-- шаге (сверка tools/lua/json_check.lua: сохранения 60 модов, деревья PST, краевые случаи).
-- Сохранены и странности оригинала: null в массиве пропускается (элементы сдвигаются), одинарные кавычки, /* */,
-- «e» в начале числа, хвост string.sub(j, j + 1) в строке (у пустой строки в позиции 1 даёт "1").
-- json.encode не трогается. Подмена — полем json.decode в общей таблице модуля: все, кто уже взял require("json"),
-- получают её при следующем вызове.

local sub, find, len, byte = string.sub, string.find, string.len, string.byte
local concat = table.concat
local char, floor = string.char, math.floor

local decode, scanArray, scanComment, scanConstant, scanNumber, scanObject, scanString, scanWhitespace

local function fail(msg)
	error(msg, 2) -- как assert: «файл:строка: сообщение» места проверки
end

function scanWhitespace(s, startPos)
	-- оригинал: пока символ из " \n\r\t" и startPos <= длины — дальше; итог — первая позиция не пробела
	local _, e = find(s, "^[ \n\r\t]*", startPos)
	if e then return e + 1 end
	return startPos
end

function decode(s, startPos)
	startPos = startPos and startPos or 1
	startPos = scanWhitespace(s, startPos)
	if not (startPos <= len(s)) then
		fail("Unterminated JSON encoded object found at position in [" .. s .. "]")
	end
	local curChar = sub(s, startPos, startPos)
	if curChar == "{" then
		return scanObject(s, startPos)
	end
	if curChar == "[" then
		return scanArray(s, startPos)
	end
	if find("+-0123456789.e", curChar, 1, true) then
		return scanNumber(s, startPos)
	end
	if curChar == [["]] or curChar == [[']] then
		return scanString(s, startPos)
	end
	if sub(s, startPos, startPos + 1) == "/*" then
		return decode(s, scanComment(s, startPos))
	end
	return scanConstant(s, startPos)
end

function scanArray(s, startPos)
	local array = {}
	local object
	local stringLen = len(s)
	if sub(s, startPos, startPos) ~= "[" then
		fail("decode_scanArray called but array does not start at position " .. startPos .. " in string:\n" .. s)
	end
	startPos = startPos + 1
	repeat
		startPos = scanWhitespace(s, startPos)
		if not (startPos <= stringLen) then fail("JSON String ended unexpectedly scanning array.") end
		local curChar = sub(s, startPos, startPos)
		if curChar == "]" then
			return array, startPos + 1
		end
		if curChar == "," then
			startPos = scanWhitespace(s, startPos + 1)
		end
		if not (startPos <= stringLen) then fail("JSON String ended unexpectedly scanning array.") end
		object, startPos = decode(s, startPos)
		array[#array + 1] = object -- как table.insert(array, object): nil не добавляется
	until false
end

function scanComment(s, startPos)
	if sub(s, startPos, startPos + 1) ~= "/*" then
		fail("decode_scanComment called but comment does not start at position " .. startPos)
	end
	local endPos = find(s, "*/", startPos + 2)
	if endPos == nil then fail("Unterminated comment in string at " .. startPos) end
	return endPos + 2
end

function scanConstant(s, startPos)
	-- порядок проверки как в оригинале: true, false, null
	if sub(s, startPos, startPos + 3) == "true" then return true, startPos + 4 end
	if sub(s, startPos, startPos + 4) == "false" then return false, startPos + 5 end
	if sub(s, startPos, startPos + 3) == "null" then return nil, startPos + 4 end
	fail("Failed to scan constant from string " .. s .. " at starting position " .. startPos)
end

function scanNumber(s, startPos)
	-- первый символ уже из «+-0123456789.e»; дальше — пока символы из этого набора
	local _, e = find(s, "^[%+%-0123456789%.e]*", startPos + 1)
	local endPos = (e or startPos) + 1
	local text = sub(s, startPos, endPos - 1)
	local n = tonumber(text)
	if n ~= nil then return n, endPos end
	local stringValue = "return " .. text
	local stringEval = load(stringValue)
	if not stringEval then
		fail("Failed to scan number [ " .. stringValue .. "] in JSON string at position " .. startPos .. " : " .. endPos)
	end
	return stringEval(), endPos
end

function scanObject(s, startPos)
	local object = {}
	local stringLen = len(s)
	local key, value
	if sub(s, startPos, startPos) ~= "{" then
		fail("decode_scanObject called but object does not start at position " .. startPos .. " in string:\n" .. s)
	end
	startPos = startPos + 1
	repeat
		startPos = scanWhitespace(s, startPos)
		if not (startPos <= stringLen) then fail("JSON string ended unexpectedly while scanning object.") end
		local curChar = sub(s, startPos, startPos)
		if curChar == "}" then
			return object, startPos + 1
		end
		if curChar == "," then
			startPos = scanWhitespace(s, startPos + 1)
		end
		if not (startPos <= stringLen) then fail("JSON string ended unexpectedly scanning object.") end
		key, startPos = decode(s, startPos)
		if not (startPos <= stringLen) then
			fail("JSON string ended unexpectedly searching for value of key " .. key)
		end
		startPos = scanWhitespace(s, startPos)
		if not (startPos <= stringLen) then
			fail("JSON string ended unexpectedly searching for value of key " .. key)
		end
		if sub(s, startPos, startPos) ~= ":" then
			fail("JSON object key-value assignment mal-formed at " .. startPos)
		end
		startPos = scanWhitespace(s, startPos + 1)
		if not (startPos <= stringLen) then
			fail("JSON string ended unexpectedly searching for value of key " .. key)
		end
		value, startPos = decode(s, startPos)
		object[key] = value
	until false
end

local escapeSequences = {
	["\\t"] = "\t",
	["\\f"] = "\f",
	["\\r"] = "\r",
	["\\n"] = "\n",
	["\\b"] = "\b",
}
setmetatable(escapeSequences, { __index = function(t, k)
	return sub(k, 2)
end })

function scanString(s, startPos)
	if not startPos then fail("decode_scanString(..) called without start position") end
	local startChar = sub(s, startPos, startPos)
	if not (startChar == [["]] or startChar == [[']]) then fail("decode_scanString called for a non-string") end
	local t = {}
	local i, j = startPos, startPos
	-- Оригинал на каждом шаге искал следующую кавычку и следующую «\.» по всему документу — квадратичное время на
	-- строках с экранированием (вложенный JSON в сохранениях модов). Здесь — один поиск ближайшего «\» или своей
	-- кавычки; ветки и результат те же.
	local stop = (startChar == '"') and '[\\"]' or "[\\']"
	local slen = len(s)
	while sub(s, j + 1, j + 1) ~= startChar do -- то же, что find(s, startChar, j + 1) ~= j + 1
		local oldj = j
		local p = find(s, stop, j + 1)
		if p and byte(s, p) == 92 and p < slen then
			i, j = p, p + 1 -- «\» и следующий символ (как find(s, "\\.", j + 1)); кавычки до него нет
		else
			local x, y -- кавычка; нет её — ошибка, как в оригинале
			if p and byte(s, p) ~= 92 then x, y = p, p end
			i, j = x, y - 1
		end
		t[#t + 1] = sub(s, oldj + 1, i - 1)
		if sub(s, i, j) == "\\u" then
			local a = sub(s, j + 1, j + 4)
			j = j + 4
			local n = tonumber(a, 16)
			if not n then fail("String decoding failed: bad Unicode escape " .. a .. " at position " .. i .. " : " .. j) end
			local c
			if n < 0x80 then
				c = char(n % 0x80)
			elseif n < 0x800 then
				c = char(0xC0 + (floor(n / 64) % 0x20), 0x80 + (n % 0x40))
			else
				c = char(0xE0 + (floor(n / 4096) % 0x10), 0x80 + (floor(n / 64) % 0x40), 0x80 + (n % 0x40))
			end
			t[#t + 1] = c
		else
			t[#t + 1] = escapeSequences[sub(s, i, j)]
		end
	end
	t[#t + 1] = sub(j, j + 1) -- как в оригинале (string.sub от числа j)
	if not find(s, startChar, j + 1, true) then
		fail("String decoding failed: missing closing " .. startChar .. " at position " .. j .. "(for string at position " .. startPos .. ")")
	end
	return concat(t, ""), j + 2
end

-- Установка: include("json_fast")(require("json")) — true, если подменено.
return function(json)
	if type(json) ~= "table" or type(json.decode) ~= "function" or json.LocalFixesFastDecode then return false end
	-- старый не сохраняется: его рекурсия идёт через поле json.decode, после подмены это уже быстрый; для сверки
	-- tools/lua/json_check.lua грузит отдельную нетронутую копию json.lua
	json.decode = decode
	json.LocalFixesFastDecode = true
	return true
end
