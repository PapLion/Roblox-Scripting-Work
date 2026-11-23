param([string]$Name, [string]$OutDir = "$PSScriptRoot\..\..\captures")
# PrintWindow capture of the Studio window (never the desktop), cropped to the specimen canvas.
$tmp = Join-Path $env:TEMP "vellum_studio_full.png"
& "$PSScriptRoot\printwin.ps1" -Out $tmp | Out-Null
New-Item -ItemType Directory -Force $OutDir | Out-Null
python "$PSScriptRoot\boardcap.py" $tmp (Join-Path $OutDir "$Name.png")
