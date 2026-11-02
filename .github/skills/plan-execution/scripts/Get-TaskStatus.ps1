#requires -Version 5.1
<#
.SYNOPSIS
  Read-only discovery of linked-v1 task records and their declared metadata.
.EXAMPLE
  .\Get-TaskStatus.ps1 -RepositoryRoot . -Plan docs/plans/0003-developer-log-filtering-and-hiding.md
.EXAMPLE
  .\Get-TaskStatus.ps1 -RepositoryRoot . -Plan docs/plans/0003-developer-log-filtering-and-hiding.md -Task T-02.1
.NOTES
  Emits one JSON object. Does not establish dependency readiness, gate approval, or execution authorization.
  Does not modify files. PowerShell 5.1 compatible.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = '.',
    [Parameter(Mandatory = $true)][string]$Plan,
    [string]$Task
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Field {
    param([string]$Content, [string[]]$Names)
    foreach ($name in $Names) {
        $escaped = [regex]::Escape($name)
        $pattern = '(?im)^\s*(?:[-*]\s+)?(?:\*\*' + $escaped + '(?:\s*:\*\*|\*\*\s*:)|' + $escaped + '\s*:)\s*(.*?)\s*$'
        $matches = @([regex]::Matches($Content, $pattern))
        if ($matches.Count -gt 0) {
            $values = @($matches | ForEach-Object { $_.Groups[1].Value.Trim().Trim('`').Trim() } | Where-Object { $_ })
            if ($values.Count -gt 0) { return ($values -join ' | ') }
        }
        $tablePattern = '(?im)^\s*\|\s*(?:\*\*)?' + $escaped + '(?:\*\*)?\s*\|\s*([^|]+?)\s*\|\s*$'
        $tableMatches = @([regex]::Matches($Content, $tablePattern))
        if ($tableMatches.Count -gt 0) { return $tableMatches[0].Groups[1].Value.Trim().Trim('`').Trim() }
    }
    return $null
}

function Get-DeclaredDependencies {
    param([string]$Content)
    $raw = Read-Field $Content @('Depends on','Dependencies','Depends On')
    if (-not $raw) { return @() }
    $ids = @([regex]::Matches($raw, '(?i)\bT-\d+\.\d+\b') | ForEach-Object { $_.Value.ToUpperInvariant() } | Select-Object -Unique)
    return $ids
}

function Inspect-Task {
    param([System.IO.FileInfo]$File, [string]$Root)
    $issues = [System.Collections.Generic.List[string]]::new()
    $content = [System.IO.File]::ReadAllText($File.FullName)
    $id = [System.IO.Path]::GetFileNameWithoutExtension($File.Name).ToUpperInvariant()
    $heading = [regex]::Match($content, '(?m)^#\s+(.+?)\s*$')
    $title = if ($heading.Success) { $heading.Groups[1].Value.Trim() } else { $null }
    $statusRaw = Read-Field $content @('Status')
    $status = if ($statusRaw) { $statusRaw.Trim().Trim('*').Trim().ToLowerInvariant() } else { $null }
    $owner = Read-Field $content @('Owner','Owning agent','Assigned agent','Agent')
    $dependencies = @(Get-DeclaredDependencies $content)
    if (-not $status) { $issues.Add('Task Status field was not found.') }
    elseif ($status -notin @('pending','in-progress','blocked','done','cancelled')) {
        $issues.Add("Unknown task status: $status")
    }
    $relative = $File.FullName.Substring($Root.TrimEnd([char]'/',[char]'\').Length).TrimStart([char]'/',[char]'\').Replace('\','/')
    return [pscustomobject]@{
        id = $id
        path = $relative
        title = $title
        status = $status
        owner = $owner
        dependencies = @($dependencies)
        valid = ($issues.Count -eq 0)
        errors = @($issues.ToArray())
    }
}

$result = [ordered]@{
    plan = $null
    tasks = @()
    errors = @()
}
try {
    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $plansDirectory = [System.IO.Path]::GetFullPath((Join-Path $root 'docs/plans'))
    $candidate = if ([System.IO.Path]::IsPathRooted($Plan)) { $Plan } else { Join-Path $root $Plan }
    $candidate = [System.IO.Path]::GetFullPath($candidate)
    $parent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($candidate))
    if ($parent.TrimEnd([char]'/',[char]'\') -ne $plansDirectory.TrimEnd([char]'/',[char]'\')) {
        throw 'Plan must be a top-level file in docs/plans.'
    }
    if (-not [System.IO.File]::Exists($candidate)) { throw "Plan not found: $Plan" }
    $planFile = Get-Item -LiteralPath $candidate
    if ($planFile.Name -notmatch '^\d{4}-.+\.md$') { throw 'Plan must match NNNN-feature.md.' }
    $index = [System.IO.File]::ReadAllText($candidate)
    $format = Read-Field $index @('Plan format')
    if ($format -ne 'linked-v1') { throw 'Only linked-v1 plans are supported; legacy or unknown plan format.' }
    $result.plan = $candidate.Substring($root.TrimEnd([char]'/',[char]'\').Length).TrimStart([char]'/',[char]'\').Replace('\','/')
    $tasksDirectory = Join-Path (Join-Path $planFile.DirectoryName $planFile.BaseName) 'tasks'
    if (-not [System.IO.Directory]::Exists($tasksDirectory)) { throw 'Linked plan tasks directory is missing.' }
    if ($PSBoundParameters.ContainsKey('Task')) {
        $taskId = $Task.ToUpperInvariant()
        if ($taskId -notmatch '^T-\d+\.\d+$') { throw 'Task must be an ID like T-02.1.' }
        $taskFile = Join-Path $tasksDirectory ($taskId + '.md')
        if (-not [System.IO.File]::Exists($taskFile)) { throw "Task not found: $taskId" }
        $files = @(Get-Item -LiteralPath $taskFile)
    } else {
        $files = @(Get-ChildItem -LiteralPath $tasksDirectory -File -Filter 'T-*.md' |
            Where-Object { $_.Name -match '^T-\d+\.\d+\.md$' } | Sort-Object Name)
    }
    $tasks = @($files | ForEach-Object { Inspect-Task -File $_ -Root $root })
    $result.tasks = @($tasks)
    foreach ($item in $tasks) {
        foreach ($issue in $item.errors) { $result.errors += "$($item.path): $issue" }
    }
} catch {
    $result.errors += $_.Exception.Message
}
$result | ConvertTo-Json -Depth 8 -Compress
if ($result.errors.Count -gt 0) { exit 1 }
