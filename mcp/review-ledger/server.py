#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "mcp==1.28.1",
#   "pyyaml==6.0.3",
# ]
# ///
"""
review-ledger MCP server — file-backed YAML ledger for security and review findings.

Transport: stdio. Framework: mcp SDK.
Launch via:
  uv run mcp/review-ledger/server.py --data-path .security --id-prefix SF --run-prefix SR
  uv run mcp/review-ledger/server.py --data-path .reviews  --id-prefix RF --run-prefix RR

Security requirements:
  - path containment enforced: all file writes stay inside --data-path
  - fcntl advisory lock held during each write (D-2)
  - request_finding_update/approve_finding_update split enforced (D-3)
  - no credentials in tool arguments
"""

from __future__ import annotations

import argparse
import fcntl
import os
import sys
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Optional

import yaml
from mcp.server.fastmcp import FastMCP


# ---------------------------------------------------------------------------
# Globals (set from CLI args at startup)
# ---------------------------------------------------------------------------

DATA_PATH: Path = Path(".")
ID_PREFIX: str = "SF"
RUN_PREFIX: str = "SR"

mcp = FastMCP("review-ledger")


# ---------------------------------------------------------------------------
# YAML helpers
# ---------------------------------------------------------------------------

def _findings_path() -> Path:
    return DATA_PATH / "findings.yaml"


def _log_path() -> Path:
    return DATA_PATH / "reviewer-log.yaml"


def _pending_path(finding_id: str) -> Path:
    return DATA_PATH / f"pending-{finding_id.lower()}.yaml"


def _load_yaml_list(path: Path) -> list[dict]:
    """Load a YAML file that contains a list of mappings, ignoring comment-only header."""
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if data is None:
        return []
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    return []


def _dump_yaml_list(items: list[dict]) -> str:
    """Dump a list of mappings as YAML, one entry per block."""
    return yaml.dump(
        items,
        default_flow_style=False,
        allow_unicode=True,
        sort_keys=False,
    )


def _append_yaml_record(path: Path, record: dict) -> None:
    """Append a single YAML record to a file, with fcntl advisory lock."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            block = yaml.dump(
                [record],
                default_flow_style=False,
                allow_unicode=True,
                sort_keys=False,
            )
            fh.write(block)
            fh.flush()
        finally:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)


def _write_yaml_file(path: Path, records: list[dict]) -> None:
    """Overwrite a YAML file atomically via fcntl lock."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # Write to temp then rename for atomicity
    tmp = path.with_suffix(".yaml.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            fh.write(_dump_yaml_list(records))
            fh.flush()
        finally:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    tmp.rename(path)


# ---------------------------------------------------------------------------
# ID generation
# ---------------------------------------------------------------------------

def _next_finding_id() -> str:
    """Return the next SF-NNN or RF-NNN ID."""
    findings = _load_yaml_list(_findings_path())
    max_n = 0
    for f in findings:
        fid = str(f.get("id", ""))
        if fid.startswith(ID_PREFIX + "-"):
            try:
                n = int(fid[len(ID_PREFIX) + 1:])
                max_n = max(max_n, n)
            except ValueError:
                pass
    return f"{ID_PREFIX}-{max_n + 1:03d}"


def _next_run_id() -> str:
    """Return the next SR-YYYY-MM-DD-NN or RR-YYYY-MM-DD-NN run ID."""
    today = date.today().isoformat()
    prefix = f"{RUN_PREFIX}-{today}-"
    runs = _load_yaml_list(_log_path())
    max_n = 0
    for r in runs:
        rid = str(r.get("run_id", ""))
        if rid.startswith(prefix):
            try:
                n = int(rid[len(prefix):])
                max_n = max(max_n, n)
            except ValueError:
                pass
    return f"{prefix}{max_n + 1:02d}"


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

@mcp.tool()
def log_finding(
    severity: str,
    source_commit: str,
    source_agent: str,
    file: str,
    line: Optional[int],
    description: str,
) -> dict:
    """
    Append a new finding to findings.yaml with an auto-assigned ID.

    severity: note | warning | finding
    source_commit: git commit hash or label (e.g. 'staged-branch-name')
    source_agent: agent name that produced the finding (e.g. 'security-reviewer')
    file: file path the finding refers to
    line: line number, or null
    description: brief description of the finding (no sensitive content)

    Returns the assigned finding ID.
    """
    if severity not in ("note", "warning", "finding"):
        return {"error": f"invalid severity '{severity}'; must be note | warning | finding"}

    finding_id = _next_finding_id()
    today = date.today().isoformat()

    record: dict[str, Any] = {
        "id": finding_id,
        "severity": severity,
        "status": "open",
        "source": {
            "commit": source_commit,
            "reviewer_run": None,
            "agent": source_agent,
        },
        "file": file,
        "line": line,
        "description": description,
        "resolution": None,
        "opened": today,
        "closed": None,
    }

    _append_yaml_record(_findings_path(), record)
    return {"id": finding_id, "status": "open", "severity": severity}


@mcp.tool()
def log_reviewer_run(
    commit: str,
    verdict: str,
    finding_ids: list[str],
    notes: Optional[str] = None,
) -> dict:
    """
    Append a reviewer run entry to reviewer-log.yaml with an auto-assigned run ID.

    commit: git commit hash or label reviewed
    verdict: clean | approved_with_notes | blocked
    finding_ids: list of finding IDs produced during this run (may be empty)
    notes: optional free-text notes

    Returns the assigned run ID.
    """
    if verdict not in ("clean", "approved_with_notes", "blocked"):
        return {
            "error": f"invalid verdict '{verdict}'; must be clean | approved_with_notes | blocked"
        }

    run_id = _next_run_id()
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")

    record: dict[str, Any] = {
        "run_id": run_id,
        "commit_reviewed": commit,
        "verdict": verdict,
        "finding_ids": finding_ids,
        "agent": source_agent_from_env(),
        "timestamp": timestamp,
    }
    if notes:
        record["notes"] = notes

    _append_yaml_record(_log_path(), record)
    return {"run_id": run_id, "verdict": verdict}


def source_agent_from_env() -> str:
    """Infer agent name from environment if possible."""
    return os.environ.get("MCP_AGENT_NAME", "unknown")


@mcp.tool()
def list_findings(
    status: Optional[str] = None,
    severity: Optional[str] = None,
) -> list[dict]:
    """
    Return findings from findings.yaml, optionally filtered.

    status: open | mitigated | closed (omit for all)
    severity: note | warning | finding (omit for all)
    """
    findings = _load_yaml_list(_findings_path())
    result = []
    for f in findings:
        if status and f.get("status") != status:
            continue
        if severity and f.get("severity") != severity:
            continue
        result.append(f)
    return result


@mcp.tool()
def get_finding(id: str) -> dict:
    """
    Return the full finding record for the given ID, including any pending update.

    id: finding ID, e.g. SF-001 or RF-001
    """
    findings = _load_yaml_list(_findings_path())
    for f in findings:
        if str(f.get("id", "")) == id:
            result = dict(f)
            pending = _pending_path(id)
            if pending.exists():
                with pending.open("r", encoding="utf-8") as fh:
                    pdata = yaml.safe_load(fh)
                if pdata:
                    result["_pending_update"] = pdata
            return result
    return {"error": f"finding {id} not found"}


@mcp.tool()
def request_finding_update(
    id: str,
    proposed_status: str,
    rationale: str,
) -> dict:
    """
    Write a pending-update record alongside the finding. Does NOT modify the finding.

    id: finding ID to update, e.g. SF-001
    proposed_status: the proposed new status (open | mitigated | closed)
    rationale: explanation for the proposed change

    Returns confirmation. Apply with approve_finding_update (HIL-only).
    """
    if proposed_status not in ("open", "mitigated", "closed"):
        return {
            "error": f"invalid proposed_status '{proposed_status}'; must be open | mitigated | closed"
        }

    findings = _load_yaml_list(_findings_path())
    finding_exists = any(str(f.get("id", "")) == id for f in findings)
    if not finding_exists:
        return {"error": f"finding {id} not found"}

    pending = _pending_path(id)
    if pending.exists():
        return {
            "error": f"a pending update already exists for {id}; it must be approved or discarded first"
        }

    record = {
        "finding_id": id,
        "proposed_status": proposed_status,
        "rationale": rationale,
        "requested_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
        "requested_by": source_agent_from_env(),
    }

    pending.parent.mkdir(parents=True, exist_ok=True)
    with open(pending, "w", encoding="utf-8") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            yaml.dump(record, fh, default_flow_style=False, allow_unicode=True, sort_keys=False)
            fh.flush()
        finally:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)

    return {
        "finding_id": id,
        "status": "pending",
        "proposed_status": proposed_status,
        "message": f"pending update written; apply with approve_finding_update('{id}')",
    }


@mcp.tool()
def approve_finding_update(id: str) -> dict:
    """
    Apply a pending update to a finding. This tool should only be wired into hil-assistant.

    id: finding ID with a pending update, e.g. SF-001

    Reads the pending-<id>.yaml record, applies the proposed_status change to the
    finding, records resolution and closed date if closing, then removes the pending file.
    """
    pending = _pending_path(id)
    if not pending.exists():
        return {"error": f"no pending update found for {id}"}

    with pending.open("r", encoding="utf-8") as fh:
        pdata = yaml.safe_load(fh)
    if not pdata:
        return {"error": f"pending update file for {id} is empty or invalid"}

    proposed_status = pdata.get("proposed_status")
    rationale = pdata.get("rationale", "")
    if not proposed_status:
        return {"error": "pending update record missing proposed_status"}

    findings = _load_yaml_list(_findings_path())
    updated = False
    today = date.today().isoformat()
    for f in findings:
        if str(f.get("id", "")) == id:
            f["status"] = proposed_status
            if proposed_status in ("mitigated", "closed"):
                f["resolution"] = rationale
                f["closed"] = today
            else:
                # Re-opening: clear resolution/closed
                f["resolution"] = None
                f["closed"] = None
            updated = True
            break

    if not updated:
        return {"error": f"finding {id} not found in findings.yaml"}

    _write_yaml_file(_findings_path(), findings)
    pending.unlink()

    return {
        "finding_id": id,
        "new_status": proposed_status,
        "approved_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
    }


@mcp.tool()
def get_audit_report(since: Optional[str] = None) -> dict:
    """
    Return an aggregate audit report.

    since: ISO date string (YYYY-MM-DD) to filter findings opened on or after this date.
           Omit for all findings.

    Returns:
      - findings_by_severity: counts by severity
      - findings_by_status: counts by status
      - verdict_trend: reviewer runs with verdicts
      - open_items: list of open findings with age in days
      - resolution_velocity: average days from open to close for closed/mitigated findings
    """
    findings = _load_yaml_list(_findings_path())
    runs = _load_yaml_list(_log_path())
    today = date.today()

    def parse_date(s: Any) -> Optional[date]:
        if not s:
            return None
        try:
            return date.fromisoformat(str(s))
        except ValueError:
            return None

    since_date = parse_date(since)

    # Filter by since if provided
    if since_date:
        findings = [
            f for f in findings
            if (parse_date(f.get("opened")) or date.min) >= since_date
        ]
        runs = [
            r for r in runs
            if (parse_date((str(r.get("timestamp", ""))[:10])) or date.min) >= since_date
        ]

    # Counts
    by_severity: dict[str, int] = {}
    by_status: dict[str, int] = {}
    open_items = []
    close_times: list[int] = []

    for f in findings:
        sev = str(f.get("severity", "unknown"))
        sta = str(f.get("status", "unknown"))
        by_severity[sev] = by_severity.get(sev, 0) + 1
        by_status[sta] = by_status.get(sta, 0) + 1

        opened = parse_date(f.get("opened"))
        if sta == "open" and opened:
            age = (today - opened).days
            open_items.append({
                "id": f.get("id"),
                "severity": sev,
                "file": f.get("file"),
                "opened": str(f.get("opened")),
                "age_days": age,
            })

        if sta in ("mitigated", "closed"):
            opened = parse_date(f.get("opened"))
            closed = parse_date(f.get("closed"))
            if opened and closed:
                close_times.append((closed - opened).days)

    resolution_velocity = (
        round(sum(close_times) / len(close_times), 1) if close_times else None
    )

    # Verdict trend (most recent first)
    verdict_trend = []
    for r in reversed(runs):
        verdict_trend.append({
            "run_id": r.get("run_id"),
            "commit": r.get("commit_reviewed"),
            "verdict": r.get("verdict"),
            "timestamp": r.get("timestamp"),
            "finding_count": len(r.get("finding_ids", [])),
        })

    return {
        "since": since or "all",
        "findings_by_severity": by_severity,
        "findings_by_status": by_status,
        "verdict_trend": verdict_trend,
        "open_items": sorted(open_items, key=lambda x: x["age_days"], reverse=True),
        "resolution_velocity_avg_days": resolution_velocity,
        "total_findings": len(findings),
        "total_runs": len(runs),
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    global DATA_PATH, ID_PREFIX, RUN_PREFIX

    parser = argparse.ArgumentParser(
        description="review-ledger MCP server — file-backed YAML finding ledger"
    )
    parser.add_argument(
        "--data-path",
        required=True,
        help="Backing path for findings.yaml and reviewer-log.yaml (e.g. .security or .reviews)",
    )
    parser.add_argument(
        "--id-prefix",
        required=True,
        choices=["SF", "RF"],
        help="Finding ID prefix: SF (security) or RF (review)",
    )
    parser.add_argument(
        "--run-prefix",
        required=True,
        choices=["SR", "RR"],
        help="Run ID prefix: SR (security reviewer) or RR (review runner)",
    )
    args = parser.parse_args()

    DATA_PATH = Path(args.data_path).resolve()
    ID_PREFIX = args.id_prefix
    RUN_PREFIX = args.run_prefix

    print(
        f"review-ledger: data_path={DATA_PATH} id_prefix={ID_PREFIX} run_prefix={RUN_PREFIX}",
        file=sys.stderr,
    )

    if not DATA_PATH.exists():
        print(
            f"review-ledger: WARNING — data path {DATA_PATH} does not exist; "
            "it will be created on first write",
            file=sys.stderr,
        )

    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
