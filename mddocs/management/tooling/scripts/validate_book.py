#!/usr/bin/env python3
"""Validate local source and built links/assets without network or JavaScript."""

from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


DOCS = Path(__file__).resolve().parents[3]
WORKSPACE = DOCS.parent
BOOK = DOCS / "book"


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []
        self.details = 0

    def handle_starttag(self, tag, attrs):
        if tag == "details":
            self.details += 1
        for name, value in attrs:
            if name in ("href", "src") and value:
                self.targets.append(value)


def main():
    errors = []
    sources = [p for p in WORKSPACE.rglob("*.md")
               if "book" not in p.relative_to(WORKSPACE).parts]
    for source in sources:
        text = source.read_text()
        for target in re.findall(r"\[[^\]\n]*\]\(([^)\n]+)\)", text):
            url = urlsplit(target)
            if url.scheme or url.netloc or not url.path:
                continue
            resolved = (source.parent / unquote(url.path)).resolve()
            if not resolved.exists():
                errors.append(f"source {source.relative_to(WORKSPACE)} -> {target}")
        for target in re.findall(r"\{\{#include\s+([^}\s]+)\s*\}\}", text):
            included = (source.parent / target).resolve()
            if not included.is_relative_to(WORKSPACE) or not included.is_file():
                errors.append(f"include {source.relative_to(WORKSPACE)} -> {target}")

    pages = list(BOOK.rglob("*.html"))
    if not pages:
        errors.append("Run the documentation build first")
    for page in pages:
        parser = Links()
        parser.feed(page.read_text())
        for target in parser.targets:
            url = urlsplit(target)
            if url.scheme or url.netloc or not url.path:
                continue
            path = unquote(url.path)
            resolved = ((BOOK / path.lstrip("/")) if path.startswith("/")
                        else (page.parent / path)).resolve()
            if resolved.name == "README.html":
                resolved = resolved.with_name("index.html")
            if not resolved.is_relative_to(BOOK) or not resolved.exists():
                errors.append(f"built {page.relative_to(BOOK)} -> {target}")

    for pattern in ("mermaid*.min.js", "mermaid-init*.js"):
        assets = list(BOOK.rglob(pattern))
        if not assets or not all(p.stat().st_size > 0 for p in assets):
            errors.append(f"Missing rendering asset: {pattern}")
    for name, expected_details, snippets in (
        ("codex-startup", 3, ("CODEX_HOME", "cli_auth_credentials_store", "prefix_rule")),
        ("documentation-tooling", 2, ("mdbook build", "class Links")),
    ):
        page = BOOK / "management" / "runbooks" / (name + ".html")
        if not page.is_file():
            errors.append(f"Missing source-view page: {name}")
            continue
        text = page.read_text()
        parser = Links()
        parser.feed(text)
        if parser.details < expected_details or re.search(r"\{\{#include\s+\S+?\}\}", text):
            errors.append(f"Missing collapsed source views: {name}")
        for snippet in snippets:
            if snippet not in text:
                errors.append(f"Missing included source in {name}: {snippet}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(sources)} Markdown sources, {len(pages)} HTML pages; "
          "local links/includes, rendering assets, and collapsed source views.")
    print("External URLs, fragment IDs, browser behavior, and Codex runtime were not tested.")


if __name__ == "__main__":
    main()
