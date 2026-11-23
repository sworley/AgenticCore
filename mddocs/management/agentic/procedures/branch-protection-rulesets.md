---
document_type: procedure
status: active
lifecycle: active
primary: true
domain: Management
category: Agentic
purpose: Configure GitHub branch-protection rulesets
---

# Procedure: GitHub Branch-Protection Rulesets

**Purpose:** Apply and verify the GitHub branch-protection rulesets that implement
ADR-0036 (the server-side enforcement of the `main` append-only / merge-only rule
and the PR-gated integration into `dev`).

**When to run:** Initial enforcement (post-ADR-0036 acceptance), after a ruleset
policy change (must be via a new superseding ADR, per forward-only ADR-0035), or to
verify current state.

**Authority:** ADR-0036 (supersedes ADR-0004). This runbook is the source of truth
for how the rulesets are intended to be configured; the live GitHub configuration is
the enforcement layer.

**Estimated time:** 5-10 minutes

---

## Prerequisites

- Repo admin access (operator account).
- A PAT with `Administration` read/write on `sworley/AgenticCore` (rulesets require
  the `Administration` permission on fine-grained tokens).
- `gh` authenticated (see the credential store; the PAT lives in `pass`).

```sh
export GH_TOKEN="$(pass show github.com/personal/sworley/AgenticCore/pat | head -1)"
```

---

## Policy summary (ADR-0036)

| Ruleset | Target | Rules | Bypass actors |
|---|---|---|---|
| `main-strict` | `main` | block creation, block deletion, block non-fast-forward; require PR with strict `verify` status check, 0 approving reviews, no code-owner review, no conversation resolution; require signed commits | operator (`sworley`) |
| `dev-strict` | `dev` | block creation, block deletion, block non-fast-forward; require PR with strict `verify` status check, 0 approving reviews, no code-owner review, no conversation resolution; require signed commits | operator (`sworley`) |

**Why no required approving reviews / code-owner review:** AgenticCore is a
single-operator harness. GitHub will not let a user approve their own pull request,
so a human-approval requirement would make `main` and `dev` un-mergeable. The merge
gate is the pull-request workflow plus CI (`verify`), branches up to date, and signed
commits.

**Why the operator is a bypass actor:** To guarantee the operator is never locked
out. Because agentic sessions run under the operator's identity, this makes the
rulesets a process-level backstop; the first line of defense is the local pre-commit
hook suite (ADR-0022) and HIL discipline.

**Branch naming:** The naming convention (PROCESS.md §5) is a documented, local
convention. It is not enforced by these rulesets, and there is no server-side
branch-name validation (which could lock out agentic sessions).

---

## User IDs

The operator is the bypass actor on both rulesets. Resolve the numeric ID if it
changes:

```sh
gh api users/sworley --jq .id   # operator (currently 1118535)
```

---

## Procedure

### Step 1 - Create the `main-strict` ruleset

```sh
cat <<'JSON' > /tmp/opencode/ruleset-main.json
{
  "name": "main-strict",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {"actor_id": 1118535, "actor_type": "User", "bypass_mode": "always"}
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "creation"},
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
    }},
    {"type": "required_status_checks", "parameters": {
        "required_status_checks": [{"context": "verify"}],
        "strict_required_status_checks_policy": true
    }},
    {"type": "required_signatures"}
  ]
}
JSON
gh api --method POST repos/sworley/AgenticCore/rulesets --input /tmp/opencode/ruleset-main.json
```

### Step 2 - Create the `dev-strict` ruleset

```sh
cat <<'JSON' > /tmp/opencode/ruleset-dev.json
{
  "name": "dev-strict",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {"actor_id": 1118535, "actor_type": "User", "bypass_mode": "always"}
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/dev"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "creation"},
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
    }},
    {"type": "required_status_checks", "parameters": {
        "required_status_checks": [{"context": "verify"}],
        "strict_required_status_checks_policy": true
    }},
    {"type": "required_signatures"}
  ]
}
JSON
gh api --method POST repos/sworley/AgenticCore/rulesets --input /tmp/opencode/ruleset-dev.json
```

### Step 3 - Remove the legacy branch protection on `main` and `dev`

Once both rulesets are active, remove the legacy protection so there is a single
source of truth (rulesets), not two competing enforcement layers:

```sh
gh api -X DELETE repos/sworley/AgenticCore/branches/main/protection
gh api -X DELETE repos/sworley/AgenticCore/branches/dev/protection
```

---

## Verification

```sh
gh api repos/sworley/AgenticCore/rulesets --jq '.[] | {name, target, enforcement}'
# expect: main-strict (branch, active) + dev-strict (branch, active)

for b in main dev; do
  gh api repos/sworley/AgenticCore/branches/$b/protection 2>&1 | grep -q 'Not Found' \
    && echo "$b: legacy protection removed" \
    || echo "$b: legacy protection still present (review)"
done
```

Expected:
- `main-strict` and `dev-strict` both present, `enforcement: active`.
- No legacy protection on `main` or `dev` (404 on the protection endpoint).

Optionally confirm the operator can still open/merge a PR to `main` and `dev` (they
are a bypass actor), and that a force-push to either branch is rejected.

---

## Rollback

List the ruleset IDs, then delete the relevant one:

```sh
gh api repos/sworley/AgenticCore/rulesets --jq '.[] | "\(.id)\t\(.name)"'
gh api -X DELETE repos/sworley/AgenticCore/rulesets/<id>
```

To restore the legacy protection after a rollback, recreate it via the UI
(Settings → Branches → Add rule) or the REST endpoints under
`/repos/sworley/AgenticCore/branches/<branch>/protection`.

---

## Notes

- A change to this policy (the rules or bypass actors) is a change to a governed
  decision and requires a **new superseding ADR** (forward-only, ADR-0035) - not an
  in-place edit to ADR-0036 or a silent ruleset tweak. Update this runbook and the
  supersession ledger accordingly.
- The release flow (`release/vX.Y.Z-prep → main`, `main → dev`) already runs through
  pull requests, so it is not blocked by the PR-required rules; the operator being a
  bypass actor covers any exceptional direct merge.
- Branch naming is enforced locally, not by these rulesets; see PROCESS.md §5.
