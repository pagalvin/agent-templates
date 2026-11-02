<#+
.SYNOPSIS
  Read-only discovery of numbered implementation plans.
.EXAMPLE
  ./Get-PlanStatus.ps1 -RepositoryRoot .
.EXAMPLE
  ./Get-PlanStatus.ps1 -RepositoryRoot . -Plan docs/plans/0003-world-clock.md
.NOTES
  Emits exactly one JSON document. Does not authorize execution or validate task readiness.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = '.',
    [string]$Plan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FieldValues {
    param([string]$Content, [string]$Name)
    $escaped = [regex]::Escape($Name)
    $pattern = '(?im)^\s*(?:[-*]\s*)?(?:\*\*)?' + $escaped + '(?:\*\*)?\s*:\s*(.+?)\s*$'
    $matchesFound = [regex]::Matches($Content, $pattern)
    $values = @()
    foreach ($match in $matchesFound) {
        $value = $match.Groups[1].Value.Trim().Trim('`').Trim()
        $value = ($value -replace '\s*\|.*$', '').Trim()
        if ($value) { $values += $value }
    }
    return $values
}

function Inspect-Plan {
    param([System.IO.FileInfo]$File, [string]$Root)
    $issues = [System.Collections.Generic.List[string]]::new()
    $content = [System.IO.File]::ReadAllText($File.FullName)
    # Legacy plans contain task-level Status fields. Only inspect the index header.
    $header = [regex]::Split($content, '(?im)^#{1,6}\s+(?:E-\d+|T-\d+\.\d+|Effort\b|Task\b|Tasks\b|Task directory\b)')[0]
    $statuses = @(Get-FieldValues $header 'Status')
    $markers = @(Get-FieldValues $header 'Plan format')
    if ($statuses.Count -ne 1) { $issues.Add("Expected exactly one plan Status field; found $($statuses.Count).") }
    $status = if ($statuses.Count -eq 1) { $statuses[0].ToLowerInvariant() } else { $null }
    if ($status -and $status -notin @('draft','active','blocked','complete','superseded')) {
        $issues.Add("Unknown plan status: $status")
    }
    if ($markers.Count -gt 1) { $issues.Add('Multiple Plan format markers.') }
    $format = 'legacy'
    if ($markers.Count -eq 1) {
        if ($markers[0] -eq 'linked-v1') { $format = 'linked-v1' }
        else { $format = 'unknown'; $issues.Add("Unknown Plan format: $($markers[0])") }
    }
    # A linked index must have its corresponding directory. Deep task/link validation is a later increment.
    if ($format -eq 'linked-v1') {
        $folder = Join-Path $File.DirectoryName $File.BaseName
        if (-not [System.IO.Directory]::Exists($folder)) { $issues.Add('Linked plan directory is missing.') }
    }
    $relative = $File.FullName.Substring($Root.TrimEnd([char]'/',[char]'\').Length).TrimStart([char]'/',[char]'\').Replace('\','/')
    return [pscustomobject]@{
        path = $relative
        status = $status
        format = $format
        valid = ($issues.Count -eq 0)
        errors = @($issues.ToArray())
    }
}

$result = [ordered]@{
    selected = $null
    plans = @()
    errors = @()
}
try {
    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $plansDirectory = Join-Path $root 'docs/plans'
    if (-not [System.IO.Directory]::Exists($plansDirectory)) { throw 'docs/plans directory does not exist.' }

    if ($PSBoundParameters.ContainsKey('Plan')) {
        $candidate = if ([System.IO.Path]::IsPathRooted($Plan)) { $Plan } else { Join-Path $root $Plan }
        $candidate = [System.IO.Path]::GetFullPath($candidate)
        $allowedParent = [System.IO.Path]::GetFullPath($plansDirectory).TrimEnd([char]'/',[char]'\')
        $parent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($candidate)).TrimEnd([char]'/',[char]'\')
        if ($parent -ne $allowedParent) { throw 'Named plan must be a top-level file directly inside docs/plans.' }
        if (-not [System.IO.File]::Exists($candidate)) { throw "Named plan does not exist: $Plan" }
        $file = Get-Item -LiteralPath $candidate
        if ($file.Name -notmatch '^\d{4}-.+\.md$') { throw 'Named plan must match NNNN-feature.md.' }
        $found = @(Inspect-Plan -File $file -Root $root)
    } else {
        $found = @(Get-ChildItem -LiteralPath $plansDirectory -File -Filter '*.md' |
            Where-Object { $_.Name -match '^\d{4}-.+\.md$' } |
            Sort-Object Name |
            ForEach-Object { Inspect-Plan -File $_ -Root $root })
        # Non-active plans are not candidates, but malformed plans are surfaced instead of silently discarded.
        $found = @($found | Where-Object { $_.status -in @('active','blocked') -or -not $_.valid })
    }
    $result.plans = @($found)
    foreach ($item in $found) {
        foreach ($issue in $item.errors) { $result.errors += "$($item.path): $issue" }
    }
    if ($result.errors.Count -eq 0) {
        if ($found.Count -eq 1) { $result.selected = $found[0].path }
        elseif ($found.Count -gt 1 -and -not $PSBoundParameters.ContainsKey('Plan')) {
            $result.errors += 'Multiple candidate plans; explicit selection required.'
        }
    }
} catch {
    $result.errors += $_.Exception.Message
}
$result | ConvertTo-Json -Depth 8 -Compress
if ($result.errors.Count -gt 0) { exit 1 }
