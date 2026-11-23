---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
category: Audits
purpose: Home for boundary-captured gate-provenance evidence bundles
---

# Evidence

**Top:** [Audits](../README.md) · [Management plane](../../index.md)

**Purpose.** Canonical home for gate-provenance evidence bundles: the captured
output of harness gates (reconcile-metadata-registry CLEAN, check-links, mdbook
build, coverage). Evidence is captured at governance boundaries (release,
supersession, waiver, activity close), not per-commit, to avoid churn.

## Contents

Gate output is captured here as it is produced. Each bundle carries provenance
(gate, timestamp, journal ref). No evidence bundles are committed yet; this home
is seeded and is populated on the first gate run at a governance boundary.

**Owner:** maintained by the harness. This home carries `category: Audits`
(ADR-0029).
