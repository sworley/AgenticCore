---
document_type: reference
status: active
lifecycle: active
primary: true
domain: Management
category: Governance
purpose: Contract governing WAV-XXXX waivers and the waiver log
---

# Waiver-Log Contract

**Top:** [Exceptions](README.md)

**Purpose.** This is the governing contract for governed exceptions. A waiver is
a recorded, risk-accepted exception to a rule, guardrail, or gate. Waivers are
identified by a `WAV-XXXX` identifier and recorded in this
`management/governance/exceptions/` home (ADR-0029 D; ADR-0032 contract;
forward-only rule ADR-0035).

## WAV-XXXX identifiers

- Format: `WAV-XXXX`, a flat global sequence (`WAV-0001`, `WAV-0002`, ...).
- A waiver ID is stable and immutable once published; never renumber or reuse.
- Waivers are governance records, not classification metadata (ADR-0032). They
  carry by themselves no authority beyond the bounded, recorded exception.

## Waiver record contract

Each waiver is recorded as a `.md` file in this home with the following
metadata contract:

| Field | Required | Notes |
|---|---|---|
| `document_type` | yes | `index` |
| `status` | yes | `active` or `superseded` |
| `lifecycle` | yes | `active` |
| `primary` | yes | `true` |
| `domain` | yes | `Management` |
| `category` | yes | `Governance` |
| `waiver_id` | yes | `WAV-XXXX` |
| `control` | yes | The rule, guardrail, or gate being waived |
| `risk` | yes | Risk accepted by granting this waiver |
| `hil_acceptance` | yes | HIL acceptance verbatim (ADR-0024) |
| `granted_by` | yes | Who granted the waiver |
| `granted_on` | yes | ISO-8601 date |
| `supersedes` | no | `WAV-XXXX` this record supersedes |

## Waiver log

The waiver log is the authoritative index of every waiver and is kept at
`management/governance/exceptions/`. It lists each `WAV-XXXX` with its control,
risk, and status so a reader can see at a glance what exceptions exist. It is
updated when a waiver is added, superseded, or closed; each waiver record remains
in place as the durable record.

## Boundaries

- A waiver does not change the underlying rule; it records a bounded,
  risk-accepted exception to it.
- Waivers are logged under governance boundaries (release, supersession, waiver,
  activity close), consistent with the `audits/evidence/` provenance model.
- Granting a waiver that touches a control governed by an absolute refusal must
  follow the informed-HIL-override path (ADR-0024) and record the HIL acceptance
  verbatim.

**Owner:** maintained by the harness. The home and contract are seeded; the log
is populated on the first waiver.
