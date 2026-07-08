# git-cleanup

A one-command PowerShell utility that cleans up the git repository in your
**current directory** — not the folder this script lives in.

## What it does

In order, it:

1. Verifies the current directory is inside a git repository.
2. Detects the root/default branch (`origin/HEAD` → `git remote show origin` → `main`/`master`).
3. Checks the working tree; if dirty it warns and skips the branch switch (unless `-Stash`).
4. Fetches all remotes and prunes stale remote-tracking branches (`git fetch --all --prune`).
5. Switches to the root branch.
6. Pulls the latest changes (`git pull --ff-only`).
7. Deletes local branches whose upstream is **gone** (skips the root and current branch).
8. Runs `git gc --prune=now`.
9. Prints a summary.

## Install

From this folder, run once:

```powershell
.\Install-GitCleanup.ps1
```

This adds the folder to your **user** PATH (idempotent). Open a **new** terminal
afterwards. The included `git-cleanup.cmd` shim means `git-cleanup` works from
both PowerShell and cmd.exe without any PATHEXT changes.

To remove it later:

```powershell
.\Install-GitCleanup.ps1 -Uninstall
```

## Usage

Run from inside any git repository:

```powershell
git-cleanup            # full cleanup
git-cleanup -DryRun    # preview stale-branch deletions, no changes
git-cleanup -Stash     # auto-stash/pop dirty changes around the switch
git-cleanup -Force     # force-delete unmerged gone branches (git branch -D)
git-cleanup -SkipGc    # skip the git gc step
```

## Parameters

| Parameter  | Description                                                            |
|------------|------------------------------------------------------------------------|
| `-DryRun`  | Preview which stale local branches would be deleted; makes no changes. |
| `-Force`   | Use `git branch -D` to delete gone branches even if not fully merged.  |
| `-Stash`   | Auto-stash uncommitted changes before switching, then pop afterwards.  |
| `-SkipGc`  | Skip the `git gc --prune=now` step.                                    |

## Notes

- Safe by default: uses `git branch -d`, so unmerged branches are not dropped
  unless you pass `-Force`.
- If the working tree is dirty and you don't pass `-Stash`, the fetch/prune and
  branch cleanup still run, but the branch switch and pull are skipped.
