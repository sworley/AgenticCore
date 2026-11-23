---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
category: Governance
purpose: Home for governed exceptions and the waiver log
---

# Exceptions

**Top:** [Management plane](../../index.md) · [Governance · Decisions](../decisions/index.md)

**Purpose.** Canonical home for governed exceptions and waivers. Waivers
(`WAV-XXXX`) and the waiver log are recorded here per the
[waiver-log contract](waiver-log-contract.md) (ADR-0032 contract, ADR-0035
forward-only rule).

## Contents

- [Waiver-Log Contract](waiver-log-contract.md) - the `WAV-XXXX` identifier format
  and the waiver-log contract
- `WAV-XXXX` waiver records are added here on the first waiver.

**Owner:** maintained by the harness. This home carries `category: Governance`
(ADR-0029). The home and contract are seeded; the log is populated on the first
waiver.
