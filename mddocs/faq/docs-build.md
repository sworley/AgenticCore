# FAQ: How Do Diagrams Render and How Do I Build the Docs?

**Question (2026-11-02 session):** "Do the workflow diagrams actually render? How do
I build the documentation site?"

## Answer

Mermaid diagrams render **natively on GitHub/GitLab**, and in the mdBook site via the
committed `mermaid.min.js` + `mermaid-init.js` assets, wired through `additional-js`
in `mddocs/book.toml`. There is no `mdbook-mermaid` preprocessor and no per-checkout
setup step.

Build and serve the site:

```sh
cd mddocs
mdbook build     # static site → mddocs/book/
mdbook serve     # http://localhost:3000, live reload
```

Validate internal links before committing docs:

```sh
./mddocs/scripts/check-links.sh
```

See the [Set Up mddoc](../operations/runbooks/setup-mddoc.md) runbook and
[check-links](../operations/runbooks/check-links-runbook.md) runbook for full detail.

## Canonical References

- [Set Up mddoc Local Documentation Site](../operations/runbooks/setup-mddoc.md)
- [Runbook: check-links](../operations/runbooks/check-links-runbook.md)

## Provenance

- **Session:** 2026-11-02 — "mermaid rendering / docs build" Q&A.
