[CmdletBinding()]
param(
    [ValidateSet('Docs', 'Quick', 'Flow', 'UI', 'Combat', 'Runtime', 'Performance', 'Full')]
    [string]$Profile = 'Quick',
    [string]$GodotPath = 'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe',
    [string]$GitPath = 'C:\Users\pasca\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe',
    [string]$ReportPath = '',
    [switch]$List,
    [switch]$Visual,
    [switch]$FullSoak,
    [switch]$BuildWeb
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

$tests = [ordered]@{
    core = @{ script = 'res://tests/test_runner.gd'; args = @() }
    flow = @{ script = 'res://tests/flow_runner.gd'; args = @('--quick-run') }
    intro = @{ script = 'res://tests/intro_runner.gd'; args = @('--quick-run') }
    tactical_flow = @{ script = 'res://tests/tactical_flow_runner.gd'; args = @() }
    meta_save = @{ script = 'res://tests/meta_loadout_v4_runner.gd'; args = @() }
    loadout_navigation = @{ script = 'res://tests/ui_navigation_loadout_runner.gd'; args = @() }
    style_gallery = @{ script = 'res://tests/style_gallery_runner.gd'; args = @() }
    ui_polish = @{ script = 'res://tests/ui_polish_runner.gd'; args = @() }
    ui_accessibility = @{ script = 'res://tests/ui_accessibility_layout_runner.gd'; args = @() }
    campus = @{ script = 'res://tests/campus_layout_runner.gd'; args = @() }
    lexicon_catalog = @{ script = 'res://tests/lexicon_catalog_runner.gd'; args = @() }
    lexicon_stats = @{ script = 'res://tests/lexicon_stats_runner.gd'; args = @() }
    lexicon_view = @{ script = 'res://tests/lexicon_master_detail_runner.gd'; args = @() }
    tactical_ui = @{ script = 'res://tests/tactical_ui_runner.gd'; args = @() }
    ui_audio_settings = @{ script = 'res://tests/ui_audio_settings_runner.gd'; args = @() }
    ui_settings_hud = @{ script = 'res://tests/ui_settings_hud_integration_runner.gd'; args = @() }
    combat = @{ script = 'res://tests/combat_foundation_runner.gd'; args = @() }
    upgrades = @{ script = 'res://tests/run_upgrade_runner.gd'; args = @() }
    passives_talents = @{ script = 'res://tests/passive_talent_completion_runner.gd'; args = @() }
    ability_pipeline = @{ script = 'res://tests/ability_pipeline_runner.gd'; args = @() }
    determinism = @{ script = 'res://tests/quality_determinism_runner.gd'; args = @() }
    runtime_architecture = @{ script = 'res://tests/runtime_architecture_runner.gd'; args = @() }
    runtime_churn = @{ script = 'res://tests/runtime_churn_regression_runner.gd'; args = @() }
    enemy_reuse = @{ script = 'res://tests/enemy_deferred_reuse_regression_runner.gd'; args = @() }
    spawn_lifecycle = @{ script = 'res://tests/spawn_lifecycle_regression_runner.gd'; args = @('--quick-run') }
    crowd_renderer = @{ script = 'res://tests/crowd_renderer_regression_runner.gd'; args = @('--quick-run') }
    projectile_renderer = @{ script = 'res://tests/projectile_renderer_regression_runner.gd'; args = @('--quick-run') }
    feedback_renderer = @{ script = 'res://tests/feedback_renderer_regression_runner.gd'; args = @('--quick-run') }
    arena_backdrop = @{ script = 'res://tests/arena_backdrop_bake_runner.gd'; args = @() }
    render_telemetry = @{ script = 'res://tests/render_stress_telemetry_runner.gd'; args = @() }
    browser_harness = @{ script = 'res://tests/browser_soak_harness_static_runner.gd'; args = @() }
    ability_stress = @{ script = 'res://tests/ability_stress_regression_runner.gd'; args = @('--quick-run') }
    performance = @{ script = 'res://tests/performance_runner.gd'; args = @('--quick-run') }
    performance_soak = @{ script = 'res://tests/performance_soak_runner.gd'; args = @('--quick-run') }
}

$groups = [ordered]@{
    Quick = @('core')
    Flow = @('core', 'flow', 'intro', 'tactical_flow', 'meta_save', 'loadout_navigation', 'ui_audio_settings')
    UI = @('style_gallery', 'ui_polish', 'ui_accessibility', 'campus', 'lexicon_catalog', 'lexicon_stats', 'lexicon_view', 'tactical_ui', 'loadout_navigation', 'ui_audio_settings', 'ui_settings_hud')
    Combat = @('core', 'combat', 'upgrades', 'passives_talents', 'ability_pipeline', 'tactical_flow', 'determinism')
    Runtime = @('runtime_architecture', 'runtime_churn', 'enemy_reuse', 'spawn_lifecycle', 'crowd_renderer', 'projectile_renderer', 'feedback_renderer', 'arena_backdrop', 'render_telemetry', 'browser_harness', 'determinism')
    Performance = @('ability_stress', 'performance', 'performance_soak')
}

if ($List) {
    Write-Host 'ALVEOLUS validation profiles'
    Write-Host '  Docs        Diff check only; no Godot process.'
    foreach ($name in $groups.Keys) {
        Write-Host ("  {0,-11} {1}" -f $name, ($groups[$name] -join ', '))
    }
    Write-Host '  Full        Union of every profile above, without duplicate runners.'
    Write-Host ''
    Write-Host 'Optional: -Visual, -FullSoak, -BuildWeb'
    return
}

if (-not (Test-Path -LiteralPath $GitPath)) {
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        throw "Git executable not found: $GitPath"
    }
    $GitPath = $gitCommand.Source
}

Write-Host '=== diff check ==='
& $GitPath -C $projectRoot diff --check
if ($LASTEXITCODE -ne 0) {
    throw 'git diff --check failed.'
}

if ($Profile -eq 'Docs') {
    Write-Host 'ALVEOLUS_CHECKS_OK profile=Docs runtime_tests=0'
    return
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $projectRoot '.codex-temp\test-reports\validation-latest.json'
}

$selected = @()
$requestedGroups = if ($Profile -eq 'Full') { @($groups.Keys) } else { @($Profile) }
foreach ($groupName in $requestedGroups) {
    foreach ($testName in $groups[$groupName]) {
        if ($selected -notcontains $testName) {
            $selected += $testName
        }
    }
}

Write-Host '=== project parse ==='
& $GodotPath --headless --editor --path $projectRoot --quit
if ($LASTEXITCODE -ne 0) {
    throw 'Godot project parse failed.'
}

$results = @()
$failed = $false
foreach ($testName in $selected) {
    $definition = $tests[$testName]
    $testArgs = @($definition.args)
    if ($testName -eq 'performance_soak' -and $FullSoak) {
        $testArgs += '--soak-full'
    }
    $arguments = @('--headless', '--path', $projectRoot, '--script', $definition.script)
    if ($testArgs.Count -gt 0) {
        $arguments += '--'
        $arguments += $testArgs
    }
    Write-Host "`n=== $testName ==="
    $started = Get-Date
    # Godot writes expected engine warnings to stderr. Windows PowerShell turns
    # redirected native stderr into non-terminating ErrorRecords; under the
    # script-wide Stop policy those used to abort a green runner before its
    # process exit code could be evaluated.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lines = @(& $GodotPath @arguments 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        $line
    })
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    $durationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 1)
    if ($exitCode -ne 0) {
        $failed = $true
    }
    $results += @{
        name = $testName
        script = $definition.script
        exit_code = $exitCode
        duration_ms = $durationMs
        tail = @($lines | Select-Object -Last 12)
    }
    if ($failed) {
        break
    }
}

if (-not $failed -and $Visual) {
    Write-Host "`n=== visual capture ==="
    $started = Get-Date
    $visualLines = @()
    $exitCode = 0
    $visualSetups = @(
        @{ size = '1280x720'; scale = '1.0'; suffix = '1280x720' },
        @{ size = '1280x800'; scale = '1.0'; suffix = '1280x800' },
        @{ size = '1024x576'; scale = '1.0'; suffix = '1024x576' },
        @{ size = '960x540'; scale = '1.0'; suffix = '960x540' },
        @{ size = '1280x720'; scale = '2.0'; suffix = '1280x720_200' },
        @{ size = '1280x800'; scale = '2.0'; suffix = '1280x800_200' },
        @{ size = '1024x576'; scale = '2.0'; suffix = '1024x576_200' },
        @{ size = '960x540'; scale = '2.0'; suffix = '960x540_200' }
    )
    foreach ($setup in $visualSetups) {
        Write-Host ("`n--- {0} at {1} % ---" -f $setup.size, ([double]$setup.scale * 100))
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $runLines = @(& $GodotPath --resolution $setup.size --path $projectRoot --script res://tests/visual_capture_runner.gd -- `
            "--capture-size=$($setup.size)" "--capture-scale=$($setup.scale)" "--capture-suffix=$($setup.suffix)" 2>&1 | ForEach-Object {
                $line = $_.ToString()
                Write-Host $line
                $line
            })
        $visualExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        $visualLines += $runLines
        if ($visualExitCode -ne 0) {
            $exitCode = $visualExitCode
            break
        }
    }
    $durationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 1)
    $captureDirectory = Join-Path $projectRoot '.codex-temp\visual_restart\screens'
    $captureCount = if (Test-Path -LiteralPath $captureDirectory) {
        @(Get-ChildItem -LiteralPath $captureDirectory -Filter '*.png' | Where-Object {
            $_.LastWriteTime -ge $started.AddSeconds(-1)
        }).Count
    } else { 0 }
    $completionMarker = @($visualLines | Where-Object { $_ -like 'ALVEOLUS_VISUAL_CAPTURE_OK*' }).Count -eq $visualSetups.Count
    $minimumCaptureCount = $visualSetups.Count * 21
    if ($exitCode -ne 0 -or -not $completionMarker -or $captureCount -lt $minimumCaptureCount) {
        $failed = $true
    }
    $results += @{
        name = 'visual_capture'
        script = 'res://tests/visual_capture_runner.gd'
        exit_code = $exitCode
        duration_ms = $durationMs
        screenshot_count = $captureCount
        completion_marker = $completionMarker
        tail = @($visualLines | Select-Object -Last 12)
    }
}

if (-not $failed -and $BuildWeb) {
    Write-Host "`n=== web export ==="
    $buildDirectory = Join-Path $projectRoot 'build\web'
    New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
    $started = Get-Date
    & $GodotPath --headless --path $projectRoot --export-release Web (Join-Path $buildDirectory 'index.html')
    $exitCode = $LASTEXITCODE
    $durationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 1)
    if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $buildDirectory 'index.html'))) {
        $failed = $true
    }
    $results += @{
        name = 'web_export'
        exit_code = $exitCode
        duration_ms = $durationMs
    }
}

$report = @{
    schema = 'alveolus.validation.v1'
    generated_utc = [DateTime]::UtcNow.ToString('o')
    profile = $Profile
    full_soak = [bool]$FullSoak
    visual = [bool]$Visual
    web_export = [bool]$BuildWeb
    passed = -not $failed
    runs = $results
}
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $ReportPath -Encoding utf8

Write-Host "`nReport: $ReportPath"
if ($failed) {
    Write-Error "ALVEOLUS_CHECKS_FAILED profile=$Profile"
    exit 1
}
Write-Host "ALVEOLUS_CHECKS_OK profile=$Profile tests=$($results.Count)"
