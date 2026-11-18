#!/usr/bin/env python3
"""
Metadata Registry Reconcile / Report.

Scans every `*.meta.yaml` companion under `mddocs/scripts/`, derives each
artifact's classification (the four-class model), and compares it against the
registry table (section 8) in `mddocs/scripts/metadata-standard.md`.

The per-artifact `.meta.yaml` is authoritative (metadata-standard section 8
note). This tool reports any drift between the authoritative metadata and the
static registry table, so the table is kept accurate rather than silently
drifting.

Usage (from the repository root, or anywhere):
    python3 mddocs/scripts/reconcile-metadata-registry.py            # print report
    python3 mddocs/scripts/reconcile-metadata-registry.py --check    # exit 1 on drift

Exit codes:
    0  report printed; on `--check`, no drift
    1  `--check` and drift was detected
"""

import re
import sys
from pathlib import Path

# Repository root = three levels up from this script (<root>/mddocs/scripts/).
REPO = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO / "mddocs" / "scripts"
STANDARD = REPO / "mddocs" / "scripts" / "metadata-standard.md"

ROW_RE = re.compile(
    r'^\|\s*(SH-\d+)\s*\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*([a-zA-Z-]+)\s*\|\s*'
    r'(true|false)\s*\|\s*([^|]+?)\s*\|\s*$'
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


def fmt_allowed(value):
    return "true" if value is True else "false"


def main():
    check_only = "--check" in sys.argv[1:]
    canonical = scan_canonical()
    table = parse_registry_table()

    drift = []

    for sh_id in sorted(canonical):
        row = canonical[sh_id]
        if sh_id not in table:
            drift.append(
                f"[MISSING IN SECTION 8] {sh_id} `{row['exec']}` annotated but absent from the registry"
            )
            continue
        t = table[sh_id]
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

    for sh_id in sorted(table):
        if sh_id not in canonical:
            drift.append(
                f"[ORPHAN IN SECTION 8] {sh_id} `{table[sh_id]['exec']}` in the table but no .meta.yaml"
            )

    print("== Metadata Registry Reconcile ==")
    print(f"Scanned {len(canonical)} .meta.yaml companion(s) under mddocs/scripts/")
    print(f"Registry rows (metadata-standard section 8): {len(table)}")
    print()
    print("Canonical registry (from .meta.yaml, authoritative):")
    print("| ID | Executable | Class | Owner | allowed_in_adopter_repos | enforces |")
    print("|---|---|---|---|---|---|")
    for sh_id in sorted(canonical):
        r = canonical[sh_id]
        print(
            f"| {sh_id} | `{r['exec']}` | {r['class']} | {r['owner']} | "
            f"{fmt_allowed(r['allowed'])} | {r['enforces'] or '-'} |"
        )
    print()

    if drift:
        print(f"Drift detected ({len(drift)} item(s)):")
        for item in sorted(drift):
            print("  " + item)
        if check_only:
            print("\nVerdict: DRIFT - exiting 1")
            return 1
        print("\nVerdict: DRIFT - update the section 8 table or the .meta.yaml to reconcile.")
        return 0

    print("Verdict: CLEAN - registry table matches .meta.yaml metadata.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
