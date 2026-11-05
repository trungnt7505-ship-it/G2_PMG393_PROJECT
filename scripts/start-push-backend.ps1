param([switch]$Check)
$ErrorActionPreference = 'Stop'
$backendPath = Join-Path $PSScriptRoot '../firebase/functions'
$nodePath = 'C:/Program Files/nodejs/node.exe'
$npmPath = 'C:/Program Files/nodejs/npm.cmd'
if (-not (Test-Path (Join-Path $backendPath 'node_modules/firebase-admin'))) {
    Push-Location $backendPath
    try {
        & $npmPath ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw 'Cannot install backend dependencies.' }
    } finally { Pop-Location }
}
$workerPath = Join-Path $backendPath 'laptop-worker.js'
if ($Check) { & $nodePath $workerPath --check }
else { & $nodePath $workerPath }
exit $LASTEXITCODE
