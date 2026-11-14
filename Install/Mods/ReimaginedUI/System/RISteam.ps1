# Reimagined UI: switch the mod on or off for the game's normal launch
# (Steam's Play button, Kentie's launcher, DeusEx.exe on its own).
#   RISteam.ps1 On    the game opens with the Reimagined UI
#   RISteam.ps1 Off   the game opens untouched again
# Edits the settings file(s) Kentie's DeusExe reads: the profile one in
# Documents\Deus Ex\System and, if present, the game's own System\DeusEx.ini.
# Only two things change: [Engine.Engine] Root (which menus the game uses)
# and one Paths line in [Core.System] (where the mod's packages are).
# A backup of each file is kept next to it the first time.
param([string]$Mode = 'On')
$ErrorActionPreference = 'Stop'

$Game    = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$ModPath = Join-Path $Game 'Mods\ReimaginedUI\System\Vanilla\*.u'
$Ours    = 'ReimaginedUI.RIRootWindow'
$Stock   = 'DeusEx.DeusExRootWindow'

# Where the lines that matter are (-1 when missing)
function Scan($Lines) {
    $R = @{ Root = -1; Engine = -1; System = -1; FirstPath = -1; OurPath = -1 }
    $Section = ''
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $L = $Lines[$i].Trim()
        if ($L -match '^\[(.+)\]$') {
            $Section = $Matches[1]
            if ($Section -eq 'Engine.Engine') { $R.Engine = $i }
            if ($Section -eq 'Core.System')   { $R.System = $i }
            continue
        }
        if ($Section -eq 'Engine.Engine' -and $L -match '^Root=') { $R.Root = $i }
        if ($Section -eq 'Core.System' -and $L -match '^Paths=') {
            if ($R.FirstPath -lt 0) { $R.FirstPath = $i }
            if ($L -match 'ReimaginedUI\\System\\Vanilla') { $R.OurPath = $i }
        }
    }
    return $R
}

$Candidates = @(
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Deus Ex\System\DeusEx.ini'),
    (Join-Path $Game 'System\DeusEx.ini')
)
$Found = @($Candidates | Where-Object { Test-Path -LiteralPath $_ })
if ($Found.Count -eq 0) {
    Write-Host 'No DeusEx.ini found yet. Start Deus Ex once from Steam (then quit), and run this again.'
    exit 1
}
if (($Mode -ne 'Off') -and -not (Test-Path -LiteralPath (Join-Path $Game 'Mods\ReimaginedUI\System\Vanilla\ReimaginedUI.u'))) {
    Write-Host "Reimagined UI isn't installed in $Game (Mods\ReimaginedUI is missing)."
    exit 1
}

foreach ($Ini in $Found) {
    # keep the file's own encoding
    $Reader = New-Object System.IO.StreamReader($Ini, [System.Text.Encoding]::Default, $true)
    $Text = $Reader.ReadToEnd()
    $Enc  = $Reader.CurrentEncoding
    $Reader.Close()
    $Lines = New-Object System.Collections.Generic.List[string]
    $Text -split "`r?`n" | ForEach-Object { $Lines.Add($_) }
    if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1] -eq '') { $Lines.RemoveAt($Lines.Count - 1) }

    $Backup = "$Ini.reimaginedui-backup"
    if (-not (Test-Path -LiteralPath $Backup)) { Copy-Item -LiteralPath $Ini -Destination $Backup }

    if ($Mode -eq 'Off') {
        $S = Scan $Lines
        if ($S.Root -ge 0) { $Lines[$S.Root] = "Root=$Stock" }
        if ($S.OurPath -ge 0) { $Lines.RemoveAt($S.OurPath) }
    } else {
        # the menus
        $S = Scan $Lines
        if ($S.Root -ge 0)       { $Lines[$S.Root] = "Root=$Ours" }
        elseif ($S.Engine -ge 0) { $Lines.Insert($S.Engine + 1, "Root=$Ours") }
        else { $Lines.Add('[Engine.Engine]'); $Lines.Add("Root=$Ours") }
        # the mod's packages, first in the list (highest priority)
        $S = Scan $Lines
        if ($S.OurPath -lt 0) {
            if ($S.FirstPath -ge 0)  { $Lines.Insert($S.FirstPath, "Paths=$ModPath") }
            elseif ($S.System -ge 0) { $Lines.Insert($S.System + 1, "Paths=$ModPath") }
            else { $Lines.Add('[Core.System]'); $Lines.Add("Paths=$ModPath"); $Lines.Add('Paths=..\System\*.u') }
        }
    }

    [System.IO.File]::WriteAllText($Ini, (($Lines -join "`r`n") + "`r`n"), $Enc)
    Write-Host "Updated $Ini"
}
if ($Mode -eq 'Off') {
    Write-Host 'Reimagined UI is off: the game starts untouched from Steam again.'
} else {
    Write-Host 'Reimagined UI is on: start Deus Ex from Steam as usual.'
}
