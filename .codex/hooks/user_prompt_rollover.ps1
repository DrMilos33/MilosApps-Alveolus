Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$SoftLimitBytes = 20L * 1024L * 1024L
$HardLimitBytes = 40L * 1024L * 1024L
$RolloverPrefix = 'ALVEOLUS-ROLLOVER'

function Write-HookJson {
    param([Parameter(Mandatory = $true)] [hashtable]$Value)
    [Console]::Out.WriteLine(($Value | ConvertTo-Json -Compress -Depth 8))
}

function Write-UnavailableWarning {
    param([string]$Reason)
    Write-HookJson @{
        systemMessage = "ALVEOLUS task-size check unavailable: $Reason"
        hookSpecificOutput = @{
            hookEventName = 'UserPromptSubmit'
            additionalContext = 'Continue cautiously. The local transcript size could not be verified; keep this task text-only and prepare a compact rollover if context is already large.'
        }
    }
}

try {
    $rawJson = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
    if ([string]::IsNullOrWhiteSpace($rawJson)) {
        throw 'Hook input is empty.'
    }
    $payload = $rawJson | ConvertFrom-Json -ErrorAction Stop
    $eventProperty = $payload.PSObject.Properties['hook_event_name']
    if ($null -eq $eventProperty -or [string]$eventProperty.Value -ne 'UserPromptSubmit') {
        throw 'Unexpected hook_event_name.'
    }

    $promptProperty = $payload.PSObject.Properties['prompt']
    $prompt = if ($null -ne $promptProperty) { [string]$promptProperty.Value } else { '' }
    $isRollover = $prompt.TrimStart().StartsWith($RolloverPrefix, [StringComparison]::OrdinalIgnoreCase)
    if ($isRollover) {
        Write-HookJson @{
            systemMessage = 'ALVEOLUS rollover mode.'
            hookSpecificOutput = @{
                hookEventName = 'UserPromptSubmit'
                additionalContext = 'Do not call tools or continue implementation. Respond only with one compact, text-only ALVEOLUS-HANDOFF-v2 containing outcome/status, exact base and local commit, file lease, changed contracts, checks, local artifact paths, open points, and Remote: keine. Include no media, raw logs, capture lists, or repeated project history.'
            }
        }
        exit 0
    }

    $transcriptProperty = $payload.PSObject.Properties['transcript_path']
    $transcriptPath = if ($null -ne $transcriptProperty) { [string]$transcriptProperty.Value } else { '' }
    if ([string]::IsNullOrWhiteSpace($transcriptPath)) {
        Write-UnavailableWarning 'transcript_path is missing.'
        exit 0
    }
    if (-not (Test-Path -LiteralPath $transcriptPath -PathType Leaf)) {
        Write-UnavailableWarning 'transcript file does not exist.'
        exit 0
    }

    $length = (Get-Item -LiteralPath $transcriptPath -ErrorAction Stop).Length
    if ($length -ge $HardLimitBytes) {
        Write-HookJson @{
            decision = 'block'
            reason = 'ALVEOLUS task transcript is at least 40 MiB. Send a prompt beginning with ALVEOLUS-ROLLOVER without attachments to obtain a text-only handoff, then continue in a new task.'
        }
        exit 0
    }
    if ($length -ge $SoftLimitBytes) {
        $sizeMiB = [Math]::Round($length / 1MB, 1)
        Write-HookJson @{
            systemMessage = "ALVEOLUS task transcript is $sizeMiB MiB; rollover preparation is now required."
            hookSpecificOutput = @{
                hookEventName = 'UserPromptSubmit'
                additionalContext = 'Finish only the smallest safe current slice. Summarize raw logs under .codex-temp/reports instead of pasting them, attach no animated media, then ask for ALVEOLUS-ROLLOVER to produce a compact text-only handoff before further work.'
            }
        }
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("ALVEOLUS UserPromptSubmit hook failed: $($_.Exception.Message)")
    exit 2
}
