[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet(
        'status', 'setup', 'preflight', 'editor', 'play', 'build-web',
        'open-build', 'cleanup-preview', 'cleanup-apply', 'release',
        'pre-push-check', 'help'
    )]
    [string]$Command = 'status',
    [string]$Commit = '',
    [string]$Version = '',
    [string]$Confirm = '',
    [switch]$Json,
    [string]$RepositoryRoot = '',
    [string]$GodotPath = '',
    [string]$HookRemoteName = '',
    [string]$HookRemoteLocation = '',
    [switch]$AllowLocalTestRemote
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$script:WorkflowSchema = 'ALVEOLUS-LOCAL-WORKFLOW-v1'
$script:ReleaseGateSchema = 'ALVEOLUS-RELEASE-GATE-v1'
$script:LocalMainBranch = 'codex/alveolus-local-main'
$script:ReleaseRemote = 'origin'
$script:ReleaseRemoteRef = 'refs/heads/dev'
$script:ReleaseRemoteUrl = 'https://github.com/DrMilos33/MilosApps-Alveolus.git'
$script:ZeroOid = '0000000000000000000000000000000000000000'
$script:SuccessfulFixtureMarker = '.alveolus-workflow-success'
$script:ProjectRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
} else {
    [IO.Path]::GetFullPath($RepositoryRoot)
}

function Invoke-GitText {
    param(
        [Parameter(Mandatory = $true)] [string[]]$Arguments,
        [switch]$AllowFailure
    )
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & git -C $script:ProjectRoot @Arguments 2>$null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "Git failed ($exitCode): git $($Arguments -join ' ')"
    }
    if ($exitCode -ne 0) {
        return ''
    }
    return (($output | Out-String).Trim())
}

function Assert-Repository {
    $topLevel = Invoke-GitText @('rev-parse', '--show-toplevel')
    if ([IO.Path]::GetFullPath($topLevel) -ne $script:ProjectRoot) {
        throw "RepositoryRoot is not the Git top-level directory: $($script:ProjectRoot)"
    }
}

function Get-VersionInfo {
    $path = Join-Path $script:ProjectRoot 'ALVEOLUS_VERSION.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing version source: $path"
    }
    $value = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -ErrorAction Stop
    if ([int]$value.schema -ne 1) {
        throw 'Unsupported ALVEOLUS_VERSION.json schema.'
    }
    return $value
}

function Get-GitDir {
    return [IO.Path]::GetFullPath((Invoke-GitText @('rev-parse', '--absolute-git-dir')))
}

function Get-GatePath {
    return Join-Path (Get-GitDir) 'alveolus-release-gate.json'
}

function Get-OptionalUpstream {
    return Invoke-GitText @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}') -AllowFailure
}

function Get-Worktrees {
    $lines = @((Invoke-GitText @('worktree', 'list', '--porcelain')) -split "`r?`n")
    $result = [Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $lines) {
        if ($line.StartsWith('worktree ')) {
            if ($null -ne $current) {
                $result.Add([pscustomobject]$current)
            }
            $current = [ordered]@{
                path = [IO.Path]::GetFullPath($line.Substring(9))
                head = ''
                branch = ''
                locked = $false
                prunable = $false
            }
        } elseif ($null -ne $current -and $line.StartsWith('HEAD ')) {
            $current.head = $line.Substring(5)
        } elseif ($null -ne $current -and $line.StartsWith('branch ')) {
            $current.branch = $line.Substring(7) -replace '^refs/heads/', ''
        } elseif ($null -ne $current -and $line -eq 'detached') {
            $current.branch = '(detached)'
        } elseif ($null -ne $current -and $line.StartsWith('locked')) {
            $current.locked = $true
        } elseif ($null -ne $current -and $line.StartsWith('prunable')) {
            $current.prunable = $true
        }
    }
    if ($null -ne $current) {
        $result.Add([pscustomobject]$current)
    }
    foreach ($worktree in $result) {
        $worktree | Add-Member -NotePropertyName role -NotePropertyValue $(
            if ($worktree.branch -eq $script:LocalMainBranch) { 'Hauptordner' }
            elseif ($worktree.branch -like 'codex/recovery-*') { 'Recovery' }
            elseif ($worktree.path -match '(?i)[\\/]\.codex[\\/]worktrees[\\/]') { 'Codex-Slice' }
            else { 'weiterer lokaler Worktree' }
        )
    }
    return @($result)
}

function Get-DirectoryBytes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return 0L
    }
    $measure = Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum
    if ($null -eq $measure -or $null -eq $measure.PSObject.Properties['Sum'] -or $null -eq $measure.Sum) {
        return 0L
    }
    return [long]$measure.Sum
}

function Get-LatestBuildManifest {
    $localRoot = Join-Path $script:ProjectRoot 'build\local'
    if (-not (Test-Path -LiteralPath $localRoot -PathType Container)) {
        return $null
    }
    $manifest = Get-ChildItem -LiteralPath $localRoot -Filter 'manifest.json' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $manifest) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $manifest.FullName | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return [pscustomobject]@{
            build_id = '(invalid manifest)'
            path = $manifest.DirectoryName
        }
    }
}

function Get-StatusObject {
    Assert-Repository
    $versionInfo = Get-VersionInfo
    $branch = Invoke-GitText @('branch', '--show-current')
    $head = Invoke-GitText @('rev-parse', 'HEAD')
    $dirtyLines = @(((Invoke-GitText @('status', '--porcelain=v1', '--untracked-files=all')) -split "`r?`n") | Where-Object { $_ })
    $publishedHead = Invoke-GitText @('rev-parse', '--verify', 'refs/remotes/origin/dev') -AllowFailure
    $publishedAhead = $null
    $publishedBehind = $null
    $publishedRelation = 'unknown'
    if (-not [string]::IsNullOrWhiteSpace($publishedHead)) {
        $counts = Invoke-GitText @('rev-list', '--left-right', '--count', "refs/remotes/origin/dev...$head") -AllowFailure
        $parts = @($counts -split '\s+' | Where-Object { $_ })
        if ($parts.Count -eq 2 -and $parts[0] -match '^\d+$' -and $parts[1] -match '^\d+$') {
            $publishedBehind = [int]$parts[0]
            $publishedAhead = [int]$parts[1]
            $publishedRelation = if ($publishedAhead -eq 0 -and $publishedBehind -eq 0) { 'same' }
                elseif ($publishedAhead -gt 0 -and $publishedBehind -eq 0) { 'ahead' }
                elseif ($publishedAhead -eq 0 -and $publishedBehind -gt 0) { 'behind' }
                else { 'diverged' }
        }
    }
    $hooksPath = Invoke-GitText @('config', '--get', 'core.hooksPath') -AllowFailure
    $resolvedHooksPath = if ([string]::IsNullOrWhiteSpace($hooksPath)) {
        ''
    } elseif ([IO.Path]::IsPathRooted($hooksPath)) {
        [IO.Path]::GetFullPath($hooksPath)
    } else {
        [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $hooksPath))
    }
    $pushDefault = Invoke-GitText @('config', '--get', 'push.default') -AllowFailure
    $latestBuild = Get-LatestBuildManifest
    return [pscustomobject][ordered]@{
        schema = $script:WorkflowSchema
        project_root = $script:ProjectRoot
        branch = $branch
        head = $head
        short_head = $head.Substring(0, 8)
        dirty = ($dirtyLines.Count -gt 0)
        dirty_path_count = $dirtyLines.Count
        upstream = Get-OptionalUpstream
        release_version = $versionInfo.release_version
        save_schema = [int]$versionInfo.save_schema
        cached_published_head = $publishedHead
        cached_published_relation = $publishedRelation
        cached_ahead_count = $publishedAhead
        cached_behind_count = $publishedBehind
        cached_published_note = 'Local tracking ref only; status performs no fetch.'
        push_default = $pushDefault
        hooks_path = $hooksPath
        git_push_guard_ready = (-not [string]::IsNullOrWhiteSpace($resolvedHooksPath) -and (Test-Path -LiteralPath (Join-Path $resolvedHooksPath 'pre-push') -PathType Leaf))
        codex_hook_trust_note = 'After hook changes, review and trust the project hooks in /hooks.'
        release_gate_armed = (Test-Path -LiteralPath (Get-GatePath) -PathType Leaf)
        latest_build = $latestBuild
        build_bytes = Get-DirectoryBytes (Join-Path $script:ProjectRoot 'build')
        report_bytes = Get-DirectoryBytes (Join-Path $script:ProjectRoot '.codex-temp\reports')
        worktrees = @(Get-Worktrees)
    }
}

function Write-Status {
    $status = Get-StatusObject
    if ($Json) {
        [Console]::Out.WriteLine(($status | ConvertTo-Json -Depth 10))
        return
    }
    Write-Host 'ALVEOLUS - lokaler Stand'
    Write-Host "  Ordner:        $($status.project_root)"
    Write-Host "  Branch:        $($status.branch)"
    Write-Host "  Commit:        $($status.head)"
    Write-Host "  Arbeitskopie:  $(if ($status.dirty) { "dirty ($($status.dirty_path_count) Pfade)" } else { 'sauber' })"
    Write-Host "  Upstream:      $(if ($status.upstream) { $status.upstream } else { 'keiner (rein lokal)' })"
    Write-Host "  Release:       $(if ($null -eq $status.release_version) { 'nicht festgelegt' } else { $status.release_version })"
    Write-Host "  Save-Schema:   v$($status.save_schema)"
    $comparison = switch ($status.cached_published_relation) {
        'same' { 'gleicher Commit' }
        'ahead' { "$($status.cached_ahead_count) lokale Commits voraus" }
        'behind' { "$($status.cached_behind_count) lokale Commits zurueck" }
        'diverged' { "$($status.cached_ahead_count) lokal voraus, $($status.cached_behind_count) nur im Cache" }
        default { 'Vergleich unbekannt' }
    }
    Write-Host "  GitHub-Cache:  $(if ($status.cached_published_head) { "$($status.cached_published_head) ($comparison)" } else { 'unbekannt' })"
    Write-Host "  Push-Schutz:   $(if ($status.git_push_guard_ready) { 'aktiv' } else { 'SETUP ERFORDERLICH' })"
    if ($null -ne $status.latest_build) {
        Write-Host "  Letzter Build: $($status.latest_build.build_id)"
        Write-Host "                 $($status.latest_build.path)"
    } else {
        Write-Host '  Letzter Build: keiner registriert'
    }
    Write-Host '  Worktrees:'
    foreach ($worktree in $status.worktrees) {
        Write-Host "    - [$($worktree.role)] $($worktree.branch) @ $($worktree.head.Substring(0, 8))"
        Write-Host "      $($worktree.path)"
    }
    Write-Host "  Hinweis:       $($status.cached_published_note)"
    Write-Host "                 $($status.codex_hook_trust_note)"
}

function Invoke-Setup {
    Assert-Repository
    if ((Invoke-GitText @('branch', '--show-current')) -ne $script:LocalMainBranch) {
        throw "Setup is allowed only from $($script:LocalMainBranch)."
    }
    $absoluteHooksPath = [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot '.githooks'))
    & git -C $script:ProjectRoot config --local push.default nothing
    if ($LASTEXITCODE -ne 0) { throw 'Could not set push.default.' }
    & git -C $script:ProjectRoot config --local core.hooksPath $absoluteHooksPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not set core.hooksPath.' }
    Write-Host "ALVEOLUS_SETUP_OK push.default=nothing core.hooksPath=$absoluteHooksPath"
    Write-Host 'Review and trust the changed project hooks once in Codex via /hooks.'
}

function Invoke-Preflight {
    $status = Get-StatusObject
    $issues = [Collections.Generic.List[string]]::new()
    if ($status.branch -ne $script:LocalMainBranch) {
        $issues.Add("Expected branch $($script:LocalMainBranch), found $($status.branch).")
    }
    if (-not $status.git_push_guard_ready) {
        $issues.Add('Git pre-push guard is not configured. Run .\ALVEOLUS.cmd setup.')
    }
    if ($status.push_default -ne 'nothing') {
        $issues.Add('push.default is not set to nothing.')
    }
    if ($issues.Count -gt 0) {
        foreach ($issue in $issues) { [Console]::Error.WriteLine($issue) }
        throw 'ALVEOLUS preflight failed.'
    }
    Write-Host "ALVEOLUS_PREFLIGHT_OK head=$($status.head) dirty=$($status.dirty)"
}

function Get-LocalConfig {
    $path = Join-Path $script:ProjectRoot '.alveolus.local.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }
    return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -ErrorAction Stop
}

function Resolve-GodotExecutable {
    param([switch]$Console)
    $candidates = [Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) { $candidates.Add($GodotPath) }
    $config = Get-LocalConfig
    if ($null -ne $config -and $null -ne $config.PSObject.Properties['godot_path']) {
        $candidates.Add([string]$config.godot_path)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ALVEOLUS_GODOT)) { $candidates.Add($env:ALVEOLUS_GODOT) }
    $known = if ($Console) {
        'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'
    } else {
        'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64.exe'
    }
    $candidates.Add($known)
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $resolved = [Environment]::ExpandEnvironmentVariables($candidate)
        if ($Console -and $resolved -notmatch '_console\.exe$') {
            $consoleSibling = $resolved -replace '\.exe$', '_console.exe'
            if (Test-Path -LiteralPath $consoleSibling -PathType Leaf) { return [IO.Path]::GetFullPath($consoleSibling) }
        }
        if (Test-Path -LiteralPath $resolved -PathType Leaf) { return [IO.Path]::GetFullPath($resolved) }
    }
    foreach ($name in $(if ($Console) { @('godot4_console', 'godot_console', 'godot4', 'godot') } else { @('godot4', 'godot') })) {
        $commandInfo = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $commandInfo) { return $commandInfo.Source }
    }
    throw 'Godot 4.7.1 was not found. Copy .alveolus.local.example.json to .alveolus.local.json and set godot_path.'
}

function Resolve-PythonExecutable {
    $candidates = [Collections.Generic.List[string]]::new()
    $config = Get-LocalConfig
    if ($null -ne $config -and $null -ne $config.PSObject.Properties['python_path']) {
        $candidates.Add([string]$config.python_path)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ALVEOLUS_PYTHON)) { $candidates.Add($env:ALVEOLUS_PYTHON) }
    $candidates.Add((Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'))
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $resolved = [Environment]::ExpandEnvironmentVariables($candidate)
        if (Test-Path -LiteralPath $resolved -PathType Leaf) { return [IO.Path]::GetFullPath($resolved) }
    }
    foreach ($name in @('py', 'python')) {
        $commandInfo = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $commandInfo -and $commandInfo.Source -notmatch '(?i)[\\/]WindowsApps[\\/]') { return $commandInfo.Source }
    }
    throw 'Python was not found. Set python_path in .alveolus.local.json or ALVEOLUS_PYTHON.'
}

function Start-Godot {
    param([switch]$Editor)
    $godot = Resolve-GodotExecutable
    $arguments = if ($Editor) { @('--editor', '--path', "`"$($script:ProjectRoot)`"") } else { @('--path', "`"$($script:ProjectRoot)`"") }
    Start-Process -FilePath $godot -ArgumentList $arguments
    Write-Host "Started Godot: $godot"
}

function Assert-SafeManagedWritePath {
    param([Parameter(Mandatory = $true)] [string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $allowed = $false
    foreach ($managedRoot in @(
        [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot 'build')),
        [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot '.codex-temp'))
    )) {
        $prefix = $managedRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($full.Equals($managedRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) { throw "Managed write path is outside build/.codex-temp: $full" }

    $probe = $full
    while (-not (Test-Path -LiteralPath $probe)) {
        $parent = Split-Path -Parent $probe
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $probe) {
            throw "Could not resolve a safe parent for managed write: $full"
        }
        $probe = [IO.Path]::GetFullPath($parent)
    }
    if (Test-PathOrAncestorContainsReparsePoint -Path $probe -BoundaryRoot $script:ProjectRoot) {
        throw "Managed write path has a reparse-point ancestor: $full"
    }
    return $full
}

function Get-LocalBuildId {
    $head = Invoke-GitText @('rev-parse', '--short=8', 'HEAD')
    $dirty = -not [string]::IsNullOrWhiteSpace((Invoke-GitText @('status', '--porcelain=v1', '--untracked-files=all')))
    return 'local-{0}-{1}{2}' -f [DateTime]::Now.ToString('yyyyMMdd-HHmmss'), $head, $(if ($dirty) { '-dirty' } else { '' })
}

function Write-BuildManifest {
    param(
        [Parameter(Mandatory = $true)] [string]$BuildPath,
        [Parameter(Mandatory = $true)] [string]$BuildId,
        [Parameter(Mandatory = $true)] [string]$GodotVersion,
        [string[]]$Checks = @(),
        [string]$MigratedFrom = '',
        [Nullable[bool]]$DirtyOverride = $null
    )
    $BuildPath = Assert-SafeManagedWritePath $BuildPath
    $manifestPath = Assert-SafeManagedWritePath (Join-Path $BuildPath 'manifest.json')
    $pointerDir = Assert-SafeManagedWritePath (Join-Path $script:ProjectRoot '.codex-temp')
    $pointerPath = Assert-SafeManagedWritePath (Join-Path $pointerDir 'latest_local_build.json')
    $head = Invoke-GitText @('rev-parse', 'HEAD')
    $dirty = -not [string]::IsNullOrWhiteSpace((Invoke-GitText @('status', '--porcelain=v1', '--untracked-files=all')))
    $manifest = [ordered]@{
        schema = 'ALVEOLUS-LOCAL-BUILD-v1'
        build_id = $BuildId
        path = [IO.Path]::GetFullPath($BuildPath)
        created_utc = [DateTime]::UtcNow.ToString('o')
        branch = Invoke-GitText @('branch', '--show-current')
        head = $head
        dirty = $(if ($null -eq $DirtyOverride) { $dirty } else { [bool]$DirtyOverride })
        godot_version = $GodotVersion
        checks = @($Checks)
        migrated_from = $MigratedFrom
    }
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Path $pointerDir -Force | Out-Null
    [IO.File]::WriteAllText($pointerPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    return [pscustomobject]$manifest
}

function Invoke-WebBuild {
    Assert-Repository
    $godot = Resolve-GodotExecutable -Console
    $buildId = Get-LocalBuildId
    $buildPath = Assert-SafeManagedWritePath (Join-Path $script:ProjectRoot (Join-Path 'build\local' $buildId))
    $null = Assert-SafeManagedWritePath (Join-Path $script:ProjectRoot '.codex-temp\latest_local_build.json')
    New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
    $versionOutput = (& $godot --version 2>&1 | Out-String).Trim()
    & $godot --headless --path $script:ProjectRoot --export-release Web (Join-Path $buildPath 'index.html')
    if ($LASTEXITCODE -ne 0) {
        throw "Godot web export failed with exit code $LASTEXITCODE. Artifacts remain at $buildPath"
    }
    $manifest = Write-BuildManifest -BuildPath $buildPath -BuildId $buildId -GodotVersion $versionOutput -Checks @('Godot Web export completed')
    Write-Host "ALVEOLUS_BUILD_OK id=$($manifest.build_id) path=$($manifest.path)"
}

function Open-LatestBuild {
    $manifest = Get-LatestBuildManifest
    if ($null -eq $manifest -or -not (Test-Path -LiteralPath ([string]$manifest.path) -PathType Container)) {
        throw 'No registered local build exists. Run .\ALVEOLUS.cmd build-web first.'
    }
    $buildPath = [string]$manifest.path
    $python = Resolve-PythonExecutable
    Start-Process -FilePath 'explorer.exe' -ArgumentList @("`"$buildPath`"")
    Write-Host "ALVEOLUS_BUILD_OPEN path=$buildPath"
    Write-Host 'Browser-Smoke aus einem zweiten PowerShell-Fenster:'
    Write-Host "  & `"$python`" -m http.server 8766 --bind 127.0.0.1 --directory `"$buildPath`""
    Write-Host '  http://127.0.0.1:8766/'
}

function Test-PathContainsReparsePoint {
    param([Parameter(Mandatory = $true)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $root = Get-Item -LiteralPath $Path -Force
    if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
    if (-not $root.PSIsContainer) { return $false }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($root.FullName)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        foreach ($child in @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop)) {
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
            if ($child.PSIsContainer) { $pending.Push($child.FullName) }
        }
    }
    return $false
}

function Test-PathOrAncestorContainsReparsePoint {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$BoundaryRoot
    )
    $current = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $boundary = [IO.Path]::GetFullPath($BoundaryRoot).TrimEnd('\', '/')
    while ($true) {
        if (-not (Test-Path -LiteralPath $current)) { return $true }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
        if ($current.Equals($boundary, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { return $true }
        $current = [IO.Path]::GetFullPath($parent).TrimEnd('\', '/')
    }
}

function Test-ContainsProtectedEvidence {
    param([Parameter(Mandatory = $true)] [string]$Path)
    $root = Get-Item -LiteralPath $Path -Force
    if ($root.Name -match '(?i)(?:gif|evidence|media|review)' -or
        $root.Extension -match '^(?i)\.(?:gif|png|jpe?g|webp|mp4|webm|mov|avi|mkv|wav|mp3)$') {
        return $true
    }
    if (-not $root.PSIsContainer) { return $false }
    $rootPrefix = $root.FullName.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    foreach ($child in @(Get-ChildItem -LiteralPath $root.FullName -Recurse -Force -ErrorAction Stop)) {
        $relative = $child.FullName.Substring($rootPrefix.Length)
        $segments = @($relative -split '[\\/]')
        if ($segments -contains 'evidence') { return $true }
        if (-not $child.PSIsContainer) {
            if ($child.Extension -match '^(?i)\.(?:gif|mp4|webm|mov|avi|mkv|wav|mp3)$') { return $true }
            if ($child.BaseName -match '^(?i)(?:original|source|input)(?:[-_.]|$)' -and
                $child.Extension -match '^(?i)\.(?:png|jpe?g|webp)$') { return $true }
        }
    }
    return $false
}

function Get-BuildUnits {
    param([string]$WorktreePath)
    $buildRoot = Join-Path $WorktreePath 'build'
    if (-not (Test-Path -LiteralPath $buildRoot -PathType Container)) { return @() }
    $result = [Collections.Generic.List[object]]::new()
    foreach ($directory in @(Get-ChildItem -LiteralPath $buildRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($directory.Name -eq 'local') {
            foreach ($localBuild in @(Get-ChildItem -LiteralPath $directory.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
                $index = Get-ChildItem -LiteralPath $localBuild.FullName -Filter 'index.html' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                $result.Add([pscustomobject]@{ path = $localBuild.FullName; index = $index; modified_utc = $localBuild.LastWriteTimeUtc })
            }
        } else {
            $index = Get-ChildItem -LiteralPath $directory.FullName -Filter 'index.html' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            $result.Add([pscustomobject]@{ path = $directory.FullName; index = $index; modified_utc = $directory.LastWriteTimeUtc })
        }
    }
    return @($result)
}

function Get-CleanupContext {
    $worktrees = @(Get-Worktrees)
    if ($worktrees.Count -eq 0) { throw 'No registered Git worktrees found.' }
    $canonicalRoot = [IO.Path]::GetFullPath([string]$worktrees[0].path)
    $units = [Collections.Generic.List[object]]::new()
    foreach ($worktree in $worktrees) {
        foreach ($unit in @(Get-BuildUnits ([string]$worktree.path))) { $units.Add($unit) }
    }
    $latest = @($units | Where-Object { $null -ne $_.index } | Sort-Object modified_utc -Descending | Select-Object -First 1)
    $latestUnit = if ($latest.Count -gt 0) { $latest[0] } else { $null }
    $preservedPath = ''
    if ($null -ne $latestUnit) {
        $canonicalLocalRoot = [IO.Path]::GetFullPath((Join-Path $canonicalRoot 'build\local')).TrimEnd('\') + '\'
        $latestPath = [IO.Path]::GetFullPath([string]$latestUnit.path)
        if ($latestPath.StartsWith($canonicalLocalRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $preservedPath = $latestPath
        } else {
            $head = Invoke-GitText @('rev-parse', '--short=8', 'HEAD')
            $buildId = 'local-{0}-{1}' -f ([DateTime]$latestUnit.modified_utc).ToLocalTime().ToString('yyyyMMdd-HHmmss'), $head
            $preservedPath = Join-Path $canonicalRoot (Join-Path 'build\local' $buildId)
        }
    }
    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($unit in $units) {
        if ($null -ne $latestUnit -and [IO.Path]::GetFullPath($unit.path) -eq [IO.Path]::GetFullPath($latestUnit.path)) { continue }
        $candidates.Add([pscustomobject]@{ path = [IO.Path]::GetFullPath($unit.path); kind = 'old-build' })
    }
    foreach ($worktree in $worktrees) {
        $tempRoot = Join-Path ([string]$worktree.path) '.codex-temp'
        if (-not (Test-Path -LiteralPath $tempRoot -PathType Container)) { continue }
        $tempItem = Get-Item -LiteralPath $tempRoot -Force
        if (($tempItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $candidates.Add([pscustomobject]@{ path = [IO.Path]::GetFullPath($tempRoot); kind = 'unsafe-reparse-root' })
            continue
        }
        foreach ($entry in @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)) {
            if ($entry.Name -in @('reports', 'evidence', 'test-reports', 'latest_local_build.json')) { continue }
            if (Test-PathContainsReparsePoint $entry.FullName) {
                $candidates.Add([pscustomobject]@{ path = [IO.Path]::GetFullPath($entry.FullName); kind = 'unsafe-reparse' })
                continue
            }
            if (Test-ContainsProtectedEvidence $entry.FullName) { continue }
            $candidates.Add([pscustomobject]@{ path = [IO.Path]::GetFullPath($entry.FullName); kind = 'legacy-temp' })
        }
        $reportsRoot = Join-Path $tempRoot 'reports'
        if (Test-Path -LiteralPath $reportsRoot -PathType Container) {
            foreach ($fixture in @(Get-ChildItem -LiteralPath $reportsRoot -Directory -Filter 'codex-workflow-fixture-*' -ErrorAction SilentlyContinue)) {
                $marker = Join-Path $fixture.FullName $script:SuccessfulFixtureMarker
                if (Test-Path -LiteralPath $marker -PathType Leaf) {
                    $candidates.Add([pscustomobject]@{ path = [IO.Path]::GetFullPath($fixture.FullName); kind = 'successful-workflow-fixture' })
                }
            }
        }
    }
    return [pscustomobject]@{
        worktrees = $worktrees
        canonical_root = $canonicalRoot
        latest_source = $latestUnit
        preserved_path = $preservedPath
        candidates = @($candidates | Sort-Object path -Unique)
    }
}

function Test-SafeCleanupPath {
    param([Parameter(Mandatory = $true)] [string]$Path, [Parameter(Mandatory = $true)] [object[]]$Worktrees)
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full)) { return $false }
    foreach ($worktree in $Worktrees) {
        $root = [IO.Path]::GetFullPath([string]$worktree.path).TrimEnd('\', '/')
        $prefix = $root + [IO.Path]::DirectorySeparatorChar
        if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (Test-PathOrAncestorContainsReparsePoint -Path $full -BoundaryRoot $root) { return $false }
        if (Test-PathContainsReparsePoint $full) { return $false }
        $relative = $full.Substring($prefix.Length)
        if ($relative -match '^(?i)build[\\/]' -or $relative -match '^(?i)\.codex-temp[\\/]') {
            if ($relative -match '^(?i)\.codex-temp[\\/]evidence(?:[\\/]|$)') { return $false }
            return $true
        }
    }
    return $false
}

function Get-PathBytes {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return [long](Get-Item -LiteralPath $Path).Length }
    return Get-DirectoryBytes $Path
}

function Invoke-Cleanup {
    param([switch]$Apply)
    Assert-Repository
    $context = Get-CleanupContext
    $rows = @(foreach ($candidate in $context.candidates) {
        if (-not (Test-SafeCleanupPath -Path $candidate.path -Worktrees $context.worktrees)) {
            throw "Unsafe cleanup candidate refused: $($candidate.path)"
        }
        [pscustomobject]@{
            path = $candidate.path
            kind = $candidate.kind
            bytes = Get-PathBytes $candidate.path
        }
    })
    $totalBytes = 0L
    foreach ($row in @($rows)) { $totalBytes += [long]$row.bytes }
    if (-not $Apply) {
        Write-Host "ALVEOLUS_CLEANUP_PREVIEW candidates=$($rows.Count) bytes=$totalBytes"
        if ($null -ne $context.latest_source) {
            Write-Host "  preserve source: $($context.latest_source.path)"
            Write-Host "  canonical copy:  $($context.preserved_path)"
        } else {
            Write-Host '  no valid web build found; cleanup-apply will refuse to delete builds.'
        }
        foreach ($row in $rows | Sort-Object bytes -Descending) {
            Write-Host ('  {0,10:N1} MiB  {1}  {2}' -f ($row.bytes / 1MB), $row.kind, $row.path)
        }
        return
    }
    if ($null -eq $context.latest_source) {
        throw 'No valid web build found. Refusing cleanup-apply so the last playable build cannot be lost.'
    }
    $preservedPath = [IO.Path]::GetFullPath($context.preserved_path)
    $sourcePath = [IO.Path]::GetFullPath($context.latest_source.path)
    $preservedPath = Assert-SafeManagedWritePath $preservedPath
    $null = Assert-SafeManagedWritePath (Join-Path $context.canonical_root '.codex-temp\latest_local_build.json')
    $reportRoot = Assert-SafeManagedWritePath (Join-Path $context.canonical_root '.codex-temp\reports\local-workflow')
    if (-not (Test-SafeCleanupPath -Path $sourcePath -Worktrees $context.worktrees)) {
        throw "Unsafe latest-build source refused: $sourcePath"
    }
    if ($sourcePath -ne $preservedPath) {
        $parent = Split-Path -Parent $preservedPath
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        if (Test-Path -LiteralPath $preservedPath) {
            throw "Preserved build destination already exists: $preservedPath"
        }
        Copy-Item -LiteralPath $sourcePath -Destination $preservedPath -Recurse
        $buildId = Split-Path -Leaf $preservedPath
        $null = Write-BuildManifest -BuildPath $preservedPath -BuildId $buildId -GodotVersion 'unknown (migrated existing export)' -Checks @('Existing index.html preserved during local cleanup') -MigratedFrom $sourcePath -DirtyOverride $false
    }
    $removed = [Collections.Generic.List[object]]::new()
    foreach ($row in $rows) {
        if (-not (Test-Path -LiteralPath $row.path)) { continue }
        if ([IO.Path]::GetFullPath($row.path) -eq $preservedPath) { continue }
        if (-not (Test-SafeCleanupPath -Path $row.path -Worktrees $context.worktrees)) {
            throw "Cleanup target became unsafe after preview: $($row.path)"
        }
        Remove-Item -LiteralPath $row.path -Recurse -Force
        $removed.Add($row)
    }
    if ($sourcePath -ne $preservedPath -and (Test-Path -LiteralPath $sourcePath)) {
        if (-not (Test-SafeCleanupPath -Path $sourcePath -Worktrees $context.worktrees)) {
            throw "Unsafe preserved-source cleanup refused: $sourcePath"
        }
        $sourceBytes = Get-PathBytes $sourcePath
        Remove-Item -LiteralPath $sourcePath -Recurse -Force
        $removed.Add([pscustomobject]@{ path = $sourcePath; kind = 'migrated-build-source'; bytes = $sourceBytes })
    }
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    $report = [ordered]@{
        schema = 'ALVEOLUS-CLEANUP-v1'
        completed_utc = [DateTime]::UtcNow.ToString('o')
        preserved_build = $preservedPath
        removed = @($removed)
        removed_bytes = $(
            $removedByteTotal = 0L
            foreach ($removedItem in $removed) { $removedByteTotal += [long]$removedItem.bytes }
            $removedByteTotal
        )
    }
    $reportPath = Assert-SafeManagedWritePath (Join-Path $reportRoot ('cleanup-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.json'))
    [IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Write-Host "ALVEOLUS_CLEANUP_OK removed=$($removed.Count) bytes=$($report.removed_bytes) preserved=$preservedPath report=$reportPath"
}

function Assert-SemVer {
    param([string]$Value)
    if ($Value -notmatch '^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
        throw 'Version must be a valid semantic version such as 0.1.0.'
    }
}

function Test-AllowedRemoteLocation {
    param([string]$Location)
    if ($Location -eq $script:ReleaseRemoteUrl) { return $true }
    $localFixtureAllowed = $AllowLocalTestRemote -or $env:ALVEOLUS_ALLOW_LOCAL_TEST_REMOTE -eq '1'
    if (-not $localFixtureAllowed) { return $false }
    $fixtureMarker = [IO.Path]::Combine('.codex-temp', 'reports', 'codex-workflow-fixture-')
    $root = [IO.Path]::GetFullPath($script:ProjectRoot)
    if ($root.IndexOf($fixtureMarker, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    try {
        $remotePath = [IO.Path]::GetFullPath($Location)
        $fixtureRoot = $root.Substring(0, $root.IndexOf($fixtureMarker, [StringComparison]::OrdinalIgnoreCase) + $fixtureMarker.Length)
        return $remotePath.StartsWith($fixtureRoot, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Invoke-Release {
    Assert-Repository
    if ($Commit -notmatch '^[0-9a-fA-F]{40}$') { throw 'Release requires one full 40-character commit SHA.' }
    Assert-SemVer $Version
    $expectedConfirmation = "ALVEOLUS-RELEASE-v1 $Commit origin/dev"
    if ($Confirm -cne $expectedConfirmation) {
        throw "Release confirmation must be exact: $expectedConfirmation"
    }
    $branch = Invoke-GitText @('branch', '--show-current')
    if ($branch -ne $script:LocalMainBranch) { throw "Release is allowed only from $($script:LocalMainBranch)." }
    $head = Invoke-GitText @('rev-parse', 'HEAD')
    if ($head -cne $Commit.ToLowerInvariant()) { throw "HEAD $head does not match approved commit $Commit." }
    if (-not [string]::IsNullOrWhiteSpace((Invoke-GitText @('status', '--porcelain=v1', '--untracked-files=all')))) {
        throw 'Release requires a clean working tree.'
    }
    $versionInfo = Get-VersionInfo
    if ($null -eq $versionInfo.release_version -or [string]$versionInfo.release_version -cne $Version) {
        throw "ALVEOLUS_VERSION.json must contain release_version $Version in the approved commit."
    }
    $remoteLocation = Invoke-GitText @('remote', 'get-url', '--push', $script:ReleaseRemote)
    if (-not (Test-AllowedRemoteLocation $remoteLocation)) {
        throw "Unexpected push URL for origin: $remoteLocation"
    }
    $gatePath = Get-GatePath
    if (Test-Path -LiteralPath $gatePath) { throw 'A release gate already exists; inspect and remove it before requesting a new release.' }
    $token = [Guid]::NewGuid().ToString('N')
    $gate = [ordered]@{
        schema = $script:ReleaseGateSchema
        token = $token
        head = $head
        branch = $branch
        remote = $script:ReleaseRemote
        remote_location = $remoteLocation
        remote_ref = $script:ReleaseRemoteRef
        version = $Version
        actions = @('git-push')
        session_id = $(if ($env:CODEX_THREAD_ID) { $env:CODEX_THREAD_ID } elseif ($env:CODEX_SESSION_ID) { $env:CODEX_SESSION_ID } else { 'manual' })
        turn_id = $(if ($env:CODEX_TURN_ID) { $env:CODEX_TURN_ID } else { 'manual' })
        created_utc = [DateTime]::UtcNow.ToString('o')
        expires_utc = [DateTime]::UtcNow.AddMinutes(10).ToString('o')
    }
    $temporaryGate = "$gatePath.$token.tmp"
    [IO.File]::WriteAllText($temporaryGate, ($gate | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryGate -Destination $gatePath
    $previousToken = $env:ALVEOLUS_RELEASE_TOKEN
    $previousTestFlag = $env:ALVEOLUS_ALLOW_LOCAL_TEST_REMOTE
    try {
        $env:ALVEOLUS_RELEASE_TOKEN = $token
        if ($AllowLocalTestRemote) { $env:ALVEOLUS_ALLOW_LOCAL_TEST_REMOTE = '1' }
        $hookPath = Join-Path $script:ProjectRoot '.githooks'
        & git -C $script:ProjectRoot -c "core.hooksPath=$hookPath" push --porcelain $script:ReleaseRemote "refs/heads/$($script:LocalMainBranch):$($script:ReleaseRemoteRef)"
        if ($LASTEXITCODE -ne 0) { throw "Git push failed with exit code $LASTEXITCODE. The one-shot gate was consumed." }
    } finally {
        if (Test-Path -LiteralPath $gatePath) { Remove-Item -LiteralPath $gatePath -Force }
        $env:ALVEOLUS_RELEASE_TOKEN = $previousToken
        $env:ALVEOLUS_ALLOW_LOCAL_TEST_REMOTE = $previousTestFlag
    }
    Write-Host "ALVEOLUS_RELEASE_OK commit=$head target=origin/dev version=$Version"
}

function Invoke-PrePushCheck {
    Assert-Repository
    if ([string]::IsNullOrWhiteSpace($env:ALVEOLUS_RELEASE_TOKEN)) {
        throw 'Direct git push blocked. Use an explicitly authorized ALVEOLUS release transaction.'
    }
    $gatePath = Get-GatePath
    if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf)) { throw 'Release gate is missing or already consumed.' }
    $gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json -ErrorAction Stop
    if ([string]$gate.schema -ne $script:ReleaseGateSchema) { throw 'Release gate schema mismatch.' }
    if ([string]$gate.token -cne $env:ALVEOLUS_RELEASE_TOKEN) { throw 'Release gate token mismatch.' }
    if ([DateTime]::Parse([string]$gate.expires_utc).ToUniversalTime() -le [DateTime]::UtcNow) { throw 'Release gate expired.' }
    if ([string]$gate.remote -cne $HookRemoteName -or [string]$gate.remote_location -cne $HookRemoteLocation) { throw 'Release remote mismatch.' }
    if ([string]$gate.remote_ref -cne $script:ReleaseRemoteRef) { throw 'Release target ref mismatch.' }
    if ([string]$gate.branch -cne (Invoke-GitText @('branch', '--show-current'))) { throw 'Release branch changed after approval.' }
    if ([string]$gate.head -cne (Invoke-GitText @('rev-parse', 'HEAD'))) { throw 'Release HEAD changed after approval.' }
    $versionInfo = Get-VersionInfo
    if ($null -eq $versionInfo.release_version -or [string]$versionInfo.release_version -cne [string]$gate.version) { throw 'Release version changed after approval.' }
    if (-not (Test-AllowedRemoteLocation $HookRemoteLocation)) { throw 'Release push URL is not allowlisted.' }
    $lines = @([Console]::In.ReadToEnd() -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -ne 1) { throw 'Release must update exactly one ref.' }
    $parts = @($lines[0] -split '\s+')
    if ($parts.Count -ne 4) { throw 'Malformed pre-push ref description.' }
    $expectedLocalRef = "refs/heads/$($script:LocalMainBranch)"
    if ($parts[0] -cne $expectedLocalRef -or $parts[1] -cne [string]$gate.head -or $parts[2] -cne $script:ReleaseRemoteRef) {
        throw 'Pre-push ref or commit does not match the approved release.'
    }
    if ($parts[1] -eq $script:ZeroOid) { throw 'Deleting the release ref is forbidden.' }
    $claimedPath = "$gatePath.claimed.$([Guid]::NewGuid().ToString('N'))"
    Move-Item -LiteralPath $gatePath -Destination $claimedPath
    Remove-Item -LiteralPath $claimedPath -Force
    [Console]::Error.WriteLine("ALVEOLUS_PRE_PUSH_OK commit=$($parts[1]) target=$($parts[2])")
}

function Write-Help {
    @'
ALVEOLUS local workflow

  .\ALVEOLUS.cmd status [-Json]       Show local source, cached GitHub comparison, builds and worktrees.
  .\ALVEOLUS.cmd setup                Enable push.default=nothing and the versioned pre-push guard.
  .\ALVEOLUS.cmd preflight            Verify the canonical local branch and push guard.
  .\ALVEOLUS.cmd editor               Open the project in Godot 4.7.1.
  .\ALVEOLUS.cmd play                 Start the project locally.
  .\ALVEOLUS.cmd build-web            Export a timestamped local web build with manifest.
  .\ALVEOLUS.cmd open-build           Open the newest registered build and print its local server command.
  .\ALVEOLUS.cmd cleanup-preview      List generated artifacts that cleanup would remove.
  .\ALVEOLUS.cmd cleanup-apply        Preserve the newest web build and remove previewed artifacts.

Git commits are local. GitHub remains unchanged until a separate explicit release request names
the full SHA and the exact ALVEOLUS-RELEASE-v1 confirmation. Do not call release for ordinary work.
'@ | Write-Host
}

try {
    switch ($Command) {
        'status' { Write-Status }
        'setup' { Invoke-Setup }
        'preflight' { Invoke-Preflight }
        'editor' { Start-Godot -Editor }
        'play' { Start-Godot }
        'build-web' { Invoke-WebBuild }
        'open-build' { Open-LatestBuild }
        'cleanup-preview' { Invoke-Cleanup }
        'cleanup-apply' { Invoke-Cleanup -Apply }
        'release' { Invoke-Release }
        'pre-push-check' { Invoke-PrePushCheck }
        'help' { Write-Help }
    }
} catch {
    [Console]::Error.WriteLine("ALVEOLUS_WORKFLOW_ERROR: $($_.Exception.Message)")
    exit 1
}
