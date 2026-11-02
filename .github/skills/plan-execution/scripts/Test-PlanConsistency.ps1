#requires -Version 5.1
<#
.SYNOPSIS
  Read-only consistency checks for a linked-v1 implementation plan.
.DESCRIPTION
  Uses Get-TaskStatus.ps1 for task discovery, then compares task files with
  the plan's Task directory and effort Progress tables. Reports discrepancies;
  never changes records, judges evidence quality, or authorizes execution.
.EXAMPLE
  .\Test-PlanConsistency.ps1 -RepositoryRoot . -Plan docs/plans/0003-developer-log-filtering-and-hiding.md
.NOTES
  Windows PowerShell 5.1. Emits one JSON object. Exit 1 on errors, 0 otherwise.
  Warnings are review items, not automatic permission to edit documentation.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = '.',
    [Parameter(Mandatory = $true)][string]$Plan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Field {
    param([string]$Content, [string]$Name)
    $escaped = [regex]::Escape($Name)
    $pattern = '(?im)^\s*(?:[-*]\s+)?(?:\*\*' + $escaped + '(?:\s*:\*\*|\*\*\s*:)|' + $escaped + '\s*:)\s*(.*?)\s*$'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('`').Trim() }
    return $null
}

function Get-MarkdownRows {
    param([string]$Section)
    $rows = @()
    foreach ($line in [regex]::Split($Section, '\r?\n')) {
        $trimmed = $line.Trim()
        if (-not ($trimmed.StartsWith('|') -and $trimmed.EndsWith('|'))) { continue }
        $cells = @($trimmed.Trim('|').Split('|') | ForEach-Object { $_.Trim().Trim('`').Trim() })
        if ($cells.Count -lt 2) { continue }
        if ((@($cells | Where-Object { $_ -notmatch '^:?-{2,}:?$' })).Count -eq 0) { continue }
        $rows += ,$cells
    }
    return $rows
}

function Get-Section {
    param([string]$Content, [string]$Heading)
    $match = [regex]::Match($Content, '(?im)^#{2,6}\s+' + [regex]::Escape($Heading) + '\s*\r?\n')
    if (-not $match.Success) { return $null }
    $level = [regex]::Match($match.Value, '^#+').Value.Length
    $start = $match.Index + $match.Length
    $remainder = $Content.Substring($start)
    $next = [regex]::Match($remainder, '(?m)^#{1,' + $level + '}\s+')
    if ($next.Success) { return $remainder.Substring(0, $next.Index) }
    return $remainder
}

$result = [ordered]@{
    plan = $null
    taskCount = 0
    indexTaskCount = 0
    effortCount = 0
    consistent = $false
    errors = @()
    warnings = @()
    checks = [ordered]@{ taskDirectory = $false; taskMetadata = $false; effortProgress = $false }
}

try {
    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $planPath = if ([System.IO.Path]::IsPathRooted($Plan)) { $Plan } else { Join-Path $root $Plan }
    $planPath = [System.IO.Path]::GetFullPath($planPath)
    $plansRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'docs/plans')).TrimEnd([char]'/', [char]'\')
    $parent = [System.IO.Path]::GetDirectoryName($planPath).TrimEnd([char]'/', [char]'\')
    if ($parent -ne $plansRoot) { throw 'Plan must be a top-level file directly in docs/plans.' }
    if (-not [System.IO.File]::Exists($planPath)) { throw "Plan not found: $Plan" }
    $index = [System.IO.File]::ReadAllText($planPath)
    if ((Get-Field $index 'Plan format') -ne 'linked-v1') { throw 'Only linked-v1 plans are supported.' }

    $reader = Join-Path $PSScriptRoot 'Get-TaskStatus.ps1'
    if (-not [System.IO.File]::Exists($reader)) { throw 'Get-TaskStatus.ps1 is missing beside this script.' }
    $global:LASTEXITCODE = 0
    $raw = & $reader -RepositoryRoot $root -Plan $planPath 2>&1
    $readerExit = $LASTEXITCODE
    $json = (@($raw) | ForEach-Object { [string]$_ }) -join "`n"
    try { $data = ConvertFrom-Json -InputObject $json -ErrorAction Stop }
    catch { throw "Get-TaskStatus.ps1 did not return valid JSON: $($_.Exception.Message)" }
    if ($null -ne $data.plan) { $result.plan = [string]$data.plan }
    if ($readerExit -ne 0 -or @($data.errors).Count -gt 0) {
        foreach ($e in @($data.errors)) { if ($e) { $result.errors += [string]$e } }
        if ($result.errors.Count -eq 0) { $result.errors += "Get-TaskStatus.ps1 exited $readerExit." }
        throw 'Task discovery failed; consistency checks were not completed.'
    }
    $tasks = @($data.tasks)
    $result.taskCount = $tasks.Count
    $byId = @{}
    foreach ($task in $tasks) {
        $id = [string]$task.id
        if ($byId.ContainsKey($id)) { $result.errors += "Duplicate task ID: $id" }
        else { $byId[$id] = $task }
        if (-not [bool]$task.valid) { $result.errors += "Invalid task record: $id" }
    }

    # Check task-directory references. Only rows with T-nn.n in the first cell count.
    $taskSection = Get-Section $index 'Task directory'
    if ($null -eq $taskSection) {
        $result.errors += 'Missing Task directory section in plan index.'
    } else {
        $listed = @{}
        foreach ($cells in @(Get-MarkdownRows $taskSection)) {
            $id = $cells[0]
            if ($id -notmatch '^T-\d+\.\d+$') { continue }
            if ($listed.ContainsKey($id)) { $result.errors += "Duplicate Task directory entry: $id" }
            else { $listed[$id] = $true }
            if (-not $byId.ContainsKey($id)) { $result.errors += "Task directory references missing task: $id" }
            if ($cells.Count -ge 3) {
                $fileRef = $cells[2]
                $mentioned = [regex]::Match($fileRef, 'T-\d+\.\d+', 'IgnoreCase')
                if ($mentioned.Success -and $mentioned.Value.ToUpperInvariant() -ne $id) {
                    $result.errors += "Task directory file reference disagrees with ID $id : $fileRef"
                }
            }
        }
        $result.indexTaskCount = $listed.Count
        foreach ($id in @($byId.Keys | Sort-Object)) {
            if (-not $listed.ContainsKey($id)) { $result.errors += "Task file not listed in Task directory: $id" }
        }
        $result.checks.taskDirectory = $true
    }

    # Validate task ID/title, explicit backlinks, owner, and Verify presence.
    foreach ($id in @($byId.Keys | Sort-Object)) {
        $task = $byId[$id]
        $fullPath = Join-Path $root ([string]$task.path).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $body = [System.IO.File]::ReadAllText($fullPath)
        $heading = [regex]::Match($body, '(?m)^#\s+(.+?)\s*$')
        if (-not $heading.Success) { $result.errors += "$id has no H1 task heading." }
        elseif ($heading.Groups[1].Value -notmatch ('(?i)\b' + [regex]::Escape($id) + '\b')) {
            $result.errors += "$id heading does not contain its task ID."
        }
        if ([string]::IsNullOrWhiteSpace([string]$task.owner)) { $result.errors += "$id is missing Owner." }
        $verifyField = Get-Field $body 'Verify'
        $verifySection = Get-Section $body 'Verify'
        if ([string]::IsNullOrWhiteSpace($verifyField) -and [string]::IsNullOrWhiteSpace($verifySection)) {
            $result.errors += "$id has no Verify field or section."
        }
        $backlink = Get-Field $body 'Plan'
        if ($backlink) {
            $expectedBase = [System.IO.Path]::GetFileNameWithoutExtension($planPath)
            if ($backlink -notmatch [regex]::Escape($expectedBase)) {
                $result.warnings += "$id Plan backlink may not reference the selected index: $backlink"
            }
        }
        if ([string]$task.status -eq 'done') {
            $outcome = Get-Section $body 'Current outcome'
            if ([string]::IsNullOrWhiteSpace($outcome)) {
                $result.warnings += "$id is done but has no nonempty Current outcome section; inspect evidence manually."
            }
        }
    }
    $result.checks.taskMetadata = $true

    # Compare E-nn Progress table totals with task files grouped by the ID prefix.
    $progress = Get-Section $index 'Progress'
    if ($null -eq $progress) {
        $result.warnings += 'No Progress section found; effort summary was not checked.'
    } else {
        $effortRows = @()
        foreach ($cells in @(Get-MarkdownRows $progress)) {
            if ($cells[0] -match '^E-\d+$' -and $cells.Count -ge 5) { $effortRows += ,$cells }
        }
        if ($effortRows.Count -eq 0) {
            $result.warnings += 'No parseable Effort/Title/Tasks/Done/Status table found in Progress; effort totals were not checked.'
        } else {
            $result.effortCount = $effortRows.Count
            $seenEfforts = @{}
            foreach ($cells in $effortRows) {
                $effort = $cells[0]
                if ($seenEfforts.ContainsKey($effort)) { $result.errors += "Duplicate Progress effort row: $effort" }
                $seenEfforts[$effort] = $true
                $effortNumber = [int]($effort.Substring(2))
                $group = @($tasks | Where-Object { $_.id -match '^T-(\d+)\.' -and [int]$Matches[1] -eq $effortNumber })
                $done = @($group | Where-Object { $_.status -eq 'done' }).Count
                if ($cells[2] -match '^\d+$') {
                    if ([int]$cells[2] -ne $group.Count) { $result.errors += "$effort Tasks count: index $($cells[2]), files $($group.Count)." }
                } else { $result.warnings += "$effort Tasks count is not numeric: $($cells[2])" }
                if ($cells[3] -match '^\d+$') {
                    if ([int]$cells[3] -ne $done) { $result.errors += "$effort Done count: index $($cells[3]), files $done." }
                } else { $result.warnings += "$effort Done count is not numeric: $($cells[3])" }
                $effortStatus = $cells[4].ToLowerInvariant()
                if ($effortStatus -eq 'done' -and @($group | Where-Object { $_.status -notin @('done','cancelled') }).Count -gt 0) {
                    $result.errors += "$effort marked done but contains unfinished tasks."
                }
            }
            foreach ($task in $tasks) {
                $match = [regex]::Match([string]$task.id, '^T-(\d+)\.')
                if ($match.Success) {
                    $effortId = 'E-{0:D2}' -f [int]$match.Groups[1].Value
                    if (-not $seenEfforts.ContainsKey($effortId)) { $result.errors += "Task $($task.id) has no Progress row for $effortId." }
                }
            }
            $result.checks.effortProgress = $true
        }
    }
} catch {
    if ($_.Exception.Message -ne 'Task discovery failed; consistency checks were not completed.') {
        $result.errors += $_.Exception.Message
    }
}
$result.consistent = ($result.errors.Count -eq 0 -and $result.warnings.Count -eq 0 -and $result.checks.taskDirectory -and $result.checks.taskMetadata -and $result.checks.effortProgress)
$result | ConvertTo-Json -Depth 12 -Compress
if ($result.errors.Count -gt 0) { exit 1 }
