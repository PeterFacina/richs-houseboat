param(
    [Parameter(Mandatory)][ValidateSet('AddOrReset','Revoke')][string]$Action,
    [Parameter(Mandatory)][string]$Name,
    [ValidateSet('admin','member')][string]$Role = 'member'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_common.ps1')
$studioNode = Find-StudioNode
$studioControl = Join-Path $PSScriptRoot 'control.mjs'
if ($Action -eq 'Revoke') {
    & $studioNode $studioControl user-revoke $Name
} else {
    $studioPassword = Read-Host 'Account password (at least 8 characters)' -AsSecureString
    $studioPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($studioPassword)
    $studioStartInfo = New-Object Diagnostics.ProcessStartInfo
    try {
        if ($Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._@-]{1,79}$') { throw 'Choose a valid account name.' }
        $studioStartInfo.FileName = $studioNode
        $studioStartInfo.Arguments = ('"{0}" user-set "{1}" {2}' -f $studioControl, $Name, $Role)
        $studioStartInfo.UseShellExecute = $false
        $studioStartInfo.RedirectStandardInput = $true
        $studioProcess = [Diagnostics.Process]::Start($studioStartInfo)
        try {
            $studioProcess.StandardInput.WriteLine([Runtime.InteropServices.Marshal]::PtrToStringBSTR($studioPointer))
            $studioProcess.StandardInput.Close()
            $studioProcess.WaitForExit()
            $studioExit = $studioProcess.ExitCode
        } finally { $studioProcess.Dispose() }
    } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($studioPointer) }
    exit $studioExit
}
exit $LASTEXITCODE
