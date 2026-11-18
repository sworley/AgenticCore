---
id: SH-0028-doc
document_type: script-docs
status: active
lifecycle: active
title: Metadata registry reconcile / report tool (script docs)
domain: Management
category: Governance
process: metadata-registry-maintenance
owner: docs-engineer
allowed_in_adopter_repos: true
related:
  paths:
    - reconcile-metadata-registry.py
    - metadata-standard.md
---

# reconcile-metadata-registry.py

<a href="reconcile-metadata-registry.py" download>Download reconcile-metadata-registry.py</a> · python3

Scans every `*.meta.yaml` companion (SH executable IDs) and the `SDX`/`REF`/`STD`/`SEED`
classification IDs in `mddocs/` frontmatter, derives each artifact's classification,
and compares it against the registry tables (`metadata-standard.md` §8 for SH,
§8.1 for classification IDs). The per-artifact metadata is authoritative; `--check`
exits 1 on drift. Run from the repository root:

```sh
python3 mddocs/scripts/reconcile-metadata-registry.py --check
```

```python
{{#include reconcile-metadata-registry.py}}
```
