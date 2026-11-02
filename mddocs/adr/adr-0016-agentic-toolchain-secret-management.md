# AP ADR-0016: Agentic Toolchain Secret Management

**Date:** 2026-07-02
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —

## Prior Art

EXAMPLE-ADR-0008 (Secret Management Posture — Current State, 2026-04-24, updated
2026-06-01). This ADR extracts the agentic toolchain credential section of that
document and generalizes it as a framework-level policy. Infrastructure and
cloud credential content is adopter-specific and is not carried forward.

---

## Context

Agentic sessions consume credentials — at minimum, a token to reach the Git
hosting platform for issue sync, GL/GH API calls, and repo operations. These
tokens are sensitive and require explicit handling rules to prevent accidental
exposure through agent context artifacts, conversation output, or committed
files.

Without a declared policy, each adopter project develops ad-hoc habits:
tokens in shell profiles, values echoed in scripts, credentials surfacing
in `tasks.yaml` notes or memory files. The framework's agentic model creates
new exposure vectors that a general-purpose secret management policy does not
address — agent context files, memory systems, and tool call results are not
standard surfaces covered by existing secure coding guidance.

---

## Decision Drivers

- Agent sessions must be able to run unattended without requiring the operator
  to inject credentials interactively mid-session
- Credential values must never appear in any artifact that could be read back
  into an agent context window or committed to git
- The policy must apply uniformly across all tools (AI toolchain, OpenCode, or
  any future agentic interface)
- Controls must be enforceable by convention at minimum; tooling enforcement is
  an improvement opportunity, not a prerequisite

---

## Decisions

### D-1: Credential storage — secret store, not shell profiles

Credential values (tokens, passwords, API keys) must be stored in a
GPG-encrypted secret store (e.g., `pass`, system keychain, or organizational
vault). They must not be stored in shell profile files (`~/.zshrc`,
`~/.bashrc`, `~/.zshsecrets`, or equivalent).

Non-credential configuration values (project paths, namespace identifiers,
feature flags) may remain in shell profiles. The test: if the value is a
secret that grants access, it belongs in the secret store.

---

### D-2: Injection model — env vars, not files, not URLs

Credentials are injected into the shell environment at runtime by a credential
injection mechanism (see ADR-0018 for the reference pattern). The consuming
scripts and agents read `GIT_TOKEN` / `GIT_HOST` (or equivalent) from
the environment. They do not:

- Read credentials from files
- Interpolate credential values into URLs (`https://token@host/repo`)
- Accept credentials as command-line arguments
- Store credentials in any in-process data structure that appears in logs

The canonical header pattern for HTTP calls:
```
Authorization: Bearer $TOKEN   (or)
PRIVATE-TOKEN: $GIT_TOKEN
```

---

### D-3: Agent session hygiene — mandatory rules

The following rules apply to all agent sessions. They are policy, not
guidelines. Agents must be instructed to follow them; operators are
responsible for verifying compliance.

1. **No credential values in context artifacts.** `tasks.yaml`, memory files,
   `AGENT.md`, agent definitions, and any file tracked in git must never
   contain token values, passwords, or other credential material.

2. **No env var inspection in agent output.** Agents must not execute
   `echo $TOKEN`, `env | grep TOKEN`, `printenv`, or any command that
   surfaces environment variable values in conversation output or tool results.

3. **Capability gate vars are session-scoped only.** Environment variables
   that control agent capabilities (e.g., `AGENT_WEB_ALLOWED`) must not be
   set in any persistent shell profile. They may only be exported for the
   duration of an explicitly authorized invocation:
   ```
   AGENT_WEB_ALLOWED=1 opencode   # scoped to this invocation only
   ```

4. **Credentials belong in the secret store, not in files.** A credential
   value that is needed by an agent script is retrieved from the secret store
   at runtime. It is never written to a temp file, a `.env` file, or any path
   visible to `git status`.

5. **Interactive fallback is acceptable, not preferred.** Scripts may use an
   interactive prompt (hidden input) as a fallback when the env var is unset.
   This is safe but breaks unattended agent operation. The credential injection
   model (ADR-0018) is the preferred solution.

---

### D-4: Pre-session environment verification

Before beginning an agentic session, the operator must verify that required
environment variables are present. `check-env.sh` is the framework-provided
tool for this verification. It must:

- Confirm required env vars are set (non-empty)
- Print PASS/FAIL per variable without echoing values
- Exit non-zero on any failure

Session open checklists must include `check-env.sh` as Step 0. Agents must
not be started when `check-env.sh` exits non-zero.

---

## Known Gaps

| ID | Finding | Risk | Status |
|----|---------|------|--------|
| G-1 | No tooling enforcement preventing credential values in agent context files (`tasks.yaml`, memory files, AGENT.md) — relies on operator convention | Medium | Open |
| G-2 | No pre-commit secret scanning across project repos — accidental token commits are not automatically blocked | Low | Open |

Improvement opportunities for G-1 and G-2 are tracked in `tasks.yaml` and
addressed as capacity allows.

---

## Consequences

**Positive:**
- Credentials are never in git history, agent context windows, or conversation
  logs
- The rules are tool-agnostic — they apply equally to AI toolchain, OpenCode,
  and any future agentic interface
- `check-env.sh` as Step 0 catches missing credentials before a session starts,
  not mid-sprint when an agent blocks on an interactive prompt

**Negative / Trade-offs:**
- Operators must set up a secret store before their first agentic session —
  one additional onboarding step
- Convention-only enforcement (G-1) means a policy violation is possible;
  tooling enforcement is an improvement opportunity, not a hard gate at this
  time

---

## Related

- [ADR-0018: Credential Injection Pattern](adr-0018-credential-injection-pattern.md) — how credentials reach the environment
- [ADR-0006: External Content Gate Scope](adr-0006-external-content-gate-scope.md) — capability gate controls
- [ADR-: Agentic Agent Enforcement Posture](adr--opencode-agent-enforcement-posture.md) — guardrail model that these rules operate within
- `mddocs/scripts/check-env.sh` — pre-session environment verification tool
