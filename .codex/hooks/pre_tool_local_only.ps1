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

function Get-NormalizedCommandName {
    param([Management.Automation.Language.CommandAst]$CommandAst)
    $name = $CommandAst.GetCommandName()
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return [IO.Path]::GetFileName($name).ToLowerInvariant()
}

function Get-LiteralArguments {
    param([Management.Automation.Language.CommandAst]$CommandAst)
    $result = [Collections.Generic.List[string]]::new()
    foreach ($element in @($CommandAst.CommandElements | Select-Object -Skip 1)) {
        $text = $element.Extent.Text.Trim()
        if (($text.StartsWith('"') -and $text.EndsWith('"')) -or ($text.StartsWith("'") -and $text.EndsWith("'"))) {
            $text = $text.Substring(1, $text.Length - 2)
        }
        $result.Add($text)
    }
    return @($result)
}

function Get-GitSubcommand {
    param([string[]]$Arguments)
    $index = 0
    while ($index -lt $Arguments.Count) {
        $argument = $Arguments[$index]
        if ($argument -in @('-C', '-c', '--git-dir', '--work-tree', '--namespace', '--super-prefix', '--config-env')) {
            $index += 2
            continue
        }
        if ($argument -match '^--(?:git-dir|work-tree|namespace|super-prefix|config-env)=' -or $argument -match '^-c.+') {
            $index += 1
            continue
        }
        if ($argument.StartsWith('-')) {
            $index += 1
            continue
        }
        return $argument.ToLowerInvariant()
    }
    return ''
}

function Test-KnownLocalGitSubcommand {
    param([string]$Subcommand)
    return $Subcommand -in @(
        'add', 'am', 'apply', 'archive', 'bisect', 'blame', 'branch', 'bundle',
        'cat-file', 'check-attr', 'check-ignore', 'checkout', 'cherry', 'cherry-pick',
        'clean', 'clone', 'commit', 'config', 'count-objects', 'describe', 'diff',
        'diff-files', 'diff-index', 'diff-tree', 'fast-export', 'fast-import', 'fetch',
        'for-each-ref', 'format-patch', 'fsck', 'gc', 'grep', 'hash-object', 'help',
        'init', 'log', 'ls-files', 'ls-remote', 'ls-tree', 'maintenance', 'merge',
        'merge-base', 'mergetool', 'mv', 'name-rev', 'notes', 'pull', 'range-diff',
        'rebase', 'reflog', 'remote', 'repack', 'replace', 'reset', 'restore',
        'revert', 'rev-list', 'rev-parse', 'rm', 'show', 'show-branch', 'show-ref',
        'sparse-checkout', 'stash', 'status', 'submodule', 'switch', 'symbolic-ref',
        'tag', 'update-index', 'update-ref', 'verify-commit', 'verify-pack',
        'verify-tag', 'version', 'whatchanged', 'worktree'
    )
}

function Test-BenignDocumentationCommand {
    param([Management.Automation.Language.CommandAst[]]$Commands)
    if ($Commands.Count -ne 1) { return $false }
    $name = Get-NormalizedCommandName $Commands[0]
    return $name -in @('write-output', 'echo')
}

function Test-BlockedShellCommand {
    param([Parameter(Mandatory = $true)] [string]$Command)

    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Command, [ref]$tokens, [ref]$parseErrors)
    $commands = @($ast.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst]
    }, $true))
    if ($parseErrors.Count -gt 0) {
        if ($Command -match '(?is)\b(?:push|send-pack|deploy|publish|upload|POST|PUT|PATCH|DELETE)\b') { return $true }
        return $false
    }
    if (Test-BenignDocumentationCommand $commands) { return $false }

    foreach ($commandAst in $commands) {
        $name = Get-NormalizedCommandName $commandAst
        $arguments = @(Get-LiteralArguments $commandAst)
        if ([string]::IsNullOrWhiteSpace($name)) {
            if ($commandAst.Extent.Text -match '(?is)\b(?:push|send-pack|deploy|publish|upload)\b') { return $true }
            continue
        }
        if ($name -in @('invoke-expression', 'iex')) { return $true }
        if ($name -in @('powershell', 'powershell.exe', 'pwsh', 'pwsh.exe', 'cmd', 'cmd.exe', 'sh', 'bash')) {
            if ($arguments.Count -eq 0) { return $true }
            if ($arguments -match '^(?i)-(?:encodedcommand|enc)$') { return $true }
            $nestedCommand = $arguments -join ' '
            if ($nestedCommand -match '(?is)\bgit(?:\.exe)?\b.*(?:\balias\.|--no-verify|\bpush\b|\bsend-pack\b)') { return $true }
        }
        if ($name -in @('git', 'git.exe')) {
            $lower = @($arguments | ForEach-Object { $_.ToLowerInvariant() })
            if ($lower -contains '--no-verify') { return $true }
            for ($index = 0; $index -lt $lower.Count; $index++) {
                $argument = $lower[$index]
                if ($argument -eq '-c' -and $index + 1 -lt $lower.Count -and $lower[$index + 1] -match '^alias\.') { return $true }
                if ($argument -match '^-calias\.') { return $true }
                if ($argument -eq '--config-env' -and $index + 1 -lt $lower.Count -and $lower[$index + 1] -match '^alias\.') { return $true }
                if ($argument -match '^--config-env=alias\.') { return $true }
            }
            $subcommand = Get-GitSubcommand $arguments
            if ($subcommand -in @('push', 'send-pack')) { return $true }
            if ($subcommand -eq 'config' -and $lower -match '(?i)^alias\.') { return $true }
            if (-not (Test-KnownLocalGitSubcommand $subcommand)) { return $true }
        }
        if ($name -in @('gh', 'gh.exe')) {
            $lower = @($arguments | ForEach-Object { $_.ToLowerInvariant() })
            if ($lower.Count -gt 1 -and $lower[0] -in @('pr', 'issue', 'review', 'release', 'repo', 'workflow') -and
                $lower[1] -in @('create', 'merge', 'close', 'reopen', 'comment', 'review', 'edit', 'delete', 'upload', 'run', 'enable', 'disable', 'fork', 'archive', 'sync')) {
                return $true
            }
            if ($lower.Count -gt 0 -and $lower[0] -eq 'api') {
                if ($lower -match '^(?:-f|-F|--field|--raw-field|--input)(?:=|$)') { return $true }
                $joined = $lower -join ' '
                if ($joined -match '(?:--method|-X)\s*(?:POST|PUT|PATCH|DELETE)\b') { return $true }
            }
        }
        if ($name -in @('curl', 'curl.exe')) {
            $lower = @($arguments | ForEach-Object { $_.ToLowerInvariant() })
            if ($lower -match '^(?:-d|--data|--data-ascii|--data-binary|--data-raw|--data-urlencode|-f|--form|--form-string|-t|--upload-file)(?:=|$)') { return $true }
            if (($lower -join ' ') -match '(?:--request|-X)\s*(?:POST|PUT|PATCH|DELETE)\b') { return $true }
        }
        if ($name -in @('invoke-restmethod', 'invoke-webrequest')) {
            if (($arguments -join ' ') -match '(?is)-Method\s+(?:POST|PUT|PATCH|DELETE)\b') { return $true }
        }
        if ($name -in @('scp', 'scp.exe', 'sftp', 'sftp.exe', 'ssh', 'ssh.exe', 'rsync', 'rsync.exe')) { return $true }
        if ($name -in @('docker', 'docker.exe', 'podman', 'podman.exe') -and $arguments.Count -gt 0 -and $arguments[0] -eq 'push') { return $true }
        if ($name -in @('npm', 'npm.cmd', 'pnpm', 'pnpm.cmd', 'yarn', 'yarn.cmd', 'cargo', 'dotnet', 'nuget', 'gem', 'twine')) {
            if ($arguments -match '^(?i)(?:publish|push|deploy|release|upload)$') { return $true }
        }
        if ($name -in @('vercel', 'netlify', 'firebase', 'wrangler', 'surge', 'flyctl', 'railway')) {
            if ($arguments -match '^(?i)(?:deploy|publish|upload)$') { return $true }
        }
    }

    $normalized = $Command -replace '(?is)(?:"[^"\r\n]*[\\/])?git(?:\.exe)?"?', 'git'
    $fallbackPatterns = @(
        '(?is)\bgit\s+(?:(?:-C|-c|--git-dir|--work-tree)(?:=\S+|\s+\S+)\s+|--\S+\s+)*?(?:push|send-pack)\b',
        '(?is)\bStart-Process\b[^\r\n;&|]*\bgit(?:\.exe)?\b[^\r\n;&|]*\bpush\b',
        '(?is)\b(?:powershell|pwsh|cmd|sh|bash)(?:\.exe)?\b[^\r\n;&|]*(?:-Command|-c|/c)[^\r\n;&|]*\bgit\s+push\b'
    )
    foreach ($pattern in $fallbackPatterns) {
        if ($normalized -match $pattern) { return $true }
    }
    return $false
}

function Test-ExternalMutationTool {
    param([Parameter(Mandatory = $true)] [string]$ToolName)
    if ($ToolName -notmatch '^(?:mcp__|mcp_)') { return $false }
    $normalized = $ToolName.ToLowerInvariant()
    $mutation = '(?:^|_)(?:add|create|update|delete|deploy|upload|share|send|reply|comment|merge|execute|set|resolve|save|publish|release|push|write|edit)(?:_|$)'
    if ($normalized -match $mutation) { return $true }
    $readOnly = '(?:^|_)(?:get|list|search|find|fetch|read|inspect|compare|check|status|schema|open|view)(?:_|$)'
    return $normalized -notmatch $readOnly
}

try {
    $rawJson = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
    if ([string]::IsNullOrWhiteSpace($rawJson)) { throw 'Hook input is empty.' }
    $payload = $rawJson | ConvertFrom-Json -ErrorAction Stop
    if ([string]$payload.hook_event_name -ne 'PreToolUse') { throw 'Unexpected hook_event_name.' }
    $toolName = [string]$payload.tool_name
    if ([string]::IsNullOrWhiteSpace($toolName)) { Deny-RemoteWrite 'Tool without a name blocked by ALVEOLUS local-only policy.' }

    if ($toolName -eq 'Bash') {
        $command = if ($null -ne $payload.tool_input -and $null -ne $payload.tool_input.PSObject.Properties['command']) {
            [string]$payload.tool_input.command
        } else { '' }
        if ([string]::IsNullOrWhiteSpace($command)) { Deny-RemoteWrite 'Shell call without a static command blocked by ALVEOLUS local-only policy.' }
        if (Test-BlockedShellCommand $command) { Deny-RemoteWrite }
        exit 0
    }
    if (Test-ExternalMutationTool $toolName) { Deny-RemoteWrite 'External mutation blocked by ALVEOLUS local-only policy.' }
    exit 0
} catch {
    [Console]::Error.WriteLine("ALVEOLUS PreToolUse hook failed: $($_.Exception.Message)")
    exit 2
}
