#!/usr/bin/env bash
#
# git-cleanup — Cleans up the git repository in the CURRENT working directory
# (not the location of this script). It performs the following, in order:
#
#   1. Validates the current directory is inside a git work tree.
#   2. Detects the root/default branch (origin/HEAD, else remote show, else
#      main/master).
#   3. Checks the working tree; if dirty it warns and skips the branch switch
#      unless --stash is supplied.
#   4. Fetches all remotes and prunes stale remote-tracking branches.
#   5. Switches to the root branch (when the tree is clean or stashed).
#   6. Pulls the latest changes (fast-forward only).
#   7. Deletes local branches whose upstream is "gone" (skips root/current).
#   8. Runs 'git gc --prune=now' (unless --skip-gc).
#   9. Prints a summary.
#
# Usage:
#   git-cleanup                 # full cleanup
#   git-cleanup --dry-run       # preview stale-branch deletions, no changes
#   git-cleanup --stash         # auto-stash/pop dirty changes around the switch
#   git-cleanup --force         # force-delete unmerged gone branches (branch -D)
#   git-cleanup --skip-gc       # skip the git gc step
#   git-cleanup --help          # show this help

set -euo pipefail

# --- Options ---------------------------------------------------------------

DRY_RUN=0
FORCE=0
STASH=0
SKIP_GC=0

usage() {
    sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n) DRY_RUN=1 ;;
        --force|-f)   FORCE=1 ;;
        --stash|-s)   STASH=1 ;;
        --skip-gc)    SKIP_GC=1 ;;
        --help|-h)    usage; exit 0 ;;
        *)
            printf '!!  Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# --- Colors / output helpers ----------------------------------------------

if [[ -t 1 ]]; then
    C_CYAN=$'\033[36m'
    C_GRAY=$'\033[90m'
    C_YELLOW=$'\033[33m'
    C_GREEN=$'\033[32m'
    C_RESET=$'\033[0m'
else
    C_CYAN='' C_GRAY='' C_YELLOW='' C_GREEN='' C_RESET=''
fi

write_step() { printf '%s==> %s%s\n' "$C_CYAN" "$1" "$C_RESET"; }
write_note() { printf '%s    %s%s\n' "$C_GRAY" "$1" "$C_RESET"; }
write_warn() { printf '%s!!  %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }

# --- Preconditions ---------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
    printf '!!  git was not found on PATH. Install Git and try again.\n' >&2
    exit 1
fi

if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null || echo false)" != "true" ]]; then
    printf '!!  The current directory is not inside a git repository: %s\n' "$PWD" >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
write_step "Repository: $repo_root"

# --- Determine the repository's default/root branch ------------------------

get_root_branch() {
    local ref show line candidate

    # 1. origin/HEAD symbolic ref (fast, no network).
    if ref="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"; then
        if [[ -n "$ref" ]]; then
            printf '%s\n' "${ref#refs/remotes/origin/}"
            return 0
        fi
    fi

    # 2. Ask the remote directly (requires network).
    if show="$(git remote show origin 2>/dev/null)"; then
        line="$(printf '%s\n' "$show" | sed -n 's/.*HEAD branch:[[:space:]]*\(.*\)/\1/p' | head -n1)"
        if [[ -n "$line" && "$line" != "(unknown)" ]]; then
            printf '%s\n' "$line"
            return 0
        fi
    fi

    # 3. Fall back to a conventional local branch.
    for candidate in main master; do
        if git rev-parse --verify --quiet "refs/heads/$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf '!!  Could not determine the root branch. Set origin/HEAD with: git remote set-head origin -a\n' >&2
    return 1
}

current_branch="$(git rev-parse --abbrev-ref HEAD)"
root_branch="$(get_root_branch)"
write_note "Current branch: $current_branch"
write_note "Root branch:    $root_branch"

if [[ $DRY_RUN -eq 1 ]]; then
    write_warn "DryRun enabled - no changes will be made."
fi

# --- Assess working tree cleanliness ---------------------------------------

status="$(git status --porcelain)"
is_dirty=0
[[ -n "$status" ]] && is_dirty=1
did_stash=0

if [[ $is_dirty -eq 1 ]]; then
    if [[ $STASH -eq 1 && $DRY_RUN -eq 0 ]]; then
        write_step "Stashing uncommitted changes"
        git stash push --include-untracked --message 'git-cleanup auto-stash' >/dev/null
        did_stash=1
    else
        write_warn "Working tree has uncommitted changes; branch switch will be skipped (use --stash to auto-stash)."
    fi
fi

# Ensure the stash is restored on exit if we created one.
restore_stash() {
    if [[ $did_stash -eq 1 ]]; then
        write_step "Restoring stashed changes"
        if ! git stash pop; then
            write_warn "Could not automatically pop the stash; resolve manually."
        fi
    fi
}
trap restore_stash EXIT

# --- 1. Fetch and prune ----------------------------------------------------

write_step "Fetching all remotes and pruning stale refs"
if [[ $DRY_RUN -eq 1 ]]; then
    write_note "would run: git fetch --all --prune"
else
    git fetch --all --prune >/dev/null
fi

# --- 2. Switch to the root branch (only if clean or stashed) ---------------

can_switch=0
{ [[ $is_dirty -eq 0 ]] || [[ $did_stash -eq 1 ]]; } && can_switch=1

if [[ "$current_branch" != "$root_branch" ]]; then
    if [[ $can_switch -eq 1 ]]; then
        write_step "Switching to '$root_branch'"
        if [[ $DRY_RUN -eq 1 ]]; then
            write_note "would run: git checkout $root_branch"
        else
            git checkout "$root_branch" >/dev/null
        fi
    else
        write_warn "Skipping switch to '$root_branch' (working tree dirty)."
    fi
fi

# --- 3. Pull latest on the root branch (fast-forward only) -----------------

active_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ $DRY_RUN -eq 1 || "$active_branch" == "$root_branch" ]]; then
    write_step "Pulling latest for '$root_branch' (fast-forward only)"
    if [[ $DRY_RUN -eq 1 ]]; then
        write_note "would run: git pull --ff-only"
    else
        if ! git pull --ff-only; then
            write_warn "Fast-forward pull failed; resolve manually."
        fi
    fi
else
    write_warn "Not on '$root_branch'; skipping pull."
fi

# --- 4. Delete local branches whose upstream is gone -----------------------

write_step "Scanning for local branches with a deleted upstream"
active_branch="$(git rev-parse --abbrev-ref HEAD)"
gone_branches=()

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Format: "* name  <sha> [origin/name: gone] subject"
    name="$(printf '%s\n' "$line" | sed -E 's/^[*+]?[[:space:]]*//' | awk '{print $1}')"
    [[ -z "$name" ]] && continue
    if printf '%s\n' "$line" | grep -Eq '\[[^]]*:[[:space:]]*gone\]'; then
        if [[ "$name" == "$root_branch" || "$name" == "$active_branch" ]]; then
            if [[ "$name" == "$active_branch" && "$name" != "$root_branch" ]]; then
                write_warn "Skipping '$name': it is currently checked out (dirty tree prevented switching to '$root_branch')."
            fi
            continue
        fi
        gone_branches+=("$name")
    fi
done < <(git branch -vv)

if [[ ${#gone_branches[@]} -eq 0 ]]; then
    write_note "No stale local branches found."
else
    delete_flag='-d'
    [[ $FORCE -eq 1 ]] && delete_flag='-D'
    for branch in "${gone_branches[@]}"; do
        if [[ $DRY_RUN -eq 1 ]]; then
            write_note "would delete: $branch (git branch $delete_flag $branch)"
        else
            if git branch "$delete_flag" "$branch" >/dev/null 2>&1; then
                write_note "deleted: $branch"
            else
                write_warn "Could not delete '$branch' (use --force to override)."
            fi
        fi
    done
fi

# --- 5. Garbage collect / prune unreachable objects ------------------------

if [[ $SKIP_GC -eq 1 ]]; then
    write_note "Skipping git gc (--skip-gc)."
else
    write_step "Running git gc --prune=now"
    if [[ $DRY_RUN -eq 1 ]]; then
        write_note "would run: git gc --prune=now"
    else
        git gc --prune=now >/dev/null
    fi
fi

# --- Summary ---------------------------------------------------------------

final_branch="$(git rev-parse --abbrev-ref HEAD)"
printf '\n%sCleanup complete.%s\n' "$C_GREEN" "$C_RESET"
write_note "Root branch:      $root_branch"
write_note "Current branch:   $final_branch"
if [[ $DRY_RUN -eq 1 ]]; then
    write_note "Stale branches:   ${#gone_branches[@]} (dry run)"
else
    write_note "Stale branches:   ${#gone_branches[@]}"
fi
