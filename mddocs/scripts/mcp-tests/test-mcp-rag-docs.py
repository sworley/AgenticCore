#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "fastmcp==3.4.2",
# ]
# ///
"""
MCP protocol-level smoke test for mcp-rag-docs server.

Uses fastmcp UvStdioTransport to exercise the actual MCP protocol layer.
Run from the repository root: uv run mddocs/scripts/mcp-tests/test-mcp-rag-docs.py
"""

import asyncio
import json
import sys
from pathlib import Path

# Resolve paths relative to repo root (two levels up from this script)
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent.parent
SERVER = REPO_ROOT / "mddocs/mcp/mcp-rag-docs/server.py"
DOCS_ROOT = REPO_ROOT / "mddocs"

PASS = 0
FAIL = 0


def ok(msg: str) -> None:
    global PASS
    print(f"[PASS] {msg}")
    PASS += 1


def fail(msg: str, reason: str) -> None:
    global FAIL
    print(f"[FAIL] {msg}: {reason}")
    FAIL += 1


async def run_tests() -> None:
    from fastmcp.client import Client
    from fastmcp.client.transports import UvStdioTransport

    transport = UvStdioTransport(
        command=str(SERVER),
        args=["--docs-root", str(DOCS_ROOT)],
    )

    async with Client(transport) as client:
        # 1. search_docs — query present in corpus
        result = await client.call_tool("search_docs", {"query": "session open checklist", "top_k": 3})
        results = json.loads(result.content[0].text)
        if results:
            ok(f"search_docs 'session open checklist' — {len(results)} result(s)")
        else:
            fail("search_docs 'session open checklist'", "empty results")

        # 2. search_docs — bench model query
        result = await client.call_tool("search_docs", {"query": "agent bench model worktree", "top_k": 5})
        results = json.loads(result.content[0].text)
        if results:
            ok(f"search_docs 'agent bench model worktree' — {len(results)} result(s)")
        else:
            fail("search_docs 'agent bench model worktree'", "empty results")

        # 3. search_docs — may return 0 results; warn only
        result = await client.call_tool("search_docs", {"query": "BM25 index rebuild", "top_k": 3})
        results = json.loads(result.content[0].text)
        ok(f"search_docs 'BM25 index rebuild' — {len(results)} result(s) (0 acceptable)")

        # 4. list_docs — assert non-empty
        result = await client.call_tool("list_docs", {})
        docs = json.loads(result.content[0].text)
        if docs:
            ok(f"list_docs — {len(docs)} document(s) indexed")
        else:
            fail("list_docs", "empty document list")
            return

        # 5. get_doc — use a known stable path
        known_path = "adr/adr-0001-bootstrap-architecture.md"
        result = await client.call_tool("get_doc", {"file_path": known_path})
        content = result.content[0].text
        if content:
            ok(f"get_doc '{known_path}' — {len(content)} chars")
        else:
            fail(f"get_doc '{known_path}'", "empty content")


def main() -> None:
    asyncio.run(run_tests())
    total = PASS + FAIL
    print()
    print(f"rag-docs: {PASS}/{total} passed")
    if FAIL > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
