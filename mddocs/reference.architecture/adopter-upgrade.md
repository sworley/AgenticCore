# Adopter Upgrade Runbook

**Defined by:** ADR-0015 (distribution and propagation)
**Audience:** AgenticCore adopter project stewards
**Companion:** [Adopter Reconciliation Model](adopter-reconciliation.md)

---

## Overview

An adopter's repo is a **severed, versioned export** (ADR-0015 D-1) - it starts from
a clean `git init` with no framework remote, upstream reference, or commit history.
The relationship between framework and adopter is **baseline-versioned, not
continuously coupled**: there is **no automatic pull** and **no in-place framework
upgrade of an already-adopted tree**.

Upgrading means re-exporting a newer framework release **into a fresh working copy**
and then **manually reconciling the delta** against the adopter's own customizations.
The release's [Adopter Impact](../management/delivery/release-process.md) classification
(Required / Optional / Transparent) tells you what actually needs reconciling.

> **Do not run `export-framework.sh` inside a previously-adopted tree.** Framework
> baselines are severed and cannot be retrofitted in place (ADR-0015). Re-export into
> a new working copy and reconcile.

---

## Prerequisites

- The adopter's current baseline version: read the repo-root `framework-version.txt`
  (written by `export-framework.sh` at initialization).
- The target framework release tag you are upgrading to (e.g. `v0.8.0`).
- A recent backup of the adopter's customizations (or the adopter repo itself).

---

## Procedure

### 1. Review the release delta

For every release between your current baseline and the target, read the
**Adopter Impact** section of the release notes
(`mddocs/management/delivery/releases/vX.Y.Z.md`) and note the class of each change:

| Class | Adopter action |
|---|---|
| **Transparent** | None required |
| **Optional** | Evaluate and adopt at your discretion |
| **Required** | Must reconcile before upgrading (a migration note is included) |

Apply the migration notes for every `Required` item in order (oldest to newest).

### 2. Re-export the target release into a new working copy

```sh
# From a fresh checkout of the framework at the target tag
git clone --branch <TARGET_TAG> <framework-repo> /tmp/fw-<TARGET_TAG>
cd /tmp/fw-<TARGET_TAG>
./mddocs/scripts/export-framework.sh --target <new-working-dir> --flow empty --slug <SLUG>
```

This produces a **new** adopter working copy (severed, git-init'd) at the target
baseline. Do **not** point `--target` at your existing adopted tree.

### 3. Reconcile the delta

Copy over / re-apply the adopter's customizations from your previous working copy,
reconciling against the new export:
- Re-apply adopter-specific docs, task queues, guardrails, and configuration.
- Drop anything the new release removed (e.g. removed bootstrap scripts).
- Convert any replaced/renamed paths per the release notes.

### 4. Update the baseline record

```sh
# framework-version.txt is the permanent baseline marker; set it to the new release.
echo "<TARGET_TAG>" > framework-version.txt
```

### 5. Validate

- Run the adopter's own tests (and the framework quality gates that ship with the
  export - `check-links.sh` etc., if present).
- Confirm the adopter tree is clean and severed (no framework remote/history).

---

## Known limitations

- Automated validation (CI `verify`, the export/severing harnesses) covers the
  **adoption surface** (Flow A/B export, re-home, target handling) and the
  **re-export / idempotence guard** (D-7.4): re-running `export-framework.sh`
  against an already-adopted target is a fail-closed **no-op** that preserves the
  baseline, `framework-version.txt`, and commit count, and the fail-closed
  allowlist set ships exactly the `allowed_in_adopter_repos: true` artifacts. The
  **cross-version adopter "upgrade + reconcile" step itself** is a **manual,
  adopter-scheduled process** by design (ADR-0015) and is not exercised by an
  automated harness - an adopter reconciles the delta between their baseline and
  the new release in a fresh working copy.

---

## Rollback

Upgrade is non-destructive by construction (the old working copy is untouched; the
new re-export is separate). To roll back, simply discard the new working copy and
continue from the previous one - **`framework-version.txt`** must be reverted too.
