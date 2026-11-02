# AP ADR-0018: Credential Injection Pattern

**Date:** 2026-07-02
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —

## Prior Art

EXAMPLE-ADR-0020 (direnv Remote-Based Credential Injection, 2026-05-17). This
ADR extracts the credential injection pattern from that document and
generalizes it as a framework-level convention. The specific direnv
implementation, pass store paths, and instance hostnames are adopter-specific
and are not carried forward.

---

## Context

Agentic sessions require credentials to reach external services (Git hosting
platforms, APIs, package registries). A project may interact with more than
one external service instance — for example, a management-plane Git and
a customer-plane Git — and the correct credential to use depends on context,
not on the operator's memory.

The naive approach — exporting all credentials at shell login — fails in
multi-instance environments: it is error-prone (wrong token for wrong
instance), over-privileged (a session that only needs one token carries all
of them), and brittle (the engineer must remember to re-export when switching
contexts).

This ADR defines the pattern the framework uses to solve this cleanly.

---

## Decision Drivers

- The correct credential must be automatically available in the current context
  without operator intervention
- Credentials must not be exported at login or persist beyond the scope where
  they are needed
- Scripts and agents must be credential-context-agnostic — the same script
  runs unchanged regardless of which service instance is active
- Adding a new service instance must not require changes to existing scripts
  or agent definitions
- The mechanism must be available to any tool that reads the process environment
  (shell scripts, Python scripts, AI toolchain, OpenCode)

---

## Decision

### D-1: Remote-based context selection

The active credential is selected based on the Git remote of the current
working directory, not on the directory path, a manually exported variable,
or a per-project configuration file.

`git remote get-url origin` is called within the injection mechanism to
determine which service instance is active. This is authoritative because:
- The remote is set once at repo creation and does not drift
- It is correct at any depth within the repo (subdirectory, nested worktree)
- It is not ambiguous: a repo's on-disk location is irrelevant; the remote is
  the source of truth for which instance owns it

---

### D-2: Single canonical env var pair

All scripts and agents consume a single canonical variable pair:

| Variable | Purpose |
|---|---|
| `GIT_HOST` | Base URL of the active Git hosting instance |
| `GIT_TOKEN` | PAT or equivalent credential for that instance |

For non-Git hosting platforms, an equivalent pair is used (e.g.,
`GITHUB_TOKEN` for GitHub). The consuming code is never aware of which
instance is active — it reads the canonical variable name and the injection
mechanism ensures it contains the correct value.

Per-context named variables (`PROJECT_GIT_TOKEN`, `CUSTOMER_GIT_HOST`,
etc.) are not used. See Alternatives Considered.

---

### D-3: Injection scope — not at login

Credentials are not exported at shell login. They are injected when the
operator enters a directory under the project's workspace root and unset when
they leave it.

A session that operates outside the workspace root carries no credentials.
This is the least-privilege default: credentials exist in the environment only
when and where they are needed.

---

### D-4: Reference implementation — direnv

The reference implementation uses `direnv` with a single `.envrc` at the
workspace root. The `.envrc` reads the git remote of the current directory
and injects the matching credential from the secret store. It unsets all
credential variables when no recognized remote is found.

Any mechanism that satisfies D-1, D-2, and D-3 is an acceptable implementation.
`direnv` is not prescribed — adopters may use a shell function, a project
`.env` loader, or an organizational secret injection tool, provided it:

- Selects credentials based on git remote (not directory path)
- Injects into the process environment (not a file)
- Unsets credentials when leaving the relevant scope
- Does not store credential values in any committed file

---

### D-5: Environment-to-git bridge

Injecting the token into the environment (D-2) is necessary but not sufficient
for git operations: git does not read `$GIT_TOKEN` on its own. A bridge must
translate the canonical environment variable into git's authentication flow.

The framework uses git's `GIT_ASKPASS` mechanism for this bridge. A small
committed helper (`.agentic/scripts/git-askpass.sh`) emits `$GIT_TOKEN` when
git requests a password and `oauth2` when git requests a username. The
injection layer exports `GIT_ASKPASS` (pointing at that helper) and
`GIT_TERMINAL_PROMPT=0` in the same recognized-remote scope where it sets the
token, and unsets both when leaving that scope.

This makes any ad-hoc git invocation in the workspace authenticate
automatically — `git push`, `git fetch`, `git ls-remote` — not only scripts
that build their own credential plumbing. It preserves the D-2/D-3 guarantees:

- **No stored secret.** The helper reads the environment variable the injection
  layer already set; it stores nothing. The token never enters a remote URL,
  `.git/config`, or the OS keychain.
- **Session scope (D-3).** When the operator leaves the workspace tree, the
  injection layer unsets `$GIT_TOKEN` and `GIT_ASKPASS`. The helper then
  emits an empty string and `GIT_TERMINAL_PROMPT=0` makes git fail closed rather
  than prompt or reuse a stale credential.
- **Instance-agnostic (D-2).** The helper reads only the canonical variable and
  has no knowledge of which instance is active.

A self-contained script that needs credentials without relying on the ambient
environment (for example `mddocs/scripts/git-sync.sh`) may build an equivalent
`GIT_ASKPASS` bridge inline and tear it down on exit. Both forms are the same
pattern; the committed helper is the workspace-wide default and the inline form
is the self-contained-script variant.

---

## Alternatives Considered

### Per-context named credential variables

Export separate named variables for each service instance at login:
```
export PROJECT_GIT_TOKEN="$(secret-store show project/pat)"
export CUSTOMER_GIT_TOKEN="$(secret-store show customer/pat)"
```

**Rejected because:**
- Every script must be aware of which context it is operating in and choose
  the correct variable pair — this couples tool logic to instance identity
- Adding a new instance multiplies variable pairs and requires updating every
  consumer
- The mapping from "which instance am I on?" to "which variable do I read?"
  is implicit knowledge that lives only in the operator's head
- Scripts cannot be shared across contexts without modification

The accepted model is strictly simpler: every script reads `$GIT_TOKEN`
with no knowledge of which instance it is talking to.

### Per-directory `.envrc` files

One `.envrc` per project directory, each exporting the credentials for that
project.

**Rejected because:**
- Directory location is not authoritative. A management-plane repo may be
  cloned into a directory named for one project while its git remote points
  to a different service instance. Directory-based selection fails this case.
- Per-directory files drift out of sync with actual remotes as repos are
  reorganized on disk.

### Static export at login

Export all credentials in `~/.zshrc` or equivalent at shell startup.

**Rejected because:**
- Over-privilege: all credentials are present in every session, including
  sessions that do not need them
- No automatic context switching: operator must manually re-export when
  switching between instances
- Credentials are present in the environment for the full session lifetime,
  increasing the window of exposure

---

## Consequences

**Positive:**
- Correct credential is always active for the current repo — no manual
  switching required
- Credentials are unset when outside the workspace tree — no persistent
  over-privilege
- Adding a new service instance requires one new case in the injection
  mechanism and one new secret store entry — no script or agent changes
- The canonical variable pair (`GIT_TOKEN`, `GIT_HOST`) means any
  script written for one adopter project runs unchanged on another

**Negative / Trade-offs:**
- New repo workflow: after a fresh clone, the operator must trigger a
  credential reload (e.g., `direnv reload` or re-entering the directory)
  before credentials are active
- The injection mechanism itself (e.g., `direnv`) is an outer dependency
  that must be installed and configured per ADR-0017

---

## Related

- [ADR-0016: Agentic Toolchain Secret Management](adr-0016-agentic-toolchain-secret-management.md) — policy that governs how credentials are stored and used; this ADR defines the injection mechanism
- [ADR-0017: Outer Dependencies and Portability](adr-0017-outer-dependencies-and-portability.md) — credential injection tooling is an outer dependency
- [ADR-0006: External Content Gate Scope](adr-0006-external-content-gate-scope.md) — capability gate variables follow the session-scope rule (D-3)
