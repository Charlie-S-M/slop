--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Format = require("@game/ReplicatedStorage/Shared/Format")

describe("Format.abbreviate", function()
	it("shows small whole numbers as they are", function()
		expect(Format.abbreviate(0)).toBe("0")
		expect(Format.abbreviate(999)).toBe("999")
	end)

	it("adds a suffix and trims trailing zeros", function()
		expect(Format.abbreviate(1500)).toBe("1.5K")
		expect(Format.abbreviate(3000000)).toBe("3M")
		expect(Format.abbreviate(5.82e12)).toBe("5.82T")
	end)

	it("carries a rounded value into the next suffix", function()
		expect(Format.abbreviate(999999)).toBe("1M")
	end)

	it("keeps going past the named suffixes", function()
		local text = Format.abbreviate(1e80)
		expect(string.match(text, "^%d")).never.toBeNil()
		expect(string.match(text, "%a+$")).never.toBeNil()
	end)

	it("handles NaN and negatives", function()
		expect(Format.abbreviate(0 / 0)).toBe("0")
		expect(Format.abbreviate(-2500)).toBe("-2.5K")
	end)
end)

describe("Format.duration", function()
	it("picks the largest useful units", function()
		expect(Format.duration(12)).toBe("12s")
		expect(Format.duration(245)).toBe("4m 05s")
		expect(Format.duration(3720)).toBe("1h 02m")
		expect(Format.duration(47 * 3600)).toBe("47h 00m")
		expect(Format.duration(500 * 3600 + 60)).toBe("20d 20h")
	end)
end)
