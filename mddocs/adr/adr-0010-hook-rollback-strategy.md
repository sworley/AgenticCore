# ADR-0010: AI toolchain Hook Rollback Strategy

**Date:** 2026-06-06
**Status:** accepted
**Supersedes:** —

## Prior Art

EXAMPLE-ADR-0027 (AI toolchain Hook Rollback Strategy, 2026-06-06). Rollback trigger
criteria, recovery procedure, and hook inventory model carried forward; EXAMPLE ticket
references and customer-specific hook rules removed.

---

## Context

The hook layer (scripts across PreToolUse, PostToolUse, and Stop events) is operational.
Three of those hooks block tool calls unconditionally on pattern match. As the rule set
evolves, two failure modes become likely:

1. A new rule in a blocking hook breaks a legitimate workflow mid-session, with no
   recovery path short of editing `settings.local.json` and restarting AI toolchain.
2. A new rule is promoted to hard-block before it has been validated against real
   workloads, causing repeated false positives.

The project follows the runbook + companion script convention. The `hook-rollback.md`
runbook needs an operational standard for hook lifecycle management.

Four open questions:
- Q1: Per-hook circuit breakers
- Q2: Env var override naming convention
- Q3: Staged rollout for new rules
- Q4: Companion script for hook-rollback.md

## Decision Drivers

- Emergency disable must be possible within a running session — no restart required
- Security-critical hooks must not have opt-outs that are easy to misuse
- New rules must be validated against real workflows before they enforce
- All runbooks with operational steps must have an idempotent companion script

## Considered Options

### Q1 — Per-hook circuit breakers

- **Option A:** No circuit breakers
- **Option B:** Universal circuit breakers — every blocking hook checks a corresponding env var
- **Option C:** Selective circuit breakers — only for hooks whose blocking is conditional by design

### Q2 — Env var override naming convention

- **Option A:** `AGENT_<HOOKNAME>_DISABLED=1` — derived from script filename stem
- **Option B:** `AGENT_<SCOPE>_BYPASS=1` — action-centric
- **Option C:** `AGENT_HOOKS_DISABLED=<hookname>` — single variable, comma-separated list

### Q3 — Staged rollout for new rules

- **Option A:** No staged rollout — new rules go straight to hard-block
- **Option B:** Warn-only mode for all blocking hooks
- **Option C:** Warn-only mode for `secret-guard.py` only

### Q4 — Companion script for hook-rollback.md

- **Option A:** No companion script — runbook is procedure-only
- **Option B:** Companion script that validates hook inventory and known-block/known-pass cases

## Decision

| Question | Chosen Option |
|---|---|
| Q1 | Option C — selective circuit breakers |
| Q2 | Option A — `AGENT_<HOOKNAME>_DISABLED=1` |
| Q3 | Option C — warn-only mode for `secret-guard.py` only |
| Q4 | Option B — companion script required |

**Q1 rationale:** `package-install-guard.py` is unconditional by design — a circuit
breaker would undermine the control. `secret-guard.py` and `read-scope-guard.py` block
on pattern matches against legitimate targets in edge cases; each benefits from a
session-scoped emergency opt-out.

**Q2 rationale:** `AGENT_<HOOKNAME>_DISABLED=1` is unambiguous, self-documenting, and
directly traceable to the specific script being bypassed.

**Q3 rationale:** `secret-guard.py` has the most active rule evolution and is the hook
most likely to produce false positives from new pattern additions.

**Q4 rationale:** A runbook + companion script convention is unconditional. A hook-rollback
runbook that cannot self-validate is an untested runbook.

## Implementation Notes

### Circuit breaker implementation

`secret-guard.py` adds at the top of its block logic:

```python
import os
if os.environ.get("AGENT_SECRET_GUARD_DISABLED") == "1":
    sys.exit(0)
```

Same pattern for `read-scope-guard.py` (`AGENT_READ_SCOPE_GUARD_DISABLED=1`).
`package-install-guard.py` — no circuit breaker added. The absence is intentional.

### Warn-only mode for secret-guard.py

New rules added to `secret-guard.py` are gated by a `WARN_ONLY_RULES` list. Rules in
that list emit a warning message and exit 0 rather than exit 1. After one sprint of
validation with no false-positive reports, the rule is promoted to the main enforcement
list.

Promotion requires explicit HIL action. There is no time-based automatic promotion.

### Companion script — validate-hooks.sh

`mddocs/scripts/validate-hooks.sh` validates:

1. **Inventory check** — all hook scripts are present and executable
2. **Known-block cases** — runs each blocking hook against synthetic input; asserts exit non-zero
3. **Known-pass cases** — runs each blocking hook against clean input; asserts exit 0
4. **Circuit breaker check** — for each circuit-breaker-eligible hook, sets the env var and re-runs the known-block case; asserts exit 0

`--check` mode (no side effects) is required. Script is idempotent.

## Consequences

**Positive:**
- Emergency disables are possible within a running session using `export AGENT_<HOOKNAME>_DISABLED=1`
- New `secret-guard.py` rules are validated in warn-only mode before they block
- The companion script provides a repeatable audit of hook health after any change

**Negative / Trade-offs:**
- Two naming conventions now coexist: grandfathered env vars alongside the new `AGENT_<HOOKNAME>_DISABLED=1` pattern
- Warn-only mode creates a sprint window where a new rule does not enforce

**Neutral:**
- `egress-audit-log.py` does not capture blocked `PreToolUse` events — blocked attempts are visible in the session transcript only

## Lessons Learned

- Circuit breakers on security hooks are dual-use: they reduce operational friction but must be scoped to hooks whose blocking is conditional. The decision to exclude `package-install-guard.py` establishes that some controls are unconditional by design.
- Staged rollout is a mechanism, not a policy. Applying it selectively to the highest-churn hook is the right starting point.

## Related

- [ADR-: Agentic Agent Enforcement Posture](adr-0022-git-pre-commit-permission-order-check.md)
- [hook-rollback.md](../operations/runbooks/hook-rollback.md)
- [secret-guard.md](../operations/runbooks/secret-guard.md)
