# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "fastmcp==3.4.2",
# ]
# ///
"""
mcp-rag-docs — BM25 search MCP server for the mddocs/ corpus.

Transport: stdio. Framework: FastMCP.
Launch via: uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs

BM25Okapi scoring is implemented inline using only the Python standard library.
No numpy or rank-bm25 dependency.

Security requirements:
  - get_doc enforces path containment via pathlib.resolve() + is_relative_to()
  - Resolved --docs-root logged to stderr at startup
  - No credentials in tool arguments
  - Read-only: no write tools exposed
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from fastmcp import FastMCP


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class Chunk:
    file_path: str          # relative to docs_root, e.g. "adr/adr-0001-bootstrap-architecture.md"
    section_heading: str    # heading text, or "" for preamble before first ##
    content: str
    line_start: int         # 1-based line number in the source file


@dataclass
class SearchResult:
    file_path: str
    section_heading: str
    snippet: str            # first 200 chars of content
    score: float
    line_start: int


# ---------------------------------------------------------------------------
# BM25Okapi — inline, stdlib only
# ---------------------------------------------------------------------------

class BM25Okapi:
    """
    BM25Okapi scoring — standard library only, no numpy.

    Parameters match the rank-bm25 defaults: k1=1.5, b=0.75, epsilon=0.25.
    """

    def __init__(
        self,
        corpus: list[list[str]],
        k1: float = 1.5,
        b: float = 0.75,
        epsilon: float = 0.25,
    ) -> None:
        self.k1 = k1
        self.b = b
        self.epsilon = epsilon
        self.corpus_size = len(corpus)
        self.doc_len: list[int] = []
        self.doc_freqs: list[dict[str, int]] = []
        self.idf: dict[str, float] = {}
        self.avgdl: float = 0.0

        nd = self._initialize(corpus)
        self._calc_idf(nd)

    def _initialize(self, corpus: list[list[str]]) -> dict[str, int]:
        nd: dict[str, int] = {}
        num_doc = 0
        for document in corpus:
            self.doc_len.append(len(document))
            num_doc += len(document)
            freqs: dict[str, int] = {}
            for word in document:
                freqs[word] = freqs.get(word, 0) + 1
            self.doc_freqs.append(freqs)
            for word in freqs:
                nd[word] = nd.get(word, 0) + 1
        self.avgdl = num_doc / self.corpus_size if self.corpus_size else 0.0
        return nd

    def _calc_idf(self, nd: dict[str, int]) -> None:
        idf_sum = 0.0
        negative_idfs: list[str] = []
        for word, freq in nd.items():
            idf = math.log(self.corpus_size - freq + 0.5) - math.log(freq + 0.5)
            self.idf[word] = idf
            idf_sum += idf
            if idf < 0:
                negative_idfs.append(word)
        average_idf = idf_sum / len(self.idf) if self.idf else 0.0
        eps = self.epsilon * average_idf
        for word in negative_idfs:
            self.idf[word] = eps

    def get_scores(self, query: list[str]) -> list[float]:
        scores = [0.0] * self.corpus_size
        for q in query:
            q_idf = self.idf.get(q, 0.0)
            if q_idf == 0.0:
                continue
            for i, (doc_freqs, dl) in enumerate(zip(self.doc_freqs, self.doc_len)):
                q_freq = doc_freqs.get(q, 0)
                denom = q_freq + self.k1 * (1 - self.b + self.b * dl / self.avgdl)
                scores[i] += q_idf * (q_freq * (self.k1 + 1) / denom)
        return scores


# ---------------------------------------------------------------------------
# Index builder
# ---------------------------------------------------------------------------

def _tokenize(text: str) -> list[str]:
    """Lowercase word tokenizer — good enough for BM25 over markdown."""
    return re.findall(r"[a-z0-9_\-]+", text.lower())


def _split_sections(text: str) -> list[tuple[str, str, int]]:
    """
    Split a markdown file into (heading, content, line_start) tuples on ## boundaries.
    The preamble before the first ## heading is returned with heading="".
    """
    sections: list[tuple[str, str, int]] = []
    current_heading = ""
    current_lines: list[str] = []
    current_start = 1

    for lineno, line in enumerate(text.splitlines(), start=1):
        if line.startswith("## "):
            if current_lines:
                sections.append((current_heading, "\n".join(current_lines), current_start))
            current_heading = line.lstrip("# ").strip()
            current_lines = [line]
            current_start = lineno
        else:
            current_lines.append(line)

    if current_lines:
        sections.append((current_heading, "\n".join(current_lines), current_start))

    return sections


def build_index(docs_root: Path) -> tuple[list[Chunk], BM25Okapi]:
    """Walk docs_root/**/*.md, split into sections, build BM25 index."""
    chunks: list[Chunk] = []

    for md_file in sorted(docs_root.rglob("*.md")):
        rel = md_file.relative_to(docs_root).as_posix()
        try:
            text = md_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        for heading, content, line_start in _split_sections(text):
            if not content.strip():
                continue
            chunks.append(Chunk(
                file_path=rel,
                section_heading=heading,
                content=content,
                line_start=line_start,
            ))

    if not chunks:
        return chunks, BM25Okapi([[]])

    tokenized = [_tokenize(c.content) for c in chunks]
    index = BM25Okapi(tokenized)
    return chunks, index


# ---------------------------------------------------------------------------
# Server setup
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="mcp-rag-docs: BM25 search MCP server for mddocs/ corpus"
    )
    parser.add_argument(
        "--docs-root",
        required=True,
        metavar="PATH",
        help="Path to the mddocs/ directory to index (absolute or relative to cwd)",
    )
    return parser.parse_args()


def _validate_docs_root(raw: str) -> Path:
    p = Path(raw).resolve()
    if not p.exists():
        print(f"[mcp-rag-docs] ERROR: --docs-root does not exist: {p}", file=sys.stderr)
        sys.exit(1)
    if not p.is_dir():
        print(f"[mcp-rag-docs] ERROR: --docs-root is not a directory: {p}", file=sys.stderr)
        sys.exit(1)
    return p


_args = _parse_args()
DOCS_ROOT: Path = _validate_docs_root(_args.docs_root)

print(f"[mcp-rag-docs] corpus root: {DOCS_ROOT}", file=sys.stderr)

_CHUNKS, _INDEX = build_index(DOCS_ROOT)
print(f"[mcp-rag-docs] indexed {len(_CHUNKS)} sections from {DOCS_ROOT}", file=sys.stderr)

mcp = FastMCP("mcp-rag-docs")


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

@mcp.tool()
def search_docs(query: str, top_k: int = 5) -> list[dict]:
    """
    Search the mddocs/ corpus using BM25.

    Returns up to top_k ranked results, each with:
      - file_path: relative path within mddocs/
      - section_heading: ## heading of the matching section (empty string for preamble)
      - snippet: first 200 characters of the section content
      - score: BM25 relevance score (higher is more relevant)
      - line_start: 1-based line number in the source file
    """
    if not _CHUNKS:
        return []

    top_k = max(1, min(top_k, 20))
    tokens = _tokenize(query)
    scores = _INDEX.get_scores(tokens)

    ranked = sorted(enumerate(scores), key=lambda x: x[1], reverse=True)[:top_k]

    results = []
    for idx, score in ranked:
        if score <= 0:
            break
        c = _CHUNKS[idx]
        results.append({
            "file_path": c.file_path,
            "section_heading": c.section_heading,
            "snippet": c.content[:200],
            "score": round(float(score), 4),
            "line_start": c.line_start,
        })
    return results


@mcp.tool()
def list_docs(path_prefix: str = "") -> list[str]:
    """
    List all indexed file paths within mddocs/.

    Optionally filter by path_prefix (e.g. "adr/" to list only ADRs).
    Returns relative paths sorted alphabetically.
    """
    seen: set[str] = set()
    results: list[str] = []
    for c in _CHUNKS:
        if c.file_path not in seen:
            seen.add(c.file_path)
            if not path_prefix or c.file_path.startswith(path_prefix):
                results.append(c.file_path)
    return sorted(results)


@mcp.tool()
def get_doc(file_path: str) -> str:
    """
    Return the full content of a file within mddocs/.

    file_path must be a relative path within the mddocs/ corpus root
    (e.g. "adr/adr-0001-bootstrap-architecture.md").

    Returns the file content as a string.
    Raises an error if the path resolves outside mddocs/ or the file does not exist.
    """
    requested = (DOCS_ROOT / file_path).resolve()
    if not requested.is_relative_to(DOCS_ROOT):
        raise ValueError(
            f"Path '{file_path}' resolves outside the corpus root. Access denied."
        )
    if not requested.exists():
        raise FileNotFoundError(f"File not found in corpus: {file_path}")
    if not requested.is_file():
        raise ValueError(f"Path is not a file: {file_path}")
    return requested.read_text(encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    mcp.run()
