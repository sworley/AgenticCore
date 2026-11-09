# Contributing to AgenticCore

Thanks for contributing. This is a harness for orchestrating AI agents; changes
are governed by the same discipline the harness enforces on its own agents.
Please read the architecture and the governance rules before making changes.

## Two Ways to Contribute

There are **two distinct paths** for improvements to reach AgenticCore, depending
on how you came to the framework:

- **Contributing to this repo directly** — you cloned or forked
  `sworley/AgenticCore`. Your branch shares history with `main`, so a standard
  PR works: branch, open a PR against `main`, attach the `AC-NNNN` task id and
  governing ADR, and pass the required gates (below). This is the normal OSS
  contribution flow.

- **You adopted the framework via `export-framework.sh`** — your copy is a
  **severed** release with no shared history with this repo, so a raw PR cannot
  be merged cleanly. Contribute improvements back through **Pattern Promotion**
  instead: abstract the portable pattern (strip all project-specific content),
  then open an `AP-NNNN` task against this repo and let `baseline-steward`
  evaluate the *abstraction*. See
  [`mddocs/reference.architecture/adopter-reconciliation.md`](mddocs/reference.architecture/adopter-reconciliation.md)
  §Pattern Promotion and ADR-0015 D-4.

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

## Main Branch Protection

`main` is protected at the repository level. GitHub enforces the following and
will block a merge until each is satisfied:

- **Pull requests only.** Direct commits and pushes to `main` are rejected
  (administrators included). All changes land via a pull request that is then
  merged.
- **CI must pass.** A pull request must pass the required `verify` status check
  from the CI workflow (mdBook build, internal-link check, `bash -n` over every
  script, and the adopt/provision test harnesses) before it can be merged.
- **Signed commits.** Every commit in the pull request must be GPG-signed
  (`git commit -S`, or `commit.gpgsign` enabled). Unsigned commits are rejected.
- **No force-push or deletion.** Rewriting, force-pushing, or deleting `main`
  directly is blocked.

Set up signing once:

```sh
git config --global user.signingkey <your-signing-key>
git config --global commit.gpgsign true
```

See `mddocs/adr/adr-0004-main-branch-protection.md` for the rationale behind
the append-only/merge-only `main` model.

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
