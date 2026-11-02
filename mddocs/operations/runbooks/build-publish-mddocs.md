# Runbook: Build and Publish mdBook

**Purpose:** Build the mdBook documentation locally and/or trigger Git Pages publication.

**Script:** Manual (see CI for automated publish)
**When to run:** Before any review session; CI runs automatically on push to main

---

## Prerequisites

- `mdbook` installed: `cargo install mdbook`
- `mdbook-mermaid` installed: `cargo install mdbook-mermaid`
- `mddocs/SUMMARY.md` is up to date

---

## Local Build

### Build

```sh
mdbook build mddocs/
```

Output is written to `mddocs/book/`. This directory is gitignored.

### Serve locally

```sh
mdbook serve mddocs/
# Open http://localhost:3000
```

Serves with live-reload on file changes.

### Clean build

```sh
rm -rf mddocs/book/
mdbook build mddocs/
```

---

## CI/CD Publish (Git Pages)

The pipeline in `.git-ci.yml` (TC-002) builds and publishes on every push to `main`.

To trigger manually:
```sh
git push origin main
```

Pages URL format: `https://<namespace>.git.example.com/<project>/`

---

## SUMMARY.md Maintenance

Every new document must be added to `mddocs/SUMMARY.md` before build.
Omitting a file from SUMMARY.md does not prevent building, but the file
will not appear in the navigation.

Format:
```markdown
- [Page Title](path/to/file.md)
  - [Nested Page](path/to/nested.md)
```

---

## Verification

- [ ] `mdbook build mddocs/` exits 0
- [ ] `mddocs/book/index.html` exists
- [ ] All expected pages present in `mddocs/book/`
- [ ] Mermaid diagrams render correctly (check in browser)

---

## Rollback

Local build: `rm -rf mddocs/book/`
Published pages: Revert the commit that broke pages and push to main.
