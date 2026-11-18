#!/usr/bin/env bash
set -euo pipefail
book_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd -- "$book_root"
mdbook build
