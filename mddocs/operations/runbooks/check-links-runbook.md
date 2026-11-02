# Runbook: check-links — mdBook Internal Link Validator

**Script:** `mddocs/scripts/check-links.sh`
**Purpose:** Scan all markdown files in `mddocs/` and report any internal links
that point to non-existent files. Satisfies the mdbook link gate standing rule
before marking a branch `branch_ready`.

---

## Prerequisites

| Tool | Notes |
|---|---|
| `sh` | POSIX sh — no extra dependencies |
| `find`, `grep`, `sed` | System tools, available on macOS and Linux |

No installation required.

---

## Usage

Run from the repository root:

```sh
# Standard check — report broken links
./mddocs/scripts/check-links.sh

# Check a different directory
./mddocs/scripts/check-links.sh --dir mddocs/adr

# Verbose — show every link checked
./mddocs/scripts/check-links.sh --verbose

# Summary only — pass/fail count, no per-link output
./mddocs/scripts/check-links.sh --summary-only

# Also report external URLs found (no HTTP requests made)
./mddocs/scripts/check-links.sh --external
```

---

## Options

| Flag | Description |
|---|---|
| `--dir <path>` | Directory to scan, relative to repo root. Default: `mddocs` |
| `--verbose` | Print every link checked, not just failures |
| `--external` | List external URLs found (no HTTP validation performed) |
| `--summary-only` | Suppress per-link output; print only the final count line |
| `-h`, `--help` | Show inline help and exit |

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | All internal links resolve — branch may proceed |
| `1` | One or more broken links found — fix before marking `branch_ready` |

---

## What Is Checked

- Relative markdown links in the form `[text](target.md)` and `[text](../dir/target.md)`
- `.html` targets are resolved as `.md` (mdbook renders `.md` as `.html`)
- Anchor fragments (`#section`) are stripped for file resolution; the file must exist but heading content is not validated

## What Is Not Checked

- External URLs (`http://`, `https://`) — listed with `--external` but not fetched
- Anchor-only links (`#section`) — skipped entirely
- `{{#include}}` directives — these are mdbook preprocessor syntax, not links

---

## mdbook Link Gate

Per AGENT.md standing rule: any branch touching `mddocs/` or `SUMMARY.md` must
pass this check with exit 0 before HIL review. Run before requesting LGTM.

```sh
./mddocs/scripts/check-links.sh && echo "link gate: PASS" || echo "link gate: FAIL"
```

---

## Interpreting Output

Each broken link is reported as:

```
  [BROKEN] mddocs/path/to/source.md
           link: ../relative/target.md
```

**Resolve by:**
1. Fixing the typo in the link path
2. Creating the missing target file
3. Updating the link to point to the correct existing file

**Placeholder links** (e.g. `filename.md`, `path/to/file.md`, `adr-NNNN-title.md`)
appear in template files — update or remove before marking the branch ready.

---

## Common False Positives

| Pattern | Cause | Resolution |
|---|---|---|
| `project_queue_state_YYYY-MM-DD.md` | Template placeholder in runbook | Replace with actual filename or remove link |
| `adr-NNNN-title.md` | ADR template placeholder | Replace when creating a real ADR |
| `.html` links to generated output | Script resolves `.html` → `.md`; if `.md` is missing, link is broken | Ensure source `.md` exists |

---

## Integration

To add to a pre-commit workflow or session-open validation, append to `check-env.sh`
or invoke directly from the session-open checklist after `mdbook build`.

---

## Related

- AGENT.md — mdbook link gate standing rule (repo root, not served by mdbook)
- [Session Close Checklist](../../reference.architecture/session-close-checklist.md)
- [Build and Publish mdBook](build-publish-mddocs.md)
- [TC-017 — Automate mdbook internal link validation](../../backlog.md)
