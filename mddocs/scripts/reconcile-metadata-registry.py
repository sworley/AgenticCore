#!/usr/bin/env python3
"""
Metadata Registry Reconcile / Report.

Scans every `*.meta.yaml` companion under `mddocs/scripts/` (SH executable IDs)
and the frontmatter classification IDs (SDX/REF/STD/SEED) across `mddocs/`, and
compares them against the registry tables (section 8 for SH, section 8.1 for
classification IDs) in `mddocs/scripts/metadata-standard.md`.

The per-artifact metadata (`.meta.yaml` / frontmatter) is authoritative. This
tool reports any drift between the authoritative metadata and the static registry
tables, so they are kept accurate rather than silently drifting.

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
MDDOCS = REPO / "mddocs"
STANDARD = REPO / "mddocs" / "scripts" / "metadata-standard.md"

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
    for meta_path in sorted(SCRIPTS_DIR.rglob("*.meta.yaml")):
        meta = parse_meta(meta_path)
        sh_id = str(meta.get("id", "")).strip()
        if not re.fullmatch(r"SH-\d+", sh_id):
            continue
        rel = meta_path.relative_to(SCRIPTS_DIR)
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
    """Scan .md frontmatter across mddocs/ for SDX/REF/STD/SEED classification IDs."""
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
    return ids


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


def fmt_allowed(value):
    return "true" if value is True else "false"


def main():
    check_only = "--check" in sys.argv[1:]
    sh_canonical = scan_canonical()
    sh_table = parse_registry_table()
    cls_canonical = scan_classification_ids()
    cls_table = parse_classification_table()

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

    # ---- report ----
    print("== Metadata Registry Reconcile ==")
    print(f"Scanned {len(sh_canonical)} .meta.yaml companion(s) under mddocs/scripts/")
    print(f"Scanned {len(cls_canonical)} classification ID(s) (SDX/REF/STD/SEED) in mddocs/ frontmatter")
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
