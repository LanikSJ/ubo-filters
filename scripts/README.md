# Scripts

Some of these scripts have been "borrowed" from [Fanboy](https://github.com/ryanbr/fanboy-adblock/)
All rights reserved by the original authors.

## 🔄 Script Sync Relationship

This repository (**ubo-filters**) is the **source of truth** for shared maintenance scripts.
The workflow [`.github/workflows/sync-scripts.yml`](../.github/workflows/sync-scripts.yml) automatically
syncs the following scripts to sibling repositories on push to `main`:

### ✅ Synced Scripts (copied verbatim to targets)

| Script             | Purpose                                                             |
| ------------------ | ------------------------------------------------------------------- |
| `checksum-sort.sh` | Filter list processing (sort + fop validation + headers + checksum) |
| `remove-lines.sh`  | Remove specific lines from filter lists                             |
| `install-fop.sh`   | Install the fop-cli tool                                            |

### 🎯 Target Repositories

| Repository                                                        | Branch   |
| ----------------------------------------------------------------- | -------- |
| [LanikSJ/AdmiraList](https://github.com/LanikSJ/AdmiraList)       | `main`   |
| [LanikSJ/webannoyances](https://github.com/LanikSJ/webannoyances) | `master` |

### ❌ NOT Synced (repo-specific)

| Script                        | Reason                                                             |
| ----------------------------- | ------------------------------------------------------------------ |
| `pre-commit-checksum-sort.sh` | Each repo gates on different filter paths via its own CONFIG block |
| `download-adshield.sh`        | ubo-filters only                                                   |
| `scripts/README.md`           | Differs per repo (this file)                                       |

### 🔧 Trigger Conditions

The sync workflow runs on push to `main` when any of these files change:

- `scripts/checksum-sort.sh`
- `scripts/remove-lines.sh`
- `scripts/install-fop.sh`
- `.github/workflows/sync-scripts.yml`

It can also be triggered manually via `workflow_dispatch`.

### 🔐 Authentication

Requires a fine-grained PAT (or classic token with `repo` scope) with **Contents: Read and write**
on the target repositories, stored as the `UBO_FILTERS_SYNC_TOKEN` repository secret.
