--!strict

-- Short number names for the huge values an incremental game reaches. Past the named suffixes the
-- list continues with two-letter codes (aa, ab, ...), so no value is ever too big to show.
const NAMED_SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
}

const ALPHABET = "abcdefghijklmnopqrstuvwxyz"

local Format = {}

local function suffixFor(group: number): string
	if group < #NAMED_SUFFIXES then
		return NAMED_SUFFIXES[group + 1]
	end
	local index = group - #NAMED_SUFFIXES
	local first = math.floor(index / 26) % 26 + 1
	local second = index % 26 + 1
	return string.sub(ALPHABET, first, first) .. string.sub(ALPHABET, second, second)
end

--[[
	Formats a number as a short string: 1234 -> "1.23K", 5.82e12 -> "5.82T". Values under 1000
	show without decimals unless they are fractional and small.
]]
function Format.abbreviate(value: number): string
	if value ~= value then
		return "0"
	end
	if value == math.huge then
		return "∞"
	end
	local negative = value < 0
	local absolute = math.abs(value)
	local text: string
	if absolute < 1000 then
		if absolute < 10 and absolute ~= math.floor(absolute) then
			text = string.format("%.1f", absolute)
		else
			text = tostring(math.floor(absolute))
		end
	else
		local group = math.floor(math.log10(absolute) / 3)
		local scaled = absolute / 10 ^ (group * 3)
		-- Rounding can carry 999.99 into 1000, which belongs to the next group.
		if scaled >= 999.995 then
			group += 1
			scaled = absolute / 10 ^ (group * 3)
		end
		local digits = if scaled >= 100 then "%.0f" elseif scaled >= 10 then "%.1f" else "%.2f"
		text = string.format(digits, scaled)
		-- Drop trailing zeros so 2.50K reads 2.5K and 3.00M reads 3M.
		if string.find(text, "%.") then
			text = string.gsub(text, "0+$", "")
			text = string.gsub(text, "%.$", "")
		end
		text ..= suffixFor(group)
	end
	return if negative then "-" .. text else text
end

-- Formats a whole number with thousands separators, used where exact counts matter.
function Format.commas(value: number): string
	local text = tostring(math.floor(value))
	local result = string.reverse(text)
	result = string.gsub(result, "(%d%d%d)", "%1,")
	result = string.reverse(result)
	return (string.gsub(result, "^(-?),", "%1"))
end

-- Formats seconds as "1h 02m", "4m 05s", or "12s".
function Format.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

-- Formats a multiplier like 2 -> "2x" and 1.5 -> "1.5x".
function Format.multiplier(value: number): string
	if value >= 1000 then
		return Format.abbreviate(value) .. "x"
	end
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text .. "x"
end

function Format.percent(value: number): string
	local text = string.format("%.1f", value * 100)
	text = string.gsub(text, "%.0$", "")
	return text .. "%"
end

return Format
