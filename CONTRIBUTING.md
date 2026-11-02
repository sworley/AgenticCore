# Contributing to AgenticCore

Thanks for contributing. This is a harness for orchestrating AI agents; changes
are governed by the same discipline the harness enforces on its own agents.
Please read the architecture and the governance rules before making changes.

## Ground Rules

- **All work goes through branches and pull requests.** No direct commits or
  pushes to `main`. `main` is append-only and merge-only (see
  `mddocs/adr/adr-0004-main-branch-protection.md`).
- **ADR discipline.** If a change affects governed behavior (task-queue rules,
  bench model, HIL gates, agent roster, security controls, branch protection),
  it must be authorized by an accepted ADR. Proposing new governed behavior
  requires a proposed ADR as part of the change.
- **No self-approval.** Your own change must be reviewed by a different
  reviewer (documentation and security use a two-role implementer/evaluator
  model — see `mddocs/AGENTICCORE_SPEC.md` §8).
- **Secrets hygiene.** Never commit credentials, tokens, or secrets. Use the
  credential store and reference variables.
- **External content gate.** Any change that incorporates external content
  (fetched URLs, upstream pull, external API data, pasted third-party text)
  must pass the security inspection gate before it is acted on.

## Getting Started

1. Read `mddocs/AGENTICCORE_SPEC.md` (the authoritative definition) and
   `.core/invariants.md` (absolute prohibitions).
2. Read `mddocs/onboarding/getting-started.md`.
3. Provision a worker bench for your change (see
   `mddocs/reference.architecture/provision-worker-bench.md`).
4. Write your change on a branch.

## Branch Naming

```
<type>/<ticket-id>-<short-slug>
```

Types: `feat/`, `fix/`, `docs/`, `chore/`, `security/`. If your change is tied
to a task in `tasks.yaml`, use its `AC-NNNN` id in the branch name.

## Commit Discipline

- Commit after each discrete unit of work — do not accumulate unrelated changes.
- Use a concise summary line, then a body explaining the why.
- Reference the task and, where applicable, the governing ADR.

## Pull Requests

- Open a PR against `main`.
- Attach the task id (`AC-NNNN`) and the governing ADR(s).
- Ensure the docs build cleanly: `cd mddocs && mdbook clean && mdbook build`.
- Ensure all scripts pass `bash -n` and (where applicable) `shellcheck`.
- If the change touches security, hooks, secrets management, or compliance,
  request a `security-reviewer` pass and include the verdict.

## Documentation

- All documentation lives in `mddocs/` and builds via mdBook.
- ADRs are forward-only and append-only; update `mddocs/adr/index.md` and
  `mddocs/SUMMARY.md` when adding or modifying docs.
- Run `mdbook clean && mdbook build` after any `mddocs/` change — zero errors required.
- Keep node labels short in diagrams; prefer Mermaid only when it helps.

## Testing

- Every script should have a companion runbook in `mddocs/operations/runbooks/`.
- Run the agent sync to confirm the roster is consistent:
  `sh .agents/sync-agents.sh`
- Run the environment check: `sh mddocs/scripts/check-env.sh`.

## Community Expectations

- Be respectful and constructive. See `CODE_OF_CONDUCT.md`.
- Do not introduce content that is proprietary, customer-identifying, or
  organization-specific. This harness is open-source ready.
