# Builds the code into .rbxm models under build/studio-sync/ for syncing into Studio without
# `rojo serve`. Import each model into ServerStorage.__Sync (the Studio MCP's import_rbxm does
# this), then run require(game.ServerStorage.__SyncApply)() in Studio. See README.md.
param([string[]]$Parts = @("shared", "server", "client"))
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path "$here\..\.."
$out = Join-Path $root "build\studio-sync"
New-Item -ItemType Directory -Force $out | Out-Null
Set-Location $root
stylua places tools
selene --display-style quiet places tools
foreach ($part in $Parts) {
	& rojo build "$here\$part.project.json" -o "$out\$part.rbxm"
	if ($LASTEXITCODE -ne 0) { throw "rojo build failed for $part" }
}
