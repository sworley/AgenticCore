# Summary

[Introduction](index.md)

---

# Getting Started

- [AgenticCore Specification](AGENTICCORE_SPEC.md)
- [Configuration Reference](configuration.md)

---

# Onboarding

- [Visual Overview](onboarding/visual-overview.md)
- [Getting Started](onboarding/getting-started.md)
- [Repository Structure](onboarding/repository-structure.md)
- [Agentic Workflow Overview](onboarding/agentic-workflow-overview.md)
- [Bench Model](onboarding/bench-model.md)

---

# Architecture Decisions

- [ADR Index](adr/index.md)
  - [ADR-0000: Template](adr/adr-0000-template.md)
  - [ADR-0001: Bootstrap Architecture](adr/adr-0001-bootstrap-architecture.md)
  - [ADR-0002: mcp-rag-docs](adr/adr-0002-mcp-rag-docs.md)
  - [ADR-0003: stdio MCP Architecture](adr/adr-0003-mcp-stdio-architecture.md)
  - [ADR-0004: main Branch Protection](adr/adr-0004-main-branch-protection.md)
  - [ADR-0005: Prompt Traceability and Session Logging](adr/adr-0005-prompt-traceability-session-logging.md)
  - [ADR-0006: External Content Gate Scope](adr/adr-0006-external-content-gate-scope.md)
  - [ADR-0007: Bench Scope Isolation](adr/adr-0007-bench-scope-isolation.md)
  - [ADR-0008: Orchestrator Subagent Routing Layer](adr/adr-0008-orchestrator-subagent-routing-layer.md)
  - [ADR-0009: Agent Portability Model](adr/adr-0009-agent-portability-model.md)
  - [ADR-0010: Hook Rollback Strategy](adr/adr-0010-hook-rollback-strategy.md)
  - [ADR-0011: Lead-Engineer Identity Anchoring](adr/adr-0011-lead-engineer-identity-anchoring.md)
  - [ADR-0012: Bench Assignment — Canonical/Generated Split](adr/adr-0012-bench-assignment-canonical-generated-split.md)
  - [ADR-0013: Pattern A — Two-Flavor Model](adr/adr-0013-pattern-a-two-flavor-model.md)
  - [ADR-0014: Project Task Slug and ADR Ticket Governance](adr/adr-0014-project-slug-adr-ticket-governance.md)
  - [ADR-0015: Framework Distribution and Adoption Model](adr/adr-0015-framework-distribution-adoption-model.md)
  - [ADR-0016: Agentic Toolchain Secret Management](adr/adr-0016-agentic-toolchain-secret-management.md)
  - [ADR-0017: Outer Dependencies and Portable Configuration](adr/adr-0017-outer-dependencies-and-portability.md)
  - [ADR-0018: Credential Injection Pattern](adr/adr-0018-credential-injection-pattern.md)
  - [ADR-0019: Role Hierarchy, Persona Convention, and Delegation Autonomy Boundary](adr/adr-0019-role-hierarchy-persona-convention-security-audit-contract.md)
  - [ADR-0020: Default Model Selection for opencode Sessions](adr/adr-0020-default-model-selection.md)
  - [ADR-0021: Per-Agent Model Tiering (Opt-In Overrides on Top of the Default)](adr/adr-0021-per-agent-model-tiering.md)
  - [ADR-0022: Git-Native Pre-Commit Permission-Order Check and Install-Only Hook Installer](adr/adr-0022-git-pre-commit-permission-order-check.md)
  - [ADR-0023: Config-Enforced opencode MCP Tool Restriction for approve_finding_update](adr/adr-0023-opencode-mcp-tool-restriction.md)
  - [ADR-0024: Informed HIL Override — Documented Risk-Acceptance Valve](adr/adr-0024-informed-hil-override.md)
  - [ADR-0025: Framework Write-Protection Model](adr/adr-0025-framework-write-protection-model.md)
  - [ADR-0026: Release-Branch Curation Model](adr/adr-0026-release-branch-curation-model.md)
  - [ADR-0027: Authoring-Agent Execution Model](adr/adr-0027-authoring-agent-execution-model.md)

---

# Reference Architecture

- [Reference Index](reference.architecture/index.md)
  - [Session Open Checklist](reference.architecture/session-open-checklist.md)
  - [Session Close Checklist](reference.architecture/session-close-checklist.md)
  - [Provision Worker Bench](reference.architecture/provision-worker-bench.md)
  - [Bootstrap New Project](reference.architecture/bootstrap-new-project.md)
  - [Task Queue Operations](reference.architecture/task-queue-operations.md)
  - [Bench Registry](reference.architecture/bench-registry.md)
  - [Agent Authoring Workflow](reference.architecture/agent-authoring-workflow.md)
  - [Release Process](reference.architecture/release-process.md)
  - [Release Notes Template](reference.architecture/release-notes-template.md)
  - [Configure MCP Servers](reference.architecture/configure-mcp.md)
  - [Shared Agent Context](reference.architecture/shared-context.md)
  - [Adopter Reconciliation](reference.architecture/adopter-reconciliation.md)
  - [Sign-Off Package](reference.architecture/sign-off-package.md)

---

# Operations

- [Operations Index](operations/index.md)
  - [Runbook: git-sync — Git Workspace Sync](operations/runbooks/git-sync-runbook.md)
  - [Runbook: Sync Agent Definitions](operations/runbooks/sync-agent-definitions.md)
  - [Runbook: Configure Agent Namespace](operations/runbooks/configure-agents.md)
  - [Runbook: Sync Agent Config](operations/runbooks/sync-opencode-config.md)
  - [Runbook: Build and Publish mdBook](operations/runbooks/build-publish-mddocs.md)
  - [Runbook: Rotate Git PAT](operations/runbooks/rotate-git-pat.md)
  - [Runbook: Set Up mddoc Local Documentation Site](operations/runbooks/setup-mddoc.md)
  - [Runbook: Hook Rollback](operations/runbooks/hook-rollback.md)
  - [Runbook: Session Continuity](operations/runbooks/session-continuity.md)
  - [Runbook: Agent Session Tracking](operations/runbooks/agent-session-tracking.md)
  - [Runbook: secret-guard Hook](operations/runbooks/secret-guard.md)
  - [Runbook: Credential-Identity Guard](operations/runbooks/credential-identity-guard.md)
  - [Runbook: check-links — Internal Link Validator](operations/runbooks/check-links-runbook.md)
  - [Runbook: Bench Recovery](operations/runbooks/bench-recovery.md)
  - [Runbook: AI-Assisted Session Commit Discipline](operations/runbooks/ai-doc-session-commit-discipline.md)
  - [Runbook: Agent Authoring Workflow](operations/runbooks/agent-authoring-workflow.md)
  - [Runbook: Review Ledger](operations/runbooks/review-ledger-runbook.md)
  - [Runbook: Session Reasoning Log](operations/runbooks/session-reasoning-log.md)

---

# FAQ

- [FAQ Index](faq/index.md)
  - [How Is the Project Workspace Managed?](faq/workspace-management.md)
  - [How Do I Quickly Get Oriented?](faq/orientation.md)
  - [How Do Diagrams Render and How Do I Build the Docs?](faq/docs-build.md)
  - [Which Git Hosts Does git-sync Support?](faq/git-sync-hosts.md)

---

# Examples

- [Examples Index](examples/index.md)
  - [Ticket Lifecycle](examples/ticket-lifecycle.md)
  - [Bench Session Walkthrough](examples/bench-session-walkthrough.md)
  - [ADR Decision Process](examples/adr-decision-process.md)
  - [Release Process](examples/release-process.md)

---

# MCP Servers

- [MCP Servers](mcp/index.md)
  - [mcp-rag-docs](mcp/mcp-rag-docs/README.md)

---

# Scripts

- [Scripts Index](scripts/operations/index.md)
  - [git-sync.sh](scripts/operations/git-sync.md)
  - [sync-agent-config.sh](scripts/operations/sync-opencode-config.md)
  - [check-env.sh](scripts/operations/check-env.md)
  - [bench-status.sh](scripts/operations/bench-status.md)
  - [provision-bench.sh](scripts/operations/provision-bench.md)
  - [check-worktree-hygiene.sh](scripts/operations/check-worktree-hygiene.md)
  - [read-audit-log.sh](scripts/operations/read-audit-log.md)
  - [check-links.sh](scripts/operations/check-links.md)

- [MCP Tests](scripts/mcp-tests/README.md)
  - [run-all.sh](scripts/mcp-tests/run-all.md)
  - [test-mcp-rag-docs.py](scripts/mcp-tests/test-mcp-rag-docs.md)
  - [test-mcp-filesystem.sh](scripts/mcp-tests/test-mcp-filesystem.md)
  - [test-mcp-git.sh](scripts/mcp-tests/test-mcp-git.md)

- [Onboarding](scripts/setup/index.md)
  - [adopt.sh](scripts/setup/adopt.md)
  - [opencode.json — init-opencode-settings](scripts/setup/init-opencode-settings.md)
  - [phase2-dev-toolchain.sh](scripts/setup/phase2-dev-toolchain.md)
  - [verify-toolchain.sh](scripts/setup/verify-toolchain.md)

- [Hooks and Utilities](scripts/hooks-index.md)
  - [statusline-command.sh](scripts/statusline-command.md)
  - [update-summary-on-adr-write.py](scripts/update-summary-on-adr-write.md)

---

# Release Notes

- [Unreleased](release-notes/UNRELEASED.md)

---

# Backlog

- [Backlog](backlog.md)
