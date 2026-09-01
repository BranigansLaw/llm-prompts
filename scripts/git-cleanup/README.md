# git-cleanup

A one-command utility (PowerShell **and** bash) that cleans up the git
repository in your **current directory** — not the folder this script lives in.

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

## Install (Windows / PowerShell)

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

## Install (Linux / bash)

From this folder, run once:

```bash
./install-git-cleanup.sh
```

This symlinks `git-cleanup` into `~/.local/bin` (falling back to
`/usr/local/bin`) pointing at `git-cleanup.sh`. It's idempotent. If the chosen
bin directory is not on your `PATH`, the installer prints the `export PATH=...`
line to add to your `~/.bashrc` or `~/.zshrc`.

Options:

```bash
./install-git-cleanup.sh --bin-dir ~/bin   # install into a custom directory
./install-git-cleanup.sh --uninstall       # remove the symlink
```

You can also skip the installer and run the script directly:

```bash
./git-cleanup.sh --dry-run
```

## Usage

Run from inside any git repository:

**PowerShell**

```powershell
git-cleanup            # full cleanup
git-cleanup -DryRun    # preview stale-branch deletions, no changes
git-cleanup -Stash     # auto-stash/pop dirty changes around the switch
git-cleanup -Force     # force-delete unmerged gone branches (git branch -D)
git-cleanup -SkipGc    # skip the git gc step
```

**bash**

```bash
git-cleanup            # full cleanup
git-cleanup --dry-run  # preview stale-branch deletions, no changes
git-cleanup --stash    # auto-stash/pop dirty changes around the switch
git-cleanup --force    # force-delete unmerged gone branches (git branch -D)
git-cleanup --skip-gc  # skip the git gc step
```

## Parameters

| PowerShell | bash         | Description                                                            |
|------------|--------------|------------------------------------------------------------------------|
| `-DryRun`  | `--dry-run`  | Preview which stale local branches would be deleted; makes no changes. |
| `-Force`   | `--force`    | Use `git branch -D` to delete gone branches even if not fully merged.  |
| `-Stash`   | `--stash`    | Auto-stash uncommitted changes before switching, then pop afterwards.  |
| `-SkipGc`  | `--skip-gc`  | Skip the `git gc --prune=now` step.                                    |

## Notes

- Safe by default: uses `git branch -d`, so unmerged branches are not dropped
  unless you pass `-Force`.
- If the working tree is dirty and you don't pass `-Stash`, the fetch/prune and
  branch cleanup still run, but the branch switch and pull are skipped.
