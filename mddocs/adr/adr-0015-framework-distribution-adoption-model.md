# AC ADR-0015: Framework Distribution and Adoption Model

**Date:** 2026-07-02
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —
**Amended:** 2026-08-17 (D-7 — two adoption flows; TC-050 field feedback); 2026-08-20
(D-8 — discipline-inheritance boundary; TC-063 field feedback)

---

## Context

AgenticCore is designed to be adopted by independent projects. The framework
repo (`AgenticCore.v1`) contains patterns, agent definitions, scripts,
runbooks, and ADRs that adopter projects are intended to build on.

There was no defined model for how an adopter *obtains* the framework, how
framework improvements flow to existing adopters, how a new project establishes
its identity at initialization, or what the hard requirements are for running
the framework at all.

This gap was identified during the TC-0020 ADR provenance audit (2026-07-02)
as a prerequisite for finalizing ADR-0014 (Project Task Slug and ADR Ticket
Governance), which defers its onboarding procedure here.

---

## Decision Drivers

- A new project operator must be able to get a working AC-governed environment
  with a minimal and well-documented onboarding procedure
- An adopter project must have its own independent Git identity from day one —
  AC commits and history must not be present in adopter repos
- Framework improvements released in AC must be reachable by adopters on their
  own cadence without requiring a live upstream connection
- The distribution model must not assume a specific Git hosting platform
- Hard requirements must be minimal and explicitly documented; everything else
  is adopter's choice
- AC is committed to compounding value from all sources — adopters, other
  agentic teams, and innovations not yet anticipated — and the ecosystem model
  must support bidirectional knowledge flow between AC and adopters

---

## Options Considered

### Option A — Clone and re-remote
Operator clones AC, replaces the `origin` remote, pushes as a new repo. AC
added back as `upstream` for future pulls.
- Lineage in Git: preserved (AC history present in adopter repo)
- Update path: `git fetch upstream && git merge`
- Rejected: AC history in adopter repo is unwanted noise; classification
  boundaries between framework development and customer environments make
  shared history a liability

### Option B — Fork (platform-native)
Operator forks AC via hosting platform. Platform tracks the fork relationship.
- Lineage in Git: preserved and platform-tracked
- Update path: platform-native sync
- Rejected: requires AC and adopter to share a hosting platform; cross-platform
  forks are not natively supported; fork model does not fit the versioned
  baseline pattern government programs require

### Option C — Template repository
AC published as a Git template. Operator creates a new repo from the template.
- Lineage in Git: severed at creation
- Update path: manual diff and patch only
- Rejected: a template is a static snapshot; it breaks the living ecosystem
  model in which AC continuously improves from adopter contributions and
  adopters pull from AC releases. Template dispensers cannot compound value.

### Option D — Export and new Git init ✓ Selected
A script exports AC release content to a target directory and runs `git init`.
No AC remote or history is present in the new repo.
- Lineage in Git: completely severed — adopter repo starts clean
- Update path: adopter pulls a future AC release export at their own cadence
- Selected: cleanest adopter identity; no classification boundary concerns;
  fits versioned baseline discipline; slug initialized by the export script
  on day one

---

## Decisions

### D-1: Distribution model — export and git init

AgenticCore is distributed as versioned release exports. An adopter
initializes a new project by running `export-framework.sh` against a specific
AC release tag, which:

1. Copies framework content to a target directory
2. Runs `git init` in that directory
3. Prompts for the adopter's project slug
4. Writes the slug to `AGENT.md`, `tasks.yaml`, and `PROCESS.md`
5. Creates an initial commit recording the AC release version used

No AC remote, upstream reference, or commit history is present in the adopter
repo after initialization. The AC release version is recorded in the initial
commit message and in a `framework-version.txt` file at the repo root, serving
as the permanent baseline reference.

---

### D-2: Hard requirements

The following are hard requirements to run AgenticCore. They are the only
things the framework mandates. Everything else is the adopter's choice.

| Requirement | Rationale |
|---|---|
| **Git** | Commit discipline, branch naming, ADR ticket linkage, and all agentic session hygiene depend on Git as the authoritative source of record |
| **AI toolchain and/or OpenCode, configured to a AI toolchain-compatible API** | AC is an agentic product framework — the AI agent interface is the operating layer the entire framework is built on. EXAMPLE-ORG Model Runtime API is the reference implementation; any AI toolchain-compatible endpoint is acceptable |

Adopter's choice (not prescribed by the framework):
- Operating system and hardware
- Shell environment
- Git hosting platform (Git, GitHub, Azure DevOps, self-hosted, or local-only)
- Credential management tooling (pass, gpg, system keychain, vault, etc.)
- Additional developer tooling beyond what AC scripts use

---

### D-3: Upstream connection — optional, versioned baseline

An adopter that wants to track AC improvements may add AC as a named remote
(`ap-upstream`) and pull selectively. This is supported but not required.

The default and recommended stance is **versioned baseline**: the adopter
records which AC release they initialized from, and upgrades by running the
export script against a newer AC release at a time of their choosing. Upgrade
decisions are owned by the adopter — there is no automatic or pressured update
mechanism.

This fits the configuration management discipline common in government programs:
baseline a version, review the delta at upgrade time, adopt on the program's
own release cycle.

---

### D-4: Pattern promotion gate

When an adopter develops a pattern, decision, or tooling improvement that merits
lifting to the framework, the promotion path is:

1. Adopter's steward opens an AC task (`AC-NNNN`) describing the pattern and
   referencing the source artifact (`<PROJECT>-ADR-NNNN` or `<PROJECT>-NNNN`)
   using the cross-project citation format defined in ADR-0014 D-6
2. AC baseline-steward reviews the submission and assigns a disposition:
   new ADR, runbook addition, script, or decline with rationale
3. If accepted, the pattern enters AC's normal development lifecycle — bench,
   review, release

There is no automation. Promotion is a judgment-driven, HIL-gated decision
documented as an AC ticket. AC is committed to compounding value from all
sources, including adopters, partner teams, and innovations not yet anticipated
at framework authoring time. The promotion gate is intentionally lightweight —
the bar is "does this improve the framework for future adopters?" not
"did it originate here?"

---

### D-5: Slug initialization

The adopter's project slug (ADR-0014 D-1) is declared during `export-framework.sh`
execution — not retroactively. The script prompts for the slug before writing
any files, validates it is non-empty uppercase ASCII, and writes it to all three
required locations (`AGENT.md`, `tasks.yaml`, `PROCESS.md`) in the initial
commit.

There is no slug registry maintained by AC. Slug uniqueness within an
organization is the adopter's responsibility. The guidance in ADR-0014 D-1
(short, derived from program name, not a person name) is advisory.

---

### D-6: Pattern maturation path and two-origin-domain model

Patterns promoted via D-4 originate under real project constraint. The expected
maturation path is:

> Emerges under real constraint → Stabilizes across sessions (shape becomes
> clear) → Adopter opens AC promotion (D-4) → AC ticket opened

A pattern is ready for promotion when all three criteria are met:

1. The portable shape is clear — the requirement can be stated without reference
   to the originating project, customer, or environment
2. Customer-specific content has been fully stripped — no project namespaces,
   environment identifiers, or customer structures remain in the proposed artifact
3. Guardrails are understood from experience — failure modes have been observed
   and constraints are known, not hypothesized

Patterns that have not cleared all three criteria remain in the adopter's
project and continue maturing. Promoting a pattern before it is stable imports
its unresolved ambiguities into the framework, where they propagate to all
future adopters.

**Two-origin-domain distinction.** Adopter projects have two distinct domains;
patterns from each have different promotion profiles:

| Origin domain | Namespace | Typical pattern type | Promotion signal |
|---|---|---|---|
| Management layer | `.01` | Agent definitions, guardrails, hooks, runbooks, tooling | Stable across multiple sessions; no project-specific content remaining |
| HIL / project layer | `.00` | Bench patterns, delegation models, scaling mechanisms | HIL has hit a real operational limit; the solution has been exercised, not just designed |

**The abstraction step is the gate.** The adopter's steward performs the
abstraction — not the HIL directly, and not the AC baseline-steward. The
steward strips project-specific content, identifies the portable shape, and
writes the AC task description from generic requirements. The AC
baseline-steward evaluates the abstraction, not the raw project artifact.
Submitting a raw project artifact (e.g., a source-project ADR with customer
references intact) is not a valid promotion submission.

**First-adopter precedent.** The originating project is the first adopter and
the primary source of early pattern submissions. Pattern W (attendant
bench-lead) is the first submission expected via this path — the requirement
became clear only after the HIL/project scaling limit was reached in practice,
confirming that the maturation path above is the correct model, not a shortcut
around it.

---

### D-7: Two adoption flows — empty-dir init and re-home-into-existing-tree

**Status of this decision:** Amendment (2026-08-17), sourced from TC-050 field
feedback — the first fresh v1.1.0 deployment into a real customer codebase.

D-1 specified a single adoption flow: export release content to a target
directory and run `git init`. Field use revealed a second, equally valid flow
that D-1 did not anticipate: **re-homing the framework into an existing,
already-git-initialized customer codebase**. The HIL exercised this flow by hand
in nine manual steps (populate the customer tree via `git-sync.sh`, clone the
framework into a subdirectory, move framework files up into the customer root,
remove the empty subdirectory, and sever the framework remote). This amendment
ratifies **both** flows as first-class and specifies `export-framework.sh` to
support each.

**Flow A — empty-dir init (the D-1 flow).**
The target directory is empty or does not yet exist. The script copies release
content, runs `git init`, and produces a clean new repository. This is the
greenfield adoption path.

**Flow B — re-home into an existing customer tree.**
The target directory already contains a customer codebase under its own git
history. The script overlays framework files into that tree, reconciles ignore
rules for pre-existing customer content (deferred to TC-051), and severs any
AgenticCore remote so customer commits cannot flow back to the framework
repository. This is the brownfield adoption path.

Both flows converge on the same post-conditions: the framework content is
present at the repository root, the adopter's slug is written (D-5), a
`framework-version.txt` baseline reference exists (D-1), and **no framework
remote, no framework upstream reference, and no framework commit history,
refs, or objects are reachable from the adopter repository.** "Framework" here
means the AgenticCore framework repository regardless of the name it is
hosted under (the project has been hosted as both `AgenticCore` and, after a
Git rename, `AgenticCore`; identity is by repository, not by name
string).

**D-7.1 — Flow selection.**
`export-framework.sh` detects the target-directory state (empty vs. existing git
repository) and selects the flow, or accepts an explicit `--flow empty|rehome`
argument. When detection is ambiguous, the script stops and requires the operator
to declare the flow explicitly rather than guessing.

**D-7.2 — Re-home safety interlock (fail-safe).**
Flow B refuses to run against a customer tree that is not a clean git working
tree. If the target has uncommitted changes or untracked files that the overlay
could clobber, the script aborts with a clear message and makes no changes. An
explicit `--force` flag is required to override **this dirty-tree guard only**,
and its use is echoed as a warning. Rationale: re-homing moves files into a tree
the operator cares about; a fail-safe default protects customer work from an
accidental overlay. A confidentiality-sensitive, one-shot bootstrap operation
must not silently overwrite.

`--force` scope is strictly bounded: **`--force` overrides the dirty-tree guard
and nothing else.** It does not, and no flag may, weaken the D-7.3 severance
assertion or the D-7.5 history-scrub verification. Those are non-overridable
controls (see D-7.3, D-7.5).

**D-7.3 — Remote-severance is a verified, allowlist-based hard assertion.**
Severing the framework remote is a confidentiality control, not a convenience
step (D-1; TC-050). Severance is verified by an **allowlist** post-condition, not
by the absence of a name substring: after severance the adopter repository's
remote set must be **empty**, or exactly the adopter's own explicitly declared
remotes — never any remote that resolves to the framework repository. The script
**aborts loudly and exits non-zero**, printing the offending configuration, if
the post-condition does not hold.

The assertion must cover every git mechanism by which a push could reach the
framework, not only named `[remote]` entries. At minimum the script clears and
then verifies the absence of:

- all `[remote "<name>"]` entries (`url` and every `pushurl`), including SSH-form
  URLs (`git@host:group/repo.git`), not only HTTPS-form;
- `url.<base>.insteadOf` and `url.<base>.pushInsteadOf` rewrite rules that could
  redirect an innocuous-looking URL to the framework;
- `remote.pushDefault`;
- every `branch.<name>.pushRemote`.

Verification is by **resolved push target**, not by literal URL string match, so
a rewrite rule or mirror URL that resolves to the framework is caught. Rationale:
a substring/denylist check fails silently against SSH remotes, `insteadOf`
rewrites, mirror URLs, and `pushDefault`/`pushRemote` redirection — and silent
failure is the worst outcome for the control that closes the customer-code
pollution risk TC-050 was filed to close. A control that is assumed, or matched
by name, rather than verified by resolved target, is not a control. This
assertion is **non-overridable by `--force` or any other flag.**

**D-7.4 — Idempotence and dry-run.**
The script supports a `--dry-run` mode that reports the flow it would take, the
files it would move or copy, and the configuration it would sever, without
modifying anything. `--dry-run` guarantees **zero side effects** — no config
writes, no ref updates, no file moves, no object changes. Re-running the script
against an already-initialized adopter repo is a no-op that reports the existing
baseline rather than re-exporting.

The D-7.3 severance assertion and the D-7.5 history-scrub verification run on
**every** invocation — including the idempotent no-op path and `--dry-run` (in
report-only form) — so a framework remote or ref re-introduced after initial
adoption is surfaced rather than silently tolerated.

**D-7.5 — Framework history, refs, and objects must be scrubbed and verified.**
Flow B introduces framework objects into the adopter tree via the clone step
(the framework is cloned, then its files are moved into the customer root).
Removing a named remote does **not** remove fetched objects, `refs/remotes/*`,
`packed-refs`, `FETCH_HEAD`, reflog entries, tags, or notes that originated from
the framework. The D-7 post-condition ("no framework commit history reachable")
is therefore not satisfied by remote-severance alone.

The script must either (a) perform Flow B such that the adopter repository's
object store never contains framework history (e.g. copy working-tree content
out of a throwaway clone into a freshly `git init`-ed adopter repo, rather than
re-homing the framework's own `.git`), or (b) explicitly scrub framework
`refs/remotes/*`, tags, notes, reflog, and unreachable objects and then verify
none remain. The script **asserts** the post-condition holds and aborts if
framework refs or objects are still reachable. This verification is
non-overridable.

**D-7.6 — Target-identity guard.**
Independent of the dirty-tree check, the script confirms the target is the
intended adopter tree and refuses to operate on the framework repository itself
or on a nested/parent framework worktree. Self-targeting a framework tree aborts
with a clear message.

**Consequence for D-1.** D-1 remains the authoritative statement of the adoption
model; D-7 extends it from one flow to two and specifies the safety semantics the
implementing script must honor. The manual nine-step procedure remains documented
as a fallback for environments where the script cannot run; the fallback
documentation must include the D-7.3 and D-7.5 verification steps so a manual
adopter performs the same confidentiality checks the script enforces.

---

### D-8: Discipline-inheritance boundary — what adopters inherit vs. what is framework-release-specific

**Status of this decision:** Amendment (2026-08-20), sourced from TC-063 field
feedback (finding FF-2): the exported baseline presumed framework-release
dev-staging onto adopters. The exported artifact shipped baseline-steward's
`dev`-as-integration-surface, curated-release git discipline (ADR-0026) as if
every adopter project must run its own work that way. ADR-0026 already states
adopters inherit none of that discipline — but before TC-063 that was an intent
statement contradicted by what actually shipped. D-8 closes the gap between the
stated intent and the exported artifact.

**What adopters DO inherit.** The full management-layer discipline described
elsewhere in this ADR and in the framework's governance model:

- Guardrails and boundary protection (namespace isolation, bench lifecycle,
  worktree teardown authorization)
- The ADR / decision-record practice — adopters write their own ADRs following
  the same template and status lifecycle
- Git commit discipline — review-before-push, no secrets, no attribution
  statements, meaningful commit messages
- AC-ticket tracking — adopters run their own ticket queue in `tasks.yaml`
  under their own slug
- The review gates — security-reviewer and docs-reviewer passes before
  `branch_ready`
- The LGTM acceptance gate — HIL confirmation before merge, every time
- **`main` append-only and merge-only** ([ADR-0004](adr-0004-main-branch-protection.md))
  — no direct commits, no force-push, no history rewrite on `main`, roll-forward
  only. This is sound universal git discipline independent of how any given
  project stages its pre-release work, and adopters inherit it as-is.

**What adopters DO NOT inherit.** The framework-release-specific `dev`-as-
integration-and-durability-surface staging model and the curated cherry-pick
release model ([ADR-0026](adr-0026-release-branch-curation-model.md)) are
**not** part of the exported baseline's prescription for the adopter's own
project. That model exists so **this framework** can ship curated
AgenticCore releases — cutting `release/vX.Y.Z-prep` from `main`,
cherry-picking only complete/closed tickets from `dev`, and merging back. It is
a framework-release mechanism, not a general project-management prescription.
An adopter chooses their own branch strategy for their own project — a single
`main`-only flow, a trunk-based flow, a different git-flow variant, or the
ADR-0026 pattern itself if they judge it useful — but the framework does not
prescribe it and does not ship agent instructions presuming it.

**Direction of flow.** The adopted codebase git-flows toward the adopter's
**own** `main` (or whatever integration branch the adopter names), and
**never** back to the AgenticCore repository. `baseline-steward` in the
framework repository remains the sole path to a new AgenticCore release;
no adopter commit, branch, or history reaches it (D-1, D-7.3, D-7.5).

**Customer layer.** Consistent with the relaxed-control model already
established for the `.00` / customer layer, the framework never prescribes the
adopter's customer-layer way of working. D-8 extends the same non-prescription
principle to the adopter's choice of branch strategy at the management layer.

**What this makes true.** ADR-0026 states, in its "Framework-development
scoped" consequence: "Adopters inherit none of this. The `dev`-staging /
release-curation discipline is a framework-development workflow, not an
adoption requirement." Before TC-063, that statement was contradicted by the
exported artifact — the baseline shipped `baseline-steward`'s dev-staging
`AGENT.md` content verbatim to adopters. D-8, together with the TC-063
neutralization work on the exported onboarding and bootstrap documentation,
makes ADR-0026's claim **true in practice**, not merely stated in intent. The
gap closes down to the provisioning layer, too: `provision-bench.sh`'s
worktree-creation logic is branch-agnostic by construction — it branches from
whatever branch `.01` currently has checked out (HEAD), not a hard-coded name
— so only the illustrative worktree-layout documentation shows the
framework's own branch names, and adopters are not required to adopt them.

**Consequence for D-1 and D-7.** D-1 and D-7 remain the authoritative
statements of the distribution/adoption **flow** — how an adopter obtains the
framework and severs it from the framework's own history. D-8 does not alter
either flow. D-8 clarifies a distinct, previously-unstated boundary: the
**discipline-inheritance** boundary — which parts of the framework's own
governance the exported baseline imposes on the adopter's project, and which
parts are specific to how this framework, and only this framework, ships its
own releases.

---

### Note: `.00` persona naming — future work

The `.00` bench persona is currently named `assistant` in the pattern-h
template. This collides with the model's generic default identity, creating
ambiguity between "raw unscoped model" and "bench persona with defined
authority and rules."

A future ADR (likely an addendum to ADR-0011) should establish that the `.00`
persona name is project-specific, declared in the bench AGENT.md at provision
time, and that `assistant` is reserved for the unscoped model. This is not
resolved here.

---

## Consequences

**Positive:**
- Adopter repos are completely clean — no AC history, no upstream coupling
  unless deliberately added
- Hard requirements are minimal and explicit; operators know exactly what they
  need before starting
- Versioned baseline model fits government program CM discipline
- Pattern promotion gate creates a formal but lightweight path for ecosystem
  growth — AC compounds value over time from all adopter innovations
- Distribution is platform-agnostic; no assumption about where AC or the
  adopter's repo is hosted
- EXAMPLE re-initialization from AC (as a v2.0 project) is a natural first
  real-world validation of this workflow

**Negative / Trade-offs:**
- No automated upstream sync means adopters can drift silently. Mitigation:
  `framework-version.txt` makes the baseline explicit; AC release notes
  document what changed since any prior version
- `export-framework.sh` does not yet exist — it is an implementation deliverable
  from this ADR
- Slug collision between organizations is possible; convention-only uniqueness
  is sufficient at current scale but may require a registry if AC adoption
  grows broadly

**Neutral:**
- Adopters who prefer a live upstream connection may add `ap-upstream` as a
  remote; this is unsupported in the sense that AC does not maintain a merge
  compatibility guarantee, but it is not prohibited

---

## Implementation Notes

The following tasks are spawned from this ADR:

1. **Write `export-framework.sh`** — copies AC release content to target
   directory; supports both adoption flows (D-7): Flow A `git init` into an
   empty dir, and Flow B re-home into an existing customer tree. Prompts for slug,
   writes slug to `AGENT.md` / `tasks.yaml` / `PROCESS.md`, severs framework
   push paths with a verified allowlist-based hard assertion (D-7.3), scrubs and
   verifies removal of framework history/refs/objects (D-7.5), honors the
   re-home safety interlock and bounded `--force` scope (D-7.2), the
   target-identity guard (D-7.6), and `--dry-run` with zero side effects (D-7.4),
   and creates an initial commit recording the AC release version. The D-7.3 and
   D-7.5 assertions are non-overridable and run on every invocation.
   **Tracked by TC-050.**
2. **Write `framework-version.txt`** — included in every AC release export;
   records AC release tag and export date. **Tracked by TC-050.**
3. **Update `getting-started.md`** — replace current onboarding flow with
   export-and-init procedure; document hard requirements prominently
4. **Update ADR-0014** — remove `Proposed — pending ADR-0015` from status
   line; D-3 and D-5 are now resolved; advance to `Accepted`
5. **Update `check-env.sh`** — add AI toolchain / OpenCode presence check as
   a hard-requirement validation step

---

## Related

- [ADR-0014: Project Task Slug and ADR Ticket Governance](adr-0014-project-slug-adr-ticket-governance.md) — slug init procedure resolved by D-5
- [ADR-: AI toolchain Profile Inheritance](adr-0009-agent-portability-model.md)
- [ADR-0001: Bootstrap Architecture](adr-0001-bootstrap-architecture.md)
- [ADR-0026: Release-Branch Curation Model](adr-0026-release-branch-curation-model.md) — the
  framework-release-specific `dev`-staging / curated-release discipline that D-8 clarifies
  adopters do **not** inherit
- [ADR-0004: `main` Branch Protection and Immutability](adr-0004-main-branch-protection.md) —
  the `main` append-only/merge-only discipline that D-8 clarifies adopters **do** inherit
- [ADR-0025: Framework Write-Protection Model](adr-0025-framework-write-protection-model.md) —
  the adoption-posture layer that already excludes adopters from framework `main` write access
