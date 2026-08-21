[CmdletBinding()]
param(
    [string]$PythonPath = 'python'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rolloverHook = Join-Path $projectRoot '.codex\hooks\user_prompt_rollover.ps1'
$localOnlyHook = Join-Path $projectRoot '.codex\hooks\pre_tool_local_only.ps1'
$mediaScript = Join-Path $projectRoot '.agents\skills\alveolus-change-workflow\scripts\prepare_feedback_media.py'
$fixtureRoot = Join-Path $projectRoot ('.codex-temp\reports\codex-workflow-fixture-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

$script:Assertions = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Test-Condition {
    param([bool]$Condition, [string]$Message)
    $script:Assertions += 1
    if (-not $Condition) {
        $script:Failures.Add($Message)
    }
}

function New-SizedFile {
    param([string]$Path, [long]$Length)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try {
        $stream.SetLength($Length)
    } finally {
        $stream.Dispose()
    }
}

function Invoke-Hook {
    param([string]$ScriptPath, [string]$InputJson)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    $startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()
    $process.StandardInput.Write($InputJson)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return @{
        exit_code = $process.ExitCode
        stdout = $stdout.Trim().Trim([char]0xFEFF)
        stderr = $stderr.Trim().Trim([char]0xFEFF)
    }
}

function Convert-HookOutput {
    param([string]$Output)
    if ([string]::IsNullOrWhiteSpace($Output)) {
        return $null
    }
    return $Output | ConvertFrom-Json -ErrorAction Stop
}

function New-PromptPayload {
    param([AllowNull()] [string]$TranscriptPath, [string]$Prompt = 'Weiterarbeiten')
    $payload = @{
        session_id = 'fixture-session'
        transcript_path = $TranscriptPath
        cwd = $projectRoot
        hook_event_name = 'UserPromptSubmit'
        model = 'fixture-model'
        turn_id = 'fixture-turn'
        permission_mode = 'default'
        prompt = $Prompt
    }
    return ($payload | ConvertTo-Json -Compress -Depth 8)
}

function New-ToolPayload {
    param([string]$ToolName, [object]$ToolInput)
    $payload = @{
        session_id = 'fixture-session'
        transcript_path = $null
        cwd = $projectRoot
        hook_event_name = 'PreToolUse'
        model = 'fixture-model'
        turn_id = 'fixture-turn'
        permission_mode = 'default'
        tool_name = $ToolName
        tool_use_id = 'fixture-tool'
        tool_input = $ToolInput
    }
    return ($payload | ConvertTo-Json -Compress -Depth 12)
}

function Test-PromptHook {
    $belowSoft = Join-Path $fixtureRoot 'below-soft.jsonl'
    $atSoft = Join-Path $fixtureRoot 'at-soft.jsonl'
    $belowHard = Join-Path $fixtureRoot 'below-hard.jsonl'
    $atHard = Join-Path $fixtureRoot 'at-hard.jsonl'
    New-SizedFile $belowSoft ((20L * 1024L * 1024L) - 1L)
    New-SizedFile $atSoft (20L * 1024L * 1024L)
    New-SizedFile $belowHard ((40L * 1024L * 1024L) - 1L)
    New-SizedFile $atHard (40L * 1024L * 1024L)

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $belowSoft)
    Test-Condition ($result.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($result.stdout)) '20 MiB minus one byte continues without hook context.'

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atSoft)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($result.exit_code -eq 0 -and $output.systemMessage -match '20') 'Exactly 20 MiB emits the rollover warning.'
    Test-Condition ([string]$output.decision -ne 'block') 'The 20 MiB warning does not block the prompt.'

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $belowHard)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($result.exit_code -eq 0 -and $output.systemMessage -match 'rollover') '40 MiB minus one byte still warns and continues.'

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atHard)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($output.decision -eq 'block' -and $output.reason -match '40 MiB') 'Exactly 40 MiB blocks a normal prompt.'

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atHard 'ALVEOLUS-ROLLOVER')
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($result.exit_code -eq 0 -and $output.hookSpecificOutput.additionalContext -match 'ALVEOLUS-HANDOFF-v2') 'The rollover marker allows a text-only Handoff at 40 MiB.'

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atHard '  alveolus-rollover kompakt fortsetzen')
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($result.exit_code -eq 0 -and $output.hookSpecificOutput.additionalContext -match 'Do not call tools') 'A prompt beginning with the marker is allowed case-insensitively.'

    $result = Invoke-Hook $rolloverHook (New-PromptPayload $null)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($result.exit_code -eq 0 -and $output.systemMessage -match 'unavailable') 'A missing transcript path fails open with a warning.'

    $result = Invoke-Hook $rolloverHook '{invalid json'
    Test-Condition ($result.exit_code -eq 2 -and $result.stderr -match 'hook failed') 'Invalid hook JSON exits with code 2 and a concise reason.'
}

function Test-LocalOnlyHook {
    foreach ($command in @(
        'git status --short',
        'git diff --check',
        'git commit -m "local checkpoint"',
        'python -m http.server 8766 --bind 127.0.0.1',
        '.\tests\run_checks.ps1 -Profile Quick'
    )) {
        $result = Invoke-Hook $localOnlyHook (New-ToolPayload 'Bash' @{ command = $command })
        Test-Condition ($result.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($result.stdout)) "Local command remains allowed: $command"
    }

    foreach ($command in @(
        'git push origin main',
        'git status; git push origin main',
        'git -C . push origin main',
        'pwsh -Command "git push origin main"',
        'cmd /c "git push origin main"',
        'gh pr create --title test',
        'gh release upload v1 build.zip',
        'docker push example/alveolus:latest',
        'npm publish',
        'npm run deploy',
        'curl -X POST https://example.invalid/upload',
        'Invoke-RestMethod https://example.invalid -Method POST',
        'scp build.zip user@example.invalid:/tmp/'
    )) {
        $result = Invoke-Hook $localOnlyHook (New-ToolPayload 'Bash' @{ command = $command })
        $output = Convert-HookOutput $result.stdout
        Test-Condition ($output.hookSpecificOutput.permissionDecision -eq 'deny') "Remote command is denied: $command"
    }

    $patchResult = Invoke-Hook $localOnlyHook (New-ToolPayload 'apply_patch' @{ command = 'Documentation example: git push origin main' })
    Test-Condition ($patchResult.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($patchResult.stdout)) 'Patch text mentioning git push is not mistaken for a shell command.'

    $readResult = Invoke-Hook $localOnlyHook (New-ToolPayload 'mcp__github__get_pull_request' @{ owner = 'local'; repo = 'fixture' })
    Test-Condition ($readResult.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($readResult.stdout)) 'Read-only GitHub MCP calls remain allowed.'

    $writeResult = Invoke-Hook $localOnlyHook (New-ToolPayload 'mcp__github__create_pull_request' @{ owner = 'local'; repo = 'fixture' })
    $writeOutput = Convert-HookOutput $writeResult.stdout
    Test-Condition ($writeOutput.hookSpecificOutput.permissionDecision -eq 'deny') 'GitHub PR creation is denied.'
}

function Test-MediaPreparation {
    $fixtureScript = Join-Path $fixtureRoot 'create_fixture.py'
    $gifPath = Join-Path $fixtureRoot 'crowd.gif'
    $outputDir = Join-Path $fixtureRoot 'prepared'
    $fixtureSource = @'
from pathlib import Path
from PIL import Image, ImageDraw
import sys

target = Path(sys.argv[1])
frames = []
for index in range(12):
    image = Image.new("RGB", (320, 180), (6 + index * 5, 20, 28))
    draw = ImageDraw.Draw(image)
    draw.ellipse((20 + index * 8, 45, 110 + index * 8, 135), fill=(220, 80 + index * 5, 70))
    draw.text((12, 12), f"frame {index}", fill=(235, 245, 240))
    frames.append(image)
frames[0].save(target, save_all=True, append_images=frames[1:], duration=100, loop=0)
'@
    [IO.File]::WriteAllText($fixtureScript, $fixtureSource, [Text.UTF8Encoding]::new($false))
    & $PythonPath $fixtureScript $gifPath
    Test-Condition ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $gifPath)) 'Synthetic GIF fixture was created.'
    $hashBefore = (Get-FileHash -LiteralPath $gifPath -Algorithm SHA256).Hash
    & $PythonPath $mediaScript $gifPath --case 'workflow-fixture' --output-dir $outputDir | Out-Null
    Test-Condition ($LASTEXITCODE -eq 0) 'GIF preparation script completed successfully.'
    $hashAfter = (Get-FileHash -LiteralPath $gifPath -Algorithm SHA256).Hash
    Test-Condition ($hashBefore -eq $hashAfter) 'GIF preparation preserves the original source bytes.'
    $frames = @(Get-ChildItem -LiteralPath $outputDir -Filter 'frame_*.png')
    Test-Condition ($frames.Count -gt 0 -and $frames.Count -le 6) 'GIF preparation creates at most six selected PNG frames.'
    Test-Condition (Test-Path -LiteralPath (Join-Path $outputDir 'contact_sheet.png')) 'GIF preparation creates a contact sheet.'
    Test-Condition (Test-Path -LiteralPath (Join-Path $outputDir 'manifest.md')) 'GIF preparation creates a text manifest.'
    $previewBytes = ($frames | Measure-Object -Property Length -Sum).Sum + (Get-Item -LiteralPath (Join-Path $outputDir 'contact_sheet.png')).Length
    Test-Condition ($previewBytes -le 8MB) 'Prepared media remains at or below eight MiB.'
}

try {
    $null = Get-Content -LiteralPath (Join-Path $projectRoot '.codex\hooks.json') -Raw | ConvertFrom-Json -ErrorAction Stop
    Test-Condition $true 'hooks.json parses.'
    Test-PromptHook
    Test-LocalOnlyHook
    Test-MediaPreparation
} catch {
    $script:Failures.Add("Unhandled fixture error: $($_.Exception.Message)")
}

if ($script:Failures.Count -eq 0) {
    Write-Host "ALVEOLUS_CODEX_WORKFLOW_OK assertions=$script:Assertions artifacts=$fixtureRoot"
    exit 0
}

foreach ($failure in $script:Failures) {
    [Console]::Error.WriteLine($failure)
}
Write-Host "ALVEOLUS_CODEX_WORKFLOW_FAILED assertions=$script:Assertions failures=$($script:Failures.Count) artifacts=$fixtureRoot"
exit 1
