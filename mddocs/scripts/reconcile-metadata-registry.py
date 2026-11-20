#!/usr/bin/env python3
"""
Metadata Registry Reconcile / Report.

Scans every `*.meta.yaml` companion under `mddocs/scripts/` and
`mddocs/management/tooling/` (SH executable IDs), every SH `.md` script-doc
sidecar under `mddocs/scripts/`, and the classification IDs (SDX/REF/STD/SEED)
across `mddocs/` (from `.md` frontmatter and `.meta.yaml` reference companions),
and compares them against the registry tables (section 8 for SH, section 8.1 for
classification IDs) in `mddocs/scripts/metadata-standard.md`.

The per-artifact metadata (`.meta.yaml` / frontmatter) is authoritative. This
tool reports any drift between the authoritative metadata and the static registry
tables, so they are kept accurate rather than silently drifting. It also checks
that each SH script-doc's `allowed_in_adopter_repos` matches its authoritative
`.meta.yaml` (AC-0014 W3), so a reclassification cannot leave the shipped doc
sidecar stale in the opposite direction.

Usage (from the repository root, or anywhere):
    python3 mddocs/scripts/reconcile-metadata-registry.py            # print report
    python3 mddocs/scripts/reconcile-metadata-registry.py --check    # exit 1 on drift

Exit codes:
    0  report printed; on `--check`, no drift
    1  `--check` and drift was detected
"""

import os
import re
import sys
from pathlib import Path

# Repository root = three levels up from this script (<root>/mddocs/scripts/).
REPO = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO / "mddocs" / "scripts"
TOOLING_DIR = REPO / "mddocs" / "management" / "tooling"
MDDOCS = REPO / "mddocs"
STANDARD = REPO / "mddocs" / "scripts" / "metadata-standard.md"
DECISIONS_DIR = REPO / "mddocs" / "management" / "governance" / "decisions"
SUPERSESSION_LEDGER = DECISIONS_DIR / "supersession-ledger.yaml"
# ADR homes: active decisions (from ADR-0029) + historical mddocs/adr/ (ADR-0000..0028).
ADR_DIRS = (DECISIONS_DIR, REPO / "mddocs" / "adr")

# Annotation roots. Each entry is (directory to scan, base for the reported
# artifact path). `mddocs/scripts/` paths are reported relative to that dir
# (historical convention, e.g. `bench-status.sh`); `mddocs/management/tooling/`
# paths are reported relative to `mddocs/` (e.g. `management/tooling/scripts/validate_book.py`)
# so the registry table stays unambiguous across the two homes.
ANNOTATION_ROOTS = (
    (SCRIPTS_DIR, SCRIPTS_DIR),
    (TOOLING_DIR, MDDOCS),
)

ROW_RE = re.compile(
    r'^\|\s*(SH-\d+)\s*\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*([a-zA-Z-]+)\s*\|\s*'
    r'(true|false)\s*\|\s*([^|]+?)\s*\|\s*$'
)

# Classification ID kinds (metadata-standard section 1): index / reference / standard / seed.
CLASS_ID_RE = re.compile(r"^(SDX-\d+|REF-\d+|STD-\d+|SEED-[A-Z0-9-]+)$")
# Section 8.1 classification-ID registry row.
CLASS_ROW_RE = re.compile(
    r'^\|\s*(SDX-\d+|REF-\d+|STD-\d+|SEED-[A-Z0-9-]+)\s*\|\s*(\S+)\s*\|\s*(\S+)\s*\|\s*`([^`]+)`\s*\|$'
)


def parse_meta(path):
    """Parse a flat `key: value` companion; read only top-level scalar keys."""
    meta = {}
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                if line[0] in " \t#" or ":" not in line:
                    continue
                k, _, v = line.partition(":")
                meta[k.strip()] = v.strip().strip("'\"")
    except OSError:
        pass
    return meta


def to_bool(value):
    if value is None:
        return None
    if str(value).strip().lower() in ("true", "yes", "1"):
        return True
    if str(value).strip().lower() in ("false", "no", "0"):
        return False
    return None


def norm(value):
    """Normalize an empty/em-dash placeholder to ''."""
    if value is None:
        return ""
    return "" if str(value).strip() in ("", "-", "\u2014", "n/a", "none") else str(value).strip()


def derive_class(meta):
    """Map metadata to the four-class classification (metadata-standard section 3)."""
    if meta.get("enforces") not in (None, "", "-", "\u2014"):
        return 4
    domain = str(meta.get("domain", ""))
    if domain.startswith("Projects/") or meta.get("source_ticket") or meta.get("source_context"):
        return 3
    if to_bool(meta.get("allowed_in_adopter_repos")) is True:
        return 2
    return 1


def scan_canonical():
    """Build the canonical registry from `.meta.yaml` companions, keyed by SH id."""
    canonical = {}
    for base_dir, rel_base in ANNOTATION_ROOTS:
        for meta_path in sorted(base_dir.rglob("*.meta.yaml")):
            meta = parse_meta(meta_path)
            sh_id = str(meta.get("id", "")).strip()
            if not re.fullmatch(r"SH-\d+", sh_id):
                continue
            rel = meta_path.relative_to(rel_base)
            exec_path = str(rel)[: -len(".meta.yaml")]
            canonical[sh_id] = {
                "exec": exec_path,
                "class": derive_class(meta),
                "owner": str(meta.get("owner", "")).strip(),
                "allowed": to_bool(meta.get("allowed_in_adopter_repos")),
                "enforces": norm(meta.get("enforces")),
            }
    return canonical


def parse_registry_table():
    """Parse the section 8 markdown table into a dict keyed by SH id."""
    table = {}
    try:
        lines = STANDARD.read_text(encoding="utf-8").splitlines()
    except OSError:
        return table
    for line in lines:
        m = ROW_RE.match(line)
        if not m:
            continue
        sh_id, exec_path, cls, owner, allowed, enforces = m.groups()
        table[sh_id] = {
            "exec": exec_path,
            "class": int(cls),
            "owner": owner,
            "allowed": to_bool(allowed),
            "enforces": norm(enforces),
        }
    return table


def parse_frontmatter(path):
    """Parse `---`-delimited YAML frontmatter; read only top-level scalar keys."""
    meta = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return meta
    if not lines or lines[0].strip() != "---":
        return meta
    for line in lines[1:]:
        st = line.strip()
        if st == "---":
            break
        if not st or st.startswith("#") or ":" not in line:
            continue
        k, _, v = line.partition(":")
        meta[k.strip()] = v.strip().strip("'\"")
    return meta


def scan_classification_ids():
    """Scan for SDX/REF/STD/SEED classification IDs across mddocs/.

    Reads `.md` frontmatter and `.meta.yaml` companions (reference artefacts such
    as schemas, dependency locks, and rendering assets carry a REF id in their
    companion), so classification IDs are reconciled regardless of artefact type.
    """
    ids = {}
    for f in sorted(MDDOCS.rglob("*.md")):
        if "book" in f.parts:
            continue
        meta = parse_frontmatter(f)
        cid = str(meta.get("id", "")).strip()
        if not CLASS_ID_RE.fullmatch(cid):
            continue
        rel = f.relative_to(MDDOCS)
        ids[cid] = {
            "doc_type": str(meta.get("document_type", "")).strip(),
            "domain": str(meta.get("domain", "")).strip(),
            "path": rel.as_posix(),
        }
    for f in sorted(MDDOCS.rglob("*.meta.yaml")):
        meta = parse_meta(f)
        cid = str(meta.get("id", "")).strip()
        if not CLASS_ID_RE.fullmatch(cid):
            continue
        rel = f.relative_to(MDDOCS)
        # Report the artefact path, not the companion path, so the registry table
        # lists `profile.schema.json` rather than `profile.schema.json.meta.yaml`.
        artefact = rel.as_posix()[: -len(".meta.yaml")]
        ids[cid] = {
            "doc_type": str(meta.get("document_type", "")).strip(),
            "domain": str(meta.get("domain", "")).strip(),
            "path": artefact,
        }
    return ids


def scan_sh_script_docs():
    """Scan .md SH script-doc sidecars under mddocs/scripts/ for their
    `allowed_in_adopter_repos` flag, keyed by SH id, so each doc sidecar can be
    checked against the authoritative `.meta.yaml` (AC-0014 W3 - catches
    post-reclassification doc/flag drift that the shipping gate would otherwise
    leave inconsistent)."""
    docs = {}
    for md_path in sorted(SCRIPTS_DIR.rglob("*.md")):
        meta = parse_frontmatter(md_path)
        doc_id = str(meta.get("id", "")).strip()
        m = re.fullmatch(r"(SH-\d+)-doc", doc_id)
        if not m:
            continue
        sh_id = m.group(1)
        docs[sh_id] = {
            "path": md_path.relative_to(SCRIPTS_DIR).as_posix(),
            "allowed": to_bool(meta.get("allowed_in_adopter_repos")),
        }
    return docs


def parse_classification_table():
    """Parse the section 8.1 classification-ID markdown table."""
    table = {}
    try:
        lines = STANDARD.read_text(encoding="utf-8").splitlines()
    except OSError:
        return table
    for line in lines:
        m = CLASS_ROW_RE.match(line)
        if not m:
            continue
        cid, doc_type, domain, path = m.groups()
        table[cid] = {"doc_type": doc_type, "domain": domain, "path": path}
    return table


ADR_ID_RE = re.compile(r"^(ADR|adr)-(\d{4})")
DEF_ADR_RE = re.compile(r"^(ADR-\d{4})$")
SUPERSESSION_LIST_RE = re.compile(r"^\s*-\s+([A-Za-z_]+)\s*:\s*(.*)$")
SUPERSESSION_FIELD_RE = re.compile(r"^\s{2,}([A-Za-z_]+)\s*:\s*(.*)$")


def parse_adr_body_meta(path):
    """Parse an ADR's metadata lines of the form `**Field:** value`."""
    meta = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return meta
    for line in lines[:20]:
        m = re.match(r"^\*\*([A-Za-z /]+):\*\*\s*(.*)$", line.strip())
        if m:
            meta[m.group(1).strip().lower()] = m.group(2).strip()
    return meta


def scan_adr_status():
    """Scan every ADR file (both homes) for its lifecycle status + superseded-by."""
    adrs = {}
    for d in ADR_DIRS:
        if not d.exists():
            continue
        for f in sorted(d.glob("*.md")):
            m = ADR_ID_RE.match(f.name)
            if not m:
                continue
            adr_id = "ADR-" + m.group(2)
            meta = parse_adr_body_meta(f)
            adrs[adr_id] = {
                "status": str(meta.get("status", "")).strip(),
                "supersedes": str(meta.get("supersedes", "")).strip(),
                "superseded_by": str(meta.get("superseded by", "")).strip(),
                "path": f.relative_to(d).as_posix(),
            }
    return adrs


def parse_supersession_ledger():
    """Parse the supersession ledger into a list of entry dicts."""
    entries = []
    try:
        lines = SUPERSESSION_LEDGER.read_text(encoding="utf-8").splitlines()
    except OSError:
        return entries
    cur = None
    for line in lines:
        st = line.strip()
        if not st or st.startswith("#"):
            continue
        m = SUPERSESSION_LIST_RE.match(line)
        if m:
            if cur is not None:
                entries.append(cur)
            cur = {m.group(1): m.group(2).strip().strip("'\"")}
            continue
        m = SUPERSESSION_FIELD_RE.match(line)
        if m and cur is not None:
            cur[m.group(1)] = m.group(2).strip().strip("'\"")
    if cur is not None:
        entries.append(cur)
    return entries


def is_true(value):
    return str(value).strip().lower() in ("true", "yes", "1")


def is_blank(value):
    return str(value).strip().lower() in ("", "-", "null", "none", "n/a")


def fmt_allowed(value):
    return "true" if value is True else "false"


def reconcile_supersession_ledger(adrs):
    """Validate the supersession ledger (ADR-0035) against the ADR files.

    Checks, per entry:
      - `superseded` / `superseding` are well-formed ADR ids (ADR-NNNN).
      - `status`, `disposition`, `date`, `ticket` match the field contract.
      - Bidirectional linkage: the superseding ADR records `Supersedes: <id>` and
        the superseded ADR records `Superseded by: <id>`.
      - Retire consistency: `retired: true` requires a `retired_git_ref` and the
        retired file absent from the tree; `retired: false` requires the file
        present and no `retired_git_ref`.
    Returns a list of drift strings (empty when the ledger is consistent).
    """
    drift = []
    entries = parse_supersession_ledger()
    seen_superseded = set()
    for i, e in enumerate(entries, 1):
        sid = str(e.get("superseded", "")).strip()
        sup = str(e.get("superseding", "")).strip()
        if not DEF_ADR_RE.fullmatch(sid):
            drift.append(f"[LEDGER #{i}] superseded must be ADR-NNNN, got {sid!r}")
            continue
        if not DEF_ADR_RE.fullmatch(sup):
            drift.append(f"[LEDGER #{i}] superseding must be ADR-NNNN, got {sup!r}")
            continue
        if sid in seen_superseded:
            drift.append(f"[LEDGER #{i}] duplicate superseded record for {sid}")
        seen_superseded.add(sid)

        if str(e.get("status", "")).strip().lower() not in ("superseded", "deprecated"):
            drift.append(f"[LEDGER #{i}] {sid} status must be superseded|deprecated (got {e.get('status')!r})")
        if str(e.get("disposition", "")).strip().lower() not in ("superseded", "waived"):
            drift.append(f"[LEDGER #{i}] {sid} disposition must be superseded|waived (got {e.get('disposition')!r})")
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(e.get("date", "")).strip()):
            drift.append(f"[LEDGER #{i}] {sid} date must be YYYY-MM-DD (got {e.get('date')!r})")
        if not re.fullmatch(r"AC-\d{4}", str(e.get("ticket", "")).strip()):
            drift.append(f"[LEDGER #{i}] {sid} ticket must be AC-NNNN (got {e.get('ticket')!r})")

        n_meta = adrs.get(sup)
        s_meta = adrs.get(sid)
        if s_meta is None:
            drift.append(f"[LEDGER #{i}] superseded {sid} not found among ADR files")
        if n_meta is None:
            drift.append(f"[LEDGER #{i}] superseding {sup} not found among ADR files")
        if s_meta is None or n_meta is None:
            continue

        # Bidirectional linkage.
        sup_field = str(n_meta.get("supersedes", "")).strip()
        if sid not in sup_field:
            drift.append(f"[LEDGER #{i}] {sup} does not record 'Supersedes: {sid}' (got {sup_field!r})")
        sb_field = str(s_meta.get("superseded_by", "")).strip()
        if sup not in sb_field:
            drift.append(f"[LEDGER #{i}] {sid} does not record 'Superseded by: {sup}' (got {sb_field!r})")

        # Retire consistency (the gate in AGENTICCORE_SPEC.md).
        retired = is_true(e.get("retired"))
        ref = str(e.get("retired_git_ref", "")).strip()
        if retired:
            if is_blank(ref):
                drift.append(f"[LEDGER #{i}] {sid} retired:true but no retired_git_ref")
            if s_meta is not None:
                drift.append(f"[LEDGER #{i}] {sid} retired:true but file still present ({s_meta['path']})")
        else:
            if s_meta is None:
                drift.append(f"[LEDGER #{i}] {sid} retired:false but superseded file not found in tree")
            elif not is_blank(ref):
                drift.append(f"[LEDGER #{i}] {sid} retired:false but retired_git_ref set ({ref!r})")

        # The superseded ADR's own status should reflect the supersession.
        own_status = str(s_meta.get("status", "")).strip().lower()
        if own_status not in ("superseded", "deprecated"):
            drift.append(f"[LEDGER #{i}] {sid} own status should be superseded|deprecated (got {s_meta.get('status')!r})")
    return drift


def main():
    check_only = "--check" in sys.argv[1:]
    sh_canonical = scan_canonical()
    sh_table = parse_registry_table()
    sh_docs = scan_sh_script_docs()
    cls_canonical = scan_classification_ids()
    cls_table = parse_classification_table()
    adrs = scan_adr_status()
    ledger_entries = parse_supersession_ledger()

    drift = []

    # --- SH (executable) reconciliation ---
    for sh_id in sorted(sh_canonical):
        row = sh_canonical[sh_id]
        if sh_id not in sh_table:
            drift.append(
                f"[MISSING IN SECTION 8] {sh_id} `{row['exec']}` annotated but absent from the registry"
            )
            continue
        t = sh_table[sh_id]
        for field, disp in [
            ("exec", "Executable"),
            ("class", "Class"),
            ("owner", "Owner"),
            ("allowed", "allowed_in_adopter_repos"),
            ("enforces", "enforces"),
        ]:
            if row[field] != t[field]:
                drift.append(
                    f"[MISMATCH] {sh_id} {disp}: canonical={row[field]!r} vs registry={t[field]!r}"
                )
    for sh_id in sorted(sh_table):
        if sh_id not in sh_canonical:
            drift.append(
                f"[ORPHAN IN SECTION 8] {sh_id} `{sh_table[sh_id]['exec']}` in the table but no .meta.yaml"
            )

    # --- SH script-doc sidecar reconciliation (AC-0014 W3) ---
    # Each SH script-doc's `allowed_in_adopter_repos` must match the
    # authoritative `.meta.yaml` for the same SH id, so a reclassification
    # cannot leave the shipped doc sidecar stale in the opposite direction.
    for sh_id in sorted(sh_docs):
        d = sh_docs[sh_id]
        if sh_id not in sh_canonical:
            drift.append(
                f"[ORPHAN DOC] {sh_id} script-doc `{d['path']}` but no matching .meta.yaml"
            )
            continue
        canon = sh_canonical[sh_id]["allowed"]
        if canon != d["allowed"]:
            drift.append(
                f"[MISMATCH] {sh_id} script-doc allowed_in_adopter_repos: doc={d['allowed']!r} "
                f"vs .meta.yaml={canon!r} (`{d['path']}`)"
            )

    # --- Classification ID (SDX/REF/STD/SEED) reconciliation ---
    for cid in sorted(cls_canonical):
        row = cls_canonical[cid]
        if cid not in cls_table:
            drift.append(
                f"[MISSING IN SECTION 8.1] {cid} `{row['path']}` annotated but absent from the classification registry"
            )
            continue
        t = cls_table[cid]
        for field, disp in [
            ("doc_type", "document_type"),
            ("domain", "domain"),
            ("path", "Path"),
        ]:
            if row[field] != t[field]:
                drift.append(
                    f"[MISMATCH] {cid} {disp}: canonical={row[field]!r} vs registry={t[field]!r}"
                )
    for cid in sorted(cls_table):
        if cid not in cls_canonical:
            drift.append(
                f"[ORPHAN IN SECTION 8.1] {cid} `{cls_table[cid]['path']}` in the registry but no matching frontmatter"
            )

    # --- Supersession ledger reconciliation (ADR-0035) ---
    drift.extend(reconcile_supersession_ledger(adrs))

    # ---- report ----
    print("== Metadata Registry Reconcile ==")
    print(f"Scanned {len(sh_canonical)} .meta.yaml SH companion(s) under mddocs/scripts/ + mddocs/management/tooling/")
    print(f"Scanned {len(sh_docs)} SH script-doc sidecar(s) under mddocs/scripts/")
    print(f"Scanned {len(cls_canonical)} classification ID(s) (SDX/REF/STD/SEED) in mddocs/ frontmatter")
    print(f"Scanned {len(adrs)} ADR(s); supersession ledger: {len(ledger_entries)} entry/entries")
    print(f"Registry rows: SH section 8 = {len(sh_table)}; classification section 8.1 = {len(cls_table)}")
    print()
    print("Canonical SH registry (from .meta.yaml, authoritative):")
    print("| ID | Executable | Class | Owner | allowed_in_adopter_repos | enforces |")
    print("|---|---|---|---|---|---|")
    for sh_id in sorted(sh_canonical):
        r = sh_canonical[sh_id]
        print(
            f"| {sh_id} | `{r['exec']}` | {r['class']} | {r['owner']} | "
            f"{fmt_allowed(r['allowed'])} | {r['enforces'] or '-'} |"
        )
    print()
    print("Canonical classification-ID registry (from frontmatter, authoritative):")
    print("| Classification ID | document_type | domain | Path |")
    print("|---|---|---|---|")
    for cid in sorted(cls_canonical):
        r = cls_canonical[cid]
        print(f"| {cid} | {r['doc_type']} | {r['domain']} | `{r['path']}` |")
    print()

    if drift:
        print(f"Drift detected ({len(drift)} item(s)):")
        for item in sorted(drift):
            print("  " + item)
        if check_only:
            print("\nVerdict: DRIFT - exiting 1")
            return 1
        print("\nVerdict: DRIFT - update the registry table or the artifact metadata to reconcile.")
        return 0

    print("Verdict: CLEAN - registry tables (sections 8 + 8.1) match the artifact metadata.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
