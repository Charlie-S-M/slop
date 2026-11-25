--[[
	Paste into a ModuleScript at ServerStorage.__RunSpecs. Runs every Jest spec in edit mode and
	returns a one-line summary plus each failure.
]]
local function strip(text: string): string
	return (string.gsub(text, "\27%[[%d;]*m", ""))
end

return function(): string
	local tests = game:GetService("ServerScriptService"):FindFirstChild("Tests") :: any
	local Jest = require(tests.Packages.Jest) :: any
	local specs = tests.Specs
	local status, result = Jest.runCLI(specs, { ci = true, verbose = false }, { specs })
		:awaitStatus()
	if status ~= "Resolved" then
		return `Jest did not finish: {if typeof(result) == "table" then result.message else result}`
	end
	local results = result.results
	local lines = {
		`{results.numTotalTestSuites} files, {results.numPassedTests} passed, {results.numFailedTests} failed`,
	}
	for _, file in results.testResults do
		if file.testExecError ~= nil then
			table.insert(
				lines,
				`LOAD ERROR {file.testFilePath}: {string.sub(
					strip(file.failureMessage or ""),
					1,
					400
				)}`
			)
		else
			for _, test in file.testResults do
				if test.status == "failed" then
					table.insert(
						lines,
						`FAIL {test.fullName}: {string.sub(
							strip(test.failureMessages[1] or ""),
							1,
							300
						)}`
					)
				end
			end
		end
	end
	return table.concat(lines, "\n")
end
