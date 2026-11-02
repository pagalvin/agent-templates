#requires -Version 5.1
<#
.SYNOPSIS
  Read-only dependency graph checks for a linked-v1 implementation plan.
.DESCRIPTION
  Calls the sibling Get-TaskStatus.ps1 to read authoritative task metadata.
  Reports missing references, cycles, inconsistent completed tasks, and
  mechanically dependency-ready pending tasks. Does not assess effort gates,
  evidence quality, governance approval, or execution authorization.
.EXAMPLE
  .\Test-PlanDependencies.ps1 -RepositoryRoot . -Plan docs/plans/0003-developer-log-filtering-and-hiding.md
.NOTES
  Emits exactly one JSON object. Compatible with Windows PowerShell 5.1.
  Does not modify files. Exit code 1 indicates errors; warnings do not fail.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = '.',
    [Parameter(Mandatory = $true)][string]$Plan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$result = [ordered]@{
    plan = $null
    taskCount = 0
    dependencyReady = @()
    waiting = @()
    inProgress = @()
    completed = @()
    blocked = @()
    cancelled = @()
    errors = @()
    warnings = @()
}

try {
    $reader = Join-Path $PSScriptRoot 'Get-TaskStatus.ps1'
    if (-not [System.IO.File]::Exists($reader)) {
        throw 'Get-TaskStatus.ps1 must exist beside Test-PlanDependencies.ps1.'
    }

    # A PowerShell script that completes without `exit` may leave LASTEXITCODE
    # unchanged from an earlier native command. Reset it before invocation.
    $global:LASTEXITCODE = 0
    $raw = & $reader -RepositoryRoot $RepositoryRoot -Plan $Plan 2>&1
    $readerExit = $LASTEXITCODE
    $json = ($raw | ForEach-Object { [string]$_ }) -join "`n"
    try { $data = ConvertFrom-Json -InputObject $json -ErrorAction Stop }
    catch { throw "Get-TaskStatus.ps1 did not return valid JSON: $($_.Exception.Message)" }
    if ($null -ne $data.plan) { $result.plan = [string]$data.plan }
    if ($readerExit -ne 0 -or @($data.errors).Count -gt 0) {
        foreach ($problem in @($data.errors)) { if ($problem) { $result.errors += [string]$problem } }
        if ($result.errors.Count -eq 0) { $result.errors += "Get-TaskStatus.ps1 failed with exit code $readerExit." }
    } else {
        $tasks = @($data.tasks)
        $result.taskCount = $tasks.Count
        $byId = @{}
        foreach ($task in $tasks) {
            $id = [string]$task.id
            if ($byId.ContainsKey($id)) {
                $result.errors += "Duplicate task ID: $id"
            } else {
                $byId[$id] = $task
            }
            if (-not [bool]$task.valid) {
                $result.errors += "Invalid task record: $id"
            }
        }

        # Validate references and detect graph cycles with a depth-first traversal.
        $adj = @{}
        foreach ($id in @($byId.Keys)) {
            $task = $byId[$id]
            $deps = @()
            foreach ($dep in @($task.dependencies)) {
                $depId = [string]$dep
                if ($depId -eq $id) {
                    $result.errors += "Self-dependency: $id"
                } elseif (-not $byId.ContainsKey($depId)) {
                    $result.errors += "Missing dependency: $id references $depId"
                } else {
                    $deps += $depId
                }
            }
            $adj[$id] = @($deps | Select-Object -Unique)
        }

        $colors = @{}
        $reportedCycles = @{}
        function Visit-Dependency {
            param([string]$Id, [string[]]$Trail)
            $colors[$Id] = 1
            $path = @($Trail) + @($Id)
            foreach ($dep in @($adj[$Id])) {
                if (-not $colors.ContainsKey($dep)) {
                    Visit-Dependency -Id $dep -Trail $path
                } elseif ($colors[$dep] -eq 1) {
                    $start = [array]::IndexOf($path, $dep)
                    $cycle = if ($start -ge 0) { @($path[$start..($path.Count - 1)]) + @($dep) } else { @($Id, $dep) }
                    $signature = $cycle -join ' -> '
                    if (-not $reportedCycles.ContainsKey($signature)) {
                        $reportedCycles[$signature] = $true
                        $result.errors += "Dependency cycle: $signature"
                    }
                }
            }
            $colors[$Id] = 2
        }
        foreach ($id in @($byId.Keys | Sort-Object)) {
            if (-not $colors.ContainsKey($id)) { Visit-Dependency -Id $id -Trail @() }
        }

        foreach ($id in @($byId.Keys | Sort-Object)) {
            $task = $byId[$id]
            $status = [string]$task.status
            $unmet = @()
            $cancelledDeps = @()
            foreach ($dep in @($task.dependencies)) {
                $depId = [string]$dep
                if (-not $byId.ContainsKey($depId)) {
                    $unmet += $depId
                    continue
                }
                $depStatus = [string]$byId[$depId].status
                if ($depStatus -eq 'cancelled') {
                    $cancelledDeps += $depId
                    $unmet += $depId
                } elseif ($depStatus -ne 'done') {
                    $unmet += $depId
                }
            }
            if ($cancelledDeps.Count -gt 0) {
                $result.warnings += "$id depends on cancelled task(s): $($cancelledDeps -join ', '). Manual rationale review required."
            }
            if ($status -eq 'done' -and $unmet.Count -gt 0) {
                $result.errors += "Completed task $id has unfinished or unverified prerequisite(s): $($unmet -join ', ')"
            }
            switch ($status) {
                'pending' {
                    if ($unmet.Count -eq 0) {
                        $result.dependencyReady += $id
                    } else {
                        $result.waiting += [pscustomobject]@{ id = $id; unmetDependencies = @($unmet) }
                    }
                }
                'in-progress' { $result.inProgress += $id }
                'done'        { $result.completed += $id }
                'blocked'     { $result.blocked += $id }
                'cancelled'   { $result.cancelled += $id }
            }
        }
        # A malformed dependency graph must never be presented as ready for dispatch.
        if ($result.errors.Count -gt 0) { $result.dependencyReady = @() }
    }
} catch {
    $result.errors += $_.Exception.Message
    $result.dependencyReady = @()
}

$result | ConvertTo-Json -Depth 12 -Compress
if ($result.errors.Count -gt 0) { exit 1 }
