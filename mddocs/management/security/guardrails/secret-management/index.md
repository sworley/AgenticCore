---
document_type: index
status: active
lifecycle: active
primary: true
security_category: guardrail
category: Security
domain: Management
purpose: Home for the secret-management guardrail runbook
---

# Secret-Management Guardrail

**Top:** [Management plane](../../../index.md)

**Purpose.** Canonical home for the secret-management guardrail. The runbook
blocks commands that expand or print credential values in plaintext.

## Contents

- [secret-guard Hook](secret-guard.md) - block commands that expand or print
  credential values in plaintext

**Owner:** maintained by the harness. This home carries `category: Security`
(ADR-0029). The authoritative runbook is `primary: true` at this path; the
historical `operations/runbooks/secret-guard.md` location is retained as a
`primary: false` redirect stub so existing links continue to resolve.
