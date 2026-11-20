# Runbook: GitHub Branch-Protection Rulesets

**Purpose:** Apply and verify the GitHub branch-protection rulesets that implement
ADR-0036 (the server-side enforcement of the `main` append-only / merge-only rule
and the `feat/*` creation gate).

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
| `feat-restrict-creation` | `feat/*` | block creation | `sworley`, `malachid` |

**Why no required approving reviews / code-owner review:** AgenticCore is a
single-operator harness. GitHub will not let a user approve their own pull request,
so a human-approval requirement would make `main` un-mergeable. The merge gate is
the pull-request workflow plus CI (`verify`), branches up to date, and signed commits.

**Why the operator is a bypass actor:** To guarantee the operator is never locked
out. Because agentic sessions run under the operator's identity, this makes the
ruleset a process-level backstop; the first line of defense is the local pre-commit
hook suite (ADR-0022) and HIL discipline.

---

## User IDs

The operator account is the bypass actor on `main`, and `sworley` + `malachid` are
the bypass actors on `feat/*`. Resolve their numeric IDs if they change:

```sh
gh api users/sworley --jq .id   # operator (currently 1118535)
gh api users/malachid --jq .id  # collaborator (currently 396197)
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
        "required_review_thread_resolution": false,
        "required_status_checks": {
          "strict": true,
          "contexts": ["verify"]
        }
    }},
    {"type": "required_signatures"}
  ]
}
JSON
gh api --method POST repos/sworley/AgenticCore/rulesets --input /tmp/opencode/ruleset-main.json
```

### Step 2 - Create the `feat-restrict-creation` ruleset

```sh
cat <<'JSON' > /tmp/opencode/ruleset-feat.json
{
  "name": "feat-restrict-creation",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {"actor_id": 1118535, "actor_type": "User", "bypass_mode": "always"},
    {"actor_id": 396197, "actor_type": "User", "bypass_mode": "always"}
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/feat/*"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "creation"}
  ]
}
JSON
gh api --method POST repos/sworley/AgenticCore/rulesets --input /tmp/opencode/ruleset-feat.json
```

### Step 3 - Remove the legacy `main` branch protection

Once `main-strict` is active, remove the legacy protection so there is a single source
of truth (rulesets), not two competing enforcement layers:

```sh
gh api -X DELETE repos/sworley/AgenticCore/branches/main/protection
```

---

## Verification

```sh
gh api repos/sworley/AgenticCore/rulesets --jq '.[] | {id, name, target, enforcement}'
# expect: main-strict (branch, active) + feat-restrict-creation (branch, active)

gh api repos/sworley/AgenticCore/branches/main/protection 2>&1 | grep -q 'Not Found' \
  && echo "legacy protection removed" || echo "legacy protection still present (review)"
```

Expected:
- `main-strict` and `feat-restrict-creation` both present, `enforcement: active`.
- No legacy protection on `main` (404 on the protection endpoint).

Optionally confirm the operator can still open/merge a PR to `main` (they are a bypass
actor), and that a force-push to `main` is rejected.

---

## Rollback

List the ruleset IDs, then delete the relevant one:

```sh
gh api repos/sworley/AgenticCore/rulesets --jq '.[] | "\(.id)\t\(.name)"'
gh api -X DELETE repos/sworley/AgenticCore/rulesets/<id>
```

To restore the legacy `main` protection after a rollback, recreate it via the UI
(Settings → Branches → Add rule) or the REST endpoints under
`/repos/sworley/AgenticCore/branches/main/protection`.

---

## Notes

- A change to this policy (the rules or bypass actors) is a change to a governed
  decision and requires a **new superseding ADR** (forward-only, ADR-0035) - not an
  in-place edit to ADR-0036 or a silent ruleset tweak. Update this runbook and the
  supersession ledger accordingly.
- The release flow (`release/vX.Y.Z-prep → main`, `main → dev`) already runs through
  pull requests, so it is not blocked by the PR-required rule; the operator being a
  bypass actor covers any exceptional direct merge.
