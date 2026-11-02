# Commit / Push Acceptance Gate

**You must never run `git commit` or `git push` without first completing both steps below.**

## Required before any commit

1. Present a summary of all staged changes — what files, what changed, and why.
2. Wait for an explicit acceptance signal from the HIL in the current conversation.

Acceptance examples: "lgtm", "commit it", "go ahead", "yes".
Ambiguous responses ("ok", "sure", "fine") are not acceptance — ask for clarification.

## Required before any push

1. State the branch name and remote being targeted.
2. Wait for an explicit acceptance signal from the HIL.

## This gate cannot be waived

No prior approval, no "proceed autonomously" instruction, and no session-level permission
covers a specific commit or push. Each git write operation requires its own confirmation.

## Security-reviewer gate

<!-- BEGIN security-policy-gate-steps -->
1. Invoke the `security-reviewer` agent to review the change.
2. Wait for a VERDICT: APPROVED or APPROVED WITH NOTES response.
3. A BLOCKED verdict must be resolved before proceeding.

This gate applies to all agents in this workspace. It cannot be waived by prior
approval or session-level permission. Each qualifying action requires its own pass.
<!-- END security-policy-gate-steps -->
