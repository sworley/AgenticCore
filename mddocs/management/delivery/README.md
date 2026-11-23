---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
category: Delivery
purpose: Home for release management, release notes, and the delivery process contracts
---

# Delivery

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for release management and the delivery process
contracts: release records, the release process / gating procedure, the release
notes template, and the sign-off package. Each file here carries `primary: true`
and is authoritative at this path; the historical `release-notes/` and
`reference.architecture/` locations are retained as `primary: false` redirect
stubs so existing links continue to resolve.

## Contents

| File | Purpose |
|---|---|
| [Release Process](release-process.md) | Release process and gating procedure |
| [Release Notes Template](release-notes-template.md) | Template for writing release notes |
| [Sign-Off Package](sign-off-package.md) | Consolidated gate between task execution and HIL approval |
| [Releases](releases/) | Release records, one per baseline (`vX.Y.Z`) plus the running draft |

Release records live in `management/delivery/releases/`:

- [Unreleased](releases/UNRELEASED.md) - running draft of the next release notes
- [v0.7.0](releases/v0.7.0.md)
- [v0.6.0](releases/v0.6.0.md)

**Owner:** maintained by the harness. Delivery content is part of the management
plane (ADR-0029) and is governed by the metadata-first authority of ADR-0029,
with physical location fixed by the additive conformance layer.
