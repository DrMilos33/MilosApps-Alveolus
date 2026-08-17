param(
    [string]$GodotPath = 'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe',
    [switch]$FullSoak,
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $projectRoot '.codex-temp\test-reports\technical-regression-latest.json'
}

$runs = @(
	@{ name = 'ability_pipeline'; script = 'res://tests/ability_pipeline_runner.gd'; args = @() },
	@{ name = 'ability_stress'; script = 'res://tests/ability_stress_regression_runner.gd'; args = @('--quick-run') },
    @{ name = 'runtime_architecture'; script = 'res://tests/runtime_architecture_runner.gd'; args = @() },
    @{ name = 'quality_determinism'; script = 'res://tests/quality_determinism_runner.gd'; args = @() },
    @{ name = 'render_stress_telemetry'; script = 'res://tests/render_stress_telemetry_runner.gd'; args = @() },
    @{ name = 'browser_soak_harness_static'; script = 'res://tests/browser_soak_harness_static_runner.gd'; args = @() },
    @{ name = 'runtime_churn'; script = 'res://tests/runtime_churn_regression_runner.gd'; args = @() },
    @{ name = 'enemy_deferred_reuse'; script = 'res://tests/enemy_deferred_reuse_regression_runner.gd'; args = @() },
    @{ name = 'spawn_lifecycle'; script = 'res://tests/spawn_lifecycle_regression_runner.gd'; args = @('--quick-run') },
    @{ name = 'crowd_renderer'; script = 'res://tests/crowd_renderer_regression_runner.gd'; args = @('--quick-run') },
    @{ name = 'projectile_renderer'; script = 'res://tests/projectile_renderer_regression_runner.gd'; args = @('--quick-run') },
    @{ name = 'feedback_renderer'; script = 'res://tests/feedback_renderer_regression_runner.gd'; args = @('--quick-run') },
    @{ name = 'arena_backdrop_bake'; script = 'res://tests/arena_backdrop_bake_runner.gd'; args = @() },
    @{ name = 'performance'; script = 'res://tests/performance_runner.gd'; args = @('--quick-run') },
    @{ name = 'performance_soak'; script = 'res://tests/performance_soak_runner.gd'; args = @('--quick-run') }
)
if ($FullSoak) {
    $runs[-1].args += '--soak-full'
}

$results = @()
$failed = $false
foreach ($run in $runs) {
    Write-Host "`n=== $($run.name) ==="
    $arguments = @('--headless', '--path', $projectRoot, '--script', $run.script)
    if ($run.args.Count -gt 0) {
        $arguments += '--'
        $arguments += $run.args
    }
    $started = Get-Date
    $lines = @(& $GodotPath @arguments 2>&1 | ForEach-Object { $_.ToString(); Write-Host $_ })
    $exitCode = $LASTEXITCODE
    $durationMs = ((Get-Date) - $started).TotalMilliseconds
    $jsonPayloads = @()
    foreach ($line in $lines) {
        if ($line -match '^ALVEOLUS_[A-Z0-9_]+_JSON=(.+)$') {
            try {
                $jsonPayloads += ($Matches[1] | ConvertFrom-Json -Depth 32)
            }
            catch {
                $jsonPayloads += @{ parse_error = $_.Exception.Message; raw = $Matches[1] }
            }
        }
    }
    if ($exitCode -ne 0) {
        $failed = $true
    }
    $results += @{
        name = $run.name
        script = $run.script
        exit_code = $exitCode
        duration_ms = $durationMs
        metrics = $jsonPayloads
        tail = @($lines | Select-Object -Last 20)
    }
}

$report = @{
    schema = 'alveolus.technical_regression_suite.v1'
    generated_utc = [DateTime]::UtcNow.ToString('o')
    project_root = $projectRoot
    godot = $GodotPath
    full_soak = [bool]$FullSoak
    passed = -not $failed
    runs = $results
}
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$report | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ReportPath -Encoding utf8
Write-Host "`nALVEOLUS_TECHNICAL_SUITE_JSON=$($report | ConvertTo-Json -Depth 32 -Compress)"
Write-Host "Report: $ReportPath"
exit $(if ($failed) { 1 } else { 0 })
