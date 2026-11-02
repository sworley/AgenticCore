# Runbook: Credential-Identity Guard (Pre-Commit) and SF-096 Residual Decision

**Category:** Security & Credential Hygiene
**Last Updated:** 2026-08-21
**Owner:** Security Engineering
**Ticket:** TC-068 — follow-on to SF-096 (mitigated)

## Overview

This runbook documents three related security artifacts, all delivered under TC-068
as the durable-prevention follow-on to security finding **SF-096**:

1. **The credential-identity guard** — a git-native `pre-commit` hook that rejects any
   commit whose author or committer identity (name or email) matches a credential
   pattern. This is the durable, forward-looking prevention.
2. **The `user.email` plumbing lock** — the verified posture that guarantees the bot
   identity can never carry a token.
3. **The SF-096 history-scrub decision** — recorded rationale for accepting the dead
   token in historical author metadata as a verified-dead residual rather than
   rewriting history.

### Background — SF-096 and SF-019

During the TC-056 investigation a Git PAT (`glpat-` prefix) was found embedded in
git author/committer **email metadata** across a bounded set of historical commits
(2026-06-22 .. 2026-07-21). The token was independently verified **dead** — it returns
HTTP 401 "Token is expired", having aged out under the HIL's 30-day PAT rotation cycle.
SF-096 is `mitigated`.

The root cause was a **misconfigured local git `user.email`** that leaked a token into
commit identity metadata. The earlier finding **SF-019** established empirically (via an
empty bare-repo clone test, 2026-07-21) that:

- `git clone` never writes `user.name` / `user.email` locally — a fresh clone leaves both
  unset and falls through to the global `~/.gitconfig`.
- The credential-injection design in `.envrc.template` (git remote URL matched by
  hostname, `GIT_TOKEN` retrieved via `pass show`, bridged to git auth by
  `git-askpass.sh`) **never touches `user.email`** and is not implicated.
- The pollution was an operator/tooling paste error at an unidentified point — not a
  defect in the framework credential model.

SF-019 recommended a preventive control: flag any identity field matching a
credential-shaped pattern, because **git author metadata is a channel none of the
existing secret-scan hooks inspect**. TC-068 implements that control at the strongest
surface — a git-native pre-commit hook.

---

## 1. The Credential-Identity Guard Hook

### What it does

`.agentic/hooks/pre-commit-credential-identity-check.py` is a Python 3 git `pre-commit`
hook. Before each commit it reads `git var GIT_AUTHOR_IDENT` and
`git var GIT_COMMITTER_IDENT` and scans both the name and email portions of each against
a conservative set of credential patterns. If any field matches, the commit is
**rejected** (non-zero exit).

Primary target: `glpat-[A-Za-z0-9_-]{20,}` (the SF-096 token shape). The hook also
matches other high-signal, length-constrained token shapes (Git deploy/runner tokens,
GitHub PATs, Slack tokens, AWS access key ids, JWTs, and PEM private-key headers). The
pattern set is deliberately conservative: identity fields are short, so a bare
high-entropy heuristic is intentionally **not** used — it would false-positive on
legitimate emails and usernames.

### Secrets-hygiene guarantee (hard requirement)

The hook **never echoes the matched credential value** — not in full, not as a partial
substring. Its error output names only the identity **role** (author / committer) and the
credential **class** (e.g. "Git personal access token (glpat-)"). The whole point of
the control is to avoid leaking the credential further; printing it would defeat the
purpose. This was verified during implementation (see Validation below).

### Why a git-native hook (surface rationale)

A git-native `pre-commit` hook fires on **every** commit to this repo regardless of which
tool or CLI produced it — a human at a terminal, opencode's git usage, an editor's git
integration, or CI. The `.agentic/hooks/` PreToolUse hooks (e.g. `secret-guard.py`,
`secret-scan-output.py`) only fire on AI toolchain tool calls and, critically, none of them
inspect **git identity metadata**. This is the same parallel-surface reasoning that
ADR-0022 applied to the permission-order check: the two mechanisms are complementary, not
a replacement.

### ADR-0004 compliance

This hook is **prevention only** — it is forward-looking and performs no history rewrite.
It honors ADR-0004 (main is append-only / merge-only). It stops a credential-bearing
identity from ever reaching a **new** commit; it does not and must not touch existing
history.

### hook-class sentinel (TC-047)

The hook carries the exact sentinel token `# hook-class: git` on its second line. This is
**required**: `check-hook-wiring.py` uses that sentinel to exclude git-native hooks from
the tool-event-wiring assertion. Without it, session-open `check-env.sh` would falsely
flag the hook as an unwired AI-tool hook.

### Installation and composition

Installation is via `.agentic/scripts/install-git-hooks.sh` — the same installer that
wires the permission-order check. The installer copies each tracked hook into the git
hooks directory under a stable name and maintains a single `pre-commit` **dispatcher**
that chains both checks, each guarded by its own idempotent marker:

```
# >>> permission-order-check (TC-035) >>>
"…/permission-order-check.py" || exit $?
# <<< permission-order-check (TC-035) <<<

# >>> credential-identity-check (TC-068) >>>
"…/credential-identity-check.py" || exit $?
# <<< credential-identity-check (TC-068) <<<
```

The installer **composes, never clobbers**: an existing (or foreign) `pre-commit` hook is
preserved, and each check's dispatch block is appended only if its marker is not already
present. Re-running the installer is idempotent. The dispatcher runs under
`set -euo pipefail`, so a non-zero exit from either check aborts the commit.

> **Installing a git hook is a privileged, per-repo action** governed by Invariant #10
> (no installing/modifying git hooks without explicit written authorization). TC-068 ships
> the tracked hook source and the updated installer; actually running
> `install-git-hooks.sh` against any `.git/hooks/` is a separate, explicitly
> HIL-authorized action.

### Validation

Test in an **isolated throwaway git repo** — never against the bench repo's real hooks.
Use an obviously-synthetic placeholder token, never a real credential shape:

```bash
TMPD="$(mktemp -d)"
HOOK=".agentic/hooks/pre-commit-credential-identity-check.py"
cd "$TMPD" && git init -q
git config user.name "Clean Bot"; git config user.email "clean-bot@example.com"

# PASS (exit 0) — clean identity
python3 "$OLDPWD/$HOOK"; echo "exit: $?"

# REJECT (exit 1) — synthetic glpat placeholder in email; value must NOT appear in output
git config user.email "glpat-EXAMPLETOKENPLACEHOLDER0@example.com"
python3 "$OLDPWD/$HOOK" 2>&1; echo "exit: $?"

# PASS (exit 0) — legitimate hyphen/plus email, no false positive
git config user.name "Maria OBrien-Smith"
git config user.email "maria.obrien-smith+ci@example.co.uk"
python3 "$OLDPWD/$HOOK"; echo "exit: $?"

cd "$OLDPWD" && rm -rf "$TMPD"
```

Expected: clean identities and legitimate hyphenated/plus-addressed emails exit `0`; a
credential-shaped identity exits `1` with a redacted message on stderr that contains
**no** trace of the token value.

---

## 2. The `user.email` Plumbing Lock (Root-Cause Lock)

### Posture — verified safe, no change required

The correct posture is **already in place** and was verified for this ticket rather than
changed. What was checked, in this bench:

| Check | Result |
|---|---|
| `git config --local --get user.email` | **unset** (exits non-zero) — falls through to global |
| `git config --local --get user.name` | **unset** — falls through to global |
| Effective `user.email` / `user.name` | clean human identity from global `~/.gitconfig`, no token |
| `git var GIT_AUTHOR_IDENT` / `GIT_COMMITTER_IDENT` | clean — no credential pattern |
| `.envrc.template` | sets `GIT_HOST`, `GIT_TOKEN`, `GIT_ASKPASS`, `GIT_TERMINAL_PROMPT` only — **never** `user.email`, `user.name`, `GIT_AUTHOR_*`, or `GIT_COMMITTER_*` |
| `.agentic/scripts/git-askpass.sh` | supplies the token to git **auth** (password/username prompts) only — it does not set, read, or influence git **identity** |

This matches the SF-019 empirical finding: the framework credential model (ADR-0018,
TC-046) fixed the leak **source** and never writes identity fields. The identity leak in
SF-096 originated from an operator/tooling paste error into local git config, not from any
framework plumbing.

### The lock

Because the plumbing itself is clean, the durable lock is the **defense that catches the
operator error at the commit boundary regardless of how it entered** — the pre-commit
credential-identity guard in Section 1. That guard is the structural lock: even if a
future paste error puts a token into `user.email` or `user.name`, no commit carrying it
can be created. No change to `.envrc.template` or `git-askpass.sh` is warranted or made;
introducing identity-setting into that plumbing would be a regression, not a fix.

---

## 3. SF-096 History-Scrub Decision

**Decision: ACCEPT AS VERIFIED-DEAD RESIDUAL. Do not rewrite history.**

### Rationale

- **The token is dead.** Verified expired (HTTP 401 "Token is expired"), aged out by the
  HIL's 30-day rotation. It is not the current env token. Remaining exploit value is
  effectively zero.
- **The only true removal is a history rewrite.** Author/committer metadata is immutable;
  scrubbing the string requires `git filter-repo` (or equivalent), which rewrites every
  affected commit's hash.
- **A rewrite collides head-on with governing controls:**
  - **ADR-0004** — `main` is append-only / merge-only; no `reset`, `rebase`, `revert`, or
    any operation that removes, alters, or reorders commits already on `main`. A history
    rewrite is exactly the prohibited operation.
  - **Invariant #4** — destructive operations require explicit HIL confirmation naming the
    specific resource; a repo-wide history rewrite is maximally destructive.
  - **Operational blast radius** — a rewrite would force-push a rewritten history, breaking
    all clones and worktrees and severing the `dev` ↔ `main` relationship.
- **Disproportionate.** Rewriting all of history to scrub a **dead** credential from a
  low-exposure metadata channel is disproportionate to the (effectively zero) residual
  risk.

### If a rewrite is ever considered

A history rewrite is **advised against** and must **not** be performed by any agent. If the
HIL judges a rewrite warranted, it is an **Informed-HIL-Override** decision (ADR-0024):
the specific control impacted (ADR-0004 append-only, Invariant #4), the concrete risk
(broken clones/worktrees, severed `dev`↔`main`, force-push on a protected branch), and who
bears it must be stated and the waiver recorded before any action. Even then, the absolute
prohibitions constrain it. This runbook records the standing recommendation: **do not
rewrite; accept as verified-dead residual.**

### Known-residual note for future secret scans

The current secret-scan hooks (`secret-scan-output.py`, `secret-guard.py`) scan tool
**output** and Bash **commands** by pattern; neither has an allowlist mechanism and neither
inspects git **history** or **author metadata**. There is therefore no scanner rule that
would re-flag SF-096 from normal operation, and no allowlist entry is required to suppress
a false re-flag today.

Should a future history-aware scanner be introduced, treat the following as a **known,
accepted, verified-dead residual — do not re-open as a new finding:**

- **Finding:** SF-096 (mitigated) — expired `glpat-` token in historical git
  author/committer email metadata.
- **Window:** commits dated 2026-06-22 .. 2026-07-21 (none since 2026-08-06).
- **Status:** token verified dead (HTTP 401); accepted as residual per this decision;
  no history rewrite (ADR-0004).

---

## Related

- **SF-096** / **SF-019** — the findings this work resolves (see `.security/findings.yaml`)
- [ADR-0004: Main Branch Append-Only](../../adr/adr-0004-main-branch-protection.md) — why no history rewrite
- [ADR-0018: Credential Injection Pattern](../../adr/adr-0018-credential-injection-pattern.md) — the credential plumbing that fixed the leak source (TC-046)
- [ADR-0022: Git-Native Pre-Commit Permission-Order Check](../../adr/adr-0022-git-pre-commit-permission-order-check.md) — the sibling git-native hook and the parallel-surface rationale
- [ADR-0024: Informed HIL Override](../../adr/adr-0024-informed-hil-override.md) — the governed path if a rewrite were ever directed
- [Runbook: secret-guard Hook](secret-guard.md) — the PreToolUse credential guard (complementary surface)
- [Runbook: Rotate Git PAT](rotate-git-pat.md) — token rotation procedure
- [Runbook: Hook Rollback](hook-rollback.md) — emergency disable / revert for hooks
- `.agentic/scripts/install-git-hooks.sh` — the installer that wires both git-native pre-commit checks
