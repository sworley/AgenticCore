## Summary

<!-- One short paragraph: what this change does and why. -->

## Related

- Task: AC-NNNN
- ADR (if applicable): ADR-XXXX

## Checklist

Before merging, confirm all of the following:

- [ ] Every commit is GPG-signed (`git commit -S`)
- [ ] The required `verify` CI check passes (mdBook build, internal-link check,
      `bash -n` over scripts, adopt/provision test harnesses)
- [ ] Docs build cleanly: `cd mddocs && mdbook clean && mdbook build`
- [ ] Scripts pass `bash -n` (and `shellcheck` where applicable)
- [ ] No secrets, credentials, or organization-specific content
- [ ] Governance-compliant: task on `tasks.yaml`, ADR referenced if governed behavior
