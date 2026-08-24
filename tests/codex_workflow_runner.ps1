[CmdletBinding()]
param(
    [string]$PythonPath = '',
    [switch]$KeepArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rolloverHook = Join-Path $projectRoot '.codex\hooks\user_prompt_rollover.ps1'
$localOnlyHook = Join-Path $projectRoot '.codex\hooks\pre_tool_local_only.ps1'
$workflowScript = Join-Path $projectRoot 'tools\alveolus-workflow.ps1'
$prePushHook = Join-Path $projectRoot '.githooks\pre-push'
$mediaScript = Join-Path $projectRoot '.agents\skills\alveolus-change-workflow\scripts\prepare_feedback_media.py'
$fixtureParent = Join-Path $projectRoot '.codex-temp\reports'
$fixtureRoot = Join-Path $fixtureParent ('codex-workflow-fixture-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    $bundledPython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    $PythonPath = if (Test-Path -LiteralPath $bundledPython -PathType Leaf) { $bundledPython } else { 'python' }
}

$script:Assertions = 0
$script:Failures = [Collections.Generic.List[string]]::new()

function Test-Condition {
    param([bool]$Condition, [string]$Message)
    $script:Assertions += 1
    if (-not $Condition) { $script:Failures.Add($Message) }
}

function New-SizedFile {
    param([string]$Path, [long]$Length)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.SetLength($Length) } finally { $stream.Dispose() }
}

function Invoke-PowerShellFile {
    param(
        [Parameter(Mandatory = $true)] [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$StandardInput = '',
        [hashtable]$Environment = @{}
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    $quotedArguments = @($Arguments | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' })
    $startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`" $($quotedArguments -join ' ')"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($key in $Environment.Keys) { $startInfo.EnvironmentVariables[[string]$key] = [string]$Environment[$key] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()
    $process.StandardInput.Write($StandardInput)
    $process.StandardInput.Close()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return @{
        exit_code = $process.ExitCode
        stdout = $stdoutTask.Result.Trim().Trim([char]0xFEFF)
        stderr = $stderrTask.Result.Trim().Trim([char]0xFEFF)
    }
}

function Invoke-Hook {
    param([string]$ScriptPath, [string]$InputJson)
    return Invoke-PowerShellFile -ScriptPath $ScriptPath -StandardInput $InputJson
}

function Convert-HookOutput {
    param([string]$Output)
    if ([string]::IsNullOrWhiteSpace($Output)) { return $null }
    return $Output | ConvertFrom-Json -ErrorAction Stop
}

function New-PromptPayload {
    param([AllowNull()] [string]$TranscriptPath, [string]$Prompt = 'Weiterarbeiten')
    return (@{
        session_id = 'fixture-session'
        transcript_path = $TranscriptPath
        cwd = $projectRoot
        hook_event_name = 'UserPromptSubmit'
        model = 'fixture-model'
        turn_id = 'fixture-turn'
        permission_mode = 'default'
        prompt = $Prompt
    } | ConvertTo-Json -Compress -Depth 8)
}

function New-ToolPayload {
    param([string]$ToolName, [object]$ToolInput)
    return (@{
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
    } | ConvertTo-Json -Compress -Depth 12)
}

function Invoke-LocalGit {
    param([string]$Root, [string[]]$Arguments, [switch]$AllowFailure)
    $output = & git -C $Root @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) { throw "Fixture Git failed: git $($Arguments -join ' ')`n$($output -join "`n")" }
    return @{ exit_code = $exitCode; output = ($output -join "`n") }
}

function Initialize-FixtureRepository {
    param([string]$Root, [AllowNull()] [string]$ReleaseVersion = $null)
    New-Item -ItemType Directory -Path (Join-Path $Root 'tools'), (Join-Path $Root '.githooks') -Force | Out-Null
    Copy-Item -LiteralPath $workflowScript -Destination (Join-Path $Root 'tools\alveolus-workflow.ps1')
    Copy-Item -LiteralPath $prePushHook -Destination (Join-Path $Root '.githooks\pre-push')
    $version = [ordered]@{ schema = 1; release_version = $ReleaseVersion; save_schema = 7 }
    [IO.File]::WriteAllText((Join-Path $Root 'ALVEOLUS_VERSION.json'), ($version | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $Root '.gitignore'), "build/`n.codex-temp/`n", [Text.UTF8Encoding]::new($false))
    & git init -q -b codex/alveolus-local-main $Root
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize fixture repository.' }
    Invoke-LocalGit $Root @('config', 'user.name', 'ALVEOLUS Fixture') | Out-Null
    Invoke-LocalGit $Root @('config', 'user.email', 'fixture@example.invalid') | Out-Null
    Invoke-LocalGit $Root @('config', 'core.hooksPath', '.githooks') | Out-Null
    Invoke-LocalGit $Root @('add', '-A') | Out-Null
    Invoke-LocalGit $Root @('commit', '-q', '-m', 'fixture baseline') | Out-Null
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
    Test-Condition ($result.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($result.stdout)) '20 MiB minus one byte continues.'
    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atSoft)
    $output = Convert-HookOutput $result.stdout
    $softDecision = $output.PSObject.Properties['decision']
    Test-Condition ($output.systemMessage -match '20' -and ($null -eq $softDecision -or [string]$softDecision.Value -ne 'block')) 'Exactly 20 MiB warns without blocking.'
    $result = Invoke-Hook $rolloverHook (New-PromptPayload $belowHard)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($output.systemMessage -match 'rollover') '40 MiB minus one byte still warns.'
    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atHard)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($output.decision -eq 'block' -and $output.reason -match '40 MiB') 'Exactly 40 MiB blocks normal prompts.'
    $result = Invoke-Hook $rolloverHook (New-PromptPayload $atHard 'ALVEOLUS-ROLLOVER')
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($output.hookSpecificOutput.additionalContext -match 'ALVEOLUS-HANDOFF-v2') 'Rollover marker remains allowed at 40 MiB.'
    $result = Invoke-Hook $rolloverHook (New-PromptPayload $null)
    $output = Convert-HookOutput $result.stdout
    Test-Condition ($output.systemMessage -match 'unavailable') 'Missing transcript path fails open with warning.'
    $result = Invoke-Hook $rolloverHook '{invalid json'
    Test-Condition ($result.exit_code -eq 2 -and $result.stderr -match 'hook failed') 'Invalid prompt hook JSON fails clearly.'
}

function Test-LocalOnlyHook {
    $allowed = @(
        'git status --short',
        'git diff --check',
        'git commit -m "local checkpoint"',
        'git worktree list',
        'python -m http.server 8766 --bind 127.0.0.1',
        '.\tests\run_checks.ps1 -Profile Quick',
        'Write-Output "git push origin HEAD"',
        'gh api --method GET repos/example/example'
    )
    foreach ($command in $allowed) {
        $result = Invoke-Hook $localOnlyHook (New-ToolPayload 'Bash' @{ command = $command })
        Test-Condition ($result.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($result.stdout)) "Local/read-only command remains allowed: $command"
    }

    $blocked = @(
        'git push origin dev',
        'git.exe push origin dev',
        '& "C:\Program Files\Git\cmd\git.exe" push origin dev',
        'git -C . push origin dev',
        'git -c color.ui=false push origin dev',
        "git -c alias.ship='push --no-verify' ship origin HEAD:refs/heads/dev",
        'git -c alias.ship=push ship origin HEAD:refs/heads/dev',
        'git --config-env=alias.ship=ALVEOLUS_ALIAS ship origin HEAD:refs/heads/dev',
        'git config alias.ship "push --no-verify"',
        'git ship origin HEAD:refs/heads/dev',
        'git ship --no-verify origin HEAD:refs/heads/dev',
        'git --git-dir=.git push origin dev',
        'git send-pack origin refs/heads/dev',
        'Start-Process git.exe -ArgumentList "push","origin","dev"',
        'pwsh -Command "git push origin dev"',
        "pwsh -Command `"git -c alias.ship='push --no-verify' ship origin HEAD:refs/heads/dev`"",
        'cmd /c "git push origin dev"',
        'powershell.exe -EncodedCommand ZgBvAG8A',
        'gh pr create --title test',
        'gh api repos/example/example -f name=value',
        'gh api repos/example/example --input payload.json',
        'curl --data value https://example.invalid',
        'curl --form file=@x https://example.invalid',
        'docker push example/alveolus:latest',
        'npm publish',
        'scp build.zip user@example.invalid:/tmp/',
        'pwsh'
    )
    foreach ($command in $blocked) {
        $result = Invoke-Hook $localOnlyHook (New-ToolPayload 'Bash' @{ command = $command })
        $output = Convert-HookOutput $result.stdout
        Test-Condition ($null -ne $output -and $output.hookSpecificOutput.permissionDecision -eq 'deny') "Remote/dynamic command is denied: $command"
    }

    $patchResult = Invoke-Hook $localOnlyHook (New-ToolPayload 'apply_patch' @{ command = 'Documentation example: git push origin dev' })
    Test-Condition ([string]::IsNullOrWhiteSpace($patchResult.stdout)) 'Patch text mentioning push is not mistaken for a shell command.'
    $readResult = Invoke-Hook $localOnlyHook (New-ToolPayload 'mcp__github__get_pull_request' @{ owner = 'fixture'; repo = 'fixture' })
    Test-Condition ([string]::IsNullOrWhiteSpace($readResult.stdout)) 'Read-only GitHub MCP call remains allowed.'
    $writeResult = Invoke-Hook $localOnlyHook (New-ToolPayload 'mcp__github__create_pull_request' @{ owner = 'fixture'; repo = 'fixture' })
    $writeOutput = Convert-HookOutput $writeResult.stdout
    Test-Condition ($writeOutput.hookSpecificOutput.permissionDecision -eq 'deny') 'GitHub PR creation remains denied.'
}

function Test-StatusContract {
    $result = Invoke-PowerShellFile -ScriptPath $workflowScript -Arguments @('status', '-Json', '-RepositoryRoot', $projectRoot)
    Test-Condition ($result.exit_code -eq 0) 'Workflow status command succeeds.'
    $status = $result.stdout | ConvertFrom-Json -ErrorAction Stop
    Test-Condition ($status.schema -eq 'ALVEOLUS-LOCAL-WORKFLOW-v1') 'Status JSON has a stable schema.'
    Test-Condition ([string]$status.head -match '^[0-9a-f]{40}$') 'Status reports an exact commit SHA.'
    Test-Condition ([int]$status.save_schema -eq 7) 'Status distinguishes save schema v7.'
    Test-Condition (@($status.worktrees).Count -ge 1) 'Status reports registered worktrees.'
    Test-Condition ($status.cached_published_relation -in @('same', 'ahead', 'behind', 'diverged', 'unknown')) 'Status reports a stable cached GitHub relation.'
    Test-Condition (-not [string]::IsNullOrWhiteSpace([string]$status.worktrees[0].role)) 'Status assigns a role to every worktree.'

    $repo = Join-Path $fixtureRoot 'status-repo'
    $linked = Join-Path $fixtureRoot 'status-linked-worktree'
    Initialize-FixtureRepository -Root $repo
    Invoke-LocalGit $repo @('worktree', 'add', '-q', '-b', 'codex/status-linked', $linked) | Out-Null
    $linkedStatusResult = Invoke-PowerShellFile -ScriptPath (Join-Path $linked 'tools\alveolus-workflow.ps1') -Arguments @('status', '-Json', '-RepositoryRoot', $linked)
    Test-Condition ($linkedStatusResult.exit_code -eq 0) 'Status succeeds from a linked worktree.'
    $linkedStatus = $linkedStatusResult.stdout | ConvertFrom-Json -ErrorAction Stop
    Test-Condition ([IO.Path]::GetFullPath([string]$linkedStatus.project_root) -eq [IO.Path]::GetFullPath($linked)) 'Linked-worktree status identifies its own working copy.'
    Test-Condition (@($linkedStatus.worktrees).Count -eq 2) 'Linked-worktree status lists both registered working copies.'
}

function Test-ReleaseGate {
    $repo = Join-Path $fixtureRoot 'release-repo'
    $remote = Join-Path $fixtureRoot 'release-remote.git'
    Initialize-FixtureRepository -Root $repo -ReleaseVersion '0.1.0'
    & git init --bare -q $remote
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize local bare release fixture.' }
    Invoke-LocalGit $repo @('remote', 'add', 'origin', $remote) | Out-Null
    $head = (Invoke-LocalGit $repo @('rev-parse', 'HEAD')).output.Trim()

    $wrongConfirm = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @(
        'release', '-RepositoryRoot', $repo, '-Commit', $head, '-Version', '0.1.0', '-Confirm', 'wrong', '-AllowLocalTestRemote'
    )
    Test-Condition ($wrongConfirm.exit_code -ne 0) 'Release rejects a wrong confirmation.'

    $wrongVersion = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @(
        'release', '-RepositoryRoot', $repo, '-Commit', $head, '-Version', '0.2.0', '-Confirm', "ALVEOLUS-RELEASE-v1 $head origin/dev", '-AllowLocalTestRemote'
    )
    Test-Condition ($wrongVersion.exit_code -ne 0) 'Release rejects a version not committed in ALVEOLUS_VERSION.json.'

    $release = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @(
        'release', '-RepositoryRoot', $repo, '-Commit', $head, '-Version', '0.1.0', '-Confirm', "ALVEOLUS-RELEASE-v1 $head origin/dev", '-AllowLocalTestRemote'
    )
    Test-Condition ($release.exit_code -eq 0 -and $release.stdout -match 'ALVEOLUS_RELEASE_OK') 'Exact one-shot release succeeds against a local bare remote.'
    $remoteHead = (& git --git-dir=$remote rev-parse refs/heads/dev 2>$null | Out-String).Trim()
    Test-Condition ($remoteHead -eq $head) 'Release updates exactly the local fixture dev ref.'
    $gatePath = Join-Path ((Invoke-LocalGit $repo @('rev-parse', '--absolute-git-dir')).output.Trim()) 'alveolus-release-gate.json'
    Test-Condition (-not (Test-Path -LiteralPath $gatePath)) 'Successful release consumes its gate.'

    $replay = Invoke-LocalGit $repo @('push', 'origin', "refs/heads/codex/alveolus-local-main:refs/heads/dev") -AllowFailure
    Test-Condition ($replay.exit_code -ne 0 -and $replay.output -match 'Direct git push blocked') 'A second/raw push fails after gate consumption.'

    Invoke-LocalGit $repo @('switch', '-q', '-c', 'codex/wrong-release-branch') | Out-Null
    $wrongBranch = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @(
        'release', '-RepositoryRoot', $repo, '-Commit', $head, '-Version', '0.1.0', '-Confirm', "ALVEOLUS-RELEASE-v1 $head origin/dev", '-AllowLocalTestRemote'
    )
    Test-Condition ($wrongBranch.exit_code -ne 0) 'Release rejects the wrong local branch.'
    Invoke-LocalGit $repo @('switch', '-q', 'codex/alveolus-local-main') | Out-Null

    $expiredToken = [Guid]::NewGuid().ToString('N')
    $gate = [ordered]@{
        schema = 'ALVEOLUS-RELEASE-GATE-v1'; token = $expiredToken; head = $head
        branch = 'codex/alveolus-local-main'; remote = 'origin'; remote_location = $remote
        remote_ref = 'refs/heads/dev'; version = '0.1.0'; actions = @('git-push')
        session_id = 'fixture'; turn_id = 'fixture'; created_utc = [DateTime]::UtcNow.AddMinutes(-20).ToString('o')
        expires_utc = [DateTime]::UtcNow.AddMinutes(-10).ToString('o')
    }
    [IO.File]::WriteAllText($gatePath, ($gate | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $stdin = "refs/heads/codex/alveolus-local-main $head refs/heads/dev 0000000000000000000000000000000000000000`n"
    $expired = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @(
        'pre-push-check', '-RepositoryRoot', $repo, '-HookRemoteName', 'origin', '-HookRemoteLocation', $remote, '-AllowLocalTestRemote'
    ) -StandardInput $stdin -Environment @{ ALVEOLUS_RELEASE_TOKEN = $expiredToken; ALVEOLUS_ALLOW_LOCAL_TEST_REMOTE = '1' }
    Test-Condition ($expired.exit_code -ne 0 -and $expired.stderr -match 'expired') 'Expired release gate is rejected.'
    Remove-Item -LiteralPath $gatePath -Force
}

function Test-CleanupContract {
    $emptyRootRepo = Join-Path $fixtureRoot 'cleanup-empty-root-repo'
    $emptyRootOutside = Join-Path $fixtureRoot 'cleanup-empty-root-outside'
    Initialize-FixtureRepository -Root $emptyRootRepo
    $emptyRootBuild = Join-Path $emptyRootRepo 'build\local\local-20260821-000000-00000000'
    New-Item -ItemType Directory -Path $emptyRootBuild, $emptyRootOutside -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $emptyRootBuild 'index.html'), 'valid build')
    $emptyRootJunction = Join-Path $emptyRootRepo '.codex-temp'
    New-Item -ItemType Junction -Path $emptyRootJunction -Target $emptyRootOutside | Out-Null
    $emptyRootApply = Invoke-PowerShellFile -ScriptPath (Join-Path $emptyRootRepo 'tools\alveolus-workflow.ps1') -Arguments @('cleanup-apply', '-RepositoryRoot', $emptyRootRepo)
    Test-Condition ($emptyRootApply.exit_code -ne 0 -and $emptyRootApply.stderr -match '(?:Unsafe cleanup candidate refused|reparse-point ancestor)') 'Cleanup refuses an empty managed-root junction before writing manifests or reports.'
    Test-Condition (@(Get-ChildItem -LiteralPath $emptyRootOutside -Force).Count -eq 0) 'Empty managed-root junction receives no outside writes.'
    Remove-Item -LiteralPath $emptyRootJunction -Force

    $ancestorRepo = Join-Path $fixtureRoot 'cleanup-ancestor-repo'
    $ancestorOutside = Join-Path $fixtureRoot 'cleanup-ancestor-outside'
    Initialize-FixtureRepository -Root $ancestorRepo
    New-Item -ItemType Directory -Path (Join-Path $ancestorOutside 'legacy-cache') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $ancestorOutside 'legacy-cache\keep.txt'), 'outside')
    $ancestorJunction = Join-Path $ancestorRepo '.codex-temp'
    New-Item -ItemType Junction -Path $ancestorJunction -Target $ancestorOutside | Out-Null
    $ancestorPreview = Invoke-PowerShellFile -ScriptPath (Join-Path $ancestorRepo 'tools\alveolus-workflow.ps1') -Arguments @('cleanup-preview', '-RepositoryRoot', $ancestorRepo)
    Test-Condition ($ancestorPreview.exit_code -ne 0 -and $ancestorPreview.stderr -match 'Unsafe cleanup candidate refused') 'Cleanup refuses a candidate below a reparse-point ancestor.'
    Remove-Item -LiteralPath $ancestorJunction -Force
    Test-Condition (Test-Path -LiteralPath (Join-Path $ancestorOutside 'legacy-cache\keep.txt')) 'Ancestor-junction refusal leaves the outside target untouched.'

    $repo = Join-Path $fixtureRoot 'cleanup-repo'
    Initialize-FixtureRepository -Root $repo
    $oldBuild = Join-Path $repo 'build\old'
    $newBuild = Join-Path $repo 'build\new'
    New-Item -ItemType Directory -Path $oldBuild, $newBuild -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $oldBuild 'index.html'), 'old', [Text.UTF8Encoding]::new($false))
    Start-Sleep -Milliseconds 25
    [IO.File]::WriteAllText((Join-Path $newBuild 'index.html'), 'new', [Text.UTF8Encoding]::new($false))
    (Get-Item -LiteralPath $oldBuild).LastWriteTimeUtc = [DateTime]::UtcNow.AddHours(-1)
    (Get-Item -LiteralPath $newBuild).LastWriteTimeUtc = [DateTime]::UtcNow
    $legacy = Join-Path $repo '.codex-temp\legacy-cache'
    $nestedEvidence = Join-Path $repo '.codex-temp\legacy-with-evidence\evidence'
    $evidence = Join-Path $repo '.codex-temp\evidence\keep'
    $successfulFixture = Join-Path $repo '.codex-temp\reports\codex-workflow-fixture-success'
    $failedFixture = Join-Path $repo '.codex-temp\reports\codex-workflow-fixture-failed'
    New-Item -ItemType Directory -Path $legacy, $nestedEvidence, $evidence, $successfulFixture, $failedFixture -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $legacy 'junk.txt'), 'junk')
    [IO.File]::WriteAllText((Join-Path $nestedEvidence 'original.gif'), 'nested evidence')
    [IO.File]::WriteAllText((Join-Path $evidence 'original.gif'), 'evidence')
    [IO.File]::WriteAllText((Join-Path $successfulFixture 'fixture.bin'), 'fixture')
    [IO.File]::WriteAllText((Join-Path $successfulFixture '.alveolus-workflow-success'), 'ok')
    [IO.File]::WriteAllText((Join-Path $failedFixture 'failure.txt'), 'keep for diagnosis')

    $outside = Join-Path $fixtureRoot 'outside-cleanup-boundary'
    $reparseContainer = Join-Path $repo '.codex-temp\reparse-cache'
    $junction = Join-Path $reparseContainer 'escape'
    New-Item -ItemType Directory -Path $outside, $reparseContainer -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $outside 'keep.txt'), 'outside')
    New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
    $unsafePreview = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @('cleanup-preview', '-RepositoryRoot', $repo)
    Test-Condition ($unsafePreview.exit_code -ne 0 -and $unsafePreview.stderr -match 'Unsafe cleanup candidate refused') 'Cleanup refuses a candidate containing a reparse point.'
    Remove-Item -LiteralPath $junction -Force
    Test-Condition (Test-Path -LiteralPath (Join-Path $outside 'keep.txt')) 'Removing the test junction leaves its target untouched.'

    $preview = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @('cleanup-preview', '-RepositoryRoot', $repo)
    Test-Condition ($preview.exit_code -eq 0 -and $preview.stdout -match 'ALVEOLUS_CLEANUP_PREVIEW') 'Cleanup preview succeeds.'
    Test-Condition ((Test-Path $oldBuild) -and (Test-Path $newBuild) -and (Test-Path $legacy)) 'Cleanup preview does not remove artifacts.'

    $apply = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @('cleanup-apply', '-RepositoryRoot', $repo)
    Test-Condition ($apply.exit_code -eq 0 -and $apply.stdout -match 'ALVEOLUS_CLEANUP_OK') 'Cleanup apply succeeds after a valid previewable plan.'
    $manifests = @(Get-ChildItem -LiteralPath (Join-Path $repo 'build\local') -Filter manifest.json -File -Recurse)
    Test-Condition ($manifests.Count -eq 1) 'Cleanup preserves exactly one canonical local build manifest.'
    $manifest = Get-Content -Raw -LiteralPath $manifests[0].FullName | ConvertFrom-Json -ErrorAction Stop
    Test-Condition ($manifest.schema -eq 'ALVEOLUS-LOCAL-BUILD-v1' -and [string]$manifest.build_id -match '^local-\d{8}-\d{6}-[0-9a-f]{8}(?:-dirty)?$') 'Build manifest uses the stable schema and versioned build ID format.'
    Test-Condition ([string]$manifest.head -match '^[0-9a-f]{40}$' -and $manifest.dirty -eq $false -and -not [string]::IsNullOrWhiteSpace([string]$manifest.godot_version)) 'Build manifest records exact source and environment state.'
    Test-Condition ((Test-Path -LiteralPath (Join-Path $evidence 'original.gif')) -and (Test-Path -LiteralPath (Join-Path $nestedEvidence 'original.gif'))) 'Cleanup preserves direct and nested evidence.'
    Test-Condition (-not (Test-Path $legacy) -and -not (Test-Path $successfulFixture) -and (Test-Path $failedFixture)) 'Cleanup removes generated and marked-success fixtures while retaining failed diagnostics.'
    $secondPreview = Invoke-PowerShellFile -ScriptPath (Join-Path $repo 'tools\alveolus-workflow.ps1') -Arguments @('cleanup-preview', '-RepositoryRoot', $repo)
    Test-Condition ($secondPreview.exit_code -eq 0 -and $secondPreview.stdout -match 'candidates=0') 'Cleanup is idempotent after the canonical build is preserved.'
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
    Test-Condition ($LASTEXITCODE -eq 0 -and (Test-Path $gifPath)) 'Synthetic GIF fixture was created.'
    $hashBefore = (Get-FileHash $gifPath -Algorithm SHA256).Hash
    & $PythonPath $mediaScript $gifPath --case workflow-fixture --output-dir $outputDir | Out-Null
    Test-Condition ($LASTEXITCODE -eq 0) 'GIF preparation succeeds.'
    $hashAfter = (Get-FileHash $gifPath -Algorithm SHA256).Hash
    $frames = @(Get-ChildItem $outputDir -Filter 'frame_*.png')
    Test-Condition ($hashBefore -eq $hashAfter -and $frames.Count -gt 0 -and $frames.Count -le 6) 'Media preparation preserves source and creates at most six frames.'
    Test-Condition ((Test-Path (Join-Path $outputDir 'contact_sheet.png')) -and (Test-Path (Join-Path $outputDir 'manifest.md'))) 'Media preparation creates contact sheet and manifest.'
    $previewBytes = ($frames | Measure-Object Length -Sum).Sum + (Get-Item (Join-Path $outputDir 'contact_sheet.png')).Length
    Test-Condition ($previewBytes -le 8MB) 'Prepared media remains at or below eight MiB.'
}

$succeeded = $false
try {
    $null = Get-Content -Raw (Join-Path $projectRoot '.codex\hooks.json') | ConvertFrom-Json -ErrorAction Stop
    $null = Get-Content -Raw (Join-Path $projectRoot 'ALVEOLUS_VERSION.json') | ConvertFrom-Json -ErrorAction Stop
    Test-Condition $true 'Workflow JSON sources parse.'
    Test-PromptHook
    Test-LocalOnlyHook
    Test-StatusContract
    Test-ReleaseGate
    Test-CleanupContract
    Test-MediaPreparation
} catch {
    $script:Failures.Add("Unhandled fixture error: $($_.Exception.Message)")
}

if ($script:Failures.Count -eq 0) { $succeeded = $true }
if ($succeeded) {
    [IO.File]::WriteAllText((Join-Path $fixtureRoot '.alveolus-workflow-success'), [DateTime]::UtcNow.ToString('o'), [Text.UTF8Encoding]::new($false))
}
if ($succeeded -and -not $KeepArtifacts) {
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $resolvedParent = [IO.Path]::GetFullPath($fixtureParent).TrimEnd('\') + '\'
    if (-not $resolvedFixture.StartsWith($resolvedParent, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolvedFixture) -notlike 'codex-workflow-fixture-*') {
        throw "Refusing unsafe fixture cleanup: $resolvedFixture"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}

if ($succeeded) {
    $artifactStatus = if ($KeepArtifacts) { $fixtureRoot } else { 'removed' }
    Write-Host "ALVEOLUS_CODEX_WORKFLOW_OK assertions=$($script:Assertions) artifacts=$artifactStatus"
    exit 0
}
foreach ($failure in $script:Failures) { [Console]::Error.WriteLine($failure) }
Write-Host "ALVEOLUS_CODEX_WORKFLOW_FAILED assertions=$($script:Assertions) failures=$($script:Failures.Count) artifacts=$fixtureRoot"
exit 1
