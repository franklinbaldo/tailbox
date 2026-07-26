[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scripts = @(
    Get-ChildItem -LiteralPath $repositoryRoot -Filter "*.ps1" -File
    Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1" -File
)

foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -ne 0) {
        throw "PowerShell parser errors in $($script.FullName): $($errors -join '; ')."
    }
}

$analysis = @(
    foreach ($script in $scripts) {
        Invoke-ScriptAnalyzer -Path $script.FullName -Severity Warning, Error
    }
)
if ($analysis.Count -ne 0) {
    $analysis | Format-Table -AutoSize | Out-String | Write-Output
    throw "PSScriptAnalyzer reported $($analysis.Count) issue(s)."
}

foreach ($script in $scripts) {
    $original = Get-Content -LiteralPath $script.FullName -Raw
    $normalizedOriginal = $original.Replace("`r`n", "`n").TrimEnd()
    $formatted = Invoke-Formatter -ScriptDefinition $normalizedOriginal
    $normalizedFormatted = $formatted.Replace("`r`n", "`n").TrimEnd()
    if ($normalizedOriginal -cne $normalizedFormatted) {
        throw "Invoke-Formatter would change $($script.FullName)."
    }
}

Write-Output "PowerShell syntax, analysis, and formatting passed."


