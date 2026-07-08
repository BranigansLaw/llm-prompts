#Requires -Version 5.1
<#
.SYNOPSIS
    Cleans up the git repository in the current directory.

.DESCRIPTION
    Operates on the git repository of the CURRENT working directory (not the
    location of this script). It performs the following, in order:

      1. Validates the current directory is inside a git work tree.
      2. Detects the root/default branch (origin/HEAD, else remote show, else
         main/master).
      3. Checks the working tree; if dirty it warns and skips the branch switch
         unless -Stash is supplied.
      4. Fetches all remotes and prunes stale remote-tracking branches.
      5. Switches to the root branch (when the tree is clean or stashed).
      6. Pulls the latest changes (fast-forward only).
      7. Deletes local branches whose upstream is "gone" (skips root/current).
      8. Runs 'git gc --prune=now' (unless -SkipGc).
      9. Prints a summary.

.PARAMETER DryRun
    Preview the local branches that would be deleted without changing anything.

.PARAMETER Force
    Use 'git branch -D' to delete gone branches even if not fully merged.

.PARAMETER Stash
    Automatically stash uncommitted changes before switching branches and pop
    them afterwards.

.PARAMETER SkipGc
    Skip the 'git gc --prune=now' step.

.EXAMPLE
    git-cleanup
    Runs the full cleanup on the repository in the current directory.

.EXAMPLE
    git-cleanup -DryRun
    Shows which stale local branches would be deleted, without making changes.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Stash,
    [switch]$SkipGc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Helpers ---------------------------------------------------------------

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Note {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "!!  $Message" -ForegroundColor Yellow
}

# Invoke git and return trimmed output. Throws on non-zero exit when $Check.
# git writes informational messages (e.g. "From https://...") to stderr, so we
# relax $ErrorActionPreference during the call and rely on the exit code
# instead. Merged stderr is only surfaced as a failure when the exit code is
# non-zero.
function Invoke-Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Check
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git @Arguments 2>&1
    }
    finally {
        $ErrorActionPreference = $previous
    }
    $exit = $LASTEXITCODE
    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    $text = $text.TrimEnd()
    if ($Check -and $exit -ne 0) {
        throw "git $($Arguments -join ' ') failed (exit $exit):`n$text"
    }
    return [pscustomobject]@{ ExitCode = $exit; Output = $text }
}

function Test-GitAvailable {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "git was not found on PATH. Install Git and try again."
    }
}

# Determine the repository's default/root branch name.
function Get-RootBranch {
    # 1. origin/HEAD symbolic ref (fast, no network).
    $ref = Invoke-Git -Arguments @('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD')
    if ($ref.ExitCode -eq 0 -and $ref.Output) {
        return ($ref.Output -replace '^refs/remotes/origin/', '')
    }

    # 2. Ask the remote directly (requires network).
    $show = Invoke-Git -Arguments @('remote', 'show', 'origin')
    if ($show.ExitCode -eq 0) {
        foreach ($line in ($show.Output -split "`n")) {
            if ($line -match 'HEAD branch:\s*(\S+)') {
                if ($Matches[1] -ne '(unknown)') { return $Matches[1] }
            }
        }
    }

    # 3. Fall back to a conventional local branch.
    foreach ($candidate in @('main', 'master')) {
        $verify = Invoke-Git -Arguments @('rev-parse', '--verify', '--quiet', "refs/heads/$candidate")
        if ($verify.ExitCode -eq 0) { return $candidate }
    }

    throw "Could not determine the root branch. Set origin/HEAD with: git remote set-head origin -a"
}

# --- Main ------------------------------------------------------------------

Test-GitAvailable

# Confirm we are inside a work tree of the CURRENT directory.
$inside = Invoke-Git -Arguments @('rev-parse', '--is-inside-work-tree')
if ($inside.ExitCode -ne 0 -or $inside.Output -ne 'true') {
    throw "The current directory is not inside a git repository: $($PWD.Path)"
}

$repoRoot = (Invoke-Git -Arguments @('rev-parse', '--show-toplevel') -Check).Output
Write-Step "Repository: $repoRoot"

$currentBranch = (Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD') -Check).Output
$rootBranch = Get-RootBranch
Write-Note "Current branch: $currentBranch"
Write-Note "Root branch:    $rootBranch"

if ($DryRun) {
    Write-Warn "DryRun enabled - no changes will be made."
}

# Assess working tree cleanliness.
$status = (Invoke-Git -Arguments @('status', '--porcelain')).Output
$isDirty = [bool]$status
$didStash = $false

if ($isDirty) {
    if ($Stash -and -not $DryRun) {
        Write-Step "Stashing uncommitted changes"
        Invoke-Git -Arguments @('stash', 'push', '--include-untracked', '--message', 'git-cleanup auto-stash') -Check | Out-Null
        $didStash = $true
    }
    else {
        Write-Warn "Working tree has uncommitted changes; branch switch will be skipped (use -Stash to auto-stash)."
    }
}

try {
    # 1. Fetch latest refs and prune stale remote-tracking branches.
    Write-Step "Fetching all remotes and pruning stale refs"
    if ($DryRun) {
        Write-Note "would run: git fetch --all --prune"
    }
    else {
        Invoke-Git -Arguments @('fetch', '--all', '--prune') -Check | Out-Null
    }

    # 2. Switch to the root branch (only if tree is clean or was stashed).
    $canSwitch = (-not $isDirty) -or $didStash
    if ($currentBranch -ne $rootBranch) {
        if ($canSwitch) {
            Write-Step "Switching to '$rootBranch'"
            if ($DryRun) {
                Write-Note "would run: git checkout $rootBranch"
            }
            else {
                Invoke-Git -Arguments @('checkout', $rootBranch) -Check | Out-Null
            }
        }
        else {
            Write-Warn "Skipping switch to '$rootBranch' (working tree dirty)."
        }
    }

    # 3. Pull latest on the root branch (fast-forward only).
    $onRoot = $DryRun -or ((Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Output -eq $rootBranch)
    if ($onRoot) {
        Write-Step "Pulling latest for '$rootBranch' (fast-forward only)"
        if ($DryRun) {
            Write-Note "would run: git pull --ff-only"
        }
        else {
            $pull = Invoke-Git -Arguments @('pull', '--ff-only')
            if ($pull.ExitCode -ne 0) {
                Write-Warn "Fast-forward pull failed; resolve manually:`n$($pull.Output)"
            }
        }
    }
    else {
        Write-Warn "Not on '$rootBranch'; skipping pull."
    }

    # 4. Delete local branches whose upstream is gone.
    Write-Step "Scanning for local branches with a deleted upstream"
    # Skip the branch that is actually checked out now (git can't delete HEAD)
    # and the root branch. Note: this is re-read after the switch, so a stale
    # branch you started on is still eligible once we've moved to root.
    $activeBranch = (Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Output
    $branchLines = (Invoke-Git -Arguments @('branch', '-vv')).Output -split "`n"
    $goneBranches = @()
    foreach ($line in $branchLines) {
        # Format: "* name  <sha> [origin/name: gone] subject"
        $name = ($line -replace '^[*+]?\s*', '') -split '\s+' | Select-Object -First 1
        if (-not $name) { continue }
        if ($line -match '\[[^\]]*:\s*gone\]') {
            if ($name -eq $rootBranch -or $name -eq $activeBranch) {
                if ($name -eq $activeBranch -and $name -ne $rootBranch) {
                    Write-Warn "Skipping '$name': it is currently checked out (dirty tree prevented switching to '$rootBranch')."
                }
                continue
            }
            $goneBranches += $name
        }
    }

    if ($goneBranches.Count -eq 0) {
        Write-Note "No stale local branches found."
    }
    else {
        $deleteFlag = if ($Force) { '-D' } else { '-d' }
        foreach ($branch in $goneBranches) {
            if ($DryRun) {
                Write-Note "would delete: $branch (git branch $deleteFlag $branch)"
            }
            else {
                $del = Invoke-Git -Arguments @('branch', $deleteFlag, $branch)
                if ($del.ExitCode -eq 0) {
                    Write-Note "deleted: $branch"
                }
                else {
                    Write-Warn "Could not delete '$branch' (use -Force to override):`n$($del.Output)"
                }
            }
        }
    }

    # 5. Garbage collect / prune unreachable objects.
    if ($SkipGc) {
        Write-Note "Skipping git gc (-SkipGc)."
    }
    else {
        Write-Step "Running git gc --prune=now"
        if ($DryRun) {
            Write-Note "would run: git gc --prune=now"
        }
        else {
            Invoke-Git -Arguments @('gc', '--prune=now') -Check | Out-Null
        }
    }
}
finally {
    if ($didStash) {
        Write-Step "Restoring stashed changes"
        $pop = Invoke-Git -Arguments @('stash', 'pop')
        if ($pop.ExitCode -ne 0) {
            Write-Warn "Could not automatically pop the stash; resolve manually:`n$($pop.Output)"
        }
    }
}

# --- Summary ---------------------------------------------------------------

$finalBranch = (Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Output
Write-Host ""
Write-Host "Cleanup complete." -ForegroundColor Green
Write-Note "Root branch:      $rootBranch"
Write-Note "Current branch:   $finalBranch"
$deletedCount = if ($DryRun) { "$($goneBranches.Count) (dry run)" } else { $goneBranches.Count }
Write-Note "Stale branches:   $deletedCount"
