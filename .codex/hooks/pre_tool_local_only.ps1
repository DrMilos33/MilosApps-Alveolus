Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Deny-RemoteWrite {
    param([string]$Reason = 'Remote write blocked by ALVEOLUS local-only policy.')
    $result = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 8))
    exit 0
}

function Test-BlockedShellCommand {
    param([Parameter(Mandatory = $true)] [string]$Command)

    $patterns = @(
        '(?is)\bgit\s+push\b',
        '(?is)(?:^|[;&|\r\n]\s*)git\s+push\b',
        '(?is)(?:^|[;&|\r\n]\s*)git(?:\s+(?:-C|--git-dir|--work-tree)\s+(?:"[^"]*"|''[^'']*''|\S+))+\s+push\b',
        '(?is)\bgit\s+send-pack\b',
        '(?is)\bgh\s+(?:pr|issue|review|release|repo|workflow)\s+(?:create|merge|close|reopen|comment|review|edit|delete|upload|run|enable|disable|fork|archive|sync)\b',
        '(?is)\bgh\s+api\b[^\r\n;&|]*(?:--method|-X)\s*(?:POST|PUT|PATCH|DELETE)\b',
        '(?is)\b(?:docker|podman)\s+push\b',
        '(?is)\b(?:npm|pnpm|yarn|cargo|dotnet|nuget|gem|twine)\s+(?:publish|push)\b',
        '(?is)\b(?:npm|pnpm|yarn|make|just)\s+(?:run\s+)?(?:deploy|publish|release|upload)\b',
        '(?is)\b(?:vercel|netlify|firebase|wrangler|surge|flyctl|railway)\b[^\r\n;&|]*(?:deploy|publish|upload|pages\s+deploy)\b',
        '(?is)\bcurl\b[^\r\n;&|]*(?:--upload-file|-T\s|--form\b|-F\s|--request\s*(?:POST|PUT|PATCH|DELETE)|-X\s*(?:POST|PUT|PATCH|DELETE))',
        '(?is)\bInvoke-(?:RestMethod|WebRequest)\b[^\r\n;&|]*-Method\s+(?:POST|PUT|PATCH|DELETE)\b',
        '(?is)(?:^|[;&|\r\n]\s*)(?:scp|sftp|ssh)\b',
        '(?is)(?:^|[;&|\r\n]\s*)rsync\b[^\r\n;&|]*\S+@\S+:',
        '(?is)\b(?:powershell|pwsh)\b[^\r\n;&|]*-(?:EncodedCommand|enc)\b',
        '(?is)\bInvoke-Expression\b|\biex\b'
    )
    foreach ($pattern in $patterns) {
        if ($Command -match $pattern) {
            return $true
        }
    }
    return $false
}

function Test-ExternalMutationTool {
    param([Parameter(Mandatory = $true)] [string]$ToolName)

    if ($ToolName -notmatch '^(?:mcp__|mcp_)') {
        return $false
    }
    $normalized = $ToolName.ToLowerInvariant()
    $mutation = '(?:^|_)(?:add|create|update|delete|deploy|upload|share|send|reply|comment|merge|execute|set|resolve|save|publish|release|push|write|edit)(?:_|$)'
    if ($normalized -match $mutation) {
        return $true
    }
    $readOnly = '(?:^|_)(?:get|list|search|find|fetch|read|inspect|compare|check|status|schema|open|view)(?:_|$)'
    return $normalized -notmatch $readOnly
}

try {
    $rawJson = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
    if ([string]::IsNullOrWhiteSpace($rawJson)) {
        throw 'Hook input is empty.'
    }
    $payload = $rawJson | ConvertFrom-Json -ErrorAction Stop
    $eventProperty = $payload.PSObject.Properties['hook_event_name']
    if ($null -eq $eventProperty -or [string]$eventProperty.Value -ne 'PreToolUse') {
        throw 'Unexpected hook_event_name.'
    }
    $toolNameProperty = $payload.PSObject.Properties['tool_name']
    $toolName = if ($null -ne $toolNameProperty) { [string]$toolNameProperty.Value } else { '' }
    if ([string]::IsNullOrWhiteSpace($toolName)) {
        Deny-RemoteWrite 'Tool without a name blocked by ALVEOLUS local-only policy.'
    }

    if ($toolName -eq 'Bash') {
        $toolInputProperty = $payload.PSObject.Properties['tool_input']
        $commandProperty = if ($null -ne $toolInputProperty -and $null -ne $toolInputProperty.Value) {
            $toolInputProperty.Value.PSObject.Properties['command']
        } else {
            $null
        }
        $command = if ($null -ne $commandProperty) { [string]$commandProperty.Value } else { '' }
        if ([string]::IsNullOrWhiteSpace($command)) {
            Deny-RemoteWrite 'Shell call without a static command blocked by ALVEOLUS local-only policy.'
        }
        if (Test-BlockedShellCommand $command) {
            Deny-RemoteWrite
        }
        exit 0
    }

    if (Test-ExternalMutationTool $toolName) {
        Deny-RemoteWrite 'External mutation blocked by ALVEOLUS local-only policy.'
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("ALVEOLUS PreToolUse hook failed: $($_.Exception.Message)")
    exit 2
}
