## Docs Review Gate

<!-- BEGIN docs-policy-standing-rules -->
These rules apply every session without exception when creating or modifying `.md` files:

- **docs-reviewer required** — any branch that creates or modifies `.md` files must invoke
  `docs-reviewer` before the branch is marked `branch_ready` or surfaced to the HIL for LGTM.
  Invoke after the last documentation edit in the session.
- **Typos check** — docs-reviewer runs `typos` (typos-cli) against all changed `.md` files.
  A BLOCKED verdict from any unallowlisted misspelling must be fixed before `branch_ready`.
- **No verdict skip** — docs-reviewer is evaluative only; it does not fix. The authoring agent
  must apply any required fixes and re-invoke docs-reviewer after correction.
- **Verdict formats are binding** — APPROVED or APPROVED WITH NOTES allows proceed; BLOCKED
  halts the pipeline until findings are resolved.
<!-- END docs-policy-standing-rules -->
