# GitHub Actions Instructions

These instructions apply to all GitHub Actions workflows. The primary goal is to
**minimize the number of artifacts that persist in a repository**, because
excess artifacts accumulate quickly, consume storage, and overload the GitHub
Actions UI/API.

Reference this file from any project instruction set that includes CI/CD
workflows.

---

## Core Rule

**A workflow should never leave behind persistent artifacts once a run
completes.** Build artifacts are only a handoff mechanism between jobs in the
same run — they are not a deliverable. Treat them as ephemeral.

Apply the protections below **only when a workflow actually produces artifacts**
(i.e. it uses `actions/upload-artifact`, `docker/build-push-action`, or pushes
container images). Do **not** add these to workflows that build and deploy in a
single step or that produce no artifacts:

- Azure Static Web Apps workflows that use `Azure/static-web-apps-deploy` with
  in-action build (no `upload-artifact` step) produce no artifacts — leave them
  alone.
- Pure Terraform workflows with no build/upload step produce no artifacts —
  leave them alone.

---

## Required Protections for Artifact-Producing Workflows

### 1. Constrain every `upload-artifact` step

Every `actions/upload-artifact` step **must** set:

```yaml
      - name: Upload build artifact
        uses: actions/upload-artifact@v6
        with:
          name: function-app
          path: <path>
          if-no-files-found: error   # fail fast instead of creating an empty/broken artifact
          retention-days: 1          # fail-safe cap; do not rely on the 90-day default
```

- `retention-days: 1` is a safety net so nothing lingers even if the cleanup
  job (below) is skipped or removed.
- `if-no-files-found: error` prevents silent, useless empty artifacts.

### 2. Add a final cleanup job that deletes the run's artifacts

Add one `cleanup-artifacts` job that depends on **every** other job in the
workflow and runs with `if: always()`. This deletes all artifacts for the run
as soon as the deploy jobs have consumed them, so nothing persists:

```yaml
  cleanup-artifacts:
    name: Clean Up Build Artifacts
    needs: [build, terraform, deploy]   # list ALL other jobs
    runs-on: ubuntu-latest
    if: always()
    permissions:
      actions: write
    steps:
      - name: Delete artifacts for this workflow run
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh api --paginate "/repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts?per_page=100" \
            --jq '.artifacts[].id' |
          while read -r artifact_id; do
            gh api --method DELETE "/repos/${GITHUB_REPOSITORY}/actions/artifacts/${artifact_id}"
          done
```

- `needs` must include **all** jobs so cleanup runs last, after every deploy job
  has downloaded what it needs.
- `if: always()` ensures artifacts are removed even when an upstream job fails or
  is skipped (e.g. a PR run that builds but never deploys).
- Scope `permissions` to `actions: write` on this job only — do not widen
  workflow-level permissions.

### 3. Suppress Docker build-record artifacts

`docker/build-push-action` uploads a build-record/summary artifact by default.
Disable it on every Docker build step:

```yaml
      - name: Build and push Docker image
        uses: docker/build-push-action@v7
        env:
          DOCKER_BUILD_SUMMARY: false
          DOCKER_BUILD_RECORD_UPLOAD: false
        with:
          ...
```

### 4. Prune old container image versions

When a workflow pushes container images (e.g. to GHCR) on every run, tagged
versions accumulate as package bloat. Add a pruning job:

```yaml
  prune-images:
    runs-on: ubuntu-latest
    needs: <image-build-job>
    if: github.ref == 'refs/heads/main'
    permissions:
      packages: write
    steps:
      - name: Delete old GHCR image versions
        uses: snok/container-retention-policy@v3.1.0
        with:
          account: ${{ github.repository_owner }}
          token: ${{ secrets.GHCR_PAT }}
          image-names: <package-name>
          image-tags: '!latest'   # never delete the latest tag
          cut-off: 1w
          keep-n-most-recent: 5
```

---

## Checklist Before Finishing a Workflow Change

- [ ] Does the workflow produce artifacts? If not, add none of the above.
- [ ] Every `upload-artifact` step has `retention-days: 1` and
      `if-no-files-found: error`.
- [ ] A single `cleanup-artifacts` job exists, `needs` every other job, and runs
      `if: always()` with `permissions: actions: write`.
- [ ] Every `docker/build-push-action` step sets `DOCKER_BUILD_SUMMARY: false`
      and `DOCKER_BUILD_RECORD_UPLOAD: false`.
- [ ] Any job that pushes container images has a corresponding pruning job.
- [ ] No innocuous or redundant checks were added that do not reduce artifacts.
