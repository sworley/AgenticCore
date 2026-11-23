---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
category: Audits
purpose: Home for gate-output evidence bundles produced by the harness
---

# Audits

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for audit and gate-provenance content. Gate outputs
produced by the harness (reconcile-metadata-registry, check-links, mdbook build,
coverage) are captured as managed, provenance-carrying evidence bundles under
`audits/evidence/`.

## Contents

- [Evidence](evidence/README.md) - boundary-captured gate provenance

**Owner:** maintained by the harness. This home carries `category: Audits`
(ADR-0029). Evidence is captured at governance boundaries (release,
supersession, waiver, activity close), not per-commit, to avoid churn.
